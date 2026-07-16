import Foundation
import UIKit
import Combine
import SwiftUI

class SecurityManager: ObservableObject {
    static let shared = SecurityManager()
    
    @Published var isCompromised: Bool = false
    
    private init() {
        self.isCompromised = checkJailbreak()
    }
    
    /// Lightweight check for compromised environments (Jailbreaks)
    private func checkJailbreak() -> Bool {
        #if targetEnvironment(simulator)
        return false // Simulators are safe to run
        #else
        
        // 1. Check for common jailbreak files and paths
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/usr/bin/ssh",
            "/Library/MobileSubstrate/MobileSubstrate.dylib"
        ]
        
        for path in suspiciousPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // 2. Check if we can write outside our sandbox
        let testPath = "/private/jailbreak_test.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true // We successfully wrote outside the sandbox, which means device is jailbroken
        } catch {
            // Expected failure
        }
        
        // 3. Check for suspicious symlinks
        if let applications = try? FileManager.default.destinationOfSymbolicLink(atPath: "/Applications") {
            if applications == "/var/stash" {
                return true
            }
        }
        
        return false
        #endif
    }
}
