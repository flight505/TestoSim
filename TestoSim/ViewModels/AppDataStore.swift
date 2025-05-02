import Foundation
import SwiftUI

@MainActor
class AppDataStore: ObservableObject {
    @Published var profile: UserProfile
    @Published var simulationData: [DataPoint] = []
    @Published var selectedProtocolID: UUID?
    @Published var isPresentingProtocolForm = false
    @Published var protocolToEdit: InjectionProtocol?
    
    let simulationDurationDays: Double = 90.0
    
    var simulationEndDate: Date {
        guard let selectedProtocolID = selectedProtocolID,
              let selectedProtocol = profile.protocols.first(where: { $0.id == selectedProtocolID }) else {
            return Date().addingTimeInterval(simulationDurationDays * 24 * 3600)
        }
        return selectedProtocol.startDate.addingTimeInterval(simulationDurationDays * 24 * 3600)
    }
    
    init() {
        // Try to load profile from UserDefaults
        if let savedData = UserDefaults.standard.data(forKey: "userProfileData"),
           let decodedProfile = try? JSONDecoder().decode(UserProfile.self, from: savedData) {
            self.profile = decodedProfile
        } else {
            // Create default profile with a sample protocol
            self.profile = UserProfile()
            let defaultProtocol = InjectionProtocol(
                name: "Default TRT",
                ester: .cypionate,
                doseMg: 100.0,
                frequencyDays: 7.0,
                startDate: Date()
            )
            self.profile.protocols.append(defaultProtocol)
        }
        
        // Set initial selected protocol
        if !profile.protocols.isEmpty {
            selectedProtocolID = profile.protocols[0].id
        }
        
        // Generate initial simulation data
        recalcSimulation()
    }
    
    func saveProfile() {
        if let encodedData = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encodedData, forKey: "userProfileData")
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