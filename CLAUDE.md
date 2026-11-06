# owl — Claude Code Instructions

> **Core rule**: this file is **preferences, process, and procedures** —
> durable rules that change rarely. Volatile state (version, binary
> sizes, line counts, consumers, milestone status, security findings)
> lives in [`docs/development/state.md`](docs/development/state.md).
> Do not inline state here.

## Project Identity

**owl** — *Observant Watcher of Lines*, a `cat`/`bat`-style terminal file viewer for AGNOS / Cyrius. The backronym maps to the feature set: *observant* = language detection + syntax highlighting, *watcher* = per-line gutter + VCS change markers, *lines* = the unit owl operates on. Name itself descends from Sanskrit **ulūka** via PIE *\*ulū-*; see README §Name.

- **Type**: Binary
- **License**: GPL-3.0-only
- **Language**: Cyrius (toolchain pinned in `cyrius.cyml [package].cyrius`)
- **Version**: `VERSION` at the project root is the source of truth
- **Genesis repo**: [agnosticos](https://github.com/MacCracken/agnosticos)
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-standards.md) · [First-Party Documentation](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-documentation.md)

## Goal

Own the terminal "show me this file" job on AGNOS. Plain mode (`-p`) is a drop-in `cat`; decorated mode adds headers, line-number gutter, auto-paging, and token-level syntax highlighting. Tokenization is not owl's problem — it belongs to [vyakarana](https://github.com/MacCracken/vyakarana).

## Current State

> Volatile state — current version, binary size, line counts, test/smoke
> status, consumers, active security findings, milestone progress — lives
> in [`docs/development/state.md`](docs/development/state.md).
> Refreshed every release.

This file (`CLAUDE.md`) is durable rules.

## Scaffolding

Project was scaffolded with `cyrius init owl`. **Do not manually create project structure** — use the tools. If the tools are missing something, fix the tools.

## Quick Start

```bash
cyrius deps                                         # populate lib/ from cyrius.cyml (mandatory after fresh checkout)
cyrius build src/main.cyr build/owl                 # build
cyrius test                                         # .tcyr unit tests
sh scripts/smoke.sh                                 # behavioral gates
cyrius lint src/*.cyr                               # static checks
CYRIUS_DCE=1 cyrius build src/main.cyr build/owl    # release parity (DCE)
```

## Architecture

Module responsibilities (file list in `state.md`):

- **`main.cyr`** — entry, CLI (parsed by cmdit since 1.6.0; owl keeps its own help, version, error wording and validators), render dispatch, TTY and mode resolution, the grammar registry bootstrap (user overlay, then vyakarana's embedded set). Owns global flag state; other modules read but do not set
- **`lang.cyr`** — language routing: config `ext.` overrides, new-name user grammars, vyakarana's `detect_language_combined`, owl's small supplement, the opening sniff. No language table of its own (since 1.6.0)
- **`theme.cyr`** — bundled themes (dark, light), 10-kind token palette, ANSI emission
- **`pager.cyr`** — pager spawn (`OWL_PAGER` → `PAGER` → `less -RFX`), SIGPIPE handling
- **`vcs.cyr`** — sit-backed VCS change markers for the gutter (since 1.4.0): `sit_repo_open` / `sit_diff_path` / `sit_repo_close` library calls, LCS edit-script → ADD/MOD/DEL mapping. All VCS-backend code confined here behind a stable five-fn interface (`vcs_compute_markers`, `vcs_mark_for_line`, `vcs_enabled`, `vcs_reset`, `set_style`) so a backend swap is a single-file rewrite
- **`config.cyr`** — minimal `key = value` config parser; no stdlib `toml`/`cyml` dep
- **`out.cyr`** — buffered stdout (since 1.5.3). Every rendered byte goes through `out_write` / `out_byte` / `out_write_sanitized`; `out_flush` loops on short writes and EINTR and ends owl with exit 3 on a write error (silently on EPIPE). Self-contained, like `escape.cyr`
- **`escape.cyr`** — the file-origin terminal-escape classifier (split out of `main.cyr` at 1.4.7). Self-contained state machine over two globals so `tests/owl.fcyr` can include it directly; the caller decides *whether* to filter (`_strip_active()` in main.cyr), this decides *what a sequence is*. Audit FINDING-001/006/013 all live here — change it with the fuzz harness in hand
- **`fetch.cyr`** — http/https remote fetch. **Not wired into the build** (see its header): complete but parked at 1.4.7 because the sandhi transport could not be verified, it costs ~521 KB of network stdlib, and it wants its own audit pass

Include order in `main.cyr`: `lib/vyakarana.cyr` and `lib/cmdit.cyr` first, then `src/escape.cyr` and `src/out.cyr` (no owl deps; everything after them writes through `out_write`), then the rest of the owl modules. The bundled grammars are compiled in (vyakarana's embedded blobs, registered by `bootstrap_grammars()`); nothing is resolved from disk except the user overlay `$XDG_CONFIG_HOME/owl/grammars/` (else `~/.config/owl/grammars/`), which is registered first so it wins by name.

## Key Constraints

- **Startup matters** — `owl --version` / `owl file.txt` must feel instant. Defer allocation and grammar bootstrap until the path needs it
- **Plain mode is sacred** — `-p` must be byte-identical to `cat` for any input. No transforms, no decorations, no surprises. Tested by `scripts/smoke.sh`
- **Color is triply-gated** — `g_want_color` resolves from (`-p` → off, `--color=always` → on, `NO_COLOR` env → off unless `always`, else TTY detection). Highlight path gates on `g_want_color` *not* `g_decorated` — piped output with `--color=always` still colors tokens even though header/gutter stay off
- **Highlight ceiling** — `HIGHLIGHT_MAX` is one less than vyakarana's `VYK_STREAM_CAP` (a stream holding `len` bytes needs `len + n + 1`), and every `tokenize_stream_feed` result is checked: a refused feed is an overflow, never a silently short stream. Resident memory for a highlighted file is roughly 13× its size (the slurp buffer, the stream's own copy, the tokenbuf), not the 4× once claimed. Oversized files fall back to plain streaming (ndjson: a hard error). The slurp buffer, read buffers and tokenbuf are allocated once and reused across files; raising the cap needs a freeing allocator or vyakarana draining per chunk
- **`grammars/` is a reference copy, not runtime data** (since 1.6.0). The binary carries vyakarana's embedded grammars; `grammars/` is re-synced from the pinned vyakarana on every bump so smoke can check `--list-languages` and per-grammar reachability against it, and `docs/grammar-coverage.md` against it. Nothing installs it
- **Routing is vyakarana's** — owl keeps no language table. A wrong or missing route is fixed in vyakarana (filed in vyakarana's `docs/development/issues/`). `_owl_supplement` in `lang.cyr` carries only routes owl had already shipped before 1.6.0, until vyakarana has them; never add a new row to it
- **A user grammar replacing a bundled one changes highlighting, not routing** — only a user grammar with a new name routes by its declarations, so the `.s` / `.asm` content votes survive an overlay
- **`[deps].stdlib` is what owl REACHES** — since 1.4.7 owl consumes sit's read-only fold (`dist/sit-read.cyr`), not the full bundle. On a dep bump, start from the union of `dist/sit-read.deps` and `dist/vyakarana.deps` plus owl's own surface, then add back whatever the link reports undefined. Do NOT trust either list alone. Through cyrius 6.6.2 the sidecars under-reported sigil's crypto follow-throughs (`ct` / `keccak` / `bayan` / `random`). From 6.6.20 the folded modules include their own requires, so the link is clean without them. A clean link is necessary but not sufficient: also confirm the trimmed build compiles the same function set (the `unreachable fns` note) and that smoke passes
- **The mouse wheel lives in the `LESS` owl supplies** (since 1.6.1, `_pager_wheel`) — only when `LESS` is unset, only for a command whose first word is `less`, and only after asking that less which flag it has. Prefer `--emouse=vscroll`: `--mouse` also means drag-to-scroll and right-click-jumps-to-mark. Never hand less a flag unprobed: an unknown option in `LESS` stops it at a "Press RETURN" prompt on every run. The probe ends in `exec` so less stays the process owl waits on; on a bash `/bin/sh` that is invisible at runtime (bash 5.1+ execs the last `-c` command itself), so smoke pins the word in the binary
- **Check the DCE release size on every bump** — it is the shipped binary. (Cyrius 6.6.20–6.7.13 stopped removing dead code past 4,096 dead-code runs and only printed a note; 6.7.14 removed that cap.)
- **An escape sequence may never swallow more than its own line** — the classifier is bounded at a newline and at `ESC_MAX_LEN`, and an ESC at either bound starts a new sequence rather than being emitted. Three audit findings (006, 013) came from getting this wrong; `tests/owl.fcyr` pins all of it
- **File-origin escapes are stripped by default** — `-r` / `--raw-control-chars` is the opt-in for trusted-ANSI passthrough. The default must stay safe. Stripping follows the *frame*, not the colour: any decorated (TTY or `-n`) or coloured render strips, and only undecorated, uncoloured piped output passes through (cat-like). Keying it on colour alone let `NO_COLOR` re-open FINDING-001 (FINDING-014)
- **All stdout goes through `out_write`** — never a raw `syscall(1, 1, …)` / `file_write(STDOUT, …)` / `print`, which would bypass the buffer and reorder output. Call `out_flush()` before anything is written to stderr, before closing the pager pipe, before sleeping, and at exit

## Development Process

### Work Loop

1. Pick the next item from `docs/development/roadmap.md`
2. Implement + update `scripts/smoke.sh` with a behavioral gate for it
3. `cyrius build` → `cyrius test` → `sh scripts/smoke.sh`
4. Manual TTY check — features depending on TTY detection need a real terminal run (type checks can't catch ANSI regressions)
5. Update `CHANGELOG.md`
6. Update `docs/development/state.md` if version, binary size, deps, consumers, or security posture changed
7. Version bump only at milestone close, not per feature

### Security Hardening (before release)

- Control-byte sanitization on any path/arg echoed to stderr (prevent ANSI injection via `owl $(printf '\x1b[2Jevil')`) — use `eprint_sanitized`; and on any file name written to stdout (the `File:` header) — use `out_write_sanitized` (FINDING-015)
- File-read bounds: `BUFSIZE` and `HIGHLIGHT_MAX` verified against allocation sizes
- Pager spawn **does** use `/bin/sh -c` for the `OWL_PAGER` / `PAGER` value, so a flag-carrying value (`PAGER="less -R"`) works — the same contract `git` and `man` offer. This is safe because the variable is set by the user, who can already run commands; it is *not* a boundary owl defends. The invariant that IS load-bearing: **no path, filename, or other file-derived string is ever interpolated into that command** — the pager receives file content on stdin and nothing else. Do not "fix" this to argv-exec without checking `docs/audit/2026-08-22-audit.md` INFO-001, which is why this line reads the way it does
- VCS markers are computed in-process via sit's `sit_diff_path` library (since 1.4.0) — no subprocess, no shell, no argv on the VCS path (closes the FINDING-003/005 injection class by construction). The pre-1.4.0 git scaffold used `fork` + `execve` with explicit argv — never `/bin/sh -c`; the no-subprocess rule supersedes it
- Audit findings filed in `docs/audit/YYYY-MM-DD-audit.md`; closure status tracked in `state.md`

### Closeout Pass (before minor/major bump)

1. Full test + smoke — both green from clean checkout
2. `cyrius lint src/*.cyr` — no unaddressed findings
3. `CYRIUS_DCE=1 cyrius build` — release binary builds; note size in CHANGELOG and `state.md`
4. ADRs (`docs/adr/`) capture any structural decision made during the milestone; ROADMAP milestone checkboxes reflect reality
5. Version triple (`VERSION`, `cyrius.cyml`, CHANGELOG header) in sync
6. `state.md` current — version, binary size, test/smoke status, deps, consumers all match reality

## Key Principles

- **Correctness before features** — a v1 that does five things perfectly beats a v1 that does fifteen unreliably (see `docs/development/roadmap.md` guiding principles)
- **Ship plain mode first, decorations later** — plain mode is the foundation; decorations are icing
- **Defer what you can** — keep later-milestone items out of earlier milestones even when they look easy; scope creep is the enemy
- **Byte-for-byte testable** — behavioral gates in `scripts/smoke.sh` diff owl's output against expected bytes. `cat -v`-level visual checks catch ANSI regressions type checking can't
- **Tokenization is vyakarana's job** — owl colors tokens, it does not recognize them. When a grammar is wrong, fix it in vyakarana, not in owl
- **File input is hostile until proven safe** — every terminal byte that originates in a file passes through the escape classifier

## Cyrius Conventions

- A bare `var buf[N]` is N **bytes** inside a function, but N **i64 slots** (N × 8 bytes) at top level, where it also lands in the binary image — see the cyrius guide's bare-`var a[N]` section. Give big buffers `alloc()` (1.5.3: a top-level 64 KiB output buffer added 512 KiB to the binary)
- `&&` / `||` short-circuit; mixed in one expression requires parens: `a && (b || c)`. Prefer nested `if` when in doubt
- No closures — use named functions
- No negative literals — write `(0 - N)`, not `-N`
- Since cyrius 6.7: `trait` `const` `true` `false` `do` `dyn` are reserved words, and `!` is a real operator (before 6.7.3 a lone `!` was silently dropped, so `!x` compiled as `x`)
- On every pin bump, read cyrius `docs/development/ecosystem-migration.md` from the old pin up. For each entry that changes what *already-compiling* code computes, grep `src/` and `tests/` with strings and comments blanked, and prove the grep matches a planted positive — a green build does not cover these
- `break` in `while` loops with `var` declarations is unreliable — use flag + `continue`
- Build ANSI escapes via `store8(&buf + i, 0x1B)` (see `ansi_reset` in `src/theme.cyr`), not a `"\x1b…"` literal. Through cyrius 6.7.10 string literals did not parse `\x??` (the literal emitted the characters `\x1b`); 6.7.11+ does, but owl keeps the explicit form so escape bytes are made in one visible place
- Test exit pattern: `syscall(60, assert_summary())`
- All struct fields are 8-byte slots unless explicitly packed (vyakarana's 12-byte Token is the exception)
- Max limits per compilation unit: 4,096 variables, 1,024 functions, 4,096 initialized globals
- Counting rule: only a top-level `var NAME = <non-literal>;` (call / identifier / expression initializer) consumes an initialized-globals slot; a bare integer-literal init (`var x = 42;`) takes the static-init fast path and enum members are const-folded, so neither counts. See the cyrius guide's **Global Initializers** section (`docs/guides/cyrius-guide.md` in the cyrius repo)

## CI / Release

- **Toolchain pin** — `cyrius.cyml [package].cyrius` is the only authority. **Never** create a `.cyrius-toolchain` file; it was retired in favor of the manifest pin across AGNOS
- **Workflow layout** — `.github/workflows/` not yet established; packaging milestone adds CI + release automation
- **Release artifacts** (planned): source tarball, bundled single-file `.cyr`, DCE binary, SHA256SUMS
- **State sync** — when release automation lands, the post-hook bumps `docs/development/state.md`. Until then, update it by hand at every tag

## Key References

- `README.md` — user-facing intro
- `docs/development/roadmap.md` — forward-looking milestone plan
- `docs/adr/` — architecture decision records (immutable, individually citable)
- `docs/design-spec.md` — behavioral spec: CLI flags, exit codes, mode matrix
- `docs/grammar-coverage.md` — aggregate of per-grammar gap notes (severity / corpus-driven? / ADR per row); refresh in the same patch as any grammar wiring change
- `CHANGELOG.md` — what landed, when
- `docs/development/state.md` — **live state snapshot**
- `docs/audit/` — security audit reports
- `docs/development/issues/README.md` — index of issues owl has filed upstream. The issue and its repro live in the **owning repo's** `docs/development/issues/`, filed there directly; owl keeps only the index row. Filing is the only write owl work makes to another repo (no source changes), and it is left uncommitted for the user
- `../vyakarana/` — tokenizer source (owl's only non-stdlib dep)
- `../vidya/content/lexing_and_parsing/` — reference corpus vyakarana grammars are tested against

## DO NOT

- **Do not commit or push without user approval** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to the GitHub API if needed
- **Do not modify files in `lib/`** — vendored dep output, rebuilt by `cyrius deps`
- **Do not modify files in `grammars/`** — copied from vyakarana; fix upstream and re-sync
- Do not inline volatile state (version, sizes, counts) in this file — that belongs in `docs/development/state.md`
- Do not add Cyrius stdlib includes in individual src files — `main.cyr` owns the include chain
- Do not hardcode toolchain versions outside `cyrius.cyml`
- Do not bypass `cyrius build` with raw `cc5` invocations
- Do not weaken the default escape-stripping path — `-r` exists for opt-in passthrough

## .gitignore (Required)

```gitignore
# Build
/build/
/dist/

# Cyrius vendored deps — regenerated by `cyrius deps` from cyrius.cyml
/lib/

# Release / toolchain artifacts
*.tar.gz
SHA256SUMS

# IDE / OS
.idea/
.vscode/
*.swp
*~
.DS_Store
```

## CHANGELOG Format

Follow [Keep a Changelog](https://keepachangelog.com/). Behavior changes (new flags, exit-code semantics) get a dated section. Breaking changes get a **Breaking** section with migration guide. Security fixes get a **Security** section with CVE references where applicable.
