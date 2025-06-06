# Журнал работы XKeen

logs_packages_info_xkeen() {
    info_content=""
    error_content=""

    if [ "$info_packages_lscpu" = "installed" ]; then
        info_content="${info_content}  [info] lscpu установлен\n"
    else
        error_content="${error_content}  [error] lscpu не установлен\n"
    fi

	if [ "$info_packages_uname" = "installed" ]; then
        info_content="${info_content}  [info] coreutils-uname установлен\n"
    else
        error_content="${error_content}  [error] coreutils-uname не установлен\n"
    fi

	if [ "$info_packages_nohup" = "installed" ]; then
        info_content="${info_content}  [info] coreutils-nohup установлен\n"
    else
        error_content="${error_content}  [error] coreutils-nohup не установлен\n"
    fi

    if [ "$info_packages_curl" = "installed" ]; then
        info_content="${info_content}  [info] curl установлен\n"
    else
        error_content="${error_content}  [error] curl не установлен\n"
    fi

    if [ "$info_packages_jq" = "installed" ]; then
        info_content="${info_content}  [info] jq установлен\n"
    else
        error_content="${error_content}  [error] jq не установлен\n"
    fi

    if [ "$info_packages_libc" = "installed" ]; then
        info_content="${info_content}  [info] libc установлен\n"
    else
        error_content="${error_content}  [error] libc не установлен\n"
    fi

    if [ "$info_packages_libssp" = "installed" ]; then
        info_content="${info_content}  [info] libssp установлен\n"
    else
        error_content="${error_content}  [error] libssp не установлен\n"
    fi

    if [ "$info_packages_librt" = "installed" ]; then
        info_content="${info_content}  [info] librt установлен\n"
    else
        error_content="${error_content}  [error] librt не установлен\n"
    fi

    if [ "$info_packages_libpthread" = "installed" ]; then
        info_content="${info_content}  [info] libpthread установлен\n"
    else
        error_content="${error_content}  [error] libpthread не установлен\n"
    fi

    if [ "$info_packages_cabundle" = "installed" ]; then
        info_content="${info_content}  [info] ca-bundle установлен\n"
    else
        error_content="${error_content}  [error] ca-bundle не установлен\n"
    fi

    if [ -n "$info_content" ]; then
        echo "[start] Проверка наличия необходимых пакетов" >> "$xkeen_info_log"
        echo -e "$info_content" | sed '/^$/d' >> "$xkeen_info_log"
        echo "[end] Проверка наличия необходимых пакетов выполнена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка наличия необходимых пакетов" >> "$xkeen_error_log"
        echo -e "$error_content" | sed '/^$/d' >> "$xkeen_error_log"
        echo "[end] Проверка наличия необходимых пакетов выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi
}

logs_cpu_info_xkeen() {
    info_content=""
    error_content=""

    if [ -n "$architecture" ]; then
        info_content="  [info] Набор инструкций процессора: $architecture\n"
    else
        error_content="  [error] Набор инструкций процессора: Не удалось определить\n"
    fi

    if [ -n "$architecture" ]; then
        info_content="$info_content\t[info] Процессор поддерживается XKeen\n"
    else
        error_content="$error_content\t[error] Процессор не поддерживается XKeen\n"
		fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка процессора" >> "$xkeen_error_log"
        echo -e "$error_content" | sed '/^$/d' >> "$xkeen_error_log"
        echo "[end] Проверка процессора выполнена" >> "$xkeen_error_log"
		echo "" >> "$xkeen_error_log"
    fi

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка процессора" >> "$xkeen_info_log"
        echo -e "$info_content" | sed '/^$/d' >> "$xkeen_info_log"
        echo "[end] Проверка процессора выполнена" >> "$xkeen_info_log"
		echo "" >> "$xkeen_info_log"
    fi
}


logs_xray_info_xkeen() {
    if [ "$xray_installed" = "installed" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка установки xray" >> "$xkeen_info_log"
        echo "  [info] xray установлен" >> "$xkeen_info_log"
        echo "[end] Проверка установки xray выполнена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
    
    if [ "$xray_installed" = "not_installed" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка установки xray" >> "$xkeen_error_log"
        echo "  [error] xray не установлен" >> "$xkeen_error_log"
        echo "[end] Проверка установки xray выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi
}


logs_geosite_info_xkeen() {
    info_content=""
    error_content=""

    if [ "$geo_exists_geosite_antifilter" = "installed" ]; then
        info_content="${info_content}	[info] База GeoSite AntiFilter установлена\n"
    else
        error_content="${error_content}	[error] База GeoSite AntiFilter не установлена\n"
    fi

    if [ "$geo_exists_geosite_v2fly" = "installed" ]; then
        info_content="${info_content}	[info] База GeoSite v2fly установлена\n"
    else
        error_content="${error_content}	[error] База GeoSite v2fly не установлена\n"
    fi

    if [ "$geo_exists_geosite_zkeen" = "installed" ]; then
        info_content="\t[info] База GeoSite Zkeen установлена\n"
    else
        error_content="\n\t[error] База GeoSite Zkeen не установлена\n"
    fi


    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка наличия баз данных GeoSite" >> "$xkeen_info_log"
        echo -e "$info_content" | sed '/^$/d' >> "$xkeen_info_log"
        echo "[end] Проверка наличия баз данных GeoSite выполнена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка наличия баз данных GeoSite" >> "$xkeen_error_log"
        echo -e "$error_content" | sed '/^$/d' >> "$xkeen_error_log"
        echo "[end] Проверка наличия баз данных GeoSite выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi
}


logs_geoip_info_xkeen() {
    info_content=""
    error_content=""

    if [ "$geo_exists_geoip_antifilter" = "installed" ]; then
        info_content="\t[info] База GeoIP AntiFilter установлена\n"
    else
        error_content="\n\t[error] База GeoIP AntiFilter не установлена\n"
    fi

    if [ "$geo_exists_geoip_v2fly" = "installed" ]; then
        info_content="${info_content}\t[info] База GeoIP v2fly установлена\n"
    else
        error_content="${error_content}\n\t[error] База GeoIP v2fly не установлена\n"
    fi

    if [ "$geo_exists_geoip_zkeenip" = "installed" ]; then
        info_content="${info_content}\t[info] База GeoIP ZkeenIP установлена\n"
    else
        error_content="${error_content}\n\t[error] База GeoIP ZkeenIP не установлена\n"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка наличия баз данных GeoIP" >> "$xkeen_error_log"
        echo -e "$error_content" | sed '/^$/d' >> "$xkeen_error_log"
        echo "[end] Проверка наличия баз данных GeoIP выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка наличия баз данных GeoIP" >> "$xkeen_info_log"
        echo -e "$info_content" | sed '/^$/d' >> "$xkeen_info_log"
        echo "[end] Проверка наличия баз данных GeoIP выполнена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
}


logs_cron_info_xkeen() {
    info_content=""
    error_content=""

    if [ "$info_update_geofile_cron" = "installed" ]; then
        info_content="${info_content}\t[info] Задача автоматического обновления GeoFile включена"
    else
        error_content="${error_content}\t[error] Задача автоматического обновления GeoFile не включена"
    fi

    if [ "$info_update_xkeen_cron" = "installed" ]; then
        info_content="${info_content}\t[info] Задача автоматического обновления Xkeen включена\n"
    else
        error_content="${error_content}\t[error] Задача автоматического обновления Xkeen не включена\n"
    fi

    if [ "$info_update_xray_cron" = "installed" ]; then
        info_content="\t[info] Задача автоматического обновления Xray включена\n"
    else
        error_content="\t[error] Задача автоматического обновления Xray не включена\n"
    fi

    if [ -n "$error_content" ]; then
		echo "" >> "$xkeen_error_log"
        echo "[start] Проверка наличия задач автоматического обновления в cron" >> "$xkeen_error_log"
        echo -e "$error_content" | sed '/^$/d' >> "$xkeen_error_log"
        echo "[end] Проверка наличия задач автоматического обновления в cron выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi

    if [ -n "$info_content" ]; then
		echo "" >> "$xkeen_info_log"
        echo "[start] Проверка наличия задач автоматического обновления в cron" >> "$xkeen_info_log"
        echo -e "$info_content" | sed '/^$/d' >> "$xkeen_info_log"
        echo "[end] Проверка наличия задач автоматического обновления в cron выполнена" >> "$xkeen_info_log"
		echo "" >> "$xkeen_info_log"
    fi
}

logs_version_xkeen_info_xkeen() {
    info_content=""
    error_content=""
    result_content=""

    info_content="\t[info] Установленная версия XKeen: $xkeen_current_version\n\t[info] GitHub версия XKeen: $xkeen_github_version"

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
		echo "[start] Проверка версии XKeen" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Проверка версии XKeen выполнена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка версии XKeen" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo "[end] Проверка версии XKeen выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi
}

logs_compare_xkeen_info_xkeen() {
    info_content=""
    error_content=""
    result_content=""

    if [ "$info_compare_xkeen" = "actual" ]; then
        info_content="[info] Текущая версия $xkeen_current_version XKeen актуальна"
    elif [ "$info_compare_xkeen" = "update" ]; then
        info_content="[info] Текущая версия XKeen $xkeen_current_version."
        info_content="${info_content}\n[info] Доступно обновление на версию $xkeen_github_version"
    else
        info_content="[info] Текущая версия XKeen $xkeen_current_version новее доступной на GitHub $xkeen_github_version"
    fi

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
		echo "[start] Сравнение версий XKeen" >> "$xkeen_info_log"
        echo -e "$info_content" | sed -e 's/^/\t/' >> "$xkeen_info_log"
        echo "[end] Сравнение версий XKeen выполнено" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Сравнение версий XKeen" >> "$xkeen_error_log"
        echo -e "$error_content" | sed -e 's/^/\t/' >> "$xkeen_error_log"
        echo "[end] Сравнение версий XKeen выполнено" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi
}

logs_version_xray_info_xkeen() {
    info_content=""
    error_content=""

    info_content="\t[info] Установленная версия xray: $xray_current_version\n"

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
		echo "[start] Проверка версии xray" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Проверка версии xray выполнена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка версии xray" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo "[end] Проверка версии xray выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi
}

logs_compare_xray_info_xkeen() {
    info_content=""
    error_content=""

    if [ "$info_compare_xray" = "actual" ]; then
        info_content="\t[info] Текущая версия $xray_current_version xray актуальна"
    elif [ "$info_compare_xray" = "update" ]; then
        info_content="\t[info] Текущая версия xray $xray_current_version."
    fi

    if [ -n "$info_content" ]; then
	    echo "" >> "$xkeen_info_log"
        echo -e "[start] Сравнение версий xray\n$info_content" >> "$xkeen_info_log"
        echo "[end] Сравнение версий xray выполнено" >> "$xkeen_info_log"
		echo "" >> "$xkeen_info_log"
    fi

    if [ -n "$error_content" ]; then
		echo "" >> "$xkeen_error_log"
        echo -e "[start] Сравнение версий xray\n$error_content" >> "$xkeen_error_log"
        echo "[end] Сравнение версий xray выполнено" >> "$xkeen_error_log"
		echo "" >> "$xkeen_error_log"
    fi
}

logs_install_packages_xkeen() {
    info_content=""
    error_content=""
    
    if [ "$info_packages_lscpu" = "installed" ]; then
        info_content="${info_content}\t[info] lscpu установлен"
    fi
    
	if [ "$info_packages_uname" = "installed" ]; then
			info_content="${info_content}\t[info] coreutils-uname установлен"
    fi

	if [ "$info_packages_nohup" = "installed" ]; then
			info_content="${info_content}\t[info] coreutils-nohup установлен"
    fi
	
    if [ "$info_packages_curl" = "installed" ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}\t[info] curl установлен"
    fi
    
    if [ "$info_packages_jq" = "installed" ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}\t[info] jq установлен"
    fi
    
    if [ "$info_packages_libc" = "installed" ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}\t[info] libc установлен"
    fi
    
    if [ "$info_packages_libssp" = "installed" ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}\t[info] libssp установлен"
    fi
    
    if [ "$info_packages_librt" = "installed" ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}\t[info] librt установлен"
    fi
    
    if [ "$info_packages_libpthread" = "installed" ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}\t[info] libpthread установлен"
    fi
    
    if [ "$info_packages_cabundle" = "installed" ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}\t[info] ca-bundle установлен"
    fi
    
    if [ -n "$info_content" ]; then
	    echo "" >> "$xkeen_info_log"
        echo "[start] Проверка наличия необходимых пакетов" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Проверка наличия необходимых пакетов выполнена" >> "$xkeen_info_log"
		echo "" >> "$xkeen_info_log"
    fi
    
    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка наличия необходимых пакетов" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo "[end] Проверка наличия необходимых пакетов выполнена" >> "$xkeen_error_log"
		echo "" >> "$xkeen_error_log"
    fi
}

logs_download_xray_info_xkeen() {
    info_content=""
    error_content=""

    if [ -n "$download_url" ]; then
        info_content="  [info] URL для скачивания Xray найден"
    else
        error_content="  [error] URL для скачивания Xray не найден"
    fi

    if [ -e "$tmp_dir/xray.ipk" ]; then
        if [ -s "$tmp_dir/xray.ipk" ]; then
            result_content="  [info] xray успешно загружен"
        else
            error_content="  [error] Загрузка Xray не удалась. Некорректная ссылка"
        fi
    else
        error_content="  [error] Загрузка Xray не удалась. Архив не найден"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Загрузка xray" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo "[end] Загрузка Xray выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi

    if [ -n "$info_content" ] || [ -n "$result_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Загрузка Xray" >> "$xkeen_info_log"
		echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Загрузка Xray выполнена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
}


logs_choice_geoip_info_xkeen() {
    info_content=""

    if [ "$install_antifilter_geoip" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Установить: AntiFilter"
    fi

    if [ "$update_antifilter_geoip" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Обновить: AntiFilter"
    fi

    if [ "$install_v2fly_geoip" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Установить: v2fly"
    fi

    if [ "$update_v2fly_geoip" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Обновить: v2fly"
    fi

    if [ "$install_zkeenip_geoip" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Установить: ZkeenIP"
    fi

    if [ "$update_zkeenip_geoip" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Обновить: ZkeenIP"
    fi

    if [ "$choice_delete_geoip_antifilter_select" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Удаление: AntiFilter"
    fi

    if [ "$choice_delete_geoip_v2fly_select" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Удаление: v2fly"
    fi

    if [ "$choice_delete_geoip_zkeenip_select" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Удаление: ZkeenIP"
    fi

    if [ -n "$info_content" ]; then
		echo "" >> "$xkeen_info_log"
        echo "[start] Выбор пользователя в секции GeoIP" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Выбор пользователя в секции GeoIP выполнен" >> "$xkeen_info_log"
		echo "" >> "$xkeen_info_log"
    fi
}

logs_choice_geosite_info_xkeen() {
    info_content=""

    if [ "$install_antifilter_geosite" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Установить: AntiFilter"
    fi

    if [ "$update_antifilter_geosite" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Обновить: AntiFilter"
    fi

    if [ "$install_v2fly_geosite" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Установить: v2fly"
    fi

    if [ "$update_v2fly_geosite" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Обновить: v2fly"
    fi

    if [ "$install_zkeen_geosite" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Установить: Zkeen"
    fi

    if [ "$update_zkeen_geosite" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Обновить: Zkeen"
    fi

    if [ "$choice_delete_geosite_antifilter_select" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Удаление: AntiFilter"
    fi

    if [ "$choice_delete_geosite_v2fly_select" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Удаление: v2fly"
    fi

    if [ "$choice_delete_geosite_zkeen_select" = true ]; then
        if [ -n "$info_content" ]; then
            info_content="${info_content}\n"
        fi
        info_content="${info_content}  [info] Удаление: Zkeen"
    fi

    if [ -n "$info_content" ]; then
	    echo "" >> "$xkeen_info_log"
        echo "[start] Выбор пользователя в секции GeoSite" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Выбор пользователя в секции GeoSite выполнен" >> "$xkeen_info_log"	
		echo "" >> "$xkeen_info_log"
    fi
}

logs_install_geoip_info_xkeen() {
    info_content=""
    error_content=""

    if [ "$install_antifilter_geoip" = true ]; then
        if [ -f "$geo_dir/geoip_antifilter.dat" ]; then
            info_content="${info_content}\n\t[info] GeoIP AntiFilter установлена"
        else
            error_content="${error_content}\n\t[error] Не удалось установить GeoIP базу AntiFilter"
        fi
    fi

    if [ "$install_v2fly_geoip" = true ]; then
        if [ -f "$geo_dir/geoip_v2fly.dat" ]; then
            info_content="${info_content}\n\t[info] GeoIP v2fly установлена"
        else
            error_content="${error_content}\n\t[error] Не удалось установить GeoIP базу v2fly"
        fi
    fi

    if [ "$install_zkeenip_geoip" = true ]; then
        if [ -f "$geo_dir/geoip_zkeenip.dat" ]; then
            info_content="${info_content}\n\t[info] GeoIP ZkeenIP установлена"
        else
            error_content="${error_content}\n\t[error] Не удалось установить GeoIP базу ZkeenIP"
        fi
    fi

    if [ "$update_antifilter_geoip" = true ]; then
        if [ -f "$geo_dir/geoip_antifilter.dat" ]; then
            info_content="${info_content}\n\t[info] GeoIP AntiFilter обновлена"
        else
            error_content="${error_content}\n\t[error] GeoIP AntiFilter  не установлена. Поэтому не может быть обновлена"
        fi
    fi

    if [ "$update_v2fly_geoip" = true ]; then
        if [ -f "$geo_dir/geoip_v2fly.dat" ]; then
            info_content="${info_content}\n\t[info] GeoIP v2fly обновлена"
        else
            error_content="${error_content}\n\t[error] GeoIP v2fly не установлена. Поэтому не может быть обновлена"
        fi
    fi

    if [ "$update_zkeenip_geoip" = true ]; then
        if [ -f "$geo_dir/geoip_zkeenip.dat" ]; then
            info_content="${info_content}\n\t[info] GeoIP ZkeenIP обновлена"
        else
            error_content="${error_content}\n\t[error] GeoIP ZkeenIP не установлена. Поэтому не может быть обновлена"
        fi
    fi

    if [ -n "$info_content" ]; then
	    echo "" >> "$xkeen_info_log"
        echo -e "[start] Установка или обновление GeoIP $info_content" >> "$xkeen_info_log"
        echo "[end] Установка или обновление GeoIP выполнено" >> "$xkeen_info_log"
		echo "" >> "$xkeen_info_log"
    fi

    if [ -n "$error_content" ]; then
		echo "" >> "$xkeen_error_log"
        echo -e "[start] Установка или обновление GeoIP $error_content" >> "$xkeen_error_log"
        echo "[end] Установка или обновление GeoIP выполнено" >> "$xkeen_error_log"
		echo "" >> "$xkeen_error_log"
    fi
}

logs_install_geosite_info_xkeen() {
    info_content=""
    error_content=""

    if [ "$install_antifilter_geosite" = true ]; then
        if [ -f "$geo_dir/geosite_antifilter.dat" ]; then
            info_content="${info_content}\n\t[info] GeoSite AntiFilter установлена"
        else
            error_content="${error_content}\n\t[error] Не удалось установить GeoSite базу AntiFilter"
        fi
    fi

    if [ "$install_v2fly_geosite" = true ]; then
        if [ -f "$geo_dir/geosite_v2fly.dat" ]; then
            info_content="${info_content}\n\t[info] GeoSite v2fly установлена"
        else
            error_content="${error_content}\n\t[error] Не удалось установить GeoSite базу v2fly"
        fi
    fi

    if [ "$install_zkeen_geosite" = true ]; then
        if [ -f "$geo_dir/geosite_zkeen.dat" ]; then
            info_content="${info_content}\n\t[info] GeoSite Zkeen установлена"
        else
            error_content="${error_content}\n\t[error] Не удалось установить GeoSite базу Zkeen"
        fi
    fi

    if [ "$update_antifilter_geosite" = true ]; then
        if [ -f "$geo_dir/geosite_antifilter.dat" ]; then
            info_content="${info_content}\n\t[info] GeoSite AntiFilter обновлена"
        else
            error_content="${error_content}\n\t[error] GeoSite AntiFilter не установлена. Поэтому не может быть обновлена"
        fi
    fi

    if [ "$update_v2fly_geosite" = true ]; then
        if [ -f "$geo_dir/geosite_v2fly.dat" ]; then
            info_content="${info_content}\n\t[info] GeoSite v2fly обновлена"
        else
            error_content="${error_content}\n\t[error] GeoSite v2fly не установлена. Поэтому не может быть обновлена"
        fi
    fi

    if [ "$update_zkeen_geosite" = true ]; then
        if [ -f "$geo_dir/geosite_zkeen.dat" ]; then
            info_content="${info_content}\n\t[info] GeoSite Zkeen обновлена"
        else
            error_content="${error_content}\n\t[error] GeoSite Zkeen не установлена. Поэтому не может быть обновлена"
        fi
    fi

    if [ -n "$info_content" ]; then
	    echo "" >> "$xkeen_info_log"
        echo -e "[start] Установка или обновление GeoSite $info_content" >> "$xkeen_info_log"
        echo "[end] Установка или обновление GeoSite выполнено" >> "$xkeen_info_log"
		echo "" >> "$xkeen_info_log"
    fi

    if [ -n "$error_content" ]; then
		echo "" >> "$xkeen_error_log"
        echo -e "[start] Установка или обновление GeoSite $error_content" >> "$xkeen_error_log"
        echo "[end] Установка или обновление GeoSite выполнено" >> "$xkeen_error_log"
		echo "" >> "$xkeen_error_log"
    fi
}


logs_install_configs_info_xkeen() {
    info_content=""
    error_content=""

    if [ -d "$xkeen_conf_dir" ]; then
        xkeen_files="$xkeen_conf_dir"/*.json
        
        files_to_replace=""
        
        for file in $xkeen_files; do
            filename=$(basename "$file" .json)
            if [ -f "$install_conf_dir/$filename.json" ]; then
                files_to_replace="$files_to_replace $filename"
            fi
        done

        if [ -n "$files_to_replace" ]; then
            info_content="\t[info] Файлы находящиеся в директории конфигураций Xray:\n"
            for filename in $files_to_replace; do
                info_content="$info_content\t\t[info] $filename\n"
            done
        fi
    else
        error_content="\t[error] Директория $xkeen_conf_dir не найдена\n"
    fi

    if [ -n "$error_content" ] || [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка файлов конфигурации Xray" >> "$xkeen_info_log"
        if [ -n "$error_content" ]; then
            echo -e "$error_content" | sed '/^$/d' >> "$xkeen_error_log"
        fi
        if [ -n "$info_content" ]; then
            echo -e "$info_content" | sed '/^$/d' >> "$xkeen_info_log"
        fi
        echo "[end] Проверка файлов конфигурации Xray завершена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
}


logs_choice_update_cron_info_xkeen() {
    info_content=""

    has_missing_cron_tasks=false
    has_updatable_cron_tasks=false

  [ "$choice_geofile_cron_select" != true ] && has_missing_cron_tasks=true
  [ "$choice_xkeen_cron_select" != true ] && has_missing_cron_tasks=true
  [ "$choice_xray_cron_select" != true ] && has_missing_cron_tasks=true

  [ "$choice_geofile_cron_select" = true ] || [ "$choice_xkeen_cron_select" = true ] || [ "$choice_xray_cron_select" = true ] && has_updatable_cron_tasks=true

    if [ "$has_missing_cron_tasks" = true ]; then
        info_content="${info_content}\n\t[info] Будут включены следующие задачи автоматического обновления:\n"
      [ "$choice_geofile_cron_select" != true ] && info_content="${info_content}\t\t[info] GeoFile\n"
      [ "$choice_xkeen_cron_select" != true ] && info_content="${info_content}\t\t[info] Xkeen\n"
      [ "$choice_xray_cron_select" != true ] && info_content="${info_content}\t\t[info] Xray\n"
    fi

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Определение статуса задач автоматического обновления" >> "$xkeen_info_log"
        echo -e "$info_content" | sed '/^$/d' >> "$xkeen_info_log"
        echo "[end] Определение статуса задач автоматического обновления выполнено" >> "$xkeen_info_log"
		echo "" >> "$xkeen_info_log"
    fi
}

logs_choice_cron_time_info_xkeen() {
    info_content=""
    result_content=""

    for task in all geofile xkeen xray; do
        task_var="choice_${task}_cron_select"
        time_var="choice_${task}_cron_time"

        case $task in
            all) task_name="всех";;
            geofile) task_name="GeoFile";;
            xkeen) task_name="Xkeen";;
            xray) task_name="Xray";;
        esac

        if [ "$(eval echo \${$task_var})" = true ]; then
            if [ "$task" = "all" ]; then
                result_content="${result_content}\n[info] Выбранное время автоматического обновления для $task_name задач:"
            else
                result_content="${result_content}\n[info] Выбранное время автоматического обновления для $task_name:"
            fi

            cron_expression=$(eval echo \${$time_var})

            cron_day=$(echo "$cron_expression" | cut -d ' ' -f 5)
            cron_hour=$(echo "$cron_expression" | cut -d ' ' -f 2)
            cron_minute=$(echo "$cron_expression" | cut -d ' ' -f 1)

            case $cron_day in
                0) day="Воскресенье";;
                1) day="Понедельник";;
                2) day="Вторник";;
                3) day="Среда";;
                4) day="Четверг";;
                5) day="Пятница";;
                6) day="Суббота";;
                *) day="Ежедневно";;
            esac

            result_content="${result_content}\n\t[info] $day, в ${cron_hour}:${cron_minute}"
        fi
    done

    if [ -n "$result_content" ]; then
		echo "" >> "$xkeen_info_log"
        echo -n "[start] Определение времени для задач cron" >> "$xkeen_info_log"
        echo -e "$result_content" | sed 's/^/\t/' >> "$xkeen_info_log"
        echo "[end] Определение времени для задач cron выполнено" >> "$xkeen_info_log"
		echo "" >> "$xkeen_info_log"
    fi
}

logs_install_cron_info_xkeen() {
    info_content=""
    error_content=""
    last_line=""

    cron_file_path="$cron_dir/$cron_file"
    
    if [ -f "$cron_file_path" ]; then
        if [ -n "$choice_all_cron_time" ] || [ -n "$choice_geofile_cron_time" ] || [ -n "$choice_xkeen_cron_time" ] || [ -n "$choice_xray_cron_time" ]; then

            if [ -n "$choice_all_cron_time" ] || [ -n "$choice_geofile_cron_time" ]; then
                if grep -q "$install_dir/xkeen.*-ugc" "$cron_file_path"; then
                    task="GeoFile"
                    cron_entry=$(grep "$install_dir/xkeen.*-ugc" "$cron_file_path")
                    info_content="$info_content\t[info] Запись для задачи автоматического обновления $task существует\n"
                    info_content="$info_content\t\t[info] $cron_entry\n"
                    last_line="$cron_entry"
                else
                    error_content="$error_content\t[error] Запись для задачи автоматического обновления GeoFile не существует в cron файле\n"
                fi
            fi

            if [ -n "$choice_all_cron_time" ] || [ -n "$choice_xkeen_cron_time" ]; then
                if grep -q "$install_dir/xkeen.*-ukc" "$cron_file_path"; then
                    task="Xkeen"
                    cron_entry=$(grep "$install_dir/xkeen.*-ukc" "$cron_file_path")
                    info_content="$info_content\t[info] Запись для задачи автоматического обновления $task существует\n"
                    info_content="$info_content\t\t[info] $cron_entry\n"
                    last_line="$cron_entry"
                else
                    error_content="$error_content\t[error] Запись для задачи автоматического обновления Xkeen не существует в cron файле\n"
                fi
            fi

            if [ -n "$choice_all_cron_time" ] || [ -n "$choice_xray_cron_time" ]; then
                if grep -q "$install_dir/xkeen.*-uxc" "$cron_file_path"; then
                    task="Xray"
                    cron_entry=$(grep "$install_dir/xkeen.*-uxc" "$cron_file_path")
                    info_content="$info_content\t[info] Запись для задачи автоматического обновления $task существует\n"
                    info_content="$info_content\t\t[info] $cron_entry\n"
                    last_line="$cron_entry"
                else
                    error_content="$error_content\t[error] Запись для задачи автоматического обновления Xray не существует в cron файле\n"
                fi
            fi
        fi
    else
        error_content="$error_content\t[error] Файл cron не найден\n"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка внесенных записей в Cron" >> "$xkeen_error_log"
        echo -e "$error_content" | sed 's/^/\t/' >> "$xkeen_error_log"
        if [ -n "$last_line" ]; then
            echo "[end] Проверка внесенных записей в Cron завершилась с ошибками" >> "$xkeen_error_log"
        else
            echo -n "[end] Проверка внесенных записей в Cron завершилась с ошибками" >> "$xkeen_error_log"
        fi
        echo "" >> "$xkeen_error_log"
    fi

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка внесенных записей в Cron" >> "$xkeen_info_log"
        echo -e "$info_content" | sed 's/^/\t/' >> "$xkeen_info_log"
        if [ -n "$last_line" ]; then
            echo "[end] Проверка внесенных записей в Cron выполнена" >> "$xkeen_info_log"
        else
            echo -n "[end] Проверка внесенных записей в Cron выполнена" >> "$xkeen_info_log"
        fi
        echo "" >> "$xkeen_info_log"
    fi
}


logs_delete_geoip_info_xkeen() {
    info_content=""
    error_content=""

    if [ -f "$geo_dir/geoip_antifilter.dat" ]; then
        info_content="${info_content}\t[info] Файл geoip_antifilter.dat отсутствует в директории '$geo_dir'\n"
    else
        error_content="${error_content}\t[error] Файл geoip_antifilter.dat не удален. Возможно его и не было в процессе установки\n"
    fi

    if [ -f "$geo_dir/geoip_v2fly.dat" ]; then
        info_content="${info_content}\t[info] Файл geoip_v2fly.dat отсутствует в директории '$geo_dir'\n"
    else
        error_content="${error_content}\t[error] Файл geoip_v2fly.dat не удален. Возможно его и не было в процессе установки\n"
    fi

    if [ -f "$geo_dir/geoip_zkeenip.dat" ]; then
        info_content="${info_content}\t[info] Файл geoip_zkeenip.dat отсутствует в директории '$geo_dir'\n"
    else
        error_content="${error_content}\t[error] Файл geoip_zkeenip.dat не удален. Возможно его и не было в процессе установки\n"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка файлов GeoSite" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo "[end] Проверка файлов GeoSite выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка файлов GeoSite" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Проверка файлов GeoSite выполнена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
}

logs_delete_geosite_info_xkeen() {
    info_content=""
    error_content=""

    if [ -f "$geo_dir/geosite_antifilter.dat" ]; then
        info_content="${info_content}\t[info] Файл geosite_antifilter.dat отсутствует в директории '$geo_dir'\n"
    else
        error_content="${error_content}\t[error] Файл geosite_antifilter.dat не удален. Возможно его и не было в процессе установки\n"
    fi

    if [ -f "$geo_dir/geosite_v2fly.dat" ]; then
		info_content="${info_content}\t[info] Файл geosite_v2fly.dat отсутствует в директории '$geo_dir'\n"	
    else
		error_content="${error_content}\t[error] Файл geosite_v2fly.dat не удален. Возможно его и не было в процессе установки\n"
    fi

    if [ -f "$geo_dir/geosite_zkeen.dat" ]; then
		info_content="${info_content}\t[info] Файл geosite_zkeen.dat отсутствует в директории '$geo_dir'\n"
    else
        error_content="${error_content}\t[error] Файл geosite_zkeen.dat не удален. Возможно его и не было в процессе установки\n"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка файлов GeoSite" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo "[end] Проверка файлов GeoSite выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка файлов GeoSite" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Проверка файлов GeoSite выполнена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
}

logs_delete_cron_task_info_xkeen() {
    info_content=""
    
    if [ -f "$cron_dir/$cron_file" ]; then
        if [ "$choice_all_cron_select" = true ] || [ "$choice_delete_all_cron_select" = true ]; then
            grep -q "ug\|uk\|ux" "$cron_dir/$cron_file"
            if [ $? -eq 1 ]; then
                info_content="\t[info] Все задачи автоматического обновления удалены из cron"
            fi
        else
            if [ "$choice_geofile_cron_select" = true ]; then
                logs_delete_cron_geofile_info_xkeen
            fi

            if [ "$choice_xkeen_cron_select" = true ]; then
                logs_delete_cron_xkeen_info_xkeen
            fi
            
            if [ "$choice_xray_cron_select" = true ]; then
                logs_delete_cron_xray_info_xkeen
            fi
        fi

        if [ -n "$info_content" ]; then
            echo "" >> "$xkeen_info_log"
            echo "[start] Удаление cron задач" >> "$xkeen_info_log"
            echo -e "$info_content" >> "$xkeen_info_log"
            echo "[end] Удаление cron задач выполнено" >> "$xkeen_info_log"
            echo "" >> "$xkeen_info_log"
        fi
    fi
}

logs_delete_cron_geofile_info_xkeen() {
    info_content=""
    
    if [ -f "$cron_dir/$cron_file" ]; then
        grep -q "ug" "$cron_dir/$cron_file"
        if [ $? -eq 1 ]; then
            info_content="\t[info] Задача автоматического обновления для GeoFile удалена из cron"
        fi
        
        if [ -n "$info_content" ]; then
            echo "" >> "$xkeen_info_log"
            echo "[start] Удаление задачи автоматического обновления GeoFile из cron" >> "$xkeen_info_log"
            echo -e "$info_content" >> "$xkeen_info_log"
            echo "[end] Удаление задачи автоматического обновления GeoFile из cron выполнено" >> "$xkeen_info_log"
            echo "" >> "$xkeen_info_log"
        fi
    fi
}

logs_delete_cron_xkeen_info_xkeen() {
    info_content=""
    
    if [ -f "$cron_dir/$cron_file" ]; then
        grep -q "uk" "$cron_dir/$cron_file"
        if [ $? -eq 1 ]; then
            info_content="\t[info] Задача автоматического обновления для XKeen удалена из cron"
        fi
        
        if [ -n "$info_content" ]; then
            echo "" >> "$xkeen_info_log"
            echo "[start] Удаление задачи автоматического обновления XKeen из cron" >> "$xkeen_info_log"
            echo -e "$info_content" >> "$xkeen_info_log"
            echo "[end] Удаление задачи автоматического обновления XKeen из cron выполнено" >> "$xkeen_info_log"
            echo "" >> "$xkeen_info_log"
        fi
    fi
}

logs_delete_cron_xray_info_xkeen() {
    info_content=""
    
    if [ -f "$cron_dir/$cron_file" ]; then
        grep -q "ux" "$cron_dir/$cron_file"
        if [ $? -eq 1 ]; then
            info_content="\t[info] Задача автоматического обновления для Xray удалена из cron"
        fi
        
        if [ -n "$info_content" ]; then
            echo "" >> "$xkeen_info_log"
            echo "[start] Удаление задачи автоматического обновления Xray из cron" >> "$xkeen_info_log"
            echo -e "$info_content" >> "$xkeen_info_log"
            echo "[end] Удаление задачи автоматического обновления Xray из cron выполнено" >> "$xkeen_info_log"
            echo "" >> "$xkeen_info_log"
        fi
    fi
}

logs_delete_configs_info_xkeen() {
    info_content=""
    error_content=""
    
    deleted_files=$(find "$install_conf_dir" -name "*.json" -type f)
    
    if [ -z "$deleted_files" ]; then
        info_content="\t[info] Все конфигурационные файлы Xray успешно удалены"
    else
        error_content="\t[error] Не удалены следующие конфигурационные файлы:\n"
        error_content="${error_content}$deleted_files\n"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка удаления конфигурационных файлов Xray" >> "$xkeen_error_log"
        echo -e "$error_content" | sed 's/^/\t/' >> "$xkeen_error_log"
        echo "[end] Проверка удаления конфигурационных файлов Xray выполнена" >> "$xkeen_error_log"
		echo "" >> "$xkeen_error_log"
    fi

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка удаления конфигурационных файлов Xray" >> "$xkeen_info_log"
        echo -e "$info_content" | sed 's/^/\t/' >> "$xkeen_info_log"
        echo "[end] Проверка удаления конфигурационных файлов Xray выполнена" >> "$xkeen_info_log"
		echo "" >> "$xkeen_info_log"
    fi
}


logs_register_xray_control_info_xkeen() {
    info_content=""
    error_content=""
    
    control_file_path="$register_dir/xray_s.control"
    
    if [ -f "$control_file_path" ]; then
        info_content="$info_content\t[info] Файл xray_s.control найден в директории '$register_dir/'"
    else
        error_content="$error_content\t[error] Файл xray_s.control не найден в директории '$register_dir/'"
    fi
    
    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка файла xray_s.control" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo "[end] Проверка файла xray_s.control завершилось с ошибками" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка файла xray_s.control" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Проверка файла xray_s.control выполнено" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
}

logs_register_xray_list_info_xkeen() {
    info_content=""
    error_content=""
    
    cd "$register_dir/" || exit

    if [ ! -f "xray_s.list" ]; then
        error_content="$error_content\t[error] Файл xray_s.list не найден в директории '$register_dir/'"
    else
        info_content="$info_content\t[info] Файл xray_s.list найден в директории '$register_dir/'"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка файла с путями xray" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo "[end] Проверка файла с путями xray не выполнено" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка файла с путями xray" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Проверка файла с путями xray выполнено" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
}

logs_register_xray_status_info_xkeen() {
    info_content=""
    error_content=""

    if grep -q "Package: xray" "$status_file"; then
        info_content="\t[info] Запись Xray найдена в '$status_file'"
    else
        error_content="\t[error] Запись Xray не найдена в '$status_file'"
    fi
    
    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка регистрации Xray в Status" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Проверка регистрации Xray в Status выполнена" >> "$xkeen_info_log"
		echo "" >> "$xkeen_info_log"
    fi
    
    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка регистрации Xray в Status" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo "[end] Проверка регистрации Xray в Status выполнена" >> "$xkeen_error_log"
		echo "" >> "$xkeen_error_log"
    fi
}


logs_register_xray_initd_info_xkeen() {
    info_content=""
    error_content=""

    initd_file="$initd_dir/S24xray"

    if [ -f "$initd_file" ]; then
        info_content="\t[info] init скрипт Xray найден в директории '$initd_dir/'"
    else
        error_content="\t[error] init скрипт Xray не найден в директории '$initd_dir/'"
    fi
    
    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка наличия init скрипта Xray" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Проверка наличия init xray выполнена" >> "$xkeen_info_log"
		echo "" >> "$xkeen_info_log"
    fi
    
    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Создание или замена файла init скрипта xray" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo "[end] Создание или замена файла init скрипта xray завершилось с ошибками" >> "$xkeen_error_log"
		echo "" >> "$xkeen_error_log"
    fi
}

logs_register_xkeen_list_info_xkeen() {
    info_content=""
    error_content=""
	
    cd "$register_dir/" || exit

    if [ ! -f "xkeen.list" ]; then
        error_content="$error_content\t[error] Файл xkeen.list не найден в директории '$register_dir/'"
    else
        info_content="$info_content\t[info] Файл xkeen.list не найден в директории '$register_dir/'\n"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка файла xkeen.list" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo "[end] Проверка файла xkeen.list выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка файла xkeen.list" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Проверка файла xkeen.list выполнена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
}


logs_register_xkeen_control_info_xkeen() {
    info_content=""
    error_content=""

    if [ -f "$register_dir/xkeen.control" ]; then
        info_content="\n[info] Файл xkeen.control найден в директории '$register_dir/'"
    else
        error_content="\n[error] Файл xkeen.control найден в директории '$register_dir/'"
    fi
    
    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка файла xkeen.control" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo -n "[end] Проверка файла xkeen.control выполнено" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
    
    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка файла xkeen.control" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo -n "[end] Проверка файла xkeen.control завершилось с ошибками" >> "$xkeen_error_log"
		echo "" >> "$xkeen_error_log"
    fi
}


logs_register_xkeen_status_info_xkeen() {
    info_content=""
    error_content=""

    if grep -q "Package: xkeen" "$status_file"; then
        info_content="\t[info] Запись XKeen найдена в '$status_file'"
    else
        error_content="\t[error] Запись XKeen не найдена в '$status_file'"
    fi
    
    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка регистрации XKeen в Status" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Проверка регистрации XKeen в Status выполнена" >> "$xkeen_info_log"
		echo "" >> "$xkeen_info_log"
    fi
    
    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка регистрации XKeen в Status" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo "[end] Проверка регистрации XKeen в Status выполнена" >> "$xkeen_error_log"
		echo "" >> "$xkeen_error_log"
    fi
}

logs_delete_register_xray_info_xkeen() {
    info_content=""
    error_content=""

    if [ ! -f "$register_dir/xray_s.list" ]; then
        info_content="$info_content\t[info] Файл xray_s.list не найден в директории '$register_dir/'\n"
    else
        error_content="$error_content\t[error] Файл xray_s.list найден в директории '$register_dir/'\n"
    fi

    if [ ! -f "$register_dir/xray_s.control" ]; then
        info_content="$info_content\t[info] Файл xray_s.control не найден в директории '$register_dir/'\n"
    else
        error_content="$error_content\t[error] Файл xray_s.control найден в директории '$register_dir/'\n"
    fi

    if ! grep -q 'Package: xray' "$status_file"; then
        info_content="$info_content\t[info] Регистрация пакета xray не обнаружена в '$status_file'"
    else
        error_content="$error_content\t[error] Регистрация пакета xray обнаружена в '$status_file'"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка удаления регистрации Xray" >> "$xkeen_error_log"
        echo -e "$error_content" | sed 's/^/\t/' >> "$xkeen_error_log"
        echo "[end] Проверка удаления регистрации Xray выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка удаления регистрации Xray" >> "$xkeen_info_log"
        echo -e "$info_content" | sed 's/^/\t/' >> "$xkeen_info_log"
        echo "[end] Проверка удаления регистрации Xray выполнена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
}

logs_delete_register_xkeen_info_xkeen() {
    info_content=""
    error_content=""

    if [ ! -f "$register_dir/xkeen.list" ]; then
        info_content="$info_content\t[info] Файл xkeen.list не найден в директории '$register_dir/'\n"
    else
        error_content="$error_content\t[error] Файл xkeen.list найден в директории '$register_dir/'\n"
    fi

    if [ ! -f "$register_dir/xkeen.control" ]; then
        info_content="$info_content\t[info] Файл xkeen.control не найден в директории '$register_dir/'\n"
    else
        error_content="$error_content\t[error] Файл xkeen.control найден в директории '$register_dir/'\n"
    fi

    if ! grep -q 'Package: xkeen' "$status_file"; then
        info_content="$info_content\t[info] Регистрация пакета xkeen не обнаружена в '$status_file'"
    else
        error_content="$error_content\t[error] Регистрация пакета xkeen обнаружена в '$status_file'"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка удаления регистрации XKeen" >> "$xkeen_error_log"
        echo -e "$error_content" | sed 's/^/\t/' >> "$xkeen_error_log"
        echo "[end] Проверка удаления регистрации XKeen выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка удаления регистрации XKeen" >> "$xkeen_info_log"
        echo -e "$info_content" | sed 's/^/\t/' >> "$xkeen_info_log"
        echo "[end] Проверка удаления регистрации XKeen выполнена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
}

logs_register_cron_initd_info_xkeen() {
    info_content=""
    error_content=""

    initd_file="$initd_dir/S05crond"

    if [ -f "$initd_file" ]; then
        info_content="\t[info] init скрипт Cron найден в директории '$initd_dir/'"
    else
        error_content="\t[error] init скрипт Cron не найден в директории '$initd_dir/'"
    fi
    
    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка наличия init скрипта Cron" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Проверка наличия init Cron выполнена" >> "$xkeen_info_log"
		echo "" >> "$xkeen_info_log"
    fi
    
    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Создание или замена файла init скрипта Cron" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo "[end] Создание или замена файла init скрипта Cron выполнена" >> "$xkeen_error_log"
		echo "" >> "$xkeen_error_log"
    fi
}

logs_delete_tmp_info_xkeen() {
    info_content=""
    error_content=""

    if [ ! -d "$tmp_dir_global/xkeen" ]; then
        info_content="$info_content\t[info] Временная директория $tmp_dir_global/xkeen успешно удалена\n"
    else
        error_content="$error_content\t[error] Временная директория $tmp_dir_global/xkeen не удалена\n"
    fi
	
	if [ ! -f "$cron_dir/root.tmp" ]; then
        info_content="$info_content\t[info] Временный файл $cron_dir/root.tmp успешно удален"
    else
        error_content="$error_content\t[error] Временный файл $cron_dir/root.tmp не удален"
    fi

    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Удаление временной директории" >> "$xkeen_error_log"
        echo -e "$error_content" >> "$xkeen_error_log"
        echo "[end] Удаление временной директории выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi

    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Удаление временной директории" >> "$xkeen_info_log"
        echo -e "$info_content" >> "$xkeen_info_log"
        echo "[end] Удаление временной директории выполнено" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
}

logs_file_check_xray_xkeen() {
    info_content=""
    error_content=""
	
	if [ ! -f "/opt/sbin/xray" ]; then
		error_content="$error_content\t[error] Файл 'xray' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'xray' найден\n"
	fi

	if [ ! -f "/opt/etc/xray/dat/geosite_antifilter.dat" ]; then
		error_content="$error_content\t[error] Файл 'geosite_antifilter.dat' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'geosite_antifilter.dat' найден\n"
	fi

	if [ ! -f "/opt/etc/xray/dat/geosite_v2fly.dat" ]; then
		error_content="$error_content\t[error] Файл 'geosite_v2fly.dat' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'geosite_v2fly.dat' найден\n"
	fi

	if [ ! -f "/opt/etc/xray/dat/geosite_zkeen.dat" ]; then
		error_content="$error_content\t[error] Файл 'geosite_zkeen.dat' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'geosite_zkeen.dat' найден\n"
	fi

	if [ ! -f "/opt/etc/xray/dat/geoip_antifilter.dat" ]; then
		error_content="$error_content\t[error] Файл 'geoip_antifilter.dat' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'geoip_antifilter.dat' найден\n"
	fi

	if [ ! -f "/opt/etc/xray/dat/geoip_v2fly.dat" ]; then
		error_content="$error_content\t[error] Файл 'geoip_v2fly.dat' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'geoip_v2fly.dat' найден\n"
	fi

	if [ ! -f "/opt/etc/xray/dat/geoip_zkeenip.dat" ]; then
		error_content="$error_content\t[error] Файл 'geoip_zkeenip.dat' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'geoip_zkeenip.dat' найден\n"
	fi

	if [ ! -f "/opt/etc/xray/configs/01_log.json" ]; then
		error_content="$error_content\t[error] Файл '01_log.json' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_log.json' найден\n"
	fi

	if [ ! -f "/opt/etc/xray/configs/04_inbounds.json" ]; then
		error_content="$error_content\t[error] Файл '03_inbounds.json' не найден\n"
	else
		info_content="$info_content\t[info] Файл '03_inbounds.json' найден\n"
	fi

	if [ ! -f "/opt/etc/xray/configs/05_outbounds.json" ]; then
		error_content="$error_content\t[error] Файл '04_outbounds.json' не найден\n"
	else
		info_content="$info_content\t[info] Файл '04_outbounds.json' найден\n"
	fi

	if [ ! -f "/opt/etc/xray/configs/05_routing.json" ]; then
		error_content="$error_content\t[error] Файл '05_routing.json' не найден\n"
	else
		info_content="$info_content\t[info] Файл '05_routing.json' найден\n"
	fi

	if [ ! -f "/opt/etc/xray/configs/06_policy.json" ]; then
		error_content="$error_content\t[error] Файл '06_policy.json' не найден\n"
	else
		info_content="$info_content\t[info] Файл '06_policy.json' найден\n"
	fi

	if [ ! -f "/opt/etc/init.d/S24xray" ]; then
		error_content="$error_content\t[error] Файл 'S24xray' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'S24xray' найден\n"
	fi

	if [ ! -f "/opt/etc/init.d/S99xkeenstart" ]; then
		error_content="$error_content\t[error] Файл 'S99xkeenstart' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'S99xkeenstart' найден\n"
	fi

	if [ ! -f "/opt/var/log/xray/error.log" ]; then
		error_content="$error_content\t[error] Файл 'error.log' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'error.log' найден\n"
	fi

	if [ ! -f "/opt/var/log/xray/access.log" ]; then
		error_content="$error_content\t[error] Файл 'access.log' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'access.log' найден\n"
	fi

	if [ ! -f "/opt/var/run/xray.pid" ]; then
		error_content="$error_content\t[error] Файл 'xray.pid' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'xray.pid' найден\n"
	fi


    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка установленных файлов Xray" >> "$xkeen_error_log"
        echo -e "$error_content" | sed '/^$/d' >> "$xkeen_error_log"
        echo "[end] Проверка установленных файлов Xray выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi
	
    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка установленных файлов Xray" >> "$xkeen_info_log"
        echo -e "$info_content" | sed '/^$/d' >> "$xkeen_info_log"
        echo "[end] Проверка установленных файлов Xray выполнена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
}

logs_file_check_xkeen_xkeen() {
    info_content=""
    error_content=""
		
	if [ ! -f "/opt/sbin/xkeen" ]; then
		error_content="$error_content\t[error] Файл 'xkeen' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'xkeen' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/import.sh" ]; then
		error_content="$error_content\t[error] Файл 'import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/author.sh" ]; then
		error_content="$error_content\t[error] Файл 'author.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'author.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/01_info/00_info_import.sh" ]; then
		error_content="$error_content\t[error] Файл '00_info_import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '00_info_import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/01_info/01_info_variable.sh" ]; then
		error_content="$error_content\t[error] Файл '01_info_variable.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_info_variable.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/01_info/02_info_packages.sh" ]; then
		error_content="$error_content\t[error] Файл '02_info_packages.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '02_info_packages.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/01_info/03_info_cpu.sh" ]; then
		error_content="$error_content\t[error] Файл '03_info_cpu.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '03_info_cpu.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/01_info/04_info_xray.sh" ]; then
		error_content="$error_content\t[error] Файл '04_info_xray.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '04_info_xray.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/01_info/05_info_geosite.sh" ]; then
		error_content="$error_content\t[error] Файл '05_info_geosite.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '05_info_geosite.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/01_info/06_info_geoip.sh" ]; then
		error_content="$error_content\t[error] Файл '06_info_geoip.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '06_info_geoip.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/01_info/07_info_cron.sh" ]; then
		error_content="$error_content\t[error] Файл '07_info_cron.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '07_info_cron.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/01_info/08_info_version/00_version_import.sh" ]; then
		error_content="$error_content\t[error] Файл '00_version_import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '00_version_import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/01_info/08_info_version/01_version_xkeen.sh" ]; then
		error_content="$error_content\t[error] Файл '01_version_xkeen.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_version_xkeen.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/01_info/08_info_version/02_version_xray.sh" ]; then
		error_content="$error_content\t[error] Файл '02_version_xray.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '02_version_xray.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/01_info/09_info_compare/00_compare_import.sh" ]; then
		error_content="$error_content\t[error] Файл '00_compare_import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '00_compare_import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/01_info/09_info_compare/01_compare_xkeen.sh" ]; then
		error_content="$error_content\t[error] Файл '01_compare_xkeen.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_compare_xkeen.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/01_info/09_info_compare/02_compare_xray.sh" ]; then
		error_content="$error_content\t[error] Файл '02_compare_xray.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '02_compare_xray.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/00_install_import.sh" ]; then
		error_content="$error_content\t[error] Файл '00_install_import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '00_install_import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/01_install_packages.sh" ]; then
		error_content="$error_content\t[error] Файл '01_install_packages.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_install_packages.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/02_install_xray.sh" ]; then
		error_content="$error_content\t[error] Файл '02_install_xray.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '02_install_xray.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/03_install_xkeen.sh" ]; then
		error_content="$error_content\t[error] Файл '03_install_xkeen.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '03_install_xkeen.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/04_install_geosite.sh" ]; then
		error_content="$error_content\t[error] Файл '04_install_geosite.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '04_install_geosite.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/05_install_geoip.sh" ]; then
		error_content="$error_content\t[error] Файл '05_install_geoip.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '05_install_geoip.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/06_install_cron.sh" ]; then
		error_content="$error_content\t[error] Файл '06_install_cron.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '06_install_cron.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/07_install_register/00_register_import.sh" ]; then
		error_content="$error_content\t[error] Файл '00_register_import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '00_register_import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/07_install_register/01_register_xray.sh" ]; then
		error_content="$error_content\t[error] Файл '01_register_xray.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_register_xray.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/07_install_register/01_register_mihomo.sh" ]; then
		error_content="$error_content\t[error] Файл '01_register_mihomo.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_register_mihomo.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/07_install_register/02_register_xkeen.sh" ]; then
		error_content="$error_content\t[error] Файл '02_register_xkeen.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '02_register_xkeen.sh' найден\n"
	fi
	
	if [ ! -f "/opt/sbin/.xkeen/02_install/07_install_register/03_register_cron.sh" ]; then
		error_content="$error_content\t[error] Файл '03_register_cron.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '03_register_cron.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/08_install_configs/00_configs_import.sh" ]; then
		error_content="$error_content\t[error] Файл '00_configs_import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '00_configs_import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/08_install_configs/01_configs_install.sh" ]; then
		error_content="$error_content\t[error] Файл '01_configs_install.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_configs_install.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/08_install_configs/02_configs_dir/01_log.json" ]; then
		error_content="$error_content\t[error] Файл '01_log.json' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_log.json' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/08_install_configs/02_configs_dir/03_inbounds.json" ]; then
		error_content="$error_content\t[error] Файл '03_inbounds.json' не найден\n"
	else
		info_content="$info_content\t[info] Файл '03_inbounds.json' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/08_install_configs/02_configs_dir/04_outbounds.json" ]; then
		error_content="$error_content\t[error] Файл '04_outbounds.json' не найден\n"
	else
		info_content="$info_content\t[info] Файл '04_outbounds.json' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/08_install_configs/02_configs_dir/05_routing.json" ]; then
		error_content="$error_content\t[error] Файл '05_routing.json' не найден\n"
	else
		info_content="$info_content\t[info] Файл '05_routing.json' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/02_install/08_install_configs/02_configs_dir/06_policy.json" ]; then
		error_content="$error_content\t[error] Файл '06_policy.json' не найден\n"
	else
		info_content="$info_content\t[info] Файл '06_policy.json' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/03_delete/00_delete_import.sh" ]; then
		error_content="$error_content\t[error] Файл '00_delete_import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '00_delete_import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/03_delete/01_delete_geosite.sh" ]; then
		error_content="$error_content\t[error] Файл '01_delete_geosite.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_delete_geosite.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/03_delete/02_delete_geoip.sh" ]; then
		error_content="$error_content\t[error] Файл '02_delete_geoip.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '02_delete_geoip.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/03_delete/03_delete_cron.sh" ]; then
		error_content="$error_content\t[error] Файл '03_delete_cron.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '03_delete_cron.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/03_delete/04_delete_configs.sh" ]; then
		error_content="$error_content\t[error] Файл '04_delete_configs.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '04_delete_configs.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/03_delete/05_delete_register.sh" ]; then
		error_content="$error_content\t[error] Файл '05_delete_register.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '05_delete_register.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/03_delete/06_delete_tmp.sh" ]; then
		error_content="$error_content\t[error] Файл '06_delete_tmp.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '06_delete_tmp.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/01_tools_logs/00_logs_import.sh" ]; then
		error_content="$error_content\t[error] Файл '00_logs_import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '00_logs_import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/01_tools_logs/01_logs_clear.sh" ]; then
		error_content="$error_content\t[error] Файл '01_logs_clear.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_logs_clear.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/01_tools_logs/02_logs_console.sh" ]; then
		error_content="$error_content\t[error] Файл '02_logs_console.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '02_logs_console.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/01_tools_logs/03_logs_xkeen.sh" ]; then
		error_content="$error_content\t[error] Файл '03_logs_xkeen.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '03_logs_xkeen.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/02_tools_choice/00_choice_import.sh" ]; then
		error_content="$error_content\t[error] Файл '00_choice_import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '00_choice_import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/02_tools_choice/01_choice_input.sh" ]; then
		error_content="$error_content\t[error] Файл '01_choice_input.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_choice_input.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/02_tools_choice/02_choice_geosite.sh" ]; then
		error_content="$error_content\t[error] Файл '02_choice_geosite.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '02_choice_geosite.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/02_tools_choice/03_choice_geoip.sh" ]; then
		error_content="$error_content\t[error] Файл '03_choice_geoip.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '03_choice_geoip.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/02_tools_choice/04_choice_cron/00_cron_import.sh" ]; then
		error_content="$error_content\t[error] Файл '00_cron_import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '00_cron_import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/02_tools_choice/04_choice_cron/01_cron_status.sh" ]; then
		error_content="$error_content\t[error] Файл '01_cron_status.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_cron_status.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/02_tools_choice/04_choice_cron/02_cron_time.sh" ]; then
		error_content="$error_content\t[error] Файл '02_cron_time.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '02_cron_time.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/03_tools_backups/00_backups_import.sh" ]; then
		error_content="$error_content\t[error] Файл '00_backups_import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '00_backups_import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/03_tools_backups/01_backups_xray.sh" ]; then
		error_content="$error_content\t[error] Файл '01_backups_xray.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_backups_xray.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/03_tools_backups/02_backups_configs.sh" ]; then
		error_content="$error_content\t[error] Файл '02_backups_configs.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '02_backups_configs.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/03_tools_backups/02_backups_xkeen.sh" ]; then
		error_content="$error_content\t[error] Файл '02_backups_xkeen.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '02_backups_xkeen.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/04_tools_downloaders/00_downloaders_import.sh" ]; then
		error_content="$error_content\t[error] Файл '00_downloaders_import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '00_downloaders_import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/04_tools_downloaders/01_downloaders_xray.sh" ]; then
		error_content="$error_content\t[error] Файл '01_downloaders_xray.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_downloaders_xray.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/04_tools_downloaders/01_donwloaders_mihomo.sh" ]; then
		error_content="$error_content\t[error] Файл '01_donwloaders_mihomo.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_donwloaders_mihomo.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/04_tools_downloaders/02_donwloaders_xkeen.sh" ]; then
		error_content="$error_content\t[error] Файл '02_donwloaders_xkeen.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '02_donwloaders_xkeen.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/00_tools_import.sh" ]; then
		error_content="$error_content\t[error] Файл '00_tools_import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '00_tools_import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/04_tools/05_tools_archive.sh" ]; then
		error_content="$error_content\t[error] Файл '05_tools_archive.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '05_tools_archive.sh' найден\n"
	fi
	
	if [ ! -f "/opt/sbin/.xkeen/04_tools/06_tools_ports.sh" ]; then
		error_content="$error_content\t[error] Файл '06_tools_ports.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '06_tools_ports.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/05_tests/00_tests_import.sh" ]; then
		error_content="$error_content\t[error] Файл '00_tests_import.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '00_tests_import.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/05_tests/01_tests_connected.sh" ]; then
		error_content="$error_content\t[error] Файл '01_tests_connected.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '01_tests_connected.sh' найден\n"
	fi

	if [ ! -f "/opt/sbin/.xkeen/05_tests/02_tests_xports.sh" ]; then
		error_content="$error_content\t[error] Файл '02_tests_xports.sh' не найден\n"
	else
		info_content="$info_content\t[info] Файл '02_tests_xports.sh' найден\n"
	fi

	if [ ! -f "/opt/var/log/xkeen/error.log" ]; then
		error_content="$error_content\t[error] Файл 'error.log' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'error.log' найден\n"
	fi

	if [ ! -f "/opt/var/log/xkeen/info.log" ]; then
		error_content="$error_content\t[error] Файл 'info.log' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'info.log' найден\n"
	fi

	if [ ! -f "/opt/etc/init.d/S05crond" ]; then
		error_content="$error_content\t[error] Файл 'S05crond' не найден\n"
	else
		info_content="$info_content\t[info] Файл 'S05crond' найден\n"
	fi
	
    if [ -n "$error_content" ]; then
        echo "" >> "$xkeen_error_log"
        echo "[start] Проверка установленных файлов XKeen" >> "$xkeen_error_log"
        echo -e "$error_content" | sed '/^$/d' >> "$xkeen_error_log"
        echo "[end] Проверка установленных файлов XKeen выполнена" >> "$xkeen_error_log"
        echo "" >> "$xkeen_error_log"
    fi
	
    if [ -n "$info_content" ]; then
        echo "" >> "$xkeen_info_log"
        echo "[start] Проверка установленных файлов XKeen" >> "$xkeen_info_log"
        echo -e "$info_content" | sed '/^$/d' >> "$xkeen_info_log"
        echo "[end] Проверка установленных файлов XKeen выполнена" >> "$xkeen_info_log"
        echo "" >> "$xkeen_info_log"
    fi
}
