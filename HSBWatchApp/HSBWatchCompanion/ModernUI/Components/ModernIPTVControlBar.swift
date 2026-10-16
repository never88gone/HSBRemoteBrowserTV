//
//  ModernIPTVControlBar.swift
//  HSBWatchCompanion
//

import SwiftUI
import UIKit

struct TowerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? Color.accentColor.opacity(0.3) : Color(uiColor: .tertiarySystemBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .foregroundStyle(configuration.isPressed ? Color.accentColor : Color.primary)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ModernIPTVNowPlayingCard: View {
    let isConnected: Bool
    let isPlaying: Bool
    let playbackSummary: String
    let currentName: String?
    let currentId: String?
    let currentIsFavorite: Bool
    let onFavoriteToggle: () -> Void

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isPlaying ? "play.tv.fill" : "tv")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(isConnected ? playbackSummary : "未连接电视")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(currentName ?? (isConnected ? "请从频道目录选台" : "连接电视后即可选台"))
                    .font(.headline)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                guard currentId != nil else { return }
                lightHaptic.impactOccurred()
                onFavoriteToggle()
            } label: {
                Image(systemName: currentIsFavorite ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(currentIsFavorite ? Color.pink : Color.secondary)
                    .frame(width: 44, height: 44)
            }
            .disabled(currentId == nil || !isConnected)
            .accessibilityLabel(currentIsFavorite ? "取消收藏当前频道" : "收藏当前频道")
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ModernIPTVChannelVolumeTowers: View {
    let isConnected: Bool
    let onAction: ((HSBRemoteSimulateAction) -> Void)?

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        HStack(spacing: 12) {
            controlTower(
                title: "频道 CH", upperIcon: "chevron.up", upperLabel: "频道加",
                lowerIcon: "chevron.down", lowerLabel: "频道减",
                upperAction: { onAction?(.channelUp) }, lowerAction: { onAction?(.channelDown) }
            )
            controlTower(
                title: "音量 VOL", upperIcon: "speaker.plus.fill", upperLabel: "音量加",
                lowerIcon: "speaker.minus.fill", lowerLabel: "音量减",
                upperAction: { onAction?(.volumeUp) }, lowerAction: { onAction?(.volumeDown) }
            )
        }
    }

    private func controlTower(
        title: String, upperIcon: String, upperLabel: String,
        lowerIcon: String, lowerLabel: String,
        upperAction: @escaping () -> Void, lowerAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Button {
                haptic.impactOccurred()
                upperAction()
            } label: {
                Image(systemName: upperIcon).frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(TowerButtonStyle())
            .accessibilityLabel(upperLabel)
            Button {
                haptic.impactOccurred()
                lowerAction()
            } label: {
                Image(systemName: lowerIcon).frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(TowerButtonStyle())
            .accessibilityLabel(lowerLabel)
        }
        .font(.title3.weight(.bold))
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        .disabled(!isConnected)
    }
}

struct ModernIPTVActionBar: View {
    let isConnected: Bool
    let wantsPlayback: Bool
    let onAction: ((HSBRemoteSimulateAction) -> Void)?
    let onRefresh: () -> Void

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        HStack(spacing: 8) {
            actionButton("静音", icon: "speaker.slash.fill") { onAction?(.toggleMute) }
            actionButton(wantsPlayback ? "暂停" : "播放", icon: wantsPlayback ? "pause.fill" : "play.fill") {
                onAction?(wantsPlayback ? .pause : .play)
            }
            actionButton("节目单", icon: "list.bullet.rectangle") { onAction?(.iptvEpg) }
            actionButton("电视列表", icon: "rectangle.stack") { onAction?(.iptvChannels) }
            actionButton("刷新", icon: "arrow.clockwise") {
                onAction?(.iptvRefresh)
                onRefresh()
            }
        }
        .disabled(!isConnected)
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            lightHaptic.impactOccurred()
            action()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.body)
                Text(title).font(.caption2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
