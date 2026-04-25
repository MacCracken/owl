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

- **`main.cyr`** — entry, CLI parsing, render dispatch, TTY and mode resolution. Owns global flag state; other modules read but do not set
- **`lang.cyr`** — extension + shebang language detection, name table
- **`theme.cyr`** — bundled themes (dark, light), 10-kind token palette, ANSI emission
- **`pager.cyr`** — pager spawn (`OWL_PAGER` → `PAGER` → `less -R`), SIGPIPE handling
- **`vcs.cyr`** — git-backed VCS change markers for the gutter; git-specific code confined here so a SIT swap is a single-file rewrite
- **`config.cyr`** — minimal `key = value` config parser; no stdlib `toml`/`cyml` dep

Include order in `main.cyr`: `lib/vyakarana.cyr` first, then owl modules. Runtime grammar resolution is cwd-relative (`grammars/<lang>.cyml`); installed-binary (exe-relative) resolution is a packaging concern.

## Key Constraints

- **Startup matters** — `owl --version` / `owl file.txt` must feel instant. Defer allocation and grammar bootstrap until the path needs it
- **Plain mode is sacred** — `-p` must be byte-identical to `cat` for any input. No transforms, no decorations, no surprises. Tested by `scripts/smoke.sh`
- **Color is triply-gated** — `g_want_color` resolves from (`-p` → off, `--color=always` → on, `NO_COLOR` env → off unless `always`, else TTY detection). Highlight path gates on `g_want_color` *not* `g_decorated` — piped output with `--color=always` still colors tokens even though header/gutter stay off
- **Highlight ceiling** — `HIGHLIGHT_MAX` caps the highlight path against the bump allocator (full file + tokenbuf + ANSI-inflated output ≈ 4× resident). Oversized files fall back to plain streaming. Raising the cap needs a freeing allocator or vyakarana 2.x streaming tokenizer
- **Grammar files ship with owl** — `grammars/*.cyml` are runtime data, not source. They must be installed alongside the binary
- **File-origin escapes are stripped by default** — `-r` / `--raw-control-chars` is the opt-in for trusted-ANSI passthrough. The default must stay safe

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

- Control-byte sanitization on any path/arg echoed to stderr (prevent ANSI injection via `owl $(printf '\x1b[2Jevil')`) — use `eprint_sanitized`
- File-read bounds: `BUFSIZE` and `HIGHLIGHT_MAX` verified against allocation sizes
- Pager spawn sanitizes environment: `OWL_PAGER` / `PAGER` values are passed as argv[0], never shelled-out
- VCS markers use `fork` + `execve` with explicit argv — never `/bin/sh -c`
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

- `var buf[N]` is N **bytes**, not N elements
- `&&` / `||` short-circuit; mixed in one expression requires parens: `a && (b || c)`. Prefer nested `if` when in doubt
- No closures — use named functions
- No negative literals — write `(0 - N)`, not `-N`
- `break` in `while` loops with `var` declarations is unreliable — use flag + `continue`
- Cyrius string literals do NOT parse `\x??` hex escapes — `"\x1b"` emits literal `\x1b` bytes. Build ANSI escapes via `store8(&buf + i, 0x1B)` instead (see `ansi_reset` in `src/theme.cyr`)
- Test exit pattern: `syscall(60, assert_summary())`
- All struct fields are 8-byte slots unless explicitly packed (vyakarana's 12-byte Token is the exception)
- Max limits per compilation unit: 4,096 variables, 1,024 functions, 256 initialized globals

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
- `CHANGELOG.md` — what landed, when
- `docs/development/state.md` — **live state snapshot**
- `docs/audit/` — security audit reports
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
