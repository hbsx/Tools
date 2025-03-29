#!/bin/bash
# !name = mihomo 一键安装脚本
# !desc = 安装 & 配置（同时兼容 alpine、debian、ubuntu）
# !date = 2025-03-29 20:21:08
# !author = ChatGPT

set -e -o pipefail

# 定义颜色变量
red="\033[31m"    
green="\033[32m"  
yellow="\033[33m" 
blue="\033[34m"   
cyan="\033[36m"   
reset="\033[0m"   

sh_ver="1.0.0"
use_cdn=false
distro="unknown"

# 全局变量：包管理命令及服务管理函数
pkg_update=""
pkg_install=""
service_enable=""
service_restart=""

# 检测系统类型：支持 alpine、debian、ubuntu（分别显示）
check_distro() {
    if [ -f /etc/alpine-release ]; then
        distro="alpine"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            debian)
                distro="debian"
                ;;
            ubuntu)
                distro="ubuntu"
                ;;
            alpine)
                distro="alpine"
                ;;
            *)
                echo -e "${red}不支持的系统：${ID}${reset}"
                exit 1
                ;;
        esac
    else
        echo -e "${red}无法识别当前系统类型${reset}"
        exit 1
    fi

    # 根据系统类型统一设置包管理和服务管理命令
    if [ "$distro" = "alpine" ]; then
        pkg_update="apk update && apk upgrade"
        pkg_install="apk add"
        service_enable() { rc-update add mihomo default; }
        service_restart() { rc-service mihomo restart; }
    else
        pkg_update="apt update && apt upgrade -y"
        pkg_install="apt install -y"
        service_enable() { systemctl enable mihomo; }
        service_restart() { systemctl daemon-reload; systemctl start mihomo; }
    fi
}

# 检查网络状态，如无法访问 Google 则启用 CDN 代理
check_network() {
    if ! curl -s --head --max-time 3 "https://www.google.com" > /dev/null; then
        use_cdn=true
    fi
}

# 根据 CDN 状态返回最终 URL，并测试连通性
get_url() {
    local url=$1
    local final_url
    final_url=$([ "$use_cdn" = true ] && echo "https://gh-proxy.com/$url" || echo "$url")
    if ! curl --silent --head --fail --max-time 3 "$final_url" > /dev/null; then
        echo -e "${red}连接失败，可能是网络或代理站点不可用，请检查后重试${reset}" >&2
        exit 1
    fi
    echo "$final_url"
}

# 获取系统架构信息，并转换为标准格式
get_schema() {
    arch_raw=$(uname -m)
    case "$arch_raw" in
        x86_64)      arch='amd64' ;;
        x86|i686|i386) arch='386' ;;
        aarch64|arm64) arch='arm64' ;;
        armv7l)      arch='armv7' ;;
        s390x)       arch='s390x' ;;
        *) echo -e "${red}不支持的架构：${arch_raw}${reset}"; exit 1 ;;
    esac
}

# 更新系统及安装必要软件包（使用预设变量）
update_system() {
    eval "$pkg_update"
    eval "$pkg_install curl git gzip wget nano iptables tzdata jq unzip" 
}

# 开启 IPv4 与 IPv6 转发
check_ip_forward() {
    local sysctl_file="/etc/sysctl.conf"
    sysctl net.ipv4.ip_forward | grep -q "1" || {
        sysctl -w net.ipv4.ip_forward=1
        echo "net.ipv4.ip_forward=1" >> "$sysctl_file"
    }
    sysctl net.ipv6.conf.all.forwarding | grep -q "1" || {
        sysctl -w net.ipv6.conf.all.forwarding=1
        echo "net.ipv6.conf.all.forwarding=1" >> "$sysctl_file"
    }
    sysctl -p > /dev/null
}

# 下载远程版本号
download_version() {
    local version_url
    version_url=$(get_url "https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/version.txt")
    version=$(curl -sSL "$version_url") || { 
        echo -e "${red}获取 mihomo 远程版本失败${reset}"; exit 1; 
    }
}

# 下载并解压 mihomo 可执行文件
download_mihomo() {
    local version_file="/root/mihomo/version.txt"
    download_version
    local filename="mihomo-linux-${arch}-${version}.gz"
    [[ "$arch" == "amd64" ]] && filename="mihomo-linux-${arch}-compatible-${version}.gz"
    local download_url
    download_url=$(get_url "https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/${filename}")
    wget -t 3 -T 30 "$download_url" -O "$filename" || { 
        echo -e "${red}mihomo 下载失败，请检查网络后重试${reset}"; exit 1; 
    }
    gunzip "$filename" || { echo -e "${red}mihomo 解压失败${reset}"; exit 1; }
    mv "mihomo-linux-${arch}-compatible-${version}" mihomo 2>/dev/null || \
    mv "mihomo-linux-${arch}-${version}" mihomo || { 
        echo -e "${red}找不到解压后的文件${reset}"; exit 1; 
    }
    chmod +x mihomo
    echo "$version" > "$version_file"
}

# 下载系统服务配置文件，并调用统一的服务启用函数
download_service() {
    if [ "$distro" = "alpine" ]; then
        local service_file="/etc/init.d/mihomo"
        local service_url
        service_url=$(get_url "https://raw.githubusercontent.com/Abcd789JK/Tools/refs/heads/main/Service/mihomo.openrc")
        wget -q -O "$service_file" "$service_url" || { 
            echo -e "${red}Alpine 服务下载失败${reset}"; exit 1; 
        }
        chmod +x "$service_file"
        service_enable
    else
        local system_file="/etc/systemd/system/mihomo.service"
        local service_url
        service_url=$(get_url "https://raw.githubusercontent.com/Abcd789JK/Tools/refs/heads/main/Service/mihomo.service")
        curl -s -o "$system_file" "$service_url" || { 
            echo -e "${red}系统服务下载失败，请检查网络后重试${reset}"; exit 1; 
        }
        chmod +x "$system_file"
        service_enable
    fi
}

# 下载管理面板文件
download_wbeui() {
    local wbe_file="/root/mihomo/ui"
    local wbe_url="https://github.com/metacubex/metacubexd.git"
    git clone "$wbe_url" -b gh-pages "$wbe_file" || { 
        echo -e "${red}管理面板下载失败，请检查网络后重试${reset}"; exit 1; 
    }
}

# 下载 mihomo 管理脚本到 /usr/bin
download_shell() {
    local shell_file="/usr/bin/mihomo"
    local sh_url
    sh_url=$(get_url "https://raw.githubusercontent.com/Abcd789JK/Tools/refs/heads/main/Script/Beta/mihomo/mihomo.sh")
    [ -f "$shell_file" ] && rm -f "$shell_file"
    wget -q -O "$shell_file" --no-check-certificate "$sh_url" || { 
        echo -e "${red}mihomo 管理脚本下载失败，请检查网络后重试${reset}"; exit 1; 
    }
    chmod +x "$shell_file"
    hash -r
}

# 安装 mihomo：下载文件、服务、管理面板及脚本，并提示后续配置
install_mihomo() {
    local folders="/root/mihomo"
    rm -rf "$folders"
    mkdir -p "$folders" && cd "$folders"
    check_distro
    echo -e "${yellow}当前系统版本：${reset}[ ${green}${distro}${reset} ]"
    get_schema
    echo -e "${yellow}当前系统架构：${reset}[ ${green}${arch_raw}${reset} ]"
    download_version
    echo -e "${yellow}当前软件版本：${reset}[ ${green}${version}${reset} ]"
    download_mihomo
    download_service
    download_wbeui
    download_shell

    read -p "$(echo -e "${green}安装完成，是否下载配置文件\n${yellow}也可上传自定义配置到 ${folders} (文件名必须为 config.yaml)\n${red}是否继续${green}(y/n): ${reset}")" confirm
    case "$confirm" in
        [Yy]*) config_mihomo ;;
        [Nn]*) echo -e "${green}跳过配置文件下载${reset}" ;;
         *) echo -e "${red}无效选择，跳过配置文件下载${reset}" ;;
    esac
    rm -f /root/install.sh
}

# 下载并生成配置文件，同时添加机场订阅信息
# 此处修改为无需先输入机场数量，而是循环提示输入，直到用户输入 n/N 表示结束
config_mihomo() {
    local folders="/root/mihomo"
    local config_file="/root/mihomo/config.yaml"
    local iface ipv4 ipv6 config_url

    # 获取默认网卡及 IP 信息
    iface=$(ip route | awk '/default/ {print $5}')
    ipv4=$(ip addr show "$iface" | awk '/inet / {print $2}' | cut -d/ -f1)
    ipv6=$(ip addr show "$iface" | awk '/inet6 / {print $2}' | cut -d/ -f1)

    echo -e "${cyan}-------------------------${reset}"
    echo -e "${yellow}1. TUN 模式${reset}"
    echo -e "${yellow}2. TProxy 模式${reset}"
    echo -e "${cyan}-------------------------${reset}"
    read -p "$(echo -e "请选择运行模式（推荐使用 TUN 模式）请输入选择(1/2): ")" confirm
    confirm=${confirm:-1}
    case "$confirm" in
        1) config_url="https://raw.githubusercontent.com/Abcd789JK/Tools/refs/heads/main/Config/mihomo.yaml" ;;
        2) config_url="https://raw.githubusercontent.com/Abcd789JK/Tools/refs/heads/main/Config/mihomotp.yaml" ;;
        *) echo -e "${red}无效选择，跳过配置文件下载。${reset}"; return ;;
    esac

    config_url=$(get_url "$config_url")
    wget -q -O "$config_file" "$config_url" || { 
        echo -e "${red}配置文件下载失败${reset}"; exit 1; 
    }

    # 添加机场订阅信息
    local proxy_providers="proxy-providers:"
    local counter=1
    while true; do
        read -p "请输入机场的订阅连接：" airport_url
        read -p "请输入机场的名称：" airport_name
        proxy_providers="${proxy_providers}
  provider_$(printf "%02d" $counter):
    url: \"${airport_url}\"
    type: http
    interval: 86400
    health-check: {enable: true, url: \"https://www.youtube.com/generate_204\", interval: 300}
    override:
      additional-prefix: \"[${airport_name}]\""
        counter=$((counter + 1))
        read -p "继续输入订阅？(或者输入 n/N 结束): " cont
        if [[ "$cont" =~ ^[nN]$ ]]; then
            break
        fi
    done

    # 将机场配置插入到配置文件中
    awk -v providers="$proxy_providers" '
      /^# 机场配置/ { print; print providers; next }
      { print }
    ' "$config_file" > temp.yaml && mv temp.yaml "$config_file"

    service_restart

    echo -e "${green}配置完成，配置文件已保存到：${yellow}${config_file}${reset}"
    echo -e "${red}mihomo 管理面板地址和管理命令：${reset}"
    echo -e "${cyan}=========================${reset}"
    echo -e "${green}http://$ipv4:9090/ui${reset}"
    echo -e "${green}命令：mihomo 进入管理菜单${reset}"
    echo -e "${cyan}=========================${reset}"
}

# 主流程：依次执行系统检测、网络检查、更新系统、开启转发及安装
check_distro
check_network
update_system
check_ip_forward
install_mihomo
