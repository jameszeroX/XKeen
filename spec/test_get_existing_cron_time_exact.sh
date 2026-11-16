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
eval "$(awk '$0 == "get_existing_cron_time() {" { on=1 } on { print } on && /^}/ { exit }' "$root/scripts/_xkeen/04_tools/05_tools_choice/05_choice_cron/01_cron_status.sh")"

# shellcheck disable=SC2034
install_dir='/opt/sbin'
cat > "$work/crontab" <<'EOF'
0 1 * * * /opt/sbin/xkeen -ugi
0 2 * * * /opt/sbin/xkeen -ugs
0 3 * * * /opt/sbin/xkeen-helper -ug
15 4 * * 1 /opt/sbin/xkeen -ug
EOF
crontab() { command cat "$work/crontab"; }

check 'time selector skips similar commands' "$(get_existing_cron_time)" '15 4 * * 1'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
