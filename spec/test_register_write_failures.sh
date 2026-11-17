#!/bin/sh
set -u

root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'command rm -rf "$work"' EXIT INT TERM
pass=0
fail=0

check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass + 1))
    else
        printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"; fail=$((fail + 1))
    fi
}
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}
register_dir="$work/register"
mkdir -p "$register_dir"
xkeen_dir="$work/xkeen"
mkdir -p "$xkeen_dir/subdir"
install_dir="$work/bin"
initd_file="$work/init/S24xkeen"
log_dir="$work/log"
mkdir -p "$install_dir" "$(dirname "$initd_file")" "$log_dir"
eval "$(extract register_xkeen_list "$root/scripts/_xkeen/02_install/07_install_register/02_register_xkeen.sh")"

# A partial find result followed by an error must not replace the last list.
printf 'previous-list\n' > "$register_dir/xkeen.list"
find() { printf '%s\n' "$xkeen_dir/partial"; return 1; }
register_xkeen_list; rc=$?
check 'find error is returned by register_xkeen_list' "$rc" 1
check 'find error preserves previous registration list' "$(command cat "$register_dir/xkeen.list")" 'previous-list'
unset -f find

cp() { printf 'partial copy\n' > "$3"; return 1; }
register_xkeen_list; rc=$?
unset -f cp
check 'copy failure is returned by register_xkeen_list' "$rc" 1
check 'copy failure preserves previous registration list' "$(command cat "$register_dir/xkeen.list")" 'previous-list'
check 'copy failure removes its temporary list' "$(find "$register_dir" -name '.xkeen.list.tmp.*' | wc -l | tr -d ' ')" 0

# A failed publication must also leave the previous file intact.
printf 'previous-list\n' > "$register_dir/xkeen.list"
mv() { return 1; }
register_xkeen_list; rc=$?
check 'list publication failure is returned' "$rc" 1
check 'publication failure preserves previous registration list' "$(command cat "$register_dir/xkeen.list")" 'previous-list'
unset -f mv
register_xkeen_list; rc=$?
check 'normal xkeen.list publication succeeds' "$rc" 0
grep -Fq "$xkeen_dir/subdir" "$register_dir/xkeen.list"
check 'published xkeen.list contains discovered paths' "$?" 0
grep -Fq "$install_dir/xkeen" "$register_dir/xkeen.list"
check 'published xkeen.list contains registration paths' "$?" 0

status_file="$work/status"
cat > "$status_file" <<'EOF'
Package: xray_s
Version: 1
Installed-Time: 1

Package: mihomo_s
Version: 1
Installed-Time: 2

Package: yq_s
Version: 1
Installed-Time: 3

Package: xkeen
Version: 2
Installed-Time: 4

Package: unrelated
Version: 1
Installed-Time: 5
EOF
cp "$status_file" "$work/base-status"
register_dir="$work/register-files"
mkdir -p "$register_dir"
delete_file="$root/scripts/_xkeen/03_delete/05_delete_register.sh"
for fn in delete_register_xray delete_register_mihomo delete_register_yq delete_register_xkeen; do
    eval "$(extract "$fn" "$delete_file")"
    cp "$work/base-status" "$status_file"
    cp "$work/base-status" "$work/original"
    awk() { printf 'partial output\n'; return 1; }
    "$fn"; rc=$?
    unset -f awk
    check "$fn returns an AWK failure" "$rc" 1
    check "$fn preserves unrelated opkg records on AWK failure" "$(command cat "$status_file")" "$(command cat "$work/original")"
    "$fn"; rc=$?
    check "$fn succeeds after a normal AWK run" "$rc" 0
    grep -q '^Package: unrelated$' "$status_file"
    check "$fn retains unrelated status records" "$?" 0
done

eval "$(extract delete_register_xray "$delete_file")"
cp "$work/base-status" "$status_file"
cp "$work/base-status" "$work/original"
mv() { return 1; }
delete_register_xray; rc=$?
unset -f mv
check 'unregister reports status publication failure' "$rc" 1
check 'publication failure preserves opkg status' "$(command cat "$status_file")" "$(command cat "$work/original")"

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
