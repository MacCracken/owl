# vyakarana / sankoch — `_stream_grow` is defined by both, with incompatible shapes

- **Filed by:** owl (the only project that co-links both)
- **Components:** `vyakarana/src/tokenize.cyr` and `sankoch/src/stream.cyr`
- **Severity:** latent. Inert for owl today, verified — but the inertness is
  a property of owl's current call graph, not a guarantee either project
  offers.
- **Ask:** namespace one of the two.

## The collision

Both projects define a private helper called `_stream_grow`, and the two
disagree about everything that matters:

| | vyakarana | sankoch |
|---|---|---|
| signature | `_stream_grow(s, needed)` | `_stream_grow(ctx)` |
| buffer field | `s + 0` | `ctx + 24` |
| length field | `s + 8` | `ctx + 40` |
| capacity field | `s + 16` | `ctx + 32` |
| success return | non-zero (0 means **failure**) | `0` means **success** |

Any consumer linking both gets a `duplicate fn '_stream_grow' (last
definition wins)` warning, and one of the two definitions disappears.

Note the return-value polarity in particular: the two functions do not just
read different offsets, they report success with opposite values. A binding
mistake here would not fault — it would quietly turn every successful grow
into a reported failure, or vice versa.

## Why owl is the one reporting it

owl links vyakarana (tokenizer) and, transitively through sit, sankoch
(zlib). It is currently the only project that co-links the two, so the
collision does not appear in either project's own build or test suite.

## What owl verified, so you do not have to re-derive it

The direction the warning names **flipped** between owl 1.4.4 and 1.4.5
(sankoch was the later definition under git deps; vyakarana is later under
the cyrius stdlib fold). Both directions were checked:

- A build with sankoch's body re-inserted last produces **byte-identical**
  highlighted output at 2 KB / 4 KB / 8 KB / 40 KB, spanning vyakarana's
  4096-byte `VYK_STREAM_INIT_CAP` so the grow path is genuinely exercised.
- An `exit 42` probe planted in the *winning* definition **never fires**.
  Call sites inside `lib/vyakarana.cyr` bind to vyakarana's own definition
  regardless of which one the warning names.
- sankoch's own caller (`stream_write`, its streaming-decompress entry) is
  not on owl's path at all — sit reaches sankoch exclusively through the
  one-shot `zlib_decompress_with_ratio_cap` / `zlib_compress` — and is dead
  in owl's DCE map.

A minimal three-file repro *did* show cyrius rebinding all call sites to
the last definition, which is worth knowing but was misleading here; the
direct test on the real binary is what settled it.

## Why fix it anyway

Inertness today rests on two accidents: that sankoch's streaming decompress
is unreachable from sit's read path, and that binding happens to resolve
per-module in this arrangement. Either could change without anyone thinking
about this symbol. The failure mode if it does is not a crash — it is a
grow function reading three fields at the wrong offsets and reporting
success as failure, inside a tokenizer, on file content.

This is the same hazard class as the patra `TK_*` / vyakarana `TK_*` enum
collision that owl surfaced at 1.4.0, which patra fixed by namespacing
(`TK_*` → `SQLT_*`). That precedent is the suggested shape here.

## Suggested fix

Rename in whichever project finds it cheaper — both are private helpers, so
neither rename is a public-API change:

- vyakarana → `_vyk_stream_grow`
- sankoch → `_sankoch_stream_grow` (sankoch already uses a `_sankoch_`
  prefix elsewhere, e.g. `_sankoch_alloc`, so this is the more consistent
  of the two)

A broader fix belongs in cyrius: a `cycc` diagnostic that treats a
duplicate `fn` with a **differing arity** as an error rather than a
warning. Same-arity duplicates are usually benign shadowing; differing
arity never is. That would have caught this at the first co-link. Related
to the existing filing at
`cyrius/docs/development/issues/2026-06-14-stdlib-constant-value-collisions.md`.
