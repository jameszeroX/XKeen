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
eval "$(awk '/^install_cron\(\) \{/,/^}/ { print }' "$root/scripts/_xkeen/02_install/06_install_cron.sh")"

cron_dir="$work/cron"
cron_file=root
install_dir=/opt/bin
choice_geofile_cron_time='0 3 * * *'
choice_cancel_cron_select=true
mkdir -p "$cron_dir"
printf '0 3 * * * /opt/bin/xkeen -ug\n5 4 * * * /opt/bin/xkeen -ugi\n' > "$cron_dir/$cron_file"
original=$(cat "$cron_dir/$cron_file")
fail_mv=true
mv() {
    [ "$fail_mv" = true ] && return 1
    command mv "$@"
}

install_cron
rc=$?
check 'GeoFile cron publish failure is returned' "$rc" 1
check 'failed GeoFile cron publish preserves the previous crontab' "$(cat "$cron_dir/$cron_file")" "$original"

fail_mv=false
install_cron
exact_count=$(grep -c '^0 3 \* \* \* /opt/bin/xkeen -ug$' "$cron_dir/$cron_file")
similar_count=$(grep -c '^5 4 \* \* \* /opt/bin/xkeen -ugi$' "$cron_dir/$cron_file")
check 'successful GeoFile cron publish leaves one exact task' "$exact_count" 1
check 'successful GeoFile cron publish preserves similar command' "$similar_count" 1

block="$work/ugc-block"
awk '/-ugc\)/ { on=1 } on && /-ri\)/ { exit } on { print }' "$root/scripts/xkeen" > "$block"
grep -Fq 'if install_cron; then' "$block"
check '-ugc reports cron write failure instead of unconditional success' "$?" 0
grep -Fq 'Создание или изменение задачи автообновления' "$block"
check '-ugc has a success report only in its success branch' "$?" 0

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
