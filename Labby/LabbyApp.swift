//
//  LabbyApp.swift
//  Labby
//
//  Created by Ryan Wiecz on 25/07/2025.
//

import SwiftUI

@main
struct LabbyApp: App {
    // Use ObservedObject for a shared singleton. The App view doesn't own the object,
    // it simply observes changes to apply the preferred color scheme.
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearanceManager.currentColorScheme)
        }
    }
}
