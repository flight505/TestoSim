import Foundation

/// Service for handling OpenAI API requests
class OpenAIService {
    // MARK: - Properties
    
    /// Singleton instance
    static let shared = OpenAIService()
    
    /// OpenAI API endpoint
    private let apiEndpoint = "https://api.openai.com/v1/chat/completions"
    
    /// Test project API key with $20 spending limit (for test users)
    private let testApiKey = "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"
    
    /// Flag to determine if using test API key
    @Published private(set) var isUsingTestKey = false
    
    /// OpenAI API key
    private var apiKey: String {
        // If user has toggled to use the test key, return it
        if isUsingTestKey {
            return testApiKey
        }
        
        // Otherwise, get API key from UserDefaults or environment
        let userKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? 
                      ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        
        // If no user key is available, fall back to the test key
        return userKey.isEmpty ? testApiKey : userKey
    }
    
    /// The model to use for generating insights
    private let model = "gpt-4o-mini" // Using the more cost-effective GPT-4o-mini model
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern
    private init() {
        // Check if test key should be used by default
        self.isUsingTestKey = UserDefaults.standard.bool(forKey: "use_test_api_key")
    }
    
    // MARK: - API Methods
    
    /// Save the API key to UserDefaults
    /// - Parameter key: The API key
    func saveAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "openai_api_key")
        isUsingTestKey = false
        UserDefaults.standard.set(false, forKey: "use_test_api_key")
    }
    
    /// Check if an API key is available
    /// - Returns: True if an API key is available, false otherwise
    func hasAPIKey() -> Bool {
        return !apiKey.isEmpty
    }
    
    /// Clear the saved API key
    func clearAPIKey() {
        UserDefaults.standard.removeObject(forKey: "openai_api_key")
    }
    
    /// Toggle between using the test API key and the user's API key
    /// - Parameter useTestKey: Whether to use the test API key
    func toggleTestApiKey(_ useTestKey: Bool) {
        isUsingTestKey = useTestKey
        UserDefaults.standard.set(useTestKey, forKey: "use_test_api_key")
    }
    
    /// Generate protocol insights using the OpenAI API
    /// - Parameters:
    ///   - protocol: The protocol to analyze
    ///   - profile: User profile information
    ///   - simulationData: Pharmacokinetic simulation data
    ///   - completion: Callback with the result
    func generateProtocolInsights(
        treatmentProtocol: InjectionProtocol,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary,
        completion: @escaping (Result<Insights, Error>) -> Void
    ) {
        // Build the chat message content
        let content = buildProtocolPrompt(
            treatmentProtocol: treatmentProtocol,
            profile: profile,
            simulationData: simulationData,
            compoundLibrary: compoundLibrary
        )
        
        // Create the request
        makeCompletionRequest(content: content) { result in
            switch result {
            case .success(let jsonResponse):
                do {
                    // Parse the insights from the response
                    let insights = try self.parseInsightsFromResponse(jsonResponse, forProtocol: treatmentProtocol)
                    completion(.success(insights))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Generate cycle insights using the OpenAI API
    /// - Parameters:
    ///   - cycle: The cycle to analyze
    ///   - profile: User profile information
    ///   - simulationData: Pharmacokinetic simulation data
    ///   - completion: Callback with the result
    func generateCycleInsights(
        cycle: Cycle,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary,
        completion: @escaping (Result<Insights, Error>) -> Void
    ) {
        // Build the chat message content
        let content = buildCyclePrompt(
            cycle: cycle,
            profile: profile,
            simulationData: simulationData,
            compoundLibrary: compoundLibrary
        )
        
        // Create the request
        makeCompletionRequest(content: content) { result in
            switch result {
            case .success(let jsonResponse):
                do {
                    // Parse the insights from the response
                    let insights = try self.parseInsightsFromResponse(jsonResponse, forCycle: cycle)
                    completion(.success(insights))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Build the prompt for protocol insights
    private func buildProtocolPrompt(
        treatmentProtocol: InjectionProtocol,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary
    ) -> String {
        // Extract protocol details
        let protocolType = treatmentProtocol.protocolType
        let protocolName = treatmentProtocol.name
        var compoundOrBlendName = "Unknown"
        var compoundInfo = ""
        
        // Get compound or blend information
        if protocolType == .compound, let compoundID = treatmentProtocol.compoundID,
           let compound = compoundLibrary.compounds.first(where: { $0.id == compoundID }) {
            compoundOrBlendName = compound.commonName
            if let ester = compound.ester {
                compoundOrBlendName += " \(ester)"
            }
            compoundInfo = """
            Compound: \(compound.commonName)
            Ester: \(compound.ester ?? "None")
            Half-life: \(compound.halfLifeDays) days
            """
        } else if protocolType == .blend, let blendID = treatmentProtocol.blendID,
                  let blend = compoundLibrary.blends.first(where: { $0.id == blendID }) {
            compoundOrBlendName = blend.name
            compoundInfo = """
            Blend: \(blend.name)
            Manufacturer: \(blend.manufacturer ?? "Unknown")
            Components:
            """
            
            // Add blend components
            let components = blend.resolvedComponents(using: compoundLibrary)
            for component in components {
                compoundInfo += """
                
                - \(component.compound.commonName) \(component.compound.ester ?? "")
                  Concentration: \(component.mgPerML) mg/mL
                  Half-life: \(component.compound.halfLifeDays) days
                """
            }
        }
        
        // Extract simulation statistics
        let maxLevel = simulationData.map { $0.level }.max() ?? 0
        let minLevel = simulationData.map { $0.level }.min() ?? 0
        let avgLevel = simulationData.map { $0.level }.reduce(0, +) / Double(max(1, simulationData.count))
        let fluctuation = maxLevel > 0 ? (maxLevel - minLevel) / maxLevel * 100 : 0
        
        // Build the prompt
        return """
        You are a specialized AI assistant for TestoSim, a hormone therapy simulation app. 
        Analyze the following protocol and simulation data, and provide insights in the specified JSON format.
        
        USER PROFILE:
        Weight: \(profile.weight ?? 0) kg
        Height: \(profile.heightCm ?? 0) cm
        Age: \(profile.age ?? 0)
        Biological sex: \(profile.biologicalSex.rawValue)
        
        PROTOCOL DETAILS:
        Name: \(protocolName)
        Type: \(protocolType.rawValue)
        \(compoundInfo)
        Dose: \(treatmentProtocol.doseMg) mg
        Frequency: Every \(treatmentProtocol.frequencyDays) days
        Route: \(treatmentProtocol.selectedRoute ?? "intramuscular")
        
        SIMULATION STATISTICS:
        Average Level: \(avgLevel) ng/dL
        Maximum Level: \(maxLevel) ng/dL
        Minimum Level: \(minLevel) ng/dL
        Fluctuation: \(fluctuation)%
        
        BLOOD SAMPLES:
        \(treatmentProtocol.bloodSamples.map { "Date: \($0.date), Value: \($0.value) \($0.unit)" }.joined(separator: "\n"))
        
        Based on this information, provide insights about the protocol in the following JSON format:
        
        {
            "title": "Insights for [Protocol Name]",
            "summary": "A concise summary of the protocol analysis.",
            "blendExplanation": "Detailed explanation of what's in the blend and how it behaves over time (only for blend protocols, null otherwise).",
            "keyPoints": [
                {
                    "title": "Short, specific point title",
                    "description": "Detailed explanation of the point",
                    "type": "information|positive|warning|suggestion"
                }
            ]
        }
        
        Focus on practical insights about:
        1. Dosing frequency and stability
        2. Level fluctuations and their implications
        3. Potential optimizations to the protocol
        4. Educational content about the compounds or blend
        """
    }
    
    /// Build the prompt for cycle insights
    private func buildCyclePrompt(
        cycle: Cycle,
        profile: UserProfile,
        simulationData: [DataPoint],
        compoundLibrary: CompoundLibrary
    ) -> String {
        // Extract cycle details
        let cycleName = cycle.name
        let cycleStages = cycle.stages
        
        // Build stages information
        var stagesInfo = ""
        for (index, stage) in cycleStages.enumerated() {
            stagesInfo += """
            
            Stage \(index + 1):
            Name: \(stage.name)
            Duration: \(stage.durationWeeks) weeks
            Start Week: \(stage.startWeek)
            """
            
            // Add compounds in stage
            if !stage.compounds.isEmpty {
                stagesInfo += "\nCompounds:"
                for compound in stage.compounds {
                    stagesInfo += """
                    
                      - \(compound.compoundName)
                          Dose: \(compound.doseMg) mg
                          Frequency: Every \(compound.frequencyDays) days
                          Route: \(compound.administrationRoute)
                    """
                }
            }
            
            // Add blends in stage
            if !stage.blends.isEmpty {
                stagesInfo += "\nBlends:"
                for blend in stage.blends {
                    stagesInfo += """
                    
                      - \(blend.blendName)
                          Dose: \(blend.doseMg) mg
                          Frequency: Every \(blend.frequencyDays) days
                          Route: \(blend.administrationRoute)
                    """
                }
            }
        }
        
        // Extract simulation statistics
        let maxLevel = simulationData.map { $0.level }.max() ?? 0
        let minLevel = simulationData.map { $0.level }.min() ?? 0
        let avgLevel = simulationData.map { $0.level }.reduce(0, +) / Double(max(1, simulationData.count))
        let fluctuation = maxLevel > 0 ? (maxLevel - minLevel) / maxLevel * 100 : 0
        
        // Build the prompt
        return """
        You are a specialized AI assistant for TestoSim, a hormone therapy simulation app. 
        Analyze the following cycle and simulation data, and provide insights in the specified JSON format.
        
        USER PROFILE:
        Weight: \(profile.weight ?? 0) kg
        Height: \(profile.heightCm ?? 0) cm
        Age: \(profile.age ?? 0)
        Biological sex: \(profile.biologicalSex.rawValue)
        
        CYCLE DETAILS:
        Name: \(cycleName)
        Total Duration: \(cycle.totalWeeks) weeks
        \(stagesInfo)
        
        SIMULATION STATISTICS:
        Average Level: \(avgLevel) ng/dL
        Maximum Level: \(maxLevel) ng/dL
        Minimum Level: \(minLevel) ng/dL
        Fluctuation: \(fluctuation)%
        
        Based on this information, provide insights about the cycle in the following JSON format:
        
        {
            "title": "Insights for [Cycle Name]",
            "summary": "A concise summary of the cycle analysis.",
            "stageBreakdown": [
                {
                    "stageNumber": 1,
                    "analysis": "Analysis of what's happening in this stage and why"
                }
            ],
            "keyPoints": [
                {
                    "title": "Short, specific point title",
                    "description": "Detailed explanation of the point",
                    "type": "information|positive|warning|suggestion"
                }
            ]
        }
        
        Focus on practical insights about:
        1. Stage progression and rationale
        2. Compound selection and synergies
        3. Level fluctuations and their implications
        4. Potential optimizations to the cycle
        5. Educational content about the compounds and how they work together
        """
    }
    
    /// Make a completion request to the OpenAI API
    private func makeCompletionRequest(content: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Create URL
        guard let url = URL(string: apiEndpoint) else {
            completion(.failure(NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create request body
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a specialized AI assistant for a hormone therapy simulation app. Provide insights in JSON format only."],
                ["role": "user", "content": content]
            ],
            "temperature": 0.3,
            "max_tokens": 2000,
            "response_format": ["type": "json_object"]
        ]
        
        // Convert request body to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body"])))
            return
        }
        
        request.httpBody = jsonData
        
        // Make the request
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            // Handle error
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Handle no data
            guard let data = data else {
                completion(.failure(NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Parse response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content))
                } else {
                    // Try to extract error message if available
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        completion(.failure(NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: message])))
                    } else {
                        completion(.failure(NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// API response structure for insights
    private struct APIInsightsResponse: Decodable {
        let title: String
        let summary: String
        let blendExplanation: String?
        let stageBreakdown: [APIStageBreakdown]?
        let keyPoints: [APIKeyPoint]
        
        struct APIKeyPoint: Decodable {
            let title: String
            let description: String
            let type: String
        }
        
        struct APIStageBreakdown: Decodable {
            let stageNumber: Int
            let analysis: String
        }
    }
    
    /// Stage analysis information
    private struct StageAnalysis {
        let stageNumber: Int
        let analysis: String
    }
    
    /// Parse insights from the OpenAI API response
    private func parseInsightsFromResponse(_ jsonString: String, forProtocol protocol: InjectionProtocol? = nil, forCycle cycle: Cycle? = nil) throws -> Insights {
        let decoder = JSONDecoder()
        
        // Extract the JSON structure from the response
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response to data"])
        }
        
        // Try to decode as APIInsightsResponse
        do {
            let response = try decoder.decode(APIInsightsResponse.self, from: jsonData)
            
            // Convert API response to Insights model
            var keyPoints: [KeyPoint] = []
            for point in response.keyPoints {
                let type: KeyPoint.KeyPointType
                switch point.type {
                case "information": type = .information
                case "positive": type = .positive
                case "warning": type = .warning
                case "suggestion": type = .suggestion
                default: type = .information
                }
                
                keyPoints.append(KeyPoint(title: point.title, description: point.description, type: type))
            }
            
            // Create the Insights object
            return Insights(
                title: response.title,
                summary: response.summary,
                blendExplanation: response.blendExplanation,
                keyPoints: keyPoints
            )
        } catch {
            print("Error parsing insights: \(error)")
            throw error
        }
    }
    
    // MARK: - Error Types
    
    /// API errors
    enum APIError: Error, LocalizedError {
        case missingAPIKey
        case invalidURL
        case invalidResponse
        case serverError(statusCode: Int)
        case noData
        case invalidResponseFormat
        case missingField(String)
        
        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "OpenAI API key is missing"
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .serverError(let statusCode):
                return "Server error with status code: \(statusCode)"
            case .noData:
                return "No data received from server"
            case .invalidResponseFormat:
                return "Invalid response format"
            case .missingField(let field):
                return "Missing field in response: \(field)"
            }
        }
    }
} 