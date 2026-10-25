#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成符合 App Store 官方规范的 Apple Watch 伴侣应用全规格屏幕截图
包括 Series 3 (312x390), Series 4 (368x448), Series 7 (396x484), Series 10 (416x496)
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

FONTS_DIR = "/Library/Fonts"
SYS_FONTS_DIR = "/System/Library/Fonts"

def get_font(name, size):
    candidates = [
        os.path.join(FONTS_DIR, f"{name}.otf"),
        os.path.join(FONTS_DIR, f"{name}.ttf"),
        os.path.join(SYS_FONTS_DIR, "Hiragino Sans GB.ttc"),
        os.path.join(FONTS_DIR, "Arial Unicode.ttf"),
        "/System/Library/Fonts/SFNS.ttf"
    ]
    for p in candidates:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()

def draw_watch_screen(w, h, lang="zh-Hans"):
    # 创建纯黑背景 (watchOS OLED)
    img = Image.new("RGB", (w, h), (0, 0, 0))
    draw = ImageDraw.Draw(img)

    scale = w / 368.0  # 以 368x448 (44mm) 为基准缩放

    # 1. 顶部时间与状态栏
    time_font = get_font("SF-Compact-Display-Medium", int(16 * scale))
    draw.text((int(16 * scale), int(10 * scale)), "09:41", font=time_font, fill=(255, 255, 255))

    # 电量/信号小图标 (右侧)
    battery_x = w - int(38 * scale)
    battery_y = int(14 * scale)
    draw.rectangle([battery_x, battery_y, battery_x + int(20 * scale), battery_y + int(10 * scale)], outline=(120, 120, 128), width=1)
    draw.rectangle([battery_x + int(2 * scale), battery_y + int(2 * scale), battery_x + int(15 * scale), battery_y + int(8 * scale)], fill=(52, 199, 89))
    draw.rectangle([battery_x + int(21 * scale), battery_y + int(3 * scale), battery_x + int(23 * scale), battery_y + int(7 * scale)], fill=(120, 120, 128))

    # 2. 状态标签 (连通指示)
    status_font = get_font("SF-Compact-Display-Medium", int(13 * scale))
    dot_r = int(3.5 * scale)
    dot_x = int(22 * scale)
    dot_y = int(46 * scale)
    draw.ellipse([dot_x - dot_r, dot_y - dot_r, dot_x + dot_r, dot_y + dot_r], fill=(52, 199, 89))
    
    status_text = "已连接 iPhone 与电视" if lang == "zh-Hans" else "Connected: iPhone & TV"
    draw.text((int(32 * scale), int(39 * scale)), status_text, font=status_font, fill=(52, 199, 89))

    # 3. 核心功能卡片 (大屏遥控协同)
    card_margin = int(12 * scale)
    card_y = int(68 * scale)
    card_h = int(180 * scale)
    card_radius = int(18 * scale)
    card_bg = (28, 28, 30)
    
    draw.rounded_rectangle([card_margin, card_y, w - card_margin, card_y + card_h], radius=card_radius, fill=card_bg)

    # 卡片顶部图标与标题
    # 画一个现代遥控器/手腕体感图标
    icon_cx = int(40 * scale)
    icon_cy = card_y + int(36 * scale)
    draw.rounded_rectangle([icon_cx - int(14 * scale), icon_cy - int(18 * scale), icon_cx + int(14 * scale), icon_cy + int(18 * scale)], radius=int(6 * scale), fill=(255, 59, 48))
    # 遥控器按键细节
    draw.ellipse([icon_cx - int(4 * scale), icon_cy - int(10 * scale), icon_cx + int(4 * scale), icon_cy - int(2 * scale)], fill=(255, 255, 255))
    draw.rectangle([icon_cx - int(5 * scale), icon_cy + int(4 * scale), icon_cx + int(5 * scale), icon_cy + int(8 * scale)], fill=(255, 255, 255))

    title_font = get_font("SF-Compact-Display-Bold", int(17 * scale))
    sub_font = get_font("SF-Compact-Display-Regular", int(12 * scale))

    title_text = "糖葫芦大屏协同" if lang == "zh-Hans" else "Tanghulu Remote"
    sub_text = "手腕姿态 · 零延迟同步" if lang == "zh-Hans" else "Wrist Gestures · Low Latency"

    draw.text((int(64 * scale), card_y + int(18 * scale)), title_text, font=title_font, fill=(255, 255, 255))
    draw.text((int(64 * scale), card_y + int(44 * scale)), sub_text, font=sub_font, fill=(142, 142, 147))

    # 卡片内部分隔线
    line_y = card_y + int(76 * scale)
    draw.line([card_margin + int(16 * scale), line_y, w - card_margin - int(16 * scale), line_y], fill=(44, 44, 46), width=1)

    # 传感器指标
    metric_title_font = get_font("SF-Compact-Display-Regular", int(11 * scale))
    metric_val_font = get_font("SF-Compact-Display-Bold", int(15 * scale))

    m1_lbl = "体感采样" if lang == "zh-Hans" else "Sampling"
    m1_val = "60 Hz"
    m2_lbl = "连接延迟" if lang == "zh-Hans" else "Latency"
    m2_val = "< 5 ms"

    col1_x = int(32 * scale)
    col2_x = int(w * 0.55)

    draw.text((col1_x, line_y + int(12 * scale)), m1_lbl, font=metric_title_font, fill=(142, 142, 147))
    draw.text((col1_x, line_y + int(32 * scale)), m1_val, font=metric_val_font, fill=(255, 255, 255))

    draw.text((col2_x, line_y + int(12 * scale)), m2_lbl, font=metric_title_font, fill=(142, 142, 147))
    draw.text((col2_x, line_y + int(32 * scale)), m2_val, font=metric_val_font, fill=(52, 199, 89))

    # 4. 品牌大红色主控制按钮
    btn_y = card_y + card_h + int(14 * scale)
    btn_h = int(50 * scale)
    btn_bg = (224, 36, 36)
    draw.rounded_rectangle([card_margin, btn_y, w - card_margin, btn_y + btn_h], radius=int(btn_h / 2), fill=btn_bg)

    btn_font = get_font("SF-Compact-Display-Bold", int(17 * scale))
    btn_text = "开始体感联动" if lang == "zh-Hans" else "Start Motion Sync"
    
    # 居中文字
    bbox = draw.textbbox((0, 0), btn_text, font=btn_font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text(((w - tw) / 2, btn_y + (btn_h - th) / 2 - int(2 * scale)), btn_text, font=btn_font, fill=(255, 255, 255))

    # 5. 底部微弱指示文字
    tip_font = get_font("SF-Compact-Display-Regular", int(11 * scale))
    tip_text = "转动手腕可直接控制大屏光标" if lang == "zh-Hans" else "Tilt wrist to control TV cursor"
    t_bbox = draw.textbbox((0, 0), tip_text, font=tip_font)
    t_tw = t_bbox[2] - t_bbox[0]
    if btn_y + btn_h + int(24 * scale) < h:
        draw.text(((w - t_tw) / 2, btn_y + btn_h + int(12 * scale)), tip_text, font=tip_font, fill=(99, 99, 102))

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
