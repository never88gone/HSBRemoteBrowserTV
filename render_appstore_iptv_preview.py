#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
糖葫芦电视浏览器 & 遥控器 - App Store 官方 App Preview 演示视频生成引擎
业务场景：3步骤 · 通过手机智能遥控器操作电视端 IPTV 直播
规范标准：App Store 1080P 16:9 (1920x1080), 30fps, H.264 High Profile, AAC 48kHz
"""

import os
import sys
import math
import shutil
import subprocess
from multiprocessing import Pool, cpu_count
from PIL import Image, ImageDraw, ImageFont, ImageFilter

WIDTH = 1920
HEIGHT = 1080
FPS = 30
DURATION_SEC = 26
TOTAL_FRAMES = FPS * DURATION_SEC

WORK_DIR = "/tmp/iptv_appstore_render"
FRAMES_DIR = os.path.join(WORK_DIR, "frames")
os.makedirs(FRAMES_DIR, exist_ok=True)

FONT_PATH = "/System/Library/Fonts/Hiragino Sans GB.ttc"
font_title = ImageFont.truetype(FONT_PATH, 42)
font_sub = ImageFont.truetype(FONT_PATH, 24)
font_step_idx = ImageFont.truetype(FONT_PATH, 16)
font_outro_title = ImageFont.truetype(FONT_PATH, 54)
font_outro_sub = ImageFont.truetype(FONT_PATH, 28)
font_outro_tag = ImageFont.truetype(FONT_PATH, 22)

# 素材路径
BRAIN_DIR = "/Users/never88gone/.gemini/antigravity/brain/d6a7d48a-d6b7-48ae-a5fd-bd36676932be"
APP_DIR = "/Volumes/MacintoshData/Work/MY/Project/Product/HSBRemoteBrowserTV"

TV_IMG_1 = os.path.join(BRAIN_DIR, "e2e_step4_iptv_initial.png")
TV_IMG_1_READY = os.path.join(BRAIN_DIR, "e2e_step4_iptv_ch_down.png")
TV_IMG_2 = os.path.join(BRAIN_DIR, "tv_switched_to_phoenix.png")
TV_IMG_3_LIVE1 = os.path.join(BRAIN_DIR, "tv265_channel3_video_frame1.png")
TV_IMG_3_VOLUME = os.path.join(BRAIN_DIR, "tv_volume_toast.png")
TV_IMG_3_LIVE2 = os.path.join(BRAIN_DIR, "tv_zap_up_jade.png")

PHONE_IMG_1 = os.path.join(BRAIN_DIR, "screenshot_unified_iptv_verified.png")
PHONE_IMG_2 = os.path.join(BRAIN_DIR, "shot_2_iptv.png")
ICON_IMG = os.path.join(APP_DIR, "HSBWatchApp/HSBWatchCompanion/Assets.xcassets/AppIcon.appiconset/launchImage.png")

OUT_VIDEO = os.path.join(BRAIN_DIR, "appstore_iptv_3steps_preview_1080p.mp4")

# 预加载与缓存尺寸
cached_assets = {}

def get_asset(path, mode="RGBA"):
    if path not in cached_assets:
        cached_assets[path] = Image.open(path).convert(mode)
    return cached_assets[path]

def render_step_card(step_num, title, subtitle, total_steps=3):
    card_w, card_h = 760, 140
    card = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(card)
    
    # 磨砂半透明深色圆角卡片
    draw.rounded_rectangle([0, 0, card_w, card_h], radius=22, fill=(15, 18, 28, 225), outline=(255, 255, 255, 50), width=2)
    
    # 步骤胶囊徽章
    badge_w, badge_h = 115, 34
    draw.rounded_rectangle([26, 20, 26 + badge_w, 20 + badge_h], radius=11, fill=(0, 122, 255, 240))
    draw.text((38, 26), f"STEP 0{step_num}", font=font_step_idx, fill=(255, 255, 255, 255))
    
    # 主标题
    draw.text((26 + badge_w + 16, 16), title, font=font_title, fill=(255, 255, 255, 255))
    # 副标题
    draw.text((26, 70), subtitle, font=font_sub, fill=(195, 205, 225, 255))
    
    # 3段进度条
    bar_y = 118
    start_x = 26
    seg_w = 226
    for i in range(1, total_steps + 1):
        x0 = start_x + (i - 1) * (seg_w + 14)
        x1 = x0 + seg_w
        if i == step_num:
            draw.rounded_rectangle([x0, bar_y, x1, bar_y + 6], radius=3, fill=(0, 122, 255, 255))
        elif i < step_num:
            draw.rounded_rectangle([x0, bar_y, x1, bar_y + 6], radius=3, fill=(52, 199, 89, 255))
        else:
            draw.rounded_rectangle([x0, bar_y, x1, bar_y + 6], radius=3, fill=(255, 255, 255, 45))
            
    return card

def render_phone_pip(phone_img, target_h=860, touch_point=None, touch_r=0, touch_opacity=1.0):
    scale = target_h / phone_img.height
    target_w = int(phone_img.width * scale)
    phone_resized = phone_img.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    # 触控光圈波纹
    if touch_point and touch_r > 0:
        touch_layer = Image.new("RGBA", phone_resized.size, (0, 0, 0, 0))
        t_draw = ImageDraw.Draw(touch_layer)
        cx = int(touch_point[0] * scale)
        cy = int(touch_point[1] * scale)
        r = int(touch_r * scale)
        alpha_outer = int(70 * touch_opacity)
        alpha_stroke = int(220 * touch_opacity)
        alpha_inner = int(190 * touch_opacity)
        
        t_draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, alpha_outer), outline=(255, 255, 255, alpha_stroke), width=3)
        inner_r = max(4, int(r * 0.42))
        t_draw.ellipse([cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r], fill=(255, 255, 255, alpha_inner))
        phone_resized = Image.alpha_composite(phone_resized, touch_layer)

    corner_radius = 50
    mask = Image.new("L", phone_resized.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, target_w, target_h], radius=corner_radius, fill=255)
    
    phone_cropped = Image.new("RGBA", phone_resized.size, (0, 0, 0, 0))
    phone_cropped.paste(phone_resized, (0, 0), mask=mask)
    
    border_draw = ImageDraw.Draw(phone_cropped)
    border_draw.rounded_rectangle([0, 0, target_w - 1, target_h - 1], radius=corner_radius, outline=(85, 90, 105, 220), width=4)
    border_draw.rounded_rectangle([3, 3, target_w - 4, target_h - 4], radius=corner_radius - 3, outline=(25, 28, 35, 255), width=2)
    
    pad = 36
    shadow_size = (target_w + pad * 2, target_h + pad * 2)
    shadow = Image.new("RGBA", shadow_size, (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    s_draw.rounded_rectangle([pad, pad, pad + target_w, pad + target_h], radius=corner_radius, fill=(0, 0, 0, 175))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    
    final_pip = Image.new("RGBA", shadow_size, (0, 0, 0, 0))
    final_pip.paste(shadow, (0, 0), shadow)
    final_pip.paste(phone_cropped, (pad, pad), phone_cropped)
    
    return final_pip

def blend_images(img_a, img_b, alpha):
    """两张 1920x1080 图像在 alpha (0.0~1.0) 平滑混合"""
    return Image.blend(img_a, img_b, alpha)

def render_single_frame(f_idx):
    sec = f_idx / FPS
    
    # 阶段 1: 0.0s - 8.0s (Step 1)
    if sec < 8.0:
        step_num = 1
        title = "手机秒连电视 · 极速载入"
        sub = "一键连接 Apple TV，自动同步丰富 IPTV 节目源"
        
        # 背景：0~3.5s 是 TV_IMG_1, 3.5~5.0s 渐变到 TV_IMG_1_READY
        im_tv1 = get_asset(TV_IMG_1).resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
        if sec < 3.5:
            bg = im_tv1.copy()
        elif sec < 5.0:
            progress = (sec - 3.5) / 1.5
            im_tv1_ready = get_asset(TV_IMG_1_READY).resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
            bg = blend_images(im_tv1, im_tv1_ready, progress)
        else:
            bg = get_asset(TV_IMG_1_READY).resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS).copy()
            
        # 手机端：0~1.0s 右侧滑入，3.5s 触发点击“管理频道源”
        im_phone = get_asset(PHONE_IMG_1)
        touch_p = None
        touch_r = 0
        touch_op = 0.0
        if 3.2 <= sec <= 4.2:
            dt = sec - 3.2
            touch_p = (589, 1475) # 管理频道源按钮位置
            touch_r = int(20 + dt * 80)
            touch_op = max(0.0, 1.0 - dt)
            
        pip = render_phone_pip(im_phone, target_h=860, touch_point=touch_p, touch_r=touch_r, touch_opacity=touch_op)
        
        # 手机滑入动画 (0~1.0s)
        base_x = WIDTH - pip.width - 25
        base_y = HEIGHT - pip.height - 15
        if sec < 1.0:
            slide_progress = 1.0 - math.pow(1.0 - sec, 3) # ease-out cubic
            cur_x = int(WIDTH - (WIDTH - base_x) * slide_progress)
        else:
            cur_x = base_x
            
        card = render_step_card(step_num, title, sub)
        bg.paste(card, (60, 55), card)
        bg.paste(pip, (cur_x, base_y), pip)
        
    # 阶段 2: 8.0s - 16.0s (Step 2)
    elif sec < 16.0:
        step_num = 2
        title = "智能遥控选台 · 节目预览"
        sub = "虚拟遥控一键选台，即时预览节目单与回看"
        
        im_tv_ready = get_asset(TV_IMG_1_READY).resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
        im_tv_phx = get_asset(TV_IMG_2).resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
        im_tv_live1 = get_asset(TV_IMG_3_LIVE1).resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
        
        # 将节目信息卡叠加在直播背景之上，形成极具层次感的大屏切台效果
        phx_composed = im_tv_live1.copy()
        # 居中贴上节目单卡片
        phx_card = im_tv_phx.crop((550, 40, 1370, 240)) # 截取大屏居中的信息卡片
        phx_composed.paste(phx_card, (550, 40), phx_card)
        
        if sec < 10.5:
            bg = im_tv_ready.copy()
        elif sec < 12.0:
            prog = (sec - 10.5) / 1.5
            bg = blend_images(im_tv_ready, phx_composed, prog)
        else:
            bg = phx_composed.copy()
            
        im_phone = get_asset(PHONE_IMG_2)
        touch_p = None
        touch_r = 0
        touch_op = 0.0
        # 10.0s~11.0s 点击快捷频道 CCTV-5 / 换台
        if 10.0 <= sec <= 11.2:
            dt = sec - 10.0
            touch_p = (430, 1480) # 快捷频道按钮
            touch_r = int(20 + dt * 75)
            touch_op = max(0.0, 1.0 - dt * 0.9)
            
        pip = render_phone_pip(im_phone, target_h=860, touch_point=touch_p, touch_r=touch_r, touch_opacity=touch_op)
        cur_x = WIDTH - pip.width - 25
        cur_y = HEIGHT - pip.height - 15
        
        card = render_step_card(step_num, title, sub)
        bg.paste(card, (60, 55), card)
        bg.paste(pip, (cur_x, cur_y), pip)
        
    # 阶段 3: 16.0s - 23.0s (Step 3)
    elif sec < 23.0:
        step_num = 3
        title = "大屏高清秒播 · 随心掌控"
        sub = "超清画质极速播放，遥控器音量切台毫秒响应"
        
        im_tv_live1 = get_asset(TV_IMG_3_LIVE1).resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
        im_tv_vol = get_asset(TV_IMG_3_VOLUME).resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
        im_tv_live2 = get_asset(TV_IMG_3_LIVE2).resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
        
        # 背景：16~17.5s 是 live1, 17.5~20.5s 是 volume toast, 20.5~23s 是 live2 (无线新闻台切台)
        if sec < 17.5:
            bg = im_tv_live1.copy()
        elif sec < 18.2:
            prog = (sec - 17.5) / 0.7
            bg = blend_images(im_tv_live1, im_tv_vol, prog)
        elif sec < 20.2:
            bg = im_tv_vol.copy()
        elif sec < 21.0:
            prog = (sec - 20.2) / 0.8
            bg = blend_images(im_tv_vol, im_tv_live2, prog)
        else:
            bg = im_tv_live2.copy()
            
        im_phone = get_asset(PHONE_IMG_2)
        touch_p = None
        touch_r = 0
        touch_op = 0.0
        # 17.5s~18.5s 点击音量 VOL+
        if 17.5 <= sec <= 18.6:
            dt = sec - 17.5
            touch_p = (710, 750) # VOL+ 按钮
            touch_r = int(18 + dt * 80)
            touch_op = max(0.0, 1.0 - dt * 0.9)
        # 19.0s~20.0s 再次点击 VOL+
        elif 19.0 <= sec <= 20.0:
            dt = sec - 19.0
            touch_p = (710, 750)
            touch_r = int(18 + dt * 80)
            touch_op = max(0.0, 1.0 - dt * 0.9)
            
        pip = render_phone_pip(im_phone, target_h=860, touch_point=touch_p, touch_r=touch_r, touch_opacity=touch_op)
        cur_x = WIDTH - pip.width - 25
        cur_y = HEIGHT - pip.height - 15
        
        card = render_step_card(step_num, title, sub)
        bg.paste(card, (60, 55), card)
        bg.paste(pip, (cur_x, cur_y), pip)
        
    # 阶段 4: 23.0s - 26.0s (Outro 品牌定格)
    else:
        # 暗色典雅展台背景
        bg = Image.new("RGBA", (WIDTH, HEIGHT), (12, 14, 20, 255))
        draw = ImageDraw.Draw(bg)
        
        # 柔和高光圆球
        glow = Image.new("RGBA", (600, 600), (0, 0, 0, 0))
        g_draw = ImageDraw.Draw(glow)
        g_draw.ellipse([50, 50, 550, 550], fill=(0, 122, 255, 60))
        glow = glow.filter(ImageFilter.GaussianBlur(80))
        bg.paste(glow, (WIDTH // 2 - 300, HEIGHT // 2 - 360), glow)
        
        # 绘制 App 图标
        icon = get_asset(ICON_IMG).resize((220, 220), Image.Resampling.LANCZOS)
        # 圆角
        mask = Image.new("L", icon.size, 0)
        m_draw = ImageDraw.Draw(mask)
        m_draw.rounded_rectangle([0, 0, 220, 220], radius=48, fill=255)
        icon_cropped = Image.new("RGBA", icon.size, (0, 0, 0, 0))
        icon_cropped.paste(icon, (0, 0), mask=mask)
        
        # 外边框
        b_draw = ImageDraw.Draw(icon_cropped)
        b_draw.rounded_rectangle([0, 0, 219, 219], radius=48, outline=(255, 255, 255, 100), width=3)
        
        icon_x = WIDTH // 2 - 110
        icon_y = HEIGHT // 2 - 250
        bg.paste(icon_cropped, (icon_x, icon_y), icon_cropped)
        
        # 标题文字
        title_text = "糖葫芦电视浏览器 & 遥控器"
        bbox = draw.textbbox((0, 0), title_text, font=font_outro_title)
        tw = bbox[2] - bbox[0]
        draw.text(((WIDTH - tw) // 2, icon_y + 260), title_text, font=font_outro_title, fill=(255, 255, 255, 255))
        
        # 副标语
        sub_text = "极速秒连 · IPTV 超清直播 · 大屏视听终极伴侣"
        bbox = draw.textbbox((0, 0), sub_text, font=font_outro_sub)
        tw = bbox[2] - bbox[0]
        draw.text(((WIDTH - tw) // 2, icon_y + 340), sub_text, font=font_outro_sub, fill=(180, 195, 220, 255))
        
        # App Store 胶囊徽章
        badge_text = "App Store 官方正版 · 欢迎下载体验"
        bbox = draw.textbbox((0, 0), badge_text, font=font_outro_tag)
        tw = bbox[2] - bbox[0]
        bx = (WIDTH - tw) // 2 - 30
        by = icon_y + 410
        draw.rounded_rectangle([bx, by, bx + tw + 60, by + 50], radius=25, fill=(0, 122, 255, 230), outline=(255, 255, 255, 80), width=2)
        draw.text(((WIDTH - tw) // 2, by + 12), badge_text, font=font_outro_tag, fill=(255, 255, 255, 255))
        
        # 0.5s 淡入效果
        if sec < 23.6:
            fade_in = (sec - 23.0) / 0.6
            im_tv_live2 = get_asset(TV_IMG_3_LIVE2).resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
            bg = blend_images(im_tv_live2, bg, fade_in)

    frame_path = os.path.join(FRAMES_DIR, f"frame_{f_idx:05d}.png")
    bg.convert("RGB").save(frame_path, quality=95)
    return f_idx

def main():
    print(f">>> 开始并发渲染全部 {TOTAL_FRAMES} 帧视频画面 (30 fps, 26 秒)...")
    workers = min(cpu_count(), 10)
    print(f"    启用 {workers} 个并行渲染核心...")
    
    with Pool(workers) as pool:
        for done_idx in pool.imap_unordered(render_single_frame, range(TOTAL_FRAMES), chunksize=10):
            if done_idx % 60 == 0:
                percent = done_idx / TOTAL_FRAMES * 100
                print(f"    Progress: {percent:.1f}% ({done_idx}/{TOTAL_FRAMES})")
                
    print(">>> 全部 780 帧渲染完毕！正在生成高保真音频轨道与按键音效...")
    
    # 生成音频
    audio_path = os.path.join(WORK_DIR, "audio_track.m4a")
    synth_path = os.path.join(WORK_DIR, "synth_bg.m4a")
    
    # 1. 生成极简科技琶音音轨
    synth_cmd = [
        "/opt/homebrew/bin/ffmpeg", "-y", "-f", "lavfi",
        "-i", "aevalsrc=0.06*sin(2*PI*440*t)*exp(-3*mod(t\,0.5)) + 0.04*sin(2*PI*659.25*t)*exp(-2.5*mod(t+0.25\,0.5)) + 0.03*sin(2*PI*880*t)*exp(-4*mod(t+0.125\,0.25)):d=26:s=48000",
        "-c:a", "aac", synth_path
    ]
    subprocess.run(synth_cmd, check=True)
    
    # 2. 混合系统原生按键音
    filter_complex = (
        "[0:a]volume=0.9[bgm];"
        "[1:a]adelay=3500|3500,volume=1.2[pop1];"
        "[1:a]adelay=10200|10200,volume=1.2[pop2];"
        "[2:a]adelay=17600|17600,volume=1.3[tink1];"
        "[2:a]adelay=19100|19100,volume=1.3[tink2];"
        "[3:a]adelay=23200|23200,volume=0.4[hero];"
        "[bgm][pop1][pop2][tink1][tink2][hero]amix=inputs=6:duration=longest:dropout_transition=2[out]"
    )
    
    mix_cmd = [
        "/opt/homebrew/bin/ffmpeg", "-y",
        "-i", synth_path,
        "-i", "/System/Library/Sounds/Pop.aiff",
        "-i", "/System/Library/Sounds/Tink.aiff",
        "-i", "/System/Library/Sounds/Hero.aiff",
        "-filter_complex", filter_complex,
        "-map", "[out]",
        "-c:a", "aac", "-b:a", "192k",
        audio_path
    ]
    subprocess.run(mix_cmd, check=True)
    print("    音频混音完成！")
    
    # 3. 压制最终 1080P MP4 视频 (严格遵守 App Store 规范)
    print(">>> 正在使用 ffmpeg 进行 App Store 官方规范压制 (1920x1080, 30fps, H.264 High Profile, yuv420p)...")
    ffmpeg_video_cmd = [
        "/opt/homebrew/bin/ffmpeg", "-y",
        "-r", str(FPS),
        "-i", os.path.join(FRAMES_DIR, "frame_%05d.png"),
        "-i", audio_path,
        "-c:v", "libx264",
        "-profile:v", "high",
        "-level", "4.2",
        "-pix_fmt", "yuv420p",
        "-crf", "18",
        "-maxrate", "12M",
        "-bufsize", "24M",
        "-c:a", "aac",
        "-b:a", "192k",
        "-ar", "48000",
        "-shortest",
        OUT_VIDEO
    ]
    subprocess.run(ffmpeg_video_cmd, check=True)
    
    file_size_mb = os.path.getsize(OUT_VIDEO) / (1024 * 1024)
    print(f"\n=======================================================")
    print(f"🎉 App Store 官方 App Preview 演示视频生成成功！")
    print(f"路径: {OUT_VIDEO}")
    print(f"规格: 1920x1080 @ 30fps, 26秒, 大小: {file_size_mb:.2f} MB")
    print(f"=======================================================\n")

if __name__ == "__main__":
    main()
