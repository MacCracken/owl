# ADR 0007: Stdin syntax highlighting

- **Status**: Accepted
- **Date**: 2026-04-25
- **Deciders**: @MacCracken

## Context

A cyrius v5.6.45 ticket originally reported the symptom as
"`--color=always` ignored when stdout is piped." On investigation,
the file-path code path (`render_path`) already honored
`--color=always` correctly; the actual gap was that the stdin code
path (`render_fd`) had no highlight branch at all. Stdin always
went straight to `render_chunk` (plain-byte streaming), regardless
of `--language=` or `--color=always`.

This affected every consumer that piped content through owl:
Claude Code's `Read(**/*.cyr)` routing, scripted log capture,
`script(1)` recording, CI gates that wanted colored diffs.

The design spec (§1) lists "stdin piping" as a supported feature
and `--language` as "Force language for syntax highlighting" — so
stdin highlighting was always in scope; it just was never
implemented.

## Decision

We will mirror `render_path`'s slurp-then-tokenize branch in
`render_fd`. Stdin reads up to `HIGHLIGHT_MAX` (128 KB, see
ADR 0003) into a buffer, tokenizes once via vyakarana, and emits
per-token color through the same `render_highlighted_buf` the
file-path branch uses. On overflow (input exceeds the cap), stdin
falls through to streaming `render_chunk` with the same stderr
notice `render_path` emits.

Stdin without `--language` stays plain — there is no path or
extension to detect from, and shebang-detection on stdin is
deferred to a follow-up ADR if it becomes a forcing function.

## Consequences

- Symmetry with file paths: `owl --color=always --language=rust < x.rs`
  and `owl --color=always --paging=never x.rs` produce equivalent
  highlight output.
- Stdin inherits the `HIGHLIGHT_MAX` ceiling. Large stdin streams
  fall through to plain streaming with the same notice.
- Memory cost: buffered stdin holds up to 128 KB resident before
  tokenization. Acceptable per the bump-allocator analysis in
  ADR 0003.
- Released in owl 1.1.0.
- Documented in CHANGELOG.md under `[1.1.0]` "Fixed".

## Amendment — 2026-04-25

The Context section above stated that "the file-path code path
(`render_path`) already honored `--color=always` correctly." This
was true *only when owl was invoked from its own source repo cwd*.
From any other cwd (cyrius repo, `$HOME`, `/tmp`, an end-user's
project tree), the file-path branch *also* produced zero ANSI bytes
— root cause: the binary loads bundled grammars via the relative
path `grammars/<name>.cyml` (verified via `strings build/owl |
grep grammars/`), which silently fails when the cwd has no
`grammars/` subdirectory.

The stdin highlight gap fixed by this ADR was real and structurally
independent — `render_fd` had no highlight branch at all,
regardless of cwd. The grammar-cwd-portability issue is a separate
bug affecting both render paths once they call into vyakarana.

The cyrius v5.6.45 ticket required *both* fixes to fully close:
- 1.1.0 — `render_fd` gains a highlight branch (this ADR).
- 1.1.2 (planned) — grammar lookup becomes cwd-independent.

The 1.1.2 fix gets its own ADR once the approach is chosen
(inline at compile time vs. well-known absolute paths vs.
exe-relative resolution). A KNOWN-FAILURE smoke gate at
`scripts/smoke.sh` pins the bug and auto-flips to a hard
regression lock when the fix lands.
