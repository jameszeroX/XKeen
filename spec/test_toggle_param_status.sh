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
eval "$(awk '$0 == "toggle_param() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/04_tools/05_tools_choice/04_choice_input.sh")"

initd_file="$work/S05xkeen"
# shellcheck disable=SC2034
bypass_autostart_msg=yes
# shellcheck disable=SC2034
apply=''
# Console colors are referenced inside the extracted function body.
# shellcheck disable=SC2034
red=''
# shellcheck disable=SC2034
green=''
# shellcheck disable=SC2034
yellow=''
# shellcheck disable=SC2034
light_blue=''
# shellcheck disable=SC2034
reset=''
add_chmod_init() { :; }
fail_mv=false
mv() {
    [ "$fail_mv" = true ] && return 1
    command mv "$@"
}
run_toggle() { toggle_param proxy_dns 'DNS proxy' restart on; }

printf 'start_auto="on"\n' > "$initd_file"
before=$(command cat "$initd_file")
run_toggle >/dev/null 2>&1
check 'missing key returns failure' "$?" 1
check 'missing key leaves init script untouched' "$(command cat "$initd_file")" "$before"

printf 'proxy_dns="off"\nproxy_dns="on"\n' > "$initd_file"
before=$(command cat "$initd_file")
run_toggle >/dev/null 2>&1
check 'duplicate keys return failure' "$?" 1
check 'duplicate keys remain unchanged' "$(command cat "$initd_file")" "$before"

printf 'proxy_dns="on"\n' > "$initd_file"
before=$(command cat "$initd_file")
run_toggle >/dev/null 2>&1
check 'already desired state succeeds' "$?" 0
check 'already desired state is unchanged' "$(command cat "$initd_file")" "$before"

printf 'proxy_dns="off"\n' > "$initd_file"
before=$(command cat "$initd_file")
fail_mv=true
run_toggle >/dev/null 2>&1
rc=$?
fail_mv=false
check 'failed publication returns error' "$rc" 1
check 'failed publication preserves old value' "$(command cat "$initd_file")" "$before"
check 'failed publication removes temporary file' "$( [ -e "$initd_file.tmp" ] && echo yes || echo no )" no

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
