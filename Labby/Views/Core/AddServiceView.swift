//
//  AddServiceView.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import SwiftUI

struct AddServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var serviceManager = ServiceManager.shared

    private enum DefaultsKeys {
        static let selectedHome = "selectedHome"
    }

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

    // Track temporary Keychain keys created during testing (ephemeral)
    @State private var tempKeychainKeys: [String] = []

    var body: some View {
        NavigationView {
            Form {

                Section("Service Details") {
                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)

                    Picker("Service Type", selection: $selectedService) {
                        ForEach(ServiceKind.allCases) { service in
                            Text(service.displayName).tag(service)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedService) { _, newService in
                        // Auto-switch auth method based on service
                        switch newService {
                        case .proxmox:
                            authMethod = .proxmoxToken
                        case .jellyfin:
                            authMethod = .usernamePassword
                        case .qbittorrent:
                            authMethod = .usernamePassword
                        case .pihole:
                            authMethod = .usernamePassword
                        }
                        // Changing service type requires re-test
                        testAttempted = false
                        testPassed = false
                        testResult = nil
                        testError = nil
                        cleanupTempSecrets()
                    }

                    TextField("Server URL", text: $baseURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: baseURL) { _, _ in
                            testAttempted = false
                            testPassed = false
                            testResult = nil
                            testError = nil
                            cleanupTempSecrets()
                        }

                    Toggle("Ignore SSL Certificate Errors", isOn: $insecureSkipTLS)
                        .tint(.green)
                        .onChange(of: insecureSkipTLS) { _, _ in
                            testAttempted = false
                            testPassed = false
                            testResult = nil
                            testError = nil
                            cleanupTempSecrets()
                        }
                }

                Section("Authentication") {
                    Picker("Auth Method", selection: $authMethod) {
                        ForEach(availableAuthMethods, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: authMethod) { _, _ in
                        // Changing auth method requires re-test
                        testAttempted = false
                        testPassed = false
                        testResult = nil
                        testError = nil
                        cleanupTempSecrets()
                    }

                    switch authMethod {
                    case .usernamePassword:
                        if selectedService != .pihole {
                            TextField("Username", text: $username)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: username) { _, _ in
                                    testAttempted = false
                                    testPassed = false
                                    testResult = nil
                                    testError = nil
                                    cleanupTempSecrets()
                                }
                        }

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .onChange(of: password) { _, _ in
                                testAttempted = false
                                testPassed = false
                                testResult = nil
                                testError = nil
                                cleanupTempSecrets()
                            }

                    case .apiToken:
                        SecureField("API Token", text: $apiToken)
                            .textContentType(.none)
                            .onChange(of: apiToken) { _, _ in
                                testAttempted = false
                                testPassed = false
                                testResult = nil
                                testError = nil
                                cleanupTempSecrets()
                            }

                    case .proxmoxToken:
                        TextField("Token ID (e.g., root@pam!labby)", text: $proxmoxTokenId)
                            .textContentType(.none)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: proxmoxTokenId) { _, _ in
                                testAttempted = false
                                testPassed = false
                                testResult = nil
                                testError = nil
                                cleanupTempSecrets()
                            }

                        SecureField("Token Secret", text: $proxmoxTokenSecret)
                            .textContentType(.none)
                            .onChange(of: proxmoxTokenSecret) { _, _ in
                                testAttempted = false
                                testPassed = false
                                testResult = nil
                                testError = nil
                                cleanupTempSecrets()
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cleanupTempSecrets()
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
        case .pihole:
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
            if selectedService == .pihole {
                return !password.isEmpty
            } else {
                return !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
            }
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
        // After successfully saving, clean up any leftover temporary secrets
        cleanupTempSecrets()
        dismiss()
    }

    private func makeTempKey(_ suffix: String) -> String {
        let key = "labby.temp.\(suffix).\(UUID().uuidString)"
        tempKeychainKeys.append(key)
        return key
    }

    private func cleanupTempSecrets() {
        guard !tempKeychainKeys.isEmpty else { return }
        for key in tempKeychainKeys {
            KeychainStorage.shared.deleteSecret(forKey: key)
        }
        tempKeychainKeys.removeAll()
    }

    private func createServiceConfig() -> ServiceConfig {
        let auth: ServiceAuthConfig

        switch authMethod {
        case .usernamePassword:
            let passwordKey = "\(UUID().uuidString)_password"
            if let data = password.data(using: .utf8) {
                _ = KeychainStorage.shared.saveSecretStatus(data, forKey: passwordKey)
            }
            auth = .usernamePassword(username: username, passwordKeychainKey: passwordKey)

        case .apiToken:
            let tokenKey = "\(UUID().uuidString)_token"
            if let data = apiToken.data(using: .utf8) {
                _ = KeychainStorage.shared.saveSecretStatus(data, forKey: tokenKey)
            }
            auth = .apiToken(secretKeychainKey: tokenKey)

        case .proxmoxToken:
            let secretKey = "\(UUID().uuidString)_proxmox_secret"
            if let data = proxmoxTokenSecret.data(using: .utf8) {
                _ = KeychainStorage.shared.saveSecretStatus(data, forKey: secretKey)
            }
            auth = .proxmoxToken(tokenId: proxmoxTokenId, tokenSecretKeychainKey: secretKey)
        }

        let home = UserDefaults.standard.string(forKey: DefaultsKeys.selectedHome) ?? "Default Home"
        return ServiceConfig(
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            kind: selectedService,
            baseURLString: baseURL.trimmingCharacters(in: .whitespaces),
            auth: auth,
            insecureSkipTLSVerify: insecureSkipTLS,
            home: home
        )
    }

    // Build a ServiceConfig that uses temporary Keychain entries for testing only.
    private func createEphemeralTestConfig() -> ServiceConfig {
        let auth: ServiceAuthConfig

        switch authMethod {
        case .usernamePassword:
            let tempPassKey = makeTempKey("password")
            if let data = password.data(using: .utf8) {
                _ = KeychainStorage.shared.saveSecretStatus(data, forKey: tempPassKey)
            }
            auth = .usernamePassword(username: username, passwordKeychainKey: tempPassKey)

        case .apiToken:
            let tempTokenKey = makeTempKey("token")
            if let data = apiToken.data(using: .utf8) {
                _ = KeychainStorage.shared.saveSecretStatus(data, forKey: tempTokenKey)
            }
            auth = .apiToken(secretKeychainKey: tempTokenKey)

        case .proxmoxToken:
            let tempSecretKey = makeTempKey("proxmox_secret")
            if let data = proxmoxTokenSecret.data(using: .utf8) {
                _ = KeychainStorage.shared.saveSecretStatus(data, forKey: tempSecretKey)
            }
            auth = .proxmoxToken(tokenId: proxmoxTokenId, tokenSecretKeychainKey: tempSecretKey)
        }

        let home = UserDefaults.standard.string(forKey: DefaultsKeys.selectedHome) ?? "Default Home"
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

        // Ensure previous temp secrets are removed before creating new ephemeral ones
        cleanupTempSecrets()

        let config = createEphemeralTestConfig()
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
