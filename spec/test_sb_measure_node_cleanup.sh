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

core="$root/scripts/_xkeen/04_tools/08_tools_balancer/01_balancer_core.sh"
eval "$(awk '$0 == "sb_measure_node() {" { on=1 } on { print } on && /^}/ { exit }' "$core")"

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
rm_count=0
rm_fail_at=0
adrules_rc=1
# shellcheck disable=SC2329
xray() {
    case "$2" in
        adrules) return "$adrules_rc" ;;
        rmrules)
            rm_count=$((rm_count + 1))
            [ "$rm_count" -ne "$rm_fail_at" ] || return 1
            ;;
    esac
    return 0
}
curl() { printf '1024 1 200'; }

sb_measure_node test-node > "$work/result"; rc=$?
check 'failed adrules returns error' "$rc" 1
check 'failed adrules does not leave probe JSON' "$(test -e "$sb_rule_tmp" && echo present || echo absent)" absent
check 'failed adrules reports status' "$(cat "$work/result")" '0 adrules'

adrules_rc=0
rm_count=0
rm_fail_at=2
sb_measure_node test-node > "$work/remove-failure-result"; rc=$?
check 'failed rmrules returns distinct error' "$rc" 2
check 'failed rmrules does not report successful speed' "$(cat "$work/remove-failure-result")" '0 rmrules'
check 'failed rmrules still cleans probe JSON' "$(test -e "$sb_rule_tmp" && echo present || echo absent)" absent

eval "$(awk '$0 == "sb_tick() {" { on=1 } on { print } on && /^}/ { exit }' "$core")"
# This test isolates stop-on-cleanup-failure. The open balancer PR adds
# serialization around ticks, so keep that unrelated lock successful here.
sb_lock_acquire() { return 0; }
sb_lock_release() { :; }
sb_api_addr=127.0.0.1:10085
sb_balancer=test-balancer
sb_hysteresis=25
sb_log_file="$work/log"
sb_log_enabled=false
export sb_api_addr sb_balancer sb_hysteresis sb_log_file sb_log_enabled
xray() { return 0; }
sb_pin_get() { :; }
sb_node_list() { sb_nodes='first-node
second-node'; }
export sb_nodes
sb_current_target() { echo active-node; }
sb_log() { :; }
sb_log_trim() { :; }
sb_measure_node() {
    printf '%s\n' "$1" >> "$work/measured-nodes"
    echo '0 rmrules'
    return 2
}
sb_tick; rc=$?
check 'tick returns error after failed cleanup' "$rc" 1
check 'tick skips subsequent node measurement' "$(wc -l < "$work/measured-nodes" | tr -d ' ')" 1
check 'tick stopped after first node' "$(cat "$work/measured-nodes")" first-node

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
