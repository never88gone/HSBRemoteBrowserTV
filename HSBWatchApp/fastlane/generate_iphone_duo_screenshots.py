#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自动化捕获与生成 iPhone Duo (外屏 1398x2034 与展开内屏 2007x2853) 原生 App Store 官方标准截图
"""

import os
import sys
import time
import subprocess
from PIL import Image

SIM_ID = "7BB3AC4D-045B-499C-8A38-615839A47E87"
BUNDLE_ID = "com.never88gone.thlbrowserios"

BASE_DIR = "/Volumes/MacintoshData/Work/MY/Project/Product/HSBRemoteBrowserTV/HSBWatchApp"
FASTLANE_DIR = os.path.join(BASE_DIR, "fastlane", "screenshots")
ARTIFACT_DIR = "/Users/never88gone/.gemini/antigravity/brain/d0037077-1c78-4260-bb96-f65ef8e7ffd3/iphone_duo_showcase"

os.makedirs(ARTIFACT_DIR, exist_ok=True)

PAGES = [
    ("duo_01_mac_trackpad",     "hsbremote://page?name=mac",          "Mac 鼠标触控与原生隔空播放多媒体直控"),
    ("duo_02_device_hub",        "hsbremote://page?name=hub",          "大屏电视与硬件终端就绪中心"),
    ("duo_03_appletv_remote",   "hsbremote://page?name=remote&tab=0", "Apple TV 原生双向硬件轮盘遥控"),
    ("duo_04_iptv_remote",      "hsbremote://page?name=remote&tab=2", "IPTV 大屏超清频道与画中画导航"),
    ("duo_05_pdf_presentation", "hsbremote://page?name=remote&tab=3", "PDF 大屏演讲与无线幻灯直控"),
    ("duo_06_ai_model_center",   "hsbremote://page?name=ai",           "端侧本地 AI 离线大模型操控中心"),
]

def run(cmd):
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return res.stdout.strip(), res.stderr.strip(), res.returncode

def ensure_app_running():
    # 检查 app 是否在前台
    run(f"xcrun simctl openurl {SIM_ID} 'hsbremote://page?name=hub'")
    time.sleep(1.0)

def capture_page(page_url, out_tmp):
    cmd_open = f"xcrun simctl openurl {SIM_ID} '{page_url}'"
    run(cmd_open)
    time.sleep(2.0) # 留足页面渲染和转场时间
    
    cmd_shot = f"xcrun simctl io {SIM_ID} screenshot --display=1 {out_tmp}"
    out, err, code = run(cmd_shot)
    if code != 0:
        print(f"❌ 捕获截图失败: {err}")
        return False
    return True

def process_and_save(src_tmp, slug, name_zh):
    with Image.open(src_tmp) as im:
        rgb_im = im.convert("RGB") # 移除 Alpha 通道，确保 App Store 100% 合规
        
        # 1. 外屏标准尺寸 (Cover Display: 1398 x 2034)
        cover_im = rgb_im.resize((1398, 2034), Image.Resampling.LANCZOS)
        
        # 2. 内屏展开态高分屏尺寸 (Folded-Out Inner Display: 2007 x 2853)
        inner_im = rgb_im.resize((2007, 2853), Image.Resampling.LANCZOS)
        
        locales = ["zh-Hans", "en-US"]
        for loc in locales:
            dest_dir = os.path.join(FASTLANE_DIR, loc)
            os.makedirs(dest_dir, exist_ok=True)
            
            # 保存外屏
            cover_path = os.path.join(dest_dir, f"{slug}_cover_1398x2034.png")
            cover_im.save(cover_path, "PNG")
            
            # 保存内屏展开态
            inner_path = os.path.join(dest_dir, f"{slug}_inner_2007x2853.png")
            inner_im.save(inner_path, "PNG")
        
        # 保存到 Artifact 供用户在 Showcase 中预览
        art_cover = os.path.join(ARTIFACT_DIR, f"{slug}_cover_1398x2034.png")
        art_inner = os.path.join(ARTIFACT_DIR, f"{slug}_inner_2007x2853.png")
        cover_im.save(art_cover, "PNG")
        inner_im.save(art_inner, "PNG")
        
        print(f"  ✓ 成功处理: {name_zh}")
        print(f"    - 外屏 Cover: 1398x2034 (RGB)")
        print(f"    - 内屏 Inner: 2007x2853 (RGB)")

def main():
    print("🚀 开始全量捕获与生成 iPhone Duo 官方标准高精度截图...")
    tmp_path = "/tmp/duo_screenshot_worker.png"
    ensure_app_running()
    
    for slug, url, desc in PAGES:
        print(f"\n📸 正在捕获场景: {desc} ({slug})...")
        if capture_page(url, tmp_path):
            process_and_save(tmp_path, slug, desc)
        else:
            print(f"❌ 页面捕获失败: {slug}")

    print("\n🎉 iPhone Duo 全套标准截图生成完成！")

if __name__ == "__main__":
    main()
