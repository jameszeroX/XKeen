#!/bin/sh
set -u

root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'command rm -rf "$work"' EXIT INT TERM
pass=0
fail=0

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
eval "$(extract geofiles_update_needed "$root/scripts/xkeen")"
eval "$(extract restart_active_proxy_after_geofile_update "$root/scripts/xkeen")"

update_refilter_geosite=false; update_v2fly_geosite=false; update_zkeen_geosite=false
update_refilter_geoip=false; update_v2fly_geoip=false; update_zkeenip_geoip=false
has_user_geodata=false
ru_exclude_ipv4="$work/ru4.lst"
ru_exclude_ipv6="$work/ru6.lst"
: > "$ru_exclude_ipv6"
geofiles_update_needed; rc=$?
check 'IPv6-only GeoIPSET triggers -ug work' "$rc" 0

rm -f "$ru_exclude_ipv6"
geofiles_update_needed; rc=$?
check 'no installed geodata returns no-work status' "$rc" 1

initd_file="$work/initd"
printf '#!/bin/sh\nexit 1\n' > "$initd_file"
chmod +x "$initd_file"
pidof() { return 0; }
restart_active_proxy_after_geofile_update >/dev/null 2>&1
rc=$?
check 'active-core restart failure reaches -ug caller' "$rc" 1

grep -Fq 'if geofiles_update_needed; then' "$root/scripts/xkeen"
check '-ug uses the IPv6-aware work gate' "$?" 0
grep -Fq 'restart_active_proxy_after_geofile_update' "$root/scripts/xkeen"
check '-ug reports failed restart instead of unconditional success' "$?" 0
grep -Fq 'install_geosite || geofile_update_status=1' "$root/scripts/xkeen"
check '-ug propagates built-in GeoSite failures' "$?" 0
grep -Fq 'install_geoip || geofile_update_status=1' "$root/scripts/xkeen"
check '-ug propagates built-in GeoIP failures' "$?" 0

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
