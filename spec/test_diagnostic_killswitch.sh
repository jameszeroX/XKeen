#!/bin/sh
set -u
root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"
        pass=$((pass + 1))
    else
        printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"
        fail=$((fail + 1))
    fi
}
diagnostic_source="$root/scripts/_xkeen/04_tools/03_tools_diagnostic.sh"
eval "$(awk 'index($0,"dump_tables() {") { on=1 } on { line=$0; sub(/^    /, "", line); print line; if (line == "}") exit }' "$diagnostic_source")"
mask_ips() { cat; }
log_block() { cat >/dev/null; }
CALL_LOG="$work/iptables.calls"
iptables() { printf '%s\n' "$*" >> "$CALL_LOG"; }
ip6tables() { printf '%s\n' "$*" >> "$CALL_LOG"; }

: > "$CALL_LOG"
dump_tables iptables IPv4
check 'IPv4 diagnostic dumps kill-switch mangle chain' "$(grep -c -- '-t mangle -nvL xkeen_killswitch' "$CALL_LOG")" 1
: > "$CALL_LOG"
dump_tables ip6tables IPv6
check 'IPv6 diagnostic dumps kill-switch mangle chain' "$(grep -c -- '-t mangle -nvL xkeen_killswitch' "$CALL_LOG")" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
