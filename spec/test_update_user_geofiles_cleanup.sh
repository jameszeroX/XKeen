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
mkdir -p "$geo_dir"
printf '%s\n' '{"xkeen":{"xray":{"geodata":[{"file":"","url":"https://example.test/data"}]}}}' > "$xkeen_config"
process_geo_file() { return 0; }
rm_fail_path=''
rm() {
    [ "$2" = "$rm_fail_path" ] && return 1
    command rm "$@"
}

update_user_geofiles
rc=$?
check 'invalid entry returns failure' "$rc" 1
list_file="$geo_dir/.geofile_list.$$"
if [ -e "$list_file" ]; then
    leaked=yes
else
    leaked=no
fi
check 'invalid entry removes temporary list' "$leaked" no

printf '%s\n' '{"xkeen":{"xray":{"geodata":[{"file":"ok.dat","url":"https://example.test/data"}]}}}' > "$xkeen_config"
rm_fail_path="$geo_dir/.geofile_list.$$"
update_user_geofiles >/dev/null 2>&1
check 'temporary-list cleanup failure propagates' "$?" 1
if [ -e "$rm_fail_path" ]; then
    leaked=yes
else
    leaked=no
fi
check 'failed cleanup leaves observable temporary file' "$leaked" yes

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
