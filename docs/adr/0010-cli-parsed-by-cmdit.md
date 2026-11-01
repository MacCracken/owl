# ADR 0010: The command line is parsed by cmdit

- **Status**: Accepted
- **Date**: 2026-10-31
- **Deciders**: @MacCracken

## Context

owl hand-rolled its argument parsing: a loop of `streq` and `match_eq_flag` over `argc` / `argv`. 1.5.3
made it two-pass, so that every flag applies to every file and nothing renders before all flags are valid
(FINDING-024). It still accepted only `--name=value`, had no `--`, and its value validation was spread
through the loop. cmdit is the AGNOS getopt-long library, a productised fork of the stdlib's `flags.cyr`.
It was already vendored into `lib/` as sit's own dependency. The 2026-06-25 ecosystem CLI review named owl
a candidate, and the promised gain was shell completions generated from the flag table.

## Decision

We will parse owl's command line with cmdit 1.5.0, pinned as `[deps.cmdit]` at the tag sit pins, so the
shared `lib/cmdit.cyr` is one file. owl keeps:
- its own help text, version line and error wording (`owl: <arg>: <reason>` on stderr; help on stdout);
- the validators shared with the config file (`set_paging`, `set_style`, `set_tabs`, `set_wrap`, themes,
  languages, line ranges), applied after the parse to the flags cmdit reports as seen.

CLI-only choices (`--color`, `--strip-ansi`, `--format`) are cmdit enums. `-n` / `-N` keep last-wins
through a scan of cmdit's raw argv.

We record four behaviour changes:
1. `--help`, `--version` and `--list-*` answer only when the whole command line parses;
2. with both `--help` and `--version`, help wins;
3. `--name VALUE` and `--` are accepted;
4. a missing value, a value given to a switch, and a flag-like separate value each get their own message.

Short flags stay one per argument (`-np` is unknown), as before.

We will not expose `--completions` yet. cmdit 1.5.0's scripts complete the (empty) subcommand list in the
first argument's place, so for owl `owl <TAB>` would offer nothing. The fix is drafted upstream; we do not
write an owl-side generator that would duplicate cmdit.

## Consequences

- The before/after comparison ran every one of smoke's 362 invocations through both parsers with the same
  stdin. Only `--help` output differs, by three new lines.
- The flag table is data, so completions arrive with a one-line change once cmdit is fixed.
- `--version` costs about 0.08 ms more (cmdit's table), and the binary carries cmdit's code.
- A future cmdit `--no-foo` would let `-n` / `-N` drop the raw-argv scan.
