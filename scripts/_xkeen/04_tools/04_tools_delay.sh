# Вспомогательная функция для получения текущего значения любого параметра
_get_delay_param() {
    local param_name="$1"
    local file_path="$2"
    awk -F= -v p="$param_name" '$0 ~ "^[[:space:]]*" p "=" {print $2; exit}' "$file_path" | tr -d '[:space:]"'
}

# Общая функция для управления задержками
_manage_delay() {
    local param_name="$1"
    local display_name="$2"
    local new_delay="$3"

    if [ ! -f "$initd_file" ]; then
        echo -e "  ${red}Ошибка${reset}: Не найден файл автозапуска ${yellow}S05xkeen${reset}"
        return 1
    fi

    local current_delay
    current_delay=$(_get_delay_param "$param_name" "$initd_file")

    if [ -z "$new_delay" ]; then
        echo -e "  Текущая задержка ${display_name} ${yellow}${current_delay} секунд(ы)${reset}"
        return 0
    fi

    case "$new_delay" in
        ''|*[!0-9]*)
            echo -e "  ${red}Ошибка${reset}"
            echo "  Новая задержка должна быть числом"
            return 1
        ;;
    esac

    if [ "$current_delay" = "$new_delay" ]; then
        echo "  Обновление задержки ${display_name} не требуется"
        return 0
    fi

    local tmpfile
    tmpfile=$(mktemp) || return 1

    awk -v d="$new_delay" -v p="$param_name" '
    $0 ~ "^[[:space:]]*" p "=" && !done {
        sub(/=.*/, "=" d)
        done=1
    }
    {print}
    ' "$initd_file" > "$tmpfile" && mv "$tmpfile" "$initd_file"

    if [ "$(_get_delay_param "$param_name" "$initd_file")" = "$new_delay" ]; then
        echo -e "  Установлена задержка ${display_name} ${yellow}${new_delay} секунд(ы)${reset}"
    else
        echo -e "  ${red}Ошибка${reset}: не удалось обновить параметр"
        return 1
    fi
}

# Управление задержкой автозапуска (start_delay)
delay_autostart() {
    _manage_delay "start_delay" "автозапуска XKeen" "$1"
}

# Управление задержкой инициализации (init_delay)
delay_init() {
    _manage_delay "init_delay" "инициализации XKeen" "$1"
}