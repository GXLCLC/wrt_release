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
#
# 三、根因修复（2026-11-10）：仅设置 firewall 不够。
#     luci-app-turboacc 的 /etc/init.d/turboacc 在每次开机执行
#       uci set firewall.@defaults[0].flow_offloading="${sw_flow}"
#       uci set firewall.@defaults[0].flow_offloading_hw="${hw_flow}"
#     取值来自 /etc/config/turboacc，出厂默认 hw_flow='1'（硬件），
#     会在首次启动之后把上面的 0 覆盖回 1。这里把开关一并改为
#     sw_flow=1 / hw_flow=0，使每次开机写出的都是软件卸载；
#     编译期也已在 apply_x64_device_defaults() 中固化该默认值。

[ -f /etc/config/firewall ] || exit 0

uci -q set 'firewall.@defaults[0].input=ACCEPT'
uci -q set 'firewall.@defaults[0].output=ACCEPT'
uci -q set 'firewall.@defaults[0].forward=ACCEPT'

uci -q set 'firewall.@defaults[0].flow_offloading=1'
uci -q set 'firewall.@defaults[0].flow_offloading_hw=0'

uci -q commit firewall

if [ -f /etc/config/turboacc ]; then
    uci -q set 'turboacc.config.sw_flow=1'
    uci -q set 'turboacc.config.hw_flow=0'
    uci -q commit turboacc
fi

exit 0
