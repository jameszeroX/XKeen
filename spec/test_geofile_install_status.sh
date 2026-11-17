#!/bin/sh
set -u

root=${ROOT:-/repo}
work=$(mktemp -d) || exit 1
trap 'command rm -rf "$work"' EXIT INT TERM
pass=0
fail=0
red=""; green=""; yellow=""; light_blue=""; reset=""
geo_dir="$work/geo"
geofile_update=true
xkeen_config="$work/missing.json"
refilter_url=https://example.invalid/refilter.dat
v2fly_url=https://example.invalid/v2fly.dat
zkeen_url=https://example.invalid/zkeen.dat
refilterip_url=https://example.invalid/refilterip.dat
v2flyip_url=https://example.invalid/v2flyip.dat
zkeenip_url=https://example.invalid/zkeenip.dat

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
eval "$(extract install_geosite "$root/scripts/_xkeen/02_install/04_install_geofile.sh")"
eval "$(extract install_geoip "$root/scripts/_xkeen/02_install/04_install_geofile.sh")"
eval "$(extract geofile_symlinks_enabled "$root/scripts/_xkeen/02_install/04_install_geofile.sh")"

process_geo_file() {
    processed="$processed $2"
    if [ "$2" = "$fail_file" ]; then return 1; fi
    : > "$geo_dir/$2"
    return 0
}
reset_vars() {
    mkdir -p "$geo_dir"
    processed=""
    fail_file=geosite_refilter.dat
    install_refilter_geosite=true; update_refilter_geosite=false
    install_v2fly_geosite=true; update_v2fly_geosite=false
    install_zkeen_geosite=false; update_zkeen_geosite=false
    install_refilter_geoip=false; update_refilter_geoip=false
    install_v2fly_geoip=false; update_v2fly_geoip=false
    install_zkeenip_geoip=false; update_zkeenip_geoip=false
}

# A failed built-in download must reach the installer caller while independent
# built-in downloads still get their chance.
reset_vars
install_geosite
rc=$?
check 'GeoSite wrapper returns failure from process_geo_file' "$rc" 1
case "$processed" in *geosite_refilter.dat*geosite_v2fly.dat*) continued=yes ;; *) continued=no ;; esac
check 'GeoSite continues independent file processing after one failure' "$continued" yes

reset_vars
install_refilter_geosite=false; install_v2fly_geosite=false
install_refilter_geoip=true; install_v2fly_geoip=true
fail_file=geoip_refilter.dat
install_geoip
rc=$?
check 'GeoIP wrapper returns failure from process_geo_file' "$rc" 1
case "$processed" in *geoip_refilter.dat*geoip_v2fly.dat*) continued=yes ;; *) continued=no ;; esac
check 'GeoIP continues independent file processing after one failure' "$continued" yes

# If alias publication fails, the previous alias must remain available.
reset_vars
install_refilter_geosite=false
install_v2fly_geosite=false
install_zkeen_geosite=true
fail_file=never
zkeen_url=https://example.invalid/zkeen.dat
geofile_symlinks_enabled() { return 0; }
: > "$geo_dir/zkeen.dat"
: > "$geo_dir/geosite_zkeen.dat"
ln() {
    case "$*" in *"$geo_dir/zkeen.dat.tmp."*) return 1 ;; esac
    command ln "$@"
}
install_geosite >/dev/null 2>&1
check 'previous GeoSite alias survives failed symlink replacement' "$([ -f "$geo_dir/zkeen.dat" ] && echo yes || echo no)" yes

reset_vars
install_refilter_geosite=false
install_v2fly_geosite=false
install_zkeen_geosite=true
fail_file=never
: > "$geo_dir/zkeen.dat"
: > "$geo_dir/geosite_zkeen.dat"
ln() { command ln "$@"; }
mv() {
    case "$*" in *"$geo_dir/zkeen.dat") return 1 ;; esac
    command mv "$@"
}
install_geosite >/dev/null 2>&1
check 'previous GeoSite alias survives failed atomic rename' "$([ -f "$geo_dir/zkeen.dat" ] && echo yes || echo no)" yes

reset_vars
install_refilter_geoip=false
install_v2fly_geoip=false
install_zkeenip_geoip=true
fail_file=never
: > "$geo_dir/zkeenip.dat"
: > "$geo_dir/geoip_zkeenip.dat"
ln() {
    case "$*" in *"$geo_dir/zkeenip.dat.tmp."*) return 1 ;; esac
    command ln "$@"
}
install_geoip >/dev/null 2>&1
rc=$?
check 'GeoIP alias replacement failure reaches caller' "$rc" 1
check 'previous GeoIP alias survives failed symlink replacement' "$([ -f "$geo_dir/zkeenip.dat" ] && echo yes || echo no)" yes

printf '\n=== passed: %s, failed: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
