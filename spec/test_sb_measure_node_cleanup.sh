#!/bin/sh
set -u

root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'command rm -rf "$work"' EXIT INT TERM
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

eval "$(awk '$0 == "sb_measure_node() {" { on=1 } on { print } on && /^}/ { exit }' \
    "$root/scripts/_xkeen/04_tools/08_tools_balancer/01_balancer_core.sh")"

sb_rule_tmp="$work/probe-rule.json"
sb_rule_tag=xkeen-test-rule
sb_probe_intag=test-in
sb_api_addr=127.0.0.1:10085
sb_probe_addr=127.0.0.1:10808
sb_maxtime=1
sb_test_url=https://example.invalid/test
export sb_rule_tag sb_probe_intag sb_api_addr sb_probe_addr sb_maxtime sb_test_url
_xkeen_secure_rundir() { echo "$work"; }
jq() { printf '%s\n' '{"routing":{"rules":[]}}'; }
xray() {
    [ "$2" != adrules ] || return 1
    return 0
}

sb_measure_node test-node > "$work/result"; rc=$?
check 'failed adrules returns error' "$rc" 1
check 'failed adrules does not leave probe JSON' "$(test -e "$sb_rule_tmp" && echo present || echo absent)" absent
check 'failed adrules reports status' "$(cat "$work/result")" '0 adrules'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
