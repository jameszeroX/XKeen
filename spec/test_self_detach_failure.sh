#!/bin/sh
# A failed background spawn must not be reported as a successful detach.
set -u
root=${ROOT:-.}
file="$root/scripts/xkeen"
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
mkdir "$work/bin" || exit 1
cat > "$work/bin/start-stop-daemon" <<'MOCK'
#!/bin/sh
exit "$MOCK_SSD_RC"
MOCK
chmod +x "$work/bin/start-stop-daemon"
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

awk '
    /^if \[ -n "\$detach_eligible" \] && \[ -z "\$XKEEN_DETACHED" \]/ { on=1 }
    on && /^fi$/ { print; exit }
    on { print }
' "$file" | sed "s|log_dir=\"/opt/var/log\"|log_dir=\"$work/log\"|" > "$work/detach.sh"
[ -s "$work/detach.sh" ] || { echo "FAIL could not extract detach block"; exit 1; }

run_detach() {
    _mock_rc="$1"
    MOCK_SSD_RC="$_mock_rc"
    DETACH_BLOCK="$work/detach.sh"
    PATH="$work/bin:$PATH"
    export MOCK_SSD_RC DETACH_BLOCK PATH
    (
        detach_eligible=true
        XKEEN_DETACHED=""
        XKEEN_FOREGROUND=""
        LOGICAL_CMD_COUNT=1
        . "$DETACH_BLOCK"
    ) </dev/null >"$work/output" 2>&1
    _rc=$?
    printf '%s\n' "$_rc"
}

result=$(run_detach 42)
rc=$result
if grep -q 'Запуск в фоновом режиме' "$work/output"; then success_message=yes; else success_message=no; fi
check 'failed start-stop-daemon preserves its failure status' "$rc" 42
check 'failed spawn does not print the background success message' "$success_message" no

result=$(run_detach 0)
rc=$result
if grep -q 'Запуск в фоновом режиме' "$work/output"; then success_message=yes; else success_message=no; fi
check 'successful spawn is reported as detached' "$rc/$success_message" '0/yes'

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
