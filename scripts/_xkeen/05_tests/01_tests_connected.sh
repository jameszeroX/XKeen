test_connection() {
    result=1

    curl -I -m 5 https://google.com >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        result=0
    fi

    curl -I -m 5 https://ya.ru >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        result=0
    fi

    if [ "$result" -eq 0 ]; then
        printf "  ${red}Отсутствует${reset} интернет-соединение\n"
        exit 1
    fi
}
