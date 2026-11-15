#!/bin/sh
set -u

root=${ROOT:-/repo}
common="$root/scripts/_xkeen/01_info/01_info_common.sh"
control="$root/scripts/_xkeen/04_tools/08_tools_balancer/02_balancer_control.sh"
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
for fn in strip_json_comments jc_set_path validate_xkeen_json_syntax; do
    eval "$(awk -v name="$fn" '$0 == name "() {" { on=1 } on {print} on && /^}/ {exit}' "$common")"
done
. "$control"

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

xkeen_config="$work/xkeen.json"
backup_marker="$work/backup-attempted"
jc_marker="$work/jc-called"
printf '%s\n' '{"generation":"current","xkeen":{"xray":{"speed_balancer":{"enabled":false}}}}' > "$xkeen_config"
printf '%s\n' '{"generation":"stale","xkeen":{"xray":{"speed_balancer":{"enabled":true}}}}' > "$xkeen_config.bak"
cp() {
    if [ "$1" = -p ]; then
        _cp_source=$2
        _cp_destination=$3
    else
        _cp_source=$1
        _cp_destination=$2
    fi
    if [ "$_cp_source" = "$xkeen_config" ]; then
      case "$_cp_destination" in
        "$xkeen_config.bak"*)
        : > "$backup_marker"
        return 1
        ;;
      esac
    fi
    command cp "$@"
}
jc_set_path() { : > "$jc_marker"; return 2; }

sb_write_setting enabled true >/dev/null 2>&1
rc=$?
check 'failed setting write reports failure' "$rc" 1
check 'failed write preserves the current configuration' "$(jq -r '.generation' "$xkeen_config")" current
check 'stale backup is not restored over current config' "$(jq -r '.xkeen.xray.speed_balancer.enabled' "$xkeen_config")" false
check 'failed backup copy is detected' "$([ -e "$backup_marker" ] && echo yes || echo no)" yes
check 'failed backup copy aborts before config rewrite' "$([ -e "$jc_marker" ] && echo yes || echo no)" no

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
