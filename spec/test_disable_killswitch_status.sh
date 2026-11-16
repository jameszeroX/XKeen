#!/bin/sh
set -u

root=${ROOT:-/repo}
pass=0
fail=0
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"
        pass=$((pass + 1))
    else
        printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"
        fail=$((fail + 1))
    fi
}
eval "$(extract disable_killswitch "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"

# Globals are consumed by the dynamically extracted production function.
# shellcheck disable=SC2034
name_chain=xkeen_test
# shellcheck disable=SC2034
comment='--comment xkeen-test'
# shellcheck disable=SC2034
iptables_supported=true
# shellcheck disable=SC2034
ip6tables_supported=false
lock_result=0
lock_owned=0
release_count=0
chain_exists=true
jump_exists=true
delete_fail=false
flush_fail=false
destroy_fail=false
_acquire_nf_lock() {
    _xkeen_lock_owned=$lock_owned
    return "$lock_result"
}
_release_nf_lock() { release_count=$((release_count + 1)); return 0; }
iptables() {
    case "$*" in
        *' -nL xkeen_test_killswitch'*) [ "$chain_exists" = true ] ;;
        *' -S PREROUTING'*)
            [ "$jump_exists" = true ] && printf '%s\n' '-A PREROUTING --comment xkeen-test -j xkeen_test_killswitch'
            return 0
            ;;
        *' -D PREROUTING'*)
            [ "$delete_fail" = true ] && return 1
            [ "$jump_exists" = true ] || return 1
            jump_exists=false
            return 0
            ;;
        *' -F xkeen_test_killswitch'*)
            [ "$flush_fail" = true ] && return 1
            return 0
            ;;
        *' -X xkeen_test_killswitch'*)
            [ "$destroy_fail" = true ] && return 1
            chain_exists=false
            return 0
            ;;
        *) return 0 ;;
    esac
}
ip6tables() { return 0; }
log_error_router() { :; }

delete_fail=true
disable_killswitch
rc=$?
check 'failed jump deletion returns failure' "$rc" 1
check 'failed jump remains detectable' "$jump_exists" true

delete_fail=false
jump_exists=true
flush_fail=true
disable_killswitch
rc=$?
check 'failed chain flush returns failure' "$rc" 1

flush_fail=false
destroy_fail=true
disable_killswitch
rc=$?
check 'busy chain deletion returns failure' "$rc" 1

chain_exists=false
jump_exists=false
destroy_fail=false
disable_killswitch
rc=$?
check 'repeated disable with absent chain succeeds' "$rc" 0

chain_exists=true
jump_exists=true
disable_killswitch
rc=$?
check 'successful removal returns success' "$rc" 0
check 'successful removal leaves no jump or chain' "$jump_exists/$chain_exists" false/false

lock_result=1
lock_owned=0
release_before=$release_count
disable_killswitch
rc=$?
check 'lock acquisition failure returns failure' "$rc" 1
check 'lock acquisition failure does not release foreign lock' "$release_count" "$release_before"

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
