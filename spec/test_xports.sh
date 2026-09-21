#!/bin/sh
# Тесты разбора вывода netstat в tests_ports_client (scripts/_xkeen/05_tests/02_tests_xports.sh)
#
# Баг, ради которого написан: ветка "обычный IPv6 [addr]:port" использовала
# `grep -q '\\]:'` (ДВА backslash в одинарных кавычках) — в grep BRE это
# буквально "литеральный backslash + ]:", строка вида '[fe80::1]:7893' под
# этот паттерн никогда не подходила и проваливалась в IPv4-ветку
# (cut -d':' -f1/-f2), давая gateway='[fe80' port=''. Консолидация разбора
# адреса в единый awk-вызов устраняет баг заодно с лишними форками.

# Модуль целиком не подключаем: он завязан на pidof/netstat живой системы.
# Берём ровно функцию tests_ports_client, как test_strip_json.sh берёт
# strip_json_comments — так тест бьёт по реальному коду, а не по копии.
extract() {
    awk '/^tests_ports_client\(\) \{/,/^\}/' "$1"
}
eval "$(extract /repo/scripts/_xkeen/05_tests/02_tests_xports.sh)"

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else
        printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1))
    fi
}

check "функция вообще найдена" "$([ -n "$(extract /repo/scripts/_xkeen/05_tests/02_tests_xports.sh)" ] && echo да || echo нет)" "да"

# Цветовые переменные функция ожидает как окружение (см. 01_info_variable.sh) —
# в тесте делаем их пустыми, чтобы сравнивать только текст.
green=; reset=; italic=; red=

# pidof подставной: xray "запущен" всегда, name_client всегда "xray"
pidof() { [ "$1" = "xray" ]; }

# netstat подставной: один снимок сокетов с пятью форматами адреса —
# 0.0.0.0:port (IPv4), :::port (IPv4-as-::), [::]:port, [addr]:port не-::
# (бывший баг) и обычный addr:port (IPv4, не loopback, UDP).
netstat() {
    cat <<'EOF'
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      1234/xray
tcp6       0      0 :::8080                 :::*                    LISTEN      1234/xray
tcp6       0      0 [::]:9090               [::]:*                  LISTEN      1234/xray
tcp6       0      0 [fe80::1]:7893          [::]:*                  LISTEN      1234/xray
udp        0      0 192.168.1.50:1080       0.0.0.0:*                           1234/xray
EOF
}

out=$(tests_ports_client)

gateways=$(printf '%s\n' "$out" | grep 'Шлюз' | sed 's/^ *Шлюз //')
ports=$(printf '%s\n' "$out" | grep 'Порт' | sed 's/^ *Порт //')
protocols=$(printf '%s\n' "$out" | grep 'Протокол' | sed 's/^ *Протокол //')

check "netstat вызывается ровно один раз" \
    "$(grep -c 'netstat -ltunp' /repo/scripts/_xkeen/05_tests/02_tests_xports.sh)" "1"

check "формат 1: 0.0.0.0:port — шлюз" "$(printf '%s\n' "$gateways" | sed -n '1p')" "0.0.0.0"
check "формат 1: 0.0.0.0:port — порт"  "$(printf '%s\n' "$ports"    | sed -n '1p')" "22"
check "формат 1: 0.0.0.0:port — протокол" "$(printf '%s\n' "$protocols" | sed -n '1p')" "TCP"

check "формат 2: :::port — шлюз" "$(printf '%s\n' "$gateways" | sed -n '2p')" "0.0.0.0"
check "формат 2: :::port — порт"  "$(printf '%s\n' "$ports"    | sed -n '2p')" "8080"
check "формат 2: :::port — протокол" "$(printf '%s\n' "$protocols" | sed -n '2p')" "TCP"

check "формат 3: [::]:port — шлюз" "$(printf '%s\n' "$gateways" | sed -n '3p')" "[::]"
check "формат 3: [::]:port — порт"  "$(printf '%s\n' "$ports"    | sed -n '3p')" "9090"
check "формат 3: [::]:port — протокол" "$(printf '%s\n' "$protocols" | sed -n '3p')" "TCP"

# Регрессия: бывший баг с двойным backslash в grep '\\]:'
check "формат 4 (regression): [addr]:port — шлюз" "$(printf '%s\n' "$gateways" | sed -n '4p')" "[fe80::1]"
check "формат 4 (regression): [addr]:port — порт"  "$(printf '%s\n' "$ports"    | sed -n '4p')" "7893"
check "формат 4 (regression): [addr]:port — протокол" "$(printf '%s\n' "$protocols" | sed -n '4p')" "TCP"

check "формат 5: addr:port (IPv4, не loopback) — шлюз" "$(printf '%s\n' "$gateways" | sed -n '5p')" "192.168.1.50"
check "формат 5: addr:port (IPv4, не loopback) — порт"  "$(printf '%s\n' "$ports"    | sed -n '5p')" "1080"
check "формат 5: addr:port (IPv4, не loopback) — протокол" "$(printf '%s\n' "$protocols" | sed -n '5p')" "UDP"

printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
