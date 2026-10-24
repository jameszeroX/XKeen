#!/bin/sh
pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then printf 'OK   %s\n' "$1"; pass=$((pass + 1));
    else printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"; fail=$((fail + 1)); fi
}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
. /repo/scripts/_xkeen/04_tools/06_tools_backups/02_backups_configs_xray.sh
. /repo/scripts/_xkeen/04_tools/06_tools_backups/02_backups_configs_mihomo.sh
cp() {
    if [ "$copy_failure" = true ]; then
        for destination do :; done
        command cp "$source_dir/01_config" "$destination/"
        return 1
    fi
    command cp "$@"
}
for core in xray mihomo; do
    source_dir="$work/$core/live"
    backups_dir="$work/$core/backups"
    mkdir -p "$source_dir" "$backups_dir/20000101_configs_$core"
    printf 'complete-one\n' > "$source_dir/01_config"
    printf 'complete-two\n' > "$source_dir/04_outbounds"
    command cp "$source_dir/"* "$backups_dir/20000101_configs_$core/"
    xray_conf_dir=$source_dir
    mihomo_conf_dir=$source_dir
    current_datetime=20990101
    copy_failure=true
    "backup_configs_$core" >/dev/null; rc=$?
    check "$core failed backup reports failure" "$rc" 1
    check "$core partial backup is not published" "$([ -e "$backups_dir/20990101_configs_$core" ] && echo yes || echo no)" no
    check "$core partial staging removed" "$(find "$backups_dir" -name '.backup-*' | wc -l | tr -d ' ')" 0
    copy_failure=false
    "restore_backup_configs_$core" >/dev/null
    check "$core restore keeps all complete files" "$(cat "$source_dir/04_outbounds")" complete-two
    "backup_configs_$core" >/dev/null
    check "$core complete backup published" "$(cat "$backups_dir/20990101_configs_$core/04_outbounds")" complete-two
    printf 'replacement\n' > "$source_dir/04_outbounds"
    "backup_configs_$core" >/dev/null; rc=$?
    check "$core existing backup is not overwritten" "$rc:$(cat "$backups_dir/20990101_configs_$core/04_outbounds")" 1:complete-two
 done
. /repo/scripts/_xkeen/04_tools/06_tools_backups/01_backups_xkeen.sh
install_dir="$work/sbin"
backups_dir="$work/xkeen-backups"
mkdir -p "$install_dir/.xkeen" "$backups_dir"
printf module > "$install_dir/.xkeen/import.sh"
printf wrapper > "$install_dir/xkeen"
manual_backup=true
xkeen_current_version=2.1
current_datetime=20990101
choice_backup_xkeen() { return 1; }
copy_failure=true
source_dir=$install_dir
printf partial > "$source_dir/01_config"
backup_xkeen >/dev/null; rc=$?
check 'XKeen partial backup is not published' "$rc:$([ -e "$backups_dir/20990101_xkeen_v2.1" ] && echo yes || echo no)" 1:no
copy_failure=false
backup_xkeen >/dev/null
check 'XKeen complete layout published' "$(cat "$backups_dir/20990101_xkeen_v2.1/_xkeen/import.sh"):$(cat "$backups_dir/20990101_xkeen_v2.1/xkeen")" module:wrapper
printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
