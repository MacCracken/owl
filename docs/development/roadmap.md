# owl — Roadmap

owl 1.1.1 shipped 2026-04-25 (ergonomics drop: `--version --verbose`,
`--strip-ansi=*`, `--line-range=A:B`, per-language config overrides,
`--wrap=character`). M0–M8 + 1.1.0 + 1.1.1 details live in
`CHANGELOG.md`; this file is the forward-looking planning surface.

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

## 1.x backlog

Small, self-contained improvements that don't require a new
dependency or a breaking-change window. Grouped into patch drops by
theme; each item adds a `scripts/smoke.sh` gate per the guiding
principles. (1.1.1 shipped — see `CHANGELOG.md`.)

### 1.1.2 — content fallbacks (M)

Items affect what owl does when the default path doesn't fit the
input, plus the post-1.1.0 follow-up to the file-path color path.

| Candidate | Rationale |
|-----------|-----------|
| Bundled grammars are loaded via relative `grammars/<name>.cyml` path — fail when invoked from non-owl cwd | **Root cause confirmed 2026-04-25 against owl 1.1.1.** The owl binary references its bundled grammars at the relative path `grammars/<name>.cyml` (verified by `strings build/owl \| grep grammars/`). When invoked from owl's source repo cwd, the lookup succeeds via `./grammars/`; from any other cwd (cyrius repo, `$HOME`, `/tmp`, an end-user's project tree), the grammar files are not found and owl silently falls back to plain output — `--color=always` becomes a no-op for syntax tokens. Surfaces NOT as a parse error or warning, just as zero ANSI bytes. **This was the actual cause of the cyrius v5.6.45 ticket.** The decision-log entry claiming "file paths already honored `--color=always`" was correct ONLY for invocations from inside the owl repo; the user-visible Claude Code routing case (`Read(**/*.cyr)` → `Bash(owl ...)` from cyrius cwd) hits the bug. Smoke gate added at `scripts/smoke.sh` (KNOWN-FAILURE marker; auto-flips to hard regression lock when fix lands). **Fix options:** (a) inline grammars into the binary at compile time (cleanest — small CYML files); (b) search absolute well-known paths (`/usr/share/owl/grammars/`, `$XDG_DATA_HOME/owl/grammars/`, `<dirname /proc/self/exe>/../share/owl/grammars/`); (c) read binary's own location and look relative to that. (b) and (c) keep the current packaging shape; (a) eliminates external file dependency entirely. Update the ADR / decision log entry once the fix approach is chosen. |
| Binary-file hex-dump fallback | `owl binary.bin` today emits a skip-notice; offer `xxd`-style hex dump as an opt-in or auto fallback. |
| User-installable grammars + themes | `$XDG_CONFIG_HOME/owl/{grammars,themes}/` overlays on top of the bundled set. Lets users add coverage without a vyakarana PR. |

### 1.1.3 — smarter detection + diff (M)

Builds on M3a (language detection) and M6 (VCS layer).

| Candidate | Rationale |
|-----------|-----------|
| Content-based language detection | Regex-anchored. Post-shebang fallback for files with no extension. |
| `--diff` mode | Show only changed hunks (uses existing VCS layer). |

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
| Pager integration breaks on AGNOS before the OS ships | `--paging=never` is a reliable fallback; test with `PAGER=cat` |
| Vyakarana grammar changes break owl's token palette | Palette is frozen at 10 kinds; vyakarana CHANGELOG-flags any layout change. Pin vyakarana tag in `cyrius.cyml` |
| `HIGHLIGHT_MAX` surprises a user with a 200 KB source file | Stderr notice on fallback (shipped in 1.0.0); M3b streaming lifts the cap |
| Memory-allocator change exposes latent `waitpid` buffer bug | Closed by audit FINDING-004 — both sites now size correctly |
| SIT takes longer than expected to ship | Current `git` scaffold is stable and covered by smoke; no urgency beyond SIT's own timeline |
