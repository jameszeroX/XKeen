# Загрузка с per-call mirror-fallback'ом.
#
# Заменяет паттерн "test_github -> один gh_proxy на сессию -> один curl
# без fallback'а". Старый flow ломается когда выбранный mirror транзиентно
# падает между test_github и фактической загрузкой: curl получает 5xx или
# таймаут, caller тихо return 1, geo-файлы устаревают.
#
# fetch_with_mirrors пробует префиксы по очереди (gh_proxy_user
# exclusive, иначе direct + gh_proxy1 + gh_proxy2), кэширует удачный
# выбор на TTL_SEC, валидирует ответ (HTTP-код + min-size + HTML-stub
# detect). После неудачного вызова caller может прочитать причину из
# глобальных переменных _last_error / _last_size (для fetch) и
# _last_http (для probe), чтобы напечатать осмысленное сообщение.

_mirror_cache="/tmp/.xkeen_mirror_cache"
_mirror_ttl=60
_DIRECT_TOKEN="__direct__"

# Чтение закэшированного префикса. stdout = префикс ("" для direct),
# rc = 0 если кэш свежий, 1 если просрочен/garbage/отсутствует.
_mirror_cache_read() {
    [ -r "$_mirror_cache" ] || return 1
    _cache_ts=""
    _cache_pfx=""
    IFS=' ' read -r _cache_ts _cache_pfx < "$_mirror_cache" 2>/dev/null || return 1
    case "$_cache_ts" in
        ''|*[!0-9]*) return 1 ;;
    esac
    _cache_now=$(date +%s 2>/dev/null) || return 1
    [ $((_cache_now - _cache_ts)) -lt "$_mirror_ttl" ] || return 1
    [ "$_cache_pfx" = "$_DIRECT_TOKEN" ] && _cache_pfx=""
    printf '%s' "$_cache_pfx"
    return 0
}

# Сохранение удачного префикса в кэш. $1 = "" для direct, иначе url.
_mirror_cache_write() {
    _w_pfx="$1"
    [ -z "$_w_pfx" ] && _w_pfx="$_DIRECT_TOKEN"
    printf '%s %s\n' "$(date +%s)" "$_w_pfx" > "$_mirror_cache" 2>/dev/null
}

# Список префиксов для попыток, по одному на строку, в порядке приоритета.
# Используется token __direct__ для direct GitHub (пустая строка ломала
# бы heredoc-итерацию).
_mirror_order() {
    if [ -n "$gh_proxy_user" ]; then
        printf '%s\n' "${gh_proxy_user%/}"
        return
    fi
    _order_cached_set=0
    if _order_cached=$(_mirror_cache_read); then
        _order_cached_set=1
        printf '%s\n' "${_order_cached:-$_DIRECT_TOKEN}"
    fi
    # direct и дефолтные mirror'ы, пропуская тот что уже в кэше
    if [ "$_order_cached_set" = "0" ] || [ -n "$_order_cached" ]; then
        printf '%s\n' "$_DIRECT_TOKEN"
    fi
    if [ -n "$gh_proxy1" ] && [ "$_order_cached" != "${gh_proxy1%/}" ]; then
        printf '%s\n' "${gh_proxy1%/}"
    fi
    if [ -n "$gh_proxy2" ] && [ "$_order_cached" != "${gh_proxy2%/}" ]; then
        printf '%s\n' "${gh_proxy2%/}"
    fi
}

# Дефолтный валидатор для скачанного файла.
# $1 = path, $2 = min_size (байт, 0 = без проверки размера).
# Сетит _last_error и _last_size для caller-сообщений.
#
# HTML-stub detect: cloudflare challenge, jsdelivr "429: Too Many
# Requests", proxy-error 404-page под HTTP 200. Маркеры якорные (^...)
# чтобы не словить false-positive на байтах в gzip/zip/ELF метадате.
_validate_default() {
    _v_f="$1"
    _v_min="${2:-0}"
    _last_error=""
    _last_size=0
    if [ ! -s "$_v_f" ]; then
        _last_error="curl_failed"
        return 1
    fi
    _last_size=$(wc -c < "$_v_f" 2>/dev/null | tr -d ' ')
    if [ "$_v_min" -gt 0 ]; then
        [ -n "$_last_size" ] && [ "$_last_size" -ge "$_v_min" ] || {
            _last_error="size"
            return 1
        }
    fi
    if head -c 100 "$_v_f" 2>/dev/null | grep -iqE '^(<!doctype|<html|<head|<body|404|error|not found)'; then
        _last_error="html_stub"
        return 1
    fi
    return 0
}

# fetch_with_mirrors <url> <dest> [min_size] [validator]
#
# Качает <url> в <dest> через цепочку префиксов, валидирует.
# Атомарная замена: запись в "${dest}.tmp.$$" + mv.
#
# Возврат: 0 на успех, 1 на полный провал (все попытки failed/invalid).
# При rc != 0: _last_error содержит причину последней неудачи
# (curl_failed / size / html_stub), _last_size содержит размер файла
# при size-fail.
fetch_with_mirrors() {
    _fwm_url="$1"
    _fwm_dest="$2"
    _fwm_min="${3:-0}"
    _fwm_validator="${4:-_validate_default}"
    _fwm_tmp="${_fwm_dest}.tmp.$$"
    _fwm_winner=""
    _last_error=""
    _last_size=0

    rm -f "$_fwm_tmp"
    _fwm_orders=$(_mirror_order)
    while IFS= read -r _fwm_prefix; do
        [ "$_fwm_prefix" = "$_DIRECT_TOKEN" ] && _fwm_prefix=""
        if [ -n "$_fwm_prefix" ]; then
            _fwm_fetch="$_fwm_prefix/$_fwm_url"
        else
            _fwm_fetch="$_fwm_url"
        fi
        if eval curl $curl_extra --connect-timeout 10 $curl_timeout \
               -fL -o "$_fwm_tmp" "$_fwm_fetch" >/dev/null 2>&1; then
            if "$_fwm_validator" "$_fwm_tmp" "$_fwm_min"; then
                _fwm_winner="$_fwm_prefix"
                break
            fi
        else
            _last_error="curl_failed"
        fi
        rm -f "$_fwm_tmp"
    done <<EOF
$_fwm_orders
EOF

    if [ -f "$_fwm_tmp" ]; then
        mv -f "$_fwm_tmp" "$_fwm_dest" || { rm -f "$_fwm_tmp"; return 1; }
        _mirror_cache_write "$_fwm_winner"
        _last_error=""
        return 0
    fi
    return 1
}

# probe_with_mirrors <url>
#
# HEAD-probe (с fallback на range-byte для mirror'ов которые не разрешают
# HEAD и отдают 405). Используется в xray/mihomo downloader'ах для
# быстрой проверки "существует ли такая версия" перед полной загрузкой.
#
# Возврат: 0 на 2xx; 2 если все попытки получили 4xx (definitive miss,
# например пользователь ввёл неверную версию); 1 на прочие транзиентные
# ошибки. _last_http содержит HTTP-код последней значимой попытки (для
# error сообщений caller'а), _last_curl_rc содержит exit-код curl
# последней попытки (28 = таймаут, остальные см. man curl).
probe_with_mirrors() {
    _pwm_url="$1"
    _pwm_attempts=0
    _pwm_fail_4xx=0
    _last_http=""
    _last_curl_rc=0

    _pwm_orders=$(_mirror_order)
    while IFS= read -r _pwm_prefix; do
        [ "$_pwm_prefix" = "$_DIRECT_TOKEN" ] && _pwm_prefix=""
        if [ -n "$_pwm_prefix" ]; then
            _pwm_probe="$_pwm_prefix/$_pwm_url"
        else
            _pwm_probe="$_pwm_url"
        fi
        _pwm_attempts=$((_pwm_attempts + 1))
        _pwm_code=$(eval curl $curl_extra --connect-timeout 10 $curl_timeout \
            -I -s -L -w '%{http_code}' -o /dev/null "$_pwm_probe" 2>/dev/null)
        _last_curl_rc=$?
        if [ "$_pwm_code" = "405" ]; then
            _pwm_code=$(eval curl $curl_extra --connect-timeout 10 $curl_timeout \
                -s -L -r 0-0 -w '%{http_code}' -o /dev/null "$_pwm_probe" 2>/dev/null)
            _last_curl_rc=$?
        fi
        _last_http="$_pwm_code"
        case "$_pwm_code" in
            2[0-9][0-9])
                _mirror_cache_write "$_pwm_prefix"
                return 0
                ;;
            40[0-9])
                _pwm_fail_4xx=$((_pwm_fail_4xx + 1))
                ;;
        esac
    done <<EOF
$_pwm_orders
EOF

    [ "$_pwm_attempts" -gt 0 ] && [ "$_pwm_fail_4xx" = "$_pwm_attempts" ] && return 2
    return 1
}
