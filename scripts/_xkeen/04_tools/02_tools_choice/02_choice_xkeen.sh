# Запрос на смену канала обновлений XKeen (Stable/Dev)
choice_channel_xkeen() {
    if [ "$xkeen_build" = "Stable" ]; then
        echo -e "  Текущий канал обновлений ${yellow}XKeen${reset}: Стабильная версия (${green}Stable${reset})"
        read -r -p "  Хотите переключиться на канал разработки? (y/N) либо (д/Н): " choice
        if echo "$choice" | grep -iq "^[yд]"; then
            choice_build="Dev"
        else
            echo "  Остаёмся на XKeen из стабильной ветки"
        fi
    else
        echo -e "  Текущий канал обновлений ${yellow}XKeen${reset}: Версия в разработке (${green}$xkeen_build${reset})"
        read -r -p "  Хотите переключиться на канал стабильной версии? (y/N) либо (д/Н): " choice
        if echo "$choice" | grep -iq "^[yд]"; then
            choice_build="Stable"
        else
            echo "  Остаёмся на XKeen из ветки разработки"
        fi
    fi
}