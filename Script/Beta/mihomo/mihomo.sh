#!/bin/bash

#!name = mihomo 一键管理脚本 Beta
#!desc = 管理
#!date = 2024-12-19 17:30
#!author = ChatGPT

set -e -o pipefail

red="\033[31m"  ## 红色
green="\033[32m"  ## 绿色 
yellow="\033[33m"  ## 黄色
blue="\033[34m"  ## 蓝色
cyan="\033[36m"  ## 青色
reset="\033[0m"  ## 重置

sh_ver="0.1.2"

use_cdn=false

if ! curl -s --head --max-time 3 "https://www.google.com" > /dev/null; then
    use_cdn=true
fi

get_url() {
    local url=$1
    local final_url=""
    final_url=$([ "$use_cdn" = true ] && echo "https://gh-proxy.com/$url" || echo "$url")
    if ! curl --silent --head --fail --max-time 3 "$final_url" > /dev/null; then
        echo -e "${red}连接失败，可能是网络或者代理站点不可用，请检查网络并稍后重试${reset}" >&2
        exit 1
    fi
    echo "$final_url"
}

get_install() {
    local file="/root/mihomo/mihomo"
    if [ ! -f "$file" ]; then
        echo -e "${red}请先安装 mihomo${reset}"
        start_main
    fi
}

start_main() {
    echo && echo -n -e "${red}* 按回车返回主菜单 *${reset}" && read temp
    main
}

show_status() {
    local file="/root/mihomo/mihomo"
    local status install_status run_status auto_start
    if [ ! -f "$file" ]; then
        install_status="${red}未安装${reset}"
        run_status="${red}未运行${reset}"
        auto_start="${red}未设置${reset}"
    else
        install_status="${green}已安装${reset}"
        if pgrep -f "$file" > /dev/null; then
            run_status="${green}已运行${reset}"
        else
            run_status="${red}未运行${reset}"
        fi
        if systemctl is-enabled mihomo.service &>/dev/null; then
            auto_start="${green}已设置${reset}"
        else
            auto_start="${red}未设置${reset}"
        fi
    fi
    echo -e "安装状态：${install_status}"
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
            return
            ;;
        disable)
            action_text="取消开机自启"
            systemctl disable mihomo
            echo -e "${green}mihomo 开机自启已禁用${reset}"
            return
            ;;
    esac

    echo -e "${green}mihomo 准备${action_text}中${reset}"
    systemctl "$action" mihomo
    sleep 2s
    echo -e "${green}mihomo ${action_text}命令已发出${reset}"
    sleep 2s
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
        echo "无效选择，卸载已取消。"
        start_main
        return
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

update_mihomo() {
    get_install
    bash <(curl -Ls "$(get_url "https://raw.githubusercontent.com/Abcd789JK/Tools/refs/heads/main/Script/Beta/mihomo/update.sh")")
    start_main
}

config_mihomo() {
    get_install
    bash <(curl -Ls "$(get_url "https://raw.githubusercontent.com/Abcd789JK/Tools/refs/heads/main/Script/Beta/mihomo/config.sh")")
    start_main
}

install_mihomo() {
    local folders="/root/mihomo"
    local install_url="https://raw.githubusercontent.com/Abcd789JK/Tools/main/Script/Beta/mihomo/install.sh"
    if [ -d "$folders" ]; then
        echo -e "${red}检测到 mihomo 已经安装在 ${folders} 目录下${reset}"
        read -p "$(echo -e "${green}是否删除并重新安装？\n${yellow}警告：重新安装将删除当前配置和文件！${reset} (y/n): ")" confirm
        case "$confirm" in
            [Yy]* ) echo -e "${green}开始删除，重新安装中${reset}";;
            [Nn]* ) echo -e "${green}取消安装，保持现有安装${reset}"; start_main; return;;
            * ) echo -e "${red}无效选择，安装已取消${reset}"; start_main; return;;
        esac
    fi
    bash <(curl -Ls "$(get_url "$install_url")")
}

update_shell() {
    local shell_file="/usr/bin/mihomo"
    local sh_ver_url="https://raw.githubusercontent.com/Abcd789JK/Tools/main/Script/Beta/mihomo/mihomo.sh"
    local sh_new_ver=$(wget --no-check-certificate -qO- "$(get_url "$sh_ver_url")" | grep 'sh_ver="' | awk -F "=" '{print $NF}' | sed 's/\"//g' | head -1)
    echo -e "${green}开始检查脚本是否有更新${reset}"
    echo -e "当前版本：[ ${green}${sh_ver}${reset} ]"
    echo -e "最新版本：[ ${green}${sh_new_ver}${reset} ]"
    if [ "$sh_ver" == "$sh_new_ver" ]; then
        echo -e "${green}当前已是最新版本，无需更新${reset}"
        start_main
        return
    fi
    read -p "$(echo -e "${green}已检查到新版本，是否升级到最新版本？${reset} (y/n): ")" confirm
    case "$confirm" in
        [Yy]* ) echo -e "${green}开始升级，升级中请等待${reset}";;
        [Nn]* ) echo -e "${green}取消升级，保持现有版本${reset}"; start_main; return;;
        * ) echo -e "${red}无效选择，升级已取消${reset}"; start_main; return;;
    esac

    [ -f "$shell_file" ] && rm "$shell_file"
    wget -O "$shell_file" --no-check-certificate "$(get_url "$sh_ver_url")"
    chmod +x "$shell_file"
    hash -r
    echo -e "更新完成，当前版本已更新为 [ ${green}${sh_new_ver} ]${reset}"
    echo -e "${yellow}3 秒后执行新脚本${reset}"
    sleep 3s
    "$shell_file"
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
    read -p "请输入选项：" confirm
    case "$confirm" in
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