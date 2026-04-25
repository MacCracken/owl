# ADR 0005: Config file format — flat CYML key=value, own parser

- **Status**: Accepted
- **Date**: 2026-04-23
- **Deciders**: @MacCracken

## Context

owl needs an optional user config file for persistent preferences
(theme, paging, style, tabs, wrap, and 1.1.1's per-extension
language overrides). The file lives at `$OWL_CONFIG`,
`$XDG_CONFIG_HOME/owl/config.cyml`, or `~/.config/owl/config.cyml`.

Format candidates:

1. **TOML or full CYML with sections.** Pulls in a stdlib parser
   dependency (`toml.cyr` / `cyml.cyr`). The recognized-keys surface
   is small (six top-level keys plus a flat `ext.<extension>`
   namespace), which doesn't justify section nesting.
2. **JSON.** Verbose for hand-editing; quoting overhead.
3. **Flat `key = value`, owl-specific.** Trivial parser, no nesting,
   no escapes beyond a single optional pair of double quotes.

The recognized-keys surface is intentionally small — owl is a
viewer, not an editor; almost every flag has a sensible default and
most users won't write a config at all.

## Decision

We will use a flat `key = value` format parsed inline in
`src/config.cyr`. No sections. No stdlib `cyml.cyr` / `toml.cyr`
dependency. Whitespace around `=` is ignored. Values may be bare
or wrapped in one pair of double quotes. Lines starting with `#`
(after leading whitespace) and blank lines are comments. Recognized
keys: `theme`, `paging`, `style`, `tabs`, `wrap`, `ext.<extension>`.

Per-line parse errors emit `owl: <path>:<line>: <reason>` to stderr
and continue — a typo in a dotfile must not hold the viewer
hostage.

## Consequences

- Binary size: no `cyml.cyr` / `toml.cyr` link cost.
- The format is owl-specific and won't carry over to other tools —
  acceptable given the small surface.
- Adding a new key family requires adding a branch in `_cfg_apply`;
  the 1.1.1 `ext.<extension>` family added one such branch.
- If the recognized-keys surface ever needs sections, this ADR
  gets superseded — likely deferred until a clear forcing function
  appears.
