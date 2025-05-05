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
    
    /// Generate insights for a specific protocol
    /// - Parameters:
    ///   - protocol: The protocol to analyze
    ///   - profile: User profile data
    ///   - simulationData: Simulation data points
    ///   - compoundLibrary: Reference to compound library
    ///   - forceRefresh: Whether to force a refresh instead of using cached insights
    func generateInsights(
        for treatmentProtocol: InjectionProtocol,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary,
        forceRefresh: Bool = false
    ) {
        // Check cache first unless refresh is forced
        if !forceRefresh, let cachedInsights = insightsCache[treatmentProtocol.id] {
            self.latestInsights = cachedInsights
            return
        }
        
        isLoading = true
        error = nil
        
        // Check if OpenAI API key is available
        if openAIService.hasAPIKey() {
            // Use OpenAI service for real insights
            openAIService.generateProtocolInsights(
                treatmentProtocol: treatmentProtocol,
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
                        self.insightsCache[treatmentProtocol.id] = insights
                        self.latestInsights = insights
                        
                    case .failure(let error):
                        self.error = error
                        // Fall back to mock insights if API call fails
                        self.generateMockInsights(for: treatmentProtocol, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
                    }
                }
            }
        } else {
            // Use mock implementation when API key is not available
            generateMockInsights(for: treatmentProtocol, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
        }
    }
    
    /// Generate insights for a cycle
    /// - Parameters:
    ///   - cycle: The cycle to analyze
    ///   - profile: User profile data
    ///   - simulationData: Cycle simulation data points
    ///   - compoundLibrary: Reference to compound library
    ///   - forceRefresh: Whether to force a refresh instead of using cached insights
    func generateCycleInsights(
        for cycle: Cycle,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary,
        forceRefresh: Bool = false
    ) {
        // Check cache first unless refresh is forced
        if !forceRefresh, let cachedInsights = insightsCache[cycle.id] {
            self.latestInsights = cachedInsights
            return
        }
        
        isLoading = true
        error = nil
        
        // Check if OpenAI API key is available
        if openAIService.hasAPIKey() {
            // Use OpenAI service for real insights
            openAIService.generateCycleInsights(
                cycle: cycle,
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
                        self.insightsCache[cycle.id] = insights
                        self.latestInsights = insights
                        
                    case .failure(let error):
                        self.error = error
                        // Fall back to mock insights if API call fails
                        self.generateMockCycleInsights(for: cycle, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
                    }
                }
            }
        } else {
            // Use mock implementation when API key is not available
            generateMockCycleInsights(for: cycle, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
        }
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
    
    /// Mock implementation for generating insights
    private func generateMockInsights(
        for treatmentProtocol: InjectionProtocol,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary
    ) {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            // Create mock insights based on protocol type
            let insights = self.createMockInsightsForProtocol(treatmentProtocol, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
            
            // Cache the insights
            self.insightsCache[treatmentProtocol.id] = insights
            
            // Update published properties
            self.latestInsights = insights
            self.isLoading = false
        }
    }
    
    /// Mock implementation for generating cycle insights
    private func generateMockCycleInsights(
        for cycle: Cycle,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary
    ) {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            // Create mock insights for the cycle
            let insights = self.createMockInsightsForCycle(cycle, profile: profile, simulationData: simulationData, compoundLibrary: compoundLibrary)
            
            // Cache the insights
            self.insightsCache[cycle.id] = insights
            
            // Update published properties
            self.latestInsights = insights
            self.isLoading = false
        }
    }
    
    /// Creates mock insights for a protocol
    private func createMockInsightsForProtocol(
        _ treatmentProtocol: InjectionProtocol,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary
    ) -> Insights {
        // Extract protocol details
        let protocolType = treatmentProtocol.protocolType
        let protocolName = treatmentProtocol.name
        var compoundOrBlendName = "Unknown"
        
        // Determine the compound or blend name
        if protocolType == .compound, let compoundID = treatmentProtocol.compoundID,
           let compound = compoundLibrary.compounds.first(where: { $0.id == compoundID }) {
            compoundOrBlendName = compound.commonName
            if let ester = compound.ester {
                compoundOrBlendName += " \(ester)"
            }
        } else if protocolType == .blend, let blendID = treatmentProtocol.blendID,
                  let blend = compoundLibrary.blends.first(where: { $0.id == blendID }) {
            compoundOrBlendName = blend.name
        }
        
        // Get simulation statistics
        let maxLevel = simulationData.map { $0.level }.max() ?? 0
        let minLevel = simulationData.map { $0.level }.min() ?? 0
        let avgLevel = simulationData.map { $0.level }.reduce(0, +) / Double(max(1, simulationData.count))
        let fluctuation = maxLevel > 0 ? (maxLevel - minLevel) / maxLevel * 100 : 0
        
        // Generate insights based on protocol characteristics
        var insights = Insights(
            title: "Insights for \(protocolName)",
            summary: "Analysis of your \(compoundOrBlendName) protocol.",
            keyPoints: []
        )
        
        // Add blend explanation if it's a blend
        if protocolType == .blend {
            insights.blendExplanation = createMockBlendExplanation(treatmentProtocol, compoundLibrary: compoundLibrary)
        }
        
        // Add key points based on protocol characteristics
        
        // 1. Frequency point
        if treatmentProtocol.frequencyDays >= 7 {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Consider splitting your dose",
                    description: "Your current injection frequency of every \(treatmentProtocol.frequencyDays) days leads to significant hormone fluctuations. Consider splitting your total dose into smaller, more frequent injections to achieve more stable hormone levels.",
                    type: .suggestion
                )
            )
        } else if treatmentProtocol.frequencyDays <= 2 {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Good injection frequency",
                    description: "Your frequent injection schedule of every \(treatmentProtocol.frequencyDays) days helps maintain stable hormone levels with minimal fluctuations.",
                    type: .positive
                )
            )
        }
        
        // 2. Fluctuation point
        if fluctuation > 40 {
            insights.keyPoints.append(
                KeyPoint(
                    title: "High level fluctuation",
                    description: "Your current protocol results in approximately \(Int(fluctuation))% fluctuation between peak and trough levels, which may lead to inconsistent symptoms and effects.",
                    type: .warning
                )
            )
        } else if fluctuation < 20 {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Stable hormone levels",
                    description: "Your protocol achieves excellent stability with only \(Int(fluctuation))% fluctuation between peak and trough levels.",
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
                    description: "Your average level of \(Int(avgLevel)) ng/dL is below the typical target range of \(Int(targetMin))-\(Int(targetMax)) ng/dL. Consider discussing a dosage adjustment with your healthcare provider.",
                    type: .warning
                )
            )
        } else if avgLevel > targetMax {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Levels above typical target range",
                    description: "Your average level of \(Int(avgLevel)) ng/dL is above the typical target range of \(Int(targetMin))-\(Int(targetMax)) ng/dL. Consider discussing potential side effects and benefits with your healthcare provider.",
                    type: .warning
                )
            )
        } else {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Levels within typical target range",
                    description: "Your average level of \(Int(avgLevel)) ng/dL falls within the typical target range of \(Int(targetMin))-\(Int(targetMax)) ng/dL.",
                    type: .positive
                )
            )
        }
        
        return insights
    }
    
    /// Creates mock insights for a cycle
    private func createMockInsightsForCycle(
        _ cycle: Cycle,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary
    ) -> Insights {
        // Extract cycle details
        let cycleName = cycle.name
        let totalWeeks = cycle.totalWeeks
        let stageCount = cycle.stages.count
        
        // Generate summary of compounds and blends used in the cycle
        var compoundsUsed = Set<String>()
        var blendsUsed = Set<String>()
        
        for stage in cycle.stages {
            for compoundItem in stage.compounds {
                if let compound = compoundLibrary.compounds.first(where: { $0.id == compoundItem.compoundID }) {
                    compoundsUsed.insert(compound.commonName)
                }
            }
            
            for blendItem in stage.blends {
                if let blend = compoundLibrary.blends.first(where: { $0.id == blendItem.blendID }) {
                    blendsUsed.insert(blend.name)
                }
            }
        }
        
        // Get simulation statistics
        let maxLevel = simulationData.map { $0.level }.max() ?? 0
        let _ = simulationData.map { $0.level }.min() ?? 0
        let _ = simulationData.map { $0.level }.reduce(0, +) / Double(max(1, simulationData.count))
        
        // Generate insights for the cycle
        var insights = Insights(
            title: "Cycle Analysis: \(cycleName)",
            summary: "Analysis of your \(totalWeeks)-week cycle with \(stageCount) stages.",
            keyPoints: []
        )
        
        // 1. Cycle structure point
        insights.keyPoints.append(
            KeyPoint(
                title: "Cycle Structure",
                description: "Your cycle spans \(totalWeeks) weeks with \(stageCount) distinct stages, using \(compoundsUsed.count) compounds and \(blendsUsed.count) blends.",
                type: .information
            )
        )
        
        // 2. Compound/blend usage point
        if !compoundsUsed.isEmpty || !blendsUsed.isEmpty {
            let compoundsList = compoundsUsed.joined(separator: ", ")
            let blendsList = blendsUsed.joined(separator: ", ")
            
            var description = "This cycle utilizes "
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
                    description: "This cycle produces a maximum concentration of \(Int(maxLevel)) ng/dL, which is significantly above the typical target range. Consider reducing dosages during peak periods.",
                    type: .warning
                )
            )
        } else if maxLevel > targetMax {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Elevated peak levels",
                    description: "This cycle produces a maximum concentration of \(Int(maxLevel)) ng/dL, which is above the typical target maximum of \(Int(targetMax)) ng/dL.",
                    type: .warning
                )
            )
        }
        
        // 4. Recovery suggestion if appropriate
        if totalWeeks > 12 {
            insights.keyPoints.append(
                KeyPoint(
                    title: "Consider post-cycle recovery",
                    description: "Your cycle duration of \(totalWeeks) weeks is relatively long. Consider implementing a proper post-cycle recovery protocol to help restore natural hormone production.",
                    type: .suggestion
                )
            )
        }
        
        return insights
    }
    
    /// Creates a mock blend explanation
    private func createMockBlendExplanation(_ treatmentProtocol: InjectionProtocol, compoundLibrary: CompoundLibrary) -> String? {
        guard treatmentProtocol.protocolType == .blend,
              let blendID = treatmentProtocol.blendID,
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
            explanation += " (\(Int(component.mgPerML)) mg/ml, approx. \(Int(percentage))%) - "
            
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
    
    /// Real implementation would make an API call to OpenAI
    private func makeOpenAIAPICall(
        for treatmentProtocol: InjectionProtocol,
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