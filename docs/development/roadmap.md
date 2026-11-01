# owl — Roadmap

Forward-looking planning surface: this file tracks what is *next*.
What has shipped is in `CHANGELOG.md`, and live state (version, sizes,
pins, open findings) is in `state.md`.

**Where we are.** The current release is **1.6.0**, on cyrius 6.7.18,
vyakarana 2.10.0 (49 grammars), sit 1.13.0 and cmdit 1.5.0.
- Languages route through vyakarana, with no tables of owl's own.
- The bundled grammars come from the binary.
- `--follow` is token-coloured.
- The CLI is parsed by cmdit.

The 1.5.x line moved owl onto cyrius's 6.7 language line and closed the
P(−1) audit (`docs/audit/2026-10-31-audit.md`). URL support and AGNOS
theming are under [Beyond 1.6.x](#beyond-16x), each with the reason it is
blocked.

---

## Guiding principles

- **Correctness before features.** A release that does five things
  perfectly beats one that does fifteen unreliably.
- **Plain mode is sacred.** `-p` stays byte-identical to `cat`.
- **Every change is testable.** Nothing lands without a behavioural
  gate in `scripts/smoke.sh` or a unit test in `tests/owl.tcyr`, and a
  gate for a fix must be shown to fail against the release before it.
- **Defer what you can.** Keep later-release items out of earlier
  releases even when they look easy.

---

## 1.6.x — next feature line

What is left of the line is blocked upstream. Each item names what
unblocks it.

### Shell completions

cmdit generates bash / zsh / fish scripts from owl's flag table
(`cmdit_completions`). The parser half shipped in 1.6.0. Completions did
not, because cmdit 1.5.0's scripts assume the first argument is a
subcommand. For owl, `owl <TAB>` completes nothing, not even files, which
is worse than the shell's default. zsh and fish complete no flags at all.

- Unblocked by: the cmdit fix drafted in
  `docs/development/issues/2026-10-31-cmdit-completions-verbless-tools.md`.
- [ ] Then: `cmdit_enum(h, 0, "completions", 0, "bash|zsh|fish", …)` plus one
      `cmdit_completions` call. Gate `owl <TAB>` (files) and `owl --col<TAB>`
      (flags) in bash.

### `--diff-from=<ref>`

Compare to a named ref instead of HEAD. sit's read API has no ref
parameter: `sit_diff_path(repo, path)` always diffs the worktree against
HEAD (ADR 0009's stable surface).

- Unblocked by: a sit entry point that takes a ref, such as
  `sit_diff_path_at(repo, path, ref)`.
- [ ] Then: route the gutter through it. `vcs.cyr` keeps its five-function
      interface, so the change stays in that one file.

### Retire the routing supplement

`src/lang.cyr` `_owl_supplement` keeps the routes owl 1.5.3 had and
vyakarana 2.10.0 does not:
- `.tcyr`, `.bcyr` and `.fcyr` → cyrius;
- the deno, rust-script, swift, elixir, ocaml and ocamlrun shebangs.

Drafted upstream in
`docs/development/issues/2026-10-31-vyakarana-missing-routes.md`.

- [ ] On each vyakarana bump, delete the rows it now routes. Smoke gate
      1.6.0 (g) keeps passing either way. Delete the table when it is empty.

---

## Beyond 1.6.x

Each item is blocked or parked, with the reason.

- **URL / remote files (`owl https://…`).** The code is complete in
  `src/fetch.cyr` but not in the build, and any one of three reasons is
  enough to keep it out:
  - `sandhi_conn_open_fully_timed` timed out for every target, including
    a known-good local server that `curl` reached;
  - it costs about 521 KB;
  - it is new inbound network attack surface and needs its own audit.

  Unblocking starts with the sandhi transport, not with owl.
- **Native AGNOS theming.** Blocked on AGNOS shipping its system-wide
  theming primitive. The prep is done: owl's theme layer has been keyed
  on vyakarana's stable kind names since 1.3.0, so the swap is
  mechanical.
- **Parked ideas**, not committed to a release:
  - localized error messages;
  - a man page (`--help` is comprehensive until a wider distribution
    pipeline exists);
  - integration with a future AGNOS package manager.
- **2.0.0** is not on the table. It waits for a genuine breaking-change
  need, or for AGNOS to reach a ship boundary that justifies
  coordinated major bumps.

---

## Upstream items being tracked

- **From the 2026-10-31 audit:**
  - **sit:** INFO-004 – 008. The tree-bomb `.git` (INFO-004) is the one
    with real impact: `sit_diff_path` flattens HEAD's whole tree on every
    call. It should resolve one path by its components instead.
  - **vyakarana:** INFO-009, a stream's input copy is never reclaimed.
  - **cyrius:** INFO-010, argv via `/proc`.

  Each is drafted, with a repro, in `docs/development/issues/` (see its
  README), ready to carry upstream. None is filed yet. There is also a
  vyakarana API ask: make `tokenbuf_reset` public and document the
  registry-ordering contract that owl's overlay-first bootstrap relies on.
  owl 1.6.0 stopped writing `_grammars_bootstrapped`.
- **From the 1.6.0 work,** also drafted in `docs/development/issues/`:
  - **vyakarana:** the routes the supplement above carries;
  - **cmdit:** completions for a tool without subcommands.
- **cyrius: stdlib constant collisions.** Filed as
  `cyrius/docs/development/issues/2026-06-14-stdlib-constant-value-collisions.md`.
- **cyrius: `private` functions still collide across files.** Filed at
  1.4.7. It no longer bites owl, since vyakarana renamed its helper at
  2.4.2.
- **A formal CYML parser in the stdlib.** owl's minimal `key = value`
  config parser (M7) moves to it when `cyml` lands.

---

## Risks being tracked

| Risk | Mitigation |
|------|------------|
| Pager integration breaks on AGNOS | `--paging=never` is a reliable fallback; test with `PAGER=cat`. Precedent: 1.1.5 fixed a missing-`TERM` regression by forwarding `/proc/self/environ` to the child |
| vyakarana changes token boundaries under owl | Expected, and owl accepts them: tokenization is vyakarana's job. Kind names are the stable contract (architecture note 004), and the palette is frozen at 10 kinds. On a bump, check colour-stripped output is unchanged and highlighted output reproduces every file (the 1.5.1 invariants) |
| A dep bump silently changes owl's behaviour | Read cyrius's `ecosystem-migration.md` from the old pin up; A/B the gutter on an executable file and a final-newline change (1.5.1); compare the `unreachable fns` note after any stdlib-list change |
| `HIGHLIGHT_MAX` surprises a user with a >16 MB file | Stderr notice on fallback; files past 16 MB render plain. True streaming render-and-discard is filed for when it is needed |
| A grammar ships bundled but unreachable | 1.5.2's markdown gap. Closed by construction in 1.6.0: owl has no language table, and smoke gate 1.6.0 (b)–(c) checks that `--list-languages` equals `grammars/*.cyml` and that every bundled grammar routes from its declared extension or filename. Re-sync `grammars/` on each vyakarana bump, since the gate compares against it |

---

## Decision log

Architectural decisions live in [`../adr/`](../adr/) as individual,
immutable records; see [`../adr/README.md`](../adr/README.md). This
roadmap tracks forward-looking work; the ADRs record the *why* behind
choices already made.
