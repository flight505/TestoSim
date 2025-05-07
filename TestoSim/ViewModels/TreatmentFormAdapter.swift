import Foundation
import SwiftUI
import Combine

/// Adapter class to integrate TreatmentFormView with AppDataStore
/// This serves as a bridge between the AppDataStore and TreatmentViewModel
@MainActor
class TreatmentFormAdapter: ObservableObject {
    // MARK: - Published Properties
    @Published var viewModel: TreatmentViewModel
    @Published var compoundLibrary: CompoundLibrary
    
    // MARK: - Private Properties
    private var dataStore: AppDataStore
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(dataStore: AppDataStore) {
        self.dataStore = dataStore
        self.compoundLibrary = dataStore.compoundLibrary
        
        // Initialize the TreatmentViewModel with data from AppDataStore
        self.viewModel = TreatmentViewModel()
        
        // Update the viewModel with the current treatments from dataStore
        self.viewModel.treatments = dataStore.treatments
        
        // Set up the viewModel to edit a treatment if one is set in dataStore
        if let treatmentToEdit = dataStore.treatmentToEdit {
            self.viewModel.treatmentToEdit = treatmentToEdit
        }
        
        // Set up subscriptions to keep the data in sync
        setupSubscriptions()
    }
    
    // MARK: - Methods
    
    /// Present the TreatmentFormView with a treatment to edit
    func presentWithTreatment(_ treatment: Treatment?) {
        if let treatment = treatment {
            viewModel.treatmentToEdit = treatment
            viewModel.isEditingTreatment = true
        } else {
            viewModel.treatmentToEdit = nil
            viewModel.isAddingTreatment = true
        }
    }
    
    /// Set up subscriptions to keep data in sync between AppDataStore and TreatmentViewModel
    private func setupSubscriptions() {
        // When treatments change in the viewModel, update the dataStore
        viewModel.$treatments
            .dropFirst() // Skip the initial value to avoid immediate update
            .sink { [weak self] treatments in
                guard let self = self else { return }
                
                // We need to use Task since we're in a non-async context
                Task { @MainActor in
                    // Only update if the arrays are different to avoid infinite loops
                    // Note: Treatment might need to conform to Equatable for this
                    // For now, assuming the reference comparison works
                    if self.dataStore.treatments != treatments {
                        self.dataStore.treatments = treatments
                    }
                }
            }
            .store(in: &cancellables)
        
        // When treatments change in the dataStore, update the viewModel
        dataStore.$treatments
            .dropFirst() // Skip the initial value to avoid immediate update
            .sink { [weak self] treatments in
                guard let self = self else { return }
                
                Task { @MainActor in
                    // Only update if the arrays are different to avoid infinite loops
                    // Same note about Equatable applies here
                    if self.viewModel.treatments != treatments {
                        self.viewModel.treatments = treatments
                        // Update filtered collections as well
                        self.viewModel.simpleTreatments = treatments.filter { $0.treatmentType == .simple }
                        self.viewModel.advancedTreatments = treatments.filter { $0.treatmentType == .advanced }
                    }
                }
            }
            .store(in: &cancellables)
        
        // When selected treatment changes in dataStore, update viewModel
        dataStore.$selectedTreatmentID
            .sink { [weak self] selectedID in
                guard let self = self else { return }
                
                Task { @MainActor in
                    self.viewModel.selectedTreatmentID = selectedID
                }
            }
            .store(in: &cancellables)
        
        // When treatment to edit changes in dataStore, update viewModel
        dataStore.$treatmentToEdit
            .sink { [weak self] treatment in
                guard let self = self else { return }
                
                Task { @MainActor in
                    self.viewModel.treatmentToEdit = treatment
                }
            }
            .store(in: &cancellables)
        
        // Intercept the viewModel's addTreatment to use the dataStore's method
        viewModel.addTreatmentCallback = { [weak self] treatment in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.dataStore.addTreatment(treatment)
            }
        }
        
        // Intercept the viewModel's updateTreatment to use the dataStore's method
        viewModel.updateTreatmentCallback = { [weak self] treatment in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.dataStore.updateTreatment(treatment)
            }
        }
        
        // Intercept the viewModel's deleteTreatment to use the dataStore's method
        viewModel.deleteTreatmentCallback = { [weak self] treatment in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.dataStore.deleteTreatment(with: treatment.id)
            }
        }
        
        // Intercept the viewModel's selectTreatment to use the dataStore's method
        viewModel.selectTreatmentCallback = { [weak self] id in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.dataStore.selectTreatment(id: id)
            }
        }
    }
}