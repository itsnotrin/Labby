//
//  ContentView.swift
//  Labby
//
//  Created by Ryan Wiecz on 25/07/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            ServicesView()
                .tabItem {
                    Label("Services", systemImage: "server.rack")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .tint(.primary)
    }
}

#Preview {
    ContentView()
}
