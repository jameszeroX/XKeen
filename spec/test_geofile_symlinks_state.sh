#!/bin/sh
# shellcheck disable=SC2154  # geofile_symlinks_enabled assigns globals.
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
eval "$(extract geofile_symlinks_enabled)"

work=$(mktemp -d) || exit 1
trap 'command rm -rf "$work"' EXIT INT TERM
xkeen_config="$work/xkeen.json"

# Кэш должен сбрасываться между проверками.
reset_state() { _geofile_symlinks_state=""; }

# false -> симлинки отключены (rc=1)
reset_state
printf '%s\n' '{"xkeen":{"xray":{"geofile_symlinks":false}}}' > "$xkeen_config"
geofile_symlinks_enabled; rc=$?
check 'false disables symlinks' "$rc" 1
check 'false caches state'     "$_geofile_symlinks_state" false

# true -> включены (rc=0)
reset_state
printf '%s\n' '{"xkeen":{"xray":{"geofile_symlinks":true}}}' > "$xkeen_config"
geofile_symlinks_enabled; rc=$?
check 'true enables symlinks' "$rc" 0
check 'true caches state'    "$_geofile_symlinks_state" true

# null -> default (true)
reset_state
printf '%s\n' '{"xkeen":{"xray":{"geofile_symlinks":null}}}' > "$xkeen_config"
geofile_symlinks_enabled; rc=$?
check 'null uses default (enabled)' "$rc" 0

# ключа нет -> default (true)
reset_state
printf '%s\n' '{"xkeen":{"xray":{}}}' > "$xkeen_config"
geofile_symlinks_enabled; rc=$?
check 'missing key uses default (enabled)' "$rc" 0

# .xkeen.xray отсутствует -> default (true)
reset_state
printf '%s\n' '{"xkeen":{}}' > "$xkeen_config"
geofile_symlinks_enabled; rc=$?
check 'missing .xkeen.xray uses default (enabled)' "$rc" 0

# строковый "false" -> ошибка -> default (true), rc=0
reset_state
printf '%s\n' '{"xkeen":{"xray":{"geofile_symlinks":"false"}}}' > "$xkeen_config"
geofile_symlinks_enabled 2>/dev/null; rc=$?
check 'string "false" falls back to default (enabled)' "$rc" 0
check 'string "false" caches default'               "$_geofile_symlinks_state" true

# decoy на .xkeen.geofile_symlinks не должен влиять
reset_state
printf '%s\n' '{"xkeen":{"geofile_symlinks":false,"xray":{}}}' > "$xkeen_config"
geofile_symlinks_enabled; rc=$?
check 'decoy at .xkeen is ignored (still default)' "$rc" 0

# кэш: после первого вызова повторный не перечитывает файл
reset_state
printf '%s\n' '{"xkeen":{"xray":{"geofile_symlinks":false}}}' > "$xkeen_config"
geofile_symlinks_enabled >/dev/null; rc1=$?
rm -f "$xkeen_config"
geofile_symlinks_enabled >/dev/null; rc2=$?
check 'cache: second call ignores missing file' "$rc2" "$rc1"
check 'cache: state kept as false'              "$_geofile_symlinks_state" false

# нет файла -> default (true)
reset_state
xkeen_config="$work/nonexistent.json"
geofile_symlinks_enabled; rc=$?
check 'missing config file uses default (enabled)' "$rc" 0

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]