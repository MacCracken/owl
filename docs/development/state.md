# owl — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). Add release-hook wiring
> when the repo's release workflow lands.

## Version

**1.1.8** — shipped 2026-04-27. Frame containment. `--wrap=auto`
(default) now wraps content when the decorated frame is active so
long lines stay inside the bottom rule; wrap-injected breaks emit a
continuation gutter (blank lineno + `│ ` in `lineno_color`) so
wrapped text aligns under the divider. Highlighting survives wrap
via `g_render_active_color` save/restore around the gutter. `--wrap=
never` is the explicit overflow escape hatch (was effectively the
pre-1.1.8 default); `--wrap=character` is unchanged. Plain mode
(`-p`) and piped non-`-n` output still byte-identical to `cat`.

**1.1.7** — shipped 2026-04-27. Header aesthetic refresh + toolchain
bump to cyrius 5.7.12. The single `─── File: <path> ─` ribbon is
replaced with a bat-style three-rule frame (top `┬`, header line `│ File: <path> (<lang>)`, middle `┼`,
file body, bottom `┴`). Rules span the actual terminal width via
`TIOCGWINSZ` on stdout (80-col fallback) and the junction column
tracks the gutter divider position (7 without VCS markers, 9 with).
Rules render in `lineno_color`; the "File:" label keeps
`header_color`. New `emit_footer()` pairs with `emit_header()` via
a `g_header_open` flag so every render path (plain, highlighted,
hex, binary auto-fallback) emits a matching bottom rule. Plain mode
(`-p`) stays byte-identical to `cat` — the frame is decorated-mode
only.

**1.1.6** — shipped 2026-04-26. Documentation polish + toolchain
bump. `--line-range` help line now carries an inline
`head -n N idiom: --line-range=:N` hint (cyrius-bb dogfood feedback —
users coming from `head(1)` muscle memory weren't connecting the
open-ended `:N` form with "first N lines"). No flag behavior change.
Toolchain pin moved to cyrius 5.7.7.

**1.1.5** — shipped 2026-04-26. Pager-spawn correctness fix.
`pager.cyr` now forwards `/proc/self/environ` to the pager child
instead of only `PATH`. Without this, `less` had no `TERM` and
exited at terminfo init (`'unknown': I need something more specific.`),
SIGPIPE'd owl mid-write, and any TTY-mode `owl <file>` exited 141.
Falls back to the prior PATH-only envp if `/proc/self/environ` is
unreadable. Smoke gate locks in the regression: spawned pager must
inherit parent `TERM`.

**1.1.4** — shipped 2026-04-25. Smarter detection + diff mode:
content-based language detection as a third-pass fallback for files
with no extension and no shebang (`{`/`[`→json, `[name]`→toml,
`---`→yaml, `# `→markdown); `--diff` filters rendered output to
lines with VCS ADD/MOD markers, forces VCS computation even when
piped, composes with `--line-range` and `-n`.

**1.1.3** — shipped 2026-04-25. Content fallbacks drop:
`--hex`/`-x` flag plus auto hex-dump for binary files (replaces the
pre-1.1.3 skip-notice); user-installable grammars
(`$XDG_CONFIG_HOME/owl/grammars/<name>.cyml` overrides bundled by
name); user-installable themes (`$XDG_CONFIG_HOME/owl/themes/<name>.cyml`
lazy-loaded via `--theme=<name>` when the name doesn't match bundled).

**1.1.2** — shipped 2026-04-25. Bundled grammars now resolve via
`/proc/self/exe` instead of cwd-relative `grammars/<name>.cyml`. Prior
versions silently produced zero ANSI bytes when invoked from any cwd
without a `grammars/` subdirectory (cyrius v5.6.45 ticket). Resolution
order: `<exe-dir>/grammars/` → `<exe-dir>/../grammars/` (dev: `build/owl`
+ sibling `./grammars/`) → cwd-relative legacy fallback. Smoke gate
locked to `fail()` from this version forward.

**1.1.1** — shipped 2026-04-25. Ergonomics drop: `--version --verbose`
prints vyakarana + cyrius pins; `--strip-ansi=auto|always|never`
aliases `-r`; `--line-range=A:B` filters output to a 1-indexed
inclusive range across plain/decorated/highlight paths;
`ext.<extension> = <language>` config keys remap extensions to
bundled languages (max 16 overrides); `--wrap=character` hard-wraps
at terminal width (TIOCGWINSZ on stdout, 80-col default when piped),
UTF-8-aware.

**1.1.0** — shipped 2026-04-25. Stdin syntax highlighting: `owl -` and
bare-`owl` with piped input now apply token color when `--color=always`
and `--language=<lang>` are set, mirroring the file-path branch.
Slurp-then-tokenize up to `HIGHLIGHT_MAX`; streaming fallback on
overflow with the same stderr notice `render_path` emits.

**1.0.0** — shipped 2026-04-23. First stable release. M0 through M8
complete; full owl attack surface audited and hardened.

## Toolchain

- **Cyrius pin**: `5.7.12` (in `cyrius.cyml [package].cyrius`)

## Binary

- ~209 KB (213,776 bytes; DCE and non-DCE identical, `build/owl`)
- +744 bytes vs 1.1.7 — `_emit_wrap_break` continuation-gutter
  helper, wrap-resolution refactor in `resolve_mode`, and
  `g_render_active_color` plumbing through `render_highlighted_buf`
- Startup targets: `owl --version` 1–2 ms, tiny-file highlight 2 ms
  (25× under the 50 ms no-op target in `docs/design-spec.md`)

## Source

- ~3,490 lines across 6 modules:
  - `src/main.cyr` (~1,920) — entry, CLI, render dispatch, TTY/mode resolution, exe-relative grammar lookup, hex-dump, --diff, bat-style header frame (1.1.7), wrap-continuation gutter (1.1.8)
  - `src/theme.cyr` (~431) — bundled themes, 10-kind palette, ANSI emission, user-theme loader (1.1.3)
  - `src/lang.cyr` (~371) — extension/shebang/content detection + ext-override table
  - `src/vcs.cyr` (~328) — git VCS markers (M6) + --diff bypass for piped output
  - `src/config.cyr` (~298) — `key = value` config parser (M7) + `ext.*` keys (1.1.1)
  - `src/pager.cyr` (~147) — pager spawn + SIGPIPE handling + env forward (1.1.5)

## Tests

- `tests/owl.tcyr` — unit assertions
- `scripts/smoke.sh` — end-to-end behavioral gates (M0 → M8)
- `tests/owl.bcyr` — benchmark slot (reserved)
- `tests/owl.fcyr` — fuzz slot (reserved)

## Dependencies

- **Cyrius stdlib** — `syscalls`, `alloc`, `fmt`, `io`, `fs`, `str`, `string`, `vec`, `args`, `hashmap`, `process`, `tagged`, `assert`
- **vyakarana** 1.0.2 — tokenizer + 11 bundled grammars (git-tag pinned in `[deps.vyakarana]`)

No FFI. No third-party deps beyond vyakarana.

## Consumers

- End users — primary; `owl` is a CLI tool
- [agnoshi](https://github.com/MacCracken/agnoshi) — invokes owl for file viewing in-shell

## Security

1.0.0 closed all findings from
[`docs/audit/2026-04-23-audit.md`](../audit/2026-04-23-audit.md):

| Finding | Severity | Fix | CVE precedent |
|---------|----------|-----|---------------|
| 001 | HIGH   | 5-state byte-level escape classifier strips file-origin terminal escapes in decorated/colored output; new `-r` / `--raw-control-chars` restores cat-like passthrough for trusted ANSI input | CVE-2019-9535 (iTerm2 OSC-52), CVE-2024-32487 (less OSC 8), CVE-2003-0063 (xterm DECRQSS) |
| 002 | MEDIUM | `eprint_sanitized` helper replaces C0 + DEL with `?` on every stderr path echoing user-supplied strings; UTF-8 passes through | — |
| 003 | MEDIUM | VCS markers fork+`execve` `git diff` with explicit argv; kernel-enforced argv boundaries close the shell-injection class | CVE-2022-46663 (less `LESSOPEN` metachar injection) |
| 004 | LOW    | `waitpid` status buffers sized at 8 bytes (were `var buf[1]` — 3-byte overrun into adjacent bump arena) | — |
| 005 | —      | Subsumed by 003. Paths with `'`, `$`, spaces, or shell-meaningful bytes render correctly under VCS markers | — |

## Verification

- `cyrius build src/main.cyr build/owl` — clean
- `cyrius test` — all `.tcyr` green
- `sh scripts/smoke.sh` — all M0–M8 behavioral gates green

## Next

Post-v1 work: M7 may add a formal CYML parser from stdlib when `cyml` lands,
and M9+ will broaden grammar coverage via vyakarana's CYML loader (M2).
1.x backlog (per `roadmap.md` in this directory): hex-dump fallback for
binary files, user-installable grammars/themes, content-based language
detection, `--diff` mode.
