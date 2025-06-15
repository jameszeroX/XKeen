data_is_updated_donor() {
    file=$1
    new_ports=$2
    current_ports=$(
        awk -F= '/port_donor/{print $2; exit}' "$file" \
        | tr -d '"'
    )
    if [ "$current_ports" == "$new_ports" ]; then
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
    if [ "$current_ports" == "$new_ports" ]; then
        return 0
    else
        return 1
    fi
}

add_ports_donor() {
    ports=$1
    # Нормализация портов - удаление пробелов и преобразование разделителей в запятые
    ports=$(echo "$ports" | tr -s '[:space:]' ',' | tr -s ',' | tr ',' '\n' | sort -nu | tr '\n' ',' | sed 's/,$//')

    current_ports=$(
        awk -F= '/port_donor/{print $2; exit}' $initd_dir/S24xray \
        | tr -d '"'
    )
    current_ports=${current_ports:-""}

    # Удаляем возможную запятую в начале
    current_ports=$(echo "$current_ports" | sed 's/^,//')

    # Соединяем текущие порты с переданными и удаляем дубликаты
    new_ports=""
    if [ -z "$current_ports" ]; then
        new_ports="$ports"
    else
        new_ports=$(echo "$current_ports,$ports" | tr ',' '\n' | sort -nu | tr '\n' ',' | sed 's/,$//')
    fi

    added_ports=""
    duplicate_ports=""

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

    tmpfile=$(mktemp)
    awk -v new="port_donor=\"$new_ports\"" 'BEGIN{replaced=0} /port_donor/ && !replaced {sub(/port_donor="[^"]*"/, new); replaced=1} {print}' $initd_dir/S24xray > "$tmpfile" && mv "$tmpfile" $initd_dir/S24xray

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
	
	chmod +x $initd_dir/S24xray
	chmod 755 $initd_dir/S24xray

        $initd_dir/S24xray restart on

}



dell_ports_donor() {
    ports="$1"
    # Нормализация портов - удаление пробелов и преобразование разделителей в запятые
    ports=$(echo "$ports" | tr -s '[:space:]' ',' | tr -s ',' | tr ',' '\n' | sort -nu | tr '\n' ',' | sed 's/,$//')

    current_ports=$(
        awk -F= '/port_donor/{print $2; exit}' "$initd_dir/S24xray" \
        | tr -d '"'
    )
    new_ports="$current_ports"
    deleted_ports=""
    not_found_ports=""

    if [ -z "$current_ports" ]; then
        echo -e "  Прокси-клиент работает на ${yellow}всех${reset} портах\n  ${red}Отсутствуют${reset} конкретные порты для удаления"
        return
    fi

    if [ -z "$ports" ]; then
        new_ports=""
        echo -e "  Все порты ${green}успешно очищены${reset}\n  При запуске прокси-клиент будет работать на ${yellow}всех${reset} портах"
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
    fi
	chmod +x $initd_dir/S24xray
	chmod 755 $initd_dir/S24xray

        $initd_dir/S24xray restart on

}

add_ports_exclude() {
    ports=$1
    # Нормализация портов - удаление пробелов и преобразование разделителей в запятые
    ports=$(echo "$ports" | tr -s '[:space:]' ',' | tr -s ',' | tr ',' '\n' | sort -nu | tr '\n' ',' | sed 's/,$//')

    current_ports=$(
        awk -F= '/port_exclude/{print $2; exit}' $initd_dir/S24xray \
        | tr -d '"'
    )
    current_ports=${current_ports:-""}

    # Удаляем возможную запятую в начале
    current_ports=$(echo "$current_ports" | sed 's/^,//')

    # Соединяем текущие порты с переданными и удаляем дубликаты
    new_ports=""
    if [ -z "$current_ports" ]; then
        new_ports="$ports"
    else
        new_ports=$(echo "$current_ports,$ports" | tr ',' '\n' | sort -nu | tr '\n' ',' | sed 's/,$//')
    fi

    added_ports=""
    duplicate_ports=""

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

    tmpfile=$(mktemp)
    awk -v new="port_exclude=\"$new_ports\"" 'BEGIN{replaced=0} /port_exclude/ && !replaced {sub(/port_exclude="[^"]*"/, new); replaced=1} {print}' $initd_dir/S24xray > "$tmpfile" && mv "$tmpfile" $initd_dir/S24xray

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
	chmod +x $initd_dir/S24xray
	chmod 755 $initd_dir/S24xray

        $initd_dir/S24xray restart on

}



dell_ports_exclude() {
    ports="$1"
    # Нормализация портов - удаление пробелов и преобразование разделителей в запятые
    ports=$(echo "$ports" | tr -s '[:space:]' ',' | tr -s ',' | tr ',' '\n' | sort -nu | tr '\n' ',' | sed 's/,$//')

    current_ports=$(
        awk -F= '/port_exclude/{print $2; exit}' "$initd_dir/S24xray" \
        | tr -d '"'
    )
    new_ports="$current_ports"
    deleted_ports=""
    not_found_ports=""

    if [ -z "$current_ports" ]; then
        echo -e "  Прокси-клиент работает на ${yellow}всех${reset} портах\n  ${red}Отсутствуют${reset} конкретные порты для удаления"
        return
    fi

    if [ -z "$ports" ]; then
        new_ports=""
        echo -e "  ${green}Успех${reset}"
		echo -e "  Все порты очищены\n  При запуске прокси-клиент будет работать на ${yellow}всех${reset} портах"
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
	chmod +x $initd_dir/S24xray
	chmod 755 $initd_dir/S24xray

        $initd_dir/S24xray restart on

}