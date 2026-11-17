#!/bin/sh
# A transport failure must not be treated as a successful HTTP probe.
set -u

root=${ROOT:-.}
eval "$(awk '/^probe_with_mirrors\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/04_tools/07_tools_downloaders/00_fetch_with_mirrors.sh")"

_DIRECT_TOKEN=__direct__
gh_proxy_user=''
MOCK_HTTP=200
MOCK_RC=0
MOCK_RANGE_HTTP=200
MOCK_RANGE_RC=28
MOCK_ORDER=__direct__
_mirror_order() { printf '%s\n' "$MOCK_ORDER"; }
_mirror_cache_write() { :; }
curl_with_timeout() {
    _mock_last_arg=''
    for _mock_arg do _mock_last_arg=$_mock_arg; done
    if [ "$MOCK_HTTP" = 405 ] && [ "$1" = -I ]; then
        printf '405'
        return 0
    fi
    if [ "$MOCK_HTTP" = 405 ] && [ "$1" = -s ]; then
        printf '%s' "$MOCK_RANGE_HTTP"
        return "$MOCK_RANGE_RC"
    fi
    printf '%s' "$MOCK_HTTP"
    return "$MOCK_RC"
}

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

MOCK_HTTP=200; MOCK_RC=28
probe_with_mirrors https://probe.example
check 'HTTP 200 with curl timeout is failure' "$?" 1
check 'curl timeout is retained' "$_last_curl_rc" 28

MOCK_HTTP=200; MOCK_RC=0
probe_with_mirrors https://probe.example
check 'HTTP 200 with successful curl passes' "$?" 0

MOCK_HTTP=404; MOCK_RC=0
probe_with_mirrors https://probe.example
check 'HTTP 404 with successful curl is definitive miss' "$?" 2

MOCK_HTTP=404; MOCK_RC=28
probe_with_mirrors https://probe.example
check 'HTTP 404 with curl failure is transient' "$?" 1

MOCK_HTTP=405; MOCK_RC=0; MOCK_RANGE_HTTP=200; MOCK_RANGE_RC=28
probe_with_mirrors https://probe.example
check 'range fallback HTTP 200 with curl failure is failure' "$?" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
