//
//  ModernPDFRemotePanel.swift
//  HSBWatchCompanion
//

import SwiftUI

public struct ModernPDFRemotePanel: View {
    public var isWideDuo: Bool = false
    
    public init(isWideDuo: Bool = false) {
        self.isWideDuo = isWideDuo
    }
    
    public var body: some View {
        ModernPDFControlView(
            isWideDuo: isWideDuo,
            onPageChange: { isNext in
                DualModeRemoteCoordinator.shared.sendDPad(
                    direction: isNext ? .right : .left,
                    action: .tap
                )
                if HSBTVOSConnectionManager.shared().isConnected {
                    HSBTVOSConnectionManager.shared().sendSimulateAction(
                        isNext ? .right : .left
                    )
                }
            },
            onJumpPage: { isFirst in
                DualModeRemoteCoordinator.shared.sendSystemKey(
                    isFirst ? .home : .menu
                )
                if HSBTVOSConnectionManager.shared().isConnected {
                    HSBTVOSConnectionManager.shared().sendSimulateAction(
                        isFirst ? .pageHome : .stop
                    )
                }
            },
            onDrawAction: { type, point, color, width in
                DualModeRemoteCoordinator.shared.nativeClient.sendTouchEvent(phase: 2, point: CGPoint(x: point.x, y: point.y))
                if HSBTVOSConnectionManager.shared().isConnected {
                    HSBTVOSConnectionManager.shared().sendPayload([
                        HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.pdfDraw.rawValue,
                        HSBRemotePayloadKeyType: type,
                        HSBRemotePayloadKeyX: Double(point.x),
                        HSBRemotePayloadKeyY: Double(point.y),
                        HSBRemotePayloadKeyColor: color,
                        HSBRemotePayloadKeyWidth: Double(width)
                    ])
                }
            },
            onClear: {
                if HSBTVOSConnectionManager.shared().isConnected {
                    HSBTVOSConnectionManager.shared().sendPayload([
                        HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.pdfDraw.rawValue,
                        HSBRemotePayloadKeyType: HSBRemoteDrawTypeClear
                    ])
                }
            },
            onUndo: {
                if HSBTVOSConnectionManager.shared().isConnected {
                    HSBTVOSConnectionManager.shared().sendPayload([
                        HSBRemotePayloadKeyAction: HSBRemoteSimulateAction.pdfDraw.rawValue,
                        HSBRemotePayloadKeyType: HSBRemoteDrawTypeUndo
                    ])
                }
            }
        )
    }
}

#if DEBUG
#Preview("PDF 远程协同主面板 · iPhone Duo") {
    DuoPreviewContainer(expandedDuo: true) {
        ModernPDFRemotePanel(isWideDuo: true)
            .padding(18)
    }
}
#endif
