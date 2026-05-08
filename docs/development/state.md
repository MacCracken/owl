# owl — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). Add release-hook wiring
> when the repo's release workflow lands.

## Version

**1.3.0** — shipped 2026-05-08. Toolchain refresh + vyakarana
1.8.0 → 1.11.0 cascade in one cut. Cyrius pin moves 5.9.41 →
5.9.43. vyakarana 1.9.0 brings two new grammars (`cyml`,
`llvm_ir`) and redirects `.cyml` from `toml` to the new `cyml`
grammar — `LANG_COUNT` 36 → 38, `lang_exts(8)` drops `.cyml`,
header label moves from `(toml)` to `(cyml)` for cyrius
dependency manifests (regression-locked in smoke). vyakarana
1.10.0's "architecture note 004" theme-palette contract
(kind_name strings = stable identifier) is honoured by
refactoring `theme_token_color` to dispatch via
`kind_name(k)` string lookup. vyakarana 1.11.0's LSP
semantic-tokens bridge is editor-consumer surface; ships in the
dep bundle but unused by owl's viewer path (DCE-strips cleanly).
Single minor bump — the 1.10.0 / 1.11.0 dep bumps that carry no
owl source changes ride along rather than burning their own
patch slots.

**1.2.6** — shipped 2026-05-08. End of the 1.2.x lockstep
cascade with vyakarana 1.2.x → 1.8.x. `LANG_COUNT` 13 → 36;
36 bundled grammars now resolve via both the user-overlay
(`$XDG_CONFIG_HOME/owl/grammars/`) and exe-relative paths.
Closes the "Further bundled-grammar broadening" 2.x backlog
item. Toolchain pins moved together: cyrius 5.9.36 → 5.9.41,
vyakarana 1.2.0 → 1.8.0. New filename-shape detection
(`_path_filename_match` in `src/lang.cyr`) handles Dockerfile
and Makefile, which carry no conventional extension. The 1.2.x
patch series is shipped as one drop:

- 1.2.0 — cyrius 5.9.41 + vyakarana 1.2.0 → 1.2.4 closeout
  (asm_x86_64, asm_aarch64).
- 1.2.1 — vyakarana 1.3.0 (java, kotlin, cpp, csharp).
- 1.2.2 — vyakarana 1.4.0 (php, ruby, lua, swift).
- 1.2.3 — vyakarana 1.5.0 (elixir, ocaml, haskell).
- 1.2.4 — vyakarana 1.6.0 (sql, graphql, protobuf).
- 1.2.5 — vyakarana 1.7.0 (html, xml, css, scss).
- 1.2.6 — vyakarana 1.8.0 (dockerfile, makefile, ini).

**1.1.12** — shipped 2026-05-08. vyakarana 1.2.0 dependency bump
adds Go and Zig highlighting. `LANG_COUNT` 11 → 13 (`lang_name(11)
= "go"` / `.go`, `lang_name(12) = "zig"` / `.zig`); `bootstrap_grammars`
in `src/main.cyr` loads `go.cyml` and `zig.cyml` from both the user
overlay path and the exe-relative bundle. `grammars/go.cyml` and
`grammars/zig.cyml` synced from vyakarana 1.2.0. `--list-languages`
now reports 13 entries. Smoke gates lock `.go` → `(go)` /
`.zig` → `(zig)` extension detection and ANSI emission for both
under `--color=always --language=…` from stdin. Cyrius pin
unchanged at 5.9.36.

**1.1.11** — shipped 2026-05-08. Last 1.x polish item closed:
exact-gutter wrap math. Pre-1.1.11 owl always subtracted the VCS-on
(11-col) gutter when computing the wrap budget, even when
`--style=no-changes` left the marker cell off and the gutter was
only 9 cols wide; wrapped content stopped 2 cols short of the right
rule. New `g_wrap_term_cols` cache + `_recompute_wrap_cols()` helper
pick the gutter width from `vcs_enabled()` (9 when 0, 11 when 1) and
re-resolve the budget after every `vcs_compute_markers(path)`.
Default-style behavior unchanged (the marker cell is always in play
in decorated mode). Smoke gates lock both the new exact-fit budget
and the unchanged default-style boundary.

**1.1.10** — shipped 2026-05-08. Toolchain + tokenizer-dep refresh.
Cyrius pin moves from 5.7.12 → 5.9.36 (four `5.9.x` minor slots'
worth of compiler-internal fixes; nothing owl exercises broke).
vyakarana pin moves from 1.0.2 → 1.1.0; the public tokenizer API is
unchanged but bundled grammars gain `unicode_ident` for C and
Markdown, `$`-prefixed Rust macro metavariables (`$expr`, `$tok`),
and TOML triple-quoted (`"""`, `'''`) string forms. No source
changes outside the version-banner triple. `HIGHLIGHT_MAX` cap is
not yet liftable — vyakarana 1.1.0 ships grammar polish, not the
streaming tokenizer that gates that work.

**1.1.9** — shipped 2026-04-27. Wrap-arrow polish. Wrap-continuation
gutter switched from `│` (which matched the line divider and made
stacked wrapped rows visually ambiguous against new file lines) to
`↪` (U+21AA, bat's convention). `│` now means "start of a new file
line"; `↪` means "continuation of the previous line", so a wrapped
paragraph reads as one logical line at a glance.

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

- **Cyrius pin**: `5.9.43` (in `cyrius.cyml [package].cyrius`)
  — bumped from `5.9.41` at 1.3.0 (2026-05-08). No source changes
  required.
- **vyakarana pin**: `1.11.0` (in `cyrius.cyml [deps.vyakarana].tag`)
  — bumped from `1.8.0` at 1.3.0. Public tokenizer API unchanged
  across the full 1.8.0 → 1.11.0 window. 1.9.0 wires two new
  grammars (`cyml`, `llvm_ir`) into owl's language table and
  bootstrap; `.cyml` redirects from `toml` to the new `cyml`
  grammar. 1.10.0 documents the kind_name → palette contract
  (architecture note 004) which owl now conforms to in
  `theme.cyr`. 1.11.0 adds a `src/lsp.cyr` semantic-tokens
  bridge; useful for editor consumers (cyim), unused by owl's
  viewer path.

## Binary

- ~233 KB (238,944 bytes, `build/owl`, DCE). +3,664 bytes vs
  1.2.6's 235,280 — almost all of it the 2 new grammar tables
  (cyml, llvm_ir) compiled into vyakarana 1.11.0's
  `dist/vyakarana.cyr`. vyakarana 1.11.0's LSP bridge module
  (`lsp_kind_from_token_type`, `lsp_kind_from_standard_index`)
  ships in `[lib] modules` but DCE-strips cleanly on owl since
  unused — confirmed in build output. owl-side growth: +4 lines
  in `src/main.cyr` (bootstrap calls in user-overlay + bundled
  paths) and +4 lines in `src/lang.cyr` (lang_name + lang_exts
  entries for cyml + llvm_ir). The `theme.cyr` kind_name
  refactor is size-neutral.
- DCE and non-DCE builds are the same size but **not
  byte-identical** under cyrius 5.9.x: DCE NOPs out dead-code
  spans where the 5.7.x DCE was a no-op for owl's call graph.
  Section layout and total size are stable.
- Startup targets: `owl --version` 1–2 ms, tiny-file highlight 2 ms
  (25× under the 50 ms no-op target in `docs/design-spec.md`).
  Bootstrap of 36 grammars at first-token-color path costs
  marginally more than 13; first-byte plain-mode path is
  unaffected (grammars are loaded lazily on first highlight).

## Source

- ~3,625 lines across 6 modules (1.3.0 cut):
  - `src/main.cyr` (~2,011) — entry, CLI, render dispatch, TTY/mode resolution, exe-relative grammar lookup, hex-dump, --diff, bat-style header frame (1.1.7), wrap-continuation gutter (1.1.8), `↪` wrap-arrow glyph (1.1.9), version-banner pin sync (1.1.10), VCS-aware wrap budget (1.1.11), go/zig grammar bootstrap (1.1.12), 23-grammar bootstrap cascade (1.2.0–1.2.6), cyml/llvm_ir bootstrap (1.3.0)
  - `src/theme.cyr` (~437) — bundled themes, 10-kind palette, ANSI emission, user-theme loader (1.1.3); kind_name-keyed `theme_token_color` per vyakarana 1.10.0 architecture note 004 (1.3.0)
  - `src/lang.cyr` (~432) — extension/shebang/content detection + ext-override table + filename-shape detection (1.2.6); LANG_COUNT 38 (1.3.0 added cyml/llvm_ir + redirected `.cyml` from toml → cyml per vyakarana 1.9.0)
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
- **vyakarana** 1.11.0 — tokenizer + 38 bundled grammars (git-tag pinned in `[deps.vyakarana]`). 1.2.0 → 1.8.0 cascade picked up 23 grammars across six minor bumps (see 1.2.6 entry above for the breakdown). 1.9.0 added cyml + llvm_ir (the AGNOS-native batch — owl now self-hosts on its own `cyrius.cyml` rendering). 1.10.0 added a `vyk --theme=` CLI flag (CLI-only, not in `[lib]` modules — owl's CLI is unaffected) plus architecture note 004 (theme-palette contract owl now honours via `kind_name(k)`-string dispatch). 1.11.0 added a `src/lsp.cyr` semantic-tokens bridge for editor consumers (cyim et al.) — ships in `[lib] modules`, DCE-strips on owl since unused.

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

The 1.x line has nothing left to ship — 1.1.11 closed the last
parked polish item (exact-gutter wrap math), and 1.2.0 → 1.2.6
closed the "Further bundled-grammar broadening" 2.x backlog
item that was the only language-side parked work. See
[`roadmap.md`](roadmap.md) for the forward list. Major work is
2.x, gated on external dependencies: SIT VCS swap, vyakarana
streaming tokenizer (lifts the `HIGHLIGHT_MAX` cap), `--follow`,
URL fetching, NDJSON output, AGNOS theming integration.

vyakarana 1.8.0 closes the "broaden the bundled grammar set" line
of work — the palette now covers JVM (java/kotlin), C-family
(cpp/csharp), scripting (php/ruby/lua), mobile (swift),
functional (elixir/ocaml/haskell), data/IDL (sql/graphql/
protobuf), markup/styling (html/xml/css/scss), DevOps
(dockerfile/makefile/ini), and assembly (asm_x86_64/
asm_aarch64) on top of the original starter set. Streaming
tokenizer is still **not** on vyakarana's near-term list, so the
`HIGHLIGHT_MAX`-lift item stays parked until at least vyakarana
2.x. Future vyakarana grammar drops will need the same
two-line wiring owl applied here: a `lang_name` / `lang_exts`
entry in `src/lang.cyr` plus matching `_owl_load_grammar` calls
in `bootstrap_grammars`. Filename-shape grammars (no extension)
additionally need a line in `detect_language_from_path` per the
1.2.6 dockerfile/makefile pattern.

Stdlib follow-ups: M7's `key = value` parser will swap to a formal
CYML parser when `cyml` lands in stdlib.
