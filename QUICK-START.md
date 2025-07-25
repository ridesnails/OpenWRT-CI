# RE-CS-02 WiFi 固件快速使用指南

## 🚀 快速开始

### GitHub Actions 在线构建（推荐）

1. **Fork 本项目**到你的 GitHub 账户

2. **手动触发构建**：
   - 进入你的项目 → Actions → `RE-CS-02-WIFI`
   - 点击 `Run workflow`
   - 自定义配置（可选）：
     ```
     WiFi名称: 你的WiFi名称
     WiFi密码: 你的密码
     LAN IP: 192.168.1.1
     ```
   - 点击运行

3. **下载固件**：
   - 构建完成后在 Actions 页面下载固件
   - 或在 Releases 页面下载正式版本

### 本地构建

```bash
# 克隆项目
git clone https://github.com/你的用户名/OpenWRT-CI.git
cd OpenWRT-CI

# 快速构建（推荐）
chmod +x build-re-cs-02.sh
./build-re-cs-02.sh -f

# 或使用原生脚本
chmod +x diy-re-cs-02.sh
./diy-re-cs-02.sh
cd wrt
make download -j8
make -j$(nproc)
```

## 📱 固件安装

### 首次刷写
1. 设备断电，按住 Reset 键后接通电源 10 秒进入恢复模式
2. 电脑连接设备 LAN 口，设置IP为 192.168.1.100
3. 浏览器访问 192.168.1.1，上传 `factory.bin` 文件
4. 等待刷写完成（约 5-10 分钟）

### 系统升级
1. 登录管理界面 http://192.168.10.1
2. 系统 → 备份/升级 → 选择 `sysupgrade.bin`
3. 不保留配置，点击升级

## ⚙️ 基本配置

### 默认设置
- **管理地址**: http://192.168.10.1
- **用户名**: root
- **密码**: 无（首次登录设置）
- **WiFi名称**: RE-CS-02-WIFI
- **WiFi密码**: 12345678

### WiFi 配置
```
2.4G: RE-CS-02-WIFI (802.11ax)
5G:   RE-CS-02-WIFI (802.11ax)
加密: WPA2-PSK/WPA3-SAE
```

### 网络配置
```
LAN: 192.168.10.1/24
DHCP: 192.168.10.100-250
```

## 🔧 高级功能

### DAE 透明代理
1. 网络 → DAE → 基本设置
2. 上传配置文件或手动配置节点
3. 启用服务并应用配置

### NSS 硬件加速
- 自动启用，支持以下功能：
  - PPPoE 加速
  - NAT 加速  
  - QoS 流控
  - VPN 加速

## 🛠️ 故障排除

### 常见问题

**无法访问管理界面**
```bash
# 重置网络配置
firstboot
reboot
```

**WiFi 无信号**
```bash
# 检查无线状态
wifi status
iwinfo

# 重启无线服务
wifi reload
```

**构建失败**
```bash
# 检查磁盘空间
df -h

# 清理构建缓存
make clean
make dirclean
```

### 恢复出厂设置
1. 设备通电状态下按住 Reset 键 10 秒
2. 或在管理界面：系统 → 备份/升级 → 恢复出厂设置

## 📋 功能清单

### ✅ 已包含功能
- [x] WiFi 6 双频支持
- [x] NSS 硬件加速
- [x] DAE 透明代理
- [x] LuCI Web 管理界面
- [x] Argon 现代主题
- [x] 中文语言支持
- [x] SSH 远程访问
- [x] IPv6 完整支持
- [x] QoS 流量控制
- [x] UPnP 端口映射

### 📦 预装软件包
```
核心: LuCI, OpenSSL, Argon主题
网络: DAE, curl, wget, iperf3, tcpdump
工具: htop, nano, vim, screen, rsync
文件: EXT4, NTFS3, FAT32 支持
```

## 🔄 自动更新

项目配置了自动同步机制：
- **定时检查**: 每日凌晨 4 点
- **源码仓库**: VIKINGYFY/immortalwrt
- **更新策略**: 检测到上游更新时自动构建

## 🆘 获取帮助

- **项目地址**: https://github.com/你的用户名/OpenWRT-CI
- **问题反馈**: GitHub Issues
- **使用交流**: GitHub Discussions
- **原项目文档**: [README-RE-CS-02.md](README-RE-CS-02.md)

---

**⚠️ 重要提醒**：
- 刷写固件有变砖风险，请确保了解恢复方法
- 首次刷写建议使用有线连接
- 建议备份原厂固件以便恢复
