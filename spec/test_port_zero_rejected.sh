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
eval "$(awk '$0 == "normalize_ports() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/04_tools/01_tools_ports.sh")"

check 'port zero is rejected like runtime' "$(normalize_ports 0)" ''
check 'port one is accepted' "$(normalize_ports 1)" 1
check 'port 65535 is accepted' "$(normalize_ports 65535)" 65535
check 'range endpoints may not include zero' "$(normalize_ports 0:80)" ''

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
