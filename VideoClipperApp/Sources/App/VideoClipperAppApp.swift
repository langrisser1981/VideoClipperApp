//
//  VideoClipperAppApp.swift
//  VideoClipperApp
//
//  Created by Lenny Cheng on 2026/8/20.
//

import SwiftUI

extension Notification.Name {
    static let videoClipperOpenFile = Notification.Name("videoClipperOpenFile")
    static let videoClipperExportVideo = Notification.Name("videoClipperExportVideo")
}

@main
struct VideoClipperAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Video…") {
                    NotificationCenter.default.post(name: .videoClipperOpenFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Export…") {
                    NotificationCenter.default.post(name: .videoClipperExportVideo, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
            }
        }
    }
}
