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
    printf "  ${yellow}Проверка доступности${reset} репозитория Entware. Подождите, пожалуйста...\n"
    repo_url=$(awk '/^src/ {print $3; exit}' /opt/etc/opkg.conf)

    if [ -z "$repo_url" ]; then
        printf "  ${red}Не удалось${reset} определить используемый репозиторий Entware\n"
        exit 1
    fi

    repo_url="$repo_url/Packages.gz"
    tmp_file="/tmp/pkg_check_$$"

    (curl -s "$repo_url" -o "$tmp_file" 2>/dev/null) &
    pid=$!

    i=1
    while [ $i -le 10 ]; do
        kill -0 $pid 2>/dev/null || break
        sleep 1
        i=$((i + 1))
    done

    kill -0 $pid 2>/dev/null 2>/dev/null && kill $pid 2>/dev/null
    wait $pid 2>/dev/null

    if [ -f "$tmp_file" ]; then
        size=$(wc -c < "$tmp_file" 2>/dev/null || echo 0)
        rm -f "$tmp_file"

        if [ "$size" -gt 100000 ]; then
            printf "  Репозиторий Entware ${green}доступен${reset}. Продолжаем...\n"
            opkg update >/dev/null 2>&1
            opkg upgrade >/dev/null 2>&1
            info_packages
            install_packages
            return 0
        else
            printf "  Репозиторий Entware ${red}недоступен${reset}\n"
            printf "  Укажите рабочее зеркало репозитория в файле ${yellow}/opt/etc/opkg.conf${reset}\n"
            exit 1
        fi
    else
        printf "  Репозиторий Entware ${red}недоступен${reset}\n"
        printf "  Укажите рабочее зеркало репозитория в файле ${yellow}/opt/etc/opkg.conf${reset}\n"
        exit 1
    fi
}