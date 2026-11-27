# Функция чтения портов из файлов
read_ports_file() {
    file="$1"

    [ -f "$file" ] || return

    raw_ports=$(sed -e 's/\r$//' -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$file" | tr '\n' ',')
    normalize_ports "$raw_ports"
}

# Функция записи портов в файлы
write_ports_file() {
    file="$1"
    ports="$2"

    tmpfile="${file}.tmp.$$"

    if ! printf '%s\n' "# XKeen ports list" > "$tmpfile" ||
        ! printf '%s\n' "$ports" | tr ',' '\n' >> "$tmpfile"; then
        rm -f "$tmpfile"
        return 1
    fi

    if ! mv -f "$tmpfile" "$file"; then
        rm -f "$tmpfile"
        return 1
    fi
    return 0
}

# Функция проверки конфликта портов
ports_conflict_check() {
    file1="$1"
    file2="$2"

    ports1=$(read_ports_file "$file1")
    ports2=$(read_ports_file "$file2")

    [ -n "$ports1" ] && [ -n "$ports2" ] || return 1

    printf '%s\n%s\n' "$ports1" "$ports2" | awk -F, '
        NR == 1 {
            left_count = split($0, left_ports, ",")
            for (i = 1; i <= left_count; i++) {
                n = split(left_ports[i], endpoint, ":")
                left_start[i] = endpoint[1] + 0
                left_end[i] = n == 2 ? endpoint[2] + 0 : left_start[i]
                if (left_start[i] > left_end[i]) {
                    temp = left_start[i]; left_start[i] = left_end[i]; left_end[i] = temp
                }
            }
            next
        }
        NR == 2 {
            right_count = split($0, right_ports, ",")
            for (i = 1; i <= right_count; i++) {
                n = split(right_ports[i], endpoint, ":")
                right_start[i] = endpoint[1] + 0
                right_end[i] = n == 2 ? endpoint[2] + 0 : right_start[i]
                if (right_start[i] > right_end[i]) {
                    temp = right_start[i]; right_start[i] = right_end[i]; right_end[i] = temp
                }
            }
        }
        END {
            for (i = 1; i <= left_count; i++) {
                for (j = 1; j <= right_count; j++) {
                    if (left_start[i] <= right_end[j] && right_start[j] <= left_end[i]) exit 0
                }
            }
            exit 1
        }
    '
}

# Функция нормализации портов
normalize_ports() {
    echo "$1" | tr ',' '\n' | awk '
    function valid(p) {
        return (p ~ /^[0-9]+$/ && p >= 1 && p <= 65535)
    }

    {
        gsub(/[[:space:]]/, "")
        if ($0 == "") next

        gsub(/-/, ":")

        n = split($0, a, ":")

        if (n == 1) {
            if (valid(a[1])) ports[a[1]]
        }

        else if (n == 2) {
            if (valid(a[1]) && valid(a[2])) {
                start = a[1]
                end   = a[2]

                if (start > end) {
                    tmp = start
                    start = end
                    end = tmp
                }

                ports[start ":" end]
            }
        }
    }

    END {
        for (p in ports)
            print p
    }
    ' | sort -n | tr '\n' ',' | sed 's/,$//'
}

ports_exist_in_list() {
    ports_to_check="$1"
    current_ports="$2"

    for port in $(echo "$ports_to_check" | tr ',' '\n'); do
        echo "$current_ports" | tr ',' '\n' | grep -qx "$port" && return 0
    done

    return 1
}

remove_ports_from_list() {
    current_ports="$1"
    ports_to_del="$2"

    echo "$current_ports" | tr ',' '\n' | awk -v del="$ports_to_del" '
    BEGIN {
        n = split(del, d, ",")
        for (i = 1; i <= n; i++) delset[d[i]] = 1
    }

    {
        if (!($0 in delset)) print
    }
    ' | tr '\n' ',' | sed 's/,$//'
}

merge_ports_lists() {
    normalize_ports "$1,$2"
}

# Функция запроса подтверждения удаления
confirm_deletion() {
    type="$1"
    ports_list="$2"
    message=""

    if [ -n "$ports_list" ]; then
        # Удаление конкретных портов
        message="Вы действительно хотите удалить следующие порты "
        if [ "$type" = "proxying" ]; then
            message="${message}проксирования"
        else
            message="${message}исключённые из проксирования"
        fi
        message="${message}: ${light_blue}${ports_list}${reset}?"
    else
        # Очистка всего списка
        if [ "$type" = "proxying" ]; then
            message="Вы действительно хотите ${red}очистить список портов${reset} проксирования?"
        else
            message="Вы действительно хотите ${red}очистить список портов${reset}, исключённых из проксирования?"
        fi
    fi

    echo
    echo -e "  ${message}"
    echo
    echo "     1. Да"
    echo "     0. Оставить без изменений"

    echo
    while true; do
        # Без TTY (cron, ssh без -t) read получает EOF: код возврата ненулевой,
        # choice остаётся пустым, попадает в ветку * — while true крутится
        # без блокировки на read, CPU-spin. Трактуем EOF как явный ввод 0.
        read -r -p "  Ваш выбор: " choice || choice=0
            case "$choice" in
                1) return 0 ;;
                0) echo && echo "  Отменено пользователем"; return 1 ;;
                *) echo -e "  ${red}Некорректный ввод${reset}" ;;
            esac
    done
}

# Функция добавления обязательных портов проксирования
ensure_web_ports() {
    ports="$1"

    echo "$ports" | tr ',' '\n' | grep -qx "80"  || ports="$ports,80"
    echo "$ports" | tr ',' '\n' | grep -qx "443" || ports="$ports,443"

    normalize_ports "$ports"
}

# Функция добавления портов проксирования
add_ports_donor() {
    [ -z "$1" ] && {
        echo -e "  ${red}Ошибка${reset}: список портов не может быть пустым"
        return 1
    }

    if ports_conflict_check "$file_port_proxying" "$file_port_exclude"; then
        echo -e "  ${yellow}Внимание${reset}: вы добавляете порты проксирования, но уже заданы порты исключения
  Приоритет у портов проксирования, порты исключения будут проигнорированы"
    fi

    new_ports=$(normalize_ports "$(printf '%s,' "$@" | sed 's/,$//')")
    current_ports=$(read_ports_file "$file_port_proxying")
    current_ports=$(normalize_ports "$current_ports")
    all_ports=$(merge_ports_lists "$current_ports" "$new_ports")
    all_ports=$(ensure_web_ports "$all_ports")
    if ! write_ports_file "$file_port_proxying" "$all_ports"; then
        echo -e "  ${red}Ошибка${reset}: не удалось сохранить список портов проксирования"
        return 1
    fi

    echo -e "  ${green}Порты проксирования обновлены${reset}"
}

# Функция удаления портов проксирования
del_ports_donor() {
    ports_to_del=$(normalize_ports "$(printf '%s,' "$@" | sed 's/,$//')")
    current_ports=$(read_ports_file "$file_port_proxying")

    [ -z "$current_ports" ] && {
        echo -e "  ${yellow}Список портов пуст${reset}"
        return
    }

    if [ -z "$ports_to_del" ]; then
        # Очистка всего списка
        if confirm_deletion "proxying"; then
            if ! write_ports_file "$file_port_proxying" ""; then
                echo -e "  ${red}Ошибка${reset}: не удалось очистить список портов проксирования"
                return 1
            fi
            echo -e "  ${green}Все порты удалены${reset}"
        fi
        return
    fi

    ports_exist_in_list "$ports_to_del" "$current_ports" || {
        echo -e "  ${yellow}Указанные порты отсутствуют в списке${reset}"
        return
    }

    # Запрос подтверждения перед удалением указанных портов
    if confirm_deletion "proxying" "$ports_to_del"; then
        new_ports=$(remove_ports_from_list "$current_ports" "$ports_to_del")
        if ! write_ports_file "$file_port_proxying" "$new_ports"; then
            echo -e "  ${red}Ошибка${reset}: не удалось сохранить список портов проксирования"
            return 1
        fi
        echo -e "  ${green}Порты удалены${reset}"
    fi
}

# Функция добавления портов, исключаемых из проксирования
add_ports_exclude() {
    [ -z "$1" ] && {
        echo -e "  ${red}Ошибка${reset}: список портов не может быть пустым"
        return 1
    }

    if ports_conflict_check "$file_port_proxying" "$file_port_exclude"; then
        echo -e "  ${yellow}Внимание${reset}: вы добавляете порты исключения, но уже заданы порты проксирования
  Приоритет у портов проксирования, порты исключения будут проигнорированы"
    fi

    new_ports=$(normalize_ports "$(printf '%s,' "$@" | sed 's/,$//')")
    current_ports=$(read_ports_file "$file_port_exclude")
    current_ports=$(normalize_ports "$current_ports")
    all_ports=$(merge_ports_lists "$current_ports" "$new_ports")
    if ! write_ports_file "$file_port_exclude" "$all_ports"; then
        echo -e "  ${red}Ошибка${reset}: не удалось сохранить список исключённых портов"
        return 1
    fi

    echo -e "  ${green}Порты исключения обновлены${reset}"
}

# Функция удаления портов, исключённых из проксирования
del_ports_exclude() {
    ports_to_del=$(normalize_ports "$(printf '%s,' "$@" | sed 's/,$//')")
    current_ports=$(read_ports_file "$file_port_exclude")

    [ -z "$current_ports" ] && {
        echo -e "  ${yellow}Список портов пуст${reset}"
        return
    }

    if [ -z "$ports_to_del" ]; then
        # Очистка всего списка
        if confirm_deletion "exclude"; then
            if ! write_ports_file "$file_port_exclude" ""; then
                echo -e "  ${red}Ошибка${reset}: не удалось очистить список исключённых портов"
                return 1
            fi
            echo -e "  ${green}Все исключения удалены${reset}"
        fi
        return
    fi

    ports_exist_in_list "$ports_to_del" "$current_ports" || {
        echo -e "  ${yellow}Указанные порты отсутствуют в списке${reset}"
        return
    }

    # Запрос подтверждения перед удалением указанных портов
    if confirm_deletion "exclude" "$ports_to_del"; then
        new_ports=$(remove_ports_from_list "$current_ports" "$ports_to_del")
        if ! write_ports_file "$file_port_exclude" "$new_ports"; then
            echo -e "  ${red}Ошибка${reset}: не удалось сохранить список исключённых портов"
            return 1
        fi
        echo -e "  ${green}Порты исключения удалены${reset}"
    fi
}

# Получить список портов проксирования
get_ports_donor() {
    ports=$(read_ports_file "$file_port_proxying")

    if [ -z "$ports" ]; then
        echo -e "  XKeen работает ${yellow}на всех портах${reset}"
    else
        echo "$ports" | tr ',' '\n' | sed 's/^/     /'
    fi
}

# Получить список портов, исключённых из проксирования
get_ports_exclude() {
    ports=$(read_ports_file "$file_port_exclude")

    if [ -z "$ports" ]; then
        echo -e "  Нет портов исключённых из проксирования"
    else
        echo "$ports" | tr ',' '\n' | sed 's/^/     /'
    fi
}

# Функция переноса пользовательских портов из переменных стартового скрипта в файловую модель
migrate_ports_from_initd() {
    legacy_initd=""

    for f in "/opt/etc/init.d/S99xkeen" "/opt/etc/init.d/S24xray"; do
        [ -f "$f" ] && { legacy_initd="$f"; break; }
    done

    [ -n "$legacy_initd" ] || return

    # Читаем старые значения
    port_donor_val=$(
        awk -F= '/^port_donor=/{print $2; exit}' "$legacy_initd" | tr -d '"'
    )

    port_exclude_val=$(
        awk -F= '/^port_exclude=/{print $2; exit}' "$legacy_initd" | tr -d '"'
    )

    port_donor_val=$(normalize_ports "$port_donor_val")
    port_exclude_val=$(normalize_ports "$port_exclude_val")

    # Миграция port_donor
    if [ -n "$port_donor_val" ]; then

        current_proxy=$(normalize_ports "$(read_ports_file "$file_port_proxying")")

        combined=$(normalize_ports "$current_proxy,$port_donor_val")

        if [ "$combined" != "$current_proxy" ]; then
            tmpfile="${file_port_proxying}.tmp.$$"
            echo "# XKeen port proxying list (migrated)" > "$tmpfile"
            echo "$combined" | tr ',' '\n' >> "$tmpfile"
            mv "$tmpfile" "$file_port_proxying"
        fi
    fi

    # Миграция port_exclude
    if [ -n "$port_exclude_val" ]; then

        current_exclude=$(normalize_ports "$(read_ports_file "$file_port_exclude")")

        combined=$(normalize_ports "$current_exclude,$port_exclude_val")

        if [ "$combined" != "$current_exclude" ]; then
            tmpfile="${file_port_exclude}.tmp.$$"
            echo "# XKeen port exclude list (migrated)" > "$tmpfile"
            echo "$combined" | tr ',' '\n' >> "$tmpfile"
            mv "$tmpfile" "$file_port_exclude"
        fi
    fi
}
