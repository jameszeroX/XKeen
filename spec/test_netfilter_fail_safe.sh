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
log_error_router() { :; }
_release_calls=0
_xkeen_release_nf_lock() { _release_calls=$((_release_calls + 1)); }
_xkeen_apply() { [ "${APPLY_FAIL:-0}" = 0 ]; }
APPLY_FAIL=1
_xkeen_apply_checked
check 'apply failure reaches checked caller' "$?" 1
check 'apply failure releases the netfilter lock' "$_release_calls" 1
APPLY_FAIL=0
_release_calls=0
_xkeen_apply_checked
check 'successful apply keeps success status' "$?" 0
check 'successful apply does not release an active lock' "$_release_calls" 0

eval "$(extract _xkeen_normalize_fwmark)"
eval "$(extract _xkeen_find_policy_table)"
eval "$(extract configure_route)"
eval "$(extract _xkeen_configure_route_checked)"
ip_log="$work/ip.log"
ip() {
    printf '%s\n' "$*" >> "$ip_log"
    case "$*" in
        'rule show')
            printf '%s\n' '100: from all fwmark 0x1000 lookup 1000' '101: from all fwmark 0x100 lookup 100'
            ;;
        '-4 route show default') printf '%s\n' 'default via 192.0.2.1 dev wan0' ;;
        '-4 route show table 100') printf '%s\n' 'default via 10.0.0.1 dev ppp0' ;;
        '-4 route show table 1000') printf '%s\n' 'default via 10.0.0.2 dev ppp1' ;;
        '-4 route show table 200') : ;;
        '-4 rule show') : ;;
        '-4 route flush table '*) return 0 ;;
        '-4 rule del '*|'-4 route add local '*|'-4 rule add '*|'-4 route add table '*)
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

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
