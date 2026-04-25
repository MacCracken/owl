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
| `--color=always` actually emits ANSI for **file paths** when stdout is a pipe | **Follow-up to 2026-04-25 decision-log entry.** That entry recorded "file paths already honored that — the actual gap was that the stdin render path (`render_fd`) had no highlight branch at all. Fixed in 1.1.0." Owner re-verified 2026-04-25 against owl 1.1.0: issue still present in the file-path scenario (`owl --color=always --paging=never <file.cyr> \| xxd` produces zero `0x1b` bytes; also reproduced with `--language=shell` on a shell file, ruling out cyrius-grammar specifics). The stdin path was indeed fixed in 1.1.0; the file-path-into-pipe case was not — either the decision-log claim was wrong about the file-path side or there's a regression. Update the decision-log entry once the actual root cause is known. |
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

| Date       | Question | Decision | Rationale |
|------------|----------|----------|-----------|
| 2026-04-22 | Theme format: reuse existing (e.g. TextMate/Sublime) or custom? | Custom CYML | Keeps toolchain consistent; refuses incumbent baggage |
| 2026-04-23 | Grammar source for M3b? | vyakarana 1.0.2 (git-tag dep) | Library-first Cyrius-native tokenizer; ten-kind palette already matches theme shape |
| 2026-04-23 | Highlight file-size ceiling? | 128 KB (`HIGHLIGHT_MAX`) | Bump allocator keeps file + tokenbuf + ANSI-inflated output resident; lifts with a freeing allocator or vyakarana streaming (their 2.x) |
| 2026-04-23 | M6 VCS backend before SIT? | Shell-free `execve` `git diff` confined to `src/vcs.cyr` | SIT will replace this layer wholesale; minimum-honest scaffold in the meantime. Argv-based (not `sh -c`) per audit FINDING-003 |
| 2026-04-23 | Config file format? | CYML key=value, no sections, own parser | Surface too small for sections; avoiding a `cyml` stdlib dep keeps the owl binary lean |
| 2026-04-23 | Strip file-origin terminal escapes in decorated mode? | Yes; `-r` / `--raw-control-chars` opt-out | Audit FINDING-001: OSC-52, title-report, DA-reply, iTerm2 OSC-1337 attack classes. `less -R` precedent. |
| 2026-04-25 | Should stdin support syntax highlighting? | Yes — slurp up to `HIGHLIGHT_MAX`, tokenize, fall back to streaming on overflow | Symmetry with file path. The cyrius v5.6.45 ticket originally reported this as "`--color=always` ignored when stdout is piped" but file paths already honored that — the actual gap was that the stdin render path (`render_fd`) had no highlight branch at all. Fixed in 1.1.0 |
| 2026-04-25 | 1.1.1 release scope and pacing | Five S-effort CLI improvements bundled as one patch (`--version --verbose`, `--strip-ansi=*`, `--line-range=A:B`, `ext.<extension>` config, `--wrap=character`) | Strict SemVer would put new flags in minor versions; owl's pre-2.0 phase intentionally treats patches as "small, frequent ergonomics" so users get incremental value without minor-bump churn. Each feature has a smoke gate; total +354 lines of source, +7 KB binary |

---

## Risks being tracked

| Risk | Mitigation |
|------|------------|
| Pager integration breaks on AGNOS before the OS ships | `--paging=never` is a reliable fallback; test with `PAGER=cat` |
| Vyakarana grammar changes break owl's token palette | Palette is frozen at 10 kinds; vyakarana CHANGELOG-flags any layout change. Pin vyakarana tag in `cyrius.cyml` |
| `HIGHLIGHT_MAX` surprises a user with a 200 KB source file | Stderr notice on fallback (shipped in 1.0.0); M3b streaming lifts the cap |
| Memory-allocator change exposes latent `waitpid` buffer bug | Closed by audit FINDING-004 — both sites now size correctly |
| SIT takes longer than expected to ship | Current `git` scaffold is stable and covered by smoke; no urgency beyond SIT's own timeline |
