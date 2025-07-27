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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearanceManager.currentColorScheme)
        }
    }
}
