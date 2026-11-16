#!/bin/sh
# shellcheck disable=SC2154  # Extracted production functions read these globals.
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
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}
eval "$(extract delete_cron_geofile "$root/scripts/_xkeen/03_delete/03_delete_cron.sh")"
eval "$(extract install_cron "$root/scripts/_xkeen/02_install/06_install_cron.sh")"

# shellcheck disable=SC2034
cron_dir="$work/cron"
mkdir -p "$cron_dir"
# shellcheck disable=SC2034
cron_file='root'
# shellcheck disable=SC2034
install_dir='/opt/sbin'
cron_file_path="$cron_dir/$cron_file"
fixture() {
    cat > "$cron_file_path" <<'EOF'
0 0 * * * /opt/sbin/xkeen -ug
0 1 * * * /opt/sbin/xkeen -ugi
0 2 * * * /opt/sbin/xkeen -ugs
0 3 * * * /opt/sbin/xkeen-helper -ug
# keep comment mentioning /opt/sbin/xkeen -ug
EOF
}

fixture
delete_cron_geofile
check 'delete removes exact -ug command' "$(awk '$6 == "/opt/sbin/xkeen" && $7 == "-ug" { n++ } END { print n + 0 }' "$cron_file_path")" 0
check 'delete preserves similar commands and comment' "$(grep -Ec 'xkeen -ugi|xkeen -ugs|xkeen-helper -ug|^# keep comment' "$cron_file_path")" 4

fixture
# Consumed by the dynamically extracted install_cron function.
# shellcheck disable=SC2034
choice_geofile_cron_time='5 0 * * *'
# shellcheck disable=SC2034
choice_cancel_cron_select=1
install_cron
check 'install replaces prior exact -ug command once' "$(awk '$6 == "/opt/sbin/xkeen" && $7 == "-ug" { n++ } END { print n + 0 }' "$cron_file_path")" 1
check 'install preserves similar commands and comment' "$(grep -Ec 'xkeen -ugi|xkeen -ugs|xkeen-helper -ug|^# keep comment' "$cron_file_path")" 4
check 'new schedule is published' "$(awk '$1 == 5 && $2 == 0 && $3 == "*" && $4 == "*" && $5 == "*" && $6 == "/opt/sbin/xkeen" && $7 == "-ug" { n++ } END { print n + 0 }' "$cron_file_path")" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
