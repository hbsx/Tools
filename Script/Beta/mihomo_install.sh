#!/bin/bash

#!name = mihomo 一键安装脚本
#!desc = 安装
#!date = 2024-12-19 10:35
#!author = ChatGPT

set -e -o pipefail

red="\033[31m"  ## 红色
green="\033[32m"  ## 绿色 
yellow="\033[33m"  ## 黄色
blue="\033[34m"  ## 蓝色
cyan="\033[36m"  ## 青色
reset="\033[0m"  ## 重置

sh_ver="1.0.3"

use_cdn=false

if ! curl -s --head --max-time 3 "https://www.google.com" > /dev/null; then
    use_cdn=true
fi

get_url() {
    local url=$1
    local final_url
    if [ "$use_cdn" = true ]; then
        final_url="https://gh-proxy.com/$url"
        if ! curl --silent --head --fail --max-time 3 "$final_url" > /dev/null; then
            echo "代理站点不可用，请稍后重试" >&2
            exit 1
        fi
    else
        final_url="$url"
        if ! curl --silent --head --fail --max-time 3 "$final_url" > /dev/null; then
            echo "连接失败，可能是网络问题，请检查网络并稍后重试" >&2
            exit 1
        fi
    fi
    echo "$final_url"
}

get_schema() {
    arch_raw=$(uname -m)
    case "${arch_raw}" in
        'x86_64') arch='amd64';;
        'x86' | 'i686' | 'i386') arch='386';;
        'aarch64' | 'arm64') arch='arm64';;
        'armv7l') arch='armv7';;
        's390x') arch='s390x';;
        *) echo -e "${red}不支持的架构：${arch_raw}${reset}"; exit 1;;
    esac
}

get_version() {
    local version_file="/root/mihomo/version.txt"
    if [ -f "$version_file" ]; then
        cat "$version_file"
    else
        echo -e "${red}请先安装 mihomo${reset}"
        start_main
    fi
}

get_install() {
    local file="/root/mihomo/mihomo"
    if [ ! -f "$file" ]; then
        echo -e "${red}请先安装 mihomo${reset}"
        start_main
    fi
}

get_status() {
    local file="/root/mihomo/mihomo"
    if pgrep -f "$file" > /dev/null; then
        status="running"
    else
        status="stopped"
    fi
}

get_local_ip() {
    local iface=$(ip route | awk '/default/ {print $5}')
    ipv4=$(ip addr show "$iface" | awk '/inet / {print $2}' | cut -d/ -f1)
    ipv6=$(ip addr show "$iface" | awk '/inet6 / {print $2}' | cut -d/ -f1)
}

start_main() {
    echo && echo -n -e "${red}* 按回车返回主菜单 *${reset}" && read temp
    main
}

install_update() {
    apt update && apt upgrade -y
    apt install -y curl git gzip wget nano iptables tzdata
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo "Asia/Shanghai" | tee /etc/timezone > /dev/null
}

check_ip_forward() {
    local sysctl_file="/etc/sysctl.conf"
    if ! sysctl net.ipv4.ip_forward | grep -q "1"; then
        sysctl -w net.ipv4.ip_forward=1
        echo "net.ipv4.ip_forward=1" | tee -a "$sysctl_file" > /dev/null
    fi
    if ! sysctl net.ipv6.conf.all.forwarding | grep -q "1"; then
        sysctl -w net.ipv6.conf.all.forwarding=1
        echo "net.ipv6.conf.all.forwarding=1" | tee -a "$sysctl_file" > /dev/null
    fi
    sysctl -p > /dev/null
}

download_version() {
    local version_url=$(get_url "https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/version.txt")
    version=$(curl -sSL "$version_url") || { echo -e "${red}获取 mihomo 远程版本失败${reset}"; exit 1; }
}

download_mihomo() {
    local version_file="/root/mihomo/version.txt"
    local filename
    download_version
    [[ "$arch" == 'amd64' ]] && filename="mihomo-linux-${arch}-compatible-${version}.gz" ||
    filename="mihomo-linux-${arch}-${version}.gz"
    local download_url=$(get_url "https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/${filename}")
    wget -t 3 -T 30 "${download_url}" -O "${filename}" || { echo -e "${red}mihomo 下载失败，可能是网络问题，建议重新运行本脚本重试下载${reset}"; exit 1; }
    gunzip "$filename" || { echo -e "${red}mihomo 解压失败${reset}"; exit 1; }
    mv "mihomo-linux-${arch}-compatible-${version}" mihomo 2>/dev/null || mv "mihomo-linux-${arch}-${version}" mihomo || { echo -e "${red}找不到解压后的文件${reset}"; exit 1; }
    chmod +x mihomo
    echo "$version" > "$version_file"
}

download_wbeui() {
    local wbe_file="/root/mihomo/ui"
    local wbe_url=$(get_url "https://github.com/metacubex/metacubexd.git")
    git clone "$wbe_url" -b gh-pages "$wbe_file" || { echo -e "${red}管理面板下载失败，可能是网络问题，建议重新运行本脚本重试下载${reset}"; exit 1; }
}

download_service() {
    local system_file="/etc/systemd/system/mihomo.service"
    local service_url=$(get_url "https://raw.githubusercontent.com/Abcd789JK/Tools/refs/heads/main/Service/mihomo.service")
    curl -s -o "$system_file" "$service_url" || { echo -e "${red}系统服务下载失败，可能是网络问题，建议重新运行本脚本重试下载${reset}"; exit 1; }
    chmod +x "$system_file"
    systemctl enable mihomo
}

download_shell() {
    local shell_file="/usr/bin/mihomo"
    local sh_url=$(get_url "https://raw.githubusercontent.com/Abcd789JK/Tools/refs/heads/main/Script/mihomo/mihomo.sh")
    [ -f "$shell_file" ] && rm -f "$shell_file"
    wget -q -O "$shell_file" --no-check-certificate "$sh_url" || { echo -e "${red}mihomo 管理脚本下载失败，可能是网络问题，建议重新运行本脚本重试下载${reset}"; exit 1; }
    chmod +x "$shell_file"
    [[ ":$PATH:" != *":/usr/bin:"* ]] && export PATH="$PATH:/usr/bin"
    hash -r
}

install_mihomo() {
    local folders="/root/mihomo"
    if [ -d "$folders" ]; then
        echo -e "${red}检测到 mihomo 已经安装在 ${folders} 目录下${reset}"
        read -p "$(echo -e "${green}是否删除并重新安装？\n${yellow}警告：重新安装将删除当前配置和文件！${reset} (y/n): ")" confirm
        case "$confirm" in
            [Yy]* )
                echo -e "${green}开始删除现有安装并重新安装${reset}"
                rm -rf "$folders"
                ;;
            [Nn]* )
                echo -e "${green}跳过重新安装，保持现有安装${reset}"
                start_main
                return 0
                ;;
            * )
                echo -e "${red}无效选择，跳过重新安装${reset}"
                start_main
                return 0
                ;;
        esac
    fi
    install_update
    check_ip_forward
    mkdir -p "$folders" && cd "$folders" 
    get_schema
    echo -e "当前系统架构：[ ${green}${arch_raw}${reset} ]" 
    download_version
    echo -e "当前软件版本：[ ${green}${version}${reset} ]"
    download_mihomo
    download_service
    download_wbeui
    download_shell
    read -p "$(echo -e "${green}安装完成，是否下载配置文件\n${yellow}你也可以上传自己的配置文件到 $folders 目录下\n${red}配置文件名称必须是 config.yaml ${reset}，是否继续(y/n): ")" confirm
    case "$confirm" in
        [Yy]* ) config_mihomo ;;
        [Nn]* ) echo -e "${green}跳过配置文件下载${reset}" ;;
        * ) echo -e "${red}无效选择，跳过配置文件下载${reset}" ;;
    esac
    rm -f /root/install.sh
}

update_mihomo() {
    local folders="/root/mihomo"
    get_install
    echo -e "${green}开始检查 mihomo 是否有更新${reset}"
    cd "$folders" || exit
    download_version
    current_version=$(get_version)
    latest_version="$version"
    if [ "$current_version" == "$latest_version" ]; then
        echo -e "当前版本：[ ${green}${current_version}${reset} ]"
        echo -e "最新版本：[ ${green}${latest_version}${reset} ]"
        echo -e "${green}当前已是最新版本，无需更新${reset}"
        start_main
    fi
    echo -e "${green}已检查到 mihomo 已有新版本${reset}"
    echo -e "当前版本：[ ${green}${current_version}${reset} ]"
    echo -e "最新版本：[ ${green}${latest_version}${reset} ]"
    while true; do
        read -p "$(echo -e "${green}是否升级到最新版本？${reset}(y/n): ")" confirm
        case $confirm in
            [Yy]* )
                download_mihomo
                sleep 2s
                systemctl restart mihomo
                echo -e "${green}更新完成，当前版本已更新为：[ ${latest_version} ]${reset}"
                start_main
                ;;
            [Nn]* )
                echo -e "${red}更新已取消${reset}"
                start_main
                ;;
            * )
                echo -e "${red}无效的输入，请输入 y 或 n${reset}"
                ;;
        esac
    done
}

config_mihomo() {
    local folders="/root/mihomo"
    local config_file="${folders}/config.yaml"
    echo -e "${cyan}-------------------------${reset}"
    echo -e "${yellow}1. TUN 模式${reset}"
    echo -e "${yellow}2. TProxy 模式${reset}"
    echo -e "${cyan}-------------------------${reset}"
    read -p "$(echo -e "请选择运行模式（${green}推荐使用 TUN 模式${reset}）请输入选择(1/2): ")" confirm
    confirm=${confirm:-1}
    case "$confirm" in
        1) config_url="https://raw.githubusercontent.com/Abcd789JK/Tools/refs/heads/main/Config/mihomo.yaml" ;;
        2) config_url="https://raw.githubusercontent.com/Abcd789JK/Tools/refs/heads/main/Config/mihomotp.yaml" ;;
        *) echo -e "${red}无效选择，跳过配置文件下载。${reset}"; return ;;
    esac
    config_url=$(get_url "$config_url")
    wget -q -O "${config_file}" "$config_url" || { echo -e "${red}配置文件下载失败${reset}"; exit 1; }
    while true; do
        read -p "请输入需要配置的机场数量（默认 1 个，最多 5 个）：" airport_count
        airport_count=${airport_count:-1}
        if [[ "$airport_count" =~ ^[1-5]$ ]]; then
            break
        else
            echo -e "${red}无效的数量，请输入 1 到 5 之间的正整数${reset}"
        fi
    done
    proxy_providers="proxy-providers:"
    for ((i=1; i<=airport_count; i++)); do
        read -p "请输入第 $i 个机场的订阅连接：" airport_url
        read -p "请输入第 $i 个机场的名称：" airport_name
        proxy_providers="$proxy_providers
  provider_0$i:
    url: \"$airport_url\"
    type: http
    interval: 86400
    health-check: {enable: true, url: \"https://www.youtube.com/generate_204\", interval: 300}
    override:
      additional-prefix: \"[$airport_name]\""
    done
    awk -v providers="$proxy_providers" '
    /^# 机场配置/ {
        print
        print providers
        next
    }
    { print }
    ' "$config_file" > temp.yaml && mv temp.yaml "$config_file"
    systemctl daemon-reload
    systemctl start mihomo
    get_local_ip
    echo -e "${green}恭喜你，你的 mihomo 已经配置完成并保存到 ${yellow}${config_file}${reset}"
    echo -e "下面是 mihomo 管理面板地址和进入管理菜单命令"
    echo -e "${cyan}=========================${reset}"
    echo -e "${green}http://$ipv4:9090/ui ${reset}"
    echo -e "${green}mihomo          进入菜单 ${reset}"
    echo -e "${cyan}=========================${reset}"
}

show_status() {
    local file="/root/mihomo/mihomo"
    if [ ! -f "$file" ]; then
        status="${red}未安装${reset}"
        run_status="${red}未运行${reset}"
        auto_start="${red}未设置${reset}"
    else
        get_status
        if [ "$status" == "running" ]; then
            status="${green}已安装${reset}"
            run_status="${green}已运行${reset}"
        else
            status="${green}已安装${reset}"
            run_status="${red}未运行${reset}"
        fi
        if systemctl is-enabled mihomo.service &>/dev/null; then
            auto_start="${green}已设置${reset}"
        else
            auto_start="${red}未设置${reset}"
        fi
    fi
    echo -e "安装状态：${status}"
    echo -e "运行状态：${run_status}"
    echo -e "开机自启：${auto_start}"
    echo -e "脚本版本：${green}${sh_ver}${reset}"
}

service_mihomo() {
    local action="$1"
    get_install
    action_text=""
    case "$action" in
        start) 
            action_text="启动" 
            if systemctl is-active --quiet mihomo; then
                echo -e "${yellow}mihomo 已经在运行，无需重复启动${reset}"
                return 0
            fi
            ;;
        stop)
            action_text="停止" 
            if ! systemctl is-active --quiet mihomo; then
                echo -e "${yellow}mihomo 已经停止，无需重复操作${reset}"
                return 0
            fi
            ;;
        restart) 
            action_text="重启"
            ;;
        enable)
            action_text="设置开机自启"
            systemctl enable mihomo
            echo -e "${green}mihomo 开机自启已启用${reset}"
            return 0
            ;;
        disable)
            action_text="取消开机自启"
            systemctl disable mihomo
            echo -e "${green}mihomo 开机自启已禁用${reset}"
            return 0
            ;;
    esac

    echo -e "${green}mihomo 准备${action_text}中${reset}"
    systemctl "$action" mihomo
    sleep 1s
    echo -e "${green}mihomo ${action_text}命令已发出${reset}"
    sleep 3s
    if [ "$action" = "stop" ]; then
        if systemctl is-active --quiet mihomo; then
            echo -e "${red}mihomo ${action_text}失败${reset}"
        else
            echo -e "${green}mihomo ${action_text}成功${reset}"
        fi
    else
        if systemctl is-active --quiet mihomo; then
            echo -e "${green}mihomo ${action_text}成功${reset}"
        else
            echo -e "${red}mihomo ${action_text}失败${reset}"
        fi
    fi
    start_main
}

start_mihomo() { service_mihomo start; }
stop_mihomo() { service_mihomo stop; }
restart_mihomo() { service_mihomo restart; }
enable_mihomo() { service_mihomo enable; }
disable_mihomo() { service_mihomo disable; }

uninstall_mihomo() {
    local folders="/root/mihomo"
    local shell_file="/usr/bin/mihomo"
    local system_file="/etc/systemd/system/mihomo.service"
    get_install
    read -p "$(echo -e "${green}确认卸载 mihomo 吗？\n${yellow}警告：卸载后将删除当前配置和文件！${reset} (y/n): ")" confirm
    if [[ -z $confirm || $confirm =~ ^[Nn]$ ]]; then
        echo "卸载已取消。"
        start_main
    fi
    echo -e "${green}mihomo 开始卸载${reset}"
    sleep 2s
    echo -e "${green}mihomo 卸载命令已发出${reset}"
    systemctl stop mihomo.service 2>/dev/null || { echo -e "${red}停止 mihomo 服务失败${reset}"; exit 1; }
    systemctl disable mihomo.service 2>/dev/null || { echo -e "${red}禁用 mihomo 服务失败${reset}"; exit 1; }
    rm -f "$system_file" || { echo -e "${red}删除服务文件失败${reset}"; exit 1; }
    rm -rf "$folders" || { echo -e "${red}删除相关文件夹失败${reset}"; exit 1; }
    systemctl daemon-reload || { echo -e "${red}重新加载 systemd 配置失败${reset}"; exit 1; }
    sleep 3s
    if [ ! -f "$system_file" ] && [ ! -d "$folders" ]; then
        echo -e "${green}mihomo 卸载完成${reset}"
        echo ""
        echo -e "卸载成功，如果你想删除此脚本，则退出脚本后，输入 ${green}rm $shell_file -f${reset} 进行删除"
        echo ""
    else
        echo -e "${red}卸载过程中出现问题，请手动检查${reset}"
    fi
    start_main
}

update_shell() {
    local shell_file="/usr/bin/mihomo"
    echo -e "${green}开始检查管理脚本是否有更新${reset}"
    sh_ver_url="https://raw.githubusercontent.com/Abcd789JK/Tools/main/Script/mihomo/mihomo.sh"
    sh_new_ver=$(wget --no-check-certificate -qO- "$sh_ver_url" | grep 'sh_ver="' | awk -F "=" '{print $NF}' | sed 's/\"//g' | head -1)
    if [ "$sh_ver" == "$sh_new_ver" ]; then
        echo -e "当前版本：[ ${green}${sh_ver}${reset} ]"
        echo -e "最新版本：[ ${green}${sh_new_ver}${reset} ]"
        echo -e "${green}当前已是最新版本，无需更新${reset}"
        start_main
    fi
    echo -e "${green}检查到管理脚本已有新版本${reset}"
    echo -e "当前版本：[ ${green}${sh_ver}${reset} ]"
    echo -e "最新版本：[ ${green}${sh_new_ver}${reset} ]"
    while true; do
        read -p "$(echo -e "${green}是否升级到最新版本？${reset}(y/n): ")" confirm
        case $confirm in
            [Yy]* )
                echo -e "开始下载最新版本 [ ${green}${sh_new_ver}${reset} ]"
                if [ -f "$shell_file" ]; then
                    rm $shell_file
                fi
                wget -O $shell_file --no-check-certificate "$sh_ver_url"
                chmod +x $shell_file
                if [[ ":$PATH:" != *":/usr/bin:"* ]]; then
                    export PATH=$PATH:/usr/bin
                fi
                hash -r
                echo -e "更新完成，当前版本已更新为 ${green}[ v${sh_new_ver} ]${reset}"
                echo -e "5 秒后执行新脚本"
                sleep 5s
                /usr/bin/mihomo
                break
                ;;
            [Nn]* )
                echo -e "${red}更新已取消 ${reset}"
                start_main
                ;;
            * )
                echo -e "${red}无效的输入，请输入 y 或 n ${reset}"
                ;;
        esac
    done
    start_main
}

main() {
    clear
    echo "================================="
    echo -e "${green}欢迎使用 mihomo 一键脚本 Beta 版${reset}"
    echo -e "${green}作者：${yellow}ChatGPT JK789${reset}"
    echo -e "${red}更换订阅说明：${reset}"
    echo -e "${red} 1. 更换订阅不能保存原有机场订阅"
    echo -e "${red} 2. 需要全部重新添加机场订阅${reset}"
    echo "================================="
    echo -e "${green} 0${reset}. 更新脚本"
    echo -e "${green}10${reset}. 退出脚本"
    echo -e "${green}20${reset}. 更换订阅"
    echo "---------------------------------"
    echo -e "${green} 1${reset}. 安装 mihomo"
    echo -e "${green} 2${reset}. 更新 mihomo"
    echo -e "${green} 3${reset}. 卸载 mihomo"
    echo "---------------------------------"
    echo -e "${green} 4${reset}. 启动 mihomo"
    echo -e "${green} 5${reset}. 停止 mihomo"
    echo -e "${green} 6${reset}. 重启 mihomo"
    echo "---------------------------------"
    echo -e "${green} 7${reset}. 添加开机自启"
    echo -e "${green} 8${reset}. 关闭开机自启"
    echo "================================="
    show_status
    echo "================================="
    read -p "请输入选项[0-10]：" num
    case "$num" in
        1) install_mihomo ;;
        2) update_mihomo ;;
        3) uninstall_mihomo ;;
        4) start_mihomo ;;
        5) stop_mihomo ;;
        6) restart_mihomo ;;
        7) enable_mihomo ;;
        8) disable_mihomo ;;
        20) config_mihomo ;;
        10) exit 0 ;;
        0) update_shell ;;
        *) echo -e "${Red}无效选项，请重新选择${reset}" 
           exit 1 ;;
    esac
}

main