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

# false в .xkeen.xray + JSONC/whitespace
printf '%s\n' '{' '  "xkeen" : {' '    /* config note */' '    "xray" : {' '      "geofile_update"  : false' '    }' '  }' '}' > "$xkeen_config"
geofiles_update_state
check 'false with JSONC and whitespace disables updates' "$geofile_update" false

# decoy на уровне .xkeen не должен переопределять .xkeen.xray
printf '%s\n' \
    '{' \
    '  "xkeen": {' \
    '    "geofile_update": false,' \
    '    "xray": { "geofile_update": true }' \
    '  }' \
    '}' > "$xkeen_config"
geofiles_update_state
check 'decoy at .xkeen does not override .xkeen.xray setting' "$geofile_update" true

# decoy в другой ветке (например, .mihomo) тоже не должен влиять
printf '%s\n' \
    '{' \
    '  "other": { "xray": { "geofile_update": false } },' \
    '  "xkeen": { "xray": { "geofile_update": true } }' \
    '}' > "$xkeen_config"
geofiles_update_state
check 'nested decoy in other branch does not override' "$geofile_update" true

# null -> default (true)
printf '%s\n' '{"xkeen":{"xray":{"geofile_update":null}}}' > "$xkeen_config"
geofiles_update_state
check 'null uses documented default' "$geofile_update" true

# ключа нет -> default (true)
printf '%s\n' '{"xkeen":{"xray":{}}}' > "$xkeen_config"
geofiles_update_state
check 'missing option uses documented default' "$geofile_update" true

# .xkeen.xray отсутствует как объект -> default (true)
printf '%s\n' '{"xkeen":{}}' > "$xkeen_config"
geofiles_update_state
check 'missing .xkeen.xray uses documented default' "$geofile_update" true

# строка "false" -> ошибка, дефолт true
printf '%s\n' '{"xkeen":{"xray":{"geofile_update":"false"}}}' > "$xkeen_config"
geofiles_update_state
rc=$?
check 'invalid type is reported' "$rc" 1
check 'invalid type keeps default enabled' "$geofile_update" true

# битый JSON -> ошибка, дефолт true
printf '%s\n' '{"xkeen":{"xray":' > "$xkeen_config"
geofiles_update_state
rc=$?
check 'malformed JSON is reported' "$rc" 1
check 'malformed JSON keeps default enabled' "$geofile_update" true

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]