#!/bin/sh
root=/repo
pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then printf 'OK   %s\n' "$1"; pass=$((pass + 1));
    else printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"; fail=$((fail + 1)); fi
}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
. "$root/scripts/_xkeen/05_tests/03_tests_storage.sh"
preinstall_warn=true
autoinstall_mode=false
entware_storage=internal
(preinstall_warn; printf continued > "$work/continued") </dev/null > "$work/storage.log" 2>&1 &
child=$!
(sleep 1; kill "$child" 2>/dev/null) & watchdog=$!
wait "$child"; rc=$?
kill "$watchdog" 2>/dev/null
check 'EOF aborts internal-storage installation' "$rc" 1
check 'installation does not continue after EOF' "$([ -e "$work/continued" ] && echo yes || echo no)" no
. "$root/scripts/_xkeen/03_delete/06_delete_tmp.sh"
backups_dir="$work/backups"
xkeen_cfg="$work/config"
mkdir "$backups_dir" "$xkeen_cfg"
(delete_all) </dev/null > "$work/delete.log" 2>&1 & child=$!
(sleep 1; kill "$child" 2>/dev/null) & watchdog=$!
wait "$child"; rc=$?
kill "$watchdog" 2>/dev/null
check 'EOF returns from optional deletion' "$rc" 0
check 'EOF preserves backups and settings' "$([ -d "$backups_dir" ] && [ -d "$xkeen_cfg" ] && echo yes || echo no)" yes
. "$root/scripts/_xkeen/05_tests/02_tests_xports.sh"
pidof() { return 0; }
netstat() { printf '%s\n' 'tcp 0 0 2001:db8::1:1080 :::* LISTEN 10/xray'; }
actual=$(tests_ports_client)
check 'unbracketed IPv6 gateway' "$(printf '%s\n' "$actual" | awk '$1 == "Шлюз" {print $2}')" '2001:db8::1'
check 'unbracketed IPv6 port' "$(printf '%s\n' "$actual" | awk '$1 == "Порт" {print $2}')" 1080
branches=$(awk '/^        -di\)/ || /^        -d\)/ { on=1 } on {print} on && /^        ;;$/ {on=0}' "$root/scripts/xkeen")
delay_init() { printf 'init:%s\n' "$1"; }
delay_autostart() { printf 'delay:%s\n' "$1"; }
add_chmod_init() { :; }
dispatch() {
    while [ "$#" -gt 0 ]; do
        eval 'case "$1" in
'"$branches"'
-status) printf "status\n" ;;
*) return 2 ;;
esac'
        shift
    done
}
check 'delay query preserves next option' "$(dispatch -d -status)" "$(printf 'delay:\nstatus')"
check 'init delay query preserves next option' "$(dispatch -di -status)" "$(printf 'init:\nstatus')"
check 'delay value is consumed once' "$(dispatch -d 5 -status)" "$(printf 'delay:5\nstatus')"
check 'standalone delay query' "$(dispatch -d)" 'delay:'
printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
