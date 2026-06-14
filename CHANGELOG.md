# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.4.0] — 2026-06-14

Opens the **1.4.x feature line** with its headline item: the **SIT
dependency swap**. owl's VCS change-marker gutter no longer shells out
to `git diff` — it reads the working-tree-vs-HEAD diff directly from
[sit](https://github.com/MacCracken/sit)'s library (`sit_diff_path`).
Toolchain moves to cyrius **6.2.2** and vyakarana **2.2.3**.

### Changed

- **VCS markers now come from sit's library, not `git`.** `src/vcs.cyr`
  is rewritten: the `fork` + `execve("git", "diff", "--no-color",
  "-U0", …)` scaffold (and its hand-written unified-diff hunk parser)
  is replaced by `sit_repo_open(".")` → `sit_diff_path(repo, path)` →
  `sit_repo_close(repo)`, walking sit's LCS edit script
  (`ann_kind`/`ann_new`) into the same ADD/MOD/DEL per-line markers the
  gutter has always emitted. **The five-fn public interface
  (`vcs_compute_markers`, `vcs_mark_for_line`, `vcs_enabled`,
  `vcs_reset`, `set_style`) is unchanged** — main.cyr and the gutter
  renderer are untouched. A change run with adds-only → ADD, adds+dels
  → MOD, dels-only → DEL anchored on the line before the lost content,
  reproducing the prior git `-U0` semantics. Verified byte-for-byte in
  `scripts/smoke.sh` against a real sit repo fixture.
- **Toolchain pin: cyrius 6.1.14 → 6.2.2.**
- **Dep bump: vyakarana 2.2.1 → 2.2.3** (CI/docs/language-table touch-ups
  upstream; no owl-visible behaviour change).
- **New deps:** `sit 1.0.1` plus its transitive object-store stack
  (`patra 1.11.2`, `sigil 3.7.13`, `sankoch 2.3.1`, `sakshi 2.3.0`).
  owl's `[deps] stdlib` widened to sit's union (adds `slice`, `chrono`,
  `fnptr`, `thread`, `freelist`, `bayan`, `ct`, `keccak`, `bench`,
  `net`, `mmap`, `dynlib`, `fdlopen`, `tls`, `tls_native`, `ws`, `http`,
  `sandhi`) so `dist/sit.cyr`'s full bundle compiles; DCE strips the
  unused serve/wire/http surface from the binary.

### Security

- **The git subprocess class is closed by construction.** With no
  `fork`/`execve` on the VCS path, the shell-injection (audit
  FINDING-003) and path-quoting (FINDING-005) classes no longer have a
  subprocess to exploit — markers are computed in-process by sit's
  library. `-r` / escape-stripping defaults are unchanged.

### Fixed

- **patra symbol collision (filed + fixed upstream as patra 1.11.2).**
  The first co-link of vyakarana + sit→patra surfaced a silent
  symbol clash: patra's SQL-tokenizer `enum TokType` and vyakarana's
  public token-kind palette both defined `TK_IDENT` / `TK_COUNT` with
  different values. cyrius's flat namespace resolved both to one
  definition (no warning for enum-vs-`var` data symbols), so inside
  patra `TK_IDENT` became `0` — aliasing patra's own `TK_EOF = 0` —
  and every SQL identifier tokenized as EOF, breaking `patra_query`
  and making every diff line read as ADD. Fixed upstream by
  namespacing patra's enum (`TK_* → SQLT_*`, patra 1.11.2); the broader
  stdlib/lib constant-collision class is filed for the cyrius toolchain
  (`cyrius/docs/development/issues/2026-06-14-stdlib-constant-value-collisions.md`).

### Known limits

- **sit markers require running from the repo root.** sit 1.0.1's
  `sit_repo_open` does not search upward for a `.sit/` root, so markers
  appear only when owl is invoked from the directory holding `.sit/`
  with a repo-root-relative path. Outside a sit repo the gutter
  silently shows no markers (same no-op as git-not-a-repo before the
  swap). A directory tracked only by git shows no markers — there is no
  git fallback.
- **The agnos build target is temporarily disabled** (commented out in
  `ci.yml` / `release.yml`). owl's viewer core stays agnos-capable and
  the `#ifdef CYRIUS_TARGET_AGNOS` gates (pager / VCS / ioctl / readlink)
  remain in the source, but linking sit drags in its transitive stdlib
  (`tls`/`net`/`mmap`/…) which is not yet agnos-ported — agnos TLS is
  unimplemented and `lib/mmap.cyr` references `CLONE_VM`, absent from the
  agnos syscall variant. cyrius has no conditional deps, so the agnos
  build can't skip sit. Re-enable once sit's stack is agnos-clean; owl's
  VCS gutter already no-ops on agnos via the `#ifdef`.

### Verified

- `cyrius build` + `CYRIUS_DCE=1 cyrius build` clean under cyrius 6.2.2.
- `cyrius test` — unit gates green.
- `sh scripts/smoke.sh` — all M0–M8 gates green; the M6 marker gate and
  the `--diff` gate now build a real sit repo fixture (init → commit →
  modify) and assert MOD (`~`) on the changed line + ADD (`+`) on the
  appended line via `sit_diff_path`. The gates skip with a stderr NOTE
  (they do not silently pass) when no `sit` binary is found; set
  `OWL_SIT_BIN` in CI.
- `cyrius lint src/*.cyr` — 0 warnings.
- `owl --version --verbose` reports `owl 1.4.0` / `vyakarana 2.2.3` /
  `sit 1.0.1` / `cyrius 6.2.2`.

### Notes

- **Binary size jumps to ~2.6 MB** (DCE) from 1.3.x's ~459 KB — the
  cost of linking sit's object-store stack (patra B+tree store, sigil
  hashing, sankoch compression, sakshi). DCE strips sit's unused
  serve/wire/http/ssh surface but the diff path genuinely needs the
  store layer. Accepted for 1.4.0; the cyrius 6.x lib-streamlining arc
  (cleaner per-symbol includes) is expected to trim the sit-only tail.

## [1.3.8] — 2026-06-09

### Fixed

- **agnos: `owl FILE` printed its usage instead of the file.** Two AGNOS-only bugs,
  both surfaced by AGNOS's 1.44.x agnsh→owl delegation smoke (`agnsh-delegation-test.py`):
  1. **Entry form** — `var r = main();` ran at module scope, i.e. during gvar-init,
     *before* cycc emits the init-rsp capture (placed after gvar-inits as of cyrius
     6.1.14) — so `argc()`/`argv()` read 0/null and owl saw no positional → help.
     Fixed with the canonical bare top-level call (`_owl_entry();`).
  2. **fnptr** — cyrius pin **6.0.56 → 6.1.14** + re-vendored `lib/`, so `lib/fnptr.cyr`
     carries the `CYRIUS_TARGET_AGNOS` fncall branch (without it the allocator vtable
     returned 0 on agnos). Same class as kriya 1.1.2 / agnoshi 1.4.9.
  Now `owl -p FILE` (byte-identical) and decorated `owl FILE` read files on agnos —
  owl is AGNOS's `cat`. Host build + behavior unchanged.

## [1.3.7] — 2026-06-09

### Added

- **AGNOS target support — owl now builds `--agnos`** and runs as a file viewer on
  the sovereign OS. Cyrius pin bumped **5.10.10 → 6.0.56** (the release that landed
  `CYRIUS_TARGET_AGNOS`); compiles clean against 6.0.x with no source changes to the
  viewer/highlighter core. agnos-unavailable facilities are gated behind
  `#ifdef CYRIUS_TARGET_AGNOS`: the **pager** (`start_pager`/`stop_pager` — no
  fork/execve on agnos → output goes straight to stdout), the **VCS gutter**
  (`_run_git_diff` — no git/fork → disabled, same as git-not-installed on Linux),
  **terminal-size ioctl** (`_term_cols` → default 80 cols), **tty detection**
  (`is_tty` → reports tty so ANSI syntax-colour stays on; the fb console interprets
  SGR per agnos 1.43.2), and **`/proc/self/exe` readlink** (`_resolve_grammars_dir`
  → falls back to the compiled-in vyakarana grammars). Host (Linux) behavior is
  unchanged — every gate's `#ifndef` branch keeps the prior code. CI/release now
  build + ship the agnos binary (`owl_agnos`) alongside the host build.

## [1.3.6] — 2026-05-09

Final catchup patch on top of 1.3.1's vyakarana 2.x bump and
the single owl-side refactor in the catchup queue. **Lifts
`HIGHLIGHT_MAX` from 128 KB to 16 MB** by hoisting the
streaming-tokenizer lifecycle (`new` / `feed*` / `finish` /
`free`) out of `render_highlighted_buf` and up into the slurp
callers in `render_fd` (stdin) and `render_path` (file). The
read loop now feeds each `file_read` chunk to vyakarana
incrementally, so scanner state stays bounded by the live
in-progress span (vyakarana 2.0.1's rolling-buffer cap) rather
than total input. **The 1.3.x catchup window closes here.**

### Changed

- **`HIGHLIGHT_MAX` 131072 → 16777216** (128 KB → 16 MB) to
  match vyakarana's `VYK_STREAM_CAP`. Files between the old
  cap and the new cap now highlight cleanly; previously they
  fell back to plain rendering with a `too large for
  highlighting (> 128 KB)` stderr notice. Allocation here is
  bump-allocator virtual address space; physical pages commit
  lazily on write so small files don't pay the 16 MB cost in
  practice.
- **`render_highlighted_buf` replaced by
  `_render_highlighted_with_tb(buf, n, tb)`.** The byte-by-byte
  render loop that walks the slurped buffer alongside a
  populated tokenbuf is now keyed off the tokenbuf the slurp
  caller produces, not a `(buf, lang)` pair the function
  tokenizes itself. The old wrapper is removed — both call
  sites (`render_fd`, `render_path`) drive the streaming
  tokenizer themselves and forward to the helper, so the
  one-shot wrapper had no callers and would have been
  speculative API surface (per CLAUDE.md "no premature
  abstraction").
- **Stdin slurp path (`render_fd`)** now opens the stream
  before the read loop; calls `tokenize_stream_feed(s, big +
  total, got)` after each successful `file_read`; on overflow
  frees the stream and falls back to plain streaming with the
  same shape as before; on success calls
  `tokenize_stream_finish` + `_render_highlighted_with_tb`. If
  the stream-ctor fails (grammar dropped between the
  `has_grammar` probe and the read loop), falls back to
  `render_fd_loop` cleanly.
- **File slurp path (`render_path`)** matches the stdin path's
  shape, with one extra wrinkle: the `first_n` bytes already
  buffered in `first_buf` (read upstream for binary detection)
  get fed via `tokenize_stream_feed(s, big, first_n)` before
  the read loop body so the stream sees the file in order.
- **Fallback notice tail** changed from `KB)` to `MB)` and the
  printed-cap math from `HIGHLIGHT_MAX / 1024` to `/ 1048576`
  — at 16 MB, KB units would print "16384 KB" which is harder
  to read than "16 MB". Local var rename `kb` → `mb` at both
  notice sites.

### Verified

- `cyrius build` + `CYRIUS_DCE=1 cyrius build` clean under
  pinned cyrius 5.10.10.
- `cyrius test` — unit gates green.
- `sh scripts/smoke.sh` — all M0–M8 gates green; new gate
  generates a ~256 KB Python fixture (well past the old
  128 KB cap, well under the new 16 MB cap), renders it under
  `--color=always`, and asserts both that ANSI escapes appear
  AND that the `too large for highlighting` stderr notice
  does NOT fire. Same gate runs for the stdin path via
  `--language=python` redirect.
- `owl --version --verbose` reports `vyakarana 2.2.1` /
  `cyrius 5.10.10`.

### Notes

- **The 1.3.x catchup window is closed.** All seven 2.1.x
  grammars wired (1.3.2–1.3.5) and the 2.0.1-unblocked
  HIGHLIGHT_MAX lift shipped (1.3.6). Forward work moves to
  whatever upstream releases next — sit's library export
  remains the only externally-tracked dependency for the SIT
  VCS swap.
- **Truly streaming render (no full-file resident) is a
  larger refactor.** owl still keeps the slurped source
  resident for the byte-by-byte render walk; the lift here
  caps owl-side memory at 16 MB max and vyakarana-side at
  the rolling-buffer span (typically a few KB). A full
  streaming render would interleave `file_read` →
  `tokenize_stream_feed` → `tokenize_stream_drain` →
  per-chunk render-and-discard, with bookkeeping for tokens
  that span chunk boundaries. Out of scope for this patch;
  filed for whenever a multi-MB-per-line input shows up.

## [1.3.5] — 2026-05-09

Fourth catchup patch on top of 1.3.1's vyakarana 2.x bump.
Wires the **vyakarana 2.1.3 grammar** (Terraform / HCL) into
owl's language table and bootstrap. Closes the 2.1.x grammar
batch — 2.1.x added 7 grammars (PowerShell, Crystal, Julia,
Vue, Svelte, Nix, Terraform); owl 1.3.2–1.3.5 wired all
seven. No toolchain pin movement.

### Added

- **Terraform / HCL highlighting.** `.tf` / `.tfvars` / `.hcl`
  extension dispatch + ANSI tokenization via
  `grammars/terraform.cyml`. The HashiCorp Configuration
  Language that Terraform / Packer / Vault / Nomad / Consul
  all consume; the upstream grammar is named `terraform`
  because that's what most users will search for, but it
  covers any HCL-shaped input. Grammar handles both `#` and
  `//` line comments + `/* … */` block comments, the `=>`
  for-expression operator (longest-match before `=`), the
  `...` spread operator (3-byte), and kebab-case idents
  (`-` in `ident_cont`) for `aws_s3_bucket` /
  `azurerm_role_assignment` / `my-bucket` style names.
  Block syntax `resource "type" "name" { ... }` tokenizes
  naturally — no special block-header token kind needed.

### Changed

- **`LANG_COUNT` 44 → 45** with `lang_name(44)` =
  `"terraform"`.
- **`docs/grammar-coverage.md`** updated with three terraform
  gap rows: heredocs (variable terminator); string
  interpolation `${expr}` per ADR 0003; splat shorthand
  `aws_instance.web.*.id` where `*` tokenizes as a 1-byte op
  amid the dotted access.

### Verified

- `cyrius build` + `CYRIUS_DCE=1 cyrius build` clean under
  pinned cyrius 5.10.10.
- `cyrius test` — unit gates green.
- `sh scripts/smoke.sh` — all M0–M8 gates green; new gates
  lock `.tf` / `.tfvars` / `.hcl` → `(terraform)` extension
  detection (all three exts route to the same grammar) and
  ANSI emission for `--language=terraform` (the `=>` for-
  expression operator + kebab-case idents exercise the
  Terraform-specific paths).
- `owl --version --verbose` reports `vyakarana 2.2.1` /
  `cyrius 5.10.10`.

### Notes

- **2.1.x batch closed for owl.** The seven grammars vyakarana
  shipped during the 2.1.x window (2.1.0 PowerShell + Crystal
  + Julia; 2.1.1 Vue + Svelte; 2.1.2 Nix; 2.1.3 Terraform)
  are all wired. Catchup queue advances to 1.3.6 — the
  HIGHLIGHT_MAX lift unblocked by vyakarana 2.0.1's rolling-
  buffer scanner.

## [1.3.4] — 2026-05-09

Third catchup patch on top of 1.3.1's vyakarana 2.x bump.
Wires the **vyakarana 2.1.2 grammar** (Nix) into owl's
language table and bootstrap. No toolchain pin movement —
still cyrius 5.10.10 + vyakarana 2.2.1; the grammar file has
been in `dist/vyakarana.cyr` since 1.3.1.

### Added

- **Nix highlighting.** `.nix` extension dispatch + ANSI
  tokenization via `grammars/nix.cyml`. The functional
  configuration language behind NixOS, home-manager, and
  the Nix package ecosystem. Grammar handles Nix-specific
  quirks: `//` is set merge / update (NOT a line comment;
  longest-match before anything else); `++` list
  concatenation; `->` implication; `?` has-attribute test;
  `@` "as" pattern in function args. Idents accept `'` and
  `-` so Haskell-prime names (`iter'`, `prev'`) and
  kebab-case names (`home-manager`, `nixpkgs-unstable`)
  tokenize as a single ident. `''…''` indented multi-line
  strings via 2-byte pair rule. `/* … */` block comments +
  `#` line comments.

### Changed

- **`LANG_COUNT` 43 → 44** with `lang_name(43)` = `"nix"`.
- **`docs/grammar-coverage.md`** updated with four nix gap
  rows (string interpolation per ADR 0003, path literals,
  indented-string escape edge cases, URL literals).

### Verified

- `cyrius build` + `CYRIUS_DCE=1 cyrius build` clean.
- `cyrius test` — unit gates green.
- `sh scripts/smoke.sh` — all M0–M8 gates green; new gates
  lock `.nix` → `(nix)` extension detection and ANSI
  emission for `--language=nix` (the `let` keyword + `//`
  set-merge op + kebab-case ident exercise the Nix-specific
  paths).
- `owl --version --verbose` reports `vyakarana 2.2.1` /
  `cyrius 5.10.10`.

### Notes

- Catchup queue advances to 1.3.5 (vyakarana 2.1.3 —
  Terraform / HCL).

## [1.3.3] — 2026-05-09

Second catchup patch on top of 1.3.1's vyakarana 2.x bump.
Wires the **vyakarana 2.1.1 SFC batch** (Vue, Svelte) into
owl's language table and bootstrap, AND introduces a new
top-level reference doc — `docs/grammar-coverage.md` — that
aggregates the per-grammar gap notes scattered across the 43
bundled `grammars/*.cyml` files into a single discoverable
table.

### Added

- **Vue SFC highlighting.** `.vue` extension dispatch + ANSI
  tokenization via `grammars/vue.cyml`. HTML-shaped outer
  tokenizer with Vue-shorthand prefixes (`@` for `v-on`, `#`
  for `v-slot`) in operators. `<script>` bodies route through
  the JavaScript grammar via vyakarana's compose rule;
  `<style>` bodies route through CSS. `<template>` content
  stays with the outer Vue tokenizer so `@click` / `:prop`
  attribute shorthand renders distinctly.
- **Svelte SFC highlighting.** `.svelte` extension dispatch +
  ANSI tokenization via `grammars/svelte.cyml`. Same shape as
  Vue minus the `<template>` block (Svelte's template lives at
  the file's top level). `$` operator covers reactive
  declarations (`$:`).
- **`docs/grammar-coverage.md`** — new top-level reference
  doc. Aggregates the "Known gaps" / "Documented limitations"
  / "Known cosmetic gaps" notes that live in every
  `grammars/*.cyml` header into a single scannable table:
  one row per gap with columns for **language**, **gap**,
  **severity** (cosmetic vs. semantic), **in sample corpus?**,
  and **tracking ADR**. Lead section identifies the eight
  recurring gap shapes (string interpolation per
  [vyakarana ADR 0003](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0003-string-expansion-not-retokenized.md);
  variable-length delimiters; numeric underscores; float
  literals split on `.`; C-family char-literal split — closed
  by [ADR 0010](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0010-char-literal-default.md)
  for grammars that opt in; regex literals; compose-rule
  attribute-bearing-tag fallback per
  [ADR 0013](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0013-grammar-composition.md);
  predeclared idents staying as `TK_IDENT` per
  [ADR 0004](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0004-shell-builtins-as-ident.md))
  so the per-grammar table doesn't have to repeat each
  rationale. Grammar file headers stay the source of truth;
  the new doc is a reader-friendly index.

### Changed

- **`LANG_COUNT` 41 → 43** with `lang_name(41)` = `"vue"`,
  `lang_name(42)` = `"svelte"`.
- **Documentation reference set extended.** `state.md`
  references `grammar-coverage.md`; future grammar bumps
  refresh both files in the same patch.

### Verified

- `cyrius build` + `CYRIUS_DCE=1 cyrius build` clean.
- `cyrius test` — unit gates green.
- `sh scripts/smoke.sh` — all M0–M8 gates green; new gates
  lock `.vue` → `(vue)`, `.svelte` → `(svelte)` extension
  detection and Vue `@click` shorthand emits ANSI under
  `--color=always --language=vue`.
- `owl --version --verbose` reports `vyakarana 2.2.1` /
  `cyrius 5.10.10`.

### Notes

- Catchup queue advances to 1.3.4 (vyakarana 2.1.2 — Nix).
- The grammar-coverage doc is a discoverability win, not a
  scope expansion: every gap was already documented
  somewhere. Adding new grammars in future patches needs an
  entry in the table at the same time, alongside the existing
  per-language wiring template.

## [1.3.2] — 2026-05-09

First catchup patch on top of 1.3.1's vyakarana 2.x bump.
Wires the **vyakarana 2.1.0 grammar batch** (PowerShell,
Crystal, Julia) into owl's language table and bootstrap. No
toolchain pin movement — still cyrius 5.10.10 + vyakarana
2.2.1; the grammar files have been in `dist/vyakarana.cyr`
since 1.3.1, this patch just lights up owl's wiring.

### Added

- **PowerShell highlighting.** `.ps1` / `.psm1` / `.psd1`
  extension dispatch + ANSI tokenization via
  `grammars/powershell.cyml`. Verb-Noun cmdlets
  (`Get-ChildItem`, `Set-Variable`) tokenize as one ident
  (`-` in `ident_cont`); alphabetic operators (`-eq`,
  `-and`, `-match`) longest-match before bare `-`. Variables
  via `$` in `ident_start` (`$args`, `$_`,
  `$PSScriptRoot`). Block + line comments. Both string forms
  (single literal, double interpolated). Case-insensitive
  keywords. Shebangs: `pwsh`, `powershell`.
- **Crystal highlighting.** `.cr` extension dispatch + ANSI
  tokenization via `grammars/crystal.cyml`. Ruby-shaped
  tokenizer with `?` and `!` in `ident_cont` for predicate-
  style and mutating-method names (`empty?`, `push!`,
  `is_a?`). `@` in `ident_start` for instance vars. The
  `<=>`, `===`, `=~`, range `..`/`...`, splat `**` operator
  surface.
- **Julia highlighting.** `.jl` extension dispatch + ANSI
  tokenization via `grammars/julia.cyml`. `@` in
  `ident_start` for macros (`@show`, `@time`,
  `@inbounds`). `!` in `ident_cont` for mutating-method
  names (`push!`, `sort!`). `::` type annotations. Triple-
  quoted strings (`"""..."""`) and backtick command
  literals. Block comments (`#=...=#`) + line comments
  (`#`).

### Changed

- **`LANG_COUNT` 38 → 41** with `lang_name(38)` =
  `"powershell"`, `lang_name(39)` = `"crystal"`,
  `lang_name(40)` = `"julia"`.
- **Shebang detection** picks up `pwsh` / `powershell` →
  `powershell` per the standard `lang_shebangs(i)` table.

### Verified

- `cyrius build` + `CYRIUS_DCE=1 cyrius build` clean.
- `cyrius test` — unit gates green.
- `sh scripts/smoke.sh` — all M0–M8 gates green; new gates
  lock `.ps1` → `(powershell)`, `.cr` → `(crystal)`, `.jl` →
  `(julia)` extension detection, `#!/usr/bin/env pwsh` →
  `(powershell)` shebang detection, and ANSI emission for
  `--language=julia` (the `@show` macro exercises the `@`-in-
  ident_start trick).
- `owl --version --verbose` reports `vyakarana 2.2.1` /
  `cyrius 5.10.10`.

### Notes

- Catchup queue advances to 1.3.3 (vyakarana 2.1.1 — Vue +
  Svelte SFC).

## [1.3.1] — 2026-05-09

Toolchain bump to vyakarana 2.x. Cyrius pin moves
5.9.43 → 5.10.10; vyakarana tag moves 1.11.0 → 2.2.1. The
load-bearing piece is the **breaking-API migration from
`tokenize_source(src, lang)` to the push-based streaming
primitive** introduced by vyakarana 2.0.0
([ADR 0017](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0017-streaming-api.md)).
This cut delivers the migration with no other behavioural
changes — per the catchup-via-patches plan, the seven new
grammars in vyakarana's 2.1.x window (powershell, crystal,
julia, vue, svelte, nix, terraform) and the
`HIGHLIGHT_MAX` lift unblocked by 2.0.1's rolling-buffer
scanner are deferred to subsequent 1.3.x patches.

### Changed

- **`render_highlighted_buf` migrated to the streaming
  tokenize API.** The single owl call site at
  `src/main.cyr:1220` switches from
  `tokenize_source(buf, lang)` to the five-call dance:
  `tokenize_stream_new(lang)`, `tokenbuf_new()`,
  `tokenize_stream_feed(s, buf, n)`,
  `tokenize_stream_finish(s, tb)`, `tokenize_stream_free(s)`.
  Behaviour unchanged — owl drives a one-shot feed because
  the highlight path is HIGHLIGHT_MAX-bounded (128 KB).
  The streaming benefit (memory bound by longest in-progress
  span, not total input) lands when owl rewires the slurp
  path to multi-chunk feed; tracked as a 1.3.x catchup
  patch.
- **Comments updated.** Three sites at `src/main.cyr` that
  referenced `tokenize_source uses strlen internally` (the
  reason owl always alloc'd HIGHLIGHT_MAX + 1) updated. The
  trailing-NUL is preserved defensively for cstr-shape paths
  but is no longer load-bearing for tokenization itself —
  streaming feed takes explicit length.
- **Toolchain pin bump: cyrius 5.9.43 → 5.10.10.** No source
  changes required for the cyrius bump itself.
- **Toolchain dep bump: vyakarana 1.11.0 → 2.2.1.** Public
  surface owl uses today: streaming primitive (new),
  tokenbuf accessors (`tokenbuf_count`, `tokenbuf_start`,
  `tokenbuf_len`, `tokenbuf_kind` — unchanged), kind
  constants + `kind_name` (unchanged), `has_grammar`,
  `grammar_load`, `registry_init`, `registry_add`,
  `_grammars_bootstrapped` flag (all unchanged). The 1.12.0
  → 1.13.3 prep window added fuzz/audit/perf-baseline work
  with no public surface changes. 2.1.0 → 2.1.5 added 7
  grammars (deferred). 2.2.0 was a vyakarana-internal cyrius
  pin bump. 2.2.1 fixed a streaming compose-rule prefix-
  buffering bug owl doesn't currently exercise (HTML/Vue/
  Markdown compose rules), but the fix lands transparently
  via the dep bundle.

### Fixed

The first build attempt of 1.3.1 surfaced two coupled bugs —
both fixed in this same cut:

- **`detect_language_from_content` collision with vyakarana
  2.x.** vyakarana's pre-2.0 prep wave added a public
  `detect_language_from_content(src, src_len)` that ships in
  `dist/vyakarana.cyr`'s `[lib] modules`. owl's own
  `detect_language_from_content(buf, n)` from the M1.4
  content-detection drop (1.1.4) collided with it; cyrius's
  "last definition wins" warning became a CI failure once
  2.2.1 pulled the function into the lib bundle. Renamed
  owl's to `_owl_detect_language_from_content` per the
  existing `_owl_*` convention used elsewhere
  (`_owl_load_grammar`, `_owl_bootstrap_grammars`). Single
  caller in `src/main.cyr` updated. owl's content-detection
  semantics unchanged — anchored `{`/`[`/`---`/`#` patterns
  for json/toml/yaml/markdown routing.
- **CI workflow installed cyrius into the wrong layout.**
  Pre-1.3.1 the `Install Cyrius toolchain` step in
  `.github/workflows/ci.yml` and `release.yml` dumped the
  release tarball flat into `~/.cyrius/{bin,lib}/`. The
  cyrius binary actually locates per-arch stdlib peers (e.g.
  `lib/syscalls_x86_64_linux.cyr` — where `SYS_DUP` lives)
  via `~/.cyrius/versions/<active>/lib/`, the cyriusly-shape
  versioned layout. Flat-only worked by accident for projects
  whose source didn't reach an arch-peer-only symbol; owl's
  pager.cyr touches `SYS_DUP` and broke loudly under the
  vyakarana 2.x bump (the bigger include surface raised the
  cost of stdlib-resolution failure). Both workflows now
  install into `~/.cyrius/versions/<v>/{bin,lib}/`, symlink
  `~/.cyrius/{bin,lib}` to the active version, and write
  `~/.cyrius/current` to record it. Reproduced locally by
  faithfully replaying the workflow's tarball-install steps
  in a clean `HOME`, then verified the patched layout
  produces a green build.

### Verified

- `cyrius build` + `CYRIUS_DCE=1 cyrius build` clean under
  both layouts:
  - cyriusly-managed local install.
  - The exact CI-replica path (faithful tarball install into
    a clean `$HOME` with the new versioned-tree layout +
    symlinks). Pre-fix this path failed with
    `error:src/pager.cyr:110: undefined variable 'SYS_DUP'`.
- `cyrius test` — unit gates green.
- `sh scripts/smoke.sh` — all M0–M8 gates green; existing
  highlight smoke (`.rs` ANSI emission, `.go` / `.zig` /
  `.cyml` / `.ll` / `.java` / `.sql` / `…` extension
  detection + ANSI) covers the migrated path end-to-end.
- `cyrius lint` — duplicate-fn warning gone; no new warnings
  introduced.
- `owl --version --verbose` reports `vyakarana 2.2.1` /
  `cyrius 5.10.10`.

### Notes

- **`HIGHLIGHT_MAX` lift now unblocked upstream.**
  vyakarana 2.0.1's rolling-buffer scanner caps live span
  at 16 MB rather than total input. owl can now highlight
  files of arbitrary size as long as the longest
  in-progress span (block comment, multi-line string,
  fenced body) fits in 16 MB. The lift work is mechanical
  given the streaming primitive is already in place — drive
  `tokenize_stream_feed` per chunk during the slurp instead
  of one-shot at the end. Tracked as a 1.3.x catchup patch.
- **7 vyakarana 2.1.x grammars deferred.** powershell +
  crystal + julia (2.1.0); vue + svelte (2.1.1); nix
  (2.1.2); terraform (2.1.3). Each lands in its own owl
  patch following the 1.2.x cascade pattern (same
  per-language wiring template — `lang_name` / `lang_exts`
  entry in `src/lang.cyr` + `_owl_load_grammar` call in
  `_owl_bootstrap_grammars` + smoke gate).
- **SIT VCS swap stays parked.** Sit is at 0.7.6 (no
  `[lib]`, no `dist/sit.cyr`); the v0.7.7 library-export
  slot owl filed on sit's roadmap hasn't shipped yet.

## [1.3.0] — 2026-05-08

Toolchain refresh + vyakarana 1.8.0 → 1.11.0 cascade in one cut.
Cyrius pin moves 5.9.41 → 5.9.43 (two patch slots, compiler-internal
fixes). vyakarana spans three minors but only one carries owl-side
work — 1.9.0 brings two new grammars (`cyml`, `llvm_ir`) and
redirects `.cyml` from `toml` to the new `cyml` grammar. 1.10.0
formalises a theme-palette contract (architecture note 004) that
owl now honours by dispatching `theme_token_color` via
`kind_name(k)` strings. 1.11.0 adds an LSP semantic-tokens bridge
(`src/lsp.cyr`) — useful to editor consumers like cyim, not to
owl's viewer surface; consumed for free as part of the dep bundle.

### Added

- **CYML highlighting.** `.cyml` extension dispatch + ANSI
  tokenization via `grammars/cyml.cyml` (vyakarana 1.9.0).
  Self-hosting payoff for the AGNOS toolchain — owl now renders
  cyrius dependency manifests, yukti config, vidya content
  samples, and its own `cyrius.cyml` through one bundled grammar.
  `---` 3-byte operator (CYML's TOML-header / markdown-body
  delimiter) tokenizes correctly; backtick spans render as
  string.
- **LLVM-IR highlighting.** `.ll` extension dispatch + ANSI
  tokenization via `grammars/llvm_ir.cyml`. `@global`,
  `%struct.Token`, `!llvm.module.flags` all tokenize as a single
  ident (vyakarana 1.9.0 puts `@`/`%`/`!` in `ident_start`).
  Comprehensive keyword set covers type literals, instruction
  set, function attributes, calling conventions, and comparison
  predicates.

### Changed

- **`.cyml` redirected from `toml` → `cyml`.** At 1.2.6,
  `lang_exts(8)` included both `.toml` and `.cyml` so cyrius
  manifests labeled as `(toml)`. vyakarana 1.9.0 ships a
  dedicated `cyml` grammar that handles the format's `---`
  delimiter and backtick-string shape; owl's `lang_exts(8)`
  drops `.cyml` and a new `lang_name(36) = "cyml"` /
  `lang_exts(36) = ".cyml"` entry takes over. Header label
  changes from `(toml)` to `(cyml)` for any `.cyml` file.
  Regression-locked in `scripts/smoke.sh`.
- **`LANG_COUNT` 36 → 38** with `lang_name(36)` = `"cyml"`,
  `lang_name(37)` = `"llvm_ir"`.
- **`theme_token_color` now dispatches via `kind_name(k)`
  strings** per vyakarana 1.10.0 architecture note 004
  (theme-palette contract: kind_name strings are the stable
  identifier across the 1.x line; the integer enum is an
  implementation detail). Switches `if (kind == 1) { … }` to
  `if (streq(kind_name(kind), "keyword") == 1) { … }`. Same
  10-color palette per bundled theme; same return values; the
  diff is conformance, not behaviour. If a future vyakarana cut
  renames any of the 10 canonical strings, owl breaks loudly at
  the streq site instead of silently mis-coloring on a
  re-ordered enum. The user-theme path was already string-keyed
  at the loader (CYML `token.<name>` keys); user-theme storage
  stays integer-indexed but the lookup now uses
  `kind_is_valid(kind)` rather than the open-coded
  `kind < 0 || kind > 9` bounds check.
- **Toolchain pin bump: cyrius 5.9.41 → 5.9.43.** No source
  changes required.
- **Toolchain dep bump: vyakarana 1.8.0 → 1.11.0.** Public
  tokenizer API unchanged across the window. 1.9.0's grammar
  additions are wired here. 1.10.0's `vyk --theme=` CLI flag is
  not consumed (CLI-only, not in `[lib] modules`); the
  consumer-integration guide and architecture note 004 are
  documentation owl now conforms to. 1.11.0's
  `lsp_kind_from_token_type` / `lsp_kind_from_standard_index`
  bridge is editor-consumer surface (cyim et al.), not used by
  owl's viewer path; ships in the dep bundle but DCE-strips
  cleanly.
- **Minor version bump.** First minor since 1.2.0 — closes the
  vyakarana 1.9.0 grammar batch and the 1.10.0 contract
  conformance in one cut. The 1.10.0 / 1.11.0 dep bumps that
  carry no owl source changes ride along rather than each
  consuming their own patch slot (no point shipping a CHANGELOG
  entry that says "no source changes").

### Verified

- `cyrius build` + `CYRIUS_DCE=1 cyrius build` clean.
- `cyrius test` — unit gates green.
- `sh scripts/smoke.sh` — all M0–M8 gates green; new gates lock
  `.cyml` → `(cyml)` (with explicit regression check against the
  prior `(toml)` label), `.ll` → `(llvm_ir)`, and ANSI emission
  for both under `--color=always --language=…` from stdin.
- `owl --version --verbose` reports `vyakarana 1.11.0` /
  `cyrius 5.9.43`.

### Notes

- SIT VCS swap stays parked. Sit is at 0.7.6 (no `[lib]` clause,
  no `dist/sit.cyr`); the v0.7.7 library-export slot owl filed
  on sit's roadmap hasn't shipped yet.
- vyakarana 1.10.0's pre-2.0 prep wave is now visible — the
  consumer-integration guide and architecture note 004 are
  signposts that the 2.x break (streaming tokenizer; lifts
  owl's `HIGHLIGHT_MAX` cap) is coming. Streaming tokenizer
  itself is still parked on vyakarana 2.x.

## [1.2.6] — 2026-05-08

vyakarana 1.7.0 → 1.8.0 — DevOps + infrastructure batch
(Dockerfile, Makefile, INI). Closes the "Further bundled-grammar
broadening" 2.x backlog item; the bundled palette now stands at
36 grammars / 35 named languages.

### Added

- **Dockerfile highlighting.** Filename-shape detection (no
  extension): exact basename `Dockerfile` / `Containerfile`, or
  any `name.Dockerfile` / `name.Containerfile` suffix per
  vyakarana 1.8.0 wiring. ANSI tokenization via `grammars/
  dockerfile.cyml`. Case-insensitive instruction heads (`FROM`
  / `from` / `From`) work via vyakarana ADR 0011 — owl gets the
  fold for free.
- **Makefile highlighting.** Filename-shape detection: exact
  basename match for `Makefile`, `makefile`, `GNUmakefile`. ANSI
  tokenization via `grammars/makefile.cyml`. All four GNU Make
  assignment forms (`=` / `:=` / `?=` / `+=`) and the conditional /
  include / define / export keyword set route through the same
  default scanner.
- **INI highlighting.** `.ini`/`.conf`/`.cfg`/`.properties`
  extension dispatch and ANSI tokenization via `grammars/ini.cyml`.
  Dotted-key sections (`[auth.providers.github]`) tokenize as a
  single ident (`.` in `ident_cont` per vyakarana grammar).

### Changed

- **Filename-shape detection added to `src/lang.cyr`.** New
  helpers `_path_ends_with` (case-sensitive end-match) and
  `_path_filename_match` (exact basename, `/<name>` basename, or
  `.<name>` suffix) feed the new dispatch block in
  `detect_language_from_path` that runs before the extension
  table. Required because Dockerfile/Makefile carry no
  conventional extension.
- **`LANG_COUNT` 33 → 36** with `lang_name(33)` =
  `"dockerfile"`, `lang_name(34)` = `"makefile"`, `lang_name(35)`
  = `"ini"`.
- **Toolchain dep bump: vyakarana 1.7.0 → 1.8.0.**

### Verified

- `cyrius build` + `CYRIUS_DCE=1 cyrius build` clean.
- `cyrius test` — unit gates green.
- `sh scripts/smoke.sh` — all M0–M8 gates green; new gates lock
  filename-shape detection for Dockerfile (basename + `.Dockerfile`
  suffix + Containerfile alias), Makefile (uppercase, lowercase,
  `GNUmakefile`), and `.ini` extension dispatch.
- `owl --version --verbose` reports `vyakarana 1.8.0` /
  `cyrius 5.9.41`.

## [1.2.5] — 2026-05-08

vyakarana 1.6.0 → 1.7.0 — markup + styling batch (HTML, XML,
CSS, SCSS).

### Added

- **HTML highlighting.** `.html`/`.htm` extension dispatch +
  ANSI tokenization via `grammars/html.cyml`. `<!-- … -->` block
  comments via vyakarana's pair-rule shape.
- **XML highlighting.** `.xml`/`.xsl`/`.xsd`/`.svg` extension
  dispatch + `grammars/xml.cyml`. `<![CDATA[ … ]]>` data
  sections tokenize as a single string per vyakarana grammar.
- **CSS highlighting.** `.css` extension dispatch +
  `grammars/css.cyml`. `@media` / `#hero` / `--color-bg` (CSS
  custom properties) all tokenize cleanly.
- **SCSS highlighting.** `.scss`/`.sass` extension dispatch +
  `grammars/scss.cyml`. `$variable` syntax + `//` line comments
  + the SCSS at-rule keyword set.

### Changed

- **`LANG_COUNT` 29 → 33** with the four new entries.
- **Toolchain dep bump: vyakarana 1.6.0 → 1.7.0.**

### Verified

- `sh scripts/smoke.sh` locks `.html` → `(html)`, `.xml` →
  `(xml)`, `.css` → `(css)`, `.scss` → `(scss)` extension
  detection.

## [1.2.4] — 2026-05-08

vyakarana 1.5.0 → 1.6.0 — data / query / IDL batch (SQL,
GraphQL, Protobuf). Picks up the new
`case_insensitive_keywords` default from vyakarana ADR 0011 by
proxy: enabled in `grammars/sql.cyml`, so `SELECT` / `select` /
`Select` all keyword-color through owl's existing tokenize +
ANSI emission path with no source changes on the owl side.

### Added

- **SQL highlighting.** `.sql` extension dispatch + ANSI
  tokenization via `grammars/sql.cyml`. ANSI SQL:1992 baseline;
  dialect extensions (PostgreSQL / MySQL / SQLite / T-SQL)
  documented in the grammar header as fork candidates.
- **GraphQL highlighting.** `.graphql`/`.gql` extension dispatch
  + `grammars/graphql.cyml`. `$variable` and `@directive` syntax
  tokenize as one ident.
- **Protobuf highlighting.** `.proto` extension dispatch +
  `grammars/protobuf.cyml`. proto2 + proto3 surface covered.

### Changed

- **`LANG_COUNT` 26 → 29** with the three new entries.
- **Toolchain dep bump: vyakarana 1.5.0 → 1.6.0.**

### Verified

- `sh scripts/smoke.sh` locks `.sql` → `(sql)` and the
  case-insensitive ANSI gate (`select * from users;` lower-case
  still emits ANSI keyword spans through vyakarana ADR 0011).

## [1.2.3] — 2026-05-08

vyakarana 1.4.0 → 1.5.0 — functional tier batch (Elixir, OCaml,
Haskell). No new vyakarana scanner extensions; all three grammars
sit on top of the 1.2.1 `char_literal` pipeline (OCaml's `'a` type
variables fall through the same yield path Rust lifetimes use).

### Added

- **Elixir highlighting.** `.ex`/`.exs` extension dispatch +
  ANSI tokenization via `grammars/elixir.cyml`. Module attribute
  (`@`) syntax and the `|>` / `<-` / `->` / `=>` / `::` operator
  set covered.
- **OCaml highlighting.** `.ml`/`.mli` extension dispatch +
  `grammars/ocaml.cyml`. `(* … *)` block comments via vyakarana
  pair rule.
- **Haskell highlighting.** `.hs`/`.lhs` extension dispatch +
  `grammars/haskell.cyml`. Prime-suffixed identifiers (`rest'`,
  `f''`) tokenize as a single ident; the monadic / applicative
  operator surface (`>>=`, `>>`, `<$>`, `<*>`, `<|>`) keyword-
  colors through the standard pipeline.
- **Shebang hints.** Added `elixir` and `ocaml` / `ocamlrun` to
  `lang_shebangs` so `#!/usr/bin/env elixir` style scripts
  detect.

### Changed

- **`LANG_COUNT` 23 → 26** with the three new entries.
- **Toolchain dep bump: vyakarana 1.4.0 → 1.5.0.**

### Verified

- `sh scripts/smoke.sh` locks `.ex` / `.ml` / `.hs` extension
  detection.

## [1.2.2] — 2026-05-08

vyakarana 1.3.0 → 1.4.0 — scripting + mobile batch (PHP, Ruby,
Lua, Swift). Covers two of the languages explicitly named in the
2.x roadmap "Further bundled-grammar broadening" candidate list
(ruby, lua, swift, plus php from the same release).

### Added

- **PHP highlighting.** `.php`/`.phtml` extension dispatch +
  ANSI tokenization via `grammars/php.cyml`. PHP 8 surface:
  `enum`, `readonly`, `match`, `fn`, `mixed`, `never`. `$variable`
  syntax tokenizes as one ident.
- **Ruby highlighting.** `.rb` extension dispatch +
  `grammars/ruby.cyml`. `@instance` and `$global` variables, the
  `<=>` / `===` / `=~` operator set.
- **Lua highlighting.** `.lua` extension dispatch +
  `grammars/lua.cyml`. Both `--[[ ]]` long-comment and `-- …\n`
  line-comment forms (vyakarana grammar uses pair-rule ordering
  per its architecture note 003 to ensure the longer prefix
  wins).
- **Swift highlighting.** `.swift` extension dispatch +
  `grammars/swift.cyml`. `"""…"""` multi-line strings; `..<` /
  `...` ranges; `??` / `?.` nil-handling operators.
- **Shebang hints.** Added `php`, `ruby`, `lua`, `swift` to
  `lang_shebangs` so script files with the matching shebang
  detect even without an extension.

### Changed

- **`LANG_COUNT` 19 → 23** with the four new entries.
- **Toolchain dep bump: vyakarana 1.3.0 → 1.4.0.**

### Verified

- `sh scripts/smoke.sh` locks `.php` / `.rb` / `.lua` / `.swift`
  extension detection plus the ruby shebang gate
  (`#!/usr/bin/env ruby` → `(ruby)`).

## [1.2.1] — 2026-05-08

vyakarana 1.2.4 → 1.3.0 — JVM + C-family batch (Java, Kotlin,
C++, C#).

### Added

- **Java highlighting.** `.java` extension dispatch + ANSI
  tokenization via `grammars/java.cyml`. Java 21 surface:
  `record`, `sealed`, `permits`, `non-sealed`, `yield`, `var`.
  `@` and `$` in `ident_start` so `@Override` and
  compiler-generated names tokenize as a single ident.
- **Kotlin highlighting.** `.kt`/`.kts` extension dispatch +
  `grammars/kotlin.cyml`. Elvis (`?:`), safe-call (`?.`),
  not-null assert (`!!`), data/sealed-class keyword set.
- **C++ highlighting.** `.cpp`/`.cc`/`.cxx`/`.hpp`/`.hxx`
  extension dispatch + `grammars/cpp.cyml`. C++20-era surface
  (concepts, modules, coroutines, three-way `<=>`). **`.h`
  stays C** — header-extension disambiguation between C and
  C++ is impossible without content inspection, and C is the
  more common owl input.
- **C# highlighting.** `.cs`/`.csx` extension dispatch +
  `grammars/csharp.cyml`. C# 12-era surface including `record`,
  `init`, `with`, LINQ contextual keywords.

### Changed

- **`LANG_COUNT` 15 → 19** with the four new entries.
- **Toolchain dep bump: vyakarana 1.2.4 → 1.3.0.**

### Verified

- `sh scripts/smoke.sh` locks `.java` / `.kt` / `.cpp` / `.cs`
  extension detection plus a `--language=java` ANSI emission
  gate.

## [1.2.0] — 2026-05-08

Toolchain refresh + vyakarana 1.2.x closeout (1.2.0 → 1.2.4).
Cyrius pin moves 5.9.36 → 5.9.41 (five `5.9.x` minor slots'
worth of compiler-internal fixes; nothing owl exercises broke).
vyakarana picks up `char_literal` (1.2.1 — already enabled in
the c/rust/go/zig grammars owl ships, so 4 known-failing vidya
samples drop to zero token errors with no owl change), and the
two assembler grammars (`asm_x86_64` at 1.2.2, `asm_aarch64` at
1.2.3). 1.2.4 was a vyakarana-side closeout — no behavioural
changes for owl. This is the first patch in the 1.2.x lockstep
series tracking vyakarana 1.2.x → 1.8.x.

### Added

- **x86_64 assembly highlighting.** `.s`/`.asm` extension
  dispatch defaults to `asm_x86_64` (Intel-syntax GAS) per
  vyakarana 1.2.2 wiring. ANSI tokenization via
  `grammars/asm_x86_64.cyml`. `.section` / `.text` / `.global` /
  `.byte` / `.cfi_*` etc. promote to keyword via the words rule;
  opcodes (`mov`, `call`, `jne`, `xor`, `syscall`) and registers
  (`rax`, `rdi`, `eax`) stay `TK_IDENT` per vyakarana ADR 0004.
  AT&T-syntax samples (`mov $1, %rax`) are not yet supported —
  documented in the grammar header as a future ADR candidate.
- **aarch64 assembly highlighting.** No default extension
  (`.s`/`.S` belongs to x86_64); ARM users pass
  `--language=asm_aarch64` explicitly. ANSI tokenization via
  `grammars/asm_aarch64.cyml`. `b.eq`/`b.ne`/`b.lt`/`b.hi`
  conditional branches tokenize as a single ident (vyakarana
  puts `.` in both `ident_start` and `ident_cont`); `!`
  write-back addressing operator covered.

### Changed

- **`LANG_COUNT` 13 → 15.** `src/lang.cyr` gains
  `lang_name(13)` = `"asm_x86_64"` / `lang_exts(13)` =
  `".s .asm"` and `lang_name(14)` = `"asm_aarch64"` /
  `lang_exts(14)` = `""` (filename dispatch via explicit
  `--language=`).
- **Toolchain pin bump: cyrius 5.9.36 → 5.9.41.** No source
  changes required — the 5.9.36 → 5.9.41 window shipped no
  breaking changes to the stdlib surface owl imports.
- **Toolchain dep bump: vyakarana 1.2.0 → 1.2.4.** Public
  tokenizer API unchanged across the bump (token kinds,
  `tokenize_source(src, lang)`, tokenbuf accessors stay
  compatible). vyakarana's `Grammar` record grew at 1.2.1
  (`char_literal` flag, GRAMMAR_SIZE 144 → 152) but owl reads
  via the public accessors so this stays transparent.
- **Minor version bump.** First minor bump since 1.1.0 — opens
  the 1.2.x patch series for the vyakarana 1.3.0 → 1.8.0
  lockstep cascade landing in 1.2.1 through 1.2.6.

### Verified

- `cyrius build` + `CYRIUS_DCE=1 cyrius build` clean.
- `cyrius test` — unit gates green.
- `sh scripts/smoke.sh` — all M0–M8 gates green; new gates lock
  `.s` → `(asm_x86_64)` extension detection plus
  `--language=asm_x86_64` and `--language=asm_aarch64` ANSI
  emission probes.
- `owl --version --verbose` reports `vyakarana 1.8.0` /
  `cyrius 5.9.41` (the minor slot ships the final pin set;
  intermediate patches inherit it as the cascade lands in one
  drop on 2026-05-08).

### Notes

- The 1.2.x patch line is shipped as one drop on 2026-05-08;
  each entry above documents one vyakarana minor's worth of
  language wiring. End state at 1.2.6: `LANG_COUNT` = 36, 36
  bundled grammars, vyakarana 1.8.0, cyrius 5.9.41.

## [1.1.12] — 2026-05-08

vyakarana 1.2.0 picks up Go and Zig — owl wires both into language
detection, the grammar registry, and `--list-languages`.

### Added

- **Go highlighting.** `.go` extension detection, `--language=go`
  validation, and ANSI tokenization via vyakarana 1.2.0's
  `grammars/go.cyml` (predeclared identifiers like `len` / `nil` /
  `iota` tokenize as `ident`, not `keyword`, per vyakarana ADR 0004).
  `grammars/go.cyml` synced from the upstream drop.
- **Zig highlighting.** `.zig` extension detection,
  `--language=zig` validation, and ANSI tokenization via vyakarana
  1.2.0's `grammars/zig.cyml` (`@`-prefixed builtins like `@import`
  / `@TypeOf` tokenize as a single `ident` per vyakarana ADR 0007).
  `grammars/zig.cyml` synced from upstream.

### Changed

- **Toolchain dep bump: vyakarana 1.1.0 → 1.2.0.**
  `cyrius.cyml [deps.vyakarana].tag` and the `--version --verbose`
  banner string updated in lockstep. Public tokenizer API unchanged
  across the bump — token kinds, `tokenize_source(src, lang)`,
  tokenbuf accessors, and the `Grammar` record layout are all
  compatible. Cyrius pin stays at `5.9.36`.

- **`LANG_COUNT` 11 → 13.** `src/lang.cyr` gains `lang_name(11) = "go"`
  / `lang_exts(11) = ".go"` and `lang_name(12) = "zig"` /
  `lang_exts(12) = ".zig"`. `bootstrap_grammars` in `src/main.cyr`
  loads `go.cyml` and `zig.cyml` from both the user-overlay path
  (`$XDG_CONFIG_HOME/owl/grammars/`) and the bundled exe-relative
  path. Existing 11-language behavior is unchanged.

- **`--list-languages`** now reports 13 entries (`plain`, the prior
  10, plus `go` and `zig`).

### Verified

- `cyrius build` + `CYRIUS_DCE=1 cyrius build` clean.
- `cyrius test` — 7/7 unit gates green.
- `sh scripts/smoke.sh` — all M0–M8 gates green; new gates lock
  `(go)` / `(zig)` headers via extension detection and confirm
  `--color=always --language=go` / `--language=zig` from stdin emits
  ANSI tokens.
- `cyrius lint src/*.cyr` — 0 warnings.
- `owl --version --verbose` reports `vyakarana 1.2.0` / `cyrius
  5.9.36`.

### Notes

- DCE binary: 225,672 bytes (~220 KB; +520 bytes vs 1.1.11). Most
  of the delta is the two new compiled-in grammar tables; owl-side
  source growth is small (~4 lines in `main.cyr` for the bootstrap
  calls, ~3 in `lang.cyr` for the table entries).
- `grammars/go.cyml` and `grammars/zig.cyml` are runtime data
  shipped alongside the binary — installed-binary packaging needs
  to copy these alongside the existing 11.
- vyakarana streaming tokenizer is **not** in the 1.2.x line, so
  the 2.x `HIGHLIGHT_MAX`-lift item stays parked.

## [1.1.11] — 2026-05-08

Last 1.x polish item closed: exact-gutter wrap math.

### Fixed

- **Wrap budget now tracks the actual gutter width per file.** Pre-1.1.11
  `resolve_mode` always subtracted the VCS-on (11-col) gutter when
  computing `g_wrap_cols`, regardless of whether the change-marker
  cell was actually rendering. Under `--style=no-changes` the marker
  cell stays off and the gutter is only 9 cols wide, so wrapped
  content stopped 2 cols short of the right rule — a cosmetic gap
  the v1.1.x roadmap had carried since 1.1.8.

  Two changes drive the fix (`src/main.cyr`):
  - New `g_wrap_term_cols` global caches the resolved terminal width
    once at `resolve_mode` time.
  - New `_recompute_wrap_cols()` helper picks the gutter width from
    `vcs_enabled()` (9 cols when 0, 11 cols when 1) and recomputes
    `g_wrap_cols`. It runs from `resolve_mode` (initial) and again
    after every `vcs_compute_markers(path)` so per-file VCS state can
    re-widen or re-narrow the budget.

  Default-style behavior is unchanged — the marker cell is always in
  play in decorated mode (its slot renders as a space outside a repo),
  so `g_wrap_cols` still resolves to `terminal − 11`. Plain mode
  (`-p`) and `--wrap=never` paths are untouched.

### Added

- **Smoke gates locking the gutter math** (`scripts/smoke.sh`):
  - `--style=no-changes -n` at 80-col fallback fits exactly 71 chars
    of content (a 71-char line does not wrap, a 72-char line does).
  - Default style (marker cell in play) preserves the 69-char budget
    — a 70-char line still wraps. Catches regressions in either
    direction.

### Notes

- DCE binary: 225,152 bytes (~220 KB; +256 bytes vs 1.1.10 — the
  new helper, the cache global, and the recompute callsite). DCE and
  non-DCE remain the same size, not byte-identical.
- `src/main.cyr`: ~1,922 → ~1,957 lines.
- vyakarana stays pinned at 1.1.0; cyrius stays at 5.9.36. The 1.2.x
  vyakarana line is on track to broaden bundled-grammar coverage —
  streaming tokenizer (the gate for raising owl's `HIGHLIGHT_MAX`)
  is *not* on the 1.2.x list, so the 2.x backlog item stays parked.

## [1.1.10] — 2026-05-08

Toolchain + tokenizer-dep refresh. No behavior change for end users;
under the hood owl now rides the latest cyrius and picks up vyakarana
1.1.0's grammar polish for C, Rust, TOML, and Markdown.

### Changed

- **Toolchain pin bumped to cyrius 5.9.36** (was 5.7.12).
  `cyrius.cyml [package].cyrius`, the `--version --verbose` banner
  in `src/main.cyr print_version`, and the install-step refs in
  `README.md` / `CONTRIBUTING.md` updated in lockstep. No owl source
  changes required — the 5.7.12 → 5.9.36 window shipped no breaking
  changes to the stdlib surface owl imports (`syscalls`, `alloc`,
  `fmt`, `io`, `fs`, `str`, `string`, `vec`, `args`, `hashmap`,
  `process`, `tagged`, `assert`).

  Notable upstream items inherited (no owl-side action needed): cyrius
  v5.9.4 switched `lib/args.cyr` to a lazy 2 MB heap-allocated argv
  buffer (was a 4 KB stack buffer); v5.9.33–v5.9.36 fixed parser /
  preprocessor / `#derive(Serialize)` codegen edge cases that owl
  doesn't currently exercise.

- **vyakarana pin bumped to 1.1.0** (was 1.0.2). Public API stable
  across the bump — token kinds, `tokenize_source(src, lang)`,
  tokenbuf accessors, and the 11-grammar bundled set all unchanged.
  Grammar polish lands automatically:
  - **C** — `unicode_ident` plus `/* … */` block-comment pair rule;
    UTF-8 bytes ≥ 0x80 in comments now coalesce instead of producing
    per-byte error tokens.
  - **Markdown** — `unicode_ident` enabled; em-dashes, smart quotes,
    and accented prose tokenize cleanly.
  - **Rust** — `ident_start` extended to include `$` so macro
    metavariables (`$expr`, `$tok`) no longer fragment.
  - **TOML** — triple-quoted (`"""…"""`, `'''…'''`) string forms
    recognized.

  Internally vyakarana's `Grammar` record grew by 8 bytes (one new
  `unicode_ident_on` field) but owl never introspects it, so no
  source change.

- **Streaming tokenizer status**: not yet shipped in vyakarana 1.1.0.
  owl's `HIGHLIGHT_MAX` cap stays parked behind that upstream
  delivery — listed in `state.md`'s Next section.

### Verified

- `cyrius deps` + `cyrius build src/main.cyr build/owl` clean
- `CYRIUS_DCE=1 cyrius build` clean
- `cyrius test` — 7/7 unit gates green
- `sh scripts/smoke.sh` — all M0–M8 behavioral gates green; banner
  reads `owl 1.1.10`
- `cyrius lint src/*.cyr` — 0 warnings
- `owl --version --verbose` reports `vyakarana 1.1.0` / `cyrius 5.9.36`

### Notes

- DCE binary: 224,896 bytes (~220 KB; +1,112 bytes vs 1.1.9's 223,992
  with the 5.9.32-only bump, +11,112 bytes vs the original 1.1.9 pin).
  Delta breakdown: ~+900 B from vyakarana 1.1.0's added grammar rules
  in `dist/vyakarana.cyr`, the rest from incremental cyrius stdlib
  growth across 5.9.33–5.9.36. DCE and non-DCE builds remain the
  same size but are not byte-identical (the 5.9.x DCE NOPs out
  dead-code spans, where the 5.7.x DCE was a no-op for owl's call
  graph).
- No changes under `src/` beyond the version-banner triple
  (`OWL_VERSION` constant, `print_version` body string, banner
  comment).

## [1.1.9] — 2026-04-27

Wrap-arrow polish.

### Changed

- **Wrap-continuation gutter now uses `↪` (U+21AA) instead of `│`.**
  In 1.1.8 the continuation glyph matched the line divider, which
  made tightly-stacked wrapped rows visually ambiguous against new
  file lines. The 1.1.9 glyph (bat's convention) keeps `│` for "this
  is the start of a new file line" and `↪` for "this is the
  continuation of the previous line", so a wrapped paragraph reads
  as one logical line at a glance (`src/main.cyr`,
  `_emit_wrap_break`).

  Smoke gate updated: continuation assertion now looks for `↪ a`
  under the wrap test instead of `│ a`.

### Notes

- DCE binary: 213,784 bytes (~209 KB; +8 bytes vs 1.1.8 — the
  arrow's UTF-8 bytes match `│` width, so the diff is just the
  string-pool slot).

## [1.1.8] — 2026-04-27

Frame containment. The 1.1.7 bat-style header rendered correctly but
long content overflowed past the right edge of the rule, breaking the
visual frame.

### Changed

- **`--wrap=auto` (default) now wraps content when the decorated
  frame is active.** Wrapped lines stay inside the bottom rule, and
  wrap-injected line breaks emit a continuation gutter (blank lineno
  + `│ ` in `lineno_color`) so wrapped text aligns under the divider.
  Highlighting survives wrap: `_emit_wrap_break` saves the active
  token color before drawing the gutter and restores it after, so a
  multi-row wrapped span keeps its syntax color throughout. Plain
  mode (`-p`) and piped output without `-n` still bypass wrap
  entirely (cat parity preserved). `--wrap=never` is the explicit
  overflow escape hatch (was effectively the pre-1.1.8 default).
  `--wrap=character` is unchanged — always-on regardless of
  decoration, still useful for scripted fixed-width capture
  (`src/main.cyr`, `_emit` / new `_emit_wrap_break` /
  `g_render_active_color`, `resolve_mode` wrap resolution,
  `render_chunk` path-1 fast-path gate, `render_highlighted_buf`
  color-state plumbing).

  Smoke gates added: `--wrap=auto` wraps a 200-char line under `-n`
  and emits the continuation gutter; `--wrap=never` leaves the same
  line on a single physical row even when decorated;
  `-p --wrap=auto` is byte-identical to `cat`.

### Notes

- DCE binary: 213,776 bytes (~209 KB; was ~208 KB at 1.1.7 — +744
  bytes for `_emit_wrap_break`, the wrap-resolution refactor, and
  `g_render_active_color` plumbing).
- `src/main.cyr`: ~1,875 → ~1,920 lines.

## [1.1.7] — 2026-04-27

Header aesthetic refresh + toolchain bump.

### Changed

- **Toolchain pin bumped to cyrius 5.7.12.** `cyrius.cyml`,
  `--verbose` banner, `CONTRIBUTING.md`, and `README.md` install
  step all updated. No source changes required for the bump.

- **File header is now a bat-style three-rule frame.** The single
  `─── File: <path> ─` ribbon is replaced with a top rule
  (`────┬────…`), an aligned `│ File: <path> (<lang>)` line, a
  middle rule (`────┼────…`), the file body, and a bottom rule
  (`────┴────…`). Rules span the actual terminal width via
  `TIOCGWINSZ` on stdout (80-col fallback when winsize is
  unavailable) and the junction column tracks the gutter divider
  (col 7 without VCS markers, col 9 with). Rules render in the
  active theme's `lineno_color`; the "File: …" label keeps
  `header_color`. New `emit_footer()` pairs with `emit_header()`
  via a `g_header_open` flag so every render path (plain stream,
  highlighted, hex, binary auto-fallback) emits a matching bottom
  rule. Plain mode (`-p`) and piped output stay byte-identical to
  `cat` — the frame is decorated-mode only (`src/main.cyr`,
  `emit_header` / new `emit_footer` / `_emit_rule` /
  `_gutter_divider_col`).

  Smoke gate updated: `── File:` substring matches now look for
  `│ File:` (the path is on a separate line under the new layout).

### Notes

- DCE binary: 213,032 bytes (~208 KB; was ~207 KB at 1.1.6 —
  +1,160 bytes for the rule helpers, footer pair, and two new
  globals).
- `src/main.cyr`: 1,795 → ~1,870 lines.

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
