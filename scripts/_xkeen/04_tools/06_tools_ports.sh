data_is_updated_donor() {
    file=$1
    new_ports=$2
    current_ports=$(
        awk -F= '/port_donor/{print $2; exit}' "$file" \
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
        awk -F= '/port_exclude/{print $2; exit}' "$file" \
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
    result=""
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
        if [ -z "$result" ]; then
            echo "$normalized_port" >> "$tmpfile"
            result="set"
        else
            echo ",$normalized_port" >> "$tmpfile"
        fi
    done

    # Читаем результат из временного файла, сортируем и удаляем дубликаты
    if [ -s "$tmpfile" ]; then
        cat "$tmpfile" | tr -d '\n' | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//'
    fi

    # Удаляем временный файл
    rm -f "$tmpfile"
}

add_ports_donor() {
    if [ -z "$1" ]; then
        echo -e "  ${red}Ошибка${reset}: список портов не может быть пустым"
        return 1
    fi

    # Проверяем наличие исключенных портов
    excluded_ports=$(
        awk -F= '/port_exclude/{print $2; exit}' $initd_dir/S24xray \
        | tr -d '"' | tr -d '[:space:]'
    )

    if [ -n "$excluded_ports" ]; then
        echo -e "  ${red}Ошибка${reset}: Невозможно добавить порты проксирования"
        echo -e "  В исключенных указаны порты: ${yellow}$excluded_ports${reset}"
        echo -e "  Сначала очистите исключенные порты, затем добавьте порты проксирования"
        return 1
    fi

    ports=$(normalize_ports "$1")
    current_ports=$(
        awk -F= '/port_donor/{print $2; exit}' $initd_dir/S24xray \
        | tr -d '"'
    )
    current_ports=${current_ports:-""}

    # Удаляем возможную запятую в начале
    current_ports=$(echo "$current_ports" | sed 's/^,//')

    # Проверяем наличие портов (80 и 443)
    missing_ports=""
    if ! echo "$ports,$current_ports" | tr ',' '\n' | grep -qFx "80"; then
        missing_ports="80"
    fi
    if ! echo "$ports,$current_ports" | tr ',' '\n' | grep -qFx "443"; then
        if [ -n "$missing_ports" ]; then
            missing_ports="$missing_ports, 443"
        else
            missing_ports="443"
        fi
    fi

    # Соединяем текущие порты с переданными и удаляем дубликаты
    new_ports=
    if [ -z "$current_ports" ]; then
        new_ports="$ports"
    else
        if [ -n "$ports" ]; then
            new_ports=$(echo "$current_ports,$ports" | tr ',' '\n' | sort -nu | tr '\n' ',' | sed 's/,$//')
        else
            new_ports="$current_ports"
        fi
    fi

    added_ports=
    duplicate_ports=

    for port in $(echo "$ports" | tr ',' '\n'); do
        if ! echo "$current_ports" \
            | tr ',' '\n' \
            | grep -Fxq "$port"; then
            added_ports="$added_ports\n     $port"
        else
            duplicate_ports="$duplicate_ports\n     $port"
        fi
    done

    new_ports=$(
        echo $new_ports \
        | sed 's/^ *//'
    )

    # Если new_ports пуст, не добавляем запятую
    if [ -n "$new_ports" ]; then
        port_var="port_donor=\"$new_ports\""
    else
        port_var="port_donor=\"\""
    fi

    tmpfile=$(mktemp)
    awk -v new="$port_var" 'BEGIN{replaced=0} /port_donor/ && !replaced {sub(/port_donor="[^"]*"/, new); replaced=1} {print}' $initd_dir/S24xray > "$tmpfile" && mv "$tmpfile" $initd_dir/S24xray

    while true; do
        if data_is_updated_donor "$initd_dir/S24xray" "$new_ports"; then
            break
        fi
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
        awk -F= '/port_donor/{print $2; exit}' "$initd_dir/S24xray" \
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
                    | tr '\n' ',' \
                    | sed 's/^,//; s/,$//'
                )
                deleted_ports="$deleted_ports\n     $port"
            else
                not_found_ports="$not_found_ports\n     $port"
            fi
        done

        # Проверяем наличие портов (80 и 443) только если new_ports не пуст
        if [ -n "$new_ports" ]; then
            missing_ports=""
            if ! echo "$new_ports" | tr ',' '\n' | grep -qFx "80"; then
                missing_ports="80"
            fi
            if ! echo "$new_ports" | tr ',' '\n' | grep -qFx "443"; then
                if [ -n "$missing_ports" ]; then
                    missing_ports="$missing_ports, 443"
                else
                    missing_ports="443"
                fi
            fi
        fi
    fi

    new_ports=$(
        echo "$new_ports" \
        | sed 's/^ *//;s/ *,$//' | tr -d '\n'
    )

    # Удаление запятых после последнего числа в переменной new_ports перед закрывающими кавычками
    new_ports=$(echo "$new_ports" | sed 's/,\+$//')

    awk -v new_ports="$new_ports" -F= '
    BEGIN {OFS=FS; first=1}
    /port_donor/ && first {
        if (new_ports == "") {
            print "port_donor=\"\""
			} else {
            print "port_donor=\"" new_ports "\""
        }
        first=0
        next
    }
    {print}' "$initd_dir/S24xray" > temp && mv temp "$initd_dir/S24xray"

    if [ -n "$ports" ]; then
        if [ -z "$deleted_ports" ]; then
            echo -e "  Список портов ${red}не обновлен${reset}\n  Прокси-клиент ${yellow}не работает${reset} на портах$not_found_ports"
        else
            echo -e "  Список портов ${green}успешно обновлен${reset}\n  Удаленные порты$deleted_ports"
            if [ -n "$not_found_ports" ]; then
                echo -e "  Прокси-клиент ${yellow}не работает${reset} с портами$not_found_ports"
            fi
        fi

        if [ -n "$missing_ports" ]; then
            echo -e "  ${red}Предупреждение${reset}: Рекомендуемые порты (${yellow}${missing_ports}${reset}) не добавлены в проксирование!"
        fi

    fi
}

add_ports_exclude() {
    if [ -z "$1" ]; then
        echo -e "  ${red}Ошибка${reset}: список портов не может быть пустым"
        return 1
    fi

    # Проверяем наличие портов проксирования
    donor_ports=$(
        awk -F= '/port_donor/{print $2; exit}' $initd_dir/S24xray \
        | tr -d '"' | tr -d '[:space:]'
    )

    if [ -n "$donor_ports" ]; then
        echo -e "  ${red}Ошибка${reset}: Невозможно добавить исключаемые порты"
        echo -e "  В портах проксирования указаны: ${yellow}$donor_ports${reset}"
        echo -e "  Сначала очистите порты проксирования, затем добавьте исключаемые порты"
        return 1
    fi

    ports=$(normalize_ports "$1")
    current_ports=$(
        awk -F= '/port_exclude/{print $2; exit}' $initd_dir/S24xray \
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
            new_ports=$(echo "$current_ports,$ports" | tr ',' '\n' | sort -nu | tr '\n' ',' | sed 's/,$//')
        else
            new_ports="$current_ports"
        fi
    fi

    added_ports=
    duplicate_ports=

    for port in $(echo "$ports" | tr ',' '\n'); do
        if ! echo "$current_ports" \
            | tr ',' '\n' \
            | grep -Fxq "$port"; then
            added_ports="$added_ports\n     $port"
        else
            duplicate_ports="$duplicate_ports\n     $port"
        fi
    done

    new_ports=$(
        echo $new_ports \
        | sed 's/^ *//'
    )

    # Если new_ports пуст, не добавляем запятую
    if [ -n "$new_ports" ]; then
        port_var="port_exclude=\"$new_ports\""
    else
        port_var="port_exclude=\"\""
    fi

    tmpfile=$(mktemp)
    awk -v new="$port_var" 'BEGIN{replaced=0} /port_exclude/ && !replaced {sub(/port_exclude="[^"]*"/, new); replaced=1} {print}' $initd_dir/S24xray > "$tmpfile" && mv "$tmpfile" $initd_dir/S24xray

    while true; do
        if data_is_updated_excluded "$initd_dir/S24xray" "$new_ports"; then
            break
        fi
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
        awk -F= '/port_exclude/{print $2; exit}' "$initd_dir/S24xray" \
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
    /port_exclude/ && first {
        if (new_ports == "") {
            print "port_exclude=\"\""
        } else {
            print "port_exclude=\"" new_ports "\""
        }
        first=0
        next
    }
    {print}' "$initd_dir/S24xray" > temp && mv temp "$initd_dir/S24xray"

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