//
//  SettingsView.swift
//  Labby
//
//  Created by Ryan Wiecz on 27/07/2025.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var appearanceManager = AppearanceManager.shared
    @AppStorage("showServiceStats") private var showServiceStats = true
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval = 30.0

    private let appearanceOptions = ["Light", "Dark"]

    @State private var isConfirmingResetEverything = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Use System Appearance", isOn: $appearanceManager.useSystemAppearance)
                        .tint(.green)

                    if !appearanceManager.useSystemAppearance {
                        Picker("Appearance", selection: $appearanceManager.selectedAppearance) {
                            ForEach(0..<appearanceOptions.count, id: \.self) { index in
                                Text(appearanceOptions[index])
                                    .tag(index)
                            }
                        }
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose between system appearance or manual light/dark mode selection")
                }

                Section {
                    Toggle(isOn: $showServiceStats) {
                        Label {
                            Text("Show Service Statistics")
                        } icon: {
                            Image(systemName: "chart.bar.fill")
                        }
                    }
                    .tint(.green)

                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text("Auto Refresh Interval")
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                        }

                        Slider(value: $autoRefreshInterval, in: 5...120, step: 5) {
                            Text("Refresh Interval")
                        } minimumValueLabel: {
                            Text("5s")
                        } maximumValueLabel: {
                            Text("120s")
                        }

                        Text("\(Int(autoRefreshInterval)) seconds")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Service Settings")
                }

                Section {
                    NavigationLink {
                        Text("Service Credentials View")
                            .navigationTitle("Service Credentials")
                    } label: {
                        Label {
                            Text("Service Credentials")
                        } icon: {
                            Image(systemName: "key.fill")
                        }
                    }

                    NavigationLink {
                        Text("About View")
                            .navigationTitle("About")
                    } label: {
                        Label {
                            Text("About Labby")
                        } icon: {
                            Image(systemName: "info.circle.fill")
                        }
                    }
                } header: {
                    Text("App Info")
                }

                Section {
                    Button(role: .destructive) {
                        // Reset settings action
                        appearanceManager.useSystemAppearance = true
                        appearanceManager.selectedAppearance = 0
                        showServiceStats = true
                        autoRefreshInterval = 30.0
                    } label: {
                        Label {
                            Text("Reset All Settings")
                        } icon: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }

                    Button(role: .destructive) {
                        isConfirmingResetEverything = true
                    } label: {
                        Label {
                            Text("Reset Everything")
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                    .confirmationDialog(
                        "Delete all homes and services?", isPresented: $isConfirmingResetEverything,
                        titleVisibility: .visible
                    ) {
                        Button("Delete Everything", role: .destructive) {
                            ServiceManager.shared.resetAllData()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(
                            "This action will permanently remove all homes and all saved services, including any stored credentials. This cannot be undone."
                        )
                    }
                } footer: {
                    Text(
                        "Reset All Settings restores settings to defaults. Reset Everything also deletes all homes and services."
                    )
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
