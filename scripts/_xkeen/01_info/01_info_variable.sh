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
tmp_ram="/tmp/xkeen"			 # Временная директория в RAM
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

strip_json_comments() {
    sed -e ':a; s:/\*[^*]*\*[^/]*\*/::g; ta' \
        -e 's/^[[:space:]]*\/\/.*$//' \
        -e 's/[[:space:]]\{1,\}\/\/.*$//' "$@"
}

# Параметры повтора загрузок
retries_download_settings() {
    retries_download=1
    retry_delay_download=2

    if [ -f "$xkeen_config" ] && command -v jq >/dev/null 2>&1; then
        local json_clean
        json_clean=$(strip_json_comments "$xkeen_config")

        local parsed_val
        parsed_val=$(printf '%s' "$json_clean" | jq -r '.xkeen.retries_download // empty' 2>/dev/null)

        if [ -n "$parsed_val" ] && [ "$parsed_val" -gt 0 ] 2>/dev/null; then
            retries_download="$parsed_val"
        fi

        local parsed_delay
        parsed_delay=$(printf '%s' "$json_clean" | jq -r '.xkeen.retry_delay_download // empty' 2>/dev/null)
        if [ -n "$parsed_delay" ] && [ "$parsed_delay" -gt 0 ] 2>/dev/null; then
            retry_delay_download="$parsed_delay"
        fi
    fi
}
retries_download_settings

# Функция извлечения rci-токена
get_rci_token() {
    rci_token=""
    [ ! -f "$xkeen_config" ] && return 1

    local json_clean
    json_clean=$(strip_json_comments "$xkeen_config")

    rci_token=$(printf '%s' "$json_clean" | sed -n 's/.*"rci_token": *"\([^"]*\)".*/\1/p' | xargs 2>/dev/null)

    [ "$rci_token" = "null" ] && rci_token=""
}
get_rci_token

http_code=$(
    curl -ksS -o /dev/null -w "%{http_code}" -H "X-Ndma-Tkn: $rci_token" "127.0.0.1:79/rci/show/version"
)

if [ "$http_code" = "403" ]; then
    printf "  ${red}Ошибка${reset}: Отсутствует или недействителен ${light_blue}токен доступа${reset} к RCI

  Для ${green}KeeneticOS 5.2${reset} и выше требуется ${light_blue}токен доступа${reset}
  Создайте его в веб-интерфейсе и укажите в ${yellow}xkeen.json${reset}\n"
    exit 1
fi

# Параметры curl
curl_api() {
    if [ -n "$rci_token" ]; then
        curl --connect-timeout 2 -m 5 -kfsS -H "X-Ndma-Tkn: $rci_token" "$@"
    else
        curl --connect-timeout 2 -m 5 -kfsS "$@"
    fi
}

curl_with_timeout() {
    # Функция динамической очистки и форматирования баров в реальном времени
    indent_stderr_live() {
        # Меняем RS (разделитель строк) в awk на '\r'
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
        # Код возврата curl снимаем через отдельный дескриптор: $? после пайпа
        # вернул бы код awk из indent_stderr_live, а не curl, из-за чего любой
        # сетевой сбой выглядел бы как успех. pipefail в POSIX sh недоступен.
        exec 3>&1
        if [ -e "/tmp/toff" ]; then
            _curl_rc=$( { { curl -# --connect-timeout 10 "$@" 2>&1 1>&3; echo $? >&4; } | indent_stderr_live; } 4>&1 )
        else
            _curl_rc=$( { { curl -# --connect-timeout 10 -m 180 "$@" 2>&1 1>&3; echo $? >&4; } | indent_stderr_live; } 4>&1 )
        fi
        exec 3>&-

        return "${_curl_rc:-1}"
    else
        # Режим проверки доступности (probe_with_mirrors / test_github)
        if [ -e "/tmp/toff" ]; then
            curl --connect-timeout 10 "$@"
        else
            curl --connect-timeout 10 -m 180 "$@"
        fi
    fi
}

# Настройки балансировки по скорости (.xkeen.speed_balancer.*).
# Вызывается по требованию из модуля -sb, а не глобально: несвязанным командам
# xkeen лишний разбор xkeen.json не нужен. Значения по умолчанию — рабочие,
# файл настроек не обязателен.
speed_balancer_settings() {
    sb_enabled="false"
    sb_log_enabled="true"
    sb_interval="15"
    sb_hysteresis="25"
    sb_balancer="balancer"
    sb_maxtime="8"
    # 50 МБ: endpoint Cloudflare __down отдаёт 403 на запрос больше ~50 МБ
    sb_test_url="https://speed.cloudflare.com/__down?bytes=50000000"
    # Имена файлов конфигурации Xray переопределяемы: ядро генерирует их с этими
    # именами, но нигде их не enforce'ит — у пользователя раскладка может отличаться.
    sb_routing_file="$xray_conf_dir/05_routing.json"
    sb_outbounds_file="$xray_conf_dir/04_outbounds.json"

    if [ -f "$xkeen_config" ] && command -v jq >/dev/null 2>&1; then
        local json_clean
        json_clean=$(strip_json_comments "$xkeen_config")

        local v
        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.speed_balancer.enabled // empty' 2>/dev/null)
        [ "$v" = "true" ] && sb_enabled="true"

        # Логирование замеров/переключений можно отключить (.speed_balancer.log:
        # false) — по умолчанию включено. Лог и так усечён до 200 строк, но кому-то
        # он не нужен вовсе (запрос из issue #103). Читаем БЕЗ `// empty`: для
        # булева false оператор // считает его пустым и вернул бы empty, из-за чего
        # log:false никогда бы не срабатывал. Отсутствующий ключ даёт "null".
        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.speed_balancer.log' 2>/dev/null)
        [ "$v" = "false" ] && sb_log_enabled="false"

        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.speed_balancer.interval // empty' 2>/dev/null)
        [ -n "$v" ] && [ "$v" -gt 0 ] 2>/dev/null && sb_interval="$v"

        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.speed_balancer.hysteresis // empty' 2>/dev/null)
        [ -n "$v" ] && [ "$v" -ge 0 ] 2>/dev/null && sb_hysteresis="$v"

        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.speed_balancer.balancer // empty' 2>/dev/null)
        [ -n "$v" ] && sb_balancer="$v"

        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.speed_balancer.max_time // empty' 2>/dev/null)
        [ -n "$v" ] && [ "$v" -gt 0 ] 2>/dev/null && sb_maxtime="$v"

        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.speed_balancer.test_url // empty' 2>/dev/null)
        [ -n "$v" ] && sb_test_url="$v"

        # Имена файлов задаются базовыми — каталог остаётся xray_conf_dir.
        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.speed_balancer.routing_file // empty' 2>/dev/null)
        [ -n "$v" ] && sb_routing_file="$xray_conf_dir/$v"

        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.speed_balancer.outbounds_file // empty' 2>/dev/null)
        [ -n "$v" ] && sb_outbounds_file="$xray_conf_dir/$v"
    fi
}