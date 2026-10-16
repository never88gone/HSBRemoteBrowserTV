//
//  MacMediaCommandDispatcher.swift
//  HSBWatchCompanion
//

import Foundation

public final class MacMediaCommandDispatcher {
    public static func dispatchCommand(_ action: String) {
        let urls = [
            "http://127.0.0.1:49888/control?action=\(action)",
            "http://localhost:49888/control?action=\(action)"
        ]
        for urlStr in urls {
            if let url = URL(string: urlStr) {
                var req = URLRequest(url: url)
                req.timeoutInterval = 0.5
                URLSession.shared.dataTask(with: req).resume()
            }
        }
    }
}
