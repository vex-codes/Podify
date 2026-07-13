//
//  PodifyApp.swift
//  Podify
//
//  Created by Vedansh Kumar on 7/14/26.
//

import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

@main
struct PodifyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager()
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    var body: some Scene {
        WindowGroup {
            IPodChassisView()
                .environmentObject(themeManager)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                LibraryManager.shared.autoSync()
            }
        }
    }
}
