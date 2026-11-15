#!/bin/sh
set -u
root=${ROOT:-/repo}
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
source_file="$root/scripts/_xkeen/04_tools/03_tools_diagnostic.sh"
eval "$(awk 'index($0,"mask_ips() {") { on=1 } on { line=$0; sub(/^    /, "", line); print line; if (line == "}") exit }' "$source_file")"
ipv4_eth=192.168.1.2
ipv6_eth=2001:db8::1

out=$(printf 'exact4=192.168.1.2\nlookalike4=192x168y1z2\nexact6=2001:db8::1\nbracket6=[2001:db8::1]\nlong6=2001:db8::12\n' | mask_ips)
check 'exact IPv4 is masked' "$(printf '%s\n' "$out" | sed -n '1p')" 'exact4=***MASKED***'
check 'IPv4 regex lookalike remains unchanged' "$(printf '%s\n' "$out" | sed -n '2p')" 'lookalike4=192x168y1z2'
check 'exact IPv6 is masked' "$(printf '%s\n' "$out" | sed -n '3p')" 'exact6=***MASKED***'
check 'bracketed IPv6 keeps brackets' "$(printf '%s\n' "$out" | sed -n '4p')" 'bracket6=[***MASKED***]'
check 'longer IPv6 address is not partially masked' "$(printf '%s\n' "$out" | sed -n '5p')" 'long6=2001:db8::12'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
