#!/bin/sh
# shellcheck disable=SC2154  # Production function assigns globals through jq.
set -u

root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'command rm -rf "$work"' EXIT INT TERM
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
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/02_install/04_install_geofile.sh"
}
eval "$(awk '$0 == "strip_json_comments() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/01_info/01_info_common.sh")"
eval "$(extract update_user_geofiles)"

xkeen_config="$work/xkeen.json"
# These globals are consumed by the extracted production function.
# shellcheck disable=SC2034
geo_dir="$work/geofiles"
# shellcheck disable=SC2034
geofile_update=true
# shellcheck disable=SC2034
red=''
# shellcheck disable=SC2034
reset=''
# shellcheck disable=SC2034
light_blue=''
# shellcheck disable=SC2034
yellow=''
printf '%s\n' '{"xkeen":{"xray":{"geodata":[' ' {"file":"one.dat","url":"https://example.test/one"},' ' {"file":"two.dat","url":"https://example.test/two"}' ']}}}' > "$xkeen_config"

called=''
fail_files='one.dat'
process_geo_file() {
    called="$called $2"
    case " $fail_files " in *" $2 "*) return 1 ;; esac
    return 0
}

update_user_geofiles > "$work/output.log" 2>&1
rc=$?
output=$(command cat "$work/output.log")
check 'failed file is reflected in status' "$rc" 1
check 'independent second file is still processed' "$called" ' one.dat two.dat'
case "$output" in *one.dat*) check 'failed file name is reported' pass pass ;; *) check 'failed file name is reported' fail pass ;; esac

called=''
fail_files=''
update_user_geofiles >/dev/null 2>&1
check 'all successful files return success' "$?" 0
check 'success case processes both files' "$called" ' one.dat two.dat'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
