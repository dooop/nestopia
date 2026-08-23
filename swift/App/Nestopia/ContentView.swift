// Copyright (C) 2026 Dominic Opitz
// SPDX-License-Identifier: GPL-2.0-or-later

import Nestopia
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var romURL: URL?
    #if !os(tvOS)
    @State private var isShowingROMPicker = false
    #endif

    var body: some View {
        #if os(tvOS)
        ContentUnavailableView(
            "No game file selected",
            systemImage: "doc",
            description: Text("File selection is not available on Apple TV.")
        )
        #else
        Group {
            if let romURL {
                Nestopia(rom: romURL)
                    .id(romURL)
            } else {
                Button("Open game file") {
                    isShowingROMPicker = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $isShowingROMPicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result else { return }
            romURL = urls.first
        }
        #endif
    }
}

#Preview {
    ContentView()
}
