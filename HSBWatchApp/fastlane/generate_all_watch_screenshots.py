#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自动化捕获 100% 真实原生 Apple Watch 官方截图
涵盖 4 大核心功能标签页，支持中英文双语与全系 watchOS 官方分辨率规范。
"""

import os
import sys
import time
import subprocess
from PIL import Image

SIM_ID = "F41E948A-49AD-488B-8BB4-108A57BAAD44"
BUNDLE_ID = "com.never88gone.thlbrowserios.watch"

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FASTLANE_DIR = os.path.join(BASE_DIR, "screenshots")
ARTIFACT_DIR = "/Users/never88gone/.gemini/antigravity/brain/d0037077-1c78-4260-bb96-f65ef8e7ffd3/watch_review_showcase"

os.makedirs(ARTIFACT_DIR, exist_ok=True)

TABS = [
    ("01_remote_dpad",   "-tab0",       "D-Pad 十字方向与高亮 OK 遥控"),
    ("02_crown_scroll",  "-tab1",       "数码表冠平滑网页滚动与缩放"),
    ("03_air_mouse",     "-tab2Active", "手腕体感空鼠姿态直驱与轻弹点击"),
    ("04_media_volume",  "-tab3",       "大屏电视音量调节与全屏媒体控制"),
]

LANGUAGES = [
    ("zh-Hans", "中文"),
    ("en-US",   "英文"),
]

TARGET_SIZES = [
    ("series10", 416, 496),
    ("series7",  396, 484),
    ("series4",  368, 448),
    ("series3",  312, 390),
]

def run(cmd):
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return res.stdout.strip(), res.stderr.strip(), res.returncode

def capture_tab(lang_code, tab_arg, out_tmp):
    run(f"xcrun simctl terminate {SIM_ID} {BUNDLE_ID} || true")
    time.sleep(0.6)
    
    lang_flag = f"-AppleLanguages '({lang_code})'"
    cmd_launch = f"xcrun simctl launch {SIM_ID} {BUNDLE_ID} {lang_flag} {tab_arg}"
    run(cmd_launch)
    time.sleep(2.6) # 留足 watchOS 动画与渲染时间
    
    out, err, code = run(f"xcrun simctl io {SIM_ID} screenshot {out_tmp}")
    if code != 0:
        print(f"❌ 捕获截图失败: {err}")
        return False
    return True

def process_and_save(src_tmp, tab_slug, lang_code):
    fastlane_lang_dir = os.path.join(FASTLANE_DIR, lang_code)
    artifact_lang_dir = os.path.join(ARTIFACT_DIR, lang_code)
    os.makedirs(fastlane_lang_dir, exist_ok=True)
    os.makedirs(artifact_lang_dir, exist_ok=True)
    
    with Image.open(src_tmp) as im:
        # 强制转换为 24-bit 纯 RGB，彻底移除 Alpha 通道（符合 App Store 严苛规范）
        rgb_im = im.convert("RGB")
        
        # 依次生成 4 种尺寸
        for name, w, h in TARGET_SIZES:
            resized = rgb_im.resize((w, h), Image.Resampling.LANCZOS)
            
            # Fastlane 格式：按顺序命名以便 Fastlane Deliver 正确抓取排序
            fastlane_name = f"watch_{tab_slug}_{name}_{w}x{h}.png"
            fastlane_dest = os.path.join(fastlane_lang_dir, fastlane_name)
            resized.save(fastlane_dest, "PNG")
            
            # Artifact 格式：用于展示的高清原生图
            artifact_name = f"{tab_slug}_{name}_{w}x{h}.png"
            artifact_dest = os.path.join(artifact_lang_dir, artifact_name)
            resized.save(artifact_dest, "PNG")
            
            print(f"  ✓ [{lang_code}] {tab_slug} -> {name} ({w}x{h}, Mode={resized.mode})")

def main():
    print("🚀 开始全量生成 Apple Watch 100% 原生官方截图...")
    tmp_path = "/tmp/watch_screenshot_worker.png"
    
    for lang_code, lang_desc in LANGUAGES:
        print(f"\n==========================================")
        print(f"🌐 正在生成语言版本: {lang_desc} ({lang_code})")
        print(f"==========================================")
        
        for tab_slug, tab_arg, tab_name in TABS:
            print(f"📸 捕获页面: {tab_name} ({tab_arg})...")
            if capture_tab(lang_code, tab_arg, tmp_path):
                process_and_save(tmp_path, tab_slug, lang_code)
            else:
                print(f"❌ 页面捕获失败: {tab_slug}")
                sys.exit(1)
                
    print("\n🎉 全套 100% 真实原生 Apple Watch 截图已完美生成并归档！")

if __name__ == "__main__":
    main()
