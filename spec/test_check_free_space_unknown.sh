#!/bin/sh
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
eval "$(awk '$0 == "check_free_space() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/05_tests/03_tests_storage.sh")"
# Helper used by the extracted function to build the displayed core name.
eval "$(awk '$0 == "set_core_title() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/01_info/01_info_common.sh")"

# Globals consumed by the extracted production function.
# shellcheck disable=SC2034
target_dir="$work"
# shellcheck disable=SC2034
xray_free_space=50
# shellcheck disable=SC2034
mihomo_free_space=100
# shellcheck disable=SC2034
autoinstall_mode=true
# These color variables are interpolated by the extracted production function.
# shellcheck disable=SC2034
red=''
# shellcheck disable=SC2034
yellow=''
# shellcheck disable=SC2034
light_blue=''
# shellcheck disable=SC2034
green=''
# shellcheck disable=SC2034
reset=''
smart_clear() { :; }
df_mode=good
mkdir "$work/bin" "$work/empty-path"
cat > "$work/bin/df" <<'EOF'
#!/bin/sh
case "$DF_MODE" in
    fail) exit 1 ;;
    empty) exit 0 ;;
    invalid) printf 'Filesystem 1M-blocks Used Available Use%% Mounted on\n/dev/test 100 20 unknown 20%% /opt\n' ;;
    low) printf 'Filesystem 1M-blocks Used Available Use%% Mounted on\n/dev/test 100 80 20 80%% /opt\n' ;;
    good) printf 'Filesystem 1M-blocks Used Available Use%% Mounted on\n/dev/test 100 20 80 20%% /opt\n' ;;
esac
EOF
chmod +x "$work/bin/df"
PATH="$work/bin:$PATH"
export PATH
DF_MODE=good
export DF_MODE

check_free_space xray >/dev/null 2>&1
check 'sufficient free space proceeds' "$?" 0

DF_MODE=fail
check_free_space xray >/dev/null 2>&1
check 'df failure blocks automatic install' "$?" 1

DF_MODE=empty
check_free_space xray >/dev/null 2>&1
check 'empty df output blocks automatic install' "$?" 1

DF_MODE=invalid
check_free_space xray >/dev/null 2>&1
check 'nonnumeric free space blocks automatic install' "$?" 1

DF_MODE=low
check_free_space xray >/dev/null 2>&1
check 'known insufficient space still blocks automatic install' "$?" 1

autoinstall_mode=false
DF_MODE=invalid
output=$(check_free_space xray <<'EOF'
1
EOF
)
check 'unknown space offers an interactive continue choice' "$?" 0
case "$output" in *'не удалось определить свободное место'*) warning=shown ;; *) warning=missing ;; esac
check 'unknown space explains the warning' "$warning" shown
case "$output" in *'Продолжить установку'*) choice=shown ;; *) choice=missing ;; esac
check 'unknown space offers continue and cancel' "$choice" shown

output=$(check_free_space xray <<'EOF'
0
EOF
)
check 'unknown space can be canceled' "$?" 1

output=$(check_free_space xray <<'EOF'
invalid
EOF
)
check 'unknown space rejects an invalid choice' "$?" 1

output=$(PATH="$work/empty-path" check_free_space xray <<'EOF'
1
EOF
)
check 'missing df offers the same interactive choice' "$?" 0
case "$output" in *'df'*) utility_notice=shown ;; *) utility_notice=missing ;; esac
check 'missing df is reported' "$utility_notice" shown

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
