//
//  HSBScreenCommands.swift
//  HSBWatchCompanion
//

import Foundation
import CoreGraphics

public enum HSBScreenCommand {
    // 1. D-pad & Remote Buttons
    case button(action: String)
    
    // 2. Cursor Pan (5.5x scale)
    case pan(dx: CGFloat, dy: CGFloat)
    
    // 3. Touch / Tap (mode: 1=single, 3=two-finger, 5=force, 6=synthetic)
    case tap(mode: Int, point: CGPoint?)
    
    // 4. Scroll (3.0x scale)
    case scroll(dx: CGFloat, dy: CGFloat)
    
    // 5. Drag (began, changed, ended)
    case drag(state: DragState, dx: CGFloat, dy: CGFloat)
    
    // 6. Navigation
    case openURL(url: String)
    case pageAction(action: PageAction)
    case zoom(scale: CGFloat)
    
    // 7. JavaScript Execution
    case executeJS(script: String)
    
    // 8. Media Playback Control
    case media(action: MediaAction, value: Double?)
    
    // 9. Volume & Audio
    case volume(action: String, value: Double?)
    
    // 10. Translation & LLM
    case translationResult(requestId: String, result: String)
    case translationBlocksResult(requestId: String, map: [String: String])
    
    // Custom JSON payload
    case raw(payload: [String: Any])
    
    public func toDictionary() -> [String: Any] {
        switch self {
        case .button(let action):
            return ["action": action]
            
        case .pan(let dx, let dy):
            return [
                "action": "mac_pan",
                "dx": Double(dx * HSBRemoteConstants.cursorScale),
                "dy": Double(dy * HSBRemoteConstants.cursorScale)
            ]
            
        case .tap(let mode, let point):
            var dict: [String: Any] = [
                "action": "mac_tap",
                "mode": mode
            ]
            if let pt = point {
                dict["x"] = Double(pt.x)
                dict["y"] = Double(pt.y)
            }
            return dict
            
        case .scroll(let dx, let dy):
            return [
                "action": "mac_scroll",
                "dx": Double(dx * HSBRemoteConstants.scrollScale),
                "dy": Double(dy * HSBRemoteConstants.scrollScale)
            ]
            
        case .drag(let state, let dx, let dy):
            return [
                "action": "mac_drag",
                "state": state.stringValue,
                "dx": Double(dx),
                "dy": Double(dy)
            ]
            
        case .openURL(let url):
            return [
                "action": "open_url",
                "url": url
            ]
            
        case .pageAction(let action):
            return ["action": action.actionName]
            
        case .zoom(let scale):
            return [
                "action": "zoom",
                "scale": Double(scale)
            ]
            
        case .executeJS(let script):
            return [
                "action": "execute_js",
                "js": script
            ]
            
        case .media(let action, let value):
            var dict: [String: Any] = ["action": action.actionName]
            if let v = value {
                dict["value"] = v
            }
            return dict
            
        case .volume(let action, let value):
            var dict: [String: Any] = ["action": action]
            if let v = value {
                dict["value"] = v
            }
            return dict
            
        case .translationResult(let reqId, let result):
            return [
                "action": "translation_result",
                "requestId": reqId,
                "result": result
            ]
            
        case .translationBlocksResult(let reqId, let map):
            return [
                "action": "translation_blocks_result",
                "requestId": reqId,
                "translationMap": map
            ]
            
        case .raw(let payload):
            return payload
        }
    }
    
    public func toJSONData() -> Data? {
        let dict = toDictionary()
        return try? JSONSerialization.data(withJSONObject: dict, options: [])
    }
}
