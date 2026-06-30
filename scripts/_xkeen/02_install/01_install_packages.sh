# Установка необходимых пакетов
install_packages() {
    package_status="$1"
    package_name="$2"

    if [ "${package_status}" = "not_installed" ]; then
        if [ ! -e "/tmp/.xkeen_opkg_updated" ]; then
            opkg update >/dev/null 2>&1 && touch "/tmp/.xkeen_opkg_updated"
        fi
        opkg install "$package_name" >/dev/null 2>&1
        opkg_rc=$?
        if [ "$opkg_rc" -ne 0 ]; then
            echo "  Ошибка установки пакета: $package_name (opkg rc=$opkg_rc)" >&2
            return 1
        fi
    fi
}

install_packages "$info_packages_curl" "curl"
install_packages "$info_packages_jq" "jq"
install_packages "$info_packages_ip_full" "ip-full"
install_packages "$info_packages_iptables" "iptables"
install_packages "$info_packages_ipset" "ipset"
install_packages "$info_packages_cabundle" "ca-bundle"
install_packages "$info_packages_uname" "coreutils-uname"
install_packages "$info_packages_nohup" "coreutils-nohup"