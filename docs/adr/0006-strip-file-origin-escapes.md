# ADR 0006: Strip file-origin terminal escapes in decorated mode

- **Status**: Accepted
- **Date**: 2026-04-23
- **Deciders**: @MacCracken

## Context

A file viewer that emits its own ANSI escapes (for syntax color,
gutter, header) and also forwards file bytes to a terminal must
reckon with file content that itself contains terminal escapes.
A malicious or accidental escape sequence in a viewed file can:

- Manipulate the user's clipboard (OSC 52 — CVE-2019-9535, iTerm2).
- Make the terminal report back its title or a synthesized response
  the shell then executes (DECRQSS — CVE-2003-0063, xterm).
- Hijack `less`-style hyperlinks (OSC 8 — CVE-2024-32487).
- Trigger iTerm2's OSC 1337 file-handler.

In `cat` parity (`-p`), passthrough is the contract — the user
opted in. In decorated mode, owl has no such excuse: the user
asked to view a file, not to execute it.

`less -R` is the shape: by default, `less` strips control sequences
in its display; `-R` (raw) is an explicit opt-out for users viewing
trusted ANSI-colored output.

## Decision

We will strip file-origin terminal escapes from the byte stream in
decorated/colored output via a 5-state classifier (`g_esc_state` /
`_emit_file_byte`). The classifier handles CSI, OSC, DCS, APC, PM,
SOS, and single-char escape sequences. Owl's own SGR output goes
through `ansi_fg` / `ansi_reset`, which write directly to stdout
and bypass the classifier — only file-loaded bytes are filtered.

A new flag `-r` / `--raw-control-chars` restores cat-like
passthrough for users who explicitly trust the input. `-p`
(plain mode) implicitly bypasses the strip — cat parity is
preserved.

Audit FINDING-002 added `eprint_sanitized` for stderr paths so
escapes in user-supplied strings (paths, config values) can't
inject ANSI into stderr capture either.

## Consequences

- Audit FINDING-001 (HIGH) closed.
- Audit FINDING-002 (MEDIUM) closed in the same release.
- Default behavior diverges from `cat`: a file with ANSI escapes
  no longer renders those escapes when viewed under decorated owl.
  Documented in CHANGELOG and in `--help`.
- Users who relied on ANSI passthrough need to add `-r`. The
  shape mirrors `less -R`, so muscle memory transfers.
- The 5-state classifier resets per render (`render_reset`), so
  escapes don't leak across files in a multi-file invocation.
- The 1.1.1 `--strip-ansi=auto|always|never` flag adds a `less -R`
  naming alias; semantics layer cleanly on top of this ADR.
