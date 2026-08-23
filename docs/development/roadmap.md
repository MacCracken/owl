# owl — Roadmap

Forward-looking planning surface. Latest release and prior history
live in `CHANGELOG.md`; this file tracks what's *next*. Current
release is **1.4.0** — the **1.4.x feature line** is open and its
headline item (the **SIT dependency swap**) has shipped: owl's VCS
gutter now reads markers from sit's `sit_diff_path` library instead
of forking `git`. The 1.3.x catchup window closed earlier (all 2.1.x
grammars wired, vyakarana 2.x migration, HIGHLIGHT_MAX lift), and
1.3.7/1.3.8 added the AGNOS target. Remaining 1.4.x items each have a
sketch below; none gate on toolchain or grammar work.

---

## Shipped since 1.0.0

Anchors the current state so the rest of this file reads as
forward-looking. Full prose in `CHANGELOG.md`.

| Release | Date       | Headline                                                |
|---------|------------|---------------------------------------------------------|
| 1.4.5   | 2026-08-22 | cyrius 6.5.35 + deps to latest; the four object-store layers become stdlib leaves; `--agnos` target returns; 46 grammars (openqasm) |
| 1.4.4   | 2026-07-07 | `--diff` discovers the file's own repo (walk-up), warns when outside |
| 1.4.3   | 2026-07-06 | VCS gutter works on AGNOS (via the sit repo-root port)   |
| 1.4.2   | 2026-06-22 | cyrius 6.2.37 (agnosys-retirement line); vendored `lib/` refresh |
| 1.4.1   | 2026-06-19 | Toolchain + dep refresh; `random` stdlib declaration     |
| 1.4.0   | 2026-06-14 | SIT dependency swap — VCS gutter via sit_diff_path (off git); cyrius 6.2.2 + vyakarana 2.2.3 |
| 1.3.8   | 2026-06-09 | agnos `owl FILE` fix (top-level entry; cyrius 6.1.14)   |
| 1.3.7   | 2026-06-09 | AGNOS target support — `owl --agnos`; cyrius 6.0.56     |
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

## 1.4.x roadmap (feature line)

The 1.x line continues — 2.0.0 isn't on the table until either a
genuine breaking-change need surfaces or AGNOS itself reaches a
ship boundary that justifies coordinated major bumps. The
following items are 1.4.x candidates; ordering is rough
priority, not commitment. Each is independent — they don't
have to ship in order.

- ~~**SIT dependency swap.**~~ **Shipped in 1.4.0** (2026-06-14).
  `src/vcs.cyr` was rewritten from `execve("git", "diff", …)` to
  sit's `sit_repo_open` / `sit_diff_path` / `sit_repo_close`
  library calls (sit 1.0.1, ADR 0009 surface), walking the LCS
  edit script into the same ADD/MOD/DEL markers. The five-fn
  public interface is unchanged. The first co-link surfaced a
  patra↔vyakarana `TK_*` symbol collision, fixed upstream as
  patra 1.11.2; the broader stdlib-collision class is filed for
  cyrius. Follow-ups: binary-size trim (owl is ~2.6 MB while it
  links sit's full bundle — pending the 6.x lib-streamlining arc)
  and sit repo-root discovery (markers need owl run from the
  `.sit/` root, as sit 1.0.1 has no upward search).
- **NDJSON output mode (`--format=ndjson`).** Emit tokens as
  one JSON object per line for downstream tooling
  (editor LSP-style consumers, code analyzers, indexing). The
  shape mirrors vyakarana's existing NDJSON debug output:
  `{"line": N, "col": C, "kind": "keyword", "text": "fn"}` per
  token. Builds directly on the streaming-tokenizer primitive
  owl already drives at 1.3.6 — drain after each feed, emit
  per-token JSON, no buffer-resident render loop.
- **`--follow` / `-f` (tail-style live highlighting).**
  inotify-watch the file; on each modify event re-tokenize
  the changed region and emit ANSI for the new bytes. Mirrors
  `tail -f` semantics. Needs a re-tokenize strategy that
  doesn't reset the user's scroll position; vyakarana's 2.0.1
  rolling-buffer scanner makes the per-event cost cheap, but
  owl-side rendering needs a "append-only ANSI" path that's
  distinct from the current full-rerender shape.
- **URL / remote-file support (`owl https://…`).** Fetch a
  remote document via HTTP and render it like a local file.
  Out of scope for v1 per design-spec §1; revisitable now
  that sandhi (Cyrius's HTTP/TLS stack) is mature enough to
  consume from owl. Adds a real network dep — needs an
  explicit opt-in flag or schema-allowlist. Could ride
  alongside the SIT swap if both want the same TLS surface.
- **Native AGNOS theming integration.** When AGNOS ships its
  system-wide theming primitive, owl's `theme_*` palette layer
  becomes a thin shim over it instead of a self-contained 256-
  color table. Architecture note 004 conformance from 1.3.0
  (kind_name string keys for theme dispatch) is the load-
  bearing prep — themes are already keyed on the stable
  contract, so the swap is mechanical. Currently blocked on
  AGNOS itself.

### Closed in 1.3.x

- ~~**Streaming tokenizer / `HIGHLIGHT_MAX` lift.**~~ Closed at
  1.3.6 (2026-05-09). vyakarana 2.0.0 introduced the push-based
  streaming primitive ([ADR 0017](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0017-streaming-api.md));
  2.0.1's rolling-buffer scanner caps live span at 16 MB
  rather than total input. owl 1.3.1 migrated to the streaming
  API; owl 1.3.6 hoisted the lifecycle into the slurp callers
  to drive per-chunk feed during the read loop, lifting
  `HIGHLIGHT_MAX` from 128 KB to 16 MB.

### Closed in 1.2.x

- ~~**Further bundled-grammar broadening.**~~ Closed by the 1.2.0
  → 1.2.6 lockstep cascade tracking vyakarana 1.2.x → 1.8.0
  and extended through 1.3.0 (cyml + llvm_ir) and 1.3.2–1.3.5
  (the 2.1.x batch — PowerShell, Crystal, Julia, Vue, Svelte,
  Nix, Terraform) and 1.4.5 (openqasm, from the 2.3.5 drop).
  Bundled palette stands at **46 grammars**.
  Per-language wiring template stays valid for any future
  vyakarana grammar drop: a `lang_name` / `lang_exts` entry
  in `src/lang.cyr` + matching `_owl_load_grammar` calls in
  `_owl_bootstrap_grammars` + a smoke gate + a row in
  `docs/grammar-coverage.md`. Filename-shape grammars (no
  extension) additionally need a line in
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
| Vyakarana grammar changes break owl's token palette | Palette is frozen at 10 kinds; kind names are the stable contract per [vyakarana architecture note 004](https://github.com/MacCracken/vyakarana/blob/main/docs/architecture/004-theme-palette-contract.md); owl dispatches via `kind_name(k)` since 1.3.0. Pin vyakarana tag in `cyrius.cyml` |
| `HIGHLIGHT_MAX` surprises a user with a >16 MB source file | Stderr notice on fallback in place; cap was lifted from 128 KB to 16 MB at 1.3.6. Files past 16 MB still drop to plain rendering with a clear notice — true streaming-render-and-discard is filed as a future-when-needed item |
| ~~SIT takes longer than expected to ship~~ | **Resolved 1.4.0** — sit 1.0.1 shipped the library export; owl swapped off git. New tracked risk: owl now links sit's full object-store bundle (~2.6 MB binary) — mitigated by DCE today, to be trimmed by the cyrius 6.x lib-streamlining arc |
