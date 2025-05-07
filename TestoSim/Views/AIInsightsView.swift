import SwiftUI

/// View for displaying AI-generated insights
struct AIInsightsView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @StateObject private var insightsGenerator = AIInsightsGenerator()
    @ObservedObject private var openAIService = OpenAIService.shared
    
    // Treatment ID to analyze
    var treatmentID: UUID?
    
    @State private var isLoading = false
    @State private var expandedPoints: Set<String> = []
    @State private var showSettings = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Test API key indicator
                if openAIService.isUsingTestKey {
                    testKeyIndicator
                }
                
                // API key warning if no key is set
                if !OpenAIService.shared.hasAPIKey() {
                    noApiKeyView
                }
                
                // Error message if present
                if let message = errorMessage {
                    errorView(message)
                }
                
                if isLoading {
                    loadingView
                } else if let insights = insightsGenerator.latestInsights {
                    insightsContent(insights)
                } else {
                    noInsightsView
                }
            }
            .padding()
        }
        .navigationTitle("AI Insights")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    generateInsights(forceRefresh: true)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .onAppear {
            generateInsights()
            // Set up error handling monitoring
            updateErrorMessage()
        }
        .sheet(isPresented: $showSettings) {
            AISettingsView(insightsGenerator: insightsGenerator)
        }
        // Use a task to monitor error state changes instead of onChange
        .task {
            for await _ in insightsGenerator.$error.values {
                updateErrorMessage()
            }
        }
    }
    
    // MARK: - Private Views
    
    private var testKeyIndicator: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.green)
            Text("Using Test API Key")
                .font(.caption)
                .foregroundColor(.green)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.green.opacity(0.1))
        .cornerRadius(5)
    }
    
    private var noApiKeyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "key.slash")
                    .foregroundColor(.yellow)
                Text("OpenAI API Key Required")
                    .font(.headline)
                    .foregroundColor(.yellow)
            }
            
            Text("To use AI-powered insights, you need to set up your OpenAI API key in settings.")
                .font(.subheadline)
            
            Button("Set API Key") {
                showSettings = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                Text("Error")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            Text(message)
                .font(.subheadline)
            
            Button("Try Again") {
                errorMessage = nil
                generateInsights(forceRefresh: true)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Analyzing data and generating insights...")
                .font(.headline)
            
            Text("This may take a moment")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    private var noInsightsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lightbulb")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            if dataStore.selectedProtocolID == nil && dataStore.selectedCycleID == nil && treatmentID == nil {
                Text("No treatment selected")
                    .font(.headline)
                
                Text("Select a treatment to generate insights.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            } else {
                Text("No insights available")
                    .font(.headline)
                
                Text("Tap the refresh button to generate insights based on your current treatment data.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            Button("Generate Insights") {
                generateInsights(forceRefresh: true)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
    }
    
    private func insightsContent(_ insights: Insights) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text(insights.title)
                .font(.title)
                .fontWeight(.bold)
            
            // Summary
            Text(insights.summary)
                .font(.headline)
                .padding(.bottom, 8)
            
            // Disclaimer
            Text("Note: These insights are generated by AI and should not replace medical advice.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            
            // Blend explanation if available
            if let blendExplanation = insights.blendExplanation {
                blendExplanationView(blendExplanation)
            }
            
            // Key points
            if !insights.keyPoints.isEmpty {
                Text("Key Points")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                ForEach(insights.keyPoints, id: \.title) { point in
                    keyPointView(point)
                }
            }
        }
    }
    
    private func blendExplanationView(_ explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Blend Analysis")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(explanation)
                .font(.body)
                .lineSpacing(4)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func keyPointView(_ point: KeyPoint) -> some View {
        let pointId = point.title
        let isExpanded = expandedPoints.contains(pointId)
        
        return VStack(alignment: .leading, spacing: 8) {
            // Header row with icon, title, and expand/collapse button
            HStack {
                iconForKeyPoint(point.type)
                    .font(.headline)
                    .foregroundColor(colorForKeyPoint(point.type))
                    .frame(width: 24, height: 24)
                
                Text(point.title)
                    .font(.headline)
                    .foregroundColor(colorForKeyPoint(point.type))
                
                Spacer()
                
                Button {
                    withAnimation {
                        if isExpanded {
                            expandedPoints.remove(pointId)
                        } else {
                            expandedPoints.insert(pointId)
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            // Description (visible when expanded)
            if isExpanded {
                Text(point.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.leading, 32)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(backgroundForKeyPoint(point.type).opacity(0.1))
        .cornerRadius(10)
        .contentShape(Rectangle()) // Make the entire row tappable
        .onTapGesture {
            withAnimation {
                if isExpanded {
                    expandedPoints.remove(pointId)
                } else {
                    expandedPoints.insert(pointId)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateInsights(forceRefresh: Bool = false) {
        self.isLoading = true
        
        // Check if we have a specific treatment to analyze
        if let treatmentID = treatmentID, let treatment = dataStore.treatments.first(where: { $0.id == treatmentID }) {
            // Generate insights for the specific treatment
            switch treatment.treatmentType {
            case .simple:
                insightsGenerator.generateInsights(
                    for: treatment,
                    profile: dataStore.profile,
                    simulationData: dataStore.simulationData,
                    compoundLibrary: dataStore.compoundLibrary,
                    forceRefresh: forceRefresh
                )
            case .advanced:
                insightsGenerator.generateAdvancedTreatmentInsights(
                    for: treatment,
                    profile: dataStore.profile,
                    simulationData: dataStore.cycleSimulationData,
                    compoundLibrary: dataStore.compoundLibrary,
                    forceRefresh: forceRefresh
                )
            }
        }
        // Fallback to legacy types during transition period
        else if let protocolID = dataStore.selectedProtocolID,
                let selectedProtocol = dataStore.profile.protocols.first(where: { $0.id == protocolID }) {
            // During transition period - convert legacy protocol to Treatment first
            let treatment = Treatment(from: selectedProtocol)
            
            insightsGenerator.generateInsights(
                for: treatment,
                profile: dataStore.profile,
                simulationData: dataStore.simulationData,
                compoundLibrary: dataStore.compoundLibrary,
                forceRefresh: forceRefresh
            )
        } else if let cycleID = dataStore.selectedCycleID,
                  let selectedCycle = dataStore.cycles.first(where: { $0.id == cycleID }) {
            // During transition period - convert legacy cycle to Treatment first
            let treatment = Treatment(from: selectedCycle)
            
            insightsGenerator.generateAdvancedTreatmentInsights(
                for: treatment,
                profile: dataStore.profile,
                simulationData: dataStore.cycleSimulationData,
                compoundLibrary: dataStore.compoundLibrary,
                forceRefresh: forceRefresh
            )
        } else {
            // If no treatment is found, show no insights available
            self.isLoading = false
            return
        }
        
        // Update loading state based on the generator's state
        DispatchQueue.main.async {
            self.isLoading = self.insightsGenerator.isLoading
        }
    }
    
    private func iconForKeyPoint(_ type: KeyPoint.KeyPointType) -> some View {
        switch type {
        case .information:
            return Image(systemName: "info.circle.fill")
        case .positive:
            return Image(systemName: "checkmark.circle.fill")
        case .warning:
            return Image(systemName: "exclamationmark.triangle.fill")
        case .suggestion:
            return Image(systemName: "lightbulb.fill")
        }
    }
    
    private func colorForKeyPoint(_ type: KeyPoint.KeyPointType) -> Color {
        switch type {
        case .information:
            return .blue
        case .positive:
            return .green
        case .warning:
            return .orange
        case .suggestion:
            return .purple
        }
    }
    
    private func backgroundForKeyPoint(_ type: KeyPoint.KeyPointType) -> Color {
        switch type {
        case .information:
            return .blue
        case .positive:
            return .green
        case .warning:
            return .orange
        case .suggestion:
            return .purple
        }
    }
    
    private func updateErrorMessage() {
        if let error = insightsGenerator.error {
            errorMessage = error.localizedDescription
        } else {
            errorMessage = nil
        }
    }
}

// MARK: - AISettingsView

/// View for managing AI settings, including API key
struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    @State private var showingSuccessMessage = false
    @State private var useTestKey: Bool = UserDefaults.standard.bool(forKey: "use_test_api_key")
    @EnvironmentObject var dataStore: AppDataStore
    
    // Reference to the shared insights generator
    private let insightsGenerator: AIInsightsGenerator
    
    init(insightsGenerator: AIInsightsGenerator = AIInsightsGenerator()) {
        self.insightsGenerator = insightsGenerator
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("API Key Options")) {
                    Toggle("Use Free Test API Key", isOn: $useTestKey)
                        .onChange(of: useTestKey) { oldValue, newValue in
                            OpenAIService.shared.toggleTestApiKey(newValue)
                            insightsGenerator.refreshAfterAPIKeyChange()
                        }
                    
                    if useTestKey {
                        Text("Using the free test API key with a $20 spending limit for all test users.")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Using your personal API key.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !useTestKey {
                    Section(header: Text("Personal OpenAI API Key")) {
                        SecureField("Enter API Key", text: $apiKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        
                        Text("Your API key is stored securely in your device's UserDefaults and is never shared.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section {
                        Button("Save API Key") {
                            OpenAIService.shared.saveAPIKey(apiKey)
                            insightsGenerator.refreshAfterAPIKeyChange()
                            showingSuccessMessage = true
                        }
                        .disabled(apiKey.isEmpty)
                        
                        if !apiKey.isEmpty {
                            Button("Clear API Key") {
                                apiKey = ""
                                OpenAIService.shared.clearAPIKey()
                                insightsGenerator.refreshAfterAPIKeyChange()
                                showingSuccessMessage = true
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                
                Section(header: Text("About AI Insights")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How it works")
                            .font(.headline)
                        
                        Text("The AI Insights feature uses OpenAI's API to analyze your hormone protocols and cycles. It provides personalized feedback, optimization suggestions, and educational content based on your specific therapy details.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy")
                            .font(.headline)
                        
                        Text("Only anonymized therapy data is sent to OpenAI for analysis. No personally identifiable information is shared. All API calls are made directly from your device.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test API Key")
                            .font(.headline)
                        
                        Text("A free test API key is provided for evaluation purposes with a $20 spending limit across all users. For continued use after testing, we recommend using your own API key.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Settings Saved", isPresented: $showingSuccessMessage) {
                Button("OK") { }
            } message: {
                Text(apiKey.isEmpty ? 
                     "API key has been cleared. The app will use mock data for insights." : 
                     "API key has been saved. The app will now use OpenAI for generating insights.")
            }
        }
    }
}

#Preview {
    NavigationStack {
        AIInsightsView()
            .environmentObject(AppDataStore())
    }
} 