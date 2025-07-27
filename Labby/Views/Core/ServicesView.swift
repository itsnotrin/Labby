//
//  ServicesView.swift
//  Labby
//
//  Created by Ryan Wiecz on 27/07/2025.
//

import SwiftUI

struct ServicesView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let services = [
        "Proxmox",
        "QBittorrent"
    ]

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(services, id: \.self) { service in
                        ServiceRowView(name: service)
                    }
                } header: {
                    Text("Active Services")
                } footer: {
                    Text("Connect and manage your services here")
                }

                Section {
                    Button {
                        // Add new service action
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New Service")
                        }
                    }
                }
            }
            .navigationTitle("Services")
        }
    }
}

struct ServiceRowView: View {
    let name: String

    var body: some View {
        HStack {
            serviceIcon
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                Text("Connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }

    private var serviceIcon: Image {
        switch name {
        case "Proxmox":
            return Image(systemName: "server.rack")
        case "QBittorrent":
            return Image(systemName: "arrow.down.circle")
        default:
            return Image(systemName: "questionmark.circle")
        }
    }
}

#Preview {
    ServicesView()
}
