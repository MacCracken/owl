# owl — Roadmap

Forward-looking planning surface: this file tracks what is *next*.
What has shipped is in `CHANGELOG.md`, and live state (version, sizes,
pins, open findings) is in `state.md`.

**Where we are.** The current release is **1.5.3**, a P(−1) audit,
hardening and repair pass (26 findings fixed; report in
`docs/audit/2026-10-31-audit.md`), on cyrius 6.7.18, vyakarana 2.10.0 (49
grammars) and sit 1.13.0. The 1.5.x line moved owl onto cyrius's 6.7
language line (1.5.0), took the deps to their latest releases (1.5.1),
routed markdown by extension (1.5.2) and closed the audit (1.5.3). The 1.4.x
feature line is closed. Its two open items, URL support and AGNOS theming,
are under [Beyond 1.6.x](#beyond-16x) with the reason each is blocked.

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

Candidates in rough priority order. Each is independent, so they need
not ship in order.

### Route languages through vyakarana's registry

vyakarana 2.9.8 added `detect_language_registered(path, src, len)`. It
routes by what each registered grammar declares (`extensions`,
`filenames`, `shebangs`, ADR 0025): the longest declared extension,
else a declared filename, else the `#!` interpreter. It also covers a
consumer's own grammars registered with `grammar_load` + `registry_add`,
which is exactly owl's user overlay. owl still routes through its own
hand-kept tables in `src/lang.cyr` (`lang_name` / `lang_exts` /
`lang_shebangs`) plus filename special cases. Since 1.5.3 the grammar
bootstrap also loops over that table, so it is the single list a grammar
must be added to. That
design produced two real gaps:

- **markdown** had a grammar from 1.0.0 but no table row until 1.5.2;
- **`.asm`** stays on `asm_x86_64`, because vyakarana's content vote
  (`nasm` by default, GNU-as files voted back) needs the source bytes,
  which owl's extension-only routing never looks at. In owl, a NASM
  `.asm` file shows its `; comment` lines as code.

The work:

- [ ] Route through the registry first. Keep owl's `ext.<x> = <lang>`
      config overrides ahead of it, and keep `_owl_detect_language_from_content`
      (json / yaml / toml / markdown openings) as the last fallback.
- [ ] Decide what replaces `lang_name` / `lang_exts` for
      `--list-languages` and `--language` validation. The registry
      knows every loaded grammar, so a user-overlay grammar becomes
      listable and selectable too.
- [ ] Byte-compare routing before and after over a real-file sample
      (vyakarana's `tests/corpus/` plus a sweep of `~/Repos`). Expected
      changes: `.asm` with NASM content, and any extension vyakarana
      declares that owl lacks. Record each one.
- [ ] Smoke: every bundled grammar routes from its declared extension.
      That gate would have caught the markdown gap.

### Test-only stdlib in the `[test]` scope

cyrius 6.7.6 added a `[test]` manifest section whose `stdlib` is prepended
only to `cyrius test` / `bench` / `fuzz` compiles. owl lists `assert` in
`[deps].stdlib`, so it is prepended to the shipped binary (DCE drops it).
`tests/owl.bcyr` includes `bench` and `fnptr` by hand for the same reason
(1.4.8). vyakarana made this move at 2.5.1.

- [ ] Move `assert` to `[test] stdlib`; move `bench` / `fnptr` there and
      drop the hand includes from `tests/owl.bcyr`.
- [ ] Check that `cyrius test` / `fuzz` / the bench build still pass, that
      the release binary is unchanged or smaller, and that an editor's
      build-scope resolve does not show false "undefined function"
      errors in the test files (vyakarana's 2.5.1 note).

### Colourised `--follow`

The tail renders without token colour, by design (see `_follow_loop`).
The 1.4.7 trade: colouring needs a tokenbuf whose spans cover the bytes
being drawn, but a live stream produces absolute offsets while the
render loop indexes into the chunk it was handed. vyakarana 2.9.11's
**documents** (`tokenize_doc_*`, ADR 0033) re-tokenize only what an
edit can change, with output always equal to a from-scratch run, which
may be the cleaner base.

- [ ] Thread a base offset through `_render_highlighted_with_tb`, or
      drive a vyakarana document with append-only edits.
- [ ] Handle a token that straddles an append boundary.
- [ ] Keep escape stripping on appended bytes (1.4.7's guarantee) and
      gate it.

### CLI parsing through cmdit, with shell completions

Demand-gated, not a forced sweep. owl is a Tier-3 ("rich / edge")
candidate in the 2026-06-25 ecosystem CLI review
(`agnosticos/docs/development/planning/cmdit.md`). The gain grows
because shell completions come with it (`cmdit_completions` writes bash,
zsh and fish). cmdit is already vendored into `lib/`, as sit's own
dependency, though nothing includes it yet.

**What is hand-rolled today.** *Line references are from the 1.4.8
survey; re-check them before starting.*

- `main()` parses and acts in one loop over `argc`/`argv` using `streq`
  and `match_eq_flag`. Value flags accept only `--name=value`
  (`--color always` is `unknown option`), and there is no `--`.
- Files render inside that loop, so `owl a.txt --bogus` prints `a.txt`
  before exiting 2, and `resolve_mode()` runs only at the first file.
- `-V`/`--version`, `-h`/`--help` and `--list-*` return at once, the
  first after a look-ahead for `-v`. `-n` and `-N` share
  `g_flag_numbers`; the last one wins.
- Validators: `set_color` / `set_paging` / `set_style` (-1/1/0),
  `set_wrap` / `set_strip_ansi` (0/1/2), `set_format` (has an
  undocumented `auto` alias), `set_tabs` (0..64), `set_line_range`
  (`A:B`), `theme_index` (falls through to user themes), `lang_is_valid`.
- Help and version go to stdout. Errors go to stderr as
  `owl: <whole arg>: <reason>` through `report_error`. Exit codes are
  0/1/2/4.

**Site → cmdit.**

- [ ] `cmdit_new("owl")`, with one `cmdit_bool` per switch and per
      `--list-*`. Read `cmdit_get_bool(f_verbose)` after the parse, which
      makes the order independence smoke checks hold by construction.
- [ ] CLI-only enums via `cmdit_enum`: `--strip-ansi`, `--color` (map
      the index to -1/1/0) and `--format` (`cmdit_metavar` keeps `auto`
      out of help).
- [ ] `--paging` / `--style` / `--wrap` / `--tabs` / `--theme` are also
      config keys. Register them as `cmdit_str` and keep the one shared
      validator: a `cmdit_enum` choice list would be a second copy that
      drifts.
- [ ] Files come from `cmdit_positional` in argv order, and a lone `-`
      stays a positional. Call `config_load()` first, then apply only the
      flags `cmdit_seen` reports, so the CLI still overrides the config.
- [ ] Byte-compare stdout, stderr and exit codes before and after, for
      every smoke invocation plus `--bogus`, `-np`, `--color` (no value)
      and `a.txt --bogus`.

**Gaps that stay owl's**, none of which blocks adoption:

- `--theme`, `--language` and `--line-range` stay `cmdit_str` plus the
  existing check.
- `NO_COLOR`, `OWL_PAGER`→`PAGER` and `OWL_CONFIG`→`XDG_CONFIG_HOME`→`HOME`
  are env-only cascades, not `cmdit_env`.
- Two independent bools cannot tell which of `-n` / `-N` came last: pick
  a precedence, scan `cmdit_raw_argv`, or wait for cmdit's `--no-foo`.
- Four behaviour changes to decide and record:
  - a bad flag is rejected before anything renders;
  - every flag applies to every file;
  - `--help --bogus` becomes an error;
  - `--color always` and `--` are accepted.
- Keep `print_help`, `print_version` and `report_error`.
  `cmdit_help_flags` writes to stderr in a different row format, and
  `cmdit_print_error` drops the offending token. Recover that token from
  `cmdit_raw_argv`.

**Manifest:** add `[deps.cmdit]` at the tag sit pins (1.5.0 today), with
`modules = ["dist/cmdit.cyr"]`. `"args"` and `"io"` stay.

### `--diff-from=<ref>`

Compare to a named ref instead of HEAD. Park it until sit's library
surface takes a ref, and check ADR 0009 before starting.

### Version pins in `--version --verbose`

The banner's vyakarana / sit / cyrius lines are hand-kept, and they were
stale for three releases (1.4.1–1.4.8). A smoke gate comparing them with
`cyrius.cyml` would lock them in. That is small enough to ride along
with any 1.6.x release.

### Piped tabs (audit INFO-012)

Decide whether piped output without `-p` keeps literal tabs, as the design
spec originally said, or keeps expanding them as it does today (smoke pins
that). Either way, record the decision in the spec.

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

  None of these is filed yet.
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
| A grammar ships bundled but unreachable | 1.5.2's markdown gap. 1.6.x registry routing removes the hand-kept tables. Until then, check every `grammars/*.cyml` has a `lang_name` row on each grammar bump |

---

## Decision log

Architectural decisions live in [`../adr/`](../adr/) as individual,
immutable records; see [`../adr/README.md`](../adr/README.md). This
roadmap tracks forward-looking work; the ADRs record the *why* behind
choices already made.
