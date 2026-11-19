#!/bin/sh
# shellcheck disable=SC2034,SC2329  # Globals and stubs are read by extracted production functions.
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
file="$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh"
eval "$(awk '/^write_schedule_hook\(\) \{/,/^}/ { print }' "$file")"

file_schedule_hook="$work/ndm/schedule.d/00-xkeen.sh"
mkdir -p "$(dirname "$file_schedule_hook")"
printf 'old hook\n' > "$file_schedule_hook"
fail_mv=true
mv_calls=0
mv() {
    mv_calls=$((mv_calls + 1))
    [ "$fail_mv" = true ] && return 1
    command mv "$@"
}
fail_chmod=false
chmod() {
    [ "$fail_chmod" = true ] && return 1
    command chmod "$@"
}

write_schedule_hook
rc=$?
check 'schedule hook publish failure is returned' "$rc" 1
check 'failed schedule hook publish preserves previous file' "$(cat "$file_schedule_hook")" 'old hook'
check 'failed schedule hook publish removes staging file' "$( [ -e "$file_schedule_hook.tmp.$$" ] && echo present || echo absent )" absent

fail_mv=false
fail_chmod=true
write_schedule_hook
rc=$?
check 'schedule hook chmod failure is returned' "$rc" 1
check 'chmod failure preserves previous file' "$(cat "$file_schedule_hook")" 'old hook'

fail_chmod=false
write_schedule_hook
check 'schedule hook installs after successful staging' "$( [ -f "$file_schedule_hook" ] && echo present || echo absent )" present
check 'schedule hook contains expected trigger' "$(grep -Fxc '[ "$1" = "start" ] || [ "$1" = "stop" ] || exit 0' "$file_schedule_hook")" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
