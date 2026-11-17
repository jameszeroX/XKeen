#!/bin/sh
# Stable and Beta XKeen operations should probe only their selected source.
set -u

root=${ROOT:-.}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
eval "$(awk '/^test_github\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/05_tests/01_tests_system.sh")"

xkeen_tar_url=https://github.com/example/releases/latest/download/xkeen.tar.gz
xkeen_dev_url=https://raw.githubusercontent.com/example/main/test/xkeen.tar.gz
gh_proxy_user=''
yellow=''; green=''; red=''; reset=''
_mirror_cache=''
_gh_probed=''
release_ok=1
raw_ok=1
calls="$work/calls"
get_user_proxy() { :; }
probe_with_mirrors() {
    printf '%s\n' "$1" >> "$calls"
    case "$1" in
        "$xkeen_tar_url") [ "$release_ok" = 1 ] ;;
        "$xkeen_dev_url") [ "$raw_ok" = 1 ] ;;
        *) return 1 ;;
    esac
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
run_probe() {
    rm -f "$calls"
    _gh_probed=''
    if (test_github "$1" >/dev/null 2>&1); then rc=0; else rc=$?; fi
    count=$(wc -l < "$calls" 2>/dev/null | tr -d ' ')
}

release_ok=1; raw_ok=0
run_probe "$xkeen_tar_url"
check 'Stable source works while raw is unavailable' "$rc" 0
check 'Stable checks one source' "$count" 1

release_ok=0; raw_ok=1
run_probe "$xkeen_dev_url"
check 'Beta source works while Releases are unavailable' "$rc" 0
check 'Beta checks one source' "$count" 1

release_ok=0; raw_ok=1
run_probe "$xkeen_tar_url"
check 'Stable still fails when its selected source is unavailable' "$rc" 1

release_ok=1; raw_ok=0
run_probe "$xkeen_dev_url"
check 'Beta still fails when its selected source is unavailable' "$rc" 1

release_ok=1; raw_ok=1
run_probe ''
check 'Unqualified legacy probe still checks both sources' "$rc" 0
check 'Unqualified legacy probe retains pair check' "$count" 2

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
