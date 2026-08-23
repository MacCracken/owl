# owl — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). Add release-hook wiring
> when the repo's release workflow lands.

## Version

**1.4.6** — shipped 2026-08-22. **P(−1) audit, hardening and repair
pass** over all six `src/*.cyr` modules. Seven findings, each with a
repro before it was accepted and a `scripts/smoke.sh` gate after it was
fixed; every gate proven non-vacuous against the 1.4.5 binary. No
feature or interface change. Report:
[`2026-08-22-audit.md`](../audit/2026-08-22-audit.md).

The one that matters: **a 2-byte file prefix could hide the entire
file.** The escape-strip classifier had no bound on sequence length, so
a file opening `ESC [` whose bytes never contained a CSI final byte had
*every* byte dropped — a 442-byte, 40-line file rendered as **0 content
bytes**, exit 0, on the default `owl FILE` terminal path. Because a
dropped byte also skips the line counter, a swallowed newline desynced
the `-n` gutter from the file. Fixed by bounding a sequence at a newline
(no escape form admits a raw LF) and at 256 bytes. FINDING-001's
stripping guarantee re-verified afterwards — zero ESC bytes survive.

Also repaired: a heap overflow building the config path from
`$XDG_CONFIG_HOME` / `$HOME` (2017 bytes into a 1024-byte buffer,
canary-confirmed); an unvalidated theme colour overrunning `ansi_fg`'s
16-byte buffer (26-byte escape emitted) and `_u16_to_ascii`'s 8-byte
buffer; the pager publishing an unterminated env entry to `execve`;
unbounded `--tabs`; unchecked `alloc()` at the load-bearing sites; and
an unbounded VCS marker allocation sized from a backend-supplied line
number. `CLAUDE.md`'s pager security claim was the inverse of the code
and is corrected.

**1.4.5** — shipped 2026-08-22. **Toolchain `6.2.37` → `6.5.35`,
deps to latest, and the `--agnos` target returns.** No `src/*.cyr`
behaviour change (+4 lines, all of it wiring the new `openqasm`
grammar). Three things make this more than a version-number pass:

1. **owl did not build before it.** Neither the released 1.4.4
   pins nor the unreleased working-tree bump compiles on `6.5.35`
   — `_sandhi_conn_open_v6_fully_timed_a` expects 9 arguments and
   gets 8 (and, on the 1.4.4 pins, `run_capture` expects 5 and
   gets 2). Both defects are in materialized `lib/`, which is
   generated, so the fix is a manifest change, not an edit.
2. **`sakshi` / `sankoch` / `sigil` / `patra` stop being git
   deps.** All four are folded into the cyrius stdlib snapshot, so
   they moved to `[deps].stdlib` and `cyrius.lock` drops from 6
   commit pins to 2. This tracks sit's own 1.3.6 correction and is
   the thing that actually clears (1): a git pin does not merely
   select a version, it **overlays** the older file on top of the
   snapshot for everything downstream, signalled only by an
   unnamed "N bundled lib(s) differ" warning that `deps --verify`
   structurally cannot catch (the lock is written from disk, so it
   records the downgraded file's own hash). The toolchain pin is
   now the single version lever for all four.
3. **The `--agnos` build lane is back**, disabled since 1.4.0. The
   blocker was sit's `tls`/`net`/`mmap` tail not being
   agnos-ported; sit closed that over 1.3.3–1.3.6. Both `cyrius
   build --agnos` and its DCE form link clean and emit a valid ELF
   (3,565,168 bytes), and both workflows are re-enabled.

Deps: vyakarana `2.2.3` → **2.4.0** (streaming chunk-invariance —
five root causes that made a chunk-fed tokenizer disagree with a
whole-buffer one; owl drives the streaming API, so this lands on
the highlight path), sit `1.3.4` → **1.6.1** (its 1.3.5–1.3.8
hardening arc, incl. two memory-safety defects in the git packfile
reader that *are* on owl's read path when the gutter opens a
`.git/` repo). `grammars/` re-synced wholesale from vyakarana
2.4.0: **46 grammars** (was 45; new `openqasm`), plus real rule
changes across 40 existing grammars owl had drifted behind — 21
new `[[rules]]`, 9 new `escape` declarations, `unicode_ident` on
8. `[deps].stdlib` now mirrors `dist/sit.deps` verbatim and gains
`thread_local` + `sync` alongside the four folded layers. DCE
binary ~2.70 MB → **~3.58 MB** (3,584,920 bytes).

**1.4.1** — shipped 2026-06-19. **Toolchain + dependency
refresh on the 1.4.x line.** No `src/*.cyr` behaviour change —
owl's viewer/highlighter/VCS surface is untouched except the
version-banner triple. Cyrius pin moves 6.2.2 → **6.2.25**; sit
1.0.1 → **1.0.2** with its object-store stack
(`sakshi 2.3.0→2.4.0`, `sankoch 2.3.1→2.4.4`,
`sigil 3.7.13→3.9.1`, `patra 1.11.2→1.12.0`); vyakarana stays
**2.2.3**. The load-bearing manifest change is one new stdlib
declaration: **`[deps] stdlib` gains `random`** — sigil 3.9.1
routes ed25519 keypair entropy through the cyrius stdlib
`random_bytes` (`lib/random.cyr`) instead of `getrandom`. owl
never generates keys, but `dist/sit.cyr`'s concatenated bundle
references the symbol, so it must resolve at compile time (DCE
strips it from owl's binary); without it the link leaves
`random_bytes` undefined. Tracks sit's own 1.0.2 refresh under
the same cyrius pin. DCE binary ~2.66 MB → **~2.70 MB**
(2,701,824 bytes, +~39 KB toolchain/dep heft). The agnos build
stays disabled (unchanged from 1.4.0 — sit's tls/net/mmap tail
isn't agnos-ported).

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

- **Cyrius pin**: `6.5.35` (in `cyrius.cyml [package].cyrius`)
  — bumped from `6.2.37` at 1.4.5, which also cleared a
  manifest-vs-wrapper pin drift. Prior moves: `6.2.2`→`6.2.25`
  (1.4.1), `6.1.14`→`6.2.2` (1.4.0), `5.9.43`→`5.10.10` (1.3.1),
  `5.10.10`→`6.0.56` (1.3.7, agnos target), `6.0.56`→`6.1.14`
  (1.3.8). CI and the release workflow both read this value out
  of `cyrius.cyml`, so a bump needs no workflow edit.
- **vyakarana pin**: `2.4.0` (in `cyrius.cyml [deps.vyakarana].tag`)
  — bumped from `2.2.3` at 1.4.5. 2.4.0's substance is **streaming
  chunk-invariance**: a chunk-fed tokenizer now produces the same
  tokens as a whole-buffer one on 15 of 20 corpora (was 7), fixing
  early-committed block comments, split longest-match operator
  runs, and mis-scanned pair openers straddling a chunk boundary.
  owl drives `tokenize_stream_new` / `_feed` / `_finish`, so this
  is directly on the highlight path. 2.3.5 added the `openqasm`
  grammar; 2.3.4 was a hardening audit (oversize-input truncation,
  a 1-byte OOB read, unchecked `alloc` at four sites). The 1.x→2.x
  history: API broke at 2.0.0 (`tokenize_source` → push-based
  streaming primitive per [ADR 0017](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0017-streaming-api.md));
  owl migrated at 1.3.1 (one-shot feed) + 1.3.6 (per-chunk feed).
- **sit pin**: `1.6.1` (in `cyrius.cyml [deps.sit].tag`) — bumped
  from `1.3.4` at 1.4.5. owl's consumed surface
  (`sit_repo_open` / `sit_diff_path` / `sit_repo_close` + `ann_*`)
  is unchanged across the whole range. What owl inherits is the
  1.3.5–1.3.8 hardening arc: a `three_way_line_merge` SIGSEGV, an
  ssh:// argument-injection class, a sankoch >1 MiB
  object-corruption fix, and — the part that is genuinely on owl's
  path — two memory-safety defects in the `.git/` packfile reader
  (a SIGSEGV from trusting `.idx` geometry, and a 127-byte heap
  disclosure from an unbounded delta source), both reachable
  read-only against any repo owl's gutter opens.
  - **The four object-store layers are no longer pinned here.**
    `sakshi` / `sankoch` / `sigil` / `patra` moved to
    `[deps].stdlib` at 1.4.5 — see §Dependencies. Do **not**
    re-add them as `[deps.<name>]` git blocks.
  - **`random` stdlib added at 1.4.1**, `thread_local` + `sync` at
    1.4.5. All three are load-bearing at *runtime* rather than
    link time (sigil's ed25519 entropy; sigil's crypto bank and
    patra's storage slots calling `thread_local_*`), so they are
    declared explicitly rather than left to the transitive arc —
    an undeclared module of this class fails as a SIGILL, not a
    build error.
  - At 1.4.0, patra moved 1.11.1 → 1.11.2 — an upstream fix owl
    drove: patra's SQL `enum TokType` collided with vyakarana's
    `TK_IDENT`/`TK_COUNT` token-kind constants under co-link;
    patra namespaced its enum (`TK_*`→`SQLT_*`).

## Binary

- **~3.59 MB (3,589,048 bytes, `build/owl`, DCE) at 1.4.6** — the
  1.4.6 audit repairs cost 4,128 bytes over 1.4.5's 3,584,920. Up
  from 1.4.1's ~2.70 MB (2,701,824), the last release that
  recorded a number. There is no true 1.4.4 baseline to diff
  against: neither the released 1.4.4 pins nor the unreleased
  working-tree bump builds under 6.5.35. The growth is toolchain
  and dep heft (the 6.2 → 6.5 stdlib arc, vyakarana's streaming
  rework, sit's 1.3.5–1.3.8 hardening), not owl source: `src/` grew
  4 lines at 1.4.5 and 146 at 1.4.6, together under 0.2% of the
  binary. The agnos binary is 3,565,200 bytes.
- The 1.4.0 baseline jumped from 1.3.6's ~459 KB. That jump is the
  sit object-store link: `dist/sit.cyr` + patra (B+tree/WAL store)
  + sigil (hashing) + sankoch (zlib) + sakshi. DCE strips sit's
  unused serve/wire/http/ssh surface, but `sit_diff_path`'s read
  path genuinely needs the store layer.
- Build emits expected co-link warnings, all benign:
  - a **`duplicate fn '_stream_grow'`** (vyakarana vs sankoch).
    **The direction flipped at 1.4.5** — under the old git-dep
    ordering sankoch was the later definition; under the stdlib
    fold vyakarana is, so the warning names the opposite file than
    it used to. Inert either way, and verified so rather than
    assumed: a build with sankoch's exact body re-inserted last
    (reproducing the old ordering) yields byte-identical
    highlighted output at 2 KB / 4 KB / 8 KB / 40 KB — spanning
    `VYK_STREAM_INIT_CAP` (4096), so the grow path is genuinely
    exercised — and an exit-42 probe in the winning definition
    never fires, i.e. call sites in `lib/vyakarana.cyr` bind to
    vyakarana's own definition regardless of which one the warning
    names. Separately, sankoch's own caller (`stream_write`) is
    off owl's path entirely — sit reaches sankoch only through
    one-shot `zlib_decompress_with_ratio_cap` / `zlib_compress` —
    and is dead in the DCE map. Still worth an upstream
    namespacing fix: inertness is a property of the current call
    graph, not a guarantee.
  - `undefined function` notes (15 of them) for sit's async/ssh
    wire surface — DCE-stripped, owl never calls them. Adopting
    `dist/sit-read.cyr` would remove them entirely; see §Next.
- **No silent global/enum collisions.** A repo-wide sweep of
  top-level `var`/`const` and enum members — the *unwarned* half
  of the hazard class, and the shape of the patra `TK_*` collision
  at 1.4.0 — found zero overlaps between vyakarana and sankoch /
  sigil / patra / sakshi / sit / bayan / ct / keccak.
- Startup targets unchanged on the plain/highlight paths
  (`owl --version` 1–2 ms; grammars still load lazily on first
  highlight). VCS marker computation opens a patra DB per file
  when in a sit repo — only on the decorated/`--diff` path.

## Source

- 4,052 lines across 6 modules (1.4.6 cut):
  - `src/main.cyr` (2,203) — entry, CLI, render dispatch, TTY/mode resolution, exe-relative grammar lookup, hex-dump, --diff, bat-style header frame (1.1.7), wrap-continuation gutter (1.1.8), `↪` wrap-arrow glyph (1.1.9), VCS-aware wrap budget (1.1.11), grammar bootstrap (1.1.12 → 1.4.5 covering 46 grammars), tokenize_source → streaming-API migration (1.3.1), per-chunk feed during slurp + HIGHLIGHT_MAX 128 KB → 16 MB (1.3.6), agnos `#ifdef` gates + bare-`_owl_entry()` top-level call (1.3.7/1.3.8), `--version --verbose` banner reports sit (1.4.0)
  - `src/lang.cyr` (505) — extension/shebang/content detection + ext-override table + filename-shape detection (1.2.6); LANG_COUNT 46 (latest additions: openqasm 1.4.5, terraform 1.3.5, nix 1.3.4, vue/svelte 1.3.3, powershell/crystal/julia 1.3.2, cyml/llvm_ir 1.3.0)
  - `src/theme.cyr` (475) — bundled themes, 10-kind palette, ANSI emission, user-theme loader (1.1.3); kind_name-keyed `theme_token_color` per vyakarana architecture note 004 (1.3.0)
  - `src/vcs.cyr` (376) — **sit-backed VCS markers (1.4.0)** via `sit_repo_open`/`sit_diff_path`/`sit_repo_close`; LCS edit-script → ADD/MOD/DEL mapping; `--diff` bypass for piped output; agnos `#ifdef` no-op. Replaced the git fork+execve scaffold; public five-fn interface unchanged
  - `src/config.cyr` (319) — `key = value` config parser (M7) + `ext.*` keys (1.1.1)
  - `src/pager.cyr` (174) — pager spawn + SIGPIPE handling + env forward (1.1.5) + agnos `#ifdef` no-op (1.3.7)

## Tests

- `tests/owl.tcyr` — unit assertions
- `scripts/smoke.sh` — end-to-end behavioral gates (M0 → M8)
- `tests/owl.bcyr` — benchmark slot (reserved)
- `tests/owl.fcyr` — fuzz slot (reserved)

## Dependencies

- **Cyrius stdlib** — owl's own viewer surface needs `syscalls`,
  `alloc`, `fmt`, `io`, `fs`, `str`, `string`, `vec`, `args`,
  `hashmap`, `process`, `tagged`, `assert`. Everything after that
  in `[deps].stdlib` is sit's transitive footprint: `dist/sit.cyr`
  concatenates sit's full `src/` (including the wire/serve/https
  surface owl never calls), so every symbol it references must
  resolve at compile time even though DCE strips the unused
  functions. **The list mirrors `dist/sit.deps` verbatim** — that
  sidecar, emitted by `cyrius distlib` next to the bundle, is the
  authority; on a sit bump, diff against it rather than guessing.
- **`sakshi` / `sankoch` / `sigil` / `patra` are stdlib leaves,
  not git deps** (since 1.4.5, tracking sit 1.3.6). All four ship
  in the cyrius stdlib snapshot, so the `cyrius` pin in
  `[package]` is the only version lever for them, and
  `cyrius.lock` carries just 2 commit pins (vyakarana + sit).
  ⚠ Do **not** re-add them as `[deps.<name>]` git blocks: a git
  pin overlays the older file on top of the snapshot for
  everything downstream, and `deps --verify` cannot detect it
  because the lock is written from disk and records the
  downgraded file's own hash. patra (1.13.0) and sigil (3.12.7)
  made the same change upstream for the same reason.
- **vyakarana** 2.4.0 — tokenizer + **46** bundled grammars
  (git-tag pinned in `[deps.vyakarana]`). 11 → 46 grammars across
  the 1.2.x/1.3.x cascade and 2.3.5's `openqasm`; 2.0.0
  streaming-API break migrated at 1.3.1/1.3.6; 2.4.0 made that
  streaming path chunk-invariant.
- **sit** 1.6.1 — AGNOS-native VCS (added 1.4.0). owl consumes its
  ADR-0009 library surface (`sit_repo_open` / `sit_diff_path` /
  `sit_repo_close` + `ann_*` accessors) for the VCS change-marker
  gutter, replacing the git fork+execve scaffold. Reaching it
  transitively (and resolved via the stdlib fold, not pins):
  patra (B+tree/WAL object store), sigil (hashing), sankoch
  (zlib/DEFLATE), sakshi (structured logging).

`grammars/` is runtime data copied from vyakarana, not source —
re-sync it wholesale on a vyakarana bump (`git archive <tag>
grammars/`) rather than editing in place, and wire any new
grammar into `src/lang.cyr`'s three tables plus both bootstrap
lists in `src/main.cyr`.

No FFI. Third-party deps: vyakarana (tokenizer) + sit (VCS).

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

**1.4.6 audit** — [`docs/audit/2026-08-22-audit.md`](../audit/2026-08-22-audit.md),
all findings closed in the same release:

| Finding | Severity | Fix |
|---------|----------|-----|
| 006 | **HIGH**   | Escape-strip classifier was unbounded — an unterminated sequence dropped the rest of the file (442-byte file → 0 rendered bytes, exit 0) and desynced the `-n` gutter. Bounded at a newline (no escape form admits a raw LF) and at `ESC_MAX_LEN` = 256; the byte that trips either bound is emitted. Hidden-content class, cf. CVE-2021-42574 (Trojan Source) |
| 007 | MEDIUM | `_config_resolve_path` appended `$XDG_CONFIG_HOME` / `$HOME` into a fixed `alloc(1024)`. Replaced with `_cfg_join`, sized from the operands, `alloc` checked, `PATH_MAX_SANE` (4096) refusal falling through to the next candidate |
| 008 | MEDIUM | Theme colours were unvalidated and reached `ansi_fg`'s 16-byte buffer via `_u16_to_ascii`'s 8-byte buffer. Validated to `-1..255` at parse time, `-1` additionally rejected for header/lineno (their call sites never test it), and `_u16_to_ascii` clamps regardless of caller |
| 009 | LOW    | Pager env forwarding handed `execve` a pointer to an entry left unterminated by the 16 KB `/proc/self/environ` read. Entries now accepted only if they terminate inside the buffer |
| 010 | LOW    | `--tabs` / `tabs =` unbounded; a 20-digit value also overflowed `i64` inside `atoi`. Rejected above 3 digits *before* `atoi`, then bounded to 0–64 |
| 011 | LOW    | `alloc()` return unchecked at ~27 sites. Load-bearing sites guarded, degrading into paths that already exist; `_user_ext_init` / `_user_theme_init` propagate failure to callers |
| 012 | LOW    | VCS marker table sized from sit's `max_line` with no ceiling, on repos that may be cloned from anywhere. Fails closed above `VCS_MAX_LINES` (16,777,216) |

Open informational items:

- **INFO-002 (upstream, cyrius)** — the stdlib's `getenv` (`lib/io.cyr`)
  reads `/proc/self/environ` into an 8 KB buffer, so any variable past
  that window is invisible. Measured on owl: `NO_COLOR=1` gives 0 ESC
  bytes with a small environment and **18** with one over 8 KB.
  `OWL_PAGER` / `PAGER` / `HOME` / `XDG_CONFIG_HOME` / `OWL_CONFIG` are
  affected identically. Not repaired locally — a private `getenv` would
  diverge from every other cyrius consumer. **Does not weaken escape
  stripping**: `_strip_active()` keys off `g_want_color`, which resolves
  from TTY detection, so a truncated environment can only fail to
  *enable* `NO_COLOR` — erring toward more decoration, never toward
  passing file-origin escapes through.
- **INFO-003 (accepted)** — 8-bit C1 controls (`0x9B` CSI, `0x9D` OSC,
  `0x90` DCS) are not stripped. In UTF-8, the only mode in which owl's
  box-drawing frame renders, `0x80–0x9F` are continuation bytes;
  stripping them would corrupt every non-ASCII file. `less` and `bat`
  make the same call. Revisit only if owl grows a non-UTF-8 mode.

## Verification

All green at 1.4.6 on cyrius `6.5.35`:

- `cyrius build src/main.cyr build/owl` — clean
- `cyrius build --agnos …` — clean, valid ELF
- `CYRIUS_DCE=1 cyrius build` (host **and** `--agnos`) — clean
- `cyrius test` — 7 passed, 0 failed
- `cyrius lint src/*.cyr` — unchanged from the 1.4.5 baseline: 20
  `exceeds 120 characters` on pre-existing comment lines + 2 tracked
  deferrals, zero new. (The 120-char rule on comment dividers is the one
  tolerated warning per `ci.yml`.)
- `sh scripts/smoke.sh` — all M0–M8 gates plus the five 1.4.6 audit
  gates. **Every audit gate is proven non-vacuous** against the 1.4.5
  binary: neutralising them in turn yields, in order, `FINDING-006:
  unterminated CSI suppressed the file (0 of 442 bytes)` → `FINDING-006:
  gutter desynced after a stripped escape` → `FINDING-007: oversized
  XDG_CONFIG_HOME was not rejected` → `FINDING-008: theme colour
  produced a 26-byte SGR (buffer is 16)`. FINDING-010's gate separates
  the same way (`--tabs=65` exits 0 on 1.4.5, 2 on 1.4.6)
- **Escape stripping (FINDING-001) re-verified after the 006 repair** —
  OSC 52, CSI SGR, OSC 0 + ST, DCS and `ESC 7` all stripped, **zero**
  ESC bytes surviving
- **Highlight round-trip** — `--color=always` output stripped of ANSI is
  byte-identical to the input across six files up to 400 KB spanning
  cyrius, cyml and markdown
- **Plain mode** — `owl -p` byte-identical to `cat` across the full
  audit corpus, hostile inputs included
- **VCS gutter** — `--diff` verified against a live working-tree change

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

Follow-ups opened by the 1.4.6 audit:

- **Report INFO-002 to cyrius** — the stdlib `getenv`'s 8 KB
  `/proc/self/environ` window silently drops any variable past it, which
  makes owl ignore `NO_COLOR` / `OWL_PAGER` / `HOME` /
  `XDG_CONFIG_HOME` on a large environment. Root cause is
  `lib/io.cyr`; owl must not carry a private `getenv`. See the audit
  report for the measurement.
- **Widen the audit corpus into a fuzz target.** `tests/owl.fcyr` is
  still a reserved slot. The 1.4.6 findings were all reachable from
  file content, config files or the environment — three inputs a fuzz
  harness could drive directly, and the escape classifier in particular
  is a state machine that wants one.

Follow-ups opened by the SIT swap:

- **Adopt `dist/sit-read.cyr`** *(highest-value follow-up)* — sit
  publishes a lean read-only bundle built for exactly this consumer;
  its manifest names owl's gutter markers by name. Same public API
  (`sit_repo_*` / `ann_*`), with the signing module and the entire
  network stack (wire / wire_http / serve) cut: **16** stdlib leaves
  instead of 38, and 8.6k bundle lines instead of 13.5k. It would let
  `[deps].stdlib` drop the whole sit-only tail (`net` / `mmap` /
  `tls` / `tls_native` / `ws` / `http` / `sandhi` / `bayan` / `ct` /
  `keccak` / `random` / `bench` / `dynlib` / `fdlopen` / `thread` /
  `fnptr` / …) and would silence all 15 `undefined function` link
  warnings, which exist solely because the full bundle leaves its
  `wire_ssh` / async transport symbols unresolved. Deliberately held
  out of 1.4.5: it changes what owl links, so it wants its own
  release and its own smoke run rather than riding a dep refresh.
  This supersedes the old "wait for the cyrius 6.x lib-streamlining
  arc" framing — the artifact already exists and has since sit 1.3.0.
- **Upstream namespacing for `_stream_grow`** — vyakarana and
  sankoch both define it, with incompatible signatures and struct
  layouts. Verified inert for owl in both link orderings (see
  §Binary), but that is a property of the current call graph, not a
  guarantee. Same hazard class as the patra `TK_*` collision owl
  drove a fix for at 1.4.0; the fix belongs upstream, in whichever
  of the two is easier to rename.
~~**sit repo-root discovery**~~ — **done at 1.4.3/1.4.4.** owl walks
up from the file's own path to find `.sit/`/`.git/` and tells sit the
root via `sit_set_repo_root`; a file outside any repo warns rather
than being diffed against an unrelated one.

~~**Re-enable the agnos build**~~ — **done at 1.4.5.** sit closed its
AGNOS syscall-ABI sweep over 1.3.3–1.3.6, so the tls/net/mmap tail
links clean; the `--agnos` build + ELF verify + package steps are
uncommented in both `ci.yml` and `release.yml`.

- **Stdlib constant collisions** — filed for cyrius
  (`cyrius/docs/development/issues/2026-06-14-stdlib-constant-value-collisions.md`):
  `ERR_*`/`SYS_*` value mismatches across vendored libs, plus a
  proposed cycc warning on conflicting-value symbol dupes (the
  class that produced the patra/vyakarana `TK_IDENT` bug).

Stdlib follow-ups: M7's `key = value` parser will swap to a formal
CYML parser when `cyml` lands in stdlib.
