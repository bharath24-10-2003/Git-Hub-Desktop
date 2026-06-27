//
//  Git_Hub_DesktopApp.swift
//  Git Hub Desktop
//
//  Created by Bharath on 25/04/26.
//

import SwiftUI

@main
struct Git_Hub_DesktopApp: App {
    @State private var coordinator = AppCoordinator()
    @AppStorage("appTheme") private var appTheme = AppTheme.system
    
    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: coordinator)
                .preferredColorScheme(appTheme.colorScheme)
        }
        
#if os(macOS)
        Settings {
            SettingsView()
        }
#endif
    }
}
