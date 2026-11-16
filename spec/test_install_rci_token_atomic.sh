#!/bin/sh
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
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$root/install.sh"
}
extract_write_rci_token() {
    awk '$0 == "write_rci_token() {" { on=1 } on && /^rci_token_manual_hint\(\) \{/ { exit } on { print }' "$root/install.sh"
}

eval "$(extract strip_json_comments)"
eval "$(extract get_rci_token_from_config)"
eval "$(extract_write_rci_token)"

xkeen_config="$work/xkeen.json"
printf '%s\n' '{' '  "xkeen": {' '    "rci_token": "old-token", // JSONC comment' '    "keep": "this setting"' '  }' '}' > "$xkeen_config"
original=$(command cat "$xkeen_config")
fail_mv=false
chmod_mode=''
chmod() {
    chmod_mode="$1"
    command chmod "$@"
}
mv() {
    [ "$fail_mv" = true ] && return 1
    command mv "$@"
}
fail_mv=true
write_rci_token 'new-token'
rc=$?
check 'failed atomic rename returns failure' "$rc" 1
after=$(command cat "$xkeen_config")
check 'failed rename preserves original config' "$after" "$original"

fail_mv=false
chmod 640 "$xkeen_config"
expected_mode=$(stat -c '%a' "$xkeen_config")
write_rci_token 'new-token'
rc=$?
check 'valid token update succeeds' "$rc" 0
check 'updated token is present' "$(get_rci_token_from_config)" 'new-token'
check 'other config values are retained' "$(command grep -c 'keep.*this setting' "$xkeen_config")" 1
check 'original mode is retained' "$chmod_mode" "$expected_mode"

original=$(command cat "$xkeen_config")
write_rci_token 'invalid"token'
rc=$?
check 'invalid token is rejected' "$rc" 1
check 'invalid token leaves config unchanged' "$(command cat "$xkeen_config")" "$original"

printf '%s\n' '{ "xkeen": { "rci_token": "old", } }' > "$xkeen_config"
original=$(command cat "$xkeen_config")
write_rci_token 'new-token'
rc=$?
check 'malformed JSONC is rejected' "$rc" 1
check 'malformed JSONC remains untouched' "$(command cat "$xkeen_config")" "$original"

xkeen_config="$work/new-config/xkeen.json"
write_rci_token 'first-token'
rc=$?
check 'new config is created atomically' "$rc" 0
check 'new config contains the token' "$(get_rci_token_from_config)" 'first-token'
check 'new config is assigned private permissions' "$chmod_mode" 600

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
