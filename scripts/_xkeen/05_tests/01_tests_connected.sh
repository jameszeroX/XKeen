test_connection() {
    result=1

    if ! curl -I -m 10 https://max.ru >/dev/null 2>&1 && \
       ! curl -I -m 10 https://ok.ru >/dev/null 2>&1; then
        result=0
    fi

    if [ "$result" -eq 0 ]; then
        printf "  ${red}Отсутствует${reset} интернет-соединение\n"
        exit 1
    fi
}

test_entware() {
    repo_url=$(awk '/^src/ {print $3; exit}' /opt/etc/opkg.conf)
    
    if [ -z "$repo_url" ]; then
        printf "  ${red}Не удалось${reset} определить используемый репозиторий Entware\n"
        exit 1
    fi
    
    if curl -m 10 -s --head "$repo_url" >/dev/null; then
        opkg update >/dev/null 2>&1
        opkg upgrade >/dev/null 2>&1
        info_packages
        install_packages
    else
        printf "  Репозиторий Entware ${red}недоступен${reset}\n"
        printf "  Укажите рабочее зеркало репозитория в файле ${yellow}/opt/etc/opkg.conf${reset}\n"
        exit 1
    fi
}