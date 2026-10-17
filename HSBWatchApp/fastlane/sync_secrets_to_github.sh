#!/usr/bin/env bash
# ==============================================================================
# 一键自动将本地 8 个 Secrets 同步到 GitHub 仓库
# 
# 依赖：GitHub CLI (gh)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_FILE="$SCRIPT_DIR/github_secrets.env"

# 确保 gh 位于 PATH 中
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if ! command -v gh >/dev/null 2>&1; then
    echo "❌ 未检测到 GitHub CLI (gh)，正在尝试安装..."
    brew install gh
fi

echo "=================================================================="
echo "🔐 糖葫芦遥控器：GitHub Actions 秘钥自动同步工具"
echo "=================================================================="

# 1. 检查 GitHub 登录状态
if ! gh auth status >/dev/null 2>&1; then
    echo "⚠️ 检测到您尚未登录 GitHub 账号。"
    echo "👉 请在终端运行以下命令登录 (按回车使用浏览器快捷授权即可):"
    echo ""
    echo "    gh auth login"
    echo ""
    exit 1
fi

# 2. 获取目标 GitHub 仓库名
TARGET_REPO="${1:-never88gone/HSBRemoteBrowserTV}"
echo "🔍 目标 GitHub 仓库: $TARGET_REPO"

if [[ -z "$TARGET_REPO" ]]; then
    echo "❌ 仓库名不能为空，操作已终止。"
    exit 1
fi

echo "🚀 目标仓库: $TARGET_REPO"
echo "📂 读取本地配置: $SECRETS_FILE"
echo "------------------------------------------------------------------"

if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "❌ 未找到 $SECRETS_FILE，请先运行 ./prepare_github_secrets.sh"
    exit 1
fi

# 3. 逐一提取并安全上传 8 个 Secrets
SECRETS=(
    "BUILD_CERTIFICATE_BASE64"
    "P12_PASSWORD"
    "BUILD_PROVISION_PROFILE_BASE64"
    "BUILD_WATCH_PROVISION_PROFILE_BASE64"
    "APP_STORE_CONNECT_KEY_ID"
    "APP_STORE_CONNECT_ISSUER_ID"
    "APP_STORE_CONNECT_KEY_CONTENT"
    "APPLE_ID"
)

SUCCESS_COUNT=0

for SECRET_NAME in "${SECRETS[@]}"; do
    # 从文件中精准提取双引号内的内容
    VAL=$(grep "^${SECRET_NAME}=" "$SECRETS_FILE" | head -n 1 | sed -E 's/^[^=]+="?([^"]*)"?$/\1/' || true)
    
    if [[ -z "$VAL" && "$SECRET_NAME" != "P12_PASSWORD" ]]; then
        echo "⚠️  [跳过] ${SECRET_NAME} 本地值为空"
        continue
    fi
    
    echo -n "⏳ 正在上传 Secret: ${SECRET_NAME} ... "
    echo "$VAL" | gh secret set "$SECRET_NAME" --repo "$TARGET_REPO"
    echo "✅ 成功"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
done

echo "------------------------------------------------------------------"
echo "🎉 恭喜！共 ${SUCCESS_COUNT}/${#SECRETS[@]} 个 Secrets 已全自动写入 GitHub 仓库: $TARGET_REPO"
echo "👉 您可以打开仓库设置确认: https://github.com/${TARGET_REPO}/settings/secrets/actions"
echo "=================================================================="
