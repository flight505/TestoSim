import SwiftUI
import Charts

struct CalibrationResultView: View {
    @EnvironmentObject var dataStore: AppDataStore
    let injectionProtocol: InjectionProtocol
    
    // These would be provided by the PK engine during calibration
    @State private var originalParameters: CalibrationParameters? = nil
    @State private var calibratedParameters: CalibrationParameters? = nil
    @State private var correlationCoefficient: Double = 0.0
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header section
                HStack {
                    VStack(alignment: .leading) {
                        Text("Calibration Results")
                            .font(.title)
                            .bold()
                        
                        Text("Protocol: \(injectionProtocol.name)")
                            .font(.subheadline)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                        .opacity(0.7)
                }
                .padding()
                
                if isLoading {
                    // Loading indicator
                    ProgressView("Calculating parameters...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    // Results
                    VStack(alignment: .leading, spacing: 15) {
                        // Model Fit Quality
                        Section(header: SectionHeader(title: "Model Fit Quality")) {
                            HStack {
                                Text("Correlation coefficient:")
                                Spacer()
                                Text(String(format: "%.3f", correlationCoefficient))
                                    .bold()
                            }
                            .padding(.horizontal)
                            
                            // Correlation coefficient visualization
                            CorrelationBar(value: correlationCoefficient)
                                .frame(height: 30)
                                .padding(.horizontal)
                            
                            Text(correlationQualityDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        
                        // Parameter Comparison
                        if let original = originalParameters, let calibrated = calibratedParameters {
                            Section(header: SectionHeader(title: "Calibration Parameters")) {
                                ParameterComparisonView(
                                    parameterName: "Elimination Rate (ke)",
                                    originalValue: original.ke,
                                    calibratedValue: calibrated.ke,
                                    unit: "day⁻¹"
                                )
                                
                                ParameterComparisonView(
                                    parameterName: "Absorption Rate (ka)",
                                    originalValue: original.ka,
                                    calibratedValue: calibrated.ka,
                                    unit: "day⁻¹"
                                )
                                
                                ParameterComparisonView(
                                    parameterName: "Effective Half-life",
                                    originalValue: log(2) / original.ke,
                                    calibratedValue: log(2) / calibrated.ke,
                                    unit: "days"
                                )
                                
                                ParameterComparisonView(
                                    parameterName: "Calibration Factor",
                                    originalValue: 1.0,
                                    calibratedValue: dataStore.profile.calibrationFactor,
                                    unit: ""
                                )
                            }
                        }
                        
                        // Blood Level Prediction
                        Section(header: SectionHeader(title: "Predicted vs Actual Levels")) {
                            if injectionProtocol.bloodSamples.isEmpty {
                                Text("No blood samples available for comparison")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            } else {
                                // Simple chart showing predicted vs actual blood levels
                                Chart {
                                    ForEach(injectionProtocol.bloodSamples) { sample in
                                        PointMark(
                                            x: .value("Date", sample.date),
                                            y: .value("Level", sample.value)
                                        )
                                        .foregroundStyle(.red)
                                        .symbol(.circle)
                                        .symbolSize(60)
                                        
                                        // Predicted level at this date (using original model)
                                        let originalPrediction = dataStore.calculateLevelWithParameters(
                                            at: sample.date, 
                                            for: injectionProtocol, 
                                            using: 1.0,
                                            parameters: originalParameters
                                        )
                                        
                                        PointMark(
                                            x: .value("Date", sample.date),
                                            y: .value("Original Prediction", originalPrediction)
                                        )
                                        .foregroundStyle(.blue)
                                        .symbol(.square)
                                        .symbolSize(40)
                                        
                                        // Predicted level at this date (using calibrated model)
                                        let calibratedPrediction = dataStore.calculateLevel(
                                            at: sample.date, 
                                            for: injectionProtocol, 
                                            using: dataStore.profile.calibrationFactor
                                        )
                                        
                                        PointMark(
                                            x: .value("Date", sample.date),
                                            y: .value("Calibrated Prediction", calibratedPrediction)
                                        )
                                        .foregroundStyle(.green)
                                        .symbol(.diamond)
                                        .symbolSize(60)
                                    }
                                }
                                .frame(height: 200)
                                .padding(.horizontal)
                                
                                // Legend
                                HStack {
                                    LegendItem(color: .red, symbol: "circle.fill", label: "Actual")
                                    LegendItem(color: .blue, symbol: "square.fill", label: "Original Prediction")
                                    LegendItem(color: .green, symbol: "diamond.fill", label: "Calibrated")
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Explanation
                        Section(header: SectionHeader(title: "Understanding Calibration")) {
                            Text("The Bayesian calibration process adjusts the model parameters to better match your actual blood test results. This makes future predictions more accurate for your specific body.")
                                .font(.body)
                                .padding(.horizontal)
                            
                            Text("• Elimination Rate (ke): How quickly your body clears the hormone")
                                .font(.caption)
                                .padding(.horizontal)
                            
                            Text("• Absorption Rate (ka): How quickly the hormone is absorbed from the injection site")
                                .font(.caption)
                                .padding(.horizontal)
                            
                            Text("• Higher correlation values (closer to 1.0) indicate a better model fit")
                                .font(.caption)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding()
            .onAppear {
                // Simulate loading the data (would actually come from the PK engine)
                loadCalibrationData()
            }
        }
        .navigationTitle("Calibration Details")
    }
    
    private var correlationQualityDescription: String {
        if correlationCoefficient >= 0.9 {
            return "Excellent fit: The model very accurately predicts your blood levels."
        } else if correlationCoefficient >= 0.8 {
            return "Good fit: The model predictions closely match your blood levels."
        } else if correlationCoefficient >= 0.6 {
            return "Acceptable fit: The model is generally aligned with your blood levels."
        } else if correlationCoefficient >= 0.4 {
            return "Moderate fit: The model has some predictive value but with notable deviations."
        } else {
            return "Poor fit: The model may not accurately predict your blood levels. Consider adding more blood samples."
        }
    }
    
    private func loadCalibrationData() {
        // In a real implementation, this would fetch data from the PK engine
        // For now, we'll simulate loading with placeholder data
        
        // Simulate a loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Create placeholder data based on the protocol's ester
            let defaultHalfLife = injectionProtocol.ester.halfLifeDays
            let ke = log(2) / defaultHalfLife
            
            // Assume some nominal values for the original parameters
            self.originalParameters = CalibrationParameters(
                ke: ke,
                ka: 0.5  // A typical absorption rate
            )
            
            // Simulate calibrated parameters with some variation
            self.calibratedParameters = CalibrationParameters(
                ke: ke * (0.8 + 0.4 * Double.random(in: 0...1)),  // +/- 20% variation
                ka: 0.5 * (0.7 + 0.6 * Double.random(in: 0...1))  // +/- 30% variation
            )
            
            // Simulate a reasonable correlation coefficient
            self.correlationCoefficient = 0.7 + 0.25 * Double.random(in: 0...1)
            
            self.isLoading = false
        }
    }
}

// MARK: - Supporting Types

struct CalibrationParameters {
    let ke: Double  // Elimination rate constant (day^-1)
    let ka: Double  // Absorption rate constant (day^-1)
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
            .padding(.horizontal)
            .padding(.top, 10)
    }
}

struct CorrelationBar: View {
    let value: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(0.2)
                    .foregroundColor(.gray)
                
                Rectangle()
                    .frame(width: min(CGFloat(value) * geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(correlationColor)
            }
            .cornerRadius(5)
        }
    }
    
    var correlationColor: Color {
        if value >= 0.9 {
            return .green
        } else if value >= 0.7 {
            return .blue
        } else if value >= 0.5 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct ParameterComparisonView: View {
    let parameterName: String
    let originalValue: Double
    let calibratedValue: Double
    let unit: String
    
    var percentChange: Double {
        ((calibratedValue / originalValue) - 1.0) * 100.0
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(parameterName)
                .font(.subheadline)
                .padding(.horizontal)
            
            HStack {
                Text("Original:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.3f", originalValue)) \(unit)")
                    .monospacedDigit()
            }
            .padding(.horizontal)
            
            HStack {
                Text("Calibrated:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.3f", calibratedValue)) \(unit)")
                    .monospacedDigit()
                    .bold()
            }
            .padding(.horizontal)
            
            HStack {
                Text("Change:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(percentChange >= 0 ? "+" : "")\(String(format: "%.1f", percentChange))%")
                    .foregroundColor(percentChange >= 0 ? .green : .red)
                    .bold()
            }
            .padding(.horizontal)
            .padding(.bottom, 5)
        }
        .padding(.vertical, 5)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct LegendItem: View {
    let color: Color
    let symbol: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Extend AppDataStore for calibration

extension AppDataStore {
    // This would be a real method that uses specific parameters for calculation
    func calculateLevelWithParameters(
        at targetDate: Date,
        for injectionProtocol: InjectionProtocol,
        using calibrationFactor: Double,
        parameters: CalibrationParameters?
    ) -> Double {
        // In a real implementation, this would use the specific parameters
        // For now, just return a value that's slightly different from the normal calculation
        let standardLevel = calculateLevel(at: targetDate, for: injectionProtocol, using: calibrationFactor)
        guard let parameters = parameters else { return standardLevel }
        
        // Simulate a difference based on parameter ratio
        let defaultHalfLife = injectionProtocol.ester.halfLifeDays
        let defaultKe = log(2) / defaultHalfLife
        let factor = parameters.ke / defaultKe
        
        return standardLevel * (0.7 + 0.6 * factor)
    }
}

#Preview {
    NavigationView {
        CalibrationResultView(injectionProtocol: InjectionProtocol(
            name: "Test Protocol",
            ester: .cypionate,
            doseMg: 100,
            frequencyDays: 7,
            startDate: Date().addingTimeInterval(-30 * 24 * 3600),
            notes: "Test protocol"
        ))
        .environmentObject(AppDataStore())
    }
} 