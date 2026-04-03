# Функция для получения информации о процессоре
info_cpu() {
    if command -v opkg >/dev/null 2>&1; then
        opkg_arch=$(opkg print-architecture | awk '!/all/ {print $2; exit}' | cut -d- -f1)
        
        case "$opkg_arch" in
            *'aarch64'*) architecture='arm64-v8a' ;;
            *'mipsel'*) architecture='mips32le' ;;
            *'mips'*) architecture='mips32' ;;
            *) architecture="$opkg_arch" ;;
        esac
    fi

    # Получение информации о архитектуре из файла состояния (status_file)
    status_architecture=$(grep -m 1 '^Architecture:' "${status_file}" | awk '{print $2}')
}

info_4g() {
    version="$(curl -kfsS "localhost:79/rci/show/version" 2>/dev/null)"

    case "$version" in
        *KN-1212*)
            clear
            echo
            echo -e "  ${red}Внимание${reset}: Для вашей модели роутера ${light_blue}Keenetic 4G KN-1212${reset}"
            ;;
        *KN-2910*)
            clear
            echo
            echo -e "  ${red}Внимание${reset}: Для вашей модели роутера ${light_blue}Keenetic Skipper 4G KN-2910${reset}"
            ;;
        *)
            return
            ;;
    esac

    echo "  после установки требуется подменять бинарный файл прокси-клиента"
    echo "  Подробности в телеграм-чате https://t.me/+8Cvh7oVf6cE0MWRi"
    echo
    echo "  Нажмите любую клавишу для продолжения..."
    read -r -n 1 _
echo
}