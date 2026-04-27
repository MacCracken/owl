# owl — Roadmap

Forward-looking planning surface. Latest release and prior history
live in `CHANGELOG.md`; this file tracks what's *next*. Current
release is **1.1.9**; the 1.x line is in polish mode and the major
forward work is 2.x, gated on external dependencies.

---

## Shipped since 1.0.0

Anchors the current state so the rest of this file reads as
forward-looking. Full prose in `CHANGELOG.md`.

| Release | Date       | Headline                                                |
|---------|------------|---------------------------------------------------------|
| 1.1.9   | 2026-04-27 | `↪` wrap-arrow continuation glyph                       |
| 1.1.8   | 2026-04-27 | Frame containment — `--wrap=auto` defaults wrap-on      |
| 1.1.7   | 2026-04-27 | bat-style three-rule header frame; cyrius 5.7.12        |
| 1.1.6   | 2026-04-26 | `--line-range` `head` idiom hint; cyrius 5.7.7          |
| 1.1.5   | 2026-04-26 | Pager spawn forwards parent envp (TERM, LANG, …)        |
| 1.1.4   | 2026-04-25 | Content-based language detection; `--diff` mode         |
| 1.1.3   | 2026-04-25 | `--hex` + auto hex-dump; user grammars/themes overlay   |
| 1.1.2   | 2026-04-25 | Bundled grammars resolve via `/proc/self/exe`           |
| 1.1.1   | 2026-04-25 | `--line-range`, `--strip-ansi`, `--wrap=character`, …   |
| 1.1.0   | 2026-04-25 | Stdin syntax highlighting                               |

---

## Guiding principles

- **Correctness before features.** A release that does five things
  perfectly beats one that does fifteen unreliably.
- **Ship plain mode first, decorations later.** `-p` must always be
  byte-identical `cat`.
- **Every change is testable.** No change lands without an
  addition to `scripts/smoke.sh` (behavioral gate) or
  `tests/owl.tcyr` (unit).
- **Defer what you can.** Keep later-release items out of
  earlier releases even when they look easy.

---

## 1.x polish (small, opportunistic)

- **Exact-gutter wrap math.** `resolve_mode` currently subtracts
  `c - 11` (VCS-on gutter width) when computing `g_wrap_cols`,
  regardless of whether VCS is active for the current file. With VCS
  off the gutter is only 9 cols, so wrapped content stops 2 cols
  short of the right rule. Cosmetic; tightening means deferring the
  wrap-cols computation until after `vcs_compute_markers` runs (or
  recomputing per-file). Park until either someone notices the
  visual gap or another wrap-region change motivates the touch.

---

## 2.x backlog (breaking / large)

- **SIT dependency swap.** When SIT (planned AGNOS-native VCS)
  ships, `src/vcs.cyr` becomes a single-file rewrite: replace the
  `execve("git", …)` path with a SIT library call. Interface
  stays (`vcs_compute_markers`, `vcs_mark_for_line`,
  `vcs_enabled`, `vcs_reset`, `set_style`). Tracked in memory.
- **Streaming tokenizer.** Raise `HIGHLIGHT_MAX` past 128 KB
  when either (a) the bump allocator gets a `free()` or (b)
  vyakarana's streaming tokenizer (their 2.x ROADMAP) ships.
- **`--follow` / `-f` (tail-style live highlighting).** Needs
  inotify and a re-tokenize strategy. Deferred explicitly.
- **URL / remote-file support.** `owl https://…` fetching a
  remote document. Out of scope for v1 per design-spec §1.
- **JSON / structured output mode.** Emit tokens as NDJSON for
  tool interop. Builds directly on vyakarana's NDJSON shape.
- **Native AGNOS theming integration.** Wait until the AGNOS
  theming system ships.

---

## Post-v1 parked ideas

Not committed to a release — parked so future work doesn't
accidentally pull them into a patch.

- Shell completion scripts (bash, zsh, fish, any AGNOS-native
  shell).
- Localization of error messages.
- `--diff-from=<ref>` — compare to a named git ref instead of
  HEAD.
- Integration with a future AGNOS package manager beyond the
  plain `cyrius build` path.
- Man page (currently the `--help` output is comprehensive;
  revisit when a wider distribution pipeline exists).

---

## Decision log

Architectural decisions live in [`../adr/`](../adr/) as individual,
immutable records. This roadmap tracks forward-looking work; the
ADR set tracks the *why* behind structural choices already made.

See [`../adr/README.md`](../adr/README.md) for the full index.

---

## Risks being tracked

| Risk | Mitigation |
|------|------------|
| Pager integration breaks on AGNOS before the OS ships | `--paging=never` is a reliable fallback; test with `PAGER=cat`. Real-world precedent: 1.1.5 fixed a missing-`TERM` regression where `less` exited at terminfo init, by forwarding `/proc/self/environ` to the child |
| Vyakarana grammar changes break owl's token palette | Palette is frozen at 10 kinds; vyakarana CHANGELOG-flags any layout change. Pin vyakarana tag in `cyrius.cyml` |
| `HIGHLIGHT_MAX` surprises a user with a 200 KB source file | Stderr notice on fallback already in place; the streaming tokenizer 2.x item lifts the cap |
| SIT takes longer than expected to ship | Current `git` scaffold is stable and covered by smoke; no urgency beyond SIT's own timeline |
