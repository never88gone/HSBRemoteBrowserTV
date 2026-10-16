//
//  ConnectionGuideModalView.swift
//  HSBWatchCompanion
//

import SwiftUI

public enum ConnectionGuideType {
    case browser
    case system
}

public struct ConnectionGuideModalView: View {
    public let type: ConnectionGuideType
    @Binding public var isPresented: Bool
    public var onPrimaryAction: () -> Void
    public var onSecondaryAction: () -> Void
    
    public init(
        type: ConnectionGuideType,
        isPresented: Binding<Bool>,
        onPrimaryAction: @escaping () -> Void,
        onSecondaryAction: @escaping () -> Void
    ) {
        self.type = type
        self._isPresented = isPresented
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶部关闭与把手区
            HStack {
                Spacer()
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // 核心图标与标题
            VStack(spacing: 8) {
                Image(systemName: type == .browser ? "tv.and.mediabox" : "appletvremote.gen4.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.tanghuluBrandBlue)
                    .padding(.bottom, 4)
                
                Text(type == .browser ? "糖葫芦浏览器专属大屏控制" : " Apple TV 原生系统遥控配对")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(type == .browser ? "扫描电视专属二维码，开启网页光标微操与同传" : "支持全局控制 tvOS 桌面、音量、系统按键与各大 App")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 4)
            .padding(.bottom, 20)
            
            // 步骤内容卡片列表
            VStack(spacing: 12) {
                if type == .browser {
                    GuideStepRow(
                        stepNumber: 1,
                        title: "打开电视端【糖葫芦浏览器】",
                        detail: "使用电视遥控器在 Apple TV 桌面打开应用，进入主界面。"
                    )
                    GuideStepRow(
                        stepNumber: 2,
                        title: "调出屏幕右上角配对二维码",
                        detail: "点击电视首页右上角的【📱 手机遥控配对】按钮呈现专属二维码。"
                    )
                    GuideStepRow(
                        stepNumber: 3,
                        title: "手机对准扫码秒连",
                        detail: "点击下方【扫描电视二维码】，对准大屏即可极速建立网页光标控制通道。"
                    )
                } else {
                    GuideStepRow(
                        stepNumber: 1,
                        title: "保持同一家庭 Wi-Fi 网络",
                        detail: "确保 iPhone 与 Apple TV 连接在同一局域网 Wi-Fi 下。"
                    )
                    GuideStepRow(
                        stepNumber: 2,
                        title: "查看电视屏幕上的 4 位 PIN 码",
                        detail: "发起连接后，Apple TV 系统屏幕正中央将弹出 4 位数字安全验证码。"
                    )
                    GuideStepRow(
                        stepNumber: 3,
                        title: "手机输入 PIN 码即可永久绑定",
                        detail: "在手机弹出的输入框中输入该 PIN 码，一次配对后续永久自动免密连接。"
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            
            // 操作按钮区
            VStack(spacing: 10) {
                Button(action: onPrimaryAction) {
                    HStack {
                        Image(systemName: type == .browser ? "qrcode.viewfinder" : "link.badge.plus")
                        Text(type == .browser ? "扫描电视二维码" : "连接并等待输入 PIN 码")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.tanghuluBrandBlue)
                    .cornerRadius(14)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onSecondaryAction) {
                    Text(type == .browser ? "暂不扫码" : "我知道了")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 24, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

public struct GuideStepRow: View {
    public let stepNumber: Int
    public let title: String
    public let detail: String
    
    public init(stepNumber: Int, title: String, detail: String) {
        self.stepNumber = stepNumber
        self.title = title
        self.detail = detail
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.tanghuluBrandBlue.opacity(0.15))
                    .frame(width: 26, height: 26)
                Text("\(stepNumber)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.tanghuluBrandBlue)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
