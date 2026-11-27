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

# Предусловия: без них проверки ниже могут проходить вхолостую
# (нет jq -> digest всегда "не найден" -> rc=0 в любом режиме)
command -v jq >/dev/null 2>&1 || { echo 'FAIL precondition: jq not found in PATH'; exit 1; }
command -v verify_github_sha256 >/dev/null 2>&1 || { echo "FAIL precondition: verify_github_sha256 not extracted from $source_file"; exit 1; }

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
printf '{"assets":[{"name":"archive.tar.gz","digest":"sha256:%s"}]}\n' "$(printf '%s' "$actual" | tr 'a-f' 'A-F')" > "$work/upper.json"
printf '%s\n' '{"assets":[{"name":"archive.tar.gz","digest":"sha256:abcd"}]}' > "$work/short.json"
printf '%s\n' '{"assets":[{"name":"archive.tar.gz","digest":"sha256:zz-not-a-digest"}]}' > "$work/garbage.json"

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
API_BODY="$work/match.json" verify_github_sha256 "$payload" "$download_url" "$api_url" > "$work/match.log" 2>&1
check 'warn mode accepts a matching digest' "$?" 0
check 'matching digest produces no warning or error' "$(grep -c -e 'не совпала' -e 'не найдена' "$work/match.log")" 0

# Контракт для вызывающего кода: verify не удаляет файл сам
# (process_geo_file/process_geoip ориентируются на его наличие, чтобы
# выставить _last_error=sha256_mismatch; удаляют файл вызывающие)
check 'file is left in place after a mismatch' "$([ -f "$payload" ] && echo yes || echo no)" yes

# strict: любой сбой проверки — ошибка
verify_downloads=strict
API_BODY="$work/mismatch.json" verify_github_sha256 "$payload" "$download_url" "$api_url" >/dev/null 2>&1
check 'strict mode rejects a SHA-256 mismatch' "$?" 1
API_BODY="$work/missing.json" verify_github_sha256 "$payload" "$download_url" "$api_url" >/dev/null 2>&1
check 'strict mode rejects a release with no published digest' "$?" 1
API_BODY="$work/match.json" verify_github_sha256 "$payload" "$download_url" "$api_url" >/dev/null 2>&1
check 'strict mode accepts a matching digest' "$?" 0

# off: явный отказ пользователя от проверки — несовпадение не блокирует
verify_downloads=off
API_BODY="$work/mismatch.json" verify_github_sha256 "$payload" "$download_url" "$api_url" > "$work/off.log" 2>&1
check 'off mode skips verification' "$?" 0
check 'off mode prints no mismatch error' "$(grep -c 'не совпала' "$work/off.log")" 0

# Формат digest: ровно 64 hex-символа, регистр не важен
verify_downloads=warn
API_BODY="$work/upper.json" verify_github_sha256 "$payload" "$download_url" "$api_url" > "$work/upper.log" 2>&1
check 'upper-case digest matches' "$?" 0
check 'upper-case digest is not reported as mismatch' "$(grep -c 'не совпала' "$work/upper.log")" 0

API_BODY="$work/short.json" verify_github_sha256 "$payload" "$download_url" "$api_url" > "$work/short.log" 2>&1
check 'warn mode treats a short digest as unavailable' "$?" 0
check 'short digest is reported as not found' "$(grep -c 'не найдена' "$work/short.log")" 1
API_BODY="$work/garbage.json" verify_github_sha256 "$payload" "$download_url" "$api_url" >/dev/null 2>&1
check 'warn mode treats a non-hex digest as unavailable' "$?" 0

verify_downloads=strict
API_BODY="$work/short.json" verify_github_sha256 "$payload" "$download_url" "$api_url" >/dev/null 2>&1
check 'strict mode rejects a short digest' "$?" 1
API_BODY="$work/garbage.json" verify_github_sha256 "$payload" "$download_url" "$api_url" >/dev/null 2>&1
check 'strict mode rejects a non-hex digest' "$?" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
