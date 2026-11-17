#!/bin/sh
# A failed Yq validation or publication must preserve the installed binary.
set -u

root=${ROOT:-.}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
mkdir -p "$work/tmp" "$work/opt/sbin" || exit 1

install_dir="$work/opt/sbin"
tmp_ram="$work/tmp"
architecture=arm64-v8a
retries_download=1
retry_delay_download=0
verify_downloads=warn
yellow=''
red=''
green=''
reset=''

get_yq_dist_url() { printf '%s\n' 'https://example.invalid/yq'; }
get_yq_api_url() { printf '%s\n' 'https://example.invalid/api'; }
_network_probe() { return 0; }
_network_download() {
    cat > "$2" <<'YQ'
#!/bin/sh
if [ "${1-}" = "--version" ]; then
    [ "${YQ_TEST_INVALID-}" != "1" ] || exit 42
    printf '%s\n' 'yq version v4.0.0'
    exit 0
fi
exit 2
YQ
    return 0
}
verify_github_sha256() { [ "${VERIFY_FAIL-}" != "1" ]; }

eval "$(awk '/^_publish_yq_candidate\(\) \{/,/^}/ { print } /^download_yq\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/04_tools/07_tools_downloaders/01_downloaders_mihomo.sh")"

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

printf '%s\n' 'old-yq' > "$install_dir/yq"
VERIFY_FAIL=1
export VERIFY_FAIL
output=$(download_yq 2>&1)
rc=$?
check 'integrity failure is reported' "$rc" 1
check 'integrity failure preserves the installed Yq' "$(cat "$install_dir/yq")" old-yq
unset VERIFY_FAIL

YQ_TEST_INVALID=1
export YQ_TEST_INVALID
output=$(download_yq 2>&1)
rc=$?
check 'invalid downloaded executable is rejected' "$rc" 1
check 'invalid download preserves the installed Yq' "$(cat "$install_dir/yq")" old-yq
check 'invalid download leaves no destination staging file' "$(find "$install_dir" -name '.yq.*' -type f | wc -l | tr -d ' ')" 0

unset YQ_TEST_INVALID
chmod() { return 23; }
output=$(download_yq 2>&1)
rc=$?
check 'chmod failure is reported' "$rc" 1
check 'chmod failure preserves the installed Yq' "$(cat "$install_dir/yq")" old-yq
unset -f chmod

cp() { return 24; }
output=$(download_yq 2>&1)
rc=$?
check 'destination staging copy failure is reported' "$rc" 1
check 'staging copy failure preserves the installed Yq' "$(cat "$install_dir/yq")" old-yq
check 'staging copy failure leaves no destination staging file' "$(find "$install_dir" -name '.yq.*' -type f | wc -l | tr -d ' ')" 0
unset -f cp

mv() { return 25; }
output=$(download_yq 2>&1)
rc=$?
check 'final publish failure is reported' "$rc" 1
check 'final publish failure preserves the installed Yq' "$(cat "$install_dir/yq")" old-yq
check 'final publish failure removes destination staging file' "$(find "$install_dir" -name '.yq.*' -type f | wc -l | tr -d ' ')" 0
unset -f mv

output=$(download_yq 2>&1)
rc=$?
check 'valid Yq download succeeds' "$rc" 0
check 'valid Yq replaces the installed binary' "$("$install_dir/yq" --version 2>/dev/null | sed 's/.*v/v/')" v4.0.0
check 'successful publish leaves no staging file' "$(find "$install_dir" -name '.yq.*' -type f | wc -l | tr -d ' ')" 0

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
