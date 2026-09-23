#!/bin/sh
# Тесты fetch_release_tags: ретраи, fallback GitHub API -> jsDelivr, фильтр
# Prerelease-Alpha, кап head -n 8. Функция гейтит, какие версии Xray/Mihomo/
# XKeen видит пользователь при установке (01_downloaders_xray.sh,
# 01_downloaders_mihomo.sh), но не имела покрытия.
#
# curl_with_timeout заглушен shell-функцией (это то, что реально вызывает
# fetch_release_tags, не curl() напрямую). Модуль не ходит на верхнем уровне
# в сеть (в отличие от 01_info_variable.sh), поэтому подключается целиком
# без awk-извлечения — тот же приём, что в test_balancer.sh для
# 01_balancer_core.sh.

italic=""; reset=""; red=""; green=""; yellow=""; light_blue=""

WORK=/tmp/frt_test
rm -rf "$WORK"; mkdir -p "$WORK"

# Заглушка _xkeen_secure_rundir(): 00_fetch_with_mirrors.sh на верхнем
# уровне ("_mirror_cache_dir="$(_xkeen_secure_rundir)" || ...") зовёт эту
# функцию, чтобы завести кэш зеркал _mirror_cache. Сама функция определена
# в 01_info_common.sh, который этот тест не подключает, поэтому без
# заглушки source модуля печатает "_xkeen_secure_rundir: not found" на
# stderr, а $_mirror_cache_dir остаётся пустой строкой. fetch_release_tags()
# этот кэш не читает и не пишет: её собственный файловый кэш строится
# через _release_cache_path() из $tmp_ram (тоже из 01_info_common.sh,
# здесь не задан) и для фейковых URL этого теста всегда возвращает rc=1.
# Заглушка убирает постороннее сообщение при source, а не меняет путь,
# по которому идёт проверяемый код.
_xkeen_secure_rundir() {
    printf '%s' "$WORK"
}

. /repo/scripts/_xkeen/04_tools/07_tools_downloaders/00_fetch_with_mirrors.sh

# --- заглушка curl_with_timeout -------------------------------------------
# Ответы берутся из очередей-файлов (по одной строке JSON-фикстуры на вызов,
# без переносов строк внутри — иначе строка-разделитель перестанет работать).
# Счётчики вызовов и лог задержек пишутся в файлы, а не в переменные: первая
# команда пайпа (curl_with_timeout | jq | grep | head) выполняется ash'ем в
# сабшелле, изменения переменных там не долетают до родителя — тот же приём,
# что curl() в test_balancer.sh использует для записи правила замера наружу.
FAKE_API_URL="https://fake-api.example/releases"
FAKE_JSD_URL="https://fake-jsd.example/versions.json"

curl_with_timeout() {
    _frt_url="$2"
    case "$_frt_url" in
        "$FAKE_API_URL"*)
            echo x >> "$WORK/api_calls"
            sed -n '1p' "$WORK/api_queue" 2>/dev/null
            sed -i '1d' "$WORK/api_queue" 2>/dev/null
            ;;
        "$FAKE_JSD_URL"*)
            echo x >> "$WORK/jsd_calls"
            sed -n '1p' "$WORK/jsd_queue" 2>/dev/null
            sed -i '1d' "$WORK/jsd_queue" 2>/dev/null
            ;;
    esac
}

# sleep заглушен, чтобы ретраи не тормозили тест и чтобы проверить, с какой
# задержкой они реально идут.
sleep() { echo "$1" >> "$WORK/sleep_log"; }

api_calls() { [ -f "$WORK/api_calls" ] && wc -l < "$WORK/api_calls" | tr -d ' ' || echo 0; }
jsd_calls() { [ -f "$WORK/jsd_calls" ] && wc -l < "$WORK/jsd_calls" | tr -d ' ' || echo 0; }
sleep_calls() { [ -f "$WORK/sleep_log" ] && wc -l < "$WORK/sleep_log" | tr -d ' ' || echo 0; }

# Сброс очередей/счётчиков/настроек перед каждым сценарием.
frt_reset() {
    rm -f "$WORK/api_calls" "$WORK/jsd_calls" "$WORK/sleep_log"
    : > "$WORK/api_queue"
    : > "$WORK/jsd_queue"
    retries_download="${1:-1}"
    retry_delay_download="${2:-2}"
}

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1)); fi
}

# === успешный путь: GitHub API, фильтр Prerelease-Alpha + кап head -n 8 ===
# 10 валидных тегов + 2 Prerelease-Alpha. Один alpha-тег стоит МЕЖДУ v3 и v4,
# то есть внутри первых 8 позиций сырого списка - если фильтр не отработает,
# он попадёт в head -n 8 вместо v8 (сдвинет его за кап). Так мутация,
# убирающая `grep -ivE 'Prerelease-Alpha'` из продакшн-кода, реально ломает
# проверки "v8 присутствует" и "alpha отфильтрован", а не проходит незамеченной
# (при alpha исключительно в хвосте её и так обрезает head -n 8 независимо от
# фильтра). Второй alpha-тег - в конце, разный регистр, для проверки
# регистронезависимости фильтра без влияния на кап.
frt_reset 1 2
printf '[{"tag_name":"v1"},{"tag_name":"v2"},{"tag_name":"v3"},{"tag_name":"v3.5-Prerelease-Alpha"},{"tag_name":"v4"},{"tag_name":"v5"},{"tag_name":"v6"},{"tag_name":"v7"},{"tag_name":"v8"},{"tag_name":"v9"},{"tag_name":"v10"},{"tag_name":"v11-prerelease-alpha"}]\n' > "$WORK/api_queue"
fetch_release_tags "$FAKE_API_URL" "$FAKE_JSD_URL" 10 >/dev/null 2>&1
check "успех API: 8 строк (кап head -n 8)"        "$(printf '%s\n' "$RELEASE_TAGS" | wc -l | tr -d ' ')" "8"
check "успех API: v1 присутствует"                "$(printf '%s\n' "$RELEASE_TAGS" | grep -c '^v1$')" "1"
check "успех API: v8 присутствует (alpha не заняла его место в капе)" "$(printf '%s\n' "$RELEASE_TAGS" | grep -c '^v8$')" "1"
check "успех API: v9 срезан капом"                "$(printf '%s\n' "$RELEASE_TAGS" | grep -c '^v9$')" "0"
check "успех API: Prerelease-Alpha отфильтрован"  "$(printf '%s\n' "$RELEASE_TAGS" | grep -ic 'prerelease-alpha')" "0"
check "успех API: USE_JSDELIVR пуст"              "$USE_JSDELIVR" ""
check "успех API: jsDelivr не вызывался"          "$(jsd_calls)" "0"
check "успех API: ровно 1 вызов API"              "$(api_calls)" "1"

# === fallback: GitHub API пуст -> jsDelivr ===
frt_reset 1 2
printf '[]\n' > "$WORK/api_queue"
printf '{"versions":["j1","j2","j3"]}\n' > "$WORK/jsd_queue"
fetch_release_tags "$FAKE_API_URL" "$FAKE_JSD_URL" 10 >/dev/null 2>&1
check "fallback: RELEASE_TAGS непуст"    "$([ -n "$RELEASE_TAGS" ] && echo yes || echo no)" "yes"
check "fallback: j1 присутствует"        "$(printf '%s\n' "$RELEASE_TAGS" | grep -c '^j1$')" "1"
check "fallback: USE_JSDELIVR=true"      "$USE_JSDELIVR" "true"
check "fallback: 1 вызов API"            "$(api_calls)" "1"
check "fallback: 1 вызов jsDelivr"       "$(jsd_calls)" "1"

# === полный провал: оба источника пусты -> exit 1 (в сабшелле) ===
frt_reset 1 2
printf '\n' > "$WORK/api_queue"
printf '\n' > "$WORK/jsd_queue"
out=$( (fetch_release_tags "$FAKE_API_URL" "$FAKE_JSD_URL" 10) 2>&1 ); rc=$?
check "полный провал: exit 1"                  "$rc" "1"
check "полный провал: сообщение об ошибке"     "$(printf '%s' "$out" | grep -c 'Не удалось получить список релизов')" "1"

# === счётчик попыток: retries_download<=1 -> ровно 1 вызов на источник ===
frt_reset 1 2
printf '\n' > "$WORK/api_queue"
printf '{"versions":["j-ok"]}\n' > "$WORK/jsd_queue"
fetch_release_tags "$FAKE_API_URL" "$FAKE_JSD_URL" 10 >/dev/null 2>&1
check "retries<=1: 1 вызов API"       "$(api_calls)" "1"
check "retries<=1: 1 вызов jsDelivr"  "$(jsd_calls)" "1"
check "retries<=1: sleep не вызван"   "$(sleep_calls)" "0"

# === счётчик попыток: retries_download>1 -> повтор с задержкой retry_delay_download ===
# Оба источника опрашиваются в каждой retry-итерации (а не последовательно по
# фазам) - именно это тут и фиксируется: 3 попытки -> по 3 вызова на каждый
# источник и 2 паузы (после 1-й и 2-й попытки), не после последней.
frt_reset 3 7
printf '\n\n\n' > "$WORK/api_queue"
printf '\n\n{"versions":["j-final"]}\n' > "$WORK/jsd_queue"
fetch_release_tags "$FAKE_API_URL" "$FAKE_JSD_URL" 10 >/dev/null 2>&1
check "retries>1: 3 вызова API"              "$(api_calls)" "3"
check "retries>1: 3 вызова jsDelivr"         "$(jsd_calls)" "3"
check "retries>1: 2 паузы (не после последней)" "$(sleep_calls)" "2"
check "retries>1: задержка = retry_delay_download" "$(sort -u "$WORK/sleep_log" | tr -d '\n')" "7"
check "retries>1: в итоге получен jsDelivr"  "$USE_JSDELIVR" "true"
check "retries>1: тег с последней попытки"   "$(printf '%s\n' "$RELEASE_TAGS" | grep -c '^j-final$')" "1"

rm -rf "$WORK"
printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
