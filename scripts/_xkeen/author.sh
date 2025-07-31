# Информация об авторе
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
    echo "     4. Сбер/ВТБ"
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
                echo -e "  ${yellow}Сбер${reset}"
                echo "     4279 5202 6189 7055"
                echo
                echo -e "  ${yellow}ВТБ${reset}"
                echo "     2200 2459 2238 1392"
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
    echo -e "  Разработчики ${red}не несут никакой ответственности${reset} за то, как Вы будете использовать XKeen"
    echo "  Предоставленные выше контакты предназначены для личной переписки, а не для консультаций"
    echo "  Возникающие вопросы по XKeen, задавайте в телеграм-чате https://t.me/+SZWOjSlvYpdlNmMy"
}
