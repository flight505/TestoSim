//
//  ContentView.swift
//  TestoSim
//
//  Created by Jesper Vang on 01/05/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @State private var treatmentViewModel: TreatmentViewModel?
    
    var body: some View {
        TabView {
            // New unified treatments tab
            NavigationStack {
                if let treatmentViewModel = createTreatmentViewModel() {
                    HStack(spacing: 0) {
                        TreatmentListView(viewModel: treatmentViewModel)
                            .frame(width: 320)
                        
                        Divider()
                        
                        if treatmentViewModel.visualizationModel != nil {
                            TreatmentVisualizationView(viewModel: treatmentViewModel)
                        } else {
                            VStack {
                                Text("Select a treatment to visualize")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                } else {
                    Text("Loading treatments...")
                }
            }
            .tabItem {
                Label("Treatments", systemImage: "syringe")
            }
            
            // Legacy tabs
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

extension ContentView {
    // Helper function to create and initialize a TreatmentViewModel
    private func createTreatmentViewModel() -> TreatmentViewModel? {
        guard treatmentViewModel == nil else {
            return treatmentViewModel
        }
        
        // Create a new viewModel using the same CoreDataManager as our AppDataStore
        let viewModel = TreatmentViewModel(
            coreDataManager: CoreDataManager.shared,
            compoundLibrary: dataStore.compoundLibrary
        )
        
        // Connect treatments in dataStore to viewModel if needed
        // This is a placeholder for a more robust integration
        
        // Store for future use
        self.treatmentViewModel = viewModel
        return viewModel
    }
}

#Preview {
    ContentView()
        .environmentObject(AppDataStore())
}
