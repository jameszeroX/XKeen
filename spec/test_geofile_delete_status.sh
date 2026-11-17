#!/bin/sh
set -u

root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'command rm -rf "$work"' EXIT INT TERM
pass=0
fail=0
geo_dir="$work/geo"
mkdir -p "$geo_dir"
red=""; green=""; yellow=""; reset=""

check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass + 1))
    else
        printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"; fail=$((fail + 1))
    fi
}
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}
eval "$(extract delete_geosite_key "$root/scripts/_xkeen/03_delete/01_delete_geofile.sh")"
eval "$(extract delete_geoip_key "$root/scripts/_xkeen/03_delete/01_delete_geofile.sh")"
eval "$(extract logs_delete_geosite_info_console "$root/scripts/_xkeen/01_info/06_info_console.sh")"
eval "$(extract logs_delete_geoip_info_console "$root/scripts/_xkeen/01_info/06_info_console.sh")"

print_log_status() {
    if [ "$1" = "0" ]; then printf '%s\n' "$2"; else printf '%s\n' "$3"; fi
}
rm() { return 1; }

for file in geosite_refilter.dat geosite_v2fly.dat geosite_zkeen.dat zkeen.dat; do : > "$geo_dir/$file"; done
delete_geosite_key; rc=$?
check 'GeoSite deletion reports filesystem failure' "$rc" 1
output=$(logs_delete_geosite_info_console)
case "$output" in *'Файл zkeen.dat не удален'*) alias_check=yes ;; *) alias_check=no ;; esac
check 'GeoSite verifier checks compatibility alias' "$alias_check" yes

for file in geoip_refilter.dat geoip_v2fly.dat geoip_zkeenip.dat zkeenip.dat; do : > "$geo_dir/$file"; done
delete_geoip_key; rc=$?
check 'GeoIP deletion reports filesystem failure' "$rc" 1
output=$(logs_delete_geoip_info_console)
case "$output" in *'Файл zkeenip.dat не удален'*) alias_check=yes ;; *) alias_check=no ;; esac
check 'GeoIP verifier checks compatibility alias' "$alias_check" yes

check 'CLI handles both GeoSite deletion failure call sites' "$(grep -Fc 'if ! delete_geosite_key; then' "$root/scripts/xkeen")" 2
check 'CLI handles both GeoIP deletion failure call sites' "$(grep -Fc 'if ! delete_geoip_key; then' "$root/scripts/xkeen")" 2

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
