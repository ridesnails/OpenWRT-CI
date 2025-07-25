# RE-CS-02 WiFi 固件构建项目

## 项目概述

本项目是基于 OpenWRT-CI 框架的 RE-CS-02 硬件专用 WiFi 固件构建解决方案。它专门针对京东云 RE-CS-02 路由器设备，提供自动化的固件构建、上游代码同步和自定义配置功能。

## 主要特性

### 🚀 核心功能
- **专用硬件支持**: 专门针对 JDCloud RE-CS-02 路由器优化
- **WiFi 双频支持**: 支持 2.4G 和 5G 双频 WiFi
- **NSS 硬件加速**: 启用高通 NSS 硬件网络加速
- **DAE 透明代理**: 集成 DAE 内核级透明代理
- **自动化构建**: 支持定时和手动触发的自动化构建

### 🔄 自动同步功能
- **上游代码同步**: 自动检测并同步 VIKINGYFY/immortalwrt 最新代码
- **最小侵入性**: 不修改源项目文件，通过外部配置实现定制
- **智能更新**: 只在检测到上游更新时才进行同步

### ⚙️ 灵活配置
- **自定义网络设置**: 支持自定义 LAN IP、WiFi 名称和密码
- **包管理**: 基于 diy.sh 的包增减和系统配置定制
- **模块化设计**: 通过配置文件和脚本实现功能定制

## 项目结构

```
OpenWRT-CI/
├── .github/workflows/
│   ├── RE-CS-02-WIFI.yml          # RE-CS-02专用工作流
│   └── WRT-CORE.yml               # 通用构建核心
├── Config/
│   └── RE-CS-02-WIFI.txt          # RE-CS-02专用配置文件
├── Scripts/                        # 构建脚本目录
│   ├── function.sh                 # 通用函数库
│   ├── Packages.sh                 # 包管理脚本
│   ├── Handles.sh                  # 处理脚本
│   └── Settings.sh                 # 设置脚本
├── package/                        # 自定义包目录
│   ├── dae/                        # DAE透明代理包
│   ├── luci-app-dae/              # DAE Web界面
│   └── v2ray-geodata/             # 地理位置数据包
├── files/                          # 固件自定义文件
├── diy-re-cs-02.sh                # RE-CS-02专用构建脚本
└── README-RE-CS-02.md             # 本文档
```

## 快速开始

### 1. 手动触发构建

1. 进入 GitHub Actions 页面
2. 选择 `RE-CS-02-WIFI` 工作流
3. 点击 `Run workflow` 按钮
4. 根据需要填写自定义参数：
   - **自定义软件包**: 额外需要的软件包名称
   - **自定义LAN IP**: 默认为 192.168.10.1
   - **自定义WiFi名称**: 默认为 RE-CS-02-WIFI
   - **自定义WiFi密码**: 默认为 12345678
   - **同步上游代码**: 是否同步最新上游代码
   - **仅测试**: 是否只生成配置文件不编译

### 2. 自动化构建

项目配置了以下自动触发机制：

- **定时构建**: 每日北京时间凌晨 4 点自动构建
- **依赖构建**: 当 Auto-Clean 工作流完成后自动触发

### 3. 本地开发和测试

```bash
# 克隆项目
git clone https://github.com/你的用户名/OpenWRT-CI.git
cd OpenWRT-CI

# 使用专用脚本进行本地构建
chmod +x diy-re-cs-02.sh
./diy-re-cs-02.sh

# 编译固件
cd wrt
make download -j8
make -j$(nproc) || make V=s -j1
```

## 配置详解

### 硬件配置 (Config/RE-CS-02-WIFI.txt)

```bash
# 目标平台
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq60xx=y
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=y

# NSS 硬件加速
CONFIG_IPQ_MEM_PROFILE_512=y
CONFIG_ATH11K_MEM_PROFILE_512M=y
CONFIG_PACKAGE_sqm-scripts-nss=y
CONFIG_PACKAGE_kmod-qca-nss-crypto=y

# WiFi 支持
CONFIG_PACKAGE_kmod-ath11k=y
CONFIG_PACKAGE_kmod-ath11k-ahb=y
CONFIG_PACKAGE_ath11k-firmware-ipq6018=y
CONFIG_PACKAGE_wpad-openssl=y
```

### 系统定制

项目通过以下方式实现系统定制而不修改源文件：

1. **配置文件覆盖**: 使用专用的 RE-CS-02-WIFI.txt 配置
2. **UCI 默认设置**: 通过 uci-defaults 脚本应用系统设置
3. **自定义文件**: 通过 files/ 目录覆盖系统文件
4. **包管理脚本**: 通过 Scripts/ 目录的脚本管理软件包

### 网络配置定制

系统启动时会自动应用以下网络配置：

```bash
# LAN 设置
uci set network.lan.ipaddr='192.168.10.1'  # 可通过输入参数自定义
uci set network.lan.netmask='255.255.255.0'

# WiFi 设置
uci set wireless.default_radio0.ssid='RE-CS-02-WIFI'  # 2.4G
uci set wireless.default_radio1.ssid='RE-CS-02-WIFI'  # 5G
uci set wireless.default_radio0.key='12345678'        # 可自定义
uci set wireless.default_radio1.key='12345678'
```

## 上游同步机制

### 自动同步流程

1. **检测更新**: 获取上游仓库最新提交
2. **比较版本**: 对比本地和远程 commit
3. **选择性同步**: 只同步必要的更改，避免冲突
4. **构建触发**: 有更新时自动触发新的构建

### 同步策略

- **源码仓库**: VIKINGYFY/immortalwrt
- **目标分支**: main
- **同步频率**: 每日检查或手动触发
- **冲突处理**: 保持本地定制，仅同步兼容更改

## 软件包管理

### 内置软件包

项目默认包含以下软件包：

#### 核心组件
- **LuCI Web界面**: 完整的 Web 管理界面
- **Argon 主题**: 现代化的管理界面主题
- **中文支持**: 中文语言包

#### 网络功能
- **DAE 透明代理**: 内核级透明代理支持
- **NSS 硬件加速**: 高通平台网络加速
- **IPv6 支持**: 完整的 IPv6 网络栈
- **QoS 管理**: 流量控制和优先级管理

#### 实用工具
- **SSH 服务**: 安全远程访问
- **文件系统支持**: EXT4, NTFS3, FAT32
- **网络工具**: curl, wget, tcpdump, iperf3
- **系统工具**: htop, nano, vim, screen

### 自定义软件包

通过工作流参数或修改配置文件添加额外软件包：

```bash
# 工作流参数方式
CUSTOM_PACKAGES: "luci-app-upnp luci-app-ddns"

# 配置文件方式
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-ddns=y
```

## 构建输出

### 固件文件

成功构建后会生成以下文件：

- **sysupgrade.bin**: 系统升级固件
- **factory.bin**: 工厂模式刷写固件
- **kernel.bin**: 内核镜像
- **rootfs.squashfs**: 根文件系统

### 文件命名

固件文件按以下格式命名：
```
RE-CS-02-{构建时间}-sysupgrade.bin
RE-CS-02-{构建时间}-factory.bin
```

例如：`RE-CS-02-24.07.25_10.30.15-sysupgrade.bin`

### 下载方式

1. **GitHub Actions Artifacts**: 每次构建的固件
2. **GitHub Releases**: 定时构建的正式发布版本
3. **本地构建**: 通过 bin/targets/ 目录获取

## 安装和使用

### 固件刷写

#### 首次刷写
1. 设备进入 Recovery 模式
2. 通过 TFTP 或 Web 界面上传 factory.bin
3. 等待刷写完成并重启

#### 系统升级
1. 登录 LuCI 管理界面
2. 进入 `系统` → `备份/升级`
3. 选择 sysupgrade.bin 文件上传
4. 保持设置并升级

### 首次配置

1. **网络连接**: 
   - 有线: 连接 LAN 口，获取 192.168.10.x IP
   - 无线: 连接 RE-CS-02-WIFI，密码 12345678

2. **Web 访问**: 
   - 浏览器访问 http://192.168.10.1
   - 用户名: root，密码: 无（首次需设置）

3. **基础配置**:
   - 设置管理员密码
   - 配置网络连接
   - 设置 WiFi 参数

### DAE 透明代理配置

1. 进入 `网络` → `DAE`
2. 上传配置文件或手动配置
3. 启用 DAE 服务
4. 配置代理规则和节点

## 故障排除

### 常见问题

#### 构建失败
- **检查依赖**: 确保所有必需的软件包都可用
- **空间不足**: GitHub Actions 可能遇到磁盘空间不足
- **网络问题**: 源码下载或包安装网络超时

#### 固件问题
- **无法启动**: 检查是否使用了正确的固件文件
- **网络异常**: 重置网络配置或恢复出厂设置
- **WiFi 无信号**: 检查地区设置和天线连接

#### 功能异常
- **DAE 无法启动**: 检查配置文件格式和节点可达性
- **NSS 不工作**: 确认内核模块已加载
- **Web 界面异常**: 清除浏览器缓存或使用其他浏览器

### 调试方法

#### 日志查看
```bash
# 系统日志
logread

# 内核日志  
dmesg

# 无线日志
iw dev
iwinfo
```

#### 网络诊断
```bash
# 接口状态
ip addr show

# 路由表
ip route show

# 防火墙状态
iptables -L -n
```

## 开发指南

### 本地开发环境

#### 系统要求
- Ubuntu 20.04/22.04 或其他 Linux 发行版
- 至少 50GB 可用磁盘空间
- 8GB 或更多内存

#### 环境配置
```bash
# 安装依赖
sudo apt update
sudo apt install -y build-essential clang flex bison g++ gawk \
gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev \
python3-distutils rsync unzip zlib1g-dev file wget

# 克隆项目
git clone https://github.com/你的用户名/OpenWRT-CI.git
cd OpenWRT-CI
```

### 自定义修改

#### 添加新软件包
1. 修改 `Scripts/Packages.sh` 添加包源
2. 更新 `Config/RE-CS-02-WIFI.txt` 添加包配置
3. 测试构建确保无冲突

#### 修改系统配置
1. 编辑 `diy-re-cs-02.sh` 中的 uci-defaults 部分
2. 或在 `files/etc/uci-defaults/` 添加自定义脚本
3. 确保脚本具有执行权限

#### 自定义主题和界面
1. 在 `files/` 目录添加覆盖文件
2. 通过 Scripts/Packages.sh 添加主题包
3. 在配置文件中启用对应主题

### 贡献指南

#### 提交流程
1. Fork 本项目
2. 创建功能分支
3. 提交更改并推送
4. 创建 Pull Request

#### 代码规范
- Shell 脚本使用 4 空格缩进
- 配置文件保持一致的注释格式
- 文档更新与代码更改同步

#### 测试要求
- 本地构建测试通过
- 固件功能测试正常
- 不影响现有功能

## 许可证

本项目遵循原 OpenWRT-CI 项目的许可证条款。详细信息请查看 LICENSE 文件。

## 联系和支持

- **项目地址**: https://github.com/你的用户名/OpenWRT-CI
- **问题反馈**: GitHub Issues
- **讨论交流**: GitHub Discussions

## 更新日志

### v1.0.0 (2024-07-25)
- 初始版本发布
- RE-CS-02 专用工作流
- 自动上游同步功能
- WiFi 双频支持
- DAE 透明代理集成
- NSS 硬件加速支持

---

**注意**: 本项目仅供学习和研究使用，请遵守当地法律法规。固件刷写有风险，请在了解相关风险的情况下操作。
