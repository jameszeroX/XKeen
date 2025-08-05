about_xkeen() {
    echo
    printf "  Утилита ${green}XKeen${reset} предназначена для управления межсетевым\n  экраном роутера ${yellow}Keenetic${reset}, защищающим домашнюю сеть.\n  Разработчики ${red}не несут ответственности${reset} за использование\n  ${green}XKeen${reset} вне прямого назначения. Перед использованием убедитесь,\n  что ваши действия соответствуют законодательству вашей страны.\n  Использование ${green}XKeen${reset} в противоправных целях ${red}строго запрещено${reset}.\n"
}

author_donate() {
    echo
    echo "  Выберите удобный для Вас способ:"
    echo
    echo -e "  Поддержать автора оригинального XKeen (${green}Skrill0${reset})"
    echo "     1. Т-Банк"
    echo "     2. DonationAlerts/ЮMoney"
    echo "     3. Crypto"
    echo
    echo -e "  Поддержать разработчика форка XKeen (${green}jameszero${reset})"
    echo "     4. Карта МИР"
    echo "     5. CloudTips/ЮMoney"
    echo "     6. Crypto"
    echo
    echo "     0. Отмена"
    echo

    while true; do
        read -r -p "  Ваш выбор: " choice
        case "$choice" in
            1)
                echo
                echo -e "  ${yellow}Прямая ссылка${reset}"
                echo "     https://www.tbank.ru/rm/krasilnikova.alina18/G4Z9433893"
                echo
                echo -e "  ${yellow}Номер карты${reset}"
                echo "     2200 7008 8716 3128"
                echo
                return 0
                ;;
            2)
                echo
                echo -e "  ${yellow}Прямая ссылка DonationAlerts${reset}"
                echo "     https://www.donationalerts.com/r/skrill0"
                echo
                echo -e "  ${yellow}Прямая ссылка ЮMoney${reset}"
                echo "     https://yoomoney.ru/to/410018052017678"
                echo
                echo -e "  ${yellow}Номер ЮMoney-кошелька${reset}"
                echo "     4100 1805 201 7678"
                echo
                return 0
                ;;
            3)
                echo
                echo -e "  ${yellow}USDT${reset}, TRC20"
                echo "     tsc6emx5khk4cpyfkwj7dusybokravxs3m"
                echo
                echo -e "  ${yellow}USDT${reset}, ERC20 и BEP20"
                echo "     0x4a0369a762e3a23cc08f0bbbf39e169a647a5661"
                echo
                return 0
                ;;
            4)
                echo
                echo -e "  ${yellow}Карта МИР${reset} ЮMoney"
                echo "     2204 1201 2976 4110"
                echo
                return 0
                ;;
            5)
                echo
                echo -e "  ${yellow}Прямая ссылка CloudTips${reset}"
                echo "     https://pay.cloudtips.ru/p/7edb30ec"
                echo
                echo -e "  ${yellow}Прямая ссылка ЮMoney${reset}"
                echo "     https://yoomoney.ru/to/41001350776240"
                echo
                echo -e "  ${yellow}Номер ЮMoney-кошелька${reset}"
                echo "     4100 1350 7762 40"
                echo
                return 0
                ;;
            6)
                echo
                echo -e "  ${yellow}USDT${reset}, TRC20"
                echo "     TB9dLwzNdLB6QeKV6w4FjCACSarePb32Dg"
                echo
                echo -e "  ${yellow}USDT${reset}, TON"
                echo "     UQDHmmyz0e1K07Wf7aTVtdmcGzCPfo4Pf7uBi_Id8TDI6Da6"
                echo
                return 0
                ;;
            0)
                echo
                echo -e "  ${yellow}Спасибо${reset}, что ознакомились с возможностью поддержать разработчиков"
                echo
                return 0
                ;;
            *)
                echo -e "  ${red}Некорректный ввод${reset}"
                ;;
        esac
    done
}

author_feedback() {
    echo
    echo -e "  ${green}Контакты разработчиков${reset}"
    echo
    echo -e "  ${light_blue}Автор оригинального XKeen${reset}:"
    echo -e "  ${yellow}Профиль на форуме keenetic${reset}:"
    echo "     https://forum.keenetic.ru/profile/73583-skrill0"
    echo -e "  ${yellow}e-mail${reset}:"
    echo "     alinajoeyone@gmail.com"
    echo -e "  ${yellow}telegram${reset}:"
    echo "     @Skrill_zerro"
    echo -e "  ${yellow}telegram помощника${reset}:"
    echo "     @skride"
    echo
    echo -e "  ${light_blue}Разработчик форка XKeen${reset}:"
    echo -e "  ${yellow}Профиль на форуме keenetic${reset}:"
    echo "     https://forum.keenetic.ru/profile/20945-jameszero"
    echo -e "  ${yellow}e-mail${reset}:"
    echo "     admin@jameszero.net"
    echo -e "  ${yellow}telegram${reset}:"
    echo "     @jameszero"
    echo -e "  ${yellow}сайт${reset}:"
    echo "     https://jameszero.net"
    echo -e "  ${yellow}GitHub${reset}:"
    echo "     https://github.com/jameszeroX"
    echo
    echo -e "  Предоставленные выше контакты предназначены ${green}для личной переписки${reset}, а ${red}не для консультаций${reset}"
    echo "  Возникающие вопросы по XKeen, задавайте в телеграм-чате https://t.me/+SZWOjSlvYpdlNmMy"
}

help_xkeen() {
        echo
        echo -e "${yellow}Установка${reset}"
        echo -e "	-i	${italic}	Основной режим установки XKeen + Xray + GeoFile + Mihomo${reset}"
        echo -e "	-io	${italic}	OffLine установка XKeen${reset}"
        echo
        echo -e "${yellow}Обновление${reset}"
        echo -e "	-uk	${italic}	XKeen${reset}"
        echo -e "	-ug	${italic}	GeoFile${reset}"
        echo -e "	-ux	${italic}	Xray${reset} (повышение/понижение версии)"
        echo -e "	-um	${italic}	Mihomo${reset} (повышение/понижение версии)"
        echo
        echo -e "${yellow}Включение или изменение задачи автообновления${reset}"
        echo -e "	-ugc	${italic}	GeoFile${reset}"
        echo
        echo -e "${yellow}Регистрация в системе${reset}"
        echo -e "	-rrk	${italic}	XKeen${reset}"
        echo -e "	-rrx	${italic}	Xray${reset}"
        echo -e "	-rrm	${italic}	Mihomo${reset}"
        echo -e "	-ri	${italic}	Автозапуск XKeen средствами init.d${reset}"
        echo
        echo -e "${red}Удаление${reset} | Утилиты и компоненты"
        echo -e "	-remove	${italic}	Полная деинсталляция XKeen${reset}"
        echo -e "	-dgs	${italic}	GeoSite${reset}"
        echo -e "	-dgi	${italic}	GeoIP${reset}"
        echo -e "	-dx	${italic}	Xray${reset}"
        echo -e "	-dm	${italic}	Mihomo${reset}"
        echo -e "	-dt	${italic}	Временные файлы${reset}"
        echo -e "	-dk	${italic}	XKeen${reset}"
        echo
        echo -e "${red}Удаление${reset} | Задачи автообновления"
        echo -e "	-dgc	${italic}	GeoFile${reset}"
        echo
        echo -e "${red}Удаление${reset} | Регистрации в системе"
        echo -e "	-drk	${italic}	XKeen${reset}"
        echo -e "	-drx	${italic}	Xray${reset}"
        echo -e "	-drm	${italic}	Mihomo${reset}"
        echo
        echo -e "${green}Порты${reset} | Через которые работает прокси-клиент"
        echo -e "	-ap	${italic}	Добавить${reset}"
        echo -e "	-dp	${italic}	Удалить${reset}"
        echo -e "	-cp	${italic}	Посмотреть${reset}"
        echo
        echo -e "${green}Порты${reset} | Исключенные из работы прокси-клиента"
        echo -e "	-ape	${italic}	Добавить${reset}"
        echo -e "	-dpe	${italic}	Удалить${reset}"
        echo -e "	-cpe	${italic}	Посмотреть${reset}"
        echo
        echo -e "${green}Переустановка${reset}"
        echo -e "	-k	${italic}	XKeen${reset}"
        echo -e "	-g	${italic}	GeoFile${reset}"
        echo
        echo -e "${green}Резервная копия XKeen${reset}"
        echo -e "	-kb	${italic}	Создание${reset}"
        echo -e "	-kbr	${italic}	Восстановление${reset}"
        echo
        echo -e "${green}Резервная копия конфигурации Xray${reset}"
        echo -e "	-cb	${italic}	Создание${reset}"
        echo -e "	-cbr	${italic}	Восстановление${reset}"
        echo
        echo -e "${green}Резервная копия конфигурации Mihomo${reset}"
        echo -e "	-mb	${italic}	Создание${reset}"
        echo -e "	-mbr	${italic}	Восстановление${reset}"
        echo
        echo -e "${light_blue}Управление прокси-клиентом${reset}"
        echo -e "	-start	${italic}	Запуск${reset}"
        echo -e "	-stop	${italic}	Остановка${reset}"
        echo -e "	-restart${italic}	Перезапуск${reset}"
        echo -e "	-status	${italic}	Статус работы${reset}"
        echo -e "	-tpx	${italic}	Порты, шлюз и протокол прокси-клиента${reset}"
        echo -e "	-auto	${italic}	Включить | Отключить автозапуск прокси-клиента${reset}"
        echo -e "	-d	${italic}	Установить задержку автозапуска прокси-клиента${reset}"
        echo -e "	-fd	${italic}	Включить | Отключить контроль файловых дескрипторов, открытых прокси-клиентом${reset}"
        echo -e "	-diag	${italic}	Выполнить диагностику${reset}"
        echo -e "	-channel${italic}	Переключить канал получения обновлений XKeen (Stable/Dev версия)${reset}"
        echo -e "	-xray	${italic}	Переключить XKeen на ядро Xray${reset}"
        echo -e "	-mihomo	${italic}	Переключить XKeen на ядро Mihomo${reset}"
        echo
        echo -e "${light_blue}Управление модулями${reset}"
        echo -e "	-modules ${italic}	Перенос модулей для XKeen в пользовательскую директорию${reset}"
        echo
        echo -e "${light_blue}Информация${reset}"
        echo -e "	-about	${italic}	О программе${reset}"
        echo -e "	-ad	${italic}	Поддержать разработчиков${reset}"
        echo -e "	-af	${italic}	Обратная связь${reset}"
        echo -e "	-v	${italic}	Версия XKeen${reset}"
}