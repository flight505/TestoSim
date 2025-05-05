import SwiftUI

struct ProtocolFormView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Environment(\.dismiss) var dismiss
    
    var protocolToEdit: InjectionProtocol?
    
    // MARK: - State variables
    @State private var name: String = ""
    @State private var doseMg: String = ""
    @State private var frequencyDays: String = ""
    @State private var startDate: Date = Date()
    @State private var notes: String = ""
    
    // Protocol type and selection variables
    @State private var protocolType: ProtocolType = .compound
    @State private var selectedCompoundID: UUID?
    @State private var selectedBlendID: UUID?
    @State private var selectedRoute: Compound.Route = .intramuscular
    
    // Sheet presentation flags
    @State private var showingCompoundPicker = false
    @State private var showingBlendPicker = false
    
    var isEditing: Bool {
        protocolToEdit != nil
    }
    
    var selectedCompoundName: String {
        if let id = selectedCompoundID,
           let compound = dataStore.compoundLibrary.compound(withID: id) {
            return compound.fullDisplayName
        }
        return "Select Compound"
    }
    
    var selectedBlendName: String {
        if let id = selectedBlendID,
           let blend = dataStore.compoundLibrary.blend(withID: id) {
            return blend.name
        }
        return "Select Blend"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Protocol Details")) {
                    TextField("Name", text: $name)
                    
                    // Protocol Type Selector
                    Picker("Type", selection: $protocolType) {
                        Text("Compound").tag(ProtocolType.compound)
                        Text("Blend").tag(ProtocolType.blend)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: protocolType) { oldValue, newValue in
                        // Reset selection when changing type
                        if protocolType != .compound {
                            selectedCompoundID = nil
                        }
                        if protocolType != .blend {
                            selectedBlendID = nil
                        }
                    }
                    
                    // Dynamically show the appropriate selection UI based on protocol type
                    switch protocolType {
                    case .compound:
                        Button(action: {
                            showingCompoundPicker = true
                        }) {
                            HStack {
                                Text("Compound")
                                Spacer()
                                Text(selectedCompoundName)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        // Show route picker if compound is selected
                        if selectedCompoundID != nil,
                           let compound = dataStore.compoundLibrary.compound(withID: selectedCompoundID!) {
                            
                            // Filter routes to only those supported by the compound
                            let supportedRoutes = compound.defaultBioavailability.keys.filter { 
                                (compound.defaultBioavailability[$0] ?? 0) > 0 
                            }
                            
                            if !supportedRoutes.isEmpty {
                                Picker("Administration Route", selection: $selectedRoute) {
                                    ForEach(supportedRoutes.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { route in
                                        Text(route.displayName).tag(route)
                                    }
                                }
                                .onChange(of: selectedRoute) { oldValue, newRoute in
                                    // Ensure the route is valid for this compound
                                    if let compound = dataStore.compoundLibrary.compound(withID: selectedCompoundID!),
                                       (compound.defaultBioavailability[newRoute] ?? 0) <= 0 {
                                        // If invalid, pick the first supported route
                                        if let firstValid = compound.defaultBioavailability.keys.first {
                                            selectedRoute = firstValid
                                        }
                                    }
                                }
                            }
                        }
                        
                    case .blend:
                        Button(action: {
                            showingBlendPicker = true
                        }) {
                            HStack {
                                Text("Vial Blend")
                                Spacer()
                                Text(selectedBlendName)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        // For blends, always default to intramuscular
                        Picker("Administration Route", selection: $selectedRoute) {
                            Text("Intramuscular (IM)").tag(Compound.Route.intramuscular)
                        }
                    }
                    
                    #if os(iOS)
                    TextField("Dose (mg)", text: $doseMg)
                        .keyboardType(.decimalPad)
                    #else
                    TextField("Dose (mg)", text: $doseMg)
                    #endif
                    
                    #if os(iOS)
                    TextField("Frequency (days)", text: $frequencyDays)
                        .keyboardType(.decimalPad)
                    #else
                    TextField("Frequency (days)", text: $frequencyDays)
                    #endif
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle(isEditing ? "Edit Protocol" : "New Protocol")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") {
                        saveProtocol()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let protocolToEdit = protocolToEdit {
                    // Fill form with existing protocol data
                    name = protocolToEdit.name
                    
                    // Determine which protocol type we're editing
                    protocolType = protocolToEdit.protocolType
                    selectedCompoundID = protocolToEdit.compoundID
                    selectedBlendID = protocolToEdit.blendID
                    
                    // Set route if available
                    if let routeString = protocolToEdit.selectedRoute,
                       let route = Compound.Route(rawValue: routeString) {
                        selectedRoute = route
                    } else {
                        selectedRoute = .intramuscular // Default
                    }
                    
                    doseMg = String(format: "%.1f", protocolToEdit.doseMg)
                    frequencyDays = String(format: "%.1f", protocolToEdit.frequencyDays)
                    startDate = protocolToEdit.startDate
                    notes = protocolToEdit.notes ?? ""
                }
            }
            .sheet(isPresented: $showingCompoundPicker) {
                CompoundListView(selectedCompoundID: $selectedCompoundID)
                    .environmentObject(dataStore)
            }
            .sheet(isPresented: $showingBlendPicker) {
                VialBlendListView(selectedBlendID: $selectedBlendID)
                    .environmentObject(dataStore)
            }
        }
    }
    
    private var isValid: Bool {
        // Basic validation
        guard !name.isEmpty && Double(doseMg) != nil && Double(frequencyDays) != nil else {
            return false
        }
        
        // Type-specific validation
        switch protocolType {
        case .compound:
            return selectedCompoundID != nil
        case .blend:
            return selectedBlendID != nil
        }
    }
    
    private func saveProtocol() {
        guard let doseValue = Double(doseMg),
              let frequencyValue = Double(frequencyDays) else {
            return
        }
        
        if isEditing, let protocolToEdit = protocolToEdit {
            var updatedProtocol = protocolToEdit
            updatedProtocol.name = name
            updatedProtocol.doseMg = doseValue
            updatedProtocol.frequencyDays = frequencyValue
            updatedProtocol.startDate = startDate
            updatedProtocol.notes = notes.isEmpty ? nil : notes
            
            // Update the protocol type-specific properties
            switch protocolType {
            case .compound:
                updatedProtocol.compoundID = selectedCompoundID
                updatedProtocol.blendID = nil
                updatedProtocol.selectedRoute = selectedRoute.rawValue
                
            case .blend:
                updatedProtocol.compoundID = nil
                updatedProtocol.blendID = selectedBlendID
                updatedProtocol.selectedRoute = selectedRoute.rawValue
            }
            
            dataStore.updateProtocol(updatedProtocol)
        } else {
            var newProtocol = InjectionProtocol(
                name: name,
                doseMg: doseValue,
                frequencyDays: frequencyValue,
                startDate: startDate,
                notes: notes.isEmpty ? nil : notes
            )
            
            // Set the protocol type-specific properties
            switch protocolType {
            case .compound:
                newProtocol.compoundID = selectedCompoundID
                newProtocol.selectedRoute = selectedRoute.rawValue
                
            case .blend:
                newProtocol.blendID = selectedBlendID
                newProtocol.selectedRoute = selectedRoute.rawValue
            }
            
            dataStore.addProtocol(newProtocol)
        }
        
        dismiss()
    }
}

#Preview {
    ProtocolFormView()
        .environmentObject(AppDataStore())
} 