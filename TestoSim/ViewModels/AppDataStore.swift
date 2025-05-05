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
    
    // Core Data manager
    private static let coreDataManager = CoreDataManager.shared
    private let coreDataManager = CoreDataManager.shared
    
    // Add PKModel instance
    private let pkModel = PKModel(useTwoCompartmentModel: false)
    
    let simulationDurationDays: Double = 90.0
    
    var simulationEndDate: Date {
        guard let selectedProtocolID = selectedProtocolID,
              let selectedProtocol = profile.protocols.first(where: { $0.id == selectedProtocolID }) else {
            return Date().addingTimeInterval(simulationDurationDays * 24 * 3600)
        }
        return selectedProtocol.startDate.addingTimeInterval(simulationDurationDays * 24 * 3600)
    }
    
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
            }
        } else {
            // Try to load profile from UserDefaults (old method)
            if let savedData = UserDefaults.standard.data(forKey: "userProfileData"),
               let decodedProfile = try? JSONDecoder().decode(UserProfile.self, from: savedData) {
                self.profile = decodedProfile
                
                // Trigger migration to Core Data if needed
                if !UserDefaults.standard.bool(forKey: "migrated") {
                    coreDataManager.migrateUserProfileFromJSON()
                }
            } else {
                // Create default profile with a sample protocol
                self.profile = AppDataStore.createDefaultProfile()
            }
        }
        
        // Set initial selected protocol
        if !profile.protocols.isEmpty {
            selectedProtocolID = profile.protocols[0].id
        }
        
        // Generate initial simulation data
        recalcSimulation()
    }
    
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
    }
    
    func updateProtocol(_ updatedProtocol: InjectionProtocol) {
        if let index = profile.protocols.firstIndex(where: { $0.id == updatedProtocol.id }) {
            profile.protocols[index] = updatedProtocol
            if updatedProtocol.id == selectedProtocolID {
                recalcSimulation()
            }
            saveProfile()
        }
    }
    
    func removeProtocol(at offsets: IndexSet) {
        let deletedIDs = offsets.map { profile.protocols[$0].id }
        profile.protocols.remove(atOffsets: offsets)
        
        // Check if selected protocol was deleted
        if let selectedID = selectedProtocolID, deletedIDs.contains(selectedID) {
            selectedProtocolID = profile.protocols.first?.id
            recalcSimulation()
        }
        
        saveProfile()
    }
    
    func selectProtocol(id: UUID) {
        selectedProtocolID = id
        recalcSimulation()
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
        let endDate = startDate.addingTimeInterval(simulationDurationDays * 24 * 3600)
        let stepInterval: TimeInterval = 6 * 3600 // 6-hour intervals
        
        var dataPoints: [DataPoint] = []
        var currentDate = startDate
        
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
        
        // Get all injection dates up to the target date
        let injectionDates = injectionProtocol.injectionDates(
            from: injectionProtocol.startDate.addingTimeInterval(-90 * 24 * 3600), // Include 90 days before to catch buildup
            upto: targetDate
        )
        
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
        
        switch protocolToCalibrate.protocolType {
        case .compound:
            hasValidCompound = protocolToCalibrate.compoundID != nil && 
                              compoundLibrary.compound(withID: protocolToCalibrate.compoundID!) != nil
        case .blend:
            hasValidCompound = protocolToCalibrate.blendID != nil && 
                              compoundLibrary.blend(withID: protocolToCalibrate.blendID!) != nil
        }
        
        // Make sure we have a valid compound
        guard hasValidCompound else {
            // Fall back to simple calibration if needed
            calibrateProtocol(protocolToCalibrate)
            return
        }
        
        // Skip remaining code in calibrateProtocolWithBayesian as it's not needed for now
        // We can restore it later when we need to implement Bayesian calibration
        
        // Convert blood samples to PKModel.SamplePoint format
        /*
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
        
        // Perform Bayesian calibration
        if let calibrationResult = pkModel.bayesianCalibration(
            samples: samplePoints,
            injectionDates: injectionDates,
            compound: compound,
            dose: protocolToCalibrate.doseMg,
            route: .intramuscular, // Default to IM for now
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
        */
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
} 