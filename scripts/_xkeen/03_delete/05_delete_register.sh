# Удаление регистрации Xray
delete_register_xray() {
    # Удаляем соответствующую строфу из файла статуса opkg: awk в paragraph-mode
    # (RS="") удаляет только строфу, чья первая строка матчит "Package: xray_s",
    # до ближайшей пустой строки-разделителя, — в отличие от прежнего
    # sed -i -e '/Package: xray_s/,/Installed-Time:/d', который при оборванной
    # (без Installed-Time:) строфе жадно стирал всё до следующей попавшейся
    # Installed-Time:, то есть мог стереть соседнюю чужую запись opkg.
    # Результат собирается во временном файле в той же директории и подменяет
    # status_file одним mv -f (атомарно).
    if [ -f "$status_file" ]; then
        status_tmp="${status_file}.tmp.$$"
        awk -v pkg="Package: xray_s" 'BEGIN{RS=""} $0 !~ ("^" pkg) {print; print ""}' "$status_file" > "$status_tmp"
        mv -f "$status_tmp" "$status_file"
    fi

    # Удаляем файлы регистрации, если они существуют
    if [ -f "$register_dir/xray_s.control" ] || [ -f "$register_dir/xray_s.list" ]; then
        rm -f "$register_dir/xray_s.control" "$register_dir/xray_s.list"
    fi
}

# Удаление регистрации Mihomo
delete_register_mihomo() {
    # Удаляем соответствующую строфу из файла статуса opkg (awk paragraph-mode,
    # атомарно через tmp+mv — см. delete_register_xray)
    if [ -f "$status_file" ]; then
        status_tmp="${status_file}.tmp.$$"
        awk -v pkg="Package: mihomo_s" 'BEGIN{RS=""} $0 !~ ("^" pkg) {print; print ""}' "$status_file" > "$status_tmp"
        mv -f "$status_tmp" "$status_file"
    fi

    # Удаляем файлы регистрации, если они существуют
    if [ -f "$register_dir/mihomo_s.control" ] || [ -f "$register_dir/mihomo_s.list" ]; then
        rm -f "$register_dir/mihomo_s.control" "$register_dir/mihomo_s.list"
    fi
}

# Удаление регистрации Yq
delete_register_yq() {
    # Удаляем соответствующую строфу из файла статуса opkg (awk paragraph-mode,
    # атомарно через tmp+mv — см. delete_register_xray)
    if [ -f "$status_file" ]; then
        status_tmp="${status_file}.tmp.$$"
        awk -v pkg="Package: yq_s" 'BEGIN{RS=""} $0 !~ ("^" pkg) {print; print ""}' "$status_file" > "$status_tmp"
        mv -f "$status_tmp" "$status_file"
    fi

    # Удаляем файлы регистрации, если они существуют
    if [ -f "$register_dir/yq_s.control" ] || [ -f "$register_dir/yq_s.list" ]; then
        rm -f "$register_dir/yq_s.control" "$register_dir/yq_s.list"
    fi
}

# Удаление регистрации XKeen
delete_register_xkeen() {
    # Удаляем соответствующую строфу из файла статуса opkg (awk paragraph-mode,
    # атомарно через tmp+mv — см. delete_register_xray)
    if [ -f "$status_file" ]; then
        status_tmp="${status_file}.tmp.$$"
        awk -v pkg="Package: xkeen" 'BEGIN{RS=""} $0 !~ ("^" pkg) {print; print ""}' "$status_file" > "$status_tmp"
        mv -f "$status_tmp" "$status_file"
    fi

    # Удаляем файлы регистрации, если они существуют
    if [ -f "$register_dir/xkeen.control" ] || [ -f "$register_dir/xkeen.list" ]; then
        rm -f "$register_dir/xkeen.control" "$register_dir/xkeen.list"
    fi
}
