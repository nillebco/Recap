//
//  RecapApp.swift
//  Recap
//
//  Created by Rawand Ahmad on 22/07/2025.
//

import SwiftUI
import AppKit

@main
struct RecapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // We don't need any scenes since we're using NSStatusItem
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelManager: MenuBarPanelManager?
    private var dependencyContainer: DependencyContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            dependencyContainer = DependencyContainer()
            panelManager = dependencyContainer?.createMenuBarPanelManager()
        }
    }
}
