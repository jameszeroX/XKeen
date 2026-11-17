#!/bin/sh
# XKeen updates must stop when an enabled backup cannot be created.
set -u

root=${ROOT:-.}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
green=''
red=''
yellow=''
reset=''
autoinstall_mode=''
xkeen_build=Dev
xkeen_tar_url=https://github.com/example/XKeen/releases/latest/download/xkeen.tar.gz
xkeen_dev_url=https://raw.githubusercontent.com/example/XKeen/main/test/xkeen.tar.gz
info_compare_xkeen=''
auto_failed=''
manual_backup=''
choice_backup_xkeen() { return 0; }
eval "$(awk '/^backup_xkeen\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/04_tools/06_tools_backups/01_backups_xkeen.sh")"

backup_xkeen >/dev/null 2>&1
backup_disabled_rc=$?
unset -f backup_xkeen

eval "$(awk '
    /^[[:space:]]*-uk\)/ { active=1; print "run_uk() {"; next }
    active && /^[[:space:]]*;;/ { print "}"; exit }
    active { print }
' "$root/scripts/xkeen")"

test_connection() { :; }
check_health() { :; }
test_entware() { :; }
test_github() { :; }
sleep() { :; }
smart_clear() { :; }
choice_menu() { return 0; }
xkeen_info() { :; }
xkeen_set_info() { :; }
delete_tmp() { : > "$work/cleanup-called"; }
get_auto_arg() { [ "${1-}" = auto ] && printf '%s' true; }
backup_xkeen() { [ "${BACKUP_RC:-0}" -eq 0 ]; }
download_xkeen_dev() {
    : > "$work/download-called"
    [ "${DOWNLOAD_RC:-0}" -eq 0 ] || exit 1
}
install_xkeen() { : > "$work/install-called"; return 0; }

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

check 'explicitly disabled backup remains a successful skip' "$backup_disabled_rc" 0

BACKUP_RC=1
export BACKUP_RC
(
    run_uk -uk '' >/dev/null 2>&1
)
rc=$?
check 'enabled-backup failure stops update with an error' "$rc" 1
check 'backup failure prevents archive download' "$([ -e "$work/download-called" ] && echo yes || echo no)" no
check 'backup failure prevents installation' "$([ -e "$work/install-called" ] && echo yes || echo no)" no
check 'backup failure runs temporary cleanup' "$([ -e "$work/cleanup-called" ] && echo yes || echo no)" yes

rm -f "$work/download-called" "$work/install-called" "$work/cleanup-called"
BACKUP_RC=0
run_uk -uk '' >/dev/null 2>&1
check 'disabled or successful backup permits update' "$?" 0
check 'permitted update downloads archive' "$([ -e "$work/download-called" ] && echo yes || echo no)" yes
check 'permitted update installs archive' "$([ -e "$work/install-called" ] && echo yes || echo no)" yes

rm -f "$work/download-called" "$work/install-called"
BACKUP_RC=0
DOWNLOAD_RC=1
export DOWNLOAD_RC
(
    run_uk -uk '' >/dev/null 2>&1
)
rc=$?
check 'download failure remains fatal' "$rc" 1
check 'download failure prevents installation' "$([ -e "$work/install-called" ] && echo yes || echo no)" no

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
