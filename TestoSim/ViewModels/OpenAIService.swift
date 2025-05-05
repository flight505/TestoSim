import Foundation

/// Service for handling OpenAI API requests
class OpenAIService {
    // MARK: - Properties
    
    /// Singleton instance
    static let shared = OpenAIService()
    
    /// OpenAI API endpoint
    private let apiEndpoint = "https://api.openai.com/v1/chat/completions"
    
    /// Test project API key with $20 spending limit (for test users)
    private var testApiKey: String {
        // Read the API key from Info.plist
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String {
            if key.hasPrefix("_") {
                // This is the sample placeholder value, log an error
                print("Warning: Using placeholder API key. Please update Config.xcconfig with a real API key.")
                return ""
            }
            return key
        }
        return ""
    }
    
    /// Flag to determine if using test API key
    @Published private(set) var isUsingTestKey = false
    
    /// OpenAI API key
    private var apiKey: String {
        // First check if we should use the test key
        if UserDefaults.standard.bool(forKey: "use_test_api_key") {
            isUsingTestKey = true
            if !testApiKey.isEmpty {
                return testApiKey
            }
        }
        
        // Otherwise use the user's API key from UserDefaults
        isUsingTestKey = false
        return UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    }
    
    /// The model to use for generating insights
    private let model = "gpt-4o-mini" // Using mini version for cost efficiency
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - API Methods
    
    /// Save the API key to UserDefaults
    /// - Parameter key: The API key
    func saveAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "openai_api_key")
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
        
        Make sure to provide medically accurate information and include appropriate disclaimers.
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
        let totalWeeks = cycle.totalWeeks
        let stageCount = cycle.stages.count
        
        // Build stages information
        var stagesInfo = ""
        for (index, stage) in cycle.stages.enumerated() {
            stagesInfo += """
            
            STAGE \(index + 1):
            Name: \(stage.name)
            Start Week: \(stage.startWeek)
            Duration: \(stage.durationWeeks) weeks
            """
            
            // Add compounds
            if !stage.compounds.isEmpty {
                stagesInfo += "\nCompounds:"
                for compound in stage.compounds {
                    if let compoundObj = compoundLibrary.compounds.first(where: { $0.id == compound.compoundID }) {
                        stagesInfo += """
                        
                        - \(compoundObj.commonName) \(compoundObj.ester ?? "")
                          Dose: \(compound.doseMg) mg
                          Frequency: Every \(compound.frequencyDays) days
                          Route: \(compound.selectedRoute ?? "intramuscular")
                        """
                    }
                }
            }
            
            // Add blends
            if !stage.blends.isEmpty {
                stagesInfo += "\nBlends:"
                for blend in stage.blends {
                    if let blendObj = compoundLibrary.blends.first(where: { $0.id == blend.blendID }) {
                        stagesInfo += """
                        
                        - \(blendObj.name)
                          Dose: \(blend.doseMg) mg
                          Frequency: Every \(blend.frequencyDays) days
                          Route: \(blend.selectedRoute ?? "intramuscular")
                        """
                    }
                }
            }
        }
        
        // Extract simulation statistics
        let maxLevel = simulationData.map { $0.level }.max() ?? 0
        let minLevel = simulationData.map { $0.level }.min() ?? 0
        let avgLevel = simulationData.map { $0.level }.reduce(0, +) / Double(max(1, simulationData.count))
        
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
        Total Weeks: \(totalWeeks)
        Number of Stages: \(stageCount)
        \(stagesInfo)
        
        SIMULATION STATISTICS:
        Average Level: \(avgLevel) ng/dL
        Maximum Level: \(maxLevel) ng/dL
        Minimum Level: \(minLevel) ng/dL
        
        Based on this information, provide insights about the cycle in the following JSON format:
        
        {
            "title": "Insights for [Cycle Name]",
            "summary": "A concise summary of the cycle analysis.",
            "keyPoints": [
                {
                    "title": "Short, specific point title",
                    "description": "Detailed explanation of the point",
                    "type": "information|positive|warning|suggestion"
                }
            ]
        }
        
        Focus on practical insights about:
        1. Cycle structure and design
        2. Compound/blend selection and scheduling
        3. Level fluctuations and their implications
        4. Potential optimizations to the cycle
        5. Post-cycle considerations if applicable
        
        Make sure to provide medically accurate information and include appropriate disclaimers.
        """
    }
    
    /// Make a completion request to the OpenAI API
    private func makeCompletionRequest(
        content: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        // Check if API key is available
        guard !apiKey.isEmpty else {
            completion(.failure(APIError.missingAPIKey))
            return
        }
        
        // Create URL
        guard let url = URL(string: apiEndpoint) else {
            completion(.failure(APIError.invalidURL))
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
                ["role": "system", "content": "You are a medical AI assistant specialized in hormone therapy and pharmacokinetics. You provide concise, accurate insights based on simulation data."],
                ["role": "user", "content": content]
            ],
            "temperature": 0.7,
            "response_format": ["type": "json_object"]
        ]
        
        // Serialize request body
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Create task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Check for errors
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Check response status
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.serverError(statusCode: httpResponse.statusCode)))
                return
            }
            
            // Check data
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            // Parse response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String,
                   let contentData = content.data(using: .utf8),
                   let jsonResponse = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
                    completion(.success(jsonResponse))
                } else {
                    completion(.failure(APIError.invalidResponseFormat))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        // Start task
        task.resume()
    }
    
    /// Parse insights from the API response
    private func parseInsightsFromResponse(_ response: [String: Any], forProtocol treatmentProtocol: InjectionProtocol? = nil, forCycle cycle: Cycle? = nil) throws -> Insights {
        // Extract title
        guard let title = response["title"] as? String else {
            throw APIError.missingField("title")
        }
        
        // Extract summary
        guard let summary = response["summary"] as? String else {
            throw APIError.missingField("summary")
        }
        
        // Extract blend explanation (optional)
        let blendExplanation = response["blendExplanation"] as? String
        
        // Extract key points
        guard let keyPointsArray = response["keyPoints"] as? [[String: Any]] else {
            throw APIError.missingField("keyPoints")
        }
        
        // Parse key points
        var keyPoints: [KeyPoint] = []
        for pointDict in keyPointsArray {
            guard let title = pointDict["title"] as? String,
                  let description = pointDict["description"] as? String,
                  let typeString = pointDict["type"] as? String else {
                continue
            }
            
            let type: KeyPoint.KeyPointType
            switch typeString {
            case "information":
                type = .information
            case "positive":
                type = .positive
            case "warning":
                type = .warning
            case "suggestion":
                type = .suggestion
            default:
                type = .information
            }
            
            keyPoints.append(KeyPoint(title: title, description: description, type: type))
        }
        
        // Create and return insights
        return Insights(
            title: title,
            summary: summary,
            blendExplanation: blendExplanation,
            keyPoints: keyPoints
        )
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