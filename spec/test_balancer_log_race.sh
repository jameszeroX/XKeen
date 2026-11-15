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
sb_log_file="$work/speed.log"
sb_log_enabled=true
. "$root/scripts/_xkeen/04_tools/08_tools_balancer/01_balancer_core.sh"

mv() {
    if [ "$SB_TEST_PAUSE_MV" = 1 ] \
        && { [ "$2" = "$sb_log_file" ] || [ "$3" = "$sb_log_file" ]; }; then
        : > "$work/trim-reached-mv"
        while [ ! -f "$work/release-mv" ]; do sleep 1; done
    fi
    command mv "$@"
}

i=1
while [ "$i" -le 220 ]; do printf 'old-%s\n' "$i" >> "$sb_log_file"; i=$((i + 1)); done
export SB_TEST_PAUSE_MV=1
sb_log_trim >/dev/null 2>&1 & trim_pid=$!
i=0
while [ ! -f "$work/trim-reached-mv" ] && [ "$i" -lt 20 ]; do sleep 1; i=$((i + 1)); done
check 'trim reached replacement point' "$([ -f "$work/trim-reached-mv" ] && echo yes || echo no)" yes

( sb_log 'concurrent-marker'; echo "done" > "$work/writer-done" ) >/dev/null 2>&1 & writer_pid=$!
sleep 1
check 'append waits while trim owns log lock' "$([ -f "$work/writer-done" ] && echo no || echo yes)" yes
: > "$work/release-mv"
wait "$trim_pid"; trim_rc=$?
wait "$writer_pid"; writer_rc=$?
check 'trim completes successfully' "$trim_rc" 0
check 'append completes after trim' "$writer_rc" 0
check 'concurrent line survives trim' "$(grep -c 'concurrent-marker' "$sb_log_file")" 1
check 'trim keeps at most last 200 original lines' "$(wc -l < "$sb_log_file" | tr -d ' ')" 201
check 'log lock is released' "$([ -d "$sb_log_file.lock.d" ] && echo yes || echo no)" no

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
