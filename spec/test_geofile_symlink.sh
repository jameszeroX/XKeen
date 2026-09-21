#!/bin/sh
# Тесты guard'а симлинков zkeen(ip) в install_geosite/install_geoip.
#
# Баг, ради которого написаны: process_geo_file вызывался без проверки
# результата, и следом безусловно создавался симлинк на geosite_zkeen.dat /
# geoip_zkeenip.dat — при неудачной первой загрузке (html-стаб, несовпадение
# размера, исчерпанные повторы) получался битый (dangling) симлинк вместо
# отсутствия файла. Комментарий «после успешной загрузки» при этом не
# соответствовал коду. Проверяем: неудача без файла не создаёт симлинк,
# успех создаёт его корректно, а неудачное обновление не ломает уже
# существующий рабочий симлинк.

italic=""; reset=""; red=""; green=""; yellow=""; light_blue=""

WORK=/tmp/geofile_symlink_test
rm -rf "$WORK"; mkdir -p "$WORK"
geo_dir="$WORK/geo"
geofile_update="true"

# process_geo_file полностью стабится: реальная загрузка не нужна, нужен
# только контракт "успех => файл на месте, провал => файла нет" (его же
# соблюдает mv -f в _download_and_validate_loop).
# STUB_RC — что вернуть; STUB_CREATE=1 — положить файл $2 перед возвратом 0.
process_geo_file() {
    local filename="$2"
    if [ "$STUB_RC" = "0" ]; then
        : > "$geo_dir/$filename"
    fi
    return "$STUB_RC"
}

# install_geosite/install_geoip берём из реального кода через awk-экстракцию
# (как strip_json_comments в test_strip_json.sh) — так тест бьёт по реальному
# guard'у, а не по его копии.
extract() {
    awk "/^$2\\(\\) \\{/,/^\\}/" "$1"
}
eval "$(extract /repo/scripts/_xkeen/02_install/04_install_geofile.sh install_geosite)"
eval "$(extract /repo/scripts/_xkeen/02_install/04_install_geofile.sh install_geoip)"

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else
        printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1))
    fi
}

reset_geo() {
    rm -rf "$geo_dir"; mkdir -p "$geo_dir"
    install_zkeen_geosite="true"; update_zkeen_geosite="false"
    install_refilter_geosite="false"; update_refilter_geosite="false"
    install_v2fly_geosite="false"; update_v2fly_geosite="false"
    zkeen_url="http://example.invalid/zkeen"

    install_zkeenip_geoip="true"; update_zkeenip_geoip="false"
    install_refilter_geoip="false"; update_refilter_geoip="false"
    install_v2fly_geoip="false"; update_v2fly_geoip="false"
    zkeenip_url="http://example.invalid/zkeenip"
}

# --- GeoSite: провал первой загрузки не создаёт симлинк ---
reset_geo
STUB_RC=1
install_geosite
check "geosite: провал → zkeen.dat не создан" \
    "$([ -e "$geo_dir/zkeen.dat" ] && echo есть || echo нет)" "нет"
check "geosite: провал → geosite_zkeen.dat не создан" \
    "$([ -e "$geo_dir/geosite_zkeen.dat" ] && echo есть || echo нет)" "нет"

# --- GeoSite: успех создаёт симлинк на реальный файл ---
reset_geo
STUB_RC=0
install_geosite
check "geosite: успех → zkeen.dat симлинк" \
    "$([ -L "$geo_dir/zkeen.dat" ] && echo да || echo нет)" "да"
check "geosite: успех → zkeen.dat указывает на рабочий файл" \
    "$([ -f "$geo_dir/zkeen.dat" ] && echo да || echo нет)" "да"

# --- GeoSite: неудачное обновление не ломает уже рабочий симлинк ---
reset_geo
: > "$geo_dir/geosite_zkeen.dat"
ln -sf "$geo_dir/geosite_zkeen.dat" "$geo_dir/zkeen.dat"
update_zkeen_geosite="true"; install_zkeen_geosite="false"
STUB_RC=1
install_geosite
check "geosite: неудачный апдейт → старый симлинк цел" \
    "$([ -f "$geo_dir/zkeen.dat" ] && echo да || echo нет)" "да"

# --- GeoIP: тот же guard, симметрично ---
reset_geo
STUB_RC=1
install_geoip
check "geoip: провал → zkeenip.dat не создан" \
    "$([ -e "$geo_dir/zkeenip.dat" ] && echo есть || echo нет)" "нет"
check "geoip: провал → geoip_zkeenip.dat не создан" \
    "$([ -e "$geo_dir/geoip_zkeenip.dat" ] && echo есть || echo нет)" "нет"

reset_geo
STUB_RC=0
install_geoip
check "geoip: успех → zkeenip.dat симлинк" \
    "$([ -L "$geo_dir/zkeenip.dat" ] && echo да || echo нет)" "да"
check "geoip: успех → zkeenip.dat указывает на рабочий файл" \
    "$([ -f "$geo_dir/zkeenip.dat" ] && echo да || echo нет)" "да"

reset_geo
: > "$geo_dir/geoip_zkeenip.dat"
ln -sf "$geo_dir/geoip_zkeenip.dat" "$geo_dir/zkeenip.dat"
update_zkeenip_geoip="true"; install_zkeenip_geoip="false"
STUB_RC=1
install_geoip
check "geoip: неудачный апдейт → старый симлинк цел" \
    "$([ -f "$geo_dir/zkeenip.dat" ] && echo да || echo нет)" "да"

printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
