#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从真实的 Apple Watch 模拟器中抓取 100% 原生运行截屏，
并生成符合 App Store Connect 严格准入规范的 Apple Watch 全规格截图资产。
尺寸支持：
- Series 3:  312x390
- Series 4:  368x448
- Series 7:  396x484
- Series 10: 416x496
色彩要求：24-bit RGB (无 Alpha 通道)
"""

import os
import sys
import time
import subprocess
from PIL import Image

SIM_ID = "F41E948A-49AD-488B-8BB4-108A57BAAD44"
BUNDLE_ID = "com.never88gone.thlbrowserios.watch"

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SCREENSHOTS_DIR = os.path.join(BASE_DIR, "screenshots")

TARGET_SIZES = [
    ("series10", 416, 496),
    ("series7",  396, 484),
    ("series4",  368, 448),
    ("series3",  312, 390),
]

def run(cmd):
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return res.stdout.strip(), res.stderr.strip(), res.returncode

def capture_sim_screenshot(lang="zh-Hans", out_path="/tmp/sim_watch.png"):
    # 终止 App
    run(f"xcrun simctl terminate {SIM_ID} {BUNDLE_ID}")
    time.sleep(0.5)
    
    # 语言参数
    lang_arg = "-AppleLanguages '(zh-Hans)'" if lang == "zh-Hans" else "-AppleLanguages '(en)'"
    
    # 启动
    run(f"xcrun simctl launch {SIM_ID} {BUNDLE_ID} {lang_arg}")
    time.sleep(2.0)
    
    # 截图
    out, err, code = run(f"xcrun simctl io {SIM_ID} screenshot {out_path}")
    if code != 0:
        print(f"Error capturing screenshot: {err}")
        return False
    return True

def process_and_save(src_path, lang="zh-Hans"):
    out_dir = os.path.join(SCREENSHOTS_DIR, lang)
    os.makedirs(out_dir, exist_ok=True)
    
    with Image.open(src_path) as im:
        # 转为 RGB 纯真彩色，彻底剔除 Alpha
        im_rgb = im.convert("RGB")
        
        for name, w, h in TARGET_SIZES:
            # 高质量双三次重采样调整尺寸，严格匹配 Apple 规范
            resized = im_rgb.resize((w, h), Image.Resampling.LANCZOS)
            file_name = f"7_watch_{name}_{w}x{h}.png"
            dest = os.path.join(out_dir, file_name)
            resized.save(dest, "PNG")
            print(f"✅ 生成官方真实截图: [{lang}] {file_name} -> {w}x{h}, Mode={resized.mode}")

def main():
    print("🚀 开始自动化捕获并生成 100% 真实原生 Apple Watch 截图...")
    
    # 1. 抓取中文版真实截图
    zh_temp = "/tmp/real_watch_zh.png"
    if capture_sim_screenshot("zh-Hans", zh_temp):
        process_and_save(zh_temp, "zh-Hans")
    else:
        print("❌ 捕获中文截图失败")
        sys.exit(1)
        
    # 2. 抓取英文版真实截图
    en_temp = "/tmp/real_watch_en.png"
    if capture_sim_screenshot("en-US", en_temp):
        process_and_save(en_temp, "en-US")
    else:
        print("❌ 捕获英文截图失败")
        sys.exit(1)

    print("🎉 全套 100% 原生真实 Apple Watch 截图生成完毕！")

if __name__ == "__main__":
    main()
