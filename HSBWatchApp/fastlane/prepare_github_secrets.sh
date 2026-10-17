#!/usr/bin/env bash
# ==============================================================================
# GitHub Secrets 自动提取与格式化工具
# 
# 作用：自动扫描 fastlane 目录下的证书与描述文件，生成 GitHub Secrets 所需的 Base64 字符串
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_FILE="$SCRIPT_DIR/github_secrets.env"

echo "=================================================================="
echo "🚀 正在为您准备 GitHub Actions Secrets 参数..."
echo "=================================================================="

# 1. 检查并转换 iOS 主 App 描述文件
MAIN_PP="$SCRIPT_DIR/thlbrowserios_dis.mobileprovision"
if [[ -f "$MAIN_PP" ]]; then
    MAIN_PP_B64=$(base64 -i "$MAIN_PP" | tr -d '\n')
    echo "✅ 成功读取 iOS 主 App 描述文件: thlbrowserios_dis.mobileprovision"
    # 更新到 github_secrets.env
    if [[ -f "$SECRETS_FILE" ]]; then
        sed -i '' "s|^BUILD_PROVISION_PROFILE_BASE64=.*|BUILD_PROVISION_PROFILE_BASE64=\"$MAIN_PP_B64\"|" "$SECRETS_FILE"
    fi
else
    echo "⚠️ 未找到 thlbrowserios_dis.mobileprovision，请确认是否存放在 fastlane/ 目录下。"
fi

# 2. 检查并转换 Watch 描述文件
WATCH_PP="$SCRIPT_DIR/thlbrowseriosWatch_dis.mobileprovision"
if [[ -f "$WATCH_PP" ]]; then
    WATCH_PP_B64=$(base64 -i "$WATCH_PP" | tr -d '\n')
    echo "✅ 成功读取 Watch App 描述文件: thlbrowseriosWatch_dis.mobileprovision"
    if [[ -f "$SECRETS_FILE" ]]; then
        sed -i '' "s|^BUILD_WATCH_PROVISION_PROFILE_BASE64=.*|BUILD_WATCH_PROVISION_PROFILE_BASE64=\"$WATCH_PP_B64\"|" "$SECRETS_FILE"
    fi
else
    echo "⚠️ 未找到 thlbrowseriosWatch_dis.mobileprovision，请确认是否存放在 fastlane/ 目录下。"
fi

# 3. 检查是否有 .p12 证书
P12_FILES=( "$SCRIPT_DIR"/*.p12 )
if [[ -f "${P12_FILES[0]:-}" ]]; then
    P12_FILE="${P12_FILES[0]}"
    P12_B64=$(base64 -i "$P12_FILE" | tr -d '\n')
    echo "✅ 发现证书文件: $(basename "$P12_FILE")"
    if [[ -f "$SECRETS_FILE" ]]; then
        sed -i '' "s|^BUILD_CERTIFICATE_BASE64=.*|BUILD_CERTIFICATE_BASE64=\"$P12_B64\"|" "$SECRETS_FILE"
    fi
else
    echo "ℹ️ fastlane 目录下未检测到 *.p12 证书文件。"
    echo "   如果您已有 certificate.p12，请放入 fastlane/ 目录再次运行本脚本，或直接在 Mac「钥匙串访问」中导出为 p12。"
fi

echo ""
echo "=================================================================="
echo "🎉 参数已全部同步至本地文件:"
echo "   $SECRETS_FILE"
echo "=================================================================="
echo "请打开 GitHub 仓库页面 -> Settings -> Secrets and variables -> Actions"
echo "依次点击 [New repository secret] 添加以下 8 个密钥："
echo ""
echo "1. BUILD_CERTIFICATE_BASE64           (Apple Distribution 证书 p12 的 Base64)"
echo "2. P12_PASSWORD                       (导出 p12 时设置的密码，无密码可填留空)"
echo "3. BUILD_PROVISION_PROFILE_BASE64     (iOS 主 App 描述文件的 Base64)"
echo "4. BUILD_WATCH_PROVISION_PROFILE_BASE64 (Watch App 描述文件的 Base64)"
echo "5. APP_STORE_CONNECT_KEY_ID           (API 密钥 ID，本地已预设: FK497QS295)"
echo "6. APP_STORE_CONNECT_ISSUER_ID        (API Issuer ID，本地已预设: eea5ec99-6a0a-44be-a598-5c2fd016b10c)"
echo "7. APP_STORE_CONNECT_KEY_CONTENT      (API 密钥 AuthKey 内容或其 Base64)"
echo "8. APPLE_ID                           (开发者账号邮箱: husanbo@gmail.com)"
echo "=================================================================="
