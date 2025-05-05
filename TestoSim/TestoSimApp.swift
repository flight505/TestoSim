//
//  TestoSimApp.swift
//  TestoSim
//
//  Created by Jesper Vang on 01/05/2025.
//

import SwiftUI
import CoreData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@main
struct TestoSimApp: App {
    @StateObject private var dataStore = AppDataStore()
    
    // Create a reference to the Core Data manager
    private let coreDataManager = CoreDataManager.shared
    
    init() {
        print("TestoSim is starting up...")
        
        // Set up default API key settings if not already set
        if UserDefaults.standard.object(forKey: "use_test_api_key") == nil {
            // Enable test API key by default for all users
            UserDefaults.standard.set(true, forKey: "use_test_api_key")
            print("Default API key settings initialized: Using test key")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environment(\.managedObjectContext, coreDataManager.persistentContainer.viewContext)
                #if os(iOS)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // Save when app moves to background
                    coreDataManager.saveContext()
                }
                #elseif os(macOS)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
                    // Save when app moves to background
                    coreDataManager.saveContext()
                }
                #endif
        }
    }
}
