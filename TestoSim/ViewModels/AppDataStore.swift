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
        // Check if migration has occurred
        if UserDefaults.standard.bool(forKey: "migrated") {
            // Load profile from Core Data
            self.profile = loadProfileFromCoreData() ?? createDefaultProfile()
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
                self.profile = createDefaultProfile()
            }
        }
        
        // Set initial selected protocol
        if !profile.protocols.isEmpty {
            selectedProtocolID = profile.protocols[0].id
        }
        
        // Generate initial simulation data
        recalcSimulation()
    }
    
    private func createDefaultProfile() -> UserProfile {
        let profile = UserProfile()
        let defaultProtocol = InjectionProtocol(
            name: "Default TRT",
            ester: .cypionate,
            doseMg: 100.0,
            frequencyDays: 7.0,
            startDate: Date()
        )
        profile.protocols.append(defaultProtocol)
        return profile
    }
    
    private func loadProfileFromCoreData() -> UserProfile? {
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
        // Get compound from library that matches the ester
        let compound = compoundFromEster(injectionProtocol.ester)
        guard let compound = compound else {
            // Fall back to old calculation if compound not found
            return calculateLevelLegacy(at: targetDate, for: injectionProtocol, using: calibrationFactor)
        }
        
        // Get all injection dates up to the target date
        let injectionDates = injectionProtocol.injectionDates(
            from: injectionProtocol.startDate.addingTimeInterval(-90 * 24 * 3600), // Include 90 days before to catch buildup
            upto: targetDate
        )
        
        // Use the new PKModel to calculate concentrations
        let compounds = [(compound: compound, dosePerInjectionMg: injectionProtocol.doseMg)]
        let concentrations = pkModel.protocolConcentrations(
            at: [targetDate],
            injectionDates: injectionDates,
            compounds: compounds,
            route: .intramuscular, // Default to IM for now
            weight: profile.weight ?? 70.0, // Use profile weight or default to 70kg
            calibrationFactor: calibrationFactor
        )
        
        return concentrations.first ?? 0.0
    }
    
    // Legacy calculation method for backward compatibility
    private func calculateLevelLegacy(at targetDate: Date, for injectionProtocol: InjectionProtocol, using calibrationFactor: Double) -> Double {
        let t_days = targetDate.timeIntervalSince(injectionProtocol.startDate) / (24 * 3600) // Time in days since start
        guard t_days >= 0 else { return 0.0 }
        
        guard injectionProtocol.ester.halfLifeDays > 0 else { return 0.0 } // Avoid division by zero if halfLife is 0
        let k = log(2) / injectionProtocol.ester.halfLifeDays // Natural log
        
        var totalLevel = 0.0
        var injIndex = 0
        
        while true {
            let injTime_days = Double(injIndex) * injectionProtocol.frequencyDays
            // Optimization: If frequency is 0 or negative, only consider the first injection
            if injectionProtocol.frequencyDays <= 0 && injIndex > 0 { break }
            
            if injTime_days > t_days { break } // Stop if injection time is after target time
            
            let timeDiff_days = t_days - injTime_days
            if timeDiff_days >= 0 { // Ensure we only calculate for times after injection
                let contribution = injectionProtocol.doseMg * exp(-k * timeDiff_days)
                totalLevel += contribution
            }
            
            // Check for infinite loop condition if frequency is 0
            if injectionProtocol.frequencyDays <= 0 { break }
            
            injIndex += 1
            // Safety break if index gets excessively large (e.g., > 10000) though unlikely with date limits
            if injIndex > 10000 { break }
        }
        
        return totalLevel * calibrationFactor
    }
    
    // Helper method to find compound that matches the TestosteroneEster
    private func compoundFromEster(_ ester: TestosteroneEster) -> Compound? {
        // Map from TestosteroneEster to Compound - looking up by name match
        let esterName = ester.name
        return compoundLibrary.compounds.first { 
            $0.classType == .testosterone && $0.ester?.lowercased() == esterName.lowercased()
        }
    }
    
    func predictedLevel(on date: Date, for injectionProtocol: InjectionProtocol) -> Double {
        return calculateLevel(at: date, for: injectionProtocol, using: profile.calibrationFactor)
    }
    
    func calibrateProtocol(_ protocolToCalibrate: InjectionProtocol) {
        // Find and calibrate based on the most recent blood sample
        guard let latestSample = protocolToCalibrate.bloodSamples.max(by: { $0.date < $1.date }) else {
            return
        }
        
        let modelPrediction = calculateLevel(at: latestSample.date, for: protocolToCalibrate, using: profile.calibrationFactor)
        
        guard modelPrediction > 0.01 else {
            print("Model prediction too low, cannot calibrate.")
            return
        }
        
        let adjustmentRatio = latestSample.value / modelPrediction
        profile.calibrationFactor *= adjustmentRatio
        
        recalcSimulation()
        saveProfile()
    }
    
    func calibrateProtocolWithBayesian(_ protocolToCalibrate: InjectionProtocol) {
        // Only proceed if protocol has blood samples and we can find matching compound
        guard !protocolToCalibrate.bloodSamples.isEmpty,
              let compound = compoundFromEster(protocolToCalibrate.ester) else {
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
} 