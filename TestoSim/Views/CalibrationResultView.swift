import SwiftUI
import Charts

struct CalibrationResultView: View {
    @EnvironmentObject var dataStore: AppDataStore
    
    // Sample calibration data (in a real app, this would come from the model)
    let calibrationResults: CalibrationResults
    
    struct CalibrationResults {
        let halfLifeDays: Double
        let absorptionRateFactor: Double
        let calibrationFactor: Double
        let treatmentProtocol: InjectionProtocol
        let compound: Compound
        let bloodSamples: [BloodSample]
        let originalPredictions: [DataPoint]
        let calibratedPredictions: [DataPoint]
        let rmseImprovement: Double  // Root Mean Square Error improvement percentage
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calibration Complete")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Protocol: \(calibrationResults.treatmentProtocol.name)")
                        .font(.headline)
                    
                    Text("Compound: \(calibrationResults.compound.fullDisplayName)")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Chart
                chartSection
                
                // Parameters
                parametersSection
                
                // Blood Samples
                bloodSamplesSection
                
                // Improvement metrics
                improvementSection
            }
            .padding()
        }
    }
    
    var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calibration Results")
                .font(.headline)
            
            Text("The chart shows the original and calibrated testosterone predictions alongside your blood samples.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Chart {
                // Original prediction line
                ForEach(calibrationResults.originalPredictions) { point in
                    LineMark(
                        x: .value("Date", point.time),
                        y: .value("Level", point.level)
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                }
                
                // Calibrated prediction line
                ForEach(calibrationResults.calibratedPredictions) { point in
                    LineMark(
                        x: .value("Date", point.time),
                        y: .value("Level", point.level)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                
                // Blood samples as points
                ForEach(calibrationResults.bloodSamples) { sample in
                    PointMark(
                        x: .value("Date", sample.date),
                        y: .value("Level", sample.value)
                    )
                    .foregroundStyle(.red)
                    .symbolSize(100)
                }
            }
            .frame(height: 250)
            
            // Legend
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Blood Samples")
                        .font(.caption)
                }
                
                HStack {
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 15, height: 2)
                    Text("Original Prediction")
                        .font(.caption)
                }
                
                HStack {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 15, height: 2)
                    Text("Calibrated Prediction")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    var parametersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calibrated Parameters")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Half-life:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(calibrationResults.halfLifeDays, specifier: "%.1f") days")
                }
                
                HStack {
                    Text("Absorption rate:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(calibrationResults.absorptionRateFactor, specifier: "%.2f")x")
                }
                
                HStack {
                    Text("Calibration factor:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(calibrationResults.calibrationFactor, specifier: "%.2f")x")
                }
                
                Divider()
                
                HStack {
                    Text("Based on:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(calibrationResults.bloodSamples.count) blood samples")
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    var bloodSamplesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Blood Samples Used")
                .font(.headline)
            
            ForEach(calibrationResults.bloodSamples) { sample in
                HStack {
                    VStack(alignment: .leading) {
                        Text(formatDate(sample.date))
                            .font(.subheadline)
                    }
                    
                    Spacer()
                    
                    Text("\(sample.value, specifier: "%.1f") \(dataStore.profile.unit)")
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 4)
                
                if sample.id != calibrationResults.bloodSamples.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // Helper function to format dates
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var improvementSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calibration Quality")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Prediction Improvement:")
                        .fontWeight(.semibold)
                    Text("The calibrated model is \(calibrationResults.rmseImprovement, specifier: "%.1f")% more accurate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Simple quality indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: min(1.0, calibrationResults.rmseImprovement / 100))
                        .stroke(
                            calibrationResults.rmseImprovement > 50 ? Color.green :
                                calibrationResults.rmseImprovement > 25 ? Color.yellow : Color.red,
                            lineWidth: 6
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(calibrationResults.rmseImprovement))%")
                        .font(.system(size: 12, weight: .bold))
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// Preview
struct CalibrationResultView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample data for preview
        let appDataStore = AppDataStore()
        
        // Create a sample compound
        let compound = Compound(
            id: UUID(),
            commonName: "Testosterone Cypionate",
            classType: .testosterone,
            ester: "cypionate",
            halfLifeDays: 8.0,
            defaultBioavailability: [.intramuscular: 1.0],
            defaultAbsorptionRateKa: [.intramuscular: 0.7]
        )
        
        // Create a sample protocol
        let testProtocol = InjectionProtocol(
            name: "Test Protocol",
            doseMg: 100,
            frequencyDays: 7,
            startDate: Date().addingTimeInterval(-60*60*24*30) // 30 days ago
        )
        
        // Add compoundID to the protocol
        var updatedProtocol = testProtocol
        updatedProtocol.compoundID = compound.id
        
        // Create sample blood samples
        let bloodSamples: [BloodSample] = [
            BloodSample(date: Date().addingTimeInterval(-60*60*24*20), value: 650, unit: "ng/dL"),
            BloodSample(date: Date().addingTimeInterval(-60*60*24*10), value: 750, unit: "ng/dL"),
            BloodSample(date: Date().addingTimeInterval(-60*60*24*2), value: 550, unit: "ng/dL"),
        ]
        
        // Create sample prediction points
        let originalPredictions: [DataPoint] = (0...30).map { i in
            let date = Date().addingTimeInterval(-60*60*24*Double(30-i))
            let baseValue = 500.0 + 200 * sin(Double(i) / 7.0 * .pi)
            return DataPoint(time: date, level: baseValue)
        }
        
        let calibratedPredictions: [DataPoint] = (0...30).map { i in
            let date = Date().addingTimeInterval(-60*60*24*Double(30-i))
            let baseValue = 600.0 + 150 * sin(Double(i) / 7.0 * .pi)
            return DataPoint(time: date, level: baseValue)
        }
        
        // Create sample calibration results
        let sampleResults = CalibrationResultView.CalibrationResults(
            halfLifeDays: 7.5,
            absorptionRateFactor: 1.2,
            calibrationFactor: 0.95,
            treatmentProtocol: updatedProtocol,
            compound: compound,
            bloodSamples: bloodSamples,
            originalPredictions: originalPredictions,
            calibratedPredictions: calibratedPredictions,
            rmseImprovement: 62.5
        )
        
        return CalibrationResultView(calibrationResults: sampleResults)
            .environmentObject(appDataStore)
    }
} 