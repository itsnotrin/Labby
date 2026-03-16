//
//  LabbyApp.swift
//  Labby
//
//  Created by Ryan Wiecz on 25/07/2025.
//

import SwiftUI

@main
struct LabbyApp: App {
    @StateObject private var appearanceManager = AppearanceManager.shared
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedSetup {
                ContentView()
                    .preferredColorScheme(appearanceManager.currentColorScheme)
            } else {
                WelcomeView()
                    .preferredColorScheme(appearanceManager.currentColorScheme)
            }
        }
    }
}
