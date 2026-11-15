#!/bin/sh
set -u
root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
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
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}
common="$root/scripts/_xkeen/01_info/01_info_common.sh"
xray_installer="$root/scripts/_xkeen/02_install/02_install_xray.sh"
eval "$(extract strip_json_comments "$common")"
eval "$(extract xray_conf_has_transport_key "$xray_installer")"

printf '%s\n' '{' '  /* "transport": "comment-only" */' '  "outbounds": []' '}' > "$work/comment.json"
printf '%s\n' '{"note":"contains \"transport\": as text","outbounds":[]}' > "$work/string.json"
printf '%s\n' '{"streamSettings":{"transport":{"protocol":"tcp"}}}' > "$work/key.json"
printf '%s\n' '{"streamSettings":' > "$work/broken.json"

if command -v xray_conf_has_transport_key >/dev/null 2>&1; then
    xray_conf_has_transport_key "$work/comment.json"; rc=$?
    check 'JSONC comment is not treated as a key' "$rc" 1
    xray_conf_has_transport_key "$work/string.json"; rc=$?
    check 'escaped string contents are not treated as a key' "$rc" 1
    xray_conf_has_transport_key "$work/key.json"; rc=$?
    check 'actual nested transport key is detected' "$rc" 0
    xray_conf_has_transport_key "$work/broken.json"; rc=$?
    check 'invalid JSON is not renamed as obsolete' "$rc" 1
else
    check 'structural key detector exists' no yes
fi

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
