# OpenWRT-CI 项目分析报告

## 1. 项目概述

本项目是一个用于云编译 OpenWRT 固件的持续集成 (CI) 系统。它通过一系列 Shell 脚本自动化了从拉取 OpenWRT 源码、管理软件包、应用自定义配置和补丁，到最终生成固件的过程。该项目特别关注了 eBPF 支持和 DAED 内核级透明代理等功能。

## 2. 代码结构

项目主要由 Shell 脚本和配置文件组成，核心目录和文件功能如下：

*   **根目录**:
    *   [`README.md`](README.md:1): 项目说明文档，包含固件特性、支持的硬件系列和目录结构说明。
    *   [`diy.sh`](diy.sh:1): 编译主入口脚本。负责设置环境变量、克隆/更新 OpenWRT 源码、调用其他核心脚本完成编译流程。
*   **`Config/`**: 存放不同目标平台和通用编译选项的配置文件。
    *   [`GENERAL.txt`](Config/GENERAL.txt:1): 通用的编译配置选项，会被合并到特定平台的配置中。
    *   `IPQ60XX-NOWIFI.txt`, `IPQ60XX-WIFI.txt`, 等: 针对特定硬件平台 (如 IPQ60XX, MEDIATEK, X86) 的编译配置文件。
*   **`Scripts/`**: 存放核心功能的 Shell 脚本。
    *   [`function.sh`](Scripts/function.sh:1): 包含一系列辅助函数，被其他脚本调用，用于生成配置、修改内核选项、处理 WiFi 依赖等。
    *   [`Packages.sh`](Scripts/Packages.sh:1): 负责管理和更新 OpenWRT 软件包。包含从 GitHub 克隆/更新指定软件包、更新软件包版本、删除冲突插件等逻辑。
    *   [`Handles.sh`](Scripts/Handles.sh:1): 用于处理特定软件包的定制化修改或补丁，例如为 HomeProxy 预置规则数据、调整 qca-nss-drv 驱动的启动顺序等。
    *   [`Settings.sh`](Scripts/Settings.sh:1): 用于修改固件的默认设置，如默认主题、IP 地址、WiFi SSID 和密码、主机名，并应用一些系统级补丁。
*   **`package/`**: 存放项目自定义的 OpenWRT 软件包。
    *   `dae/`: DAE (DAE Adblock Engine) 核心组件。
        *   [`Makefile`](package/dae/Makefile:1)
        *   [`files/dae.config`](package/dae/files/dae.config:1), [`files/dae.init`](package/dae/files/dae.init:1)
    *   `luci-app-dae/`: DAE 的 LuCI Web 管理界面。
        *   [`Makefile`](package/luci-app-dae/Makefile:1)
        *   `htdocs/luci-static/resources/view/dae/`: LuCI 界面的 JavaScript 文件。
    *   `v2ray-geodata/`: v2ray-geodata 相关工具或脚本。
        *   [`Makefile`](package/v2ray-geodata/Makefile:1)
        *   [`init.sh`](package/v2ray-geodata/init.sh:1)
*   **`files/`**: 存放会被直接复制到固件根文件系统中的自定义文件。
    *   `files/etc/config/argon`: Argon 主题的配置文件示例。
*   **`patches/`**: 存放用于修复或修改源码的补丁文件。
    *   [`001-fix_compile_with_ccache.patch`](patches/001-fix_compile_with_ccache.patch:1): 修复 ccache 编译问题的补丁。
    *   [`daed/Makefile`](patches/daed/Makefile:1): 可能用于修复或替换 `luci-app-daed` 中 `daed` 子模块的 Makefile。

**主要脚本及其函数关系:**

*   **[`diy.sh`](diy.sh:1)**:
    *   调用 [`Scripts/function.sh`](Scripts/function.sh:1) 中的 `generate_config()` (通过 `source` 后直接调用)。
    *   执行 [`Scripts/Packages.sh`](Scripts/Packages.sh:1)。
    *   执行 [`Scripts/Handles.sh`](Scripts/Handles.sh:1)。
    *   执行 [`Scripts/Settings.sh`](Scripts/Settings.sh:1)。
*   **[`Scripts/function.sh`](Scripts/function.sh:1)**:
    *   `cat_kernel_config()`: 向内核配置文件追加 eBPF 等相关选项。
    *   `cat_ebpf_config()`: 向 `.config` 文件追加 eBPF 相关选项。
    *   `cat_usb_net()`: 向 `.config` 文件追加 USB 网卡驱动选项。
    *   `set_nss_driver()`: 向 `.config` 文件追加 NSS 驱动相关选项。
    *   `remove_wifi()`: 移除无线相关的依赖和组件。
    *   `set_kernel_size()`: 修改特定设备 (如 jdcloud ax1800 pro) 的内核分区大小。
    *   `enable_skb_recycler()`: 开启 SKB 内存回收补丁。
    *   `generate_config()`: 核心配置生成函数，合并平台配置和通用配置，并调用上述多个函数添加特定功能配置。
*   **[`Scripts/Packages.sh`](Scripts/Packages.sh:1)**:
    *   `UPDATE_PACKAGE()`: 克隆或更新指定的软件包到 OpenWRT 源码树。
    *   `UPDATE_VERSION()`: (可选) 尝试从 GitHub API 获取软件包的最新版本并更新 Makefile。
*   **[`Scripts/Settings.sh`](Scripts/Settings.sh:1)**:
    *   直接通过 `sed` 等命令修改 OpenWRT 源码树中的配置文件或脚本，以应用自定义设置。
    *   调用 [`Scripts/function.sh`](Scripts/function.sh:1) (通过 `source` 引入)。

## 3. 核心算法/业务逻辑摘要

该项目的核心业务逻辑是自动化 OpenWRT 固件的编译过程，具体步骤如下：

1.  **初始化与环境设置 ([`diy.sh`](diy.sh:1))**:
    *   接收编译目标参数 (`WRT_CONFIG`) 和 OpenWRT 源码仓库/分支信息。若无参数，则使用默认值。
    *   设置一系列环境变量，如工作目录 (`GITHUB_WORKSPACE`)、编译日期 (`WRT_DATE`)、固件版本 (`WRT_VER`)、固件名称 (`WRT_NAME`)、WiFi SSID (`WRT_SSID`)、默认 IP (`WRT_IP`) 等。这些变量后续会被其他脚本使用。

2.  **OpenWRT 源码管理 ([`diy.sh`](diy.sh:1))**:
    *   检查本地是否已存在 OpenWRT 源码目录 (`$WRT_DIR`)。
    *   如果不存在，使用 `git clone --depth=1 --single-branch` 克隆指定的 OpenWRT 源码。
    *   如果已存在，进入该目录，设置远程仓库 URL，清理旧文件，并执行 `git pull` 更新源码。

3.  **Feeds 更新与安装 ([`diy.sh`](diy.sh:1))**:
    *   执行 `./scripts/feeds update -a` 更新所有 feeds。
    *   执行 `./scripts/feeds install -a` 安装所有 feeds 中的软件包。

4.  **自定义软件包处理 ([`diy.sh`](diy.sh:1) -> [`Scripts/Packages.sh`](Scripts/Packages.sh:1), [`Scripts/Handles.sh`](Scripts/Handles.sh:1))**:
    *   进入 `package/` 目录。
    *   执行 [`Scripts/Packages.sh`](Scripts/Packages.sh:1):
        *   通过 `UPDATE_PACKAGE()` 函数，根据预设列表从 GitHub 克隆或更新一系列第三方软件包 (如 `luci-theme-argon`, `luci-app-passwall2`, `luci-app-daed` 等)。此函数会先尝试删除本地已存在的同名或关联名称的包，以避免冲突。
        *   (可选) 通过 `UPDATE_VERSION()` 函数，尝试自动更新某些软件包 Makefile 中的版本号和 HASH 值。
        *   执行固定的包管理操作，例如：删除官方 feeds 中可能冲突的插件 (`luci-app-passwall`, `luci-app-mosdns` 等)，更新 `golang` 工具链版本，将项目根目录 `package/` 下的自定义包 (如 `dae`, `luci-app-dae`) 复制到 OpenWRT 源码的 `package` 目录中。
    *   执行 [`Scripts/Handles.sh`](Scripts/Handles.sh:1):
        *   对特定的软件包进行定制化修改。例如：为 `homeproxy` 预置规则文件；修改 `qca-nss-drv` 和 `qca-nss-pbuf` 的启动脚本中的 `START` 顺序；修复 `tailscale` Makefile 中的文件路径问题。

5.  **编译配置生成 ([`diy.sh`](diy.sh:1) -> [`Scripts/function.sh`](Scripts/function.sh:1) 的 `generate_config()`)**:
    *   调用 `generate_config()` 函数。
    *   该函数首先将指定平台的配置文件 (`Config/$WRT_CONFIG.txt`) 和通用配置文件 (`Config/GENERAL.txt`) 合并，生成初始的 `.config` 文件。
    *   如果配置名中包含 "NOWIFI" (例如 [`Config/IPQ60XX-NOWIFI.txt`](Config/IPQ60XX-NOWIFI.txt:1)), 则调用 `remove_wifi()` 函数移除无线相关的驱动和依赖。
    *   调用 `set_nss_driver()`、`cat_ebpf_config()`、`enable_skb_recycler()` 等函数向 `.config` 文件中追加 NSS 加速、eBPF 支持、SKB 内存回收等功能的编译选项。
    *   调用 `set_kernel_size()` 修改特定设备的内核分区大小配置。
    *   调用 `cat_kernel_config()` 向目标平台的内核配置文件 (如 `target/linux/qualcommax/ipq60xx/config-default`) 中添加 eBPF 等内核编译选项。

6.  **固件默认设置调整 ([`diy.sh`](diy.sh:1) -> [`Scripts/Settings.sh`](Scripts/Settings.sh:1))**:
    *   执行 [`Scripts/Settings.sh`](Scripts/Settings.sh:1)。
    *   修改默认主题 (由 `$WRT_THEME` 环境变量指定，如 `argon`)。
    *   修改 `immortalwrt.lan` 关联的 IP 地址为 `$WRT_IP`。
    *   在系统状态页面添加编译日期标识 (`DaeWRT-$WRT_DATE`)。
    *   修改默认的 WiFi SSID (`$WRT_SSID`) 和密码 (`$WRT_WORD`)。
    *   修改默认的 IP 地址 (`$WRT_IP`) 和主机名 (`$WRT_NAME`)。
    *   应用一些补丁，例如为 `vlmcsd` 添加修复 ccache 编译的补丁，修改 `dropbear` 配置。
    *   将项目根目录 `files/` 下的所有文件和目录复制到 OpenWRT 源码树的 `files/` 目录，这些文件最终会被包含在固件的根文件系统中。
    *   如果定义了 `$WRT_PACKAGE` 环境变量，将其内容追加到 `.config` 文件中，用于手动添加额外的软件包。
    *   针对高通平台 (`QUALCOMMAX`) 进行特定调整，如禁用 nss 相关 feed，设置 NSS 固件版本，开启 `sqm-nss` 插件等。

7.  **最终配置与编译准备 ([`diy.sh`](diy.sh:1))**:
    *   执行 `make defconfig`，根据 `.config` 文件生成最终的内核和软件包编译配置。
    *   脚本中注释了实际的下载和编译命令 (`make download -j8`, `make -j$(nproc) || make V=s -j1`)，这些通常由 CI 系统在后续步骤执行。

## 4. 主要数据流

*   **输入 (Inputs)**:
    *   **CI 触发参数**: 通过 GitHub Actions (或其他 CI 系统) 传递给 [`diy.sh`](diy.sh:1) 的参数，如 `$1` (用于确定 `WRT_CONFIG`) 和 `$2` (用于确定 `WRT_REPO`)。
    *   **配置文件**:
        *   `Config/*.txt` (e.g., [`Config/IPQ60XX-NOWIFI.txt`](Config/IPQ60XX-NOWIFI.txt:1), [`Config/GENERAL.txt`](Config/GENERAL.txt:1)): 定义了不同编译目标的软件包选择和内核选项。
    *   **项目内置资源**:
        *   [`package/`](package/dae/Makefile:1): 包含自定义的软件包源码 (如 `dae`, `luci-app-dae`)。
        *   [`files/`](files/etc/config/argon:1): 包含需要直接复制到固件文件系统中的文件。
        *   [`patches/`](patches/001-fix_compile_with_ccache.patch:1): 包含用于修改源码的补丁文件。
    *   **外部代码仓库**:
        *   OpenWRT 基础源码仓库 (由 `$WRT_REPO` 和 `$WRT_BRANCH` 环境变量指定，例如 `https://github.com/VIKINGYFY/immortalwrt`)。
        *   第三方软件包的 GitHub 仓库 (在 [`Scripts/Packages.sh`](Scripts/Packages.sh:1) 中通过 `UPDATE_PACKAGE` 函数动态克隆)。

*   **处理 (Processing)**:
    *   **Shell 脚本执行**: [`diy.sh`](diy.sh:1) 作为主控脚本，按顺序调用 [`Scripts/Packages.sh`](Scripts/Packages.sh:1), [`Scripts/Handles.sh`](Scripts/Handles.sh:1), [`Scripts/function.sh`](Scripts/function.sh:1) (间接调用), 和 [`Scripts/Settings.sh`](Scripts/Settings.sh:1) 中的逻辑。
    *   **环境变量**: 脚本大量使用环境变量 (在 [`diy.sh`](diy.sh:1) 中定义) 来控制编译行为和固件参数。
    *   **文件操作**:
        *   读写 `.config` 文件。
        *   修改 OpenWRT 源码树中的 Makefile、配置文件、脚本。
        *   复制文件和目录。
    *   **版本控制命令**: `git clone`, `git pull`, `git remote set-url` 等用于管理 OpenWRT 源码和第三方软件包。
    *   **文本处理命令**: `sed`, `awk`, `grep`, `find` 用于修改文件内容和查找文件。
    *   **OpenWRT 构建系统**: `make defconfig`, `./scripts/feeds update/install` (以及被注释的 `make download`, `make`)。

*   **输出 (Outputs)**:
    *   **修改后的 OpenWRT 源码树**: 包含更新的 feeds、添加/修改的软件包、应用的补丁和自定义设置。
    *   **`.config` 文件**: 最终确定的编译配置文件，指导后续的编译过程。
    *   **编译日志**: 通过 `echo` 命令输出到标准输出，由 CI 系统捕获。
    *   **(最终产物 - 隐含)**: 编译完成的 OpenWRT 固件镜像文件 (通常在 `bin/targets/...` 目录下，脚本本身不直接产生，但整个流程的目的是生成它)。

## 5. 关键内外依赖列表

*   **内部依赖**:
    *   **脚本间调用**:
        *   [`diy.sh`](diy.sh:1) 依赖并执行:
            *   [`Scripts/Packages.sh`](Scripts/Packages.sh:1)
            *   [`Scripts/Handles.sh`](Scripts/Handles.sh:1)
            *   [`Scripts/Settings.sh`](Scripts/Settings.sh:1)
        *   [`diy.sh`](diy.sh:1) (通过 `source` [`Scripts/function.sh`](Scripts/function.sh:1) 后) 调用 `generate_config()`。
        *   [`Scripts/Settings.sh`](Scripts/Settings.sh:1) `source` (引入) [`Scripts/function.sh`](Scripts/function.sh:1)。
    *   **配置文件**:
        *   [`diy.sh`](diy.sh:1) 和 [`Scripts/function.sh`](Scripts/function.sh:1) (通过 `generate_config()`) 读取 `Config/*.txt` 文件。
    *   **项目资源**:
        *   [`Scripts/Packages.sh`](Scripts/Packages.sh:1) 将 `package/*` 目录下的自定义包复制到 OpenWRT 源码树。
        *   [`Scripts/Settings.sh`](Scripts/Settings.sh:1) 将 `files/*` 目录下的文件复制到 OpenWRT 源码树。
        *   [`Scripts/Settings.sh`](Scripts/Settings.sh:1) 和 [`Scripts/Handles.sh`](Scripts/Handles.sh:1) (间接) 使用 `patches/*` 下的补丁文件。

*   **外部依赖**:
    *   **核心源码**:
        *   OpenWRT 源码仓库 (例如 `https://github.com/VIKINGYFY/immortalwrt`, 由 `$WRT_REPO` 环境变量定义)。
    *   **软件包源码**:
        *   众多第三方软件包的 GitHub 仓库 (在 [`Scripts/Packages.sh`](Scripts/Packages.sh:1) 的 `UPDATE_PACKAGE` 调用中列出，例如 `sbwml/luci-theme-argon`, `xiaorouji/openwrt-passwall2` 等)。
    *   **命令行工具 (由 CI 环境提供)**:
        *   `git`: 用于版本控制。
        *   `curl`: 用于网络请求 (如 `UPDATE_VERSION` 中获取 GitHub API 数据)。
        *   `jq`: 用于处理 JSON 数据 (如 `UPDATE_VERSION` 中解析 GitHub API 响应)。
        *   `sed`, `awk`, `grep`, `find`, `basename`, `dirname`, `realpath`, `cut`, `tr`, `rm`, `cp`, `mv`, `mkdir`, `cat`, `tee`, `sha256sum`, `dpkg` (用于版本比较): 标准的 Shell 工具。
        *   `make`, `gcc`, `binutils` 等 OpenWRT 编译所需的完整工具链 (虽然未在脚本中直接调用，但 `make defconfig` 和后续编译步骤依赖它们)。
    *   **网络服务**:
        *   GitHub.com: 用于克隆源码和软件包。
        *   GitHub API (`api.github.com`): 用于 [`Scripts/Packages.sh`](Scripts/Packages.sh:1) 中的 `UPDATE_VERSION` 功能。
    *   **可选工具**:
        *   `ccache`: 如果 `CONFIG_CCACHE=y` 生效，则依赖 `ccache` 工具以加速编译。

## 6. 核心流程 Mermaid 图

### a. 固件编译主流程 ([`diy.sh`](diy.sh:1))

```mermaid
graph TD
    A[开始: diy.sh] --> B{参数检查 WRT_CONFIG, WRT_REPO};
    B --> C[设置环境变量 GITHUB_WORKSPACE, WRT_DATE等];
    C --> D{OpenWRT源码目录 wrt 是否存在?};
    D -- 不存在 --> E[git clone OpenWRT源码];
    D -- 存在 --> F[cd wrt && git remote set-url && git clean && git reset && git pull];
    E --> G[cd wrt];
    F --> G;
    G --> H[./scripts/feeds update -a && ./scripts/feeds install -a];
    H --> I[cd package];
    I --> J[执行 Scripts/Packages.sh (更新/添加包)];
    J --> K[执行 Scripts/Handles.sh (处理特定包)];
    K --> L[cd .. (返回wrt源码根目录)];
    L --> M[调用 function.sh/generate_config 生成 .config];
    M --> N[执行 Scripts/Settings.sh (应用固件设置)];
    N --> O[make defconfig];
    O --> P[结束: 准备编译];
