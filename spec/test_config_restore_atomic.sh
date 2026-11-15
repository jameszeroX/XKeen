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
        printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"
        fail=$((fail + 1))
    fi
}

. "$root/scripts/_xkeen/04_tools/06_tools_backups/02_backups_configs_xray.sh"
. "$root/scripts/_xkeen/04_tools/06_tools_backups/02_backups_configs_mihomo.sh"
red=''; yellow=''; green=''; reset=''

for core in xray mihomo; do
    backups_dir="$work/$core/backups"
    live_dir="$work/$core/live"
    mkdir -p "$backups_dir/20260101_configs_$core" "$live_dir"
    printf 'restored-visible\n' > "$backups_dir/20260101_configs_$core/visible.json"
    printf 'restored-hidden\n' > "$backups_dir/20260101_configs_$core/.secret"
    printf 'current-visible\n' > "$live_dir/visible.json"
    printf 'current-hidden\n' > "$live_dir/.secret"
    xray_conf_dir=$live_dir
    mihomo_conf_dir=$live_dir

    "restore_backup_configs_$core" >/dev/null 2>&1; rc=$?
    check "$core restore returns success" "$rc" 0
    check "$core restore publishes visible config" "$(cat "$live_dir/visible.json" 2>/dev/null)" restored-visible
    check "$core restore preserves hidden config" "$(cat "$live_dir/.secret" 2>/dev/null)" restored-hidden

    printf 'must-survive-copy-error\n' > "$live_dir/visible.json"
    copy_failure=true
    cp() {
        for _destination do :; done
        case "$_destination" in
            *.restore*)
                command cp "$latest_backup/visible.json" "$_destination/" 2>/dev/null
                return 1
                ;;
        esac
        command cp "$@"
    }
    "restore_backup_configs_$core" >/dev/null 2>&1; rc=$?
    check "$core copy failure returns failure" "$rc" 1
    check "$core copy failure preserves live config" "$(cat "$live_dir/visible.json" 2>/dev/null)" must-survive-copy-error
    unset -f cp

    printf 'must-survive-publish-error\n' > "$live_dir/visible.json"
    mv() {
        case "$1" in
            "$live_dir".restore-*) [ "$2" = "$live_dir" ] && return 1 ;;
        esac
        command mv "$@"
    }
    "restore_backup_configs_$core" >/dev/null 2>&1; rc=$?
    check "$core publish failure returns failure" "$rc" 1
    check "$core publish failure preserves live config" "$(cat "$live_dir/visible.json" 2>/dev/null)" must-survive-publish-error
    unset -f mv
done

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
