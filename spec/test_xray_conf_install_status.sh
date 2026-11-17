#!/bin/sh
# Failed template copies must not be reported as successful installation.
set -u

root=${ROOT:-.}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
mkdir -p "$work/live" "$work/samples" || exit 1
printf '%s\n' '{"log":{}}' > "$work/samples/config.json"
xray_conf_dir="$work/live"
xray_conf_smpl="$work/samples"
yellow=''
red=''
reset=''
sleep() { :; }
eval "$(awk '/^xray_conf_install\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/02_install/08_install_configs/01_configs_install.sh")"

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

cp() { return 23; }
output=$(xray_conf_install 2>&1)
rc=$?
check 'copy failure returns an error' "$rc" 1
case "$output" in *'Добавлен шаблон'*) success_message=yes ;; *) success_message=no ;; esac
check 'copy failure does not claim a template was added' "$success_message" no
check 'copy failure leaves the template absent' "$([ -e "$xray_conf_dir/config.json" ] && echo yes || echo no)" no

xray_conf_dir="$work/mkdir-fail"
mkdir() { return 24; }
output=$(xray_conf_install 2>&1)
rc=$?
check 'configuration directory failure returns an error' "$rc" 1
case "$output" in *'Добавлен шаблон'*) success_message=yes ;; *) success_message=no ;; esac
check 'directory failure does not claim a template was added' "$success_message" no

unset -f mkdir
xray_conf_dir="$work/live"
unset -f cp
output=$(xray_conf_install 2>&1)
rc=$?
check 'successful template copy returns success' "$rc" 0
check 'successful template copy publishes the file' "$([ -f "$xray_conf_dir/config.json" ] && echo yes || echo no)" yes
case "$output" in *'Добавлен шаблон конфигурационного файла Xray'*) success_message=yes ;; *) success_message=no ;; esac
check 'successful copy reports the template' "$success_message" yes

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
