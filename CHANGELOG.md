# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

_No unreleased changes._

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
