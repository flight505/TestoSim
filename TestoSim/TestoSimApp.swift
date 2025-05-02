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
