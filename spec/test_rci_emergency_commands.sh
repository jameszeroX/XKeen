#!/bin/sh
# Corrupt JSON exemptions must also bypass the global RCI auth gate for recovery commands.
set -u
root=${ROOT:-/repo}
common="$root/scripts/_xkeen/01_info/01_info_common.sh"
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

awk '
    /^# Справка, диагностика, восстановление и удаление/ { on=1 }
    on && /^# Параметры curl/ { exit }
    on { print }
' "$common" > "$work/rci-gate.sh"

run_gate() {
    _command="$1"
    _http="$2"
    MOCK_HTTP="$_http" RCI_GATE="$work/rci-gate.sh" sh -c '
        rci_token=""
        _xkeen_json_invalid=1
        rci_probe_code() { printf "%s" "$MOCK_HTTP"; }
        sleep() { :; }
        set -- "$1"
        . "$RCI_GATE"
        printf "DISPATCHED\n"
    ' sh "$_command" 2>&1
}

for cmd in -h -help -v -version -about -ad -donate -af -feedback \
    -diag -kbr -remove -dk -stop -status -toff; do
    for code in 401 403; do
        output=$(run_gate "$cmd" "$code")
        case "$output" in *DISPATCHED*) reached=yes ;; *) reached=no ;; esac
        check "$cmd with HTTP $code reaches dispatcher despite invalid JSON" "$reached" yes
    done
done

output=$(run_gate -start 401)
case "$output" in *DISPATCHED*) reached=yes ;; *) reached=no ;; esac
check 'proxy start remains blocked by HTTP 401' "$reached" no
output=$(MOCK_HTTP=401 RCI_GATE="$work/rci-gate.sh" sh -c '
    rci_token=""
    _xkeen_json_invalid=1
    rci_probe_code() { printf "%s" "$MOCK_HTTP"; }
    sleep() { :; }
    set -- -stop -start
    . "$RCI_GATE"
    printf "DISPATCHED\n"
' 2>&1)
case "$output" in *DISPATCHED*) reached=yes ;; *) reached=no ;; esac
check 'mixed stop and start still requires RCI authorization' "$reached" no

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
