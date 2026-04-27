# Contributing to owl

Thanks for wanting to help `owl` see more.

## Prerequisites

- Cyrius toolchain 5.7.12+ (`cyrius` on `$PATH`) — <https://github.com/MacCracken/cyrius>
- A POSIX-ish host (Linux primary; macOS best-effort). `owl` targets
  AGNOS long-term, but the development shape is portable.

## Development Workflow

1. Fork and clone
2. `cyrius deps` — populates `lib/` from `cyrius.cyml [deps]`. `lib/`
   is gitignored, so this step is mandatory after every fresh
   checkout. The toolchain pin in `cyrius.cyml [package].cyrius`
   (currently `5.7.12`) is the only authority for the Cyrius version
   — never create a `.cyrius-toolchain` file.
3. Branch from `main`
4. Make your change
5. `sh scripts/smoke.sh build/owl` and `cyrius test tests/owl.tcyr` before opening a PR
6. Reference the ROADMAP milestone your change belongs to

## Build / Test / Smoke

```sh
cyrius deps
cyrius build src/main.cyr build/owl
cyrius test  tests/owl.tcyr
sh scripts/smoke.sh build/owl
```

There is no Makefile — `cyrius <subcommand>` is the whole build system.
Never shell out to `cc5` directly.

## Scope Discipline

`owl` is a file viewer. Not an editor. Not a pager. Not a search tool.
The [design spec](docs/design-spec.md) §1 enumerates out-of-scope items —
read it before proposing a feature in those areas. If you think the
line should move, update the spec in the same PR that moves it.

The [ROADMAP](docs/development/roadmap.md) is the source of truth for milestone order.
One milestone at a time; don't skip ahead. Post-v1 ideas live in the
roadmap's "Post-v1 ideas (deferred)" section — don't sneak them into
earlier milestones, even when they seem trivial.

## Code Style

- Enums and top-level `var` constants for fixed values
- Direct syscalls via `lib/syscalls` — no libc, no FFI at this stage
- `str` and `string` for buffers; avoid ad-hoc pointer arithmetic when
  a helper already exists
- Errors go to stderr as `owl: <path>: <reason>` — stdout is reserved
  for content (design spec §10)
- Prefer the Cyrius stdlib over reinventing primitives; if a primitive
  is missing, file an issue upstream at `cyrius/docs/development/issues/`
  rather than forking one locally

## Testing

- Every new dispatch path adds a `tests/owl.tcyr` assertion
- Every user-visible behavior adds a `scripts/smoke.sh` assertion (or a
  dedicated script under `scripts/`)
- When a milestone lands, its ROADMAP "Done when" checklist must be
  verifiable — the CI workflow runs `build + test + smoke` on every PR

## Commits

- One logical change per commit; conventional-ish messages
- Commit messages reference the ROADMAP milestone when applicable
  (e.g. `M1: read files by path`, `M2: TTY detection`)
- The maintainer handles `git push`, tags, and releases. Do not push
  tags from a contributor branch.

## Reporting Bugs / Filing Issues

- **Cyrius-compiler issues discovered via owl** — file upstream at
  [cyrius/docs/development/issues/](https://github.com/MacCracken/cyrius/tree/main/docs/development/issues)
  using the template in that directory's README. Follow the
  `{consumer}-{slug}-{date}.md` naming pattern.
- **owl issues** — open a GitHub issue on this repo. Include
  `owl --version`, the OS + terminal, a minimal file that reproduces
  (if applicable), and the exact command + observed vs. expected
  output.

## License

Contributions are accepted under GPL-3.0-only. See [LICENSE](LICENSE).
