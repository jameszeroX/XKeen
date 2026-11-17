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
file="$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh"
eval "$(extract proxy_stop "$file")"
red=''
reset=''
name_client=xray
xkeen_rundir="$work/run"
mkdir -p "$xkeen_rundir"
start_attempts=1
daemon_running=true
kill_count=0
cleanup_count=0
touch "$xkeen_rundir/ready"
_acquire_proxy_mutex() { return 2; }
_release_proxy_mutex() { :; }
proxy_status() { [ "$daemon_running" = true ]; }
cleanup_fd_monitor() { cleanup_count=$((cleanup_count + 1)); }
clean_firewall() { return 1; }
killall() { kill_count=$((kill_count + 1)); daemon_running=false; }
pidof() { [ "$daemon_running" = true ]; }
usleep() { :; }
log_info_router() { :; }
log_error_terminal() { :; }
log_warning_terminal() { :; }
_release_coldstart_guard() { :; }
proxy_stop >/dev/null 2>&1
stop_rc=$?
check 'stop reports firewall cleanup failure' "$stop_rc" 1
check 'stop preserves the running core when cleanup failed' "$daemon_running" true
check 'stop does not kill a core without cleaning firewall' "$kill_count" 0
check 'stop preserves the readiness marker when cleanup failed' "$( [ -e "$xkeen_rundir/ready" ] && echo present || echo missing )" present
check 'stop keeps the fd monitor when cleanup failed' "$cleanup_count" 0

daemon_running=false
cleanup_count=0
touch "$xkeen_rundir/ready"
proxy_stop >/dev/null 2>&1
stop_rc=$?
check 'stop reports cleanup failure when the core is already down' "$stop_rc" 1
check 'stop keeps the readiness marker until firewall cleanup succeeds' "$( [ -e "$xkeen_rundir/ready" ] && echo present || echo missing )" present
check 'stop cleans the fd monitor only after firewall cleanup' "$cleanup_count" 0
printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

