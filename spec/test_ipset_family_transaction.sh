#!/bin/sh
set -u

root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
cleanup() { rm -rf "$work"; }
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
eval "$(extract load_user_ipset_family "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"
eval "$(extract load_user_ipset "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"
eval "$(extract _filter_ip_cidr_family "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"
eval "$(extract _acquire_geoipset_lock "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"
eval "$(extract _release_geoipset_lock "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"
eval "$(extract load_ipset "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"

state_dir="$work/ipset"
fixture="$work/ips.lst"
xkeen_rundir="$work/run"
mkdir -p "$state_dir" "$xkeen_rundir"
usleep() { return 0; }
fail_create_name=''
fail_flush_name=''
fail_restore=false
fail_swap=false
ipset() {
    local ip_cmd set_name restore_line
    ip_cmd="$1"
    shift
    case "$ip_cmd" in
        create)
            set_name="$1"
            [ "$set_name" = "$fail_create_name" ] && return 1
            [ -f "$state_dir/$set_name" ] || : > "$state_dir/$set_name"
            return 0
            ;;
        flush)
            set_name="$1"
            [ "$set_name" = "$fail_flush_name" ] && return 1
            [ -f "$state_dir/$set_name" ] || return 1
            : > "$state_dir/$set_name"
            return 0
            ;;
        restore)
            while IFS= read -r restore_line; do
                # shellcheck disable=SC2086
                set -- $restore_line
                [ "$#" -eq 3 ] && [ "$1" = add ] || return 1
                [ -f "$state_dir/$2" ] || return 1
                printf '%s\n' "$3" >> "$state_dir/$2"
                [ "$fail_restore" = true ] && return 1
            done
            return 0
            ;;
        swap)
            [ "$fail_swap" = true ] && return 1
            [ -f "$state_dir/$1" ] && [ -f "$state_dir/$2" ] || return 1
            cp "$state_dir/$2" "$state_dir/swap.$$" || return 1
            cat "$state_dir/$1" > "$state_dir/$2" || return 1
            cat "$state_dir/swap.$$" > "$state_dir/$1" || return 1
            rm -f "$state_dir/swap.$$"
            return 0
            ;;
        destroy)
            rm -f "$state_dir/$1"
            return 0
            ;;
        *) return 2 ;;
    esac
}

reset_state() {
    set_name="$1"
    printf '10.0.0.0/8\n' > "$state_dir/$set_name"
    rm -f "$state_dir/${set_name}_tmp"
    fail_create_name=''
    fail_flush_name=''
    fail_restore=false
    fail_swap=false
    printf '192.0.2.0/24\n' > "$fixture"
}
run_user_loader() {
    load_user_ipset_family user_test inet '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' "$fixture"
    load_rc=$?
}
run_runtime_loader() {
    load_ipset runtime_test "$fixture" inet
    load_rc=$?
}
assert_old_set() {
    check "$1" "$(cat "$state_dir/$2")" '10.0.0.0/8'
}

for loader in user runtime; do
    if [ "$loader" = user ]; then test_set=user_test; else test_set=runtime_test; fi

    reset_state "$test_set"
    fail_create_name="$test_set"
    if [ "$loader" = user ]; then run_user_loader; else run_runtime_loader; fi
    check "$loader active set create failure returns failure" "$load_rc" 1
    assert_old_set "$loader active set create failure preserves active set" "$test_set"

    reset_state "$test_set"
    fail_create_name="${test_set}_tmp"
    if [ "$loader" = user ]; then run_user_loader; else run_runtime_loader; fi
    check "$loader staging create failure returns failure" "$load_rc" 1
    assert_old_set "$loader staging create failure preserves active set" "$test_set"

    reset_state "$test_set"
    printf '203.0.113.0/24\n' > "$state_dir/${test_set}_tmp"
    fail_flush_name="${test_set}_tmp"
    if [ "$loader" = user ]; then run_user_loader; else run_runtime_loader; fi
    check "$loader staging flush failure returns failure" "$load_rc" 1
    assert_old_set "$loader staging flush failure preserves active set" "$test_set"

    reset_state "$test_set"
    fail_restore=true
    if [ "$loader" = user ]; then run_user_loader; else run_runtime_loader; fi
    check "$loader restore failure returns failure" "$load_rc" 1
    assert_old_set "$loader restore failure preserves active set" "$test_set"

    reset_state "$test_set"
    fail_swap=true
    if [ "$loader" = user ]; then run_user_loader; else run_runtime_loader; fi
    check "$loader swap failure returns failure" "$load_rc" 1
    assert_old_set "$loader swap failure preserves active set" "$test_set"

    reset_state "$test_set"
    if [ "$loader" = user ]; then run_user_loader; else run_runtime_loader; fi
    check "$loader success publishes complete set" "$(cat "$state_dir/$test_set")" '192.0.2.0/24'
done

reset_state user_test
: > "$fixture"
run_user_loader
check 'empty user list remains a valid clear operation' "$load_rc" 0
check 'empty user list clears its set' "$(cat "$state_dir/user_test")" ''

reset_state runtime_test
: > "$fixture"
run_runtime_loader
check 'empty runtime GeoIP file returns failure' "$load_rc" 1
assert_old_set 'empty runtime GeoIP file preserves active set' runtime_test

reset_state user_exclude
# These variables are read by the dynamically extracted production function.
# shellcheck disable=SC2034
file_ip_exclude="$fixture"
# shellcheck disable=SC2034
ru_override="$work/no-override.lst"
# shellcheck disable=SC2034
iptables_supported=true
# shellcheck disable=SC2034
ip6tables_supported=false
fail_restore=true
load_user_ipset
check 'load_user_ipset propagates family load failure' "$?" 1
check 'failed aggregate user load preserves active set' "$(cat "$state_dir/user_exclude")" '10.0.0.0/8'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
