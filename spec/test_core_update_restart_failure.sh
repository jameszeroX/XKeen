#!/bin/sh
# A failed restart after replacing a running core must not report success.
set -u

root=${ROOT:-.}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
green=''
red=''
yellow=''
light_blue=''
reset=''
autoinstall_mode=''
auto_xray_version=''
auto_mihomo_version=''
xray_installed=installed
xray_current_version=1.0.0
bypass_xray=''
mihomo_installed=installed
mihomo_current_version=1.0.0
mihomo_was_installed=installed
bypass_mihomo=''
install_dir="$work/install"
mkdir -p "$install_dir" || exit 1
initd_file="$work/initd"
cat > "$initd_file" <<'INIT'
#!/bin/sh
exit "${RESTART_RC:-0}"
INIT
chmod +x "$initd_file"

eval "$(awk '
    /^[[:space:]]*-ux\)/ { active=1; print "run_ux() {"; next }
    active && /^        ;;[[:space:]]*$/ { print "}"; exit }
    active { print }
' "$root/scripts/xkeen")"
eval "$(awk '
    /^[[:space:]]*-um\)/ { active=1; print "run_um() {"; next }
    active && /^        ;;[[:space:]]*$/ { print "}"; exit }
    active { print }
' "$root/scripts/xkeen")"

check_free_space() { :; }
test_connection() { :; }
check_health() { :; }
test_github() { :; }
info_cpu() { :; }
sleep() { :; }
smart_clear() { :; }
info_xray() { :; }
info_mihomo() { :; }
download_xray() { :; }
download_mihomo() { :; }
install_xray() { :; }
install_mihomo() { :; }
pidof() { [ "${PIDOF_RC:-0}" -eq 0 ]; }
delete_register_xray() { :; }
logs_delete_register_xray_info_console() { :; }
register_xray_list() { :; }
logs_register_xray_list_info_console() { :; }
register_xray_control() { :; }
logs_register_xray_control_info_console() { :; }
register_xray_status() { :; }
logs_register_xray_status_info_console() { :; }
delete_register_mihomo() { :; }
delete_register_yq() { :; }
logs_delete_register_mihomo_info_console() { :; }
logs_delete_register_yq_info_console() { :; }
register_mihomo_list() { :; }
logs_register_mihomo_list_info_console() { :; }
register_mihomo_control() { :; }
logs_register_mihomo_control_info_console() { :; }
register_mihomo_status() { :; }
logs_register_mihomo_status_info_console() { :; }
register_yq_list() { :; }
logs_register_yq_list_info_console() { :; }
register_yq_control() { :; }
logs_register_yq_control_info_console() { :; }
register_yq_status() { :; }
fixed_register_packages() { :; }
delete_tmp() { :; }
get_auto_arg() { [ "${1-}" = auto ] && printf '%s' true; }
is_version_arg() { return 1; }

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

RESTART_RC=42
export RESTART_RC
ux_output=$(run_ux -ux '' 2>&1)
ux_rc=$?
check 'Xray restart failure returns an error' "$ux_rc" 1
case "$ux_output" in *'Обновление ядра Xray'*'выполнено'*) ux_success=yes ;; *) ux_success=no ;; esac
check 'Xray restart failure does not report update success' "$ux_success" no

um_output=$(run_um -um '' 2>&1)
um_rc=$?
check 'Mihomo restart failure returns an error' "$um_rc" 1
case "$um_output" in *'Обновление ядра'*'выполнено'*) um_success=yes ;; *) um_success=no ;; esac
check 'Mihomo restart failure does not report update success' "$um_success" no

RESTART_RC=0
ux_output=$(run_ux -ux '' 2>&1)
check 'successful Xray restart retains success status' "$?" 0
case "$ux_output" in *'Обновление ядра Xray'*'выполнено'*) ux_success=yes ;; *) ux_success=no ;; esac
check 'successful Xray restart reports completion' "$ux_success" yes

PIDOF_RC=1
ux_output=$(run_ux -ux '' 2>&1)
check 'stopped Xray does not trigger a restart error' "$?" 0

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
