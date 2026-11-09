#!/bin/sh
# 2026-11-09：X86_64 专用防火墙默认值（仅 X64_DEVICE_DEFAULTS=1 的设备注入）。
# 注入：wrt_core/modules/target_fixes.sh 的 apply_x64_device_defaults() 安装到
#       package/base-files/files/etc/uci-defaults/，固件首次启动时执行。
#
# 一、通用设置：入站 / 出站 / 转发全部改为接受。
#     ImmortalWrt master 的 package/network/config/firewall/files/firewall.config
#     默认 input=REJECT、output=ACCEPT、forward=REJECT，这里显式覆盖为 ACCEPT。
#     注意这是 firewall.@defaults[0] 的兜底策略，各 zone 自身的 input/forward
#     选项仍由 /etc/config/firewall 的 zone 段决定，未被本脚本改动。
#
# 二、路由/NAT 卸载：流量卸载类型改为「软件流量卸载」。
#     依据 immortalwrt/luci 的 applications/luci-app-firewall/.../zones.js：
#       offloading_type 的 load = flow_offloading=='1'
#           ? (flow_offloading_hw=='1' ? '2' 硬件 : '1' 软件) : '0' 关闭
#     故显式设 flow_offloading=1 且 flow_offloading_hw=0，界面即选中软件卸载。

[ -f /etc/config/firewall ] || exit 0

uci -q set 'firewall.@defaults[0].input=ACCEPT'
uci -q set 'firewall.@defaults[0].output=ACCEPT'
uci -q set 'firewall.@defaults[0].forward=ACCEPT'

uci -q set 'firewall.@defaults[0].flow_offloading=1'
uci -q set 'firewall.@defaults[0].flow_offloading_hw=0'

uci -q commit firewall
exit 0
