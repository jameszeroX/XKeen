#!/bin/sh
set -u

root=${ROOT:-/repo}
source_file="$root/scripts/_xkeen/04_tools/07_tools_downloaders/00_fetch_with_mirrors.sh"
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

_release_cache_path() { return 1; }
curl_with_timeout() {
    _out=
    _prev=
    for _arg do
        [ "$_prev" = -o ] && _out=$_arg
        _prev=$_arg
    done
    [ -n "$_out" ] && cp "$API_BODY" "$_out"
}
eval "$(awk '/^verify_github_sha256\(\) \{/,/^}/ { print }' "$source_file")"

red=''; yellow=''; green=''; light_blue=''; reset=''
tmp_ram="$work/cache"
mkdir -p "$tmp_ram"
payload="$work/payload"
printf 'downloaded payload\n' > "$payload"
actual=$(sha256sum "$payload" | awk '{print $1}')
api_url='https://api.github.com/repos/example/project/releases/tags/v1.0.0'
download_url='https://github.com/example/project/releases/download/v1.0.0/archive.tar.gz'

printf '{"assets":[{"name":"archive.tar.gz","digest":"sha256:%s"}]}\n' "$actual" > "$work/match.json"
printf '%s\n' '{"assets":[{"name":"archive.tar.gz","digest":"sha256:0000000000000000000000000000000000000000000000000000000000000000"}]}' > "$work/mismatch.json"
printf '%s\n' '{"assets":[]}' > "$work/missing.json"

verify_downloads=warn
API_BODY="$work/mismatch.json" verify_github_sha256 "$payload" "$download_url" "$api_url" > "$work/mismatch.log" 2>&1
rc=$?
check 'warn mode rejects a known SHA-256 mismatch' "$rc" 1
check 'known mismatch is reported as an error' "$(grep -c 'не совпала' "$work/mismatch.log")" 1

verify_downloads=warn
API_BODY="$work/missing.json" verify_github_sha256 "$payload" "$download_url" "$api_url" > "$work/missing.log" 2>&1
rc=$?
check 'warn mode permits a release with no published digest' "$rc" 0
check 'missing digest remains a warning' "$(grep -c 'не найдена' "$work/missing.log")" 1

verify_downloads=warn
API_BODY="$work/match.json" verify_github_sha256 "$payload" "$download_url" "$api_url" >/dev/null 2>&1
check 'warn mode accepts a matching digest' "$?" 0

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
