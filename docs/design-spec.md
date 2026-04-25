# `owl` — Design Specification

**Observant Watcher of Lines — a file viewer for AGNOS / Cyrius**

Version: 1.0
Status: Released 2026-04-23
Audience: Implementation agent / contributors
Name: English "owl" — progenitor is Sanskrit **ulūka** (उलूक) via
PIE *\*ulū-*. As a backronym: **O**bservant **W**atcher of **L**ines
— *observant* for syntax / language / change detection, *watcher*
for the per-line gutter + VCS markers, *lines* for the unit the tool
operates on. See `README.md` §Name.

---

## 1. Purpose & Scope

`owl` is a terminal file viewer in the tradition of `cat` and `bat`. It reads files from disk (or stdin) and prints their contents to stdout, optionally with syntax highlighting, line numbers, and other decorations. It is designed for the AGNOS / Cyrius platform but should remain portable where reasonable.

**In scope:**
- Reading and displaying file contents
- Syntax highlighting
- Line numbering and gutter decorations
- Paging for long output
- Concatenating multiple files
- stdin piping (input and output)

**Out of scope (for v1):**
- Editing files
- Searching within files (delegate to `grep`, `rg`, etc.)
- Diffing files (delegate to `diff`)
- Network/URL fetching
- Binary file hex-dumping (may be added later; for v1, detect and refuse with a clear message)

---

## 2. Design Principles

1. **Drop-in friendly.** A user who types `owl file.txt` instead of `cat file.txt` should get a reasonable result without flags.
2. **Pipe-aware.** When stdout is not a TTY (i.e. output is piped), `owl` disables all decorations by default and emits plain bytes. This preserves composability with other tools.
3. **Fast on common paths.** Small text files should render with no perceptible delay. Syntax highlighting should not block first-byte output on large files — stream where possible.
4. **Quiet by default.** No banners, no version strings, no "thanks for using owl" messages. Errors go to stderr, content goes to stdout.
5. **Predictable exit codes.** See §9.
6. **Respect the platform.** Follow AGNOS / Cyrius conventions for config file locations, color handling, and signal behavior.

---

## 3. Invocation & CLI Surface

### 3.1 Synopsis

```
owl [OPTIONS] [FILE...]
owl [OPTIONS] -          # read from stdin
owl                      # with no args and stdin is a pipe: read stdin
                         # with no args and stdin is a TTY: print short help
```

### 3.2 Arguments

- `FILE...` — one or more file paths. If multiple, files are concatenated in order, each preceded by a header (see §6.3) when decorations are on.
- `-` — explicit stdin marker. Can be mixed with file paths (e.g. `owl a.txt - b.txt`).

### 3.3 Options

| Short | Long | Description |
|-------|------|-------------|
| `-n` | `--number` | Show line numbers (on by default in decorated mode) |
| `-N` | `--no-number` | Hide line numbers |
| `-p` | `--plain` | No decorations. Equivalent to `cat`. Shortcut for `--no-number --no-highlight --no-header --no-pager` |
| `-P` | `--paging <when>` | Paging: `auto` (default), `always`, `never` |
| | `--color <when>` | Color: `auto` (default), `always`, `never` |
| | `--theme <name>` | Syntax highlighting theme. See §5.2 |
| | `--list-themes` | Print available themes and exit |
| | `--language <lang>` | Force language for syntax highlighting (overrides auto-detect) |
| | `--list-languages` | Print supported languages and exit |
| `-A` | `--show-all` | Show non-printable characters (tabs as `→`, newlines as `$`, etc.) |
| | `--tabs <n>` | Render tabs as N spaces. Default: 4. `0` preserves literal tab |
| | `--wrap <mode>` | Line wrapping: `auto` (default), `never`, `character` |
| | `--style <list>` | Comma-separated decoration list: `numbers`, `header`, `grid`, `changes`, `snip`. Overrides individual toggles |
| `-h` | `--help` | Print help and exit |
| `-V` | `--version` | Print version and exit |

### 3.4 Environment variables

- `OWL_THEME` — default theme name
- `OWL_PAGER` — pager command (overrides system pager)
- `OWL_CONFIG` — config file path (overrides default location)
- `NO_COLOR` — if set to any non-empty value, disable color (standard convention)
- `PAGER` — fallback pager if `OWL_PAGER` unset

---

## 4. Behavior Modes

`owl` operates in one of two rendering modes, auto-selected:

### 4.1 Decorated mode (default when stdout is a TTY)

- Syntax highlighting on
- Line numbers on
- File header shown (when multiple files or when a single named file)
- Output paged if it exceeds terminal height
- Git gutter markers shown if inside a repo

### 4.2 Plain mode (default when stdout is not a TTY, or `-p`)

- No decorations of any kind
- Bytes pass through essentially unchanged
- Exit behavior matches `cat` for scriptability

**Rule:** `owl` MUST detect whether stdout is a TTY and flip to plain mode when it is not, unless the user explicitly requests `--color always` or `--paging always`.

---

## 5. Syntax Highlighting

### 5.1 Language detection

Detection order (first match wins):
1. `--language` flag if given
2. Filename and extension match (e.g. `.py` → Python, `Makefile` → Make)
3. Shebang line (e.g. `#!/usr/bin/env node` → JavaScript)
4. Content heuristics (optional, may be skipped in v1)
5. Fallback: plain text, no highlighting

### 5.2 Themes

Ship with at least:
- One light theme
- One dark theme (default)
- A high-contrast theme for accessibility
- A "none" / monochrome theme

Theme files should be data, not code — loadable from a config directory so users can add their own without recompiling.

### 5.3 Performance

Highlighting must not block first output on files larger than a reasonable threshold (suggested: 1 MB). For larger files, either:
- Stream highlighted output line-by-line, or
- Disable highlighting past a size limit (suggested: 10 MB) and emit a one-line notice to stderr

---

## 6. Output Format

### 6.1 Line numbers

- Right-aligned in a gutter
- Separated from content by a single vertical bar (`│` in Unicode, `|` in ASCII fallback)
- Gutter width adapts to file length (e.g. 3 cols for <1000 lines, 4 for <10000)

### 6.2 Git gutter (optional, when inside a git repo)

- `+` for added lines
- `~` for modified lines
- `−` for removed lines (shown as marker on adjacent line)
- Rendered between line number and content

### 6.3 File header

When showing a file in decorated mode:

```
─── File: path/to/file.ext ─────────────────────────────
```

When showing multiple files, a header precedes each. A trailing horizontal rule closes the last file.

### 6.4 Non-printable characters (`-A`)

- Tab → `→` followed by padding
- Newline → `$` at end of line
- Carriage return → `␍`
- Other control chars → `^X` notation

---

## 7. Paging

- Default pager: system pager on AGNOS / Cyrius, or `less -R` if available
- Paging triggered only when output exceeds terminal height AND stdout is TTY
- `--paging never` or piped output disables paging
- Pager receives already-rendered output (colors included); pager must be capable of interpreting ANSI escape sequences, or color must be stripped

---

## 8. Configuration File

Location: platform-appropriate config dir (e.g. `$XDG_CONFIG_HOME/owl/config.toml` or AGNOS/Cyrius equivalent).

Example:

```toml
theme = "nocturne-dark"
paging = "auto"
tabs = 2
wrap = "auto"

[style]
numbers = true
header = true
changes = true
```

CLI flags override config file values. Environment variables override config file but are overridden by CLI flags.

Precedence (lowest to highest): defaults → config file → environment → CLI flags.

---

## 9. Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success — all files read and displayed |
| 1 | General error (e.g. one or more files could not be read, but others succeeded) |
| 2 | Usage error (bad flag, missing argument) |
| 3 | I/O error on stdout (e.g. broken pipe — may also be silently suppressed, see below) |
| 4 | All requested files failed to open |

On `SIGPIPE` (downstream reader closed), exit cleanly without error message. This is critical for pipelines like `owl huge.log | head`.

---

## 10. Error Handling

- Errors go to stderr, never stdout.
- One file failing does not abort other files. `owl a.txt missing.txt b.txt` reads `a`, prints an error for `missing`, then reads `b`. Exit code reflects partial failure.
- Error format: `owl: <path>: <reason>` — mirrors classic Unix utilities.
- Binary file detection: if a file appears to be binary (null bytes in first N bytes, or failed UTF-8 decode at high rate), print a one-line notice to stderr and skip unless `--show-all` or `--plain` is set.

---

## 11. Signal Handling

- `SIGINT` (Ctrl-C): exit immediately, clean up pager if spawned
- `SIGPIPE`: exit silently with appropriate code
- `SIGTERM`: clean shutdown

---

## 12. Non-functional Requirements

- **Startup time:** under 50ms for a no-op invocation on the target platform
- **Memory:** should not load entire file into memory for streaming-friendly operations; hard cap based on platform norms
- **Dependencies:** minimize. Syntax grammars and themes should be data files, not compiled-in, where the platform allows
- **Localization:** error messages in English for v1; structure code to allow translation later
- **Accessibility:** high-contrast theme required; respect `NO_COLOR`

---

## 13. Testing Checklist

A conforming implementation should pass at least:

- `owl file.txt` prints the file with decorations on a TTY
- `owl file.txt | cat` prints the file with NO decorations
- `owl a b c` concatenates three files with headers
- `echo hi | owl` reads from stdin
- `echo hi | owl -` same as above
- `owl missing.txt` exits non-zero, prints error to stderr, stdout is empty
- `owl a missing b` prints a and b, error for missing, exits non-zero
- `owl huge.log | head -5` exits cleanly without broken-pipe error
- `owl binary.bin` skips with notice
- `owl -p file.py` produces byte-identical output to `cat file.py`
- `NO_COLOR=1 owl file.py` produces no ANSI codes
- `owl --language rust plain.txt` highlights as Rust
- `owl` with no args and TTY stdin prints help

---

## 14. Open Questions (for implementer)

1. Should there be a `--follow` / `-f` mode like `tail -f` with highlighting? (Suggested: defer to v2)
2. How aggressive should content-based language detection be? (Suggested: minimal in v1 — extension + shebang only)
3. Should `owl` integrate with the AGNOS / Cyrius native theming system, or maintain its own theme format?
4. Is there a platform convention on config file format (TOML vs native) that should be followed?

---

*End of specification.*
