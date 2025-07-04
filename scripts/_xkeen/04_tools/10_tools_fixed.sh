entware_fixed() {
    sed -i -e '/Package: xray/,/Installed-Time:/d' "$status_file"

    rm -f "${register_dir}/xray.control" \
          "${register_dir}/xray.list" \
          "${initd_dir}/S24xray" \
          "${install_dir}/xray" \
          "${install_conf_dir}/config.json.example"
}