# owl — Roadmap

Forward-looking planning surface. Latest release and prior history
live in `CHANGELOG.md`; this file tracks what's *next*. Current
release is **1.3.2**; the 1.3.x catchup window is open with
four 2.1.x grammars + the HIGHLIGHT_MAX lift remaining (see
"1.3.x catchup patches" below). Major forward work beyond that
is 2.x, gated on external dependencies.

---

## Shipped since 1.0.0

Anchors the current state so the rest of this file reads as
forward-looking. Full prose in `CHANGELOG.md`.

| Release | Date       | Headline                                                |
|---------|------------|---------------------------------------------------------|
| 1.3.2   | 2026-05-09 | vyakarana 2.1.0 — PowerShell + Crystal + Julia          |
| 1.3.1   | 2026-05-09 | cyrius 5.10.10 + vyakarana 2.2.1 — streaming-API migration |
| 1.3.0   | 2026-05-08 | cyrius 5.9.43 + vyakarana 1.11.0 — cyml + llvm_ir + ADR-004 conformance |
| 1.2.6   | 2026-05-08 | vyakarana 1.8.0 — Dockerfile + Makefile + INI           |
| 1.2.5   | 2026-05-08 | vyakarana 1.7.0 — HTML + XML + CSS + SCSS               |
| 1.2.4   | 2026-05-08 | vyakarana 1.6.0 — SQL + GraphQL + Protobuf              |
| 1.2.3   | 2026-05-08 | vyakarana 1.5.0 — Elixir + OCaml + Haskell              |
| 1.2.2   | 2026-05-08 | vyakarana 1.4.0 — PHP + Ruby + Lua + Swift              |
| 1.2.1   | 2026-05-08 | vyakarana 1.3.0 — Java + Kotlin + C++ + C#              |
| 1.2.0   | 2026-05-08 | cyrius 5.9.41 + vyakarana 1.2.4 (asm_x86_64 + aarch64)  |
| 1.1.12  | 2026-05-08 | vyakarana 1.2.0 — Go + Zig grammars                     |
| 1.1.11  | 2026-05-08 | exact-gutter wrap math (last 1.x polish item)           |
| 1.1.10  | 2026-05-08 | cyrius 5.9.36 + vyakarana 1.1.0 toolchain refresh       |
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

## 1.3.x catchup patches

Open queue. Per the user's "patches to catchup" plan settled
when 1.3.1 landed (the surgical vyakarana 2.x migration cut),
each of these is a focused patch on top of 1.3.1's pin set —
no further toolchain bumps needed unless a fresh cyrius / vyakarana
release surfaces during the catchup window.

| Slot   | Vyakarana origin | Scope                                                                                  |
|--------|------------------|----------------------------------------------------------------------------------------|
| 1.3.3  | 2.1.1            | Vue + Svelte SFC grammars. Both are HTML-shaped outer tokenizers; no special detection beyond ext dispatch (`.vue`, `.svelte`).                                  |
| 1.3.4  | 2.1.2            | Nix grammar. `.nix` ext dispatch. Note: vyakarana ADR called out indented-string + path-literal gaps that owl inherits — same trade-off, not an owl problem.    |
| 1.3.5  | 2.1.3            | Terraform / HCL grammar. `.tf`, `.tfvars`, `.hcl` ext dispatch. The grammar is named `terraform` upstream — same name in owl's table.                            |
| 1.3.6  | 2.0.1 (lift)     | **HIGHLIGHT_MAX lift.** Rewire the slurp path in `render_path` / `render_stdin_highlighted` to drive `tokenize_stream_feed` per-chunk during the read loop instead of one-shot at the end. Cap moves from 128 KB total input to 16 MB live in-progress span (vyakarana's `VYK_STREAM_CAP`). Long files with normal comment density stream comfortably. |

Catchup-patch principles:

- **One vyakarana minor per patch** for the grammar work — same
  shape that worked for the 1.2.x cascade. Keeps each diff tight
  and bisectable.
- **No bundled toolchain bumps.** If cyrius or vyakarana ship a
  fresh release during the catchup window, evaluate as its own
  bump cut (likely 1.3.7 / 1.4.0), don't tack onto a catchup
  patch.
- **HIGHLIGHT_MAX lift is the highest-value catchup item** by
  user impact (lifts the cap from 128 KB to functionally-
  unlimited for normal-shape files). Could land first instead
  of last; ordering above mirrors the vyakarana shipping order
  rather than priority.

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

_Empty — last item closed in 1.1.11 (exact-gutter wrap math)._

---

## 2.x backlog (breaking / large)

- **SIT dependency swap.** When SIT (planned AGNOS-native VCS)
  ships, `src/vcs.cyr` becomes a single-file rewrite: replace the
  `execve("git", …)` path with a SIT library call. Interface
  stays (`vcs_compute_markers`, `vcs_mark_for_line`,
  `vcs_enabled`, `vcs_reset`, `set_style`). Tracked in memory.
- **Streaming tokenizer.** Raise `HIGHLIGHT_MAX` past 128 KB
  when either (a) the bump allocator gets a `free()` or (b)
  vyakarana ships a streaming tokenizer. Not on vyakarana's
  near-term list (1.2.0 → 1.8.0 was all grammar broadening, no
  scanner-architecture work), so this item stays parked until at
  least vyakarana 2.x.

- **`--follow` / `-f` (tail-style live highlighting).** Needs
  inotify and a re-tokenize strategy. Deferred explicitly.
- **URL / remote-file support.** `owl https://…` fetching a
  remote document. Out of scope for v1 per design-spec §1.
- **JSON / structured output mode.** Emit tokens as NDJSON for
  tool interop. Builds directly on vyakarana's NDJSON shape.
- **Native AGNOS theming integration.** Wait until the AGNOS
  theming system ships.

### Closed in 1.2.x

- ~~**Further bundled-grammar broadening.**~~ Closed by the 1.2.0
  → 1.2.6 lockstep cascade tracking vyakarana 1.2.x → 1.8.0. The
  bundled palette went 13 → 36 grammars, picking up everything
  vyakarana 1.8.0 ships (assembly, JVM, C-family, scripting,
  mobile, functional, data/IDL, markup/styling, DevOps). The
  per-language wiring template (entry in `lang_name`/`lang_exts`
  + `_owl_load_grammar` call in bootstrap + smoke gate) is what
  any future vyakarana grammar drop needs. Filename-shape grammars
  (no extension) additionally need a line in
  `detect_language_from_path` per the 1.2.6 dockerfile/makefile
  pattern.

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
