#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

set -euo pipefail

network_config=package/base-files/files/bin/config_generate
theme_makefile=feeds/luci/collections/luci/Makefile
light_makefile=feeds/luci/collections/luci-light/Makefile
theme_dependency='\+luci-theme-(bootstrap|argon)([[:space:]]|$)'

if ! grep -Eq '"192\.168\.(1|10)\.1"' "$network_config"; then
    echo 'Could not find the expected default LAN address in config_generate' >&2
    exit 1
fi
if [[ -f $light_makefile ]] && grep -Eq "$theme_dependency" "$light_makefile"; then
    theme_makefile=$light_makefile
fi
if ! grep -Eq "$theme_dependency" "$theme_makefile"; then
    echo "Could not find the LuCI theme dependency in $theme_makefile" >&2
    exit 1
fi

package_stage_dir=$(mktemp -d .actions-openwrt.XXXXXXXX)
trap 'rm -rf -- "$package_stage_dir"' EXIT

fetch_package() {
    local url=$1 revision=$2 destination=$3
    git init --quiet "$destination"
    git -C "$destination" fetch --quiet --depth 1 "$url" "$revision"
    git -C "$destination" checkout --quiet --detach FETCH_HEAD
}

# Argon v2.4.7 and OpenClash v0.48.002
fetch_package https://github.com/jerrykuku/luci-theme-argon.git 2a28799ca063aba7edc3314143b93c8325c86df4 "$package_stage_dir/luci-theme-argon"
fetch_package https://github.com/vernesong/OpenClash.git e553e82e01c697aefbe1555261a503f425e00ccd "$package_stage_dir/luci-app-openclash"
test -f "$package_stage_dir/luci-theme-argon/Makefile"
test -f "$package_stage_dir/luci-app-openclash/luci-app-openclash/Makefile"

# 修改默认IP和默认主题
sed -i 's/"192\.168\.1\.1"/"192.168.10.1"/g' "$network_config"
sed -Ei 's/\+luci-theme-bootstrap([[:space:]]|$)/+luci-theme-argon\1/g' "$theme_makefile"

rm -rf -- package/luci-theme-argon package/luci-app-openclash
mv -- "$package_stage_dir/luci-theme-argon" "$package_stage_dir/luci-app-openclash" package/
