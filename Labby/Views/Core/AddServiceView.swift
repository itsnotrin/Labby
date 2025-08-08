//
//  AddServiceView.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import SwiftUI

struct AddServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var serviceManager = ServiceManager.shared

    @State private var displayName = ""
    @State private var selectedService: ServiceKind = .proxmox
    @State private var baseURL = ""
    @State private var insecureSkipTLS = false

    // Auth fields
    @State private var authMethod: AuthMethodType = .proxmoxToken
    @State private var username = ""
    @State private var password = ""
    @State private var apiToken = ""
    @State private var proxmoxTokenId = ""
    @State private var proxmoxTokenSecret = ""

    @State private var isTesting = false
    @State private var testResult: String?
    @State private var testError: String?
    @State private var testAttempted = false
    @State private var testPassed = false

    var body: some View {
        NavigationView {
            Form {

                Section("Service Details") {
                    TextField("Display Name", text: $displayName)
                        .textContentType(.none)
                        .autocapitalization(.words)

                    Picker("Service Type", selection: $selectedService) {
                        ForEach(ServiceKind.allCases) { service in
                            Text(service.displayName).tag(service)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedService) { newService in
                        // Auto-switch auth method based on service
                        switch newService {
                        case .proxmox:
                            authMethod = .proxmoxToken
                        case .jellyfin:
                            authMethod = .usernamePassword
                        case .qbittorrent:
                            authMethod = .usernamePassword
                        }
                        // Changing service type requires re-test
                        testAttempted = false
                        testPassed = false
                    }

                    TextField("Server URL", text: $baseURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: baseURL) { _ in
                            testAttempted = false
                            testPassed = false
                            testResult = nil
                            testError = nil
                        }

                    Toggle("Ignore SSL Certificate Errors", isOn: $insecureSkipTLS)
                        .onChange(of: insecureSkipTLS) { _ in
                            testAttempted = false
                            testPassed = false
                            testResult = nil
                            testError = nil
                        }
                }

                Section("Authentication") {
                    Picker("Auth Method", selection: $authMethod) {
                        ForEach(availableAuthMethods, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: authMethod) { _ in
                        // Changing auth method requires re-test
                        testAttempted = false
                        testPassed = false
                    }

                    switch authMethod {
                    case .usernamePassword:
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onChange(of: username) { _ in
                                testAttempted = false
                                testPassed = false
                                testResult = nil
                                testError = nil
                            }

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .onChange(of: password) { _ in
                                testAttempted = false
                                testPassed = false
                                testResult = nil
                                testError = nil
                            }

                    case .apiToken:
                        SecureField("API Token", text: $apiToken)
                            .textContentType(.none)
                            .onChange(of: apiToken) { _ in
                                testAttempted = false
                                testPassed = false
                                testResult = nil
                                testError = nil
                            }

                    case .proxmoxToken:
                        TextField("Token ID (e.g., root@pam!labby)", text: $proxmoxTokenId)
                            .textContentType(.none)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onChange(of: proxmoxTokenId) { _ in
                                testAttempted = false
                                testPassed = false
                                testResult = nil
                                testError = nil
                            }

                        SecureField("Token Secret", text: $proxmoxTokenSecret)
                            .textContentType(.none)
                            .onChange(of: proxmoxTokenSecret) { _ in
                                testAttempted = false
                                testPassed = false
                                testResult = nil
                                testError = nil
                            }
                    }
                }

                Section {
                    Button {
                        Task {
                            await testConnection()
                        }
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "network")
                            }
                            Text(
                                testAttempted
                                    ? (testPassed ? "Test Passed" : "Test Failed")
                                    : "Test Connection")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(testButtonColor)
                    .disabled(isTesting || !isValid)
                }
            }
            .navigationTitle("Add Service")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveService()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(testPassed ? .green : .gray)
                    .disabled(!isValid || !testPassed)
                    .scaleEffect(testPassed ? 1.06 : 1.0)
                    .shadow(
                        color: testPassed ? .green.opacity(0.5) : .clear, radius: testPassed ? 8 : 0
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: testPassed)
                }
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

    private var availableAuthMethods: [AuthMethodType] {
        switch selectedService {
        case .proxmox:
            return [.proxmoxToken]
        case .jellyfin:
            return [.usernamePassword, .apiToken]
        case .qbittorrent:
            return [.usernamePassword]
        }
    }

    private var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
            && !baseURL.trimmingCharacters(in: .whitespaces).isEmpty && URL(string: baseURL) != nil
            && authFieldsValid
    }

    private var authFieldsValid: Bool {
        switch authMethod {
        case .usernamePassword:
            return !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
        case .apiToken:
            return !apiToken.isEmpty
        case .proxmoxToken:
            return !proxmoxTokenId.trimmingCharacters(in: .whitespaces).isEmpty
                && !proxmoxTokenSecret.isEmpty
        }
    }

    private var testButtonColor: Color {
        if isTesting { return .gray }
        if !testAttempted { return .yellow }
        return testPassed ? .green : .red
    }

    private func saveService() {
        let config = createServiceConfig()
        serviceManager.addService(config)
        dismiss()
    }

    private func createServiceConfig() -> ServiceConfig {
        let auth: ServiceAuthConfig

        switch authMethod {
        case .usernamePassword:
            let passwordKey = "\(UUID().uuidString)_password"
            KeychainStorage.shared.saveSecret(password.data(using: .utf8)!, forKey: passwordKey)
            auth = .usernamePassword(username: username, passwordKeychainKey: passwordKey)

        case .apiToken:
            let tokenKey = "\(UUID().uuidString)_token"
            KeychainStorage.shared.saveSecret(apiToken.data(using: .utf8)!, forKey: tokenKey)
            auth = .apiToken(secretKeychainKey: tokenKey)

        case .proxmoxToken:
            let secretKey = "\(UUID().uuidString)_proxmox_secret"
            KeychainStorage.shared.saveSecret(
                proxmoxTokenSecret.data(using: .utf8)!, forKey: secretKey)
            auth = .proxmoxToken(tokenId: proxmoxTokenId, tokenSecretKeychainKey: secretKey)
        }

        let home = UserDefaults.standard.string(forKey: "selectedHome") ?? "Default Home"
        return ServiceConfig(
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            kind: selectedService,
            baseURLString: baseURL.trimmingCharacters(in: .whitespaces),
            auth: auth,
            insecureSkipTLSVerify: insecureSkipTLS,
            home: home
        )
    }

    private func testConnection() async {
        isTesting = true
        testAttempted = true
        defer { isTesting = false }

        let config = createServiceConfig()
        let client = serviceManager.client(for: config)

        do {
            let result = try await client.testConnection()
            testResult = result
            testPassed = true
        } catch {
            testError = error.localizedDescription
            testPassed = false
        }
    }
}

#Preview {
    AddServiceView()
}
