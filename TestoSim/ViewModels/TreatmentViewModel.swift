import Foundation
import SwiftUI
import CoreData
import Combine

/// ViewModel for managing the unified Treatment model
@MainActor
class TreatmentViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // Main data collections
    @Published var treatments: [Treatment] = []
    @Published var simpleTreatments: [Treatment] = []
    @Published var advancedTreatments: [Treatment] = []
    
    // Selection and UI state
    @Published var selectedTreatmentID: UUID?
    @Published var isAddingTreatment = false
    @Published var isEditingTreatment = false
    @Published var treatmentToEdit: Treatment?
    
    // Visualization data
    @Published var visualizationModel: VisualizationModel?
    @Published var visualizationStatistics: VisualizationStatistics?
    
    // Callback functions for AppDataStore integration
    var addTreatmentCallback: ((Treatment) -> Void)?
    var updateTreatmentCallback: ((Treatment) -> Void)?
    var deleteTreatmentCallback: ((Treatment) -> Void)?
    var selectTreatmentCallback: ((UUID?) -> Void)?
    
    // Dependencies
    private let coreDataManager: CoreDataManager
    private let compoundLibrary: CompoundLibrary
    private let pkModel: PKModel
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        coreDataManager: CoreDataManager = CoreDataManager.shared,
        compoundLibrary: CompoundLibrary = CompoundLibrary(),
        pkModel: PKModel = PKModel(useTwoCompartmentModel: true)
    ) {
        self.coreDataManager = coreDataManager
        self.compoundLibrary = compoundLibrary
        self.pkModel = pkModel
        
        // Load initial data
        loadTreatments()
        
        // Set up initial selection
        if !treatments.isEmpty, selectedTreatmentID == nil {
            selectedTreatmentID = treatments.first?.id
        }
    }
    
    // MARK: - Data Loading Methods
    
    /// Load all treatments from Core Data
    func loadTreatments() {
        // First attempt to load from the unified treatment model
        let unifiedTreatments = loadUnifiedTreatments()
        
        if !unifiedTreatments.isEmpty {
            // If we have unified treatments, use them
            treatments = unifiedTreatments
        } else {
            // Otherwise, try to load legacy protocols and cycles and convert them
            treatments = loadLegacyTreatments()
        }
        
        // Filter by type for convenience
        simpleTreatments = treatments.filter { $0.treatmentType == .simple }
        advancedTreatments = treatments.filter { $0.treatmentType == .advanced }
        
        // Recalculate visualization if we have a selected treatment
        if let selectedID = selectedTreatmentID,
           let selectedTreatment = treatments.first(where: { $0.id == selectedID }) {
            generateVisualization(for: selectedTreatment)
        }
    }
    
    /// Load treatments from the unified CDTreatment entity
    private func loadUnifiedTreatments() -> [Treatment] {
        let context = coreDataManager.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<CDTreatment>(entityName: "CDTreatment")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        do {
            let cdTreatments = try context.fetch(fetchRequest)
            return cdTreatments.compactMap { Treatment(from: $0) }
        } catch {
            print("Error loading unified treatments: \(error)")
            return []
        }
    }
    
    /// Load and convert legacy protocols and cycles
    private func loadLegacyTreatments() -> [Treatment] {
        var result: [Treatment] = []
        
        // Load protocols
        let protocols = loadLegacyProtocols()
        result.append(contentsOf: protocols.map { Treatment(from: $0) })
        
        // Load cycles
        let cycles = loadLegacyCycles()
        result.append(contentsOf: cycles.map { Treatment(from: $0) })
        
        return result
    }
    
    /// Load legacy protocols from Core Data
    private func loadLegacyProtocols() -> [InjectionProtocol] {
        let context = coreDataManager.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<CDInjectionProtocol> = CDInjectionProtocol.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        do {
            let cdProtocols = try context.fetch(fetchRequest)
            return cdProtocols.compactMap { InjectionProtocol(from: $0) }
        } catch {
            print("Error loading legacy protocols: \(error)")
            return []
        }
    }
    
    /// Load legacy cycles from Core Data
    private func loadLegacyCycles() -> [Cycle] {
        let context = coreDataManager.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<CDCycle> = CDCycle.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        do {
            let cdCycles = try context.fetch(fetchRequest)
            return cdCycles.map { Cycle(from: $0, context: context) }
        } catch {
            print("Error loading legacy cycles: \(error)")
            return []
        }
    }
    
    // MARK: - Treatment CRUD Operations
    
    /// Add a new treatment
    func addTreatment(_ treatment: Treatment) {
        // If callback is set, use it (AppDataStore integration)
        if let callback = addTreatmentCallback {
            callback(treatment)
            return
        }
        
        // Default implementation when not using AppDataStore
        // Add to the local array
        treatments.append(treatment)
        
        // Update filtered arrays
        if treatment.treatmentType == .simple {
            simpleTreatments.append(treatment)
        } else {
            advancedTreatments.append(treatment)
        }
        
        // Save to Core Data
        saveTreatment(treatment)
        
        // Select the new treatment
        selectedTreatmentID = treatment.id
        
        // Update visualization
        generateVisualization(for: treatment)
    }
    
    /// Update an existing treatment
    func updateTreatment(_ treatment: Treatment) {
        // If callback is set, use it (AppDataStore integration)
        if let callback = updateTreatmentCallback {
            callback(treatment)
            return
        }
        
        // Default implementation when not using AppDataStore
        // Update in the local array
        if let index = treatments.firstIndex(where: { $0.id == treatment.id }) {
            treatments[index] = treatment
        }
        
        // Update in the filtered arrays
        if treatment.treatmentType == .simple {
            if let index = simpleTreatments.firstIndex(where: { $0.id == treatment.id }) {
                simpleTreatments[index] = treatment
            } else {
                // If not in simple treatments, it was an advanced that changed to simple
                simpleTreatments.append(treatment)
                advancedTreatments.removeAll { $0.id == treatment.id }
            }
        } else {
            if let index = advancedTreatments.firstIndex(where: { $0.id == treatment.id }) {
                advancedTreatments[index] = treatment
            } else {
                // If not in advanced treatments, it was a simple that changed to advanced
                advancedTreatments.append(treatment)
                simpleTreatments.removeAll { $0.id == treatment.id }
            }
        }
        
        // Save to Core Data
        saveTreatment(treatment)
        
        // Update visualization if this is the selected treatment
        if treatment.id == selectedTreatmentID {
            generateVisualization(for: treatment)
        }
    }
    
    /// Delete a treatment
    func deleteTreatment(_ treatment: Treatment) {
        // If callback is set, use it (AppDataStore integration)
        if let callback = deleteTreatmentCallback {
            callback(treatment)
            return
        }
        
        // Default implementation when not using AppDataStore
        // Remove from the local arrays
        treatments.removeAll { $0.id == treatment.id }
        simpleTreatments.removeAll { $0.id == treatment.id }
        advancedTreatments.removeAll { $0.id == treatment.id }
        
        // Delete from Core Data
        let context = coreDataManager.persistentContainer.viewContext
        let fetchRequest = CDTreatment.fetchRequestWithID(treatment.id)
        
        do {
            if let cdTreatment = try context.fetch(fetchRequest).first {
                context.delete(cdTreatment)
                try context.save()
            }
        } catch {
            print("Error deleting treatment: \(error)")
        }
        
        // If this was the selected treatment, select another one or clear visualization
        if treatment.id == selectedTreatmentID {
            if let firstTreatment = treatments.first {
                selectedTreatmentID = firstTreatment.id
                generateVisualization(for: firstTreatment)
            } else {
                selectedTreatmentID = nil
                visualizationModel = nil
                visualizationStatistics = nil
            }
        }
    }
    
    /// Save a treatment to Core Data
    private func saveTreatment(_ treatment: Treatment) {
        let context = coreDataManager.persistentContainer.viewContext
        _ = treatment.saveToCD(context: context)
        
        do {
            try context.save()
        } catch {
            print("Error saving treatment: \(error)")
        }
    }
    
    // MARK: - Treatment Selection and Visualization
    
    /// Select a treatment and generate its visualization
    func selectTreatment(id: UUID?) {
        // If callback is set, use it (AppDataStore integration)
        if let callback = selectTreatmentCallback {
            callback(id)
            return
        }
        
        // Default implementation when not using AppDataStore
        guard let id = id else {
            selectedTreatmentID = nil
            visualizationModel = nil
            visualizationStatistics = nil
            return
        }
        
        selectedTreatmentID = id
        
        if let treatment = treatments.first(where: { $0.id == id }) {
            generateVisualization(for: treatment)
        } else {
            visualizationModel = nil
            visualizationStatistics = nil
        }
    }
    
    /// Generate visualization for a treatment
    func generateVisualization(for treatment: Treatment, userWeight: Double = 70.0, calibrationFactor: Double = 1.0) {
        let visualizationFactory = VisualizationFactory(
            compoundLibrary: compoundLibrary,
            pkModel: pkModel
        )
        
        let model = visualizationFactory.createVisualization(
            for: treatment,
            weight: userWeight,
            calibrationFactor: calibrationFactor,
            unit: "ng/dL" // Default unit, could be configurable
        )
        
        visualizationModel = model
        visualizationStatistics = model.calculateStatistics()
    }
    
    /// Update layer visibility in visualization
    func updateLayerVisibility(layerID: UUID, isVisible: Bool) {
        guard var model = visualizationModel else { return }
        model.updateLayerVisibility(id: layerID, isVisible: isVisible)
        visualizationModel = model
    }
    
    /// Update layer opacity in visualization
    func updateLayerOpacity(layerID: UUID, opacity: Double) {
        guard var model = visualizationModel else { return }
        model.updateLayerOpacity(id: layerID, opacity: opacity)
        visualizationModel = model
    }
    
    /// Move a layer up in the visualization order (rendered on top)
    func moveLayerUp(layerID: UUID) {
        guard var model = visualizationModel else { return }
        model.moveLayerUp(id: layerID)
        visualizationModel = model
    }
    
    /// Move a layer down in the visualization order (rendered below)
    func moveLayerDown(layerID: UUID) {
        guard var model = visualizationModel else { return }
        model.moveLayerDown(id: layerID)
        visualizationModel = model
    }
    
    // MARK: - Conversion Methods
    
    /// Convert a legacy protocol to the unified treatment model
    func convertProtocolToTreatment(_ protocol_: InjectionProtocol) -> Treatment {
        return Treatment(from: protocol_)
    }
    
    /// Convert a legacy cycle to the unified treatment model
    func convertCycleToTreatment(_ cycle: Cycle) -> Treatment {
        return Treatment(from: cycle)
    }
    
    /// Convert a unified treatment back to a legacy protocol (if simple type)
    func convertTreatmentToProtocol(_ treatment: Treatment) -> InjectionProtocol? {
        return treatment.toLegacyProtocol()
    }
    
    /// Convert a unified treatment back to a legacy cycle (if advanced type)
    func convertTreatmentToCycle(_ treatment: Treatment) -> Cycle? {
        return treatment.toLegacyCycle()
    }
    
    // MARK: - Migration Helpers
    
    /// Migrate all legacy protocols and cycles to the unified treatment model
    func migrateAllToUnifiedModel() {
        // Load all legacy protocols and cycles
        let protocols = loadLegacyProtocols()
        let cycles = loadLegacyCycles()
        
        // Convert to unified treatments
        let simpleTreatments = protocols.map { Treatment(from: $0) }
        let advancedTreatments = cycles.map { Treatment(from: $0) }
        
        // Save all to Core Data
        let context = coreDataManager.persistentContainer.viewContext
        
        for treatment in simpleTreatments + advancedTreatments {
            _ = treatment.saveToCD(context: context)
        }
        
        do {
            try context.save()
            print("Successfully migrated \(simpleTreatments.count) protocols and \(advancedTreatments.count) cycles to unified treatment model")
        } catch {
            print("Error during migration: \(error)")
        }
        
        // Reload treatments
        loadTreatments()
    }
}