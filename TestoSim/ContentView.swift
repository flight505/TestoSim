//
//  ContentView.swift
//  TestoSim
//
//  Created by Jesper Vang on 01/05/2025.
//

import SwiftUI

struct ContentView_Updated: View {
    @EnvironmentObject var dataStore: AppDataStore
    @State private var treatmentViewModel: TreatmentViewModel?
    
    var body: some View {
        TabView {
            // Treatments tab (unified view)
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
            
            // Simple Treatments
            NavigationStack {
                TreatmentListView_Simple()
            }
            .tabItem {
                Label("Simple Treatments", systemImage: "list.bullet")
            }
            
            // Advanced Treatments - Using the view from CyclePlannerView.swift
            NavigationStack {
                Text("Advanced Treatments")
                    .font(.headline)
            }
            .tabItem {
                Label("Advanced Treatments", systemImage: "calendar")
            }
            
            // AI Insights
            NavigationStack {
                AIInsightsView()
            }
            .tabItem {
                Label("Insights", systemImage: "lightbulb")
            }
            
            // Profile
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person")
            }
        }
    }
}

extension ContentView_Updated {
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
        
        // Set up callbacks to integrate with AppDataStore
        viewModel.addTreatmentCallback = { [weak dataStore] treatment in
            dataStore?.addTreatment(treatment)
        }
        
        viewModel.updateTreatmentCallback = { [weak dataStore] treatment in
            dataStore?.updateTreatment(treatment)
        }
        
        viewModel.deleteTreatmentCallback = { [weak dataStore] treatment in
            dataStore?.deleteTreatment(with: treatment.id)
        }
        
        viewModel.selectTreatmentCallback = { [weak dataStore] id in
            dataStore?.selectTreatment(id: id)
        }
        
        // Store for future use
        self.treatmentViewModel = viewModel
        return viewModel
    }
}

// Simple view that only shows simple treatments
struct TreatmentListView_Simple: View {
    @EnvironmentObject var dataStore: AppDataStore
    @State private var isAddingTreatment = false
    @State private var isShowingDetail = false
    @State private var selectedTreatment: Treatment?
    
    var simpleTreatments: [Treatment] {
        dataStore.treatments.filter { $0.treatmentType == .simple }
    }
    
    var body: some View {
        List {
            if simpleTreatments.isEmpty {
                Text("No simple treatments yet")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(simpleTreatments) { treatment in
                    Button(action: {
                        selectedTreatment = treatment
                        isShowingDetail = true
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(treatment.name)
                                    .font(.headline)
                                
                                if let doseMg = treatment.doseMg, let frequencyDays = treatment.frequencyDays {
                                    Text("\(Int(doseMg))mg every \(frequencyDays, specifier: "%.1f") days")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
        .navigationTitle("Simple Treatments")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    isAddingTreatment = true
                }) {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingTreatment) {
            TreatmentFormView_Updated()
                .environmentObject(dataStore)
        }
        .sheet(isPresented: $isShowingDetail) {
            if let treatment = selectedTreatment {
                NavigationView {
                    TreatmentDetailView_Updated(treatment: treatment)
                        .environmentObject(dataStore)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    isShowingDetail = false
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            if index < simpleTreatments.count {
                let treatment = simpleTreatments[index]
                dataStore.deleteTreatment(with: treatment.id)
            }
        }
    }
}

#Preview {
    ContentView_Updated()
        .environmentObject(AppDataStore())
}