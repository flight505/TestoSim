import Foundation
import SwiftUI
import CoreData

@MainActor
class AppDataStore: ObservableObject {
    @Published var profile: UserProfile
    @Published var simulationData: [DataPoint] = []
    @Published var selectedProtocolID: UUID?
    @Published var isPresentingProtocolForm = false
    @Published var protocolToEdit: InjectionProtocol?
    @Published var compoundLibrary = CompoundLibrary()
    
    // Cycle management
    @Published var cycles: [Cycle] = []
    @Published var selectedCycleID: UUID?
    @Published var isPresentingCycleForm = false
    @Published var cycleToEdit: Cycle?
    @Published var isCycleSimulationActive = false
    @Published var cycleSimulationData: [DataPoint] = []
    
    // Core Data manager
    private static let coreDataManager = CoreDataManager.shared
    private let coreDataManager = CoreDataManager.shared
    
    // Notification manager
    private let notificationManager = NotificationManager.shared
    
    // Add PKModel instance - always use two-compartment model
    private let pkModel = PKModel(useTwoCompartmentModel: true)
    
    let simulationDurationDays: Double = 90.0
    
    var simulationEndDate: Date {
        guard let selectedProtocolID = selectedProtocolID,
              let selectedProtocol = profile.protocols.first(where: { $0.id == selectedProtocolID }) else {
            return Date().addingTimeInterval(simulationDurationDays * 24 * 3600)
        }
        return selectedProtocol.startDate.addingTimeInterval(simulationDurationDays * 24 * 3600)
    }
    
    // MARK: - Initialization
    
    init() {
        // Initialize profile with a default empty profile first
        self.profile = UserProfile()
        
        // Now we can safely use static methods that do not require self
        if UserDefaults.standard.bool(forKey: "migrated") {
            // Load profile from Core Data
            if let loadedProfile = AppDataStore.loadProfileFromCoreData() {
                self.profile = loadedProfile
            } else {
                self.profile = AppDataStore.createDefaultProfile()
                
                // Save the default profile to Core Data
                let context = coreDataManager.persistentContainer.viewContext
                _ = self.profile.saveToCD(context: context)
                
                do {
                    try context.save()
                } catch {
                    print("Error saving default profile to Core Data: \(error)")
                }
            }
            
            // Load cycles from Core Data if migrated
            loadCyclesFromCoreData()
        } else {
            // Try to load profile from UserDefaults (old method)
            if let savedData = UserDefaults.standard.data(forKey: "userProfileData"),
               let decodedProfile = try? JSONDecoder().decode(UserProfile.self, from: savedData) {
                self.profile = decodedProfile
                
                // Trigger migration to Core Data if needed
                coreDataManager.migrateUserProfileFromJSON()
                UserDefaults.standard.set(true, forKey: "migrated")
            } else {
                // Create default profile with a sample protocol
                self.profile = AppDataStore.createDefaultProfile()
                
                // Set the migrated flag to true
                UserDefaults.standard.set(true, forKey: "migrated")
                
                // Save the default profile to Core Data
                let context = coreDataManager.persistentContainer.viewContext
                _ = self.profile.saveToCD(context: context)
                
                do {
                    try context.save()
                } catch {
                    print("Error saving default profile to Core Data: \(error)")
                }
            }
        }
        
        // Set initial selected protocol
        if !profile.protocols.isEmpty {
            selectedProtocolID = profile.protocols[0].id
        }
        
        // Generate initial simulation data
        recalcSimulation()
        
        // Schedule notifications for all protocols if enabled
        if notificationManager.notificationsEnabled {
            Task {
                await scheduleAllNotifications()
            }
        }
    }
    
    // MARK: - Notification Management
    
    func toggleNotifications(enabled: Bool) {
        notificationManager.notificationsEnabled = enabled
        
        if enabled {
            Task {
                let granted = await notificationManager.requestNotificationPermission()
                
                // If permission granted, schedule notifications
                if granted {
                    await scheduleAllNotifications()
                } else {
                    // Permission denied - disable notifications
                    await MainActor.run {
                        notificationManager.notificationsEnabled = false
                    }
                }
            }
        } else {
            // Cancel all notifications if disabled
            notificationManager.cancelAllNotifications()
        }
    }
    
    func setNotificationSound(enabled: Bool) {
        notificationManager.soundEnabled = enabled
        
        // Reschedule all notifications to apply sound setting
        if notificationManager.notificationsEnabled {
            Task {
                await scheduleAllNotifications()
            }
        }
    }
    
    func setNotificationLeadTime(_ leadTime: NotificationManager.LeadTime) {
        notificationManager.selectedLeadTime = leadTime
        
        // Reschedule all notifications to apply lead time
        if notificationManager.notificationsEnabled {
            Task {
                await scheduleAllNotifications()
            }
        }
    }
    
    func scheduleAllNotifications() async {
        // Request permission if needed
        if notificationManager.notificationsEnabled {
            let granted = await notificationManager.requestNotificationPermission()
            if !granted {
                await MainActor.run {
                    notificationManager.notificationsEnabled = false
                }
                return
            }
            
            // Schedule notifications for all active protocols
            for p in profile.protocols {
                notificationManager.scheduleNotifications(for: p, using: compoundLibrary)
            }
        }
    }
    
    // MARK: - Protocol Management
    
    private static func createDefaultProfile() -> UserProfile {
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
        
        // Add a variety of test protocols with compounds
        let compoundLibrary = CompoundLibrary()
        
        // 1. Standard TRT protocol (cypionate)
        var weeklyProtocol = InjectionProtocol(
            name: "Weekly Cypionate",
            doseMg: 100.0,
            frequencyDays: 7.0,
            startDate: Calendar.current.date(byAdding: .day, value: -60, to: Date())!,
            notes: "Standard TRT protocol with weekly injections"
        )
        
        // Find cypionate compound
        if let cypionate = compoundLibrary.compounds.first(where: { 
            $0.classType == .testosterone && $0.ester?.lowercased() == "cypionate" 
        }) {
            weeklyProtocol.compoundID = cypionate.id
            weeklyProtocol.selectedRoute = Compound.Route.intramuscular.rawValue
        }
        
        // Add some test blood samples to the protocol
        weeklyProtocol.bloodSamples = [
            BloodSample(
                date: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
                value: 650.0,
                unit: "ng/dL"
            ),
            BloodSample(
                date: Calendar.current.date(byAdding: .day, value: -15, to: Date())!,
                value: 720.0,
                unit: "ng/dL"
            )
        ]
        
        profile.protocols.append(weeklyProtocol)
        
        // 2. Split dose protocol (enanthate)
        var splitDoseProtocol = InjectionProtocol(
            name: "Split Dose Enanthate",
            doseMg: 75.0,
            frequencyDays: 3.5,
            startDate: Calendar.current.date(byAdding: .day, value: -45, to: Date())!,
            notes: "Split dose protocol for more stable levels"
        )
        
        // Find enanthate compound
        if let enanthate = compoundLibrary.compounds.first(where: { 
            $0.classType == .testosterone && $0.ester?.lowercased() == "enanthate" 
        }) {
            splitDoseProtocol.compoundID = enanthate.id
            splitDoseProtocol.selectedRoute = Compound.Route.intramuscular.rawValue
        }
        
        profile.protocols.append(splitDoseProtocol)
        
        // 3. Propionate protocol (more frequent injections)
        var propionateProtocol = InjectionProtocol(
            name: "EOD Propionate",
            doseMg: 30.0,
            frequencyDays: 2.0,
            startDate: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
            notes: "Every other day protocol with propionate"
        )
        
        // Find propionate compound
        if let propionate = compoundLibrary.compounds.first(where: { 
            $0.classType == .testosterone && $0.ester?.lowercased() == "propionate" 
        }) {
            propionateProtocol.compoundID = propionate.id
            propionateProtocol.selectedRoute = Compound.Route.intramuscular.rawValue
        }
        
        profile.protocols.append(propionateProtocol)
        
        return profile
    }
    
    private static func loadProfileFromCoreData() -> UserProfile? {
        let context = coreDataManager.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<CDUserProfile> = CDUserProfile.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            if let cdProfile = results.first {
                return UserProfile(from: cdProfile)
            }
        } catch {
            print("Error fetching profile from Core Data: \(error)")
        }
        
        return nil
    }
    
    func saveProfile() {
        // If we've migrated to Core Data, use that for storage
        if UserDefaults.standard.bool(forKey: "migrated") {
            let context = coreDataManager.persistentContainer.viewContext
            _ = profile.saveToCD(context: context)
        } else {
            // Otherwise use the old UserDefaults method
            if let encodedData = try? JSONEncoder().encode(profile) {
                UserDefaults.standard.set(encodedData, forKey: "userProfileData")
            }
        }
    }
    
    func addProtocol(_ newProtocol: InjectionProtocol) {
        profile.protocols.append(newProtocol)
        selectedProtocolID = newProtocol.id
        recalcSimulation()
        saveProfile()
        
        // Schedule notifications for the new protocol
        if notificationManager.notificationsEnabled {
            notificationManager.scheduleNotifications(for: newProtocol, using: compoundLibrary)
        }
    }
    
    func updateProtocol(_ updatedProtocol: InjectionProtocol) {
        if let index = profile.protocols.firstIndex(where: { $0.id == updatedProtocol.id }) {
            profile.protocols[index] = updatedProtocol
            if updatedProtocol.id == selectedProtocolID {
                recalcSimulation()
            }
            saveProfile()
            
            // Update notifications for the modified protocol
            if notificationManager.notificationsEnabled {
                notificationManager.scheduleNotifications(for: updatedProtocol, using: compoundLibrary)
            }
        }
    }
    
    func removeProtocol(at offsets: IndexSet) {
        let deletedProtocols = offsets.map { profile.protocols[$0] }
        let deletedIDs = deletedProtocols.map { $0.id }
        
        profile.protocols.remove(atOffsets: offsets)
        
        // Check if selected protocol was deleted
        if let selectedID = selectedProtocolID, deletedIDs.contains(selectedID) {
            selectedProtocolID = profile.protocols.first?.id
            recalcSimulation()
        }
        
        saveProfile()
        
        // Cancel notifications for deleted protocols
        for item in deletedProtocols {
            notificationManager.cancelNotifications(for: item.id)
        }
    }
    
    func selectProtocol(id: UUID) {
        // Clear previous selection if different
        if selectedProtocolID != id {
            selectedProtocolID = id
            
            // Always run simulation when protocol is selected
            simulateProtocol(id: id)
        } else {
            // Even if same protocol, ensure we have simulation data
            if simulationData.isEmpty {
                simulateProtocol(id: id)
            }
        }
    }
    
    func recalcSimulation() {
        guard let selectedProtocolID = selectedProtocolID,
              let selectedProtocol = profile.protocols.first(where: { $0.id == selectedProtocolID }) else {
            simulationData = []
            return
        }
        
        simulationData = generateSimulationData(for: selectedProtocol)
    }
    
    func generateSimulationData(for injectionProtocol: InjectionProtocol) -> [DataPoint] {
        let startDate = injectionProtocol.startDate
        // Project at least 90 days of data
        let endDate = startDate.addingTimeInterval(simulationDurationDays * 24 * 3600)
        let stepInterval: TimeInterval = 6 * 3600 // 6-hour intervals
        
        var dataPoints: [DataPoint] = []
        
        // Start simulation from a week before the protocol start date
        let simulationStartDate = Calendar.current.date(byAdding: .day, value: -7, to: startDate) ?? startDate
        var currentDate = simulationStartDate
        
        while currentDate <= endDate {
            let level = calculateLevel(at: currentDate, for: injectionProtocol, using: profile.calibrationFactor)
            let dataPoint = DataPoint(time: currentDate, level: level)
            dataPoints.append(dataPoint)
            
            currentDate = currentDate.addingTimeInterval(stepInterval)
        }
        
        return dataPoints
    }
    
    func calculateLevel(at targetDate: Date, for injectionProtocol: InjectionProtocol, using calibrationFactor: Double) -> Double {
        // Get the appropriate compound or blend
        var compounds: [(compound: Compound, dosePerInjectionMg: Double)] = []
        
        switch injectionProtocol.protocolType {
        case .compound:
            // Get compound from library
            guard let compoundID = injectionProtocol.compoundID,
                  let compound = compoundLibrary.compound(withID: compoundID) else {
                return 0 // No valid compound found
            }
            compounds = [(compound: compound, dosePerInjectionMg: injectionProtocol.doseMg)]
            
        case .blend:
            // Get blend from library
            guard let blendID = injectionProtocol.blendID,
                  let blend = compoundLibrary.blend(withID: blendID) else {
                return 0 // No valid blend found
            }
            
            // Get all compounds in the blend
            let resolvedComponents = blend.resolvedComponents(using: compoundLibrary)
            compounds = resolvedComponents.map { 
                (compound: $0.compound, dosePerInjectionMg: $0.mgPerML * injectionProtocol.doseMg / blend.totalConcentration)
            }
        }
        
        if compounds.isEmpty {
            return 0 // No valid compounds found
        }
        
        // Get the route (default to intramuscular if not specified)
        let route: Compound.Route
        if let routeString = injectionProtocol.selectedRoute,
           let selectedRoute = Compound.Route(rawValue: routeString) {
            route = selectedRoute
        } else {
            route = .intramuscular
        }
        
        // We want to show expected concentrations even for future protocols
        // So for dates before protocol starts, we'll return 0
        // But we'll still calculate properly for the simulation curve
        
        // Get all injection dates from protocol start date up to target date
        // This ensures we get injections that happen exactly on target date
        let injectionDates = injectionProtocol.injectionDates(
            from: injectionProtocol.startDate,
            upto: targetDate
        )
        
        // If target date is before protocol starts, return 0
        if targetDate < injectionProtocol.startDate {
            return 0
        }
        
        // Use the PKModel to calculate concentrations
        let concentrations = pkModel.protocolConcentrations(
            at: [targetDate],
            injectionDates: injectionDates,
            compounds: compounds,
            route: route,
            weight: profile.weight ?? 70.0, // Use profile weight or default to 70kg
            calibrationFactor: calibrationFactor
        )
        
        return concentrations.first ?? 0.0
    }
    
    func predictedLevel(on date: Date, for injectionProtocol: InjectionProtocol) -> Double {
        return calculateLevel(at: date, for: injectionProtocol, using: profile.calibrationFactor)
    }
    
    // MARK: - Protocol Calibration
    
    func calibrateProtocol(_ protocolToCalibrate: InjectionProtocol) {
        // We need at least one blood sample to calibrate
        if protocolToCalibrate.bloodSamples.isEmpty {
            print("No blood samples to calibrate with")
            return
        }
        
        // Check if we have a valid compound or blend
        let hasValidCompound = protocolToCalibrate.compoundID != nil && compoundLibrary.compound(withID: protocolToCalibrate.compoundID!) != nil
        let hasValidBlend = protocolToCalibrate.blendID != nil && compoundLibrary.blend(withID: protocolToCalibrate.blendID!) != nil
        
        // Make sure we have a compound to calibrate with
        guard hasValidCompound || hasValidBlend else {
            print("Cannot calibrate: Invalid compound or blend")
            return
        }
        
        // Create calibration data points from blood samples (not using these yet but keeping for future implementation)
        _ = protocolToCalibrate.bloodSamples.map { sample in
            return DataPoint(time: sample.date, level: sample.value) 
        }
        
        // For now, use a simple approach to calibration
        // Calculate the average of the observed values 
        let avgLabValue = protocolToCalibrate.bloodSamples.reduce(0.0) { $0 + $1.value } / Double(protocolToCalibrate.bloodSamples.count)
        
        // Calculate the predicted values using current settings
        let oldPredictions = protocolToCalibrate.bloodSamples.map { sample in
            calculateLevel(at: sample.date, for: protocolToCalibrate, using: 1.0)
        }
        let avgOldPrediction = oldPredictions.reduce(0.0, +) / Double(oldPredictions.count)
        
        // Set calibration factor to make average prediction match average lab value
        if avgOldPrediction > 0 {
            profile.calibrationFactor = avgLabValue / avgOldPrediction
            saveProfile()
            print("Protocol calibrated, new factor: \(profile.calibrationFactor)")
        } else {
            print("Calibration failed")
        }
    }
    
    func calibrateProtocolWithBayesian(_ protocolToCalibrate: InjectionProtocol) {
        // Only proceed if protocol has blood samples and we can find matching compound
        guard !protocolToCalibrate.bloodSamples.isEmpty else {
            // Fall back to simple calibration if needed
            calibrateProtocol(protocolToCalibrate)
            return
        }
        
        // Check if we have a valid compound based on protocol type
        let hasValidCompound: Bool
        var compound: Compound?
        var dose: Double = protocolToCalibrate.doseMg
        
        switch protocolToCalibrate.protocolType {
        case .compound:
            hasValidCompound = protocolToCalibrate.compoundID != nil && 
                              compoundLibrary.compound(withID: protocolToCalibrate.compoundID!) != nil
            compound = protocolToCalibrate.compoundID != nil ? compoundLibrary.compound(withID: protocolToCalibrate.compoundID!) : nil
            
        case .blend:
            if let blendID = protocolToCalibrate.blendID,
               let blend = compoundLibrary.blend(withID: blendID),
               let mainComponent = blend.resolvedComponents(using: compoundLibrary).first {
                
                hasValidCompound = true
                compound = mainComponent.compound
                // Adjust dose for the main component in the blend
                dose = mainComponent.mgPerML * protocolToCalibrate.doseMg / blend.totalConcentration
            } else {
                hasValidCompound = false
            }
        }
        
        // Make sure we have a valid compound
        guard hasValidCompound, let compound = compound else {
            // Fall back to simple calibration if needed
            calibrateProtocol(protocolToCalibrate)
            return
        }
        
        // Convert blood samples to PKModel.SamplePoint format
        let samplePoints = protocolToCalibrate.bloodSamples.map { 
            PKModel.SamplePoint(timestamp: $0.date, labValue: $0.value)
        }
        
        // Get injection dates for this protocol
        let startDate = Calendar.current.date(
            byAdding: .day,
            value: -90, // Look back 90 days to catch buildup
            to: protocolToCalibrate.bloodSamples.map { $0.date }.min() ?? Date()
        ) ?? Date()
        
        let endDate = protocolToCalibrate.bloodSamples.map { $0.date }.max() ?? Date()
        let injectionDates = protocolToCalibrate.injectionDates(from: startDate, upto: endDate)
        
        // Determine the route
        let route: Compound.Route = {
            if let routeString = protocolToCalibrate.selectedRoute,
               let selectedRoute = Compound.Route(rawValue: routeString) {
                return selectedRoute
            }
            return .intramuscular // Default to IM if not specified
        }()
        
        // Perform Bayesian calibration
        if let calibrationResult = pkModel.bayesianCalibration(
            samples: samplePoints,
            injectionDates: injectionDates,
            compound: compound,
            dose: dose,
            route: route,
            weight: profile.weight ?? 70.0
        ) {
            // For now, just use the calibration results to adjust the global calibration factor
            // In a more advanced implementation, we could store the adjusted ke and ka per-compound
            // or create a custom compound for this user
            
            // Update calibration factor based on average accuracy improvement
            let avgLabValue = samplePoints.reduce(0.0) { $0 + $1.labValue } / Double(samplePoints.count)
            let oldPredictions = samplePoints.map { point in
                calculateLevel(at: point.timestamp, for: protocolToCalibrate, using: 1.0)
            }
            let avgOldPrediction = oldPredictions.reduce(0.0, +) / Double(oldPredictions.count)
            
            // Set calibration factor to make average prediction match average lab value
            if avgOldPrediction > 0 {
                profile.calibrationFactor = avgLabValue / avgOldPrediction
            }
            
            // Print calibration results to console (would show in UI in full implementation)
            print("Bayesian Calibration Results:")
            print("Original half-life: \(compound.halfLifeDays) days")
            print("Calibrated half-life: \(calibrationResult.halfLifeDays) days")
            
            let percentFormatter = NumberFormatter()
            percentFormatter.maximumFractionDigits = 1
            let halfLifeChangeStr = percentFormatter.string(from: NSNumber(value: calibrationResult.halfLifeChangePercent)) ?? "\(calibrationResult.halfLifeChangePercent)"
            print("Half-life change: \(halfLifeChangeStr)%")
            
            let decimalFormatter = NumberFormatter()
            decimalFormatter.maximumFractionDigits = 2
            let correlationStr = decimalFormatter.string(from: NSNumber(value: calibrationResult.correlation)) ?? "\(calibrationResult.correlation)"
            let calFactorStr = decimalFormatter.string(from: NSNumber(value: profile.calibrationFactor)) ?? "\(profile.calibrationFactor)"
            print("Fit correlation: \(correlationStr)")
            print("Applied calibration factor: \(calFactorStr)")
            
            // Update simulation and save
            recalcSimulation()
            saveProfile()
        } else {
            // Fall back to simple calibration if Bayesian method fails
            calibrateProtocol(protocolToCalibrate)
        }
    }
    
    func formatValue(_ value: Double, unit: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if unit == "nmol/L" {
            formatter.maximumFractionDigits = 1
        } else { // ng/dL typically whole numbers
            formatter.maximumFractionDigits = 0
        }
        formatter.minimumFractionDigits = formatter.maximumFractionDigits // Ensure consistency
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    // MARK: - Peak Predictions
    
    /// Calculate the peak concentration and time for a protocol
    /// - Parameters:
    ///   - injectionProtocol: The protocol to analyze
    /// - Returns: Tuple containing (peak date, max concentration)
    func calculatePeakDetails(for injectionProtocol: InjectionProtocol) -> (peakDate: Date, maxConcentration: Double) {
        var compounds: [(compound: Compound, dosePerInjectionMg: Double)] = []
        var route = Compound.Route.intramuscular
        
        // Determine compound and route based on protocol type
        switch injectionProtocol.protocolType {
        case .compound:
            if let compoundID = injectionProtocol.compoundID,
               let compound = compoundLibrary.compound(withID: compoundID) {
                compounds = [(compound: compound, dosePerInjectionMg: injectionProtocol.doseMg)]
            }
            
        case .blend:
            // For blends, we need the full blend components
            if let blendID = injectionProtocol.blendID,
               let blend = compoundLibrary.blend(withID: blendID) {
                // Get resolved components with their compounds
                let resolvedComponents = blend.resolvedComponents(using: compoundLibrary)
                compounds = resolvedComponents.map {
                    (compound: $0.compound, dosePerInjectionMg: $0.mgPerML * injectionProtocol.doseMg / blend.totalConcentration)
                }
            }
        }
        
        // If we don't have valid compounds, return zeros
        if compounds.isEmpty {
            return (peakDate: injectionProtocol.startDate, maxConcentration: 0)
        }
        
        // Get the appropriate route
        if let routeString = injectionProtocol.selectedRoute,
           let selectedRoute = Compound.Route(rawValue: routeString) {
            route = selectedRoute
        }
        
        // Get the time window for evaluation
        let timeWindow = (
            start: injectionProtocol.startDate,
            end: injectionProtocol.startDate.addingTimeInterval(simulationDurationDays * 24 * 3600)
        )
        
        // Get all injection dates
        let injectionDates = injectionProtocol.injectionDates(
            from: timeWindow.start,
            upto: timeWindow.end
        )
        
        // Calculate peak details using PKModel
        return pkModel.calculateProtocolPeakDetails(
            injectionDates: injectionDates,
            compounds: compounds,
            route: route,
            timeWindow: timeWindow,
            weight: profile.weight ?? 70.0,
            calibrationFactor: profile.calibrationFactor
        )
    }
    
    /// Calculate the first peak concentration and time (after a single injection)
    /// - Parameters:
    ///   - injectionProtocol: The protocol to analyze
    /// - Returns: Tuple containing (time to peak in days, max concentration)
    func calculateSingleDosePeakDetails(for injectionProtocol: InjectionProtocol) -> (timeToMaxDays: Double, maxConcentration: Double) {
        var compounds: [(compound: Compound, doseMg: Double)] = []
        var route = Compound.Route.intramuscular
        
        // Determine compound and route based on protocol type
        switch injectionProtocol.protocolType {
        case .compound:
            if let compoundID = injectionProtocol.compoundID,
               let compound = compoundLibrary.compound(withID: compoundID) {
                compounds = [(compound: compound, doseMg: injectionProtocol.doseMg)]
            }
            
        case .blend:
            // For blends, use the blend components
            if let blendID = injectionProtocol.blendID,
               let blend = compoundLibrary.blend(withID: blendID) {
                
                // Get resolved components with their compounds
                let resolvedComponents = blend.resolvedComponents(using: compoundLibrary)
                compounds = resolvedComponents.map {
                    (compound: $0.compound, doseMg: $0.mgPerML * injectionProtocol.doseMg / blend.totalConcentration)
                }
            }
        }
        
        // If we don't have valid compounds, return zeros
        if compounds.isEmpty {
            return (timeToMaxDays: 0, maxConcentration: 0)
        }
        
        // Get appropriate route
        if let routeString = injectionProtocol.selectedRoute,
           let selectedRoute = Compound.Route(rawValue: routeString) {
            route = selectedRoute
        }
        
        // For simplicity, just use the first compound for peak calculation
        if let firstCompound = compounds.first {
            // Get appropriate parameters from compound for selected route
            let bioavailability = firstCompound.compound.defaultBioavailability[route] ?? 1.0
            let absorptionRate = firstCompound.compound.defaultAbsorptionRateKa[route] ?? 0.7 // Default ka if not specified
            
            // Calculate using PKModel methods
            let timeToMax = pkModel.calculateTimeToMaxConcentration(
                dose: firstCompound.doseMg,
                halfLifeDays: firstCompound.compound.halfLifeDays,
                absorptionRateKa: absorptionRate,
                bioavailability: bioavailability,
                weight: profile.weight ?? 70.0,
                calibrationFactor: profile.calibrationFactor
            )
            
            let maxConc = pkModel.calculateMaxConcentration(
                dose: firstCompound.doseMg,
                halfLifeDays: firstCompound.compound.halfLifeDays,
                absorptionRateKa: absorptionRate,
                bioavailability: bioavailability,
                weight: profile.weight ?? 70.0,
                calibrationFactor: profile.calibrationFactor
            )
            
            return (timeToMaxDays: timeToMax, maxConcentration: maxConc)
        }
        
        return (timeToMaxDays: 0, maxConcentration: 0)
    }
    
    // MARK: - Adherence Tracking
    
    func acknowledgeInjection(protocolID: UUID, injectionDate: Date) {
        notificationManager.acknowledgeInjection(protocolID: protocolID, injectionDate: injectionDate)
    }
    
    func adherenceStats() -> (total: Int, onTime: Int, late: Int, missed: Int) {
        return notificationManager.adherenceStats()
    }
    
    func adherencePercentage() -> Double {
        return notificationManager.adherencePercentage()
    }
    
    func injectionHistory(for protocolID: UUID? = nil) -> [NotificationManager.InjectionRecord] {
        return notificationManager.injectionHistory(for: protocolID)
    }
    
    // Clean up old records periodically
    func cleanupOldRecords() {
        notificationManager.cleanupOldRecords()
    }
    
    // MARK: - Cycle Management
    
    func loadCyclesFromCoreData() {
        let context = coreDataManager.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<CDCycle> = CDCycle.fetchRequest()
        
        do {
            let cdCycles = try context.fetch(fetchRequest)
            self.cycles = cdCycles.map { Cycle(from: $0, context: context) }
        } catch {
            print("Error loading cycles from Core Data: \(error)")
        }
    }
    
    func saveCycle(_ cycle: Cycle) {
        let context = coreDataManager.persistentContainer.viewContext
        
        // Save to Core Data
        _ = cycle.save(to: context)
        
        do {
            try context.save()
            
            // Refresh cycles from Core Data
            loadCyclesFromCoreData()
        } catch {
            print("Error saving cycle: \(error)")
        }
    }
    
    func deleteCycle(with id: UUID) {
        let context = coreDataManager.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<CDCycle> = CDCycle.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let cdCycle = try context.fetch(fetchRequest).first {
                context.delete(cdCycle)
                try context.save()
                
                // Refresh cycles from Core Data
                loadCyclesFromCoreData()
                
                // If this was the selected cycle, deselect it
                if selectedCycleID == id {
                    selectedCycleID = nil
                    isCycleSimulationActive = false
                    cycleSimulationData = []
                }
            }
        } catch {
            print("Error deleting cycle: \(error)")
        }
    }
    
    func simulateCycle(id: UUID? = nil) {
        let cycleToSimulate: Cycle?
        
        if let id = id {
            cycleToSimulate = cycles.first { $0.id == id }
        } else if let id = selectedCycleID {
            cycleToSimulate = cycles.first { $0.id == id }
        } else {
            cycleToSimulate = cycles.first
        }
        
        guard let cycle = cycleToSimulate else {
            cycleSimulationData = []
            return
        }
        
        // Create protocols for simulation
        let tempProtocols = cycle.generateTemporaryProtocols(compoundLibrary: compoundLibrary)
        
        // No protocols to simulate
        if tempProtocols.isEmpty {
            cycleSimulationData = []
            return
        }
        
        // Create a properly configured PK model using our helper method
        let pkModel = createPKModel()
        
        // Clear existing data
        cycleSimulationData = []
        
        // Generate dates for simulation
        let calendar = Calendar.current
        let startDate = cycle.startDate
        let endDate = calendar.date(byAdding: .day, value: cycle.totalWeeks * 7, to: startDate) ?? startDate
        let simulationDates = generateSimulationDates(
            startDate: startDate,
            endDate: endDate,
            interval: 0.5 // Two points per day for smooth curves
        )
        
        // Initialize data array
        var totalConcentrations = Array(repeating: 0.0, count: simulationDates.count)
        
        // For each protocol, generate concentration data and accumulate
        for treatmentProtocol in tempProtocols {
            // Get simulation parameters
            let routeStr = treatmentProtocol.selectedRoute ?? Compound.Route.intramuscular.rawValue
            let route = Compound.Route(rawValue: routeStr) ?? .intramuscular
            let weight = profile.weight ?? 70.0
            
            // Get compound or blend for this protocol
            var compounds: [(compound: Compound, dosePerInjectionMg: Double)] = []
            
            if treatmentProtocol.protocolType == .compound, let compoundID = treatmentProtocol.compoundID {
                if let compound = compoundLibrary.compounds.first(where: { $0.id == compoundID }) {
                    compounds = [(compound, treatmentProtocol.doseMg)]
                }
            } else if treatmentProtocol.protocolType == .blend, let blendID = treatmentProtocol.blendID {
                if let blend = compoundLibrary.blends.first(where: { $0.id == blendID }) {
                    compounds = blend.components.map { component in
                        if let compound = compoundLibrary.compound(withID: component.compoundID) {
                            return (compound, treatmentProtocol.doseMg * (component.mgPerML / blend.totalConcentration))
                        } else {
                            return nil
                        }
                    }.compactMap { $0 }
                }
            } else {
                // Legacy protocol with testosterone ester - convert to compound
                // Try to find a matching testosterone compound based on ester name
                if let esterName = treatmentProtocol.notes?.contains("ester:") == true ? 
                    treatmentProtocol.notes?.components(separatedBy: "ester:").last?.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                   let compound = compoundLibrary.compounds.first(where: { 
                       $0.classType == .testosterone && $0.ester?.lowercased() == esterName.lowercased() 
                   }) {
                    compounds = [(compound, treatmentProtocol.doseMg)]
                }
            }
            
            // Skip if no compounds
            guard !compounds.isEmpty else { continue }
            
            // Generate injection dates
            let injectionDates = treatmentProtocol.injectionDates(from: startDate, upto: endDate)
            
            // Calculate concentrations
            let concentrations = pkModel.protocolConcentrations(
                at: simulationDates,
                injectionDates: injectionDates,
                compounds: compounds,
                route: route,
                weight: weight,
                calibrationFactor: profile.calibrationFactor
            )
            
            // Add to total
            for i in 0..<min(totalConcentrations.count, concentrations.count) {
                totalConcentrations[i] += concentrations[i]
            }
        }
        
        // Convert to DataPoints
        cycleSimulationData = zip(simulationDates, totalConcentrations).map {
            DataPoint(time: $0, level: $1)
        }
        
        isCycleSimulationActive = true
    }
    
    // Add a new method to simplify access to the model
    private func createPKModel() -> PKModel {
        return PKModel(useTwoCompartmentModel: true)
    }
    
    // Update the existing simulateProtocol method to use the two-compartment model setting
    func simulateProtocol(id: UUID? = nil) {
        let protocolToSimulate: InjectionProtocol?
        
        if let id = id {
            protocolToSimulate = profile.protocols.first { $0.id == id }
        } else if let id = selectedProtocolID {
            protocolToSimulate = profile.protocols.first { $0.id == id }
        } else {
            protocolToSimulate = profile.protocols.first
        }
        
        guard let treatmentProtocol = protocolToSimulate else {
            simulationData = []
            return
        }
        
        // Use the new helper method to create a properly configured PK model
        let pkModel = createPKModel()
        
        let now = Date()
        let calendar = Calendar.current
        
        // Adjust simulation dates to always show a meaningful timeline
        // If protocol starts in the future, show from 7 days before start date
        // If protocol started in the past, show from 7 days before now or protocol start, whichever is earlier
        let simulationStartDate: Date
        let daysBeforeStart = -7
        
        if treatmentProtocol.startDate > now {
            // Future protocol - start simulation a week before protocol start
            simulationStartDate = calendar.date(byAdding: .day, value: daysBeforeStart, to: treatmentProtocol.startDate) ?? treatmentProtocol.startDate
        } else {
            // Protocol already started - show from a week before now or protocol start, whichever is earlier
            let aWeekBeforeNow = calendar.date(byAdding: .day, value: daysBeforeStart, to: now) ?? now
            simulationStartDate = min(aWeekBeforeNow, treatmentProtocol.startDate)
        }
        
        // Always show at least 90 days from protocol start for future visibility
        let minEndDate = calendar.date(byAdding: .day, value: 90, to: treatmentProtocol.startDate) ?? now
        // Also ensure we see at least 30 days from now for current visibility
        let thirtyDaysFromNow = calendar.date(byAdding: .day, value: 30, to: now) ?? now
        // Use the later of these two dates to ensure sufficient future visibility
        let projectedEndDate = max(minEndDate, thirtyDaysFromNow)
        
        // Generate simulation dates
        let simulationDates = generateSimulationDates(
            startDate: simulationStartDate,
            endDate: projectedEndDate,
            interval: max(0.25, treatmentProtocol.frequencyDays / 16.0) // 16 points per interval for smoother curve
        )
        
        // Generate injection dates - ALWAYS use protocol start date for beginning
        // regardless of whether it's in the future or past
        let injectionDates = treatmentProtocol.injectionDates(from: treatmentProtocol.startDate, upto: projectedEndDate)
        
        // Weight for allometric scaling
        let weight = profile.weight ?? 70.0 // Default to 70kg if not specified
        
        // Get compound or blend for this protocol
        var compounds: [(compound: Compound, dosePerInjectionMg: Double)] = []
        
        if treatmentProtocol.protocolType == .compound, let compoundID = treatmentProtocol.compoundID {
            if let compound = compoundLibrary.compounds.first(where: { $0.id == compoundID }) {
                compounds = [(compound, treatmentProtocol.doseMg)]
            }
        } else if treatmentProtocol.protocolType == .blend, let blendID = treatmentProtocol.blendID {
            if let blend = compoundLibrary.blends.first(where: { $0.id == blendID }) {
                // Get all compounds from the blend with their proportional doses
                compounds = blend.components.map { component in
                    if let compound = compoundLibrary.compound(withID: component.compoundID) {
                        return (compound, treatmentProtocol.doseMg * (component.mgPerML / blend.totalConcentration))
                    } else {
                        return nil
                    }
                }.compactMap { $0 }
            }
        } else {
            // Legacy protocol with testosterone ester - convert to compound
            // Try to find a matching testosterone compound based on ester name
            if let esterName = treatmentProtocol.notes?.contains("ester:") == true ? 
                treatmentProtocol.notes?.components(separatedBy: "ester:").last?.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
               let compound = compoundLibrary.compounds.first(where: { 
                   $0.classType == .testosterone && $0.ester?.lowercased() == esterName.lowercased() 
               }) {
                compounds = [(compound, treatmentProtocol.doseMg)]
            }
        }
        
        // Skip if no compounds
        if compounds.isEmpty {
            print("No compounds found for protocol. Check protocol configuration.")
            simulationData = []
            return
        }
        
        // Get the route (default to intramuscular if not specified)
        let route: Compound.Route
        if let routeString = treatmentProtocol.selectedRoute,
           let selectedRoute = Compound.Route(rawValue: routeString) {
            route = selectedRoute
        } else {
            route = .intramuscular
        }
        
        // Calculate concentrations
        let concentrations = pkModel.protocolConcentrations(
            at: simulationDates,
            injectionDates: injectionDates,
            compounds: compounds,
            route: route,
            weight: weight,
            calibrationFactor: profile.calibrationFactor
        )
        
        // Convert to DataPoints
        simulationData = zip(simulationDates, concentrations).map {
            DataPoint(time: $0, level: $1)
        }
        
        // Log for debugging
        print("Simulated protocol: \(treatmentProtocol.name)")
        print("  - Start date: \(treatmentProtocol.startDate)")
        print("  - Simulation date range: \(simulationStartDate) to \(projectedEndDate)")
        print("  - Found \(injectionDates.count) injection dates")
        print("  - Generated \(simulationData.count) data points")
        if let first = simulationData.first, let last = simulationData.last {
            print("  - First point: \(first.time) = \(first.level)")
            print("  - Last point: \(last.time) = \(last.level)")
        }
    }
    
    // Add this method to generate simulation dates
    private func generateSimulationDates(startDate: Date, endDate: Date, interval: Double) -> [Date] {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.day], from: startDate, to: endDate)
        guard let days = dateComponents.day, days > 0 else { return [startDate] }
        
        // Create date points for the simulation period with the specified interval (in days)
        return stride(from: 0, to: Double(days), by: interval).map { day in
            startDate.addingTimeInterval(day * 24 * 3600)
        }
    }
} 