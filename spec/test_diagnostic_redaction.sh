#!/bin/sh
set -u
root=/repo
extract() {
    awk -v name="$1" '$0 == "    " name "() {" { found=1 } found { print } found && $0 == "    }" { exit }' "$root/scripts/_xkeen/04_tools/03_tools_diagnostic.sh"
}
eval "$(awk '/^strip_json_comments\(\) \{/,/^\}/' "$root/scripts/_xkeen/01_info/01_info_common.sh")"
for name in mask_json_sensitive_data mask_xray_sensitive_data mask_mihomo_sensitive_data; do
    eval "$(extract "$name")"
done
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
actual=$(printf '%s' '{"password":"first SECOND_SENTINEL","nested":{"shortIds":["ARRAY_SENTINEL"],"serverNames":["SNI_SENTINEL"],"port":443}}' | mask_xray_sensitive_data)
check 'password with spaces' "$(printf '%s' "$actual" | jq -r .password)" '***MASKED***'
check 'sensitive arrays' "$(printf '%s' "$actual" | jq -r '.nested.shortIds,.nested.serverNames' | sort -u)" '***MASKED***'
check 'ordinary values preserved' "$(printf '%s' "$actual" | jq -r .nested.port)" 443
check 'no secret suffix or array member' "$(printf '%s' "$actual" | grep -c SENTINEL)" 0
actual=$(printf '%s' '{"password":"HIDDEN_SENTINEL"} invalid' | mask_xray_sensitive_data)
check 'malformed JSON omitted' "$(printf '%s' "$actual" | grep -c SENTINEL)" 0
check 'JSON parse failure reported' "$(printf '%s' '{bad' | mask_xray_sensitive_data >/dev/null; echo "$?")" 1
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT INT TERM
install_dir=$scratch
ln -s "$(command -v yq)" "$install_dir/yq"
actual=$(printf '%s' 'proxies: [{name: proxy, type: trojan, password: FLOW_SENTINEL, server: HOST_SENTINEL, port: 443}]' | mask_mihomo_sensitive_data)
check 'flow YAML password' "$(printf '%s' "$actual" | jq -r '.proxies[0].password')" '***MASKED***'
check 'flow YAML server' "$(printf '%s' "$actual" | jq -r '.proxies[0].server')" '***MASKED***'
check 'YAML ordinary values preserved' "$(printf '%s' "$actual" | jq -r '.proxies[0].name')" proxy
check 'no flow YAML secrets' "$(printf '%s' "$actual" | grep -c SENTINEL)" 0
actual=$(printf '%s' 'proxies: [{password: YAML_SENTINEL' | mask_mihomo_sensitive_data)
check 'malformed YAML omitted' "$(printf '%s' "$actual" | grep -c SENTINEL)" 0
rm "$install_dir/yq"
check 'missing YAML parser fails closed' "$(printf '%s' 'password: MISSING_SENTINEL' | mask_mihomo_sensitive_data >/dev/null; echo "$?")" 1
printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
