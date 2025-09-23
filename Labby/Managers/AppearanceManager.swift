//
//  AppearanceManager.swift
//  Labby
//
//  Created by Ryan Wiecz on 27/07/2025.
//

import Combine
import SwiftUI

enum AppTheme: Int {
    case light = 0
    case dark = 1

    var colorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    @AppStorage("useSystemAppearance") var useSystemAppearance = true {
        willSet { objectWillChange.send() }
    }

    @AppStorage("selectedAppearance") var selectedAppearance = 0 {
        willSet { objectWillChange.send() }
    }

    private init() {}

    var currentColorScheme: ColorScheme? {
        guard !useSystemAppearance else { return nil }
        return AppTheme(rawValue: selectedAppearance)?.colorScheme
    }

    func toggleSystemAppearance() {
        useSystemAppearance.toggle()
    }

    func setAppearance(_ theme: AppTheme) {
        selectedAppearance = theme.rawValue
    }
}
