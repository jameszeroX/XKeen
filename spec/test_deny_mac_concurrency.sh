#!/bin/sh
root=/repo
file="$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"
        pass=$((pass+1))
    else
        printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"
        fail=$((fail+1))
    fi
}
for name in sync_deny_mac_ipset _xkeen_sync_deny_mac_ipset; do
    case_dir="$work/$name"
    mkdir -p "$case_dir"
    cat > "$case_dir/runner.sh" <<'RUN'
scratch=$1
name_ipset_deny_mac=xkeen_deny_mac
url_server=unused
url_hotspot=unused
curl_api() {
    printf '%s\n' '{"host":[{"access":"deny","mac":"aa:bb:cc:dd:ee:ff"},{"access":"permit","mac":"02:00:00:00:00:01"},{"access":"deny","mac":"invalid"}]}'
}
log_warning_router() { :; }
logger() { :; }
ipset() {
    case "$1" in
        create)
            [ "$2" = "$name_ipset_deny_mac" ] || printf '%s\n' "$2" > "$scratch/created.$$"
            ;;
        restore) cat > "$scratch/restored.$$" ;;
    esac
    return 0
}
RUN
    awk -v name="$name" '
        $0 == name "() {" || $0 == "    " name "() {" {on=1}
        on {print}
        on && ($0 == "}" || $0 == "    }") {exit}
    ' "$file" >> "$case_dir/runner.sh"
    printf '\n%s\n' "$name" >> "$case_dir/runner.sh"
    sh "$case_dir/runner.sh" "$case_dir" & first=$!
    sh "$case_dir/runner.sh" "$case_dir" & second=$!
    wait "$first"
    wait "$second"
    count=$(cat "$case_dir"/created.* | sort -u | wc -l | tr -d ' ')
    check "$name concurrent calls use distinct staging sets" "$count" 2
    actual=$(cat "$case_dir"/restored.* | awk '{print $3}' | sort -u)
    check "$name only denied valid MAC is restored" "$actual" 'AA:BB:CC:DD:EE:FF'
done
printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
