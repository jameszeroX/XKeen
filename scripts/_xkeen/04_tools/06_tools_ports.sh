data_is_updated_donor() {
    file=$1
    new_ports=$2
    current_ports=$(
        awk -F= '/^port_donor/{print $2; exit}' "$file" \
        | tr -d '"'
    )
    if [ "$current_ports" = "$new_ports" ]; then
        return 0
    else
        return 1
    fi
}

data_is_updated_excluded() {
    file=$1
    new_ports=$2
    current_ports=$(
        awk -F= '/^port_exclude/{print $2; exit}' "$file" \
        | tr -d '"'
    )
    if [ "$current_ports" = "$new_ports" ]; then
        return 0
    else
        return 1
    fi
}

normalize_ports() {
    input="$1"
    tmpfile=$(mktemp)

    # Разделяем входные данные по запятым и обрабатываем построчно
    echo "$input" | tr ',' '\n' | while read port; do
        # Удаляем пробелы
        port=$(echo "$port" | tr -d '[:space:]')

        # Проверяем, является ли порт диапазоном
        if echo "$port" | grep -q '[:-]'; then
            # Заменяем '-' на ':'
            port=$(echo "$port" | tr '-' ':')
            # Извлекаем начало и конец диапазона
            start=$(echo "$port" | cut -d':' -f1)
            end=$(echo "$port" | cut -d':' -f2)

            # Проверяем, что start и end — числа и не превышают 65535
            if ! [ "$start" -ge 0 ] 2>/dev/null || ! [ "$end" -ge 0 ] 2>/dev/null || \
               [ "$start" -gt 65535 ] || [ "$end" -gt 65535 ]; then
                continue
            fi

            # Если первое число больше второго, меняем их местами
            if [ "$start" -gt "$end" ]; then
                temp="$start"
                start="$end"
                end="$temp"
            fi

            # Формируем диапазон в формате start:end
            normalized_port="$start:$end"
        else
            # Если это одиночный порт, проверяем, что это число и не превышает 65535
            if ! [ "$port" -ge 0 ] 2>/dev/null || [ "$port" -gt 65535 ]; then
                continue
            fi
            normalized_port="$port"
        fi

        # Добавляем нормализованный порт к временному файлу
        echo "$normalized_port" >> "$tmpfile"
    done

    # Читаем результат из временного файла, сортируем и удаляем дубликаты
    if [ -s "$tmpfile" ]; then
        sort -n -u "$tmpfile" | tr '\n' ',' | sed 's/,$//'
    fi

    # Удаляем временный файл
    rm -f "$tmpfile"
}

# Функция валидации портов
validate_and_clean_ports() {
    input_ports="$1"
    final_ports=""

    final_ports=$(echo "$input_ports" | tr ',' '\n' | awk '
        function is_valid(p) {
            return p > 0 && p <= 65535 && p ~ /^[0-9]+$/
        }
        {
            gsub(/ /, "", $0)
            if ($0 == "") next;

            n = split($0, a, ":")
            if (n == 1) {
                if (is_valid(a[1])) print a[1]
            } else if (n == 2) {
                if (is_valid(a[1]) && is_valid(a[2]) && a[1] < a[2]) print a[1]":"a[2]
            }
        }
    ' | sort -un | tr '\n' ',' | sed 's/,$//')
    
    echo "$final_ports"
}

# Функция обработки пользовательских портов
process_user_ports() {
    user_proxy_ports=""
    user_exclude_ports=""

    if [ -f "/opt/etc/xkeen/port_proxying.lst" ]; then
        user_proxy_ports=$(
            sed 's/\r$//' "/opt/etc/xkeen/port_proxying.lst" | \
            sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
            grep -v '^#' | \
            grep -v '^$' | \
            sed 's/-/:/g' | \
            grep -E '^[0-9]+(:[0-9]+)?$' | \
            tr '\n' ',' | \
            sed 's/,$//'
        )
    fi

    if [ -f "/opt/etc/xkeen/port_exclude.lst" ]; then
        user_exclude_ports=$(
            sed 's/\r$//' "/opt/etc/xkeen/port_exclude.lst" | \
            sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
            grep -v '^#' | \
            grep -v '^$' | \
            sed 's/-/:/g' | \
            grep -E '^[0-9]+(:[0-9]+)?$' | \
            tr '\n' ',' | \
            sed 's/,$//'
        )
    fi

    if [ -n "$user_proxy_ports" ]; then
        port_donor="${port_donor},${user_proxy_ports}"

        port_donor=$(validate_and_clean_ports "$port_donor")

    elif [ -n "$user_exclude_ports" ]; then
        port_exclude="${port_exclude},${user_exclude_ports}"

        port_exclude=$(validate_and_clean_ports "$port_exclude")

    else
        :
    fi
}

add_ports_donor() {
    add_ports="donor"
    choice_port_xkeen
    if [ -z "$1" ]; then
        echo -e "  ${red}Ошибка${reset}: список портов не может быть пустым"
        return 1
    fi

    file_port_exclude="/opt/etc/xkeen/port_exclude.lst"
    excluded_ports_from_file=""
    excluded_ports_from_var=""
    conflict_found=0
    error_message=""

    if [ -f "$file_port_exclude" ]; then
        excluded_ports_from_file=$(grep -v '^#' "$file_port_exclude" | grep -v '^$' | tr -d '[:space:]')
    fi

    excluded_ports_from_var=$(
        awk -F= '/^port_exclude/{print $2; exit}' "$initd_dir/S99xkeen" \
        | tr -d '"' | tr -d '[:space:]'
    )
    excluded_ports_from_var=$(normalize_ports "$excluded_ports_from_var")

    if [ -n "$excluded_ports_from_file" ]; then
        conflict_found=1
        display_ports=$(grep -v '^#' "$file_port_exclude" | grep -v '^$' | tr '\n' ',' | sed 's/,$//')
        error_message="${error_message}  -> В файле (${yellow}$file_port_exclude${reset}) найдены порты: ${yellow}$display_ports${reset}\n"
    fi

    if [ -n "$excluded_ports_from_var" ]; then
        conflict_found=1
        error_message="${error_message}  -> В файле S99xkeen указаны порты исключения: ${yellow}$excluded_ports_from_var${reset}\n"
    fi

    if [ "$conflict_found" -eq 1 ]; then
        echo -e "  ${red}Ошибка${reset}: Невозможно добавить порты проксирования, так как уже заданы исключения"
        echo -e "$error_message"
        echo -e "  Сначала очистите все исключенные порты, затем повторите попытку"
        return 1
    fi

    ports=$(normalize_ports "$1")
    current_ports=$(
        awk -F= '/^port_donor/{print $2; exit}' $initd_dir/S99xkeen \
        | tr -d '"'
    )
    current_ports=${current_ports:-""}

    current_ports=$(echo "$current_ports" | sed 's/^,//')

    user_proxy_ports=""
    if [ -f "/opt/etc/xkeen/port_proxying.lst" ]; then
        user_proxy_ports=$(grep -v '^#' "/opt/etc/xkeen/port_proxying.lst" | grep -v '^$' | tr '\n' ',' | sed 's/,$//')
        user_proxy_ports=$(normalize_ports "$user_proxy_ports")
    fi

    all_current_ports="$current_ports"
    if [ -n "$user_proxy_ports" ] && [ -n "$all_current_ports" ]; then
        all_current_ports="$all_current_ports,$user_proxy_ports"
    elif [ -n "$user_proxy_ports" ]; then
        all_current_ports="$user_proxy_ports"
    fi

    if echo "$all_current_ports" | grep -qv "\(^\|,\)80\(,\|$\)"; then
        ports="80,$ports"
    fi
    if echo "$all_current_ports" | grep -qv "\(^\|,\)443\(,\|$\)"; then
        ports="443,$ports"
    fi

    ports=$(validate_and_clean_ports "$ports")

    # Соединяем текущие порты с переданными и удаляем дубликаты
    new_ports=
    if [ -z "$current_ports" ]; then
        new_ports="$ports"
    else
        if [ -n "$ports" ]; then
            new_ports=$(echo "$current_ports,$ports" | tr ',' '\n' | sort -n -u | tr '\n' ',' | sed 's/,$//')
        else
            new_ports="$current_ports"
        fi
    fi

    added_ports=
    duplicate_ports=
    for port in $(echo "$ports" | tr ',' '\n'); do
        if ! echo "$current_ports" | tr ',' '\n' | grep -Fxq "$port"; then
            added_ports="$added_ports\n     $port"
        else
            duplicate_ports="$duplicate_ports\n     $port"
        fi
    done

    new_ports=$(echo $new_ports | sed 's/^ *//')

    # Если new_ports пуст, не добавляем запятую
    if [ -n "$new_ports" ]; then
        port_var="port_donor=\"$new_ports\""
    else
        port_var="port_donor=\"\""
    fi

    tmpfile=$(mktemp)
    awk -v new="$port_var" 'BEGIN{replaced=0} /^port_donor/ && !replaced {sub(/^port_donor="[^"]*"/, new); replaced=1} {print}' $initd_dir/S99xkeen > "$tmpfile" && mv "$tmpfile" $initd_dir/S99xkeen

    while true; do
        if data_is_updated_donor "$initd_dir/S99xkeen" "$new_ports"; then break; fi
        sleep 1
    done

    if [ -z "$added_ports" ]; then
        echo -e "  Список портов ${red}не обновлен${reset}\n  Прокси-клиент ${yellow}уже работает${reset} на портах$duplicate_ports"
    else
        echo -e "  Список портов ${green}успешно обновлен${reset}\n  Новые порты прокси-клиента$added_ports"
        if [ -n "$duplicate_ports" ]; then
            echo -e "  Прокси-клиент ${yellow}уже работает${reset} на портах$duplicate_ports"
        fi
    fi

    if [ -n "$missing_ports" ]; then
        echo -e "  ${red}Предупреждение${reset}: Рекомендуемые порты (${yellow}${missing_ports}${reset}) не добавлены в проксирование!"
    fi
}

dell_ports_donor() {
    ports=$(normalize_ports "$1")
    current_ports=$(
        awk -F= '/^port_donor/{print $2; exit}' "$initd_dir/S99xkeen" \
        | tr -d '"'
    )
    new_ports="$current_ports"
    deleted_ports=
    not_found_ports=

    if [ -z "$current_ports" ]; then
        echo -e "  Прокси-клиент работает на ${yellow}всех${reset} портах\n  ${red}Отсутствуют${reset} конкретные порты для удаления"
        return
    fi

    if [ -z "$ports" ]; then
        new_ports=
        echo -e "  Все порты ${green}успешно очищены${reset}\n  Прокси-клиент работает на ${yellow}всех${reset} портах"
    else
        for port in $(echo "$ports" | tr ',' '\n'); do
            if echo "$new_ports" \
                | tr ',' '\n' \
                | grep -Fxq "$port"; then
                new_ports=$(
                    echo "$new_ports" \
                    | tr ',' '\n' \
                    | grep -vFx "$port" \
                    | sort -n \
                    | tr '\n' ',' \
                    | sed 's/^,//; s/,$//'
                )
                deleted_ports="$deleted_ports\n     $port"
            else
                not_found_ports="$not_found_ports\n     $port"
            fi
        done
    fi

    new_ports=$(
        echo "$new_ports" \
        | sed 's/^ *//;s/ *,$//' | tr -d '\n'
    )

    # Удаление запятых после последнего числа в переменной new_ports перед закрывающими кавычками
    new_ports=$(echo "$new_ports" | sed 's/,\+$//')

    awk -v new_ports="$new_ports" -F= '
    BEGIN {OFS=FS; first=1}
    /^port_donor/ && first {
        if (new_ports == "") {
            print "port_donor=\"\""
			} else {
            print "port_donor=\"" new_ports "\""
        }
        first=0
        next
    }
    {print}' "$initd_dir/S99xkeen" > temp && mv temp "$initd_dir/S99xkeen"

    if [ -n "$ports" ]; then
        if [ -z "$deleted_ports" ]; then
            echo -e "  Список портов ${red}не обновлен${reset}\n  Прокси-клиент ${yellow}не работает${reset} на портах$not_found_ports"
        else
            echo -e "  Список портов ${green}успешно обновлен${reset}\n  Удаленные порты$deleted_ports"
            if [ -n "$not_found_ports" ]; then
                echo -e "  Прокси-клиент ${yellow}не работает${reset} с портами$not_found_ports"
            fi
        fi
    fi
}

add_ports_exclude() {
    add_ports="exclude"
    choice_port_xkeen
    if [ -z "$1" ]; then
        echo -e "  ${red}Ошибка${reset}: список портов не может быть пустым"
        return 1
    fi

    file_port_proxying="/opt/etc/xkeen/port_proxying.lst"
    donor_ports_from_file=""
    donor_ports_from_var=""
    conflict_found=0
    error_message=""

    if [ -f "$file_port_proxying" ]; then
        donor_ports_from_file=$(grep -v '^#' "$file_port_proxying" | grep -v '^$' | tr -d '[:space:]')
    fi

    donor_ports_from_var=$(
        awk -F= '/^port_donor/{print $2; exit}' "$initd_dir/S99xkeen" \
        | tr -d '"' | tr -d '[:space:]'
    )
    donor_ports_from_var=$(normalize_ports "$donor_ports_from_var")

    if [ -n "$donor_ports_from_file" ]; then
        conflict_found=1
        display_ports=$(grep -v '^#' "$file_port_proxying" | grep -v '^$' | tr '\n' ',' | sed 's/,$//')
        error_message="${error_message}  -> В файле (${yellow}$file_port_proxying${reset}) найдены порты: ${yellow}$display_ports${reset}\n"
    fi

    if [ -n "$donor_ports_from_var" ]; then
        conflict_found=1
        error_message="${error_message}  -> В файле S99xkeen указаны порты проксирования: ${yellow}$donor_ports_from_var${reset}\n"
    fi

    if [ "$conflict_found" -eq 1 ]; then
        echo -e "  ${red}Ошибка${reset}: Невозможно добавить исключаемые порты, так как уже заданы порты проксирования"
        echo -e "$error_message"
        echo -e "  Сначала очистите все порты проксирования, затем повторите попытку"
        return 1
    fi

    ports=$(normalize_ports "$1")
    current_ports=$(
        awk -F= '/^port_exclude/{print $2; exit}' $initd_dir/S99xkeen \
        | tr -d '"'
    )
    current_ports=${current_ports:-""}

    # Удаляем возможную запятую в начале
    current_ports=$(echo "$current_ports" | sed 's/^,//')

    # Соединяем текущие порты с переданными и удаляем дубликаты
    new_ports=
    if [ -z "$current_ports" ]; then
        new_ports="$ports"
    else
        if [ -n "$ports" ]; then
            new_ports=$(echo "$current_ports,$ports" | tr ',' '\n' | sort -n -u | tr '\n' ',' | sed 's/,$//')
        else
            new_ports="$current_ports"
        fi
    fi

    added_ports=
    duplicate_ports=
    for port in $(echo "$ports" | tr ',' '\n'); do
        if ! echo "$current_ports" | tr ',' '\n' | grep -Fxq "$port"; then
            added_ports="$added_ports\n     $port"
        else
            duplicate_ports="$duplicate_ports\n     $port"
        fi
    done

    new_ports=$(echo $new_ports | sed 's/^ *//')

    # Если new_ports пуст, не добавляем запятую
    if [ -n "$new_ports" ]; then
        port_var="port_exclude=\"$new_ports\""
    else
        port_var="port_exclude=\"\""
    fi

    tmpfile=$(mktemp)
    awk -v new="$port_var" 'BEGIN{replaced=0} /^port_exclude/ && !replaced {sub(/^port_exclude="[^"]*"/, new); replaced=1} {print}' $initd_dir/S99xkeen > "$tmpfile" && mv "$tmpfile" $initd_dir/S99xkeen

    while true; do
        if data_is_updated_excluded "$initd_dir/S99xkeen" "$new_ports"; then break; fi
        sleep 1
    done

    if [ -z "$added_ports" ]; then
        echo -e "  ${yellow}Предупреждение${reset}"
		echo -e "  Список портов-исключений ${red}не обновлен${reset}\n  Прокси-клиент уже не работает с портами$duplicate_ports"
    else
        echo -e "  ${green}Успех${reset}"
		echo -e "  Список портов-исключений ${green}успешно обновлен${reset}\n  Новые порты с которыми прокси-клиент не будет работать$added_ports"
        if [ -n "$duplicate_ports" ]; then
            echo -e "  ${yellow}Ошибка${reset}"
			echo -e "  Прокси-клиент ${yellow}уже не работает${reset} с портами$duplicate_ports"
        fi
    fi
}

dell_ports_exclude() {
    ports=$(normalize_ports "$1")
    current_ports=$(
        awk -F= '/^port_exclude/{print $2; exit}' "$initd_dir/S99xkeen" \
        | tr -d '"'
    )
    new_ports="$current_ports"
    deleted_ports=
    not_found_ports=

    if [ -z "$current_ports" ]; then
        echo -e "  Прокси-клиент работает на ${yellow}всех${reset} портах\n  ${red}Отсутствуют${reset} конкретные порты для удаления"
        return
    fi

    if [ -z "$ports" ]; then
        new_ports=
        echo -e "  ${green}Успех${reset}"
        echo -e "  Все порты очищены\n  Прокси-клиент работает на ${yellow}всех${reset} портах"
    else
        for port in $(echo "$ports" | tr ',' '\n'); do
            if echo "$new_ports" \
                | tr ',' '\n' \
                | grep -Fxq "$port"; then
                new_ports=$(
                    echo "$new_ports" \
                    | tr ',' '\n' \
                    | grep -vFx "$port" \
                    | sort -n \
                    | tr '\n' ',' \
                    | sed 's/^,//; s/,$//'
                )
                deleted_ports="$deleted_ports\n     $port"
            else
                not_found_ports="$not_found_ports\n     $port"
            fi
        done
    fi

    new_ports=$(
        echo "$new_ports" \
        | sed 's/^ *//;s/ *,$//' | tr -d '\n'
    )

    # Удаление запятых после последнего числа в переменной new_ports перед закрывающими кавычками
    new_ports=$(echo "$new_ports" | sed 's/,\+$//')

    awk -v new_ports="$new_ports" -F= '
    BEGIN {OFS=FS; first=1}
    /^port_exclude/ && first {
        if (new_ports == "") {
            print "port_exclude=\"\""
        } else {
            print "port_exclude=\"" new_ports "\""
        }
        first=0
        next
    }
    {print}' "$initd_dir/S99xkeen" > temp && mv temp "$initd_dir/S99xkeen"

    if [ -n "$ports" ]; then
        if [ -z "$deleted_ports" ]; then
            echo -e "  ${yellow}Предупреждение${reset}"
			echo -e "  Список портов-исключений ${red}не обновлен${reset}\n  Прокси-клиент не имеет исключеных портов$not_found_ports"
        else
            echo -e "  ${green}Успех${reset}"
			echo -e "  Список портов-исключений успешно обновлен\n  Удаленные порты$deleted_ports"
            if [ -n "$not_found_ports" ]; then
                 echo -e "  ${yellow}Ошибка${reset}"
				echo -e "  Прокси-клиент ${yellow}не работает${reset} с портами$not_found_ports"
            fi
        fi
    fi
}

# Получить список портов проксирования
get_ports_donor() {
    port_donor=$(grep -m1 '^port_donor=' $initd_dir/S99xkeen | cut -d'=' -f2 | tr -d '"')
    port_exclude=$(grep -m1 '^port_exclude=' $initd_dir/S99xkeen | cut -d'=' -f2 | tr -d '"')
    
    process_user_ports
    
    if [ -z "$port_donor" ] || [ "$port_donor" = "" ]; then
        echo -e "  Прокси-клиент работает ${yellow}на всех портах${reset}"
    else
        formatted_ports=$(echo "$port_donor" | tr ',' '\n' | sed 's/^/     /')
        echo -e "  Прокси-клиент работает на портах\n${green}$formatted_ports${reset}"
    fi
}

# Получить список портов, исключённых из проксирования
get_ports_exclude() {
    port_donor=$(grep -m1 '^port_donor=' $initd_dir/S99xkeen | cut -d'=' -f2 | tr -d '"')
    port_exclude=$(grep -m1 '^port_exclude=' $initd_dir/S99xkeen | cut -d'=' -f2 | tr -d '"')
    
    process_user_ports
    
    if [ -z "$port_exclude" ] || [ "$port_exclude" = "" ]; then
        echo -e "  ${yellow}Нет портов${reset} исключенных из проксирования"
    else
        formatted_ports=$(echo "$port_exclude" | tr ',' '\n' | sed 's/^/     /')
        echo -e "  Из проксирования исключены порты\n${green}$formatted_ports${reset}"
    fi
}
