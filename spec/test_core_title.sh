#!/bin/sh
# Тесты отображаемого имени ядра проксирования (core_title).
#
# name_client остаётся строчным (имя процесса и бинарника), а для вывода
# пользователю используется core_title: xray -> Xray, mihomo -> Mihomo.
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
contains() {
    case "$2" in *"$3"*) check "$1" yes yes ;; *) check "$1" "$2" "...$3..." ;; esac
}
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}

common="$root/scripts/_xkeen/01_info/01_info_common.sh"
init="$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh"

# --- set_core_title (общая функция модулей xkeen) ---
eval "$(extract set_core_title "$common")"

name_client=xray
set_core_title "$name_client"
check 'xray is displayed as Xray' "$core_title" Xray
check 'name_client stays lowercase' "$name_client" xray
set_core_title mihomo
check 'mihomo is displayed as Mihomo' "$core_title" Mihomo
set_core_title sing-box
check 'unknown core is shown unchanged' "$core_title" sing-box

core_title=outer
scoped_result=''
scoped() { local core_title; set_core_title mihomo; scoped_result=$core_title; }
scoped
check 'local core_title receives the value inside a function' "$scoped_result" Mihomo
check 'local core_title does not leak to the caller' "$core_title" outer

# --- блок core_title в init-скрипте ---
names=$(awk '/^name_client=/ { on=1 } on { print } on && /^esac$/ { exit }' "$init")
contains 'init derives core_title from name_client' "$names" 'core_title='

# Цели sed из 01_choice_cores.sh должны оставаться единственными в init
check 'init has exactly one name_client="xray" line' "$(grep -c 'name_client="xray"' "$init")" 1
check 'init has no name_client="mihomo" line' "$(grep -c 'name_client="mihomo"' "$init")" 0

unset core_title
eval "$names"
check 'init: xray core is titled Xray' "$core_title" Xray

to_mihomo="$(printf '%s\n' "$names" | sed 's/name_client="xray"/name_client="mihomo"/')"
eval "$to_mihomo"
check 'init: switched name_client is mihomo' "$name_client" mihomo
check 'init: core_title follows the switched core' "$core_title" Mihomo

eval "$(printf '%s\n' "$to_mihomo" | sed 's/name_client="mihomo"/name_client="xray"/')"
check 'init: core_title follows the switch back' "$core_title" Xray

# --- cmd_status (xkeen -status) ---
eval "$(extract cmd_status "$init")"
red=''; yellow=''; green=''; light_blue=''; reset=''
file_netfilter_hook="$work/hook.sh"
status_running=true
proxy_status() { [ "$status_running" = true ]; }

printf "mode_proxy='Hybrid'\n" > "$file_netfilter_hook"
name_client=xray; core_title=Xray
out=$(cmd_status); rc=$?
contains 'status names XKeen, mode and core' "$out" 'XKeen запущен в режиме Hybrid (ядро Xray)'
check 'status of a running XKeen returns success' "$rc" 0

printf "mode_proxy='TProxy'\n" > "$file_netfilter_hook"
name_client=mihomo; core_title=Mihomo
out=$(cmd_status)
contains 'status shows Mihomo with a capital letter' "$out" 'XKeen запущен в режиме TProxy (ядро Mihomo)'

rm -f "$file_netfilter_hook"
out=$(cmd_status)
contains 'status falls back to the Other mode' "$out" 'в режиме Other (ядро Mihomo)'

status_running=false
out=$(cmd_status); rc=$?
contains 'stopped XKeen is reported' "$out" 'XKeen не запущен'
check 'status of a stopped XKeen returns failure' "$rc" 1

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
