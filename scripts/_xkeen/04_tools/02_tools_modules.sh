show_deprecation_warning() {
    echo -e "  ${red}Внимание!${reset} Команда устарела и удалена из XKeen"
    echo -e "  Компонент '${yellow}Модули ядра подсистемы Netfilter${reset}' обязателен"
    echo
}

migration_modules() {
    show_deprecation_warning && return
}

remove_modules() {
    show_deprecation_warning && return
}