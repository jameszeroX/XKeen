#!/bin/sh
# A false cron-cancel flag with no selected entry must not touch crontab.
set -u

root=${ROOT:-.}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
cron_dir="$work/cron"
cron_file=root
install_dir=/opt/sbin
mkdir -p "$cron_dir" || exit 1
cron_file_path="$cron_dir/$cron_file"

eval "$(awk '/^install_cron\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/02_install/06_install_cron.sh")"

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

printf '%s\n\n' '# user comment' '15 3 * * * /usr/bin/backup' > "$cron_file_path"
chmod 600 "$cron_file_path"
cp "$cron_file_path" "$work/original"
choice_geofile_cron_time=''
choice_cancel_cron_select=false
install_cron
check 'cancel=false and empty selection leave crontab bytes unchanged' "$(cmp -s "$work/original" "$cron_file_path"; echo $?)" 0
check 'cancel=false and empty selection do not create a staging file' "$(find "$cron_dir" -name '*.tmp' -type f | wc -l | tr -d ' ')" 0

rm -f "$cron_file_path"
install_cron
check 'cancel=false and empty selection do not create crontab' "$([ -e "$cron_file_path" ] && echo yes || echo no)" no

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
