# Architecture Decision Records

Durable, individually-citable records of architectural decisions made
in owl. Each ADR captures one decision: the question that prompted it,
the context that constrained it, what was decided, and the
consequences accepted in trade.

## Format

Each ADR follows this template:

```markdown
# ADR NNNN: <one-line title>

- **Status**: Accepted | Superseded by NNNN | Deprecated
- **Date**: YYYY-MM-DD
- **Deciders**: <name(s)>

## Context

The forces at play: constraints, prior art, the problem being solved.

## Decision

What was decided, in active voice. ("We will …")

## Consequences

Trade-offs accepted, follow-up work created, doors closed.
```

ADR numbers are zero-padded to four digits and never reused.
Once Accepted, an ADR is immutable except to add a Superseded-by
pointer; new context creates a new ADR.

## Index

| #    | Date       | Title                                                                   | Status   |
|------|------------|-------------------------------------------------------------------------|----------|
| 0001 | 2026-04-22 | [Theme format: custom CYML](0001-theme-format-custom-cyml.md)            | Accepted |
| 0002 | 2026-04-23 | [Grammar source: vyakarana git-tag dep](0002-grammar-source-vyakarana.md) | Accepted |
| 0003 | 2026-04-23 | [Highlight ceiling: 128 KB](0003-highlight-ceiling-128kb.md)             | Accepted |
| 0004 | 2026-04-23 | [VCS backend: shell-free `execve` git](0004-vcs-backend-execve-git.md)   | Accepted |
| 0005 | 2026-04-23 | [Config format: flat CYML key=value](0005-config-format-flat-cyml.md)    | Accepted |
| 0006 | 2026-04-23 | [Strip file-origin terminal escapes](0006-strip-file-origin-escapes.md)  | Accepted |
| 0007 | 2026-04-25 | [Stdin syntax highlighting](0007-stdin-syntax-highlighting.md)           | Accepted |
| 0008 | 2026-04-25 | [1.1.1 release pacing](0008-1.1.1-release-pacing.md)                    | Accepted |
