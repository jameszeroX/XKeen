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

eval "$(awk '$0 == "delete_register_xkeen() {" { on=1 } on { print } on && /^}/ { exit }' \
    "$root/scripts/_xkeen/03_delete/05_delete_register.sh")"

status_file="$work/status"
register_dir="$work/register"
mkdir -p "$register_dir"
cat > "$status_file" <<'EOF'
Package: xkeen
Version: 2.2
Installed-Time: 1

Package: xkeen-tools
Version: 1.0
Installed-Time: 2

Package: unrelated
Version: 1.0
Installed-Time: 3
EOF

delete_register_xkeen
check 'exact XKeen record removed' "$(grep -c '^Package: xkeen$' "$status_file")" 0
check 'similarly named package retained' "$(grep -c '^Package: xkeen-tools$' "$status_file")" 1
check 'unrelated record retained' "$(grep -c '^Package: unrelated$' "$status_file")" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
