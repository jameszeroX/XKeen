#!/bin/sh

root=/repo
pass=0
fail=0
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT INT TERM

check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"
        pass=$((pass + 1))
    else
        printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"
        fail=$((fail + 1))
    fi
}

initd_dir="$work/init.d"
backups_dir="$work/backups"
xinstall_dir="$work/install"
initd_file="$initd_dir/S05xkeen"
old_start_file="$initd_dir/S99xkeenstart"
script_file="$xinstall_dir/07_install_register/04_register_init.sh"
current_datetime='2099-01-01_00-00-00'
backup_target="$backups_dir/${current_datetime}_S05xkeen"
fail_backup=true
fail_backup_prefix="$backup_target"

mkdir -p "$initd_dir" "$backups_dir" "$(dirname "$script_file")" || exit 1
cat > "$initd_file" <<'EOF'
#!/bin/sh
name_client="mihomo"
start_auto="on"
start_delay="13"
EOF
cat > "$old_start_file" <<'EOF'
start_auto=on
start_delay=13
EOF
cat > "$script_file" <<'EOF'
#!/bin/sh
name_client="xray"
start_auto="off"
start_delay="1"
EOF
# A backup left by an earlier invocation must never be trusted when cp fails.
cat > "$backup_target" <<'EOF'
#!/bin/sh
name_client="xray"
start_auto="off"
start_delay="1"
EOF

. "$root/scripts/_xkeen/02_install/07_install_register/02_register_xkeen.sh"
date() { printf '%s\n' "$current_datetime"; }
cp() {
    if [ "$fail_backup" = true ]; then
        case "$2" in
            "$fail_backup_prefix"*)
                printf 'partial backup\n' > "$2"
                return 1
                ;;
        esac
    fi
    command cp "$@"
}
choice_backup_xkeen() { return 1; }

cp "$initd_file" "$work/original_initd"
cp "$old_start_file" "$work/original_legacy"
(register_xkeen_initd) >/dev/null 2>&1
rc=$?

check 'backup failure aborts registration' "$rc" 1
check 'existing init script is preserved' "$(cmp -s "$initd_file" "$work/original_initd" && echo yes || echo no)" yes
check 'legacy startup file is preserved' "$(cmp -s "$old_start_file" "$work/original_legacy" && echo yes || echo no)" yes
check 'stale backup is not used as migration source' "$(grep -q '^name_client="mihomo"$' "$initd_file" && echo yes || echo no)" yes
check 'partial backup is removed after cp failure' "$(find "$backups_dir" -type f | wc -l | tr -d ' ' )" 1

fail_backup=false
(register_xkeen_initd) >/dev/null 2>&1
rc=$?
check 'successful backup permits registration' "$rc" 0
check 'successful registration migrates proxy choice' "$(grep -c '^name_client="mihomo"$' "$initd_file")" 1
check 'successful registration migrates autostart' "$(grep -c '^start_auto="on"$' "$initd_file")" 1
check 'successful registration migrates start delay' "$(grep -c '^start_delay="13"$' "$initd_file")" 1

cp "$initd_file" "$work/before_unavailable_backup"
backups_dir="$work/not-a-directory"
printf 'not a directory\n' > "$backups_dir"
printf 'legacy marker\n' > "$old_start_file"
(register_xkeen_initd) >/dev/null 2>&1
rc=$?
check 'unavailable backup directory aborts registration' "$rc" 1
check 'unavailable backup directory preserves init script' "$(cmp -s "$initd_file" "$work/before_unavailable_backup" && echo yes || echo no)" yes
check 'unavailable backup directory preserves legacy file' "$(cat "$old_start_file")" 'legacy marker'

backups_dir="$work/backups"
cp "$initd_file" "$work/before_failed_publish"
mv() { return 1; }
(register_xkeen_initd) >/dev/null 2>&1
rc=$?
check 'failed publication aborts registration' "$rc" 1
check 'failed publication preserves init script' "$(cmp -s "$initd_file" "$work/before_failed_publish" && echo yes || echo no)" yes
check 'failed publication preserves legacy file' "$(cat "$old_start_file")" 'legacy marker'

legacy_root="$work/legacy"
initd_dir="$legacy_root/init.d"
backups_dir="$legacy_root/backups"
xinstall_dir="$legacy_root/install"
initd_file="$initd_dir/S05xkeen"
old_initd_file="$initd_dir/S24xray"
old_start_file="$initd_dir/S99xkeenstart"
script_file="$xinstall_dir/07_install_register/04_register_init.sh"
current_datetime='2099-01-02_00-00-00'
fail_backup_prefix="$backups_dir/${current_datetime}_S99xkeenstart"
fail_backup=true
mkdir -p "$initd_dir" "$backups_dir" "$(dirname "$script_file")" || exit 1
cat > "$old_initd_file" <<'EOF'
#!/bin/sh
name_client="xray"
name_policy="legacy-policy"
EOF
cat > "$old_start_file" <<'EOF'
start_auto=on
start_delay=23
EOF
cat > "$script_file" <<'EOF'
#!/bin/sh
name_client="xray"
name_policy="default-policy"
start_auto="off"
start_delay="1"
EOF
(register_xkeen_initd) >/dev/null 2>&1
rc=$?
check 'legacy start backup failure aborts registration' "$rc" 1
check 'legacy init script remains after backup failure' "$(grep -q '^name_policy="legacy-policy"$' "$old_initd_file" && echo yes || echo no)" yes
check 'legacy start script remains after backup failure' "$(grep -q '^start_delay=23$' "$old_start_file" && echo yes || echo no)" yes
check 'new init script is not published after backup failure' "$( [ -e "$initd_file" ] && echo yes || echo no )" no

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
