#!/bin/sh
# shellcheck disable=SC2154  # Production function reads configuration globals.
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

common="$root/scripts/_xkeen/01_info/01_info_common.sh"
geofile="$root/scripts/_xkeen/02_install/04_install_geofile.sh"
eval "$(awk '$0 == "strip_json_comments() {" { on=1 } on { print } on && /^}/ { exit }' "$common")"
eval "$(awk '$0 == "update_user_geofiles() {" { on=1 } on { print } on && /^}/ { exit }' "$geofile")"

xkeen_config="$work/xkeen.json"
geo_dir="$work/geofiles"
geofile_update=true
red=''; reset=''; yellow=''; light_blue=''
export geo_dir geofile_update red reset yellow light_blue
mkdir -p "$geo_dir"
calls=0
process_geo_file() { calls=$((calls + 1)); }

reject_config() {
    name="$1"
    content="$2"
    printf '%s\n' "$content" > "$xkeen_config"
    before=$calls
    update_user_geofiles >/dev/null 2>&1; rc=$?
    check "$name rejected" "$rc" 1
    check "$name makes no download call" "$calls" "$before"
    check "$name leaves no entry list" "$(find "$geo_dir" -name '.geofile_list.*' -print | wc -l | tr -d ' ')" 0
}

reject_config 'null geodata' '{"xkeen":{"xray":{"geodata":null}}}'
reject_config 'string geodata' '{"xkeen":{"xray":{"geodata":"geo.dat"}}}'
reject_config 'numeric geodata' '{"xkeen":{"xray":{"geodata":7}}}'
reject_config 'non-object entry' '{"xkeen":{"xray":{"geodata":[7]}}}'
reject_config 'missing filename' '{"xkeen":{"xray":{"geodata":[{"url":"https://example.test/a"}]}}}'
reject_config 'missing URL' '{"xkeen":{"xray":{"geodata":[{"file":"a.dat"}]}}}'
reject_config 'empty URL' '{"xkeen":{"xray":{"geodata":[{"file":"a.dat","url":""}]}}}'
reject_config 'non-string filename' '{"xkeen":{"xray":{"geodata":[{"file":7,"url":"https://example.test/a"}]}}}'
reject_config 'non-string URL' '{"xkeen":{"xray":{"geodata":[{"file":"a.dat","url":7}]}}}'
reject_config 'unsupported URL scheme' '{"xkeen":{"xray":{"geodata":[{"file":"a.dat","url":"file:///etc/passwd"}]}}}'
reject_config 'URL without authority' '{"xkeen":{"xray":{"geodata":[{"file":"a.dat","url":"https:///data"}]}}}'
reject_config 'path traversal filename' '{"xkeen":{"xray":{"geodata":[{"file":"../escape.dat","url":"https://example.test/a"}]}}}'
reject_config 'backslash filename' '{"xkeen":{"xray":{"geodata":[{"file":"..\\escape.dat","url":"https://example.test/a"}]}}}'
reject_config 'absolute filename' '{"xkeen":{"xray":{"geodata":[{"file":"/tmp/escape.dat","url":"https://example.test/a"}]}}}'
reject_config 'malformed config JSON' '{"xkeen":{"xray":{"geodata":[}'

printf '%s\n' '{"xkeen":{"xray":{"geodata":[{"file":"valid_name-1.dat","url":"https://example.test/data?token=fixture"}]}}}' > "$xkeen_config"
update_user_geofiles >/dev/null 2>&1; rc=$?
check 'valid geodata accepted' "$rc" 0
check 'valid geodata processed once' "$calls" 1

printf '%s\n' '{"xkeen":{"xray":{}}}' > "$xkeen_config"
update_user_geofiles >/dev/null 2>&1; rc=$?
check 'absent geodata remains a no-op' "$rc" 0
check 'absent geodata makes no call' "$calls" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
