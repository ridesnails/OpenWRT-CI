#!/bin/bash

# RE-CS-02专用构建脚本
# 基于原版diy.sh但针对RE-CS-02进行了优化

# 设置仓库信息
WRT_REPO='https://github.com/VIKINGYFY/immortalwrt'
WRT_BRANCH='main'

# 固定配置为RE-CS-02
export WRT_CONFIG="RE-CS-02-WIFI"

# 设置基本环境变量
export WRT_DIR=wrt
export GITHUB_WORKSPACE=$(pwd)
export WRT_DATE=$(TZ=UTC-8 date +"%y.%m.%d_%H.%M.%S")
export WRT_VER=$(echo $WRT_REPO | cut -d '/' -f 5-)-$WRT_BRANCH
export WRT_TYPE="RE-CS-02"
export WRT_NAME=${WRT_NAME:-'RE-CS-02-WIFI'}
export WRT_SSID=${WRT_SSID:-'RE-CS-02-WIFI'}
export WRT_WORD=${WRT_WORD:-'12345678'}
export WRT_THEME=${WRT_THEME:-'argon'}
export WRT_IP=${WRT_IP:-'192.168.10.1'}
export WRT_CI='RE-CS-02-OpenWRT-CI'
export WRT_ARCH='ipq60xx'
export CI_NAME='RE-CS-02-WIFI'
export WRT_TARGET='QUALCOMMAX'

# 加载函数库
. $GITHUB_WORKSPACE/Scripts/function.sh

echo "=== RE-CS-02 WiFi固件构建开始 ==="
echo "构建时间: $WRT_DATE"
echo "源码仓库: $WRT_REPO"
echo "源码分支: $WRT_BRANCH"
echo "目标设备: RE-CS-02"
echo "WiFi名称: $WRT_SSID"
echo "LAN地址: $WRT_IP"
echo "============================="

# 检查或克隆源码
if [ ! -d $WRT_DIR ]; then
  echo "克隆源码仓库..."
  git clone --depth=1 --single-branch --branch $WRT_BRANCH $WRT_REPO $WRT_DIR
  cd $WRT_DIR
else
  echo "更新现有源码..."
  cd $WRT_DIR
  git remote set-url origin $WRT_REPO
  rm -rf feeds/*
  git clean -f
  git reset --hard
  git pull
fi

echo "当前源码信息:"
git log --oneline -n 3

# 更新feeds
echo "更新feeds..."
./scripts/feeds update -a && ./scripts/feeds install -a

# 进入package目录添加自定义包
cd package/

echo "添加自定义软件包..."
# 运行包管理脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/Packages.sh" ]; then
    echo "运行Packages.sh..."
    $GITHUB_WORKSPACE/Scripts/Packages.sh
fi

# 运行处理脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/Handles.sh" ]; then
    echo "运行Handles.sh..."
    $GITHUB_WORKSPACE/Scripts/Handles.sh
fi

# 添加DAE相关包
echo "添加DAE相关包..."
if [ -d "$GITHUB_WORKSPACE/package/dae" ] && [ ! -d "dae" ]; then
    cp -rf $GITHUB_WORKSPACE/package/dae ./
    echo "添加dae包"
fi

if [ -d "$GITHUB_WORKSPACE/package/luci-app-dae" ] && [ ! -d "luci-app-dae" ]; then
    cp -rf $GITHUB_WORKSPACE/package/luci-app-dae ./
    echo "添加luci-app-dae包"
fi

if [ -d "$GITHUB_WORKSPACE/package/v2ray-geodata" ] && [ ! -d "v2ray-geodata" ]; then
    cp -rf $GITHUB_WORKSPACE/package/v2ray-geodata ./
    echo "添加v2ray-geodata包"
fi

cd ..

echo "生成配置文件..."
# 生成配置
generate_config

echo "应用自定义设置..."
# 运行设置脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/Settings.sh" ]; then
    $GITHUB_WORKSPACE/Scripts/Settings.sh
fi

# 创建自定义文件目录
echo "应用自定义文件..."
if [ -d "$GITHUB_WORKSPACE/files" ]; then
    cp -rf $GITHUB_WORKSPACE/files/* ./
    echo "复制自定义文件完成"
fi

# 创建uci-defaults设置
mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/99-re-cs-02-settings << EOF
#!/bin/sh

# RE-CS-02专用设置脚本

# 设置主机名
uci set system.@system[0].hostname='$WRT_NAME'
uci set system.@system[0].description='RE-CS-02 WiFi Router'

# 设置时区
uci set system.@system[0].zonename='Asia/Shanghai' 
uci set system.@system[0].timezone='CST-8'

# 设置LAN配置
uci set network.lan.ipaddr='$WRT_IP'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.proto='static'

# 设置WiFi (如果存在无线配置)
if [ -n "\$(uci -q get wireless.radio0)" ]; then
    # 2.4G WiFi
    uci set wireless.radio0.disabled='0'
    uci set wireless.radio0.country='CN'
    uci set wireless.radio0.channel='auto'
    uci set wireless.radio0.htmode='HE20'
    
    uci set wireless.default_radio0.ssid='$WRT_SSID'
    uci set wireless.default_radio0.encryption='psk2'
    uci set wireless.default_radio0.key='$WRT_WORD'
    uci set wireless.default_radio0.ieee80211w='1'
fi

if [ -n "\$(uci -q get wireless.radio1)" ]; then
    # 5G WiFi  
    uci set wireless.radio1.disabled='0'
    uci set wireless.radio1.country='CN'
    uci set wireless.radio1.channel='auto'
    uci set wireless.radio1.htmode='HE80'
    
    uci set wireless.default_radio1.ssid='$WRT_SSID'
    uci set wireless.default_radio1.encryption='psk2'
    uci set wireless.default_radio1.key='$WRT_WORD'
    uci set wireless.default_radio1.ieee80211w='1'
fi

# 设置防火墙
uci set firewall.@defaults[0].forward='ACCEPT'

# 设置DHCP
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'

# 提交所有配置
uci commit

# 设置root密码为空（首次登录强制设置）
passwd -d root

exit 0
EOF

chmod +x files/etc/uci-defaults/99-re-cs-02-settings

echo "生成最终配置..."
make defconfig

echo "=== 配置生成完成 ==="
echo "如需编译固件，请运行:"
echo "make download -j8"
echo "make -j\$(nproc) || make V=s -j1"
echo "==================="
