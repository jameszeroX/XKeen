#!/bin/sh
set -u

root=${ROOT:-/repo}
register_source=${REGISTER_SOURCE:-$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh}
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
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$register_source"
}
eval "$(extract _filter_ip_cidr_family)"
eval "$(extract load_user_ipset_family)"
eval "$(extract _acquire_geoipset_lock)"
eval "$(extract _release_geoipset_lock)"
eval "$(extract load_ipset)"

state_dir="$work/ipset"
xkeen_rundir="$work/run"
fixture="$work/ips.lst"
capture="$work/restore.txt"
mkdir -p "$state_dir" "$xkeen_rundir"
usleep() { return 0; }
swap_count=0
ipset() {
    local op="$1"
    shift
    case "$op" in
        restore) cat > "$capture"; return 0 ;;
        swap) swap_count=$((swap_count + 1)); return 0 ;;
        *) return 0 ;;
    esac
}
run_user_v4() {
    load_user_ipset_family user_test inet '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' "$fixture"
    load_rc=$?
}
run_user_v6() {
    load_user_ipset_family user_test6 inet6 '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}(/[0-9]{1,3})?' "$fixture"
    load_rc=$?
}
reset_capture() { : > "$capture"; swap_count=0; }

printf '192.0.2.0/24\n0.0.0.0/0\n2001:db8::/48\n2001:db8:abcd::/56\nfd00::/64\n::/0\n::ffff:192.0.2.1/128\n' > "$fixture"
reset_capture
run_user_v4
check 'valid IPv4 /0 and /24 accepted' "$load_rc/$(cat "$capture")" '0/add user_test_tmp 192.0.2.0/24
add user_test_tmp 0.0.0.0/0'

reset_capture
run_user_v6
check 'valid compressed IPv6 /48, /56, /64 and /0 accepted' "$load_rc/$(cat "$capture")" '0/add user_test6_tmp 2001:db8::/48
add user_test6_tmp 2001:db8:abcd::/56
add user_test6_tmp fd00::/64
add user_test6_tmp ::/0
add user_test6_tmp ::ffff:192.0.2.1/128'

for bad in '999.1.1.1' '192.0.2.1/33' 'host 192.0.2.1 suffix'; do
    printf '%s\n192.0.2.0/24\n' "$bad" > "$fixture"
    reset_capture
    run_user_v4
    check "invalid whole IPv4 record rejected: $bad" "$load_rc/$swap_count/$(cat "$capture")" '1/0/'
done

for bad in '2001:db8::1/129' '2001:::1' 'prefix 2001:db8::/48 suffix'; do
    printf '%s\n2001:db8::/48\n' "$bad" > "$fixture"
    reset_capture
    run_user_v6
    check "invalid whole IPv6 record rejected: $bad" "$load_rc/$swap_count/$(cat "$capture")" '1/0/'
done

printf '2001:db8::1/128\n' > "$fixture"
reset_capture
load_ipset geo_test "$fixture" inet6
check 'runtime GeoIP loader accepts valid /128' "$?/$(cat "$capture")" '0/add geo_test_tmp 2001:db8::1/128'

printf 'bad 2001:db8::1/128\n' > "$fixture"
reset_capture
load_ipset geo_test "$fixture" inet6
check 'runtime GeoIP loader rejects partial CIDR extraction' "$?/$swap_count/$(cat "$capture")" '1/0/'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
