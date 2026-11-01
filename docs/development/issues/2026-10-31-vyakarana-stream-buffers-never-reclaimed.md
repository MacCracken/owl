# A token stream's buffers are never reclaimed: each stream costs ~18× its input on the bump heap — OPEN

**Discovered:** 2026-10-31 during owl's P(−1) audit (1.5.3, INFO-009), memory review; quantified with the
standalone repro below while drafting this filing.
**Severity:** Medium. No wrong output, but a silent, unbounded memory cost for any consumer that tokenizes
more than one input per process. owl shows many files per run, the default on a terminal.
**Affects:** vyakarana 2.10.0 (verified) under cyrius's default bump allocator; the streaming API
(`tokenize_stream_new` / `_feed` / `_finish` / `_free`) since 2.0.0.

## Summary

`tokenize_stream_free` is documented as a no-op for the stream's buffers ("Cyrius's bump allocator doesn't
free individual allocations"). It only zeroes the stream's fields. The stream's input copy, its staging
tokenbuf and the intermediate buffers left behind as each one grows by doubling stay on the heap for the
life of the process. Measured with the repro (the same 94,185-byte Rust input tokenized 60 times, one
fresh stream each time, the **output** tokenbuf reused):

| streams | heap growth (`alloc_used`) |
|---:|---:|
| 10 | 18,655,088 B |
| 30 | 52,822,608 B |
| 60 | 104,073,888 B |

That is exactly **1,708,376 bytes per stream**, about **18× the input**, deterministic and linear. In owl
1.5.2, 60 highlighted 92 KB files peaked at 238 MB RSS; owl 1.5.3 cut that to 62.5 MB by reusing every
buffer it owns. The remainder, roughly 0.8 MB of resident pages per file, is the stream state above. RSS
understates the heap figure, because untouched pages of the doubled buffers never become resident.

For a single file the same stream state is why a highlighted file costs ~13× its size resident, not the ~4×
owl's docs used to claim (owl never drained between feeds, so the stream held the whole input as well).

## Reproduction

```sh
# in any project that vendors vyakarana (owl's lib/ works) with the usual stdlib list
cyrius build repros/2026-10-31-vyakarana-stream-heap.cyr build/stream-heap
./build/stream-heap
# streams=10 input_bytes=94185 tokens=58305 heap_growth_bytes=18655088
# ...
# streams=60 input_bytes=94185 tokens=58305 heap_growth_bytes=104073888
```

## Proposed fix

Any of these, in rough order of payoff:
1. **`tokenize_stream_reset(s, lang)`**: start a new input on an existing stream, keeping its grown buffers.
   A consumer that reuses one stream then pays the high-water mark once rather than per input. This is the
   tokenizer-side twin of what owl did for its own buffers.
2. **Allocate stream buffers through the stdlib freelist** (`fl_alloc` / `fl_free`, already linked by most
   consumers) and release them in `tokenize_stream_free`.
3. **Grow buffers with a release of the old block** where the allocator supports it, instead of keeping each
   doubled copy.

## Consumer-side workaround

Partial. owl 1.5.3 reuses its slurp buffer, read buffers and output tokenbuf across files (owl FINDING-022),
the share it controls. The stream's own state cannot be reused through the public API today.
