# Обновление списков пакетов opkg: не чаще одного раза за сессию (маркер в rundir)
_opkg_update_once() {
    _xkeen_rundir=$(_xkeen_secure_rundir) || _xkeen_rundir=""
    if [ -z "$_xkeen_rundir" ] || [ ! -e "$_xkeen_rundir/opkg_updated" ]; then
        opkg update >/dev/null 2>&1 && [ -n "$_xkeen_rundir" ] && touch "$_xkeen_rundir/opkg_updated"
    fi
}

# Установка необходимых пакетов
install_packages() {
    package_status="$1"
    package_name="$2"

    if [ "${package_status}" = "not_installed" ]; then
        # Повторная независимая проверка: opkg install для уже установленного
        # пакета — это не установка, а обновление до версии из репозитория
        # (без обновления зависимостей), что может сломать пакет.
        if opkg status "$package_name" 2>/dev/null | grep -q '^Status: .* installed$'; then
            return 0
        fi

        _opkg_update_once

        echo "  Устанавливаю недостающий пакет: $package_name" >&2
        opkg_log=$(mktemp 2>/dev/null) || opkg_log="/dev/null"
        opkg install "$package_name" >"$opkg_log" 2>&1
        opkg_rc=$?
        if [ "$opkg_rc" -ne 0 ]; then
            echo "  Ошибка установки пакета: $package_name (opkg rc=$opkg_rc)" >&2
            [ "$opkg_log" != "/dev/null" ] && tail -n 5 "$opkg_log" 2>/dev/null | sed 's/^/    /' >&2
        fi
        [ "$opkg_log" != "/dev/null" ] && rm -f "$opkg_log"
        return "$opkg_rc"
    fi
}

# Проверка работоспособности пакета: бинарник должен запускаться.
# Критерий — код возврата `<команда> --version`, а не наличие вывода в stderr:
# рабочие программы могут писать предупреждения (например, ipset сообщает о
# разнице версий протокола ядра и userspace, но завершается с кодом 0).
# Для пакетов без проверки возвращает 0. В $_pkg_health_err остаётся stderr
# проверки (для диагностики и поиска недостающей библиотеки).
_check_package_health() {
    _pkg_health_err=""
    case "$1" in
        curl|jq|iptables|ipset) ;;
        *) return 0 ;;
    esac
    _pkg_health_err=$("$1" --version 2>&1 >/dev/null)
}

# Имя недостающей библиотеки из сообщения динамического загрузчика
# (glibc, uClibc, musl). Пусто, если сообщение другого рода.
_missing_lib_from_error() {
    printf '%s\n' "$1" | sed -n \
        -e 's/.*loading shared librar[a-z]*: \([^:]*\):.*/\1/p' \
        -e "s/.*can't load library '\([^']*\)'.*/\1/p" \
        -e 's/.*Error loading shared library \([^:]*\):.*/\1/p' | head -n 1
}

# Имя пакета Entware, содержащего библиотеку (libnghttp2.so.14 -> libnghttp2)
_lib_to_package() {
    case "$1" in
        libssl.so*|libcrypto.so*) echo "libopenssl" ;;
        libz.so*)                 echo "zlib" ;;
        *)                        echo "${1%%.so*}" ;;
    esac
}

# Чинит пакет, который установлен, но не запускается из-за недостающей
# библиотеки. opkg считает такой пакет установленным и на обычный
# `opkg install` ответит «up to date», поэтому библиотечный пакет
# переустанавливается с --force-reinstall. Одна починка может открыть
# следующую недостающую библиотеку, поэтому цикл ограничен 4 шагами.
_repair_package() {
    package_name="$1"
    repair_tried=" "
    repair_round=0

    while [ "$repair_round" -lt 4 ]; do
        missing_lib=$(_missing_lib_from_error "$_pkg_health_err")
        [ -n "$missing_lib" ] || break

        repair_pkg=$(_lib_to_package "$missing_lib")
        # Тот же пакет уже переустанавливали, а проблема осталась — не зацикливаемся
        case "$repair_tried" in *" $repair_pkg "*) break ;; esac
        repair_tried="$repair_tried$repair_pkg "

        _opkg_update_once
        opkg info "$repair_pkg" 2>/dev/null | grep -q '^Package: ' || break

        echo "  Пакет $package_name не запускается: не найдена библиотека $missing_lib. Переустанавливаю пакет: $repair_pkg" >&2
        opkg install --force-reinstall "$repair_pkg" >/dev/null 2>&1

        _check_package_health "$package_name" && return 0
        repair_round=$((repair_round + 1))
    done

    echo "  Пакет $package_name установлен, но не запускается: $(printf '%s\n' "$_pkg_health_err" | head -n 1)" >&2
    echo "  Устраните проблему вручную, например: opkg install --force-reinstall <пакет с недостающей библиотекой>" >&2
    return 1
}

# Проверяет, что установленные пакеты не просто числятся в базе opkg, но и
# запускаются. Отсутствующие бинарники пропускаются: ошибку их установки
# уже показал install_packages().
_verify_installed_packages() {
    for verify_pkg in curl jq iptables ipset; do
        command -v "$verify_pkg" >/dev/null 2>&1 || continue
        _check_package_health "$verify_pkg" || _repair_package "$verify_pkg"
    done
}

# Устанавливает отсутствующие пакеты по данным _load_packages_info() и проверяет
# работоспособность установленных. Вызывается явно из scripts/xkeen вместе с
# _load_packages_info(). Если список установленных пакетов получить не удалось,
# ничего не делает.
_ensure_installed_packages() {
    [ "${packages_info_ok:-0}" = "1" ] || return 0

    install_packages "$info_packages_curl" "curl"
    install_packages "$info_packages_jq" "jq"
    install_packages "$info_packages_ip_full" "ip-full"
    install_packages "$info_packages_iptables" "iptables"
    install_packages "$info_packages_ipset" "ipset"
    install_packages "$info_packages_cabundle" "ca-bundle"
    install_packages "$info_packages_uname" "coreutils-uname"
    install_packages "$info_packages_nohup" "coreutils-nohup"
    install_packages "$info_packages_conntrack" "conntrack"

    _verify_installed_packages
    return 0
}
