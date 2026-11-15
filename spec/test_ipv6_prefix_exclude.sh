#!/bin/sh
set -u

root=${ROOT:-/repo}
source_file="$root/scripts/_xkeen/02_install/07_install_register/04_register_init.sh"
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

ip6tables_supported=true
ipv6_exclude='::/128 ::1/128 fd00::/8 ff00::/8 fe80::/10'
eval "$(awk '/^get_exclude_ip6/ { capture=1 } capture { print; if ($0 == "}") exit }' "$source_file")"
ip() { printf '1: dev eth0 src 2001:db8::55 metric 1\n'; }
curl() {
    [ "${RCI_FAIL:-false}" = false ] || return 7
    cat "$RCI_BODY"
}

printf '%s\n' '{"prefix":[{"prefix":"2001:db8:100::/56","global":true},{"prefix":"fd0d:aeb8::/48","global":false}]}' > "$work/global.json"
RCI_BODY="$work/global.json"
RCI_FAIL=false
output=$(get_exclude_ip6)
case " $output " in *' 2001:db8:100::/56 '*) has_global=yes ;; *) has_global=no ;; esac
check 'global delegated prefix from RCI is included' "$has_global" yes
case " $output " in *' 2001:db8::55/128 '*) has_wan_src=yes ;; *) has_wan_src=no ;; esac
check 'WAN source address remains excluded' "$has_wan_src" yes

for body in '{"status":"error"}' '[]' '{"prefix":[{"prefix":"not-an-ipv6/64","global":true},{"prefix":"2001:db8::/129","global":true},{"prefix":"2001:::1/64","global":true},{"prefix":"2001:db8:1:2:3:4:5:6:7/64","global":true},{"prefix":"2001:db8::/0","global":true}]}' ; do
    printf '%s\n' "$body" > "$work/invalid.json"
    RCI_BODY="$work/invalid.json"
    RCI_FAIL=false
    output=$(get_exclude_ip6)
    case " $output " in *' 2001:db8:100::/56 '*) leaked=yes ;; *) leaked=no ;; esac
    check 'invalid RCI response adds no prefix' "$leaked" no
done

RCI_BODY="$work/global.json"
RCI_FAIL=true
output=$(get_exclude_ip6)
case " $output " in *' 2001:db8:100::/56 '*) leaked=yes ;; *) leaked=no ;; esac
check 'unavailable RCI keeps the static fallback list' "$leaked" no
case " $output " in *' 2001:db8::55/128 '*) has_wan_src=yes ;; *) has_wan_src=no ;; esac
check 'unavailable RCI still excludes WAN source' "$has_wan_src" yes

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
