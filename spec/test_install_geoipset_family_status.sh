#!/bin/sh
# shellcheck disable=SC2034,SC2154  # Extracted production function reads and assigns these globals.
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
eval "$(awk '$0 == "install_geoipset() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/02_install/05_install_geoipset.sh")"

ipset_cfg="$work/ipset"
mkdir -p "$ipset_cfg"
ru_exclude_ipv4="$ipset_cfg/ipv4.lst"
ru_exclude_ipv6="$ipset_cfg/ipv6.lst"
ru_override="$ipset_cfg/override.lst"
geoipv4_url='https://example.test/ipv4'
geoipv6_url='https://example.test/ipv6'
printf 'old\n' > "$ru_exclude_ipv4"
printf 'old\n' > "$ru_exclude_ipv6"
yellow=''
green=''
reset=''
action=update
autoinstall_mode=false
auto_geoipset=on
bypass_cron_geoipset=false
ip() { printf '    inet 192.0.2.1/24\n'; }
iptables() { :; }
ip6tables() { :; }
ipv6_enabled=true
check_ipv6_active() { [ "$ipv6_enabled" = true ]; }
fail_download=''
fail_load=''
download_calls=''
load_calls=''
install_geoipset_lst() {
    download_calls="$download_calls $2"
    [ "$2" != "$fail_download" ]
}
load_geoipset() {
    load_calls="$load_calls $1"
    [ "$1" != "$fail_load" ]
}
run_case() {
    fail_download="$1"
    fail_load="$2"
    ipv6_enabled="$3"
    download_calls=''
    load_calls=''
    install_geoipset update >/dev/null 2>&1
    case_rc=$?
}

run_case "$ru_exclude_ipv6" '' true
check 'IPv4 pass and IPv6 download failure returns failure' "$case_rc" 1
check 'IPv4 success does not hide IPv6 failure' "$download_calls" " $ru_exclude_ipv4 $ru_exclude_ipv6"

run_case "$ru_exclude_ipv4" '' true
check 'IPv4 failure and IPv6 pass returns failure' "$case_rc" 1

run_case '' '' true
check 'both family updates succeed' "$case_rc" 0

run_case '' geo_exclude6 true
check 'load failure also propagates' "$case_rc" 1

run_case '' '' false
check 'disabled IPv6 does not fail or call IPv6 downloader' "$case_rc:$download_calls:$load_calls" "0: $ru_exclude_ipv4: geo_exclude"

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
