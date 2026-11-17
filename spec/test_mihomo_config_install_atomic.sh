#!/bin/sh
# A failed Mihomo config write must not leave a partial file or a success message.
set -u

root=${ROOT:-.}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
mkdir -p "$work/install" || exit 1
: > "$work/install/mihomo"
mihomo_conf_dir="$work/mihomo"
install_dir="$work/install"
yellow=''
red=''
reset=''
sleep() { :; }
eval "$(awk '/^add_mihomo_config\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/02_install/07_install_register/01_register_mihomo.sh")"

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

mkdir() { return 24; }
output=$(add_mihomo_config 2>&1)
rc=$?
check 'directory creation failure returns an error' "$rc" 1
case "$output" in *'Добавлен шаблон конфигурационного файла Mihomo'*) success_message=yes ;; *) success_message=no ;; esac
check 'directory creation failure does not claim success' "$success_message" no
check 'directory creation failure leaves no config' "$([ -e "$mihomo_conf_dir/config.yaml" ] && echo yes || echo no)" no

unset -f mkdir
mkdir -p "$mihomo_conf_dir"
cat() { return 23; }
output=$(add_mihomo_config 2>&1)
rc=$?
check 'template write failure returns an error' "$rc" 1
case "$output" in *'Добавлен шаблон конфигурационного файла Mihomo'*) success_message=yes ;; *) success_message=no ;; esac
check 'template write failure does not claim success' "$success_message" no
check 'template write failure leaves no published config' "$([ -f "$mihomo_conf_dir/config.yaml" ] && echo yes || echo no)" no
check 'template write failure removes temporary files' "$(find "$mihomo_conf_dir" -type f | wc -l | tr -d ' ')" 0

unset -f cat
rm -f "$mihomo_conf_dir/config.yaml"
mv() { return 26; }
output=$(add_mihomo_config 2>&1)
rc=$?
check 'publish failure returns an error' "$rc" 1
check 'publish failure leaves no config' "$([ -f "$mihomo_conf_dir/config.yaml" ] && echo yes || echo no)" no
check 'publish failure removes temporary files' "$(find "$mihomo_conf_dir" -type f | wc -l | tr -d ' ')" 0

unset -f mv
output=$(add_mihomo_config 2>&1)
rc=$?
check 'successful template creation returns success' "$rc" 0
check 'successful template creation publishes config' "$([ -f "$mihomo_conf_dir/config.yaml" ] && echo yes || echo no)" yes
check 'successful template contains expected listener setup' "$(grep -c 'name: tproxy' "$mihomo_conf_dir/config.yaml")" 1
check 'successful template leaves no staging file' "$(find "$mihomo_conf_dir" -type f | wc -l | tr -d ' ')" 1
case "$output" in *'Добавлен шаблон конфигурационного файла Mihomo'*) success_message=yes ;; *) success_message=no ;; esac
check 'successful template creation reports success' "$success_message" yes

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
