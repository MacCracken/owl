# owl — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). Add release-hook wiring
> when the repo's release workflow lands.

## Version

**1.1.0** — shipped 2026-04-25. Stdin syntax highlighting: `owl -` and
bare-`owl` with piped input now apply token color when `--color=always`
and `--language=<lang>` are set, mirroring the file-path branch.
Slurp-then-tokenize up to `HIGHLIGHT_MAX`; streaming fallback on
overflow with the same stderr notice `render_path` emits.

**1.0.0** — shipped 2026-04-23. First stable release. M0 through M8
complete; full owl attack surface audited and hardened.

## Toolchain

- **Cyrius pin**: `5.6.44` (in `cyrius.cyml [package].cyrius`)

## Binary

- ~167 KB (non-DCE build, `build/owl`)
- Startup targets: `owl --version` 1–2 ms, tiny-file highlight 2 ms
  (25× under the 50 ms no-op target in `owl-design-spec.md`)

## Source

- ~2,230 lines across 6 modules:
  - `src/main.cyr` (~1,103) — entry, CLI, render dispatch, TTY/mode resolution
  - `src/lang.cyr` (~233) — extension + shebang language detection
  - `src/theme.cyr` (~180) — bundled themes, 10-kind palette, ANSI emission
  - `src/pager.cyr` (~114) — pager spawn + SIGPIPE handling
  - `src/vcs.cyr` (~323) — git VCS markers (M6)
  - `src/config.cyr` (~277) — `key = value` config parser (M7)

## Tests

- `tests/owl.tcyr` — unit assertions
- `scripts/smoke.sh` — end-to-end behavioral gates (M0 → M8)
- `tests/owl.bcyr` — benchmark slot (reserved)
- `tests/owl.fcyr` — fuzz slot (reserved)

## Dependencies

- **Cyrius stdlib** — `syscalls`, `alloc`, `fmt`, `io`, `fs`, `str`, `string`, `vec`, `args`, `hashmap`, `process`, `tagged`, `assert`
- **vyakarana** 1.0.2 — tokenizer + 11 bundled grammars (git-tag pinned in `[deps.vyakarana]`)

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

Post-v1 work: M7 may add a formal CYML parser from stdlib when `cyml` lands,
and M9+ will broaden grammar coverage via vyakarana's CYML loader (M2).
1.x backlog (per `ROADMAP.md`): `--wrap=character`, `--line-range=A:B`,
hex-dump fallback for binary files, user-installable grammars/themes.
