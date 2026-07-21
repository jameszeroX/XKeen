# Ядро балансировки по фактической скорости.
#
# Замер идёт через probe http-proxy inbound Xray и временное routing-правило,
# добавляемое в рантайм (adrules) — трафик curl уходит через КОНКРЕТНЫЙ
# outbound, боевой роутинг не трогается. Выбор применяется через
# RoutingService.OverrideBalancerTarget (bo) — без перезаписи конфига и без
# рестарта. Оба механизма проверены на живом роутере (Xray 26.6.27).

# Запись строки в лог замеров с меткой времени. Лог усечён до последних строк
# отдельно (sb_log_trim), чтобы не расти без предела на tmpfs.
sb_log() {
    [ -n "$sb_log_file" ] || return 0
    printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$sb_log_file" 2>/dev/null
}

# Оставить в логе только последние 200 строк.
sb_log_trim() {
    [ -f "$sb_log_file" ] || return 0
    tail -n 200 "$sb_log_file" > "$sb_log_file.tmp" 2>/dev/null && mv "$sb_log_file.tmp" "$sb_log_file" 2>/dev/null
}

# Список нод балансировщика: outbound-теги, попадающие под его selector.
# Xray сопоставляет selector с тегом по подстроке, поэтому здесь тоже подстрока.
# Результат — в глобальную sb_nodes (через субшелл вернуть нельзя). Возврат 1,
# если балансировщик или ноды не найдены.
sb_node_list() {
    sb_nodes=""
    [ -f "$sb_routing_file" ] || return 1
    [ -f "$sb_outbounds_file" ] || return 1

    local selectors all tag sel
    selectors=$(strip_json_comments "$sb_routing_file" \
        | jq -r --arg b "$sb_balancer" '.routing.balancers[]? | select(.tag==$b) | .selector[]?' 2>/dev/null)
    [ -n "$selectors" ] || return 1

    all=$(strip_json_comments "$sb_outbounds_file" \
        | jq -r '.outbounds[]? | .tag // empty' 2>/dev/null)
    [ -n "$all" ] || return 1

    for tag in $all; do
        for sel in $selectors; do
            case "$tag" in
                *"$sel"*) sb_nodes="$sb_nodes $tag"; break ;;
            esac
        done
    done

    sb_nodes="${sb_nodes# }"   # срезать единственный ведущий пробел
    [ -n "$sb_nodes" ]
}

# Замер одной ноды. Печатает "КБ/с КОД" одной строкой: скорость (0 при отказе)
# и код завершения — HTTP-код curl либо "adrules", если не удалось выставить
# правило. Оба значения идут через stdout, а не через глобаль: вызов через
# $() — субшелл, и присваивание глобали из него не пережило бы возврат.
# Целое, а не дробь: гистерезис считается целочисленной арифметикой sh.
# curl здесь прямой, а не curl_with_timeout: нужны -x (proxy) и -w (подсчёт
# байт), которых обёртка не даёт. Правило снимается всегда — и до, и после,
# чтобы прошлый замер не протёк в боевой роутинг.
#
# Размер test_url важен: endpoint Cloudflare __down отдаёт 403 на запрос
# больше ~50 МБ, поэтому по умолчанию берётся 50 МБ. Для окна замера этого
# достаточно — медленная нода за max_time его не докачает, а быстрая
# докачает, и в обоих случаях size/time даёт скорость.
sb_measure_node() {
    local node size time code
    node="$1"

    printf '{"routing":{"rules":[{"ruleTag":"%s","type":"field","inboundTag":["%s"],"outboundTag":"%s"}]}}' \
        "$sb_rule_tag" "$sb_probe_intag" "$node" > "$sb_rule_tmp" 2>/dev/null

    xray api rmrules -s "$sb_api_addr" "$sb_rule_tag" >/dev/null 2>&1
    if ! xray api adrules -s "$sb_api_addr" -append "$sb_rule_tmp" >/dev/null 2>&1; then
        echo "0 adrules"; return 1
    fi

    # curl печатает -w всегда, даже при отказе (код 000, размер 0) и при
    # таймауте (частичный размер, реальный код) — фолбэк ||echo не нужен и
    # вреден: у -w нет завершающего пробела, и приписанное "0 0 000" слиплось
    # бы с кодом ("200"+"0 0 000" -> "2000"), ломая разбор для медленных нод,
    # которые не докачивают файл за max_time.
    # разбиение по пробелам здесь намеренное: -w печатает три поля через пробел
    # shellcheck disable=SC2046
    set -- $(curl -x "http://$sb_probe_addr" -o /dev/null -sS \
        --max-time "$sb_maxtime" -w '%{size_download} %{time_total} %{http_code}' \
        "$sb_test_url" 2>/dev/null)
    size="${1:-0}"; time="${2:-0}"; code="${3:-000}"

    xray api rmrules -s "$sb_api_addr" "$sb_rule_tag" >/dev/null 2>&1
    rm -f "$sb_rule_tmp" 2>/dev/null

    # curl при таймауте (max_time) выходит с ошибкой, но код и объём уже отдал:
    # частичная загрузка с кодом 200 — валидный замер сустейнед-скорости.
    [ "$code" = "200" ] || { echo "0 $code"; return 1; }
    echo "$size $time" | awk '{ if ($2 > 0) printf "%d %s", $1 / $2 / 1024, "200"; else print "0 200" }'
}

# Текущая эффективная нода балансировщика (что он выбирает сейчас — с учётом
# ранее выставленного override). Парсит секцию Selects вывода bi. Пусто, если
# не удалось определить.
sb_current_target() {
    xray api bi -s "$sb_api_addr" "$sb_balancer" 2>/dev/null | awk '
        /Selects:/    { in_sel = 1; next }
        /Selecting/   { in_sel = 0 }
        in_sel && $2 ~ /./ { print $2; exit }'
}

# Один цикл: замерить все ноды, выбрать самую быструю, переключиться с учётом
# гистерезиса. Настройки должны быть загружены (speed_balancer_settings).
sb_tick() {
    if ! xray api bi -s "$sb_api_addr" "$sb_balancer" >/dev/null 2>&1; then
        sb_log "api недоступен ($sb_api_addr) — пропуск"
        return 1
    fi
    if ! sb_node_list; then
        sb_log "ноды балансировщика '$sb_balancer' не найдены — пропуск"
        return 1
    fi

    local n s best best_speed current current_speed threshold
    best=""; best_speed=0
    current=$(sb_current_target); current_speed=0

    local r code
    for n in $sb_nodes; do
        r=$(sb_measure_node "$n")
        s=${r%% *}; code=${r#* }
        if [ "$s" -gt 0 ] 2>/dev/null; then
            sb_log "замер $n: $s КБ/с"
        else
            sb_log "замер $n: 0 КБ/с (код $code)"
        fi
        [ "$n" = "$current" ] && current_speed="$s"
        if [ "$s" -gt "$best_speed" ] 2>/dev/null; then
            best_speed="$s"; best="$n"
        fi
    done

    if [ -z "$best" ] || [ "$best_speed" -eq 0 ] 2>/dev/null; then
        sb_log "все замеры провалились — выбор не меняем"
        sb_log_trim
        return 1
    fi

    if [ "$best" = "$current" ]; then
        sb_log "быстрейшая нода уже активна: $current ($best_speed КБ/с)"
        sb_log_trim
        return 0
    fi

    # Гистерезис: сменить, только если кандидат быстрее текущей более чем на
    # sb_hysteresis процентов. Если текущую замерить не удалось (0), любой
    # ненулевой кандидат проходит порог.
    threshold=$(( current_speed * (100 + sb_hysteresis) / 100 ))
    if [ "$best_speed" -gt "$threshold" ]; then
        if xray api bo -s "$sb_api_addr" -b "$sb_balancer" "$best" >/dev/null 2>&1; then
            sb_log "переключение: $current ($current_speed) -> $best ($best_speed КБ/с)"
        else
            sb_log "bo не смог переключить на $best"
        fi
    else
        sb_log "оставляем $current: кандидат $best ($best_speed) не выше порога $threshold КБ/с"
    fi

    sb_log_trim
}
