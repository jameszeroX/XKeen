#!/bin/sh
set -u

root=${ROOT:-/repo}
# The extracted production functions interpolate these console colors.
# shellcheck disable=SC2034
green=''
# shellcheck disable=SC2034
red=''
# shellcheck disable=SC2034
reset=''
work=$(mktemp -d) || exit 1
cleanup() { command rm -rf "$work"; }
trap cleanup EXIT INT TERM
pass=0
fail=0
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/03_delete/02_delete_geoipset.sh"
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
eval "$(extract _delete_geoipset_resources)"
eval "$(extract delete_geoipset_key)"
eval "$(extract delete_geoipset)"

ru_exclude_ipv4="$work/ru_exclude_ipv4.lst"
ru_exclude_ipv6="$work/ru_exclude_ipv6.lst"
printf 'v4 data\n' > "$ru_exclude_ipv4"
printf 'v6 data\n' > "$ru_exclude_ipv6"
names='geo_exclude geo_exclude6'
list_fail=false
flush_fail=''
save_dirty=''
rm_fail_path=''
ipset() {
    case "$1" in
        list)
            if [ "$2" = -name ]; then
                [ "$list_fail" = false ] || return 1
                printf '%s\n' "$names"
                return 0
            fi
            return 0
            ;;
        flush)
            [ "$2" = "$flush_fail" ] && return 1
            return 0
            ;;
        save)
            [ "$2" = "$save_dirty" ] && printf 'add %s 192.0.2.0/24\n' "$2"
            return 0
            ;;
        *) return 2 ;;
    esac
}
rm() {
    for path do
        [ "$path" = "$rm_fail_path" ] && return 1
    done
    command rm "$@"
}
read() {
    # The extracted interactive function consumes this simulated answer.
    # shellcheck disable=SC2034
    choice=1
}

delete_geoipset_key
rc=$?
check 'successful deletion returns success' "$rc" 0
if [ -e "$ru_exclude_ipv4" ] || [ -e "$ru_exclude_ipv6" ]; then
    files_remain=0
else
    files_remain=1
fi
check 'successful deletion removes both files' "$files_remain" 1

printf 'v4 data\n' > "$ru_exclude_ipv4"
printf 'v6 data\n' > "$ru_exclude_ipv6"
flush_fail=geo_exclude
delete_geoipset_key
rc=$?
check 'ipset flush failure propagates' "$rc" 1
if [ -e "$ru_exclude_ipv4" ] || [ -e "$ru_exclude_ipv6" ]; then
    files_remain=0
else
    files_remain=1
fi
check 'independent file cleanup continues after set failure' "$files_remain" 1

flush_fail=''
printf 'v6 data\n' > "$ru_exclude_ipv6"
rm_fail_path="$ru_exclude_ipv6"
delete_geoipset_key
rc=$?
check 'file removal failure propagates' "$rc" 1
check 'failed file remains visible' "$( [ -e "$ru_exclude_ipv6" ] && echo present || echo absent )" present

rm_fail_path=''
rm -f "$ru_exclude_ipv6"
printf 'v6 data\n' > "$ru_exclude_ipv6"
save_dirty=geo_exclude6
delete_geoipset_key
rc=$?
check 'nonempty set after flush is treated as failure' "$rc" 1
output=$(delete_geoipset)
rc=$?
check 'interactive deletion propagates failure' "$rc" 1
case "$output" in
    *"Не удалось полностью удалить списки исключений GeoIPSET"*) check 'failure message does not claim success' pass pass ;;
    *) check 'failure message does not claim success' fail pass ;;
esac
save_dirty=''
output=$(delete_geoipset)
rc=$?
check 'interactive deletion succeeds after cleanup' "$rc" 0
case "$output" in
    *"Списки исключений GeoIPSET успешно удалены"*) check 'success message follows verified cleanup' pass pass ;;
    *) check 'success message follows verified cleanup' fail pass ;;
esac

list_fail=true
delete_geoipset_key
rc=$?
check 'unable to inspect ipset state propagates' "$rc" 1

list_fail=false
names=''
save_dirty=''
delete_geoipset_key
check 'repeat deletion after resources are absent succeeds' "$?" 0

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
