# owl reaches into vyakarana-private symbols: make `tokenbuf_reset` public and bless the overlay-first bootstrap — OPEN

**Discovered:** 2026-10-31 during owl 1.5.3 (audit repairs). owl started depending on a second private symbol.
**Severity:** Low. Nothing is broken; a rename upstream would fail owl's build loudly. This asks for two
supported contracts so owl can stop depending on internals.
**Affects:** vyakarana 2.10.0; owl 1.5.3's `src/main.cyr`. **Updated for owl 1.6.0:** owl no longer writes
`_grammars_bootstrapped` (item 2 below). It now depends on the ordering contract item 2 asks vyakarana to
document.

## Summary

owl uses two underscore-prefixed (private) names from `dist/vyakarana.cyr`:

1. **`_tokenbuf_reset(tb)`** (since owl 1.5.3). owl reuses one tokenbuf across every highlighted file
   instead of calling `tokenbuf_new()` per file, which on the bump heap leaked a full tokenbuf, plus its
   doubled copies, per file. vyakarana uses the same function internally for its streaming drain (the 2.5.2
   audit's P1-4).
2. **`_grammars_bootstrapped`** (owl 1.1.2 – 1.5.3). owl registered grammars itself: first a user overlay
   from `~/.config/owl/grammars/`, then the bundled set from a directory next to its binary. It then set this
   flag so `bootstrap_grammars()` did not run again. **owl 1.6.0 dropped this.** It now registers the overlay
   with `registry_add()` and then calls the public `bootstrap_grammars()`, which loads the embedded blobs. That
   is the design item 2 of the ask proposes, so owl now relies on the four ordering properties listed there.
   They hold in 2.10.0 by reading the source, not by contract.

## The ask

1. **Make `tokenbuf_reset(tb)` public** (empty the buffer in place, keep the capacity), with the same
   contract as the private one.
2. **Document, as a supported contract, what owl would otherwise rely on by reading the source:**
   - `registry_init()` is idempotent;
   - `registry_add()` before `bootstrap_grammars()` is honoured;
   - `bootstrap_grammars()` appends after whatever is registered;
   - name lookup returns the **first** registered match.

   With that, owl can register its user overlay and then call the public `bootstrap_grammars()`, so user
   grammars win by name. It would never touch `_grammars_bootstrapped`, and would load the bundled set from
   the embedded blobs instead of 49 files on disk.
3. Optionally, a public way to ask "is this path a bundled grammar?". Today `grammar_load` matches embedded
   blobs only on the exact relative string `grammars/<name>.cyml`, which owl's absolute overlay paths rely on
   to reach the disk.

## Consumer-side workaround

owl 1.6.0 uses `_tokenbuf_reset` (`src/main.cyr` `_hl_tokenbuf`, commented as vyakarana-private) and depends on
the item 2 ordering. `scripts/smoke.sh` gate 1.1.3 checks that the overlay wins by name. Gate 1.6.0 (d)–(f)
checks that a new-name user grammar routes and is listed, and that a same-name one leaves routing alone. A
change to any of the four properties fails one of these gates, not silently.
