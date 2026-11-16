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
        printf 'FAIL %s\n       expected [%s]\n       got      [%s]\n' "$1" "$3" "$2"
        fail=$((fail + 1))
    fi
}
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/02_install/05_install_geoipset.sh"
}
eval "$(extract load_geoipset)"

rundir="$work/run"
fixture="$work/geoip.lst"
mkdir -p "$rundir"
printf '192.0.2.0/24\n' > "$fixture"
_xkeen_secure_rundir() { printf '%s' "$rundir"; }
fail_create=false
ipset() {
    case "$1" in
        create) [ "$fail_create" = false ] ;;
        restore) cat >/dev/null; return 0 ;;
        *) return 0 ;;
    esac
}
trap 'trap_marker=original-int' INT
trap 'trap_marker=original-term' TERM
trap 'trap_marker=original-exit' EXIT
trap > "$work/traps.before.success"
load_geoipset geo_test "$fixture" inet
trap > "$work/traps.after.success"
check 'success restores every caller trap' "$(cmp -s "$work/traps.before.success" "$work/traps.after.success"; echo $?)" 0

fail_create=true
trap 'trap_marker=original-int' INT
trap 'trap_marker=original-term' TERM
trap 'trap_marker=original-exit' EXIT
trap > "$work/traps.before.failure"
load_geoipset geo_test "$fixture" inet
load_rc=$?
trap > "$work/traps.after.failure"
check 'injected loader failure is reported' "$load_rc" 1
check 'failure restores every caller trap' "$(cmp -s "$work/traps.before.failure" "$work/traps.after.failure"; echo $?)" 0

trap - EXIT INT TERM
rm -rf "$work"
printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
