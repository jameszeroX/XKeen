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
current_datetime=$(date "+%d-%b-%y_%H-%M")
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
xray_conf_smpl="$xkeen_dir/02_install/08_install_configs/02_configs_dir"
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
xkeen_config="$xkeen_cfg/xkeen.json"
status_file="/opt/lib/opkg/status"
initd_file="$initd_dir/S05xkeen"
initd_cron="$initd_dir/S05crond"
cron_file="root"

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
gh_proxy2="https://ghproxy.cc"									# 2 прокси для загрузок с GitHub

yq_use_workaround="true"									# отключить после исправления issue 2609 (по желанию)
yq_workaround_issue_url="https://github.com/mikefarah/yq/issues/2609"				# issue с поломанным релизом Yq
get_yq_dist_url() {
    if [ "$yq_use_workaround" = "true" ]; then
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

# Таймаут curl
[ -e "/tmp/toff" ] && curl_timeout="" || curl_timeout="-m 180"

# Дополнительные параметры curl
# Пример загрузки через socks5 inbound: curl_extra="--socks5 192.168.1.1:1080"
curl_extra="-k"
