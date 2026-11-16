#!/bin/sh
set -u

root=${ROOT:-/repo}
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
extract() {
    awk -v name="$1" '$0 == name "() {" { on=1 } on { print } on && /^}/ { exit }' "$2"
}

common="$root/scripts/_xkeen/01_info/01_info_common.sh"
choice="$root/scripts/_xkeen/04_tools/05_tools_choice/02_choice_xkeen.sh"
eval "$(extract strip_json_comments "$common")"
eval "$(extract validate_xkeen_json_syntax "$common")"
eval "$(extract jc_set_path "$common" | sed 's/^jc_set_path()/actual_jc_set_path()/')"
eval "$(extract change_killswitch "$choice")"

xkeen_config="$work/xkeen.json"
bak="${xkeen_config}.bak"
red=''; green=''; reset=''
register_calls=0
register_xkeen_initd() { register_calls=$((register_calls + 1)); }
force_write_failure=false
jc_set_path_calls=0
jc_set_path() {
    jc_set_path_calls=$((jc_set_path_calls + 1))
    if [ "$force_write_failure" = true ]; then
        printf '{invalid JSON\n'
        return 1
    fi
    actual_jc_set_path "$@"
}
backup_failure=false
backup_publish_failure=false
cp() {
    if [ "$backup_failure" = true ]; then
        case "$2" in
            "$bak"*) return 1 ;;
        esac
    fi
    command cp "$@"
}
mv() {
    if [ "$backup_publish_failure" = true ] && [ "$3" = "$bak" ]; then
        return 1
    fi
    command mv "$@"
}

write_original_config() {
    cat > "$xkeen_config" <<'EOF'
{
  "xkeen": {
    // keep this user comment
    "killswitch": "on",
    "custom": "keep"
  }
}
EOF
}

write_original_config
cp "$xkeen_config" "$work/original.json"
cat > "$bak" <<'EOF'
{"xkeen":{"killswitch":"off","custom":"stale backup"}}
EOF
cp "$bak" "$work/stale-backup.json"
backup_failure=true
force_write_failure=true
change_killswitch off >/dev/null 2>&1
rc=$?
check 'backup copy failure returns error' "$rc" 1
check 'configuration is preserved after backup failure' "$(cmp -s "$xkeen_config" "$work/original.json" && echo yes || echo no)" yes
check 'stale backup is not copied over configuration' "$(grep -q '"custom": "keep"' "$xkeen_config" && echo yes || echo no)" yes
check 'failed backup aborts before JSON update' "$jc_set_path_calls" 0
check 'stale backup remains unchanged' "$(cmp -s "$bak" "$work/stale-backup.json" && echo yes || echo no)" yes

write_original_config
backup_failure=false
force_write_failure=false
backup_publish_failure=false
change_killswitch off >/dev/null 2>&1
rc=$?
check 'successful toggle returns success' "$rc" 0
check 'successful toggle updates only killswitch' "$(strip_json_comments "$xkeen_config" | jq -r '.xkeen.killswitch,.xkeen.custom' | tr -d '\r' | tr '\n' ':')" 'off:keep:'
check 'successful toggle preserves JSONC comment' "$(grep -c 'keep this user comment' "$xkeen_config")" 1
check 'successful backup contains previous configuration' "$(cmp -s "$bak" "$work/original.json" && echo yes || echo no)" yes
check 'successful toggle registers init script once' "$register_calls" 1

write_original_config
cp "$xkeen_config" "$work/before_backup_publish_failure.json"
backup_publish_failure=true
change_killswitch off >/dev/null 2>&1
rc=$?
check 'backup publication failure returns error' "$rc" 1
check 'backup publication failure preserves configuration' "$(cmp -s "$xkeen_config" "$work/before_backup_publish_failure.json" && echo yes || echo no)" yes
check 'backup publication failure does not register init script' "$register_calls" 1

write_original_config
backup_publish_failure=false
force_write_failure=true
change_killswitch off >/dev/null 2>&1
rc=$?
check 'JSON generation failure returns error' "$rc" 1
check 'JSON generation failure preserves configuration' "$(cmp -s "$xkeen_config" "$work/before_backup_publish_failure.json" && echo yes || echo no)" yes
check 'JSON generation failure does not register init script' "$register_calls" 1
check 'failed operation leaves no temporary config' "$(find "$work" -name 'xkeen.json.tmp.*' | wc -l | tr -d ' ')" 0

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
