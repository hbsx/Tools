#!/bin/bash

# 配置参数
USERNAME="GitHub 的用户名"
EMAIL_PREFIX="GitHub 分配的临时邮箱前缀"
GITHUB_TOKEN="GitHub token"
PROJECT_DIR="你的实际文件路径"

# TOKEN="${GITHUB_TOKEN}"
REPO_URL="https://${USERNAME}:${GITHUB_TOKEN}@github.com/${USERNAME}/Tools.git"

# 配置 Git 用户信息
git config --global user.name "${USERNAME}"
git config --global user.email "${EMAIL_PREFIX}+${USERNAME}@users.noreply.github.com"

# 设置换行符自动转换行为
## win 系统
git config --global core.autocrlf true
## Linux 系统
# git config --global core.autocrlf input

# 检查项目目录是否存在
if [ ! -d "$PROJECT_DIR" ]; then
    echo "$PROJECT_DIR 不存在，开始克隆仓库"

    git clone "$REPO_URL" "$PROJECT_DIR" || { echo "克隆失败"; exit 1; }

    echo "仓库已成功克隆到 $PROJECT_DIR"
else
    echo "$PROJECT_DIR 目录已经存在，跳过克隆操作"
fi

# 进入项目目录
cd "$PROJECT_DIR" || { echo "切换目录失败"; exit 1; }

# 检查并设置远程仓库
if ! git remote | grep -q "origin"; then
    git remote add origin "$REPO_URL"
else
    git remote set-url origin "$REPO_URL"
fi

# 获取最新的远程仓库更新
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

    # 添加所有更改（新增、修改和删除）
    git add -A
    # 提交本地文件更改
    git commit -m "Update $(date +'%Y-%m-%d %H:%M:%S')"
    # 如果是其他分支，替换 `main` 为目标分支名
    git push origin main || { echo "Git push 失败"; exit 1; }

    echo "提交成功"
else
    echo "检测到本地仓库没有变更，无需提交"
fi

exit 0