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
eval "$(awk '$0 == "start() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/02_install/07_install_register/03_register_cron.sh")"
eval "$(awk '$0 == "restart() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/02_install/07_install_register/03_register_cron.sh")"

# Values consumed by the extracted generated init function.
# shellcheck disable=SC2034
red=''
# shellcheck disable=SC2034
green=''
# shellcheck disable=SC2034
yellow=''
# shellcheck disable=SC2034
reset=''
# shellcheck disable=SC2034
cron_initd=mock_crond
running=false
launch_rc=0
daemonizes=true
launch_calls=0
cron_status() { [ "$running" = true ]; }
mock_crond() {
    launch_calls=$((launch_calls + 1))
    [ "$launch_rc" = 0 ] || return "$launch_rc"
    [ "$daemonizes" = true ] && running=true
    return 0
}
sleep() { :; }
stop() { :; }

launch_rc=1
output=$(start 2>&1)
rc=$?
check 'crond process failure returns error' "$rc" 1
case "$output" in *'запущен'*) started=misreported ;; *) started=not-reported ;; esac
check 'failed start is not reported as running' "$started" not-reported

launch_rc=0
daemonizes=false
output=$(start 2>&1)
rc=$?
check 'missing daemon after successful launcher returns error' "$rc" 1
case "$output" in *'запущен'*) started=misreported ;; *) started=not-reported ;; esac
check 'missing process is not reported as running' "$started" not-reported

daemonizes=true
output=$(start 2>&1)
rc=$?
check 'successful start returns success' "$rc" 0
case "$output" in *'запущен'*) started=reported ;; *) started=missing ;; esac
check 'successful start reports process state' "$started" reported

running=false
launch_rc=1
output=$(restart 2>&1)
rc=$?
check 'restart propagates failed start' "$rc" 1
case "$output" in *'перезапущен'*) restarted=misreported ;; *) restarted=not-reported ;; esac
check 'restart does not claim success after failed start' "$restarted" not-reported
check 'initd template version is bumped for existing installations' "$(grep -c 'required_script_version="0.7"' "$root/scripts/_xkeen/02_install/07_install_register/03_register_cron.sh")" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
