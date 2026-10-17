#!/usr/bin/env bash
# ==============================================================================
# 根据当前时间 (年月日时分秒) 生成全新的构建版本号
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/HSBWatchApp/HSBWatchCompanion/AppVersion.xcconfig"

# 生成当前年月日时分秒时间戳 (例如: 20261017080800)
TIMESTAMP=$(date +"%Y%m%d%H%M%S")

echo "=================================================================="
echo "🕒 正在按时间戳生成新版本号: $TIMESTAMP"
echo "=================================================================="

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ 找不到配置文件: $CONFIG_FILE"
    exit 1
fi

sed -i '' "s|^GITHUB_VERSION[[:space:]]*=.*|GITHUB_VERSION = $TIMESTAMP|" "$CONFIG_FILE"
sed -i '' "s|^BUILD_VERSION[[:space:]]*=.*|BUILD_VERSION = $TIMESTAMP|" "$CONFIG_FILE"

PBXPROJ_FILE="$ROOT_DIR/HSBWatchApp/HSBWatchApp.xcodeproj/project.pbxproj"
if [[ -f "$PBXPROJ_FILE" ]]; then
    sed -i '' "s|CURRENT_PROJECT_VERSION = .*;|CURRENT_PROJECT_VERSION = $TIMESTAMP;|" "$PBXPROJ_FILE"
    echo "✅ $PBXPROJ_FILE 中 CURRENT_PROJECT_VERSION 已同步更新为: $TIMESTAMP"
fi

echo "✅ $CONFIG_FILE 已成功更新为:"
cat "$CONFIG_FILE"
echo "=================================================================="
