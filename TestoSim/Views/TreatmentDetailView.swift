import SwiftUI

struct TreatmentDetailView_Updated: View {
    @EnvironmentObject var dataStore: AppDataStore
    @State private var showingAddBloodSheet = false
    @State private var showingCalibrateConfirm = false
    @State private var showingNotificationOptions = false
    @State private var showingEnableNotificationsAlert = false
    
    let treatment: Treatment
    
    // Try to get the compound for any treatment type
    var resolvedCompound: Compound? {
        // If treatment has a direct compound reference, use that
        if let compoundID = treatment.compoundID {
            return dataStore.compoundLibrary.compound(withID: compoundID)
        }
        return nil
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Treatment summary
                treatmentSummaryView
                
                // Display the latest bloodwork info if available
                if let bloodSamples = treatment.bloodSamples,
                   let latestSample = bloodSamples.max(by: { $0.date < $1.date }) {
                    latestBloodworkView(sample: latestSample)
                }
                
                // Chart
                TreatmentSimulationChart(simulationData: dataStore.treatmentSimulationData)
                    .frame(height: 300)
                
                // Next injection information
                nextInjectionView
                
                // Action buttons section
                actionButtonsView
            }
            .padding()
        }
        .navigationTitle(treatment.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    dataStore.treatmentToEdit = treatment
                    dataStore.isPresentingTreatmentForm = true
                }
            }
        }
        .sheet(isPresented: $showingAddBloodSheet) {
            AddBloodworkView_Updated(treatment: treatment)
                .environmentObject(dataStore)
        }
        .alert("Calibration Updated", isPresented: $showingCalibrateConfirm) {
            Button("OK", role: .cancel) { }
        }
        .alert("Enable Notifications", isPresented: $showingEnableNotificationsAlert) {
            Button("Settings", role: .none) {
                showingNotificationOptions = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Notifications are currently disabled. Would you like to enable them in settings?")
        }
        .sheet(isPresented: $showingNotificationOptions) {
            NotificationSettingsView()
                .environmentObject(dataStore)
        }
        .onAppear {
            dataStore.selectTreatment(id: treatment.id)
            dataStore.recalcSimulation()
        }
    }
    
    // MARK: - Next Injection View
    
    var nextInjectionView: some View {
        let nextInjection = nextInjectionDate()
        
        return VStack(alignment: .leading, spacing: 8) {
            Text("Next Injection")
                .font(.headline)
            
            HStack {
                if let nextDate = nextInjection {
                    VStack(alignment: .leading) {
                        Text(nextDate, style: .date)
                            .font(.title3)
                            .foregroundColor(.primary)
                        
                        Text(daysUntilNextInjection(nextDate))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if NotificationManager.shared.notificationsEnabled {
                            NotificationManager.shared.scheduleNotifications(
                                for: treatment,
                                using: dataStore.compoundLibrary
                            )
                        } else {
                            showingEnableNotificationsAlert = true
                        }
                    }) {
                        Label("Remind Me", systemImage: "bell")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("No upcoming injections scheduled")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Action Buttons View
    
    var actionButtonsView: some View {
        HStack {
            Button(action: {
                showingAddBloodSheet = true
            }) {
                Label("Add Bloodwork", systemImage: "drop.fill")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            // Record injection button (acknowledges adherence)
            Button(action: {
                if let nextDate = nextInjectionDate() {
                    dataStore.acknowledgeInjection(
                        treatmentID: treatment.id,
                        injectionDate: nextDate
                    )
                }
            }) {
                Label("Record Injection", systemImage: "checkmark.circle")
            }
            .buttonStyle(.bordered)
            .disabled(nextInjectionDate() == nil)
            
            Spacer()
            
            Button(action: {
                dataStore.calibrateTreatment(treatment)
                showingCalibrateConfirm = true
            }) {
                Label("Recalibrate", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .disabled(treatment.bloodSamples?.isEmpty ?? true)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Treatment summary based on treatment type
    
    var treatmentSummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Display information based on content type
            if let contentType = treatment.contentType {
                switch contentType {
                case .compound:
                    if let compoundID = treatment.compoundID,
                       let compound = dataStore.compoundLibrary.compound(withID: compoundID) {
                        compoundSummary(compound: compound)
                    } else {
                        Text("Invalid compound selection")
                            .foregroundColor(.red)
                    }
                    
                case .blend:
                    if let blendID = treatment.blendID,
                       let blend = dataStore.compoundLibrary.blend(withID: blendID) {
                        blendSummary(blend: blend)
                    } else {
                        Text("Invalid blend selection")
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Common treatment details
            Divider()
            
            HStack {
                Text("Dose:")
                    .bold()
                Spacer()
                if let doseMg = treatment.doseMg {
                    Text("\(doseMg, specifier: "%.1f") mg")
                } else {
                    Text("Not specified")
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("Frequency:")
                    .bold()
                Spacer()
                if let frequencyDays = treatment.frequencyDays {
                    if frequencyDays == 7 {
                        Text("Weekly")
                    } else if frequencyDays == 3.5 {
                        Text("Twice weekly")
                    } else if frequencyDays == 1 {
                        Text("Daily")
                    } else {
                        Text("Every \(frequencyDays, specifier: "%.1f") days")
                    }
                } else {
                    Text("Not specified")
                        .foregroundColor(.secondary)
                }
            }
            
            // Show administration route if available
            if let routeString = treatment.selectedRoute,
               let route = Compound.Route(rawValue: routeString) {
                HStack {
                    Text("Route:")
                        .bold()
                    Spacer()
                    Text(route.displayName)
                }
            } else {
                // Default route if not specified
                HStack {
                    Text("Route:")
                        .bold()
                    Spacer()
                    Text("Intramuscular (IM)")
                }
            }
            
            HStack {
                Text("Start Date:")
                    .bold()
                Spacer()
                Text(treatment.startDate, style: .date)
            }
            
            if let notes = treatment.notes, !notes.isEmpty {
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
    
    // MARK: - Treatment type-specific summaries
    
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
            let modelPrediction = dataStore.getLevelForDate(sample.date, for: treatment)
            
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
        return dataStore.formatValue(value, unit: unit)
    }
    
    // MARK: - Helper Methods
    
    private func nextInjectionDate() -> Date? {
        guard treatment.treatmentType == .simple,
              let frequencyDays = treatment.frequencyDays, frequencyDays > 0 else {
            return nil
        }
        
        let today = Date()
        let endDate = today.addingTimeInterval(60 * 24 * 3600) // Look 60 days ahead
        let upcomingDates = treatment.injectionDates(from: today, upto: endDate)
        
        return upcomingDates.first
    }
    
    private func daysUntilNextInjection(_ nextDate: Date) -> String {
        let today = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour], from: today, to: nextDate)
        
        if let days = components.day, let hours = components.hour {
            if days == 0 {
                return "Today"
            } else if days == 1 {
                return "Tomorrow"
            } else {
                return "In \(days) days, \(hours) hours"
            }
        }
        
        return ""
    }
}

// Using the imported TestosteroneChart from the TestosteroneChart.swift file
private struct TreatmentSimulationChart: View {
    let simulationData: [DataPoint]
    
    var body: some View {
        VStack {
            Text("Treatment Simulation")
                .font(.headline)
                .padding(.bottom, 8)
            
            if simulationData.isEmpty {
                Text("No simulation data available")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                GeometryReader { geometry in
                    // Simple line chart (would be replaced with a proper chart component)
                    Path { path in
                        guard let firstPoint = simulationData.first else { return }
                        
                        let maxValue = simulationData.map { $0.level }.max() ?? 1.0
                        let width = geometry.size.width
                        let height = geometry.size.height
                        
                        // Map the data points to screen coordinates
                        let points = simulationData.enumerated().map { (index, point) -> CGPoint in
                            let x = CGFloat(index) / CGFloat(simulationData.count - 1) * width
                            let y = height - CGFloat(point.level / maxValue) * height
                            return CGPoint(x: x, y: y)
                        }
                        
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)
                }
                .frame(height: 200)
                .overlay(
                    VStack {
                        Spacer()
                        HStack {
                            if let firstDate = simulationData.first?.time {
                                Text(firstDate, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if let lastDate = simulationData.last?.time {
                                Text(lastDate, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    NavigationStack {
        TreatmentDetailView_Updated(treatment: Treatment(
            name: "Test Treatment",
            startDate: Date(),
            notes: "Test notes",
            treatmentType: .simple
        ))
        .environmentObject(AppDataStore())
    }
}