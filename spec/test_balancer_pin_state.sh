#!/bin/sh
set -u
root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
pass=0
fail=0
green=""
reset=""
yellow=""
red=""
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
core="$root/scripts/_xkeen/04_tools/08_tools_balancer/01_balancer_core.sh"
control="$root/scripts/_xkeen/04_tools/08_tools_balancer/02_balancer_control.sh"
. "$core"
eval "$(extract sb_apply_node "$control")"
eval "$(extract sb_auto "$control")"
eval "$(extract sb_auto_locked "$control")"
sb_tick_locked() { sb_tick; }

sb_api_addr=127.0.0.1:10085
sb_balancer=balancer
sb_log_enabled=true
sb_log_file="$work/balancer.log"
sb_pin_file="$work/.sb_pinned"
sb_enabled=false
reset_rc=1
last_bo=''
api_available=true
speed_balancer_settings() { :; }
sb_api_alive() { [ "$api_available" = true ]; }
sb_current_target() { printf 'old-node\n'; }
sb_tick() { return 0; }
xray() {
    case "$2" in
        bo)
            last_bo="$*"
            case " $* " in
                *' -r '*) return "$reset_rc" ;;
                *' old-node '*) return "${restore_rc:-0}" ;;
                *) return 0 ;;
            esac
            ;;
        *) return 0 ;;
    esac
}

printf 'manual-node\n' > "$sb_pin_file"
reset_rc=1
out=$(sb_auto 2>&1); rc=$?
check 'failed API reset returns an error' "$rc" 1
check 'failed API reset keeps manual pin' "$(cat "$sb_pin_file")" manual-node
case "$out" in *'Ручное закрепление снято'*) success=yes ;; *) success=no ;; esac
check 'failed API reset does not claim pin was removed' "$success" no

api_available=false
out=$(sb_auto 2>&1); rc=$?
check 'unavailable API returns an error' "$rc" 1
check 'unavailable API keeps manual pin' "$(cat "$sb_pin_file")" manual-node

api_available=true
reset_rc=0
sb_auto >/dev/null 2>&1; rc=$?
check 'successful API reset returns success' "$rc" 0
check 'successful API reset clears manual pin' "$(sb_pin_get)" ''

sb_pin_set() { return 1; }
restore_rc=0
sb_apply_node new-node; rc=$?
check 'failed pin write after API success returns error' "$rc" 1
case " $last_bo " in *' old-node '*) rolled_back=yes ;; *) rolled_back=no ;; esac
check 'failed pin write rolls API target back when possible' "$rolled_back" yes
check 'failed pin write does not log a successful pin' "$(grep -c 'закреплена)' "$sb_log_file" 2>/dev/null || true)" 0

last_bo=''
restore_rc=1
sb_apply_node another-node; rc=$?
check 'failed rollback reports partial state distinctly' "$rc" 2
case " $last_bo " in *' old-node '*) rollback_attempted=yes ;; *) rollback_attempted=no ;; esac
check 'failed rollback was attempted' "$rollback_attempted" yes

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
