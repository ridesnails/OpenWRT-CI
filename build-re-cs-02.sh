#!/bin/bash

# RE-CS-02 快速构建脚本
# 用于快速开始 RE-CS-02 固件构建

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
RE-CS-02 WiFi 固件构建脚本

用法: $0 [选项]

选项:
    -h, --help          显示此帮助信息
    -c, --config-only   仅生成配置文件，不编译
    -f, --full-build    完整构建（包括下载和编译）
    -u, --update        更新源码和 feeds
    --lan-ip IP         设置自定义 LAN IP (默认: 192.168.10.1)
    --wifi-name NAME    设置自定义 WiFi 名称 (默认: RE-CS-02-WIFI)
    --wifi-pass PASS    设置自定义 WiFi 密码 (默认: 12345678)

示例:
    $0 -c                                    # 仅生成配置
    $0 -f                                    # 完整构建
    $0 --lan-ip 192.168.1.1 -f             # 自定义IP并构建
    $0 --wifi-name MyWiFi --wifi-pass mypass123 -f  # 自定义WiFi信息并构建

EOF
}

# 检查系统依赖
check_dependencies() {
    print_info "检查系统依赖..."
    
    local missing_deps=()
    local deps=("git" "make" "gcc" "g++" "curl" "wget" "python3")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "缺少以下依赖: ${missing_deps[*]}"
        print_info "请先安装依赖包:"
        print_info "Ubuntu/Debian: sudo apt update && sudo apt install -y build-essential git curl wget python3"
        print_info "CentOS/RHEL: sudo yum groupinstall 'Development Tools' && sudo yum install git curl wget python3"
        exit 1
    fi
    
    print_success "系统依赖检查通过"
}

# 检查磁盘空间
check_disk_space() {
    print_info "检查磁盘空间..."
    
    local available=$(df . | awk 'NR==2 {print $4}')
    local required=$((20 * 1024 * 1024)) # 20GB in KB
    
    if [ "$available" -lt "$required" ]; then
        print_warning "可用磁盘空间不足 20GB，可能导致构建失败"
        print_info "当前可用空间: $(( available / 1024 / 1024 ))GB"
        read -p "是否继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "磁盘空间充足"
    fi
}

# 设置环境变量
setup_env() {
    export WRT_CONFIG="RE-CS-02-WIFI"
    export WRT_NAME="${WIFI_NAME:-RE-CS-02-WIFI}"
    export WRT_SSID="${WIFI_NAME:-RE-CS-02-WIFI}"
    export WRT_WORD="${WIFI_PASS:-12345678}"
    export WRT_IP="${LAN_IP:-192.168.10.1}"
    export WRT_THEME="argon"
    export WRT_DIR="wrt"
    export GITHUB_WORKSPACE=$(pwd)
    export WRT_DATE=$(TZ=UTC-8 date +"%y.%m.%d_%H.%M.%S")
    
    print_info "构建配置:"
    print_info "  设备型号: RE-CS-02"
    print_info "  WiFi名称: $WRT_SSID"
    print_info "  WiFi密码: $WRT_WORD"
    print_info "  LAN地址: $WRT_IP"
    print_info "  构建时间: $WRT_DATE"
}

# 准备源码
prepare_source() {
    print_info "准备源码..."
    
    if [ ! -f "diy-re-cs-02.sh" ]; then
        print_error "未找到 diy-re-cs-02.sh 脚本"
        print_info "请确保在 OpenWRT-CI 项目根目录运行此脚本"
        exit 1
    fi
    
    # 检查配置文件
    if [ ! -f "Config/RE-CS-02-WIFI.txt" ]; then
        print_error "未找到 RE-CS-02-WIFI.txt 配置文件"
        exit 1
    fi
    
    chmod +x diy-re-cs-02.sh
    print_success "源码准备完成"
}

# 运行构建脚本
run_build_script() {
    print_info "运行 RE-CS-02 构建脚本..."
    
    # 设置环境变量并运行脚本
    WRT_NAME="$WRT_NAME" \
    WRT_SSID="$WRT_SSID" \
    WRT_WORD="$WRT_WORD" \
    WRT_IP="$WRT_IP" \
    ./diy-re-cs-02.sh
    
    print_success "构建脚本执行完成"
}

# 下载依赖包
download_packages() {
    if [ "$CONFIG_ONLY" = true ]; then
        print_info "仅生成配置模式，跳过下载"
        return
    fi
    
    print_info "下载构建依赖包..."
    
    cd "$WRT_DIR"
    
    make download -j8 || {
        print_warning "并行下载失败，尝试单线程下载..."
        make download -j1
    }
    
    # 检查下载失败的文件
    local failed_files=$(find dl -size -1024c 2>/dev/null | wc -l)
    if [ "$failed_files" -gt 0 ]; then
        print_warning "发现 $failed_files 个下载失败的文件，正在清理..."
        find dl -size -1024c -exec rm -f {} \;
    fi
    
    cd ..
    print_success "依赖包下载完成"
}

# 编译固件
compile_firmware() {
    if [ "$CONFIG_ONLY" = true ]; then
        print_info "仅生成配置模式，跳过编译"
        show_config_info
        return
    fi
    
    print_info "开始编译固件..."
    print_info "这可能需要 1-3 小时，请耐心等待..."
    
    cd "$WRT_DIR"
    
    local cpu_cores=$(nproc)
    print_info "使用 $cpu_cores 线程进行编译"
    
    if make -j"$cpu_cores"; then
        print_success "固件编译成功！"
        show_build_result
    else
        print_warning "多线程编译失败，尝试单线程详细模式..."
        if make V=s -j1; then
            print_success "固件编译成功！"
            show_build_result
        else
            print_error "固件编译失败"
            print_info "请检查错误日志并解决问题后重试"
            exit 1
        fi
    fi
    
    cd ..
}

# 显示配置信息
show_config_info() {
    print_success "配置文件生成完成！"
    print_info "配置文件位置: $WRT_DIR/.config"
    print_info "要编译固件，请运行:"
    print_info "  cd $WRT_DIR"
    print_info "  make download -j8"
    print_info "  make -j\$(nproc) || make V=s -j1"
}

# 显示构建结果
show_build_result() {
    local output_dir="$WRT_DIR/bin/targets"
    local target_dir=$(find "$output_dir" -type d -name "*qualcommax*" | head -1)
    
    if [ -d "$target_dir" ]; then
        print_info "固件文件位置: $target_dir"
        print_info "生成的固件文件:"
        ls -la "$target_dir"/*.bin 2>/dev/null || print_warning "未找到 .bin 固件文件"
        
        # 统计文件大小
        local total_size=$(du -sh "$target_dir" | cut -f1)
        print_info "输出目录总大小: $total_size"
    else
        print_warning "未找到输出目录"
    fi
    
    print_success "===================="
    print_success "RE-CS-02 固件构建完成！"
    print_success "===================="
    print_info "下载固件文件进行刷写："
    print_info "1. factory.bin - 首次刷写使用"
    print_info "2. sysupgrade.bin - 系统升级使用"
    print_info ""
    print_info "刷写后的默认设置："
    print_info "- 设备IP: $WRT_IP"
    print_info "- WiFi名称: $WRT_SSID"
    print_info "- WiFi密码: $WRT_WORD"
    print_info "- 用户名: root"
    print_info "- 密码: 无（首次登录需设置）"
}

# 清理函数
cleanup() {
    if [ "$?" -ne 0 ]; then
        print_error "构建过程中发生错误"
        print_info "清理临时文件..."
        # 可以在这里添加清理逻辑
    fi
}

# 主函数
main() {
    # 解析命令行参数
    CONFIG_ONLY=false
    FULL_BUILD=false
    UPDATE_SOURCE=false
    LAN_IP=""
    WIFI_NAME=""
    WIFI_PASS=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--config-only)
                CONFIG_ONLY=true
                shift
                ;;
            -f|--full-build)
                FULL_BUILD=true
                shift
                ;;
            -u|--update)
                UPDATE_SOURCE=true
                shift
                ;;
            --lan-ip)
                LAN_IP="$2"
                shift 2
                ;;
            --wifi-name)
                WIFI_NAME="$2"
                shift 2
                ;;
            --wifi-pass)
                WIFI_PASS="$2"
                shift 2
                ;;
            *)
                print_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 设置陷阱处理
    trap cleanup EXIT
    
    # 显示欢迎信息
    echo
    print_success "====================================="
    print_success "  RE-CS-02 WiFi 固件构建脚本"
    print_success "====================================="
    echo
    
    # 执行构建流程
    check_dependencies
    check_disk_space
    setup_env
    prepare_source
    run_build_script
    
    if [ "$FULL_BUILD" = true ] || [ "$CONFIG_ONLY" = false ]; then
        download_packages
        compile_firmware
    else
        show_config_info
    fi
    
    print_success "所有任务完成！"
}

# 运行主函数
main "$@"
