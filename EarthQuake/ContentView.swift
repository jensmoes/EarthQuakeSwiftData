//
//  ContentView.swift
//  EarthQuakeSwiftData
//
//  Created by Jens Troest on 11/4/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Quake.timestamp, order: .reverse) private var items: [Quake]
    @Environment(\.modelContext) private var modelContext

    var provider = QuakesProvider.shared
    
    var body: some View {
        NavigationSplitView {
            // FIXME: Create a stringdict to support plurals
            Text(pluralizedTitle)
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Quake at \(item.place)")
                    } label: {
                        Text("\(String(format: "%.1f", item.magnitude)) \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    }
                }
                .onDelete(perform: deleteItems)
            }
            #if os(iOS)
            .refreshable {
                await fetchQuakes()
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        try? modelContext.delete(model: Quake.self)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                }
                ToolbarItem {
                    Button {
                        Task { await fetchQuakes() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
        .onChange(of: items) { oldValue, newValue in
            print("Changes! \(newValue.count) from \(oldValue.count)")
        }
    }
    
    private var pluralizedTitle: String {
        if items.isEmpty {
            return "No quakes"
        }
        if items.count == 1 {
            return "One quake"
        }
        return "\(items.count) quakes"
    }
    
    /// Wrapper to handle errors
    private func fetchQuakes() async {
        do {
            try await provider.fetchSummary()
        } catch {
            // Do error handling
            fatalError()
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
