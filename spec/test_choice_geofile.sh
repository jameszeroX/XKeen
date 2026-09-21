#!/bin/sh
# Тесты choice_geodata(): защита от конфликтующих multi-select пунктов меню.
#
# Баг: пункт "6. Удалить установленные" и пункты "1-5. Установить/обновить",
# а также "0. Пропустить" и любой другой пункт, обрабатывались в одном
# for-цикле независимо друг от друга — ни одна ветка case не сбрасывала
# флаги другой. Ввод "1 6" сначала взводил install_*/update_*, затем "6"
# взводил choice_delete_*_select — scripts/xkeen вызывает choice_geosite;
# delete_geosite; install_geosite в фиксированном порядке, так что удаление
# тут же перекрывалось скрытой переустановкой. Ввод "1 0" взводил install_*,
# затем "0" печатал "Выполнен пропуск" и делал return, минуя сброс уже
# взведённых install_*/update_* — те всё равно отрабатывали позже, хотя
# пользователь только что увидел сообщение о пропуске.
#
# Патч добавляет pre-scan-валидацию перед циклом обработки: конфликтующие
# комбинации отклоняются с сообщением и повторным запросом ввода (тот же
# идиом continue/while true, что уже используется в файле для invalid_choice).

yellow=""; red=""; green=""; italic=""; reset=""
input_concordance_list() { return 1; }

GEOFILE="${GEOFILE:-/repo/scripts/_xkeen/04_tools/05_tools_choice/03_choice_geofile.sh}"
. "$GEOFILE"

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else
        printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1))
    fi
}

# Состояние: Re:filter и ZKeen уже установлены и обновляемы, v2fly отсутствует
# — has_missing_bases=true, has_updatable_bases=true. Живой сценарий, на
# котором баг подтверждён.
reset_state() {
    update_refilter_geosite=true
    update_v2fly_geosite=false
    update_zkeen_geosite=true
}

# $1 = ввод (одна или несколько строк, разделённых переводом строки)
#
# Ввод передаётся через `< "$INPUT_FILE"`, а не через пайп: пайп запускает
# choice_geosite в отдельном subshell, и все её eval-присвоенные флаги
# (install_*_geosite, update_*_geosite) теряются при выходе из функции —
# для тестов, которые сверяют итоговые флаги, это критично.
INPUT_FILE="/tmp/test_choice_geofile_input.$$"
run_choice() {
    reset_state
    printf '%s\n' "$1" > "$INPUT_FILE"
    choice_geosite < "$INPUT_FILE" 2>&1
}

# --- конфликт "6" (удалить) с любым из "1".."5" (установить/обновить) ---
for combo in "1 6" "2 6" "3 6" "4 6" "5 6"; do
    out=$(run_choice "$combo
0")
    check "конфликт '$combo': сообщение об ошибке"      "$(printf '%s' "$out" | grep -c 'нельзя выбирать вместе')" "1"
    check "конфликт '$combo': меню перезапрошено дважды" "$(printf '%s' "$out" | grep -c 'Выберите номер или номера действий')" "2"
    check "конфликт '$combo': install не проскочил"      "$(printf '%s' "$out" | grep -c 'Устанавливаются следующие')" "0"
    check "конфликт '$combo': update не проскочил"       "$(printf '%s' "$out" | grep -c 'Обновляются следующие')" "0"
    check "конфликт '$combo': delete не проскочил"       "$(printf '%s' "$out" | grep -c 'Удаляются следующие')" "0"
done

# --- конфликт "0" (пропустить) с чем угодно ---
for combo in "1 0" "6 0" "0 3"; do
    out=$(run_choice "$combo
0")
    check "конфликт '$combo': сообщение об ошибке"      "$(printf '%s' "$out" | grep -c 'нельзя выбирать вместе')" "1"
    check "конфликт '$combo': меню перезапрошено дважды" "$(printf '%s' "$out" | grep -c 'Выберите номер или номера действий')" "2"
done

# --- одиночные варианты работают как до патча (без ошибки о конфликте) ---
out=$(run_choice "0")
check "'0' в одиночку: пропуск без ошибки"      "$(printf '%s' "$out" | grep -c 'Выполнен пропуск')" "1"
check "'0' в одиночку: без ложного конфликта"   "$(printf '%s' "$out" | grep -c 'нельзя выбирать вместе')" "0"

out=$(run_choice "6")
check "'6' в одиночку: удаление без ошибки"     "$(printf '%s' "$out" | grep -c 'Удаляются следующие')" "1"
check "'6' в одиночку: без ложного конфликта"   "$(printf '%s' "$out" | grep -c 'нельзя выбирать вместе')" "0"

reset_state
run_choice "1" >/dev/null 2>&1
check "'1' в одиночку: install_refilter"  "$install_refilter_geosite" "false"
check "'1' в одиночку: update_refilter"   "$update_refilter_geosite"  "true"
check "'1' в одиночку: install_v2fly"     "$install_v2fly_geosite"    "true"
check "'1' в одиночку: update_zkeen"      "$update_zkeen_geosite"     "true"

# --- легитимные непересекающиеся multi-select работают побитово как раньше ---
run_choice "3 4 5" >/dev/null 2>&1
check "'3 4 5': update_refilter" "$update_refilter_geosite" "true"
check "'3 4 5': install_v2fly"   "$install_v2fly_geosite"   "true"
check "'3 4 5': update_zkeen"    "$update_zkeen_geosite"    "true"
check "'3 4 5': install_refilter не взведён" "$install_refilter_geosite" "false"
check "'3 4 5': update_v2fly не взведён"     "$update_v2fly_geosite"     "false"

run_choice "1 2" >/dev/null 2>&1
check "'1 2': update_refilter" "$update_refilter_geosite" "true"
check "'1 2': install_v2fly"   "$install_v2fly_geosite"   "true"
check "'1 2': update_zkeen"    "$update_zkeen_geosite"    "true"

rm -f "$INPUT_FILE"

printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
