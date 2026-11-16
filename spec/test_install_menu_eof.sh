#!/bin/sh
set -u

root=${ROOT:-/repo}
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

eval "$(awk '$0 == "read_install_input() {" { on=1 } on { print } on && /^}/ { exit }' "$root/install.sh")"
read_install_input value </dev/null
rc=$?
check 'EOF is returned as an input error' "$rc" 1

value=''
read_install_input value <<'EOF'
3
EOF
check 'normal input remains available to caller' "$value" 3

call_sites=$(grep -c 'if ! read_install_input' "$root/install.sh")
check 'both menu reads check EOF' "$call_sites" 2

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
