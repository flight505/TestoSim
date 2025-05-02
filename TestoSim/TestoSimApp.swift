//
//  TestoSimApp.swift
//  TestoSim
//
//  Created by Jesper Vang on 01/05/2025.
//

import SwiftUI
import CoreData
import CloudKit

@main
struct TestoSimApp: App {
    @StateObject private var dataStore = AppDataStore()
    
    // Create a reference to the Core Data manager
    private let coreDataManager = CoreDataManager.shared
    
    init() {
        // Prepare CloudKit setup through entitlements
        if let identifier = Bundle.main.infoDictionary?["com.apple.developer.icloud-container-identifiers"] as? [String],
           !identifier.isEmpty {
            print("CloudKit container identifier: \(identifier)")
        } else {
            print("CloudKit container identifier not found in entitlements")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environment(\.managedObjectContext, coreDataManager.persistentContainer.viewContext)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // Save when app moves to background
                    coreDataManager.saveContext()
                }
        }
    }
}
