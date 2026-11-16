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
eval "$(extract write_ports_file)"
eval "$(extract add_ports_donor)"
eval "$(extract add_ports_exclude)"

# shellcheck disable=SC2034
file_port_proxying="$work/proxy.ports"
# shellcheck disable=SC2034
file_port_exclude="$work/exclude.ports"
# Colors are interpolated by extracted production functions.
# shellcheck disable=SC2034
red=''
# shellcheck disable=SC2034
yellow=''
# shellcheck disable=SC2034
green=''
# shellcheck disable=SC2034
light_blue=''
# shellcheck disable=SC2034
reset=''
printf 'old-list\n' > "$file_port_proxying"
printf 'old-excludes\n' > "$file_port_exclude"
normalize_ports() { printf '%s\n' "$1"; }
read_ports_file() { printf '80,443\n'; }
merge_ports_lists() { printf '%s\n' "$1"; }
ensure_web_ports() { printf '%s\n' "$1"; }
ports_conflict_check() { return 1; }
fail_mv=true
mv() {
    [ "$fail_mv" = true ] && return 1
    command mv "$@"
}

output=$(add_ports_donor 1234 2>&1)
rc=$?
check 'proxy port addition propagates publication failure' "$rc" 1
check 'proxy port file is preserved' "$(command cat "$file_port_proxying")" old-list
case "$output" in *'обновлены'*) message=success ;; *) message=error ;; esac
check 'proxy port addition does not claim success' "$message" error

output=$(add_ports_exclude 8443 2>&1)
rc=$?
check 'exclude port addition propagates publication failure' "$rc" 1
check 'exclude port file is preserved' "$(command cat "$file_port_exclude")" old-excludes
case "$output" in *'обновлены'*) message=success ;; *) message=error ;; esac
check 'exclude port addition does not claim success' "$message" error

fail_mv=false
write_fail=true
printf() {
    [ "$write_fail" = true ] && [ "$2" = '# XKeen ports list' ] && return 1
    command printf "$@"
}
output=$(add_ports_donor 5555 2>&1)
rc=$?
write_fail=false
check 'temporary file write failure propagates' "$rc" 1
check 'write failure preserves old port file' "$(command cat "$file_port_proxying")" old-list

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
