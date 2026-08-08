# Создание директорий и файлов
init_directories() {
    mkdir -p "$xray_log_dir" || { echo "Ошибка: Не удалось создать директорию $xray_log_dir"; exit 1; }
    mkdir -p "$initd_dir" || { echo "Ошибка: Не удалось создать директорию $initd_dir"; exit 1; }
    mkdir -p "$backups_dir" || { echo "Ошибка: Не удалось создать директорию $backups_dir"; exit 1; }
    mkdir -p "$install_dir" || { echo "Ошибка: Не удалось создать директорию $install_dir"; exit 1; }
    mkdir -p "$cron_dir" || { echo "Ошибка: Не удалось создать директорию $cron_dir"; exit 1; }
    touch "$xray_access_log" || { echo "Ошибка: Не удалось создать файл $xray_access_log"; exit 1; }
    touch "$xray_error_log" || { echo "Ошибка: Не удалось создать файл $xray_error_log"; exit 1; }
}

# Root-only runtime state in tmpfs.  Do not use predictable top-level /tmp
# paths: XKeen and its hooks run as root.
_xkeen_secure_rundir() {
    d="/tmp/.xkeen"
    if [ -e "$d" ] && [ ! -d "$d" ]; then
        rm -f "$d" 2>/dev/null
    fi
    if [ -d "$d" ]; then
        set -- $(ls -ld "$d" 2>/dev/null)
        mode="$1"
        owner="$3"
        if [ "$owner" != "root" ] || [ "$mode" != "drwx------" ]; then
            rm -rf "$d" 2>/dev/null
        fi
    fi
    [ -d "$d" ] || mkdir -m 700 "$d" 2>/dev/null || return 1
    chmod 700 "$d" 2>/dev/null || return 1
    printf '%s' "$d"
}
tmp_ram="$(_xkeen_secure_rundir)/work.$$"

verify_downloads_settings() {
    verify_downloads="warn"
    [ -f "$xkeen_config" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    _vd_value=$(strip_json_comments "$xkeen_config" | jq -r '.xkeen.verify_downloads // "warn"' 2>/dev/null)
    case "$_vd_value" in strict|warn|off) verify_downloads="$_vd_value" ;; esac
    unset _vd_value
}

get_yq_dist_url() {
    if [ "$yq_use_workaround" = "true" ] || [ "$softfloat" = "true" ]; then
        printf '%s\n' "$yq_workaround_dist_url"
    else
        printf '%s\n' "$yq_upstream_dist_url"
    fi
}

get_yq_api_url() {
    if [ "$yq_use_workaround" = "true" ] || [ "$softfloat" = "true" ]; then
        printf '%s\n' "$yq_workaround_api_url"
    else
        printf '%s\n' "$yq_api_url"
    fi
}

# Вырезание комментариев перед подачей файла в jq: сам jq принимает только
# строгий JSON, режима JSON5/JSONC у него нет.
#
# Разбор состоянием, а не регуляркой. Регулярка не отличает комментарий от
# строкового значения: `/*` внутри строки склеивался бы со следующим настоящим
# комментарием и вырезал кусок конфига, а ` // ` внутри строки обрезало бы
# значение. Прежняя реализация вдобавок требовала лишнюю `*` внутри блока,
# из-за чего обычный `/* текст */` не вырезался вовсе и jq падал.
#
# inblk намеренно живёт между строками — блочный комментарий многострочный.
# instr сбрасывается на каждой строке: в JSON строка не может содержать
# неэкранированный перевод строки.
strip_json_comments() {
    awk '
    {
        line = ""; i = 1; n = length($0); instr = 0; esc = 0
        while (i <= n) {
            c = substr($0, i, 1)
            if (inblk) {
                if (c == "*" && substr($0, i + 1, 1) == "/") { inblk = 0; i += 2 } else i++
                continue
            }
            if (instr) {
                line = line c
                if (esc) esc = 0
                else if (c == "\\") esc = 1
                else if (c == "\"") instr = 0
                i++
                continue
            }
            if (c == "\"") { instr = 1; line = line c; i++; continue }
            if (c == "/" && substr($0, i + 1, 1) == "*") { inblk = 1; i += 2; continue }
            if (c == "/" && substr($0, i + 1, 1) == "/") break
            line = line c; i++
        }
        print line
    }' "$@"
}
verify_downloads_settings

# Заменить/вставить ЗНАЧЕНИЕ (объект, массив ИЛИ скаляр — строка, число,
# true/false/null) по пути ключей ($1, через точку, напр. "xkeen.killswitch"
# или "xkeen.xray.speed_balancer") новым значением ($2) в файле ($3),
# сохранив ВЕСЬ остальной текст файла побайтово — включая комментарии.
#
# Все ключи пути, КРОМЕ последнего, обязаны либо уже быть объектами (тогда
# в них "заходят" дальше), либо отсутствовать (тогда для них строится
# недостающая обёртка). Последний ключ пути — это то, что реально
# заменяется/вставляется, и он может быть значением ЛЮБОГО типа.
#
# Код возврата:
#   0 — значение по пути найдено и заменено;
#   1 — путь (или его часть, включая последний ключ) отсутствовал —
#       недостающее построено и вставлено в глубочайший существующий
#       объект (при необходимости — в корень файла);
#   2 — конфликт: какой-то ИЗ ПРОМЕЖУТОЧНЫХ ключей пути существует, но это
#       не объект, либо у существующего значения повреждены скобки/кавычки —
#       файл на stdout возвращён без изменений;
#   4 — файл на входе даже не открывается как JSON-объект.
jc_set_path() {
    JC_PATH="$1" JC_NEW="$2" awk '
    function reindent(s, pad,   n, i, parts, out) {
      n = split(s, parts, "\n")
      if (n < 2) return s
      out = parts[1]
      for (i = 2; i <= n; i++) out = out "\n" pad parts[i]
      return out
    }

    # Найти ключ key внутри [from,to] и убедиться, что его значение — ОБЪЕКТ.
    # Нужна для промежуточных уровней пути, в которые предстоит "войти".
    # out[1]/out[2] — скобки объекта, out[3] — позиция ключа.
    # 1 — нашли объект; 0 — ключа нет; 2 — ключ есть, но не объект/битые скобки.
    function locate_obj(buf, key, from, to, out,   kp, i, n, depth, instr, esc, c, ai) {
      kp = index(substr(buf, from, to - from + 1), key)
      if (kp == 0) return 0
      kp = from + kp - 1
      i = kp + length(key); n = to
      while (i <= n && substr(buf,i,1) != ":") i++
      if (i > n) return 2
      i++
      while (i <= n && substr(buf,i,1) ~ /[ \t\r\n]/) i++
      if (i > n || substr(buf,i,1) != "{") return 2
      depth=0; instr=0; esc=0; ai = i
      for (; i <= n; i++) {
        c = substr(buf,i,1)
        if (instr) { if (esc) esc=0; else if (c=="\\") esc=1; else if (c=="\"") instr=0 }
        else { if (c=="\"") instr=1; else if (c=="{") depth++;
               else if (c=="}") { depth--; if (depth==0) { out[1]=ai; out[2]=i; out[3]=kp; return 1 } } }
      }
      return 2
    }

    # Найти ключ key внутри [from,to] и вернуть границы его ЗНАЧЕНИЯ ЛЮБОГО
    # ТИПА: объект/массив (по балансу скобок), строка (до непроэкранированной
    # закрывающей кавычки) или "голый" литерал — число/true/false/null (до
    # первого символа, которым такой литерал кончиться не может).
    # out[1]/out[2] — первая/последняя позиция значения, out[3] — позиция ключа.
    # 1 — нашли; 0 — ключа нет; 2 — ключ есть, но не удалось разобрать значение.
    function locate_value(buf, key, from, to, out,   kp, i, n, c, esc, instr, depth, openc, closec) {
      kp = index(substr(buf, from, to - from + 1), key)
      if (kp == 0) return 0
      kp = from + kp - 1
      i = kp + length(key); n = to
      while (i <= n && substr(buf,i,1) != ":") i++
      if (i > n) return 2
      i++
      while (i <= n && substr(buf,i,1) ~ /[ \t\r\n]/) i++
      if (i > n) return 2
      c = substr(buf,i,1)
      if (c == "\"") {
        vs = i; i++; esc = 0
        for (; i <= n; i++) {
          cc = substr(buf,i,1)
          if (esc) { esc = 0; continue }
          if (cc == "\\") { esc = 1; continue }
          if (cc == "\"") { out[1]=vs; out[2]=i; out[3]=kp; return 1 }
        }
        return 2
      }
      if (c == "{" || c == "[") {
        openc = c; closec = (c == "{") ? "}" : "]"
        depth = 0; instr = 0; esc = 0; vs = i
        for (; i <= n; i++) {
          cc = substr(buf,i,1)
          if (instr) { if (esc) esc=0; else if (cc=="\\") esc=1; else if (cc=="\"") instr=0 }
          else {
            if (cc == "\"") instr = 1
            else if (cc == openc) depth++
            else if (cc == closec) { depth--; if (depth == 0) { out[1]=vs; out[2]=i; out[3]=kp; return 1 } }
          }
        }
        return 2
      }
      # Голый литерал: число / true / false / null — до первого символа,
      # которым он кончиться не может (пробел, запятая, скобка, комментарий).
      vs = i
      while (i <= n) {
        cc = substr(buf,i,1)
        if (cc ~ /[ \t\r\n,}\]]/) break
        if (cc == "/" && (substr(buf,i+1,1) == "/" || substr(buf,i+1,1) == "*")) break
        i++
      }
      if (i == vs) return 2
      out[1] = vs; out[2] = i - 1; out[3] = kp
      return 1
    }

    function locate_root(buf, out,   i, n, depth, instr, esc, c, ai) {
      n = length(buf); i = 1
      while (i <= n && substr(buf,i,1) != "{") i++
      if (i > n) return 0
      depth=0; instr=0; esc=0; ai = i
      for (; i <= n; i++) {
        c = substr(buf,i,1)
        if (instr) { if (esc) esc=0; else if (c=="\\") esc=1; else if (c=="\"") instr=0 }
        else { if (c=="\"") instr=1; else if (c=="{") depth++;
               else if (c=="}") { depth--; if (depth==0) { out[1]=ai; out[2]=i; out[3]=0; return 1 } } }
      }
      return 0
    }

    # Обёртка для недостающих ключей keys[lo..hi] со значением val на самом
    # глубоком уровне (val может быть чем угодно — объектом или скаляром).
    function build_wrap(keys, lo, hi, val, pad,   inner) {
      if (lo == hi) return "\"" keys[lo] "\": " reindent(val, pad)
      inner = pad "  "
      return "\"" keys[lo] "\": {\n" inner build_wrap(keys, lo + 1, hi, val, inner) "\n" pad "}"
    }

    { buf = buf $0 "\n" }
    END {
      new = ENVIRON["JC_NEW"]
      npath = split(ENVIRON["JC_PATH"], keys, ".")

      if (!locate_root(buf, cur)) { printf "%s", buf; exit 4 }

      # Промежуточные уровни (все, кроме последнего ключа пути) обязаны
      # быть объектами, чтобы в них можно было "войти".
      matched = 0
      for (lvl = 1; lvl < npath; lvl++) {
        key = "\"" keys[lvl] "\""
        r = locate_obj(buf, key, cur[1], cur[2], nxt)
        if (r == 1) { cur[1]=nxt[1]; cur[2]=nxt[2]; cur[3]=nxt[3]; matched = lvl; continue }
        if (r == 2) { printf "%s", buf; exit 2 }
        break   # r == 0: этого промежуточного ключа нет — дальше только вставка
      }

      if (matched == npath - 1) {
        # Все родители найдены — последний ключ пути ищем как значение
        # ЛЮБОГО типа (не обязательно объект).
        key = "\"" keys[npath] "\""
        r = locate_value(buf, key, cur[1], cur[2], leaf)
        if (r == 1) {
          vs = leaf[1]; ve = leaf[2]; kp = leaf[3]
          ls = kp
          while (ls > 1 && substr(buf, ls - 1, 1) != "\n") ls--
          pad = substr(buf, ls, kp - ls)
          if (pad ~ /[^ \t]/) { gsub(/\n[ \t]*/, " ", new); pad = "" }
          printf "%s%s%s", substr(buf,1,vs-1), reindent(new, pad), substr(buf,ve+1)
          exit 0
        }
        if (r == 2) { printf "%s", buf; exit 2 }
        # r == 0: последнего ключа нет — вставляем ниже как единственный
        # недостающий уровень (matched уже == npath-1).
      }

      # Не хватает keys[matched+1 .. npath] (может быть как только последний
      # ключ, так и несколько уровней сразу) — строим хвост и вставляем сразу
      # после открывающей "{" самого глубокого найденного объекта.
      i = cur[1]; n = cur[2]
      j = i + 1
      while (j <= n && substr(buf,j,1) ~ /[ \t\r\n]/) j++

      if (cur[3] > 0) {
        ls = cur[3]
        while (ls > 1 && substr(buf, ls - 1, 1) != "\n") ls--
        base = substr(buf, ls, cur[3] - ls)
        if (base ~ /[^ \t]/) base = ""
      } else base = ""
      pad = base "  "
      if (substr(buf,j,1) != "}") {
        ks = j
        while (ks > 1 && substr(buf, ks - 1, 1) != "\n") ks--
        cand = substr(buf, ks, j - ks)
        if (cand != "" && cand !~ /[^ \t]/) pad = cand
      }

      block = build_wrap(keys, matched + 1, npath, new, pad)
      before = substr(buf,1,i); after = substr(buf,i+1)
      if (substr(buf,j,1) == "}")
        printf "%s\n%s%s\n%s%s", before, pad, block, base, after
      else
        printf "%s\n%s%s,%s", before, pad, block, after
      exit 1
    }' "$3"
}

# Параметры повтора загрузок
retries_download_settings() {
    retries_download=1
    retry_delay_download=2

    if [ -f "$xkeen_config" ] && command -v jq >/dev/null 2>&1; then
        local json_clean
        json_clean=$(strip_json_comments "$xkeen_config")

        local parsed_val
        parsed_val=$(printf '%s' "$json_clean" | jq -r '.xkeen.retries_download // empty' 2>/dev/null)

        if [ -n "$parsed_val" ] && [ "$parsed_val" -gt 0 ] 2>/dev/null; then
            retries_download="$parsed_val"
        fi

        local parsed_delay
        parsed_delay=$(printf '%s' "$json_clean" | jq -r '.xkeen.retry_delay_download // empty' 2>/dev/null)
        if [ -n "$parsed_delay" ] && [ "$parsed_delay" -gt 0 ] 2>/dev/null; then
            retry_delay_download="$parsed_delay"
        fi
    fi
}
retries_download_settings

# Функция извлечения rci-токена
get_rci_token() {
    rci_token=""
    [ ! -f "$xkeen_config" ] && return 1

    local json_clean
    json_clean=$(strip_json_comments "$xkeen_config")

    rci_token=$(printf '%s' "$json_clean" | sed -n 's/.*"rci_token": *"\([^"]*\)".*/\1/p' | xargs 2>/dev/null)

    [ "$rci_token" = "null" ] && rci_token=""
}
get_rci_token

http_code=$(
    curl -ksS -o /dev/null -w "%{http_code}" -H "X-Ndma-Tkn: $rci_token" "127.0.0.1:79/rci/show/version"
)

if [ "$http_code" = "403" ]; then
    printf "  ${red}Ошибка${reset}: Отсутствует или недействителен ${light_blue}токен доступа${reset} к RCI

  Для ${green}KeeneticOS 5.2${reset} и выше требуется ${light_blue}токен доступа${reset}
  Создайте его в веб-интерфейсе и укажите в ${yellow}xkeen.json${reset}\n"
    exit 1
fi

# Параметры curl
curl_api() {
    if [ -n "$rci_token" ]; then
        curl --connect-timeout 2 -m 5 -kfsS -H "X-Ndma-Tkn: $rci_token" "$@"
    else
        curl --connect-timeout 2 -m 5 -kfsS "$@"
    fi
}

curl_with_timeout() {
    # Функция динамической очистки и форматирования баров в реальном времени
    indent_stderr_live() {
        # Меняем RS (разделитель строк) в awk на '\r'
        awk -v RS='\r' '{
            # Удаляем мусор (таблицы, ошибки curl)
            if ($0 ~ /(% Total|Average Speed|Time Current|curl:)/) next;
            if ($0 ~ /^[[:space:]]*$/) next;

            # Если это самый первый символ прогресс-бара, делаем начальный отступ
            if (first == 0 && $0 ~ /^[# ]/) {
                printf "  "
                first = 1
            }

            # Выводим бар обратно в stderr с возвратом каретки и отступом
            printf "%s\r  ", $0
            fflush()
        }
        END {
            # Если выполнение закончилось, принудительно сбрасываем каретку
            # в самый левый край (\r), чтобы стереть паразитный отступ для caller-скрипта
            printf "\r"
            fflush()
        }' >&2
    }

    # Проверяем контекст: если вывод в /dev/null или это HEAD-запрос (-I), то это проверка (probe)
    _is_probe=0
    for _arg in "$@"; do
        [ "$_arg" = "/dev/null" ] || [ "$_arg" = "-I" ] && _is_probe=1 && break
    done

    if [ "$_is_probe" = "0" ]; then
        # Режим скачивания (fetch_with_mirrors)
        # Код возврата curl снимаем через отдельный дескриптор: $? после пайпа
        # вернул бы код awk из indent_stderr_live, а не curl, из-за чего любой
        # сетевой сбой выглядел бы как успех. pipefail в POSIX sh недоступен.
        exec 3>&1
        if [ "${XKEEN_TIMEOUT_OFF:-}" = "1" ]; then
            _curl_rc=$( { { curl -# --connect-timeout 10 "$@" 2>&1 1>&3; echo $? >&4; } | indent_stderr_live; } 4>&1 )
        else
            _curl_rc=$( { { curl -# --connect-timeout 10 -m 180 "$@" 2>&1 1>&3; echo $? >&4; } | indent_stderr_live; } 4>&1 )
        fi
        exec 3>&-

        return "${_curl_rc:-1}"
    else
        # Режим проверки доступности (probe_with_mirrors / test_github)
        if [ "${XKEEN_TIMEOUT_OFF:-}" = "1" ]; then
            curl --connect-timeout 10 "$@"
        else
            curl --connect-timeout 10 -m 180 "$@"
        fi
    fi
}

# Настройки балансировки по скорости (.xkeen.xray.speed_balancer.*).
# Вызывается по требованию из модуля -sb, а не глобально: несвязанным командам
# xkeen лишний разбор xkeen.json не нужен. Значения по умолчанию — рабочие,
# файл настроек не обязателен.
speed_balancer_settings() {
    sb_enabled="false"
    sb_log_enabled="true"
    sb_interval="15"
    sb_hysteresis="25"
    sb_balancer="balancer"
    sb_maxtime="8"
    # 10 МБ: endpoint Cloudflare __down отдаёт 403 на запрос больше ~50 МБ
    sb_test_url="https://speed.cloudflare.com/__down?bytes=10000000"
    # Имена файлов конфигурации Xray переопределяемы: ядро генерирует их с этими
    # именами, но нигде их не enforce'ит — у пользователя раскладка может отличаться.
    sb_routing_file="$xray_conf_dir/05_routing.json"
    sb_outbounds_file="$xray_conf_dir/04_outbounds.json"

    if [ -f "$xkeen_config" ] && command -v jq >/dev/null 2>&1; then
        local json_clean
        json_clean=$(strip_json_comments "$xkeen_config")

        local v
        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.xray.speed_balancer.enabled // empty' 2>/dev/null)
        [ "$v" = "true" ] && sb_enabled="true"

        # Логирование замеров/переключений можно отключить (.xray.speed_balancer.log:
        # false) — по умолчанию включено. Лог и так усечён до 200 строк, но кому-то
        # он не нужен вовсе (запрос из issue #103). Читаем БЕЗ `// empty`: для
        # булева false оператор // считает его пустым и вернул бы empty, из-за чего
        # log:false никогда бы не срабатывал. Отсутствующий ключ даёт "null".
        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.xray.speed_balancer.log' 2>/dev/null)
        [ "$v" = "false" ] && sb_log_enabled="false"

        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.xray.speed_balancer.interval // empty' 2>/dev/null)
        [ -n "$v" ] && [ "$v" -gt 0 ] 2>/dev/null && sb_interval="$v"

        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.xray.speed_balancer.hysteresis // empty' 2>/dev/null)
        [ -n "$v" ] && [ "$v" -ge 0 ] 2>/dev/null && sb_hysteresis="$v"

        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.xray.speed_balancer.balancer // empty' 2>/dev/null)
        [ -n "$v" ] && sb_balancer="$v"

        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.xray.speed_balancer.max_time // empty' 2>/dev/null)
        [ -n "$v" ] && [ "$v" -gt 0 ] 2>/dev/null && sb_maxtime="$v"

        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.xray.speed_balancer.test_url // empty' 2>/dev/null)
        [ -n "$v" ] && sb_test_url="$v"

        # Имена файлов задаются базовыми — каталог остаётся xray_conf_dir.
        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.xray.speed_balancer.routing_file // empty' 2>/dev/null)
        [ -n "$v" ] && sb_routing_file="$xray_conf_dir/$v"

        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.xray.speed_balancer.outbounds_file // empty' 2>/dev/null)
        [ -n "$v" ] && sb_outbounds_file="$xray_conf_dir/$v"
    fi
}