#!/bin/sh
pass=0
fail=0
check() {
    if [ "$2" = "$3" ]; then printf 'OK   %s\n' "$1"; pass=$((pass + 1));
    else printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"; fail=$((fail + 1)); fi
}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
for mode in wrapper modules success; do
    case_dir="$work/$mode"
    mkdir -p "$case_dir/live/.xkeen" "$case_dir/archive/_xkeen"
    printf 'old-modules\n' > "$case_dir/live/.xkeen/version"
    printf 'new-modules\n' > "$case_dir/archive/_xkeen/version"
    printf '#!/bin/sh\nprintf "old-wrapper\\n"\ncat "$(dirname "$0")/.xkeen/version"\n' > "$case_dir/live/xkeen"
    printf '#!/bin/sh\nprintf "new-wrapper\\n"\ncat "$(dirname "$0")/.xkeen/version"\n' > "$case_dir/archive/xkeen"
    archive_name="$case_dir/xkeen.tar.gz"
    tar -czf "$archive_name" -C "$case_dir/archive" xkeen _xkeen
    block=$(awk '/^stage_dir=/ { on=1 } on {print}' /repo/install.sh | sed "s#/opt/sbin#$case_dir/live#g")
    mv() {
        if { [ "$mode" = wrapper ] && [ "$1" = "$case_dir/live/xkeen" ]; } ||
           { [ "$mode" = modules ] && [ "$1" = "$case_dir/live/.xkeen" ]; }; then
            return 1
        fi
        command mv "$@"
    }
    (eval "$block") > "$case_dir/output" 2>&1; rc=$?
    if [ "$mode" = success ]; then
        check 'successful promotion exits successfully' "$rc" 0
        check 'new wrapper loads new modules' "$(cat "$case_dir/output")" "$(printf 'new-wrapper\nnew-modules')"
    else
        check "$mode backup failure aborts promotion" "$rc" 1
        check "$mode failure preserves old wrapper" "$(grep -c old-wrapper "$case_dir/live/xkeen")" 1
        check "$mode failure preserves old modules" "$(cat "$case_dir/live/.xkeen/version")" old-modules
        check "$mode failure never nests modules" "$([ -e "$case_dir/live/.xkeen/_xkeen" ] && echo yes || echo no)" no
    fi
 done
printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
