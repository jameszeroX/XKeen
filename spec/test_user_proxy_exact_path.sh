#!/bin/sh
# Only .xkeen.gh_proxy may control GitHub requests.
set -u

root=${ROOT:-.}
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM
xkeen_config="$work/xkeen.json"
gh_proxy_user=''

eval "$(awk '/^strip_json_comments\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/01_info/01_info_common.sh")"
eval "$(awk '/^jsonc_get_xkeen_gh_proxy\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/05_tests/01_tests_system.sh")"
eval "$(awk '/^get_user_proxy\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/05_tests/01_tests_system.sh")"

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

cat > "$xkeen_config" <<'JSON'
{
  "other": { "gh_proxy": "https://wrong.example" },
  "xkeen": { "gh_proxy": "https://right.example/" }
}
JSON
eval "$(awk '/^strip_json_comments\(\) \{/,/^}/ { print }' "$root/install.sh")"
eval "$(awk '/^jsonc_get_xkeen_gh_proxy\(\) \{/,/^}/ { print }' "$root/install.sh")"
eval "$(awk '/^get_user_proxy\(\) \{/,/^}/ { print }' "$root/install.sh")"
get_user_proxy
check 'installer proxy comes from .xkeen.gh_proxy' "$gh_proxy_user" 'https://right.example'

eval "$(awk '/^strip_json_comments\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/01_info/01_info_common.sh")"
eval "$(awk '/^get_user_proxy\(\) \{/,/^}/ { print }' \
    "$root/scripts/_xkeen/05_tests/01_tests_system.sh")"
if command -v jq >/dev/null 2>&1; then
    get_user_proxy
    check 'runtime proxy comes from .xkeen.gh_proxy' "$gh_proxy_user" 'https://right.example'
else
    printf 'SKIP runtime path extraction requires jq\n'
fi

cat > "$xkeen_config" <<'JSON'
{
  "other": { "gh_proxy": "https://wrong.example" },
  "xkeen": {}
}
JSON
get_user_proxy >/dev/null 2>&1
check 'runtime ignores an unrelated gh_proxy key' "${gh_proxy_user:-}" ''

# Simulate a fresh installer/runtime without jq. Ambiguous plain-text fallback
# must not select a value from another JSON object.
command() { [ "$1" = -v ] && [ "$2" = jq ] && return 1; }
cat > "$xkeen_config" <<'JSON'
{
  "other": { "gh_proxy": "https://wrong.example" },
  "xkeen": {}
}
JSON
get_user_proxy >/dev/null 2>&1
check 'runtime without jq ignores unrelated keys' "${gh_proxy_user:-}" ''

cat > "$xkeen_config" <<'JSON'
{
  "other": { "gh_proxy": "https://wrong.example" },
  "xkeen": { "gh_proxy": "https://right.example/" }
}
JSON
get_user_proxy
check 'runtime without jq does not use an ambiguous fallback' "${gh_proxy_user:-}" ''

cat > "$xkeen_config" <<'JSON'
{"other":{"gh_proxy":"https://wrong.example"},"xkeen":{"gh_proxy":"https://right.example/"
JSON
get_user_proxy >/dev/null 2>&1
check 'runtime without jq rejects truncated JSON' "${gh_proxy_user:-}" ''
cat > "$xkeen_config" <<'JSON'
{"xkeen":{"gh_proxy":null,"other":"https://wrong.example"}}
JSON
get_user_proxy >/dev/null 2>&1
check 'runtime without jq rejects non-string proxy' "${gh_proxy_user:-}" ''

eval "$(awk '/^strip_json_comments\(\) \{/,/^}/ { print }' "$root/install.sh")"
eval "$(awk '/^get_user_proxy\(\) \{/,/^}/ { print }' "$root/install.sh")"
cat > "$xkeen_config" <<'JSON'
{
  "other": { "gh_proxy": "https://wrong.example" },
  "xkeen": { "gh_proxy": "https://right.example/" }
}
JSON
get_user_proxy
check 'installer without jq reads the exact xkeen path' "$gh_proxy_user" 'https://right.example'
cat > "$xkeen_config" <<'JSON'
{
  "other": { "gh_proxy": "https://wrong.example" },
  "xkeen": {}
}
JSON
get_user_proxy >/dev/null 2>&1
check 'installer without jq ignores unrelated keys' "${gh_proxy_user:-}" ''

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
