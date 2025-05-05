import SwiftUI

struct ProtocolDetailView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @State private var showingAddBloodSheet = false
    @State private var showingCalibrateConfirm = false
    
    let injectionProtocol: InjectionProtocol
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Protocol summary
                protocolSummaryView
                
                // Display the latest bloodwork info if available
                if let latestSample = injectionProtocol.bloodSamples.max(by: { $0.date < $1.date }) {
                    latestBloodworkView(sample: latestSample)
                }
                
                // Chart
                // TestosteroneChart(treatmentProtocol: injectionProtocol)
                //    .frame(height: 300)
                
                // Temporary placeholder until chart compiler issues are resolved
                Text("Chart temporarily disabled - compiler limitations")
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.vertical)
                
                // Action buttons
                HStack {
                    Button(action: {
                        showingAddBloodSheet = true
                    }) {
                        Label("Add Bloodwork", systemImage: "drop.fill")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(action: {
                        dataStore.calibrateProtocol(injectionProtocol)
                        showingCalibrateConfirm = true
                    }) {
                        Label("Recalibrate Model", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)
                    .disabled(injectionProtocol.bloodSamples.isEmpty)
                    
                    // New navigation link to calibration details
                    NavigationLink(destination: CalibrationResultView(injectionProtocol: injectionProtocol)) {
                        Label("View Calibration Details", systemImage: "chart.xyaxis.line")
                    }
                    .buttonStyle(.bordered)
                    .disabled(injectionProtocol.bloodSamples.isEmpty)
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle(injectionProtocol.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    dataStore.protocolToEdit = injectionProtocol
                    dataStore.isPresentingProtocolForm = true
                }
            }
        }
        .sheet(isPresented: $showingAddBloodSheet) {
            AddBloodworkView(injectionProtocol: injectionProtocol)
                .environmentObject(dataStore)
        }
        .alert("Calibration Updated", isPresented: $showingCalibrateConfirm) {
            Button("OK", role: .cancel) { }
        }
        .onAppear {
            dataStore.selectProtocol(id: injectionProtocol.id)
        }
    }
    
    // MARK: - Protocol summary based on protocol type
    
    var protocolSummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Display information based on protocol type
            switch injectionProtocol.protocolType {
            case .legacyEster:
                legacyEsterSummary
                
            case .compound:
                if let compoundID = injectionProtocol.compoundID,
                   let compound = dataStore.compoundLibrary.compound(withID: compoundID) {
                    compoundSummary(compound: compound)
                } else {
                    Text("Invalid compound selection")
                        .foregroundColor(.red)
                }
                
            case .blend:
                if let blendID = injectionProtocol.blendID,
                   let blend = dataStore.compoundLibrary.blend(withID: blendID) {
                    blendSummary(blend: blend)
                } else {
                    Text("Invalid blend selection")
                        .foregroundColor(.red)
                }
            }
            
            // Common protocol details
            Divider()
            
            HStack {
                Text("Dose:")
                    .bold()
                Spacer()
                Text("\(injectionProtocol.doseMg, specifier: "%.1f") mg")
            }
            
            HStack {
                Text("Frequency:")
                    .bold()
                Spacer()
                if injectionProtocol.frequencyDays == 7 {
                    Text("Weekly")
                } else if injectionProtocol.frequencyDays == 3.5 {
                    Text("Twice weekly")
                } else if injectionProtocol.frequencyDays == 1 {
                    Text("Daily")
                } else {
                    Text("Every \(injectionProtocol.frequencyDays, specifier: "%.1f") days")
                }
            }
            
            // Show administration route if available
            if let routeString = injectionProtocol.selectedRoute,
               let route = Compound.Route(rawValue: routeString) {
                HStack {
                    Text("Route:")
                        .bold()
                    Spacer()
                    Text(route.displayName)
                }
            }
            
            HStack {
                Text("Start Date:")
                    .bold()
                Spacer()
                Text(injectionProtocol.startDate, style: .date)
            }
            
            if let notes = injectionProtocol.notes, !notes.isEmpty {
                Text("Notes:")
                    .bold()
                Text(notes)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Protocol type-specific summaries
    
    var legacyEsterSummary: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Testosterone Ester:")
                    .bold()
                Spacer()
                Text(injectionProtocol.ester.name)
            }
            
            HStack {
                Text("Half-life:")
                    .bold()
                Spacer()
                Text("\(injectionProtocol.ester.halfLifeDays, specifier: "%.1f") days")
            }
        }
    }
    
    func compoundSummary(compound: Compound) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Compound:")
                    .bold()
                Spacer()
                Text(compound.fullDisplayName)
            }
            
            HStack {
                Text("Half-life:")
                    .bold()
                Spacer()
                Text("\(compound.halfLifeDays, specifier: "%.1f") days")
            }
            
            HStack {
                Text("Class:")
                    .bold()
                Spacer()
                Text(compound.classType.displayName)
            }
        }
    }
    
    func blendSummary(blend: VialBlend) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Blend:")
                    .bold()
                Spacer()
                Text(blend.name)
            }
            
            if let manufacturer = blend.manufacturer {
                HStack {
                    Text("Manufacturer:")
                        .bold()
                    Spacer()
                    Text(manufacturer)
                }
            }
            
            HStack {
                Text("Composition:")
                    .bold()
                Spacer()
            }
            
            Text(blend.compositionDescription(using: dataStore.compoundLibrary))
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Blood sample summary
    
    func latestBloodworkView(sample: BloodSample) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest Blood Test")
                .font(.headline)
            
            HStack {
                Text("Date:")
                    .bold()
                Spacer()
                Text(sample.date, style: .date)
            }
            
            HStack {
                Text("Measured Level:")
                    .bold()
                Spacer()
                Text("\(formatValue(sample.value, unit: sample.unit)) \(sample.unit)")
            }
            
            // Calculate the model's prediction for the same date
            let modelPrediction = dataStore.calculateLevel(
                at: sample.date,
                for: injectionProtocol, 
                using: dataStore.profile.calibrationFactor
            )
            
            HStack {
                Text("Model Prediction:")
                    .bold()
                Spacer()
                Text("\(formatValue(modelPrediction, unit: dataStore.profile.unit)) \(dataStore.profile.unit)")
            }
            
            // Show error percentage
            let errorPercentage = abs((modelPrediction - sample.value) / sample.value * 100)
            HStack {
                Text("Deviation:")
                    .bold()
                Spacer()
                Text("\(formatValue(errorPercentage, unit: "%"))%")
                    .foregroundColor(errorPercentage < 10 ? .green : (errorPercentage < 20 ? .yellow : .red))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Helper for value formatting
    
    func formatValue(_ value: Double, unit: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if unit == "nmol/L" {
            formatter.maximumFractionDigits = 1
        } else if unit == "%" {
            formatter.maximumFractionDigits = 1
        } else { // ng/dL typically whole numbers
            formatter.maximumFractionDigits = 0
        }
        formatter.minimumFractionDigits = formatter.maximumFractionDigits // Ensure consistency
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

#Preview {
    NavigationStack {
        ProtocolDetailView(injectionProtocol: InjectionProtocol(
            name: "Test Protocol",
            ester: .cypionate,
            doseMg: 100,
            frequencyDays: 7,
            startDate: Date()
        ))
        .environmentObject(AppDataStore())
    }
} 