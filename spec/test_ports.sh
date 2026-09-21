#!/bin/sh
# Тесты диспетчеризации -ap/-dp/-ape/-dpe в scripts/xkeen
#
# Баг, ради которого написаны (C03): `shift; <func> "$@"; shift $#` в этих
# 4 case-ветках поглощал ВСЕ оставшиеся позиционные параметры, включая
# следующий флаг командной строки (`xkeen -ap 8080 -status` терял -status
# бесследно). Фикс — сбор портов в цикле до первого токена "-*" + `continue`,
# чтобы не отдавать управление в общий trailing `shift` внешнего while.
#
# Реальные case-ветки извлекаются из scripts/xkeen через awk (как в
# test_strip_json.sh) и прогоняются в собственном мини-диспетчере, который
# воспроизводит структуру внешнего while-цикла оригинала (case; esac; shift;
# done) — так тест бьёт по продовому коду, а не по переписанной копии.
# Функции работы с портами (01_tools_ports.sh) подменены заглушками: их
# внутренняя логика не входит в scope этой ветки и не меняется.

extract() {
    awk '/^        -di\)/{exit} /^        -ap\)/{f=1} f{print}' "$1"
}
branches=$(extract /repo/scripts/xkeen)
[ -n "$branches" ] || { echo "FAIL не удалось извлечь case-ветки -ap/-dp/-ape/-dpe из scripts/xkeen"; exit 1; }

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else
        printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1))
    fi
}

# Мини-диспетчер: та же структура, что и внешний while в scripts/xkeen
# (case "$1" in ... esac; shift; done), с реальными извлечёнными ветками
# внутри и заглушками вместо add/del_ports_donor|exclude, add_chmod_init,
# is_proxy_running.
run_dispatch() {
    log=""
    add_ports_donor()   { log="${log}ADD_DONOR:[$*] "; }
    del_ports_donor()   { log="${log}DEL_DONOR:[$*] "; }
    add_ports_exclude() { log="${log}ADD_EXCL:[$*] "; }
    del_ports_exclude() { log="${log}DEL_EXCL:[$*] "; }
    get_ports_donor()   { :; }
    get_ports_exclude() { :; }
    add_chmod_init()    { :; }
    is_proxy_running()  { return 1; }
    sleep()             { :; }
    initd_file=""

    eval "
    while [ \$# -gt 0 ]; do
        case \"\$1\" in
$branches
            *)
                log=\"\${log}REACHED:[\$1] \"
            ;;
        esac
        shift
    done
    "
    remaining=$#
    printf '%s|rest=%s' "$log" "$remaining"
}

# --- multi-port add без хвостового флага (регрессия double-shift, c972fd2) ---
res=$(run_dispatch -ap 80 443 8080)
check "multi-port add: все 3 порта одним вызовом" "$res" "ADD_DONOR:[80 443 8080] |rest=0"

res=$(run_dispatch -dp 80 443 8080)
check "multi-port del: все 3 порта одним вызовом" "$res" "DEL_DONOR:[80 443 8080] |rest=0"

# --- port + следующий флаг (сам C03) ---
res=$(run_dispatch -ap 8080 -status)
check "C03: -ap 8080 -status — оба эффекта" "$res" "ADD_DONOR:[8080] REACHED:[-status] |rest=0"

res=$(run_dispatch -dp 8080 -status)
check "C03: -dp 8080 -status — оба эффекта" "$res" "DEL_DONOR:[8080] REACHED:[-status] |rest=0"

res=$(run_dispatch -ape 8080 -status)
check "C03: -ape 8080 -status — оба эффекта" "$res" "ADD_EXCL:[8080] REACHED:[-status] |rest=0"

res=$(run_dispatch -dpe 8080 -status)
check "C03: -dpe 8080 -status — оба эффекта" "$res" "DEL_EXCL:[8080] REACHED:[-status] |rest=0"

# --- флаг сразу без портов (пустой список + следующий флаг не теряется) ---
res=$(run_dispatch -ap -status)
check "-ap -status: пустой список, -status не теряется" "$res" "ADD_DONOR:[] REACHED:[-status] |rest=0"

res=$(run_dispatch -dp -status)
check "-dp -status: пустой список, -status не теряется" "$res" "DEL_DONOR:[] REACHED:[-status] |rest=0"

# --- пустой список в конце аргументов (без падения на завершающем shift) ---
res=$(run_dispatch -ap)
check "-ap без портов, конец аргументов" "$res" "ADD_DONOR:[] |rest=0"

res=$(run_dispatch -dp)
check "-dp без портов, конец аргументов" "$res" "DEL_DONOR:[] |rest=0"

res=$(run_dispatch -ape)
check "-ape без портов, конец аргументов" "$res" "ADD_EXCL:[] |rest=0"

res=$(run_dispatch -dpe)
check "-dpe без портов, конец аргументов" "$res" "DEL_EXCL:[] |rest=0"

printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
