import SwiftUI

struct ProtocolDetailView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @State private var showingAddBloodSheet = false
    @State private var showingCalibrateConfirm = false
    @State private var showingNotificationOptions = false
    @State private var showingEnableNotificationsAlert = false
    
    let injectionProtocol: InjectionProtocol
    
    // Try to get the compound for any protocol type
    var resolvedCompound: Compound? {
        // If protocol has a direct compound reference, use that
        if let compoundID = injectionProtocol.compoundID {
            return dataStore.compoundLibrary.compound(withID: compoundID)
        }
        return nil
    }
    
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
                TestosteroneChart(treatmentProtocol: injectionProtocol)
                    .frame(height: 300)
                
                // Next injection information
                nextInjectionView
                
                // Action buttons section
                actionButtonsView
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
            dataStore.selectProtocol(id: injectionProtocol.id)
            dataStore.recalcSimulation()
            // Check if the protocol needs a compound fix
            fixProtocolCompound()
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
                                for: injectionProtocol,
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
                        protocolID: injectionProtocol.id,
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
                dataStore.calibrateProtocol(injectionProtocol)
                showingCalibrateConfirm = true
            }) {
                Label("Recalibrate", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .disabled(injectionProtocol.bloodSamples.isEmpty)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Protocol summary based on protocol type
    
    var protocolSummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Display information based on protocol type
            switch injectionProtocol.protocolType {
            case .compound:
                if let compoundID = injectionProtocol.compoundID,
                   let compound = dataStore.compoundLibrary.compound(withID: compoundID) {
                    compoundSummary(compound: compound)
                } else {
                    // Fallback: Try to extract compound name from protocol name
                    let esterNames = ["propionate", "phenylpropionate", "isocaproate", "enanthate", 
                                     "cypionate", "decanoate", "undecanoate"]
                    
                    let foundEster = esterNames.first { ester in
                        injectionProtocol.name.lowercased().contains(ester) ||
                        (injectionProtocol.notes ?? "").lowercased().contains(ester)
                    }
                    
                    if let esterName = foundEster,
                       let compound = dataStore.compoundLibrary.compounds.first(where: { 
                           $0.classType == .testosterone && 
                           $0.ester?.lowercased() == esterName.lowercased() 
                       }) {
                        // Found a matching compound, show it
                        compoundSummary(compound: compound)
                        
                        // This will be updated in onAppear
                        Text("Protocol will be updated")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Invalid compound selection")
                            .foregroundColor(.red)
                    }
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
                Text(injectionProtocol.startDate, style: .date)
            }
            
            if let notes = injectionProtocol.notes, !notes.isEmpty {
                Text("Notes:")
                    .bold()
                
                // Filter out the extended data JSON
                let filteredNotes = notes.contains("---EXTENDED_DATA---") 
                    ? notes.components(separatedBy: "---EXTENDED_DATA---").first?.trimmingCharacters(in: .whitespacesAndNewlines) 
                    : notes
                
                if let filteredNotes = filteredNotes, !filteredNotes.isEmpty {
                    Text(filteredNotes)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Protocol type-specific summaries
    
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
            let modelPrediction = dataStore.predictedLevel(on: sample.date, for: injectionProtocol)
            
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
    
    // MARK: - Helper Methods
    
    private func nextInjectionDate() -> Date? {
        let today = Date()
        let endDate = today.addingTimeInterval(60 * 24 * 3600) // Look 60 days ahead
        let upcomingDates = injectionProtocol.injectionDates(from: today, upto: endDate)
        
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
    
    // MARK: - Protocol Compound Auto-Fix
    
    private func fixProtocolCompound() {
        // Only fix protocols that don't have compounds
        if injectionProtocol.compoundID == nil {
            let esterNames = ["propionate", "phenylpropionate", "isocaproate", "enanthate", 
                             "cypionate", "decanoate", "undecanoate"]
            
            // Look for matching ester in name or notes
            let foundEster = esterNames.first { ester in
                injectionProtocol.name.lowercased().contains(ester) ||
                (injectionProtocol.notes ?? "").lowercased().contains(ester)
            }
            
            if let esterName = foundEster,
               let compound = dataStore.compoundLibrary.compounds.first(where: { 
                   $0.classType == .testosterone && 
                   $0.ester?.lowercased() == esterName.lowercased() 
               }) {
                // Found a matching compound, update protocol
                var updatedProtocol = injectionProtocol
                updatedProtocol.compoundID = compound.id
                updatedProtocol.selectedRoute = updatedProtocol.selectedRoute ?? 
                                             Compound.Route.intramuscular.rawValue
                
                // Update protocol in datastore
                dataStore.updateProtocol(updatedProtocol)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProtocolDetailView(injectionProtocol: InjectionProtocol(
            name: "Test Protocol",
            doseMg: 100,
            frequencyDays: 7,
            startDate: Date()
        ))
        .environmentObject(AppDataStore())
    }
} 