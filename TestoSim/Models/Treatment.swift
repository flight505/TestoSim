import Foundation

/// Represents a unified treatment model that combines protocol and cycle concepts
/// with support for both simple and advanced treatments
struct Treatment: Identifiable, Codable {
    // MARK: - Core Properties
    var id: UUID = UUID()
    var name: String
    var startDate: Date
    var notes: String?
    
    // MARK: - Type Discrimination
    enum TreatmentType: String, Codable {
        case simple    // Single compound or blend with fixed schedule (former "Protocol")
        case advanced  // Multi-stage treatment with varying compounds/doses (former "Cycle")
    }
    
    let treatmentType: TreatmentType
    
    // MARK: - Simple Treatment Properties
    // Only relevant when treatmentType is .simple
    var doseMg: Double?
    var frequencyDays: Double?
    var compoundID: UUID?
    var blendID: UUID?
    var selectedRoute: String?
    var bloodSamples: [BloodSample]?
    
    // MARK: - Advanced Treatment Properties
    // Only relevant when treatmentType is .advanced
    var totalWeeks: Int?
    var stages: [TreatmentStage]?
    
    // MARK: - Computed Properties
    
    var endDate: Date {
        switch treatmentType {
        case .simple:
            // For simple treatments, show at least 90 days from start
            return Calendar.current.date(byAdding: .day, value: 90, to: startDate) ?? startDate
        case .advanced:
            // For advanced treatments, calculate from total weeks
            guard let weeks = totalWeeks else { return startDate }
            return Calendar.current.date(byAdding: .day, value: weeks * 7, to: startDate) ?? startDate
        }
    }
    
    // Determine if this is a compound or blend-based treatment (simple type only)
    var contentType: ContentType? {
        guard treatmentType == .simple else { return nil }
        
        if compoundID != nil {
            return .compound
        } else if blendID != nil {
            return .blend
        }
        return nil
    }
    
    enum ContentType: String, Codable {
        case compound
        case blend
    }
    
    // MARK: - Methods for Simple Treatments
    
    /// Calculate injection dates for a simple treatment
    func injectionDates(from simulationStartDate: Date, upto endDate: Date) -> [Date] {
        guard treatmentType == .simple, 
              let frequency = frequencyDays, frequency > 0 else { 
            return [] 
        }
        
        var dates: [Date] = []
        var current = startDate
        var injectionIndex = 0
        
        // Calculate how many injections would have occurred before simulation start
        if simulationStartDate > startDate {
            let daysSinceStart = simulationStartDate.timeIntervalSince(startDate) / (24 * 3600)
            injectionIndex = Int(floor(daysSinceStart / frequency))
            // Set current to the first injection on or after simulationStartDate
            current = startDate.addingTimeInterval(Double(injectionIndex) * frequency * 24 * 3600)
        }
        
        // Add all injections from current date up to endDate
        while current <= endDate {
            dates.append(current)
            
            injectionIndex += 1
            current = startDate.addingTimeInterval(Double(injectionIndex) * frequency * 24 * 3600)
            
            // Safety break to prevent infinite loops
            if injectionIndex > 10000 { 
                print("Safety break in injection dates calculation")
                break 
            }
        }
        
        return dates
    }
    
    // MARK: - Methods for Advanced Treatments
    
    /// Generate temporary simple treatments from an advanced treatment's stages
    func generateSimpleTreatments(compoundLibrary: CompoundLibrary) -> [Treatment] {
        guard treatmentType == .advanced, let stages = stages else { return [] }
        
        // Each stage will create one or more treatments
        return stages.flatMap { stage in
            stage.generateTreatments(treatmentStartDate: startDate)
        }
    }
    
    // MARK: - Initialization From Legacy Models
    
    /// Create a Treatment from a legacy Protocol model
    init(from legacyProtocol: InjectionProtocol) {
        self.id = legacyProtocol.id
        self.name = legacyProtocol.name
        self.startDate = legacyProtocol.startDate
        self.notes = legacyProtocol.notes
        self.treatmentType = .simple
        
        // Simple treatment properties
        self.doseMg = legacyProtocol.doseMg
        self.frequencyDays = legacyProtocol.frequencyDays
        self.compoundID = legacyProtocol.compoundID
        self.blendID = legacyProtocol.blendID
        self.selectedRoute = legacyProtocol.selectedRoute
        self.bloodSamples = legacyProtocol.bloodSamples
        
        // Advanced properties are nil for simple treatments
        self.totalWeeks = nil
        self.stages = nil
    }
    
    /// Create a Treatment from a legacy Cycle model
    init(from legacyCycle: Cycle) {
        self.id = legacyCycle.id
        self.name = legacyCycle.name
        self.startDate = legacyCycle.startDate
        self.notes = legacyCycle.notes
        self.treatmentType = .advanced
        
        // Advanced treatment properties
        self.totalWeeks = legacyCycle.totalWeeks
        self.stages = legacyCycle.stages.map { TreatmentStage(from: $0) }
        
        // Simple properties are nil for advanced treatments
        self.doseMg = nil
        self.frequencyDays = nil
        self.compoundID = nil
        self.blendID = nil
        self.selectedRoute = nil
        self.bloodSamples = nil
    }
    
    // MARK: - Conversion to Legacy Models
    
    /// Convert this Treatment to a legacy Protocol model (if simple type)
    func toLegacyProtocol() -> InjectionProtocol? {
        guard treatmentType == .simple,
              let doseMg = doseMg,
              let frequencyDays = frequencyDays else {
            return nil
        }
        
        var protocol_ = InjectionProtocol(
            id: id,
            name: name,
            doseMg: doseMg,
            frequencyDays: frequencyDays,
            startDate: startDate,
            notes: notes
        )
        
        // Set other properties
        protocol_.compoundID = compoundID
        protocol_.blendID = blendID
        protocol_.selectedRoute = selectedRoute
        protocol_.bloodSamples = bloodSamples ?? []
        
        return protocol_
    }
    
    /// Convert this Treatment to a legacy Cycle model (if advanced type)
    func toLegacyCycle() -> Cycle? {
        guard treatmentType == .advanced,
              let totalWeeks = totalWeeks,
              let stages = stages else {
            return nil
        }
        
        var cycle = Cycle(
            id: id,
            name: name,
            startDate: startDate,
            totalWeeks: totalWeeks,
            notes: notes
        )
        
        // Convert stages
        cycle.stages = stages.map { $0.toLegacyCycleStage() }
        
        return cycle
    }
}

/// Represents a stage within an advanced treatment
struct TreatmentStage: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var startWeek: Int  // Week number in the treatment (0-based)
    var durationWeeks: Int
    var compounds: [CompoundStageItem] = []
    var blends: [BlendStageItem] = []
    
    /// Start date calculated from treatment start date and stage's start week
    func startDate(from treatmentStartDate: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: startWeek * 7, to: treatmentStartDate) ?? treatmentStartDate
    }
    
    /// End date calculated from start date and duration
    func endDate(from treatmentStartDate: Date) -> Date {
        let start = startDate(from: treatmentStartDate)
        return Calendar.current.date(byAdding: .day, value: durationWeeks * 7, to: start) ?? start
    }
    
    /// Generates simple treatments for this stage
    func generateTreatments(treatmentStartDate: Date) -> [Treatment] {
        var treatments: [Treatment] = []
        
        // Add compound treatments
        for compoundItem in compounds {
            let name = "\(self.name) - \(compoundItem.compoundName)"
            var treatment = Treatment(
                name: name,
                startDate: startDate(from: treatmentStartDate),
                notes: "Part of treatment: \(self.name)",
                treatmentType: .simple
            )
            
            // Set simple treatment properties
            treatment.doseMg = compoundItem.doseMg
            treatment.frequencyDays = compoundItem.frequencyDays
            treatment.compoundID = compoundItem.compoundID
            treatment.selectedRoute = compoundItem.administrationRoute
            
            treatments.append(treatment)
        }
        
        // Add blend treatments
        for blendItem in blends {
            let name = "\(self.name) - \(blendItem.blendName)"
            var treatment = Treatment(
                name: name,
                startDate: startDate(from: treatmentStartDate),
                notes: "Part of treatment: \(self.name)",
                treatmentType: .simple
            )
            
            // Set simple treatment properties
            treatment.doseMg = blendItem.doseMg
            treatment.frequencyDays = blendItem.frequencyDays
            treatment.blendID = blendItem.blendID
            treatment.selectedRoute = blendItem.administrationRoute
            
            treatments.append(treatment)
        }
        
        return treatments
    }
    
    /// Create a TreatmentStage from a legacy CycleStage
    init(from legacyStage: CycleStage) {
        self.id = legacyStage.id
        self.name = legacyStage.name
        self.startWeek = legacyStage.startWeek
        self.durationWeeks = legacyStage.durationWeeks
        self.compounds = legacyStage.compounds
        self.blends = legacyStage.blends
    }
    
    /// Convert to legacy CycleStage
    func toLegacyCycleStage() -> CycleStage {
        var stage = CycleStage(
            id: id,
            name: name,
            startWeek: startWeek,
            durationWeeks: durationWeeks
        )
        
        stage.compounds = compounds
        stage.blends = blends
        
        return stage
    }
}

// MARK: - Extension for Effect Indices

extension Treatment {
    /// Calculate anabolic effect index
    func calculateAnabolicEffectIndex(using library: CompoundLibrary) -> Double {
        switch treatmentType {
        case .simple:
            // For simple treatments, calculate based on compound or blend
            if let compoundID = compoundID, let compound = library.compound(withID: compoundID) {
                return calculateAnabolicIndexForCompound(compound, doseMg: doseMg ?? 0, frequencyDays: frequencyDays ?? 0)
            } else if let blendID = blendID, let blend = library.blend(withID: blendID) {
                let components = blend.resolvedComponents(using: library)
                return components.reduce(0.0) { sum, component in
                    // Calculate each component's contribution
                    let componentDose = (doseMg ?? 0) * (component.mgPerML / blend.totalConcentration)
                    return sum + calculateAnabolicIndexForCompound(component.compound, doseMg: componentDose, frequencyDays: frequencyDays ?? 0)
                }
            }
            return 0
            
        case .advanced:
            // For advanced treatments, calculate based on all stages and compounds
            guard let stages = stages else { return 0 }
            
            var totalIndex = 0.0
            var totalDuration = 0
            
            for stage in stages {
                var stageIndex = 0.0
                
                // Add compound contributions
                for compound in stage.compounds {
                    if let actualCompound = library.compound(withID: compound.compoundID) {
                        stageIndex += calculateAnabolicIndexForCompound(
                            actualCompound,
                            doseMg: compound.doseMg,
                            frequencyDays: compound.frequencyDays
                        )
                    }
                }
                
                // Add blend contributions
                for blend in stage.blends {
                    if let actualBlend = library.blend(withID: blend.blendID) {
                        let components = actualBlend.resolvedComponents(using: library)
                        for component in components {
                            let componentDose = blend.doseMg * (component.mgPerML / actualBlend.totalConcentration)
                            stageIndex += calculateAnabolicIndexForCompound(
                                component.compound,
                                doseMg: componentDose,
                                frequencyDays: blend.frequencyDays
                            )
                        }
                    }
                }
                
                // Weight by stage duration
                totalIndex += stageIndex * Double(stage.durationWeeks)
                totalDuration += stage.durationWeeks
            }
            
            // Return average across all stages, weighted by duration
            return totalDuration > 0 ? totalIndex / Double(totalDuration) : 0
        }
    }
    
    /// Calculate androgenic effect index
    func calculateAndrogenicEffectIndex(using library: CompoundLibrary) -> Double {
        switch treatmentType {
        case .simple:
            // For simple treatments, calculate based on compound or blend
            if let compoundID = compoundID, let compound = library.compound(withID: compoundID) {
                return calculateAndrogenicIndexForCompound(compound, doseMg: doseMg ?? 0, frequencyDays: frequencyDays ?? 0)
            } else if let blendID = blendID, let blend = library.blend(withID: blendID) {
                let components = blend.resolvedComponents(using: library)
                return components.reduce(0.0) { sum, component in
                    // Calculate each component's contribution
                    let componentDose = (doseMg ?? 0) * (component.mgPerML / blend.totalConcentration)
                    return sum + calculateAndrogenicIndexForCompound(component.compound, doseMg: componentDose, frequencyDays: frequencyDays ?? 0)
                }
            }
            return 0
            
        case .advanced:
            // For advanced treatments, calculate based on all stages and compounds
            guard let stages = stages else { return 0 }
            
            var totalIndex = 0.0
            var totalDuration = 0
            
            for stage in stages {
                var stageIndex = 0.0
                
                // Add compound contributions
                for compound in stage.compounds {
                    if let actualCompound = library.compound(withID: compound.compoundID) {
                        stageIndex += calculateAndrogenicIndexForCompound(
                            actualCompound,
                            doseMg: compound.doseMg,
                            frequencyDays: compound.frequencyDays
                        )
                    }
                }
                
                // Add blend contributions
                for blend in stage.blends {
                    if let actualBlend = library.blend(withID: blend.blendID) {
                        let components = actualBlend.resolvedComponents(using: library)
                        for component in components {
                            let componentDose = blend.doseMg * (component.mgPerML / actualBlend.totalConcentration)
                            stageIndex += calculateAndrogenicIndexForCompound(
                                component.compound,
                                doseMg: componentDose,
                                frequencyDays: blend.frequencyDays
                            )
                        }
                    }
                }
                
                // Weight by stage duration
                totalIndex += stageIndex * Double(stage.durationWeeks)
                totalDuration += stage.durationWeeks
            }
            
            // Return average across all stages, weighted by duration
            return totalDuration > 0 ? totalIndex / Double(totalDuration) : 0
        }
    }
    
    // Helper methods for effect calculations
    
    private func calculateAnabolicIndexForCompound(_ compound: Compound, doseMg: Double, frequencyDays: Double) -> Double {
        // Base calculation on compound type, dose, and frequency
        let weeklyDose = frequencyDays > 0 ? doseMg * (7.0 / frequencyDays) : 0
        
        // Different multipliers based on compound class
        var anabolicMultiplier = 1.0
        
        switch compound.classType {
        case .testosterone:
            anabolicMultiplier = 1.0
        case .nandrolone:
            anabolicMultiplier = 1.25
        case .trenbolone:
            anabolicMultiplier = 5.0
        case .boldenone:
            anabolicMultiplier = 1.0
        case .drostanolone:
            anabolicMultiplier = 0.65
        case .stanozolol:
            anabolicMultiplier = 2.0
        case .metenolone:
            anabolicMultiplier = 0.88
        case .trestolone:
            anabolicMultiplier = 2.3
        case .dhb:
            anabolicMultiplier = 1.55
        }
        
        return weeklyDose * anabolicMultiplier
    }
    
    private func calculateAndrogenicIndexForCompound(_ compound: Compound, doseMg: Double, frequencyDays: Double) -> Double {
        // Base calculation on compound type, dose, and frequency
        let weeklyDose = frequencyDays > 0 ? doseMg * (7.0 / frequencyDays) : 0
        
        // Different multipliers based on compound class
        var androgenicMultiplier = 1.0
        
        switch compound.classType {
        case .testosterone:
            androgenicMultiplier = 1.0
        case .nandrolone:
            androgenicMultiplier = 0.37
        case .trenbolone:
            androgenicMultiplier = 5.0
        case .boldenone:
            androgenicMultiplier = 0.5
        case .drostanolone:
            androgenicMultiplier = 1.25
        case .stanozolol:
            androgenicMultiplier = 0.6
        case .metenolone:
            androgenicMultiplier = 0.44
        case .trestolone:
            androgenicMultiplier = 1.5
        case .dhb:
            androgenicMultiplier = 0.65
        }
        
        return weeklyDose * androgenicMultiplier
    }
}