#!/bin/sh
set -u

root=${ROOT:-/repo}
file="$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh"
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
    awk -v name="$1" '
        $0 == "    " name "() {" { on=1 }
        on && $0 == "    }" { print; exit }
        on { print }
    ' "$file"
}

eval "$(extract _xkeen_apply)"
iptables_supported=true
ip6tables_supported=true
_xkeen_v4_nat_rules='-A PREROUTING -j XKeen'
_xkeen_v4_mangle_rules='-A PREROUTING -j XKeen'
_xkeen_v6_nat_rules='-A PREROUTING -j XKeen'
_xkeen_v6_mangle_rules='-A PREROUTING -j XKeen'
apply_calls=0
fail_table=iptables_nat
_xkeen_apply_table() {
    apply_calls=$((apply_calls + 1))
    [ "${1}_$2" != "$fail_table" ]
}
_xkeen_apply
apply_rc=$?
check 'apply reports failure if any table fails' "$apply_rc" 1
check 'apply continues trying every supported table' "$apply_calls" 4
fail_table=none
apply_calls=0
_xkeen_apply
check 'apply reports success when all tables succeed' "$?" 0

eval "$(extract _xkeen_apply_checked)"
logger_log="$work/logger.log"
logger() { printf '%s\n' "$*" >> "$logger_log"; }
_release_calls=0
_xkeen_release_nf_lock() { _release_calls=$((_release_calls + 1)); }
_xkeen_apply() { [ "${APPLY_FAIL:-0}" = 0 ]; }
APPLY_FAIL=1
_xkeen_apply_checked
check 'apply failure reaches checked caller' "$?" 1
check 'apply failure releases the netfilter lock' "$_release_calls" 1
check 'apply failure logs through logger directly' "$(cat "$logger_log")" '-p error -t XKeen Не удалось применить все поддерживаемые таблицы netfilter; новые правила XKeen не считаются активными'
APPLY_FAIL=0
_release_calls=0
: > "$logger_log"
_xkeen_apply_checked
check 'successful apply keeps success status' "$?" 0
check 'successful apply does not release an active lock' "$_release_calls" 0
check 'successful apply does not log an error' "$(cat "$logger_log")" ''

eval "$(extract _xkeen_normalize_fwmark)"
eval "$(extract _xkeen_find_policy_table)"
eval "$(extract configure_route)"
eval "$(extract _xkeen_configure_route_checked)"
ip_log="$work/ip.log"
ip() {
    printf '%s\n' "$*" >> "$ip_log"
    case "$*" in
        'rule show')
            printf '%s\n' '100: from all fwmark 0x1000 lookup 1000' '101: from all fwmark 0x100 lookup 100' '102: from all fwmark 0xffffaaa lookup 4096'
            ;;
        '-4 route show default') printf '%s\n' 'default via 192.0.2.1 dev wan0' ;;
        '-4 route show table 100') printf '%s\n' 'default via 10.0.0.1 dev ppp0' ;;
        '-4 route show table 1000') printf '%s\n' 'default via 10.0.0.2 dev ppp1' ;;
        '-4 route show table 200') : ;;
        '-6 route show table 4096')
            printf '%s\n' \
                '2001:2::c633:6425 dev ezcfg0 metric 256 linkdown pref medium' \
                'fe80::/64 dev br0 metric 256' \
                'fe80::/64 dev eth3 metric 256' \
                '2001:db8:1::/64 dev wan0 metric 256'
            ;;
        '-6 route show table 424242') : ;;
        '-4 rule show') : ;;
        '-4 route flush table '*|'-6 route flush table '*) return 0 ;;
        '-6 route add table 424242 2001:2::'*linkdown*) return 42 ;;
        '-6 route add table 424242 fe80::/64 dev '*)
            _v6_fe80_adds=$((${_v6_fe80_adds:-0} + 1))
            [ "$_v6_fe80_adds" -eq 1 ] || return 17
            return 0
            ;;
        '-6 route add table 424242 2001:db8:1::/64 '*) return 0 ;;
        '-4 rule del '*|'-6 rule del '*|'-4 route add local '*|'-6 route add local '*|'-4 rule add '*|'-6 rule add '*|'-4 route add table '*|'-6 route add table '*)
            [ "${FAIL_ROUTE_MUTATION:-0}" = 0 ] || return 42
            return 0
            ;;
        *) return 0 ;;
    esac
}
policy_mark=0x100
allow_noisp=off
table_id=200
table_mark=0x200
configure_route 4
route_rc=$?
selected_source=$(awk '/route show table (100|1000)$/ {print $NF; exit}' "$ip_log")
check 'policy 0x100 selects its exact routing table' "$selected_source" 100
check 'successful route setup returns zero' "$route_rc" 0

# IPv6 enabled without a provider route is not itself a route-setup error.
: > "$ip_log"
policy_mark=
configure_route 6
no_ipv6_uplink_rc=$?
check 'IPv6 setup tolerates an empty main route table when ISP provides no IPv6' "$no_ipv6_uplink_rc" 0

: > "$ip_log"
policy_mark=0xffffaaa
table_id=424242
table_mark=0x424242
_v6_fe80_adds=0
configure_route 6
v6_no_isp_rc=$?
check 'IPv6 setup ignores linkdown and link-local routes from IPv4-only policy table' "$v6_no_isp_rc" 0
v6_copy_count=$(grep -c '^-6 route add table 424242 ' "$ip_log" || true)
check 'IPv6 policy table copies only the usable route' "$v6_copy_count" 1
v6_copied_route=$(grep '^-6 route add table 424242 ' "$ip_log" | tail -n 1)
check 'usable global IPv6 route remains copied' "$v6_copied_route" '-6 route add table 424242 2001:db8:1::/64 dev wan0 metric 256'

: > "$ip_log"
FAIL_ROUTE_MUTATION=1 configure_route 4
route_failure_rc=$?
check 'route mutation failure is returned' "$route_failure_rc" 1
rule_adds=$(awk '/rule add/ { n++ } END { print n + 0 }' "$ip_log")
check 'no fwmark rule is installed after local-route failure' "$rule_adds" 0
configure_route() { return "${ROUTE_FAIL:-0}"; }
ROUTE_FAIL=42
_release_calls=0
_xkeen_configure_route_checked 4
check 'route error reaches checked caller' "$?" 1
check 'route error releases the netfilter lock' "$_release_calls" 1
check 'route failure logs through logger directly' "$(tail -n 1 "$logger_log")" '-p error -t XKeen Не удалось настроить policy routing IPv4; правила TProxy не будут применены'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
