#!/bin/sh
set -u

root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'command rm -rf "$work"' EXIT INT TERM
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
    awk '$0 == "download_with_check() {" { on=1 } on { print } on && /^}/ { exit }' "$1"
}
curl_mode=transfer_error
curl() {
    out=''
    previous=''
    for arg do
        if [ "$previous" = -o ]; then out=$arg; fi
        previous=$arg
    done
    case "$curl_mode" in
        transfer_error|http_error) printf 'partial-content' > "$out"; return 28 ;;
        success) printf 'valid-content' > "$out"; return 0 ;;
    esac
}

for source in "$root/install.sh" "$root/scripts/_xkeen/05_tests/01_tests_system.sh"; do
    eval "$(extract "$source")"
    output_file="$work/download.bin"
    curl_mode=transfer_error
    download_with_check https://example.test/file "$output_file" 5
    rc=$?
    check "curl transfer failure propagates from $source" "$rc" 1
    check "partial file is removed from $source" "$( [ -e "$output_file" ] && echo yes || echo no )" no

    curl_mode=success
    download_with_check https://example.test/file "$output_file" 5
    rc=$?
    check "complete download still succeeds from $source" "$rc" 0
    check "successful output remains from $source" "$( [ -f "$output_file" ] && echo yes || echo no )" yes
done

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
