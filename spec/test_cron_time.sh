#!/bin/sh
# Тесты форматирования часа/минуты автообновления геофайлов в cron-статусе.
#
# Баг, ради которого написаны: `printf "%02d" "$hour"` в busybox ash разбирает
# число через strtol(base=0), а там ведущий ноль включает восьмеричный режим —
# "08"/"09" не десятичные восьмеричные цифры, поэтому printf валится с
# "invalid number '08'" в stderr и выводит "00" вместо "08". Проверено живьём
# на KN-1012 при настройке автообновления на 8 или 9 часов/минут.

# Модуль целиком не подключаем: он тянет остальной cron_status.sh с
# зависимостями от переменных wizard'а. Берём ровно проверяемую функцию.
extract() {
    awk '/^format_cron_time\(\) \{/,/^\}/' "$1"
}
eval "$(extract /repo/scripts/_xkeen/04_tools/05_tools_choice/05_choice_cron/01_cron_status.sh)"

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else
        printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1))
    fi
}

# format_cron_time принимает строку crontab "minute hour * * dow"
# --- часы: пороговые значения 0,5,8,9,10,23 ---
check "час 0"  "$(format_cron_time '0 0 * * *')"  'Ежедневно в 00:00'
check "час 5"  "$(format_cron_time '0 5 * * *')"  'Ежедневно в 05:00'
check "час 8"  "$(format_cron_time '0 8 * * *')"  'Ежедневно в 08:00'
check "час 9"  "$(format_cron_time '0 9 * * *')"  'Ежедневно в 09:00'
check "час 10" "$(format_cron_time '0 10 * * *')" 'Ежедневно в 10:00'
check "час 23" "$(format_cron_time '0 23 * * *')" 'Ежедневно в 23:00'

# --- минуты: пороговые значения 0,5,8,9,10,59 ---
check "минута 0"  "$(format_cron_time '0 12 * * *')"  'Ежедневно в 12:00'
check "минута 5"  "$(format_cron_time '5 12 * * *')"  'Ежедневно в 12:05'
check "минута 8"  "$(format_cron_time '8 12 * * *')"  'Ежедневно в 12:08'
check "минута 9"  "$(format_cron_time '9 12 * * *')"  'Ежедневно в 12:09'
check "минута 10" "$(format_cron_time '10 12 * * *')" 'Ежедневно в 12:10'
check "минута 59" "$(format_cron_time '59 12 * * *')" 'Ежедневно в 12:59'

# --- регрессия: 08/09 не должны давать "00" и не должны сыпать stderr ---
out=$(format_cron_time '8 8 * * *' 2>&1 1>/dev/null)
check "08 час + 08 минута: stderr пуст" "$out" ''
check "08 час + 08 минута: без урезания до 00" "$(format_cron_time '8 8 * * *')" 'Ежедневно в 08:08'

printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
