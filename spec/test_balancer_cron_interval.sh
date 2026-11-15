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
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}
control="$root/scripts/_xkeen/04_tools/08_tools_balancer/02_balancer_control.sh"
eval "$(extract sb_install_cron "$control")"
if [ -n "$(awk -v name=sb_tick_if_due '$0 == name "() {" {found=1} END {if (found) print "yes"}' "$control")" ]; then
    eval "$(extract sb_tick_if_due "$control")"
else
    sb_tick_if_due() { return 127; }
fi

cron_dir="$work/cron"
cron_file=root
install_dir="$work/sbin"
mkdir -p "$cron_dir" "$install_dir"
sb_interval=40
sb_install_cron
check 'cron schedules the inexpensive minute guard' "$(grep -c '^\* \* \* \* \* .*xkeen -sbtx$' "$cron_dir/$cron_file")" 1

tick_calls=0
sb_tick() { tick_calls=$((tick_calls + 1)); return 0; }
sb_interval=40
sb_tick_if_due 2400; check '40-minute boundary runs' "$tick_calls" 1
sb_tick_if_due 2460; check '40-minute interval does not drift at hour' "$tick_calls" 1
sb_tick_if_due 4800; check '40-minute interval repeats exactly' "$tick_calls" 2
sb_interval=45
sb_tick_if_due 2700; check '45-minute boundary runs' "$tick_calls" 3
sb_tick_if_due 5400; check '45-minute interval repeats exactly' "$tick_calls" 4
sb_interval=60
sb_tick_if_due 3600; check '60-minute interval runs hourly' "$tick_calls" 5
sb_interval=90
sb_tick_if_due 5400; check 'interval over 60 minutes is supported' "$tick_calls" 6
sb_tick_if_due 5460; check 'interval over 60 minutes does not run every hour' "$tick_calls" 6

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
