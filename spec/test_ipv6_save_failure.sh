#!/bin/sh
# IPv6 must not be reported as enabled when NDM did not persist the change.
set -u

root=${ROOT:-.}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
eval "$(awk '/^change_ipv6_support\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/04_tools/05_tools_choice/02_choice_xkeen.sh")"

initd_file="$work/S05xkeen"
printf 'ipv6_support="off"\n' > "$initd_file"
ip6_supported=false
save_rc=0
op_rc=0
green=''; red=''; yellow=''; reset=''
check_ipv6_active() { [ "$ip6_supported" = true ]; }
sysctl() {
    if [ "$1" = -n ]; then printf '0'; fi
    return 0
}
ndmc() {
    case "$*" in
        *'system configuration save'*) return "$save_rc" ;;
        *'ipv6 subnet Default'*) return "$op_rc" ;;
        *) return 0 ;;
    esac
}
pidof() { return 1; }

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

save_rc=0
success_output=$(change_ipv6_support on 2>&1)
success_rc=$?
case "$success_output" in *'Поддержка IPv6 в KeeneticOS включена'*) success_message=yes ;; *) success_message=no ;; esac
check 'successful NDM save is reported' "$success_message:$success_rc" yes:0

printf 'ipv6_support="off"\n' > "$initd_file"
save_rc=1
failure_output=$(change_ipv6_support on 2>&1)
failure_rc=$?
case "$failure_output" in *'Ошибка при включении IPv6'*) failure_message=yes ;; *) failure_message=no ;; esac
check 'failed NDM save is reported as an error' "$failure_message:$failure_rc" yes:1

printf 'ipv6_support="off"\n' > "$initd_file"
save_rc=0
op_rc=1
failure_output=$(change_ipv6_support on 2>&1)
failure_rc=$?
case "$failure_output" in *'Ошибка при включении IPv6'*) failure_message=yes ;; *) failure_message=no ;; esac
check 'failed NDM IPv6 command is reported as an error' "$failure_message:$failure_rc" yes:1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
