// BIOSListView.swift — BIOS file list with default selection
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI
import UniformTypeIdentifiers

struct BIOSListView: View {
    @State private var bioses: [String] = []
    @State private var defaultBIOS: String = ""
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            Group {
                if bioses.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(bioses, id: \.self) { bios in
                            biosRow(bios)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("BIOS")
            .aeroScreen(.dewdrop)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showImporter = true } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { loadBIOSes() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.data, .item],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .onAppear { loadBIOSes() }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                FileImportHandler.shared.handleURL(url)
            }
            loadBIOSes()
        case .failure(let error):
            FileImportHandler.shared.lastImportMessage = "Import failed: \(error.localizedDescription)"
            FileImportHandler.shared.showImportAlert = true
        }
    }

    private func biosRow(_ bios: String) -> some View {
        Button {
            iPSX2Bridge.setDefaultBIOS(bios)
            defaultBIOS = bios
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bios)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(regionGuess(bios))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if bios == defaultBIOS {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private var emptyState: some View {
        AeroEmptyState(
            title: "No BIOS yet",
            message: "Add a PS2 BIOS you dumped from your own console to boot games.",
            buttonTitle: "Import BIOS",
            systemImage: "square.and.arrow.down",
            hint: "Or drop a .bin into On My iPhone › ELORIS-PRISM › bios",
            action: { showImporter = true }
        )
    }

    private func loadBIOSes() {
        bioses = iPSX2Bridge.availableBIOSes()
        defaultBIOS = iPSX2Bridge.defaultBIOSName()
    }

    private func regionGuess(_ name: String) -> String {
        let upper = name.uppercased()
        if upper.contains("JP") || upper.contains("JAPAN") || upper.contains("70000") || upper.contains("50000") {
            return "Japan"
        } else if upper.contains("US") || upper.contains("AMERICA") || upper.contains("30001") || upper.contains("39001") {
            return "North America"
        } else if upper.contains("EU") || upper.contains("EUROPE") || upper.contains("30004") || upper.contains("39004") {
            return "Europe"
        }
        return "Unknown Region"
    }
}
