#!/bin/sh
set -u

root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
. "$root/scripts/_xkeen/04_tools/08_tools_balancer/01_balancer_core.sh"
. "$root/scripts/_xkeen/04_tools/08_tools_balancer/02_balancer_control.sh"
red=''; green=''; yellow=''; reset=''
sb_pin_file="$work/.sb_pinned"
sb_api_addr=127.0.0.1:10085
sb_balancer=balancer
cron_dir="$work/cron"
cron_file=root
install_dir="$work/sbin"
mkdir -p "$cron_dir" "$install_dir"
speed_balancer_settings() { sb_enabled=false; }
sb_cron_installed() { return 1; }
sb_remove_cron() { return 0; }
sb_write_setting() { return 0; }
clear_rc=0
sb_pin_clear() { [ "$clear_rc" -eq 0 ] && rm -f "$sb_pin_file"; }
reset_rc=0
xray() {
    : > "$work/xray-called"
    return "$reset_rc"
}

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

printf 'node-a\n' > "$sb_pin_file"
sb_disable >/dev/null 2>&1; rc=$?
check 'off with a stale pin completes successfully' "$rc" 0
check 'off clears a stale pin after API reset' "$([ -e "$sb_pin_file" ] && echo yes || echo no)" no
check 'off resets Xray override even when auto is disabled' "$([ -e "$work/xray-called" ] && echo yes || echo no)" yes

rm -f "$work/xray-called"
printf 'node-b\n' > "$sb_pin_file"
reset_rc=1
sb_disable >/dev/null 2>&1; rc=$?
check 'failed API reset is reported' "$rc" 1
check 'failed API reset keeps the pin for retry' "$(cat "$sb_pin_file")" node-b

reset_rc=0
clear_rc=1
sb_disable >/dev/null 2>&1; rc=$?
check 'failed pin removal is reported' "$rc" 1
check 'failed pin removal does not claim success' "$(cat "$sb_pin_file")" node-b

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
