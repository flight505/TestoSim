//
//  ContentView.swift
//  TestoSim
//
//  Created by Jesper Vang on 01/05/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStore: AppDataStore
    
    var body: some View {
        TabView {
            NavigationStack {
                ProtocolListView()
            }
            .tabItem {
                Label("Protocols", systemImage: "list.bullet")
            }
            
            NavigationStack {
                CyclePlannerView()
            }
            .tabItem {
                Label("Cycles", systemImage: "calendar")
            }
            
            NavigationStack {
                AIInsightsView()
            }
            .tabItem {
                Label("Insights", systemImage: "lightbulb")
            }
            
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppDataStore())
}
