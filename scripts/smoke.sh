#!/bin/sh
# owl M0 smoke test — asserts the built binary answers --version / --help.
# Usage: sh scripts/smoke.sh [path/to/owl]    (default: build/owl)
set -eu

BIN="${1:-build/owl}"

if [ ! -x "$BIN" ]; then
    echo "smoke: $BIN not executable — run 'cyrius build src/main.cyr build/owl' first" >&2
    exit 1
fi

fail() { echo "smoke: FAIL — $1" >&2; exit 1; }

v_long=$("$BIN" --version) || fail "--version exited non-zero"
[ -n "$v_long" ]            || fail "--version emitted nothing"

v_short=$("$BIN" -V) || fail "-V exited non-zero"
[ "$v_long" = "$v_short" ] || fail "-V disagrees with --version ($v_short vs $v_long)"

# Version string must start with "owl " (keeps us honest about the binary name).
case "$v_long" in
    "owl "*) ;;
    *) fail "--version output does not start with 'owl ': $v_long" ;;
esac

h_long=$("$BIN" --help) || fail "--help exited non-zero"
[ -n "$h_long" ]         || fail "--help emitted nothing"

h_short=$("$BIN" -h) || fail "-h exited non-zero"
[ "$h_long" = "$h_short" ] || fail "-h disagrees with --help"

bare=$("$BIN" </dev/null) || fail "bare invocation exited non-zero"
[ -n "$bare" ]             || fail "bare invocation emitted nothing (M0: should print help)"

echo "smoke: OK ($v_long)"
