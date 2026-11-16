#!/bin/sh
# Regression coverage for RCI prefix parsing and generated IPv6 DNS rules.
# shellcheck disable=SC2034,SC2329
# Values are consumed by functions extracted with eval; ipt mocks are called indirectly.
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
has_word() {
    _hw_words=$(printf '%s\n' "$1" | tr '\n' ' ')
    case " $_hw_words " in *" $2 "*) return 0 ;; *) return 1 ;; esac
}
extract_top_function() {
    awk -v name="$1" '$0 == name "() {" { capture=1 } capture { print; if ($0 == "}") exit }' "$source_file"
}
extract_hook_function() {
    awk -v name="$1" '$0 == "    " name "() {" { capture=1 } capture { sub(/^    /, ""); print; if ($0 == "}") exit }' "$source_file"
}
eval "$(extract_top_function curl_api)"
eval "$(extract_top_function get_exclude_ip6)"
eval "$(extract_hook_function add_exclude_rules)"
eval "$(extract_hook_function add_ipt_rule)"
eval "$(extract_hook_function add_force_ipt_rule)"

ip6tables_supported=true
ipv6_exclude='::/128 ::1/128 64:ff9b::/96 2001::/32 2002::/16 fd00::/8 ff00::/8 fe80::/10'
url_server='127.0.0.1:79'
name_chain=xkeen
comment='-m comment --comment xkeen_rule'
ipv6_local_prefixes=''
ipv6_exclude_static=''
ipv6_exclude_ip6=''
ip() { printf '2001:db8::55 via fe80::1 dev ppp0 src 2001:db8::55 metric 1\n'; }
curl() {
    curl_args="$*"
    printf '%s\n' "$curl_args" >> "$work/curl-args"
    case "${CURL_HTTP_STATUS:-200}" in 401|403|500) return 22 ;; esac
    [ "${CURL_FAIL:-false}" = false ] || return "${CURL_EXIT:-22}"
    [ -n "${RCI_BODY:-}" ] && cat "$RCI_BODY"
}
write_json() { printf '%s\n' "$1" > "$work/rci.json"; RCI_BODY="$work/rci.json"; CURL_FAIL=false; CURL_EXIT=22; }
read_prefixes() { rci_token=${RCI_TOKEN:-}; get_exclude_ip6 >/dev/null 2>"$work/diagnostics"; }

write_json '{"prefix":[{"prefix":"2a02:2168:1234::/48","interface":"GigabitEthernet1","valid-lifetime":"1584","preferred-lifetime":"1584","global":true},{"prefix":"2a02:2168:1234:5600::/56","interface":"GigabitEthernet1","valid-lifetime":"1584","preferred-lifetime":"1584","global":true},{"prefix":"2a02:2168:1234:5601::/64","interface":"GigabitEthernet1","valid-lifetime":"infinite","preferred-lifetime":"infinite","global":true}]}'
RCI_TOKEN='secret-token-value'; read_prefixes
for cidr in '2a02:2168:1234::/48' '2a02:2168:1234:5600::/56' '2a02:2168:1234:5601::/64'; do
    has_word "$ipv6_local_prefixes" "$cidr" && got=yes || got=no
    check "real RCI prefix[] shape accepts $cidr" "$got" yes
done
has_word "$ipv6_exclude_ip6" '2001:db8::55/128' && got=yes || got=no
check 'WAN IPv6 source remains excluded' "$got" yes
has_word "$ipv6_exclude_ip6" 'fd00::/8' && got=yes || got=no
check 'static exclusions remain in complete list' "$got" yes
case "$(cat "$work/curl-args")" in *'X-Ndma-Tkn: secret-token-value'*) got=yes ;; *) got=no ;; esac
check 'curl_api uses the configured RCI token' "$got" yes
case "$(cat "$work/curl-args")" in *'--connect-timeout 2'*'-m 5'*'127.0.0.1:79/rci/show/ipv6/prefixes/'*) got=yes ;; *) got=no ;; esac
check 'RCI request reuses curl_api URL and timeout policy' "$got" yes

RCI_TOKEN=''; : > "$work/curl-args"; write_json '{"prefix":[]}'; read_prefixes
case "$(cat "$work/curl-args")" in *'-H X-Ndma-Tkn:'*) got=yes ;; *) got=no ;; esac
check 'curl_api supports an allowed no-token configuration' "$got" no

RCI_TOKEN='secret-token-value'
for failure in 401 403 500 timeout missing_api; do
    write_json '{"prefix":[{"prefix":"2a02:2168:bad::/56","interface":"wan0","valid-lifetime":"120","global":true}]}'
    CURL_FAIL=true
    case "$failure" in
        401|403|500) CURL_HTTP_STATUS="$failure" ;;
        timeout) CURL_HTTP_STATUS=000; CURL_EXIT=28 ;;
        missing_api) CURL_HTTP_STATUS=000; CURL_EXIT=7 ;;
    esac
    read_prefixes
    has_word "$ipv6_exclude_ip6" 'fd00::/8' && got=yes || got=no
    check "$failure keeps prior static exclusions" "$got" yes
    [ -z "$ipv6_local_prefixes" ] && got=yes || got=no
    check "$failure adds no unverified prefix" "$got" yes
    if grep -q 'secret-token-value' "$work/diagnostics"; then got=leaked; else got=redacted; fi
    check "$failure does not expose the RCI token in diagnostics" "$got" redacted
done

for body in '' '{broken' '[]' '{"prefix":null}' \
    '{"prefix":[{"prefix":"2a02:2168:bad::/56","valid-lifetime":"0","global":true}]}' \
    '{"prefix":[{"prefix":"2a02:2168:bad::/56","global":true}]}' \
    '{"prefix":[{"prefix":"2a02:2168:bad::/56","valid-lifetime":"-1","global":true}]}'; do
    write_json "$body"; read_prefixes
    [ -z "$ipv6_local_prefixes" ] && got=yes || got=no
    check 'empty, malformed, expired, or incomplete JSON adds no CIDR' "$got" yes
    has_word "$ipv6_exclude_ip6" 'fd00::/8' && got=yes || got=no
    check 'invalid JSON preserves static fallback exclusions' "$got" yes
done

write_json '{"prefix":[{"prefix":"fdf2:cc10:506a::/48","interface":"","valid-lifetime":"infinite","preferred-lifetime":"infinite","global":true}]}'
read_prefixes
[ -z "$ipv6_local_prefixes" ] && got=yes || got=no
check 'global=true ULA is not treated as a public GUA prefix' "$got" yes
has_word "$ipv6_exclude_ip6" 'fd00::/8' && got=yes || got=no
check 'ULA still follows static fd00::/8 policy' "$got" yes

# Redacted live RCI shape: the router returned an active local prefix with
# global=false and an empty interface. The address below is anonymized.
write_json '{"prefix":[{"prefix":"2001:db8::/48","interface":"","valid-lifetime":"infinite","preferred-lifetime":"infinite","global":false}],"prompt":""}'
read_prefixes
[ -z "$ipv6_local_prefixes" ] && got=yes || got=no
check 'redacted live RCI response with global=false is parsed but not classified as GUA' "$got" yes
has_word "$ipv6_exclude_ip6" 'fd00::/8' && got=yes || got=no
check 'live RCI response keeps static fallback exclusions' "$got" yes

for cidr in '2a02:2168:1234::/47' '2a02:2168::/0' '2a02:2168::/65' 'not-ipv6/64' '2a02:2168::/129' '2a02:2168:::1/56' '2a02:2168:1:2:3:4:5:6:7/64' '2606:4700:4700::1111/128'; do
    write_json "{\"prefix\":[{\"prefix\":\"$cidr\",\"interface\":\"wan0\",\"valid-lifetime\":\"120\",\"global\":true}]}"
    read_prefixes
    has_word "$ipv6_local_prefixes" "$cidr" && got=yes || got=no
    check "rejects unsupported CIDR $cidr" "$got" no
done

write_json '{"prefix":[{"prefix":"2a02:2168:1234:5600::/56","interface":"wan0","valid-lifetime":"120","global":true},{"prefix":"2a02:2168:1234:5601::/64","interface":"wan0","valid-lifetime":"120","global":true},{"prefix":"2a02:2168:1234:5600::/56","interface":"wan0","valid-lifetime":"120","global":true}]}'
read_prefixes
[ "$(printf '%s\n' "$ipv6_local_prefixes" | wc -l | tr -d ' ')" = 2 ] && got=yes || got=no
check 'multiple valid prefixes are deduplicated' "$got" yes
write_json '{"prefix":[{"prefix":"2a02:2168:beef::/56","interface":"wan0","valid-lifetime":"120","global":true}]}'
read_prefixes
write_json '{"prefix":[{"prefix":"2a02:2168:cafe::/56","interface":"wan0","valid-lifetime":"120","global":true}]}'
read_prefixes
has_word "$ipv6_local_prefixes" '2a02:2168:cafe::/56' && got=yes || got=no
check 'new hook generation picks up changed PD prefix' "$got" yes
has_word "$ipv6_local_prefixes" '2a02:2168:beef::/56' && got=yes || got=no
check 'new hook generation drops prior PD prefix' "$got" no

# Mock ipt around the real add_exclude_rules generator and inspect its rules.
run_excludes() {
    : > "$work/rules"
    ipt() { printf '%s\n' "$*" >> "$work/rules"; }
    add_exclude_rules "$chain"
    cat "$work/rules"
}
add_ipset_exclude() { :; }
add_geo_exclude() { :; }
run_ipt_rules() {
    : > "$work/rules"
    ipt() { printf '%s\n' "$*" >> "$work/rules"; }
    add_ipt_rule ip6tables "$table" xkeen
    cat "$work/rules"
}
exclude_list='::/128 fd00::/8 fe80::/10'
local_exclude_list='2a02:2168:1234:5600::/56'
file_dns=false; proxy_dns=off; chain=xkeen; table=mangle; mode_proxy=TProxy
rules=$(run_excludes)
case "$rules" in *'-d 2a02:2168:1234:5600::/56'*'-j RETURN'*) got=yes ;; *) got=no ;; esac
check 'TProxy with DNS off excludes delegated local IPv6' "$got" yes

file_dns=true; proxy_dns=on; table=mangle; mode_proxy=TProxy
rules=$(run_excludes)
case "$rules" in *'-d 2a02:2168:1234:5600::/56 -p tcp ! --dport 53'*'-d 2a02:2168:1234:5600::/56 -p udp ! --dport 53'*) got=yes ;; *) got=no ;; esac
check 'TProxy DNS on preserves both TCP and UDP 53' "$got" yes

mode_proxy=Hybrid; table=mangle; rules=$(run_excludes)
case "$rules" in *'-p tcp --dport 53'*'-p udp ! --dport 53'*) got=yes ;; *) got=no ;; esac
check 'Hybrid mangle keeps TCP DNS for REDIRECT and UDP DNS for TPROXY' "$got" yes
table=nat; rules=$(run_excludes)
case "$rules" in *'-p tcp ! --dport 53'*'-p udp --dport 53'*) got=yes ;; *) got=no ;; esac
check 'Hybrid nat complements mangle for TCP and UDP DNS' "$got" yes

mode_proxy=Redirect; table=nat; rules=$(run_excludes)
case "$rules" in *'-d 2a02:2168:1234:5600::/56 -p tcp ! --dport 53'*'-j RETURN'*) got=yes ;; *) got=no ;; esac
check 'Redirect DNS on emits a local TCP/443 bypass rule (!53)' "$got" yes
case "$rules" in *'-d 2a02:2168:1234:5600::/56 -p tcp --dport 53'*'-j RETURN'*) got=yes ;; *) got=no ;; esac
check 'Redirect DNS on does not exclude local TCP 53' "$got" no

file_dns=false; proxy_dns=off; rules=$(run_excludes)
case "$rules" in *'-d 2a02:2168:1234:5600::/56'*'-j RETURN'*) got=yes ;; *) got=no ;; esac
check 'Redirect DNS off fully excludes delegated local IPv6' "$got" yes

mode_proxy=TProxy; table=mangle; chain=xkeen_force; rules=$(run_excludes)
case "$rules" in *'-d 2a02:2168:1234:5600::/56'*'-j RETURN'*) got=yes ;; *) got=no ;; esac
check 'xkeen_full force chain receives local prefix exclusions' "$got" yes
chain=xkeen_out; rules=$(run_excludes)
case "$rules" in *'-d 2a02:2168:1234:5600::/56'*'-j RETURN'*) got=yes ;; *) got=no ;; esac
check 'proxy_router OUTPUT path excludes local delegated prefix' "$got" yes

# Test the actual add_ipt_rule mode branches with ipt mocked: the local
# RETURN rules must be emitted before the terminal MARK/TPROXY/REDIRECT rules.
table_tproxy=mangle; table_redirect=nat; table_mark=0x111
port_tproxy=12345; port_redirect=12346; proxy_ip='::1'
network_tproxy='tcp udp'; network_redirect=tcp
dscp_exclude=''; port_dscp_force_proxy_tproxy=''; port_dscp_force_proxy_redirect=''
exclude_list='fd00::/8 fe80::/10'; local_exclude_list='2a02:2168:1234:5600::/56'
file_dns=true; proxy_dns=on; mode_proxy=TProxy; table=mangle
rules=$(run_ipt_rules)
case "$rules" in *'-d 2a02:2168:1234:5600::/56 -p tcp ! --dport 53'*) got=yes ;; *) got=no ;; esac
check 'TProxy add_ipt_rule includes local DNS exception' "$got" yes
case "$rules" in *'-d 2a02:2168:1234:5600::/56 -p udp ! --dport 53'*'-j TPROXY'*) got=yes ;; *) got=no ;; esac
check 'TProxy RETURN exceptions precede its terminal TPROXY actions' "$got" yes

mode_proxy=Hybrid; table=mangle; rules=$(run_ipt_rules)
case "$rules" in *'-p tcp --dport 53'*'-p udp ! --dport 53'*'-j TPROXY'*) got=yes ;; *) got=no ;; esac
check 'Hybrid mangle preserves DNS split before TPROXY action' "$got" yes
mode_proxy=Hybrid; table=nat; rules=$(run_ipt_rules)
case "$rules" in *'-p tcp ! --dport 53'*'-p udp --dport 53'*'-j REDIRECT'*) got=yes ;; *) got=no ;; esac
check 'Hybrid nat preserves DNS split before REDIRECT action' "$got" yes
mode_proxy=Redirect; table=nat; rules=$(run_ipt_rules)
file_dns=true; proxy_dns=on
rules=$(run_ipt_rules)
tcp_return_line=$(printf '%s\n' "$rules" | awk '/-d 2a02:2168:1234:5600::\/56 -p tcp ! --dport 53 .* -j RETURN/ { print NR; exit }')
redirect_line=$(printf '%s\n' "$rules" | awk '/-j REDIRECT --to-port 12346/ { print NR; exit }')
[ -n "$tcp_return_line" ] && [ -n "$redirect_line" ] && [ "$tcp_return_line" -lt "$redirect_line" ] && got=yes || got=no
check 'Redirect local TCP bypass precedes final REDIRECT' "$got" yes
case "$rules" in *'-d 2a02:2168:1234:5600::/56 -p tcp ! --dport 53'*'-j REDIRECT --to-port 12346'*) got=yes ;; *) got=no ;; esac
check 'Redirect TCP 443 bypass rule preserves TCP 53 REDIRECT' "$got" yes
case "$rules" in *'-d 2a02:2168:1234:5600::/56 -p tcp --dport 53'*'-j RETURN'*) got=yes ;; *) got=no ;; esac
check 'Redirect TCP 53 is not covered by local bypass RETURN' "$got" no

file_dns=false; proxy_dns=off; rules=$(run_ipt_rules)
case "$rules" in *'-d 2a02:2168:1234:5600::/56'*'-j RETURN'*) got=yes ;; *) got=no ;; esac
check 'Redirect DNS off keeps full local-prefix RETURN' "$got" yes

run_force_rules() {
    : > "$work/rules"
    ipt() { printf '%s\n' "$*" >> "$work/rules"; }
    add_force_ipt_rule ip6tables "$table_tproxy" xkeen_force
    cat "$work/rules"
}
file_dns=true; proxy_dns=on
mode_proxy=TProxy; table=mangle; port_dscp_force_proxy_tproxy=12347
network_dscp_force_proxy_tproxy=udp
rules=$(run_force_rules)
case "$rules" in *'-d 2a02:2168:1234:5600::/56 -p udp ! --dport 53'*'-j TPROXY --on-ip ::1'*) got=yes ;; *) got=no ;; esac
check 'xkeen_full force chain keeps local DNS exception ahead of TPROXY' "$got" yes

local_exclude_list=''; exclude_list='::/128 fd00::/8 fe80::/10'
chain=xkeen; file_dns=false; proxy_dns=off; rules=$(run_excludes)
case "$rules" in *'2606:4700:4700::1111'*) got=yes ;; *) got=no ;; esac
check 'external IPv6 absent from active RCI prefixes is not excluded' "$got" no

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
