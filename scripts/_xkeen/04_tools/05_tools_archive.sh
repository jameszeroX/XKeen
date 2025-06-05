# Архивирование xkeen для релиза
archive_xkeen() {
    # Создаем временную директорию
    cp -r "$install_dir/.xkeen" "$tmp_dir"
    cp "$install_dir/xkeen" "$tmp_dir"
    mv "$tmp_dir/.xkeen" "$tmp_dir/_xkeen"
	
	# Создаем директорию релизов
	mkdir -p "$releases_dir" || { echo "Ошибка: Не удалось создать директорию $releases_dir"; exit 1; }

    # Создаем архив
    tar -cf "$tmp_dir/xkeen_v$xkeen_current_version.tar" -C "$tmp_dir" _xkeen xkeen

    # Перемещаем архив в директорию релизов
    mv "$tmp_dir/xkeen_v$xkeen_current_version.tar" "$releases_dir"

    # Удаляем временные файлы
    rm -r "$tmp_dir/_xkeen"
    rm "$tmp_dir/xkeen"
}