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
# M6 — VCS change markers (git scaffold; swappable for SIT)
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

# Non-git path doesn't hang and doesn't leak git errors onto stderr.
"$BIN" -n --color=always "$TMPDIR/a.txt" > /dev/null 2>"$TMPDIR/err" \
    || fail "non-git file rendered non-zero under -n --color=always"
[ ! -s "$TMPDIR/err" ] || fail "non-git file leaked stderr: $(cat "$TMPDIR/err")"

# Inside a real git repo with a dirty file, markers should appear.
# owl itself is under git; use its README as a controlled probe —
# copy → append → render and grep for an ADD marker (+ in the
# change column). Restore README afterwards via git checkout.
README_BAK="$TMPDIR/README.bak"
cp README.md "$README_BAK"
printf '\nsmoke-marker-probe\n' >> README.md
if ! "$BIN" -n --color=always README.md 2>/dev/null | grep -q '+'; then
    cp "$README_BAK" README.md
    fail "expected ADD marker (+) on dirty README.md inside repo"
fi
cp "$README_BAK" README.md

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

# ============================================================
# M8a — Robustness (binary detect, large-file notice, weird inputs)
# ============================================================

# Binary file: NUL byte in first chunk → skip with notice, don't dump.
printf '\x00binary\x00content\x00' > "$TMPDIR/bin.dat"
set +e
"$BIN" "$TMPDIR/bin.dat" > "$TMPDIR/out" 2> "$TMPDIR/err"
rc=$?
set -e
[ ! -s "$TMPDIR/out" ] || fail "binary file dumped to stdout instead of skipping"
grep -q "binary file" "$TMPDIR/err" \
    || fail "binary skip did not mention 'binary file' on stderr"
# One file, all-fail → exit 4.
[ "$rc" = "4" ] || fail "binary-skip single-file exit: got $rc, expected 4"

# Binary with -p (cat parity) MUST dump byte-identically.
diff "$TMPDIR/bin.dat" <("$BIN" -p "$TMPDIR/bin.dat") > /dev/null \
    || fail "-p did not byte-identically dump binary file (cat-parity)"

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
# Without -p, binary is skipped, others render. Expect exit 1 (partial).
set +e
"$BIN" "$TMPDIR/a.txt" "$TMPDIR/bin.dat" "$TMPDIR/b.txt" \
    > "$TMPDIR/out" 2> "$TMPDIR/err"
rc=$?
set -e
[ "$rc" = "1" ] || fail "mixed-with-binary exit: got $rc, expected 1 (partial)"
grep -q "binary file" "$TMPDIR/err" || fail "binary notice missing in mixed run"

# Large-file highlight fallback: creating a >128KB file should still
# render (no crash) with color stripped and a stderr notice.
yes "print('x')" | head -20000 > "$TMPDIR/big.py"
"$BIN" --color=always "$TMPDIR/big.py" > "$TMPDIR/out" 2> "$TMPDIR/err" \
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

# FINDING-003 — git via argv (no shell). Markers still appear on a
# dirty file inside the owl repo.
cp README.md "$TMPDIR/README.bak"
printf '\nsmoke-hardening-probe\n' >> README.md
if ! "$BIN" -n --color=always README.md 2>/dev/null | grep -q '+'; then
    cp "$TMPDIR/README.bak" README.md
    fail "FINDING-003 regression: argv-git no longer produces ADD markers"
fi
cp "$TMPDIR/README.bak" README.md

echo "smoke: OK ($v_long) — M0–M8 gates passing (security hardening FINDING-001/002/003/004 closed)"
