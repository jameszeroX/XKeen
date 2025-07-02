## Версия 1.1.3.8 Preview

- Исправлена загрузка бинарника Mihomo архитектуры mips32
- Добавлена возможность выполнять резервное копирование и восстановление конфигурации Mihomo (параметры `-mb`, `-mbr`)
- Возвращена возможность выполнять резервное копирование и восстановление конфигурации Xray (параметры `-cb`, `-cbr`)
- Исправлено выполнение команды `xkeen -tpx`
- При добавлении/удалении портов проксирования или портов исключений прокси-клиент теперь перезапускается только если был уже запущен
- При обновлении геофайлов прокси-клиент теперь перезапускается только если был уже запущен и используется ядро Xray
- При запуске `xkeen -d` без цифрового параметра, теперь отображается информация о текущей задержке автозапуска
- Не актуальные GeoSite и GeoIP antifilter-community заменены на базы Re:filter
- Удалено логирование процесса установки XKeen в директорию `/opt/var/log/xkeen` (на практике не использовалось)
- Доработка скриптов, исправление обнаруженных багов, добавление новых)

### Порядок установки
```
opkg update && opkg upgrade && opkg install curl tar
curl -OL https://raw.githubusercontent.com/jameszeroX/xkeen/main/test/xkeen.tar.gz
tar -xvzf xkeen.tar.gz -C /opt/sbin > /dev/null && rm xkeen.tar.gz
xkeen -i
```

### Порядок обновления с предыдущей версии
```
opkg update && opkg upgrade && opkg install curl tar
curl -OL https://raw.githubusercontent.com/jameszeroX/xkeen/main/test/xkeen.tar.gz
tar -xvzf xkeen.tar.gz -C /opt/sbin > /dev/null && rm xkeen.tar.gz
xkeen -k
```

Обсудить XKeen и сообщить об ошибках можно в телеграм-чате https://t.me/+SZWOjSlvYpdlNmMy
