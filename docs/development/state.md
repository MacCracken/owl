# owl — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). Add release-hook wiring
> when the repo's release workflow lands.

## Version

**1.4.0** — shipped 2026-06-14. **Opens the 1.4.x feature
line with the SIT dependency swap.** owl's VCS change-marker
gutter no longer forks `git diff` — `src/vcs.cyr` is rewritten
to read the working-tree-vs-HEAD diff from
[sit](https://github.com/MacCracken/sit)'s library
(`sit_repo_open` → `sit_diff_path` → `sit_repo_close`), walking
sit's LCS edit script (`ann_kind`/`ann_new`) into the same
ADD/MOD/DEL per-line markers. The five-fn public interface
(`vcs_compute_markers`, `vcs_mark_for_line`, `vcs_enabled`,
`vcs_reset`, `set_style`) is unchanged, so main.cyr and the
gutter renderer are untouched. Toolchain moves to cyrius 6.2.2
+ vyakarana 2.2.3; new deps `sit 1.0.1` + its object-store
stack (`patra 1.11.2`, `sigil 3.7.13`, `sankoch 2.3.1`,
`sakshi 2.3.0`). The first co-link of vyakarana + sit→patra
surfaced a silent symbol collision (patra's SQL `enum TokType`
vs vyakarana's `TK_IDENT`/`TK_COUNT` token-kind palette) that
broke patra's SQL parser → fixed upstream by namespacing
patra's enum (`TK_*`→`SQLT_*`, patra 1.11.2); the broader
stdlib constant-collision class is filed for cyrius
(`cyrius/docs/development/issues/2026-06-14-stdlib-constant-value-collisions.md`).
The git subprocess (fork+execve) is gone, closing audit
FINDING-003/005 by construction. Binary jumps ~459 KB → ~2.6 MB
(the object-store link; accepted, pending the 6.x
lib-streamlining arc). Known limit: sit 1.0.1 doesn't search
upward for `.sit/`, so markers need owl run from the repo root.
The **agnos build target is temporarily disabled** (commented in
both workflows): linking sit pulls its transitive stdlib
(`tls`/`net`/`mmap`) which isn't agnos-ported yet (agnos TLS
unimplemented; `mmap.cyr` needs `CLONE_VM`), and cyrius has no
conditional deps to skip sit on agnos. owl's `#ifdef
CYRIUS_TARGET_AGNOS` gates stay in the source for when it returns.

**1.3.8** — shipped 2026-06-09. agnos fix: `owl FILE` printed
usage instead of the file. Two AGNOS-only bugs — module-scope
`var r = main();` ran during gvar-init (before cycc's init-rsp
capture, placed after gvar-inits as of cyrius 6.1.14) so
argc/argv read 0/null → help; fixed with the bare top-level
`_owl_entry();` call. And cyrius pin 6.0.56 → 6.1.14 + re-vendored
`lib/` so `lib/fnptr.cyr` carries the `CYRIUS_TARGET_AGNOS`
fncall branch. Host build/behaviour unchanged.

**1.3.7** — shipped 2026-06-09. **AGNOS target support** — owl
builds `--agnos` and runs as a file viewer on the sovereign OS.
Cyrius pin 5.10.10 → 6.0.56 (`CYRIUS_TARGET_AGNOS` landed there).
agnos-unavailable facilities gated behind `#ifdef
CYRIUS_TARGET_AGNOS`: pager, VCS gutter, terminal-size ioctl,
tty detection, `/proc/self/exe` readlink. Host (Linux) behaviour
unchanged. CI/release build + ship `owl_agnos` alongside the host
binary.

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

- **Cyrius pin**: `6.2.2` (in `cyrius.cyml [package].cyrius`)
  — bumped from `6.1.14` at 1.4.0. Prior moves: `5.9.43`→`5.10.10`
  (1.3.1), `5.10.10`→`6.0.56` (1.3.7, agnos target),
  `6.0.56`→`6.1.14` (1.3.8). No source changes required for the
  6.1.14 → 6.2.2 bump.
- **vyakarana pin**: `2.2.3` (in `cyrius.cyml [deps.vyakarana].tag`)
  — bumped from `2.2.1` at 1.4.0 (2.2.2/2.2.3 are CI/docs/
  language-table touch-ups; no owl-visible change). The 1.x→2.x
  history: API broke at 2.0.0 (`tokenize_source` → push-based
  streaming primitive per [ADR 0017](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0017-streaming-api.md));
  owl migrated at 1.3.1 (one-shot feed) + 1.3.6 (per-chunk feed).
  2.0.1's rolling-buffer scanner caps live span at 16 MB →
  unblocked the HIGHLIGHT_MAX lift (1.3.6). 2.1.x added 7
  grammars, all wired by 1.3.2–1.3.5.
- **sit pin**: `1.0.1` (in `cyrius.cyml [deps.sit].tag`) — added
  at 1.4.0 for the VCS change-marker gutter (library swap off
  git). Pulls its object-store stack as explicit deps:
  `patra 1.11.2`, `sigil 3.7.13`, `sankoch 2.3.1`, `sakshi 2.3.0`.
  patra moved 1.11.1 → **1.11.2** as part of this cut — an
  upstream fix owl drove: patra's SQL `enum TokType` collided
  with vyakarana's `TK_IDENT`/`TK_COUNT` token-kind constants
  under co-link; patra namespaced its enum (`TK_*`→`SQLT_*`).

## Binary

- **~2.6 MB (2,662,096 bytes, `build/owl`, DCE) at 1.4.0** — up
  from 1.3.6's ~459 KB. The jump is the sit object-store link:
  `dist/sit.cyr` (427 KB) + patra (B+tree/WAL store) + sigil
  (hashing) + sankoch (zlib) + sakshi. DCE strips sit's unused
  serve/wire/http/ssh surface, but `sit_diff_path`'s read path
  genuinely needs the store layer (read commit/tree/blob objects
  from patra, decompress via sankoch). Accepted for 1.4.0;
  trimming the sit-only tail waits on the cyrius 6.x
  lib-streamlining arc (cleaner per-symbol includes).
- Build emits expected co-link warnings, all benign: a
  `duplicate fn '_stream_grow'` (sankoch streaming vs vyakarana —
  inert, sit's reads use one-shot decompress) and
  `undefined function` notes for sit's async/ssh wire surface
  (DCE-stripped, owl never calls them).
- Startup targets unchanged on the plain/highlight paths
  (`owl --version` 1–2 ms; grammars still load lazily on first
  highlight). VCS marker computation now opens a patra DB per
  file when in a sit repo — only on the decorated/`--diff` path.

## Source

- 3,768 lines across 6 modules (1.4.0 cut):
  - `src/main.cyr` (2,143) — entry, CLI, render dispatch, TTY/mode resolution, exe-relative grammar lookup, hex-dump, --diff, bat-style header frame (1.1.7), wrap-continuation gutter (1.1.8), `↪` wrap-arrow glyph (1.1.9), VCS-aware wrap budget (1.1.11), grammar bootstrap (1.1.12 → 1.3.5 covering 45 grammars), tokenize_source → streaming-API migration (1.3.1), per-chunk feed during slurp + HIGHLIGHT_MAX 128 KB → 16 MB (1.3.6), agnos `#ifdef` gates + bare-`_owl_entry()` top-level call (1.3.7/1.3.8), `--version --verbose` banner reports sit (1.4.0)
  - `src/lang.cyr` (499) — extension/shebang/content detection + ext-override table + filename-shape detection (1.2.6); LANG_COUNT 45 (latest additions: terraform 1.3.5, nix 1.3.4, vue/svelte 1.3.3, powershell/crystal/julia 1.3.2, cyml/llvm_ir 1.3.0)
  - `src/theme.cyr` (439) — bundled themes, 10-kind palette, ANSI emission, user-theme loader (1.1.3); kind_name-keyed `theme_token_color` per vyakarana architecture note 004 (1.3.0)
  - `src/vcs.cyr` (229) — **sit-backed VCS markers (1.4.0)** via `sit_repo_open`/`sit_diff_path`/`sit_repo_close`; LCS edit-script → ADD/MOD/DEL mapping; `--diff` bypass for piped output; agnos `#ifdef` no-op. Replaced the git fork+execve scaffold; public five-fn interface unchanged
  - `src/config.cyr` (298) — `key = value` config parser (M7) + `ext.*` keys (1.1.1)
  - `src/pager.cyr` (160) — pager spawn + SIGPIPE handling + env forward (1.1.5) + agnos `#ifdef` no-op (1.3.7)

## Tests

- `tests/owl.tcyr` — unit assertions
- `scripts/smoke.sh` — end-to-end behavioral gates (M0 → M8)
- `tests/owl.bcyr` — benchmark slot (reserved)
- `tests/owl.fcyr` — fuzz slot (reserved)

## Dependencies

- **Cyrius stdlib** — owl's own viewer surface needs `syscalls`,
  `alloc`, `fmt`, `io`, `fs`, `str`, `string`, `vec`, `args`,
  `hashmap`, `process`, `tagged`, `assert`. As of 1.4.0 the
  `[deps] stdlib` list also carries sit's transitive footprint
  (`slice`, `chrono`, `fnptr`, `thread`, `freelist`, `bayan`,
  `ct`, `keccak`, `bench`, `net`, `mmap`, `dynlib`, `fdlopen`,
  `tls`, `tls_native`, `ws`, `http`, `sandhi`) so `dist/sit.cyr`'s
  full bundle resolves at compile time — DCE strips the unused
  serve/wire/http functions from the binary. The 6.x lib-
  streamlining arc should let owl drop the sit-only tail.
- **vyakarana** 2.2.3 — tokenizer + 45 bundled grammars
  (git-tag pinned in `[deps.vyakarana]`). 11 → 45 grammars across
  the 1.2.x/1.3.x cascade; 2.0.0 streaming-API break migrated at
  1.3.1/1.3.6.
- **sit** 1.0.1 — AGNOS-native VCS (added 1.4.0). owl consumes its
  ADR-0009 library surface (`sit_repo_open` / `sit_diff_path` /
  `sit_repo_close` + `ann_*` accessors) for the VCS change-marker
  gutter, replacing the git fork+execve scaffold. Pulls a
  transitive object-store stack:
  - **patra** 1.11.2 — B+tree/WAL object store (sit's `.sit/objects`).
    1.11.2 namespaced its SQL token enum (`TK_*`→`SQLT_*`) to clear
    a co-link collision with vyakarana's token-kind constants.
  - **sigil** 3.7.13 — hashing (object addressing).
  - **sankoch** 2.3.1 — zlib/DEFLATE (object compression).
  - **sakshi** 2.3.0 — sit primitive used by the store stack.

No FFI. Third-party deps: vyakarana (tokenizer) + the sit VCS
stack (sit/patra/sigil/sankoch/sakshi).

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

**1.4.0 update:** the SIT swap removes the VCS subprocess entirely —
markers are computed in-process by sit's `sit_diff_path` library call,
with no `fork`/`execve` and no argv at all. FINDING-003 (shell
injection) and FINDING-005 (path quoting) are now closed *by
construction* on the VCS path, not just by careful argv handling.

## Verification

- `cyrius build src/main.cyr build/owl` — clean (cyrius 6.2.2)
- `CYRIUS_DCE=1 cyrius build` — clean; ~2.6 MB
- `cyrius test` — all `.tcyr` green
- `cyrius lint src/*.cyr` — 0 warnings
- `sh scripts/smoke.sh` — all M0–M8 behavioral gates green; the M6
  marker + `--diff` gates build a real sit repo fixture and assert
  MOD/ADD markers via `sit_diff_path` (skip with a stderr NOTE, not a
  silent pass, when no `sit` binary is found — set `OWL_SIT_BIN` in CI)

## Next

**1.4.0 shipped the SIT dependency swap** — the highest-priority
1.4.x item. Remaining 1.4.x candidates, each independent:

- **NDJSON output mode** (`--format=ndjson`) — emit tokens as
  one JSON object per line for tooling consumers. Mirrors
  vyakarana's existing NDJSON debug shape. No upstream blocker.
- **`--follow` / `-f`** — tail-style live highlighting via
  inotify + per-modify re-tokenize. Cheap upstream now that
  vyakarana 2.0.1's rolling-buffer scanner is in place; needs
  owl-side append-only ANSI render path.
- **URL / remote-file support** (`owl https://…`) — fetch
  via sandhi's HTTP/TLS surface. (sandhi is now linked anyway as
  part of sit's stdlib footprint, so the TLS surface is present.)
- **Native AGNOS theming** — wait until AGNOS ships its
  system-wide theming primitive; owl's kind_name-keyed theme
  layer (1.3.0) is the load-bearing prep, swap is mechanical.

Follow-ups opened by the SIT swap:

- **Binary-size trim** — owl is ~2.6 MB while it links sit's full
  bundle; revisit once the cyrius 6.x lib-streamlining arc lands
  cleaner per-symbol includes (drop the sit-only stdlib tail).
- **sit repo-root discovery** — markers need owl run from the
  `.sit/` root (sit 1.0.1's `sit_repo_open` has no upward search).
  Revisit if sit adds upward discovery, or add owl-side walk-up.
- **Re-enable the agnos build** — disabled in 1.4.0 because sit's
  transitive stdlib (tls/net/mmap) isn't agnos-ported. Uncomment the
  `--agnos` build + verify + package steps in `ci.yml`/`release.yml`
  once agnos TLS lands and `mmap.cyr` is agnos-clean (`CLONE_VM`).
- **Stdlib constant collisions** — filed for cyrius
  (`cyrius/docs/development/issues/2026-06-14-stdlib-constant-value-collisions.md`):
  `ERR_*`/`SYS_*` value mismatches across vendored libs, plus a
  proposed cycc warning on conflicting-value symbol dupes (the
  class that produced the patra/vyakarana `TK_IDENT` bug).

Stdlib follow-ups: M7's `key = value` parser will swap to a formal
CYML parser when `cyml` lands in stdlib.
