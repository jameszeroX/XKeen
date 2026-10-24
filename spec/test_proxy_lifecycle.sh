#!/bin/sh
file=/repo/scripts/_xkeen/02_install/07_install_register/04_register_init.sh
extract() {
    awk -v name="$1" '$0 ~ "^" name "\\(\\) \\{" { on=1 } on { print } on && ($0 ~ /^}/ || $0 ~ /; }$/) { exit }' "$file"
}
eval "$(extract proxy_pids)"
eval "$(extract proxy_status)"
pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then printf 'OK   %s\n' "$1"; pass=$((pass + 1));
    else printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"; fail=$((fail + 1)); fi
}
work=$(mktemp -d)
trap 'kill "$daemon" "$helper" "$tester" 2>/dev/null; rm -rf "$work"' EXIT INT TERM
printf 'sleep 30\n:\n' > "$work/run"
cp "$work/run" "$work/api"
cd "$work" || exit 1
sh run & daemon=$!
sh api & helper=$!
sh run -test & tester=$!
sleep 0.1
pids="$helper"
pidof() { printf '%s\n' "$pids"; }
name_client=xray
check 'helper alone is not a daemon' "$(proxy_status; echo "$?")" 1
pids="$tester"
check 'configuration test is not a daemon' "$(proxy_status; echo "$?")" 1
pids="$helper $daemon $tester"
check 'only run daemon selected' "$(proxy_pids)" "$daemon"
check 'daemon status succeeds' "$(proxy_status; echo "$?")" 0
name_client=mihomo
check 'Mihomo process selection preserved' "$(proxy_pids)" "$pids"
proxy_status() { return 1; }
_acquire_proxy_mutex() { return 2; }
cleanup_fd_monitor() { :; }
clean_firewall() { rm -f "$work/firewall"; }
xkeen_rundir=$work
touch "$work/firewall"
eval "$(extract proxy_stop)"
proxy_stop >/dev/null
check 'stop without daemon cleans firewall' "$([ -e "$work/firewall" ] && echo present || echo absent)" absent
_xkeen_cur_wan=192.0.2.1
_xkeen_prev_wan=$_xkeen_cur_wan
iptables_supported=false
ip6tables_supported=false
_xkeen_rules_intact() { return 0; }
_xkeen_release_nf_lock() { touch "$work/unlocked"; }
_xkeen_sync_deny_mac_ipset() { [ -f "$work/unlocked" ] && touch "$work/refreshed"; }
block=$(awk '/^    if \[ -n "\$_xkeen_cur_wan"/ { on=1 } on { print } on && /^    fi$/ { exit }' "$file")
(eval "$block")
check 'same WAN schedule refreshes deny list after unlock' "$([ -e "$work/refreshed" ] && echo refreshed || echo stale)" refreshed
printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
