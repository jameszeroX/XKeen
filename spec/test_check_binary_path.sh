#!/bin/sh
root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
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
    awk '$0 == "check_binary() {" { on=1 } on { print } on && /^}/ { exit }' "$1"
}
register="$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh"
eval "$(extract "$register")"
log_error_router() { :; }
log_error_terminal() { :; }
install_dir="$work/install"
mkdir -p "$install_dir" "$work/path"
CHECK_LOG="$work/exec.log"
TARGET_FAIL="$work/target-fail"
export CHECK_LOG TARGET_FAIL
cat > "$install_dir/xray" <<'SH'
#!/bin/sh
printf 'installed:%s\n' "$1" >> "$CHECK_LOG"
[ ! -f "$TARGET_FAIL" ]
SH
cat > "$work/path/xray" <<'SH'
#!/bin/sh
printf 'path:%s\n' "$1" >> "$CHECK_LOG"
exit 0
SH
chmod +x "$install_dir/xray" "$work/path/xray"
PATH="$work/path:$PATH"
export PATH

check_binary xray; rc=$?
check 'healthy installed binary accepted' "$rc" 0
check 'installed path receives version command' "$(cat "$CHECK_LOG")" 'installed:version'

: > "$CHECK_LOG"
: > "$TARGET_FAIL"
check_binary xray; rc=$?
check 'broken installed binary is reported unhealthy' "$rc" 1
check 'shadow binary is never executed' "$(cat "$CHECK_LOG")" 'installed:version'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
