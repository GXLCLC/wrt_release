#!/usr/bin/env bash

get_feeds_path() {
    local feeds_path="$BUILD_DIR/$FEEDS_CONF"
    if [[ -f "$BUILD_DIR/feeds.conf" ]]; then
        feeds_path="$BUILD_DIR/feeds.conf"
    fi
    printf '%s\n' "$feeds_path"
}

append_feed_if_missing() {
    local feeds_path="$1"
    local match_pattern="$2"
    local feed_entry="$3"

    if ! grep -q "$match_pattern" "$feeds_path"; then
        echo "$feed_entry" >>"$feeds_path"
    fi
}

update_feeds() {
    local FEEDS_PATH
    FEEDS_PATH=$(get_feeds_path)
    sed -i '/packages_ext/d' "$FEEDS_PATH"
    sed -i '/[[:space:]]small8[[:space:]]/d' "$FEEDS_PATH"
    sed -i '/[[:space:]]custom_feed[[:space:]]/d' "$FEEDS_PATH"

    append_feed_if_missing "$FEEDS_PATH" "openwrt_bandix" "src-git openwrt_bandix https://github.com/timsaya/openwrt-bandix.git;main"
    append_feed_if_missing "$FEEDS_PATH" "luci_app_bandix" "src-git luci_app_bandix https://github.com/timsaya/luci-app-bandix.git;main"
    #过时原仓库迁移
    #append_feed_if_missing "$FEEDS_PATH" "ddnsto" "src-git ddnsto https://github.com/linkease/ddnsto-openwrt.git;main"
    #添加新的DDNSTO源
    append_feed_if_missing "$FEEDS_PATH" "nas" "src-git nas https://github.com/linkease/nas-packages.git;master"
    append_feed_if_missing "$FEEDS_PATH" "nas_luci" "src-git nas_luci https://github.com/linkease/nas-packages-luci.git;main"
    #添加turboacc源
    append_feed_if_missing "$FEEDS_PATH" "turboacc-luci" "src-git turboacc-luci https://github.com/chenmozhijin/turboacc.git;luci"
    # TurboACC 底层SFE/FullCone内核模块（package分支）
    append_feed_if_missing "$FEEDS_PATH" "turboacc-core" "src-git turboacc-core https://github.com/chenmozhijin/turboacc.git;package"
    if [ ! -f "$BUILD_DIR/include/bpf.mk" ]; then
        touch "$BUILD_DIR/include/bpf.mk"
    fi

    ./scripts/feeds update -a
}

install_feeds() {
    ./scripts/feeds update -i
    ./scripts/feeds install -a -f
}
