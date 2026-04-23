# owl

Written in [Cyrius](https://github.com/MacCracken/cyrius).

## Build

```sh
cyrius deps && cyrius build src/main.cyr build/owl
cyrius test
```

## Key Facts

- Source in `src/`, tests in `tests/`, stdlib in `lib/` (vendored, do not edit)
- Dependencies declared in `cyrius.cyml`
- Toolchain pinned in `cyrius.cyml [package].cyrius`

## Language Notes

- `var buf[N]` is N bytes, not elements
- `&&`/`||` short-circuit; mixed requires parens: `a && (b || c)`
- No closures — use named functions
- Test exit pattern: `syscall(60, assert_summary())`

## Do Not

- Do not commit or push without user approval
- Do not modify files in `lib/`
