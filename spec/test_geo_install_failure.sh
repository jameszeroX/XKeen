#!/bin/sh
set -u
root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
pass=0
fail=0
red=""
green=""
yellow=""
reset=""
retries_download=1
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
eval "$(extract process_geo_file "$root/scripts/_xkeen/02_install/04_install_geofile.sh")"
eval "$(extract install_geoipset_lst "$root/scripts/_xkeen/02_install/05_install_geoipset.sh")"

_get_expected_size() { printf '4\n'; }
_download_and_validate_loop() { printf 'new!' > "$2"; return 0; }
_is_github_release_url() { return 1; }
verify_github_sha256() { return 0; }
mv() {
    case "$3" in
        "$fail_publish_path") return 1 ;;
    esac
    command mv "$@"
}

geo_dir="$work/geo"
mkdir -p "$geo_dir"
printf 'old!' > "$geo_dir/test.dat"
fail_publish_path="$geo_dir/test.dat"
_last_error=''
out=$(process_geo_file 'https://example.invalid/test.dat' 'test.dat' 'Test GeoFile' true 2>&1)
rc=$?
check 'GeoFile publish failure returns nonzero' "$rc" 1
check 'GeoFile keeps last good file' "$(cat "$geo_dir/test.dat")" 'old!'
case "$out" in *'успешно обновлён'*) success=yes ;; *) success=no ;; esac
check 'GeoFile does not print success after publish failure' "$success" no
case "$out" in *'не удалось установить файл'*) install_error=yes ;; *) install_error=no ;; esac
check 'GeoFile reports installation failure' "$install_error" yes

dest_file="$work/geoipset.dat"
printf 'old!' > "$dest_file"
fail_publish_path="$dest_file"
url='https://example.invalid/geoipset.dat'
action=update
_last_error=''
out=$(install_geoipset_lst "$url" "$dest_file" 'Test GeoIPSET' ipv4 2>&1)
rc=$?
check 'GeoIPSET publish failure returns nonzero' "$rc" 1
check 'GeoIPSET keeps last good file' "$(cat "$dest_file")" 'old!'
case "$out" in *'успешно обновлён'*) success=yes ;; *) success=no ;; esac
check 'GeoIPSET does not print success after publish failure' "$success" no
case "$out" in *'не удалось установить файл'*) install_error=yes ;; *) install_error=no ;; esac
check 'GeoIPSET reports installation failure' "$install_error" yes

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
