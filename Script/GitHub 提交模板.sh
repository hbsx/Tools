#!/bin/bash

# 配置参数
USERNAME="GitHub_的用户名"  # GitHub 用户名
EMAIL_PREFIX="GitHub_分配的临时邮箱前缀"  # GitHub 临时邮箱前缀
GITHUB_TOKEN="GitHub_token"  # 用于身份验证的 GitHub token
PROJECT_DIR="你的实际文件路径"  # 本地仓库路径

# 设置仓库 URL，包含 GitHub token 用于身份验证
REPO_URL="https://${USERNAME}:${GITHUB_TOKEN}@github.com/${USERNAME}/Tools.git"

# 设置 Git 的用户名
git config --global user.name "${USERNAME}"
# 设置 Git 的用户邮箱，使用 GitHub 提供的临时邮箱
git config --global user.email "${EMAIL_PREFIX}+${USERNAME}@users.noreply.github.com"

# 设置换行符自动转换行为
# 对于 Windows 系统，Git 会自动将 LF 换行符转换为 CRLF
git config --global core.autocrlf true
# 对于 Linux 系统，只会在提交时将 CRLF 转换为 LF
# git config --global core.autocrlf input

# 检查项目目录是否存在
if [ ! -d "$PROJECT_DIR" ]; then
    echo "$PROJECT_DIR 不存在，开始克隆仓库"
    # 克隆远程仓库到本地目录
    git clone "$REPO_URL" "$PROJECT_DIR" || { echo "克隆失败"; exit 1; }
    echo "仓库已成功克隆到 $PROJECT_DIR"
else
    echo "$PROJECT_DIR 目录已经存在，跳过克隆操作"
fi

# 进入项目目录
cd "$PROJECT_DIR" || { echo "切换目录失败"; exit 1; }

# 检查并设置远程仓库
# 如果没有远程仓库配置，则添加远程仓库
if ! git remote | grep -q "origin"; then
    git remote add origin "$REPO_URL"
else
    # 如果远程仓库已配置，则更新远程仓库 URL
    git remote set-url origin "$REPO_URL"
fi

# 从远程仓库获取最新的提交记录
git fetch origin || { echo "Git fetch 失败"; exit 1; }

# 获取本地与远程最新提交
LOCAL_COMMIT=$(git rev-parse @)
if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    REMOTE_COMMIT=$(git rev-parse @{u})
else
    echo "当前分支没有上游分支，尝试设置"
    git branch --set-upstream-to=origin/main
    REMOTE_COMMIT=$(git rev-parse @{u})
fi

# 检查远程是否有更新
if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
    echo "检测到远程仓库有变更，准备拉取"
    git pull --rebase origin main || { echo "Git pull 失败"; exit 1; }
else
    echo "检测到远程仓库没有变更，无需拉取"
fi

# 检查本地是否有变更
if [ -n "$(git status --porcelain)" ]; then
    echo "检测到本地仓库有变更，准备提交"
    # 将所有修改过的文件（包括新增、修改、删除的文件）添加到暂存区
    git add -A
    # 将修改记录提交到本地仓库，提交信息使用当前时间戳，以确保每次提交都有唯一性
    git commit -m "Update $(date +'%Y-%m-%d %H:%M:%S')"
    # 将更改推送到远程仓库，如果是其他分支，替换 `main` 为目标分支名
    git push origin main || { echo "Git push 失败"; exit 1; }
    echo "提交成功"
else
    echo "检测到本地仓库没有变更，无需提交"
fi

exit 0