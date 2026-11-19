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
file="$root/scripts/xkeen"
eval "$(awk '/^restart_proxy_after_update\(\) \{/,/^}/ { print }' "$file")"
is_proxy_running() { [ "$proxy_running" = true ]; }
restart_rc=1
initd_file=mock_initd
mock_initd() { [ "$restart_rc" -eq 0 ]; }

proxy_running=true
restart_proxy_after_update >/dev/null 2>&1
check 'active proxy restart failure is returned' "$?" 1

restart_rc=0
restart_proxy_after_update >/dev/null 2>&1
check 'successful active proxy restart succeeds' "$?" 0

proxy_running=false
restart_rc=1
restart_proxy_after_update >/dev/null 2>&1
check 'update with no active proxy needs no restart' "$?" 0

block="$work/update-block"
awk '/-uk_post_update\)/ { on=1 } on && /-ux\)/ { exit } on { print }' "$file" > "$block"
grep -Fq 'restart_proxy_after_update || {' "$block" && grep -Fq 'xkeen_rc=1' "$block"
check 'post-update branch propagates restart failure' "$?" 0
grep -Fq 'if [ "$_update_restart_failed" = "true" ]; then' "$block"
check 'post-update success message is conditional on restart result' "$?" 0

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
