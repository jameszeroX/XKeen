#!/bin/sh
set -u
root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
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
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}
source_file="$root/scripts/_xkeen/04_tools/03_tools_diagnostic.sh"
eval "$(extract diagnostic_process_snapshot "$source_file")"
eval "$(extract diagnostic_process_stats "$source_file")"
diagnostic_proc_root="$work/proc"
mkdir -p "$diagnostic_proc_root/123/fd"
: > "$diagnostic_proc_root/123/fd/3"
: > "$diagnostic_proc_root/123/fd/4"
printf 'Max open files            1024                 4096                 files\n' > "$diagnostic_proc_root/123/limits"

pidof() {
    case "$1" in
        xray) printf '123 456\n'; return 0 ;;
        mihomo) return 1 ;;
    esac
}
diagnostic_process_snapshot; rc=$?
check 'multiple pidof values produce one snapshot' "$rc:$name_client:$diagnostic_pid" '0:xray:123'
out=$(diagnostic_process_stats)
case "$out" in *'2'*'1024'*) stats=ok ;; *) stats=bad ;; esac
check 'fd and limits use the same process snapshot' "$stats" ok

rm -rf "$diagnostic_proc_root/123"
out=$(diagnostic_process_stats); rc=$?
check 'process exit after snapshot is handled softly' "$rc" 0
case "$out" in *'завершился во время диагностики'*) gone=yes ;; *) gone=no ;; esac
check 'process exit is explained in report' "$gone" yes

pidof() {
    case "$1" in
        xray) printf 'not-a-pid\n'; return 0 ;;
        mihomo) printf '789\n'; return 0 ;;
    esac
}
diagnostic_proc_snapshot_rc=0
diagnostic_process_snapshot; rc=$?
check 'malformed xray PID falls through to mihomo' "$rc:$name_client:$diagnostic_pid" '0:mihomo:789'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
