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
eval "$(awk '/^    _xkeen_cache_valid\(\) \{/,/^    }/ { print }' "$file")"
_xkeen_cache_dir="$work/cache"
md5sum() { printf 'expected-digest  %s\n' "$1"; }
mkdir -p "$_xkeen_cache_dir"
printf '%s\n' expected-digest > "$_xkeen_cache_dir/key"

_xkeen_cache_valid
check 'key without restore blobs is invalid' "$?" 1

for name in v4_nat v4_mangle v6_nat v6_mangle; do : > "$_xkeen_cache_dir/$name"; done
_xkeen_cache_valid
check 'all four empty blobs are a valid cache entry' "$?" 0

printf '%s\n' 'not an iptables rule' > "$_xkeen_cache_dir/v4_nat"
_xkeen_cache_valid
check 'malformed restore blob invalidates the cache' "$?" 1

printf '%s\n' '-A PREROUTING -j XKeen' > "$_xkeen_cache_dir/v4_nat"
_xkeen_cache_valid
check 'well-formed rule line remains cacheable' "$?" 0

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
