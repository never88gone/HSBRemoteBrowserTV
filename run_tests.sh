#!/usr/bin/env bash
set -e

# ==============================================================================
# HSBRemoteBrowserTV 4-Tier 独立黑盒 E2E / 协议验证套件 一键运行脚本
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="${SCRIPT_DIR}/Tests"

echo "======================================================="
echo "🔍 正在检查 Swift 编译环境与测试套件基础设施..."
echo "======================================================="

if ! command -v swift &> /dev/null; then
    echo "❌ 错误: 未检测到 Swift 编译器，请检查 Xcode 或 Command Line Tools 安装。"
    exit 1
fi

SWIFT_VERSION=$(swift --version | head -n 1)
echo "✅ 检测到 Swift: ${SWIFT_VERSION}"
echo "📁 测试套件目录: ${TESTS_DIR}"

echo "======================================================="
echo "⚡ 开始编译并运行 4-Tier 黑盒 E2E 验证套件 (166 用例)..."
echo "======================================================="

swift run --package-path "${TESTS_DIR}" HSBTestsRunner

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "======================================================="
    echo "🎉 [SUCCESS] 所有 4-Tier 测试用例全部通过！"
    echo "======================================================="
    exit 0
else
    echo "======================================================="
    echo "🚨 [FAILURE] 测试执行失败，退出码: ${EXIT_CODE}"
    echo "======================================================="
    exit $EXIT_CODE
fi
