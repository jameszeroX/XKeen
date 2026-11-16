#!/bin/sh
set -u

root=${ROOT:-/repo}
pass=0
fail=0
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"
        pass=$((pass + 1))
    else
        printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"
        fail=$((fail + 1))
    fi
}
eval "$(extract _ensure_installed_packages "$root/scripts/_xkeen/02_install/01_install_packages.sh")"
verify_function=$(extract _verify_installed_packages "$root/scripts/_xkeen/02_install/01_install_packages.sh")

fail_install_package=''
verify_result=0
verify_called=0
install_packages() {
    [ "$2" = "$fail_install_package" ] && return 1
    return 0
}
_verify_installed_packages() {
    verify_called=$((verify_called + 1))
    return "$verify_result"
}
# Metadata globals are consumed by the dynamically extracted production function.
# shellcheck disable=SC2034
packages_info_ok=1
# shellcheck disable=SC2034
info_packages_curl=installed
# shellcheck disable=SC2034
info_packages_jq=installed
# shellcheck disable=SC2034
info_packages_ip_full=installed
# shellcheck disable=SC2034
info_packages_iptables=installed
# shellcheck disable=SC2034
info_packages_ipset=installed
# shellcheck disable=SC2034
info_packages_cabundle=installed
# shellcheck disable=SC2034
info_packages_uname=installed
# shellcheck disable=SC2034
info_packages_nohup=installed
# shellcheck disable=SC2034
info_packages_conntrack=installed

fail_install_package=jq
_ensure_installed_packages
result=$?
check 'failed required package installation propagates' "$result" 1
check 'package verifier still runs after independent install failure' "$verify_called" 1

fail_install_package=''
verify_called=0
verify_result=1
_ensure_installed_packages
result=$?
check 'package verifier failure propagates' "$result" 1
check 'all package installs run before verification' "$verify_called" 1

# shellcheck disable=SC2034
packages_info_ok=0
verify_called=0
_ensure_installed_packages
result=$?
check 'unavailable package metadata remains a no-op' "$result" 0
check 'unavailable metadata skips verification' "$verify_called" 0

eval "$verify_function"
_package_binary() { printf '%s' "$1"; }
command() { [ "$1" = -v ]; }
_check_package_health() { [ "$1" != curl ]; }
_repair_package() { return 1; }
_verify_installed_packages
result=$?
check 'verifier aggregates one package failure across later successes' "$result" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
