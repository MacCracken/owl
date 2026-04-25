# ADR 0001: Theme format — custom CYML

- **Status**: Accepted
- **Date**: 2026-04-22
- **Deciders**: @MacCracken

## Context

owl needs a portable on-disk format for syntax-highlighting themes
(token colors per-kind, plus theme-level metadata like header and
gutter foreground). Two paths were considered:

1. **Reuse an incumbent.** TextMate `.tmTheme` and Sublime
   `.sublime-color-scheme` are widely supported and would let users
   drop in pre-existing themes from other tools.
2. **Custom CYML.** Define a small owl-specific schema using the
   AGNOS-native CYML serialization that vyakarana grammars already
   use.

Incumbents bring baggage: TextMate's plist XML requires a parser owl
doesn't have; Sublime's JSON variant has historical quirks (rgba(),
embedded variables) that don't map cleanly to terminal SGR codes.
owl's palette is also intentionally narrow — ten kinds, fixed —
which most external themes over-specify.

## Decision

We will define a custom theme format using CYML. Themes ship with
the binary (dark and light, bundled at compile time). The schema is
flat key=value with one entry per token kind plus a small set of
theme-level keys.

## Consequences

- Toolchain consistency: owl, vyakarana, and AGNOS-native config all
  use CYML. One mental model.
- Users cannot drop in `.tmTheme` files. If demand emerges, a
  one-off converter can ship later as a separate tool.
- The 10-kind palette is the surface contract; theme files map
  kinds → colors with no escape hatch for hyper-specific cases.
- No external schema-validator dependency; `theme.cyr` parses
  bundled themes inline.
