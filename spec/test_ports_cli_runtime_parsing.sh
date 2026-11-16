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
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}
tools="$root/scripts/_xkeen/04_tools/01_tools_ports.sh"
runtime="$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh"
eval "$(extract normalize_ports "$tools")"
eval "$(extract read_ports_file "$tools")"
eval "$(extract read_ports_from_file "$runtime")"
eval "$(extract validate_and_clean_ports "$runtime")"

fixture="$work/ports.lst"
cat > "$fixture" <<'EOF'
# user comment
80 # inline note
100 : 200
300-250 # reversed range
0
70000
443
EOF
cli=$(read_ports_file "$fixture")
runtime_result=$(validate_and_clean_ports "$(read_ports_from_file "$fixture")" '')
check 'CLI and runtime normalize the same port file' "$cli" "$runtime_result"
check 'comments, spacing, bounds and ranges have stable canonical output' "$cli" '80,100:200,250:300,443'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
