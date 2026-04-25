# ADR 0002: Grammar source — vyakarana 1.0.2 (git-tag dep)

- **Status**: Accepted
- **Date**: 2026-04-23
- **Deciders**: @MacCracken

## Context

owl's M3b milestone (token-level highlighting) needs a tokenizer and
a grammar set. Three options:

1. **Hand-write a tokenizer per language inside owl.** Maximum
   control; minimum reuse; multiplies surface area.
2. **Bind to `tree-sitter` or another C library via FFI.** Mature
   grammars, but pulls in a non-AGNOS dependency and an FFI surface
   owl explicitly avoids at this stage.
3. **Use vyakarana**, the Cyrius-native tokenizer in the sibling
   repo. Already structured around a fixed ten-kind token palette
   that maps directly onto owl's theme schema (ADR 0001).

vyakarana 1.0.2 has eleven bundled grammars (shell, python, js, ts,
rust, c, cyrius, toml, json, yaml, markdown). The token shape is
stable; CHANGELOG flags any breaking layout change.

## Decision

We will depend on vyakarana 1.0.2 via a git-tag pin in
`cyrius.cyml [deps.vyakarana]`. Token kinds map 1:1 onto owl's
10-kind palette. Grammar files (`grammars/*.cyml`) ship alongside
the owl binary as runtime data.

## Consequences

- One non-stdlib dependency. The pin is explicit and `cyrius deps`
  resolves it.
- Grammar fixes happen upstream in vyakarana, not in owl. Owl never
  modifies grammars directly.
- Adding a new language is a vyakarana PR, then a pin bump in owl.
- Streaming-tokenizer support (vyakarana 2.x) will lift owl's
  `HIGHLIGHT_MAX` ceiling (see ADR 0003) when it ships.
- Tokenization correctness is vyakarana's problem, not owl's.
