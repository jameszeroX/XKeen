# Утилиты для проверки целостности загруженных файлов

# Верификация SHA256 контрольной суммы
# Аргументы: $1 — путь к файлу, $2 — ожидаемый SHA256 хеш
verify_sha256() {
    local_file="$1"
    expected_hash="$2"

    if [ -z "$local_file" ] || [ -z "$expected_hash" ]; then
        return 1
    fi

    if ! [ -f "$local_file" ]; then
        return 1
    fi

    # Вычисляем SHA256 сумму файла
    if command -v sha256sum >/dev/null 2>&1; then
        actual_hash=$(sha256sum "$local_file" | awk '{print $1}')
    elif command -v openssl >/dev/null 2>&1; then
        actual_hash=$(openssl dgst -sha256 "$local_file" | awk '{print $NF}')
    else
        printf "  ${yellow}Предупреждение${reset}: sha256sum/openssl не найдены, проверка целостности пропущена\n"
        return 0
    fi

    # Приводим оба хеша к нижнему регистру для сравнения
    actual_hash=$(printf '%s' "$actual_hash" | tr 'A-F' 'a-f')
    expected_hash=$(printf '%s' "$expected_hash" | tr 'A-F' 'a-f')

    if [ "$actual_hash" = "$expected_hash" ]; then
        return 0
    else
        return 1
    fi
}

# Загрузка и парсинг .dgst файла Xray (содержит MD5, SHA1, SHA2-256, SHA2-512)
# Аргументы: $1 — URL .dgst файла
# Выводит: SHA2-256 хеш
fetch_xray_dgst_sha256() {
    dgst_url="$1"

    dgst_content=$(curl --connect-timeout 10 $curl_timeout -sfL "$dgst_url" 2>/dev/null)
    if [ -z "$dgst_content" ]; then
        return 1
    fi

    # Формат файла .dgst: "SHA2-256= <hash>"
    sha256_hash=$(printf '%s\n' "$dgst_content" | grep -i 'SHA2-256' | sed 's/.*=\s*//' | tr -d '[:space:]')

    if [ -z "$sha256_hash" ]; then
        return 1
    fi

    printf '%s' "$sha256_hash"
}

# Загрузка и верификация бинарника с проверкой контрольной суммы
# Аргументы: $1 — путь к загруженному файлу, $2 — SHA256 хеш
# Возвращает 0 при совпадении, 1 при несовпадении
verify_download_integrity() {
    downloaded_file="$1"
    expected_sha256="$2"

    if [ -z "$expected_sha256" ]; then
        printf "  ${yellow}Предупреждение${reset}: Контрольная сумма недоступна, проверка целостности пропущена\n"
        return 0
    fi

    printf "  ${yellow}Проверка${reset} целостности загруженного файла...\n"

    if verify_sha256 "$downloaded_file" "$expected_sha256"; then
        printf "  Контрольная сумма SHA256 ${green}совпадает${reset}\n"
        return 0
    else
        printf "  ${red}Ошибка${reset}: Контрольная сумма SHA256 ${red}НЕ совпадает${reset}!\n"
        printf "  Файл мог быть подменён при загрузке. Установка прервана\n"
        return 1
    fi
}
