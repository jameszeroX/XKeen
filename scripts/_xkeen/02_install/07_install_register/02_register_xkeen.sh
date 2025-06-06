# Регистрация xkeen

# Функция для создания файла xkeen.control
register_xkeen_control() {
	script_dir="$(cd "$(dirname "$0")" && pwd)"
	. "$script_dir/.xkeen/01_info/01_info_variable.sh"
	
    # Создание файла xkeen.control
    cat << EOF > "$register_dir/xkeen.control"
Package: xkeen
Version: $xkeen_current_version
Depends: jq, curl, lscpu, coreutils-uname, coreutils-nohup, iptables
Source: Skrill
SourceName: xkeen
Section: net
SourceDateEpoch: $source_date_epoch
Maintainer: Skrill
Architecture: $status_architecture
Installed-Size: $installed_size
Description: The platform that makes Xray work.
EOF
}

register_xkeen_list() {
    cd "$register_dir/" || exit

    # Создание файла xkeen.list
    touch xkeen.list

    # Генерация списка файлов и директорий
    find /opt/sbin/.xkeen -mindepth 1 | while read entry; do
        echo "$entry" >> xkeen.list
    done

    # Добавление дополнительных путей
    echo "/opt/sbin/xkeen" >> xkeen.list
	echo "/opt/sbin/.xkeen" >> xkeen.list
    echo "/opt/var/log/xkeen/error.log" >> xkeen.list
    echo "/opt/var/log/xkeen/info.log" >> xkeen.list
    echo "/opt/var/log/xkeen" >> xkeen.list
}

register_xkeen_status() {
    # Генерация хэш-сумм для .json файлов
    temp_file=$(mktemp)

    # Генерация новой записи
    echo "Package: xkeen" > new_entry.txt
    echo "Version: $xkeen_current_version" >> new_entry.txt
    echo "Depends: jq, curl, lscpu, coreutils-uname, coreutils-nohup, iptables" >> new_entry.txt
    echo "Status: install user installed" >> new_entry.txt
    echo "Architecture: $status_architecture" >> new_entry.txt
    echo "Installed-Time: $(date +%s)" >> new_entry.txt	

    # Удаление временного файла
    rm $temp_file

    # Чтение существующего содержимого файла "status"
    existing_content=$(cat "$status_file")

    # Объединение существующего содержимого и новой записи
    printf "\n$(cat new_entry.txt)\n" >> "$status_file"
}