# Информация об авторе

author_donate() {
	echo
    echo "  Выберите удобный для Вас способ перевода:"
    echo "     0. Отмена"
    echo "     1. Тинькофф"
    echo "     2. Юmoney"
    echo "     3. Crypto"
	echo

    read -p "  Ваш выбор: " choice

    case "$choice" in
        0)

            ;;
        1)
			echo
            echo -e "  ${yellow}Прямая ссылка${reset}"
			echo "     tinkoff.ru/rm/krasilnikova.alina18/g4z9433893"
			echo
            echo -e "  ${yellow}Номер карты${reset}"
			echo "     2200 7008 8716 3128"
			echo
            ;;
        2)
			echo
            echo -e "  ${yellow}Прямая ссылка${reset}"
			echo      "yoomoney.ru/to/410018052017678"
			echo
            echo -e "  ${yellow}Номер Юmoney-кошелька${reset}"
			echo "     4100 1805 201 7678"
			echo
            ;;
        3)
			echo
            echo -e "  ${yellow}usdt${reset}, trc20"
			echo "     tsc6emx5khk4cpyfkwj7dusybokravxs3m"
			echo
            echo -e "  ${yellow}usdt${reset}, erc20"
			echo "     0x4a0369a762e3a23cc08f0bbbf39e169a647a5661"
			echo
            echo -e "  ${yellow}usdt${reset}, bep20"
			echo "     0x4a0369a762e3a23cc08f0bbbf39e169a647a5661"
            ;;
        *)
            echo -e "     ${red}Некорректный выбор.${reset}"
            ;;
    esac
}

author_feedback() {
	echo
    echo "  Контакты"
    echo -e "  ${yellow}Профиль на форуме keenetic${reset}"
	echo "     forum.keenetic.com/profile/73583-skrill0"
	echo
    echo -e "  ${yellow}e-mail${reset}"
	echo "     alinajoeyone@gmail.com"
	echo
    echo -e "  ${yellow}telegram${reset}"
	echo "     t.me/Skrill_zerro"
	echo
    echo -e "  ${yellow}telegram помощника${reset}"
	echo "     t.me/skride"
    echo 
    echo -e "  Автор ${red}не обязуется${reset} предоставлять обратную связь и ${red}не несет никакой ответственности${reset}."
}
