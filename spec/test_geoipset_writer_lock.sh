#!/bin/sh
set -u

root=${ROOT:-/repo}
register_source=${REGISTER_SOURCE:-$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh}
work=$(mktemp -d) || exit 1
lock_owner_pid=''
cleanup() {
    [ -z "$lock_owner_pid" ] || kill "$lock_owner_pid" 2>/dev/null
    rm -rf "$work"
}
trap cleanup EXIT INT TERM
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
eval "$(extract _acquire_geoipset_lock "$register_source")"
eval "$(extract _release_geoipset_lock "$register_source")"
eval "$(extract _filter_ip_cidr_family "$register_source")"
eval "$(extract load_ipset "$register_source")"

xkeen_rundir="$work/run"
fixture="$work/ips.lst"
mkdir -p "$xkeen_rundir" "$xkeen_rundir/geoipset.lock.d"
printf '192.0.2.0/24\n' > "$fixture"
active="$work/geo_exclude"
printf '10.0.0.0/8\n' > "$active"
printf '%s\n' "$$" > "$xkeen_rundir/geoipset.lock.d/pid.marker"
sleep 60 &
lock_owner_pid=$!
printf '%s\n' "$lock_owner_pid" > "$xkeen_rundir/geoipset.lock.d/pid"
usleep() { return 0; }
ipset_calls=0
ipset() { ipset_calls=$((ipset_calls + 1)); return 0; }

load_ipset geo_exclude "$fixture" inet
busy_rc=$?
check 'runtime load refuses concurrent install/cron lock' "$busy_rc" 1
check 'runtime load does not reach ipset while lock is held' "$ipset_calls" 0
check 'live shared lock remains present' "$( [ -f "$xkeen_rundir/geoipset.lock.d/pid.marker" ] && echo present || echo missing )" present

kill "$lock_owner_pid" 2>/dev/null
wait "$lock_owner_pid" 2>/dev/null
lock_owner_pid=''
rm -rf "$xkeen_rundir/geoipset.lock.d"
load_ipset geo_exclude "$fixture" inet
success_rc=$?
check 'runtime load works after shared lock clears' "$success_rc" 0
check 'runtime load releases its lock after publication' "$( [ -e "$xkeen_rundir/geoipset.lock.d" ] && echo present || echo absent )" absent

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
