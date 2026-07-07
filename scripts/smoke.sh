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
# (vyakarana 2.1.2); 1.3.5 added terraform (vyakarana 2.1.3).
llist=$("$BIN" --list-languages)
for lang in plain shell python javascript typescript rust cyrius c toml json yaml go zig \
            asm_x86_64 asm_aarch64 java kotlin cpp csharp php ruby lua swift \
            elixir ocaml haskell sql graphql protobuf html xml css scss \
            dockerfile makefile ini cyml llvm_ir \
            powershell crystal julia vue svelte nix terraform; do
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

echo "smoke: OK ($v_long) — M0–M8 gates passing (security hardening FINDING-001/002/003/004 closed)"
