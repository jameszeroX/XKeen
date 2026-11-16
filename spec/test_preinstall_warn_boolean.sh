#!/bin/sh
# shellcheck disable=SC2154  # Production function reads these shell globals.
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
eval "$(awk '$0 == "preinstall_warn() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/05_tests/03_tests_storage.sh")"

# shellcheck disable=SC2034
autoinstall_mode=true
# shellcheck disable=SC2034
entware_storage='on internal storage'
# The extracted function interpolates these colors and reads its same-named flag.
# shellcheck disable=SC2034
red=''
# shellcheck disable=SC2034
green=''
# shellcheck disable=SC2034
reset=''
# shellcheck disable=SC2034
yellow=''
# shellcheck disable=SC2034
preinstall_warn=false
output=$(preinstall_warn)
check 'false suppresses storage warning' "$output" ''

preinstall_warn=true
output=$(preinstall_warn)
case "$output" in
    *'Внимание'*) warn=shown ;;
    *) warn=missing ;;
esac
check 'true retains storage warning' "$warn" shown

# shellcheck disable=SC2034
preinstall_warn=''
output=$(preinstall_warn)
check 'empty value suppresses storage warning' "$output" ''

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
