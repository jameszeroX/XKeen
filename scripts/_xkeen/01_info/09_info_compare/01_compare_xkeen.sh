# Функция для сравнения версий XKeen и сохранения результата в переменной
info_compare_xkeen() {
    # Сравниваем текущую версию XKeen с версией из GitHub
    if [ "$xkeen_current_version" = "$xkeen_github_version" ]; then
        info_compare_xkeen="actual" # Если версии совпадают, XKeen актуален
		
    elif [ "$xkeen_current_version" \< "$xkeen_github_version" ]; then
        info_compare_xkeen="update" # Если текущая версия меньше версии из GitHub, требуется обновление
    else
        info_compare_xkeen="not_release" # Если версия из GitHub меньше текущей версии (не выпущена), XKeen не выпущен
    fi
}
