# owl — Roadmap

A phased plan for building `owl` from nothing to a polished release. Each milestone is independently shippable and adds a coherent layer of functionality. The goal is to have something usable at the end of every phase, not a 6-month march toward a first demo.

---

## Guiding principles for the roadmap

- **Ship plain mode first, decorations later.** Plain mode is the foundation — everything else is icing. If plain mode is broken, nothing else matters.
- **Every milestone is testable.** No "phase complete" without a checklist of observable behaviors.
- **Correctness before features.** A v1 that does five things perfectly beats a v1 that does fifteen things unreliably.
- **Defer what you can.** Items in later milestones should stay out of earlier ones even if they seem easy. Scope creep is the enemy.

---

## Milestone 0 — Scaffolding

**Goal:** A binary called `owl` exists, builds cleanly, and prints something.

- Project structure and build system for the target platform
- CI or equivalent on AGNOS / Cyrius (build + basic smoke test)
- `owl --version` and `owl --help` work
- `owl` with no args and a TTY prints a short help message
- License file, README stub, contribution notes

**Done when:** a fresh checkout builds and produces a working binary with no runtime behavior beyond version/help.

---

## Milestone 1 — `cat` parity (plain mode)

**Goal:** `owl -p` is a drop-in replacement for `cat` for all common cases.

- Read one or more files and write bytes to stdout
- Read from stdin when no files given or `-` is passed
- Mix files and stdin (`owl a.txt - b.txt`)
- Correct handling of broken pipes (`SIGPIPE` → clean exit)
- Exit codes per spec (0, 1, 2, 4)
- Errors to stderr in `owl: <path>: <reason>` format
- One file failing does not abort other files

**Testing:**
- Byte-for-byte comparison with `cat` for a corpus of text files
- `owl -p huge.log | head -5` exits cleanly
- `owl missing real.txt` prints error for one, contents of the other

**Done when:** you could alias `cat=owl -p` and not notice.

---

## Milestone 2 — TTY awareness & line numbers

**Goal:** When output goes to a terminal, show line numbers; when piped, stay plain.

- Detect whether stdout is a TTY
- Auto-switch between decorated and plain mode
- Line numbers with adaptive gutter width
- `--color <auto|always|never>`, `--paging <auto|always|never>`
- `-n` / `-N` to force numbers on/off
- File header when a file path is given (decorated mode only)
- Multiple file headers when concatenating

**Testing:**
- `owl file.txt` at prompt shows numbers
- `owl file.txt | cat` shows no numbers
- `owl a b c` shows three headers

**Done when:** the tool feels useful at the terminal and invisible in pipelines.

---

## Milestone 3 — Syntax highlighting

Split into two sub-milestones after a local-repo survey (2026-04-22)
turned up no port-ready grammar source anywhere in the AGNOS
ecosystem. Detection + theme infrastructure ships first; tokenization
follows once a grammar format is chosen.

### M3a — Detection + theme scaffolding

**Goal:** Files are classified, themes are picked, and the existing
decorations (header, gutter) are color-aware. No token-level coloring
yet — that's M3b.

- Language detection from extension and shebang (tested by detection,
  stored but not yet acted on beyond theme color of decorations)
- At least two themes shipped: one dark (default), one light
- Theme format: Cyrius-native TOML/CYML (decided 2026-04-22, overrides
  the spec's earlier "use an existing format" suggestion)
- `--language <lang>` override, `--list-languages`
- `--theme <n>`, `--list-themes`
- `NO_COLOR` environment variable respected (no ANSI emitted)
- Color disabled automatically when output is not a TTY
- `--color=always` overrides both NO_COLOR and TTY gate

**Non-goals for M3a:**
- Token-level syntax coloring (→ M3b)
- User-installable themes from config dir (→ post-v1 or M7 config)
- Content-based language detection (shebang + extension only)

**Done when:** `--list-themes` / `--list-languages` work, themes
affect visible decoration color on a TTY, NO_COLOR fully suppresses
ANSI, detected language surfaces via `--list-languages` and is
validated via `--language=<x>`.

### M3b — Token-level highlighting (deferred)

**Goal:** File *contents* render with per-token color.

- Choose grammar format (candidates: reuse `vidya`'s hand-written
  lexer pattern from `content/lexing_and_parsing/cyrius.cyr`, or
  adapt a minimal TextMate/Sublime subset, or a Cyrius-native spec)
- Bundled grammars for the starter set: shell, Python, JavaScript,
  Rust, C, Cyrius, TOML, JSON, YAML, Markdown
- Wire tokenizer output to theme palette
- `NO_COLOR=1 owl file.py` still emits zero ANSI
- Sample file per bundled language for visual regression

**Blocked on:** a grammar format decision. No pre-existing grammar
source found in AGNOS ecosystem repos as of 2026-04-22 — must
hand-author or port from an external lexer spec.

**Done when:** a developer viewing their own code says "oh, nice."

---

## Milestone 4 — Paging

**Goal:** Long output is automatically paged; pipelines are unaffected.

- Detect when output would exceed terminal height
- Spawn a pager (`OWL_PAGER` → `PAGER` → system default → `less -R`)
- Pass color-capable flags to the pager
- `--paging always` forces pager even on short output
- `--paging never` disables it
- Clean handling of pager exit (user pressing `q` doesn't leave terminal in a weird state)

**Testing:**
- Long file at prompt triggers pager
- Short file at prompt does not
- `owl big.log | grep foo` does not trigger pager
- Quitting pager mid-stream cleans up without errors

**Done when:** users stop manually piping `owl` into `less`.

---

## Milestone 5 — Non-printables & whitespace

**Goal:** `-A` and tab handling work as specified.

- `-A` / `--show-all` renders tabs, newlines, CRs, and control chars visibly
- `--tabs <n>` sets tab expansion width (default 4, 0 = literal)
- `--wrap <auto|never|character>` controls long-line handling

**Testing:**
- `owl -A` shows tab markers and line-end `$`
- `owl --tabs 2` renders tabs as two spaces
- Long-line file with `--wrap never` does not break terminal layout

**Done when:** whitespace-sensitive debugging is possible without switching tools.

---

## Milestone 6 — Git integration

**Goal:** Files inside git repos show change markers in the gutter.

- Detect whether file is tracked in a git repo
- Show `+` / `~` / `−` markers for added / modified / removed lines
- Toggle via `--style changes` or config
- Graceful no-op when git is unavailable or file is not tracked

**Testing:**
- Modified file in a repo shows markers next to the right lines
- Non-git file shows no markers, no errors, no performance penalty
- Repo with no changes renders cleanly

**Done when:** reviewing a working-copy change with `owl` is faster than `git diff`.

---

## Milestone 7 — Configuration file

**Goal:** Users can set persistent preferences.

- Read config from platform-appropriate location
- `OWL_CONFIG` overrides location
- Support theme, paging, tabs, wrap, style flags
- Precedence: defaults → config → env → CLI

**Testing:**
- Config setting theme is respected
- CLI flag overrides config
- Missing config file is a silent no-op, not an error
- Malformed config file produces a helpful error, doesn't crash

**Done when:** users stop typing the same flags every time.

---

## Milestone 8 — Polish & release candidate

**Goal:** Ready for broad use.

- Binary file detection with clear skip message
- Large-file fallback (disable highlighting past a size threshold with stderr notice)
- Startup time benchmarked and acceptable (<50ms for no-op)
- Error messages reviewed for clarity and consistency
- Full test suite covering the spec's testing checklist
- Documentation: man page, README finalized, examples in help output
- AGNOS / Cyrius packaging

**Testing:**
- Full checklist from design spec §13 passes
- Fuzz or stress tests on weird inputs (empty files, 1-byte files, files with only null bytes, files with BOMs, etc.)

**Done when:** you'd recommend it to someone without caveats.

---

## Post-v1 ideas (deferred)

Not committed, just parked here so the agent doesn't accidentally build them into v1:

- `--follow` / `-f` mode with live highlighting (tail-style)
- URL / remote file support
- User-installable grammars and themes (plugin directory)
- Content-based language detection for files without extensions
- Hex dump mode for binary files
- Integration with the AGNOS / Cyrius native theming system (if one exists)
- JSON / structured output mode for tool interop
- Shell completion scripts (bash, zsh, fish, and any AGNOS-native shell)
- Localization of error messages

---

## Decision log

Keep a running list here as questions get answered during implementation:

| Date | Question | Decision | Rationale |
|------|----------|----------|-----------|
| — | Config file format? | TBD | Pending platform convention check |
| — | Default pager on AGNOS/Cyrius? | TBD | Depends on what ships with the OS |
| — | Theme format: reuse existing (e.g. TextMate/Sublime) or custom? | TBD | Reuse if practical — grammar ecosystems exist |
| — | Native theming integration? | Deferred to post-v1 | Keeps v1 portable |

---

## Risk & mitigation

| Risk | Mitigation |
|------|------------|
| Syntax highlighting turns out to be the biggest chunk of work | Land plain mode (M1) and line numbers (M2) first — both are independently useful |
| Pager integration is finicky on AGNOS/Cyrius | Ship `--paging never` as a reliable fallback; treat paging as a convenience, not a core feature |
| Scope creep from users wanting `--follow`, search, etc. | Keep the "post-v1" list visible; be firm about what's in v1 |
| Platform-specific quirks (TTY detection, signal handling) | Write abstraction layer early in M1; test on real hardware, not just emulators |

---

*End of roadmap.*
