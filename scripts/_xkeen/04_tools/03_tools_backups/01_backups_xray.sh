# Создание резервной копии Xray
backup_xray() {
    if [ "$xray_installed" = "installed" ]; then
        backup_filename="${current_datetime}_xray_v${xray_current_version}"
        cp "$install_dir/xray" "$backups_dir/$backup_filename"

        # Проверка успешности создания резервной копии
        if [ $? -eq 0 ]; then
            echo -e "  Резервная копия Xray создана: ${yellow}$backup_filename${reset}"
        else
            echo -e "  ${red}Ошибка${reset} при создании резервной копии Xray"
        fi
    else
        echo -e "  ${gray}Xray не установлен.${reset} Создание резервной копии невозможно"
    fi
}

# Восстановление резервной копии Xray
restore_backup_xray() {
    latest_backup=$(ls -t "$backups_dir" | grep "xray" | head -n 1)
    
    if [ -n "$latest_backup" ]; then
        backup_path="$backups_dir/$latest_backup"
        
		rm "$install_dir/xray"
		cp "$backup_path" "$install_dir/xray" 2>/dev/null

        # Проверка успешности восстановления резервной копии
        if [ $? -eq 0 ]; then
            echo -e "  Xray ${green}успешно восстановлен${reset} из резервной копии"
        else
		echo -e "  ${red}Ошибка${reset} при восстановлении Xray из резервной копии"
        fi
    else
        echo -e "  ${gray}Нет доступных резервных копий Xray${reset}"
    fi
}
