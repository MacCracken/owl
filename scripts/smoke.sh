#!/usr/bin/env bash
# owl smoke test — M0–M8 gates + security hardening probes.
# Usage: bash scripts/smoke.sh [path/to/owl]    (default: build/owl)
#
# bash is required: the script uses process substitution `<(...)` for
# diff comparisons against dynamic output, and `$'\x1b'` C-string
# escapes for ANSI probes. Running this through dash (Ubuntu's /bin/sh)
# will fail on line 51 with a syntax error.
set -eu

BIN="${1:-build/owl}"

if [ ! -x "$BIN" ]; then
    echo "smoke: $BIN not executable — run 'cyrius build src/main.cyr build/owl' first" >&2
    exit 1
fi

TMPDIR="${TMPDIR:-/tmp}/owl-smoke-$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

fail() { echo "smoke: FAIL — $1" >&2; exit 1; }

# Absolute owl path — the VCS-marker gates `cd` into a throwaway sit repo
# (owl resolves the repo from CWD), so a relative $BIN would break there.
BIN_ABS="$(cd "$(dirname "$BIN")" && pwd)/$(basename "$BIN")"

# sit binary — owl 1.4.0 reads VCS change markers from sit's *library*
# (no subprocess at runtime), but building a test repo for the marker gates
# needs the sit CLI to init/commit. Discovery: $OWL_SIT_BIN → PATH → sibling
# checkout. Empty when unavailable, in which case the sit-backed gates print
# a NOTE and skip (they do not silently pass).
SIT_BIN=""
if [ -n "${OWL_SIT_BIN:-}" ] && [ -x "${OWL_SIT_BIN}" ]; then
    SIT_BIN="$OWL_SIT_BIN"
elif command -v sit >/dev/null 2>&1; then
    SIT_BIN="$(command -v sit)"
elif [ -x "../sit/build/sit" ]; then
    SIT_BIN="$(cd ../sit/build && pwd)/sit"
fi

# Build a throwaway sit repo at $1 with a committed-then-modified file
# `tracked.txt`: line 2 changed in place (→ MOD) and a line appended (→ ADD).
# Used by the M6 marker gate and the --diff gate. Caller must have checked
# $SIT_BIN is non-empty.
make_sit_fixture() {
    repo="$1"
    mkdir -p "$repo"
    (
        cd "$repo" || exit 1
        "$SIT_BIN" init        >/dev/null 2>&1 || exit 1
        printf 'alpha\nbeta\ngamma\ndelta\n' > tracked.txt
        "$SIT_BIN" add tracked.txt >/dev/null 2>&1 || exit 1
        "$SIT_BIN" commit -m init  >/dev/null 2>&1 || exit 1
        printf 'alpha\nBETA-changed\ngamma\ndelta\nepsilon-new\n' > tracked.txt
    )
}

# ============================================================
# M0 — version / help
# ============================================================

v_long=$("$BIN" --version) || fail "--version exited non-zero"
[ -n "$v_long" ]            || fail "--version emitted nothing"

v_short=$("$BIN" -V) || fail "-V exited non-zero"
[ "$v_long" = "$v_short" ] || fail "-V disagrees with --version"

case "$v_long" in
    "owl "*) ;;
    *) fail "--version output does not start with 'owl ': $v_long" ;;
esac

h_long=$("$BIN" --help) || fail "--help exited non-zero"
[ -n "$h_long" ]         || fail "--help emitted nothing"

h_short=$("$BIN" -h) || fail "-h exited non-zero"
[ "$h_long" = "$h_short" ] || fail "-h disagrees with --help"

# --version --verbose adds vyakarana + cyrius pins (1.1.1).
v_verbose=$("$BIN" --version --verbose) || fail "--version --verbose exited non-zero"
case "$v_verbose" in
    *vyakarana*cyrius*) ;;
    *) fail "--version --verbose missing vyakarana/cyrius lines: $v_verbose" ;;
esac
# Order independence — --verbose --version should match.
v_verbose2=$("$BIN" --verbose --version) || fail "--verbose --version exited non-zero"
[ "$v_verbose" = "$v_verbose2" ] || fail "--version --verbose ≠ --verbose --version"
# Plain --version stays terse (regression guard).
[ "$v_long" != "$v_verbose" ] || fail "--version regressed to verbose by default"
# 1.6.0 — the verbose pins are hand-kept in print_version, and went stale for
# three releases (1.4.1–1.4.8). Pin them to cyrius.cyml, the one authority.
if [ -f cyrius.cyml ]; then
    want_cy=$(sed -n 's/^cyrius = "\(.*\)"/\1/p' cyrius.cyml)
    want_vy=$(sed -n '/^\[deps\.vyakarana\]/,/^\[/s/^tag = "\(.*\)"/\1/p' cyrius.cyml)
    want_sit=$(sed -n '/^\[deps\.sit\]/,/^\[/s/^tag = "\(.*\)"/\1/p' cyrius.cyml)
    want_cmdit=$(sed -n '/^\[deps\.cmdit\]/,/^\[/s/^tag = "\(.*\)"/\1/p' cyrius.cyml)
    for pair in "vyakarana $want_vy" "sit $want_sit" "cmdit $want_cmdit" "cyrius $want_cy"; do
        printf '%s\n' "$v_verbose" | grep -qx "$pair" \
            || fail "--version --verbose does not print '$pair' (cyrius.cyml); update print_version"
    done
else
    echo "smoke: NOTE — run from the repo root to check --verbose pins against cyrius.cyml" >&2
fi

# ============================================================
# M1 — plain-mode cat parity
# ============================================================

# Fixture corpus.
printf 'line one\nline two\nline three\n' > "$TMPDIR/a.txt"
printf 'second file\n' > "$TMPDIR/b.txt"
: > "$TMPDIR/empty.txt"
yes "this is owl" 2>/dev/null | head -c 1048576 > "$TMPDIR/big.txt"

# Single-file byte identity with cat.
diff "$TMPDIR/a.txt" <("$BIN" "$TMPDIR/a.txt") > /dev/null \
    || fail "single-file output not byte-identical to cat"

# Multi-file concat byte identity.
diff <(cat "$TMPDIR/a.txt" "$TMPDIR/b.txt") <("$BIN" "$TMPDIR/a.txt" "$TMPDIR/b.txt") > /dev/null \
    || fail "multi-file concat not byte-identical"

# Empty file.
out=$("$BIN" "$TMPDIR/empty.txt")
[ -z "$out" ] || fail "empty file produced output: $out"

# ~1 MiB file (flushes past one buffer boundary).
diff "$TMPDIR/big.txt" <("$BIN" "$TMPDIR/big.txt") > /dev/null \
    || fail "1 MiB file not byte-identical"

# stdin via explicit '-'
out=$(echo "stdin via dash" | "$BIN" -)
[ "$out" = "stdin via dash" ] || fail "stdin-via-dash: got '$out'"

# bare stdin (no args): cat parity says read stdin.
out=$(echo "bare stdin" | "$BIN")
[ "$out" = "bare stdin" ] || fail "bare stdin: got '$out'"

# Mix of files and stdin.
mixed=$(printf 'mid\n' | "$BIN" "$TMPDIR/a.txt" - "$TMPDIR/b.txt")
expected=$(printf 'line one\nline two\nline three\nmid\nsecond file')
[ "$mixed" = "$expected" ] || fail "mixed files+stdin: got '$mixed'"

# -p and --plain are accepted and are no-ops in M1.
diff <("$BIN" -p "$TMPDIR/a.txt") <("$BIN" "$TMPDIR/a.txt") > /dev/null \
    || fail "-p changed output (should be no-op in M1)"
diff <("$BIN" --plain "$TMPDIR/a.txt") <("$BIN" "$TMPDIR/a.txt") > /dev/null \
    || fail "--plain changed output (should be no-op in M1)"

# Missing file → exit 4, "owl: <path>: <reason>" to stderr.
set +e
"$BIN" "$TMPDIR/missing.txt" > /dev/null 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" = "4" ] || fail "missing-file exit: got $rc, expected 4"
grep -q "^owl: .*missing.txt: .*" "$TMPDIR/err" || fail "missing-file stderr format wrong: $(cat "$TMPDIR/err")"

# Partial failure: missing + real → exit 1, content of real file on stdout.
set +e
out=$("$BIN" "$TMPDIR/missing.txt" "$TMPDIR/a.txt" 2>"$TMPDIR/err")
rc=$?
set -e
[ "$rc" = "1" ] || fail "partial-fail exit: got $rc, expected 1"
[ "$out" = "$(cat "$TMPDIR/a.txt")" ] || fail "partial-fail: content of good file missing/corrupt"

# Unknown option → exit 2, error on stderr.
set +e
"$BIN" --frobnicate > /dev/null 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" = "2" ] || fail "unknown-option exit: got $rc, expected 2"
grep -q "^owl: .*frobnicate: .*" "$TMPDIR/err" || fail "unknown-option stderr format wrong"

# Broken pipe: spec §9 mandates clean exit without stderr noise.
# (Kernel default SIGPIPE terminates owl; shell sees 128+13=141. We
# assert the user-visible contract: stderr is empty.)
: > "$TMPDIR/err"
"$BIN" "$TMPDIR/big.txt" 2>"$TMPDIR/err" | head -1 > /dev/null || true
[ ! -s "$TMPDIR/err" ] || fail "broken-pipe produced stderr noise: $(cat "$TMPDIR/err")"

# ============================================================
# M2 — TTY awareness + line numbers
# ============================================================

# Piped output stays plain (the tests above covered byte-identity;
# this re-verifies no decorations leak when stdout is a pipe).
out=$("$BIN" "$TMPDIR/a.txt" | od -An -c | head -1)
case "$out" in
    *"l"*"i"*"n"*"e"*) ;;  # raw content
    *) fail "piped output looks decorated: $out" ;;
esac

# -n forces numbers even when piped. Gutter contains the │ separator.
out=$("$BIN" -n "$TMPDIR/a.txt")
case "$out" in
    *" │ line one"*) ;;
    *) fail "-n did not emit line-number gutter: $(printf '%s' "$out" | od -An -c | head -3)" ;;
esac
# --number long form parity.
out_long=$("$BIN" --number "$TMPDIR/a.txt")
[ "$out_long" = "$out" ] || fail "--number disagrees with -n"

# -n also emits a file header with the path.
case "$out" in
    *"│ File: $TMPDIR/a.txt"*) ;;
    *) fail "-n did not emit file header" ;;
esac

# -N forces numbers off. Piped output is already plain; this asserts
# the flag is accepted and doesn't alter byte-for-byte output.
diff <("$BIN" -N "$TMPDIR/a.txt") "$TMPDIR/a.txt" > /dev/null \
    || fail "-N changed output (should be byte-identical to cat when piped)"
diff <("$BIN" --no-number "$TMPDIR/a.txt") "$TMPDIR/a.txt" > /dev/null \
    || fail "--no-number changed output"

# -p overrides -n: plain wins.
diff <("$BIN" -p -n "$TMPDIR/a.txt") "$TMPDIR/a.txt" > /dev/null \
    || fail "-p did not override -n"

# Multi-file with -n shows one header per file.
out=$("$BIN" -n "$TMPDIR/a.txt" "$TMPDIR/b.txt")
hdr_count=$(printf '%s\n' "$out" | grep -c "│ File: ")
[ "$hdr_count" = "2" ] || fail "expected 2 file headers with -n, got $hdr_count"

# --color=<value> parses. auto/always/never all accepted, bogus rejected.
"$BIN" --color=auto "$TMPDIR/a.txt"   > /dev/null 2>&1 || fail "--color=auto rejected"
"$BIN" --color=always "$TMPDIR/a.txt" > /dev/null 2>&1 || fail "--color=always rejected"
"$BIN" --color=never "$TMPDIR/a.txt"  > /dev/null 2>&1 || fail "--color=never rejected"
set +e
"$BIN" --color=bogus "$TMPDIR/a.txt" > /dev/null 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" = "2" ] || fail "--color=bogus exit: got $rc, expected 2"
grep -q "invalid value" "$TMPDIR/err" || fail "--color=bogus missing 'invalid value' in stderr"

# --paging=<value> parses the same way.
"$BIN" --paging=auto "$TMPDIR/a.txt"   > /dev/null 2>&1 || fail "--paging=auto rejected"
set +e
"$BIN" --paging=bogus "$TMPDIR/a.txt" > /dev/null 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" = "2" ] || fail "--paging=bogus exit: got $rc, expected 2"

# NO_COLOR env — accepted without error. (M2 has no color subsystem
# yet, so this just checks the flag path doesn't regress.)
NO_COLOR=1 "$BIN" "$TMPDIR/a.txt" > /dev/null 2>&1 \
    || fail "NO_COLOR=1 caused non-zero exit"

# Bare `owl` with piped stdin still reads stdin (cat parity).
out=$(echo "bare piped" | "$BIN")
[ "$out" = "bare piped" ] || fail "bare-piped: got '$out'"

# ============================================================
# M3a — language detection + theme scaffolding
# ============================================================

# --list-themes must include both bundled themes.
tlist=$("$BIN" --list-themes)
echo "$tlist" | grep -q "^dark$"  || fail "--list-themes missing 'dark'"
echo "$tlist" | grep -q "^light$" || fail "--list-themes missing 'light'"

# --list-languages must include the starter set. 1.1.12 added go +
# zig (vyakarana 1.2.0); 1.2.0–1.2.6 added 23 more in lockstep with
# vyakarana 1.2.4 → 1.8.0; 1.3.0 added cyml + llvm_ir (vyakarana
# 1.9.0); 1.3.2 added powershell + crystal + julia (vyakarana 2.1.0);
# 1.3.3 added vue + svelte (vyakarana 2.1.1); 1.3.4 added nix
# (vyakarana 2.1.2); 1.3.5 added terraform (vyakarana 2.1.3);
# 1.4.5 added openqasm (vyakarana 2.3.5); 1.5.1 added nasm + mdx +
# lean (vyakarana 2.9.9) — 49 grammars. 1.5.2 listed markdown, whose
# grammar had shipped since 1.0.0 without a language-table row.
llist=$("$BIN" --list-languages)
for lang in plain shell python javascript typescript rust cyrius c toml json yaml go zig \
            asm_x86_64 asm_aarch64 java kotlin cpp csharp php ruby lua swift \
            elixir ocaml haskell sql graphql protobuf html xml css scss \
            dockerfile makefile ini cyml llvm_ir \
            powershell crystal julia vue svelte nix terraform openqasm \
            nasm mdx lean markdown; do
    echo "$llist" | grep -q "^$lang\$" || fail "--list-languages missing '$lang'"
done

# --theme=bogus → exit 2 with clear error.
set +e
"$BIN" --theme=bogus "$TMPDIR/a.txt" > /dev/null 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" = "2" ] || fail "--theme=bogus exit: got $rc, expected 2"
grep -q "unknown theme" "$TMPDIR/err" || fail "--theme=bogus missing 'unknown theme' in stderr"

# --language=bogus → exit 2.
set +e
"$BIN" --language=bogus "$TMPDIR/a.txt" > /dev/null 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" = "2" ] || fail "--language=bogus exit: got $rc, expected 2"

# Extension detection: .rs → rust.
printf 'fn main() {}\n' > "$TMPDIR/t.rs"
out=$("$BIN" -n "$TMPDIR/t.rs")
case "$out" in
    *"(rust)"*) ;;
    *) fail "extension detection: .rs should show (rust) in header" ;;
esac

# 1.1.12 — extension detection for the vyakarana 1.2.0 grammars
# (go, zig). Symmetric with the .rs gate above; also proves
# bootstrap_grammars is wiring go.cyml + zig.cyml into the registry.
printf 'package main\nfunc main() {}\n' > "$TMPDIR/t.go"
out=$("$BIN" -n "$TMPDIR/t.go")
case "$out" in
    *"(go)"*) ;;
    *) fail "extension detection: .go should show (go) in header" ;;
esac
printf 'pub fn main() void {}\n' > "$TMPDIR/t.zig"
out=$("$BIN" -n "$TMPDIR/t.zig")
case "$out" in
    *"(zig)"*) ;;
    *) fail "extension detection: .zig should show (zig) in header" ;;
esac
# --color=always against a Go file emits ANSI for tokens (proves the
# bundled go.cyml is loaded and the keyword pass colors `package`).
out=$(printf 'package main\nfunc main() {}\n' | "$BIN" --color=always --paging=never --language=go)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=go did not emit ANSI" ;;
esac
# Same probe for Zig — `const` / `pub fn` keywords drive the ANSI output.
out=$(printf 'pub fn main() void {}\nconst x = 1;\n' | "$BIN" --color=always --paging=never --language=zig)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=zig did not emit ANSI" ;;
esac

# 1.2.0 — asm_x86_64 (vyakarana 1.2.2). `.s` extension defaults to
# asm_x86_64; asm_aarch64 needs explicit --language= per ADR. ANSI
# probe drives `.section` + `.global` GAS directives as keywords.
printf '.global _start\n.section .text\n_start:\n  mov rax, 60\n  syscall\n' > "$TMPDIR/t.s"
out=$("$BIN" -n "$TMPDIR/t.s")
case "$out" in
    *"(asm_x86_64)"*) ;;
    *) fail "extension detection: .s should show (asm_x86_64) in header" ;;
esac
out=$(printf '.global _start\n.section .text\n' | "$BIN" --color=always --paging=never --language=asm_x86_64)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=asm_x86_64 did not emit ANSI" ;;
esac
out=$(printf 'b.eq label\nstp x29, x30, [sp, #-16]!\n' | "$BIN" --color=always --paging=never --language=asm_aarch64)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=asm_aarch64 did not emit ANSI" ;;
esac

# 1.2.1 — JVM + C-family (vyakarana 1.3.0). Java covers the
# `@`-in-ident_start + Java 21 keyword set. C++ collisions with C: .h
# stays C, .hpp / .cpp / .cc / .cxx / .hxx route to cpp.
printf 'public class T { public static void main(String[] a) {} }\n' > "$TMPDIR/t.java"
out=$("$BIN" -n "$TMPDIR/t.java")
case "$out" in
    *"(java)"*) ;;
    *) fail "extension detection: .java should show (java) in header" ;;
esac
printf 'fun main() { println(\"hi\") }\n' > "$TMPDIR/t.kt"
out=$("$BIN" -n "$TMPDIR/t.kt")
case "$out" in
    *"(kotlin)"*) ;;
    *) fail "extension detection: .kt should show (kotlin) in header" ;;
esac
printf '#include <iostream>\nint main() { return 0; }\n' > "$TMPDIR/t.cpp"
out=$("$BIN" -n "$TMPDIR/t.cpp")
case "$out" in
    *"(cpp)"*) ;;
    *) fail "extension detection: .cpp should show (cpp) in header" ;;
esac
printf 'using System;\nclass T { static void Main() {} }\n' > "$TMPDIR/t.cs"
out=$("$BIN" -n "$TMPDIR/t.cs")
case "$out" in
    *"(csharp)"*) ;;
    *) fail "extension detection: .cs should show (csharp) in header" ;;
esac
out=$(printf 'public class T {}\n' | "$BIN" --color=always --paging=never --language=java)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=java did not emit ANSI" ;;
esac

# 1.2.2 — Scripting + mobile (vyakarana 1.4.0). PHP / Ruby / Lua /
# Swift. Ruby and Lua also pick up shebang detection.
printf '<?php echo \"hi\";\n' > "$TMPDIR/t.php"
out=$("$BIN" -n "$TMPDIR/t.php")
case "$out" in
    *"(php)"*) ;;
    *) fail "extension detection: .php should show (php) in header" ;;
esac
printf 'puts \"hi\"\n' > "$TMPDIR/t.rb"
out=$("$BIN" -n "$TMPDIR/t.rb")
case "$out" in
    *"(ruby)"*) ;;
    *) fail "extension detection: .rb should show (ruby) in header" ;;
esac
printf 'print(\"hi\")\n' > "$TMPDIR/t.lua"
out=$("$BIN" -n "$TMPDIR/t.lua")
case "$out" in
    *"(lua)"*) ;;
    *) fail "extension detection: .lua should show (lua) in header" ;;
esac
printf 'import Foundation\nprint(\"hi\")\n' > "$TMPDIR/t.swift"
out=$("$BIN" -n "$TMPDIR/t.swift")
case "$out" in
    *"(swift)"*) ;;
    *) fail "extension detection: .swift should show (swift) in header" ;;
esac
# Shebang: ruby.
printf '#!/usr/bin/env ruby\nputs "hi"\n' > "$TMPDIR/rb_script"
out=$("$BIN" -n "$TMPDIR/rb_script")
case "$out" in
    *"(ruby)"*) ;;
    *) fail "shebang detection: ruby not detected in '$out'" ;;
esac
out=$(printf 'puts \"hi\"\n' | "$BIN" --color=always --paging=never --language=ruby)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=ruby did not emit ANSI" ;;
esac

# 1.2.3 — Functional tier (vyakarana 1.5.0). Elixir / OCaml / Haskell.
printf 'defmodule T do\n  def hi, do: :ok\nend\n' > "$TMPDIR/t.ex"
out=$("$BIN" -n "$TMPDIR/t.ex")
case "$out" in
    *"(elixir)"*) ;;
    *) fail "extension detection: .ex should show (elixir) in header" ;;
esac
printf 'let x = 1\n' > "$TMPDIR/t.ml"
out=$("$BIN" -n "$TMPDIR/t.ml")
case "$out" in
    *"(ocaml)"*) ;;
    *) fail "extension detection: .ml should show (ocaml) in header" ;;
esac
printf 'main :: IO ()\nmain = putStrLn \"hi\"\n' > "$TMPDIR/t.hs"
out=$("$BIN" -n "$TMPDIR/t.hs")
case "$out" in
    *"(haskell)"*) ;;
    *) fail "extension detection: .hs should show (haskell) in header" ;;
esac

# 1.2.4 — Data / query / IDL (vyakarana 1.6.0). SQL exercises the
# case-insensitive keyword default (ADR 0011).
printf 'SELECT * FROM users;\n' > "$TMPDIR/t.sql"
out=$("$BIN" -n "$TMPDIR/t.sql")
case "$out" in
    *"(sql)"*) ;;
    *) fail "extension detection: .sql should show (sql) in header" ;;
esac
printf 'type Query { hello: String }\n' > "$TMPDIR/t.graphql"
out=$("$BIN" -n "$TMPDIR/t.graphql")
case "$out" in
    *"(graphql)"*) ;;
    *) fail "extension detection: .graphql should show (graphql) in header" ;;
esac
printf 'syntax = \"proto3\";\nmessage M { string s = 1; }\n' > "$TMPDIR/t.proto"
out=$("$BIN" -n "$TMPDIR/t.proto")
case "$out" in
    *"(protobuf)"*) ;;
    *) fail "extension detection: .proto should show (protobuf) in header" ;;
esac
out=$(printf 'select * from users;\n' | "$BIN" --color=always --paging=never --language=sql)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=sql did not emit ANSI on lower-case keywords" ;;
esac

# 1.2.5 — Markup + styling (vyakarana 1.7.0). HTML / XML / CSS / SCSS.
printf '<html><body>hi</body></html>\n' > "$TMPDIR/t.html"
out=$("$BIN" -n "$TMPDIR/t.html")
case "$out" in
    *"(html)"*) ;;
    *) fail "extension detection: .html should show (html) in header" ;;
esac
printf '<?xml version=\"1.0\"?>\n<root/>\n' > "$TMPDIR/t.xml"
out=$("$BIN" -n "$TMPDIR/t.xml")
case "$out" in
    *"(xml)"*) ;;
    *) fail "extension detection: .xml should show (xml) in header" ;;
esac
printf 'body { color: red; }\n' > "$TMPDIR/t.css"
out=$("$BIN" -n "$TMPDIR/t.css")
case "$out" in
    *"(css)"*) ;;
    *) fail "extension detection: .css should show (css) in header" ;;
esac
printf '$primary: red;\nbody { color: $primary; }\n' > "$TMPDIR/t.scss"
out=$("$BIN" -n "$TMPDIR/t.scss")
case "$out" in
    *"(scss)"*) ;;
    *) fail "extension detection: .scss should show (scss) in header" ;;
esac

# 1.2.6 — DevOps + infrastructure (vyakarana 1.8.0). Dockerfile and
# Makefile have no extension — they dispatch via _path_filename_match.
# INI dispatches via .ini extension.
printf 'FROM alpine\nRUN echo hi\n' > "$TMPDIR/Dockerfile"
out=$("$BIN" -n "$TMPDIR/Dockerfile")
case "$out" in
    *"(dockerfile)"*) ;;
    *) fail "filename detection: Dockerfile should show (dockerfile) in header" ;;
esac
printf 'FROM alpine\n' > "$TMPDIR/myapp.Dockerfile"
out=$("$BIN" -n "$TMPDIR/myapp.Dockerfile")
case "$out" in
    *"(dockerfile)"*) ;;
    *) fail "filename detection: name.Dockerfile should show (dockerfile) in header" ;;
esac
printf 'FROM alpine\n' > "$TMPDIR/Containerfile"
out=$("$BIN" -n "$TMPDIR/Containerfile")
case "$out" in
    *"(dockerfile)"*) ;;
    *) fail "filename detection: Containerfile should show (dockerfile) in header" ;;
esac
printf 'all:\n\techo hi\n' > "$TMPDIR/Makefile"
out=$("$BIN" -n "$TMPDIR/Makefile")
case "$out" in
    *"(makefile)"*) ;;
    *) fail "filename detection: Makefile should show (makefile) in header" ;;
esac
printf 'all:\n\techo hi\n' > "$TMPDIR/makefile"
out=$("$BIN" -n "$TMPDIR/makefile")
case "$out" in
    *"(makefile)"*) ;;
    *) fail "filename detection: lowercase makefile should show (makefile) in header" ;;
esac
printf 'all:\n\techo hi\n' > "$TMPDIR/GNUmakefile"
out=$("$BIN" -n "$TMPDIR/GNUmakefile")
case "$out" in
    *"(makefile)"*) ;;
    *) fail "filename detection: GNUmakefile should show (makefile) in header" ;;
esac
printf '[section]\nkey = value\n' > "$TMPDIR/t.ini"
out=$("$BIN" -n "$TMPDIR/t.ini")
case "$out" in
    *"(ini)"*) ;;
    *) fail "extension detection: .ini should show (ini) in header" ;;
esac
out=$(printf 'FROM alpine\nRUN echo hi\n' | "$BIN" --color=always --paging=never --language=dockerfile)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=dockerfile did not emit ANSI" ;;
esac

# 1.3.0 — AGNOS-native batch (vyakarana 1.9.0). cyml + llvm_ir.
# .cyml redirects from toml → cyml at this cut (vyakarana 1.9.0
# routing change); regression gate locks the new label.
printf '[package]\nname = "x"\n---\nbody\n' > "$TMPDIR/t.cyml"
out=$("$BIN" -n "$TMPDIR/t.cyml")
case "$out" in
    *"(cyml)"*) ;;
    *"(toml)"*) fail "regression: .cyml still labeled (toml) — vyakarana 1.9.0 redirect not applied" ;;
    *)         fail "extension detection: .cyml should show (cyml) in header — got '$out'" ;;
esac
printf 'define i32 @main() {\n  ret i32 0\n}\n' > "$TMPDIR/t.ll"
out=$("$BIN" -n "$TMPDIR/t.ll")
case "$out" in
    *"(llvm_ir)"*) ;;
    *) fail "extension detection: .ll should show (llvm_ir) in header" ;;
esac
out=$(printf '[package]\nname = "x"\n' | "$BIN" --color=always --paging=never --language=cyml)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=cyml did not emit ANSI" ;;
esac
out=$(printf 'define i32 @main() { ret i32 0 }\n' | "$BIN" --color=always --paging=never --language=llvm_ir)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=llvm_ir did not emit ANSI" ;;
esac

# 1.3.2 — PowerShell + Crystal + Julia (vyakarana 2.1.0).
printf 'Get-ChildItem -Path C:\\\n' > "$TMPDIR/t.ps1"
out=$("$BIN" -n "$TMPDIR/t.ps1")
case "$out" in
    *"(powershell)"*) ;;
    *) fail "extension detection: .ps1 should show (powershell) in header" ;;
esac
printf 'def hi : String\n  "ok"\nend\n' > "$TMPDIR/t.cr"
out=$("$BIN" -n "$TMPDIR/t.cr")
case "$out" in
    *"(crystal)"*) ;;
    *) fail "extension detection: .cr should show (crystal) in header" ;;
esac
printf 'function hi()\n  println("ok")\nend\n' > "$TMPDIR/t.jl"
out=$("$BIN" -n "$TMPDIR/t.jl")
case "$out" in
    *"(julia)"*) ;;
    *) fail "extension detection: .jl should show (julia) in header" ;;
esac
# PowerShell shebang detection: #!/usr/bin/env pwsh
printf '#!/usr/bin/env pwsh\nGet-Date\n' > "$TMPDIR/ps_script"
out=$("$BIN" -n "$TMPDIR/ps_script")
case "$out" in
    *"(powershell)"*) ;;
    *) fail "shebang detection: powershell not detected in '$out'" ;;
esac
# ANSI emission probe — Julia macro `@show` exercises the `@`-in-ident_start trick.
out=$(printf 'function hi()\n  @show 1+1\nend\n' | "$BIN" --color=always --paging=never --language=julia)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=julia did not emit ANSI" ;;
esac

# 1.3.3 — Vue + Svelte SFC (vyakarana 2.1.1). Both are HTML-shaped
# outer tokenizers with framework-specific shorthand prefixes; the
# compose rules route <script> → JS and <style> → CSS bodies.
printf '<template>\n  <h1>{{ title }}</h1>\n</template>\n<script>\nexport default { data: () => ({ title: "hi" }) }\n</script>\n' > "$TMPDIR/t.vue"
out=$("$BIN" -n "$TMPDIR/t.vue")
case "$out" in
    *"(vue)"*) ;;
    *) fail "extension detection: .vue should show (vue) in header" ;;
esac
printf '<script>\n  let count = 0;\n</script>\n<button on:click={() => count++}>{count}</button>\n' > "$TMPDIR/t.svelte"
out=$("$BIN" -n "$TMPDIR/t.svelte")
case "$out" in
    *"(svelte)"*) ;;
    *) fail "extension detection: .svelte should show (svelte) in header" ;;
esac
# ANSI emission probe — Vue's @click shorthand exercises the `@` operator path.
out=$(printf '<button @click="hi">x</button>\n' | "$BIN" --color=always --paging=never --language=vue)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=vue did not emit ANSI" ;;
esac

# 1.3.4 — Nix (vyakarana 2.1.2). `.nix` ext dispatch + ANSI probe;
# `let` keyword + kebab-case ident + `//` set-merge op exercise the
# Nix-specific quirks (`-` in ident_cont, `//` longest-match before
# anything else).
printf 'let pkgs = import <nixpkgs> { }; in pkgs.hello\n' > "$TMPDIR/t.nix"
out=$("$BIN" -n "$TMPDIR/t.nix")
case "$out" in
    *"(nix)"*) ;;
    *) fail "extension detection: .nix should show (nix) in header" ;;
esac
out=$(printf 'let home-manager = a // b; in home-manager\n' | "$BIN" --color=always --paging=never --language=nix)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=nix did not emit ANSI" ;;
esac

# 1.3.5 — Terraform / HCL (vyakarana 2.1.3). All three exts route
# to the same upstream-named `terraform` grammar. Probes hit the
# kebab-case ident path (`-` in ident_cont, `aws_s3_bucket`-style)
# and the `=>` for-expression op (longest-match before `=`).
printf 'resource "aws_s3_bucket" "example" {\n  bucket = "my-bucket"\n}\n' > "$TMPDIR/t.tf"
out=$("$BIN" -n "$TMPDIR/t.tf")
case "$out" in
    *"(terraform)"*) ;;
    *) fail "extension detection: .tf should show (terraform) in header" ;;
esac
printf 'region = "us-east-1"\nbucket_count = 3\n' > "$TMPDIR/t.tfvars"
out=$("$BIN" -n "$TMPDIR/t.tfvars")
case "$out" in
    *"(terraform)"*) ;;
    *) fail "extension detection: .tfvars should show (terraform) in header" ;;
esac
printf 'variable "name" {\n  default = "x"\n}\n' > "$TMPDIR/t.hcl"
out=$("$BIN" -n "$TMPDIR/t.hcl")
case "$out" in
    *"(terraform)"*) ;;
    *) fail "extension detection: .hcl should show (terraform) in header" ;;
esac
out=$(printf '{ for k, v in vars : k => upper(v) }\n' | "$BIN" --color=always --paging=never --language=terraform)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=terraform did not emit ANSI" ;;
esac

# 1.4.5 — OpenQASM (vyakarana 2.3.5, wired at owl 1.4.5). `.qasm`
# ext dispatch + ANSI probe. The probe deliberately uses `measure
# q -> c`: `->` must win longest-match over `-`, and `measure` /
# `qreg` must colour as keywords while the stdlib gate names (`h`,
# `cx`) stay idents — they come from qelib1.inc and are
# user-redefinable, so `keyword` would be wrong (upstream ADR 0004,
# same call as shell builtins).
printf 'OPENQASM 2.0;\ninclude "qelib1.inc";\nqreg q[2];\ncreg c[2];\nh q[0];\ncx q[0], q[1];\nmeasure q -> c;\n' > "$TMPDIR/t.qasm"
out=$("$BIN" -n "$TMPDIR/t.qasm")
case "$out" in
    *"(openqasm)"*) ;;
    *) fail "extension detection: .qasm should show (openqasm) in header" ;;
esac
out=$(printf 'measure q -> c;\n' | "$BIN" --color=always --paging=never --language=openqasm)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=openqasm did not emit ANSI" ;;
esac
# Plain mode stays byte-identical for the new grammar too.
out=$("$BIN" -p "$TMPDIR/t.qasm" | cmp -s - "$TMPDIR/t.qasm" && echo same || echo differ)
[ "$out" = "same" ] || fail "plain mode must be byte-identical to cat for .qasm"

# 1.5.1 — NASM, MDX and Lean (vyakarana 2.9.9, wired at owl 1.5.1).
# Each: extension dispatch in the header, an ANSI probe through
# stdin + --language, and plain mode byte-identical to cat.
printf 'section .text\nglobal _start\n%%define N 1\n_start: mov rax, 60 ; exit\n' > "$TMPDIR/t.nasm"
printf 'import {X} from "./x.js"\n\n# Title\n\n<X n={1} />\n' > "$TMPDIR/t.mdx"
printf -- '-- comment\ntheorem t : 1 + 1 = 2 := by rfl\n#eval 2.5\n' > "$TMPDIR/t.lean"
for pair in nasm:nasm mdx:mdx lean:lean; do
    ext=${pair%%:*}; lang=${pair#*:}
    out=$("$BIN" -n "$TMPDIR/t.$ext")
    case "$out" in
        *"($lang)"*) ;;
        *) fail "extension detection: .$ext should show ($lang) in header" ;;
    esac
    out=$("$BIN" --color=always --paging=never --language="$lang" < "$TMPDIR/t.$ext")
    case "$out" in
        *$(printf '\033')*) ;;
        *) fail "stdin + --color=always + --language=$lang did not emit ANSI" ;;
    esac
    out=$("$BIN" -p "$TMPDIR/t.$ext" | cmp -s - "$TMPDIR/t.$ext" && echo same || echo differ)
    [ "$out" = "same" ] || fail "plain mode must be byte-identical to cat for .$ext"
done
# `.asm` is decided by content since 1.6.0 (vyakarana's vote, reached through
# detect_language_combined in src/lang.cyr). Through 1.5.3 owl routed on the
# extension alone and pinned `.asm` to asm_x86_64, because vyakarana's table
# says nasm and only its content vote sends GNU-as files back. Now owl has the
# vote: NASM directives or a bare instruction stream → nasm, a GNU-as
# directive (`.intel_syntax`, `.text`, `.globl`) → asm_x86_64.
printf 'mov rax, 60\n' > "$TMPDIR/t.asm"
printf '.intel_syntax noprefix\n.text\nmov rax, 60\n' > "$TMPDIR/g.asm"
printf 'section .text\nglobal _start\n%%define N 1\n' > "$TMPDIR/n.asm"
for pair in t:nasm g:asm_x86_64 n:nasm; do
    f=${pair%%:*}; lang=${pair#*:}
    out=$("$BIN" -n "$TMPDIR/$f.asm")
    case "$out" in
        *"($lang)"*) ;;
        *) fail "content vote: $f.asm should show ($lang) in header" ;;
    esac
done

# 1.5.2 — markdown routes by extension. Through 1.5.1 it had no
# language-table row: `.md` reached the grammar only when the file's
# first line was a `# ` heading (the content sniff), and
# `--language=markdown` exited 2. The probe deliberately opens with
# prose, so the content sniff cannot be what passes it.
printf 'Intro text, no heading.\n\n- item `code`\n\n## Later\n' > "$TMPDIR/notes.md"
cp "$TMPDIR/notes.md" "$TMPDIR/notes.markdown"
for f in notes.md notes.markdown; do
    out=$("$BIN" -n "$TMPDIR/$f")
    case "$out" in
        *"(markdown)"*) ;;
        *) fail "extension detection: $f should show (markdown) in header" ;;
    esac
    out=$("$BIN" -p "$TMPDIR/$f" | cmp -s - "$TMPDIR/$f" && echo same || echo differ)
    [ "$out" = "same" ] || fail "plain mode must be byte-identical to cat for $f"
done
out=$(printf -- '- item `code`\n' | "$BIN" --color=always --paging=never --language=markdown) \
    || fail "--language=markdown exited non-zero"
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=markdown did not emit ANSI" ;;
esac
# `.md` must not shadow `.mdx` (suffix match, but check it).
out=$("$BIN" -n "$TMPDIR/t.mdx")
case "$out" in
    *"(mdx)"*) ;;
    *) fail "extension detection: .mdx must stay (mdx) now that .md is listed" ;;
esac

# 1.3.6 — HIGHLIGHT_MAX lift. Pre-1.3.6 the cap was 128 KB total
# input; files past that fell back to plain rendering with a
# stderr "too large for highlighting (> 128 KB)" notice. 1.3.6
# bumps the cap to 16 MB and feeds vyakarana per-chunk during the
# read loop so the rolling-buffer scanner caps live in-progress
# span (not total input). A 256 KB file — well past the old cap,
# well under the new one — must highlight cleanly with no
# fallback notice.
{
    awk 'BEGIN { for (i = 0; i < 8000; i++) print "def f_" i "(x): return x + 1" }' > "$TMPDIR/big.py"
}
[ "$(wc -c < "$TMPDIR/big.py")" -gt 131072 ] || fail "1.3.6 fixture not larger than old 128 KB cap"
[ "$(wc -c < "$TMPDIR/big.py")" -lt 16777216 ] || fail "1.3.6 fixture exceeds new 16 MB cap"
out=$("$BIN" --color=always --paging=never "$TMPDIR/big.py" 2>"$TMPDIR/big.err")
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "1.3.6 lift: 256 KB Python file did not emit ANSI under --color=always" ;;
esac
grep -q "too large for highlighting" "$TMPDIR/big.err" \
    && fail "1.3.6 lift: 256 KB file should not trigger 'too large for highlighting' fallback"
# Belt-and-suspenders: piped stdin path must also handle the same
# size cleanly (the lift wires both render_path and the stdin
# slurp).
out=$("$BIN" --color=always --paging=never --language=python < "$TMPDIR/big.py" 2>"$TMPDIR/big.err")
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "1.3.6 lift: stdin > 128 KB did not emit ANSI" ;;
esac
grep -q "too large for highlighting" "$TMPDIR/big.err" \
    && fail "1.3.6 lift: stdin > 128 KB triggered the fallback notice"

# Shebang detection: python shebang.
printf '#!/usr/bin/env python3\nprint("hi")\n' > "$TMPDIR/shebang"
out=$("$BIN" -n "$TMPDIR/shebang")
case "$out" in
    *"(python)"*) ;;
    *) fail "shebang detection: python not detected in '$out'" ;;
esac

# Shebang detection: bash shebang.
printf '#!/bin/bash\necho hi\n' > "$TMPDIR/script"
out=$("$BIN" -n "$TMPDIR/script")
case "$out" in
    *"(shell)"*) ;;
    *) fail "shebang detection: shell not detected" ;;
esac

# --language overrides detection.
out=$("$BIN" -n --language=rust "$TMPDIR/t.rs")
case "$out" in
    *"(rust)"*) ;;
    *) fail "--language=rust override should leave (rust) in header" ;;
esac

# Stdin input has no language label in header.
out=$(echo "hi" | "$BIN" -n -)
case "$out" in
    *"("*) fail "stdin header should not carry a language label: '$out'" ;;
    *) ;;
esac

# --color=always emits ANSI escape even when piped (-n to force header).
out=$("$BIN" --color=always -n "$TMPDIR/a.txt")
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "--color=always did not emit ANSI escape when piped" ;;
esac

# stdin + --language + --color=always highlights tokens. Symmetric with
# the file path: piped consumers (Claude Code's Read routing, scripted
# log capture, `script(1)` recording) need color from the stdin path too.
out=$(printf 'fn x() {}\n' | "$BIN" --color=always --paging=never --language=rust)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "stdin + --color=always + --language=rust did not emit ANSI" ;;
esac

# Stdin without --language stays plain (no extension/path to detect from).
out=$(printf 'fn x() {}\n' | "$BIN" --color=always --paging=never)
case "$out" in
    *$(printf '\033')*) fail "stdin without --language should not colorize" ;;
    *) ;;
esac

# ---------------------------------------------------------------------
# 1.1.3 — user grammar overlay via $XDG_CONFIG_HOME/owl/grammars/.
# Override-only scope: the user dir is consulted before bundled, so a
# user file with a known name (e.g. python.cyml) wins. Missing dir is
# a silent no-op. We test by copying the bundled python grammar to a
# user dir and confirming owl still highlights .py — exercises the
# load path, even though identity output isn't a strict override
# proof on its own. Crash-free + correct ANSI is the contract here.
# Locate the grammars dir relative to the smoke script itself, not the
# cwd: CI invokes `bash scripts/smoke.sh build/owl` from the repo root,
# but the script must work regardless. The script lives in scripts/,
# so grammars/ is one level up.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GRAMMARS_SRC="$REPO_ROOT/grammars"
mkdir -p "$TMPDIR/userhome/owl/grammars"
cp "$GRAMMARS_SRC/python.cyml" "$TMPDIR/userhome/owl/grammars/python.cyml"
printf 'def hi(): pass\n' > "$TMPDIR/sample.py"
out=$(XDG_CONFIG_HOME="$TMPDIR/userhome" "$BIN" --color=always --paging=never "$TMPDIR/sample.py")
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "user grammar overlay broke .py highlighting" ;;
esac
# Missing user dir is a silent no-op — no error, no warning.
out=$(XDG_CONFIG_HOME="$TMPDIR/nonexistent" "$BIN" --color=always --paging=never "$TMPDIR/sample.py" 2>"$TMPDIR/err")
[ ! -s "$TMPDIR/err" ] || fail "missing user grammars dir leaked stderr: $(cat "$TMPDIR/err")"
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "missing user grammars dir broke .py highlighting fallback" ;;
esac

# 1.6.0 — grammars and routes come from vyakarana. The 49 bundled grammars
# are compiled into the vyakarana bundle (no grammars/ directory at
# runtime), and routing is vyakarana's detect_language_combined plus, for a
# user grammar with a new name, detect_language_registered (src/lang.cyr).
#
# (a) The binary alone highlights: no grammars/ beside it, none in the cwd,
# no user overlay. Through 1.5.3 this printed uncoloured text.
mkdir -p "$TMPDIR/r160/bin" "$TMPDIR/r160/cwd"
cp "$BIN_ABS" "$TMPDIR/r160/bin/owl"
printf 'fn main() { return 0; }\n' > "$TMPDIR/r160/cwd/x.rs"
out=$(cd "$TMPDIR/r160/cwd" && env -i PATH="$PATH" HOME="$TMPDIR/r160/nohome" \
    "$TMPDIR/r160/bin/owl" --color=always --paging=never x.rs)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "1.6.0: owl with no grammars/ beside it or in the cwd did not highlight" ;;
esac
# (b) --list-languages is exactly the bundled set: the repo's grammars/ copy
# (re-synced from vyakarana) plus "plain", sorted. Drift between the copy and
# the pinned vyakarana's embedded blobs fails here.
want=$( { echo plain; for f in "$GRAMMARS_SRC"/*.cyml; do basename "$f" .cyml; done | LC_ALL=C sort; } )
got=$(env -i PATH="$PATH" HOME="$TMPDIR/r160/nohome" "$BIN" --list-languages)
[ "$got" = "$want" ] || fail "1.6.0: --list-languages is not grammars/*.cyml + plain"
# (c) Every bundled grammar is reachable: each one's first declared extension
# (or first declared filename) routes to it. `.asm` is nasm's and gets the
# content vote, so an empty file stays nasm; asm_aarch64 shares `.s` with
# asm_x86_64 (an empty `.s` votes x86-64) and is reached by content below.
for f in "$GRAMMARS_SRC"/*.cyml; do
    g=$(basename "$f" .cyml)
    [ "$g" != asm_aarch64 ] || continue
    first=$(sed -n 's/^extensions *= *\["\([^"]*\)".*/\1/p' "$f" | head -n 1)
    name="x$first"
    if [ -z "$first" ]; then
        first=$(sed -n 's/^filenames *= *\["\([^"]*\)".*/\1/p' "$f" | head -n 1)
        name="$first"
    fi
    [ -n "$first" ] || continue
    : > "$TMPDIR/r160/cwd/$name"
    out=$(env -i PATH="$PATH" HOME="$TMPDIR/r160/nohome" "$BIN" -n "$TMPDIR/r160/cwd/$name")
    case "$out" in
        *"($g)"*) ;;
        *) fail "1.6.0: $name should route to ($g)" ;;
    esac
    rm -f "$TMPDIR/r160/cwd/$name"
done
printf 'stp x29, x30, [sp, #-16]!\nldr x0, [x1]\nret\n' > "$TMPDIR/r160/cwd/a.s"
out=$(env -i PATH="$PATH" HOME="$TMPDIR/r160/nohome" "$BIN" -n "$TMPDIR/r160/cwd/a.s")
case "$out" in
    *"(asm_aarch64)"*) ;;
    *) fail "1.6.0: an AArch64 .s file should route to (asm_aarch64) by content" ;;
esac
# (d) A user grammar with a NEW name routes by what it declares — extension,
# filename, shebang — is listed, and is selectable. It may claim an extension
# a bundled grammar routes (`.conf` from ini): installing it is the user's
# choice. Through 1.5.3 a new name was unreachable.
og="$TMPDIR/r160/xdg/owl/grammars"
mkdir -p "$og"
cat > "$og/owlgate.cyml" <<'EOF'
[grammar]
name = "owlgate"
extensions = [".owlgate", ".conf"]
filenames = ["Owlgatefile"]
shebangs = ["owlgate-run"]

[defaults]
shebang = true
whitespace = true
ident_start = "A-Za-z_"
ident_cont  = "A-Za-z0-9_"

[[rules]]
kind = "comment"
match = "line"
start = "#"
EOF
printf '# hi\n' > "$TMPDIR/r160/cwd/x.owlgate"
printf '# hi\n' > "$TMPDIR/r160/cwd/x.conf"
printf '# hi\n' > "$TMPDIR/r160/cwd/Owlgatefile"
printf '#!/usr/bin/env owlgate-run\n# hi\n' > "$TMPDIR/r160/cwd/script"
for f in x.owlgate x.conf Owlgatefile script; do
    out=$(env -i PATH="$PATH" HOME="$TMPDIR/r160/nohome" XDG_CONFIG_HOME="$TMPDIR/r160/xdg" \
        "$BIN" -n "$TMPDIR/r160/cwd/$f")
    case "$out" in
        *"(owlgate)"*) ;;
        *) fail "1.6.0: $f should route to the user grammar (owlgate)" ;;
    esac
done
out=$(env -i PATH="$PATH" HOME="$TMPDIR/r160/nohome" "$BIN" -n "$TMPDIR/r160/cwd/x.conf")
case "$out" in
    *"(ini)"*) ;;
    *) fail "1.6.0: without the overlay, x.conf should route to (ini)" ;;
esac
env -i PATH="$PATH" HOME="$TMPDIR/r160/nohome" XDG_CONFIG_HOME="$TMPDIR/r160/xdg" \
    "$BIN" --list-languages | grep -qx owlgate || fail "1.6.0: --list-languages missing the user grammar"
out=$(printf '# hi\n' | env -i PATH="$PATH" HOME="$TMPDIR/r160/nohome" XDG_CONFIG_HOME="$TMPDIR/r160/xdg" \
    "$BIN" --color=always --paging=never --language=owlgate)
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "1.6.0: --language=owlgate (a user grammar) did not colour" ;;
esac
# (e) A user grammar that REPLACES a bundled one changes how it highlights,
# not what routes to it: with nasm.cyml in the overlay, a GNU-as `.asm` file
# still gets the content vote.
cp "$GRAMMARS_SRC/nasm.cyml" "$og/nasm.cyml"
printf '.intel_syntax noprefix\n.text\nmov rax, 60\n' > "$TMPDIR/r160/cwd/g.asm"
out=$(env -i PATH="$PATH" HOME="$TMPDIR/r160/nohome" XDG_CONFIG_HOME="$TMPDIR/r160/xdg" \
    "$BIN" -n "$TMPDIR/r160/cwd/g.asm")
case "$out" in
    *"(asm_x86_64)"*) ;;
    *) fail "1.6.0: a replaced nasm grammar took .asm routing from the content vote" ;;
esac
# (f) Overlay hygiene: a FIFO, a directory, an unparseable file, a nameless
# grammar and one named "plain", all named *.cyml, are skipped — owl neither blocks (the overlay is stat'ed, never
# opened, unless it is a regular file) nor drops the good grammar.
if command -v timeout > /dev/null 2>&1 && mkfifo "$og/zz-fifo.cyml" 2>/dev/null; then
    mkdir -p "$og/dir.cyml"
    printf 'this is not a grammar\n' > "$og/bad.cyml"
    # Parses, but declares no name: through the 1.6.0 dev cycle a nameless
    # entry crashed owl's name scans (SIGSEGV); "plain" is owl's to reserve.
    printf '[grammar]\nextensions = [".owlgate"]\n' > "$og/noname.cyml"
    printf '[grammar]\nname = "plain"\nextensions = [".owlgate"]\n' > "$og/plain.cyml"
    set +e
    out=$(env -i PATH="$PATH" HOME="$TMPDIR/r160/nohome" XDG_CONFIG_HOME="$TMPDIR/r160/xdg" \
        timeout 5 "$BIN" -n "$TMPDIR/r160/cwd/x.owlgate")
    rc=$?
    set -e
    [ "$rc" -eq 0 ] || fail "1.6.0: a FIFO / directory / bad grammar in the overlay made owl exit $rc (124 = blocked)"
    case "$out" in
        *"(owlgate)"*) ;;
        *) fail "1.6.0: junk in the overlay dropped the good user grammar" ;;
    esac
else
    echo "smoke: NOTE — timeout or mkfifo unavailable; skipping the overlay FIFO gate" >&2
fi
# (g) owl's supplement: routes owl 1.5.3 had that vyakarana 2.10.0 does not
# (docs/development/issues/2026-10-31-vyakarana-missing-routes.md).
for pair in t.tcyr:cyrius b.bcyr:cyrius f.FCYR:cyrius; do
    f=${pair%%:*}; lang=${pair#*:}
    printf '# a comment\nvar x = 1;\n' > "$TMPDIR/r160/cwd/$f"
    out=$(env -i PATH="$PATH" HOME="$TMPDIR/r160/nohome" "$BIN" -n "$TMPDIR/r160/cwd/$f")
    case "$out" in
        *"($lang)"*) ;;
        *) fail "1.6.0 supplement: $f should route to ($lang)" ;;
    esac
done
for pair in "env deno:javascript" "env -S deno run:javascript" "rust-script:rust" \
            "swift:swift" "env elixir:elixir" "ocaml:ocaml" "ocamlrun:ocaml"; do
    interp=${pair%%:*}; lang=${pair#*:}
    printf '#!/usr/bin/%s\nx\n' "$interp" > "$TMPDIR/r160/cwd/s"
    out=$(env -i PATH="$PATH" HOME="$TMPDIR/r160/nohome" "$BIN" -n "$TMPDIR/r160/cwd/s")
    case "$out" in
        *"($lang)"*) ;;
        *) fail "1.6.0 supplement: #!/usr/bin/$interp should route to ($lang)" ;;
    esac
done
# (h) INFO-013: a dotfile is never sniffed as markdown — `# ` opens a shell
# or git comment there, not a heading. Through 1.5.3 `.gitignore` and
# `.bashrc` starting `# …` rendered as markdown. A non-dotfile still is.
for f in .bashrc .gitignore .env.example; do
    printf '# a comment\nX=1\n' > "$TMPDIR/r160/cwd/$f"
    out=$(env -i PATH="$PATH" HOME="$TMPDIR/r160/nohome" "$BIN" -n "$TMPDIR/r160/cwd/$f")
    case "$out" in
        *"(markdown)"*) fail "INFO-013: $f was sniffed as markdown" ;;
    esac
done
printf '# Title\n\ntext\n' > "$TMPDIR/r160/cwd/NOTES"
out=$(env -i PATH="$PATH" HOME="$TMPDIR/r160/nohome" "$BIN" -n "$TMPDIR/r160/cwd/NOTES")
case "$out" in
    *"(markdown)"*) ;;
    *) fail "1.6.0: an extensionless file opening '# Title' should still sniff as (markdown)" ;;
esac

# 1.1.3 — user theme overlay via $XDG_CONFIG_HOME/owl/themes/<name>.cyml.
# Single-slot lazy-load on theme_index miss. Verify a user-supplied
# "test_theme.cyml" actually overrides bundled token colors by picking
# a header_color value that NO bundled theme uses (37) and asserting
# it appears in the file header SGR escape.
mkdir -p "$TMPDIR/userhome/owl/themes"
cat > "$TMPDIR/userhome/owl/themes/test_theme.cyml" <<'EOF'
header_color = 37
lineno_color = 240
token.keyword = 207
token.string = 154
token.number = 220
token.comment = 247
EOF
printf 'fn x() {}\n' > "$TMPDIR/sample.rs"
out=$(XDG_CONFIG_HOME="$TMPDIR/userhome" "$BIN" -n --color=always --paging=never --theme=test_theme "$TMPDIR/sample.rs")
case "$out" in
    *"[38;5;37m"*) ;;
    *) fail "user theme test_theme did not apply header_color=37" ;;
esac
case "$out" in
    *"[38;5;207m"*) ;;
    *) fail "user theme test_theme did not apply token.keyword=207" ;;
esac
# Theme name not found → exit 2 (same as bogus bundled theme).
set +e
"$BIN" --theme=zzz_definitely_missing "$TMPDIR/sample.rs" > /dev/null 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" = "2" ] || fail "missing theme exit: got $rc, expected 2"

# 1.1.2 REGRESSION LOCK — bundled grammars cwd-portability
# ---------------------------------------------------------------------
# Was a KNOWN-FAILURE in 1.1.1; fixed in 1.1.2 by resolving grammars
# via /proc/self/exe. Now a hard fail() — if owl ever loses the
# exe-relative lookup, this trips immediately.
#
# CRITICAL: must `cd` out of the owl repo first. The initial version
# of this gate (without the cd) reported PASS while the user-
# reproducible bug still existed, because the cwd-relative grammar
# lookup accidentally succeeded inside the owl source tree.
printf 'fn greet() { return "hi"; }\nvar count = 42;\n' > "$TMPDIR/sample.cyr"
ABS_BIN="$(realpath "$BIN")"
out=$(cd "$TMPDIR" && "$ABS_BIN" --color=always --paging=never "$TMPDIR/sample.cyr")
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "1.1.2 regression: owl from non-owl cwd ($TMPDIR) emits no ANSI for .cyr file — grammar lookup not exe-relative" ;;
esac
# Same scenario with explicit --language=cyrius — exercises the
# render path that doesn't rely on extension detection.
out=$(cd "$TMPDIR" && "$ABS_BIN" --color=always --paging=never --language=cyrius "$TMPDIR/sample.cyr")
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "1.1.2 regression: owl from non-owl cwd with --language=cyrius emits no ANSI" ;;
esac

# --color=always + --theme=light produces different bytes than --theme=dark
# (palette values differ, so the escape-code digits are different).
dark_out=$("$BIN"  --color=always --theme=dark  -n "$TMPDIR/a.txt")
light_out=$("$BIN" --color=always --theme=light -n "$TMPDIR/a.txt")
[ "$dark_out" != "$light_out" ] || fail "dark and light themes produced identical output"

# NO_COLOR strips ANSI (overrides auto / default) but leaves numbers on with -n.
out=$(NO_COLOR=1 "$BIN" -n "$TMPDIR/a.txt")
case "$out" in
    *$(printf '\033')*) fail "NO_COLOR=1 failed to strip ANSI" ;;
    *) ;;
esac
case "$out" in
    *"line one"*) ;;
    *) fail "NO_COLOR=1 corrupted content" ;;
esac

# --color=always overrides NO_COLOR (flags > env).
out=$(NO_COLOR=1 "$BIN" --color=always -n "$TMPDIR/a.txt")
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "--color=always should override NO_COLOR" ;;
esac

# ============================================================
# M4 — paging
# ============================================================

# Pager must NOT fire when stdout is not a TTY, even with
# --paging=always. Uses a side-effecting OWL_PAGER so we can detect
# spawning via a marker file rather than output content.
rm -f "$TMPDIR/pager_marker"
OWL_PAGER="sh -c 'touch \"$TMPDIR/pager_marker\"; cat'" \
    "$BIN" --paging=always "$TMPDIR/a.txt" > /dev/null 2>&1
[ ! -f "$TMPDIR/pager_marker" ] \
    || fail "pager invoked on non-TTY stdout despite --paging=always"

# Paging gates to TTY; when we can simulate one via script(1), also
# verify the positive path and --paging=never respecting the flag.
if command -v script > /dev/null 2>&1; then
    # util-linux: script -qc 'CMD' /dev/null.  BSD macOS flips the arg order.
    # Detect util-linux by probing the accepted invocation.
    if script -qc 'true' /dev/null > /dev/null 2>&1; then
        rm -f "$TMPDIR/pager_marker"
        OWL_PAGER="sh -c 'touch \"$TMPDIR/pager_marker\"; cat'" \
            script -qc "'$BIN' --paging=always '$TMPDIR/a.txt'" /dev/null \
                < /dev/null > /dev/null 2>&1 || true
        [ -f "$TMPDIR/pager_marker" ] \
            || fail "pager not invoked on TTY with --paging=always"

        rm -f "$TMPDIR/pager_marker"
        OWL_PAGER="sh -c 'touch \"$TMPDIR/pager_marker\"; cat'" \
            script -qc "'$BIN' --paging=never '$TMPDIR/a.txt'" /dev/null \
                < /dev/null > /dev/null 2>&1 || true
        [ ! -f "$TMPDIR/pager_marker" ] \
            || fail "pager invoked despite --paging=never"

        # Spawned pager must inherit parent env (TERM, HOME, LESS, ...).
        # Regression guard for the bug where only PATH was forwarded:
        # less could not init terminfo, printed
        #   'unknown': I need something more specific.
        # to stderr and exited, leaving owl writing into a dead pipe
        # (SIGPIPE -> exit 141).
        rm -f "$TMPDIR/pager_term"
        TERM=xterm-256color \
        OWL_PAGER="sh -c 'printf %s \"\$TERM\" > \"$TMPDIR/pager_term\"; cat'" \
            script -qc "'$BIN' --paging=always '$TMPDIR/a.txt'" /dev/null \
                < /dev/null > /dev/null 2>&1 || true
        captured=$(cat "$TMPDIR/pager_term" 2>/dev/null || true)
        [ "$captured" = "xterm-256color" ] \
            || fail "pager did not inherit TERM (got: '$captured')"
    fi
fi

# ============================================================
# M5 — non-printables + whitespace
# ============================================================

# Fixture with tab, CR, DEL-class control chars.
printf 'a\tb\n'              > "$TMPDIR/tab.txt"
printf 'line\r\nnext\n'      > "$TMPDIR/cr.txt"
printf 'x\x01\x02y\n'        > "$TMPDIR/ctrl.txt"

# -A shows → for tab and $ before \n.
out=$("$BIN" -A "$TMPDIR/tab.txt")
case "$out" in
    *"→"*"b"*) ;;
    *) fail "-A did not render → for tab" ;;
esac
case "$out" in
    *"b\$") ;;
    *) fail "-A did not append \$ before \\n" ;;
esac

# -A shows ␍ for CR.
out=$("$BIN" -A "$TMPDIR/cr.txt")
case "$out" in
    *"␍"*) ;;
    *) fail "-A did not render ␍ for CR" ;;
esac

# -A shows ^A / ^B for control chars.
out=$("$BIN" -A "$TMPDIR/ctrl.txt")
case "$out" in
    *"^A"*"^B"*) ;;
    *) fail "-A did not render ^X notation" ;;
esac

# Default tab expansion (4 spaces).
out=$("$BIN" "$TMPDIR/tab.txt")
[ "$out" = "a    b" ] || fail "default tab expansion: got '$out', expected 'a    b'"

# --tabs=2.
out=$("$BIN" --tabs=2 "$TMPDIR/tab.txt")
[ "$out" = "a  b" ] || fail "--tabs=2: got '$out', expected 'a  b'"

# --tabs=0 preserves literal \t.
diff "$TMPDIR/tab.txt" <("$BIN" --tabs=0 "$TMPDIR/tab.txt") > /dev/null \
    || fail "--tabs=0 did not preserve literal \\t"

# --tabs=foo → exit 2.
set +e
"$BIN" --tabs=foo "$TMPDIR/tab.txt" > /dev/null 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" = "2" ] || fail "--tabs=foo exit: got $rc, expected 2"

# --wrap=<value> validates.
"$BIN" --wrap=auto      "$TMPDIR/a.txt" > /dev/null 2>&1 || fail "--wrap=auto rejected"
"$BIN" --wrap=never     "$TMPDIR/a.txt" > /dev/null 2>&1 || fail "--wrap=never rejected"
"$BIN" --wrap=character "$TMPDIR/a.txt" > /dev/null 2>&1 || fail "--wrap=character rejected"
set +e
"$BIN" --wrap=bogus "$TMPDIR/a.txt" > /dev/null 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" = "2" ] || fail "--wrap=bogus exit: got $rc, expected 2"

# -p overrides all transforms — byte-identical to cat for tab file.
diff "$TMPDIR/tab.txt" <("$BIN" -p "$TMPDIR/tab.txt") > /dev/null \
    || fail "-p did not pass tabs through literally (cat-parity violation)"
# -p wins over -A + -n.
diff "$TMPDIR/tab.txt" <("$BIN" -p -A -n "$TMPDIR/tab.txt") > /dev/null \
    || fail "-p did not override -A / -n"

# ============================================================
# M6 — VCS change markers (sit library backend, owl 1.4.0)
# ============================================================

# --style=bogus is a usage error.
set +e
"$BIN" --style=bogus "$TMPDIR/a.txt" > /dev/null 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" = "2" ] || fail "--style=bogus exit: got $rc, expected 2"

# --style=no-changes outside a repo: renders cleanly, no error.
"$BIN" -n --color=always --style=no-changes "$TMPDIR/a.txt" > /dev/null \
    || fail "--style=no-changes on a plain file should render cleanly"

# Outside any sit repo: no hang, no stderr leak (silent no-op, same as the
# old git-not-a-repo behaviour).
"$BIN" -n --color=always "$TMPDIR/a.txt" > /dev/null 2>"$TMPDIR/err" \
    || fail "non-repo file rendered non-zero under -n --color=always"
[ ! -s "$TMPDIR/err" ] || fail "non-repo file leaked stderr: $(cat "$TMPDIR/err")"

# Inside a real sit repo with a dirty file, markers come from sit's
# sit_diff_path library call: MOD (~) on the in-place-changed line and
# ADD (+) on the appended line. owl resolves the repo from CWD, so we cd in.
if [ -n "$SIT_BIN" ]; then
    make_sit_fixture "$TMPDIR/sitrepo" \
        || fail "could not build sit fixture (sit init/add/commit failed)"
    sit_out=$( cd "$TMPDIR/sitrepo" && "$BIN_ABS" -n --color=never --style=changes --paging=never tracked.txt 2>/dev/null )
    case "$sit_out" in
        *"+"*) ;;
        *) fail "expected ADD marker (+) on appended line in dirty sit repo" ;;
    esac
    case "$sit_out" in
        *"~"*) ;;
        *) fail "expected MOD marker (~) on changed line in dirty sit repo" ;;
    esac
else
    echo "smoke: NOTE — sit binary not found (set OWL_SIT_BIN); skipping VCS marker + --diff gates" >&2
fi

# 1.5.1 — git read mode, executable file. Through 1.5.0 (sit 1.7.0) a
# one-line edit to a mode-100755 file in a `.git/` repo marked EVERY
# line as added; a mode-100644 file was right. sit 1.12.0 reads git
# tree modes as git wrote them. Needs the git CLI for the fixture
# (isolated from the user's config, so signing or hooks can't break
# it); NOTE-skips without one, like the sit gates above.
if command -v git >/dev/null 2>&1; then
    grepo="$TMPDIR/gitexec"
    mkdir -p "$grepo"
    (
        cd "$grepo" || exit 1
        export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
        git init -q . || exit 1
        i=0; : > x.sh
        while [ $i -lt 20 ]; do echo "echo $i" >> x.sh; i=$((i + 1)); done
        chmod +x x.sh
        git add x.sh || exit 1
        git -c user.name=owl -c user.email=owl@smoke commit -qm base || exit 1
        # Rewrite through the existing inode so the mode stays 100755.
        i=0; : > x.sh
        while [ $i -lt 20 ]; do
            if [ $i -eq 10 ]; then echo "echo TEN" >> x.sh; else echo "echo $i" >> x.sh; fi
            i=$((i + 1))
        done
    ) || fail "could not build git fixture (git init/add/commit failed)"
    gout=$( cd "$grepo" && "$BIN_ABS" -n --color=never --style=changes --paging=never x.sh 2>/dev/null )
    # `|| true`: grep -c prints 0 but exits 1 on no match, which set -e
    # would turn into a silent exit — and 0 ADD is the passing case.
    nmod=$(printf '%s\n' "$gout" | grep -cE '^ *[0-9]+ ~ ' || true)
    nadd=$(printf '%s\n' "$gout" | grep -cE '^ *[0-9]+ \+ ' || true)
    [ "$nmod" = "1" ] && [ "$nadd" = "0" ] \
        || fail "git read mode: a one-line edit to an executable file should mark 1 MOD / 0 ADD, got $nmod MOD / $nadd ADD"
else
    echo "smoke: NOTE — git not found; skipping the git-read-mode executable-file gate" >&2
fi

# ============================================================
# 1.5.3 — VCS path hardening (docs/audit/2026-10-31-audit.md)
# ============================================================

# git with the user's config shut out (signing, hooks or templates can't break
# a fixture). Shared by the 1.5.3 VCS gates below.
sgit() {
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
        git -c user.name=owl -c user.email=owl@smoke -c init.defaultBranch=main "$@"
}
# Marker count in piped gutter output (`    11 ~ │ text`). `|| true`: grep -c
# exits 1 on zero matches, and zero is usually the passing case under set -e.
count_marks() { grep -cE '^ *[0-9]+ [-+~] ' "$1" || true; }
HAVE_TIMEOUT=0
command -v timeout >/dev/null 2>&1 && HAVE_TIMEOUT=1
HAVE_GIT=0
command -v git >/dev/null 2>&1 && HAVE_GIT=1

# A FIFO named `.git/HEAD` in an ancestor: repo discovery must stat(), never
# open() — open(2) on a FIFO blocks until a writer appears, and through 1.5.2
# owl hung there forever. A HEAD that isn't a regular file is no repository,
# so the file is "outside of repo".
if [ "$HAVE_TIMEOUT" = "1" ] && mkdir -p "$TMPDIR/fifo/p/.git" "$TMPDIR/fifo/p/src" \
    && mkfifo "$TMPDIR/fifo/p/.git/HEAD" 2>/dev/null; then
echo hi > "$TMPDIR/fifo/p/src/a.txt"
set +e
out=$(timeout 10 "$BIN" --diff "$TMPDIR/fifo/p/src/a.txt" 2>"$TMPDIR/err")
rc=$?
set -e
[ "$rc" != "124" ] || fail "FIFO .git/HEAD in an ancestor hung repo discovery (killed after 10s)"
[ "$rc" = "0" ]    || fail "FIFO .git/HEAD in an ancestor: exit $rc, expected 0"
[ -z "$out" ]      || fail "FIFO .git/HEAD in an ancestor: --diff should emit nothing, got: $out"
grep -q "outside of repo" "$TMPDIR/err" \
    || fail "FIFO .git/HEAD in an ancestor: expected 'outside of repo', got: $(cat "$TMPDIR/err")"
set +e
timeout 10 "$BIN" -n --color=never --style=changes --paging=never \
    "$TMPDIR/fifo/p/src/a.txt" > "$TMPDIR/out" 2>&1
rc=$?
set -e
[ "$rc" = "0" ] || fail "FIFO .git/HEAD in an ancestor: gutter view exit $rc (124 = hung)"
grep -q 'hi' "$TMPDIR/out" || fail "FIFO .git/HEAD in an ancestor: gutter view lost the file content"
else
echo "smoke: NOTE — timeout or mkfifo unavailable; skipping the FIFO .git/HEAD gate" >&2
fi

# VCS memory is bounded BEFORE sit runs. sit's diff costs ~95 B per line per
# side, so 1 MiB of newlines with a 1-byte edit cost ~200 MB through 1.5.2 (and
# 16 MiB cost 2.5 GB). Over VCS_MAX_LINES (512 Ki) or VCS_MAX_BYTES (8 MiB)
# owl now skips markers: silent in the gutter, one note under --diff. Run
# under a 128 MB address-space cap, which 1.5.2 died under (SIGSEGV or 'vec: alloc failed').
if [ "$HAVE_GIT" = "1" ]; then
mrepo="$TMPDIR/vcsmem"
mkdir -p "$mrepo"
(
    cd "$mrepo" || exit 1
    sgit init -q . || exit 1
    head -c 1048576 /dev/zero | tr '\0' '\n' > nl.txt
    # 9 MiB in 9216 lines: over the byte ceiling, nowhere near the line one.
    line=$(head -c 1023 /dev/zero | tr '\0' 'w')
    i=0; : > wide.txt
    while [ $i -lt 9216 ]; do printf '%s\n' "$line"; i=$((i + 1)); done > wide.txt
    sgit add nl.txt wide.txt || exit 1
    sgit commit -qm base || exit 1
    printf 'X' | dd of=nl.txt bs=1 seek=100 conv=notrunc 2>/dev/null || exit 1
    printf 'X' | dd of=wide.txt bs=1 seek=100 conv=notrunc 2>/dev/null || exit 1
) || fail "could not build the VCS-memory git fixture"
set +e
( cd "$mrepo" && ulimit -v 131072 && exec "$BIN_ABS" --diff --paging=never nl.txt ) \
    > "$TMPDIR/out" 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" = "0" ] || fail "VCS memory: --diff of 1 MiB of newlines under a 128 MB cap exited $rc (1.5.2: out of memory — SIGSEGV or 'alloc failed')"
[ ! -s "$TMPDIR/out" ] || fail "VCS memory: a file over VCS_MAX_LINES should get no diff, got: $(head -c 200 "$TMPDIR/out")"
grep -q "too large" "$TMPDIR/err" \
    || fail "VCS memory: --diff over VCS_MAX_LINES should say 'too large', got: $(cat "$TMPDIR/err")"
set +e
( cd "$mrepo" && ulimit -v 131072 && exec "$BIN_ABS" -n --color=never --style=changes \
    --paging=never --line-range=95:105 nl.txt ) > "$TMPDIR/out" 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" = "0" ] || fail "VCS memory: gutter view of 1 MiB of newlines under a 128 MB cap exited $rc"
[ ! -s "$TMPDIR/err" ] || fail "VCS memory: gutter mode must skip silently, got: $(cat "$TMPDIR/err")"
n=$(count_marks "$TMPDIR/out")
[ "$n" = "0" ] || fail "VCS memory: a file over VCS_MAX_LINES should show no markers, got $n"
# Byte ceiling: 9 MiB of 1 KiB lines.
( cd "$mrepo" && "$BIN_ABS" -n --color=never --style=changes --paging=never \
    --line-range=1:3 wide.txt ) > "$TMPDIR/out" 2>/dev/null
n=$(count_marks "$TMPDIR/out")
[ "$n" = "0" ] || fail "VCS memory: a file over VCS_MAX_BYTES should show no markers, got $n"
else
echo "smoke: NOTE — git not found; skipping the VCS memory-ceiling gate" >&2
fi

# -p is cat: it must not run the VCS diff at all (through 1.5.2 `-p --diff`
# computed every marker and threw them away). Two observables: no "outside of
# repo" note (the VCS path never ran), and a 500 Ki-line file in a dirty repo
# — under the ceilings, so the gutter WOULD diff it — streams under a 64 MB
# address-space cap that the discarded diff blew through.
cp README.md "$TMPDIR/plain_diff.md"
"$BIN" -p --diff "$TMPDIR/plain_diff.md" > "$TMPDIR/out" 2>"$TMPDIR/err" \
|| fail "-p --diff outside a repo exited non-zero"
cmp -s "$TMPDIR/out" "$TMPDIR/plain_diff.md" || fail "-p --diff is not byte-identical to cat"
[ ! -s "$TMPDIR/err" ] || fail "-p --diff consulted VCS (stderr: $(cat "$TMPDIR/err"))"
if [ "$HAVE_GIT" = "1" ]; then
prepo="$TMPDIR/plainvcs"
mkdir -p "$prepo"
(
    cd "$prepo" || exit 1
    sgit init -q . || exit 1
    head -c 512000 /dev/zero | tr '\0' '\n' > nl.txt
    sgit add nl.txt || exit 1
    sgit commit -qm base || exit 1
    printf 'X' | dd of=nl.txt bs=1 seek=100 conv=notrunc 2>/dev/null || exit 1
) || fail "could not build the -p --diff git fixture"
set +e
( cd "$prepo" && ulimit -v 65536 && exec "$BIN_ABS" -p --diff nl.txt ) > "$TMPDIR/out" 2>/dev/null
rc=$?
set -e
[ "$rc" = "0" ] || fail "-p --diff ran the VCS diff: exit $rc under a 64 MB cap (1.5.2: SIGSEGV)"
cmp -s "$TMPDIR/out" "$prepo/nl.txt" || fail "-p --diff in a dirty repo is not byte-identical to cat"
else
echo "smoke: NOTE — git not found; skipping the -p --diff memory half of the plain-mode gate" >&2
fi

# A tracked symlink holds its target TEXT; owl shows the target's CONTENT and
# sit read through the link, so a clean, committed symlink marked every line
# "~". The path naming a symlink now means no markers.
if [ "$HAVE_GIT" = "1" ]; then
srepo="$TMPDIR/vcslink"
mkdir -p "$srepo"
(
    cd "$srepo" || exit 1
    sgit init -q . || exit 1
    printf 'one\ntwo\nthree\n' > target.txt
    ln -s target.txt link.txt || exit 1
    sgit add target.txt link.txt || exit 1
    sgit commit -qm base || exit 1
) || fail "could not build the tracked-symlink git fixture"
( cd "$srepo" && "$BIN_ABS" -n --color=never --style=changes --paging=never link.txt ) \
    > "$TMPDIR/out" 2>/dev/null
grep -q 'three' "$TMPDIR/out" || fail "tracked symlink: target content not rendered"
n=$(count_marks "$TMPDIR/out")
[ "$n" = "0" ] || fail "tracked symlink: a clean committed symlink should show no markers, got $n"
out=$( cd "$srepo" && "$BIN_ABS" --diff link.txt 2>"$TMPDIR/err" )
[ -z "$out" ] || fail "tracked symlink: --diff should emit nothing, got: $out"
grep -q "symlink" "$TMPDIR/err" || fail "tracked symlink: --diff should say why, got: $(cat "$TMPDIR/err")"
else
echo "smoke: NOTE — git not found; skipping the tracked-symlink gate" >&2
fi

# A `.git` that is a FILE (`gitdir:` — a submodule or `git worktree add`) is a
# repository boundary sit can't follow. Through 1.5.2 the walk went on to the
# superproject, where the worktree's files are untracked: every line "+".
if [ "$HAVE_GIT" = "1" ]; then
wrepo="$TMPDIR/vcswt"
mkdir -p "$wrepo"
(
    cd "$wrepo" || exit 1
    sgit init -q . || exit 1
    printf 'a\nb\nc\n' > f.txt
    sgit add f.txt || exit 1
    sgit commit -qm base || exit 1
    sgit worktree add -q nested >/dev/null 2>&1 || exit 1
) || fail "could not build the linked-worktree git fixture"
[ -f "$wrepo/nested/.git" ] || fail "linked-worktree fixture: nested/.git is not a file"
"$BIN" -n --color=never --style=changes --paging=never "$wrepo/nested/f.txt" \
    > "$TMPDIR/out" 2>/dev/null
n=$(count_marks "$TMPDIR/out")
[ "$n" = "0" ] || fail "linked worktree: a .git file must stop the repo walk (no markers), got $n"
out=$("$BIN" --diff "$wrepo/nested/f.txt" 2>"$TMPDIR/err")
[ -z "$out" ] || fail "linked worktree: --diff should emit nothing, got: $out"
grep -q "linked worktree" "$TMPDIR/err" \
    || fail "linked worktree: --diff should say why, got: $(cat "$TMPDIR/err")"
else
echo "smoke: NOTE — git not found; skipping the .git-file (gitdir:) gate" >&2
fi

# A file inside the repo's own `.git/` is not in its work tree; through 1.5.2
# `owl .git/config` showed every line "+" (absent from HEAD, present on disk).
if [ "$HAVE_GIT" = "1" ]; then
grm="$TMPDIR/vcsmeta"
mkdir -p "$grm"
( cd "$grm" && sgit init -q . ) || fail "could not build the .git/ metadata git fixture"
( cd "$grm" && "$BIN_ABS" -n --color=never --style=changes --paging=never .git/config ) \
    > "$TMPDIR/out" 2>/dev/null
n=$(count_marks "$TMPDIR/out")
[ "$n" = "0" ] || fail ".git/ metadata: .git/config should show no markers, got $n"
out=$( cd "$grm" && "$BIN_ABS" --diff .git/config 2>"$TMPDIR/err" )
[ -z "$out" ] || fail ".git/ metadata: --diff .git/config should emit nothing, got: $out"
grep -q "outside of repo" "$TMPDIR/err" \
    || fail ".git/ metadata: --diff .git/config should say 'outside of repo', got: $(cat "$TMPDIR/err")"
else
echo "smoke: NOTE — git not found; skipping the .git/ metadata gate" >&2
fi
# Same for a sit repo's `.sit/`.
if [ -n "$SIT_BIN" ]; then
srm="$TMPDIR/vcsmeta_sit"
mkdir -p "$srm"
( cd "$srm" && "$SIT_BIN" init >/dev/null 2>&1 ) || fail "could not build the .sit/ metadata sit fixture"
( cd "$srm" && "$BIN_ABS" -n --color=never --style=changes --paging=never .sit/HEAD ) \
    > "$TMPDIR/out" 2>/dev/null
n=$(count_marks "$TMPDIR/out")
[ "$n" = "0" ] || fail ".sit/ metadata: .sit/HEAD should show no markers, got $n"
fi

# Lexical `..` after a symlink names a different file than the kernel opens:
# with R/lnk -> ../X/sub, `R/lnk/../f.txt` IS X/f.txt, but 1.5.2 diffed R/f.txt
# and painted R's changes onto X's content. A `..` that follows a symlink now
# means no markers.
if [ "$HAVE_GIT" = "1" ]; then
dd_="$TMPDIR/vcsdotdot"
mkdir -p "$dd_/R" "$dd_/X/sub"
printf 'x-one\nx-two\nx-three\nx-four\n' > "$dd_/X/f.txt"
(
    cd "$dd_/R" || exit 1
    sgit init -q . || exit 1
    printf 'r-one\nr-two\nr-three\nr-four\n' > f.txt
    sgit add f.txt || exit 1
    sgit commit -qm base || exit 1
    printf 'r-one\nR-TWO\nr-three\nr-four\nr-five\n' > f.txt
    ln -s ../X/sub lnk || exit 1
) || fail "could not build the ..-after-symlink git fixture"
# Control: R/f.txt itself has markers.
"$BIN" -n --color=never --style=changes --paging=never "$dd_/R/f.txt" > "$TMPDIR/out" 2>/dev/null
n=$(count_marks "$TMPDIR/out")
[ "$n" = "2" ] || fail "..-after-symlink control: R/f.txt should show 2 markers, got $n"
for p in "$dd_/R/lnk/../f.txt" "lnk/../f.txt"; do
    ( cd "$dd_/R" && "$BIN_ABS" -n --color=never --style=changes --paging=never "$p" ) \
        > "$TMPDIR/out" 2>/dev/null
    grep -q 'x-three' "$TMPDIR/out" || fail "..-after-symlink: $p should render X/f.txt"
    n=$(count_marks "$TMPDIR/out")
    [ "$n" = "0" ] || fail "..-after-symlink: $p shows X/f.txt but got $n markers from R/f.txt"
done
out=$( cd "$dd_/R" && "$BIN_ABS" --diff lnk/../f.txt 2>"$TMPDIR/err" )
[ -z "$out" ] || fail "..-after-symlink: --diff should emit nothing, got: $out"
grep -q "symlink" "$TMPDIR/err" || fail "..-after-symlink: --diff should say why, got: $(cat "$TMPDIR/err")"
# A `..` with no symlink before it still resolves (and still marks).
mkdir -p "$dd_/R/sub"
( cd "$dd_/R/sub" && "$BIN_ABS" -n --color=never --style=changes --paging=never ../f.txt ) \
    > "$TMPDIR/out" 2>/dev/null
n=$(count_marks "$TMPDIR/out")
[ "$n" = "2" ] || fail "plain ../ path: ../f.txt from R/sub should show 2 markers, got $n"
else
echo "smoke: NOTE — git not found; skipping the ..-after-symlink gate" >&2
fi


# ============================================================
# M7 — Config file (OWL_CONFIG + precedence)
# ============================================================

# Valid config: theme=light applied, keyword ANSI is 126 (light) not 141 (dark).
cat > "$TMPDIR/owl.cyml" <<'EOF'
theme = light
tabs  = 2
style = no-changes
EOF
printf 'def x():\n    return 1\n' > "$TMPDIR/hi.py"

out=$(OWL_CONFIG="$TMPDIR/owl.cyml" "$BIN" --color=always "$TMPDIR/hi.py")
case "$out" in
    *"[38;5;126m"*) ;;
    *) fail "config theme=light did not take effect (no 126 ANSI code in output)" ;;
esac

# CLI overrides config: --theme=dark wins, keyword is 141 not 126.
out=$(OWL_CONFIG="$TMPDIR/owl.cyml" "$BIN" --color=always --theme=dark "$TMPDIR/hi.py")
case "$out" in
    *"[38;5;141m"*) ;;
    *) fail "CLI --theme=dark did not override config theme=light" ;;
esac
case "$out" in
    *"[38;5;126m"*) fail "CLI override leaked the config color (found 126)" ;;
esac

# Missing config path is silent and does not break startup.
OWL_CONFIG=/nonexistent/path/config.cyml "$BIN" --version > /dev/null 2>"$TMPDIR/err" \
    || fail "missing OWL_CONFIG broke --version"
[ ! -s "$TMPDIR/err" ] || fail "missing OWL_CONFIG leaked stderr: $(cat "$TMPDIR/err")"

# Malformed line prints `owl: path:line: reason` to stderr and continues.
cat > "$TMPDIR/bad.cyml" <<'EOF'
theme = light
garbage-line-no-equals
tabs = 2
EOF
OWL_CONFIG="$TMPDIR/bad.cyml" "$BIN" "$TMPDIR/hi.py" > /dev/null 2>"$TMPDIR/err" \
    || fail "malformed config should not fail the run"
grep -q ":2: expected key=value" "$TMPDIR/err" \
    || fail "malformed config did not report line-2 error on stderr"

# Bad value for a known key reports "bad value".
cat > "$TMPDIR/badval.cyml" <<'EOF'
theme = chartreuse
EOF
OWL_CONFIG="$TMPDIR/badval.cyml" "$BIN" "$TMPDIR/hi.py" > /dev/null 2>"$TMPDIR/err" \
    || fail "bad config value should not fail the run"
grep -q ":1: bad value" "$TMPDIR/err" \
    || fail "bad theme value not reported on stderr"

# Unknown key reports "unknown config key".
cat > "$TMPDIR/badkey.cyml" <<'EOF'
not-a-real-key = whatever
EOF
OWL_CONFIG="$TMPDIR/badkey.cyml" "$BIN" "$TMPDIR/hi.py" > /dev/null 2>"$TMPDIR/err" \
    || fail "unknown config key should not fail the run"
grep -q ":1: unknown config key" "$TMPDIR/err" \
    || fail "unknown key not reported on stderr"

# 1.1.1 — --wrap=character hard-wraps at terminal width. Default
# falls back to 80 cols when stdout isn't a TTY (this is, since the
# test pipes through $().
long_line=$(printf 'a%.0s' $(seq 1 200))
out=$("$BIN" --wrap=character --paging=never <<<"$long_line")
# After wrap, 200 a's should be split with at least one \n inserted.
nl_count=$(printf '%s' "$out" | tr -cd '\n' | wc -c)
[ "$nl_count" -ge 1 ] || fail "--wrap=character did not insert any newline in 200-char line"
# Each non-final line should be ~80 chars long. awk 'length' avoids
# wc -c's trailing-LF count.
first_line_len=$(printf '%s' "$out" | awk 'NR==1 { print length; exit }')
[ "$first_line_len" -le 80 ] || fail "--wrap=character first line too long: $first_line_len"

# UTF-8 safety: codepoint count, not byte count, drives wrap.
# 79 ASCII chars + one 2-byte ä = 80 codepoints, fits one line.
mixed=$(printf 'a%.0s' $(seq 1 79); printf '\xc3\xa4')
out=$(printf '%s' "$mixed" | "$BIN" --wrap=character --paging=never)
# Should stay one line (no wrap).
nl_count=$(printf '%s' "$out" | tr -cd '\n' | wc -c)
[ "$nl_count" = "0" ] || fail "--wrap=character broke UTF-8 boundary at 80 cols"

# Plain mode preserves cat parity even with --wrap=character.
diff <(printf '%s\n' "$long_line") <("$BIN" -p --wrap=character <<<"$long_line") > /dev/null \
    || fail "--wrap=character broke -p cat parity"

# 1.1.8 — --wrap=auto (default) wraps content when the decorated
# frame is rendering. A 200-char line piped through -n should wrap
# inside the frame and emit at least one continuation gutter glyph
# under the divider.
out=$("$BIN" -n --paging=never <<<"$long_line")
nl_count=$(printf '%s' "$out" | tr -cd '\n' | wc -c)
# Header rule + file line + middle rule + content (1 file-origin nl
# + at least 1 wrap nl) + bottom rule = >= 6 newlines.
[ "$nl_count" -ge 6 ] || fail "--wrap=auto did not wrap under -n: $nl_count newlines"
# Wrap continuation lines start with whitespace + '↪ ' (the 1.1.9
# wrap-arrow glyph in lineno color, distinct from '│' which marks
# the start of a new file line). Existence proves alignment.
case "$out" in
    *"         ↪ a"*) ;;
    *) fail "--wrap=auto missing ↪ continuation gutter under -n" ;;
esac

# 1.1.8 — --wrap=never lets long lines overflow even when decorated.
# The body row containing the 'a's must remain a single physical line
# (only the file-origin newline at the end).
out=$("$BIN" --wrap=never -n --paging=never <<<"$long_line")
body_line=$(printf '%s\n' "$out" | grep 'aaaaaaa')
body_count=$(printf '%s\n' "$out" | grep -c 'aaaaaaa')
[ "$body_count" = "1" ] || fail "--wrap=never split content under -n: $body_count rows"
# Plain mode + --wrap=auto still cat-parity (auto is a no-op without
# the frame).
diff <(printf '%s\n' "$long_line") <("$BIN" -p --wrap=auto <<<"$long_line") > /dev/null \
    || fail "--wrap=auto broke -p cat parity"

# 1.1.11 — exact-gutter wrap math. Pre-1.1.11 owl always subtracted
# the VCS-on (11-col) gutter when computing the wrap budget, even
# when --style=no-changes left the marker cell off and the gutter was
# only 9 cols wide; wrapped content stopped 2 cols short of the right
# rule. With the per-file _recompute_wrap_cols path, --style=no-changes
# at 80-col fallback width should fit exactly 71 chars of content per
# row (80 − 9), and a 71-char line must NOT wrap.
seventy_one=$(printf 'a%.0s' $(seq 1 71))
out=$("$BIN" --style=no-changes -n --paging=never <<<"$seventy_one")
case "$out" in
    *"↪"*) fail "--style=no-changes wrapped 71-char line that fits 9-col gutter at 80 cols" ;;
esac
# And the boundary holds: a 72-char line MUST wrap, proving the
# budget is exactly 71 (not silently widened past the right rule).
seventy_two=$(printf 'a%.0s' $(seq 1 72))
out=$("$BIN" --style=no-changes -n --paging=never <<<"$seventy_two")
case "$out" in
    *"↪"*) ;;
    *) fail "--style=no-changes did not wrap 72-char line at 80-col fallback" ;;
esac
# Default style (marker cell present, gutter 11 cols) keeps the
# pre-1.1.11 budget — a 70-char line wraps because 80 − 11 = 69.
seventy=$(printf 'a%.0s' $(seq 1 70))
out=$("$BIN" -n --paging=never <<<"$seventy")
case "$out" in
    *"↪"*) ;;
    *) fail "default-style wrap budget regressed: 70-char line should wrap (80 − 11 = 69)" ;;
esac

# 1.1.1 — ext.<extension> = <language> override. Map an arbitrary
# extension to a known language; verify the file header gains the
# language label that the built-in table wouldn't have produced.
cat > "$TMPDIR/extover.cyml" <<'EOF'
ext.confx = shell
EOF
printf 'echo no-shebang\n' > "$TMPDIR/over.confx"
out=$(OWL_CONFIG="$TMPDIR/extover.cyml" "$BIN" -n --color=never "$TMPDIR/over.confx")
case "$out" in
    *"(shell)"*) ;;
    *) fail "ext.confx=shell override did not relabel: $out" ;;
esac
# Bad lang in override reports "bad value" — uses the same line-error
# path config.cyr already has for malformed values.
cat > "$TMPDIR/badext.cyml" <<'EOF'
ext.confx = bogus
EOF
OWL_CONFIG="$TMPDIR/badext.cyml" "$BIN" "$TMPDIR/over.confx" > /dev/null 2>"$TMPDIR/err" \
    || fail "bad ext-override should continue (error to stderr only)"
grep -q ":1: bad value" "$TMPDIR/err" \
    || fail "bad ext-override did not report :1: bad value"

# ============================================================
# M8a — Robustness (binary detect, large-file notice, weird inputs)
# ============================================================

# Binary file: 1.1.3 changed pre-1.1.3 skip-notice → auto hex-dump.
# stdout now carries an xxd-style dump; stderr stays clean; exit 0.
printf '\x00binary\x00content\x00' > "$TMPDIR/bin.dat"
"$BIN" "$TMPDIR/bin.dat" > "$TMPDIR/out" 2> "$TMPDIR/err" \
    || fail "binary auto hex-dump should exit 0 (got non-zero)"
[ -s "$TMPDIR/out" ] || fail "binary auto hex-dump emitted no stdout"
grep -q "binary" "$TMPDIR/out" \
    || fail "binary auto hex-dump missing ASCII column with 'binary' substring"
[ ! -s "$TMPDIR/err" ] || fail "binary auto hex-dump leaked stderr: $(cat "$TMPDIR/err")"

# Binary with -p (cat parity) MUST dump byte-identically.
diff "$TMPDIR/bin.dat" <("$BIN" -p "$TMPDIR/bin.dat") > /dev/null \
    || fail "-p did not byte-identically dump binary file (cat-parity)"

# 1.1.3 — explicit --hex / -x forces xxd-style on text files too.
printf 'hello\nworld\n' > "$TMPDIR/text.txt"
out=$("$BIN" --hex "$TMPDIR/text.txt")
case "$out" in
    *"68 65 6c 6c 6f 0a"*"|hello."*) ;;
    *) fail "--hex did not emit xxd-style hex+ASCII on text file: $out" ;;
esac
out=$("$BIN" -x "$TMPDIR/text.txt")
case "$out" in
    *"68 65 6c 6c 6f"*) ;;
    *) fail "-x short form does not match --hex" ;;
esac
# -p wins over --hex (cat parity sacred).
diff "$TMPDIR/text.txt" <("$BIN" -p --hex "$TMPDIR/text.txt") > /dev/null \
    || fail "-p --hex broke cat parity"

# Binary with -A MUST render (escape glyphs), not skip.
"$BIN" -A "$TMPDIR/bin.dat" > "$TMPDIR/out" 2> "$TMPDIR/err" \
    || fail "-A on binary should render, not exit non-zero"
[ -s "$TMPDIR/out" ] || fail "-A on binary produced no output"

# Binary with --language= asserted: user takes responsibility, no skip.
"$BIN" --language=plain "$TMPDIR/bin.dat" > "$TMPDIR/out" 2>"$TMPDIR/err" \
    || fail "--language=plain on binary should render, not skip"

# Mixed files: binary between two text files — text renders, binary
# reports, overall exit is partial (1) because some files succeeded.
printf 'hello\n' > "$TMPDIR/a.txt"
printf 'world\n' > "$TMPDIR/b.txt"
set +e
"$BIN" -p "$TMPDIR/a.txt" "$TMPDIR/bin.dat" "$TMPDIR/b.txt" \
    > "$TMPDIR/out" 2> "$TMPDIR/err"
rc=$?
set -e
# -p bypasses binary detection — all three files dump. Exit code 0.
[ "$rc" = "0" ] || fail "-p mixed exit: got $rc, expected 0"
# 1.1.3 — without -p, binary auto-hex-dumps inline; all three files
# render successfully. Pre-1.1.3 this was a partial-failure case
# (binary skipped, exit 1, "binary file" notice on stderr). Note a.txt
# and b.txt were just re-printed above with "hello\n" / "world\n".
"$BIN" "$TMPDIR/a.txt" "$TMPDIR/bin.dat" "$TMPDIR/b.txt" \
    > "$TMPDIR/out" 2> "$TMPDIR/err" \
    || fail "mixed-with-binary should now exit 0 (hex-dump fallback)"
[ ! -s "$TMPDIR/err" ] || fail "mixed-with-binary leaked stderr: $(cat "$TMPDIR/err")"
grep -q "^hello$"   "$TMPDIR/out" || fail "mixed run missing a.txt content"
grep -q "^world$"   "$TMPDIR/out" || fail "mixed run missing b.txt content"
grep -q "^00000000" "$TMPDIR/out" || fail "mixed run missing hex-dump offsets for binary"

# Large-file highlight fallback: creating a file past the 16 MB
# HIGHLIGHT_MAX cap (raised from 128 KB at 1.3.6) should still
# render (no crash) with color stripped and a stderr notice.
# `print('x')` is 11 bytes per line including newline; 1.7M lines
# lands at ~18 MB, comfortably over the cap.
yes "print('x')" 2>/dev/null | head -1700000 > "$TMPDIR/huge.py"
[ "$(wc -c < "$TMPDIR/huge.py")" -gt 16777216 ] \
    || fail "large-file fixture not larger than 16 MB cap"
"$BIN" --color=always "$TMPDIR/huge.py" > "$TMPDIR/out" 2> "$TMPDIR/err" \
    || fail "large file highlight fallback failed exit"
! grep -q $'\x1b' "$TMPDIR/out" \
    || fail "large file emitted ANSI — fallback did not kick in"
grep -q "too large for highlighting" "$TMPDIR/err" \
    || fail "large file missing stderr notice"

# Weird-input robustness.
: > "$TMPDIR/empty.txt"
"$BIN" "$TMPDIR/empty.txt" > "$TMPDIR/out" 2> "$TMPDIR/err" \
    || fail "empty file non-zero exit"
[ ! -s "$TMPDIR/out" ]  || fail "empty file produced stdout bytes"
[ ! -s "$TMPDIR/err" ]  || fail "empty file produced stderr"

printf 'x' > "$TMPDIR/one.txt"
out=$("$BIN" -p "$TMPDIR/one.txt")
[ "$out" = "x" ] || fail "single-byte file did not render 'x' under -p"

printf 'no trailing newline' > "$TMPDIR/notail.txt"
diff "$TMPDIR/notail.txt" <("$BIN" -p "$TMPDIR/notail.txt") > /dev/null \
    || fail "-p broke cat parity on file without trailing newline"

# UTF-8 BOM: bytes pass through under -p (cat parity).
printf '\xef\xbb\xbfhello\n' > "$TMPDIR/bom.txt"
diff "$TMPDIR/bom.txt" <("$BIN" -p "$TMPDIR/bom.txt") > /dev/null \
    || fail "-p broke cat parity on BOM-prefixed file"

# ============================================================
# M8c — Security hardening (audit 2026-04-23 findings 001–004)
# ============================================================

# FINDING-002 — ESC in path is replaced with '?' on stderr so ANSI
# can't inject into downstream stderr capture.
esc_path=$(printf '/tmp/\x1b]0;evil\x07badpath')
set +e
"$BIN" "$esc_path" 2>"$TMPDIR/err" >/dev/null
set -e
grep -q $'\x1b' "$TMPDIR/err" \
    && fail "FINDING-002 regression: ESC leaked into stderr"
grep -q "badpath" "$TMPDIR/err" \
    || fail "FINDING-002 regression: path body missing from stderr"

# FINDING-001 — OSC 52 in file content is stripped in decorated mode;
# -p, -A, -r all bypass the strip.
printf 'before\x1b]52;c;evil\x07after\n' > "$TMPDIR/evil.txt"

out=$("$BIN" --color=always "$TMPDIR/evil.txt")
case "$out" in
    *beforeafter*) ;;
    *) fail "FINDING-001 regression: OSC 52 not stripped in decorated mode" ;;
esac

out=$("$BIN" -r --color=always "$TMPDIR/evil.txt")
case "$out" in
    *$'\x1b]52'*) ;;
    *) fail "FINDING-001: --raw-control-chars did not pass ESC through" ;;
esac

# -p must be byte-identical to cat regardless of content.
diff "$TMPDIR/evil.txt" <("$BIN" -p "$TMPDIR/evil.txt") >/dev/null \
    || fail "-p broke cat parity on content with OSC"

# 1.1.1 — --strip-ansi=never aliases -r (passthrough).
out=$("$BIN" --strip-ansi=never --color=always "$TMPDIR/evil.txt")
case "$out" in
    *$'\x1b]52'*) ;;
    *) fail "--strip-ansi=never did not pass ESC through (alias of -r)" ;;
esac

# 1.1.1 — --strip-ansi=always overrides -r in decorated mode.
out=$("$BIN" --strip-ansi=always -r --color=always "$TMPDIR/evil.txt")
case "$out" in
    *beforeafter*) ;;
    *) fail "--strip-ansi=always failed to override -r in decorated mode" ;;
esac

# 1.1.1 — --strip-ansi=always preserves -p cat parity (plain is sacred).
diff "$TMPDIR/evil.txt" <("$BIN" --strip-ansi=always -p "$TMPDIR/evil.txt") >/dev/null \
    || fail "--strip-ansi=always broke -p cat parity"

# 1.1.1 — --strip-ansi=bogus → exit 2.
set +e
"$BIN" --strip-ansi=bogus "$TMPDIR/evil.txt" > /dev/null 2>"$TMPDIR/err"
rc=$?
set -e
[ "$rc" = "2" ] || fail "--strip-ansi=bogus exit: got $rc, expected 2"

# 1.1.1 — --line-range filters output across plain, decorated, and highlight paths.
printf 'one\ntwo\nthree\nfour\nfive\n' > "$TMPDIR/lr.txt"
out=$("$BIN" --line-range=2:4 "$TMPDIR/lr.txt")
[ "$out" = "$(printf 'two\nthree\nfour')" ] || fail "--line-range=2:4 plain output: got '$out'"
out=$("$BIN" --line-range=:3 "$TMPDIR/lr.txt")
[ "$out" = "$(printf 'one\ntwo\nthree')" ] || fail "--line-range=:3 (open start): got '$out'"
out=$("$BIN" --line-range=4: "$TMPDIR/lr.txt")
[ "$out" = "$(printf 'four\nfive')" ] || fail "--line-range=4: (open end): got '$out'"
out=$("$BIN" --line-range=3 "$TMPDIR/lr.txt")
[ "$out" = "three" ] || fail "--line-range=3 (single line): got '$out'"
# Range applies in -p mode (explicit user opt-in to a transform).
out=$("$BIN" -p --line-range=2:4 "$TMPDIR/lr.txt")
[ "$out" = "$(printf 'two\nthree\nfour')" ] || fail "--line-range under -p: got '$out'"
# Decorated -n with range — gutter shows the actual line numbers (2,3,4).
out=$("$BIN" -n --color=never --line-range=2:4 "$TMPDIR/lr.txt")
case "$out" in
    *"     2"*"two"*"     3"*"three"*"     4"*"four"*) ;;
    *) fail "--line-range -n gutter wrong: $out" ;;
esac
# Highlight path honors range — colored bytes only for lines in range.
# Strip owl's own ANSI before string-matching so the test sees only
# the underlying text.
printf 'fn a() {}\nfn b() {}\nfn c() {}\n' > "$TMPDIR/lr.rs"
out=$("$BIN" --color=always --paging=never --line-range=2:2 "$TMPDIR/lr.rs" \
        | sed $'s/\x1b\\[[0-9;]*m//g')
case "$out" in
    *"fn b()"*) ;;
    *) fail "--line-range highlight path missed line 2: $out" ;;
esac
case "$out" in
    *"fn c()"*) fail "--line-range highlight emitted past end: $out" ;;
    *) ;;
esac
case "$out" in
    *"fn a()"*) fail "--line-range highlight emitted before start: $out" ;;
    *) ;;
esac
# Error cases — exit 2.
for bad in bogus 5:2 ""; do
    set +e
    "$BIN" --line-range="$bad" "$TMPDIR/lr.txt" > /dev/null 2>"$TMPDIR/err"
    rc=$?
    set -e
    [ "$rc" = "2" ] || fail "--line-range=$bad exit: got $rc, expected 2"
done

# FINDING-003/005 — the git fork+execve scaffold is gone in owl 1.4.0. VCS
# markers now come from sit's sit_diff_path *library* call, so there is no
# subprocess at all: the shell-injection and argv-quoting classes are closed
# by construction (nothing is spawned, nothing is quoted). Re-verify the
# library path still produces markers (reuses the M6 sit fixture). Skipped
# when sit is unavailable.
if [ -n "$SIT_BIN" ]; then
    if ! ( cd "$TMPDIR/sitrepo" && "$BIN_ABS" -n --color=never --style=changes --paging=never tracked.txt 2>/dev/null ) | grep -q '+'; then
        fail "VCS regression: sit_diff_path no longer produces ADD markers"
    fi
fi

# 1.1.4 — content-based language detection (post-shebang fallback).
# Files with no extension and no shebang get a language label from the
# opening bytes.
printf '{"name": "owl"}\n' > "$TMPDIR/c_json"
out=$("$BIN" -n --color=never "$TMPDIR/c_json")
case "$out" in
    *"(json)"*) ;;
    *) fail "content-detect: '{ ...}' should resolve as json: $out" ;;
esac
printf -- '---\nkey: value\n' > "$TMPDIR/c_yaml"
out=$("$BIN" -n --color=never "$TMPDIR/c_yaml")
case "$out" in
    *"(yaml)"*) ;;
    *) fail "content-detect: '---' opener should resolve as yaml: $out" ;;
esac
printf '# Title\n' > "$TMPDIR/c_md"
out=$("$BIN" -n --color=never "$TMPDIR/c_md")
case "$out" in
    *"(markdown)"*) ;;
    *) fail "content-detect: '# ...' should resolve as markdown: $out" ;;
esac
printf '[package]\nname = "owl"\n' > "$TMPDIR/c_toml"
out=$("$BIN" -n --color=never "$TMPDIR/c_toml")
case "$out" in
    *"(toml)"*) ;;
    *) fail "content-detect: '[name]' should resolve as toml: $out" ;;
esac
# Plain text — no false positive.
printf 'just some words\n' > "$TMPDIR/c_plain"
out=$("$BIN" -n --color=never "$TMPDIR/c_plain")
case "$out" in
    *"("*) fail "content-detect false positive on plain text: $out" ;;
    *) ;;
esac

# 1.1.4 — --diff mode (sit backend). The M6 fixture's tracked.txt changed
# line 2 in place (MOD) and appended line 5 (ADD); --diff emits only the
# changed/added lines, not the untouched ones. Skipped when sit is absent.
if [ -n "$SIT_BIN" ]; then
    out=$( cd "$TMPDIR/sitrepo" && "$BIN_ABS" --diff tracked.txt 2>/dev/null )
    case "$out" in
        *"epsilon-new"*) ;;
        *) fail "--diff did not emit appended line: $out" ;;
    esac
    case "$out" in
        *"BETA-changed"*) ;;
        *) fail "--diff did not emit changed line: $out" ;;
    esac
    # Untouched lines should not appear.
    case "$out" in
        *"gamma"*) fail "--diff emitted unchanged content (gamma leaked)" ;;
        *) ;;
    esac
fi
# --diff on a file outside any sit/git repo: empty stdout + an "outside of
# repo - no diff" warning on stderr (owl 1.4.4 — walk-up repo discovery finds
# no .sit/.git at the file's level or above).
cp README.md "$TMPDIR/elsewhere.md"
out=$("$BIN" --diff "$TMPDIR/elsewhere.md" 2>"$TMPDIR/err")
[ -z "$out" ] || fail "--diff on non-tracked file should produce empty stdout, got: $out"
grep -q "outside of repo" "$TMPDIR/err" || fail "--diff on non-tracked file should warn 'outside of repo', got: $(cat "$TMPDIR/err")"

# ── 1.4.6 audit gates (docs/audit/2026-08-22-audit.md) ────────────────

# FINDING-006 — an escape sequence must never swallow more than its own
# line. Pre-1.4.6 a file opening with a bare CSI whose final byte
# (0x40-0x7E) never arrived left the strip classifier latched forever, so
# every following byte was dropped: `owl file` rendered an EMPTY file,
# silently, exit 0. Payload here is digits + LF only, so no byte in the
# file can ever terminate the CSI.
printf '\033[' > "$TMPDIR/csi.txt"
i=0
while [ $i -lt 40 ]; do printf '1234567890\n' >> "$TMPDIR/csi.txt"; i=$((i+1)); done
raw=$(/bin/cat "$TMPDIR/csi.txt" | wc -c)
got=$("$BIN" --color=always --paging=never "$TMPDIR/csi.txt" | wc -c)
[ "$got" -gt $((raw - 40)) ] \
    || fail "FINDING-006 regression: unterminated CSI suppressed the file ($got of $raw bytes)"
# ...and the line-number gutter must stay in step with the file. A
# swallowed LF is a line the counter never sees, so every later number
# would be wrong. Line 2 of the file is the first payload line.
"$BIN" -n --color=always --paging=never "$TMPDIR/csi.txt" \
    | sed 's/\x1b\[[0-9;]*m//g' | grep -qE '^ *2 .*1234567890' \
    || fail "FINDING-006 regression: gutter desynced after a stripped escape"

# FINDING-001 must still hold after the FINDING-006 bounds — every escape
# class is stripped, nothing leaks to the terminal.
printf 'a\033]52;c;ZXZpbA==\007b\033[31mc\033[0md\033]0;t\033\\e\033Pq\033\\f\0337g\n' \
    > "$TMPDIR/allesc.txt"
"$BIN" --color=always --paging=never "$TMPDIR/allesc.txt" | tr -dc '\033' | wc -c \
    | grep -qx '0' || fail "FINDING-001 regression: an ESC survived stripping"
# ...and exactly the content survives. The count above also passes for a
# binary that prints nothing, and for a classifier that over-suppresses
# (a CSI final byte or a string terminator that no longer ends its
# sequence hides the rest of the line) — both found by the 2026-10-31 audit.
[ "$("$BIN" --color=always --paging=never "$TMPDIR/allesc.txt")" = "abcdefg" ] \
    || fail "FINDING-001 regression: stripping did not leave exactly the text (abcdefg)"

# FINDING-007 — an oversized $XDG_CONFIG_HOME / $HOME must not be appended
# into a fixed-size config-path buffer. Pre-1.4.6 both were copied into a
# flat alloc(1024), so anything past ~1007 bytes wrote off the end.
#
# The overflow itself is not observable from outside the process (it lands
# in unused bump arena, so the pre-fix binary exits 0 too) — the proof is
# the canary PoC in the audit report. What IS observable, and what this
# gate pins, is the fallback the fix introduces: a path that could never
# name a real file is now REJECTED, so resolution falls through to the
# next candidate instead of dead-ending on a 3 KB filename. A config under
# $HOME therefore still loads. Pre-1.4.6 the huge XDG path won and the
# HOME config was never read.
# `env -i` keeps the environment small and fully controlled: the cyrius
# stdlib's getenv reads /proc/self/environ into an 8 KB buffer, so a big
# var plus an inherited environment can push HOME out of its window (see
# the audit's INFO-002) and make this gate flap for an unrelated reason.
big=$(awk 'BEGIN{while(i++<6000)printf "A"}')
mkdir -p "$TMPDIR/h/.config/owl"
printf 'definitely_not_a_key = 1\n' > "$TMPDIR/h/.config/owl/config.cyml"
env -i PATH="$PATH" XDG_CONFIG_HOME="$big" HOME="$TMPDIR/h" \
    "$BIN" -p "$TMPDIR/csi.txt" >/dev/null 2>"$TMPDIR/cfgerr"
grep -q "unknown config key" "$TMPDIR/cfgerr" \
    || fail "FINDING-007 regression: oversized XDG_CONFIG_HOME was not rejected (HOME config never read)"
# A sane XDG_CONFIG_HOME must still win over HOME, unchanged.
mkdir -p "$TMPDIR/x/owl"
printf 'tabs = 3\n' > "$TMPDIR/x/owl/config.cyml"
env -i PATH="$PATH" XDG_CONFIG_HOME="$TMPDIR/x" HOME="$TMPDIR/h" \
    "$BIN" -p "$TMPDIR/csi.txt" >/dev/null 2>"$TMPDIR/cfgerr2"
grep -q "unknown config key" "$TMPDIR/cfgerr2" \
    && fail "FINDING-007 regression: a valid XDG config no longer takes precedence over HOME"

# FINDING-008 — theme colours are validated to 0..255 (or -1 where the call
# site guards it), so ansi_fg's 16-byte buffer can never be overrun. An
# 18-digit value previously emitted a 26-byte escape out of that buffer.
mkdir -p "$TMPDIR/th/owl/themes"
printf 'lineno_color = 999999999999999999\nheader_color = 45\n' > "$TMPDIR/th/owl/themes/huge.cyml"
longest=$(XDG_CONFIG_HOME="$TMPDIR/th" "$BIN" -n --color=always --paging=never \
    --theme=huge "$TMPDIR/csi.txt" 2>/dev/null \
    | grep -oaE "$(printf '\033')\[38;5;[0-9]+m" | awk '{if(length($0)>m)m=length($0)}END{print m+0}')
[ "$longest" -ge 9 ] \
    || fail "FINDING-008: no colour was emitted at all (the bound below would pass vacuously)"
[ "$longest" -le 12 ] \
    || fail "FINDING-008 regression: theme colour produced a ${longest}-byte SGR (buffer is 16)"

# FINDING-010 — tab width is bounded. An unbounded value made one TAB
# expand into that many spaces.
"$BIN" --tabs=8 "$TMPDIR/csi.txt" >/dev/null 2>&1 \
    || fail "FINDING-010: --tabs=8 should be accepted"
"$BIN" --tabs=65 "$TMPDIR/csi.txt" >/dev/null 2>&1 \
    && fail "FINDING-010 regression: --tabs=65 should be rejected"
"$BIN" --tabs=99999999999999999999 "$TMPDIR/csi.txt" >/dev/null 2>&1 \
    && fail "FINDING-010 regression: --tabs with a 20-digit value should be rejected"

# FINDING-013 (1.4.7) — the byte ceiling added for FINDING-006 emitted the
# byte that tripped it, and that byte can be an ESC. The ESC then reached
# the terminal and the bytes after it were handed to it as a fresh
# sequence — re-opening the FINDING-001 injection the classifier exists to
# close. Found by tests/owl.fcyr, which explores the boundary; a
# hand-written file misses it unless the ESC lands EXACTLY on the byte
# that trips the ceiling. That is 254 padding bytes after `ESC [` with
# ESC_MAX_LEN = 256 (ESC and `[` spend the first two of the budget), so
# this gate is offset-sensitive: if ESC_MAX_LEN changes, this number must
# change with it or the gate goes quiet.
{
    printf '\033['
    i=0; while [ $i -lt 254 ]; do printf '3'; i=$((i+1)); done
    printf '\033]52;c;cHduZWQ=\007TAIL\n'
} > "$TMPDIR/ceil.txt"
esc=$("$BIN" --color=always --paging=never "$TMPDIR/ceil.txt" | tr -dc '\033' | wc -c)
[ "$esc" -eq 0 ] \
    || fail "FINDING-013 regression: $esc raw ESC byte(s) reached stdout at the escape ceiling"
# The tail must still render — the ceiling exists so content is not lost,
# and a fix that simply dropped everything would also pass the check above.
"$BIN" --color=always --paging=never "$TMPDIR/ceil.txt" | grep -q 'TAIL' \
    || fail "FINDING-013: content after an over-long escape was suppressed"

# ── 1.5.3 audit gates (docs/audit/2026-10-31-audit.md) ────────────────
# Each gate was run against the 1.5.2 binary and fails there (FINDING-017
# needs OWL_POISON_BIN, a `cyrius build -D CYRIUS_POISON` build).

# FINDING-014 — escape stripping follows the frame, not the colour. Through
# 1.5.2 `_strip_active` keyed on colour alone, so NO_COLOR=1 or
# --color=never on a terminal drew the decorated frame and passed every
# file escape (here an OSC 52 clipboard write) straight to the terminal —
# FINDING-001 re-opened by a common setting. `-n` piped decorates too.
printf 'hello\n\033]52;c;cHduZWQ=\007world\n\033[2Jcls\n' > "$TMPDIR/esc14.txt"
out=$("$BIN" -n --color=never "$TMPDIR/esc14.txt")
n=$(printf '%s' "$out" | tr -dc '\033' | wc -c)
[ "$n" -eq 0 ] || fail "FINDING-014: -n --color=never passed $n raw ESC byte(s)"
case "$out" in *world*cls*) ;; *) fail "FINDING-014: stripped content missing" ;; esac
if script -qc 'true' /dev/null > /dev/null 2>&1; then
    for mode in NO_COLOR never; do
        if [ "$mode" = NO_COLOR ]; then cmd="env NO_COLOR=1 '$BIN_ABS' --paging=never '$TMPDIR/esc14.txt'"
        else cmd="'$BIN_ABS' --color=never --paging=never '$TMPDIR/esc14.txt'"; fi
        out=$(script -qc "$cmd" /dev/null)
        n=$(printf '%s' "$out" | tr -dc '\033' | wc -c)
        [ "$n" -eq 0 ] || fail "FINDING-014: $mode on a TTY passed $n raw ESC byte(s)"
        case "$out" in *world*) ;; *) fail "FINDING-014: $mode TTY content missing" ;; esac
    done
else
    echo "smoke: NOTE — script(1) unavailable; skipping FINDING-014 TTY half" >&2
fi

# FINDING-015 — the header's file name is sanitized like stderr echoes
# (FINDING-002's stdout twin). A name from a glob over a hostile tree
# carried a live escape into the `File:` line.
f14="$TMPDIR/x$(printf '\033]0;PWNED\007').txt"
echo hi > "$f14"
hdr=$("$BIN" -n --color=never "$f14" | grep -a 'File:')
n=$(printf '%s' "$hdr" | tr -dc '\033\007' | wc -c)
[ "$n" -eq 0 ] || fail "FINDING-015: header carried $n raw control byte(s) from the file name"
case "$hdr" in *'x?]0;PWNED?.txt'*) ;; *) fail "FINDING-015: header name not rendered with '?': $hdr" ;; esac

# FINDING-016 — stdin honours --format=ndjson and --hex. Through 1.5.2
# render_fd had neither branch: ndjson passed the input through raw (a
# forged JSON line reached the consumer as a record) and --hex printed raw.
out=$(printf 'let x = 1;\n{"kind":"keyword","text":"FORGED"}\n' \
    | "$BIN" --format=ndjson --language=rust -)
first=$(printf '%s\n' "$out" | head -1)
[ "$first" = '{"kind":"keyword","start":0,"len":3,"line":1,"text":"let"}' ] \
    || fail "FINDING-016: stdin ndjson did not emit token records: $first"
printf '%s\n' "$out" | grep -qx '{"kind":"keyword","text":"FORGED"}' \
    && fail "FINDING-016: a raw input line was emitted as an ndjson record"
set +e
printf 'x\n' | "$BIN" --format=ndjson - > /dev/null 2>&1; rc=$?
set -e
[ "$rc" -ne 0 ] || fail "FINDING-016: stdin ndjson without a grammar must fail, not exit 0"
printf 'ab\0cd\n' | "$BIN" --hex - | grep -q '^00000000  61 62 00 63 64 0a' \
    || fail "FINDING-016: --hex on stdin did not hex-dump"

# FINDING-017 — the user-grammar path is sized from the env-derived dir.
# Through 1.5.2 $HOME / $XDG_CONFIG_HOME was copied into a fixed 1024-byte
# buffer on any highlighted file: a heap overflow nothing outside the
# process can see, so this gate needs a build made with
# `cyrius build -D CYRIUS_POISON` (exit 86 on a redzone write), named by
# OWL_POISON_BIN. Without one it NOTE-skips.
if [ -n "${OWL_POISON_BIN:-}" ] && [ -x "${OWL_POISON_BIN}" ]; then
    printf 'int main(void) { return 0; }\n' > "$TMPDIR/p17.c"
    longh="/$(awk 'BEGIN{while(i++<1100)printf "A"}')"
    set +e
    env -i PATH="$PATH" HOME="$longh" "$OWL_POISON_BIN" --color=always "$TMPDIR/p17.c" > /dev/null 2>&1; rc=$?
    env -i PATH="$PATH" XDG_CONFIG_HOME="$longh" "$OWL_POISON_BIN" --color=always "$TMPDIR/p17.c" > /dev/null 2>&1; rc2=$?
    set -e
    [ "$rc" -eq 0 ] || fail "FINDING-017: long HOME on the highlight path exited $rc (86 = heap overflow)"
    [ "$rc2" -eq 0 ] || fail "FINDING-017: long XDG_CONFIG_HOME on the highlight path exited $rc2"
else
    echo "smoke: NOTE — OWL_POISON_BIN not set; skipping FINDING-017 (needs a -D CYRIUS_POISON build)" >&2
fi

# FINDING-018 / 028 — the highlight cap is the stream's real capacity, and
# nothing is lost at it. Through 1.5.2 an input of exactly 16 MiB was
# tokenized for its first 64 KiB without a word (ndjson exited 0 with a
# truncated stream), and over the cap the 1-byte overflow probe was dropped.
head -c 16777216 /dev/zero | tr '\0' 'a' > "$TMPDIR/cap.cyr"
set +e
"$BIN" --format=ndjson "$TMPDIR/cap.cyr" > /dev/null 2> "$TMPDIR/cap.err"; rc=$?
set -e
[ "$rc" -ne 0 ] || fail "FINDING-018: a 16 MiB file gave ndjson exit 0 (truncated stream)"
grep -q 'too large' "$TMPDIR/cap.err" || fail "FINDING-018: no 'too large' error for a 16 MiB ndjson input"
# Over the cap on stdin (size unknown, so the probe decides): every byte out.
{ head -c 16777216 /dev/zero | tr '\0' 'b'; printf 'Z_after\n'; } > "$TMPDIR/cap2.ini"
"$BIN" --color=always -N --wrap=never --language=ini - < "$TMPDIR/cap2.ini" 2>/dev/null \
    | sed 's/\x1b\[[0-9;]*m//g' | cmp -s - "$TMPDIR/cap2.ini" \
    || fail "FINDING-028: over-cap stdin lost a byte at the overflow probe"

# FINDING-021 — stdout write errors end owl with exit 3 (design-spec §9).
# Through 1.5.2 every write result was ignored: /dev/full and a closed
# stdout exited 0, and with SIGPIPE ignored owl spun forever after its
# reader quit.
echo hi > "$TMPDIR/w.txt"
set +e
"$BIN" "$TMPDIR/w.txt" > /dev/full 2> "$TMPDIR/w.err"; rc=$?
set -e
[ "$rc" -eq 3 ] || fail "FINDING-021: write to /dev/full exited $rc, want 3"
grep -q 'write error' "$TMPDIR/w.err" || fail "FINDING-021: no 'write error' message for /dev/full"
set +e
"$BIN" "$TMPDIR/w.txt" >&- 2>/dev/null; rc=$?
set -e
[ "$rc" -eq 3 ] || fail "FINDING-021: closed stdout exited $rc, want 3"
if command -v timeout >/dev/null 2>&1; then
    { sh -c "trap '' PIPE; timeout 10 '$BIN_ABS' -p /dev/zero; echo \$? > '$TMPDIR/w.st'"; } | head -c 1 > /dev/null
    st=$(cat "$TMPDIR/w.st")
    [ "$st" = 3 ] || fail "FINDING-021: with SIGPIPE ignored owl exited $st (124 = still spinning), want 3"
fi

# FINDING-022 — buffers are reused across files. Through 1.5.2 every
# highlighted file took a fresh 16 MiB buffer on the never-freed heap, so
# under an address-space limit highlighting quietly stopped partway
# (1.5.2: 16 of 40 files coloured at 300 MB).
mkdir -p "$TMPDIR/m22"
i=1; while [ $i -le 40 ]; do printf 'int f%d(void) { return %d; }\n' $i $i > "$TMPDIR/m22/f$i.c"; i=$((i+1)); done
pat=$(printf '\033[38;5;141mint')
n=$(sh -c "ulimit -v 300000; '$BIN_ABS' --color=always '$TMPDIR'/m22/*.c 2>/dev/null" | grep -cF "$pat" || true)
[ "$n" -eq 40 ] || fail "FINDING-022: only $n of 40 files highlighted under a 300 MB address-space limit"

# FINDING-023 — the gutter prints any line number whole. Through 1.5.2 a
# fixed 8-byte buffer was filled past its start from line 1,000,000 on (an
# out-of-bounds stack write driven by the line count) and the gutter showed
# the number mod 10^6.
awk 'BEGIN{while(i++<1000001)print "x"}' > "$TMPDIR/m.txt"
"$BIN" -n --color=never --wrap=never "$TMPDIR/m.txt" | grep -q '^1000000 ' \
    || fail "FINDING-023: line 1000000 not rendered as 1000000"

# FINDING-024 — flags apply to every file and are all checked before
# anything renders. Through 1.5.2 parse and render were one loop.
printf 'int a;\n' > "$TMPDIR/a24.c"; printf 'int b;\n' > "$TMPDIR/b24.c"
out=$("$BIN" --color=always "$TMPDIR/a24.c" -p "$TMPDIR/b24.c")
[ "$out" = "$(cat "$TMPDIR/a24.c" "$TMPDIR/b24.c")" ] \
    || fail "FINDING-024: -p after a file did not make the run cat-identical"
set +e
out=$("$BIN" "$TMPDIR/a24.c" --bogus 2>/dev/null); rc=$?
set -e
[ "$rc" -eq 2 ] || fail "FINDING-024: FILE --bogus exited $rc, want 2"
[ -z "$out" ] || fail "FINDING-024: FILE --bogus rendered FILE before rejecting the flag"
set +e
"$BIN" -f "$TMPDIR/a24.c" "$TMPDIR/b24.c" > /dev/null 2>&1; rc=$?
set -e
[ "$rc" -eq 2 ] || fail "FINDING-024: --follow with two files exited $rc, want 2"

# FINDING-025 — the pager gets its input and the whole environment. Through
# 1.5.2: with owl's fd 0 closed the pager's stdin was closed too; past
# 16 KB or 255 entries of environment TERM et al. were dropped; and a bare
# PAGER=less got no LESS flags (raw escapes, short files paged).
if script -qc 'true' /dev/null > /dev/null 2>&1; then
    printf '#!/bin/sh\nn=$(wc -c); printf "%%s %%s %%s\\n" "$n" "${LESS:-unset}" "${TERM:-unset}" > "%s/pg.out"\n' "$TMPDIR" > "$TMPDIR/pg.sh"
    chmod +x "$TMPDIR/pg.sh"
    printf 'one\ntwo\n' > "$TMPDIR/p25.txt"
    script -qc "env -u LESS PAGER='$TMPDIR/pg.sh' '$BIN_ABS' --paging=always -N '$TMPDIR/p25.txt' <&-" /dev/null > /dev/null 2>&1 || true
    set -- $(cat "$TMPDIR/pg.out" 2>/dev/null || echo "0 x x")
    [ "$1" -gt 0 ] || fail "FINDING-025: with fd 0 closed the pager received no input"
    [ "$2" = FRX ] || fail "FINDING-025: LESS unset, the pager got LESS=$2 (want FRX)"
    bigenv=$(awk 'BEGIN{while(i++<300)printf "V%03d=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx ", i}')
    script -qc "env -i PATH='$PATH' $bigenv TERM=xterm-owl PAGER='$TMPDIR/pg.sh' '$BIN_ABS' --paging=always -N '$TMPDIR/p25.txt'" /dev/null > /dev/null 2>&1 || true
    set -- $(cat "$TMPDIR/pg.out" 2>/dev/null || echo "0 x x")
    [ "$3" = xterm-owl ] || fail "FINDING-025: a large environment dropped TERM before the pager (got $3)"
else
    echo "smoke: NOTE — script(1) unavailable; skipping FINDING-025 pager gates" >&2
fi

# FINDING-027 — line numbers are 1-indexed and bounded. Through 1.5.2
# `0`, `0:` and `:0` meant "unset" and printed everything, and an overlong
# number wrapped (2^64 + 1 printed line 1).
seq 1 10 > "$TMPDIR/ten.txt" 2>/dev/null || awk 'BEGIN{while(i++<10)print i}' > "$TMPDIR/ten.txt"
for r in 0 :0 0:0 0:5 18446744073709551617 9223372036854775808 5:3; do
    set +e
    "$BIN" -p --line-range=$r "$TMPDIR/ten.txt" > /dev/null 2>&1; rc=$?
    set -e
    [ "$rc" -eq 2 ] || fail "FINDING-027: --line-range=$r exited $rc, want 2"
done
[ "$("$BIN" -p --line-range=3:4 "$TMPDIR/ten.txt" | tr '\n' ,)" = "3,4," ] \
    || fail "FINDING-027: --line-range=3:4 regressed"

# FINDING-032 — errors say what happened. Through 1.5.2 every open failure
# read "No such file or directory" and a directory "read error"; a stdin
# read failure printed nothing at all.
mkdir -p "$TMPDIR/d32"
"$BIN" "$TMPDIR/d32" 2>&1 >/dev/null | grep -q 'Is a directory' \
    || fail "FINDING-032: a directory was not reported as 'Is a directory'"
"$BIN" "$TMPDIR/d32/x/y" 2>&1 >/dev/null | grep -q 'No such file' \
    || fail "FINDING-032: ENOENT text regressed"
echo s > "$TMPDIR/np32"; chmod 000 "$TMPDIR/np32"
if [ ! -r "$TMPDIR/np32" ]; then
    "$BIN" "$TMPDIR/np32" 2>&1 >/dev/null | grep -q 'Permission denied' \
        || fail "FINDING-032: EACCES was not reported as 'Permission denied'"
fi
"$BIN" - < "$TMPDIR/d32" 2>&1 >/dev/null | grep -q '<stdin>: Is a directory' \
    || fail "FINDING-032: a stdin read failure was silent"

# FINDING-034 — --follow survives truncation like `tail -f`. Through 1.5.2
# a truncated log (logrotate copytruncate) went silent, and later appends
# came out as a torn fragment.
if command -v timeout >/dev/null 2>&1; then
    printf 'old-1\nold-2\n' > "$TMPDIR/f.log"
    ( timeout 4 "$BIN" -f -p "$TMPDIR/f.log" > "$TMPDIR/f.out" 2> "$TMPDIR/f.err" & )
    sleep 1; : > "$TMPDIR/f.log"; sleep 1
    printf 'new-1\nnew-2\n' >> "$TMPDIR/f.log"; sleep 3
    grep -q '^new-2$' "$TMPDIR/f.out" || fail "FINDING-034: --follow lost lines appended after truncation"
    grep -q 'truncated' "$TMPDIR/f.err" || fail "FINDING-034: --follow did not report the truncation"
fi

# 1.6.0 — --follow is token-coloured (_follow_hl: a vyakarana document,
# appended to as the file grows). Through 1.5.3 a follow session had no
# token colour at all. The test is that following a file as it grows prints
# what the one-shot viewer prints for the final file, byte for byte: the
# initial content, whole lines appended in several batches (a block comment
# opened in one and closed in the next), a partial line drawn when the file
# goes quiet and then continued — `fn ma` + `in() …`, where re-tokenizing
# the tail alone would colour `in` as a keyword — and a line carrying
# terminal escapes, which must still be stripped. Under -n the session is
# the one-shot output minus the closing rule a follow never reaches.
# Truncation restarts from the top, coloured.
if command -v timeout > /dev/null 2>&1; then
    fd160="$TMPDIR/fol160"
    mkdir -p "$fd160"
    printf 'fn main() {\n    let s = "hi"; // c\n' > "$fd160/f.rs"
    printf 'fn old() {}\n' > "$fd160/t.rs"
    ( timeout 5 "$BIN" -f --color=always "$fd160/f.rs" > "$fd160/f.out" 2> "$fd160/f.err" & )
    ( timeout 5 "$BIN" -f --color=always -n "$fd160/f.rs" > "$fd160/n.out" 2> /dev/null & )
    ( timeout 5 "$BIN" -f --color=always "$fd160/t.rs" > "$fd160/t.out" 2> "$fd160/t.err" & )
    sleep 1
    printf '    let n = 42;\n    /* multi\n' >> "$fd160/f.rs"
    : > "$fd160/t.rs"
    sleep 1
    printf '       line */ let x = 1;\n}\nfn ma' >> "$fd160/f.rs"
    printf 'fn new() { return 1; }\n' >> "$fd160/t.rs"
    sleep 1
    printf 'in() { let e = "\033[2J\033]0;owl\007"; }\n' >> "$fd160/f.rs"
    sleep 3
    "$BIN" --color=always --paging=never "$fd160/f.rs" > "$fd160/f.want"
    cmp -s "$fd160/f.out" "$fd160/f.want" \
        || fail "1.6.0: coloured --follow differs from the one-shot render of the final file"
    "$BIN" --color=always --paging=never -n "$fd160/f.rs" > "$fd160/n.want"
    [ -s "$fd160/n.out" ] || fail "1.6.0: --follow -n printed nothing"
    head -c "$(wc -c < "$fd160/n.out")" "$fd160/n.want" | cmp -s - "$fd160/n.out" \
        || fail "1.6.0: --follow -n is not the one-shot -n output (less its closing rule)"
    case "$(cat "$fd160/f.out")" in
        *"$(printf '\033[2J')"*|*"$(printf '\033]0')"*) fail "1.6.0: coloured --follow passed a file-origin escape through" ;;
    esac
    [ ! -s "$fd160/f.err" ] || fail "1.6.0: coloured --follow wrote to stderr: $(cat "$fd160/f.err")"
    grep -q 'truncated' "$fd160/t.err" || fail "1.6.0: coloured --follow did not report the truncation"
    case "$(cat "$fd160/t.out")" in
        *"$(printf '\033[')"*"fn"*"new"*) ;;
        *) fail "1.6.0: coloured --follow lost or uncoloured the lines appended after truncation" ;;
    esac
else
    echo "smoke: NOTE — timeout unavailable; skipping the coloured --follow gates" >&2
fi

# 1.6.0 — the CLI is parsed by cmdit. What changed, each pinned:
#   - a value flag takes `--name VALUE` as well as `--name=VALUE`;
#   - `--` ends the options, so a file may start with `-`;
#   - --help / --version / --list-* answer only when the whole command line
#     parses (`--help --bogus` was help; now it is an error);
#   - a missing value, and a value given to a switch, say so.
# What did not: error wording for an attached value, `-np` (one short flag
# per argument), -n / -N last-wins, exit codes.
printf 'fn a() {}\n' > "$TMPDIR/c160.rs"
out=$("$BIN" --color always --paging never "$TMPDIR/c160.rs")
case "$out" in
    *$(printf '\033')*) ;;
    *) fail "1.6.0 CLI: --color always (separate value) did not colour" ;;
esac
[ "$out" = "$("$BIN" --color=always --paging=never "$TMPDIR/c160.rs")" ] \
    || fail "1.6.0 CLI: --color always and --color=always differ"
mkdir -p "$TMPDIR/c160"
printf 'dash file\n' > "$TMPDIR/c160/-x.txt"
out=$(cd "$TMPDIR/c160" && "$BIN_ABS" -p -- -x.txt)
[ "$out" = "dash file" ] || fail "1.6.0 CLI: -- did not make -x.txt a file"
cli_err() {   # args… ; sets rc and err
    set +e
    "$BIN" "$@" < /dev/null > /dev/null 2> "$TMPDIR/c160/err"; rc=$?
    set -e
    err=$(cat "$TMPDIR/c160/err")
}
cli_err --help --bogus
[ "$rc" -eq 2 ] || fail "1.6.0 CLI: --help --bogus exited $rc, want 2"
[ "$err" = "owl: --bogus: unknown option" ] || fail "1.6.0 CLI: --help --bogus said: $err"
cli_err --color
[ "$rc" -eq 2 ] || fail "1.6.0 CLI: --color with no value exited $rc, want 2"
[ "$err" = "owl: --color: missing value (want auto|always|never)" ] || fail "1.6.0 CLI: --color said: $err"
cli_err --language -n "$TMPDIR/c160.rs"
[ "$err" = "owl: --language: missing value (try --list-languages)" ] \
    || fail "1.6.0 CLI: --language -n should refuse -n as the value, said: $err"
cli_err --plain=1 "$TMPDIR/c160.rs"
[ "$rc" -eq 2 ] || fail "1.6.0 CLI: --plain=1 exited $rc, want 2"
[ "$err" = "owl: --plain=1: takes no value" ] || fail "1.6.0 CLI: --plain=1 said: $err"
cli_err --paging nope "$TMPDIR/c160.rs"
[ "$err" = "owl: --paging=nope: invalid value (want auto|always|never)" ] \
    || fail "1.6.0 CLI: --paging nope said: $err"
cli_err --paging=nope "$TMPDIR/c160.rs"
[ "$err" = "owl: --paging=nope: invalid value (want auto|always|never)" ] \
    || fail "1.6.0 CLI: --paging=nope wording changed: $err"
cli_err -np "$TMPDIR/c160.rs"
[ "$rc" -eq 2 ] || fail "1.6.0 CLI: -np exited $rc, want 2"
[ "$err" = "owl: -np: unknown option" ] || fail "1.6.0 CLI: -np said: $err"
on=$("$BIN" -N -n --color=never "$TMPDIR/c160.rs")
off=$("$BIN" -n -N --color=never "$TMPDIR/c160.rs")
case "$on" in *"1 "*"fn a"*) ;; *) fail "1.6.0 CLI: -N -n should end with numbers on" ;; esac
[ "$off" = "fn a() {}" ] || fail "1.6.0 CLI: -n -N should end with numbers off"

# FINDING-036 — no colour codes for bytes that are not drawn: through 1.5.2
# --line-range emitted an empty SGR pair for every token before the range.
printf 'fn a() {}\nfn b() {}\nfn c() {}\nfn d() {}\n' > "$TMPDIR/lr.rs"
out=$("$BIN" --color=always --line-range=4 "$TMPDIR/lr.rs")
first=$(printf '%s' "$out" | head -c 11 | od -An -c | tr -d ' \n')
[ "$first" = "033[38;5;141mf" ] || [ "$first" = '033[38;5;141' ] || {
    pairs=$(printf '%s' "$out" | sed 's/\x1b\[38;5;[0-9]*m\x1b\[0m/@/g' | tr -dc '@' | wc -c)
    [ "$pairs" -eq 0 ] || fail "FINDING-036: $pairs empty SGR pair(s) for tokens outside --line-range"
}

# FINDING-037 — ndjson is valid JSON for any input: invalid UTF-8 becomes
# \ufffd instead of passing through raw.
printf 'x = "\303\251 \377 end"\n' > "$TMPDIR/u.py"
out=$("$BIN" --format=ndjson "$TMPDIR/u.py")
raw=$(printf '%s' "$out" | tr -dc '\377' | wc -c)
[ "$raw" -eq 0 ] || fail "FINDING-037: ndjson carried a raw invalid UTF-8 byte"
# A case pattern, not grep: some greps read `\u` as an escape even under -F.
case "$out" in *'\ufffd'*) ;; *) fail "FINDING-037: invalid UTF-8 not replaced with \\ufffd" ;; esac
printf '%s' "$out" | grep -qF "$(printf '\303\251')" || fail "FINDING-037: valid UTF-8 no longer passes through"

# FINDING-038 — a command line owl cannot read is an error, not "no
# arguments". Through 1.5.2 owl silently read stdin instead (no /proc, or
# fd exhaustion as here).
echo hi > "$TMPDIR/s38.txt"
set +e
# No redirect inside: with only fds 0-2 allowed the shell itself could not
# open one, and owl would never run.
err=$(sh -c "ulimit -n 3; '$BIN_ABS' '$TMPDIR/s38.txt'" 2>&1 >/dev/null); rc=$?
set -e
[ "$rc" -eq 2 ] || fail "FINDING-038: unreadable command line exited $rc, want 2"
case "$err" in *'command line'*) ;; *) fail "FINDING-038: no error for an unreadable command line" ;; esac

# ── 1.5.3 parser gates (config.cyr / theme.cyr / lang.cyr) ──────────

# ── Finding 1: user theme name dangled into a dead stack frame ──────────
# [theme_name_copy]
mkdir -p "$TMPDIR/g1/owl/themes"
printf 'header_color = 37\n' > "$TMPDIR/g1/owl/themes/mytheme.cyml"
printf 'header_color = 38\n' > "$TMPDIR/g1/owl/themes/other.cyml"
# The later line matters: its _cfg_apply reuses the stack frame whose
# buffer 1.5.2 kept as the theme's name, so the name became "4".
printf 'theme = mytheme\ntabs = 4\n' > "$TMPDIR/g1.cyml"
printf 'x\n' > "$TMPDIR/g1.txt"
# config `theme = mytheme`, CLI `--theme=mytheme`: same theme, must resolve.
out=$(env -i PATH="$PATH" HOME="$TMPDIR/nohome" XDG_CONFIG_HOME="$TMPDIR/g1" \
    OWL_CONFIG="$TMPDIR/g1.cyml" "$BIN" -n --color=always --paging=never \
    --theme=mytheme "$TMPDIR/g1.txt" 2>"$TMPDIR/g1.err") \
    || fail "1.5.3 parser audit: --theme=<user theme the config already loaded> rejected: $(cat "$TMPDIR/g1.err")"
case "$out" in
    *"[38;5;37m"*) ;;
    *) fail "1.5.3 parser audit: config+CLI user theme lost header_color=37" ;;
esac

# [theme_cli_overrides_config]
mkdir -p "$TMPDIR/g1/owl/themes"
printf 'header_color = 37\n' > "$TMPDIR/g1/owl/themes/mytheme.cyml"
printf 'header_color = 38\n' > "$TMPDIR/g1/owl/themes/other.cyml"
printf 'theme = mytheme\n' > "$TMPDIR/g1.cyml"
printf 'x\n' > "$TMPDIR/g1.txt"
# CLI --theme=<another user theme> must override the config's user theme.
out=$(env -i PATH="$PATH" HOME="$TMPDIR/nohome" XDG_CONFIG_HOME="$TMPDIR/g1" \
    OWL_CONFIG="$TMPDIR/g1.cyml" "$BIN" -n --color=always --paging=never \
    --theme=other "$TMPDIR/g1.txt" 2>"$TMPDIR/g1.err") \
    || fail "1.5.3 parser audit: CLI --theme=other could not override config theme=mytheme: $(cat "$TMPDIR/g1.err")"
case "$out" in
    *"[38;5;38m"*) ;;
    *) fail "1.5.3 parser audit: CLI user theme did not apply header_color=38" ;;
esac
case "$out" in
    *"[38;5;37m"*) fail "1.5.3 parser audit: config user theme leaked through a CLI override" ;;
esac

# ── Finding 2: config / theme silently truncated at 8192 bytes ──────────
# [config_truncation]
printf '\tX\n' > "$TMPDIR/tab.txt"
# `tabs = 64` straddles byte 8192: `tabs = 6` is the last in-limit text.
{
    printf '#'; i=0; while [ $i -lt 8182 ]; do printf 'x'; i=$((i+1)); done; printf '\n'
    printf 'tabs = 64\nwrap = never\n'
} > "$TMPDIR/big.cyml"
out=$(env -i PATH="$PATH" HOME="$TMPDIR/nohome" OWL_CONFIG="$TMPDIR/big.cyml" \
    "$BIN" "$TMPDIR/tab.txt" 2>"$TMPDIR/big.err")
[ "$out" = "    X" ] \
    || fail "1.5.3 parser audit: a config line cut at 8192 bytes was applied (got '$out', want 4-space default)"
n=$(grep -c "big.cyml: larger than 8192 bytes" "$TMPDIR/big.err" || true)
[ "$n" = "1" ] || fail "1.5.3 parser audit: oversized config did not warn exactly once (got $n): $(cat "$TMPDIR/big.err")"
# Exactly-full file whose newline is byte 8193: nothing lost, no warning.
{
    printf '#'; i=0; while [ $i -lt 8182 ]; do printf 'x'; i=$((i+1)); done; printf '\n'
    printf 'tabs = 6\n'
} > "$TMPDIR/full.cyml"
out=$(env -i PATH="$PATH" HOME="$TMPDIR/nohome" OWL_CONFIG="$TMPDIR/full.cyml" \
    "$BIN" "$TMPDIR/tab.txt" 2>"$TMPDIR/full.err")
[ "$out" = "      X" ] || fail "1.5.3 parser audit: last line of an exactly-full config was dropped"
[ ! -s "$TMPDIR/full.err" ] || fail "1.5.3 parser audit: exactly-full config warned: $(cat "$TMPDIR/full.err")"

# [theme_truncation]
mkdir -p "$TMPDIR/g2/owl/themes"
printf 'x\n' > "$TMPDIR/g2.txt"
# `header_color = 123` straddles byte 8192: `header_color = 12` is in-limit.
{
    printf '#'; i=0; while [ $i -lt 8173 ]; do printf 'x'; i=$((i+1)); done; printf '\n'
    printf 'header_color = 123\n'
} > "$TMPDIR/g2/owl/themes/big.cyml"
out=$(env -i PATH="$PATH" HOME="$TMPDIR/nohome" XDG_CONFIG_HOME="$TMPDIR/g2" \
    "$BIN" -n --color=always --paging=never --theme=big "$TMPDIR/g2.txt" 2>"$TMPDIR/g2.err") \
    || fail "1.5.3 parser audit: oversized theme failed to load"
case "$out" in
    *"[38;5;12m"*) fail "1.5.3 parser audit: a theme line cut at 8192 bytes was applied (header 12)" ;;
esac
n=$(grep -c "big.cyml: larger than 8192 bytes" "$TMPDIR/g2.err" || true)
[ "$n" = "1" ] || fail "1.5.3 parser audit: oversized theme did not warn exactly once (got $n)"

# ── Finding 3: ext.<X> overrides ────────────────────────────────────────
# [ext_uppercase_key]
printf 'echo hi\n' > "$TMPDIR/f.confx"
printf 'ext.CONFX = shell\n' > "$TMPDIR/e1.cyml"
out=$(env -i PATH="$PATH" HOME="$TMPDIR/nohome" OWL_CONFIG="$TMPDIR/e1.cyml" \
    "$BIN" -n --color=never "$TMPDIR/f.confx")
case "$out" in
    *"(shell)"*) ;;
    *) fail "1.5.3 parser audit: ext.CONFX = shell did not match f.confx: $out" ;;
esac

# [ext_last_wins]
printf 'echo hi\n' > "$TMPDIR/f.confx"
printf 'ext.confx = ini\next.confx = shell\n' > "$TMPDIR/e2.cyml"
out=$(env -i PATH="$PATH" HOME="$TMPDIR/nohome" OWL_CONFIG="$TMPDIR/e2.cyml" \
    "$BIN" -n --color=never "$TMPDIR/f.confx")
case "$out" in
    *"(shell)"*) ;;
    *) fail "1.5.3 parser audit: repeated ext.confx is not last-wins: $out" ;;
esac

# [ext_too_many]
printf 'echo hi\n' > "$TMPDIR/f.confx"
: > "$TMPDIR/e3.cyml"
i=0; while [ $i -lt 16 ]; do printf 'ext.e%d = shell\n' $i >> "$TMPDIR/e3.cyml"; i=$((i+1)); done
printf 'ext.e3 = python\next.confx = shell\n' >> "$TMPDIR/e3.cyml"
env -i PATH="$PATH" HOME="$TMPDIR/nohome" OWL_CONFIG="$TMPDIR/e3.cyml" \
    "$BIN" "$TMPDIR/f.confx" >/dev/null 2>"$TMPDIR/e3.err"
grep -q ":18: too many ext overrides (max 16)" "$TMPDIR/e3.err" \
    || fail "1.5.3 parser audit: 17th distinct ext override not reported as too many: $(cat "$TMPDIR/e3.err")"
# Re-registering e3 (line 17) replaces in place, so it must NOT error.
grep -q ":17:" "$TMPDIR/e3.err" && fail "1.5.3 parser audit: re-registering a known ext used up a slot"

# ── Finding 4a: theme integers wrapped i64 ──────────────────────────────
# [theme_int_digits]
mkdir -p "$TMPDIR/g4/owl/themes"
printf 'x\n' > "$TMPDIR/g4.txt"
printf 'lineno_color = 18446744073709551716\n' > "$TMPDIR/g4/owl/themes/wrap.cyml"
out=$(env -i PATH="$PATH" HOME="$TMPDIR/nohome" XDG_CONFIG_HOME="$TMPDIR/g4" \
    "$BIN" -n --color=always --paging=never --theme=wrap "$TMPDIR/g4.txt")
case "$out" in
    *"[38;5;100m"*) fail "1.5.3 parser audit: 2^64+100 wrapped and was accepted as colour 100" ;;
esac
printf 'lineno_color = 0100\n' > "$TMPDIR/g4/owl/themes/four.cyml"
out=$(env -i PATH="$PATH" HOME="$TMPDIR/nohome" XDG_CONFIG_HOME="$TMPDIR/g4" \
    "$BIN" -n --color=always --paging=never --theme=four "$TMPDIR/g4.txt")
case "$out" in
    *"[38;5;100m"*) fail "1.5.3 parser audit: a 4-digit theme colour was accepted" ;;
esac
printf 'lineno_color = 100\n' > "$TMPDIR/g4/owl/themes/ok.cyml"
out=$(env -i PATH="$PATH" HOME="$TMPDIR/nohome" XDG_CONFIG_HOME="$TMPDIR/g4" \
    "$BIN" -n --color=always --paging=never --theme=ok "$TMPDIR/g4.txt")
case "$out" in
    *"[38;5;100m"*) ;;
    *) fail "1.5.3 parser audit: a valid 3-digit theme colour was refused" ;;
esac

# ── Finding 4b: theme name escaped the themes directory ─────────────────
# [theme_name_confined]
mkdir -p "$TMPDIR/g5/x/owl/themes"
printf 'header_color = 37\n' > "$TMPDIR/g5/evil.cyml"
printf 'x\n' > "$TMPDIR/g5.txt"
set +e
env -i PATH="$PATH" HOME="$TMPDIR/nohome" XDG_CONFIG_HOME="$TMPDIR/g5/x" \
    "$BIN" -n --color=always --paging=never --theme=../../../evil "$TMPDIR/g5.txt" \
    >"$TMPDIR/g5.out" 2>"$TMPDIR/g5.err"
rc=$?
set -e
[ "$rc" = "2" ] || fail "1.5.3 parser audit: --theme=../../../evil loaded a file outside the themes dir (rc=$rc)"
printf 'theme = ../../../evil\n' > "$TMPDIR/g5.cyml"
out=$(env -i PATH="$PATH" HOME="$TMPDIR/nohome" XDG_CONFIG_HOME="$TMPDIR/g5/x" \
    OWL_CONFIG="$TMPDIR/g5.cyml" "$BIN" -n --color=always --paging=never \
    "$TMPDIR/g5.txt" 2>"$TMPDIR/g5.err")
grep -q ":1: bad value" "$TMPDIR/g5.err" \
    || fail "1.5.3 parser audit: config theme = ../../../evil was not refused"
case "$out" in
    *"[38;5;37m"*) fail "1.5.3 parser audit: config theme name traversed out of the themes dir" ;;
esac

# ── Finding 4c: non-regular config / theme files ────────────────────────
# [config_fifo]
mkfifo "$TMPDIR/cfg.fifo"
set +e
env -i PATH="$PATH" HOME="$TMPDIR/nohome" OWL_CONFIG="$TMPDIR/cfg.fifo" \
    timeout 5 "$BIN" --version >/dev/null 2>&1
rc=$?
set -e
[ "$rc" = "0" ] || fail "1.5.3 parser audit: a FIFO at OWL_CONFIG hung or broke owl --version (rc=$rc)"

# [theme_fifo]
mkdir -p "$TMPDIR/g6/owl/themes"
mkfifo "$TMPDIR/g6/owl/themes/ff.cyml"
printf 'x\n' > "$TMPDIR/g6.txt"
set +e
env -i PATH="$PATH" HOME="$TMPDIR/nohome" XDG_CONFIG_HOME="$TMPDIR/g6" \
    timeout 5 "$BIN" --theme=ff "$TMPDIR/g6.txt" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" = "2" ] || fail "1.5.3 parser audit: a FIFO theme file hung owl or was accepted (rc=$rc, want 2)"

# [config_dev_stdin]
out=$(printf 'tabs = 2\n' | env -i PATH="$PATH" HOME="$TMPDIR/nohome" \
    OWL_CONFIG=/dev/stdin timeout 5 "$BIN" -p)
[ "$out" = "tabs = 2" ] || fail "1.5.3 parser audit: OWL_CONFIG=/dev/stdin consumed the piped input (got '$out')"

# ── Finding 5: CRLF / TAB shebangs ──────────────────────────────────────
# [shebang_crlf]
printf '#!/bin/sh\r\necho hi\r\n' > "$TMPDIR/crlfsh"
out=$("$BIN" -n --color=never "$TMPDIR/crlfsh")
case "$out" in
    *"(shell)"*) ;;
    *) fail "1.5.3 parser audit: CRLF shebang #!/bin/sh not detected: $out" ;;
esac

# [shebang_tab]
printf '#!/usr/bin/env\tpython3\nprint(1)\n' > "$TMPDIR/tabpy"
out=$("$BIN" -n --color=never "$TMPDIR/tabpy")
case "$out" in
    *"(python)"*) ;;
    *) fail "1.5.3 parser audit: TAB-separated shebang env<TAB>python3 not detected: $out" ;;
esac

# ── Harness-found: a NUL inside a config value was silently cut ─────────
# [config_value_nul]
printf '\tX\n' > "$TMPDIR/tab.txt"
printf 'tabs = 8\000junk\n' > "$TMPDIR/nul.cyml"
out=$(env -i PATH="$PATH" HOME="$TMPDIR/nohome" OWL_CONFIG="$TMPDIR/nul.cyml" \
    "$BIN" "$TMPDIR/tab.txt" 2>"$TMPDIR/nul.err")
[ "$out" = "    X" ] || fail "1.5.3 parser audit: 'tabs = 8<NUL>junk' was applied as tabs=8"
grep -q ":1: bad value" "$TMPDIR/nul.err" || fail "1.5.3 parser audit: NUL in a config value not reported"

# ── Unchanged behaviour: valid config/theme still apply ─────────────────
# [valid_unchanged]
mkdir -p "$TMPDIR/g7/owl/themes"
printf 'header_color = 37\ntoken.keyword = 207\n' > "$TMPDIR/g7/owl/themes/t.cyml"
printf 'theme = t\ntabs = "6"\next.confx = shell\n' > "$TMPDIR/g7.cyml"
printf '\tX\n' > "$TMPDIR/g7.confx"
out=$(env -i PATH="$PATH" HOME="$TMPDIR/nohome" XDG_CONFIG_HOME="$TMPDIR/g7" \
    OWL_CONFIG="$TMPDIR/g7.cyml" "$BIN" -n --color=always --paging=never \
    "$TMPDIR/g7.confx" 2>"$TMPDIR/g7.err")
[ ! -s "$TMPDIR/g7.err" ] || fail "valid config warned: $(cat "$TMPDIR/g7.err")"
case "$out" in *"[38;5;37m"*) ;; *) fail "valid user theme not applied" ;; esac
case "$out" in *"(shell)"*) ;; *) fail "valid ext override not applied" ;; esac
case "$out" in *"      X"*) ;; *) fail "valid quoted tabs not applied" ;; esac

echo "smoke: OK ($v_long) — M0–M8 gates passing (security hardening FINDING-001…013 and the 2026-10-31 audit gates closed)"
