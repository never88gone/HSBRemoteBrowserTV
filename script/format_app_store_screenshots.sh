#!/usr/bin/env bash
set -euo pipefail

# 糖葫芦遥控器：App Store 官方截图尺寸与色彩通道合规化转换脚本
# 1. 重采样至苹果强制的 6.9 英寸最高清分辨率 1320 x 2868 (iPhone 16 Pro Max / 15 Pro Max 官方标准)
# 2. 彻底剔除 Alpha 透明通道 (强制 RGB 24-bit)，解决 App Store Connect 报错拦截问题

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCREENSHOT_DIR="$ROOT_DIR/HSBWatchApp/fastlane/screenshots"

echo "==> 正在标准化 HSBWatchApp 截图为 App Store 官方 6.9 寸规格 (1320 x 2868, 无 Alpha 通道)..."

python3 - <<PYEOF
import os
import glob
from PIL import Image

screenshot_dir = "$SCREENSHOT_DIR"
target_width = 1320
target_height = 2868

locales = ['zh-Hans', 'en-US']

for locale in locales:
    dir_path = os.path.join(screenshot_dir, locale)
    if not os.path.exists(dir_path):
        continue
    
    png_files = sorted(glob.glob(os.path.join(dir_path, "*.png")))
    for img_path in png_files:
        filename = os.path.basename(img_path)
        with Image.open(img_path) as im:
            orig_w, orig_h = im.size
            has_alpha = (im.mode in ('RGBA', 'LA') or (im.mode == 'P' and 'transparency' in im.info))
            
            # 转换为高保真 RGB 模式 (彻底去除 Alpha 透明通道)
            rgb_im = im.convert('RGB')
            
            # 如果分辨率不是 1320x2868，使用高质量 Lanczos 重采样
            if orig_w != target_width or orig_h != target_height:
                resized_im = rgb_im.resize((target_width, target_height), Image.Resampling.LANCZOS)
            else:
                resized_im = rgb_im
                
            resized_im.save(img_path, format='PNG', optimize=True)
            print(f"[{locale}] 成功处理 {filename}: 原尺寸 {orig_w}x{orig_h} (Alpha: {has_alpha}) -> 标准尺寸 {target_width}x{target_height} (RGB 无Alpha)")

print("==> 全部截图标准化处理完成！")
PYEOF

# 运行 sips 二次复核
echo "==> 执行 sips 系统工具复核..."
for f in "$SCREENSHOT_DIR"/zh-Hans/*.png "$SCREENSHOT_DIR"/en-US/*.png; do
  if [ -f "$f" ]; then
    dim="$(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk '/pixel/{print $2}' | tr '\n' 'x')"
    alpha="$(sips -g hasAlpha "$f" 2>/dev/null | awk '/hasAlpha/{print $2}')"
    echo "$(basename "$(dirname "$f")")/$(basename "$f"): 尺寸=${dim%x} 包含Alpha通道=${alpha}"
    if [ "$alpha" != "no" ]; then
      echo "错误: $f 仍然含有 Alpha 通道！" >&2
      exit 1
    fi
  fi
done

echo "==> 复核全部通过，截图完全符合苹果官方 App Store 上传规范！"
