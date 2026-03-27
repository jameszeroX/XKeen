# Функция для регистрации инициализационного скрипта cron
register_cron_initd() {
    # Проверка наличия пакета cron
    opkg list-installed 2>/dev/null | grep -q "^cron " && return

    # Определение переменных
    s05crond_filename="${current_datetime}_S05crond"
    required_script_version="0.6"

    # Получение текущей версии скрипта
    if [ -e "${initd_cron}" ]; then
        script_version=$(grep 'version=' "${initd_cron}" | grep -o '[0-9.]\+')
    fi

    # Содержимое скрипта
    script_content='#!/bin/sh

# Информация о службе: Запуск / Остановка Cron
# version="0.6"

green="\\033[32m"
red="\\033[31m"
yellow="\\033[33m"
reset="\\033[0m" 

cron_initd="/opt/sbin/crond"

# Функция для проверки статуса cron
cron_status() {
    if pidof crond > /dev/null; then
        return 0 # Процесс существует и работает
    else
        return 1 # Процесс не существует
    fi
}

# Функция для запуска cron
start() {
    if cron_status; then
        printf "  Cron ${yellow}уже запущен${reset}\\n"
    else
        $cron_initd -L /dev/null
        printf "  Cron ${green}запущен${reset}\\n"
    fi
}

# Функция для остановки cron
stop() {
    if cron_status; then
        killall crond
        printf "  Cron ${yellow}остановлен${reset}\\n"
    else
        printf "  Cron ${red}не запущен${reset}\\n"
    fi
}

# Функция для перезапуска cron
restart() {
    stop > /dev/null 2>&1
    sleep 1
    start > /dev/null 2>&1
    printf "  Cron ${green}перезапущен${reset}\\n"
}

# Обработка аргументов командной строки
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        if cron_status; then
            printf "  Cron ${green}запущен${reset}\\n"
        else
            printf "  Cron ${red}не запущен${reset}\\n"
        fi
        ;;
    *)
        printf "  Команды: ${green}start${reset} | ${red}stop${reset} | ${yellow}restart${reset} | status\\n"
        ;;
esac

exit 0'
    
    # Создание или замена файла, если версия скрипта не соответствует требуемой версии 
    if [ "${script_version}" != "${required_script_version}" ]; then 
        echo -e "${script_content}" > "${initd_cron}" 
        chmod +x "${initd_cron}" 
    fi 
}

# Обновление cron задач
update_cron_geofile_task() {
    if [ -f "$cron_dir/$cron_file" ]; then
        tmp_file="$cron_dir/${cron_file}.tmp"
        cp "$cron_dir/$cron_file" "$tmp_file"
        
        if [ -z "$choice_cancel_cron_select" ]; then
            grep -v -e "ug" -e "ux" -e "uk" -e '^\s*$' "$tmp_file" > "$cron_dir/$cron_file"
        else
            grep -v -e "ugi" -e "ugs" -e "ux" -e "uk" -e '^\s*$' "$tmp_file" > "$cron_dir/$cron_file"
        fi
    fi
}