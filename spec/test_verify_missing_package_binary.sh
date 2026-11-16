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
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/02_install/01_install_packages.sh"
}
eval "$(extract _repair_missing_package_binary)"
eval "$(extract _verify_installed_packages)"

missing_bin=curl
installed=true
repair_succeeds=true
repaired=false
force_calls=0
_package_binary() { printf '%s\n' "$1"; }
_opkg_update_once() { :; }
opkg() {
    case "$1" in
        status) [ "$installed" = true ] && printf 'Status: install user installed\n' ;;
        install)
            force_calls=$((force_calls + 1))
            [ "$repair_succeeds" = true ] || return 1
            repaired=true
            ;;
        *) return 1 ;;
    esac
}
command() {
    if [ "$1" = -v ]; then
        [ "$2" != "$missing_bin" ] || [ "$repaired" = true ]
        return $?
    fi
    command "$@"
}
_check_package_health() { return 0; }
_repair_package() { return 1; }

_verify_installed_packages
rc=$?
check 'missing binary is force-reinstalled' "$force_calls" 1
check 'successful targeted repair verifies package' "$rc:$repaired" '0:true'

repaired=false
force_calls=0
repair_succeeds=false
_verify_installed_packages
check 'failed targeted repair is reported' "$?" 1

installed=false
repair_succeeds=true
force_calls=0
_verify_installed_packages
check 'missing package is not force-reinstalled blindly' "$?:$force_calls" '1:0'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
