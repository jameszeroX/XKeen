# Функция для проверки наличия необходимых пакетов
info_packages() {
    package_name="$1"

    # Newline-prefix эмулирует якорь "^pkg ", чтобы libc не матчил libcurl
    case "
$_packages_cache" in
        *"
$package_name "*) package_status="installed" ;;
        *) package_status="not_installed" ;;
    esac
}

# Формирует кэш установленных пакетов (по одному имени с пробелом на строку).
# Основной источник — файл статуса opkg ($status_file): он не требует форка
# opkg и не зависит от блокировки базы opkg, которую может держать другой
# процесс. Запасной источник — `opkg list-installed`.
_read_installed_packages() {
    _packages_cache=""

    if [ -r "$status_file" ]; then
        _packages_cache=$(awk 'BEGIN { RS = ""; FS = "\n" } {
            name = ""; ok = 0
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^Package: /) name = substr($i, 10)
                else if ($i ~ /^Status: .* installed$/) ok = 1
            }
            if (ok && name != "") print name " "
        }' "$status_file" 2>/dev/null)
    fi

    if [ -z "$_packages_cache" ]; then
        _packages_cache=$(opkg list-installed 2>/dev/null)
    fi
}

# Кэширует список установленных пакетов один раз вместо opkg-форка на каждую
# проверку и определяет статус нужных пакетов. Вызывается явно из scripts/xkeen
# для команд, которым self-heal пакетов действительно нужен, а не безусловно
# на этапе source — см. commit.
#
# Если список получить не удалось (пустой или без базовых пакетов libc/opkg,
# которые есть в любом рабочем Entware), функция возвращает 1 и выставляет
# packages_info_ok=0. Статусы пакетов в этом случае не определяются, и
# _ensure_installed_packages ничего не устанавливает: пустой список —
# признак сбоя чтения, а не отсутствия всех пакетов.
_load_packages_info() {
    packages_info_ok=0
    _read_installed_packages

    case "
$_packages_cache" in
        *"
libc "*|*"
opkg "*) packages_info_ok=1 ;;
        *)
            echo -e "  ${yellow}Не удалось получить список пакетов Entware${reset}. Проверка необходимых пакетов пропущена" >&2
            return 1
            ;;
    esac

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

    # Проверка наличия пакета "ip-full"
    info_packages "ip-full"
    info_packages_ip_full=$package_status

    # Проверка наличия пакета "ca-bundle"
    info_packages "ca-bundle"
    info_packages_cabundle=$package_status

    # Проверка наличия пакета "iptables"
    info_packages "iptables"
    info_packages_iptables=$package_status

    # Проверка наличия пакета "ipset"
    info_packages "ipset"
    info_packages_ipset=$package_status

    # Проверка наличия пакета "conntrack"
    info_packages "conntrack"
    info_packages_conntrack=$package_status
}
