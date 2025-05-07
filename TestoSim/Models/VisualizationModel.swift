import Foundation

/// Defines the data structure for multi-layered treatment visualization
struct VisualizationModel {
    // MARK: - Layer Types
    
    /// Represents the type of visualization layer
    enum LayerType: String, Codable, CaseIterable {
        case compoundCurve      // Individual compound concentration
        case totalCurve         // Combined concentration of all compounds
        case anabolicIndex      // Anabolic effect index
        case androgenicIndex    // Androgenic effect index
    }
    
    // MARK: - Layer Definitions
    
    /// Represents a single visualization layer
    struct Layer: Identifiable {
        let id: UUID = UUID()
        let type: LayerType
        let name: String
        let color: String  // Color as hex string
        var opacity: Double
        var isVisible: Bool
        var data: [DataPoint]
        
        /// Normalized data points (0.0-1.0 range)
        var normalizedData: [DataPoint] {
            guard !data.isEmpty else { return [] }
            
            let maxLevel = data.map { $0.level }.max() ?? 1.0
            guard maxLevel > 0 else { return data }
            
            return data.map { DataPoint(time: $0.time, level: $0.level / maxLevel) }
        }
    }
    
    // MARK: - Properties
    
    var layers: [Layer] = []
    var startDate: Date
    var endDate: Date
    var baseUnit: String
    
    // MARK: - Initialization
    
    init(startDate: Date, endDate: Date, baseUnit: String = "ng/dL") {
        self.startDate = startDate
        self.endDate = endDate
        self.baseUnit = baseUnit
    }
    
    // MARK: - Methods
    
    /// Add a layer to the visualization
    mutating func addLayer(type: LayerType, name: String, color: String, data: [DataPoint], isVisible: Bool = true, opacity: Double = 1.0) {
        let layer = Layer(
            type: type,
            name: name,
            color: color,
            opacity: opacity,
            isVisible: isVisible,
            data: data
        )
        layers.append(layer)
    }
    
    /// Update the visibility of a layer
    mutating func updateLayerVisibility(id: UUID, isVisible: Bool) {
        if let index = layers.firstIndex(where: { $0.id == id }) {
            layers[index].isVisible = isVisible
        }
    }
    
    /// Update the opacity of a layer
    mutating func updateLayerOpacity(id: UUID, opacity: Double) {
        if let index = layers.firstIndex(where: { $0.id == id }) {
            layers[index].opacity = min(1.0, max(0.0, opacity))
        }
    }
    
    /// Move a layer to a new position
    mutating func moveLayer(from source: Int, to destination: Int) {
        guard source >= 0, source < layers.count, 
              destination >= 0, destination < layers.count, 
              source != destination else {
            return
        }
        
        let layer = layers.remove(at: source)
        layers.insert(layer, at: destination)
    }
    
    /// Move a layer up in the order (rendered on top)
    mutating func moveLayerUp(id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }), index > 0 else {
            return
        }
        moveLayer(from: index, to: index - 1)
    }
    
    /// Move a layer down in the order (rendered below)
    mutating func moveLayerDown(id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }), index < layers.count - 1 else {
            return
        }
        moveLayer(from: index, to: index + 1)
    }
    
    /// Get all layers of a specific type
    func layers(ofType type: LayerType) -> [Layer] {
        return layers.filter { $0.type == type }
    }
    
    /// Get only visible layers
    var visibleLayers: [Layer] {
        return layers.filter { $0.isVisible }
    }
    
    /// Calculate statistics for the visualization
    func calculateStatistics() -> VisualizationStatistics {
        // Calculate max values for each layer type
        let compoundMax = layers(ofType: .compoundCurve).flatMap { $0.data }.map { $0.level }.max() ?? 0
        let totalMax = layers(ofType: .totalCurve).flatMap { $0.data }.map { $0.level }.max() ?? 0
        let anabolicMax = layers(ofType: .anabolicIndex).flatMap { $0.data }.map { $0.level }.max() ?? 0
        let androgenicMax = layers(ofType: .androgenicIndex).flatMap { $0.data }.map { $0.level }.max() ?? 0
        
        // Calculate average values for effect indices
        let anabolicValues = layers(ofType: .anabolicIndex).flatMap { $0.data }.map { $0.level }
        let androgenicValues = layers(ofType: .androgenicIndex).flatMap { $0.data }.map { $0.level }
        
        let anabolicAvg = anabolicValues.isEmpty ? 0 : anabolicValues.reduce(0, +) / Double(anabolicValues.count)
        let androgenicAvg = androgenicValues.isEmpty ? 0 : androgenicValues.reduce(0, +) / Double(androgenicValues.count)
        
        // Calculate ratio if both values are valid
        let effectRatio = androgenicAvg > 0 ? anabolicAvg / androgenicAvg : 0
        
        return VisualizationStatistics(
            maxConcentration: totalMax,
            maxCompoundConcentration: compoundMax,
            maxAnabolicIndex: anabolicMax,
            maxAndrogenicIndex: androgenicMax,
            averageAnabolicIndex: anabolicAvg,
            averageAndrogenicIndex: androgenicAvg,
            anabolicToAndrogenicRatio: effectRatio
        )
    }
}

/// Statistics for the visualization model
struct VisualizationStatistics {
    let maxConcentration: Double
    let maxCompoundConcentration: Double
    let maxAnabolicIndex: Double
    let maxAndrogenicIndex: Double
    let averageAnabolicIndex: Double
    let averageAndrogenicIndex: Double
    let anabolicToAndrogenicRatio: Double
}

/// Factory for creating visualization models from treatments
class VisualizationFactory {
    let compoundLibrary: CompoundLibrary
    let pkModel: PKModel
    
    init(compoundLibrary: CompoundLibrary, pkModel: PKModel) {
        self.compoundLibrary = compoundLibrary
        self.pkModel = pkModel
    }
    
    /// Create a visualization model for a single treatment
    func createVisualization(for treatment: Treatment, weight: Double, calibrationFactor: Double, unit: String) -> VisualizationModel {
        var model = VisualizationModel(
            startDate: treatment.startDate,
            endDate: treatment.endDate,
            baseUnit: unit
        )
        
        switch treatment.treatmentType {
        case .simple:
            addLayersForSimpleTreatment(treatment, to: &model, weight: weight, calibrationFactor: calibrationFactor)
        case .advanced:
            addLayersForAdvancedTreatment(treatment, to: &model, weight: weight, calibrationFactor: calibrationFactor)
        }
        
        return model
    }
    
    /// Add visualization layers for a simple treatment
    private func addLayersForSimpleTreatment(_ treatment: Treatment, to model: inout VisualizationModel, weight: Double, calibrationFactor: Double) {
        guard let doseMg = treatment.doseMg,
              let _ = treatment.frequencyDays else {
            return
        }
        
        // Determine route
        let route: Compound.Route
        if let routeString = treatment.selectedRoute, let selectedRoute = Compound.Route(rawValue: routeString) {
            route = selectedRoute
        } else {
            route = .intramuscular
        }
        
        // Generate time points for the chart (one point per day)
        let calendar = Calendar.current
        let daysBetween = calendar.dateComponents([.day], from: treatment.startDate, to: treatment.endDate).day ?? 90
        let simulationDates = (0...daysBetween).map { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: treatment.startDate) ?? treatment.startDate
        }
        
        // Generate injection dates
        let injectionDates = treatment.injectionDates(
            from: treatment.startDate,
            upto: treatment.endDate
        )
        
        // Handle compound or blend based treatment
        if let compoundID = treatment.compoundID, let compound = compoundLibrary.compound(withID: compoundID) {
            // Create individual compound layer
            let compoundConcentrations = pkModel.protocolConcentrations(
                at: simulationDates,
                injectionDates: injectionDates,
                compounds: [(compound: compound, dosePerInjectionMg: doseMg)],
                route: route,
                weight: weight,
                calibrationFactor: calibrationFactor
            )
            
            // Add compound curve layer
            let compoundData = zip(simulationDates, compoundConcentrations).map { DataPoint(time: $0, level: $1) }
            model.addLayer(
                type: .compoundCurve,
                name: compound.fullDisplayName,
                color: "4285F4", // Blue
                data: compoundData
            )
            
            // Add total curve layer (same as compound for single compound treatments)
            model.addLayer(
                type: .totalCurve,
                name: "Total Concentration",
                color: "34A853", // Green
                data: compoundData
            )
            
            // Add anabolic index layer
            let anabolicIndex = treatment.calculateAnabolicEffectIndex(using: compoundLibrary)
            let anabolicData = simulationDates.map { DataPoint(time: $0, level: anabolicIndex) }
            model.addLayer(
                type: .anabolicIndex,
                name: "Anabolic Effect",
                color: "FBBC05", // Yellow
                data: anabolicData,
                isVisible: false,
                opacity: 0.7
            )
            
            // Add androgenic index layer
            let androgenicIndex = treatment.calculateAndrogenicEffectIndex(using: compoundLibrary)
            let androgenicData = simulationDates.map { DataPoint(time: $0, level: androgenicIndex) }
            model.addLayer(
                type: .androgenicIndex,
                name: "Androgenic Effect",
                color: "EA4335", // Red
                data: androgenicData,
                isVisible: false,
                opacity: 0.7
            )
            
        } else if let blendID = treatment.blendID, let blend = compoundLibrary.blend(withID: blendID) {
            // For blends, we need to create a layer for each component
            let components = blend.resolvedComponents(using: compoundLibrary)
            guard !components.isEmpty, blend.totalConcentration > 0 else { return }
            
            // Create array to accumulate total concentration
            var totalConcentrations = Array(repeating: 0.0, count: simulationDates.count)
            
            // Process each component
            for component in components {
                let componentDose = doseMg * (component.mgPerML / blend.totalConcentration)
                
                // Calculate concentration for this component
                let componentConcentrations = pkModel.protocolConcentrations(
                    at: simulationDates,
                    injectionDates: injectionDates,
                    compounds: [(compound: component.compound, dosePerInjectionMg: componentDose)],
                    route: route,
                    weight: weight,
                    calibrationFactor: calibrationFactor
                )
                
                // Add component curve layer
                let componentData = zip(simulationDates, componentConcentrations).map { DataPoint(time: $0, level: $1) }
                model.addLayer(
                    type: .compoundCurve,
                    name: component.compound.fullDisplayName,
                    color: getColorForCompound(component.compound), // Get a unique color for each component
                    data: componentData,
                    opacity: 0.8
                )
                
                // Accumulate for total
                for i in 0..<min(totalConcentrations.count, componentConcentrations.count) {
                    totalConcentrations[i] += componentConcentrations[i]
                }
            }
            
            // Add total curve layer
            let totalData = zip(simulationDates, totalConcentrations).map { DataPoint(time: $0, level: $1) }
            model.addLayer(
                type: .totalCurve,
                name: "Total Concentration",
                color: "34A853", // Green
                data: totalData
            )
            
            // Add anabolic index layer
            let anabolicIndex = treatment.calculateAnabolicEffectIndex(using: compoundLibrary)
            let anabolicData = simulationDates.map { DataPoint(time: $0, level: anabolicIndex) }
            model.addLayer(
                type: .anabolicIndex,
                name: "Anabolic Effect",
                color: "FBBC05", // Yellow
                data: anabolicData,
                isVisible: false,
                opacity: 0.7
            )
            
            // Add androgenic index layer
            let androgenicIndex = treatment.calculateAndrogenicEffectIndex(using: compoundLibrary)
            let androgenicData = simulationDates.map { DataPoint(time: $0, level: androgenicIndex) }
            model.addLayer(
                type: .androgenicIndex,
                name: "Androgenic Effect",
                color: "EA4335", // Red
                data: androgenicData,
                isVisible: false,
                opacity: 0.7
            )
        }
    }
    
    /// Add visualization layers for an advanced treatment
    private func addLayersForAdvancedTreatment(_ treatment: Treatment, to model: inout VisualizationModel, weight: Double, calibrationFactor: Double) {
        // Generate simple treatments from this advanced treatment
        let simpleTreatments = treatment.generateSimpleTreatments(compoundLibrary: compoundLibrary)
        
        // Generate time points for the chart (one point per day)
        let calendar = Calendar.current
        let daysBetween = calendar.dateComponents([.day], from: treatment.startDate, to: treatment.endDate).day ?? 90
        let simulationDates = (0...daysBetween).map { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: treatment.startDate) ?? treatment.startDate
        }
        
        // Create array to accumulate total concentration
        var totalConcentrations = Array(repeating: 0.0, count: simulationDates.count)
        
        // Process each simple treatment
        for simpleTreatment in simpleTreatments {
            if let doseMg = simpleTreatment.doseMg,
               let _ = simpleTreatment.frequencyDays {
                
                // Determine route
                let route: Compound.Route
                if let routeString = simpleTreatment.selectedRoute, let selectedRoute = Compound.Route(rawValue: routeString) {
                    route = selectedRoute
                } else {
                    route = .intramuscular
                }
                
                // Generate injection dates for this specific treatment
                let treatmentEndDate = min(simpleTreatment.endDate, treatment.endDate)
                let injectionDates = simpleTreatment.injectionDates(
                    from: simpleTreatment.startDate,
                    upto: treatmentEndDate
                )
                
                // Handle compound or blend based treatment
                if let compoundID = simpleTreatment.compoundID, let compound = compoundLibrary.compound(withID: compoundID) {
                    // Calculate concentration for this compound
                    let compoundConcentrations = pkModel.protocolConcentrations(
                        at: simulationDates,
                        injectionDates: injectionDates,
                        compounds: [(compound: compound, dosePerInjectionMg: doseMg)],
                        route: route,
                        weight: weight,
                        calibrationFactor: calibrationFactor
                    )
                    
                    // Add component curve layer
                    let compoundData = zip(simulationDates, compoundConcentrations).map { DataPoint(time: $0, level: $1) }
                    let stageName = simpleTreatment.notes?.replacingOccurrences(of: "Part of treatment: ", with: "") ?? "Unknown Stage"
                    model.addLayer(
                        type: .compoundCurve,
                        name: "\(stageName) - \(compound.fullDisplayName)",
                        color: getColorForCompound(compound),
                        data: compoundData,
                        opacity: 0.8
                    )
                    
                    // Accumulate for total
                    for i in 0..<min(totalConcentrations.count, compoundConcentrations.count) {
                        totalConcentrations[i] += compoundConcentrations[i]
                    }
                    
                } else if let blendID = simpleTreatment.blendID, let blend = compoundLibrary.blend(withID: blendID) {
                    // For blends, we need to calculate for each component
                    let components = blend.resolvedComponents(using: compoundLibrary)
                    guard !components.isEmpty, blend.totalConcentration > 0 else { continue }
                    
                    // Process each component
                    for component in components {
                        let componentDose = doseMg * (component.mgPerML / blend.totalConcentration)
                        
                        // Calculate concentration for this component
                        let componentConcentrations = pkModel.protocolConcentrations(
                            at: simulationDates,
                            injectionDates: injectionDates,
                            compounds: [(compound: component.compound, dosePerInjectionMg: componentDose)],
                            route: route,
                            weight: weight,
                            calibrationFactor: calibrationFactor
                        )
                        
                        // Add component curve layer
                        let componentData = zip(simulationDates, componentConcentrations).map { DataPoint(time: $0, level: $1) }
                        let stageName = simpleTreatment.notes?.replacingOccurrences(of: "Part of treatment: ", with: "") ?? "Unknown Stage"
                        model.addLayer(
                            type: .compoundCurve,
                            name: "\(stageName) - \(component.compound.fullDisplayName)",
                            color: getColorForCompound(component.compound),
                            data: componentData,
                            opacity: 0.8
                        )
                        
                        // Accumulate for total
                        for i in 0..<min(totalConcentrations.count, componentConcentrations.count) {
                            totalConcentrations[i] += componentConcentrations[i]
                        }
                    }
                }
            }
        }
        
        // Add total curve layer
        let totalData = zip(simulationDates, totalConcentrations).map { DataPoint(time: $0, level: $1) }
        model.addLayer(
            type: .totalCurve,
            name: "Total Concentration",
            color: "34A853", // Green
            data: totalData
        )
        
        // Add anabolic and androgenic indices
        // For advanced treatments, these can vary over time based on stages
        if let stages = treatment.stages, !stages.isEmpty {
            var anabolicValues = Array(repeating: 0.0, count: simulationDates.count)
            var androgenicValues = Array(repeating: 0.0, count: simulationDates.count)
            
            // Calculate indices for each date based on active stages
            for (index, date) in simulationDates.enumerated() {
                let activeStages = stages.filter { stage in
                    let stageStart = stage.startDate(from: treatment.startDate)
                    let stageEnd = stage.endDate(from: treatment.startDate)
                    return date >= stageStart && date <= stageEnd
                }
                
                if !activeStages.isEmpty {
                    // Calculate combined indices from all active stages
                    var anabolicSum = 0.0
                    var androgenicSum = 0.0
                    
                    for stage in activeStages {
                        // Calculate stage's contribution to anabolic index
                        for compound in stage.compounds {
                            if let actualCompound = compoundLibrary.compound(withID: compound.compoundID) {
                                let weeklyDose = compound.frequencyDays > 0 ? compound.doseMg * (7.0 / compound.frequencyDays) : 0
                                anabolicSum += calculateAnabolicFactorForCompound(actualCompound) * weeklyDose
                                androgenicSum += calculateAndrogenicFactorForCompound(actualCompound) * weeklyDose
                            }
                        }
                        
                        for blend in stage.blends {
                            if let actualBlend = compoundLibrary.blend(withID: blend.blendID) {
                                let components = actualBlend.resolvedComponents(using: compoundLibrary)
                                for component in components {
                                    let componentDose = blend.doseMg * (component.mgPerML / actualBlend.totalConcentration)
                                    let weeklyDose = blend.frequencyDays > 0 ? componentDose * (7.0 / blend.frequencyDays) : 0
                                    anabolicSum += calculateAnabolicFactorForCompound(component.compound) * weeklyDose
                                    androgenicSum += calculateAndrogenicFactorForCompound(component.compound) * weeklyDose
                                }
                            }
                        }
                    }
                    
                    anabolicValues[index] = anabolicSum / Double(activeStages.count)
                    androgenicValues[index] = androgenicSum / Double(activeStages.count)
                }
            }
            
            // Add anabolic index layer
            let anabolicData = zip(simulationDates, anabolicValues).map { DataPoint(time: $0, level: $1) }
            model.addLayer(
                type: .anabolicIndex,
                name: "Anabolic Effect",
                color: "FBBC05", // Yellow
                data: anabolicData,
                isVisible: false,
                opacity: 0.7
            )
            
            // Add androgenic index layer
            let androgenicData = zip(simulationDates, androgenicValues).map { DataPoint(time: $0, level: $1) }
            model.addLayer(
                type: .androgenicIndex,
                name: "Androgenic Effect",
                color: "EA4335", // Red
                data: androgenicData,
                isVisible: false,
                opacity: 0.7
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get a color for a specific compound
    private func getColorForCompound(_ compound: Compound) -> String {
        // Map compound classes to colors
        switch compound.classType {
        case .testosterone:
            return "4285F4" // Blue
        case .nandrolone:
            return "0F9D58" // Dark Green
        case .trenbolone:
            return "DB4437" // Red
        case .boldenone:
            return "F4B400" // Yellow
        case .drostanolone:
            return "9C27B0" // Purple
        case .stanozolol:
            return "FF6D00" // Orange
        case .metenolone:
            return "795548" // Brown
        case .trestolone:
            return "607D8B" // Blue Gray
        case .dhb:
            return "009688" // Teal
        }
    }
    
    /// Calculate anabolic factor for a compound
    private func calculateAnabolicFactorForCompound(_ compound: Compound) -> Double {
        switch compound.classType {
        case .testosterone:
            return 1.0
        case .nandrolone:
            return 1.25
        case .trenbolone:
            return 5.0
        case .boldenone:
            return 1.0
        case .drostanolone:
            return 0.65
        case .stanozolol:
            return 2.0
        case .metenolone:
            return 0.88
        case .trestolone:
            return 2.3
        case .dhb:
            return 1.55
        }
    }
    
    /// Calculate androgenic factor for a compound
    private func calculateAndrogenicFactorForCompound(_ compound: Compound) -> Double {
        switch compound.classType {
        case .testosterone:
            return 1.0
        case .nandrolone:
            return 0.37
        case .trenbolone:
            return 5.0
        case .boldenone:
            return 0.5
        case .drostanolone:
            return 1.25
        case .stanozolol:
            return 0.6
        case .metenolone:
            return 0.44
        case .trestolone:
            return 1.5
        case .dhb:
            return 0.65
        }
    }
}