#!/bin/sh
set -u

root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
cleanup() { [ -z "${lock_owner_pid:-}" ] || kill "$lock_owner_pid" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT INT TERM
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
eval "$(extract _acquire_nf_lock "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"
eval "$(extract _release_nf_lock "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"
eval "$(extract clean_firewall "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"
eval "$(extract enable_killswitch "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"
eval "$(extract disable_killswitch "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"

xkeen_rundir="$work/run"
mkdir -p "$xkeen_rundir/netfilter.lock.d"
sleep 60 &
lock_owner_pid=$!
printf '%s\n' "$lock_owner_pid" > "$xkeen_rundir/netfilter.lock.d/pid"
: > "$xkeen_rundir/netfilter.lock.d/owner.marker"
usleep() { return 0; }
_acquire_nf_lock
lock_rc=$?
check 'live owner lock is reported as busy' "$lock_rc" 1
check 'timeout does not steal a live owner lock' "$( [ -f "$xkeen_rundir/netfilter.lock.d/owner.marker" ] && echo present || echo missing )" present

mutation_count=0
# Values are consumed by the dynamically extracted clean_firewall function.
# shellcheck disable=SC2034
iptables_supported=false
# shellcheck disable=SC2034
ip6tables_supported=false
# shellcheck disable=SC2034
name_chain=xkeen_test
# shellcheck disable=SC2034
name_ipset_deny_mac=xkeen_test_deny
# shellcheck disable=SC2034
keep_killswitch=off
# shellcheck disable=SC2034
file_netfilter_hook="$work/no-hook"
# shellcheck disable=SC2034
file_schedule_hook="$work/no-schedule-hook"
# shellcheck disable=SC2034
comment_tag='--comment xkeen-test'
# shellcheck disable=SC2034
get_ipver_support() { iptables_supported=false; ip6tables_supported=false; }
_acquire_nf_lock() { _xkeen_lock_owned=''; return 1; }
_release_nf_lock() { return 0; }
command() { return 1; }
iptables() {
    case " $* " in
        *" -F "*|*" -X "*|*" -D "*) mutation_count=$((mutation_count + 1)); return 0 ;;
        *) return 0 ;;
    esac
}
ip6tables() { iptables "$@"; }
clean_firewall
clean_rc=$?
check 'clean_firewall returns lock acquisition failure' "$clean_rc" 1
check 'clean_firewall performs no mutations without owning the lock' "$mutation_count" 0

mutation_count=0
# Values consumed by the dynamically extracted kill-switch functions.
# shellcheck disable=SC2034
killswitch=on
# shellcheck disable=SC2034
policy_mark=0x1
# shellcheck disable=SC2034
policy_mark_full=0x2
# shellcheck disable=SC2034
user_policies=''
enable_killswitch
enable_rc=$?
check 'enable_killswitch returns lock acquisition failure' "$enable_rc" 1
check 'enable_killswitch does not apply rules without lock' "$mutation_count" 0

# shellcheck disable=SC2034
iptables_supported=true
disable_killswitch
disable_rc=$?
check 'disable_killswitch returns lock acquisition failure' "$disable_rc" 1
check 'disable_killswitch does not delete rules without lock' "$mutation_count" 0

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
