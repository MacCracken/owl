# owl — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). Add release-hook wiring
> when the repo's release workflow lands.

## Version

**1.6.0** — 2026-10-31. **The 1.6.x feature line.** owl keeps no
language table and no grammar files:
- languages route through vyakarana (`detect_language_combined`), so `.asm`
  gets the NASM / GNU-as content vote and `.s` the x86-64 / AArch64 one;
- the 49 bundled grammars are vyakarana's embedded blobs, so the binary
  works from anywhere and releases ship no `grammars/`;
- a user grammar with a new name routes, lists and is selectable.

Also:
- `--follow` is token-coloured, through a vyakarana document;
- the CLI is parsed by cmdit (`--name VALUE`, `--`);
- INFO-012 is decided (piped tabs keep expanding);
- INFO-013 and INFO-014 are closed.

Over a 2,539-file sample, 171 files route differently, every one a
correction. 13 routes vyakarana lacks are kept in a supplement and drafted
upstream. Shell completions wait on a cmdit fix, and `--diff-from` on a sit
API (roadmap). Pins unchanged: cyrius 6.7.18, vyakarana 2.10.0, sit 1.13.0.
cmdit 1.5.0 becomes a direct dependency.

**1.5.3** — shipped 2026-10-31. **P(−1) audit, hardening and repair
pass** over everything since the 1.4.6 audit
([`2026-10-31-audit.md`](../audit/2026-10-31-audit.md)). Five independent
reviews found 26 defects in owl (1 HIGH, 9 MEDIUM, 16 LOW, numbered
FINDING-014 – 039) and 12 informational items, 5 of them sit-owned. All 26
are fixed, and each has a smoke gate that fails against 1.5.2.

The HIGH: escape stripping keyed on colour, so `NO_COLOR` or
`--color=never` on a terminal drew the frame and passed file escapes
through. That re-opened FINDING-001. Also closed:
- a heap overflow and a stack under-write;
- an ancestor-FIFO hang;
- gigabyte-scale VCS memory;
- ignored write errors;
- per-file memory growth;
- argument order mattering;
- an ndjson stream that silently ended at 64 KiB.

All output now goes through `src/out.cyr`: piped output is ~18× faster,
highlighted ~4×, `-p` unchanged. There is a second fuzz harness (config and
theme), the escape harness gained a precision invariant, and two vacuous
smoke gates are rewritten. Pins unchanged. The release binary is 1,414,456
bytes (+8,616).

**1.5.2** — shipped 2026-10-31. **Markdown is routed by extension.** Its
grammar has shipped since 1.0.0, but the language table had no row
for it. Before this release:
- `.md` and `.markdown` highlighted only when the first line was a
  `# ` heading;
- `--language=markdown` exited 2;
- markdown was missing from `--list-languages`.

It now has a row (`LANG_COUNT` 50: `plain` plus 49 grammars), and
smoke gates pin it. Pins and toolchain are unchanged from 1.5.1. The
release binary is 1,405,840 bytes (+8).

**1.5.1** — shipped 2026-10-31. **Toolchain `6.7.9` → `6.7.18`;
vyakarana `2.5.0` → `2.10.0`, sit `1.7.0` → `1.13.0`**, the latest
tag of each. Three new grammars (`nasm`, `mdx`, `lean`; 49 in all),
and a gutter fix that matters in practice: through 1.5.0, a one-line
edit to an **executable** file in a git repository marked every line
as added. That covered every shell script in a git checkout. sit
1.12.0 fixed how git tree modes are read, and a smoke gate now pins
it.

Highlighting changes where vyakarana deliberately moved token
boundaries (number literals, shell, prefixes, heredocs, chunked
compose streams). Nothing else changes: colour-stripped output is
byte-identical to 1.5.0, and highlighted output reproduces every
corpus file exactly.

sit's 1.7.6 and 1.12.2 audits harden the in-process read path owl's
gutter runs on: no retained blobs, no diffing of unchanged files, no
reads through symlinked directories. owl can now read `sit gc`'d
(packed) repositories.

The 6.7.10–6.7.18 migration notes (about 6,700 lines) were audited
against owl's source before the bump. Nothing reached owl's code.
`\x??` string escapes and the end of the 4,096-run DCE cap were
corrected in CLAUDE.md. The release binary is 1,405,832 bytes
(+73,712).

**1.5.0** — shipped 2026-10-31. **Toolchain `6.6.20` → `6.7.9`,
cyrius's 6.7 language line; vyakarana `2.4.3` → `2.5.0`, sit
`1.6.4` → `1.7.0`.** It is a minor release because cyrius moved a
language minor; owl itself did not change. No flag, output or
exit-code change: 288 corpus runs, `--diff` and the TTY gutter are
byte-identical to 1.4.9. Both dep tags are the only ones pinned to
6.7.9, and neither changes anything owl reaches.

Because several 6.7 changes alter what *already-compiling* code
computes (a lone `!`, unary `-`/`~` binding, narrow `*T` dereferences,
`println` of an untyped name), owl's source was audited against the
6.7.0–6.7.9 migration notes before the build. It is clean on every
item, and every grep pattern was checked against a planted positive.
The release binary is 1,332,120 bytes (+3,952).

**1.4.9** — shipped 2026-10-31. **Toolchain `6.6.2` → `6.6.20`;
vyakarana `2.4.2` → `2.4.3`, sit `1.6.1` → `1.6.4`.** These are the last
tags of each dep line pinned to 6.6.20; the next ones move to 6.7.x. No
behaviour change: owl's output is byte-identical to 1.4.8 in all 192
runs of the corpus A/B, and in the `--diff` and TTY gutter A/B.

Three things came with the bump:

- **The release binary halved, 2,650,688 → 1,328,168 bytes.** At 6.6.20,
  DCE removes dead code; at 6.6.2 it only replaced it with NOPs.
- **`[deps].stdlib` dropped 22 → 17 entries.** The 6.6.20 folded modules
  include their own requires, so the hand-kept sigil follow-throughs
  are no longer needed.
- **INFO-002 (the 8 KB `getenv` window) is confirmed closed upstream**,
  fixed in cyrius 6.5.36 and in effect since 1.4.8.

sit 1.6.4's audit puts several read-path fixes (D1/D3/D5/D8/D10/X1)
inside the fold owl links. `--version --verbose` now prints the real
pins; it had been stale since 1.4.1.

**1.4.8** — shipped 2026-09-11. **Toolchain `6.5.35` → `6.6.2`;
vyakarana `2.4.0` → `2.4.2`.** The toolchain made the long-tolerated
`_stream_grow` collision (vyakarana vs sankoch, different arity) a hard
error. vyakarana 2.4.2 renamed its copy, which retired the warning.
`tests/owl.bcyr` started including `bench` / `fnptr` itself, which
keeps them out of the shipped binary. This file was not refreshed at
that tag; the 1.4.9 entry covers it.

**1.4.7** — shipped 2026-08-22. **Closes the 1.4.x follow-up list.**
Two items landed as planned, one landed and immediately paid for
itself, one is parked with its reasons written down.

**sit's read-only fold.** `[deps.sit].modules` moves from
`dist/sit.cyr` to **`dist/sit-read.cyr`** — the same public API with
the signing module and the whole network stack cut. DCE binary
3,589,048 → **2,953,112** (**−17.7%**), `[deps].stdlib` 38 → **22**
entries, `undefined function` link warnings 15 → **3** (the three sit
documents as deliberate dead-path placeholders; the other twelve were
noise a real one could have hidden in). The sidecar under-reports —
`ct` / `keccak` / `bayan` / `random` are required and not listed, found
by trimming to the sidecar and reading the link errors.

**Two new flags.** `--format=ndjson` emits one JSON object per token
(vyakarana's `kind`/`start`/`len` shape plus owl's `line` and `text`);
escaping verified by reconstruction against every C0 byte, DEL, quotes,
backslashes and multi-byte UTF-8. `--follow` / `-f` tails a growing
file — deliberately without token colour, but **with** escape
stripping on appended bytes.

**A fuzz harness that found a hole in 1.4.6's own fix.**
`tests/owl.fcyr` is a real harness now (5 invariants over the escape
classifier, each A/B-verified against a broken build), and its first
run surfaced **FINDING-013**: the byte ceiling added for FINDING-006
emitted the byte that tripped it, and that byte can be an ESC — so a
sequence padded to exactly the ceiling followed by `ESC ] 52` wrote a
raw ESC and a complete clipboard-write sequence to the terminal,
re-opening FINDING-001 inside the repair for FINDING-006. The
classifier moved to its own module (`src/escape.cyr`) to make it
includable by the harness.

**URL support is written but parked** (`src/fetch.cyr`, not built) —
see §Next.

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

- **Cyrius pin**: `6.7.18` (in `cyrius.cyml [package].cyrius`) —
  bumped from `6.7.9` at 1.5.1. The 6.7.10–6.7.18 migration notes
  changed nothing in owl's code, but four things changed around it:
  - string literals parse `\x??` (6.7.11);
  - DCE compacts past 4,096 dead-code runs (6.7.14);
  - a pin bump re-locks only through `cyrius deps` (6.7.13);
  - every resolve names each stale `cyrius.lock` commit row
    (6.7.12).

  `6.7.9` came in at 1.5.0, bumped from `6.6.20`. 6.7 is a language minor: new
  reserved words (`trait` `const` `true` `false` `do` `dyn`), `!` as a
  real operator, forward calls arity-checked, and several binding and
  pointer-arithmetic changes that alter compiling code. The authority
  on what changes at a pin bump is cyrius
  `docs/development/ecosystem-migration.md`; read it before every
  bump. From 6.7.6, `cyrius deps --locked` checks `lib/` and the lock
  without writing. 6.6.20 came in at 1.4.9, bumped from 6.6.2, which was bumped from `6.5.35`
  at 1.4.8. At 6.6.20, `distlib` bundles and folded stdlib modules
  open with a compile-checked `# Requires` include block, `cyrius
  deps` writes `cyrius.lock` for stdlib entries too, and DCE now
  removes dead code where it used to NOP-fill it. `6.2.37`→`6.5.35`
  was 1.4.5, which also cleared a manifest-vs-wrapper pin drift.
  Prior moves: `6.2.2`→`6.2.25`
  (1.4.1), `6.1.14`→`6.2.2` (1.4.0), `5.9.43`→`5.10.10` (1.3.1),
  `5.10.10`→`6.0.56` (1.3.7, agnos target), `6.0.56`→`6.1.14`
  (1.3.8). CI and the release workflow both read this value out
  of `cyrius.cyml`, so a bump needs no workflow edit.
- **vyakarana pin**: `2.10.0` (in `cyrius.cyml [deps.vyakarana].tag`)
  — bumped from 2.5.0 at 1.5.1. No token kind, `Token` layout or
  public-API change across the range. Every function owl calls is
  present with the same arity, and `_grammars_bootstrapped`, the one
  internal owl writes, keeps its meaning. What arrives:
  - three grammars (2.9.9);
  - deliberate token-boundary changes (2.6.0 shell, 2.7.0 / 2.9.7
    numbers, 2.7.1 / 2.9.6 prefixes, 2.9.5 delimiters);
  - chunk-invariant streaming of compose grammars (2.8.0 –
    2.9.12);
  - compacted grammar blobs (2.9.0).

  `grammar_load` still matches embedded blobs only on the exact
  relative path `grammars/<name>.cyml`, so owl's absolute bundled
  paths and its user overlay still read from disk. Not adopted yet:
  `detect_language_registered` (2.9.8) and documents and incremental
  retokenization (2.9.11). 2.5.0 at 1.5.0 moved onto the 6.7 line with no source, grammar,
  token-kind or API change (its minor marks the language minor, as
  owl's does). 2.4.3 at 1.4.9 is a toolchain re-pin with no source or grammar
  change, and it cuts `dist/vyakarana.deps` from 11 leaves to 4.
  2.4.2 at 1.4.8 renamed `_stream_grow` → `_vyk_stream_grow`.
  Bumped from `2.2.3` to `2.4.0` at 1.4.5. 2.4.0's substance is **streaming
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
- **sit pin**: `1.13.0` (in `cyrius.cyml [deps.sit].tag`) — bumped
  from `1.7.0` at 1.5.1. The ADR 0009 surface owl calls is unchanged;
  it was amended at 1.11.0 for what `sit_repo_open` drops and for the
  per-call store lock. On owl's path:
  - git tree modes are read as git wrote them (1.12.0); this fixed
    owl's executable-file gutter;
  - `sit_diff_path` no longer retains blobs (R1) or diffs unchanged
    files (R9);
  - no reads through symlinked directories (G1);
  - packs are mapped read-only, which is why `mmap` is a stdlib entry
    again (1.7.4);
  - `sit gc` packs are readable (1.10.0);
  - the final newline is part of the last line (1.7.2).

  Locking: the read API takes `.sit/objects.flock` **shared, per
  call**. A running `sit` command never blocks owl; the gutter waits
  only while `sit gc` / `fsck --prune` hold it exclusively. ⚠ The read
  bundle carries a fourth unresolved symbol, `commit_tree_hex` (since
  sit 1.7.6), which ADR 0013 does not list. It is unreachable from
  owl, so this is an upstream gap. 1.7.0 came in at 1.5.0, bumped
  from `1.6.4`. Nothing on owl's path changed: the read fold
  gains 169 lines of conflict-recording CLI code (`conflicts_*`,
  `cmd_status`, `cmd_reset`), none of it reachable from `sit_diff_path`.
  Its bearer-token binding (ADR 0014) is network-side, outside the
  fold. The folded layers moved with the pin, notably patra
  1.15.2 → 1.16.0 (on-disk format A/B'd by sit, no change). ⚠ sit
  flags patra 1.16.1 / 1.16.2 (write-path data-loss fixes) as folding
  only at cyrius 6.7.11. owl's gutter is read-only, but that pin is
  where they land.
  1.6.4 came in at 1.4.9, bumped from `1.6.1`. 1.6.3 re-pinned to 6.6.20. 1.6.4 is a P(−1)
  audit release ([sit `docs/audit/2026-10-19-audit.md`](https://github.com/MacCracken/sit/blob/main/docs/audit/2026-10-19-audit.md));
  confirmed present in `lib/sit-read.cyr` are:
  - D3: pack indexes cached, not re-read on every lookup;
  - D8: object ids hex-checked before they reach the git backend;
  - D10 / D5: delta base size and the 16 MiB result ceiling checked;
  - D1: inflate ratio cap raised to 1100;
  - X1: `parse_tree` requires strict order.

  The sidecar `dist/sit-read.deps` dropped `tagged` (16 → 15 leaves).
  Bumped from `1.3.4` to `1.6.1` at 1.4.5. owl's consumed surface
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
    build error. **Superseded at 1.4.9:** `thread_local` / `sync`
    left with the sit-read move (1.4.7), and `random` left at 1.4.9.
    At 6.6.20 `lib/sigil.cyr` includes `random` itself, and since
    6.6.9 a reachable undefined function refuses to link rather
    than trapping at runtime. The trimmed build was checked to
    compile the identical function set before the entry was dropped.
  - At 1.4.0, patra moved 1.11.1 → 1.11.2 — an upstream fix owl
    drove: patra's SQL `enum TokType` collided with vyakarana's
    `TK_IDENT`/`TK_COUNT` token-kind constants under co-link;
    patra namespaced its enum (`TK_*`→`SQLT_*`).

## Binary

- **1,476,032 bytes (`CYRIUS_DCE=1`) at 1.6.0**, +61,576 over 1.5.3. About
  24 KB is vyakarana's routing and bootstrap code, now reachable. The rest
  is cmdit and the document API. `--agnos` DCE is 1,473,256; the plain build
  3,483,072. The grammar blobs were already in 1.5.3's binary as static
  data, which DCE keeps. Highlighting a small file takes 2.56 ms, down from
  3.43 ms, with no grammar file reads; `--version` takes 0.48 ms.
- **1,414,456 bytes (`CYRIUS_DCE=1`) at 1.5.3**, +8,616 over 1.5.2: the
  audit's repairs, the buffered writer and the new checks. `--agnos` DCE
  is 1,411,656; the plain build 3,482,936.
- **1,405,832 bytes (`CYRIUS_DCE=1`) at 1.5.1**, +73,712 over 1.5.0.
  `--agnos` DCE is 1,402,992 and the plain build 3,474,312;
  unreachable fns went 3,621 → 4,376. The growth is the deps'
  reachable code: sit's read path (packs, git read parity, audit
  fixes) and three grammar blobs, partly offset by vyakarana 2.9.0's
  blob compaction.
- **1,332,120 bytes (`CYRIUS_DCE=1`) at 1.5.0**, +3,952 over 1.4.9.
  `--agnos` DCE is 1,325,136; the plain build is 2,958,232.
  Unreachable fns went 3,611 → 3,621, the extra ten from sit 1.7.0's
  CLI code. That is still under the 4,096-run removal cap below.
- **~1.33 MB (1,328,168 bytes, `CYRIUS_DCE=1`) at 1.4.9**, down from
  2,650,688 at 1.4.8 (−49.9%); `--agnos` DCE is 1,325,264. This is
  the toolchain, not owl. At 6.6.20, DCE removes the 3,611
  unreachable functions (1,619,537 bytes), where 6.6.2 NOP-filled
  them in place. That is why 1.4.8's DCE and plain builds were the
  same size. The plain (non-DCE) build is 2,946,088 at 1.4.9, up
  from 2,650,688 because the 6.6.20 stdlib snapshot is larger.
  `release.yml` builds with `CYRIUS_DCE: '1'`, so 1.33 MB is what
  ships.
- ~~**Watch item: dead-code removal is capped at 4,096 dead-code
  runs.**~~ **Retired at 1.5.1: cyrius 6.7.14 removed the cap.**
  `tests/owl.tcyr` (5,199 unreachable fns) now compacts to 872 KB
  under `CYRIUS_DCE=1`, and owl's 4,376 compact as before. For
  6.6.20–6.7.13 the compiler NOP-filled past the cap and only printed
  a note, so the release binary could double without failing.
- **~2.95 MB (2,953,112 bytes, `build/owl`, DCE) at 1.4.7** — down
  **635,936 bytes (−17.7%)** from 1.4.6's 3,589,048, entirely from
  adopting sit's read-only fold. This reverses the growth trend since
  1.4.0 and lands below every release since 1.4.1 (2,701,824 was the
  pre-sit-bundle figure; the gap that remains is the object-store link
  the diff path genuinely needs). The agnos binary tracks it.
- **Adding URL support would cost 521,352 bytes** (measured:
  2,948,696 → 3,470,048), giving back 81% of that win. One of the
  three reasons `src/fetch.cyr` is parked — see §Next.
- Link warnings are down 15 → 3. The survivors are
  `load_signing_seed` / `sign_commit_body` / `verify_commit_body`,
  which sit documents as intentional dead-path placeholders in the
  read fold, referenced only by commit's signing path the read API
  never calls.
- The **`duplicate fn '_stream_grow'`** warning (vyakarana vs sankoch)
  is **gone since 1.4.8**. cyrius 6.5.37 made the arity mismatch a hard
  error, and vyakarana 2.4.2 renamed its copy. The history below is
  kept for the upstream filing. *(1.4.7:)* persisted and remained inert — verified in both link orderings. Filed
  at 1.4.7 as a **cyrius** issue, not a library one: `private` exists
  (6.5.0+) but does not scope symbol resolution, so neither library can
  currently fix this on its own. See
  `cyrius/docs/development/issues/2026-08-22-owl-private-fns-still-collide-across-files.md`.
- Startup targets unchanged on the plain/highlight paths
  (`owl --version` 1–2 ms; grammars still load lazily on first
  highlight).

## Source

- 5,161 lines across 8 built modules at 1.6.0 (`fetch.cyr`, 325, is not
  built — see §Next):
  - `src/main.cyr` (2,728) — entry, CLI (two-pass since 1.5.3; parsed by
    cmdit since 1.6.0), mode resolution, render dispatch, decorated frame,
    gutter, wrap, hex dump, ndjson, `--follow` (coloured through a
    vyakarana document since 1.6.0), the shared slurp (`_hl_slurp`) and the
    grammar bootstrap (user overlay, then vyakarana's embedded set)
  - `src/vcs.cyr` (593) — sit-backed change markers (1.4.0); stat-only repo
    probe, worktree size / line pre-check, and symlink / `.git`-file / `..`
    skips (1.5.3)
  - `src/lang.cyr` (456) — routing: ext overrides, new-name user grammars,
    vyakarana's routes, owl's supplement, the opening sniff. No language
    table since 1.6.0
  - `src/theme.cyr` (539) — bundled and user themes, the 10-kind palette,
    ANSI emission (through `out_write` since 1.5.3)
  - `src/config.cyr` (416) — `key = value` parser and `cfg_read_regular`,
    the shared regular-file reader for config and themes (1.5.3)
  - `src/pager.cyr` (186) — pager spawn; environment from `env_block`, SIGINT
    ignored while paging (1.5.3)
  - `src/out.cyr` (127) — **buffered stdout (1.5.3)**: every rendered byte;
    exit 3 on a write error
  - `src/escape.cyr` (116) — the file-origin escape classifier (1.4.7)

## Tests

- `tests/owl.tcyr` — unit assertions
- `scripts/smoke.sh` — end-to-end behavioral gates (M0 → M8)
- `tests/owl.bcyr` — benchmark slot (reserved)
- `tests/owl.fcyr` — **fuzz harness for the escape classifier (1.4.7)**.
  6 invariants: bounded suppression, newlines always emitted, ESC never
  emitted, escape-free streams pass through whole, reset is total, and
  (1.5.3) precision — a well-formed sequence is suppressed whole and the
  text after it emitted exactly. Each is A/B-verified against a broken
  classifier: `no-ceiling`, `no-lf`, `esc-at-ceiling`, and (1.5.3) a CSI
  final byte or BEL / ST that no longer terminates.
- `tests/owl_config.fcyr` — **fuzz harness for the config and theme
  parsers (1.5.3)**, closing the 1.4.6 audit's follow-up. 6 invariants
  checked against reference models; it caught 11 planted mutations.
- **1.6.0 gates**, each shown to fail before its change:
  - the `--verbose` pins against `cyrius.cyml`;
  - routing: the bare binary highlights, `--list-languages` equals
    `grammars/`, every grammar is reachable, the `.s` / `.asm` votes,
    new-name and same-name user grammars, overlay hygiene, the supplement,
    INFO-013;
  - coloured `--follow`: byte-identical to the one-shot render of the final
    file;
  - the cmdit CLI.

  Unit tests, both fuzz harnesses (also `--poison`), smoke on the plain,
  poison and DCE builds, and lint are green at 1.6.0.
- `scripts/smoke.sh` gates every 2026-10-31 finding. FINDING-017 needs
  `OWL_POISON_BIN` (a `cyrius build -D CYRIUS_POISON` binary) and
  NOTE-skips without one. Several gates need `script(1)`, `git` or
  `timeout`, and NOTE-skip without them.

## Dependencies

- **Cyrius stdlib** — **18 entries at 1.5.1**: `mmap` re-added, because
  sit 1.7.4+ maps git packs read-only. `cyrius deps` also vendors
  `lib/cmdit.cyr` (sit's CLI dep), which no bundle includes. (17 at
  1.4.9–1.5.0; 22 at 1.4.7–1.4.8,
  38 before that). owl's own viewer surface needs `syscalls`,
  `alloc`, `fmt`, `io`, `fs`, `str`, `string`, `vec`, `args`,
  `hashmap`, `process`, `assert`; sit-read's diff path adds
  `chrono`, `freelist`, `sankoch`, `sigil`, `patra`. The list is
  the union of `dist/sit-read.deps` (15) and `dist/vyakarana.deps`
  (4) plus owl's own surface, checked against the link. At 6.6.20
  the folded modules include their own requires: `sigil.cyr`
  brings `ct` / `bayan` / `random` / `keccak` / `tagged`, and
  `cyrius deps` materializes all 58 `lib/` files from a clean tree.
  The reasoning and the bump procedure are in `cyrius.cyml`'s
  `[deps]` comment.
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
- **vyakarana** 2.10.0 — tokenizer + **49** bundled grammars (nasm, mdx, lean at 1.5.1)
  (git-tag pinned in `[deps.vyakarana]`). 11 → 46 grammars across
  the 1.2.x/1.3.x cascade and 2.3.5's `openqasm`; 2.0.0
  streaming-API break migrated at 1.3.1/1.3.6; 2.4.0 made that
  streaming path chunk-invariant.
- **cmdit** 1.5.0 — the AGNOS getopt-long library (direct dependency since
  1.6.0; vendored before that as sit's own dependency). Parses owl's CLI.
  The tag is the one sit pins, so `lib/cmdit.cyr` is one file at one
  version. `cyrius.lock` carries 3 commit pins (cmdit, sit, vyakarana).
- **sit** 1.13.0 — AGNOS-native VCS (added 1.4.0). owl consumes its
  ADR-0009 library surface (`sit_repo_open` / `sit_diff_path` /
  `sit_repo_close` + `ann_*` accessors) for the VCS change-marker
  gutter, replacing the git fork+execve scaffold. Reaching it
  transitively (and resolved via the stdlib fold, not pins):
  patra (B+tree/WAL object store), sigil (hashing), sankoch
  (zlib/DEFLATE), sakshi (structured logging).

`grammars/` is a reference copy of vyakarana's grammars, not runtime data
(since 1.6.0 the binary carries them). Re-sync it wholesale on a vyakarana
bump (`git archive <tag> grammars/`) rather than editing in place. Smoke
checks `--list-languages` and per-grammar routing against it. A new grammar
needs no wiring in owl.

No FFI. Third-party deps: vyakarana (tokenizer), sit (VCS), cmdit (CLI).

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

**1.4.6 audit** — [`docs/audit/2026-08-22-audit.md`](../audit/2026-08-22-audit.md).
006–012 closed in 1.4.6; 013 was found afterwards by the fuzz harness
the audit asked for, and closed in 1.4.7:

| Finding | Severity | Fix |
|---------|----------|-----|
| 006 | **HIGH**   | Escape-strip classifier was unbounded — an unterminated sequence dropped the rest of the file (442-byte file → 0 rendered bytes, exit 0) and desynced the `-n` gutter. Bounded at a newline (no escape form admits a raw LF) and at `ESC_MAX_LEN` = 256; the byte that trips either bound is emitted. Hidden-content class, cf. CVE-2021-42574 (Trojan Source) |
| 007 | MEDIUM | `_config_resolve_path` appended `$XDG_CONFIG_HOME` / `$HOME` into a fixed `alloc(1024)`. Replaced with `_cfg_join`, sized from the operands, `alloc` checked, `PATH_MAX_SANE` (4096) refusal falling through to the next candidate |
| 008 | MEDIUM | Theme colours were unvalidated and reached `ansi_fg`'s 16-byte buffer via `_u16_to_ascii`'s 8-byte buffer. Validated to `-1..255` at parse time, `-1` additionally rejected for header/lineno (their call sites never test it), and `_u16_to_ascii` clamps regardless of caller |
| 009 | LOW    | Pager env forwarding handed `execve` a pointer to an entry left unterminated by the 16 KB `/proc/self/environ` read. Entries now accepted only if they terminate inside the buffer |
| 010 | LOW    | `--tabs` / `tabs =` unbounded; a 20-digit value also overflowed `i64` inside `atoi`. Rejected above 3 digits *before* `atoi`, then bounded to 0–64 |
| 011 | LOW    | `alloc()` return unchecked at ~27 sites. Load-bearing sites guarded, degrading into paths that already exist; `_user_ext_init` / `_user_theme_init` propagate failure to callers |
| 012 | LOW    | VCS marker table sized from sit's `max_line` with no ceiling, on repos that may be cloned from anywhere. Fails closed above `VCS_MAX_LINES` (16,777,216) |
| 013 | **HIGH** | *(1.4.7)* The ceiling added for 006 emitted the byte that tripped it — and that byte can be an ESC, so a sequence padded to exactly the ceiling followed by `ESC ] 52` wrote a raw ESC + a full clipboard-write sequence to the terminal, re-opening 001 inside the repair for 006. Found by `tests/owl.fcyr`. An ESC at the ceiling now starts a new sequence instead |

**2026-10-31 audit (1.5.3)** —
[`docs/audit/2026-10-31-audit.md`](../audit/2026-10-31-audit.md).
FINDING-014 – 039, all fixed in 1.5.3; the report has the full table.
Headlines:
- **014 HIGH:** stripping keyed on colour, so `NO_COLOR` passed file
  escapes.
- **015 MEDIUM:** the header file name was unsanitized.
- **016 MEDIUM:** stdin ignored ndjson and hex.
- **017 MEDIUM:** heap overflow in the user-grammar path.
- **018 MEDIUM:** a 16 MiB ndjson stream silently ended at 64 KiB.
- **019 MEDIUM:** an ancestor-FIFO hang.
- **020 MEDIUM:** gigabyte-scale VCS memory.
- **021 MEDIUM:** write errors ignored.
- **022 MEDIUM:** per-file memory growth.
- **023 MEDIUM:** gutter stack under-write.

Informational: INFO-004 – 008 are sit's (tree-bomb memory; unbounded lock
wait; unreadable vs unchanged; gitattributes; `commit_tree_hex`), INFO-009
vyakarana's (per-stream memory), INFO-010 cyrius's (argv via `/proc`), and
INFO-011 – 015 owl-side (CR/BS accepted; piped-tab expansion an open
decision; the `.bashrc` sniff and `--` deferred to 1.6.x; the spec
corrected).

Open informational items:

- ~~**INFO-002 (upstream, cyrius)**~~ — **closed upstream in cyrius
  6.5.36** ("`getenv` saw only the first 8 KB of the environment"), so
  it has been in effect since 1.4.8 (6.6.2), confirmed at 1.4.9. The
  stdlib now loads the whole environment block once and caches it
  (`_env_load`). Re-measured at 1.4.9 with a 12 KB variable ahead of
  `NO_COLOR`: 0 ESC bytes, against 207 without `NO_COLOR`. Original
  text: the stdlib's `getenv` (`lib/io.cyr`)
  reads `/proc/self/environ` into an 8 KB buffer, so any variable past
  that window is invisible. Measured on owl: `NO_COLOR=1` gives 0 ESC
  bytes with a small environment and **18** with one over 8 KB.
  `OWL_PAGER` / `PAGER` / `HOME` / `XDG_CONFIG_HOME` / `OWL_CONFIG` are
  affected identically. Not repaired locally — a private `getenv` would
  diverge from every other cyrius consumer. **Does not weaken escape
  stripping**: `_strip_active()` keys off `g_want_color`, which resolves
  from TTY detection, so a truncated environment can only fail to
  *enable* `NO_COLOR` — erring toward more decoration, never toward
  passing file-origin escapes through. *(That reasoning was itself wrong
  until 1.5.3: honouring `NO_COLOR` turned stripping off — FINDING-014.)*
- **INFO-003 (accepted)** — 8-bit C1 controls (`0x9B` CSI, `0x9D` OSC,
  `0x90` DCS) are not stripped. In UTF-8, the only mode in which owl's
  box-drawing frame renders, `0x80–0x9F` are continuation bytes;
  stripping them would corrupt every non-ASCII file. `less` and `bat`
  make the same call. Revisit only if owl grows a non-UTF-8 mode.

## Verification

All green at 1.5.3 on cyrius `6.7.18`:
- **builds:** host / DCE / `-D CYRIUS_POISON` / `--agnos` / DCE `--agnos` /
  `--aarch64`;
- **unit tests:** `cyrius test` 7/7;
- **fuzz:** `cyrius fuzz` 2/2 (escape, 6 invariants; config, 6), also under
  `--poison`;
- **smoke:** green on the plain and DCE builds with `OWL_POISON_BIN`; every
  new gate fails against 1.5.2;
- **lint:** 0 warnings.

Output A/B against 1.5.2 (52 corpus files × 11 modes plus 12 TTY runs) is
identical except highlighted `--line-range`, which loses only its empty
out-of-range SGR pairs.

All green at 1.5.2 on cyrius `6.7.18` (build, test, fuzz, lint, smoke
on plain + DCE; the markdown gates fail against 1.5.1). The 1.5.1
run, from a clean `lib/`:

- `cyrius build` host / DCE / `--agnos` / DCE `--agnos` /
  `--aarch64`: clean. The link warnings are sit's three `sign`
  placeholders plus `commit_tree_hex` (see §Toolchain).
- `cyrius test`: 7/7. `cyrius fuzz`: 1 passed (5 invariants).
  `tests/owl.bcyr` builds and runs. `cyrius deps --locked` and
  `--verify` (67/67) are clean.
- `sh scripts/smoke.sh`: green against the plain and the DCE binary.
  The new grammar gates and the git executable-file gate each fail
  against 1.5.0.
- `cyrius lint src/*.cyr`: 0 warnings, the same two deferrals.
- **Invariants over vyakarana 2.10.0's 52 corpus files:**
  - `-p` equals `cat`, 52/52;
  - colour-stripped highlighted output equals the file, 52/52
    (`--tabs=0`);
  - every `--format=ndjson` line parses.
- **Against 1.5.0, on the 49 files 1.5.0 can route:** `-p`, `-x` and
  colour-stripped decorated `-n` are identical; colour changed in 18,
  all deliberate vyakarana token-boundary changes.
- **VCS:** identical to 1.5.0 except where 1.5.0 was wrong (executable
  files in git repos; final-newline changes). Agrees with git on a
  20,000-line change/insert/delete.

At 1.5.0 on cyrius `6.7.9`, on the first build with no
source change:

- `cyrius build` host / DCE / `--agnos` / DCE `--agnos` /
  `--aarch64`: all clean. The only warnings are sit's three
  dead-path `sign` placeholders.
- `cyrius test`: 7/7. `cyrius fuzz`: 1 passed (5 invariants).
  `tests/owl.bcyr` builds and runs.
- `sh scripts/smoke.sh`: green against the plain and the DCE binary,
  including the native-sit-repo gutter gates.
- `cyrius lint src/*.cyr`: 0 warnings, the same two deferrals.
  `cyrius deps --locked`: exact.
- **6.7 migration audit of owl's source**: clean (see §Version).
- **A/B against the 1.4.9 binary**: identical in 288 runs (48 corpus
  files × highlight / `-p` / decorated `-n` / ndjson / `--theme=light`
  / `-x`). `--diff` and the TTY gutter are byte-identical, with the
  3 `~` markers on the 3 changed lines.

At 1.4.9 on cyrius `6.6.20`:

- `cyrius build` host / DCE / `--agnos` / DCE `--agnos`: all clean.
  The only warnings are sit's three documented dead-path `sign`
  placeholders; there is no duplicate-fn warning.
- `cyrius test`: 7 passed, 0 failed. Fuzz: OK, 5 invariants.
  `tests/owl.bcyr` builds and runs.
- `sh scripts/smoke.sh`: green against both the plain and the DCE
  binary. The native-sit-repo gutter gates ran with sit 1.13.0's
  CLI building the fixture.
- `cyrius lint src/*.cyr`: 0 warnings. The 20-line long-comment
  baseline is no longer reported. The two existing untracked
  deferrals at `src/main.cyr:13` / `:61` remain.
- **A/B against the 1.4.8 binary**: identical in all 192 runs (48
  vyakarana corpus files × highlight, `-p`, decorated `-n`,
  `--format=ndjson`). `--diff` and the TTY gutter (`~` markers) are
  byte-identical on two modified files.
- **INFO-002 re-measured closed** (see §Security).

At 1.4.7 on cyrius `6.5.35`:

- `cyrius build` host / `--agnos` / DCE / DCE `--agnos` — all clean
- `cyrius test` — 7 passed, 0 failed
- **`cyrius fuzz` — 1 passed, 0 failed (5 invariants).** Non-vacuous:
  three separate mutations of `src/escape.cyr` each fail it with a
  distinct message — `no-ceiling` → *classifier latched past
  ESC_MAX_LEN*, `no-lf` → *LF dropped in state 1*, `esc-at-ceiling` →
  *ESC was emitted*. Mutate the **ceiling block specifically**: the
  state-0 ESC check is textually identical and identically indented, and
  hitting it by mistake breaks stripping wholesale and produces a
  misleading A/B (this happened once).
- `sh scripts/smoke.sh` — M0–M8 plus the 1.4.6 audit gates plus the new
  FINDING-013 gate, which fails against the 1.4.6 classifier with
  `1 raw ESC byte(s) reached stdout at the escape ceiling`
- `cyrius lint src/*.cyr` — the two new modules are clean; the rest is
  unchanged from the 1.4.5 baseline
- **`--format=ndjson` round-trip** — a file containing every C0 byte,
  DEL, `"`, `\` and multi-byte UTF-8 (`é 中 🦉`) reconstructs from the
  emitted `text` fields to the original bytes exactly; a raw ESC comes
  out as `\u001b`
- **`--follow`** — verified against live appends: initial content, both
  appends, gutter numbering continuing across them, and an appended
  OSC 52 clipboard write stripped
- **Escape stripping** — OSC 52 / CSI SGR / OSC 0 + ST / DCS / `ESC 7`
  all stripped, zero ESC survivors
- **Plain mode** — byte-identical to `cat`, hostile inputs included
- **VCS gutter under sit-read** — `--diff` reports exactly the changed
  lines; markers render on a TTY

## Next

Forward work lives in [`roadmap.md`](roadmap.md). What is left of **1.6.x**
is blocked upstream:
- shell completions, on a cmdit fix;
- `--diff-from`, on a sit API that takes a ref;
- retiring the routing supplement, on vyakarana gaining those routes.

URL support and AGNOS theming are blocked too, with the reasons recorded
there.

Open follow-ups:

- **Upstream, from the 2026-10-31 audit.** Drafted in
  [`issues/`](issues/README.md), one file each with a repro, for the user to
  carry upstream. None is filed yet.
  - **sit:** INFO-004, the tree-bomb `.git` (impact HIGH: resolve one path
    by its components instead of flattening HEAD's tree); INFO-005, an
    unbounded lock wait; INFO-006, unreadable vs unchanged; INFO-007,
    gitattributes; INFO-008, `commit_tree_hex`.
  - **vyakarana:** INFO-009, per-stream memory.
  - **cyrius:** INFO-010, argv via `/proc`.
- **Upstream, from 1.6.0** (also in [`issues/`](issues/README.md)):
  - **vyakarana:** the 13 routes owl's supplement carries;
  - **cmdit:** completion scripts that complete nothing in a verb-less
    tool's first argument.
- **cyrius stdlib constant collisions.** Filed
  (`cyrius/docs/development/issues/2026-06-14-stdlib-constant-value-collisions.md`).

Closed and kept for the record: INFO-002, the `getenv` 8 KB window
(fixed in cyrius 6.5.36, re-verified at 1.4.9 and 1.5.1); sit-read
adoption (1.4.7); the `_stream_grow` collision (vyakarana 2.4.2, at
owl 1.4.8); the escape-classifier fuzz harness (1.4.7); the config and
theme parser harness (1.5.3); INFO-012 decided, INFO-013 / 014 closed
(1.6.0).
