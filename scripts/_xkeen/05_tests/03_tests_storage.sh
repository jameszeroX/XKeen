# Определение места установки Entware
tests_entware_storage() {
    mount_point=$(mount | grep 'on /opt ')
    device=$(echo "$mount_point" | awk '{print $1}')

    if echo "$device" | grep -q "^/dev/sd"; then
        entware_storage="на внешний USB-накопитель"
    elif echo "$device" | grep -q "^/dev/ubi"; then
        entware_storage="во внутреннюю память роутера"
        preinstall_warn="true"
    fi
}