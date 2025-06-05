# Функция для сравнения версий Xray и определения статуса
info_compare_xray() {
    # Проверяем, установлен ли Xray
    if [ -z "$xray_current_version" ]; then
        info_compare_xray="not_installed" # Если Xray не установлен, статус - не установлен
    else
        info_compare_xray="update" # Разрешаем понижение/повышение версии Xray
    fi
}
