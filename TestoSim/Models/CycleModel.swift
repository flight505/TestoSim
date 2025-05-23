import Foundation

/// Represents a complete treatment cycle with multiple stages
struct Cycle: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var startDate: Date
    var totalWeeks: Int
    var notes: String?
    var stages: [CycleStage] = []
    
    /// Calculated end date based on start date and total weeks
    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: totalWeeks * 7, to: startDate) ?? startDate
    }
    
    /// Converts this cycle to a set of temporary InjectionProtocols for simulation
    func generateTemporaryProtocols(compoundLibrary: CompoundLibrary) -> [InjectionProtocol] {
        // Each stage will create one or more protocols
        return stages.flatMap { stage in
            stage.generateProtocols(cycleStartDate: startDate, compoundLibrary: compoundLibrary)
        }
    }
}

/// Represents a single stage in a cycle with specific compounds/blends and timing
struct CycleStage: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var startWeek: Int  // Week number in the cycle (0-based)
    var durationWeeks: Int
    var compounds: [CompoundStageItem] = []
    var blends: [BlendStageItem] = []
    
    /// Start date calculated from cycle start date and stage's start week
    func startDate(from cycleStartDate: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: startWeek * 7, to: cycleStartDate) ?? cycleStartDate
    }
    
    /// End date calculated from start date and duration
    func endDate(from cycleStartDate: Date) -> Date {
        let start = startDate(from: cycleStartDate)
        return Calendar.current.date(byAdding: .day, value: durationWeeks * 7, to: start) ?? start
    }
    
    /// Generates temporary protocols for each compound and blend in this stage
    func generateProtocols(cycleStartDate: Date, compoundLibrary: CompoundLibrary) -> [InjectionProtocol] {
        var protocols: [InjectionProtocol] = []
        
        // Add compound protocols
        for compoundItem in compounds {
            let name = "\(self.name) - \(compoundItem.compoundName)"
            let treatmentProtocol = InjectionProtocol(
                name: name,
                doseMg: compoundItem.doseMg,
                frequencyDays: compoundItem.frequencyDays,
                startDate: startDate(from: cycleStartDate),
                notes: "Part of cycle: \(self.name)",
                compoundID: compoundItem.compoundID,
                selectedRoute: compoundItem.administrationRoute
            )
            protocols.append(treatmentProtocol)
        }
        
        // Add blend protocols
        for blendItem in blends {
            let name = "\(self.name) - \(blendItem.blendName)"
            let treatmentProtocol = InjectionProtocol(
                name: name,
                doseMg: blendItem.doseMg,
                frequencyDays: blendItem.frequencyDays,
                startDate: startDate(from: cycleStartDate),
                notes: "Part of cycle: \(self.name)",
                blendID: blendItem.blendID,
                selectedRoute: blendItem.administrationRoute
            )
            protocols.append(treatmentProtocol)
        }
        
        return protocols
    }
}

/// Represents a single compound item within a cycle stage
struct CompoundStageItem: Identifiable, Codable {
    var id: UUID = UUID()
    var compoundID: UUID
    var compoundName: String
    var doseMg: Double
    var frequencyDays: Double
    var administrationRoute: String // Compound.Route.rawValue
}

/// Represents a single blend item within a cycle stage
struct BlendStageItem: Identifiable, Codable {
    var id: UUID = UUID()
    var blendID: UUID
    var blendName: String
    var doseMg: Double
    var frequencyDays: Double
    var administrationRoute: String // Compound.Route.rawValue
} 