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
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}
file="$root/scripts/_xkeen/04_tools/08_tools_balancer/02_balancer_control.sh"
eval "$(extract sb_install_cron "$file")"
eval "$(extract sb_remove_cron "$file")"
eval "$(extract sb_disable_locked "$file")"

cron_dir="$work/cron"
cron_file=root
install_dir=/opt/bin
mkdir -p "$cron_dir"
printf '* * * * * /opt/bin/xkeen -sbt-old\n' > "$cron_dir/$cron_file"
printf '* * * * * /opt/bin/xkeen -sbtx\n' >> "$cron_dir/$cron_file"
fail_mv=true
mv() {
    [ "$fail_mv" = true ] && return 1
    command mv "$@"
}
original=$(cat "$cron_dir/$cron_file")

sb_install_cron
install_rc=$?
check 'balancer cron install reports failed publish' "$install_rc" 1
check 'balancer cron install preserves original file after failed publish' "$(cat "$cron_dir/$cron_file")" "$original"

fail_mv=false
sb_install_cron
install_count=$(grep -c '/opt/bin/xkeen -sbtx$' "$cron_dir/$cron_file")
similar_count=$(grep -c '/opt/bin/xkeen -sbt-old$' "$cron_dir/$cron_file")
check 'balancer cron install replaces its exact command once' "$install_count" 1
check 'balancer cron install preserves similar command' "$similar_count" 1

printf '* * * * * /opt/bin/xkeen -sbt-old\n' > "$cron_dir/$cron_file"
printf '* * * * * /opt/bin/xkeen -sbtx\n' >> "$cron_dir/$cron_file"
original=$(cat "$cron_dir/$cron_file")
fail_mv=true
sb_remove_cron
remove_rc=$?
check 'balancer cron removal reports failed publish' "$remove_rc" 1
check 'balancer cron removal preserves original file after failed publish' "$(cat "$cron_dir/$cron_file")" "$original"

fail_mv=false
sb_remove_cron
remove_count=$(grep -c '/opt/bin/xkeen -sbtx$' "$cron_dir/$cron_file")
similar_count=$(grep -c '/opt/bin/xkeen -sbt-old$' "$cron_dir/$cron_file")
check 'balancer cron removal removes exact task' "$remove_count" 0
check 'balancer cron removal preserves similar command' "$similar_count" 1

speed_balancer_settings() { :; }
sb_cron_installed() { return 0; }
xray() { return 0; }
sb_pin_clear() { return 0; }
sb_remove_cron() { return 1; }
setting_written=''
sb_write_setting() { setting_written="$2"; return 0; }
sb_enabled=true
sb_pin_file="$work/no-pin"
sb_api_addr=127.0.0.1:1
sb_balancer=balancer
red=''; green=''; yellow=''; reset=''
sb_disable_locked >/dev/null 2>&1
disable_rc=$?
check 'balancer disable reports failed cron removal' "$disable_rc" 1
check 'failed cron removal keeps enabled setting unchanged' "$setting_written" ''

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
