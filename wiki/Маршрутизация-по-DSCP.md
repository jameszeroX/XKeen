# Маршрутизация по DSCP-меткам в XKeen

> Источник: [jameszero.net/4509.htm](https://jameszero.net/4509.htm)

В XKeen 2.0 появилась возможность маршрутизации по DSCP-меткам QoS. Это позволяет исключить конкретные приложения из проксирования или направить их трафик через прокси на всех портах, что полезно когда компьютер имеет ограничения на порты 80 и 443.

XKeen использует DSCP-значения из диапазона `0-63`. Значение `64` недопустимо, так как выходит за пределы DSCP-поля.

## Настройка в Windows

### Предварительные требования

Требуется полная редакция Windows с поддержкой Group Policy. В начальных редакциях настройка возможна только через реестр.

### Этап 1: Изменение реестра

Примените следующий твик реестра:

```
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\QoS]
"Do not use NLA"="1"
```

Перезагрузите компьютер после применения.

### Этап 2: Проверка параметров сетевой карты

Убедитесь, что включена опция "Планировщик пакетов QoS" в настройках сетевого адаптера.

### Этап 3: Создание QoS-политики

1. Нажмите Win+R и выполните `gpedit.msc`
2. Откройте "QoS на основе политики"
3. В меню "Действие" выберите "Создать новую политику"
4. Пройдите мастер, указав имя политики, DSCP-метку, приложение, IP-адреса, протоколы и порты

По умолчанию XKeen использует:

- `61` - принудительная отправка трафика в отдельный inbound/listener ядра проксирования
- `62` - исключение из проксирования (`direct/exclude`)
- `63` - принудительное попадание трафика в обычную цепочку XKeen

Коды DSCP задаются не в `xkeen.json`, а в отдельном стартовом конфиге XKeen через переменные `dscp_force_proxy`, `dscp_exclude` и `dscp_proxy`.

После создания политики маршрутизация работает сразу без перезагрузки (достаточно перезапустить приложение).

Каждое приложение требует отдельной политики.

## DSCP 61: принудительное проксирование через отдельный inbound/listener

Метка `61` не отправляет трафик напрямую в обычные правила маршрутизации XKeen. Вместо этого XKeen перехватывает такой трафик и отправляет его в отдельный transparent inbound/listener. Дальше Xray выбирает outbound по `inboundTag`, а Mihomo — по `proxy` в listener.

Это позволяет принудительно отправлять трафик конкретного приложения через прокси, даже если обычные правила маршрутизации направили бы его в `direct`.

Поддерживаются только режимы XKeen `TProxy` и `Hybrid`. В режиме `Redirect` функция не работает.

- В режиме `TProxy` DSCP 61 использует отдельный `tproxy` inbound/listener.
- В режиме `Hybrid` DSCP 61 повторяет общую модель XKeen: `TCP -> Redirect`, `UDP -> TProxy`.

Если в `Hybrid` настроен только отдельный `tproxy` inbound/listener без отдельного `redirect` inbound/listener для TCP, XKeen отключит DSCP 61 и покажет причину в `xkeen -dscp`.

### Пример inbound Xray для Hybrid

```json
[
  {
    "port": 1191,
    "protocol": "tunnel",
    "settings": {
      "network": "tcp",
      "followRedirect": true
    },
    "sniffing": {
      "enabled": true,
      "routeOnly": true,
      "destOverride": ["http","tls"]
    },
    "tag": "dscp-force-proxy"
  },
  {
    "port": 1191,
    "protocol": "tunnel",
    "settings": {
      "network": "udp",
      "followRedirect": true
    },
    "streamSettings": {
      "sockopt": {"tproxy": "tproxy"}
    },
    "sniffing": {
      "enabled": true,
      "routeOnly": true,
      "destOverride": ["quic"]
    },
    "tag": "dscp-force-proxy"
  }
]
```

`1191` приведён только как пример. XKeen не использует хардкод порта и определяет его автоматически по inbound с тегом `dscp-force-proxy`.

Также поддерживаются раздельные теги `dscp-force-proxy-redirect` и `dscp-force-proxy-tproxy`, если удобнее явно разделить inbound'ы.

### Пример routing rule Xray

```json
{
  "inboundTag": ["dscp-force-proxy"],
  "outboundTag": "vless-reality"
}
```

Это правило пользователь добавляет самостоятельно. XKeen не изменяет автоматически `routing.rules` и `outbounds`.

Для режима `TProxy` достаточно отдельного inbound'а `tproxy`. Для режима `Hybrid` нужен полноценный split force-path: `redirect` для TCP и `tproxy` для UDP.

### Пример listener Mihomo для Hybrid

```yaml
listeners:
  - name: dscp-force-proxy-redirect
    type: redir
    port: 1191
    listen: 0.0.0.0
    proxy: ProxyTCP
  - name: dscp-force-proxy-tproxy
    type: tproxy
    port: 1192
    listen: 0.0.0.0
    udp: true
    proxy: ProxyUDP
```

или

```yaml
listeners:
  - name: dscp-force-proxy-redirect
    type: redir
    port: 1191
    listen: 0.0.0.0
  - name: dscp-force-proxy-tproxy
    type: tproxy
    port: 1192
    listen: 0.0.0.0
    udp: true

rules:
  - IN-NAME,dscp-force-proxy-redirect,ProxyTCP
  - IN-NAME,dscp-force-proxy-tproxy,ProxyUDP
```

Для режима `TProxy` достаточно listener `dscp-force-proxy` или `dscp-force-proxy-tproxy`. Для режима `Hybrid` нужны оба listener'а.

`ProxyTCP` и `ProxyUDP` должны быть именами существующих исходящих прокси или proxy-group в конфигурации Mihomo.

`proxy` можно указывать либо прямо в listener, либо через правило `IN-NAME,<listener>,<proxy>` в `rules`. XKeen включает `DSCP 61` для Mihomo только если для каждого нужного listener'а найден корректный `type`, валидный `port` и задан `proxy` — либо прямо в listener, либо через `IN-NAME`.

Для `Hybrid` это правило должно быть задано отдельно для каждого listener'а, например `dscp-force-proxy-redirect` и `dscp-force-proxy-tproxy`. Для режима `TProxy` тот же подход работает с `dscp-force-proxy` или `dscp-force-proxy-tproxy`.

### Маркировка трафика в Windows

Для приложений Windows можно использовать QoS Policy, задавая нужную DSCP-метку конкретному исполняемому файлу. Для `DSCP 61` это позволяет принудительно отправлять трафик приложения через выбранный прокси-маршрут.
