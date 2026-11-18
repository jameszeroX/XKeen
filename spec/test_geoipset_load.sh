#!/bin/sh
# Тесты санитизации входного файла в load_geoipset (install-путь) и
# load_ipset (runtime-путь, топ-левел код будущего /opt/etc/init.d/S05xkeen).
#
# Баг, ради которого написаны: до фикса обе копии по-разному чистили входной
# файл geo_exclude/geo_exclude6. load_geoipset фильтровала строки якорем
# /^[0-9a-fA-F]/ — от CRLF-входа в каждую команду ipset restore встраивался
# литеральный \r (подтверждено od -c), а IPv6-запись вида "::/0" (ведущий ':')
# якорь не матчил и молча терялась. load_ipset вообще не проверяла формат
# адреса — мусорная строка становилась аргументом ipset restore как есть.
# Обе копии сведены к паттерну load_user_ipset_family: sed CR/comment/blank-
# strip + grep -Eo с тем же адресным regex, что и везде в проекте.

# Модули целиком не подключаем: 04_register_init.sh standalone и на верхнем
# уровне содержит генерацию init.d-скрипта, а 05_install_geoipset.sh ходит в
# сеть за GeoIPSET. Берём ровно проверяемые функции — так тест бьёт по
# реальному коду, а не по его пересказу.
extract() {
    awk "/^$1\\(\\) \\{/,/^\\}/" "$2"
}
eval "$(extract load_geoipset /repo/scripts/_xkeen/02_install/05_install_geoipset.sh)"
eval "$(extract load_ipset /repo/scripts/_xkeen/02_install/07_install_register/04_register_init.sh)"
eval "$(extract load_user_ipset_family /repo/scripts/_xkeen/02_install/07_install_register/04_register_init.sh)"

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else
        printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1))
    fi
}

# Заглушка _xkeen_secure_rundir(): с коммита 789ddde load_geoipset() зовёт
# эту функцию напрямую, чтобы взять mkdir-лок против гонки на общем
# tmp-наборе "${set}_tmp" (cron `xkeen -ug` поверх ручного `xkeen -i`).
# Из 05_install_geoipset.sh awk'ом извлекается только сама load_geoipset
# (см. выше), эта функция в извлечённый текст не входит — без заглушки
# "_gi_rundir=$(_xkeen_secure_rundir)" получает пустую строку (в stderr
# уходит "not found"), и весь лок-блок пропускается веткой
# "if [ -n "$_gi_rundir" ]" — ни mkdir, ни pid-файл, ни trap ни разу не
# выполняются. Реальная версия (01_info_common.sh) создаёт системный путь
# /tmp/.xkeen с owner=root; в тесте вместо него отдаём каталог из
# собственной песочницы, чтобы лок реально брался и снимался.
rundir="$(mktemp -d)"
_xkeen_secure_rundir() {
    printf '%s' "$rundir"
}

# Заглушка ipset: реальный бинарь недоступен и не нужен — проверяется только
# текстовый пайплайн санитизации, а не поведение ipset restore/swap/destroy.
# ipset restore читает stdin последним звеном пайпа (сабшелл busybox ash), так
# что перехваченные строки сохраняем в файл, а не в переменную.
capture_file="$(mktemp)"
ipset() {
    if [ "$1" = "restore" ]; then
        cat > "$capture_file"
    fi
    return 0
}

# Fixture: CRLF, комментарий, пустая строка, мусорная строка, IPv6 с
# ведущим "::" — ровно те случаи, что разошлись между копиями.
fixture="$(mktemp)"
printf '1.2.3.0/24\r\n# comment\n   \n5.6.7.8/32\r\ngarbage not an ip\n2001:db8::/32\r\n::/0\r\n' > "$fixture"

v4_regex='([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?'
v6_regex='([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}(/[0-9]{1,3})?'

expected_v4='add geo_test_tmp 1.2.3.0/24
add geo_test_tmp 5.6.7.8/32'
expected_v6='add geo_test_tmp 2001:db8::/32
add geo_test_tmp ::/0'

# Одинаковый "set", чтобы имя tmp-набора ("${set}_tmp") совпадало у всех
# трёх функций и вывод был побайтово сравним.
: > "$capture_file"; load_geoipset geo_test "$fixture" inet
check "load_geoipset v4: без \\r, без мусора" "$(cat "$capture_file")" "$expected_v4"

: > "$capture_file"; load_geoipset geo_test "$fixture" inet6
check "load_geoipset v6: '::/0' захвачен" "$(cat "$capture_file")" "$expected_v6"

: > "$capture_file"; load_ipset geo_test "$fixture" inet
check "load_ipset v4: мусорная строка отфильтрована" "$(cat "$capture_file")" "$expected_v4"

: > "$capture_file"; load_ipset geo_test "$fixture" inet6
check "load_ipset v6: '::/0' захвачен" "$(cat "$capture_file")" "$expected_v6"

: > "$capture_file"; load_user_ipset_family geo_test inet "$v4_regex" "$fixture"
check "load_user_ipset_family v4 (эталон)" "$(cat "$capture_file")" "$expected_v4"

: > "$capture_file"; load_user_ipset_family geo_test inet6 "$v6_regex" "$fixture"
check "load_user_ipset_family v6 (эталон)" "$(cat "$capture_file")" "$expected_v6"

# --- обе копии обязаны совпадать между собой, а не только с ожиданием ---
: > "$capture_file"; load_geoipset geo_test "$fixture" inet
geoipset_v4="$(cat "$capture_file")"
: > "$capture_file"; load_ipset geo_test "$fixture" inet
ipset_v4="$(cat "$capture_file")"
check "load_geoipset и load_ipset совпадают (v4)" "$geoipset_v4" "$ipset_v4"

: > "$capture_file"; load_geoipset geo_test "$fixture" inet6
geoipset_v6="$(cat "$capture_file")"
: > "$capture_file"; load_ipset geo_test "$fixture" inet6
ipset_v6="$(cat "$capture_file")"
check "load_geoipset и load_ipset совпадают (v6)" "$geoipset_v6" "$ipset_v6"

rm -f "$capture_file" "$fixture"
rm -rf "$rundir"

printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
