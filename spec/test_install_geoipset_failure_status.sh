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
touch "$ru_exclude_ipv4" "$ru_override"

ip() { printf 'inet 192.0.2.1/24\n'; }
iptables() { return 0; }
check_ipv6_active() { return 1; }
install_geoipset_lst() { return 1; }
load_geoipset() { return 0; }

install_geoipset update >/dev/null 2>&1
rc=$?
check 'IPv4 file download failure propagates from install_geoipset' "$rc" 1

install_geoipset_lst() { return 0; }
load_geoipset() { return 1; }
install_geoipset update >/dev/null 2>&1
rc=$?
check 'IPv4 set load failure propagates from install_geoipset' "$rc" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
