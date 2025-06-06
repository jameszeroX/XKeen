migration_modules() {
    modules="xt_multiport.ko xt_TPROXY.ko xt_owner.ko xt_socket.ko"

    if [ ! -d "${user_modules}" ]; then
        echo -e "  Целевая директория ${yellow}не существует${reset}"
        echo "  Выполняется создание директории"
        mkdir -p "${user_modules}"
    fi

    for module in $modules; do
        cp "${os_modules}/$module" "${user_modules}"
        if [ ! -f "${user_modules}/$module" ]; then
            echo -e "  ${red}Ошибка${reset} при копировании модуля $module"
            echo -e "  Проверьте, установлен ли компонент роутера '${yellow}Модули ядра подсистемы Netfilter${reset}'"
            exit 1
        fi
    done

    echo -e "  Необходимые для XKeen модули ${green}успешно${reset} скопированы"
	echo -e "  Если компонент роутера '${yellow}Модули ядра подсистемы Netfilter${reset}' не требуется, можете удалить его"
}
