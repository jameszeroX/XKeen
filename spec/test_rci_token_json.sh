#!/bin/sh
set -u
root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass + 1))
    else
        printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"; fail=$((fail + 1))
    fi
}
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}
common="$root/scripts/_xkeen/01_info/01_info_common.sh"
eval "$(extract strip_json_comments "$common")"
eval "$(extract get_rci_token "$common")"
xkeen_config="$work/xkeen.json"

printf '%s\n' '{' '  "xkeen": {' '    /* comment */ "rci_token"  :  "abc-123"' '  }' '}' > "$xkeen_config"
_xkeen_json_clean=$(strip_json_comments "$xkeen_config")
get_rci_token; rc=$?
check 'nested token, spaces and JSONC' "$rci_token" 'abc-123'
check 'valid configured token returns success' "$rc" 0

printf '%s\n' '{"xkeen":{"rci_token":"real"},"other":{"rci_token":"decoy"}}' > "$xkeen_config"
_xkeen_json_clean=$(strip_json_comments "$xkeen_config")
get_rci_token
check 'same key in another object is ignored' "$rci_token" 'real'

printf '%s\n' '{"xkeen":{"rci_token":"abc\/123"}}' > "$xkeen_config"
_xkeen_json_clean=$(strip_json_comments "$xkeen_config")
get_rci_token
check 'escaped slash in JSON string is decoded' "$rci_token" 'abc/123'

printf '%s\n' '{"xkeen":{"rci_token":"abc\nX"}}' > "$xkeen_config"
_xkeen_json_clean=$(strip_json_comments "$xkeen_config")
get_rci_token; rc=$?
check 'control characters are rejected' "$rci_token:$rc" ':1'

printf '%s\n' '{"xkeen":{"rci_token":null}}' > "$xkeen_config"
_xkeen_json_clean=$(strip_json_comments "$xkeen_config")
get_rci_token
check 'null token is treated as absent' "$rci_token" ''
printf '%s\n' '{"xkeen":{"rci_token":' > "$xkeen_config"
_xkeen_json_clean=$(strip_json_comments "$xkeen_config")
get_rci_token; rc=$?
check 'malformed JSON produces no token' "$rci_token" ''
check 'malformed JSON returns failure' "$rc" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
