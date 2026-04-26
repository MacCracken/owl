# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

_No unreleased changes._

## [1.1.6] — 2026-04-26

Documentation polish + toolchain bump. Single-issue patch.

### Changed

- **`--line-range` help now calls out the head/tail idiom.** Field
  notes from cyrius-bb dogfooding flagged that users coming from
  `head(1)` muscle memory don't immediately connect the open-ended
  `:N` form with "first N lines". The help line for `--line-range`
  now carries an inline hint: `head -n N idiom: --line-range=:N`.
  No behavior change — the flag itself is unchanged
  (`src/main.cyr`, `print_help`).

- **Toolchain pin bumped to cyrius 5.7.7.** `cyrius.cyml`,
  `--verbose` banner, `CONTRIBUTING.md`, and `README.md` install
  step all updated. No source changes required for the bump.

## [1.1.5] — 2026-04-26

Pager-spawn correctness fix. Single-issue patch.

### Fixed

- **Pager spawn now forwards the parent environment.** The child
  process previously received only `PATH=/usr/local/bin:/usr/bin:/bin`,
  so `less` could not init terminfo (no `TERM`), printed
  `'unknown': I need something more specific.` to stderr and exited.
  Owl was then mid-write into the dead pipe and got `SIGPIPE` →
  `exit 141`, surfacing as a broken `owl <file>` on a TTY in any
  shell where `TERM` was the only thing the child needed. `pager.cyr`
  now reads `/proc/self/environ` in the child and rebuilds `envp`
  from it (TERM, HOME, LANG, LESS, COLORTERM, … all flow through).
  Falls back to the previous PATH-only behavior if
  `/proc/self/environ` is unreadable, so containers without `/proc`
  do not regress. Pager values still flow through `/bin/sh -c`
  exactly as before — no new shell-injection surface.

  Smoke gate added: spawned pager must capture the parent's `TERM`.

### Notes

- DCE binary: 211,800 bytes (~207 KB; was ~193 KB at 1.1.4 — +14 KB
  from the env-forward loop and 16 KiB stack envbuf).
- `src/pager.cyr`: 114 → 147 lines.

## [1.1.4] — 2026-04-25

Smarter detection + diff mode. Two contained features.

### Added

- **Content-based language detection.** Post-shebang fallback in
  `render_path` for files with no extension and no shebang. Conservative
  high-confidence patterns only:

  | Opening bytes        | Language   |
  |----------------------|------------|
  | `{` or `[` (non-alpha next) | `json`     |
  | `[<alpha>...]`       | `toml`     |
  | `---` at file start  | `yaml`     |
  | `# ` or `## `        | `markdown` |

  Programming languages (rust, python, c, etc.) are intentionally
  excluded — false-positive risk on plain text is too high for the
  payoff. The detection chain is now: extension → shebang → content
  → "plain".

- **`--diff` mode.** Filter rendered output to lines with VCS markers
  (ADD/MOD only; DEL has no surviving line in the file). Composes
  cleanly with `--line-range` and `-n`. Forces VCS computation even
  when stdout is piped (`vcs_enabled()` honors the flag), so
  `owl --diff file > changed-lines.txt` works the same in a pipeline
  as in a TTY. Files outside any git repo or with no changes emit an
  empty diff (silent, no stderr). The gutter `+`/`~`/`-` markers from
  the existing VCS layer make the changes visually obvious when `-n`
  is also set.

## [1.1.3] — 2026-04-25

Content fallbacks drop. Three contained features; no architectural
changes.

### Added

- **`--hex` / `-x` and binary auto-fallback.** `owl --hex <file>`
  emits an `xxd`-style dump (`OFFSET  16 hex bytes  |ASCII|`) on
  any file, text or binary. Binary files (NUL-byte detection in
  the first chunk) now hex-dump automatically instead of emitting
  the pre-1.1.3 `binary file (use -p to dump)` skip-notice — exit
  code is 0 with content on stdout. Plain mode (`-p`) still
  byte-streams binary verbatim (cat-parity is sacred).
- **User-installable grammars.** Drop a `.cyml` grammar file at
  `$XDG_CONFIG_HOME/owl/grammars/<name>.cyml` (or
  `~/.config/owl/grammars/<name>.cyml`) to override the bundled
  grammar of the same name. Override-only scope for v1: extending
  the language list (e.g. adding `elixir`) requires a vyakarana PR
  and an entry in `lang.cyr`. User overlay is loaded BEFORE
  bundled, so vyakarana's first-match registry returns the user
  version. Up to the 11 bundled grammar names are eligible for
  override.
- **User-installable themes.** `--theme=<name>` lazy-loads
  `$XDG_CONFIG_HOME/owl/themes/<name>.cyml` (or
  `~/.config/owl/themes/<name>.cyml`) when `<name>` doesn't match
  a bundled theme. Format is flat CYML:

  ```cyml
  # ~/.config/owl/themes/neon.cyml
  header_color = 201
  lineno_color = 240
  token.keyword = 207     # 256-color ANSI index; -1 = terminal default
  token.string  = 154
  token.number  = 220
  token.comment = 247
  vcs.add = 154
  vcs.mod = 220
  vcs.del = 196
  ```

  Single-slot scope for v1: only one user theme can be loaded per
  invocation (the one named via `--theme=`). Bundled themes still
  take priority on name collision. User themes do not appear in
  `--list-themes` (no startup dir-scan).

### Changed

- **Mixed-file partial-failure on binary input is gone.** Pre-1.1.3,
  `owl text.txt binary.bin text2.txt` exited 1 (partial) with the
  binary file skipped. Now all three render — binary inline as hex
  — and the run exits 0. The corresponding smoke gate
  (`mixed-with-binary`) was updated to assert the new shape.

## [1.1.2] — 2026-04-25

### Fixed

- **Bundled grammars now resolve via `/proc/self/exe` instead of
  cwd.** Prior to 1.1.2 the binary loaded grammars from the literal
  relative path `grammars/<name>.cyml`, so `--color=always` produced
  zero ANSI bytes when owl was invoked from any cwd that didn't
  happen to contain a `grammars/` subdirectory (cyrius repo, `$HOME`,
  `/tmp`, end-user project trees). The cyrius v5.6.45 ticket — which
  routes Claude Code's `Read(**/*.cyr)` through `Bash(owl …)` from
  the cyrius repo cwd — was the public-facing symptom.

  owl now resolves the grammars directory at first highlight need:
  `<exe-dir>/grammars/` first (installed-adjacent layout), then
  `<exe-dir>/../grammars/` (covers the dev workflow where `build/owl`
  sits next to `./grammars/`), with cwd-relative as a final fallback
  for pre-1.1.2 muscle memory. Probe is `cyrius.cyml`; on success,
  every bundled grammar pre-loads via absolute paths and vyakarana's
  lazy relative-path bootstrap is bypassed.

  The 1.1.0 stdin highlight fix was structurally correct but did not
  close the cyrius v5.6.45 ticket on its own — see the
  2026-04-25 amendment in
  [`docs/adr/0007-stdin-syntax-highlighting.md`](docs/adr/0007-stdin-syntax-highlighting.md).

## [1.1.1] — 2026-04-25

Ergonomics drop. Five small, contained CLI improvements; no
architectural changes.

### Added

- **`--version --verbose` / `-v`** — adds `vyakarana <tag>`,
  `cyrius <pin>`, and `target linux-x86_64` lines under the version
  string. Useful for bug reports; would have helped diagnose the
  cyrius v5.6.45 ticket. Order-independent (`--verbose --version`
  produces the same output).
- **`--strip-ansi=auto|always|never`** — `less -R`-style alias of
  `-r` / default. `never` matches `-r` (passthrough). `always`
  forces strip even with `-r` set. `auto` is the existing default
  (strip in decorated/colored output, passthrough otherwise). Plain
  mode (`-p`) remains byte-identical to `cat` regardless — `always`
  does not violate cat-parity.
- **`--line-range=A:B`** — print only lines A..B (1-indexed,
  inclusive). Either side may be open: `A:` prints from A to EOF,
  `:B` prints lines 1..B, `A` (no colon) prints just line A.
  Applies in plain (opt-in transform), decorated, and highlight
  paths. Render short-circuits after the end line — no extra reads.
- **Per-language extension override** — `ext.<extension> = <language>`
  in `~/.config/owl/config.cyml` remaps a file extension to a
  bundled language (e.g. `ext.conf = shell` colorizes `.conf` files
  as shell). Up to 16 entries. Consulted before the built-in
  extension table; bad language name reports `bad value` to stderr
  and continues.
- **`--wrap=character`** — hard-wrap output at terminal width
  (TIOCGWINSZ on stdout; default 80 cols when piped). Counts UTF-8
  codepoints (continuation bytes don't increment the column), so
  multi-byte chars stay intact across wraps. Plain mode (`-p`)
  preserves cat-parity — `--wrap=character` is a no-op there.

## [1.1.0] — 2026-04-25

### Changed

- **Toolchain pin** — bumped `cyrius.cyml [package].cyrius` from
  `5.6.0` to `5.6.44`. Pulls in the v5.6.34 `alloc(>1MB)`-near-brk
  SIGSEGV fix (`lib/alloc.cyr` rounds the new heap end up to a 1MB
  boundary covering `_heap_ptr` instead of stepping by exactly
  `0x100000`). Relevant for the new stdin-slurp path, which can
  alloc `HIGHLIGHT_MAX + 1` (~128 KB) into a bump arena that already
  holds a tokenbuf and ANSI-inflated output buffer.
- **Vendored deps no longer tracked.** `lib/` is now fully gitignored
  (yukti style); `cyrius deps` regenerates it from `cyrius.cyml`
  `[deps]` on demand. Removes 70 tracked stdlib files (only 14 of
  which were actually used — the rest were vestigial scaffolding
  bloat) and ensures the vendored copy always matches the manifest
  pin. Run `cyrius deps` after a fresh checkout.

### Fixed

- **stdin syntax highlighting** — `owl --color=always --language=<lang>`
  now applies token-level color when reading from stdin (`owl -` and
  bare-`owl` with piped input), matching the file-path behavior. Prior
  to 1.1.0 the stdin path went straight to `render_chunk` and ignored
  `--language` for highlighting purposes, so consumers piping owl
  (Claude Code's `Read` routing, scripted log capture, `script(1)`
  sessions) saw plain text even with explicit color + language flags.
  Slurp-then-tokenize mirrors the file-path branch: stdin is buffered
  up to `HIGHLIGHT_MAX` (128 KB), tokenized once, then byte-emitted
  with per-token color. Inputs that exceed the cap fall through to
  streaming `render_chunk` with the same stderr fallback notice
  `render_path` emits. Stdin without `--language` stays plain — there
  is no extension or path to detect from.

## [1.0.0] — 2026-04-23

First stable release. M0 through M8 shipped; full owl attack surface
audited and hardened. `-p` mode is a byte-identical drop-in for
`cat`; decorated mode adds token-highlighting via
[vyakarana](https://github.com/MacCracken/vyakarana), line-number
gutter with VCS change markers, auto-paging, and non-printable glyph
rendering.

### Security

All four OPEN findings from
[docs/audit/2026-04-23-audit.md](docs/audit/2026-04-23-audit.md)
closed in this release:

- **FINDING-001 (HIGH)** — file-origin terminal escapes are now
  stripped in decorated/colored output via a 5-state byte-level
  classifier (`g_esc_state` / `_emit_file_byte`). Closes the
  OSC-52 clipboard, title-report RCE, DA/DSR-reply, and iTerm2
  OSC-1337 attack classes. New `-r` / `--raw-control-chars` flag
  restores cat-like passthrough for users viewing trusted ANSI
  output. Precedent: CVE-2019-9535 (iTerm2), CVE-2024-32487 (less
  OSC 8), CVE-2003-0063 (xterm DECRQSS — the canonical ancestor).
- **FINDING-002 (MEDIUM)** — new `eprint_sanitized` helper
  replaces C0 control bytes and DEL with `?` on every stderr path
  that echoes user-supplied strings (`report_error`, the
  large-file fallback notice, `_cfg_err`). UTF-8 passes through.
- **FINDING-003 (MEDIUM)** — VCS markers now fork+`execve` `git
  diff` with explicit argv instead of `/bin/sh -c`. Kernel-enforced
  argv boundaries eliminate the shell-injection class entirely.
  Precedent: CVE-2022-46663 (less `LESSOPEN` metachar injection).
- **FINDING-004 (LOW)** — `waitpid` status buffers sized at 8
  bytes (were declared `var buf[1]` — 3-byte overrun of adjacent
  bump arena).
- **FINDING-005 (LOW)** — subsumed by 003. Paths containing `'`,
  `$`, spaces, or any other shell-meaningful character now render
  with VCS markers correctly.

### Added (M8)

- **M8a** — binary file detection (NUL-byte scan of first chunk;
  skip with `owl: <path>: binary file (use -p to dump)`; bypassed
  by `-p`, `-A`, `--language`); large-file highlight fallback
  notice emitted to stderr when `HIGHLIGHT_MAX` (128 KB) is
  exceeded; weird-input robustness (empty, 1-byte, no trailing
  newline, UTF-8 BOM).
- **M8b** — error-surface consistency sweep; startup bench
  verifies `--version` at 1–2 ms, tiny-file highlight at 2 ms
  (25× under the 50 ms no-op target from the spec).
- **M8c** — security hardening (see Security section).

### Added (M7)

- `src/config.cyr` — minimal `key = value` parser (no new stdlib
  dep). Keys: `theme`, `paging`, `style`, `tabs`, `wrap`.
- Config location (first hit wins): `$OWL_CONFIG` →
  `$XDG_CONFIG_HOME/owl/config.cyml` →
  `$HOME/.config/owl/config.cyml`.
- Precedence: defaults → config → env → CLI.
- Per-line parse errors emit
  `owl: <path>:<line>: <reason>` and keep loading.

### Added (M6)

- `src/vcs.cyr` — VCS change markers for the line-number gutter.
- `+` / `~` / `−` markers for added / modified / deleted lines
  with theme-aware color (`theme_change_color`).
- `--style=auto | changes | no-changes` flag; default auto (on
  when decorated and in a repo).
- Git-specific code confined to this module — swap to SIT when
  that ships is a single-file rewrite.

### Added (M5)

- `-A` / `--show-all` renders tabs as `→`, EOL as `$`, CR as `␍`,
  other controls as `^X` / `^?`.
- `--tabs=<n>` controls tab expansion width (default 4, 0 =
  literal `\t`).
- `--wrap=<auto | never | character>` parsed for spec parity
  (character wrap needs `TIOCGWINSZ`, deferred to post-v1).

### Added (M4)

- `src/pager.cyr` — auto-paging via `OWL_PAGER` →
  `PAGER` → `less -RFX`.
- `--paging=<auto | always | never>` flag.

### Added (M3)

- **M3a** — language detection from extension and shebang;
  dark + light bundled themes; `--language`, `--list-languages`,
  `--theme`, `--list-themes`, `NO_COLOR`, `--color=<when>`.
- **M3b** — token-level syntax highlighting via
  `[deps.vyakarana]` (1.0.2, git-tag pinned, vendored to
  `lib/vyakarana.cyr` by `cyrius deps`). Eleven bundled grammars
  ship as CYML: shell, python, javascript, typescript, rust, c,
  cyrius, toml, json, yaml, markdown. `HIGHLIGHT_MAX = 128 KB`
  ceiling; larger files fall back to plain streaming.
- Fixed `ansi_reset` to emit bytes explicitly — Cyrius string
  literals don't parse `\x??` hex escapes.

### Added (M2)

- Line-number gutter with theme-aware color.
- `-n` / `-N` to force numbers on/off.
- File header emitted in decorated mode; detected language
  surfaced next to the filename.
- TTY detection via `ioctl(TCGETS)` (not `fstat+S_IFCHR` — the
  latter matched `/dev/null` and mis-triggered the pager).

### Added (M1)

- Read one or more files, mix with stdin (`-` or implicit when
  no files given).
- Clean SIGPIPE handling (`owl big.log | head` exits 0 without
  "broken pipe" stderr leak).
- Exit codes per design spec §9: 0 success, 1 partial, 2 usage,
  4 all-fail.
- Error format `owl: <path>: <reason>` — matches classic Unix
  utilities.

### Added (M0)

- Initial project scaffold: `src/main.cyr`, `tests/owl.tcyr`,
  `scripts/smoke.sh`, `cyrius.cyml`, `README.md`, `LICENSE`
  (GPL-3.0-only).
- `owl --version` / `owl --help`; bare `owl` with TTY stdin
  prints help.

### Infrastructure

- `scripts/smoke.sh` gates M0 → M8 behavior end-to-end, including
  security hardening (ESC-in-path, OSC-52 strip, argv-git).
- `tests/owl.tcyr` — 7 unit assertions.
- `docs/audit/2026-04-23-audit.md` — full scaffold-hardening
  audit with class CVE references.
- `CLAUDE.md` — rewritten against agnosticos `example_claude.md`
  template.
- Startup: 1–2 ms cold run; 153 KB binary (DCE parity).

## [0.1.0]

Initial project scaffold — see `[1.0.0]` section above for the
development arc.
