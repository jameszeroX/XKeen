# Проверка наличия задач автоматического обновления в cron
info_cron() {
    # Получаем текущую crontab конфигурацию для пользователя root
    cron_output=$(crontab -l -u root 2>/dev/null)

    # Проверяем наличие задачи с ключевым словом "ug" в crontab
    if echo "$cron_output" | grep -q "ug"; then
        info_update_geofile_cron="installed"
    else
        info_update_geofile_cron="not_installed"
    fi
}
