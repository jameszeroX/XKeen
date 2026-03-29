# Общие функции для регистрации пакетов в opkg

write_opkg_control() {
    package_name="$1"
    package_version="$2"
    package_depends="$3"
    package_source="$4"
    package_source_name="$5"
    package_maintainer="$6"
    package_description="$7"

    {
        echo "Package: $package_name"
        echo "Version: $package_version"
        [ -n "$package_depends" ] && echo "Depends: $package_depends"
        echo "Source: $package_source"
        echo "SourceName: $package_source_name"
        echo "Section: net"
        echo "SourceDateEpoch: $source_date_epoch"
        echo "Maintainer: $package_maintainer"
        echo "Architecture: $status_architecture"
        echo "Installed-Size: $installed_size"
        echo "Description: $package_description"
    } > "$register_dir/$package_name.control"
}

write_opkg_status() {
    package_name="$1"
    package_version="$2"
    package_depends="$3"
    status_entry="$(mktemp)"

    {
        echo "Package: $package_name"
        echo "Version: $package_version"
        [ -n "$package_depends" ] && echo "Depends: $package_depends"
        echo "Status: install user installed"
        echo "Architecture: $status_architecture"
        echo "Installed-Time: $(date +%s)"
    } > "$status_entry"

    echo "" >> "$status_file"
    cat "$status_entry" >> "$status_file"
    echo "" >> "$status_file"
    rm -f "$status_entry"
    sed -i '/^$/{N;/^\n$/D}' "$status_file"
}
