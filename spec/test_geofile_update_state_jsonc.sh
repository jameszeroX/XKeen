#!/bin/sh
# shellcheck disable=SC2154  # geofiles_update_state assigns this shell global.
set -u

root=${ROOT:-/repo}
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
eval "$(extract geofiles_update_state)"

work=$(mktemp -d) || exit 1
trap 'command rm -rf "$work"' EXIT INT TERM
xkeen_config="$work/xkeen.json"

printf '%s\n' '{' '  "xkeen" : {' '    /* config note */' '    "geofile_update"  : false' '  }' '}' > "$xkeen_config"
geofiles_update_state
check 'false with JSONC and whitespace disables updates' "$geofile_update" false

printf '%s\n' '{' '  "other": { "geofile_update": false },' '  "xkeen": { "geofile_update": true }' '}' > "$xkeen_config"
geofiles_update_state
check 'nested decoy does not override xkeen setting' "$geofile_update" true

printf '%s\n' '{"xkeen":{"geofile_update":null}}' > "$xkeen_config"
geofiles_update_state
check 'null uses documented default' "$geofile_update" true

printf '%s\n' '{"xkeen":{}}' > "$xkeen_config"
geofiles_update_state
check 'missing option uses documented default' "$geofile_update" true

printf '%s\n' '{"xkeen":{"geofile_update":"false"}}' > "$xkeen_config"
geofiles_update_state
rc=$?
check 'invalid type is reported' "$rc" 1
check 'invalid type keeps default enabled' "$geofile_update" true

printf '%s\n' '{"xkeen":' > "$xkeen_config"
geofiles_update_state
rc=$?
check 'malformed JSON is reported' "$rc" 1
check 'malformed JSON keeps default enabled' "$geofile_update" true

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
