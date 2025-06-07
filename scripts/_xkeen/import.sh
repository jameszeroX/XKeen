# Импорт основных модулей и определение их путей

script_dir="$(cd "$(dirname "$0")" && pwd)"
xinfo_dir="$script_dir/.xkeen/01_info"
xinstall_dir="$script_dir/.xkeen/02_install"
xdelete_dir="$script_dir/.xkeen/03_delete"
xtools_dir="$script_dir/.xkeen/04_tools"
xtests_dir="$script_dir/.xkeen/05_tests"
main_dir="$script_dir/.xkeen"

# Модуль информации
. "$xinfo_dir/00_info_import.sh"

# Модуль установки
. "$xinstall_dir/00_install_import.sh"

# Модуль удаления
. "$xdelete_dir/00_delete_import.sh"

# Модуль инструментария
. "$xtools_dir/00_tools_import.sh"

# Модуль тестирования
. "$xtests_dir/00_tests_import.sh"

# Модуль тестирования
. "$main_dir/author.sh"