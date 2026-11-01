# vyakarana's route table lacks cyrius's own test extensions and six shebang interpreters that owl routed through 1.5.3 — OPEN

**Discovered:** 2026-10-31 while moving owl 1.6.0 onto vyakarana's routes (`detect_language_combined`)
in place of owl's own three tables.
**Severity:** Low. Nothing crashes. Without a workaround the files render with the wrong grammar, or with none.
owl carries a workaround, a small supplement table.
**Affects:** vyakarana 2.10.0 (verified): the compiled route table and the matching `[grammar]` declarations
(ADR 0025).

## Summary

owl 1.6.0 hands routing to vyakarana. Before deleting its own tables, owl checked all 122 routes from them
against `detect_language_combined(path, src, len)`. 108 agree. One differs on purpose: `.asm` now goes
through vyakarana's NASM / GNU-as content vote, which is better. The other 13 return 0, meaning no route:

| Input | owl 1.5.3 | vyakarana 2.10.0 | Real-world effect |
|---|---|---|---|
| `x.tcyr` | cyrius | 0 | cyrius unit tests, the files `cyrius test` runs |
| `x.bcyr` | cyrius | 0 | cyrius benchmarks (`cyrius bench`) |
| `x.fcyr` | cyrius | 0 | cyrius fuzz harnesses (`cyrius fuzz`) |
| `#!/usr/bin/env deno` | javascript | 0 | |
| `#!/usr/bin/env rust-script` | rust | 0 | |
| `#!/usr/bin/env swift` | swift | 0 | |
| `#!/usr/bin/env elixir` | elixir | 0 | |
| `#!/usr/bin/env ocaml` | ocaml | 0 | |
| `#!/usr/bin/env ocamlrun` | ocaml | 0 | |

The interpreter rows fail the same way with `#!/usr/bin/<interp>`, which makes 13 failing inputs.

The cyrius extensions matter most. Across a local checkout of the AGNOS repositories (2,539 sampled files),
74 `.tcyr` / `.fcyr` / `.bcyr` files lost their route. Most of them open with a `# …` comment, so a consumer
with a markdown opening-line sniff (owl has one) rendered them as **markdown** rather than cyrius. One more
fell to plain. `grammars/cyrius.cyml` declares only `extensions = [".cyr"]`.

## Reproduction

```cyrius
include "lib/vyakarana.cyr"
fn main() {
    alloc_init();
    var a = detect_language_combined("x.tcyr", "", 0);                       # 0, expected "cyrius"
    var b = detect_language_combined("noext", "#!/usr/bin/env deno\n", 20);  # 0, expected "javascript"
    return 0;
}
var _rc = main();
syscall(SYS_EXIT, _rc);
```

## Proposed fix

Per ADR 0025, each route changes in two places: the compiled table and the grammar's declaration.

- `cyrius.cyml`: `extensions = [".cyr", ".tcyr", ".bcyr", ".fcyr"]`, plus the matching `_detect_*` lines.
- `shebangs` declarations and interpreter routes:
  - javascript `["node", "deno"]`
  - rust `["rust-script"]`
  - swift `["swift"]`
  - elixir `["elixir"]`
  - ocaml `["ocaml", "ocamlrun"]` (`ocaml` is a prefix of `ocamlrun`, so the longest-match rule covers both).

  rust, swift, elixir and ocaml declare `shebang = false` today. Whether a `#!` first line should lex as a
  comment in those grammars is vyakarana's call; routing does not depend on it.

Optional, not a regression for owl: route the shell dotfiles `.bashrc`, `.bash_profile`, `.zshrc`, `.profile`
and `.zprofile` to shell (they are `filenames` entries). Today they get no route, and a consumer shows them
plain.

## Consumer-side workaround

owl 1.6.0 `src/lang.cyr` `_owl_supplement`: the three extensions and six interpreters above. It runs only after
`detect_language_combined` returns 0, so the day vyakarana routes them the rows go dead. `scripts/smoke.sh`
gate 1.6.0 (g) pins each one. Delete each row as vyakarana gains it, and delete the table once it is empty.
