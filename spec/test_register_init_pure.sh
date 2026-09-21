#!/bin/sh
# Тесты пяти функций 04_register_init.sh с нетривиальной граничной логикой,
# на которые не было ни одной регрессионной проверки (grep по spec/ — 0
# совпадений для каждой).
#
# format_routing_mark_items, validate_and_clean_ports, normalize_network_list
# и hex_mark_to_decimal — чистые функции: строка на входе, строка на выходе.
# Экстракция и проверка — по образцу spec/test_strip_json.sh.
#
# resolve_user_policies — НЕ чистая функция: аргументов не принимает, читает
# файл $xkeen_config и глобальные $api_policy_json/$file_dns/$proxy_dns,
# вызывает jq и три вспомогательные функции (strip_json_comments,
# get_api_exclude_ports, validate_and_clean_ports). Тестируется через
# временный JSON-фикстур и замоканные глобальные переменные, по образцу
# spec/test_balancer.sh.
#
# Модуль целиком не подключаем: на верхнем уровне он ходит curl'ом в RCI
# роутера и парсит опции командной строки. Берём ровно проверяемые функции.
#
# spec/ сейчас не подключён ни к одному workflow в .github/workflows/ (grep
# -rl "spec/" .github/workflows/ пуст), поэтому этот тест защищает только при
# ручном/локальном прогоне, а не автоматически в CI.

FILE=/repo/scripts/_xkeen/02_install/07_install_register/04_register_init.sh

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else
        printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1))
    fi
}

# =========================================================================
# format_routing_mark_items — форматирует список интерфейсов/маршрутов с их
# метками для вывода в терминал: дедуплицирует повторяющиеся строки и
# подставляет метку "отсутствует", если поле метки пусто.
# =========================================================================
extract() {
    awk '/^format_routing_mark_items\(\) \{/,/^\}/' "$1"
}
eval "$(extract "$FILE")"

raw=$(printf 'eth0\t0x1\neth0\t0x1\neth1\t')
got=$(format_routing_mark_items "интерфейс" "метка" "$raw")
exp='  - интерфейс eth0: найден метка 0x1
  - интерфейс eth1: метка отсутствует'
check "дедупликация повторов + метка для пустого mark" "$got" "$exp"

raw=$(printf 'a\tX\nb\tY\nc\t')
got=$(format_routing_mark_items "элемент" "mark" "$raw")
exp='  - элемент a: найден mark X
  - элемент b: найден mark Y
  - элемент c: mark отсутствует'
check "без дублей все строки печатаются" "$got" "$exp"

# =========================================================================
# validate_and_clean_ports — разбирает CSV-список портов/диапазонов,
# нормализует обратные диапазоны, отбрасывает невалидные значения,
# схлопывает дубликаты и сортирует результат.
# =========================================================================
extract() {
    awk '/^validate_and_clean_ports\(\) \{/,/^\}/' "$1"
}
eval "$(extract "$FILE")"

check "обратный диапазон 443-80 нормализуется в 80:443" \
    "$(validate_and_clean_ports '443-80' '')" '80:443'

check "прямой диапазон не переворачивается" \
    "$(validate_and_clean_ports '80-443' '')" '80:443'

check "порт вне диапазона (0, >65535) отбрасывается" \
    "$(validate_and_clean_ports '0,70000,80' '')" '80'

check "дубликаты схлопываются" \
    "$(validate_and_clean_ports '80,80,443,443,443' '')" '80,443'

check "режим только mandatory_ports" \
    "$(validate_and_clean_ports '' '53,80')" '53,80'

out=$(validate_and_clean_ports '' ''); rc=$?
check "оба аргумента пусты: пустой вывод" "$out" ''
check "оба аргумента пусты: rc=1" "$rc" '1'

# =========================================================================
# hex_mark_to_decimal — переводит fwmark из hex (с необязательным префиксом
# 0x/0X, регистронезависимо) в десятичное число.
# =========================================================================
extract() {
    awk '/^hex_mark_to_decimal\(\) \{/,/^\}/' "$1"
}
eval "$(extract "$FILE")"

check "валидный hex с префиксом 0x (нижний регистр)" \
    "$(hex_mark_to_decimal '0xff')" '255'

check "валидный hex с префиксом 0X (верхний регистр)" \
    "$(hex_mark_to_decimal '0XFF')" '255'

check "валидный hex без префикса" \
    "$(hex_mark_to_decimal 'a')" '10'

out=$(hex_mark_to_decimal 'zz'); rc=$?
check "невалидный hex: пустой вывод" "$out" ''
check "невалидный hex: rc=1" "$rc" '1'

# =========================================================================
# normalize_network_list — нормализует список сетевых протоколов: оставляет
# только tcp/udp, дедуплицирует, отфильтровывает неизвестные токены.
# =========================================================================
extract() {
    awk '/^normalize_network_list\(\) \{/,/^\}/' "$1"
}
eval "$(extract "$FILE")"

check "дедупликация tcp/udp" \
    "$(normalize_network_list 'tcp,udp,tcp')" 'tcp udp'

check "неизвестные токены отфильтрованы" \
    "$(normalize_network_list 'tcp,foo,udp,bar')" 'tcp udp'

check "порядок первого появления сохраняется" \
    "$(normalize_network_list 'udp,tcp,udp')" 'udp tcp'

# =========================================================================
# resolve_user_policies — НЕ чистая функция (см. заголовок файла). Читает
# $xkeen_config (порты и имена пользовательских политик) и глобальный
# $api_policy_json (описания и fwmark-метки от RCI), сопоставляет их по
# имени/description регистронезависимо (jq ascii_downcase — только ASCII,
# для кириллицы регистр не приводится, поэтому кейс с кириллицей ниже не
# берём: это не баг теста, а реальное ограничение ascii_downcase).
#
# Неочевидный контракт, обнаруженный при чтении кода: итоговый порт политики
# берётся из ЛОКАЛЬНОГО xkeen_config (.port из $up), а не из api_policy_json
# (.port там игнорируется) — ниже это явно проверяется отдельным кейсом.
# =========================================================================
extract() {
    awk '/^strip_json_comments\(\) \{/,/^\}/' "$1"
}
eval "$(extract "$FILE")"

extract() {
    awk '/^get_api_exclude_ports\(\) \{/,/^\}/' "$1"
}
eval "$(extract "$FILE")"

extract() {
    awk '/^validate_and_clean_ports\(\) \{/,/^\}/' "$1"
}
eval "$(extract "$FILE")"

extract() {
    awk '/^resolve_user_policies\(\) \{/,/^\}/' "$1"
}
eval "$(extract "$FILE")"

WORK=/tmp/rip_test
rm -rf "$WORK"; mkdir -p "$WORK"
xkeen_config="$WORK/xkeen.json"

# --- режим "all" (порт в xkeen_config не задан, api_exclude_ports пуст) ---
printf '{"xkeen":{"policy":[{"name":"AllTraffic"}]}}' > "$xkeen_config"
api_policy_json='[{"description":"AllTraffic","mark":"0x2"}]'
api_static_json=""
file_dns=""; proxy_dns=""
check "режим all без api_exclude_ports" \
    "$(resolve_user_policies)" 'AllTraffic|0x2|all|'

# --- режим "all" + подмешивание api_exclude_ports (mode -> exclude) ---
printf '{"xkeen":{"policy":[{"name":"Guest"}]}}' > "$xkeen_config"
api_policy_json='[{"description":"Guest","mark":"0x3"}]'
api_static_json='[{"port":"9000","end-port":"9010"},{"port":"80"},{"port":"443"}]'
check "режим all с api_exclude_ports становится exclude" \
    "$(resolve_user_policies)" 'Guest|0x3|exclude|9000:9010'

# --- явный exclude ("!8080") + подмешивание api_exclude_ports ---
printf '{"xkeen":{"policy":[{"name":"NoGames","port":"!8080"}]}}' > "$xkeen_config"
api_policy_json='[{"description":"NoGames","mark":"0x4"}]'
api_static_json='[{"port":"9000","end-port":"9010"}]'
check "явный exclude смешивается с api_exclude_ports" \
    "$(resolve_user_policies)" 'NoGames|0x4|exclude|8080,9000:9010'

# --- include с авто-инъекцией порта 53 (file_dns=true + proxy_dns=on) ---
# Порт "9999" в api_policy_json намеренно НЕ должен попасть в результат:
# порт берётся из xkeen_config, api-шный порт для этого поля игнорируется.
printf '{"xkeen":{"policy":[{"name":"Work","port":"80,443"}]}}' > "$xkeen_config"
api_policy_json='[{"description":"work","mark":"0x1","port":"9999"}]'
api_static_json=""
file_dns="true"; proxy_dns="on"
check "include: авто-инъекция 53 при file_dns=true и proxy_dns=on" \
    "$(resolve_user_policies)" 'Work|0x1|include|53,80,443'

# --- include без DNS-условий: порта 53 быть не должно ---
printf '{"xkeen":{"policy":[{"name":"Movies","port":"80,443"}]}}' > "$xkeen_config"
api_policy_json='[{"description":"Movies","mark":"0x5"}]'
file_dns="false"; proxy_dns="on"
check "include: без file_dns=true порт 53 не добавляется" \
    "$(resolve_user_policies)" 'Movies|0x5|include|80,443'

# --- регистронезависимое сопоставление имени (ASCII) ---
file_dns=""; proxy_dns=""
printf '{"xkeen":{"policy":[{"name":"GAMING","port":"6000,7000"}]}}' > "$xkeen_config"
api_policy_json='[{"description":"gaming","mark":"0x9"}]'
check "сопоставление имени регистронезависимо (ASCII)" \
    "$(resolve_user_policies)" 'GAMING|0x9|include|6000,7000'

# --- отсутствующий xkeen_config -> rc=1, пустой вывод ---
xkeen_config="$WORK/no_such_file.json"
api_policy_json='[{"description":"whatever","mark":"0x1"}]'
out=$(resolve_user_policies); rc=$?
check "отсутствующий xkeen_config: пустой вывод" "$out" ''
check "отсутствующий xkeen_config: rc=1" "$rc" '1'

rm -rf "$WORK"

printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
