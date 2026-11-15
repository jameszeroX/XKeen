#!/bin/sh
set -u

root=${ROOT:-/repo}
core="$root/scripts/_xkeen/04_tools/08_tools_balancer/01_balancer_core.sh"
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

sb_api_addr=127.0.0.1:10085
sb_balancer=balancer
sb_log_enabled=true
sb_log_file="$work/balancer.log"
sb_pin_file="$work/.sb_pinned"
sb_hysteresis=25
STUB_BO_RC=1
STUB_BO_CALLS=0

xray() {
    case "$2" in
        bi)
            printf '  - Selecting Override:\n  - Selects:\n    1   sub-a\n'
            return 0
            ;;
        bo)
            STUB_BO_CALLS=$((STUB_BO_CALLS + 1))
            return "$STUB_BO_RC"
            ;;
    esac
    return 0
}
sb_node_list() { sb_nodes='sub-a
sub-b'; }
sb_measure_node() {
    case "$1" in
        sub-a) printf '5 200\n' ;;
        sub-b) printf '20 200\n' ;;
    esac
}

. "$core"
sb_node_list() { sb_nodes='sub-a
sub-b'; }
sb_measure_node() {
    case "$1" in
        sub-a) printf '5 200\n' ;;
        sub-b) printf '20 200\n' ;;
    esac
}

printf 'sub-b\n' > "$sb_pin_file"
sb_tick
rc=$?
check 'failed pinned-node recovery returns failure' "$rc" 1
check 'pinned-node recovery attempted API override' "$STUB_BO_CALLS" 1

rm -f "$sb_pin_file"
STUB_BO_CALLS=0
sb_tick
rc=$?
check 'failed automatic override returns failure' "$rc" 1
check 'automatic override attempted API change' "$STUB_BO_CALLS" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
