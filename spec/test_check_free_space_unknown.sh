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
eval "$(awk '$0 == "check_free_space() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/05_tests/03_tests_storage.sh")"

# Globals consumed by the extracted production function.
# shellcheck disable=SC2034
target_dir="$work"
# shellcheck disable=SC2034
xray_free_space=50
# shellcheck disable=SC2034
mihomo_free_space=100
# shellcheck disable=SC2034
autoinstall_mode=true
# These color variables are interpolated by the extracted production function.
# shellcheck disable=SC2034
red=''
# shellcheck disable=SC2034
yellow=''
# shellcheck disable=SC2034
light_blue=''
# shellcheck disable=SC2034
green=''
# shellcheck disable=SC2034
reset=''
smart_clear() { :; }
df_mode=good
df() {
    case "$df_mode" in
        fail) return 1 ;;
        empty) return 0 ;;
        invalid) printf 'Filesystem 1M-blocks Used Available Use%% Mounted on\n/dev/test 100 20 unknown 20%% /opt\n' ;;
        low) printf 'Filesystem 1M-blocks Used Available Use%% Mounted on\n/dev/test 100 80 20 80%% /opt\n' ;;
        good) printf 'Filesystem 1M-blocks Used Available Use%% Mounted on\n/dev/test 100 20 80 20%% /opt\n' ;;
    esac
}

check_free_space xray >/dev/null 2>&1
check 'sufficient free space proceeds' "$?" 0

df_mode=fail
check_free_space xray >/dev/null 2>&1
check 'df failure blocks automatic install' "$?" 1

df_mode=empty
check_free_space xray >/dev/null 2>&1
check 'empty df output blocks automatic install' "$?" 1

df_mode=invalid
check_free_space xray >/dev/null 2>&1
check 'nonnumeric free space blocks automatic install' "$?" 1

df_mode=low
check_free_space xray >/dev/null 2>&1
check 'known insufficient space still blocks automatic install' "$?" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
