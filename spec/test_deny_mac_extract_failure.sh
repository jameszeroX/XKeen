#!/bin/sh
# shellcheck disable=SC2034,SC2329  # Globals and stubs are read by extracted production functions.
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
    awk '/^    _xkeen_sync_deny_mac_ipset\(\) \{/{on=1} on{print} on && /^    \}/{exit}' \
        "$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh"
}
eval "$(extract)"

name_ipset_deny_mac=xkeen_deny_mac
url_server=http://router
url_hotspot=rci/show/hotspot
hotspot_state="$work/live-set"
staged="$work/staged"
printf 'old-deny-entry\n' > "$hotspot_state"
swaps=0
jq_extract_fail=1
restore_fail=0
swap_fail=0

command() {
    [ "$1" = -v ] && [ "$2" = ipset ]
}
jq() {
    case "$1" in
        -e) return 0 ;;
        -r)
            [ "$jq_extract_fail" -eq 0 ] || return 1
            printf 'AA:BB:CC:DD:EE:FF\n'
            return 0
            ;;
    esac
    return 1
}
curl_api() { printf '{"host":[{"access":"deny","mac":"AA:BB:CC:DD:EE:FF"}]}'; }
log_router() { :; }
ipset() {
    case "$1" in
        create|flush|destroy) return 0 ;;
        restore) cat > "$staged"; return "$restore_fail" ;;
        swap)
            swaps=$((swaps + 1))
            [ "$swap_fail" -eq 0 ] || return 1
            cp "$staged" "$hotspot_state"
            return 0
            ;;
    esac
    return 1
}

_xkeen_sync_deny_mac_ipset
rc=$?
check 'jq extraction failure is returned' "$rc" 1
check 'jq extraction failure does not swap the live deny set' "$swaps" 0
check 'jq extraction failure preserves existing deny entries' "$(cat "$hotspot_state")" old-deny-entry

jq_extract_fail=0
for fail_stage in restore swap; do
    swaps=0; restore_fail=0; swap_fail=0
    [ "$fail_stage" != restore ] || restore_fail=1
    [ "$fail_stage" != swap ] || swap_fail=1
    printf 'old-deny-entry\n' > "$hotspot_state"
    _xkeen_sync_deny_mac_ipset >/dev/null 2>&1
    check "$fail_stage failure is returned" "$?" 1
    expected_swaps=0
    [ "$fail_stage" != swap ] || expected_swaps=1
    check "$fail_stage failure reaches expected swap boundary" "$swaps" "$expected_swaps"
    check "$fail_stage failure preserves prior deny entries" "$(cat "$hotspot_state")" old-deny-entry
done

restore_fail=0; swap_fail=0; swaps=0
printf 'old-deny-entry\n' > "$hotspot_state"
_xkeen_sync_deny_mac_ipset
check 'normal deny sync succeeds' "$?" 0
check 'normal deny sync swaps exactly once' "$swaps" 1
check 'normal deny sync installs extracted MAC' "$(cat "$hotspot_state")" 'add xkeen_deny_mac_tmp_'"$$"' AA:BB:CC:DD:EE:FF -exist'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
