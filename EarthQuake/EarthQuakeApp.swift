//
//  EarthQuakeApp.swift
//  EarthQuake app using swift data and batch import
//
//  Created by Jens Troest on 11/4/24.
//

import SwiftUI
import SwiftData

@main
struct EarthQuakeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Quake.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        

        do {
            let container =  try ModelContainer(for: schema, configurations: [modelConfiguration])
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
