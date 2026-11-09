#!/bin/sh
# 2026-11-09：固件默认设置（适用于所有设备，不限于 X86_64）。
# 注入方式：wrt_core/modules/target_fixes.sh 的 install_default_settings() 把本脚本
#           安装到 package/base-files/files/etc/uci-defaults/，固件首次启动时执行；
#           编译期把占位符替换为 build.sh 导出的设备值。
#
# 一、SmartDNS（用户要求所有设备一致，未做要求的项保持原预设）
# 字段依据：pymumu/luci-app-smartdns 的 UCI 定义（smartdns 段的 port / auto_set_dnsmasq；
#           server 段的 name / ip / type）与 pymumu/smartdns 的 /etc/config/smartdns。
#
# 二、Argon 在线壁纸来源（仅 X86_64 为 bing，其余为 none 内建壁纸）
# 取值依据：kenzok8/small-package 的 luci-theme-argon uci-defaults/30_luci-theme-argon
#           迁移逻辑 uci set 'argon.@global[0].online_wallpaper=bing'。

# --- SmartDNS：本地端口 6053，不勾选自动设置 Dnsmasq ---
if [ -f /etc/config/smartdns ]; then
    uci -q get 'smartdns.@smartdns[0]' >/dev/null || uci -q add smartdns smartdns >/dev/null
    uci -q set 'smartdns.@smartdns[0].port=6053'
    uci -q set 'smartdns.@smartdns[0].auto_set_dnsmasq=0'

    # 清空原有上游服务器段，再按用户给出的 6 个 UDP 服务器重建。
    while uci -q get 'smartdns.@server[0]' >/dev/null; do
        uci -q delete 'smartdns.@server[0]' || break
    done

    add_udp_server() {
        uci -q add smartdns server >/dev/null
        uci -q set 'smartdns.@server[-1].enabled=1'
        uci -q set "smartdns.@server[-1].name=$1"
        uci -q set "smartdns.@server[-1].ip=$2"
        uci -q set 'smartdns.@server[-1].type=udp'
    }

    add_udp_server '114DNS' '114.114.114.114'
    add_udp_server '阿里' '223.5.5.5'
    add_udp_server '腾讯' '119.29.29.29'
    add_udp_server '谷歌' '8.8.8.8'
    add_udp_server '字节跳动' '180.184.1.1'
    add_udp_server 'Cloudflare' '1.1.1.1'

    uci -q commit smartdns
fi

# --- Argon 在线壁纸来源（占位符由编译期注入） ---
if [ -f /etc/config/argon ]; then
    uci -q get 'argon.@global[0]' >/dev/null || uci -q add argon global >/dev/null
    uci -q set 'argon.@global[0].online_wallpaper=@ARGON_ONLINE_WALLPAPER@'
    uci -q commit argon
fi

exit 0
