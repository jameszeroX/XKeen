#!/bin/sh
set -u

root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
pass=0
fail=0
extract_restart_branch() {
    awk '
        /^    restart\)/ { in_restart=1; next }
        in_restart && /^    cold_start\)/ { exit }
        in_restart && /^        ;;$/ { next }
        in_restart { print }
    ' "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh"
}
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"
        pass=$((pass + 1))
    else
        printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"
        fail=$((fail + 1))
    fi
}
eval "restart_sequence() { $(extract_restart_branch); }"

# Values are consumed by the extracted restart case branch.
# shellcheck disable=SC2034
killswitch=on
file_netfilter_hook="$work/hook.sh"
printf "mode_proxy='TProxy'\n" > "$file_netfilter_hook"
# shellcheck disable=SC2034
mode_proxy=TProxy
keep_killswitch=off
proxy_stop_count=0
proxy_start_count=0
enable_result=1
proxy_status() { return 0; }
get_ipver_support() { :; }
_ks_load_marks_from_hook() { return 0; }
enable_killswitch() { return "$enable_result"; }
proxy_stop() { proxy_stop_count=$((proxy_stop_count + 1)); return 0; }
proxy_start() { proxy_start_count=$((proxy_start_count + 1)); return 0; }
log_error_router() { :; }
log_warning_router() { :; }
# shellcheck disable=SC2034
yellow=''
# shellcheck disable=SC2034
green=''
# shellcheck disable=SC2034
reset=''
# shellcheck disable=SC2034
red=''

restart_sequence restart on
# shellcheck disable=SC2154
check 'failed hold setup fails the restart command' "$_cmd_rc" 1
check 'failed hold setup keeps the old proxy running' "$proxy_stop_count/$proxy_start_count" 0/0
check 'failed hold setup does not claim to keep a hold rule' "$keep_killswitch" off

enable_result=0
proxy_stop_count=0
proxy_start_count=0
keep_killswitch=off
restart_sequence restart on
check 'successful hold setup proceeds with restart' "$_cmd_rc/$proxy_stop_count/$proxy_start_count" 0/1/1
check 'successful hold setup is retained through stop' "$keep_killswitch" on

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
