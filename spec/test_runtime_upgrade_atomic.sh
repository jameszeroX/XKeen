#!/bin/sh
set -u

root=${ROOT:-/repo}
file="$root/scripts/_xkeen/02_install/03_install_xkeen.sh"
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
eval "$(awk '/^install_xkeen\(\) \{/,/^}/ { print }' "$file")"
red=''; yellow=''; reset=''

for mode in wrapper-backup modules-backup modules-promotion; do
    case_dir="$work/$mode"
    source_dir="$case_dir/archive"
    install_dir="$case_dir/live"
    tmp_ram="$case_dir/tmp"
    log_dir="$case_dir/log"
    stage_dir=''
    mkdir -p "$source_dir/_xkeen" "$install_dir/.xkeen" "$tmp_ram" "$log_dir"
    printf '%s\n' old-wrapper > "$install_dir/xkeen"
    printf '%s\n' old-modules > "$install_dir/.xkeen/version"
    printf '%s\n' new-wrapper > "$source_dir/xkeen"
    printf '%s\n' new-modules > "$source_dir/_xkeen/version"
    : > "$tmp_ram/xkeen.tar.gz"

    tar() {
        case "$1" in
            -tzf) return 0 ;;
            -xzf)
                _dest="$4"
                cp "$source_dir/xkeen" "$_dest/xkeen" || return 1
                cp -R "$source_dir/_xkeen" "$_dest/_xkeen" || return 1
                return 0
                ;;
        esac
        return 1
    }
    mv() {
        case "$mode:$1:$2" in
            wrapper-backup:"$install_dir/xkeen":"$install_dir/xkeen.old"|\
            modules-backup:"$install_dir/.xkeen":"$install_dir/.xkeen.old"|\
            modules-promotion:*/_xkeen:"$install_dir/.xkeen") return 1 ;;
        esac
        command mv "$@"
    }
    install_xkeen >/dev/null 2>&1
    rc=$?
    check "$mode reports promotion failure" "$rc" 1
    check "$mode keeps the old wrapper" "$(cat "$install_dir/xkeen" 2>/dev/null)" old-wrapper
    check "$mode keeps old modules at the live path" "$(cat "$install_dir/.xkeen/version" 2>/dev/null)" old-modules
    check "$mode does not nest modules" "$([ -e "$install_dir/.xkeen/_xkeen" ] && echo yes || echo no)" no
done

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
