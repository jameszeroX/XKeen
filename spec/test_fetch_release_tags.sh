#!/bin/sh
# Тесты fetch_release_tags: ретраи, fallback GitHub API -> jsDelivr, фильтр
# версионных тегов (_frt_tag_re='^v?[0-9]+(\.[0-9]+)*$'), кап head -n 8.
# Функция гейтит, какие версии Xray/Mihomo/XKeen видит пользователь при
# установке (01_downloaders_xray.sh, 01_downloaders_mihomo.sh).
#
# Фильтр применяется к ОБОИМ источникам (GitHub API и jsDelivr), поэтому все
# теги в фикстурах, которые должны дойти до RELEASE_TAGS, обязаны быть
# версионными (v1, 1.2.3, v2.0). Теги вроде j1, latest, nightly, v2-beta и
# *-Prerelease-Alpha отсекаются. Важно: если в фикстуре fallback/retry
# оказался невалидный тег, оба источника окажутся пусты, и fetch_release_tags
# вызовет exit 1 - а вне сабшелла это завершит весь тестовый скрипт без итога.
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

# Число непустых строк в RELEASE_TAGS (пустая переменная -> 0, а не 1, как
# у wc -l над printf '%s\n').
tags_count() { printf '%s\n' "$RELEASE_TAGS" | grep -c .; }
# Сколько раз тег (точное совпадение, фиксированная строка) есть в RELEASE_TAGS.
tag_has() { printf '%s\n' "$RELEASE_TAGS" | grep -cxF "$1"; }

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

# === успешный путь: GitHub API, фильтр версионных тегов + кап head -n 8 ===
# 10 валидных тегов (v1..v10) + невалидные: 'v3.5-Prerelease-Alpha' и
# 'latest' стоят внутри первых 8 позиций сырого списка - если фильтр не
# отработает, они попадут в head -n 8 и сдвинут v7/v8 за кап. Так мутация,
# убирающая `grep -E "$_frt_tag_re"` из продакшн-кода, реально ломает
# проверки "v8 присутствует" и "невалидные отфильтрованы", а не проходит
# незамеченной (при невалидных исключительно в хвосте их и так обрезает
# head -n 8 независимо от фильтра). 'v11-prerelease-alpha' (другой регистр),
# 'nightly' и 'v2-beta' стоят в конце и проверяют сам фильтр без влияния
# на кап.
frt_reset 1 2
printf '[{"tag_name":"v1"},{"tag_name":"v2"},{"tag_name":"v3"},{"tag_name":"v3.5-Prerelease-Alpha"},{"tag_name":"latest"},{"tag_name":"v4"},{"tag_name":"v5"},{"tag_name":"v6"},{"tag_name":"v7"},{"tag_name":"v8"},{"tag_name":"v9"},{"tag_name":"v10"},{"tag_name":"v11-prerelease-alpha"},{"tag_name":"nightly"},{"tag_name":"v2-beta"}]\n' > "$WORK/api_queue"
fetch_release_tags "$FAKE_API_URL" "$FAKE_JSD_URL" 10 >/dev/null 2>&1
check "успех API: 8 строк (кап head -n 8)"        "$(tags_count)" "8"
check "успех API: v1 присутствует"                "$(tag_has v1)" "1"
check "успех API: v8 присутствует (невалидные не заняли его место в капе)" "$(tag_has v8)" "1"
check "успех API: v9 срезан капом"                "$(tag_has v9)" "0"
check "успех API: Prerelease-Alpha отфильтрован"  "$(printf '%s\n' "$RELEASE_TAGS" | grep -ic 'prerelease-alpha')" "0"
check "успех API: latest отфильтрован"            "$(tag_has latest)" "0"
check "успех API: nightly отфильтрован"           "$(tag_has nightly)" "0"
check "успех API: v2-beta отфильтрован"           "$(tag_has v2-beta)" "0"
check "успех API: USE_JSDELIVR пуст"              "$USE_JSDELIVR" ""
check "успех API: jsDelivr не вызывался"          "$(jsd_calls)" "0"
check "успех API: ровно 1 вызов API"              "$(api_calls)" "1"

# === фильтр версионных тегов: формы, которые он должен пропускать/резать ===
# Пропускаются: с префиксом v и без, из одной или нескольких групп цифр.
# Режутся: суффиксы (-rc1, -beta), нечисловые имена, дата с дефисами,
# лишний префикс, пустые сегменты (1..2, 1.2.), тег из одних букв.
frt_reset 1 2
printf '[{"tag_name":"1.2.3"},{"tag_name":"v2.0"},{"tag_name":"latest"},{"tag_name":"v1.0-rc1"},{"tag_name":"nightly"},{"tag_name":"2024-01-01"},{"tag_name":"vv3"},{"tag_name":"1..2"},{"tag_name":"1.2."},{"tag_name":"v"},{"tag_name":"10"}]\n' > "$WORK/api_queue"
fetch_release_tags "$FAKE_API_URL" "$FAKE_JSD_URL" 10 >/dev/null 2>&1
check "фильтр: остались ровно 3 версионных тега" "$(tags_count)" "3"
check "фильтр: 1.2.3 (без v) пропущен"           "$(tag_has 1.2.3)" "1"
check "фильтр: v2.0 пропущен"                    "$(tag_has v2.0)" "1"
check "фильтр: 10 (одно число) пропущено"        "$(tag_has 10)" "1"
check "фильтр: v1.0-rc1 отрезан"                 "$(tag_has v1.0-rc1)" "0"
check "фильтр: 2024-01-01 отрезан"               "$(tag_has 2024-01-01)" "0"
check "фильтр: vv3 отрезан"                      "$(tag_has vv3)" "0"
check "фильтр: 1..2 отрезан"                     "$(tag_has 1..2)" "0"
check "фильтр: 1.2. отрезан"                     "$(tag_has 1.2.)" "0"
check "фильтр: одиночный v отрезан"              "$(tag_has v)" "0"
check "фильтр: USE_JSDELIVR пуст (API дал теги)" "$USE_JSDELIVR" ""
check "фильтр: jsDelivr не вызывался"            "$(jsd_calls)" "0"

# === fallback: GitHub API пуст -> jsDelivr ===
# В ответе jsDelivr есть невалидные теги: они должны быть отфильтрованы и
# на этой ветке тоже (фильтр стоит на обоих источниках).
frt_reset 1 2
printf '[]\n' > "$WORK/api_queue"
printf '{"versions":["1.0.1","latest","1.0.2","1.0.3-beta","1.0.3"]}\n' > "$WORK/jsd_queue"
fetch_release_tags "$FAKE_API_URL" "$FAKE_JSD_URL" 10 >/dev/null 2>&1
check "fallback: RELEASE_TAGS непуст"      "$([ -n "$RELEASE_TAGS" ] && echo yes || echo no)" "yes"
check "fallback: 1.0.1 присутствует"       "$(tag_has 1.0.1)" "1"
check "fallback: 1.0.3 присутствует"       "$(tag_has 1.0.3)" "1"
check "fallback: 3 валидных тега"          "$(tags_count)" "3"
check "fallback: latest отфильтрован (jsDelivr)"     "$(tag_has latest)" "0"
check "fallback: 1.0.3-beta отфильтрован (jsDelivr)" "$(tag_has 1.0.3-beta)" "0"
check "fallback: USE_JSDELIVR=true"        "$USE_JSDELIVR" "true"
check "fallback: 1 вызов API"              "$(api_calls)" "1"
check "fallback: 1 вызов jsDelivr"         "$(jsd_calls)" "1"

# === fallback: API отдал ТОЛЬКО невалидные теги -> тоже переход на jsDelivr ===
# Для функции это неотличимо от пустого ответа: после фильтра список пуст.
frt_reset 1 2
printf '[{"tag_name":"latest"},{"tag_name":"nightly"},{"tag_name":"v1-Prerelease-Alpha"}]\n' > "$WORK/api_queue"
printf '{"versions":["3.1.4"]}\n' > "$WORK/jsd_queue"
fetch_release_tags "$FAKE_API_URL" "$FAKE_JSD_URL" 10 >/dev/null 2>&1
check "API только невалидные: fallback на jsDelivr" "$USE_JSDELIVR" "true"
check "API только невалидные: тег из jsDelivr"      "$(tag_has 3.1.4)" "1"
check "API только невалидные: невалидные не просочились" "$(tags_count)" "1"

# === полный провал: оба источника пусты -> exit 1 (в сабшелле) ===
frt_reset 1 2
printf '\n' > "$WORK/api_queue"
printf '\n' > "$WORK/jsd_queue"
out=$( (fetch_release_tags "$FAKE_API_URL" "$FAKE_JSD_URL" 10) 2>&1 ); rc=$?
check "полный провал: exit 1"                  "$rc" "1"
check "полный провал: сообщение об ошибке"     "$(printf '%s' "$out" | grep -c 'Не удалось получить список релизов')" "1"

# === полный провал: оба источника отдали только невалидные теги -> exit 1 ===
# Фильтр не должен пропускать мусор "за неимением лучшего".
frt_reset 1 2
printf '[{"tag_name":"latest"},{"tag_name":"nightly"}]\n' > "$WORK/api_queue"
printf '{"versions":["latest","j1","1.0-beta"]}\n' > "$WORK/jsd_queue"
out=$( (fetch_release_tags "$FAKE_API_URL" "$FAKE_JSD_URL" 10) 2>&1 ); rc=$?
check "только невалидные везде: exit 1"               "$rc" "1"
check "только невалидные везде: сообщение об ошибке"  "$(printf '%s' "$out" | grep -c 'Не удалось получить список релизов')" "1"

# === счётчик попыток: retries_download<=1 -> ровно 1 вызов на источник ===
frt_reset 1 2
printf '\n' > "$WORK/api_queue"
printf '{"versions":["1.0.0"]}\n' > "$WORK/jsd_queue"
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
printf '\n\n{"versions":["9.9.9"]}\n' > "$WORK/jsd_queue"
fetch_release_tags "$FAKE_API_URL" "$FAKE_JSD_URL" 10 >/dev/null 2>&1
check "retries>1: 3 вызова API"              "$(api_calls)" "3"
check "retries>1: 3 вызова jsDelivr"         "$(jsd_calls)" "3"
check "retries>1: 2 паузы (не после последней)" "$(sleep_calls)" "2"
check "retries>1: задержка = retry_delay_download" "$(sort -u "$WORK/sleep_log" | tr -d '\n')" "7"
check "retries>1: в итоге получен jsDelivr"  "$USE_JSDELIVR" "true"
check "retries>1: тег с последней попытки"   "$(tag_has 9.9.9)" "1"

rm -rf "$WORK"
printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
