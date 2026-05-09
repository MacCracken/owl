# owl — Grammar coverage

A reader-friendly index of what won't highlight perfectly in
each bundled grammar. **Source of truth lives in the grammar
file headers themselves** (`grammars/*.cyml`) — this doc
aggregates those notes so you don't have to read 45 files to
find out whether your Python f-strings or Vue directives will
render the way you'd expect.

owl bundles **45 grammars** as of the 1.3.5 cut. Each one was
designed against a real or stand-in corpus that round-trips
with zero `TK_ERROR` tokens; the gaps below are places where
the tokenization is *correct* but cosmetically less rich than
a hand-tuned grammar would produce.

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
  Crystal, Julia, Swift, PowerShell.
- **Variable-length delimiters (heredocs, long brackets, raw
  strings).** `<<EOT … EOT`, `[==[…]==]`, `r#"…"#`, `"""…"""`
  with a runtime-determined terminator. Vyakarana's pair-rule
  scanner uses a fixed start/end byte sequence; variable
  delimiters are tracked collectively and require a future
  scanner extension. Affects Lua, Ruby, PHP, Crystal, Swift,
  Dockerfile, OCaml, SQL, PowerShell, Kotlin (`"""…"""`).
- **Numeric literal underscores fragment.** `1_000_000`
  tokenizes as `number(1) + ident(_000_000)` because
  `ident_start` excludes digits, but `_` is in `ident_cont`.
  A `digit_sep = true` scanner default would close this
  across all C-family grammars; until then it's cosmetic.
  Affects Java, Kotlin, C#, Go, Rust, Ruby, PHP, OCaml,
  Elixir, others.
- **Float literal split on `.`.** The number scanner stops at
  `.`; `1.5rem` becomes `number(1) + .(punct) + number(5) +
  ident(rem)`. A `number_float` default would close it
  uniformly. Affects Java, CSS, SCSS, asm_x86_64,
  asm_aarch64, GraphQL, Protobuf, others.
- **C-family char literals split.** `'x'` tokenizes as
  `'(op) + ident(x) + '(op)` instead of one `TK_STRING`. The
  `char_literal = true` default
  ([vyakarana ADR 0010](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0010-char-literal-default.md))
  has landed for C, Rust, Go, Zig grammars; C++ and others
  still inherit the gap.
- **Regex literals aren't distinguished.** `/pat/flags` is
  context-sensitive vs. division; tokenizes as op + body +
  op. Affects JS, TS, Ruby.
- **Compose-rule start markers must be literal.**
  `<script>` and `<style>` route through compose rules to
  JavaScript / CSS, but attribute-bearing forms like
  `<script lang="ts">` fall back to plain outer-grammar
  tokenization
  ([vyakarana ADR 0013 §When to revisit](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0013-grammar-composition.md)).
  Affects HTML, Vue, Svelte.
- **Predeclared identifiers aren't keywords.** Built-in
  names that are *shadowable* in the language stay as
  `TK_IDENT` rather than `TK_KEYWORD` per
  [vyakarana ADR 0004](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0004-shell-builtins-as-ident.md):
  `len` / `iota` / `nil` in Go, `@import` in Zig, shell
  builtins, etc. Themes can apply secondary palettes by
  token text.

---

## Per-grammar gaps

| Language     | Gap                                                                          | Severity | In sample corpus? | ADR        |
|--------------|------------------------------------------------------------------------------|----------|-------------------|------------|
| asm_aarch64  | Float literals (`1.5`) split on `.`                                          | cosmetic | no                | —          |
| asm_aarch64  | `;` instruction-separator tokenizes as punctuation                           | cosmetic | no                | —          |
| asm_x86_64   | Float literals (`1.5`) split on `.`                                          | cosmetic | no                | —          |
| asm_x86_64   | AT&T-syntax operand sigils (`%rax`, `$0x10`) — only Intel syntax in corpus   | cosmetic | no                | —          |
| asm_x86_64   | NASM-style `;` line comments — GAS uses `#`                                  | cosmetic | no                | —          |
| c            | Block comments `/* … */` not in vidya sample                                 | cosmetic | no                | —          |
| c            | Char literals `'x'` split into 3 ops (until char_literal default lands)      | cosmetic | yes               | ADR 0010 (now active)|
| c            | Preprocessor (`#include`, `#define`) tokenizes as `#` op + ident             | cosmetic | yes               | —          |
| cpp          | Raw string literals `R"delim(…)delim"` — variable-length delimiter           | cosmetic | no                | —          |
| cpp          | User-defined literal suffixes (`42_km`, `"x"sv`) — suffix splits as ident    | cosmetic | no                | —          |
| cpp          | Numeric digit separators (`1'000'000`) could confuse char_literal            | cosmetic | no                | —          |
| cpp          | Preprocessor directives — same shape as C                                    | cosmetic | yes               | —          |
| cpp          | Trigraphs / digraphs (obsolete; never seen in real code)                     | cosmetic | no                | —          |
| crystal      | Heredocs `<<-EOF … EOF` — variable terminator                                | cosmetic | no                | —          |
| crystal      | String interpolation `#{expr}` stays inside string span                      | cosmetic | yes               | ADR 0003   |
| crystal      | Macro markers `{% %}` and `{{ }}` not distinguished                          | cosmetic | no                | —          |
| csharp       | Verbatim `@"…"` and raw `"""…"""` strings — prefixes split off               | cosmetic | no                | —          |
| csharp       | Numeric suffixes (`42L`, `1.5f`, `1_000_000`)                                | cosmetic | no                | —          |
| csharp       | Pattern-matching keywords (`is`, `not`, `and`, `or`) parse-side concern      | cosmetic | yes               | —          |
| css          | Float numbers (`1.5rem`) split on `.`                                        | cosmetic | no                | —          |
| css          | `url(...)` body parsed as nested punctuation, not URL-aware                  | cosmetic | yes               | —          |
| cyml         | Multi-line TOML `"""…"""` not in current sample                              | cosmetic | no                | ADR 0008   |
| cyml         | Markdown code fences `` ``` `` tokenize as three backtick ops                | cosmetic | yes               | —          |
| cyml         | Setext heading `===` ambiguity with `---` separator (rare edge case)         | semantic | no                | —          |
| dockerfile   | Heredoc syntax (`COPY <<EOT`) — variable terminator                          | cosmetic | no                | —          |
| dockerfile   | Parser directives `# syntax=…` / `# escape=…` are plain `#` line comments    | cosmetic | yes               | —          |
| elixir       | Sigils `~r/.../`, `~w()`, `~s"…"` tokenize as op + body                      | cosmetic | no                | —          |
| elixir       | Heredoc strings `"""…"""`                                                    | cosmetic | no                | ADR 0008   |
| elixir       | String interpolation `#{expr}` stays inside string span                      | cosmetic | yes               | ADR 0003   |
| elixir       | Atoms `:foo` split as `:` punct + `foo` ident                                | cosmetic | yes               | —          |
| elixir       | Numeric underscores (`1_000_000`) — number scanner stops at `_`              | cosmetic | yes               | —          |
| go           | Backtick raw strings `` `…` `` not in vidya sample                           | cosmetic | no                | —          |
| go           | Rune literals `'x'` split into 3 ops                                         | cosmetic | yes               | ADR 0010 (now active)|
| go           | Numeric underscores (`1_000_000`)                                            | cosmetic | no                | —          |
| go           | Predeclared identifiers (`len`, `iota`, `nil`, `make`) tokenize as ident     | cosmetic | yes               | ADR 0004   |
| graphql      | Float / scientific notation (`3.14`, `1.5e3`)                                | cosmetic | no                | —          |
| graphql      | Custom directive bodies — themes can re-pair by token text                   | cosmetic | yes               | —          |
| haskell      | Layout-sensitive parsing (where / let / do off-side rule) — parser-level     | cosmetic | yes               | —          |
| haskell      | Pragmas `{-# LANGUAGE … #-}` treated as block comments                       | cosmetic | yes               | —          |
| haskell      | Multi-line `"""…"""` strings (not actually Haskell syntax)                   | n/a      | no                | —          |
| haskell      | User-defined operators with rare punctuation may fragment                    | cosmetic | no                | —          |
| html         | DOCTYPE declarations split as `<` + `!` + ident + ident + `>`                | cosmetic | yes               | —          |
| html         | Conditional comments (`<!--[if IE]>…<![endif]-->`) — not in stand-in         | cosmetic | no                | —          |
| html         | Numeric character references (`&#8212;`) split into 4 tokens                 | cosmetic | yes               | —          |
| ini          | Multi-line values via line-continuation (`\` at EOL)                         | cosmetic | no                | —          |
| ini          | `KEY[]` repeated-key array syntax (PHP-style ini)                            | cosmetic | no                | —          |
| java         | Text blocks (`"""…"""`, Java 13+)                                            | cosmetic | no                | ADR 0008   |
| java         | Numeric suffixes (`42L`, `3.14f`) and underscores (`1_000_000`)              | cosmetic | yes               | —          |
| java         | Float literals (`3.14`) split on `.`                                         | cosmetic | yes               | —          |
| javascript   | Template literal interpolation `${expr}` flat string                         | cosmetic | yes               | ADR 0003   |
| javascript   | Regex literals `/pat/flags` not distinguished                                | cosmetic | yes               | —          |
| javascript   | JSX is a separate grammar                                                    | n/a      | no                | —          |
| julia        | Nested block comments `#= a #= b =# c =#` close at first `=#` (greedy)       | semantic | no                | —          |
| julia        | Unicode operators (`≠`, `≤`, `∈`) tokenize as ident                          | cosmetic | yes               | —          |
| julia        | String interpolation `$var` / `$(expr)` stays in string span                 | cosmetic | yes               | ADR 0003   |
| julia        | Raw strings `raw"..."` — `raw` prefix splits off as ident                    | cosmetic | no                | —          |
| kotlin       | Triple-quoted raw strings `"""…"""`                                          | cosmetic | no                | ADR 0008   |
| kotlin       | Backtick-quoted identifiers (`` `class` ``) for Java reserved words          | cosmetic | no                | —          |
| kotlin       | Numeric suffixes (`42L`, `1.5f`, `1_000_000`)                                | cosmetic | no                | —          |
| llvm_ir      | C-string syntax `c"…\\00"` — body handled by regular `"…"` pair              | cosmetic | yes               | —          |
| llvm_ir      | Aggregate constants `<{ … }>` (packed structs)                               | cosmetic | no                | —          |
| llvm_ir      | Vector types `<4 x i32>` — `<`, `x`, `>` all separate tokens                 | cosmetic | yes               | —          |
| lua          | Variable-padded long brackets `[==[…]==]`                                    | cosmetic | no                | —          |
| markdown     | Setext heading underlines (`===`, `---`) split per byte                      | cosmetic | yes               | —          |
| markdown     | Tables don't get a distinguished kind                                        | cosmetic | yes               | —          |
| markdown     | Prose tokenizes as ident runs (no `prose` kind in 10-kind palette)           | cosmetic | yes               | —          |
| markdown     | Snake_case prose words fragment (`_` is emphasis here)                       | cosmetic | yes               | —          |
| nix          | String interpolation `${expr}` stays inside string span                      | cosmetic | no                | ADR 0003   |
| nix          | Path literals (`./foo`, `~/cfg`, `<nixpkgs>`) split as punct + ident         | cosmetic | no                | —          |
| nix          | Indented-string escapes (`''$`, `'''`, `''\n`) close pair early              | cosmetic | no                | —          |
| nix          | URL literals (`https://foo`) split as ident + `:` + `//` + path tail         | cosmetic | no                | —          |
| ocaml        | Quoted strings `{\|…\|}` and `{tag\|…\|tag}` — variable delimiter            | cosmetic | no                | —          |
| ocaml        | Polymorphic variants `` `Foo `` (backtick prefix)                            | cosmetic | no                | —          |
| ocaml        | Numeric underscores (`1_000_000`)                                            | cosmetic | no                | —          |
| php          | `#[Attribute]` syntax (PHP 8) splits into `#` + `[` + ident + `]`            | cosmetic | no                | —          |
| php          | Heredocs / nowdocs `<<<EOT … EOT;` — variable terminator                     | cosmetic | no                | —          |
| php          | Numeric underscores (`1_000_000`)                                            | cosmetic | no                | —          |
| php          | String interpolation (`"$x"`, `"{$x}"`) stays inside string span             | cosmetic | yes               | ADR 0003   |
| powershell   | Here-strings `@'...'@` and `@"..."@`                                         | cosmetic | no                | —          |
| powershell   | String interpolation `$var` / `$(expr)` stays inside string span             | cosmetic | yes               | ADR 0003   |
| powershell   | Cmdlet-parameter context — `-Path`, `-Recurse` split as `-` + ident          | cosmetic | yes               | —          |
| protobuf     | Custom options bodies tokenize as nested k/v ident pairs                     | cosmetic | yes               | —          |
| protobuf     | Numeric literal scientific notation (`1.5e3`)                                | cosmetic | no                | —          |
| protobuf     | `reserved 100 to 199;` — `to` not in keyword set                             | cosmetic | no                | —          |
| python       | F-string prefix `f"..."` splits into `ident(f) + string("...")`              | cosmetic | yes               | —          |
| python       | F-string interpolation `{expr}` stays inside string span                     | cosmetic | yes               | ADR 0003   |
| ruby         | Heredocs `<<~END … END` — variable terminator                                | cosmetic | no                | —          |
| ruby         | Regex literals `/.../` context-sensitive vs. division                        | cosmetic | yes               | —          |
| ruby         | `?C` character literal (deprecated post-1.9)                                 | cosmetic | no                | —          |
| ruby         | Numeric underscores (`1_000_000`); `_` as ignored argument                   | cosmetic | yes               | —          |
| rust         | Block comments `/* … */` (Rust's are nestable)                               | cosmetic | no                | —          |
| rust         | Raw strings `r"..."`, `r#"..."#`, `r##"..."##`                               | cosmetic | no                | —          |
| rust         | Byte strings `b"..."`, byte chars `b'x'`                                     | cosmetic | no                | —          |
| rust         | Char literals `'x'` split into 3 tokens                                      | cosmetic | yes               | ADR 0010 (now active)|
| rust         | Numeric literal suffixes (`42_u32`) and floats                               | cosmetic | yes               | —          |
| scss         | Float numbers (same as css)                                                  | cosmetic | yes               | —          |
| scss         | Sass placeholder selectors `%placeholder` — `%` not in ident_start           | cosmetic | no                | —          |
| sql          | Dollar-quoted strings (PostgreSQL `$$ … $$`, `$tag$ … $tag$`)                | cosmetic | no                | —          |
| sql          | Backtick identifiers (MySQL) — not in ANSI baseline                          | cosmetic | no                | —          |
| sql          | Numeric scientific notation (`1.5e3`)                                        | cosmetic | no                | —          |
| svelte       | Logic blocks `{#if}` / `{:else}` / `{/if}` tokenize as raw braces + idents   | cosmetic | yes               | —          |
| svelte       | Single-brace interpolation `{expression}` not routed through JS              | cosmetic | yes               | —          |
| svelte       | Reactive declarations `$:` split as `$` + `:`                                | cosmetic | yes               | —          |
| svelte       | Event handlers / bindings (`on:click`, `bind:value`) split on `:`            | cosmetic | yes               | —          |
| svelte       | Attribute-bearing block tags `<script lang="ts">` — fall back to HTML        | cosmetic | yes               | ADR 0013   |
| swift        | String interpolation `\(expr)` stays inside string span                      | cosmetic | yes               | ADR 0003   |
| swift        | Raw strings `#"…"#`, `##"…"##` — variable-length delimiter                   | cosmetic | no                | —          |
| swift        | Nestable block comments `/* */` close at first `*/`                          | cosmetic | no                | —          |
| swift        | Attribute syntax (`@available`, `@objc`) — `@` in ident_start                | n/a      | yes               | —          |
| terraform    | Heredocs `<<EOT … EOT` / `<<-EOT … EOT` — variable terminator                | cosmetic | no                | —          |
| terraform    | String interpolation `${expr}` stays inside string span                      | cosmetic | yes               | ADR 0003   |
| terraform    | Splat shorthand `aws_instance.web.*.id` — `*` is 1-byte op amid dotted access | cosmetic | yes               | —          |
| typescript   | Template literal interpolation `${expr}` flat string                         | cosmetic | yes               | ADR 0003   |
| typescript   | Regex literals `/pat/flags` not distinguished                                | cosmetic | no                | —          |
| typescript   | JSX / TSX elements (`.tsx`) — separate grammar                               | n/a      | no                | —          |
| vue          | Vue directives (`v-if`, `v-for`, …) tokenize as plain attribute idents       | cosmetic | yes               | —          |
| vue          | Shorthand prefixes (`:`, `@`, `#`) split before attribute name               | cosmetic | yes               | —          |
| vue          | Mustache `{{ expr }}` interpolation tokenizes as raw braces                  | cosmetic | yes               | —          |
| vue          | Attribute-bearing block tags `<script lang="ts">` — fall back to HTML        | cosmetic | yes               | ADR 0013   |
| vue          | Custom elements (`<my-component>`) — plain idents (HTML5-compatible)         | n/a      | yes               | —          |
| xml          | DTDs (`<!ELEMENT …>`, `<!ATTLIST …>`)                                        | cosmetic | no                | —          |
| xml          | XML Schema / XSLT keywords tokenize as plain idents                          | cosmetic | no                | —          |
| zig          | Char literals `'x'` split into 3 ops                                         | cosmetic | yes               | ADR 0010 (now active)|
| zig          | Multi-line strings (lines starting with `\\`)                                | cosmetic | no                | —          |
| zig          | `@`-prefixed builtins (`@import`) tokenize as ident, not keyword             | cosmetic | yes               | ADR 0004   |

---

## Grammars with no documented gaps

These grammars round-trip their corpus cleanly without any
documented limitations in the file header. That doesn't mean
they're gap-free — it means the maintainer hasn't surfaced any
yet, and real-world inputs may still reveal edge cases worth
opening an issue against vyakarana for.

- **cyrius** — Self-hosting; the corpus is owl's own source.
- **json** — Strict spec, no syntactic variation.
- **shell** — POSIX baseline. The shell grammar exposed
  `special_vars` and ADR 0004 (builtins-as-ident) shapes
  upstream; both are documented as scanner defaults rather
  than gaps.
- **toml** — Triple-quoted strings (the only historical gap)
  closed by [vyakarana ADR 0008](https://github.com/MacCracken/vyakarana/blob/main/docs/adr/0008-toml-triple-quoted-strings.md);
  no remaining items.
- **yaml** — Block-scalar shapes (`|`, `>`) and anchor
  references (`&`, `*`) tokenize correctly via the standard
  scanner defaults.

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
