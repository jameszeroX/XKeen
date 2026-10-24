#!/bin/sh
pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then printf 'OK   %s\n' "$1"; pass=$((pass + 1));
    else printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"; fail=$((fail + 1)); fi
}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
common=/repo/scripts/_xkeen/01_info/01_info_common.sh
for fn in strip_json_comments jc_set_path validate_xkeen_json_syntax; do
    eval "$(awk -v name="$fn" '$0 == name "() {" { on=1 } on {print} on && /^}/ {exit}' "$common")"
done
. /repo/scripts/_xkeen/04_tools/08_tools_balancer/02_balancer_control.sh
xkeen_config="$work/xkeen.json"
cat > "$xkeen_config" <<'JSON'
/* fake root { "xkeen": {} } */
{"xkeen":{
// braces { } } and "xray"
"policy":[{"name":"XKeen"}],
"xray":{"speed_balancer":{"enabled":false}}
}}
JSON
sb_write_setting enabled true >/dev/null; rc=$?
check 'comment-aware setting write succeeds' "$rc" 0
check 'requested setting really changed' "$(strip_json_comments "$xkeen_config" | jq -r '.xkeen.xray.speed_balancer.enabled')" true
check 'outside comments preserved' "$(grep -c 'fake root' "$xkeen_config")" 1
xray_conf_dir="$work/configs"
install_dir="$work/sbin"
backups_dir="$work/backups"
cron_dir="$work/cron"
cron_file=root
sb_api_addr=127.0.0.1:10085
sb_probe_addr=127.0.0.1:10808
sb_probe_intag=probe
sb_api_config="$xray_conf_dir/00_api.json"
sb_probe_config="$xray_conf_dir/00_probe.json"
sb_routing_file="$xray_conf_dir/05_routing.json"
mkdir -p "$xray_conf_dir" "$install_dir" "$backups_dir" "$cron_dir"
printf '%s\n' '{"api":{"tag":"custom-api","services":["RoutingService"]},"inbounds":[{"tag":"custom-api","protocol":"tunnel","port":10085}]}' > "$xray_conf_dir/custom-api.json"
printf '%s\n' '{"routing":{"rules":[{"outboundTag":"custom-api"}]}}' > "$sb_routing_file"
printf '%s\n' '{"inbounds":[{"tag":"existing","protocol":"socks","port":10809}],"outbounds":[{"tag":"keep-outbound","protocol":"freedom"}]}' > "$sb_probe_config"
api_before=$(cat "$xray_conf_dir/custom-api.json")
routing_before=$(cat "$sb_routing_file")
printf '#!/bin/sh\n[ "$XKEEN_FOREGROUND" = 1 ] || exit 1\nprintf restart >> "%s"\n' "$work/restarts" > "$install_dir/xkeen"
chmod +x "$install_dir/xkeen"
pidof() { [ "$1" = xray ]; }
sb_check_xray_version() { return 0; }
reset_rc=0
xray() {
    if [ "$1" = api ] && [ "$2" = bo ]; then
        printf attempt >> "$work/resets"
        return "$reset_rc"
    fi
    return 0
}
printf 'y\n' | sb_ensure_api >/dev/null; rc=$?
check 'existing API can gain missing probe' "$rc" 0
check 'probe config created' "$(jq -r '[.inbounds[] | select(.tag == "probe")] | length' "$sb_probe_config" 2>/dev/null)" 1
check 'existing inbound preserved' "$(jq -r '.inbounds[0].tag' "$sb_probe_config")" existing
check 'other probe-file sections preserved' "$(jq -r '.outbounds[0].tag' "$sb_probe_config")" keep-outbound
check 'existing API preserved' "$(cat "$xray_conf_dir/custom-api.json")" "$api_before"
check 'existing routing preserved' "$(cat "$sb_routing_file")" "$routing_before"
check 'restart waits for completion' "$(cat "$work/restarts")" restart
sb_ensure_api </dev/null >/dev/null
check 'complete setup needs no second restart' "$(cat "$work/restarts")" restart
printf '%s\n' '{"xkeen":{"xray":{"speed_balancer":{"enabled":true}}}}' > "$xkeen_config"
printf '*/5 * * * * %s/xkeen -sbt\n' "$install_dir" > "$cron_dir/root"
sb_balancer=balancer
speed_balancer_settings() { sb_enabled=$(jq -r '.xkeen.xray.speed_balancer.enabled' "$xkeen_config"); }
reset_rc=42
sb_disable >/dev/null; rc=$?
check 'failed reset reports failure' "$rc" 1
check 'failed reset preserves enabled state' "$(jq -r '.xkeen.xray.speed_balancer.enabled' "$xkeen_config")" true
check 'failed reset preserves cron' "$(sb_cron_installed; echo "$?")" 0
reset_rc=0
sb_disable >/dev/null; rc=$?
check 'retry can disable successfully' "$rc" 0
check 'successful reset disables state' "$(jq -r '.xkeen.xray.speed_balancer.enabled' "$xkeen_config")" false
check 'successful reset removes cron' "$(sb_cron_installed; echo "$?")" 1
check 'failed reset was retried' "$(cat "$work/resets")" attemptattempt
jc_set_path() { cat "$3"; return 0; }
original=$(cat "$xkeen_config")
sb_write_setting enabled true >/dev/null; rc=$?
check 'unchanged requested value rejects publication' "$rc" 1
check 'semantic rejection preserves config' "$(cat "$xkeen_config")" "$original"
printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
