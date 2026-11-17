#!/bin/sh
set -u

root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'command rm -rf "$work"' EXIT INT TERM
pass=0
fail=0
xkeen_config=/temporary/xkeen.json
token_marker="$work/generated"
token_written=false
green=""; red=""; yellow=""; light_blue=""; reset=""

check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass + 1))
    else
        printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"; fail=$((fail + 1))
    fi
}
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}
eval "$(extract setup_rci_token "$root/install.sh")"

get_rci_token_from_config() { return 1; }
rci_probe_code_retry() { printf '200\n'; }
get_keenetic_release() { printf '5.2.1\n'; }
is_firmware_52_or_newer() { return 0; }
validate_xkeen_json_early() { return 0; }
mkdir -p "$work/bin"
cat > "$work/bin/ndmc" <<EOF
#!/bin/sh
: > "$token_marker"
printf 'value: generated-token\\n'
EOF
chmod +x "$work/bin/ndmc"
extract_rci_token() { printf 'generated-token\n'; }
rci_token_manual_hint() { :; }
write_rci_token() { token_written=true; return 1; }

PATH="$work/bin" setup_rci_token >/dev/null 2>&1
check 'missing jq skips RCI token generation' "$([ -e "$token_marker" ] && echo true || echo false)" false
check 'missing jq does not attempt config publication' "$token_written" false

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
