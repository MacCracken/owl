# owl — Issues Filed Upstream

Findings surfaced during owl work that belong to another project (cyrius, sit,
vyakarana, cmdit, or a folded stdlib layer) are filed in **that project's own
`docs/development/issues/`**, with any standalone reproduction in its `repros/`.
They do not live in owl. This file is only owl's index of them, so that a
workaround in owl can be traced to the filing that retires it.

## Filing

- Follow the target repo's own issue conventions. cyrius, for one, requires
  `**Status:**` and `**Placement:**` lines; see its issues README.
- Filename: `YYYY-MM-DD-{dep}-{short-slug}.md`, kebab-case. The date is the
  discovery date and the name stays stable, so references keep working.
- Before filing, check the finding against the target's live code and its
  existing issues.
- State what fails, where, and owl's status. Severity follows sit's scale:
  - **Critical** — silent data corruption, security, SIGSEGV on first-party use.
  - **High** — a hard failure on a shipping consumer with no workaround.
  - **Medium** — a hard failure with a workaround, or a silent cost or wrong
    answer.
  - **Low** — misleading messages, doc drift, papercuts.
- Add a row below, and leave the target repo's change uncommitted for the user.

## Lifecycle

When the upstream fix lands and owl picks it up, the issue is resolved in the
target repo under its own rules. owl retires its workaround, notes it in the
CHANGELOG, and deletes the row here.

## Open

Paths are relative to the shared parent of the repos.

From the 2026-10-31 audit (owl 1.5.3, `../../audit/2026-10-31-audit.md`):

| File | Severity | Audit ID |
|------|----------|----------|
| `sit/docs/development/issues/2026-10-31-sit-diff-path-flattens-whole-head-tree.md` | High | INFO-004 |
| `sit/docs/development/issues/2026-10-31-sit-read-api-unbounded-store-lock-wait.md` | Medium | INFO-005 |
| `sit/docs/development/issues/2026-10-31-sit-diff-path-unreadable-reads-as-absent.md` | Medium | INFO-006 |
| `sit/docs/development/issues/2026-10-31-sit-gitattributes-eol-not-applied.md` | Low | INFO-007 |
| `sit/docs/development/issues/2026-10-31-sit-read-bundle-commit-tree-hex-dangling.md` | Low | INFO-008 |
| `vyakarana/docs/development/issues/2026-10-31-vyakarana-stream-buffers-never-reclaimed.md` | Medium | INFO-009 |
| `vyakarana/docs/development/issues/2026-10-31-vyakarana-public-api-for-owl-private-uses.md` | Low | — |
| `cyrius/docs/development/issues/2026-10-31-cyrius-linux-argv-needs-proc.md` | Low | INFO-010 |

From the owl 1.6.0 work:

| File | Severity | Audit ID |
|------|----------|----------|
| `vyakarana/docs/development/issues/2026-10-31-vyakarana-missing-routes.md` | Low | — |
| `cmdit/docs/development/issues/2026-10-31-cmdit-completions-verbless-tools.md` | Medium | — |
