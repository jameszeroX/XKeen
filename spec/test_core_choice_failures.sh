#!/bin/sh
# Core selection must not change when stopping the active core or editing initd fails.
set -u

root=${ROOT:-.}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
mkdir -p "$work/bin" "$work/opt/sbin" || exit 1
cat > "$work/initd" <<'MOCK'
#!/bin/sh
[ "$1" = stop ] || exit 2
exit 0
MOCK
chmod +x "$work/initd" || exit 1
for core in xray mihomo yq; do : > "$work/opt/sbin/$core" || exit 1; done

extract() {
    awk -v name="$1" '
        $0 ~ "^" name "\\(\\) *\\{" { on=1 }
        on { print }
        on && /^}/ { exit }
    ' "$2"
}
eval "$(extract choice_xray_core "$root/scripts/_xkeen/04_tools/05_tools_choice/01_choice_cores.sh")"
eval "$(extract choice_mihomo_core "$root/scripts/_xkeen/04_tools/05_tools_choice/01_choice_cores.sh")"

initd_file="$work/initd"
install_dir="$work/opt/sbin"
xray_conf_dir="$work/xray"
mihomo_conf_dir="$work/mihomo"
red=''
green=''
yellow=''
reset=''
add_chmod_init() { :; }
pidof() { return 0; }
xray() { :; }
mihomo() { :; }
yq() { :; }
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
set_selected_core() {
    printf '#!/bin/sh\nname_client="%s"\nexit 0\n' "$1" > "$initd_file"
    chmod +x "$initd_file"
}
set_stop_result() {
    _selected=$(selected_core)
    printf '#!/bin/sh\nname_client="%s"\n[ "$1" = stop ] || exit 2\nexit %s\n' \
        "$_selected" "$1" > "$initd_file"
    chmod +x "$initd_file"
}
selected_core() {
    awk -F '"' '/^name_client=/ { print $2; exit }' "$initd_file"
}

for target in xray mihomo; do
    if [ "$target" = xray ]; then
        old=mihomo
        switch=choice_xray_core
    else
        old=xray
        switch=choice_mihomo_core
    fi

    set_selected_core "$old"
    set_stop_result 17
    "$switch" >"$work/switch.output" 2>&1
    rc=$?
    check "$target selection returns stop failure" "$rc" 1
    check "$target selection preserves old core after stop failure" "$(selected_core)" "$old"

    set_stop_result 0
    sed() { return 1; }
    "$switch" >"$work/switch.output" 2>&1
    rc=$?
    check "$target selection returns init write failure" "$rc" 1
    check "$target selection preserves old core after write failure" "$(selected_core)" "$old"
    unset -f sed

    mv() { return 1; }
    "$switch" >"$work/switch.output" 2>&1
    rc=$?
    check "$target selection returns publish failure" "$rc" 1
    check "$target selection preserves old core after publish failure" "$(selected_core)" "$old"
    unset -f mv

    "$switch" >"$work/switch.output" 2>&1
    rc=$?
    check "$target selection succeeds when operations succeed" "$rc" 0
    check "$target selection publishes requested core" "$(selected_core)" "$target"
done

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
