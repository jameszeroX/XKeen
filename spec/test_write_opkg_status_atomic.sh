#!/bin/sh
# Failure to read the existing opkg database must not publish a truncated copy.
set -u

root=${ROOT:-.}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
status_file="$work/status"
status_architecture='all'
install_dir="$work"
awk '
    /^write_opkg_status\(\) \{/ { on=1 }
    on { print }
    on && /^}/ { exit }
' "$root/scripts/_xkeen/02_install/07_install_register/00_register_common.sh" > "$work/function.sh"
[ -s "$work/function.sh" ] || { echo 'FAIL could not extract write_opkg_status'; exit 1; }
. "$work/function.sh"

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

CAT_FAIL_PATH=''
cat() {
    _cat_arg=${1:-}
    if [ -n "${CAT_FAIL_PATH:-}" ] && [ "$CAT_FAIL_PATH" = "$_cat_arg" ]; then
        return 42
    fi
    command cat "$@"
}

cat > "$status_file" <<'EOF'
Package: existing-package
Version: 1
Status: install user installed

EOF
write_opkg_status 'new-package' '2' ''
rc=$?
check 'normal registration succeeds' "$rc" 0
grep -q '^Package: existing-package$' "$status_file" && old_preserved=yes || old_preserved=no
grep -q '^Package: new-package$' "$status_file" && new_added=yes || new_added=no
check 'normal registration preserves prior records' "$old_preserved" yes
check 'normal registration adds the new record' "$new_added" yes
cp "$status_file" "$work/expected"
CAT_FAIL_PATH="$status_file"
write_opkg_status 'lost-package' '3' ''
rc=$?
check 'read error is returned to caller' "$rc" 1
if cmp -s "$work/expected" "$status_file"; then unchanged=yes; else unchanged=no; fi
check 'read error leaves the opkg database unchanged' "$unchanged" yes

CAT_FAIL_PATH=''
cp "$status_file" "$work/expected"
ECHO_FAIL=1
echo() {
    [ "${ECHO_FAIL:-0}" = 0 ] || return 1
    command echo "$@"
}
write_opkg_status 'unwritten-package' '4' ''
rc=$?
check 'entry write error is returned to caller' "$rc" 1
if cmp -s "$work/expected" "$status_file"; then unchanged=yes; else unchanged=no; fi
check 'entry write error leaves the opkg database unchanged' "$unchanged" yes

unset -f echo
mktemp() { return 1; }
write_opkg_status 'no-temp-package' '5' ''
rc=$?
check 'temporary entry creation error is returned' "$rc" 1
if cmp -s "$work/expected" "$status_file"; then unchanged=yes; else unchanged=no; fi
check 'temporary entry creation error leaves database unchanged' "$unchanged" yes

mv() { return 1; }
write_opkg_status 'unpublished-package' '6' ''
rc=$?
check 'publish error is returned to caller' "$rc" 1
if cmp -s "$work/expected" "$status_file"; then unchanged=yes; else unchanged=no; fi
check 'publish error leaves the opkg database unchanged' "$unchanged" yes

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
