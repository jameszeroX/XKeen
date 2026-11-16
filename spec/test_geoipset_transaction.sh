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
eval "$(extract load_geoipset "$root/scripts/_xkeen/02_install/05_install_geoipset.sh")"

rundir="$work/run"
state_dir="$work/ipset"
fixture="$work/geoip.lst"
mkdir -p "$rundir" "$state_dir"
_xkeen_secure_rundir() { printf '%s' "$rundir"; }

fail_create_name=''
fail_flush_name=''
fail_restore=false
fail_swap=false
fail_destroy=false
ipset() {
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
                # Expected ipset restore format is three space-delimited fields.
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
            [ "$fail_destroy" = true ] && return 1
            rm -f "$state_dir/$1"
            return 0
            ;;
        *)
            return 2
            ;;
    esac
}

reset_state() {
    printf '10.0.0.0/8\n' > "$state_dir/geo_test"
    rm -f "$state_dir/geo_test_tmp"
    fail_create_name=''
    fail_flush_name=''
    fail_restore=false
    fail_swap=false
    fail_destroy=false
    printf '192.0.2.0/24\n' > "$fixture"
}
run_load() {
    load_geoipset geo_test "$fixture" inet
    load_rc=$?
    # load_geoipset installs process traps; keep this test's cleanup intact.
    trap cleanup EXIT INT TERM
}
assert_old_set() {
    check "$1" "$(cat "$state_dir/geo_test")" '10.0.0.0/8'
}

# `ru_exclude*.lst` is a required downloaded GeoIP list: install_geoipset_lst
# rejects files without at least one address. Empty user-created exception
# sets are handled by a different runtime path and remain allowed there.
reset_state
printf '' > "$fixture"
run_load
check 'empty GeoIP list returns failure' "$load_rc" 1
assert_old_set 'empty GeoIP list preserves active set'

reset_state
fail_create_name=geo_test
run_load
check 'primary set create failure returns failure' "$load_rc" 1
assert_old_set 'primary set create failure preserves active set'

reset_state
fail_create_name=geo_test_tmp
run_load
check 'staging set create failure returns failure' "$load_rc" 1
assert_old_set 'staging set create failure preserves active set'

reset_state
printf '10.20.0.0/16\n' > "$state_dir/geo_test_tmp"
fail_flush_name=geo_test_tmp
run_load
check 'staging flush failure returns failure' "$load_rc" 1
assert_old_set 'staging flush failure preserves active set'

reset_state
fail_restore=true
run_load
check 'restore failure returns failure' "$load_rc" 1
assert_old_set 'restore failure preserves active set'

reset_state
fail_swap=true
run_load
check 'swap failure returns failure' "$load_rc" 1
assert_old_set 'swap failure preserves active set'

reset_state
run_load
check 'successful update returns success' "$load_rc" 0
check 'successful update publishes complete set' "$(cat "$state_dir/geo_test")" '192.0.2.0/24'
check 'successful update removes staging set' "$( [ -e "$state_dir/geo_test_tmp" ] && echo present || echo absent )" absent

reset_state
fail_destroy=true
run_load
check 'staging cleanup failure returns failure' "$load_rc" 1
check 'staging cleanup failure leaves published set valid' "$(cat "$state_dir/geo_test")" '192.0.2.0/24'
check 'staging cleanup failure leaves only staging set behind' "$( [ -e "$state_dir/geo_test_tmp" ] && echo present || echo absent )" present

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
