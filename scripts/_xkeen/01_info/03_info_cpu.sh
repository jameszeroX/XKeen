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

    # Получение информации о необходимости softfloat банарников
    [ "$architecture" != "mips32le" ] && echo && return
    version="$(curl -kfsS "localhost:79/rci/show/version" 2>/dev/null)"

    case "$version" in
        *KN-1212*|*KN-2910*) softfloat="true" ;;
        *) echo; return ;;
    esac
}
