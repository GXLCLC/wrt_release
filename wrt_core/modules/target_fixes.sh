#!/usr/bin/env bash
# target、kernel 与 base system 源码修正。

fix_default_set() {
    # 替换默认主题依赖，并注入系统设置和目标平台通用补丁。
    if [ -d "$BUILD_DIR/feeds/luci/collections/" ]; then
        find "$BUILD_DIR/feeds/luci/collections/" -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$THEME_SET/g" {} \;
    fi

    install -Dm544 "$BASE_PATH/patches/991_custom_settings" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/991_custom_settings"
    install -Dm544 "$BASE_PATH/patches/992_set-wifi-uci.sh" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/992_set-wifi-uci.sh"

    # 2026-11-07：Wi-Fi 名称不再按机型命名。编译期把脚本中的 @WIFI_SSID_PREFIX@
    # 替换为 build.sh 导出的源码类型前缀（LibWrt / Immortalwrt）；未导出时取 Immortalwrt，
    # 保证脚本被单独使用时也有确定值。
    sed -i "s/@WIFI_SSID_PREFIX@/${WIFI_SSID_PREFIX:-Immortalwrt}/g" \
        "$BUILD_DIR/package/base-files/files/etc/uci-defaults/992_set-wifi-uci.sh"

    if [ -f "$BUILD_DIR/package/emortal/autocore/files/tempinfo" ]; then
        # 2026-11-09：X86_64 改用能读 hwmon / thermal 节点的 tempinfo_x86；
        # 其余设备沿用通用版，取值逻辑不变。
        local tempinfo_patch="$BASE_PATH/patches/tempinfo"
        if [ "${X64_DEVICE_DEFAULTS:-0}" = "1" ] && [ -f "$BASE_PATH/patches/tempinfo_x86" ]; then
            tempinfo_patch="$BASE_PATH/patches/tempinfo_x86"
        fi
        if [ -f "$tempinfo_patch" ]; then
            \cp -f "$tempinfo_patch" "$BUILD_DIR/package/emortal/autocore/files/tempinfo"
        fi
    fi
}


# 2026-11-09：全局 SmartDNS 默认配置与设备级 Argon 壁纸来源。
# 993 排在 991 / 992 之后，固件首次启动时由 /etc/uci-defaults 依次执行；
# 用占位符把设备 ini 的 ARGON_ONLINE_WALLPAPER 注入脚本，
# 未配置该键的设备取 none（主题内建壁纸），不改动主题包源码目录。
install_default_settings() {
    local target="$BUILD_DIR/package/base-files/files/etc/uci-defaults/993_default_settings.sh"

    install -Dm544 "$BASE_PATH/patches/993_default_settings.sh" "$target"
    sed -i "s/@ARGON_ONLINE_WALLPAPER@/${ARGON_ONLINE_WALLPAPER:-none}/g" "$target"
}


# 2026-11-09：X86_64 专属默认设置，由 x64_immwrt.ini 的 X64_DEVICE_DEFAULTS=1 开启。
# 其它设备不声明该键，本函数直接返回，源码树与固件均不受影响。
apply_x64_device_defaults() {
    [ "${X64_DEVICE_DEFAULTS:-0}" = "1" ] || return 0

    # 1) CPU 温度：ImmortalWrt 的 autocore 只给 ipq / mediatek / qualcommax 目标安装
    #    /sbin/tempinfo，x86_64 缺失导致 luci.getTempInfo 返回空、架构信息页不显示温度。
    #    这里改由 base-files 直接提供该脚本，不修改 autocore 的目标条件，作用域可控。
    install -Dm755 "$BASE_PATH/patches/tempinfo_x86" \
        "$BUILD_DIR/package/base-files/files/sbin/tempinfo"

    # 2) 防火墙默认值与软件流量卸载，固件首次启动时由 uci-defaults 写入。
    install -Dm544 "$BASE_PATH/patches/994_x64_firewall.sh" \
        "$BUILD_DIR/package/base-files/files/etc/uci-defaults/994_x64_firewall.sh"

    echo "X86_64 专属默认设置已注入：CPU 温度脚本 + 防火墙/卸载默认值。"
}


fix_miniupnpd() {
    local miniupnpd_dir="$BUILD_DIR/feeds/packages/net/miniupnpd"
    local patch_file="999-chanage-default-leaseduration.patch"
    local upstream_repo="https://github.com/immortalwrt/packages.git"
    local upstream_branch="openwrt-25.12"

    if [ -d "$miniupnpd_dir" ] && [ -f "$BASE_PATH/patches/$patch_file" ]; then
        if ! sync_sparse_packages_to_feed_dir \
            "$upstream_repo" \
            "$upstream_branch" \
            "$BUILD_DIR/feeds/packages" \
            "immortalwrt/packages" \
            "net/miniupnpd"; then
            echo "错误：同步 miniupnpd 到 $upstream_branch 分支失败" >&2
            return 1
        fi

        install -Dm644 "$BASE_PATH/patches/$patch_file" "$miniupnpd_dir/patches/$patch_file"
    fi
}


change_dnsmasq2full() {
    if ! grep -q "dnsmasq-full" $BUILD_DIR/include/target.mk; then
        sed -i 's/dnsmasq/dnsmasq-full/g' ./include/target.mk
    fi
}


fix_mk_def_depends() {
    sed -i 's/libustream-mbedtls/libustream-openssl/g' $BUILD_DIR/include/target.mk 2>/dev/null
    if [ -f $BUILD_DIR/target/linux/qualcommax/Makefile ]; then
        sed -i 's/wpad-openssl/wpad-mesh-openssl/g' $BUILD_DIR/target/linux/qualcommax/Makefile
    fi
}


fix_kconfig_recursive_dependency() {
    local file="$BUILD_DIR/scripts/package-metadata.pl"
    if [ -f "$file" ]; then
        sed -i 's/<PACKAGE_\$pkgname/!=y/g' "$file"
        echo "已修复 package-metadata.pl 的 Kconfig 递归依赖生成逻辑。"
    fi
}


update_default_lan_addr() {
    local CFG_PATH="$BUILD_DIR/package/base-files/files/bin/config_generate"
    if [ -f $CFG_PATH ]; then
        sed -i 's/192\.168\.[0-9]*\.[0-9]*/'$LAN_ADDR'/g' $CFG_PATH
    fi
}


remove_something_nss_kmod() {
    local ipq_mk_path="$BUILD_DIR/target/linux/qualcommax/Makefile"
    local target_mks=("$BUILD_DIR/target/linux/qualcommax/ipq60xx/target.mk" "$BUILD_DIR/target/linux/qualcommax/ipq807x/target.mk")

    for target_mk in "${target_mks[@]}"; do
        if [ -f "$target_mk" ]; then
            sed -i 's/kmod-qca-nss-crypto//g' "$target_mk"
        fi
    done

    if [ -f "$ipq_mk_path" ]; then
        sed -i '/kmod-qca-nss-drv-eogremgr/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-gre/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-map-t/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-match/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-mirror/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-tun6rd/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-tunipip6/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-vxlanmgr/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-wifi-meshmgr/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-macsec/d' "$ipq_mk_path"

        sed -i 's/automount //g' "$ipq_mk_path"
        sed -i 's/cpufreq //g' "$ipq_mk_path"
    fi
}


update_affinity_script() {
    local affinity_script_dir="$BUILD_DIR/target/linux/qualcommax"

    if [ -d "$affinity_script_dir" ]; then
        find "$affinity_script_dir" -name "set-irq-affinity" -exec rm -f {} \;
        find "$affinity_script_dir" -name "smp_affinity" -exec rm -f {} \;
        install -Dm755 "$BASE_PATH/patches/smp_affinity" "$affinity_script_dir/base-files/etc/init.d/smp_affinity"
    fi
}


fix_hash_value() {
    local makefile_path="$1"
    local old_hash="$2"
    local new_hash="$3"
    local package_name="$4"

    if [ -f "$makefile_path" ]; then
        sed -i "s/$old_hash/$new_hash/g" "$makefile_path"
        echo "已修正 $package_name 的哈希值。"
    fi
}


apply_hash_fixes() {
    fix_hash_value \
        "$BUILD_DIR/package/feeds/packages/smartdns/Makefile" \
        "860a816bf1e69d5a8a2049483197dbebe8a3da2c9b05b2da68c85ef7dee7bdde" \
        "582021891808442b01f551bc41d7d95c38fb00c1ec78a58ac3aaaf898fbd2b5b" \
        "smartdns"

    fix_hash_value \
        "$BUILD_DIR/package/feeds/packages/smartdns/Makefile" \
        "320c99a65ca67a98d11a45292aa99b8904b5ebae5b0e17b302932076bf62b1ec" \
        "43e58467690476a77ce644f9dc246e8a481353160644203a1bd01eb09c881275" \
        "smartdns"
}


update_ath11k_fw() {
    local makefile="$BUILD_DIR/package/firmware/ath11k-firmware/Makefile"
    local new_mk="$BASE_PATH/patches/ath11k_fw.mk"
    local url="https://raw.githubusercontent.com/VIKINGYFY/immortalwrt/refs/heads/main/package/firmware/ath11k-firmware/Makefile"
    local ipq60_target="$BUILD_DIR/target/linux/qualcommax/ipq60xx/target.mk"
    local ipq807_target="$BUILD_DIR/target/linux/qualcommax/ipq807x/target.mk"

    if [ -d "$(dirname "$makefile")" ]; then
        echo "正在更新 ath11k-firmware Makefile..."
        if ! curl_retry -fsSL -o "$new_mk" "$url"; then
            echo "错误：从 $url 下载 ath11k-firmware Makefile 失败" >&2
            exit 1
        fi
        if [ ! -s "$new_mk" ]; then
            echo "错误：下载的 ath11k-firmware Makefile 为空文件" >&2
            exit 1
        fi
        mv -f "$new_mk" "$makefile"

        if [ -f "$ipq60_target" ]; then
            sed -i 's/ath11k-firmware-ipq6018\([^-[:alnum:]_]\|$\)/ath11k-firmware-ipq6018-ddwrt\1/g' "$ipq60_target"
        fi

        if [ -f "$ipq807_target" ]; then
            sed -i 's/ath11k-firmware-ipq8074\([^-[:alnum:]_]\|$\)/ath11k-firmware-ipq8074-ddwrt\1/g' "$ipq807_target"
        fi

        if [ -f "$ipq60_target" ] || [ -f "$ipq807_target" ]; then
            echo "已同步 ipq60xx/ipq807x ath11k 固件依赖为 ddwrt 包名。"
        fi
    fi
}


change_cpuusage() {
    local luci_rpc_path="$BUILD_DIR/feeds/luci/modules/luci-base/root/usr/share/rpcd/ucode/luci"
    local qualcommax_sbin_dir="$BUILD_DIR/target/linux/qualcommax/base-files/sbin"
    local filogic_sbin_dir="$BUILD_DIR/target/linux/mediatek/filogic/base-files/sbin"

    if [ -f "$luci_rpc_path" ]; then
        sed -i "s#const fd = popen('top -n1 | awk \\\'/^CPU/ {printf(\"%d%\", 100 - \$8)}\\\'')#const cpuUsageCommand = access('/sbin/cpuusage') ? '/sbin/cpuusage' : 'top -n1 | awk \\\'/^CPU/ {printf(\"%d%\", 100 - \$8)}\\\''#g" "$luci_rpc_path"
        sed -i '/cpuUsageCommand/a \\t\t\tconst fd = popen(cpuUsageCommand);' "$luci_rpc_path"
    fi

    local old_script_path="$BUILD_DIR/package/base-files/files/sbin/cpuusage"
    if [ -f "$old_script_path" ]; then
        rm -f "$old_script_path"
    fi

    if [ -d "$BUILD_DIR/target/linux/qualcommax" ]; then
        install -Dm755 "$BASE_PATH/patches/cpuusage" "$qualcommax_sbin_dir/cpuusage"
    fi
    if [ -d "$BUILD_DIR/target/linux/mediatek" ]; then
        install -Dm755 "$BASE_PATH/patches/hnatusage" "$filogic_sbin_dir/cpuusage"
    fi
}


update_nss_pbuf_performance() {
    local pbuf_path="$BUILD_DIR/package/kernel/mac80211/files/pbuf.uci"
    if [ -d "$(dirname "$pbuf_path")" ] && [ -f $pbuf_path ]; then
        sed -i "s/auto_scale '1'/auto_scale 'off'/g" $pbuf_path
        sed -i "s/scaling_governor 'performance'/scaling_governor 'schedutil'/g" $pbuf_path
    fi
}


update_nss_diag() {
    local file="$BUILD_DIR/package/kernel/mac80211/files/nss_diag.sh"
    if [ -d "$(dirname "$file")" ] && [ -f "$file" ]; then
        \rm -f "$file"
        install -Dm755 "$BASE_PATH/patches/nss_diag.sh" "$file"
    fi
}


fix_compile_coremark() {
    local file="$BUILD_DIR/feeds/packages/utils/coremark/Makefile"
    if [ -d "$(dirname "$file")" ] && [ -f "$file" ]; then
        sed -i 's/mkdir \$/mkdir -p \$/g' "$file"
    fi
}


update_dnsmasq_conf() {
    local file="$BUILD_DIR/package/network/services/dnsmasq/files/dhcp.conf"
    if [ -d "$(dirname "$file")" ] && [ -f "$file" ]; then
        sed -i '/dns_redirect/d' "$file"
    fi
}


# 2026-11-07：Lucky 已从固件移除，sysupgrade 备份清单中不再保留 /etc/lucky/。
add_backup_info_to_sysupgrade() {
    local conf_path="$BUILD_DIR/package/base-files/files/etc/sysupgrade.conf"

    if [ -f "$conf_path" ]; then
        cat >"$conf_path" <<'EOF'
/etc/AdGuardHome.yaml
/etc/easytier
EOF
    fi
}


fix_rust_compile_error() {
    if [ -f "$BUILD_DIR/feeds/packages/lang/rust/Makefile" ]; then
        sed -i 's/download-ci-llvm=true/download-ci-llvm=false/g' "$BUILD_DIR/feeds/packages/lang/rust/Makefile"
    fi
}
