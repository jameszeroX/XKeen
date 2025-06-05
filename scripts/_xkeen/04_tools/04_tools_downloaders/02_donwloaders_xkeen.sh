# Загрузка xkeen

download_xkeen() {
    download_url="${xkeen_tar_url}"

        # Если URL для загрузки доступен
        if [ -n "$download_url" ]; then
            filename=$(basename "$download_url")
            extension="${filename##*.}"
            
            # Создание временной директории для загрузки файла
            mkdir -p "$tmp_dir"
            
            echo -e "  ${yellow}Выполняется загрузка${reset} XKeen"
    
            # Загрузка файла с использованием cURL и сохранение его во временной директории
            curl -L -o "/tmp/$filename" "$download_url" &> /dev/null
    
            # Если файл был успешно загружен
            if [ -e "/tmp/$filename" ]; then
                mv "/tmp/$filename" "$tmp_dir/xkeen.$extension"
                echo -e "  XKeen ${green}успешно загружен${reset}"
            fi
        else
            echo -e "  ${red}Ошибка${reset}: Не удалось загрузить XKeen. Проверьте соединение с интернетом или повторите позже"
        fi
}
