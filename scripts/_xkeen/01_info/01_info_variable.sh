# -------------------------------------
# Цвета
# -------------------------------------
green="\033[92m"	# Зеленый
red="\033[91m"		# Красный
yellow="\033[93m"	# Желтый
light_blue="\033[96m"	# Голубой
italic="\033[3m"	# Курсив
reset="\033[0m"		# Сброс цветов

# -------------------------------------
# Информация
# -------------------------------------
current_datetime=$(date +"%Y-%m-%d_%H-%M")
xkeen_current_version="2.0"
xkeen_build="Beta"
build_timestamp=""

# -------------------------------------
# Директории
# -------------------------------------
tmp_dir="/opt/tmp"			 # Временная директория
ktmp_dir="$tmp_dir/xkeen"		 # Временная директория XKeen
xtmp_dir="$tmp_dir/xray"		 # Временная директория Xray
mtmp_dir="$tmp_dir/mihomo"		 # Временная директория Mihomo
install_dir="/opt/sbin"			 # Директория установки
xkeen_dir="$install_dir/.xkeen"		 # Директория скриптов XKeen
xkeen_cfg="/opt/etc/xkeen"		 # Директория конфигурации XKeen
ipset_cfg="$xkeen_cfg/ipset"		 # Директория IPSET
log_dir="/opt/var/log"			 # Директория логов
xray_log_dir="$log_dir/xray"		 # Директория логов Xray
initd_dir="/opt/etc/init.d"		 # Директория init.d
backups_dir="/opt/backups"		 # Директория бекапов
geo_dir="/opt/etc/xray/dat"		 # Директория для dat
cron_dir="/opt/var/spool/cron/crontabs"	 # Директория планировщика
mihomo_conf_dir="/opt/etc/mihomo"	 # Директория конфигурации Mihomo
xray_conf_dir="/opt/etc/xray/configs"	 # Директория конфигурации Xray
xray_conf_smpl="$xkeen_dir/02_install/08_install_configs/02_configs_xray"
register_dir="/opt/lib/opkg/info"
os_modules="/lib/modules/$(uname -r)"
user_modules="/opt/lib/modules"

# -------------------------------------
# Файлы
# -------------------------------------
xkeen_var_file="$xkeen_dir/01_info/01_info_variable.sh"
file_port_proxying="$xkeen_cfg/port_proxying.lst"
file_port_exclude="$xkeen_cfg/port_exclude.lst"
file_ip_exclude="$xkeen_cfg/ip_exclude.lst"
ru_exclude_ipv4="$ipset_cfg/ru_exclude_ipv4.lst"
ru_exclude_ipv6="$ipset_cfg/ru_exclude_ipv6.lst"
ru_override="$ipset_cfg/ru_exclude_override.lst"
xkeen_config="$xkeen_cfg/xkeen.json"
status_file="/opt/lib/opkg/status"
initd_file="$initd_dir/S05xkeen"
initd_cron="$initd_dir/S05crond"
cron_file="root"
file_netfilter_hook="/opt/etc/ndm/netfilter.d/proxy.sh"
file_schedule_hook="/opt/etc/ndm/schedule.d/00-xkeen-hotspot-sync.sh"
name_ipset_deny_mac="xkeen_deny_mac"

# -------------------------------------
# Ресурсы для проверки доступа в интернет
# -------------------------------------
conn_URL="ya.ru"
conn_IP1="195.208.4.1"
conn_IP2="77.88.44.55"

# -------------------------------------
# URL
# -------------------------------------
xkeen_api_url="https://api.github.com/repos/jameszeroX/xkeen/releases/latest"			# url api для XKeen
xkeen_jsd_url="https://data.jsdelivr.com/v1/package/gh/jameszeroX/xkeen"			# резервный url api для XKeen
xkeen_tar_url="https://github.com/jameszeroX/XKeen/releases/latest/download/xkeen.tar.gz"	# url для загрузки XKeen
xkeen_dev_url="https://raw.githubusercontent.com/jameszeroX/xkeen/main/test/xkeen.tar.gz"	# url для загрузки XKeen dev
xray_api_url="https://api.github.com/repos/XTLS/Xray-core/releases"				# url api для Xray
xray_jsd_url="https://data.jsdelivr.com/v1/package/gh/XTLS/Xray-core"				# резервный url api для Xray
xray_zip_url="https://github.com/XTLS/Xray-core/releases/download"				# url для загрузки Xray
mihomo_api_url="https://api.github.com/repos/MetaCubeX/mihomo/releases"				# url api для Mihomo
mihomo_jsd_url="https://data.jsdelivr.com/v1/package/gh/MetaCubeX/mihomo"			# резервный url api для Mihomo
mihomo_gz_url="https://github.com/MetaCubeX/mihomo/releases/download"				# url для загрузки Mihomo
yq_upstream_dist_url="https://github.com/mikefarah/yq/releases/latest/download"			# url для загрузки оригинального Yq
yq_workaround_dist_url="https://github.com/jameszeroX/yq/releases/latest/download"		# url для загрузки рабочего Yq
gh_proxy1="https://gh-proxy.com"								# 1 прокси для загрузок с GitHub
gh_proxy2="https://ghfast.top"									# 2 прокси для загрузок с GitHub

yq_use_workaround="false"									# включить при возникноверии пробелем, подобных issue 2609
yq_workaround_issue_url="https://github.com/mikefarah/yq/issues/2609"				# issue с поломанным релизом Yq
get_yq_dist_url() {
    if [ "$yq_use_workaround" = "true" ] || [ "$softfloat" = "true" ]; then
        printf '%s\n' "$yq_workaround_dist_url"
    else
        printf '%s\n' "$yq_upstream_dist_url"
    fi
}

# url для загрузки геофайлов
refilter_url="https://github.com/1andrevich/Re-filter-lists/releases/latest/download/geosite.dat"
refilterip_url="https://github.com/1andrevich/Re-filter-lists/releases/latest/download/geoip.dat"
v2fly_url="https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat"
v2flyip_url="https://github.com/loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
zkeen_url="https://github.com/jameszeroX/zkeen-domains/releases/latest/download/zkeen.dat"
zkeenip_url="https://github.com/jameszeroX/zkeen-ip/releases/latest/download/zkeenip.dat"
geoipv4_url="https://github.com/jameszeroX/zkeen-ip/releases/latest/download/ru"
geoipv6_url="https://github.com/jameszeroX/zkeen-ip/releases/latest/download/ru6"

# -------------------------------------
# Журналы
# -------------------------------------
xray_access_log="$xray_log_dir/access.log"
xray_error_log="$xray_log_dir/error.log"

# -------------------------------------
# Создание директорий и файлов
# -------------------------------------
init_directories() {
    mkdir -p "$xray_log_dir" || { echo "Ошибка: Не удалось создать директорию $xray_log_dir"; exit 1; }
    mkdir -p "$initd_dir" || { echo "Ошибка: Не удалось создать директорию $initd_dir"; exit 1; }
    mkdir -p "$backups_dir" || { echo "Ошибка: Не удалось создать директорию $backups_dir"; exit 1; }
    mkdir -p "$install_dir" || { echo "Ошибка: Не удалось создать директорию $install_dir"; exit 1; }
    mkdir -p "$cron_dir" || { echo "Ошибка: Не удалось создать директорию $cron_dir"; exit 1; }
    touch "$xray_access_log" || { echo "Ошибка: Не удалось создать файл $xray_access_log"; exit 1; }
    touch "$xray_error_log" || { echo "Ошибка: Не удалось создать файл $xray_error_log"; exit 1; }
}

# Параметры curl
curl_api() { curl --connect-timeout 2 -m 5 -kfsS "$@"; }
curl_with_timeout() {
    # Функция динамической очистки и форматирования баров в реальном времени
    indent_stderr_live() {
        # Меняем RS (разделитель строк) в awk на '\r'. 
        awk -v RS='\r' '{
            # Удаляем мусор (таблицы, ошибки curl)
            if ($0 ~ /(% Total|Average Speed|Time Current|curl:)/) next;
            if ($0 ~ /^[[:space:]]*$/) next;
            
            # Если это самый первый символ прогресс-бара, делаем начальный отступ
            if (first == 0 && $0 ~ /^[# ]/) {
                printf "  "
                first = 1
            }
            
            # Выводим бар обратно в stderr с возвратом каретки и отступом
            printf "%s\r  ", $0
            fflush()
        }
        END {
            # Если выполнение закончилось, принудительно сбрасываем каретку 
            # в самый левый край (\r), чтобы стереть паразитный отступ для caller-скрипта
            printf "\r"
            fflush()
        }' >&2
    }

    # Проверяем контекст: если вывод в /dev/null или это HEAD-запрос (-I), то это проверка (probe)
    _is_probe=0
    for _arg in "$@"; do
        [ "$_arg" = "/dev/null" ] || [ "$_arg" = "-I" ] && _is_probe=1 && break
    done

    if [ "$_is_probe" = "0" ]; then
        # Режим скачивания (fetch_with_mirrors)
        if [ -e "/tmp/toff" ]; then
            (curl -# --connect-timeout 10 "$@" 2>&1 1>&3 | indent_stderr_live) 3>&1
        else
            (curl -# --connect-timeout 10 -m 180 "$@" 2>&1 1>&3 | indent_stderr_live) 3>&1
        fi
        _curl_rc=$?

        return $_curl_rc
    else
        # Режим проверки доступности (probe_with_mirrors / test_github)
        if [ -e "/tmp/toff" ]; then
            curl --connect-timeout 10 "$@"
        else
            curl --connect-timeout 10 -m 180 "$@"
        fi
    fi
}

# Параметры повтора загрузок
retries_download_settings() {
    retries_download=1
    retry_delay_download=2

    if [ -f "$xkeen_config" ] && command -v jq >/dev/null 2>&1; then
        local parsed_val
        parsed_val=$(jq -r '.xkeen.retries_download // empty' "$xkeen_config" 2>/dev/null)

        if [ -n "$parsed_val" ] && [ "$parsed_val" -gt 0 ] 2>/dev/null; then
            retries_download="$parsed_val"
        fi

        local parsed_delay
        parsed_delay=$(jq -r '.xkeen.retry_delay_download // empty' "$xkeen_config" 2>/dev/null)
        if [ -n "$parsed_delay" ] && [ "$parsed_delay" -gt 0 ] 2>/dev/null; then
            retry_delay_download="$parsed_delay"
        fi
    fi
}
retries_download_settings