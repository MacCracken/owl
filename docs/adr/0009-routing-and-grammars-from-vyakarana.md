# ADR 0009: Language routing and bundled grammars come from vyakarana

- **Status**: Accepted
- **Date**: 2026-10-31
- **Deciders**: @MacCracken
- **Partially supersedes**: [ADR 0002](0002-grammar-source-vyakarana.md), on one point only. Grammar files no
  longer ship beside the binary as runtime data.

## Context

Through 1.5.3, owl decided a file's language with three tables of its own in `src/lang.cyr` (names,
extensions, shebang interpreters), plus filename special cases. It loaded the bundled grammars as 49 `.cyml`
files from a `grammars/` directory beside the binary, found through `/proc/self/exe`. vyakarana already
owned both halves:

- **Routes.** Since 2.6.2 every grammar declares its `extensions`, `filenames` and `shebangs`, and the
  compiled route table is held equal to those declarations by test (vyakarana ADR 0025).
  `detect_language_combined` adds content votes for the ambiguous assembly extensions. `.s` picks x86-64
  or AArch64, and `.asm` picks NASM or GNU as. `detect_language_registered` (ADR 0031) also routes a
  consumer's own registered grammars.
- **Grammars.** The bundle compiles all 49 grammars in as blobs, and `bootstrap_grammars()` registers them
  with no file I/O. They were already in owl's binary, since DCE keeps static data, but owl never used
  them.

The duplicate tables cost owl real bugs. Markdown's grammar shipped from 1.0.0 with no table row until
1.5.2. `.asm` could never get the content vote. Every vyakarana grammar addition meant editing three tables
and two bootstrap lists in lockstep. A user grammar with a new name could never be reached. Before
deciding, owl compared all 122 of its routes against vyakarana's: 108 agree, `.asm` differs on purpose,
and 13 are routes vyakarana lacks.

## Decision

We will route through vyakarana and keep no language table in owl. The order is:
1. config `ext.<x>` overrides;
2. a user grammar with a new name, through `detect_language_registered`, accepted only when it names such a
   grammar;
3. `detect_language_combined`;
4. owl's supplement;
5. owl's JSON / YAML / TOML / markdown opening sniff.

The supplement holds the 13 routes owl had already shipped and vyakarana lacks. It is filed upstream,
shrinks as vyakarana gains them, and never gains new rows.

We will register the bundled grammars from vyakarana's embedded blobs. The user overlay
(`$XDG_CONFIG_HOME/owl/grammars/`, else `~/.config/owl/grammars/`) is registered first, so it wins by name.
A user grammar that replaces a bundled one changes highlighting, not routing. Only a new name routes by its
declarations, so the content votes survive an overlay. `grammars/` stays in the repository as a reference
copy, re-synced on each vyakarana bump, which smoke checks the binary against. Nothing installs it.

## Consequences

- A grammar vyakarana adds is routed, listed and highlighted with no change to owl. Smoke checks that
  `--list-languages` equals `grammars/*.cyml` and that every grammar routes from its first declared
  extension or filename. The markdown class of gap is closed by construction.
- The binary is self-contained. Releases drop `grammars/`, and highlighting a small file got 25% faster
  (no 49 file reads).
- A routing bug is now vyakarana's to fix. owl drafts the filing in `docs/development/issues/` and, for a
  route it already shipped, carries it in the supplement until the fix lands. That is the
  "tokenization is vyakarana's job" principle extended to routing.
- owl depends on vyakarana's registry ordering: `registry_add` before `bootstrap_grammars` is honoured,
  and name lookup returns the first match. This holds by reading the source, not by contract, and the
  request to make it a contract is drafted upstream. Smoke gates fail if it changes.
- The release binary grew about 24 KB of now-reachable routing and bootstrap code.
