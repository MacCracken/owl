#!/bin/sh
# owl smoke test — M0 (version/help) + M1 (plain-mode cat parity).
# Usage: sh scripts/smoke.sh [path/to/owl]    (default: build/owl)
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

# ============================================================
# M1 — plain-mode cat parity
# ============================================================

# Fixture corpus.
printf 'line one\nline two\nline three\n' > "$TMPDIR/a.txt"
printf 'second file\n' > "$TMPDIR/b.txt"
: > "$TMPDIR/empty.txt"
yes "this is owl" | head -c 1048576 > "$TMPDIR/big.txt"

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
    *"── File: $TMPDIR/a.txt"*) ;;
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
hdr_count=$(printf '%s\n' "$out" | grep -c "── File: ")
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

# --list-languages must include the starter set.
llist=$("$BIN" --list-languages)
for lang in plain shell python javascript typescript rust cyrius c toml json yaml; do
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

echo "smoke: OK ($v_long) — M0 + M1 + M2 + M3a gates passing"
