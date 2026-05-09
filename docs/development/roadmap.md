# owl — Roadmap

Forward-looking planning surface. Latest release and prior history
live in `CHANGELOG.md`; this file tracks what's *next*. Current
release is **1.3.6**; the 1.3.x catchup window is **closed** —
all 2.1.x grammars wired and the HIGHLIGHT_MAX lift shipped.
Major forward work beyond that is 2.x, gated on external
dependencies (sit library export still parked).

---

## Shipped since 1.0.0

Anchors the current state so the rest of this file reads as
forward-looking. Full prose in `CHANGELOG.md`.

| Release | Date       | Headline                                                |
|---------|------------|---------------------------------------------------------|
| 1.3.6   | 2026-05-09 | HIGHLIGHT_MAX 128 KB → 16 MB; per-chunk feed; closes 1.3.x catchup |
| 1.3.5   | 2026-05-09 | vyakarana 2.1.3 — Terraform / HCL (closes 2.1.x batch)  |
| 1.3.4   | 2026-05-09 | vyakarana 2.1.2 — Nix                                    |
| 1.3.3   | 2026-05-09 | vyakarana 2.1.1 — Vue + Svelte SFC + grammar-coverage doc |
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

## 1.3.x catchup window — closed

Per the user's "patches to catchup" plan settled when 1.3.1
landed, the 1.3.x window covered the vyakarana 2.x bump
(1.3.1 — surgical streaming-API migration) plus five focused
patches:

- **1.3.2** — vyakarana 2.1.0 grammars (PowerShell + Crystal +
  Julia)
- **1.3.3** — vyakarana 2.1.1 SFC grammars (Vue + Svelte) +
  `docs/grammar-coverage.md`
- **1.3.4** — vyakarana 2.1.2 grammar (Nix)
- **1.3.5** — vyakarana 2.1.3 grammar (Terraform / HCL)
- **1.3.6** — owl-side HIGHLIGHT_MAX lift (vyakarana 2.0.1
  rolling-buffer scanner unblock)

End state: 45 bundled grammars, 16 MB highlight cap, per-chunk
feed driving vyakarana's streaming primitive end-to-end. Future
catchup-style windows (when vyakarana ships another batch of
grammars or owl-relevant scanner work) follow the same shape:
one focused patch per upstream minor, no bundled toolchain
bumps mid-window.

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
