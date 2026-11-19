#!/bin/sh
# shellcheck disable=SC2034,SC2329
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
    awk '$0 == "install_geoipset() {" { on=1 } on { print } on && /^}/ { exit }' \
        "$root/scripts/_xkeen/02_install/05_install_geoipset.sh"
}
eval "$(extract)"

ipset_cfg="$work/ipset"
ru_exclude_ipv4="$ipset_cfg/ru-v4.txt"
ru_exclude_ipv6="$ipset_cfg/ru-v6.txt"
ru_override="$ipset_cfg/ru-override.txt"
geoipv4_url=unused
geoipv6_url=unused
autoinstall_mode=true
auto_geoipset=on
red=''; green=''; yellow=''; reset=''
mkdir -p "$ipset_cfg"
touch "$ru_exclude_ipv4" "$ru_exclude_ipv6" "$ru_override"

ipv4_on=true
ipv6_on=false
fail_download_file=''
fail_load_set=''
download_calls=''
load_calls=''
ip() { [ "$ipv4_on" = true ] && printf 'inet 192.0.2.1/24\n'; }
iptables() { return 0; }
ip6tables() { return 0; }
check_ipv6_active() { [ "$ipv6_on" = true ]; }
install_geoipset_lst() {
    download_calls="$download_calls $2"
    [ "$2" != "$fail_download_file" ]
}
load_geoipset() {
    load_calls="$load_calls $1"
    [ "$1" != "$fail_load_set" ]
}
run_case() {
    ipv4_on="$1"
    ipv6_on="$2"
    fail_download_file="$3"
    fail_load_set="$4"
    download_calls=''
    load_calls=''
    install_geoipset update >/dev/null 2>&1
    case_rc=$?
}

run_case true false "$ru_exclude_ipv4" ''
check 'IPv4 download failure propagates' "$case_rc" 1
check 'failed IPv4 download does not skip attempted set load' "$load_calls" ' geo_exclude'

run_case true false '' geo_exclude
check 'IPv4 set load failure propagates' "$case_rc" 1

run_case true true "$ru_exclude_ipv6" ''
check 'IPv4 success does not hide IPv6 download failure' "$case_rc" 1
check 'both requested families are attempted after IPv6 failure' "$download_calls" " $ru_exclude_ipv4 $ru_exclude_ipv6"

run_case true true "$ru_exclude_ipv4" ''
check 'IPv6 success does not hide IPv4 download failure' "$case_rc" 1
check 'IPv6 load still runs after IPv4 failure' "$load_calls" ' geo_exclude geo_exclude6'

run_case true true '' geo_exclude6
check 'IPv6 set load failure propagates' "$case_rc" 1

run_case true true '' ''
check 'both family updates succeed' "$case_rc" 0

run_case true false "$ru_exclude_ipv6" ''
check 'disabled IPv6 is skipped without failing' "$case_rc:$download_calls:$load_calls" "0: $ru_exclude_ipv4: geo_exclude"

grep -A8 -- '-gips)' "$root/scripts/xkeen" | grep -Fq 'install_geoipset init || xkeen_rc=1'
check 'standalone -gips returns GeoIPSET failure to the CLI' "$?" 0

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
