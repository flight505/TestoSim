import Foundation
import SwiftUI

/// Generates AI-powered insights for user's protocols and cycles
class AIInsightsGenerator: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether an insight request is currently in progress
    @Published var isLoading = false
    
    /// Latest generated insights
    @Published var latestInsights: Insights?
    
    /// Any error that occurred during the last insight generation
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    /// API Service for OpenAI
    private let openAIService = OpenAIService.shared
    
    /// Cache to store generated insights for each protocol
    private var insightsCache: [UUID: Insights] = [:]
    
    // MARK: - Initialization
    
    init() {
        // Initialization doesn't require anything specific
    }
    
    // MARK: - Public Methods
    
    /// Generate insights for a treatment
    /// - Parameters:
    ///   - treatment: The treatment to analyze
    ///   - profile: User profile data
    ///   - simulationData: Simulation data points
    ///   - compoundLibrary: Reference to compound library
    ///   - forceRefresh: Whether to force a refresh instead of using cached insights
    func generateInsights(
        for treatment: Treatment,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary,
        forceRefresh: Bool = false
    ) {
        // Check cache first unless refresh is forced
        if !forceRefresh, let cachedInsights = insightsCache[treatment.id] {
            self.latestInsights = cachedInsights
            return
        }
        
        isLoading = true
        error = nil
        
        // Ensure this is a simple treatment
        guard treatment.treatmentType == .simple else {
            // For advanced treatments, use the advanced version
            if treatment.treatmentType == .advanced {
                generateAdvancedTreatmentInsights(for: treatment, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
            }
            return
        }
        
        // Check if OpenAI API key is available
        if openAIService.hasAPIKey() {
            // Use OpenAI service for real insights
            // OpenAIService now supports the unified Treatment model directly
            openAIService.generateInsights(
                for: treatment,
                profile: profile,
                simulationData: simulationData,
                compoundLibrary: compoundLibrary
            ) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    switch result {
                    case .success(let insights):
                        // Cache the insights
                        self.insightsCache[treatment.id] = insights
                        self.latestInsights = insights
                        
                    case .failure(let error):
                        self.error = error
                        // Fall back to mock insights if API call fails
                        self.generateMockInsights(for: treatment, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
                    }
                }
            }
        } else {
            // Use mock implementation when API key is not available
            generateMockInsights(for: treatment, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
        }
    }
    
    /// Generate insights for an advanced treatment (previously known as cycle)
    /// - Parameters:
    ///   - treatment: The advanced treatment to analyze
    ///   - profile: User profile data
    ///   - simulationData: Treatment simulation data points
    ///   - compoundLibrary: Reference to compound library
    ///   - forceRefresh: Whether to force a refresh instead of using cached insights
    func generateAdvancedTreatmentInsights(
        for treatment: Treatment,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary,
        forceRefresh: Bool = false
    ) {
        // Ensure this is an advanced treatment
        guard treatment.treatmentType == .advanced else {
            // For simple treatments, use the simple version
            if treatment.treatmentType == .simple {
                generateInsights(for: treatment, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
            }
            return
        }
        
        // Check cache first unless refresh is forced
        if !forceRefresh, let cachedInsights = insightsCache[treatment.id] {
            self.latestInsights = cachedInsights
            return
        }
        
        isLoading = true
        error = nil
        
        // Check if OpenAI API key is available
        if openAIService.hasAPIKey() {
            // Use OpenAI service for real insights
            // OpenAIService now supports the unified Treatment model directly
            openAIService.generateAdvancedTreatmentInsights(
                for: treatment,
                profile: profile,
                simulationData: simulationData,
                compoundLibrary: compoundLibrary
            ) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    switch result {
                    case .success(let insights):
                        // Cache the insights
                        self.insightsCache[treatment.id] = insights
                        self.latestInsights = insights
                        
                    case .failure(let error):
                        self.error = error
                        // Fall back to mock insights if API call fails
                        self.generateMockAdvancedTreatmentInsights(for: treatment, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
                    }
                }
            }
        } else {
            // Use mock implementation when API key is not available
            generateMockAdvancedTreatmentInsights(for: treatment, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
        }
    }
    
    // Legacy method for backward compatibility
    // This will be removed once all code is migrated to the unified model
    @available(*, deprecated, message: "Use generateAdvancedTreatmentInsights instead")
    func generateCycleInsights(
        for cycle: Cycle,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary,
        forceRefresh: Bool = false
    ) {
        // Convert legacy cycle to unified Treatment
        let treatment = Treatment(from: cycle)
        
        // Use the new method
        generateAdvancedTreatmentInsights(
            for: treatment,
            profile: profile,
            simulationData: simulationData,
            compoundLibrary: compoundLibrary,
            forceRefresh: forceRefresh
        )
    }
    
    /// Clear all cached insights
    func clearCache() {
        insightsCache.removeAll()
        latestInsights = nil
    }
    
    /// Refreshes insights after API key change
    func refreshAfterAPIKeyChange() {
        // Clear the cache to force a refresh on next request
        clearCache()
        
        // Reset any error state
        error = nil
        
        // Clear the latest insights to prompt a new request
        latestInsights = nil
    }
    
    // MARK: - Private Methods
    
    /// Mock implementation for generating insights for simple treatments
    private func generateMockInsights(
        for treatment: Treatment,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary
    ) {
        // Ensure this is a simple treatment
        guard treatment.treatmentType == .simple else {
            // For advanced treatments, use the advanced version
            if treatment.treatmentType == .advanced {
                generateMockAdvancedTreatmentInsights(for: treatment, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
            }
            return
        }
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            // Create mock insights based on treatment type
            let insights = self.createMockInsightsForSimpleTreatment(treatment, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
            
            // Cache the insights
            self.insightsCache[treatment.id] = insights
            
            // Update published properties
            self.latestInsights = insights
            self.isLoading = false
        }
    }
    
    /// Mock implementation for generating advanced treatment insights
    private func generateMockAdvancedTreatmentInsights(
        for treatment: Treatment,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary
    ) {
        // Ensure this is an advanced treatment
        guard treatment.treatmentType == .advanced else {
            // For simple treatments, use the simple version
            if treatment.treatmentType == .simple {
                generateMockInsights(for: treatment, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
            }
            return
        }
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            // Create mock insights for the advanced treatment
            let insights = self.createMockInsightsForAdvancedTreatment(treatment, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
            
            // Cache the insights
            self.insightsCache[treatment.id] = insights
            
            // Update published properties
            self.latestInsights = insights
            self.isLoading = false
        }
    }
    
    // Legacy methods for backward compatibility
    // These will be removed once all code is migrated to the unified model
    
    @available(*, deprecated, message: "Use generateMockInsights with Treatment instead")
    private func generateMockInsights(
        for treatmentProtocol: InjectionProtocol,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary
    ) {
        // Convert legacy protocol to unified Treatment
        let treatment = Treatment(from: treatmentProtocol)
        
        // Use the new method
        generateMockInsights(
            for: treatment,
            profile: profile,
            simulationData: simulationData,
            compoundLibrary: compoundLibrary
        )
    }
    
    @available(*, deprecated, message: "Use generateMockAdvancedTreatmentInsights with Treatment instead")
    private func generateMockCycleInsights(
        for cycle: Cycle,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary
    ) {
        // Convert legacy cycle to unified Treatment
        let treatment = Treatment(from: cycle)
        
        // Use the new method
        generateMockAdvancedTreatmentInsights(
            for: treatment,
            profile: profile,
            simulationData: simulationData,
            compoundLibrary: compoundLibrary
        )
    }
    
    /// Creates mock insights for a simple treatment
    private func createMockInsightsForSimpleTreatment(
        _ treatment: Treatment,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary
    ) -> Insights {
        // Ensure this is a simple treatment
        guard treatment.treatmentType == .simple,
              let frequencyDays = treatment.frequencyDays,
              let contentType = treatment.contentType else {
            return Insights(title: "Invalid Treatment", summary: "This treatment type is not supported.", keyPoints: [])
        }
        
        // Extract treatment details
        let treatmentName = treatment.name
        var compoundOrBlendName = "Unknown"
        
        // Determine the compound or blend name
        if contentType == .compound, let compoundID = treatment.compoundID,
           let compound = compoundLibrary.compounds.first(where: { $0.id == compoundID }) {
            compoundOrBlendName = compound.commonName
            if let ester = compound.ester {
                compoundOrBlendName += " \(ester)"
            }
        } else if contentType == .blend, let blendID = treatment.blendID,
                  let blend = compoundLibrary.blends.first(where: { $0.id == blendID }) {
            compoundOrBlendName = blend.name
        }
        
        // Get simulation statistics
        let maxLevel = simulationData.map { $0.level }.max() ?? 0
        let minLevel = simulationData.map { $0.level }.min() ?? 0
        let avgLevel = simulationData.map { $0.level }.reduce(0, +) / Double(max(1, simulationData.count))
        let fluctuation = maxLevel > 0 ? (maxLevel - minLevel) / maxLevel * 100 : 0
        
        // Generate insights based on treatment characteristics
        var insights = Insights(
            title: "Insights for \(treatmentName)",
            summary: "Analysis of your \(compoundOrBlendName) treatment.",
            keyPoints: []
        )
        
        // Add blend explanation if it's a blend
        if contentType == .blend {
            insights.blendExplanation = createMockBlendExplanationForTreatment(treatment, compoundLibrary: compoundLibrary)
        }
        
        // Add key points based on treatment characteristics
        
        // 1. Frequency point
        if frequencyDays >= 7 {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Consider splitting your dose",
                    description: "Your current injection frequency of every \(frequencyDays) days leads to significant hormone fluctuations. Consider splitting your total dose into smaller, more frequent injections to achieve more stable hormone levels.",
                    type: .suggestion
                )
            )
        } else if frequencyDays <= 2 {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Good injection frequency",
                    description: "Your frequent injection schedule of every \(frequencyDays) days helps maintain stable hormone levels with minimal fluctuations.",
                    type: .positive
                )
            )
        }
        
        // 2. Fluctuation point
        if fluctuation > 40 {
            insights.keyPoints.append(
                KeyPoint(
                    title: "High level fluctuation",
                    description: "Your current treatment results in approximately \(fluctuation.isFinite ? Int(fluctuation) : 0)% fluctuation between peak and trough levels, which may lead to inconsistent symptoms and effects.",
                    type: .warning
                )
            )
        } else if fluctuation < 20 {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Stable hormone levels",
                    description: "Your treatment achieves excellent stability with only \(fluctuation.isFinite ? Int(fluctuation) : 0)% fluctuation between peak and trough levels.",
                    type: .positive
                )
            )
        }
        
        // 3. Overall level point
        let targetMin = 400.0 // Example target minimum
        let targetMax = 1000.0 // Example target maximum
        if avgLevel < targetMin {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Levels below typical target range",
                    description: "Your average level of \(avgLevel.isFinite ? Int(avgLevel) : 0) ng/dL is below the typical target range of \(targetMin.isFinite ? Int(targetMin) : 0)-\(targetMax.isFinite ? Int(targetMax) : 0) ng/dL. Consider discussing a dosage adjustment with your healthcare provider.",
                    type: .warning
                )
            )
        } else if avgLevel > targetMax {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Levels above typical target range",
                    description: "Your average level of \(avgLevel.isFinite ? Int(avgLevel) : 0) ng/dL is above the typical target range of \(targetMin.isFinite ? Int(targetMin) : 0)-\(targetMax.isFinite ? Int(targetMax) : 0) ng/dL. Consider discussing potential side effects and benefits with your healthcare provider.",
                    type: .warning
                )
            )
        } else {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Levels within typical target range",
                    description: "Your average level of \(avgLevel.isFinite ? Int(avgLevel) : 0) ng/dL falls within the typical target range of \(targetMin.isFinite ? Int(targetMin) : 0)-\(targetMax.isFinite ? Int(targetMax) : 0) ng/dL.",
                    type: .positive
                )
            )
        }
        
        return insights
    }
    
    /// Legacy method for backward compatibility
    @available(*, deprecated, message: "Use createMockInsightsForSimpleTreatment instead")
    private func createMockInsightsForProtocol(
        _ treatmentProtocol: InjectionProtocol,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary
    ) -> Insights {
        // Convert legacy protocol to unified Treatment
        let treatment = Treatment(from: treatmentProtocol)
        
        // Use the new method
        return createMockInsightsForSimpleTreatment(treatment, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
    }
    
    /// Creates mock insights for an advanced treatment
    private func createMockInsightsForAdvancedTreatment(
        _ treatment: Treatment,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary
    ) -> Insights {
        // Ensure this is an advanced treatment
        guard treatment.treatmentType == .advanced,
              let totalWeeks = treatment.totalWeeks,
              let stages = treatment.stages else {
            return Insights(title: "Invalid Treatment", summary: "This treatment type is not supported.", keyPoints: [])
        }
        
        // Extract treatment details
        let treatmentName = treatment.name
        let stageCount = stages.count
        
        // Generate summary of compounds and blends used in the treatment
        var compoundsUsed = Set<String>()
        var blendsUsed = Set<String>()
        
        for stage in stages {
            for compound in stage.compounds {
                if let actualCompound = compoundLibrary.compounds.first(where: { $0.id == compound.compoundID }) {
                    compoundsUsed.insert(actualCompound.commonName)
                }
            }
            
            for blend in stage.blends {
                if let actualBlend = compoundLibrary.blends.first(where: { $0.id == blend.blendID }) {
                    blendsUsed.insert(actualBlend.name)
                }
            }
        }
        
        // Get simulation statistics
        let maxLevel = simulationData.map { $0.level }.max() ?? 0
        // We're not using these in the current implementation, but they're available for future enhancements
        let _ = simulationData.map { $0.level }.min() ?? 0
        let _ = simulationData.map { $0.level }.reduce(0, +) / Double(max(1, simulationData.count))
        
        // Generate insights for the advanced treatment
        var insights = Insights(
            title: "Treatment Analysis: \(treatmentName)",
            summary: "Analysis of your \(totalWeeks)-week advanced treatment with \(stageCount) stages.",
            keyPoints: []
        )
        
        // 1. Structure point
        insights.keyPoints.append(
            KeyPoint(
                title: "Treatment Structure",
                description: "Your treatment spans \(totalWeeks) weeks with \(stageCount) distinct stages, using \(compoundsUsed.count) compounds and \(blendsUsed.count) blends.",
                type: .information
            )
        )
        
        // 2. Compound/blend usage point
        if !compoundsUsed.isEmpty || !blendsUsed.isEmpty {
            let compoundsList = compoundsUsed.joined(separator: ", ")
            let blendsList = blendsUsed.joined(separator: ", ")
            
            var description = "This treatment utilizes "
            if !compoundsUsed.isEmpty {
                description += "the following compounds: \(compoundsList)"
            }
            if !compoundsUsed.isEmpty && !blendsUsed.isEmpty {
                description += " and "
            }
            if !blendsUsed.isEmpty {
                description += "the following blends: \(blendsList)"
            }
            
            insights.keyPoints.append(
                KeyPoint(
                    title: "Compounds and Blends",
                    description: description,
                    type: .information
                )
            )
        }
        
        // 3. Level analysis point
        let targetMax = 1000.0 // Example target maximum
        if maxLevel > targetMax * 1.5 {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Very high peak levels",
                    description: "This treatment produces a maximum concentration of \(maxLevel.isFinite ? Int(maxLevel) : 0) ng/dL, which is significantly above the typical target range. Consider reducing dosages during peak periods.",
                    type: .warning
                )
            )
        } else if maxLevel > targetMax {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Elevated peak levels",
                    description: "This treatment produces a maximum concentration of \(maxLevel.isFinite ? Int(maxLevel) : 0) ng/dL, which is above the typical target maximum of \(targetMax.isFinite ? Int(targetMax) : 0) ng/dL.",
                    type: .warning
                )
            )
        }
        
        // 4. Recovery suggestion if appropriate
        if totalWeeks > 12 {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Consider post-treatment recovery",
                    description: "Your treatment duration of \(totalWeeks) weeks is relatively long. Consider implementing a proper post-treatment recovery protocol to help restore natural hormone production.",
                    type: .suggestion
                )
            )
        }
        
        return insights
    }
    
    /// Legacy method for backward compatibility
    @available(*, deprecated, message: "Use createMockInsightsForAdvancedTreatment instead")
    private func createMockInsightsForCycle(
        _ cycle: Cycle,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary
    ) -> Insights {
        // Convert legacy cycle to unified Treatment
        let treatment = Treatment(from: cycle)
        
        // Use the new method
        return createMockInsightsForAdvancedTreatment(treatment, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
    }
    
    /// Creates a mock blend explanation for a treatment
    private func createMockBlendExplanationForTreatment(_ treatment: Treatment, compoundLibrary: CompoundLibrary) -> String? {
        guard treatment.treatmentType == .simple,
              treatment.contentType == .blend,
              let blendID = treatment.blendID,
              let blend = compoundLibrary.blends.first(where: { $0.id == blendID }) else {
            return nil
        }
        
        // Get the components of the blend
        let components = blend.resolvedComponents(using: compoundLibrary)
        
        // Return nil if there are no components
        if components.isEmpty {
            return nil
        }
        
        // Create the explanation
        var explanation = "\(blend.name) contains \(components.count) different compounds:\n\n"
        
        // Sort components by half-life
        let sortedComponents = components.sorted { $0.compound.halfLifeDays < $1.compound.halfLifeDays }
        
        // Add component descriptions
        for component in sortedComponents {
            let percentage = (component.mgPerML / blend.totalConcentration) * 100
            let halfLife = component.compound.halfLifeDays
            
            explanation += "• \(component.compound.commonName)"
            if let ester = component.compound.ester {
                explanation += " \(ester)"
            }
            explanation += " (\(component.mgPerML.isFinite ? Int(component.mgPerML) : 0) mg/ml, approx. \(percentage.isFinite ? Int(percentage) : 0)%) - "
            
            // Describe the expected behavior
            if halfLife < 1.0 {
                explanation += "Very fast-acting with a half-life of \(String(format: "%.1f", halfLife)) days, providing an initial spike in hormone levels.\n"
            } else if halfLife < 3.0 {
                explanation += "Fast-acting with a half-life of \(String(format: "%.1f", halfLife)) days, providing relatively quick effects.\n"
            } else if halfLife < 7.0 {
                explanation += "Medium-acting with a half-life of \(String(format: "%.1f", halfLife)) days, providing balanced release.\n"
            } else {
                explanation += "Long-acting with a half-life of \(String(format: "%.1f", halfLife)) days, providing extended release of hormone levels.\n"
            }
        }
        
        // Add overall blend characteristics
        let shortActingCount = sortedComponents.filter { $0.compound.halfLifeDays < 3.0 }.count
        let longActingCount = sortedComponents.filter { $0.compound.halfLifeDays >= 7.0 }.count
        
        explanation += "\nOverall characteristics: "
        
        if shortActingCount > 0 && longActingCount > 0 {
            explanation += "This blend is designed to provide both immediate effects (from the shorter-acting compounds) and sustained release (from the longer-acting compounds), creating a balanced hormone profile over time."
        } else if shortActingCount > 0 {
            explanation += "This blend is primarily designed for quick onset of action, with effects becoming noticeable rapidly after injection."
        } else if longActingCount > 0 {
            explanation += "This blend is designed for stable, long-term release with minimal fluctuations, requiring less frequent injections."
        } else {
            explanation += "This blend provides a balanced release profile with moderate onset and duration of action."
        }
        
        return explanation
    }
    
    /// Legacy method for backward compatibility
    @available(*, deprecated, message: "Use createMockBlendExplanationForTreatment instead")
    private func createMockBlendExplanation(_ treatmentProtocol: InjectionProtocol, compoundLibrary: CompoundLibrary) -> String? {
        // Convert legacy protocol to unified Treatment
        guard treatmentProtocol.protocolType == .blend else {
            return nil
        }
        
        // Use the new method
        return createMockBlendExplanationForTreatment(Treatment(from: treatmentProtocol), compoundLibrary: compoundLibrary)
    }
    
    /// Real implementation would make an API call to OpenAI
    private func makeOpenAIAPICall(
        for treatment: Treatment,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary,
        completion: @escaping (Result<Insights, Error>) -> Void
    ) {
        // This would be implemented with actual API calls in a production version
        // For now, this is just a placeholder
        
        // 1. Construct the request data
        // 2. Make API call to OpenAI
        // 3. Process the response
        // 4. Return the insights
    }
    
    /// Legacy method for backward compatibility
    @available(*, deprecated, message: "Use makeOpenAIAPICall with Treatment instead")
    private func makeOpenAIAPICall(
        for treatmentProtocol: InjectionProtocol,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary,
        completion: @escaping (Result<Insights, Error>) -> Void
    ) {
        // Convert legacy protocol to unified Treatment
        let treatment = Treatment(from: treatmentProtocol)
        
        // Use the new method
        makeOpenAIAPICall(for: treatment, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary, completion: completion)
    }
}

// MARK: - Insights Model

/// Represents AI-generated insights
struct Insights {
    /// Title of the insights
    var title: String
    
    /// Summary paragraph
    var summary: String
    
    /// Detailed explanation for blend protocols
    var blendExplanation: String?
    
    /// Key points of the insights
    var keyPoints: [KeyPoint]
}

/// Represents a key point in the insights
struct KeyPoint {
    /// Title of the key point
    var title: String
    
    /// Detailed description
    var description: String
    
    /// Type of key point
    var type: KeyPointType
    
    /// Type of key point
    enum KeyPointType {
        case information
        case positive
        case warning
        case suggestion
    }
} 