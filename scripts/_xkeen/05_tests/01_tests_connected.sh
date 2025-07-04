tests_connection() {
    result=1
    
    # Проверка соединения с google.com
    if ping -c 4 google.com > /dev/null 2>&1; then
        result=0
    else
        echo -e "  ${red}Ошибка${reset}: Не удалось пинговать google.com"
    fi

    # Проверка соединения с yandex.ru
    if ping -c 4 yandex.ru > /dev/null 2>&1; then
        result=0
    else
        echo -e "  ${red}Ошибка${reset}: Не удалось пинговать yandex.ru"
    fi

    # Проверяем код завершения функции и выводим сообщение
    if [ $result -eq 0 ]; then
        echo -e "  Интернет-соединение ${green}работает${reset}"
    else
        echo -e "  ${red}Отсутствует${reset} интернет-соединение"
    fi
	
    return 1
}
