#!/bin/bash

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not fonud directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理克隆的仓库
	if [[ $PKG_SPECIAL == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ $PKG_SPECIAL == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# 调用示例
# UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "custom_name1 custom_name2"
# UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf" 这样会把原有的open-app-filter，luci-app-appfilter，oaf相关组件删除，不会出现coremark错误。

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-24.10"

#自定义添加包
#argon 主题配置
UPDATE_PACKAGE "argon-config" "sbwml/luci-app-argon-config" "openwrt-24.10"
#natmap以及 luci
UPDATE_PACKAGE "natmapt" "muink/openwrt-natmapt" "master"
UPDATE_PACKAGE "luci-app-natmapt" "muink/luci-app-natmapt" "master"


#UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "js"

#UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
#UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
#UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
#UPDATE_PACKAGE "passwall" "xiaorouji/openwrt-passwall" "main" "pkg"
#UPDATE_PACKAGE "passwall2" "xiaorouji/openwrt-passwall2" "main" "pkg"

#UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

#UPDATE_PACKAGE "alist" "sbwml/luci-app-alist" "main"
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
#UPDATE_PACKAGE "gecoosac" "lwb1978/openwrt-gecoosac" "main"
#UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "netspeedtest" "sirpdboy/luci-app-netspeedtest" "js" "" "homebox speedtest"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
#UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
#UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"
#UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"


UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "master"
UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"
#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ $OLD_URL == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ $NEW_VER =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
#UPDATE_VERSION "sing-box"
#UPDATE_VERSION "tailscale"

#获取sing-box beta版本相关信息
get_sing_box_beta() {
    echo "正在获取 sing-box beta 版本信息..."
    
    latest_beta=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases | grep -oP '"tag_name":\s*"\K[^"]+' | grep beta | head -n1)
    
    if [ -z "$latest_beta" ]; then
        echo "未找到 beta 版本，使用稳定版本"
        return 1
    fi
    
    echo "找到最新beta版本: $latest_beta"
    
    # 构建下载URL
    tar_url="https://github.com/SagerNet/sing-box/archive/refs/tags/$latest_beta.tar.gz"
    
    # 下载并计算哈希
    echo "正在下载并计算哈希..."
    wget -q -O /tmp/sing-box-beta.tar.gz "$tar_url"
    
    if [ $? -ne 0 ]; then
        echo "下载失败"
        return 1
    fi
    
    hash=$(sha256sum /tmp/sing-box-beta.tar.gz | awk '{print $1}')
    rm -f /tmp/sing-box-beta.tar.gz
    
    echo "版本: $latest_beta"
    echo "SHA256: $hash"
    
    # 更新Makefile
    SING_BOX_MAKEFILE="$GITHUB_WORKSPACE/package/sing-box/Makefile"
    
    if [ -f "$SING_BOX_MAKEFILE" ]; then
        echo "正在更新 Makefile..."
        # 将 beta 版本号转换为 OpenWrt 兼容格式，例如 1.12.0-beta.33 -> 1.12.0~beta33
        orig_ver="${latest_beta#v}"
        compat_ver=$(echo "$orig_ver" | sed -E 's/-beta\.([0-9]+)/~beta\1/')
        sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$compat_ver/" "$SING_BOX_MAKEFILE"
        sed -i "s/PKG_HASH:=.*/PKG_HASH:=${hash}/" "$SING_BOX_MAKEFILE"
        
        # 更新源码URL为原始GitHub archive URL
        sed -i "s|PKG_SOURCE_URL:=.*|PKG_SOURCE_URL:=https://github.com/SagerNet/sing-box/archive/refs/tags/$latest_beta.tar.gz|" "$SING_BOX_MAKEFILE"
        # 更新源码文件名为原始版本号对应文件
        sed -i "s|PKG_SOURCE:=.*|PKG_SOURCE:=sing-box-${orig_ver}.tar.gz|" "$SING_BOX_MAKEFILE"
        
        echo "✅ 已成功更新 sing-box Makefile:"
        echo "   版本: ${latest_beta#v}"
        echo "   哈希: ${hash}"
        
        # 验证更新结果
        echo "验证更新结果:"
        grep "PKG_VERSION:=" "$SING_BOX_MAKEFILE"
        grep "PKG_HASH:=" "$SING_BOX_MAKEFILE"
        
    else
        echo "❌ 错误: 找不到 sing-box Makefile 文件: $SING_BOX_MAKEFILE"
        return 1
    fi
}
get_sing_box_beta
#不编译xray-core
#sed -i 's/+xray-core//' luci-app-passwall2/Makefile

#删除官方的默认插件
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,dae*,bypass*,homeproxy}
rm -rf ../feeds/packages/net/{v2ray-geodata,dae*,sing-box}

#更新golang为最新版
rm -rf ../feeds/packages/lang/golang
git clone -b 24.x https://github.com/sbwml/packages_lang_golang ../feeds/packages/lang/golang


cp -r $GITHUB_WORKSPACE/package/* ./

#coremark修复
sed -i 's/mkdir \$(PKG_BUILD_DIR)\/\$(ARCH)/mkdir -p \$(PKG_BUILD_DIR)\/\$(ARCH)/g' ../feeds/packages/utils/coremark/Makefile

#修改字体
argon_css_file=$(find ./luci-theme-argon/ -type f -name "cascade.css")
sed -i "/^.main .main-left .nav li a {/,/^}/ { /font-weight: bolder/d }" $argon_css_file
sed -i '/^\[data-page="admin-system-opkg"\] #maincontent>.container {/,/}/ s/font-weight: 600;/font-weight: normal;/' $argon_css_file

#修复daed/Makefile
#rm -rf luci-app-daed/daed/Makefile && cp -r $GITHUB_WORKSPACE/patches/daed/Makefile luci-app-daed/daed/
#cat luci-app-daed/daed/Makefile