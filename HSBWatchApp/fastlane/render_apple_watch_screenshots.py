#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成符合 App Store 官方规范的 Apple Watch 伴侣应用全规格高清官方海报截图
严格使用苹果原生 PingFang SC (苹方简体) 与 SF Compact 字体，杜绝任何豆腐块/乱码！
规格支持：
- Series 3:  312x390
- Series 4:  368x448
- Series 7:  396x484
- Series 10: 416x496
"""

import os
from PIL import Image, ImageDraw, ImageFont

ROOT_DIR = "/Volumes/MacintoshData/Work/MY/Project/Product/HSBRemoteBrowserTV/HSBWatchApp/fastlane/screenshots"

SIZES = [
    ("series3", 312, 390),
    ("series4", 368, 448),
    ("series7", 396, 484),
    ("series10", 416, 496),
]

PINGFANG_TTC = "/System/Library/AssetsV2/com_apple_MobileAsset_Font8/86ba2c91f017a3749571a82f2c6d890ac7ffb2fb.asset/AssetData/PingFang.ttc"
SF_COMPACT_DIR = "/Library/Fonts"

def get_font(weight="regular", size=16, is_zh=True):
    size = max(10, int(size))
    if is_zh:
        if os.path.exists(PINGFANG_TTC):
            idx = 3  # Regular
            if weight in ["bold", "heavy", "black"]:
                idx = 11  # Semibold
            elif weight in ["medium", "semibold"]:
                idx = 7   # Medium
            try:
                return ImageFont.truetype(PINGFANG_TTC, size, index=idx)
            except Exception:
                pass
    else:
        sf_name = "SF-Compact-Display-Regular.otf"
        if weight in ["bold", "heavy"]:
            sf_name = "SF-Compact-Display-Bold.otf"
        elif weight in ["medium", "semibold"]:
            sf_name = "SF-Compact-Display-Medium.otf"
        sf_path = os.path.join(SF_COMPACT_DIR, sf_name)
        if os.path.exists(sf_path):
            try:
                return ImageFont.truetype(sf_path, size)
            except Exception:
                pass

    # 兜底苹方
    if os.path.exists(PINGFANG_TTC):
        return ImageFont.truetype(PINGFANG_TTC, size, index=3)
    return ImageFont.load_default()

def draw_watch_screen(w, h, lang="zh-Hans"):
    is_zh = (lang == "zh-Hans")
    scale = w / 368.0

    # 1. 创建纯黑 OLED 背景
    img = Image.new("RGB", (w, h), (0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 2. 顶部状态栏：时间 (左) + 电池 (右)
    time_font = get_font("medium", 16 * scale, is_zh=False)
    draw.text((int(14 * scale), int(10 * scale)), "09:41", font=time_font, fill=(255, 255, 255))

    # 右侧电量图标
    bx = w - int(38 * scale)
    by = int(14 * scale)
    bw = int(22 * scale)
    bh = int(11 * scale)
    draw.rectangle([bx, by, bx + bw, by + bh], outline=(142, 142, 147), width=1)
    draw.rectangle([bx + int(2 * scale), by + int(2 * scale), bx + bw - int(4 * scale), by + bh - int(2 * scale)], fill=(52, 199, 89))
    draw.rectangle([bx + bw, by + int(3 * scale), bx + bw + int(2 * scale), by + bh - int(3 * scale)], fill=(142, 142, 147))

    # 3. 连通指示条 (绿色微脉冲指示)
    dot_r = int(3.5 * scale)
    dot_x = int(18 * scale)
    dot_y = int(44 * scale)
    draw.ellipse([dot_x - dot_r, dot_y - dot_r, dot_x + dot_r, dot_y + dot_r], fill=(52, 199, 89))

    status_str = "已连接 iPhone & Apple TV" if is_zh else "Connected: iPhone & TV"
    status_font = get_font("medium", 13 * scale, is_zh=is_zh)
    draw.text((dot_x + int(8 * scale), dot_y - int(8 * scale)), status_str, font=status_font, fill=(52, 199, 89))

    # 4. 主功能交互卡片 (体感与多模大屏控制)
    card_x1 = int(12 * scale)
    card_y1 = int(66 * scale)
    card_x2 = w - int(12 * scale)
    card_h = int(178 * scale)
    card_y2 = card_y1 + card_h
    card_radius = int(16 * scale)
    
    # 高级深灰微弧卡片
    draw.rounded_rectangle([card_x1, card_y1, card_x2, card_y2], radius=card_radius, fill=(28, 28, 30))

    # 卡片顶部：红白图标 + 标题
    icon_cx = card_x1 + int(28 * scale)
    icon_cy = card_y1 + int(36 * scale)
    icon_r = int(16 * scale)
    draw.rounded_rectangle([icon_cx - icon_r, icon_cy - icon_r, icon_cx + icon_r, icon_cy + icon_r], radius=int(7 * scale), fill=(255, 59, 48))
    # 遥控器图标形状
    draw.ellipse([icon_cx - int(4 * scale), icon_cy - int(8 * scale), icon_cx + int(4 * scale), icon_cy], fill=(255, 255, 255))
    draw.rectangle([icon_cx - int(5 * scale), icon_cy + int(4 * scale), icon_cx + int(5 * scale), icon_cy + int(8 * scale)], fill=(255, 255, 255))

    title_font = get_font("bold", 16 * scale, is_zh=is_zh)
    sub_font = get_font("regular", 12 * scale, is_zh=is_zh)

    title_text = "糖葫芦体感协同" if is_zh else "Tanghulu Remote"
    sub_text = "手腕姿态 · 零延迟大屏直驱" if is_zh else "Wrist Gestures · Low Latency"

    draw.text((icon_cx + icon_r + int(10 * scale), card_y1 + int(18 * scale)), title_text, font=title_font, fill=(255, 255, 255))
    draw.text((icon_cx + icon_r + int(10 * scale), card_y1 + int(42 * scale)), sub_text, font=sub_font, fill=(142, 142, 147))

    # 分隔线
    sep_y = card_y1 + int(74 * scale)
    draw.line([card_x1 + int(14 * scale), sep_y, card_x2 - int(14 * scale), sep_y], fill=(44, 44, 46), width=1)

    # 左右指标项
    k1 = "体感采样" if is_zh else "Sampling"
    v1 = "60 Hz"
    k2 = "响应时延" if is_zh else "Latency"
    v2 = "< 5 ms"

    metric_lbl_font = get_font("regular", 11 * scale, is_zh=is_zh)
    metric_val_font = get_font("bold", 15 * scale, is_zh=False)

    col1_x = card_x1 + int(20 * scale)
    col2_x = int(w * 0.55)

    draw.text((col1_x, sep_y + int(12 * scale)), k1, font=metric_lbl_font, fill=(142, 142, 147))
    draw.text((col1_x, sep_y + int(32 * scale)), v1, font=metric_val_font, fill=(255, 255, 255))

    draw.text((col2_x, sep_y + int(12 * scale)), k2, font=metric_lbl_font, fill=(142, 142, 147))
    draw.text((col2_x, sep_y + int(32 * scale)), v2, font=metric_val_font, fill=(52, 199, 89))

    # 5. 品牌大红色主控制按钮 (胶囊按钮)
    btn_y1 = card_y2 + int(16 * scale)
    btn_h = int(50 * scale)
    btn_y2 = btn_y1 + btn_h
    btn_bg = (224, 36, 36)
    draw.rounded_rectangle([card_x1, btn_y1, card_x2, btn_y2], radius=int(btn_h / 2), fill=btn_bg)

    btn_font = get_font("bold", 16 * scale, is_zh=is_zh)
    btn_text = "开始体感联动" if is_zh else "Start Motion Sync"
    bbox = draw.textbbox((0, 0), btn_text, font=btn_font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text(((w - tw) / 2, btn_y1 + (btn_h - th) / 2 - int(2 * scale)), btn_text, font=btn_font, fill=(255, 255, 255))

    # 6. 底部微弱说明文字
    tip_text = "抬腕倾斜即可精准控制电视光标" if is_zh else "Tilt wrist to control TV cursor"
    tip_font = get_font("regular", 11 * scale, is_zh=is_zh)
    t_bbox = draw.textbbox((0, 0), tip_text, font=tip_font)
    t_tw = t_bbox[2] - t_bbox[0]
    if btn_y2 + int(24 * scale) < h:
        draw.text(((w - t_tw) / 2, btn_y2 + int(12 * scale)), tip_text, font=tip_font, fill=(110, 110, 115))

    return img

def main():
    for lang in ["zh-Hans", "en-US"]:
        out_dir = os.path.join(ROOT_DIR, lang)
        os.makedirs(out_dir, exist_ok=True)
        for name, w, h in SIZES:
            img = draw_watch_screen(w, h, lang)
            filename = f"7_watch_{name}_{w}x{h}.png"
            path = os.path.join(out_dir, filename)
            img.save(path, "PNG")
            print(f"Generated: {path} ({w}x{h}, RGB)")

if __name__ == "__main__":
    main()
