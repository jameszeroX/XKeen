# Функция для получения версии из xkeen API и сохранения ее в переменной
info_version_xkeen() {
    version=$(curl -s "$xkeen_api_url" | jq -r '.tag_name // .name' 2>/dev/null)

    if [ -z "$version" ]; then
        printf "${red}Нет доступа{reset} к ${yellow}GitHub API${reset}, пробуем ${yellow}jsDelivr${reset}...\n"
        version=$(curl -s "$xkeen_jsd_url" | jq -r '.versions | first' 2>/dev/null)

        if [ -z "$version" ]; then
            printf "${red}Ошибка:${reset} Не удалось получить версию ни с ${yellow}GitHub${reset}, ни с ${yellow}jsDelivr${reset}. Проверьте соединение с интернетом или повторите позже\n"
            exit 1
        fi
    fi

    xkeen_github_version="${version#v}"
}