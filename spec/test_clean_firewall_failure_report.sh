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
file="$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh"
eval "$(extract clean_firewall "$file")"

xkeen_rundir="$work/run"
mkdir -p "$xkeen_rundir"
iptables_supported=true
ip6tables_supported=false
keep_killswitch=off
name_chain=xkeen_test
name_ipset_deny_mac=xkeen_test_deny
file_netfilter_hook="$work/no-netfilter-hook"
file_schedule_hook="$work/no-schedule-hook"
comment_tag='--comment xkeen-test'
table_mark=1
table_id=100
lock_release_count=0
_xkeen_lock_owned=1

_acquire_nf_lock() { return 0; }
_release_nf_lock() { lock_release_count=$((lock_release_count + 1)); return 0; }
get_ipver_support() { iptables_supported=true; ip6tables_supported=false; }
command() { return 1; }
iptables() {
    case " $* " in
        *" -S _NDM_HOTSPOT_DNSREDIR "*) return 1 ;;
        *" -S "*)
            printf '%s\n' '-N xkeen_test' '-A PREROUTING -m comment --comment xkeen-test -j xkeen_test'
            return 0
            ;;
        *" -D "*|*" -F "*|*" -X "*) return 1 ;;
    esac
    return 0
}

clean_firewall
rc=$?
check 'cleanup failure is returned to caller' "$rc" 1
check 'network lock is still released after cleanup failure' "$lock_release_count" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
