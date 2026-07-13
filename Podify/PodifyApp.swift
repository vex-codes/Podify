//
//  PodifyApp.swift
//  Podify
//
//  Created by Vedansh Kumar on 7/14/26.
//

import SwiftUI

@main
struct PodifyApp: App {
    @StateObject private var themeManager = ThemeManager()
    
    init() {
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    var body: some Scene {
        WindowGroup {
            IPodChassisView()
                .environmentObject(themeManager)
        }
    }
}
