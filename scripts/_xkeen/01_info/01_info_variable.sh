# -------------------------------------
# Цвета
# -------------------------------------
green="\033[92m"	# Зеленый
red="\033[91m"		# Красный
yellow="\033[33m"	# Желтый
light_blue="\033[96m"	# Голубой
italic="\033[3m"	# Курсив
reset="\033[0m"		# Сброс цветов

# -------------------------------------
# Директории
# -------------------------------------
tmp_dir_global="/opt/tmp"		 # Временная директория общая
tmp_dir="/opt/tmp/xkeen"		 # Временная директория XKeen
xtmp_dir="/opt/tmp/xray"		 # Временная директория Xray
mtmp_dir="/opt/tmp/mihomo"		 # Временная директория Mihomo
xkeen_dir="/opt/sbin/.xkeen"		 # Директория скриптов XKeen
xkeen_cfg="/opt/etc/xkeen"		 # Директория конфигурации XKeen
xkeen_log_dir="/opt/var/log/xkeen"	 # Директория логов XKeen
xray_log_dir="/opt/var/log/xray"	 # Директория логов Xray
initd_dir="/opt/etc/init.d"		 # Директория init.d
pid_dir="/opt/var/run"			 # Директория pid файлов
backups_dir="/opt/backups"		 # Директория бекапов
install_dir="/opt/sbin"			 # Директория установки
geo_dir="/opt/etc/xray/dat"		 # Директория для dat
cron_dir="/opt/var/spool/cron/crontabs"	 # Директория планировщика
cron_file="root"			 # Файл планировщика
install_conf_dir="/opt/etc/xray/configs" # Директория конфигурации Xray
mihomo_conf_dir="/opt/etc/mihomo"	 # Директория конфигурации Mihomo
xkeen_conf_dir="$xkeen_dir/02_install/08_install_configs/02_configs_dir"
xkeen_var_file="$xkeen_dir/01_info/01_info_variable.sh"
register_dir="/opt/lib/opkg/info"
status_file="/opt/lib/opkg/status"
os_modules="/lib/modules/$(uname -r)"
user_modules="/opt/lib/modules"
xkeen_current_version="1.1.3.9"
xkeen_build="Beta"
build_timestamp=""

# -------------------------------------
# Время
# -------------------------------------
existing_content=$(cat "$status_file")
installed_size=$(du -s "$install_dir" | cut -f1)
source_date_epoch=$(date +%s)
current_datetime=$(date "+%d-%b-%y_%H-%M")

# -------------------------------------
# IP для проверки доступа в интернет
# -------------------------------------
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
yq_dist_url="https://github.com/mikefarah/yq/releases/latest/download"				# url для загрузки Yq
gh_proxy1="https://ghfast.top"								        # 1 прокси для загрузок с GitHub
gh_proxy2="https://edgeone.gh-proxy.org"							# 2 прокси для загрузок с GitHub

# url для загрузки геофайлов
refilter_url="https://github.com/1andrevich/Re-filter-lists/releases/latest/download/geosite.dat"
refilterip_url="https://github.com/1andrevich/Re-filter-lists/releases/latest/download/geoip.dat"
v2fly_url="https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat"
v2flyip_url="https://github.com/loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
zkeen_url="https://github.com/jameszeroX/zkeen-domains/releases/latest/download/zkeen.dat"
zkeenip_url="https://github.com/jameszeroX/zkeen-ip/releases/latest/download/zkeenip.dat"

# -------------------------------------
# Создание директорий и файлов
# -------------------------------------
mkdir -p "$xray_log_dir" || { echo "Ошибка: Не удалось создать директорию $xray_log_dir"; exit 1; }
mkdir -p "$initd_dir" || { echo "Ошибка: Не удалось создать директорию $initd_dir"; exit 1; }
mkdir -p "$pid_dir" || { echo "Ошибка: Не удалось создать директорию $pid_dir"; exit 1; }
mkdir -p "$backups_dir" || { echo "Ошибка: Не удалось создать директорию $backups_dir"; exit 1; }
mkdir -p "$install_dir" || { echo "Ошибка: Не удалось создать директорию $install_dir"; exit 1; }
mkdir -p "$cron_dir" || { echo "Ошибка: Не удалось создать директорию $cron_dir"; exit 1; }

# -------------------------------------
# Журналы
# -------------------------------------
xray_access_log="$xray_log_dir/access.log"
xray_error_log="$xray_log_dir/error.log"

touch "$xray_access_log" || { echo "Ошибка: Не удалось создать файл $xray_access_log"; exit 1; }
touch "$xray_error_log" || { echo "Ошибка: Не удалось создать файл $xray_error_log"; exit 1; }
