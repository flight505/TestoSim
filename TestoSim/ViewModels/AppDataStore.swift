import Foundation
import SwiftUI
import CoreData
import Combine

@MainActor
class AppDataStore: ObservableObject {
    // MARK: - Published Properties
    @Published var profile: UserProfile
    @Published var simulationData: [DataPoint] = []
    
    // Legacy properties - kept for temporary backward compatibility
    // These should be removed in future versions once all views are migrated
    @Published var selectedProtocolID: UUID?
    @Published var isPresentingProtocolForm = false
    @Published var protocolToEdit: InjectionProtocol?
    
    // Core property - compound library for all treatments
    @Published var compoundLibrary = CompoundLibrary()
    
    // Unified treatment model - main source of truth
    @Published var treatments: [Treatment] = []
    @Published var selectedTreatmentID: UUID?
    @Published var isPresentingTreatmentForm = false
    @Published var treatmentToEdit: Treatment?
    @Published var treatmentSimulationData: [DataPoint] = []
    
    // Treatment form adapter for integrating TreatmentFormView
    private(set) lazy var treatmentFormAdapter = TreatmentFormAdapter(dataStore: self)
    
    // MARK: - Private Properties
    private static let coreDataManager = CoreDataManager.shared
    private let coreDataManager = CoreDataManager.shared
    private let notificationManager = NotificationManager.shared
    private let pkModel = PKModel(useTwoCompartmentModel: true)
    
    // View model for unified treatment management
    private lazy var treatmentViewModel: TreatmentViewModel = {
        let viewModel = TreatmentViewModel(
            coreDataManager: coreDataManager,
            compoundLibrary: compoundLibrary,
            pkModel: pkModel
        )
        
        // Set callbacks to integrate with this AppDataStore
        viewModel.addTreatmentCallback = { [weak self] treatment in
            guard let self = self else { return }
            self.addTreatment(treatment)
        }
        
        viewModel.updateTreatmentCallback = { [weak self] treatment in
            guard let self = self else { return }
            self.updateTreatment(treatment)
        }
        
        viewModel.deleteTreatmentCallback = { [weak self] treatment in
            guard let self = self else { return }
            self.deleteTreatment(with: treatment.id)
        }
        
        viewModel.selectTreatmentCallback = { [weak self] id in
            guard let self = self else { return }
            self.selectTreatment(id: id)
        }
        
        return viewModel
    }()
    
    // MARK: - Constants
    let simulationDurationDays: Double = 90.0 // Default simulation length
    
    // MARK: - Initialization
    init() {
        // Initialize profile with a default empty profile first
        self.profile = UserProfile()
        
        // Check migration status and load data accordingly
        if UserDefaults.standard.bool(forKey: "migrated") {
            // Load profile from Core Data
            if let loadedProfile = AppDataStore.loadProfileFromCoreData() {
                self.profile = loadedProfile
            } else {
                // If loading fails after migration, create default and save
                self.profile = AppDataStore.createDefaultProfile()
                let context = coreDataManager.persistentContainer.viewContext
                _ = self.profile.saveToCD(context: context)
                do {
                    try context.save()
                } catch {
                    print("Error saving default profile to Core Data after failed load: \(error)")
                }
            }
        } else {
            // Not migrated yet, try loading from UserDefaults (old method)
            if let savedData = UserDefaults.standard.data(forKey: "userProfileData"),
               let decodedProfile = try? JSONDecoder().decode(UserProfile.self, from: savedData) {
                self.profile = decodedProfile
                // Trigger migration to Core Data
                coreDataManager.migrateUserProfileFromJSON() // This saves the migrated data
                UserDefaults.standard.set(true, forKey: "migrated") // Mark as migrated
                print("Successfully migrated profile from UserDefaults to Core Data.")
            } else {
                // No old data and not migrated: Create default profile and save to Core Data
                self.profile = AppDataStore.createDefaultProfile()
                let context = coreDataManager.persistentContainer.viewContext
                _ = self.profile.saveToCD(context: context)
                do {
                    try context.save()
                } catch {
                    print("Error saving initial default profile to Core Data: \(error)")
                }
                UserDefaults.standard.set(true, forKey: "migrated") // Mark as migrated even if creating default
            }
        }
        
        // Set initial selected protocol if any exist (for legacy UI)
        if !profile.protocols.isEmpty {
            // Ensure the selected protocol ID actually exists in the loaded profile
            if let firstValidProtocolID = profile.protocols.first?.id {
                selectedProtocolID = firstValidProtocolID
            }
        } else {
            selectedProtocolID = nil // Explicitly nil if no protocols
        }
        
        // Load unified treatments from Core Data
        loadTreatmentsFromCoreData()
        
        // If there are protocols but no treatments, create treatments from protocols
        if !profile.protocols.isEmpty && treatments.isEmpty {
            createTreatmentsFromProtocols()
            // Reload treatments after creating them
            loadTreatmentsFromCoreData()
        }
        
        // Set initial selected treatment if any exist
        if !treatments.isEmpty && selectedTreatmentID == nil {
            // Prefer to select the same treatment as the protocol, if possible
            if let selectedID = selectedProtocolID,
               treatments.contains(where: { $0.id == selectedID }) {
                selectedTreatmentID = selectedID
                simulateTreatment(id: selectedID)
            } else {
                // Otherwise select the first treatment
                selectedTreatmentID = treatments.first?.id
                if let firstID = selectedTreatmentID {
                    simulateTreatment(id: firstID)
                }
            }
        }
        
        // Generate initial simulation data for the selected protocol (if any)
        recalcSimulation() // This will handle the case where selectedProtocolID is nil
        
        // Schedule notifications for all protocols if enabled
        if notificationManager.notificationsEnabled {
            Task {
                await scheduleAllNotifications()
            }
        }
    }
    
    // MARK: - Core Data Loading/Saving
    private static func loadProfileFromCoreData() -> UserProfile? {
        let context = coreDataManager.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<CDUserProfile> = CDUserProfile.fetchRequest()
        do {
            let results = try context.fetch(fetchRequest)
            if let cdProfile = results.first {
                print("Profile loaded successfully from Core Data.")
                return UserProfile(from: cdProfile)
            } else {
                print("No profile found in Core Data.")
            }
        } catch {
            print("Error fetching profile from Core Data: \(error)")
        }
        return nil
    }
    
    func saveProfile() {
        // Always save to Core Data now
        let context = coreDataManager.persistentContainer.viewContext
        _ = profile.saveToCD(context: context) // This handles create/update
        print("Profile prepared for saving to Core Data.")
    }
    
    // MARK: - Default Profile Creation
    private static func createDefaultProfile() -> UserProfile {
        print("Creating default profile.")
        var profile = UserProfile()
        // Set up a complete test profile with realistic user data
        profile.name = "Test User"
        profile.unit = "ng/dL"
        profile.calibrationFactor = 1.0
        profile.dateOfBirth = Calendar.current.date(byAdding: .year, value: -35, to: Date())!
        profile.heightCm = 175.0 // cm
        profile.weight = 85.0 // kg
        profile.biologicalSex = .male
        profile.usesICloudSync = false
        
        return profile
    }
    
    // Create unified model treatments from legacy protocols
    private func createTreatmentsFromProtocols() {
        for protocol_ in profile.protocols {
            let treatment = Treatment(from: protocol_)
            saveTreatment(treatment)
        }
        print("Created unified treatments from \(profile.protocols.count) legacy protocols")
    }
    
    // MARK: - Treatment Management
    
    /// Add a new treatment
    func addTreatment(_ treatment: Treatment) {
        // Save to Core Data
        saveTreatment(treatment)
        
        // Select the newly added treatment
        selectedTreatmentID = treatment.id
        simulateTreatment(id: treatment.id)
        
        // Schedule notifications if it's a simple treatment
        if treatment.treatmentType == .simple, 
           notificationManager.notificationsEnabled {
            notificationManager.scheduleNotifications(for: treatment, using: compoundLibrary)
        }
        
        print("Added treatment: \(treatment.name)")
    }
    
    /// Update an existing treatment
    func updateTreatment(_ treatment: Treatment) {
        // Save to Core Data
        saveTreatment(treatment)
        
        // Update visualization if this is the selected treatment
        if treatment.id == selectedTreatmentID {
            simulateTreatment(id: treatment.id)
        }
        
        // Update notifications if it's a simple treatment
        if treatment.treatmentType == .simple, 
           notificationManager.notificationsEnabled {
            notificationManager.scheduleNotifications(for: treatment, using: compoundLibrary)
        }
        
        print("Updated treatment: \(treatment.name)")
    }
    
    /// Delete a treatment
    func deleteTreatment(with id: UUID) {
        let context = coreDataManager.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<CDTreatment>(entityName: "CDTreatment")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let cdTreatment = try context.fetch(fetchRequest).first {
                let treatmentName = cdTreatment.name ?? "Unknown"
                context.delete(cdTreatment)
                try context.save()
            }
        } catch {
            print("Error deleting treatment: \(error)")
        }
        
        // Reload treatments from Core Data
        loadTreatmentsFromCoreData()
        
        // If this was the selected treatment, deselect it
        if selectedTreatmentID == id {
            selectedTreatmentID = nil
            // Clear visualization data
            simulationData = []
            treatmentSimulationData = []
        }
    }
    
    /// Load treatments from Core Data
    func loadTreatmentsFromCoreData() {
        let context = coreDataManager.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<CDTreatment>(entityName: "CDTreatment")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        do {
            let cdTreatments = try context.fetch(fetchRequest)
            let loadedTreatments = cdTreatments.compactMap { Treatment(from: $0) }
            self.treatments = loadedTreatments
            
            print("Loaded \(self.treatments.count) treatments from Core Data.")
        } catch {
            print("Error fetching treatments from CoreData: \(error)")
        }
    }
    
    /// Save a treatment to Core Data
    func saveTreatment(_ treatment: Treatment) {
        let context = coreDataManager.persistentContainer.viewContext
        
        // Save treatment to Core Data
        let cdTreatment = treatment.saveToCD(context: context)
        
        // Associate with user profile if not already
        if cdTreatment.userProfile == nil {
            // Fetch user profile
            let fetchRequest: NSFetchRequest<CDUserProfile> = CDUserProfile.fetchRequest()
            do {
                if let userProfile = try context.fetch(fetchRequest).first {
                    cdTreatment.userProfile = userProfile
                    userProfile.addToTreatments(cdTreatment)
                }
            } catch {
                print("Error fetching user profile: \(error)")
            }
        }
        
        do {
            try context.save()
            // Refresh treatments from Core Data
            loadTreatmentsFromCoreData()
        } catch {
            print("Error saving treatment \(treatment.name): \(error)")
        }
    }
    
    // MARK: - Treatment Selection and Visualization
    
    /// Selects a treatment by ID and simulates it
    func selectTreatment(id: UUID?) {
        guard let id = id else {
            selectedTreatmentID = nil
            treatmentSimulationData = []
            print("Treatment deselected.")
            return
        }
        
        // Verify the treatment exists
        guard treatments.contains(where: { $0.id == id }) else {
            print("Error: Attempted to select non-existent treatment ID: \(id)")
            // Optionally select the first available treatment if selection is invalid
            if let firstID = treatments.first?.id {
                selectedTreatmentID = firstID
                simulateTreatment(id: firstID)
            } else {
                selectedTreatmentID = nil
                treatmentSimulationData = []
            }
            return
        }
        
        // Update selected ID
        selectedTreatmentID = id
        
        // Update visualization
        simulateTreatment(id: id)
        
        print("Selected treatment: \(treatments.first { $0.id == id }?.name ?? "Unknown")")
    }
    
    /// Simulates a treatment by ID
    func simulateTreatment(id: UUID) {
        guard let treatment = treatments.first(where: { $0.id == id }) else {
            print("SimulateTreatment Error: Treatment with ID \(id) not found.")
            treatmentSimulationData = []
            simulationData = [] // Clear legacy simulation data too
            return
        }
        
        // Generate visualization data for the treatment
        treatmentSimulationData = generateSimulationData(for: treatment)
        
        // Also update legacy simulationData for backward compatibility
        simulationData = treatmentSimulationData
        
        print("Simulation generated for treatment: \(treatment.name)")
    }
    
    // MARK: - Simulation Methods
    
    /// Recalculates simulation based on the currently selected treatment
    func recalcSimulation() {
        guard let currentSelectedID = selectedTreatmentID else {
            simulationData = [] // Clear data if no treatment is selected
            treatmentSimulationData = []
            print("RecalcSimulation: No treatment selected, clearing data.")
            return
        }
        
        simulateTreatment(id: currentSelectedID)
    }
    
    /// Generates simulation data for a unified Treatment
    func generateSimulationData(for treatment: Treatment) -> [DataPoint] {
        // Determine start and end dates for simulation
        let startDate = treatment.startDate
        let endDate = treatment.endDate
        
        // Generate data points for the date range
        let calendar = Calendar.current
        let daysBetween = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 90
        
        // For simple treatments
        if treatment.treatmentType == .simple {
            if let compound = findCompoundForTreatment(treatment),
               let doseMg = treatment.doseMg,
               let frequencyDays = treatment.frequencyDays,
               let route = treatment.selectedRoute.flatMap({ Compound.Route(rawValue: $0) }) {
                
                // Generate injection dates
                let injectionDates = treatment.injectionDates(from: startDate, upto: endDate)
                
                // Calculate time points with dynamic interval based on frequency
                let interval = max(0.25, frequencyDays / 16.0) // Minimum 6 hours (0.25 days)
                let simulationDates = generateSimulationDates(
                    startDate: startDate,
                    endDate: endDate,
                    interval: interval
                )
                
                // For blends, we need to calculate the contribution of each component
                var compounds: [(compound: Compound, dosePerInjectionMg: Double)] = []
                
                if let compoundID = treatment.compoundID {
                    // Simple compound treatment
                    compounds = [(compound: compound, dosePerInjectionMg: doseMg)]
                } else if let blendID = treatment.blendID, 
                          let blend = compoundLibrary.blend(withID: blendID) {
                    // Blend treatment
                    let resolvedComponents = blend.resolvedComponents(using: compoundLibrary)
                    
                    guard blend.totalConcentration > 0 else {
                        print("Error: Blend has zero total concentration.")
                        return []
                    }
                    
                    compounds = resolvedComponents.map {
                        (compound: $0.compound, dosePerInjectionMg: $0.mgPerML * doseMg / blend.totalConcentration)
                    }
                }
                
                if compounds.isEmpty {
                    print("Error: No valid compounds found for treatment \(treatment.name)")
                    return []
                }
                
                // Call the PK model to calculate concentrations
                let concentrations = pkModel.protocolConcentrations(
                    at: simulationDates,
                    injectionDates: injectionDates,
                    compounds: compounds,
                    route: route,
                    weight: profile.weight ?? 70.0,
                    calibrationFactor: profile.calibrationFactor
                )
                
                // Create data points
                return zip(simulationDates, concentrations).map { 
                    DataPoint(time: $0, level: $1.isNaN ? 0 : $1)
                }
            }
        } else if treatment.treatmentType == .advanced, let stages = treatment.stages {
            // For advanced treatments, use the visualization model
            let visualizationFactory = VisualizationFactory(
                compoundLibrary: compoundLibrary,
                pkModel: pkModel
            )
            
            let model = visualizationFactory.createVisualization(
                for: treatment,
                weight: profile.weight ?? 70.0,
                calibrationFactor: profile.calibrationFactor,
                unit: profile.unit
            )
            
            // Return the total curve layer if it exists
            if let totalLayer = model.layers.first(where: { $0.type == .totalCurve }) {
                return totalLayer.data
            }
        }
        
        // Return empty array if simulation failed
        return []
    }
    
    // MARK: - Helper Methods
    
    /// Generate time points for the chart
    private func generateSimulationDates(startDate: Date, endDate: Date, interval: Double) -> [Date] {
        guard startDate <= endDate, interval > 0 else { return [] } // Basic validation
        
        var dates: [Date] = []
        var currentDate = startDate
        let intervalSeconds = interval * 24 * 3600 // Convert days to seconds
        
        while currentDate <= endDate {
            dates.append(currentDate)
            
            // Ensure adding interval doesn't cause precision issues
            if let nextDate = Calendar.current.date(byAdding: .second, value: Int(intervalSeconds.rounded()), to: currentDate), nextDate > currentDate {
                currentDate = nextDate
            } else {
                currentDate = currentDate.addingTimeInterval(intervalSeconds)
                if currentDate <= dates.last ?? startDate { // Prevent infinite loop
                    print("Warning: Simulation date interval too small. Breaking loop.")
                    break
                }
            }
            
            // Safety break
            if dates.count > 5000 { // Limit number of points to prevent excessive calculation
                print("Warning: Simulation date generation exceeded 5000 points. Breaking loop.")
                break
            }
        }
        
        // Ensure the end date is included if it wasn't hit exactly by the stride
        if let lastDate = dates.last, lastDate < endDate {
            dates.append(endDate)
        }
        
        return dates
    }
    
    /// Find compound for a treatment
    private func findCompoundForTreatment(_ treatment: Treatment) -> Compound? {
        if let compoundID = treatment.compoundID {
            return compoundLibrary.compound(withID: compoundID)
        } else if let blendID = treatment.blendID, 
                  let blend = compoundLibrary.blend(withID: blendID),
                  let firstComponent = blend.components.first {
            // For blends, just return the first compound for now
            return compoundLibrary.compound(withID: firstComponent.compoundID)
        }
        return nil
    }
    
    // MARK: - Protocol Calibration
    
    /// Calibrate a treatment based on blood samples
    func calibrateTreatment(_ treatment: Treatment) {
        guard treatment.treatmentType == .simple,
              let bloodSamples = treatment.bloodSamples,
              !bloodSamples.isEmpty else {
            print("Cannot calibrate: No blood samples available.")
            return
        }
        
        guard let latestSample = bloodSamples.max(by: { $0.date < $1.date }) else {
            return
        }
        
        // Calculate the model's prediction AT THE SAMPLE DATE using the CURRENT calibration factor
        let modelPrediction = calculateLevelForDate(latestSample.date, for: treatment)
        
        guard modelPrediction.isFinite, modelPrediction > 0.01 else {
            print("Calibration failed: Model prediction is invalid (\(modelPrediction)) at sample date.")
            return
        }
        
        // Calculate the adjustment ratio needed to match the latest sample
        let adjustmentRatio = latestSample.value / modelPrediction
        
        // Apply the adjustment to the global factor (with bounds)
        let newFactor = max(0.1, min(10.0, profile.calibrationFactor * adjustmentRatio))
        
        print("Calibration Summary:")
        print("  - Latest Sample: \(latestSample.value) \(latestSample.unit) on \(latestSample.date)")
        print("  - Model Prediction: \(modelPrediction)")
        print("  - Adjustment Ratio: \(adjustmentRatio)")
        print("  - Old Factor: \(profile.calibrationFactor)")
        print("  - New Factor: \(newFactor)")
        
        profile.calibrationFactor = newFactor
        recalcSimulation() // Update chart data with the new factor
        saveProfile()      // Persist the new factor
        coreDataManager.saveContext() // Save immediately
    }
    
    /// Calculate level for a specific date (used for calibration)
    private func calculateLevelForDate(_ date: Date, for treatment: Treatment) -> Double {
        guard treatment.treatmentType == .simple,
              let doseMg = treatment.doseMg,
              let frequencyDays = treatment.frequencyDays else {
            return 0.0
        }
        
        // Determine route
        let route: Compound.Route
        if let routeString = treatment.selectedRoute, let selectedRoute = Compound.Route(rawValue: routeString) {
            route = selectedRoute
        } else {
            route = .intramuscular // Default route
        }
        
        // Determine compounds/blends
        var compounds: [(compound: Compound, doseMg: Double)] = []
        
        if let compoundID = treatment.compoundID, let compound = compoundLibrary.compound(withID: compoundID) {
            compounds = [(compound: compound, doseMg: doseMg)]
        } else if let blendID = treatment.blendID, let blend = compoundLibrary.blend(withID: blendID) {
            guard blend.totalConcentration > 0 else { return 0.0 }
            
            compounds = blend.resolvedComponents(using: compoundLibrary).map {
                (compound: $0.compound, doseMg: $0.mgPerML * doseMg / blend.totalConcentration)
            }
        }
        
        if compounds.isEmpty {
            return 0.0 // No valid compounds
        }
        
        // Generate injection dates up to the target date
        let injectionDates = treatment.injectionDates(
            from: treatment.startDate,
            upto: date
        )
        
        // Calculate concentration for the single date
        let concentrations = pkModel.protocolConcentrations(
            at: [date],
            injectionDates: injectionDates,
            compounds: compounds.map { (compound: $0.compound, dosePerInjectionMg: $0.doseMg) },
            route: route,
            weight: profile.weight ?? 70.0,
            calibrationFactor: profile.calibrationFactor
        )
        
        return concentrations.first ?? 0.0
    }
    
    // MARK: - Value Formatting
    func formatValue(_ value: Double, unit: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if unit == "nmol/L" {
            formatter.maximumFractionDigits = 1
        } else if unit == "%" {
             formatter.maximumFractionDigits = 1
        } else { // ng/dL typically whole numbers
            formatter.maximumFractionDigits = 0
        }
        formatter.minimumFractionDigits = formatter.maximumFractionDigits // Ensure consistency
        
        // Handle potential NaN or infinity
        if !value.isFinite {
             return "N/A"
        }
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    /// Public method to calculate hormone level for a date
    func getLevelForDate(_ date: Date, for treatment: Treatment) -> Double {
        return calculateLevelForDate(date, for: treatment)
    }
    
    // MARK: - Legacy Support Methods
    // These methods provide backward compatibility with views that still use InjectionProtocol
    
    /// Calibrate protocol (legacy method)
    func calibrateProtocol(_ protocol_: InjectionProtocol) {
        // Convert to treatment, then calibrate
        if let treatment = treatments.first(where: { $0.id == protocol_.id }) {
            calibrateTreatment(treatment)
        } else {
            let treatment = Treatment(from: protocol_)
            saveTreatment(treatment)
            calibrateTreatment(treatment)
        }
    }
    
    /// Predicted level at specific date
    func predictedLevel(on date: Date, for injectionProtocol: InjectionProtocol) -> Double {
        // Find corresponding treatment
        if let treatment = treatments.first(where: { $0.id == injectionProtocol.id }) {
            return calculateLevelForDate(date, for: treatment)
        }
        
        // If treatment doesn't exist, create a temporary one
        let temporaryTreatment = Treatment(from: injectionProtocol)
        return calculateLevelForDate(date, for: temporaryTreatment)
    }
    
    // MARK: - Notification Management Interface
    
    /// Acknowledge injection for treatment
    func acknowledgeInjection(treatmentID: UUID, injectionDate: Date) {
        notificationManager.acknowledgeInjection(treatmentID: treatmentID, injectionDate: injectionDate)
        print("Acknowledged injection for treatment \(treatmentID) scheduled on \(injectionDate)")
    }
    
    /// Get injection history 
    func injectionHistory(for treatmentID: UUID? = nil, treatmentType: String? = nil) -> [NotificationManager.InjectionRecord] {
        return notificationManager.injectionHistory(for: treatmentID, treatmentType: treatmentType)
    }
    
    /// Toggle notification settings
    func toggleNotifications(enabled: Bool) {
        notificationManager.notificationsEnabled = enabled
        if enabled {
            Task {
                let granted = await notificationManager.requestNotificationPermission()
                if granted {
                    await scheduleAllNotifications()
                    print("Notifications enabled and scheduled.")
                } else {
                    // Permission denied - update state
                    await MainActor.run {
                        notificationManager.notificationsEnabled = false
                        print("Notification permission denied.")
                    }
                }
            }
        } else {
            notificationManager.cancelAllNotifications()
            print("Notifications disabled and cancelled.")
        }
    }
    
    /// Schedule notifications for all treatments
    func scheduleAllNotifications() async {
        guard notificationManager.notificationsEnabled else { return }
        
        // Ensure permission is granted before scheduling
        let granted = await notificationManager.requestNotificationPermission()
        if !granted {
            await MainActor.run {
                notificationManager.notificationsEnabled = false
            }
            print("Cannot schedule notifications: Permission denied.")
            return
        }
        
        print("Scheduling notifications for treatments...")
        
        // Cancel all existing first to avoid duplicates if rescheduling
        notificationManager.cancelAllNotifications()
        
        // Schedule for simple treatments
        let simpleTreatments = treatments.filter { $0.treatmentType == .simple }
        
        for treatment in simpleTreatments {
            notificationManager.scheduleNotifications(for: treatment, using: compoundLibrary)
        }
        
        print("Notification scheduling complete.")
    }
}