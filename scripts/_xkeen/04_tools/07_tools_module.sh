migration_modules() {
    modules="xt_multiport.ko xt_TPROXY.ko xt_owner.ko xt_socket.ko"

    if [ ! -d "${user_modules}" ]; then
        echo -e "  Целевая директория ${color_yellow}не существует${color_reset}"
        echo "     Выполняется создание директории"
        mkdir -p "${user_modules}"
    fi

    for module in $modules; do
        cp "${os_modules}/$module" "${user_modules}"
        if [ $? -ne 0 ]; then
            echo -e "  ${color_red}Ошибка${color_reset} при копировании модуля $module"
			echo -e "     Проверьте, установлены ли у Вас компоненты роутера '${color_yellow}IPv6${color_reset}' и '${color_yellow}Модули ядра Netfilter${color_reset}'"
            exit 1
        fi
    done

    echo -e "  Модули ${color_green}успешно${color_reset} скопированы."
	echo -e "  Если у Вас нет нужды в компонентах '${color_yellow}IPv6${color_reset}' и '${color_yellow}Модули ядра Netfilter${color_reset}', то их можно удалить."
}
