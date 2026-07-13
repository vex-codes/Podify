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
    
    var body: some Scene {
        WindowGroup {
            IPodChassisView()
                .environmentObject(themeManager)
        }
    }
}
