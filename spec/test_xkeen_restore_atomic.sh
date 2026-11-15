#!/bin/sh
set -u

root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
red=''; yellow=''; green=''; reset=''
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
. "$root/scripts/_xkeen/04_tools/06_tools_backups/01_backups_xkeen.sh"

prepare_case() {
    case_dir="$work/$1"
    install_dir="$case_dir/live"
    backups_dir="$case_dir/backups"
    latest_backup_dir="$backups_dir/20260101_xkeen_v2.0"
    mkdir -p "$install_dir/.xkeen" "$latest_backup_dir/_xkeen"
    printf 'old-wrapper\n' > "$install_dir/xkeen"
    printf 'old-module\n' > "$install_dir/.xkeen/import.sh"
    printf 'new-wrapper\n' > "$latest_backup_dir/xkeen"
    printf 'new-module\n' > "$latest_backup_dir/_xkeen/import.sh"
}

prepare_case copy-failure
cp() {
    if [ "$copy_failure" = true ]; then
        if [ "$1" = -f ] || [ "$1" = -p ]; then
            _source=$2
            _destination=$3
            case "$_destination" in */) _destination="${_destination}xkeen" ;; esac
            command cp "$_source" "$_destination"
            return 1
        fi
    fi
    command cp "$@"
}
copy_failure=true
restore_backup_xkeen >/dev/null 2>&1; rc=$?
check 'partial wrapper copy reports failure' "$rc" 1
check 'copy failure preserves old wrapper' "$(cat "$install_dir/xkeen" 2>/dev/null)" old-wrapper
check 'copy failure preserves old modules' "$(cat "$install_dir/.xkeen/import.sh" 2>/dev/null)" old-module
unset -f cp

prepare_case publish-failure
mv_fail_once=true
mv() {
    if [ "$mv_fail_once" = true ] && [ "$2" = "$install_dir/.xkeen" ]; then
        mv_fail_once=false
        return 1
    fi
    command mv "$@"
}
restore_backup_xkeen >/dev/null 2>&1; rc=$?
check 'module publication failure reports failure' "$rc" 1
check 'publication failure preserves old wrapper' "$(cat "$install_dir/xkeen" 2>/dev/null)" old-wrapper
check 'publication failure preserves old modules' "$(cat "$install_dir/.xkeen/import.sh" 2>/dev/null)" old-module
unset -f mv

prepare_case success
restore_backup_xkeen >/dev/null 2>&1; rc=$?
check 'successful pair restore returns success' "$rc" 0
check 'successful pair restore publishes new wrapper' "$(cat "$install_dir/xkeen" 2>/dev/null)" new-wrapper
check 'successful pair restore publishes new modules' "$(cat "$install_dir/.xkeen/import.sh" 2>/dev/null)" new-module

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
