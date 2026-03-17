# Установка необходимых пакетов
install_packages() {
    package_status="$1"
    package_name="$2"

    if [ "${package_status}" = "not_installed" ]; then
        opkg install "$package_name" &>/dev/null
    fi
}

install_packages "$info_packages_curl" "curl"
install_packages "$info_packages_jq" "jq"
install_packages "$info_packages_libc" "libc"
install_packages "$info_packages_libssp" "libssp"
install_packages "$info_packages_librt" "librt"
install_packages "$info_packages_iptables" "iptables"
install_packages "$info_packages_libpthread" "libpthread"
install_packages "$info_packages_ipset" "ipset"
install_packages "$info_packages_cabundle" "ca-bundle"
install_packages "$info_packages_uname" "coreutils-uname"
install_packages "$info_packages_nohup" "coreutils-nohup"