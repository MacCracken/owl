# owl — Upstream Issue Writeups

Findings surfaced during owl work that belong **upstream** (cyrius, sit,
vyakarana, cmdit, or a folded stdlib layer) are written up here. The user carries
each one across to the target repo's own `docs/development/issues/`; owl does
not edit upstream repos directly. This mirrors sit's
`docs/development/issues/README.md`.

## Filename convention

`YYYY-MM-DD-{dep}-{short-slug}.md`, kebab-case. Date = discovery date, kept
when the issue is later resolved. Standalone reproductions go in `repros/`
under the same date prefix.

## Body template

The cyrius issues template, which sit also uses:

```markdown
# {title} — OPEN

**Discovered:** YYYY-MM-DD during {context}
**Severity:** Low / Medium / High / Critical
**Affects:** {dep} {version range}

## Summary
## Reproduction
## Root cause (if known)
## Proposed fix
## Consumer-side workaround (if any)
```

Severity follows sit's scale:
- **Critical** — silent data corruption, security, SIGSEGV on first-party
  use.
- **High** — a hard failure on a shipping consumer with no workaround.
- **Medium** — a hard failure with a workaround, or a silent cost or
  wrong answer.
- **Low** — misleading messages, doc drift, papercuts.

## Lifecycle

When the upstream fix lands and owl picks it up, add `— RESOLVED` to the
heading, point at the fixing version and the owl CHANGELOG entry that
retired the workaround, and move the file to `archived/`.

## Open

From the 2026-10-31 audit (owl 1.5.3, `../../audit/2026-10-31-audit.md`):

| File | Owner | Severity | Audit ID |
|------|-------|----------|----------|
| [2026-10-31-sit-diff-path-flattens-whole-head-tree.md](2026-10-31-sit-diff-path-flattens-whole-head-tree.md) | sit | High | INFO-004 |
| [2026-10-31-sit-read-api-unbounded-store-lock-wait.md](2026-10-31-sit-read-api-unbounded-store-lock-wait.md) | sit | Medium | INFO-005 |
| [2026-10-31-sit-diff-path-unreadable-reads-as-absent.md](2026-10-31-sit-diff-path-unreadable-reads-as-absent.md) | sit | Medium | INFO-006 |
| [2026-10-31-sit-gitattributes-eol-not-applied.md](2026-10-31-sit-gitattributes-eol-not-applied.md) | sit | Low | INFO-007 |
| [2026-10-31-sit-read-bundle-commit-tree-hex-dangling.md](2026-10-31-sit-read-bundle-commit-tree-hex-dangling.md) | sit | Low | INFO-008 |
| [2026-10-31-vyakarana-stream-buffers-never-reclaimed.md](2026-10-31-vyakarana-stream-buffers-never-reclaimed.md) | vyakarana | Medium | INFO-009 |
| [2026-10-31-vyakarana-public-api-for-owl-private-uses.md](2026-10-31-vyakarana-public-api-for-owl-private-uses.md) | vyakarana | Low | — |
| [2026-10-31-cyrius-linux-argv-needs-proc.md](2026-10-31-cyrius-linux-argv-needs-proc.md) | cyrius | Low | INFO-010 |

From the owl 1.6.0 work:

| File | Owner | Severity | Audit ID |
|------|-------|----------|----------|
| [2026-10-31-vyakarana-missing-routes.md](2026-10-31-vyakarana-missing-routes.md) | vyakarana | Low | — |
| [2026-10-31-cmdit-completions-verbless-tools.md](2026-10-31-cmdit-completions-verbless-tools.md) | cmdit | Medium | — |
