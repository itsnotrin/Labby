//
//  ServicesView.swift
//  Labby
//
//  Created by Ryan Wiecz on 27/07/2025.
//

import SwiftUI

struct ServicesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var serviceManager = ServiceManager.shared
    @State private var isPresentingAdd = false
    @State private var testingServiceId: UUID?
    @State private var testResult: String?
    @State private var testError: String?

    var body: some View {
        NavigationView {
            List {
                if serviceManager.services.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Spacer(minLength: 0)
                            
                            Image(systemName: "server.rack")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            
                            Text("No Services Added")
                                .font(.headline)
                            
                            Text("Add your first service to get started")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 32)
                    }
                } else {
                    Section {
                        ForEach(serviceManager.services) { config in
                            ServiceRowView(config: config) {
                                Task {
                                    await testConnection(config)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let service = serviceManager.services[index]
                                serviceManager.removeService(id: service.id)
                            }
                        }
                    } header: {
                        Text("Active Services")
                    } footer: {
                        Text("Tap a service to test connection and log info to console")
                    }
                }

                Section {
                    Button {
                        isPresentingAdd = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New Service")
                        }
                    }
                }
            }
            .navigationTitle("Services")
            .sheet(isPresented: $isPresentingAdd) {
                AddServiceView()
            }
            .alert("Test Result", isPresented: .constant(testResult != nil || testError != nil)) {
                Button("OK") {
                    testResult = nil
                    testError = nil
                }
            } message: {
                if let result = testResult {
                    Text(result)
                } else if let error = testError {
                    Text(error)
                }
            }
        }
    }

    private func testConnection(_ config: ServiceConfig) async {
        testingServiceId = config.id
        let client = serviceManager.client(for: config)
        do {
            let info = try await client.testConnection()
            print("[Service Test] \(config.displayName): \(info)")
            testResult = info
        } catch {
            print("[Service Test] \(config.displayName) error: \(error.localizedDescription)")
            testError = error.localizedDescription
        }
        testingServiceId = nil
    }
}

struct ServiceRowView: View {
    let config: ServiceConfig
    let onTest: () -> Void
    
    @State private var isTesting = false

    var body: some View {
        Button(action: {
            isTesting = true
            onTest()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTesting = false
            }
        }) {
            HStack {
                serviceIcon
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading) {
                    Text(config.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(config.kind.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isTesting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var serviceIcon: Image {
        switch config.kind {
        case .proxmox:
            return Image(systemName: "server.rack")
        case .jellyfin:
            return Image(systemName: "tv")
        }
    }
}

#Preview {
    ServicesView()
}
