#!/bin/sh
set -u

root=${ROOT:-/repo}
file="$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh"
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
    awk -v name="$1" '$0 == name "() {" || $0 == "    " name "() {" { on=1 } on { print } on && ($0 == "}" || $0 == "    }") { exit }' "$file"
}
command -v jq >/dev/null 2>&1 || { echo 'jq is required' >&2; exit 2; }
eval "$(extract validate_api_policy_response)"
eval "$(extract get_policy_mark)"
eval "$(extract should_reset_policy_mark)"
eval "$(awk '/^sync_deny_mac_ipset\(\) \{/{on=1} on && /^# Получаем пользовательские политики/{exit} on{print}' "$file")"
has_policy_validator=0
has_reset_guard=0
command -v validate_api_policy_response >/dev/null 2>&1 && has_policy_validator=1
command -v should_reset_policy_mark >/dev/null 2>&1 && has_reset_guard=1
check 'policy response validator is available' "$has_policy_validator" 1
check 'policy reset guard is available' "$has_reset_guard" 1

for fixture in '{"status":"error"}' '{"status":[{"status":"error","code":"6553609"}]}' 'not-json'; do
    printf '%s' "$fixture" > "$work/response.json"
    api_policy_json=$(cat "$work/response.json")
    validate_api_policy_response >/dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 127 ]; then rejected=missing; elif [ "$rc" -ne 0 ]; then rejected=1; else rejected=0; fi
    check "policy API error rejected: $fixture" "$rejected" 1
done

for fixture in '[]' '[{"description":"other","mark":"123"}]' '{"Policy0":{"description":"xkeen","mark":"111"}}'; do
    api_policy_json=$fixture
    validate_api_policy_response >/dev/null 2>&1
    check "valid policy collection accepted: $fixture" "$?" 0
done

api_policy_json='{"status":"error"}'
if [ "$has_reset_guard" -ne 1 ]; then policy_cache_action=missing
elif should_reset_policy_mark xkeen >/dev/null 2>&1; then policy_cache_action=reset; else policy_cache_action=preserve; fi
check 'RCI application error preserves cached policy mark' "$policy_cache_action" preserve

for fixture in '[]' '[{"description":"other","mark":"123"}]'; do
    api_policy_json=$fixture
    if [ "$has_reset_guard" -ne 1 ]; then policy_cache_action=missing
    elif should_reset_policy_mark xkeen >/dev/null 2>&1; then policy_cache_action=reset; else policy_cache_action=preserve; fi
    check "valid response without XKeen policy resets cache: $fixture" "$policy_cache_action" reset
done

name_ipset_deny_mac=xkeen_deny_mac
url_server=unused
url_hotspot=unused
ipset_state="$work/live-set"
printf '%s\n' 'old-deny-entry' > "$ipset_state"
hotspot_payload=''
swaps=0
restore_failure=0
swap_failure=0
curl_api() { printf '%s' "$hotspot_payload"; }
log_warning_router() { :; }
command() { [ "$1" = -v ] && [ "$2" = ipset ]; }
ipset() {
    case "$1" in
        create|flush|destroy) return 0 ;;
        restore) cat > "$work/staged"; return "$restore_failure" ;;
        swap) swaps=$((swaps + 1)); [ "$swap_failure" -eq 0 ] || return 1; cp "$work/staged" "$ipset_state"; return 0 ;;
    esac
}

for hotspot_payload in 'not-json' '{"status":"error"}' '{"host":"wrong-type"}'; do
    swaps=0
    sync_deny_mac_ipset
    check "invalid hotspot response does not swap: $hotspot_payload" "$swaps" 0
    check 'invalid hotspot response preserves live set' "$(cat "$ipset_state")" old-deny-entry
done

hotspot_payload='{"host":[{"access":"deny","mac":"aa:bb:cc:dd:ee:ff"},{"access":"permit","mac":"02:00:00:00:00:01"}]}'
swaps=0
sync_deny_mac_ipset
check 'valid hotspot response swaps once' "$swaps" 1
check 'valid hotspot response installs deny-only entry' "$(cat "$ipset_state" | grep -c 'AA:BB:CC:DD:EE:FF')" 1

for failure in restore swap; do
    printf '%s\n' old-deny-entry > "$ipset_state"
    swaps=0; restore_failure=0; swap_failure=0
    [ "$failure" != restore ] || restore_failure=1
    [ "$failure" != swap ] || swap_failure=1
    sync_deny_mac_ipset >/dev/null 2>&1
    check "$failure failure is returned" "$?" 1
    check "$failure failure preserves live deny set" "$(cat "$ipset_state")" old-deny-entry
done

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
