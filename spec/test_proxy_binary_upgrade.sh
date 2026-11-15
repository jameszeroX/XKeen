#!/bin/sh
set -u

root=${ROOT:-/repo}
xray_file="$root/scripts/_xkeen/02_install/02_install_xray.sh"
mihomo_file="$root/scripts/_xkeen/02_install/02_install_mihomo.sh"
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
eval "$(awk '/^install_xray\(\) \{/,/^}/ { print }' "$xray_file")"
eval "$(awk '/^install_mihomo\(\) \{/,/^}/ { print }' "$mihomo_file")"
red=''; yellow=''; reset=''

for client in xray mihomo; do
    for mode in backup-only backup-and-install; do
        case_dir="$work/$client-$mode"
        install_dir="$case_dir/live"
        tmp_ram="$case_dir/tmp"
        xtmp_dir="$case_dir/unzip"
        mtmp_dir="$case_dir/gzip"
        xray_conf_dir="$case_dir/conf"
        softfloat=false
        mkdir -p "$install_dir" "$tmp_ram"
        printf '%s\n' old-binary > "$install_dir/$client"
        printf '#!/bin/sh\nexit 0\n' > "$case_dir/fake-binary"
        chmod +x "$case_dir/fake-binary"

        unzip() {
            mkdir -p "$4"
            cp "$case_dir/fake-binary" "$4/xray"
        }
        gzip() {
            case "$1" in
                -t) return 0 ;;
                -cd) cat "$case_dir/fake-binary" ;;
            esac
        }
        hexdump() { printf '7f454c46'; }
        wc() { [ "$1" = -c ] && { printf '2000000\n'; return 0; }; command wc "$@"; }
        mv() {
            if [ "$1" = "$install_dir/$client" ] && [ "$2" = "$install_dir/${client}_bak" ]; then
                return 1
            fi
            if [ "$mode" = backup-and-install ]; then
                if [ "$client" = xray ] && [ "$1" = "$xtmp_dir/xray" ] && [ "$2" = "$install_dir/xray" ]; then
                    return 1
                fi
                if [ "$client" = mihomo ] && [ "$1" = "$mtmp_dir/mihomo" ] && [ "$2" = "$install_dir/" ]; then
                    return 1
                fi
            fi
            command mv "$@"
        }
        if [ "$client" = xray ]; then
            : > "$tmp_ram/xray.zip"
            install_xray
        else
            : > "$tmp_ram/mihomo.gz"
            install_mihomo
        fi
        rc=$?
        check "$client $mode returns failure" "$rc" 1
        check "$client $mode preserves the prior binary" "$(cat "$install_dir/$client" 2>/dev/null)" old-binary
    done
done

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
