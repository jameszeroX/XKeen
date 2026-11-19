#!/bin/sh
# shellcheck disable=SC2034,SC2329  # Globals and stubs are read by extracted production functions.
set -u

root=${ROOT:-/repo}
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
file="$root/scripts/_xkeen/04_tools/01_tools_ports.sh"
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$file"
}
eval "$(extract del_ports_donor)"
eval "$(extract del_ports_exclude)"

file_port_proxying="$work/proxy.ports"
file_port_exclude="$work/exclude.ports"
red=''; yellow=''; green=''; light_blue=''; reset=''
normalize_ports() { printf '%s\n' "$1"; }
read_ports_file() { printf '80,443\n'; }
confirm_deletion() { return 0; }
write_ports_file() { return 1; }

output=$(del_ports_donor 2>&1)
rc=$?
check 'clear all proxy ports reports write failure' "$rc" 1
case "$output" in *'Все порты удалены'*) result=success ;; *) result=error ;; esac
check 'clear all proxy ports does not report success on failure' "$result" error

output=$(del_ports_exclude 2>&1)
rc=$?
check 'clear all exclude ports reports write failure' "$rc" 1
case "$output" in *'Все исключения удалены'*) result=success ;; *) result=error ;; esac
check 'clear all exclude ports does not report success on failure' "$result" error

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
