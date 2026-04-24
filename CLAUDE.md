# owl — Claude Code Instructions

## Project Identity

**owl** — *Observant Watcher of Lines*, a `cat`/`bat`-style terminal file viewer for AGNOS / Cyrius. The backronym maps to the feature set: *observant* = language detection + syntax highlighting, *watcher* = per-line gutter + VCS change markers, *lines* = the unit owl operates on. Name itself descends from Sanskrit **ulūka** via PIE *\*ulū-*; see README §Name.

- **Type**: Binary
- **License**: GPL-3.0-only
- **Language**: Cyrius (toolchain pinned in `cyrius.cyml [package].cyrius`, currently 5.6.0)
- **Version**: SemVer, `VERSION` is the source of truth
- **Status**: 0.1.0 — M0–M5 + M3b shipped; pre-release
- **Genesis repo**: [agnosticos](https://github.com/MacCracken/agnosticos)
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-standards.md)

## Goal

Own the terminal "show me this file" job on AGNOS. Plain mode (`-p`) is a drop-in `cat`; decorated mode adds headers, line-number gutter, auto-paging, and token-level syntax highlighting. Tokenization is not owl's problem — it belongs to [vyakarana](https://github.com/MacCracken/vyakarana).

## Scaffolding

Project was scaffolded with `cyrius init owl`. Do not manually create project structure — use the tools. If the tools are missing something, fix the tools.

## Current State

- **Source**: ~1300 lines across 4 modules (`main.cyr`, `lang.cyr`, `theme.cyr`, `pager.cyr`)
- **Tests**: `tests/owl.tcyr` + `scripts/smoke.sh` (M0–M5 behavioral gates)
- **Binary**: ~140KB (non-DCE)
- **Stable**: pre-release — all milestones through M5 + M3b (token highlighting) shipped
- **Integration**: no downstream consumers; owl is an end-user tool

## Consumers

None. owl is a terminal application, not a library.

## Dependencies

- **Cyrius stdlib** — `syscalls`, `alloc`, `fmt`, `io`, `fs`, `str`, `string`, `vec`, `args`, `hashmap`, `process`, `assert` (declared in `cyrius.cyml [deps] stdlib`)
- **vyakarana** (1.0.2) — tokenizer + 11 bundled grammars; git-tag pinned in `[deps.vyakarana]`, vendored to `lib/vyakarana.cyr` by `cyrius deps`. Ships the ten-kind palette that `src/theme.cyr` colors against.

No other external deps. No FFI. M7 (config file) may add `cyml`/`toml` from stdlib; no new third-party deps planned before v1.

## Quick Start

```bash
cyrius deps                                # resolve vyakarana dep
cyrius build src/main.cyr build/owl        # build
cyrius test                                # .tcyr unit tests
sh scripts/smoke.sh                        # M0–M5 behavioral gates
cyrius lint src/*.cyr                      # static checks
CYRIUS_DCE=1 cyrius build src/main.cyr build/owl   # release parity
```

## Architecture

```
src/
  main.cyr    — entry, CLI parsing, render dispatch, TTY / mode resolution
  lang.cyr    — extension + shebang language detection, name table
  theme.cyr   — bundled themes (dark, light), 10-kind token palette, ANSI emission
  pager.cyr   — pager spawn (OWL_PAGER → PAGER → less -R), SIGPIPE handling
lib/
  vyakarana.cyr  — vendored tokenizer (git-dep, do not edit)
grammars/
  *.cyml         — 11 starter grammars loaded at runtime by vyakarana's bootstrap
tests/
  owl.tcyr       — unit assertions
  owl.bcyr       — benchmarks (reserved)
  owl.fcyr       — fuzz (reserved)
scripts/
  smoke.sh       — end-to-end behavioral gates (stages M0 → M5)
```

**Include order in `main.cyr`**: `lib/vyakarana.cyr` first, then owl modules (`lang.cyr`, `theme.cyr`, `pager.cyr`). `main.cyr` owns global flag state; other modules read it but do not set it.

Runtime grammar resolution is cwd-relative (`grammars/<lang>.cyml`). Installed-binary resolution (exe-relative paths) is a M8 packaging concern.

## Key Constraints

- **Startup matters** — `owl --version` / `owl file.txt` must feel instant. Defer allocation and grammar bootstrap until the path needs it
- **Plain mode is sacred** — `-p` must be byte-identical to `cat` for any input. No transforms, no decorations, no surprises. This is tested by `scripts/smoke.sh`
- **Color is triply-gated** — `g_want_color` resolves from (`-p` → off, `--color=always` → on, `NO_COLOR` env → off unless `always`, else TTY detection). Highlight path gates on `g_want_color` *not* `g_decorated` — piped output with `--color=always` still colors tokens even though header/gutter stay off
- **Highlight ceiling** — `HIGHLIGHT_MAX` caps the highlight path against the bump allocator (full file + tokenbuf + ANSI-inflated output ≈ 4× resident). Oversized files fall back to plain streaming. Raising the cap needs a freeing allocator or vyakarana 2.x streaming tokenizer
- **Grammar files ship with owl** — `grammars/*.cyml` are runtime data, not source. They must be installed alongside the binary

## Development Process

### Work Loop

1. Pick the next milestone item from `ROADMAP.md`
2. Implement + update `scripts/smoke.sh` with a behavioral gate for it
3. `cyrius build` → `cyrius test` → `sh scripts/smoke.sh`
4. Manual TTY check — features that depend on TTY detection need a real terminal run (type checks can't catch ANSI regressions)
5. Update `CHANGELOG.md`
6. Version bump only at milestone close, not per feature

### Security Hardening (before release)

- Control-byte sanitization on any path/arg echoed to stderr (prevent ANSI injection via `owl $(printf '\x1b[2Jevil')`)
- File-read bounds: `BUFSIZE` and `HIGHLIGHT_MAX` verified against allocation sizes
- Pager spawn sanitizes environment: `OWL_PAGER` / `PAGER` values are passed as argv[0], never shelled-out
- Audit findings filed in `docs/audit/YYYY-MM-DD-audit.md`

### Closeout Pass (before minor/major bump)

1. Full test + smoke — both green from clean checkout
2. `cyrius lint src/*.cyr` — no unaddressed findings
3. `CYRIUS_DCE=1 cyrius build` — release binary builds; note size in CHANGELOG
4. ROADMAP decision log + milestone checkboxes reflect reality
5. Version triple (`VERSION`, `cyrius.cyml`, CHANGELOG header) in sync

## Key Principles

- **Correctness before features** — a v1 that does five things perfectly beats a v1 that does fifteen unreliably (see `ROADMAP.md` guiding principles)
- **Ship plain mode first, decorations later** — plain mode is the foundation; decorations are icing
- **Defer what you can** — keep later-milestone items out of earlier milestones even when they look easy; scope creep is the enemy
- **Byte-for-byte testable** — behavioral gates in `scripts/smoke.sh` diff owl's output against expected bytes. `cat -v`-level visual checks catch ANSI regressions type checking can't
- **Tokenization is vyakarana's job** — owl colors tokens, it does not recognize them. When a grammar is wrong, fix it in vyakarana, not in owl

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

- **Toolchain pin** — `cyrius.cyml [package].cyrius` is the authority (no `.cyrius-toolchain` file yet; add when CI lands)
- **Workflow layout** — `.github/workflows/` not yet established; M8 packaging milestone adds CI + release automation
- **Release artifacts** (planned for v1): source tarball, bundled single-file `.cyr`, DCE binary, SHA256SUMS

## Key References

- `README.md` — user-facing intro
- `ROADMAP.md` — milestone plan + decision log (source of truth for what's done vs. open)
- `owl-design-spec.md` — behavioral spec: CLI flags, exit codes, mode matrix
- `CHANGELOG.md` — what landed, when
- `../vyakarana/` — tokenizer source (owl's only non-stdlib dep)
- `../vidya/content/lexing_and_parsing/` — reference corpus vyakarana grammars are tested against

## DO NOT

- **Do not commit or push without user approval** — the user handles all git operations
- **Do not modify files in `lib/`** — vendored dep output, rebuilt by `cyrius deps`
- **Do not modify files in `grammars/`** — copied from vyakarana; fix upstream and re-sync
- Do not add Cyrius stdlib includes in individual src files — `main.cyr` owns the include chain
- Do not hardcode toolchain versions outside `cyrius.cyml`
- Do not bypass `cyrius build` with raw `cc3` invocations

## .gitignore (Required)

```gitignore
# Build
/build/
/dist/

# Cyrius vendored deps
lib/*.cyr
!lib/k*.cyr

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

Follow [Keep a Changelog](https://keepachangelog.com/). Behavior changes (new flags, exit-code semantics) get a dated section. Breaking changes get a **Breaking** section with migration guide. Security fixes get a **Security** section.
