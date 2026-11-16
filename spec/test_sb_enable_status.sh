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

eval "$(awk '$0 == "sb_enable() {" { on=1 } on { print } on && /^}/ { exit }' \
    "$root/scripts/_xkeen/04_tools/08_tools_balancer/02_balancer_control.sh")"

red=''; reset=''; green=''; yellow=''
# Values are consumed by the extracted function body through eval.
export red reset green yellow
sb_enabled=false
sb_interval=5
export sb_interval
cron_state=absent
tick_rc=0
install_rc=0
tick_calls=0
speed_balancer_settings() { :; }
sb_ensure_api() { return 0; }
sb_cron_installed() { [ "$cron_state" = installed ]; }
sb_write_setting() { sb_enabled=$2; }
sb_remove_cron() { cron_state=absent; return 0; }
sb_install_cron() {
    [ "$install_rc" -eq 0 ] || return "$install_rc"
    cron_state=installed
}
sb_tick() { tick_calls=$((tick_calls + 1)); return "$tick_rc"; }
sb_current_target() { echo test-node; }

install_rc=1
sb_enable > "$work/cron-failure.log" 2>&1; rc=$?
check 'cron failure returns error' "$rc" 1
check 'cron failure rolls setting back off' "$sb_enabled" false
check 'cron failure does not run first measurement' "$tick_calls" 0
check 'cron failure removes any partial schedule' "$cron_state" absent

install_rc=0
tick_rc=7
sb_enable > "$work/tick-failure.log" 2>&1; rc=$?
check 'first measurement failure is reported' "$rc" 1
check 'failed first measurement keeps scheduled activation' "$sb_enabled" true
check 'cron remains installed after measurement failure' "$cron_state" installed
check 'first measurement failure is explicit' "$(grep -ci 'первый замер' "$work/tick-failure.log")" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
