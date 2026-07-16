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
    @StateObject private var securityManager = SecurityManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
    }
    
    var body: some Scene {
        WindowGroup {
            if securityManager.isCompromised {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.red)
                        Text("Security Alert")
                            .font(.title).bold()
                            .foregroundColor(.white)
                        Text("This app cannot run on a compromised or jailbroken device. Device tampering detected.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 40)
                    }
                }
            } else {
                IPodChassisView()
                    .environmentObject(themeManager)
            }
        }
    }
}
