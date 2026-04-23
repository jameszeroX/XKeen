# Функция для получения версии из xkeen API и сохранения ее в переменной
info_version_xkeen() {
    version=$(curl --connect-timeout 10 $curl_timeout -s "$xkeen_api_url" | jq -r '.tag_name // .name // ""' 2>/dev/null)

    if [ -z "$version" ]; then
        echo
        printf "${red}Нет доступа${reset} к ${yellow}GitHub API${reset}, пробуем ${yellow}jsDelivr${reset}...\n"
        version=$(curl --connect-timeout 10 $curl_timeout -s "$xkeen_jsd_url" | jq -r '.versions | first' 2>/dev/null)

        if [ -z "$version" ]; then
            echo
            printf "  ${red}Нет доступа${reset} к ${yellow}jsDelivr${reset}\n"
            echo
            printf "${red}Ошибка${reset}: Не удалось получить версию ни с ${yellow}GitHub${reset}, ни с ${yellow}jsDelivr${reset}\n
  Проверьте соединение с интернетом или повторите позже\n
  Если ошибка сохраняется, воспользуйтесь возможностью OffLine установки:\n
  https://github.com/levmnkv/XKeen/blob/main/OffLine_install.md\n"
            echo
            exit 1
        fi
    fi

    xkeen_github_version="${version}"
}

# Функция для сравнения версий XKeen
info_compare_xkeen() {
    if [ "$xkeen_current_version" = "$xkeen_github_version" ]; then
        info_compare_xkeen="actual"
    else
        info_compare_xkeen="update"
    fi
}