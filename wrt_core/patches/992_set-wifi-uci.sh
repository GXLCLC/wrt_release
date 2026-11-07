#!/bin/sh

# 2026-11-07：取消以机型命名 Wi-Fi SSID，统一按编译所用源码类型命名。
# 下方变量的占位符由 wrt_core/modules/target_fixes.sh 在编译期注入：
#   LibWrt 固件      -> Libwrt（2.4G）/ Libwrt_5G（5G）
#   ImmortalWrt 固件 -> Immortalwrt（2.4G）/ Immortalwrt_5G（5G）
# 同一设备存在多个 5G 射频时共用 _5G 名称；6G 射频在本脚本中默认关闭，也统一归入 _5G。
WIFI_SSID_PREFIX='@WIFI_SSID_PREFIX@'

board_name=$(cat /tmp/sysinfo/board_name)

configure_wifi() {
	local radio=$1
	local channel=$2
	local htmode=$3
	local txpower=$4
	local ssid=$5
	local key=$6
	local encryption=${7:-"psk2+ccmp"} # 新增 encryption 参数，如果为空则默认为 psk2+ccmp
	local now_encryption=$(uci get wireless.default_radio${radio}.encryption)
	if [ -n "$now_encryption" ] && [ "$now_encryption" != "none" ]; then
		return 0
	fi
	uci -q batch <<EOF
set wireless.radio${radio}.channel="${channel}"
set wireless.radio${radio}.htmode="${htmode}"
set wireless.radio${radio}.mu_beamformer='1'
set wireless.radio${radio}.country='US'
set wireless.radio${radio}.txpower="${txpower}"
set wireless.radio${radio}.cell_density='0'
set wireless.radio${radio}.disabled='0'
set wireless.default_radio${radio}.ssid="${ssid}"
set wireless.default_radio${radio}.encryption="${encryption}"
set wireless.default_radio${radio}.key="${key}"
set wireless.default_radio${radio}.ieee80211k='1'
set wireless.default_radio${radio}.time_advertisement='2'
set wireless.default_radio${radio}.time_zone='CST-8'
set wireless.default_radio${radio}.bss_transition='1'
set wireless.default_radio${radio}.wnm_sleep_mode='1'
set wireless.default_radio${radio}.wnm_sleep_mode_no_keys='1'
EOF
}

configure_wifi7() {
	local radio=$1
	local channel=$2
	local htmode=$3
	local txpower=$4
	local ssid=$5
	local key=$6
	local encryption=${7:-"psk2"} # 新增 encryption 参数，如果为空则默认为 psk2
	local now_encryption=$(uci -q get wireless.default_radio${radio}.encryption)
	local bandmode=$(uci -q get wireless.radio${radio}.band)
	if [ "$bandmode" = "6g" ] && [ "$now_encryption" = "$encryption" ]; then
		return 0
	fi
	if [ "$bandmode" != "6g" ] && [ -n "$now_encryption" ] && [ "$now_encryption" != "none" ]; then
		return 0
	fi
	uci -q batch <<EOF
set wireless.radio${radio}.channel="${channel}"
set wireless.radio${radio}.htmode="${htmode}"
set wireless.radio${radio}.disabled='0'
set wireless.radio${radio}.country='US'
set wireless.radio${radio}.sku_idx='0'
set wireless.radio${radio}.he_twt_responder='1'
set wireless.radio${radio}.cell_density='0'
set wireless.radio${radio}.txpower="${txpower}"
set wireless.radio${radio}.noscan='0'
set wireless.default_radio${radio}.ssid="${ssid}"
set wireless.default_radio${radio}.encryption="${encryption}"
set wireless.default_radio${radio}.key="${key}"
set wireless.default_radio${radio}.vif_txpower="${txpower}"
set wireless.default_radio${radio}.ieee80211k='1'
set wireless.default_radio${radio}.time_zone='CST-8'
set wireless.default_radio${radio}.bss_transition='1'
set wireless.default_radio${radio}.wmm='1'
EOF
	if [ "$bandmode" = "2g" ]; then
		uci -q batch <<EOF
set wireless.radio${radio}.legacy_rates='1'
set wireless.radio${radio}.sr_enable='1'
set wireless.radio${radio}.etxbfen='1'
EOF
	elif [ "$bandmode" = "5g" ]; then
		uci -q batch <<EOF
set wireless.radio${radio}.background_radar='0'
EOF
	elif [ "$bandmode" = "6g" ]; then
		uci -q batch <<EOF
set wireless.radio${radio}.lpi_enable='0'
EOF
	fi
}

jdc_ax1800_pro_wifi_cfg() {
	configure_wifi 0 149 HE80 20 "${WIFI_SSID_PREFIX}_5G" '12345678'
	configure_wifi 1 1 HE20 20 "${WIFI_SSID_PREFIX}" '12345678'
}

jdc_ax6600_wifi_cfg() {
	configure_wifi 0 149 HE80 22 "${WIFI_SSID_PREFIX}_5G" '12345678'
	configure_wifi 1 1 HE20 22 "${WIFI_SSID_PREFIX}" '12345678'
	configure_wifi 2 44 HE160 23 "${WIFI_SSID_PREFIX}_5G" '12345678'
}

redmi_ax5_wifi_cfg() {
	configure_wifi 0 149 HE80 20 "${WIFI_SSID_PREFIX}_5G" '12345678'
	configure_wifi 1 1 HE20 20 "${WIFI_SSID_PREFIX}" '12345678'
}

aliyun_ap8220_wifi_cfg() {
	configure_wifi 0 149 HE80 26 "${WIFI_SSID_PREFIX}_5G" '12345678'
	configure_wifi 1 1 HE20 23 "${WIFI_SSID_PREFIX}" '12345678'
}

cmcc_rax3000m_wifi_cfg() {
	configure_wifi 0 1 HE20 23 "${WIFI_SSID_PREFIX}" '12345678'
	configure_wifi 1 44 HE160 25 "${WIFI_SSID_PREFIX}_5G" '12345678'
}

redmi_ax6_wifi_cfg() {
	configure_wifi 0 149 HE80 22 "${WIFI_SSID_PREFIX}_5G" '12345678'
	configure_wifi 1 1 HE20 21 "${WIFI_SSID_PREFIX}" '12345678'
}

qihoo_360v6_wifi_cfg() {
	configure_wifi 0 1 HE80 20 "${WIFI_SSID_PREFIX}" '12345678'
	configure_wifi 1 149 HE20 20 "${WIFI_SSID_PREFIX}_5G" '12345678'
}

linksys_mx4x00_wifi_cfg() {
	configure_wifi 0 44 HE80 22 "${WIFI_SSID_PREFIX}_5G" '12345678'
	configure_wifi 1 1 HE20 21 "${WIFI_SSID_PREFIX}" '12345678'
	configure_wifi 2 149 HE80 21 "${WIFI_SSID_PREFIX}_5G" '12345678'
}

gemtek_w1701k_wifi_cfg() {
	configure_wifi7 0 1 EHT20 23 "${WIFI_SSID_PREFIX}" '12345678'
	configure_wifi7 1 44 EHT160 23 "${WIFI_SSID_PREFIX}_5G" '12345678'
	configure_wifi7 2 1 EHT320 23 "${WIFI_SSID_PREFIX}_5G" '12345678' 'sae'
	uci set wireless.radio2.disabled='1'
}

link_nn6000_wifi_cfg() {
	configure_wifi 0 149 HE80 19 "${WIFI_SSID_PREFIX}_5G" '12345678'
	configure_wifi 1 1 HT20 19 "${WIFI_SSID_PREFIX}" '12345678'
}

case "${board_name}" in
jdcloud,ax1800-pro | \
	jdcloud,re-ss-01)
	jdc_ax1800_pro_wifi_cfg
	;;
jdcloud,ax6600 | \
	jdcloud,re-cs-02)
	jdc_ax6600_wifi_cfg
	;;
redmi,ax5 | \
	redmi,ax5-jdcloud)
	redmi_ax5_wifi_cfg
	;;
aliyun,ap8220)
	aliyun_ap8220_wifi_cfg
	;;
cmcc,rax3000m)
	cmcc_rax3000m_wifi_cfg
	;;
redmi,ax6 | \
	redmi,ax6-stock)
	redmi_ax6_wifi_cfg
	;;
qihoo,360v6)
	qihoo_360v6_wifi_cfg
	;;
linksys,mx4200v1 | \
	linksys,mx4200v2 | \
	linksys,mx4300 | \
	linksys,homewrk)
	linksys_mx4x00_wifi_cfg
	;;
gemtek,w1701k-ubi)
	gemtek_w1701k_wifi_cfg
	;;
link,nn6000-v2)
	link_nn6000_wifi_cfg
	;;
*)
	exit 0
	;;
esac

uci commit wireless
/etc/init.d/network restart
