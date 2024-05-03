//
//  PreviewContainer.swift
//  EarthQuakeSwiftData
//
//  Created by Jens Troest on 24/4/24.
//

import Foundation
import SwiftData

@MainActor
let previewContainer: ModelContainer = {
    do {
        let container = try ModelContainer(
            for: Quake.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let modelContext = container.mainContext
        if try modelContext.fetch(FetchDescriptor<Quake>()).isEmpty {
            sampleData.forEach { container.mainContext.insert($0) }
        }
        return container
    } catch {
        fatalError("Failed to create preview container")
    }
}()

let sampleData = [
    Quake(magnitude: 1.0, place: "A place", timestamp: Date.now, code: "a")
]
