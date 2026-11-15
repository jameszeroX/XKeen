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
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}
run_eof() {
    run_input "$1" ''
}
run_input() {
    _re_fn="$1"
    _re_input="$2"
    _re_rcfile="$work/$_re_fn.rc"
    rm -f "$_re_rcfile"
    ( printf '%b' "$_re_input" | "$_re_fn" >/dev/null 2>&1; printf '%s\n' "$?" > "$_re_rcfile" ) &
    _re_pid=$!
    _re_i=0
    while [ ! -f "$_re_rcfile" ] && [ "$_re_i" -lt 4 ]; do
        sleep 1
        _re_i=$((_re_i + 1))
    done
    if [ -f "$_re_rcfile" ]; then
        _re_rc=$(cat "$_re_rcfile")
        wait "$_re_pid" 2>/dev/null
        check "$_re_fn exits on EOF" "$_re_rc" 1
    else
        kill "$_re_pid" 2>/dev/null
        wait "$_re_pid" 2>/dev/null
        check "$_re_fn exits on EOF without CPU spin" timeout exited
    fi
}

choice_file="$root/scripts/_xkeen/04_tools/05_tools_choice/01_choice_cores.sh"
eval "$(extract choice_add_proxy_cores "$choice_file")"
autoinstall_mode=false
run_eof choice_add_proxy_cores

channel_file="$root/scripts/_xkeen/04_tools/05_tools_choice/02_choice_xkeen.sh"
eval "$(extract choice_channel_xkeen "$channel_file")"
xkeen_build=Stable
run_eof choice_channel_xkeen
eval "$(extract change_ipv6_support "$channel_file")"
check_ipv6_active() { return 0; }
ip6_supported=false
run_eof change_ipv6_support

geofile="$root/scripts/_xkeen/04_tools/05_tools_choice/03_choice_geofile.sh"
eval "$(extract choice_geodata "$geofile")"
autoinstall_mode=false
update_refilter_geosite=false
update_v2fly_geosite=false
update_zkeen_geosite=false
run_eof choice_geodata

cron_file="$root/scripts/_xkeen/04_tools/05_tools_choice/05_choice_cron/02_cron_time.sh"
eval "$(extract choice_cron_time "$cron_file")"
choice_geofile_cron_select=true
autoinstall_mode=false
run_eof choice_cron_time
run_input choice_cron_time '8\n'
run_input choice_cron_time '8\n12\n'

cron_status="$root/scripts/_xkeen/04_tools/05_tools_choice/05_choice_cron/01_cron_status.sh"
eval "$(extract choice_update_cron "$cron_status")"
get_existing_cron_time() { :; }
autoinstall_mode=false
info_update_geofile_cron=""
run_eof choice_update_cron

input_file="$root/scripts/_xkeen/04_tools/05_tools_choice/04_choice_input.sh"
eval "$(extract toggle_param "$input_file")"
initd_file="$work/S05xkeen"
printf 'probe="off"\n' > "$initd_file"
test_toggle_param() { toggle_param probe "параметр" restart ""; }
run_eof test_toggle_param
check 'EOF leaves configuration unchanged' "$(cat "$initd_file")" 'probe="off"'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
