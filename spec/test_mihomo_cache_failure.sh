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
extract_nested() {
    awk -v name="$1" '$0 == "    " name "() {" { on=1 } on { print } on && $0 == "    }" { exit }' "$2"
}
eval "$(extract get_mihomo_config_cache "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"
eval "$(extract get_mihomo_listener_field_by_name "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"
eval "$(extract get_mihomo_listener_rule_proxy_by_name "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"
eval "$(extract_nested find_dscp_force_listener "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"
eval "$(extract_nested validate_dscp_force_listener "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh")"

cache_file="$xkeen_rundir/mihomo-config-cache"
printf '{"last_good":true}\n' > "$cache_file"
find() { printf '%s\n' "$mihomo_config"; }
yq_rc=1
yq() { printf '{"partial":true}\n'; return "$yq_rc"; }
output=$(get_mihomo_config_cache 2>/dev/null); rc=$?
check 'yq failure returns nonzero' "$rc" 1
check 'yq failure does not serve partial output' "$output" ''
check 'yq failure preserves last-good cache' "$(command cat "$cache_file")" '{"last_good":true}'

# Callers must not turn a failed cache refresh into a successful empty lookup.
jq() {
    case "$*" in
        *listeners*) printf '1080\n' ;;
        *rules*) printf 'IN-NAME,tag,proxy\n' ;;
    esac
    return 0
}
output=$(get_mihomo_listener_field_by_name tag port 2>/dev/null); rc=$?
check 'listener lookup propagates cache refresh failure' "$rc" 1
check 'listener lookup returns no fabricated field' "$output" ''
output=$(get_mihomo_listener_rule_proxy_by_name tag 2>/dev/null); rc=$?
check 'rule lookup propagates cache refresh failure' "$rc" 1
check 'rule lookup returns no fabricated proxy' "$output" ''
find_dscp_force_listener tag >/dev/null 2>&1; rc=$?
check 'DSCP listener search propagates cache refresh failure' "$rc" 2
check 'DSCP listener search reports cache failure' "$dscp_force_proxy_reason" 'не удалось прочитать актуальную конфигурацию Mihomo'
dscp_force_proxy_tag=tag
validate_dscp_force_listener tproxy udp tag tproxy >/dev/null 2>&1; rc=$?
check 'DSCP validation propagates cache refresh failure' "$rc" 2
check 'DSCP validation reports cache failure' "$dscp_force_proxy_reason" 'не удалось прочитать актуальную конфигурацию Mihomo'

yq_rc=0
yq() { printf '{"updated":true}\n'; return 0; }
output=$(get_mihomo_config_cache 2>/dev/null); rc=$?
check 'successful yq refresh returns success' "$rc" 0
check 'successful yq refresh serves new JSON' "$output" '{"updated":true}'
check 'successful yq refresh publishes cache' "$(command cat "$cache_file")" '{"updated":true}'
output=$(get_mihomo_listener_field_by_name tag port 2>/dev/null); rc=$?
check 'listener lookup succeeds with a valid cache' "$rc" 0
check 'listener lookup returns the requested field' "$output" '1080'
output=$(get_mihomo_listener_rule_proxy_by_name tag 2>/dev/null); rc=$?
check 'rule lookup succeeds with a valid cache' "$rc" 0
check 'rule lookup returns the matching proxy' "$output" 'proxy'

mv() { return 1; }
yq() { printf '{"not_published":true}\n'; return 0; }
output=$(get_mihomo_config_cache 2>/dev/null); rc=$?
check 'cache publication failure returns nonzero' "$rc" 1
check 'cache publication failure serves no stale data' "$output" ''
check 'cache publication failure preserves last-good file' "$(command cat "$cache_file")" '{"updated":true}'
unset -f mv

yq() { return 0; }
output=$(get_mihomo_config_cache 2>/dev/null); rc=$?
check 'empty successful yq output is rejected' "$rc" 1
check 'empty yq output preserves last-good cache' "$(command cat "$cache_file")" '{"updated":true}'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
