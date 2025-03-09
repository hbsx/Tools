#!/bin/bash

#!name = GitHub 自动同步脚本  # 脚本名称，不参与执行
#!desc = 自动同步             # 脚本描述
#!date = 2025-03-09 19:30     # 脚本创建或修改日期
#!author = ChatGPT            # 脚本作者

sh_ver="0.0.2"  # 设置脚本版本号

# 定义账户信息数组，每个元素包含 GitHub 用户名、临时邮箱前缀、GitHub Token 和项目目录
ACCOUNTS=(
    "GitHub用户名;临时邮箱前缀;GitHub Token;项目保持目录"
    "12345;56789;ghp_xxxxxxxxxxxxxxxxx;D:\GitHub\12345\你的 GitHub 上仓库名字"
)

# 定义同步仓库的函数，接受用户名、邮箱前缀、GitHub Token 和项目目录作为参数
sync_repo() {
    local USERNAME="$1"  # 用户名
    local EMAIL_PREFIX="$2"  # 邮箱前缀
    local GITHUB_TOKEN="$3"  # GitHub Token
    local PROJECT_DIR="$4"  # 项目目录
    
    local REPO_URL="https://${USERNAME}:${GITHUB_TOKEN}@github.com/${USERNAME}/Tools.git"  # 仓库 URL

    echo "========================================"
    echo "🚀 当前执行账户：${USERNAME}"  # 输出当前执行的账户名
    
    git config --global user.name "${USERNAME}"  # 设置全局 Git 用户名
    git config --global user.email "${EMAIL_PREFIX}+${USERNAME}@users.noreply.github.com"  # 设置全局 Git 邮箱
    git config --global core.autocrlf input  # 设置 Git 自动处理换行符

    # 检查项目目录是否存在
    if [ ! -d "$PROJECT_DIR" ]; then
        echo "📂 检查文件本地不存在，开始克隆仓库"  # 输出提示信息
        git clone "${REPO_URL}" "${PROJECT_DIR}" || { echo "❌ 克隆失败"; return 1; }  # 克隆仓库，如果失败则返回 1
        echo "✅ 克隆成功，文件保存位置：${PROJECT_DIR}"  # 输出克隆成功的信息
    else
        echo "📂 本地文件本地已存在，跳过克隆操作"  # 输出提示信息
    fi

    echo "📂 进入执行目录：$PROJECT_DIR"  # 输出进入的目录
    cd "$PROJECT_DIR" || { echo "❌ 切换目录失败"; return 1; }  # 进入项目目录，如果失败则返回 1
    sleep 1s  # 暂停 1 秒

    # 检查并设置远程仓库的 URL
    if ! git remote | grep -q "origin"; then
        git remote add origin "${REPO_URL}"  # 添加远程仓库 origin
    else
        git remote set-url origin "${REPO_URL}"  # 设置远程仓库 origin 的 URL
    fi

    git fetch origin || { echo "Git fetch 失败"; return 1; }  # 获取远程仓库的更新，如果失败则返回 1

    LOCAL_COMMIT=$(git rev-parse @)  # 获取本地最新提交的哈希值
    REMOTE_COMMIT=$(git rev-parse origin/main)  # 获取远程主分支的最新提交哈希值

    echo "🔎 开始检测远程仓库是否有更新，请等待"  # 提示检测远程仓库更新
    sleep 3s  # 暂停 3 秒
    # 比较本地和远程的提交哈希值，判断是否有更新
    if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
        echo "🔄 检测到远程仓库有更新，准备拉取并同步"  # 提示有更新
        if [ -n "$(git status --porcelain)" ]; then
            git stash -u  # 保存本地未提交的更改
        fi
        git pull --rebase origin main || { echo "Git pull 失败"; return 1; }  # 拉取远程更新并 rebase，如果失败则返回 1
        if [ -n "$(git stash list)" ]; then
            git stash pop  # 恢复之前保存的本地更改
        fi
        echo "✅ 已拉取并同步"  # 输出同步成功的信息
    else
        echo "🔔 未检测到远程仓库有变更，无需拉取并同步"  # 输出无更新的信息
    fi

    echo "🔎 开始检测本地仓库是否有变更，请等待"  # 提示检测本地仓库更新
    sleep 3s  # 暂停 3 秒
    # 检查本地仓库是否有未提交的更改
    if [ -n "$(git status --porcelain)" ]; then
        echo "🔄 检测到本地仓库有变更，准备提交并同步"  # 提示有本地更改
        git add -A  # 添加所有更改到暂存区
        git commit -m "Update $(date +'%Y-%m-%d %H:%M:%S')"  # 提交更改，提交信息包含当前日期和时间
        git push origin main || { echo "Git push 失败"; return 1; }  # 推送更改到远程主分支，如果失败则返回 1
        echo "✅ 已提交并同步"  # 输出提交同步成功的信息
    else
        echo "🔔 未检测到本地仓库有变更，无需提交并同步"  # 输出无本地更改的信息
    fi

    echo "✅ 恭喜你！账户 ${USERNAME} 同步成功"  # 输出同步成功的信息
    cd - > /dev/null  # 返回到之前的目录
    echo "========================================"
    echo ""
    return 0  # 返回 0，表示函数执行成功
}

# 遍历每个账户，拆分信息并调用 sync_repo 函数进行同步
for account in "${ACCOUNTS[@]}"; do
    IFS=';' read -r USERNAME EMAIL_PREFIX GITHUB_TOKEN PROJECT_DIR <<< "$account"
    sync_repo "$USERNAME" "$EMAIL_PREFIX" "$GITHUB_TOKEN" "$PROJECT_DIR"
done

echo "========================================"
echo "🎉 恭喜你！任务执行成功"  # 输出任务执行成功的信息
echo "========================================"

exit 0  # 退出脚本，返回 0，表示脚本执行成功