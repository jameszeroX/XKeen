Обычная установка XKeen и необходимых компонентов выполняется в OnLine режиме и жёстко привязана к GitHub, а в случае его недоступности будет невозможна. Поэтому в форк добавлен режим OffLine установки по команде `xkeen -io`

Для OffLine установки необходимо заранее любым способом скачать установочный архив XKeen версии 1.1.3.4+, бинарник xray, подходящей архитектуры, из [репозитория](https://github.com/XTLS/Xray-core/releases/latest) и необходимые dat-файлы. Затем поместить архив XKeen и предварительно извлечённый из архива бинарник xray в папку entware /opt/sbin/, после чего выполнить следующие команды в ssh-консоли entware Keenetic:

```
cd /opt/sbin
tar -xvzf xkeen.tar.gz && rm xkeen.tar.gz
xkeen -io
```

Копирование файлов конфигурации xray и необходимых dat-файлов в директории /opt/etc/xray/configs и /opt/etc/xray/dat выполните вручную, после чего можете запустить проксирование командой `xkeen -start`

При OffLine установке XKeen не проверяет соответствие архитектуры процессора и бинарника xray, поэтому выбирайте нужный бинарник внимательно. Если затрудняетесь в выборе, запустите `xkeen -io` без файла xray в папке /opt/sbin/ и XKeen сообщит, какой бинарник требуется для вашего роутера

При недоступности GitHub, обновление dat-файлов в роутере по планировщику работать не будет, выполняйте его вручную
