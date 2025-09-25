diagnostic() {
# Установка пути к файлу diagnostic
diagnostic="/opt/diagnostic.txt"

if pidof "xray" >/dev/null; then
    name_client=xray
elif pidof "mihomo" >/dev/null; then
    name_client=mihomo
else
    echo
    echo -e "  Диагностика возможна только при работающем ${yellow}XKeen${reset}"
    echo -e "  Запустите ${yellow}XKeen${reset} командой '${green}xkeen -start${reset}'"
    exit 1
fi

ip4_supported=$(ip -4 addr show | grep -q "inet " && echo true || echo false)
ip6_supported=$(ip -6 addr show | grep -q "inet6 " && echo true || echo false)

iptables_supported=$([ "$ip4_supported" = "true" ] && command -v iptables >/dev/null 2>&1 && echo true || echo false)
ip6tables_supported=$([ "$ip6_supported" = "true" ] && command -v ip6tables >/dev/null 2>&1 && echo true || echo false)

echo
echo "  Выполняется диагностика. Пожалуйста, подождите..."

# Создаем файл diagnostic
touch "$diagnostic" 

# Очищаем файл diagnostic перед записью новых данных
> "$diagnostic" 

# Функция для записи заголовка в файл
write_header() {
    echo "-------------------------" >> "$diagnostic"
    echo -e "$1" >> "$diagnostic"
    echo "-------------------------" >> "$diagnostic"
    echo >> "$diagnostic"
}

# Ядро
write_header "XKeen работает на ядре ${name_client}\nи установлен ${entware_storage}"

# Определение доступности IPv4 и IPv6
write_header "Доступность IPv4 и IPv6"
echo "Поддержка IPv4 - $ip4_supported" >> "$diagnostic" 
echo "Поддержка IPv6 - $ip6_supported" >> "$diagnostic" 
echo >> "$diagnostic" 
echo "Поддержка iptables - $iptables_supported" >> "$diagnostic" 
echo "Поддержка i6ptables - $ip6tables_supported" >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

if [ $iptables_supported = "true" ]; then
    # Запись заголовка и выполнение команд iptables
    write_header "Результат таблицы NAT цепи PREROUTING IPv4"
    { iptables -t nat -nvL PREROUTING 2>&1; } >> "$diagnostic" 
    echo >> "$diagnostic"
    echo >> "$diagnostic"
    
    write_header "Результат таблицы NAT цепи xkeen IPv4"
    { iptables -t nat -nvL xkeen 2>&1; } >> "$diagnostic" 
    echo >> "$diagnostic"
    echo >> "$diagnostic"
    
    write_header "Результат таблицы MANGLE цепи PREROUTING IPv4"
    { iptables -t mangle -nvL PREROUTING 2>&1; } >> "$diagnostic" 
    echo >> "$diagnostic"
    echo >> "$diagnostic"
    
    write_header "Результат таблицы MANGLE цепи xkeen IPv4"
    { iptables -t mangle -nvL xkeen 2>&1; } >> "$diagnostic" 
    echo >> "$diagnostic"
    echo >> "$diagnostic"
    
    write_header "Результат таблицы MANGLE цепи OUTPUT IPv4"
    { iptables -t mangle -nvL OUTPUT 2>&1; } >> "$diagnostic" 
    echo >> "$diagnostic"
    echo >> "$diagnostic"
    
    write_header "Результат таблицы MANGLE цепи xkeen_mask IPv4"
    { iptables -t mangle -nvL xkeen_mask 2>&1; } >> "$diagnostic" 
    echo >> "$diagnostic"
    echo >> "$diagnostic"
fi

if [ $ip6tables_supported = "true" ]; then
    # Запись заголовка и выполнение команд ip6tables
    write_header "Результат таблицы NAT цепи PREROUTING IPv6"
    { ip6tables -t nat -nvL PREROUTING 2>&1; } >> "$diagnostic" 
    echo >> "$diagnostic"
    echo >> "$diagnostic"
    
    write_header "Результат таблицы NAT цепи xkeen IPv6"
    { ip6tables -t nat -nvL xkeen 2>&1; } >> "$diagnostic" 
    echo >> "$diagnostic"
    echo >> "$diagnostic"
    
    write_header "Результат таблицы MANGLE цепи PREROUTING IPv6"
    { ip6tables -t mangle -nvL PREROUTING 2>&1; } >> "$diagnostic" 
    echo >> "$diagnostic"
    echo >> "$diagnostic"
    
    write_header "Результат таблицы MANGLE цепи xkeen IPv6"
    { ip6tables -t mangle -nvL xkeen 2>&1; } >> "$diagnostic" 
    echo >> "$diagnostic"
    echo >> "$diagnostic"
    
    write_header "Результат таблицы MANGLE цепи OUTPUT IPv6"
    { ip6tables -t mangle -nvL OUTPUT 2>&1; } >> "$diagnostic" 
    echo >> "$diagnostic"
    echo >> "$diagnostic"
    
    write_header "Результат таблицы MANGLE цепи xkeen_mask IPv6"
    { ip6tables -t mangle -nvL xkeen_mask 2>&1; } >> "$diagnostic" 
    echo >> "$diagnostic"
    echo >> "$diagnostic"
fi

# Копирование содержимого файла /opt/etc/ndm/netfilter.d/proxy.sh
write_header "Содержимое файла /opt/etc/ndm/netfilter.d/proxy.sh"
cat /opt/etc/ndm/netfilter.d/proxy.sh >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

# Проверка использования SSL порта
write_header "Проверка использования SSL порта"
curl -kfsS "localhost:79/rci/ip/http/ssl" | jq -r '.port' >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

# Сбор данных о политике доступа
write_header "Данные о политике доступа"
curl -kfsS "localhost:79/rci/show/ip/policy" | jq -r ' .[] | select(.description | ascii_downcase == "xkeen")' >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

# Сбор результатов команды ip rule show
write_header "Результат команды ip rule show"
ip rule show >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

# Сбор результатов команды ip route show table main
write_header "Результат команды ip route show table main"
ip route show table main >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

# Запрос к curl для получения title, model, region
write_header "Данные из localhost:79/rci/show/version"
curl -kfsS "localhost:79/rci/show/version" | jq -r '.title, .model, .region' >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

# Запрос версии ядра
if [ "${name_client}" = "xray" ]; then
    write_header "Версия Xray"
    xray -version >> "$diagnostic" 
elif [ "${name_client}" = "mihomo" ]; then
    write_header "Версия Mihomo"
    mihomo -v >> "$diagnostic" 
fi
echo >> "$diagnostic"
echo "Разрешено файловых дескрипторов:" >> "$diagnostic"
grep 'Max open files' "/proc/$(pidof ${name_client})/limits" | awk '{print $4}' >> "$diagnostic" 
echo "Использовано файловых дескрипторов:" >> "$diagnostic"
ls -l /proc/$(pidof ${name_client})/fd | wc -l >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

# Запрос версии XKeen
write_header "Версия XKeen"
xkeen -v >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

if [ "${name_client}" = "xray" ]; then
    # dns.json
    if ls "$install_conf_dir"/*dns* >/dev/null 2>&1; then
        write_header "Содержимое файла dns.json"
        cat "$install_conf_dir"/*dns* >> /opt/diagnostic.txt
        echo >> "$diagnostic"
        echo >> "$diagnostic"
    fi
    # inbounds.json
    if ls "$install_conf_dir"/*inbounds* >/dev/null 2>&1; then
        write_header "Содержимое файла inbounds.json"
        cat "$install_conf_dir"/*inbounds* >> /opt/diagnostic.txt
        echo >> "$diagnostic"
        echo >> "$diagnostic"
    fi
    # routing.json
    if ls "$install_conf_dir"/*routing* >/dev/null 2>&1; then
        write_header "Содержимое файла routing.json"
        cat "$install_conf_dir"/*routing* >> /opt/diagnostic.txt
        echo >> "$diagnostic"
        echo >> "$diagnostic"
    fi
fi

echo
echo
echo -e "  Диагностика ${green}выполнена${reset}"
echo -e "  Отправьте файл '${yellow}$diagnostic${reset}' в телеграм-чат ${yellow}XKeen${reset}, подробно описав возникшую проблему"
echo
echo -e "  ${red}Примечание${reset}: Диагностика не проверяет доступ к прокси-серверу, правильность заполнения конфигов
  и настройки роутера/сервера. Она проверяет ${green}только${reset} корректность инициализации ${yellow}XKeen${reset} в роутере"
}