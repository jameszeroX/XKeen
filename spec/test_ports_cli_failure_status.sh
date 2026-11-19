#!/bin/sh
# shellcheck disable=SC2034,SC2329  # Globals and stubs are read by extracted production functions.
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
file="$root/scripts/xkeen"
eval "$(awk '/^apply_port_change\(\) \{/,/^}/ { print }' "$file")"

add_chmod_init() { chmod_calls=$((chmod_calls + 1)); }
is_proxy_running() { [ "$proxy_running" = true ]; }
sleep() { :; }
restart_rc=0
initd_file=mock_initd
mock_initd() { [ "$restart_rc" -eq 0 ]; }
proxy_running=true
chmod_calls=0
add_ports_donor() { return 1; }

apply_port_change add_ports_donor 1234 >/dev/null 2>&1
rc=$?
check 'port write failure reaches CLI wrapper' "$rc" 1
check 'port write failure skips restart' "$chmod_calls" 0

add_ports_donor() { return 0; }
restart_rc=1
apply_port_change add_ports_donor 1234 >/dev/null 2>&1
rc=$?
check 'proxy restart failure reaches CLI wrapper' "$rc" 1

proxy_running=false
restart_rc=0
apply_port_change add_ports_donor 1234 >/dev/null 2>&1
check 'successful port update without running proxy succeeds' "$?" 0

for fn in add_ports_donor del_ports_donor add_ports_exclude del_ports_exclude; do
    grep -Fq "apply_port_change $fn" "$file"
    check "$fn CLI uses checked update wrapper" "$?" 0
done

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
