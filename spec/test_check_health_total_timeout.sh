#!/bin/sh
# check_health must bound the complete response wait, not only connection setup.
set -u

root=${ROOT:-.}
eval "$(awk '/^check_health\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/05_tests/01_tests_system.sh")"

red=''; reset=''; green=''; yellow=''
conn_URL=health.example
call_log=$(mktemp) || exit 1
trap 'rm -f "$call_log"' EXIT INT TERM
check_binary_health() { :; }
_load_packages_info() { :; }
_ensure_installed_packages() { return 0; }
curl() {
    if [ "$1" = --version ]; then return 0; fi
    printf '%s\n' "$*" > "$call_log"
    return 0
}

check_health
rc=$?
args=$(cat "$call_log")
case " $args " in *" --connect-timeout "*) connect_timeout=1 ;; *) connect_timeout=0 ;; esac
case " $args " in *" --max-time "*) total_timeout=1 ;; *) total_timeout=0 ;; esac

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
check 'health check retains connect timeout' "$connect_timeout" 1
check 'health check sets full response timeout' "$total_timeout" 1
check 'successful health request remains successful' "$rc" 0
printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
