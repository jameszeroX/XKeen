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

iptables_supported=false
if [ $ip4_supported = "true" ]; then
    iptables_supported=$(command -v iptables >/dev/null 2>&1 && echo true)
fi

ip6tables_supported=false
if [ $ip6_supported = "true" ]; then
    ip6tables_supported=$(command -v ip6tables >/dev/null 2>&1 && echo true)
fi

echo
echo "  Выполняется диагностика. Пожалуйста, подождите..."

# Создаем файл diagnostic
touch "$diagnostic" 

# Очищаем файл diagnostic перед записью новых данных
> "$diagnostic" 

# Функция для записи заголовка в файл
write_header() {
    echo "-------------------------" >> "$diagnostic"
    echo "$1" >> "$diagnostic"
    echo "-------------------------" >> "$diagnostic"
    echo >> "$diagnostic"
}

# 1. Место установки
write_header "Entware установлена ${entware_storage}"

# 2. Ядро
write_header "XKeen работает на ядре ${name_client}"

# 3. Определение доступности IPv4 и IPv6
write_header "Доступность IPv4 и IPv6"
echo "Поддержка IPv4 - $ip4_supported" >> "$diagnostic" 
echo "Поддержка IPv6 - $ip6_supported" >> "$diagnostic" 
echo >> "$diagnostic" 
echo "Поддержка iptables - $iptables_supported" >> "$diagnostic" 
echo "Поддержка i6ptables - $ip6tables_supported" >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

if [ $iptables_supported = "true" ]; then
    # 4. Запись заголовка и выполнение команд iptables
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
    # 5. Запись заголовка и выполнение команд ip6tables
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

# 6. Копирование содержимого файла /opt/etc/ndm/netfilter.d/proxy.sh
write_header "Содержимое файла /opt/etc/ndm/netfilter.d/proxy.sh"
cat /opt/etc/ndm/netfilter.d/proxy.sh >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

# 7. Проверка использования SSL порта
write_header "Проверка использования SSL порта"
curl -kfsS "localhost:79/rci/ip/http/ssl" | jq -r '.port' >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

# 8. Сбор данных о политике доступа
write_header "Данные о политике доступа"
curl -kfsS "localhost:79/rci/show/ip/policy" | jq -r ' .[] | select(.description | ascii_downcase == "xkeen")' >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

# 9. Сбор результатов команды ip rule show
write_header "Результат команды ip rule show"
ip rule show >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

# 10. Сбор результатов команды ip route show table main
write_header "Результат команды ip route show table main"
ip route show table main >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

# 11. Запрос к curl для получения country, ndmhwid, product
write_header "Данные из localhost:79/rci/show/defaults"
curl -kfsS "localhost:79/rci/show/defaults" | jq -r '.country, .ndmhwid, .product' >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

# 12. Запрос версии ядра
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

# 13. Запрос версии XKeen
write_header "Версия XKeen"
xkeen -v >> "$diagnostic" 
echo >> "$diagnostic"
echo >> "$diagnostic"

echo
echo
echo -e "  Диагностика ${green}выполнена${reset}"
echo -e "  Отправьте файл '${yellow}$diagnostic${reset}' в телеграм-чат ${yellow}XKeen${reset}, подробно описав возникшую проблему"
echo
echo -e "  ${red}Примечание${reset}: Диагностика не проверяет доступ к прокси-серверу, правильность заполнения конфигов
  и настройки роутера/сервера. Она проверяет ${green}только${reset} корректность инициализации ${yellow}XKeen${reset} в роутере"
}