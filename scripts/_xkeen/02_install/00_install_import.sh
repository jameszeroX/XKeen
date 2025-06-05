# Импорт модулей установки

# Модули установки
. "$xinstall_dir/01_install_packages.sh"
. "$xinstall_dir/02_install_xray.sh"
. "$xinstall_dir/02_install_mihomo.sh"
. "$xinstall_dir/03_install_xkeen.sh"
. "$xinstall_dir/04_install_geosite.sh"
. "$xinstall_dir/05_install_geoip.sh"
. "$xinstall_dir/06_install_cron.sh"

. "$xinstall_dir/07_install_register/00_register_import.sh"
. "$xinstall_dir/08_install_configs/00_configs_import.sh"