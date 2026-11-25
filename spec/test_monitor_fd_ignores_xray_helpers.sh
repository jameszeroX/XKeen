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

file="$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh"
eval "$(awk '$0 == "proxy_process_pids() {" { on=1 } on { print } on && /^}/ { exit }' "$file")"
# shellcheck disable=SC2016
eval "$(awk '$0 == "monitor_fd() {" { on=1 } on { print } on && /^}/ { exit }' "$file" \
    | sed 's#/proc/#$xkeen_proc_root/#g')"

xkeen_proc_root="$work/proc"
name_client=xray
delay_fd=1
file_pid_fd="$work/fd-monitor.pid"
restart_marker="$work/restarted"
export name_client delay_fd file_pid_fd xkeen_proc_root
mkdir -p "$xkeen_proc_root/111/fd" "$xkeen_proc_root/222/fd"
printf 'xray\0api\0bi\0' > "$xkeen_proc_root/111/cmdline"
printf 'xray\0run\0-config\0/tmp/config.json\0' > "$xkeen_proc_root/222/cmdline"
printf 'Max open files 10 10 10 files\n' > "$xkeen_proc_root/111/limits"
printf 'Max open files 1000 1000 1000 files\n' > "$xkeen_proc_root/222/limits"
i=1
while [ "$i" -le 10 ]; do : > "$xkeen_proc_root/111/fd/$i"; i=$((i + 1)); done
: > "$xkeen_proc_root/222/fd/1"

pidof() { [ "$1" = xray ] && printf '111 222\n'; }
log_router() { echo warning > "$restart_marker"; }
proxy_stop() { echo stop >> "$restart_marker"; }
proxy_start() { echo start >> "$restart_marker"; }
sleep() { exit 0; }

( monitor_fd )
check 'helper process does not trigger restart' "$(test -e "$restart_marker" && echo restarted || echo running)" running

i=2
while [ "$i" -le 901 ]; do : > "$xkeen_proc_root/222/fd/$i"; i=$((i + 1)); done
( monitor_fd )
check 'main daemon still triggers restart above threshold' "$(cat "$restart_marker" | tr '\n' ' ' | sed 's/ $//')" 'warning stop start'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
