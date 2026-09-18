#!/usr/bin/env bash
set -euo pipefail

# 糖葫芦遥控器：App Store 自动打包、独立验签与导出脚本 (参考 THLDance 规范)
PLATFORM="${1:-ios}"
ACTION="${2:---archive-only}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/HSBWatchApp/HSBWatchApp.xcodeproj"
BUILD_NUMBER="${BUILD_NUMBER:-${THLBROWSER_BUILD_NUMBER:-$(date +%Y%m%d%H%M)}}"
OUTPUT_ROOT="${OUTPUT_ROOT:-${THLBROWSER_ARCHIVE_ROOT:-$ROOT_DIR/Artifacts/AppStore/$BUILD_NUMBER}}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${THLBROWSER_DERIVED_DATA_PATH:-$HOME/.thlbrowser-derived}}"

# 网络加速防护：如果本地代理监听 6152 端口（如 Surge/Clash），自动注入代理加速 GitHub SPM 依赖拉取
if nc -z 127.0.0.1 6152 2>/dev/null; then
  export http_proxy="http://127.0.0.1:6152"
  export https_proxy="http://127.0.0.1:6152"
  export ALL_PROXY="http://127.0.0.1:6152"
  echo "==> 检测到本地开发代理 (127.0.0.1:6152)，已自动开启 SPM 网络拉取加速"
fi

# 1. 自动装载 Fastlane 目录下的描述文件至系统 Provisioning Profiles 路径 (支持本地与 CI/CD Runner)
PROFILES_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$PROFILES_DIR"

install_provisioning_profiles() {
  echo "==> 检查并动态装载描述文件..."
  for p in "$ROOT_DIR/HSBWatchApp/fastlane"/*.mobileprovision; do
    if [[ -f "$p" ]]; then
      local uuid
      uuid=$(/usr/libexec/PlistBuddy -c "Print :UUID" /dev/stdin <<< "$(security cms -D -i "$p" 2>/dev/null)" 2>/dev/null || true)
      local name
      name=$(/usr/libexec/PlistBuddy -c "Print :Name" /dev/stdin <<< "$(security cms -D -i "$p" 2>/dev/null)" 2>/dev/null || true)
      if [[ -n "$uuid" ]]; then
        cp -f "$p" "$PROFILES_DIR/$uuid.mobileprovision"
        echo "    已装载描述文件: $name -> $uuid.mobileprovision"
      fi
    fi
  done
}

install_provisioning_profiles

if [[ "$PLATFORM" == "all" ]]; then
  PLATFORM="ios"
fi

if [[ "$PLATFORM" != "ios" ]]; then
  echo "usage: $0 {ios|all} [--archive-only|--export|--export-only|--verify-only]" >&2
  exit 2
fi

SCHEME="HSBWatchCompanion"
DESTINATION="generic/platform=iOS"
EXPORT_OPTIONS="$ROOT_DIR/ExportOptions_iOS_appstore.plist"
EXPECTED_BUNDLE_ID="com.never88gone.thlbrowserios"
EXPECTED_WATCH_BUNDLE_ID="com.never88gone.thlbrowserios.watch"

if [[ "$ACTION" != "--archive-only" && "$ACTION" != "--export" && "$ACTION" != "--export-only" && "$ACTION" != "--verify-only" ]]; then
  echo "usage: $0 {ios|all} [--archive-only|--export|--export-only|--verify-only]" >&2
  exit 2
fi

ARCHIVE_PATH="$OUTPUT_ROOT/$PLATFORM/$SCHEME.xcarchive"
EXPORT_PATH="$OUTPUT_ROOT/$PLATFORM/export"
mkdir -p "$(dirname "$ARCHIVE_PATH")"

if [[ "$ACTION" == "--archive-only" || "$ACTION" == "--export" ]]; then
  echo "==> Archiving $SCHEME (build $BUILD_NUMBER)..."
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -archivePath "$ARCHIVE_PATH" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    archive
elif [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "ERROR: archive not found for verification: $ARCHIVE_PATH" >&2
  exit 1
fi

APP_PATH="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -type d -name '*.app' -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "ERROR: archive does not contain an application" >&2
  exit 1
fi

read_plist() {
  local info_plist="$1/Info.plist"
  /usr/libexec/PlistBuddy -c "Print :$2" "$info_plist"
}

assert_equal() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: $label is '$actual', expected '$expected'" >&2
    exit 1
  fi
}

assert_privacy_manifest() {
  local bundle="$1"
  local label="$2"
  local manifest=""
  local candidate
  for candidate in \
    "$bundle/PrivacyInfo.xcprivacy" \
    "$bundle/Resources/PrivacyInfo.xcprivacy" \
    "$bundle/Contents/Resources/PrivacyInfo.xcprivacy"; do
    if [[ -f "$candidate" ]]; then
      manifest="$candidate"
      break
    fi
  done
  if [[ -z "$manifest" ]]; then
    echo "ERROR: $label does not contain PrivacyInfo.xcprivacy" >&2
    exit 1
  fi
  plutil -lint "$manifest" >/dev/null
}

echo "==> 正在执行独立法医级签名与合规性检查..."
APP_VERSION="$(read_plist "$APP_PATH" CFBundleShortVersionString)"
APP_BUILD="$(read_plist "$APP_PATH" CFBundleVersion)"

assert_equal "iOS bundle identifier" "$(read_plist "$APP_PATH" CFBundleIdentifier)" "$EXPECTED_BUNDLE_ID"
assert_equal "iOS marketing version" "$APP_VERSION" "1.0.0"
assert_equal "iOS build number" "$APP_BUILD" "$BUILD_NUMBER"
assert_equal "iOS export-compliance flag" "$(read_plist "$APP_PATH" ITSAppUsesNonExemptEncryption)" "false"
assert_privacy_manifest "$APP_PATH" "iOS app"

# 校验内嵌的 watchOS 伴侣应用
WATCH_PATH="$(find "$APP_PATH/Watch" -maxdepth 1 -type d -name '*.app' -print -quit 2>/dev/null || true)"
if [[ -z "$WATCH_PATH" ]]; then
  echo "ERROR: iOS archive does not contain embedded watchOS companion app in Watch/" >&2
  exit 1
fi

assert_equal "watchOS bundle identifier" "$(read_plist "$WATCH_PATH" CFBundleIdentifier)" "$EXPECTED_WATCH_BUNDLE_ID"
assert_equal "watchOS companion bundle identifier" "$(read_plist "$WATCH_PATH" WKCompanionAppBundleIdentifier)" "$EXPECTED_BUNDLE_ID"
assert_equal "watchOS version" "$(read_plist "$WATCH_PATH" CFBundleShortVersionString)" "$APP_VERSION"
assert_equal "watchOS build number" "$(read_plist "$WATCH_PATH" CFBundleVersion)" "$APP_BUILD"
assert_equal "watchOS export-compliance flag" "$(read_plist "$WATCH_PATH" ITSAppUsesNonExemptEncryption)" "false"
assert_privacy_manifest "$WATCH_PATH" "watchOS companion app"

echo "==> 执行严格代码签名校验 (codesign --verify --deep --strict)..."
codesign --verify --deep --strict "$APP_PATH"
echo "PASS: 主工程与内嵌 Watch App 元数据、隐私清单和代码签名完全通过！"
echo "Archive: $ARCHIVE_PATH"

if [[ "$ACTION" == "--export" || "$ACTION" == "--export-only" ]]; then
  mkdir -p "$EXPORT_PATH"
  echo "==> Exporting IPA with $(basename "$EXPORT_OPTIONS")..."
  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS"
  
  IPA_FILE="$(find "$EXPORT_PATH" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
  if [[ -z "$IPA_FILE" ]]; then
    echo "ERROR: export did not produce an .ipa file" >&2
    exit 1
  fi
  echo "Exported IPA: $IPA_FILE"
  echo "SHA256: $(shasum -a 256 "$IPA_FILE" | awk '{print $1}')"
fi
