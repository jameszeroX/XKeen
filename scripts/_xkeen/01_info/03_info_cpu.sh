# Функция для получения информации о процессоре
info_cpu() {
    # Определение переменных
    cpuinfo=$(grep -i 'model name' /proc/cpuinfo | sed -e 's/.*: //i' | tr '[:upper:]' '[:lower:]')

    # Попытка определить архитектуру из uname или /proc/cpuinfo
    case "$(uname -m | tr '[:upper:]' '[:lower:]')" in
        *'armv5tel'* | *'armv6l'* | *'armv7'*)
            architecture='arm32-v5'
            ;;
        *'armv8'* | *'aarch64'* | *'cortex-a'* )
            architecture='arm64-v8a'
            ;;
        *'mips64le'* )
            architecture='mips64le'
            ;;
        *'mips64'* )
            architecture='mips64'
            ;;
        *'mipsle'* | *'mips 1004'* | *'mips 34'* | *'mips 24'* )
            architecture='mips32le'
            ;;
        *'mips'* )
            architecture='mips32'
            ;;
        *)
            # Если архитектура не определена, используем резервную проверку /proc/cpuinfo
            if echo "${cpuinfo}" | grep -q -e 'armv8' -e 'aarch64' -e 'cortex-a'; then
                architecture='arm64-v8a'
            elif echo "${cpuinfo}" | grep -q 'mips64le'; then
                architecture='mips64le'
            elif echo "${cpuinfo}" | grep -q 'mips64'; then
                architecture='mips64'
            elif echo "${cpuinfo}" | grep -q -e 'mips32le' -e 'mips 1004' -e 'mips 34' -e 'mips 24'; then
                architecture='mips32le'
            elif echo "${cpuinfo}" | grep -q 'mips'; then
                architecture='mips32'
            fi
            ;;
    esac

    # Проверка Little Endian с помощью lscpu только при архитектуре "mips64" или "mips32"
    if [ "${architecture}" = 'mips64' ] || [ "${architecture}" = 'mips32' ]; then
        if [ "${info_packages_lscpu}" = "not_installed" ]; then
            opkg install lscpu &>/dev/null
        fi

        lscpu_output="$(lscpu 2>/dev/null | tr '[:upper:]' '[:lower:]')"
        if echo "${lscpu_output}" | grep -q "little endian"; then
            architecture="${architecture}le"
        fi
    fi

    # Получение информации о архитектуре из файла состояния (status_file)
    status_architecture=$(grep -m 1 '^Architecture:' "${status_file}" | awk '{print $2}')
}