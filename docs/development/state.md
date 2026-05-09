# owl — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). Add release-hook wiring
> when the repo's release workflow lands.

## Version

**1.3.6** — shipped 2026-05-09. **Closes the 1.3.x catchup
window.** Lifts `HIGHLIGHT_MAX` from 128 KB to 16 MB by
hoisting the streaming-tokenizer lifecycle out of
`render_highlighted_buf` and into the slurp callers in
`render_fd` (stdin) and `render_path` (file). The read loop
feeds each `file_read` chunk to vyakarana incrementally, so
scanner state stays bounded by the live in-progress span
(vyakarana 2.0.1's rolling-buffer cap) rather than total
input. `render_highlighted_buf` split into a one-shot wrapper
+ a new internal `_render_highlighted_with_tb(buf, n, tb)`
that takes a pre-populated tokenbuf. Files between 128 KB and
16 MB now highlight cleanly; previously fell back to plain
rendering. No toolchain pin movement; still cyrius 5.10.10 +
vyakarana 2.2.1. The 1.3.x window started with the surgical
2.x migration (1.3.1) and ended here — all seven 2.1.x
grammars wired (1.3.2–1.3.5) plus the 2.0.1-unblocked lift.

**1.3.5** — shipped 2026-05-09. Fourth catchup patch on top
of 1.3.1's vyakarana 2.x bump. Wires the vyakarana 2.1.3
grammar (Terraform / HCL) into owl's language table and
bootstrap; `LANG_COUNT` 44 → 45. Closes the 2.1.x grammar
batch — owl 1.3.2 through 1.3.5 picked up all seven
grammars vyakarana shipped in that window (PowerShell,
Crystal, Julia, Vue, Svelte, Nix, Terraform).
`grammar-coverage.md` extended with three terraform gap
rows. No toolchain pin movement; still cyrius 5.10.10 +
vyakarana 2.2.1. Catchup queue advances to 1.3.6 — the
HIGHLIGHT_MAX lift unblocked by vyakarana 2.0.1's rolling-
buffer scanner.

**1.3.4** — shipped 2026-05-09. Third catchup patch on top of
1.3.1's vyakarana 2.x bump. Wires the vyakarana 2.1.2 grammar
(Nix) into owl's language table and bootstrap; `LANG_COUNT`
43 → 44. `grammar-coverage.md` extended with four nix gap
rows. No toolchain pin movement; still cyrius 5.10.10 +
vyakarana 2.2.1. Catchup queue advances to 1.3.5 (vyakarana
2.1.3 — Terraform / HCL).

**1.3.3** — shipped 2026-05-09. Second catchup patch on top
of 1.3.1's vyakarana 2.x bump. Wires the vyakarana 2.1.1 SFC
batch (Vue, Svelte) into owl's language table and bootstrap;
`LANG_COUNT` 41 → 43. Adds `docs/grammar-coverage.md` — a new
top-level reference doc aggregating the per-grammar gap notes
that live in every `grammars/*.cyml` header into a single
scannable table. No toolchain pin movement; still cyrius
5.10.10 + vyakarana 2.2.1. Catchup queue advances to 1.3.4
(vyakarana 2.1.2 — Nix).

**1.3.2** — shipped 2026-05-09. First catchup patch on top
of 1.3.1's vyakarana 2.x bump. Wires the vyakarana 2.1.0
grammar batch (PowerShell, Crystal, Julia) into owl's
language table and bootstrap. `LANG_COUNT` 38 → 41. No
toolchain pin movement — still cyrius 5.10.10 + vyakarana
2.2.1; grammar files have been in `dist/vyakarana.cyr` since
1.3.1, this patch lights up the wiring. Catchup queue
advances to 1.3.3 (vyakarana 2.1.1 — Vue + Svelte SFC).

**1.3.1** — shipped 2026-05-09. Vyakarana 2.x toolchain bump.
Cyrius 5.9.43 → 5.10.10; vyakarana 1.11.0 → 2.2.1. The
load-bearing change is the breaking-API migration from
`tokenize_source(buf, lang)` to the push-based streaming
primitive (`tokenize_stream_new` / `_feed` / `_finish` /
`_free`) per vyakarana ADR 0017 — single owl call site at
`src/main.cyr:1220`. Behaviour unchanged: owl drives a
one-shot feed since the highlight path is still
HIGHLIGHT_MAX-bounded (128 KB). Per the catchup-via-patches
plan, the seven new grammars in vyakarana's 2.1.x window
(powershell, crystal, julia, vue, svelte, nix, terraform) and
the `HIGHLIGHT_MAX` lift unblocked by 2.0.1's rolling-buffer
scanner are deferred to subsequent 1.3.x patches. LANG_COUNT
unchanged at 38. The first build attempt surfaced two coupled
bugs that landed under this same version: (a) renamed
`detect_language_from_content` → `_owl_detect_language_from_content`
to dodge a collision with vyakarana 2.x's now-public function
of the same name; (b) corrected the `Install Cyrius toolchain`
step in both CI workflows to use the cyriusly-shape
versioned-tree layout (`~/.cyrius/versions/<v>/{bin,lib}/` +
symlinks + `current` file) — the prior flat layout silently
hid `SYS_DUP` and other peer-only symbols from cyrius's
stdlib search path.

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

- **Cyrius pin**: `5.10.10` (in `cyrius.cyml [package].cyrius`)
  — bumped from `5.9.43` at 1.3.1 (2026-05-09). No source
  changes required.
- **vyakarana pin**: `2.2.1` (in `cyrius.cyml [deps.vyakarana].tag`)
  — bumped from `1.11.0` at 1.3.1. **Crossed the 1.x → 2.x
  major-version boundary.** Public tokenizer API broke at 2.0.0
  (`tokenize_source` removed; replaced by the push-based
  streaming primitive per [ADR 0017](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0017-streaming-api.md)).
  owl's call sites migrated in 1.3.1 (one-shot feed) and again
  in 1.3.6 (per-chunk feed during the slurp read loop). 2.0.1's
  rolling-buffer scanner caps live span at 16 MB rather than
  total input — the load-bearing improvement that unblocked
  owl's HIGHLIGHT_MAX lift at 1.3.6. 2.1.x added 7 grammars
  (powershell, crystal, julia, vue, svelte, nix, terraform);
  all wired by owl 1.3.2–1.3.5. 2.2.0/2.2.1 are streaming-
  correctness fixes that ride along transparently.

## Binary

- ~459 KB (470,448 bytes, `build/owl`, DCE) at 1.3.6.
  +231,504 bytes vs 1.3.0's 238,944 — almost double, primarily
  because vyakarana 2.x ships per ADR 0014 with **inlined CYML
  grammar text** in the bundle, and the full 45-grammar set
  (1.3.x catchup) is now both inlined upstream and wired in
  owl's `_owl_bootstrap_grammars`. owl-side source growth
  across the 1.3.x window is modest — ~100 lines net (45 lines
  in `lang.cyr` table entries, 30 lines in `main.cyr` bootstrap
  calls, ~25 lines in the streaming-API + per-chunk-feed
  refactor at 1.3.1 / 1.3.6).
- DCE and non-DCE builds are the same size but **not
  byte-identical** under cyrius 5.10.x: DCE NOPs out dead-code
  spans (the streaming primitive's pull-adapter, vyakarana's
  LSP bridge, and the historical handcoded shell tokenizer all
  strip cleanly).
- Startup targets: `owl --version` 1–2 ms, tiny-file highlight
  2 ms (25× under the 50 ms no-op target in
  `docs/design-spec.md`). Bootstrap of 45 grammars at
  first-token-color path is marginally more than the original
  11; first-byte plain-mode path is unaffected (grammars load
  lazily on first highlight).

## Source

- 3,823 lines across 6 modules (1.3.6 cut):
  - `src/main.cyr` (2,112) — entry, CLI, render dispatch, TTY/mode resolution, exe-relative grammar lookup, hex-dump, --diff, bat-style header frame (1.1.7), wrap-continuation gutter (1.1.8), `↪` wrap-arrow glyph (1.1.9), VCS-aware wrap budget (1.1.11), grammar bootstrap (1.1.12 → 1.3.5 covering 45 grammars), tokenize_source → streaming-API migration (1.3.1), per-chunk feed during slurp + HIGHLIGHT_MAX 128 KB → 16 MB (1.3.6)
  - `src/lang.cyr` (499) — extension/shebang/content detection + ext-override table + filename-shape detection (1.2.6); LANG_COUNT 45 (latest additions: terraform 1.3.5, nix 1.3.4, vue/svelte 1.3.3, powershell/crystal/julia 1.3.2, cyml/llvm_ir 1.3.0)
  - `src/theme.cyr` (439) — bundled themes, 10-kind palette, ANSI emission, user-theme loader (1.1.3); kind_name-keyed `theme_token_color` per vyakarana architecture note 004 (1.3.0)
  - `src/vcs.cyr` (328) — git VCS markers (M6) + --diff bypass for piped output
  - `src/config.cyr` (298) — `key = value` config parser (M7) + `ext.*` keys (1.1.1)
  - `src/pager.cyr` (147) — pager spawn + SIGPIPE handling + env forward (1.1.5)

## Tests

- `tests/owl.tcyr` — unit assertions
- `scripts/smoke.sh` — end-to-end behavioral gates (M0 → M8)
- `tests/owl.bcyr` — benchmark slot (reserved)
- `tests/owl.fcyr` — fuzz slot (reserved)

## Dependencies

- **Cyrius stdlib** — `syscalls`, `alloc`, `fmt`, `io`, `fs`, `str`, `string`, `vec`, `args`, `hashmap`, `process`, `tagged`, `assert`
- **vyakarana** 2.2.1 — tokenizer + 45 bundled grammars (git-tag pinned in `[deps.vyakarana]`). The 1.x grammar cascade (1.2.0 → 1.9.0) brought owl from 11 → 38 bundled grammars; the 2.1.x grammar batch (2.1.0 → 2.1.3, picked up at owl 1.3.2 → 1.3.5) added the final 7 (powershell, crystal, julia, vue, svelte, nix, terraform). 2.0.0's streaming-API break replaced `tokenize_source` with the push primitive (owl's call sites migrated at 1.3.1); 2.0.1's rolling-buffer scanner unblocked the HIGHLIGHT_MAX lift owl shipped at 1.3.6. The 1.11.0 LSP bridge ships in `[lib] modules` but DCE-strips on owl (editor-consumer surface, unused by the viewer path).

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

The 1.3.x catchup window is closed — the four blockers it
worked through (vyakarana 2.x API migration, the 2.1.x grammar
batch, the architecture-note-004 conformance refactor, the
HIGHLIGHT_MAX lift unblocked by 2.0.1's rolling-buffer
scanner) all shipped between 1.3.0 and 1.3.6. See
[`roadmap.md`](roadmap.md) for the forward list — **1.4.x is
the next minor**, with five candidate items each independent
of the others:

- **SIT dependency swap** (highest priority once unblocked) —
  swap `src/vcs.cyr`'s `execve("git", "diff", …)` for a
  `sit_diff_path` library call. Blocked on sit 0.7.7 shipping
  `dist/sit.cyr` with a stable public API; sit is at 0.7.6.
- **NDJSON output mode** (`--format=ndjson`) — emit tokens as
  one JSON object per line for tooling consumers. Mirrors
  vyakarana's existing NDJSON debug shape. No upstream blocker.
- **`--follow` / `-f`** — tail-style live highlighting via
  inotify + per-modify re-tokenize. Cheap upstream now that
  vyakarana 2.0.1's rolling-buffer scanner is in place; needs
  owl-side append-only ANSI render path.
- **URL / remote-file support** (`owl https://…`) — fetch
  via sandhi's HTTP/TLS surface. Was out of scope for v1; now
  reachable since AGNOS's networking stack is mature.
- **Native AGNOS theming** — wait until AGNOS ships its
  system-wide theming primitive; owl's kind_name-keyed theme
  layer (1.3.0) is the load-bearing prep, swap is mechanical.

No upstream toolchain or grammar items currently parked —
when vyakarana ships another batch of grammars or owl-relevant
scanner work, the same catchup-window pattern applies (one
focused patch per upstream minor).

Stdlib follow-ups: M7's `key = value` parser will swap to a formal
CYML parser when `cyml` lands in stdlib.
