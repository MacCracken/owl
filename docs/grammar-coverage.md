# owl — Grammar coverage

A reader-friendly index of what won't highlight perfectly in
each bundled grammar. **Source of truth lives in the grammar
file headers themselves** (`grammars/*.cyml`) — this doc
aggregates those notes so you don't have to read 49 files to
find out whether your Python f-strings or Vue directives will
render the way you'd expect.

owl bundles **49 grammars** as of the 1.5.1 cut (vyakarana
2.10.0). Each one was designed against a real or stand-in
corpus that round-trips with zero `TK_ERROR` tokens; the gaps
below are places where the tokenization is *correct* but
cosmetically less rich than a hand-tuned grammar would
produce.

---

## Reading this doc

| Column                | Meaning                                                                                                                                                                |
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Language**          | Grammar name as listed by `owl --list-languages`.                                                                                                                      |
| **Gap**               | One-line description. The grammar file header has the full rationale.                                                                                                  |
| **Severity**          | `cosmetic` — coverage holds, themes look slightly off; `semantic` — wrong content classification or token boundary affects parse.                                       |
| **In sample corpus?** | `yes` — the gap is exercised by the test/stand-in corpus the grammar was designed against; `no` — documented in advance, no real input has tripped it yet.            |
| **ADR**               | Pointer to the upstream vyakarana ADR (`docs/adr/NNNN-…`) when the gap is governed by an explicit design decision; `—` when it's a future-ADR candidate or just a note. |

Coverage holds in every row regardless of severity — owl will
render the file end-to-end without `TK_ERROR` stretches. The
gap is about *which* token kind a span lands in, not about
whether tokenization succeeds.

---

## Universal patterns

A few gap shapes recur across many grammars. Reading them
once here means the per-grammar table doesn't have to repeat
the rationale:

- **String interpolation isn't re-tokenized.** Inside a
  `"…${expr}…"` / `"…#{expr}…"` / `"…$var…"` / `"…\(expr)…"`
  string, the embedded expression stays inside the string-pair
  span as part of the surrounding `TK_STRING`. Per
  [vyakarana ADR 0003](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0003-string-expansion-not-retokenized.md);
  affects shell, JS, TS, Python f-strings, Ruby, PHP, Elixir,
  Crystal, Julia, Swift, PowerShell, C#, Kotlin, Lean, Nix,
  Terraform, SCSS.
- **Variable-length delimiters (heredocs, long brackets, raw
  strings).** Since vyakarana 2.9.5 a rule can compute its
  closer from the opener
  ([vyakarana ADR 0030](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0030-heredoc-computed-closers.md)),
  so Rust `r#"…"#`, Swift `#"…"#`, Lua `[==[…]==]`, C++
  `R"d(…)d"`, Lean `r#"…"#` and Ruby / PHP heredocs are one
  string token each; shell heredocs have been one string since
  2.6.0
  ([vyakarana ADR 0023](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0023-heredoc-rule.md)).
  Grammars that haven't declared such a rule yet still split
  them: Crystal, Dockerfile and Terraform heredocs, OCaml
  `{tag|…|tag}`, PostgreSQL `$tag$ … $tag$`. Fixed-delimiter
  forms that are simply undeclared — Java / Kotlin text blocks,
  C# 11 raw strings, PowerShell here-strings — are listed per
  grammar below.
- **Nestable block comments close at the first closer.** The
  pair-rule scanner is greedy, so `/* a /* b */ c */` ends at
  the first `*/` and ` c */` tokenizes as code. Affects every
  grammar whose spec nests comments: Haskell `{- -}`, OCaml
  `(* *)`, Rust and Swift `/* */`, Julia `#= =#`, Lean `/- -/`.
  Unnested comments are unaffected.
- **Regex literals aren't distinguished.** `/pat/flags` is
  context-sensitive vs. division; tokenizes as op + body +
  op. Affects JS, TS, Ruby.
- **Compose-rule start markers must be literal.**
  `<script>` and `<style>` route through compose rules to
  JavaScript / CSS, but attribute-bearing forms like
  `<script lang="ts">` fall back to plain outer-grammar
  tokenization
  ([vyakarana ADR 0013 §When to revisit](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0013-grammar-composition-rule.md)).
  Affects HTML, Vue, Svelte.
- **Predeclared identifiers aren't keywords.** Built-in
  names that are *shadowable* in the language stay as
  `TK_IDENT` rather than `TK_KEYWORD` per
  [vyakarana ADR 0004](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0004-shell-builtins-as-ident.md):
  `len` / `iota` / `nil` in Go, `@import` in Zig, shell
  builtins, opcodes and registers in the asm and NASM
  grammars, etc. Themes can apply secondary palettes by
  token text.
- **Closed since the 1.4.5 refresh: numbers, char literals,
  string prefixes.** Since vyakarana 2.7.0
  ([ADR 0026](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0026-number-literal-shapes.md))
  floats, exponents, digit separators (`1_000_000`, C++
  `1'000'000`) and TOML / YAML date-times are one `number`
  token, and since 2.9.7 so are type suffixes (`100u32`, `1UL`,
  `42L`, `1.5f`, Python `1j`) and, where a grammar enables it,
  leading-dot `.5`. `char_literal = true`
  ([ADR 0010](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0010-char-literal-default.md))
  is on in every C-family grammar, so `'x'` is one
  `TK_STRING`. String prefixes join their string
  ([ADR 0027](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0027-prefixes-lead-bytes-next-byte-rules.md)):
  Python `f"…"` / `rb"…"`, Rust `b"…"` / `r"…"`, C `L"…"` /
  `u8"…"` since 2.7.1, C# `$"…"` / `@"…"` since 2.9.6. The
  number rows left below are grammar-specific: asm floats,
  leading-dot `.5` in OpenQASM and Nix, OpenQASM timing units,
  C++ user-defined suffixes, NASM `0FFh`.

---

## Per-grammar gaps

| Language     | Gap                                                                          | Severity | In sample corpus? | ADR        |
|--------------|------------------------------------------------------------------------------|----------|-------------------|------------|
| asm_aarch64  | Float literals (`1.5`) split as `number(1)` + `ident(.5)`                    | cosmetic | no                | —          |
| asm_aarch64  | `;` instruction-separator tokenizes as punctuation                           | cosmetic | no                | —          |
| asm_x86_64   | Float literals (`1.5`) split as `number(1)` + `ident(.5)`                    | cosmetic | no                | —          |
| asm_x86_64   | NASM `;` comments render as code — owl routes `.asm` here, not to nasm       | semantic | no                | —          |
| c            | Preprocessor (`#include`, `#define`) tokenizes as `#` op + ident             | cosmetic | yes               | —          |
| cpp          | User-defined literal suffixes (`42_km`, `"x"sv`) — suffix splits as ident    | cosmetic | no                | —          |
| cpp          | Preprocessor directives — same shape as C                                    | cosmetic | yes               | —          |
| cpp          | Trigraphs / digraphs (obsolete; never seen in real code)                     | cosmetic | no                | —          |
| crystal      | Heredocs `<<-EOF … EOF` — variable terminator, not declared                  | cosmetic | no                | —          |
| crystal      | String interpolation `#{expr}` stays inside string span                      | cosmetic | yes               | ADR 0003   |
| crystal      | Macro markers `{% %}` and `{{ }}` not distinguished                          | cosmetic | no                | —          |
| csharp       | Raw string literals `"""…"""` (C# 11) split into strings at each `""`        | cosmetic | no                | —          |
| csharp       | Quote inside an interpolation hole (`$"{(c ? "x" : "y")}"`) ends the string  | semantic | no                | ADR 0003   |
| csharp       | Pattern-matching keywords (`is`, `not`, `and`, `or`) parse-side concern      | cosmetic | yes               | —          |
| css          | `url(...)` body parsed as nested punctuation, not URL-aware                  | cosmetic | yes               | —          |
| cyml         | Setext heading `===` ambiguity with `---` separator (rare edge case)         | semantic | no                | —          |
| cyml         | A single-bracket `[table]` header right after a body reads as body text      | semantic | no                | —          |
| dockerfile   | Heredoc syntax (`COPY <<EOT`) — variable terminator, not declared            | cosmetic | no                | —          |
| dockerfile   | Parser directives `# syntax=…` / `# escape=…` are plain `#` line comments    | cosmetic | yes               | —          |
| elixir       | Sigils `~r/.../`, `~w()`, `~s"…"` tokenize as op + body                      | cosmetic | no                | —          |
| elixir       | String interpolation `#{expr}` stays inside string span                      | cosmetic | yes               | ADR 0003   |
| elixir       | Atoms `:foo` split as `:` punct + `foo` ident                                | cosmetic | yes               | —          |
| go           | Predeclared identifiers (`len`, `iota`, `nil`, `make`) tokenize as ident     | cosmetic | yes               | ADR 0004   |
| graphql      | Custom directive bodies — themes can re-pair by token text                   | cosmetic | yes               | —          |
| haskell      | Layout-sensitive parsing (where / let / do off-side rule) — parser-level     | cosmetic | yes               | —          |
| haskell      | Nested block comments `{- a {- b -} c -}` close at the first `-}`            | semantic | no                | —          |
| haskell      | Pragmas `{-# LANGUAGE … #-}` treated as block comments                       | cosmetic | yes               | —          |
| haskell      | Multi-line `"""…"""` strings (not actually Haskell syntax)                   | n/a      | no                | —          |
| haskell      | User-defined operators with rare punctuation may fragment                    | cosmetic | no                | —          |
| html         | DOCTYPE declarations split as `<` + `!` + ident + ident + `>`                | cosmetic | yes               | —          |
| html         | Conditional comments (`<!--[if IE]>…<![endif]-->`) — not in stand-in         | cosmetic | no                | —          |
| html         | Numeric character references (`&#8212;`) split into 4 tokens                 | cosmetic | yes               | —          |
| ini          | Multi-line values via line-continuation (`\` at EOL)                         | cosmetic | no                | —          |
| ini          | `.properties`: `!` comments unrecognised; `;` / `#` in a value opens one     | semantic | no                | —          |
| ini          | `KEY[]` repeated-key array syntax (PHP-style ini)                            | cosmetic | no                | —          |
| java         | Text blocks (`"""…"""`, Java 13+)                                            | cosmetic | no                | ADR 0008   |
| javascript   | Template literal interpolation `${expr}` flat string                         | cosmetic | yes               | ADR 0003   |
| javascript   | Regex literals `/pat/flags` not distinguished                                | cosmetic | yes               | —          |
| javascript   | JSX not handled — no bundled grammar covers it                               | n/a      | no                | —          |
| julia        | Nested block comments `#= a #= b =# c =#` close at first `=#` (greedy)       | semantic | no                | —          |
| julia        | Unicode operators (`≠`, `≤`, `∈`) tokenize as ident                          | cosmetic | yes               | —          |
| julia        | String interpolation `$var` / `$(expr)` stays in string span                 | cosmetic | yes               | ADR 0003   |
| julia        | String macros beyond `raw` / `r` / `b` / `v` (`html"…"`) split off as ident  | cosmetic | no                | —          |
| kotlin       | Triple-quoted raw strings `"""…"""`                                          | cosmetic | no                | ADR 0008   |
| lean         | Nested block comments `/- a /- b -/ c -/` close at the first `-/`            | semantic | no                | —          |
| lean         | Unicode operators (`→`, `∀`, `≤`) tokenize as ident                          | cosmetic | yes               | —          |
| lean         | Interpolation holes in `s!"…{x}…"` stay inside string span                   | cosmetic | yes               | ADR 0003   |
| llvm_ir      | C-string syntax `c"…\\00"` — body handled by regular `"…"` pair              | cosmetic | yes               | —          |
| llvm_ir      | Aggregate constants `<{ … }>` (packed structs)                               | cosmetic | no                | —          |
| llvm_ir      | Vector types `<4 x i32>` — `<`, `x`, `>` all separate tokens                 | cosmetic | yes               | —          |
| makefile     | `define VAR … endef` bodies tokenize as ordinary code, not one span          | cosmetic | no                | —          |
| makefile     | Recipe lines (after a tab) are not routed to the shell grammar               | cosmetic | yes               | —          |
| markdown     | Setext underlines (`===`, `---`) are 3-byte ops — same token as a `---` rule | cosmetic | yes               | —          |
| markdown     | Tables don't get a distinguished kind                                        | cosmetic | yes               | —          |
| markdown     | Prose tokenizes as ident runs (no `prose` kind in 10-kind palette)           | cosmetic | yes               | —          |
| markdown     | Snake_case prose words fragment (`_` is emphasis here)                       | cosmetic | yes               | —          |
| mdx          | `{…}` expressions end at the first `}` — a nested `{ {a: 1} }` ends early    | semantic | no                | —          |
| mdx          | JSX tags (`<Chart …>`) tokenize as markdown ops / idents, as raw HTML does   | cosmetic | yes               | —          |
| nasm         | Suffixed hex with a letter digit (`0FFh`) is `number(0)` + `ident(FFh)`      | cosmetic | no                | —          |
| nix          | String interpolation `${expr}` stays inside string span                      | cosmetic | no                | ADR 0003   |
| nix          | Path literals (`./foo`, `~/cfg`, `<nixpkgs>`) split as punct + ident         | cosmetic | no                | —          |
| nix          | Indented-string escapes (`''$`, `'''`, `''\n`) close pair early              | cosmetic | no                | —          |
| nix          | URL literals (`https://foo`) split as ident + `:` + `//` + path tail         | cosmetic | no                | —          |
| nix          | Leading-dot floats (`.5`) split as `.` + `number`                            | cosmetic | no                | ADR 0026   |
| ocaml        | Nested block comments `(* a (* b *) c *)` close at the first `*)`            | semantic | no                | —          |
| ocaml        | Quoted strings `{\|…\|}` and `{tag\|…\|tag}` — variable delimiter            | cosmetic | no                | —          |
| ocaml        | Polymorphic variants `` `Foo `` (backtick prefix)                            | cosmetic | yes               | —          |
| openqasm     | Leading-dot floats (`.5`) split as `.` + `number`                            | cosmetic | no                | ADR 0026   |
| openqasm     | Timing literals (`100ns`, `2us`, `1dt`) split as `number` + `ident`          | cosmetic | no                | —          |
| openqasm     | `pragma` / `defcalgrammar` free-text bodies tokenize as ordinary idents      | cosmetic | no                | —          |
| php          | String interpolation (`"$x"`, `"{$x}"`) stays inside string span             | cosmetic | yes               | ADR 0003   |
| powershell   | Here-strings `@'...'@` and `@"..."@`                                         | cosmetic | no                | —          |
| powershell   | String interpolation `$var` / `$(expr)` stays inside string span             | cosmetic | yes               | ADR 0003   |
| powershell   | Cmdlet-parameter context — `-Path`, `-Recurse` split as `-` + ident          | cosmetic | yes               | —          |
| protobuf     | Custom options bodies tokenize as nested k/v ident pairs                     | cosmetic | yes               | —          |
| python       | F-string interpolation `{expr}` stays inside string span                     | cosmetic | yes               | ADR 0003   |
| ruby         | Regex literals `/.../` context-sensitive vs. division                        | cosmetic | yes               | —          |
| ruby         | `?C` character literal (deprecated post-1.9)                                 | cosmetic | no                | —          |
| ruby         | `=begin` / `=end` also match mid-line (Ruby requires column 0)               | semantic | no                | —          |
| rust         | Nested block comments `/* a /* b */ c */` close at the first `*/`            | semantic | no                | —          |
| scss         | Sass placeholder selectors `%placeholder` split as `%` op + ident            | cosmetic | yes               | —          |
| sql          | Dollar-quoted strings (PostgreSQL `$$ … $$`, `$tag$ … $tag$`)                | cosmetic | no                | —          |
| sql          | Doubled-quote escape `'it''s'` comes back as two adjacent strings            | cosmetic | no                | —          |
| svelte       | Logic blocks `{#if}` / `{:else}` / `{/if}` tokenize as raw braces + idents   | cosmetic | yes               | —          |
| svelte       | Single-brace interpolation `{expression}` not routed through JS              | cosmetic | yes               | —          |
| svelte       | Reactive declarations `$:` split as `$` + `:`                                | cosmetic | yes               | —          |
| svelte       | Event handlers / bindings (`on:click`, `bind:value`) split on `:`            | cosmetic | yes               | —          |
| svelte       | Attribute-bearing block tags `<script lang="ts">` — fall back to HTML        | cosmetic | yes               | ADR 0013   |
| swift        | String interpolation `\(expr)` stays inside string span                      | cosmetic | yes               | ADR 0003   |
| swift        | Extended-delimiter escape `\#"` not read — `#"\#"#"#` closes at first `"#`   | semantic | no                | ADR 0030   |
| swift        | Nested block comments `/* a /* b */ c */` close at the first `*/`            | semantic | no                | —          |
| swift        | Attribute syntax (`@available`, `@objc`) — `@` in ident_start                | n/a      | yes               | —          |
| terraform    | Heredocs `<<EOT … EOT` / `<<-EOT … EOT` — variable terminator                | cosmetic | no                | —          |
| terraform    | String interpolation `${expr}` stays inside string span                      | cosmetic | yes               | ADR 0003   |
| terraform    | Splat shorthand `aws_instance.web.*.id` — `*` is 1-byte op amid dotted access | cosmetic | yes               | —          |
| typescript   | Template literal interpolation `${expr}` flat string                         | cosmetic | yes               | ADR 0003   |
| typescript   | Regex literals `/pat/flags` not distinguished                                | cosmetic | no                | —          |
| typescript   | JSX / TSX elements (`.tsx`) — not mapped; no bundled grammar covers them     | n/a      | no                | —          |
| vue          | Vue directives (`v-if`, `v-for`, …) tokenize as plain attribute idents       | cosmetic | yes               | —          |
| vue          | Shorthand prefixes (`:`, `@`, `#`) split before attribute name               | cosmetic | yes               | —          |
| vue          | Mustache `{{ expr }}` interpolation tokenizes as raw braces                  | cosmetic | yes               | —          |
| vue          | Attribute-bearing block tags `<script lang="ts">` — fall back to HTML        | cosmetic | yes               | ADR 0013   |
| vue          | Custom elements (`<my-component>`) — plain idents (HTML5-compatible)         | n/a      | yes               | —          |
| xml          | DTDs (`<!ELEMENT …>`, `<!ATTLIST …>`)                                        | cosmetic | no                | —          |
| xml          | XML Schema / XSLT keywords tokenize as plain idents                          | cosmetic | no                | —          |
| yaml         | Block scalars `\|` / `>` — the content lines fragment into plain idents      | cosmetic | no                | —          |
| yaml         | Document markers `---` / `...` split into three 1-byte tokens each           | cosmetic | no                | —          |
| yaml         | Tags `!!str` / `!foo` split as `!` operator(s) + ident                       | cosmetic | no                | —          |
| zig          | `@`-prefixed builtins (`@import`) tokenize as ident, not keyword             | cosmetic | yes               | ADR 0004   |

---

## Grammars with no documented gaps

These grammars round-trip their corpus cleanly without any
documented limitations in the file header. That doesn't mean
they're gap-free — it means the maintainer hasn't surfaced any
yet, and real-world inputs may still reveal edge cases worth
opening an issue against vyakarana for.

- **cyrius** — The corpus is vidya's reference sample. Char
  literals (`'"'`, `'\n'`) are one token since vyakarana 2.5.2
  ([ADR 0010](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0010-char-literal-default.md)).
- **json** — Strict spec, no syntactic variation.
- **lua** — Level-n long brackets `[==[…]==]` (the only
  historical gap) are one token since vyakarana 2.9.5
  ([ADR 0030](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0030-heredoc-computed-closers.md));
  no remaining items.
- **shell** — POSIX baseline. `#` opens a comment only at
  word start
  ([ADR 0022](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0022-line-rule-start-after.md))
  and heredocs are one string token
  ([ADR 0023](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0023-heredoc-rule.md)),
  both since vyakarana 2.6.0. The `special_vars` and ADR 0004
  (builtins-as-ident) shapes are documented as scanner
  defaults rather than gaps.
- **toml** — Triple-quoted strings (the only historical gap)
  closed by [vyakarana ADR 0008](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0008-toml-triple-quoted-strings.md);
  no remaining items.

---

## How this doc stays current

Source of truth: the gap-note headers in
`grammars/*.cyml`. owl's bundled grammars are vendored from
[vyakarana](https://github.com/MacCracken/vyakarana) at every
`[deps.vyakarana].tag` bump in `cyrius.cyml`; this doc is
refreshed in the same patch that adds, removes, or rewires a
grammar.

If you find a gap not listed here — either because a real
input trips it or because a grammar header documents it but
this doc doesn't reflect the language yet — the right fix is
upstream in vyakarana's grammar source, with a follow-up
sync in owl.
