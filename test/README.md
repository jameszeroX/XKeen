# XKeen 2.0.1 Beta

- Расширен функционал [маршрутизации по DSCP-меткам](https://github.com/jameszeroX/XKeen/wiki/Маршрутизация-по-DSCP). Добавлена метка `61` - принудительное проксирование через отдельный transparent inbound/listener, в Hybrid с раздельной обработкой TCP/UDP [@MichaelDavislol](https://github.com/MichaelDavislol), [@zxc-rv](https://github.com/zxc-rv)
- **Multi-WAN:** при `proxy_router=on` (проксирование трафика Entware) метка исходящих соединений ядра принимается как `255`, как десятичная метка политики `XKeen`, **либо** как метка пользовательской политики из `xkeen.json` (если она создана в роутере с тем же именем). XKeen вешает для всех этих меток bypass-`RETURN` и валидирует их у outbound'ов. Для egress ядра через выбранного провайдера заменить `255` на метку политики — значение покажет `xkeen -diag`, блок «Метка политики XKeen для проксирования через провайдера».
- Добавлена проверка исправности Entware перед началом установки XKeen
- Исправлена установка/обновление геофайлов и GeoIPSET [известные проблемы](https://github.com/jameszeroX/XKeen/wiki/Knownissues)
- Скрыт выбор установки Mihomo Prerelease-Alpha [известные проблемы](https://github.com/jameszeroX/XKeen/wiki/Knownissues)
- Прочие незначительные фиксы

### Порядок установки/обновления

```bash
opkg update && opkg upgrade && opkg install curl tar && cd /tmp
sh -c "$(curl -sSL https://raw.githubusercontent.com/jameszeroX/XKeen/main/install.sh)"
```

### Порядок обновления с XKeen 2.0

```bash
xkeen -channel # переключитесь на канал разработки
xkeen -uk  # проверьте и установите обновление
```
