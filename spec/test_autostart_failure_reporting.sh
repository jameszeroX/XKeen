#!/bin/sh
# Explicit auto-install autostart failures must affect the final install status.
set -u

root=${ROOT:-.}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
initd_file="$work/S05xkeen"
printf '%s\n' 'start_auto="on"' > "$initd_file"
autoinstall_mode=true
auto_autostart_set=true
auto_autostart=on
auto_failed=''
xkeen_rc=0
green=''
light_blue=''
reset=''
red=''
yellow=''
bypass_autostart_msg=''

change_autostart_xkeen() { return "${CHANGE_AUTOSTART_RC:-0}"; }
choice_menu() { return 0; }

eval "$(awk '/^choice_autostart_xkeen\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/04_tools/05_tools_choice/02_choice_xkeen.sh")"

# Reuse the final result aggregation from the full -i installation path.
eval "apply_auto_failed_status() {
$(awk '/if \[ -n "\$auto_failed" \]; then/,/^[[:space:]]*fi$/ { print }' "$root/scripts/xkeen" | tail -n 5)
}"

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

CHANGE_AUTOSTART_RC=1
export CHANGE_AUTOSTART_RC
choice_autostart_xkeen >/dev/null 2>&1
apply_auto_failed_status >/dev/null 2>&1
check 'failed requested setting is recorded' "$(case "$auto_failed" in *autostart*) echo yes ;; *) echo no ;; esac)" yes
check 'failed requested setting reaches final installer status' "$xkeen_rc" 1

auto_failed=''
xkeen_rc=0
CHANGE_AUTOSTART_RC=0
choice_autostart_xkeen >/dev/null 2>&1
apply_auto_failed_status >/dev/null 2>&1
check 'successful setting is not recorded as a failure' "$auto_failed" ''

auto_failed=''
xkeen_rc=0
auto_autostart_set=''
printf '%s\n' 'start_auto="off"' > "$initd_file"
choice_autostart_xkeen >/dev/null 2>&1
apply_auto_failed_status >/dev/null 2>&1
check 'preserved disabled setting is not treated as an error' "$auto_failed" ''
check 'preserved disabled setting does not fail installation' "$xkeen_rc" 0

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
