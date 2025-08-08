//
//  AddHomeView.swift
//  Labby
//
//  Created by Ryan Wiecz on 27/07/2025.
//

import SwiftUI

struct AddHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var homes: [String]
    @Binding var selectedHome: String
    @State private var newHomeName: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Home Details")) {
                    TextField("Home Name", text: $newHomeName)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Add New Home")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNewHome()
                    }
                    .disabled(newHomeName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveNewHome() {
        let trimmedName = newHomeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        var updatedHomes = homes
        if !updatedHomes.contains(trimmedName) {
            updatedHomes.append(trimmedName)
        }

        homes = updatedHomes
        selectedHome = trimmedName
        UserDefaults.standard.set(updatedHomes, forKey: "homes")
        UserDefaults.standard.set(trimmedName, forKey: "selectedHome")
        dismiss()
    }
}

#Preview {
    AddHomeView(homes: .constant(["Default Home"]), selectedHome: .constant("Default Home"))
}
