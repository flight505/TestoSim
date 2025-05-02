//
//  TestoSimApp.swift
//  TestoSim
//
//  Created by Jesper Vang on 01/05/2025.
//

import SwiftUI

@main
struct TestoSimApp: App {
    @StateObject private var dataStore = AppDataStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
        }
    }
}
