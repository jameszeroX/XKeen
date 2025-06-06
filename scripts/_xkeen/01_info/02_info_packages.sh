# Функция для проверки наличия необходимых пакетов
info_packages() {
    package_name="$1"
    
    # Проверяем, установлен ли пакет
    if opkg list-installed | grep -q "$package_name"; then
        package_status="installed"
    else
        package_status="not_installed"
    fi
}

# Проверка наличия пакета "lscpu"
info_packages "lscpu"
info_packages_lscpu=$package_status

# Проверка наличия пакета "coreutils-uname"
info_packages "coreutils-uname"
info_packages_uname=$package_status

# Проверка наличия пакета "coreutils-nohup"
info_packages "coreutils-nohup"
info_packages_nohup=$package_status

# Проверка наличия пакета "curl"
info_packages "curl"
info_packages_curl=$package_status

# Проверка наличия пакета "jq"
info_packages "jq"
info_packages_jq=$package_status

# Проверка наличия пакета "libc"
info_packages "libc"
info_packages_libc=$package_status

# Проверка наличия пакета "libssp"
info_packages "libssp"
info_packages_libssp=$package_status

# Проверка наличия пакета "librt"
info_packages "librt"
info_packages_librt=$package_status

# Проверка наличия пакета "libpthread"
info_packages "libpthread"
info_packages_libpthread=$package_status

# Проверка наличия пакета "ca-bundle"
info_packages "ca-bundle"
info_packages_cabundle=$package_status

# Проверка наличия пакета "iptables"
info_packages "iptables"
info_packages_iptables=$package_status