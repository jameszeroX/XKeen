Установочный скрипт XKeen кроме интерактивного режима имеет следующие возможности

- Автоматическая установка
```
# Стабильная версия
sh -c "$(curl -sSL https://raw.githubusercontent.com/jameszeroX/XKeen/main/install.sh)" -- --stable

# Бета-версия
sh -c "$(curl -sSL https://raw.githubusercontent.com/jameszeroX/XKeen/main/install.sh)" -- --beta

# Предыдущая версия (например, 1.1.3.9)
sh -c "$(curl -sSL https://raw.githubusercontent.com/jameszeroX/XKeen/main/install.sh)" -- --legacy 1.1.3.9
```

- Если скрипт сохранён локально
```
# Стабильная версия
./install.sh --stable

# Бета-версия
./install.sh --beta

# Предыдущая версия
./install.sh --legacy 1.1.3.9
```

- Показать справку по параметрам
```
./install.sh --help
```
