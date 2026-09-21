#!/bin/sh
# TOCTOU-гонка при реклейме протухшего lock: _acquire_coldstart_guard и
# _acquire_proxy_mutex.
#
# Баг, ради которого написан: обе функции при мёртвом pid делают
# rm -rf lock.d; mkdir lock.d; printf pid; return 0 одной незащищённой
# последовательностью. Если между чтением протухшего pid и rm -rf другой
# процесс успел сделать свой mkdir+printf (легитимный reclaim), текущий
# процесс своим rm -rf сносит ЧУЖОЙ свежесозданный лок и создаёт свой
# поверх — оба получают rc=0 (двойной coldstart / двойной proxy_start).

# Модуль целиком не подключаем (он ходит в RCI роутера): берём ровно
# проверяемые функции из реального файла — тест бьёт по реальному коду.
SRC=/repo/scripts/_xkeen/02_install/07_install_register/04_register_init.sh

extract() {
    awk "/^${1}\\(\\) \\{/,/^\\}/" "$SRC"
}

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else
        printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1))
    fi
}

# Эмулирует двух конкурентов, увидевших один и тот же протухший pid: строит
# из реального тела функции две копии под разными именами (slow/fast) и
# инжектирует sleep сразу после строки чтения протухшего pid — это открывает
# окно гонки ровно там, где до патча нет re-check перед rm -rf. slow уходит
# в sleep, за это время fast успевает полностью завершить reclaim, затем
# slow просыпается и пытается снести (уже чужой) каталог.
#
# $1 = имя функции в файле, $2 = имя lock-каталога (относительно rundir),
# $3 = имя переменной, в которую функция читает протухший pid (_gpid/_mpid)
race_double_acquire_count() {
    fn="$1"; lockdir="$2"; readvar="$3"; n="$4"

    body=$(extract "$fn")
    [ -n "$body" ] || { echo "функция $fn не найдена в $SRC" >&2; echo -1; return; }

    slow_body=$(printf '%s\n' "$body" \
        | sed "1s/^${fn}/slow_${fn}/" \
        | sed "/^    ${readvar}=\\\$(cat /a\\
        sleep 1")
    fast_body=$(printf '%s\n' "$body" | sed "1s/^${fn}/fast_${fn}/")

    eval "$slow_body"
    eval "$fast_body"

    double=0
    i=0
    while [ "$i" -lt "$n" ]; do
        i=$((i + 1))
        xkeen_rundir=$(mktemp -d)
        mkdir "$xkeen_rundir/$lockdir"
        # заведомо мёртвый pid — оба конкурента видят один и тот же
        echo 999999 > "$xkeen_rundir/$lockdir/pid"
        export xkeen_rundir

        ( eval "slow_${fn}"; echo $? > "$xkeen_rundir/slow.rc" ) &
        sleep 0.3
        ( eval "fast_${fn}"; echo $? > "$xkeen_rundir/fast.rc" )
        wait

        wins=0
        [ "$(cat "$xkeen_rundir/slow.rc")" = 0 ] && wins=$((wins + 1))
        [ "$(cat "$xkeen_rundir/fast.rc")" = 0 ] && wins=$((wins + 1))
        [ "$wins" -gt 1 ] && double=$((double + 1))

        rm -rf "$xkeen_rundir"
    done
    echo "$double"
}

N=10

d=$(race_double_acquire_count _acquire_coldstart_guard coldstart.lock.d _gpid "$N")
check "coldstart guard: конкурентный reclaim без двойного захвата" "$d/$N" "0/$N"

d=$(race_double_acquire_count _acquire_proxy_mutex proxy.mutex.d _mpid "$N")
check "proxy mutex: конкурентный reclaim без двойного захвата" "$d/$N" "0/$N"

# --- коды возврата не должны были измениться (fail-fast сохранён) ---
eval "$(extract _acquire_proxy_mutex)"
xkeen_rundir=$(mktemp -d)

_acquire_proxy_mutex >/dev/null 2>&1
check "mutex: свежий захват rc=0" "$?" "0"

_acquire_proxy_mutex >/dev/null 2>&1
check "mutex: повторный вызов тем же \$\$ (re-entrant) rc=2" "$?" "2"

sleep 60 &
livepid=$!
rm -rf "$xkeen_rundir/proxy.mutex.d"
mkdir "$xkeen_rundir/proxy.mutex.d"
echo "$livepid" > "$xkeen_rundir/proxy.mutex.d/pid"
_acquire_proxy_mutex >/dev/null 2>&1
check "mutex: живой конкурент — мгновенный отказ rc=1" "$?" "1"
kill "$livepid" 2>/dev/null

rm -rf "$xkeen_rundir/proxy.mutex.d"
mkdir "$xkeen_rundir/proxy.mutex.d"
echo 999999 > "$xkeen_rundir/proxy.mutex.d/pid"
_acquire_proxy_mutex >/dev/null 2>&1
check "mutex: протухший pid без гонки — обычный reclaim rc=0" "$?" "0"

rm -rf "$xkeen_rundir"

printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
