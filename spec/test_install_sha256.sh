#!/bin/sh
# Тесты verify_install_sha256() из install.sh (bootstrap-установщик не
# проверял SHA-256 скачанного архива ни в каком режиме).
#
# install.sh standalone (curl | sh, модули ещё не на диске), поэтому функцию
# бьём напрямую, как test_strip_json.sh бьёт strip_json_comments — вырезаем
# её awk'ом из реального файла и подменяем curl/jq/sha256sum фикстурами.
# Каждый сценарий запускается в подоболочке: PATH/переменные окружения не
# просачиваются между проверками.

extract() {
    awk '/^verify_install_sha256\(\) \{/,/^\}/' "$1"
}
eval "$(extract /repo/install.sh)"

# Цвета, которые использует функция в printf, вне install.sh не определены
red=""; yellow=""; green=""; light_blue=""; reset=""
gh_proxy_user=""

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else
        printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1))
    fi
}

work=$(mktemp -d)
fakebin="$work/fakebin"
mkdir -p "$fakebin"
archive="$work/xkeen.tar.gz"
echo "не важно что внутри" > "$archive"

# --- фикстура GitHub API: assets[] с одним xkeen.tar.gz ---
api_fixture() {
    cat <<EOF
{"assets":[{"name":"xkeen.tar.gz","digest":"sha256:$1"},{"name":"other.bin","digest":"sha256:deadbeef"}]}
EOF
}

# Фейковый curl: копирует $FAKE_CURL_BODY в файл, указанный после "-o",
# и помечает факт вызова (нужно доказать, что для --beta API не дёргается).
cat > "$fakebin/curl" <<'CURLEOF'
#!/bin/sh
[ -n "$FAKE_CURL_CALLED_MARKER" ] && touch "$FAKE_CURL_CALLED_MARKER" 2>/dev/null
out=""
prev=""
for a in "$@"; do
    [ "$prev" = "-o" ] && out="$a"
    prev="$a"
done
if [ -n "$out" ] && [ -n "$FAKE_CURL_BODY" ] && [ -f "$FAKE_CURL_BODY" ]; then
    cp "$FAKE_CURL_BODY" "$out"
fi
exit "${FAKE_CURL_RC:-0}"
CURLEOF
chmod +x "$fakebin/curl"

# Фейковый sha256sum: печатает контролируемый хэш вместо реального
cat > "$fakebin/sha256sum" <<'SHAEOF'
#!/bin/sh
printf '%s  %s\n' "${FAKE_SHA256:?FAKE_SHA256 не задан}" "$1"
SHAEOF
chmod +x "$fakebin/sha256sum"

digest_a="aaaa111122223333444455556666777788889999aaaa111122223333444455"
digest_b="bbbb111122223333444455556666777788889999aaaa111122223333444455"
fixture_match="$work/api_match.json"
fixture_mismatch="$work/api_mismatch.json"
api_fixture "$digest_a" > "$fixture_match"
api_fixture "$digest_b" > "$fixture_mismatch"

url_stable="https://github.com/jameszeroX/XKeen/releases/latest/download/xkeen.tar.gz"
url_legacy="https://github.com/jameszeroX/XKeen/releases/download/1.1.3.9/xkeen.tar.gz"
url_beta="https://raw.githubusercontent.com/jameszeroX/XKeen/main/test/xkeen.tar.gz"

# --- каталог PATH без jq (для сценария "jq не установлен") ---
noqjbin="$work/noqjbin"
mkdir -p "$noqjbin"
for b in sed head rm awk mktemp basename cp touch; do
    p=$(command -v "$b" 2>/dev/null) && ln -s "$p" "$noqjbin/$b" 2>/dev/null
done
ln -s "$fakebin/curl" "$noqjbin/curl"

# --- совпадающий digest (stable) → успех, api.github.com реально вызван ---
rc_match=$(
    PATH="$fakebin:$PATH"
    export PATH FAKE_CURL_BODY="$fixture_match" FAKE_CURL_RC=0 \
        FAKE_SHA256="$digest_a" FAKE_CURL_CALLED_MARKER="$work/called.match"
    verify_install_sha256 "$archive" "$url_stable" >"$work/out.match" 2>&1
    echo $?
)
check "совпадающий digest (stable): rc=0" "$rc_match" "0"
check "совпадающий digest: api.github.com вызван" "$([ -f "$work/called.match" ] && echo да || echo нет)" "да"

# --- совпадающий digest (legacy, тег вместо latest) → тоже успех ---
rc_legacy=$(
    PATH="$fakebin:$PATH"
    export PATH FAKE_CURL_BODY="$fixture_match" FAKE_CURL_RC=0 FAKE_SHA256="$digest_a"
    verify_install_sha256 "$archive" "$url_legacy" >/dev/null 2>&1
    echo $?
)
check "совпадающий digest (legacy): rc=0" "$rc_legacy" "0"

# --- несовпадающий digest → провал, сообщение об ошибке, ДО tar/rm archive_name решает caller ---
out_mismatch=$(
    PATH="$fakebin:$PATH"
    export PATH FAKE_CURL_BODY="$fixture_mismatch" FAKE_CURL_RC=0 FAKE_SHA256="$digest_a"
    verify_install_sha256 "$archive" "$url_stable" 2>&1
    echo "___RC=$?"
)
rc_mismatch=$(printf '%s\n' "$out_mismatch" | sed -n 's/^___RC=//p')
check "несовпадающий digest: rc!=0" "$([ "$rc_mismatch" != "0" ] && echo да || echo нет)" "да"
check "несовпадающий digest: сообщение об ошибке" "$(printf '%s\n' "$out_mismatch" | grep -c 'Ошибка')" "1"

# --- jq отсутствует → предупреждение, но rc=0 (не блокирует установку) ---
out_nojq=$(
    PATH="$noqjbin"
    export PATH FAKE_CURL_BODY="$fixture_match" FAKE_CURL_RC=0 FAKE_SHA256="$digest_a"
    verify_install_sha256 "$archive" "$url_stable" 2>&1
    echo "___RC=$?"
)
rc_nojq=$(printf '%s\n' "$out_nojq" | sed -n 's/^___RC=//p')
check "нет jq: rc=0 (не блокирует)" "$rc_nojq" "0"
check "нет jq: печатает предупреждение" "$(printf '%s\n' "$out_nojq" | grep -c 'Предупреждение')" "1"

# --- --beta: api.github.com вообще не дёргается (нет тега/digest у dev-канала) ---
rc_beta=$(
    PATH="$fakebin:$PATH"
    export PATH FAKE_CURL_RC=1 FAKE_CURL_CALLED_MARKER="$work/called.beta"
    verify_install_sha256 "$archive" "$url_beta" >/dev/null 2>&1
    echo $?
)
check "--beta: rc=0 (не наш случай)" "$rc_beta" "0"
check "--beta: curl вообще не вызывался" "$([ -f "$work/called.beta" ] && echo да || echo нет)" "нет"

rm -rf "$work"

printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
