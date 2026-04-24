# owl — Roadmap

A phased plan for building `owl` from nothing to a polished release. Each milestone is independently shippable and adds a coherent layer of functionality. The goal is to have something usable at the end of every phase, not a 6-month march toward a first demo.

---

## Guiding principles for the roadmap

- **Ship plain mode first, decorations later.** Plain mode is the foundation — everything else is icing. If plain mode is broken, nothing else matters.
- **Every milestone is testable.** No "phase complete" without a checklist of observable behaviors.
- **Correctness before features.** A v1 that does five things perfectly beats a v1 that does fifteen things unreliably.
- **Defer what you can.** Items in later milestones should stay out of earlier ones even if they seem easy. Scope creep is the enemy.

---

## Milestone 0 — Scaffolding

**Goal:** A binary called `owl` exists, builds cleanly, and prints something.

- Project structure and build system for the target platform
- CI or equivalent on AGNOS / Cyrius (build + basic smoke test)
- `owl --version` and `owl --help` work
- `owl` with no args and a TTY prints a short help message
- License file, README stub, contribution notes

**Done when:** a fresh checkout builds and produces a working binary with no runtime behavior beyond version/help.

---

## Milestone 1 — `cat` parity (plain mode)

**Goal:** `owl -p` is a drop-in replacement for `cat` for all common cases.

- Read one or more files and write bytes to stdout
- Read from stdin when no files given or `-` is passed
- Mix files and stdin (`owl a.txt - b.txt`)
- Correct handling of broken pipes (`SIGPIPE` → clean exit)
- Exit codes per spec (0, 1, 2, 4)
- Errors to stderr in `owl: <path>: <reason>` format
- One file failing does not abort other files

**Testing:**
- Byte-for-byte comparison with `cat` for a corpus of text files
- `owl -p huge.log | head -5` exits cleanly
- `owl missing real.txt` prints error for one, contents of the other

**Done when:** you could alias `cat=owl -p` and not notice.

---

## Milestone 2 — TTY awareness & line numbers

**Goal:** When output goes to a terminal, show line numbers; when piped, stay plain.

- Detect whether stdout is a TTY
- Auto-switch between decorated and plain mode
- Line numbers with adaptive gutter width
- `--color <auto|always|never>`, `--paging <auto|always|never>`
- `-n` / `-N` to force numbers on/off
- File header when a file path is given (decorated mode only)
- Multiple file headers when concatenating

**Testing:**
- `owl file.txt` at prompt shows numbers
- `owl file.txt | cat` shows no numbers
- `owl a b c` shows three headers

**Done when:** the tool feels useful at the terminal and invisible in pipelines.

---

## Milestone 3 — Syntax highlighting

Split into two sub-milestones after a local-repo survey (2026-04-22)
turned up no port-ready grammar source anywhere in the AGNOS
ecosystem. Detection + theme infrastructure shipped first (M3a);
tokenization landed after vyakarana 1.0 cut a stable tokenizer
library (M3b).

### M3a — Detection + theme scaffolding ✅ shipped

**Goal:** Files are classified, themes are picked, and the existing
decorations (header, gutter) are color-aware. No token-level coloring
yet — that's M3b.

- Language detection from extension and shebang (tested by detection,
  stored but not yet acted on beyond theme color of decorations)
- At least two themes shipped: one dark (default), one light
- Theme format: Cyrius-native TOML/CYML (decided 2026-04-22, overrides
  the spec's earlier "use an existing format" suggestion)
- `--language <lang>` override, `--list-languages`
- `--theme <n>`, `--list-themes`
- `NO_COLOR` environment variable respected (no ANSI emitted)
- Color disabled automatically when output is not a TTY
- `--color=always` overrides both NO_COLOR and TTY gate

**Non-goals for M3a:**
- Token-level syntax coloring (→ M3b)
- User-installable themes from config dir (→ post-v1 or M7 config)
- Content-based language detection (shebang + extension only)

### M3b — Token-level highlighting ✅ shipped

**Goal:** File *contents* render with per-token color.

- Grammar source: **vyakarana** 1.0.2 pulled in as a git-tag dep
  (`[deps.vyakarana]` in `cyrius.cyml`, vendored to
  `lib/vyakarana.cyr` by `cyrius deps`). Eleven bundled grammars
  ship as CYML: shell, python, javascript, typescript, rust, c,
  cyrius, toml, json, yaml, markdown
- `theme_token_color(theme, kind)` maps vyakarana's ten-kind palette
  to 256-color ANSI indices for dark + light themes; kinds marked
  `-1` fall through to terminal default
- `render_highlighted_buf` buffers the full file, calls
  `tokenize_source`, drives a byte-level emitter that layers color
  over the existing line-number gutter + `-A` glyph + `--tabs`
  expansion paths from M2/M5
- `NO_COLOR=1 owl file.py` emits zero ANSI; `--color=always`
  overrides `NO_COLOR` per spec; `-p` forces highlight off
- `HIGHLIGHT_MAX` ceiling (128 KB) — larger files fall back to plain
  streaming so the bump allocator doesn't exhaust on large inputs.
  Lifting the cap is gated on a freeing allocator or vyakarana's
  streaming-tokenizer milestone (their 2.x)
- Fixed `ansi_reset` to build bytes explicitly — Cyrius string
  literals don't parse `\x??` escapes, which was emitting literal
  `\x1b[` on every reset

---

## Milestone 4 — Paging

**Goal:** Long output is automatically paged; pipelines are unaffected.

- Detect when output would exceed terminal height
- Spawn a pager (`OWL_PAGER` → `PAGER` → system default → `less -R`)
- Pass color-capable flags to the pager
- `--paging always` forces pager even on short output
- `--paging never` disables it
- Clean handling of pager exit (user pressing `q` doesn't leave terminal in a weird state)

**Testing:**
- Long file at prompt triggers pager
- Short file at prompt does not
- `owl big.log | grep foo` does not trigger pager
- Quitting pager mid-stream cleans up without errors

**Done when:** users stop manually piping `owl` into `less`.

---

## Milestone 5 — Non-printables & whitespace

**Goal:** `-A` and tab handling work as specified.

- `-A` / `--show-all` renders tabs, newlines, CRs, and control chars visibly
- `--tabs <n>` sets tab expansion width (default 4, 0 = literal)
- `--wrap <auto|never|character>` controls long-line handling

**Testing:**
- `owl -A` shows tab markers and line-end `$`
- `owl --tabs 2` renders tabs as two spaces
- Long-line file with `--wrap never` does not break terminal layout

**Done when:** whitespace-sensitive debugging is possible without switching tools.

---

## Milestone 6 — VCS integration (git scaffold) ✅ shipped

**Goal:** Files inside git repos show change markers in the gutter.

- `src/vcs.cyr` — narrow VCS interface (`vcs_compute_markers`,
  `vcs_mark_for_line`, `vcs_reset`, `vcs_enabled`, `set_style`).
  All git-specific code lives in this module so M6 is a single-file
  rewrite once SIT (planned AGNOS-native VCS) ships
- `git diff --no-color -U0 -- <path>` via `/bin/sh -c` with a minimal
  PATH env; hunk headers parsed directly, no external diff parser
- Per-line markers: `VCS_MARK_ADD` (`+`, green), `VCS_MARK_MOD`
  (`~`, orange), `VCS_MARK_DEL` (`-`, red) with theme-aware color
  via `theme_change_color`
- `--style=auto | changes | no-changes` flag (default auto; on when
  decorated and in a repo)
- Gutter layout: `"     N " + "+/~/- " + "│ "`; marker column is
  omitted entirely when `--style=no-changes` or when markers wouldn't
  be shown, keeping the narrow gutter for non-repo files
- Diff output capped at 64KB; huge diffs render partial markers
- Silent no-op outside a repo, with unavailable `git`, or for
  untracked / clean files — no errors, no stderr leakage

**Known limitations (M6 scaffold):**
- Paths containing `'` or control bytes render without markers
  (single-quote shell wrap; proper quoting deferred)
- `git` is located via PATH env passed to `/bin/sh`; unusual installs
  may not resolve
- Not yet streaming — file must be rendered after diff is fully
  captured

**Done when the SIT swap lands:** replace `_capture_shell` +
`_parse_hunk_header` + `_apply_hunks` with calls into a SIT library
dep. Interface above stays.

---

## Milestone 7 — Configuration file ✅ shipped

**Goal:** Users can set persistent preferences.

- `src/config.cyr` — minimal `key = value` parser, no new stdlib dep.
  Values may be bare or double-quoted. `#` starts a line comment. No
  sections — the surface is too small to need them
- Recognized keys: `theme`, `paging`, `style`, `tabs`, `wrap`. Each
  delegates to the same `set_*` / `theme_index` helper the CLI path
  uses, so validation is shared
- Location (first hit wins): `$OWL_CONFIG` →
  `$XDG_CONFIG_HOME/owl/config.cyml` → `$HOME/.config/owl/config.cyml`.
  Missing file is a silent no-op
- Precedence: defaults → config → env (`NO_COLOR`, `OWL_PAGER`,
  `PAGER`) → CLI. `config_load()` runs before CLI arg parsing, so CLI
  flags always win
- Per-line parse errors emit `owl: <path>:<line>: <reason>` to stderr
  and the rest of the file keeps loading. Deliberately does **not**
  fail startup on bad config — a viewer shouldn't be held hostage by
  a typo in dotfiles
- `--help` documents the config location cascade and the keys

---

## Milestone 8 — Polish & release candidate

**Goal:** Ready for broad use. Sliced into four phases so each ships
with gates green before the next starts.

### M8a — Robustness pass ✅ shipped

- **Binary file detection** — NUL-byte scan of the first chunk in
  `render_path`. Skip with `owl: <path>: binary file (use -p to dump)`
  to stderr. Bypassed by `-p` (cat parity), `-A` (raw escape view),
  and `--language=<name>` (asserted type). Exit codes obey §9: one
  binary alone → 4; mixed with text → 1 (partial)
- **Large-file highlight fallback notice** — when `HIGHLIGHT_MAX` is
  exceeded, emit `owl: <path>: file too large for highlighting (> 128
  KB), rendering without color` so the missing color isn't mysterious
- **Weird-input robustness** — verified: empty files, 1-byte files,
  files without trailing newline, UTF-8 BOM-prefixed files. All
  render or pass-through cleanly; `-p` preserves byte-for-byte cat
  parity in every case
- **Smoke gates** — 14 new M8a assertions in `scripts/smoke.sh`
  covering the design-spec §13 items that were previously ungated
  (binary skip, binary under `-p`/`-A`/`--language`, mixed-with-binary
  exit codes, large-file notice, empty/1-byte/no-trailing-NL/BOM
  robustness)

### M8b — Error consistency + startup bench (pending)

- Sweep every `eprint` / `report_error` call for format consistency
  (`owl: <path>: <reason>` everywhere)
- Benchmark startup: `--version` cold/warm; target <50ms
- Trim any hot-path allocations that miss the target

### M8c — Docs polish (pending)

- README finalize: synopsis, install, examples, feature matrix
- `--help` gains a worked example block
- Man page (`docs/owl.1`) — scdoc or hand-rolled troff

### M8d — AGNOS / Cyrius packaging (deferred)

- Hold until AGNOS ships a packaging convention. `.cyrius-toolchain`
  file + release workflow per agnosticos first-party standards

---

## Post-v1 ideas (deferred)

Not committed, just parked here so the agent doesn't accidentally build them into v1:

- `--follow` / `-f` mode with live highlighting (tail-style)
- URL / remote file support
- User-installable grammars and themes (plugin directory)
- Content-based language detection for files without extensions
- Hex dump mode for binary files
- Integration with the AGNOS / Cyrius native theming system (if one exists)
- JSON / structured output mode for tool interop
- Shell completion scripts (bash, zsh, fish, and any AGNOS-native shell)
- Localization of error messages

---

## Decision log

Keep a running list here as questions get answered during implementation:

| Date       | Question | Decision | Rationale |
|------------|----------|----------|-----------|
| 2026-04-23 | Config file format? | CYML key=value, no sections, own parser | Surface is too small for sections; avoiding a `cyml` stdlib dep keeps the owl binary lean |
| —          | Default pager on AGNOS/Cyrius? | TBD | Depends on what ships with the OS |
| 2026-04-22 | Theme format: reuse existing (e.g. TextMate/Sublime) or custom? | Custom CYML | Keeps toolchain consistent; refuses incumbent baggage |
| 2026-04-23 | Grammar source for M3b? | vyakarana 1.0.2 (git-tag dep) | Library-first Cyrius-native tokenizer; ten-kind palette already matches theme shape |
| 2026-04-23 | Highlight file-size ceiling? | 128 KB (`HIGHLIGHT_MAX`) | Bump allocator keeps file + tokenbuf + ANSI-inflated output resident; lifts with a freeing allocator or vyakarana streaming (their 2.x) |
| 2026-04-23 | M6 VCS backend: implement git internals, shell out, or wait for SIT? | Shell out to `git diff` confined to `src/vcs.cyr` | SIT (AGNOS-native VCS) will replace the layer wholesale; a single-file scaffold is the minimum honest thing. `.git/index` + SHA-1 in Cyrius would also need rewriting |
| —          | Native theming integration? | Deferred to post-v1 | Keeps v1 portable |

---

## Risk & mitigation

| Risk | Mitigation |
|------|------------|
| Syntax highlighting turns out to be the biggest chunk of work | Land plain mode (M1) and line numbers (M2) first — both are independently useful. Resolved 2026-04-23: vyakarana 1.0.2 made M3b a small wiring job |
| Pager integration is finicky on AGNOS/Cyrius | Ship `--paging never` as a reliable fallback; treat paging as a convenience, not a core feature |
| Scope creep from users wanting `--follow`, search, etc. | Keep the "post-v1" list visible; be firm about what's in v1 |
| Platform-specific quirks (TTY detection, signal handling) | Write abstraction layer early in M1; test on real hardware, not just emulators |

---

*End of roadmap.*
