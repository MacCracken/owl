# ADR 0003: Highlight file-size ceiling — 128 KB (`HIGHLIGHT_MAX`)

- **Status**: Accepted
- **Date**: 2026-04-23
- **Deciders**: @MacCracken

## Context

Token-level highlighting requires the full file to be resident in
memory: vyakarana tokenizes a buffer in one pass, and owl walks
tokens against the buffer to emit per-byte SGR codes. The Cyrius
bump allocator does not free, so peak memory holds:

1. The file content (`buf`, N bytes).
2. The tokenbuf (~12 bytes per token; rough rule of thumb 0.5–1×
   file size for source code).
3. The ANSI-inflated output buffer the kernel write path eventually
   drains (~2× file size with dense color escapes).

Effective working set: roughly 4× file size. Without a freeing
allocator or a streaming tokenizer, raising the cap risks OOM on
modest files.

## Decision

We will set `HIGHLIGHT_MAX = 131072` (128 KB). Files larger than
this fall back to streaming `render_chunk` with no token color; the
gutter, line numbers, header, and `-A` glyphs all still render. A
one-line stderr notice tells the user why color is missing.

## Consequences

- 128 KB covers ~95% of source files in typical repos.
- Above the cap, no color but full decorations — a graceful
  degradation rather than a hard failure.
- Lifting the cap requires either (a) a freeing allocator in Cyrius
  or (b) vyakarana's 2.x streaming tokenizer; tracked in 2.x
  backlog (see `docs/development/roadmap.md`).
- The stderr notice is sanitized via `eprint_sanitized` (see
  ADR 0006) to prevent escape-injection through file paths.
- Stdin highlight (ADR 0007) inherits this ceiling — slurps up to
  `HIGHLIGHT_MAX` and falls through to streaming on overflow with
  the same notice shape.
