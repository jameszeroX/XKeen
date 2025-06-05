# Очистка журнала xkeen перед началом работы

logs_clear() {
    echo "" > "$xkeen_info_log"
    echo "" > "$xkeen_error_log"
}