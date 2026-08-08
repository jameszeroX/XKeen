# -------------------------------------
# Информация
# -------------------------------------
current_datetime=$(date +"%Y-%m-%d_%H-%M")
xkeen_current_version="2.0.1"
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
# Балансировка по фактической скорости (xkeen -sb)
# -------------------------------------
sb_api_config="$xray_conf_dir/00_api.json"		 # блок gRPC api Xray
sb_probe_config="$xray_conf_dir/00_probe.json"		 # probe http-proxy inbound для замера
sb_api_addr="127.0.0.1:10085"				 # адрес gRPC api
sb_probe_addr="127.0.0.1:10808"				 # адрес probe http-proxy
sb_probe_intag="probe"					 # tag probe-inbound
sb_rule_tag="xkeen-sb-probe"				 # ruleTag временного правила замера
sb_rule_tmp="$tmp_dir/sb_probe_rule.json"		 # временный файл правила замера
sb_log_file="$xray_log_dir/speed_balancer.log"		 # лог замеров и переключений

# -------------------------------------
# Ресурсы для проверки доступа в интернет
# -------------------------------------
conn_URL="ya.ru"
conn_IP1="195.208.4.1"
conn_IP2="77.88.44.55"

# -------------------------------------
# Требования к свободному месту на накопителе
# -------------------------------------
xray_free_space=40
mihomo_free_space=52
target_dir="/opt"

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
yq_api_url="https://api.github.com/repos/mikefarah/yq/releases/latest"				# url api для оригинального Yq
yq_workaround_api_url="https://api.github.com/repos/jameszeroX/yq/releases/latest"		# url api для рабочего Yq
yq_upstream_dist_url="https://github.com/mikefarah/yq/releases/latest/download"			# url для загрузки оригинального Yq
yq_workaround_dist_url="https://github.com/jameszeroX/yq/releases/latest/download"		# url для загрузки рабочего Yq
gh_proxy1="https://gh-proxy.com"								# 1 прокси для загрузок с GitHub
gh_proxy2="https://ghfast.top"									# 2 прокси для загрузок с GitHub

yq_use_workaround="false"									# включить при возникноверии пробелем, подобных issue 2609
yq_workaround_issue_url="https://github.com/mikefarah/yq/issues/2609"				# issue с поломанным релизом Yq

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
# Цвета
# -------------------------------------
green="\033[92m"	# Зеленый
red="\033[91m"		# Красный
yellow="\033[93m"	# Желтый
light_blue="\033[96m"	# Голубой
italic="\033[3m"	# Курсив
reset="\033[0m"		# Сброс цветов