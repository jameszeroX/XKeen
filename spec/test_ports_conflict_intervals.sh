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
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/04_tools/01_tools_ports.sh"
}
eval "$(extract read_ports_file)"
eval "$(extract ports_conflict_check)"

file1="$work/ports1"
file2="$work/ports2"
write_ports_file() {
    printf '%s\n' "$1" > "$file1"
    printf '%s\n' "$2" > "$file2"
}

write_ports_file '80' '443'
ports_conflict_check "$file1" "$file2"
check 'different singleton ports do not conflict' "$?" 1

write_ports_file '100:200' '150'
ports_conflict_check "$file1" "$file2"
check 'single port inside range conflicts' "$?" 0

write_ports_file '100:200' '300:400'
ports_conflict_check "$file1" "$file2"
check 'disjoint ranges do not conflict' "$?" 1

write_ports_file '80' '80'
ports_conflict_check "$file1" "$file2"
check 'equal singleton ports conflict' "$?" 0

write_ports_file '80,100:200' '90'
ports_conflict_check "$file1" "$file2"
check 'multiple entries compare actual intervals' "$?" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
