#!/bin/sh
set -u

root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'command rm -rf "$work"' EXIT INT TERM
pass=0
fail=0
xkeen_rundir="$work/run"
mihomo_config="$work/config.yaml"
mkdir -p "$xkeen_rundir"
printf 'listeners: []\n' > "$mihomo_config"
red=""; green=""; yellow=""; reset=""

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
eval "$(extract get_mihomo_config_cache "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"

cache_file="$xkeen_rundir/mihomo-config-cache"
printf '{"last_good":true}\n' > "$cache_file"
find() { printf '%s\n' "$mihomo_config"; }
yq_rc=1
yq() { printf '{"partial":true}\n'; return "$yq_rc"; }
output=$(get_mihomo_config_cache 2>/dev/null); rc=$?
check 'yq failure returns nonzero' "$rc" 1
check 'yq failure does not serve partial output' "$output" ''
check 'yq failure preserves last-good cache' "$(command cat "$cache_file")" '{"last_good":true}'

yq_rc=0
yq() { printf '{"updated":true}\n'; return 0; }
output=$(get_mihomo_config_cache 2>/dev/null); rc=$?
check 'successful yq refresh returns success' "$rc" 0
check 'successful yq refresh serves new JSON' "$output" '{"updated":true}'
check 'successful yq refresh publishes cache' "$(command cat "$cache_file")" '{"updated":true}'

yq() { return 0; }
output=$(get_mihomo_config_cache 2>/dev/null); rc=$?
check 'empty successful yq output is rejected' "$rc" 1
check 'empty yq output preserves last-good cache' "$(command cat "$cache_file")" '{"updated":true}'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
