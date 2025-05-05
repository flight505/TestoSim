import SwiftUI

struct CycleStageFormView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Binding var isPresented: Bool
    
    var cycle: Cycle
    var stageToEdit: CycleStage?
    
    @State private var stageName: String = ""
    @State private var startWeek: Int = 0
    @State private var durationWeeks: Int = 4
    @State private var isPresentingCompoundPicker = false
    @State private var isPresentingBlendPicker = false
    
    // Stage items
    @State private var compounds: [CompoundStageItem] = []
    @State private var blends: [BlendStageItem] = []
    
    // Temporary item being configured
    @State private var tempCompound: Compound?
    @State private var tempBlend: VialBlend?
    @State private var tempDoseMg: Double = 0
    @State private var tempFrequencyDays: Double = 0
    @State private var tempRoute: Compound.Route = .intramuscular
    @State private var isAddingItem = false
    @State private var itemType: ItemType = .compound
    
    enum ItemType {
        case compound, blend
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Stage Details")) {
                    TextField("Stage Name", text: $stageName)
                    
                    HStack {
                        Text("Start Week")
                        Spacer()
                        Picker("Start Week", selection: $startWeek) {
                            ForEach(0..<cycle.totalWeeks) { week in
                                Text("Week \(week + 1)").tag(week)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    Stepper("Duration: \(durationWeeks) weeks", value: $durationWeeks, in: 1...max(1, cycle.totalWeeks - startWeek))
                }
                
                Section(header: stageItemsHeader) {
                    if compounds.isEmpty && blends.isEmpty {
                        Text("No compounds or blends added")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(compounds) { item in
                            CompoundItemRow(item: item)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            compounds.removeAll { $0.id == item.id }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        
                        ForEach(blends) { item in
                            BlendItemRow(item: item)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            blends.removeAll { $0.id == item.id }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle(stageToEdit == nil ? "New Stage" : "Edit Stage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveStage()
                        isPresented = false
                    }
                    .disabled(stageName.isEmpty || (compounds.isEmpty && blends.isEmpty))
                }
            }
            .sheet(isPresented: $isPresentingCompoundPicker) {
                CompoundPickerView(selectedCompound: $tempCompound, onCompoundSelected: configureCompound)
            }
            .sheet(isPresented: $isPresentingBlendPicker) {
                BlendPickerView(selectedBlend: $tempBlend, onBlendSelected: configureBlend)
            }
            .sheet(isPresented: $isAddingItem) {
                if itemType == .compound, let compound = tempCompound {
                    ItemConfigurationView(
                        title: "Configure \(compound.fullDisplayName)",
                        doseMg: $tempDoseMg,
                        frequencyDays: $tempFrequencyDays,
                        route: $tempRoute,
                        onSave: {
                            addCompoundItem()
                            isAddingItem = false
                        },
                        onCancel: {
                            isAddingItem = false
                        }
                    )
                } else if itemType == .blend, let blend = tempBlend {
                    ItemConfigurationView(
                        title: "Configure \(blend.name)",
                        doseMg: $tempDoseMg,
                        frequencyDays: $tempFrequencyDays,
                        route: $tempRoute,
                        onSave: {
                            addBlendItem()
                            isAddingItem = false
                        },
                        onCancel: {
                            isAddingItem = false
                        }
                    )
                }
            }
            .onAppear {
                initializeForm()
            }
        }
    }
    
    private var stageItemsHeader: some View {
        HStack {
            Text("Compounds & Blends")
            
            Spacer()
            
            Menu {
                Button(action: {
                    itemType = .compound
                    isPresentingCompoundPicker = true
                }) {
                    Label("Add Compound", systemImage: "pill")
                }
                
                Button(action: {
                    itemType = .blend
                    isPresentingBlendPicker = true
                }) {
                    Label("Add Blend", systemImage: "cross.vial")
                }
            } label: {
                Image(systemName: "plus")
            }
        }
    }
    
    private func initializeForm() {
        if let stage = stageToEdit {
            stageName = stage.name
            startWeek = stage.startWeek
            durationWeeks = stage.durationWeeks
            compounds = stage.compounds
            blends = stage.blends
        } else {
            // Find the first available week after any existing stages
            if !cycle.stages.isEmpty {
                let lastStage = cycle.stages.max(by: { $0.startWeek + $0.durationWeeks < $1.startWeek + $1.durationWeeks })
                if let lastStage = lastStage {
                    startWeek = min(lastStage.startWeek + lastStage.durationWeeks, cycle.totalWeeks - 1)
                }
            }
            
            // Default stage name if creating new
            stageName = "Stage \(cycle.stages.count + 1)"
        }
    }
    
    private func saveStage() {
        // Create a new stage or update existing
        var updatedStage: CycleStage
        if let existingStage = stageToEdit {
            // Update existing stage
            updatedStage = existingStage
            updatedStage.name = stageName
            updatedStage.startWeek = startWeek
            updatedStage.durationWeeks = durationWeeks
            updatedStage.compounds = compounds
            updatedStage.blends = blends
            
            // Find and replace in cycle
            var updatedCycle = cycle
            if let index = updatedCycle.stages.firstIndex(where: { $0.id == existingStage.id }) {
                updatedCycle.stages[index] = updatedStage
            }
            
            // Save cycle
            dataStore.saveCycle(updatedCycle)
        } else {
            // Create new stage
            updatedStage = CycleStage(
                name: stageName,
                startWeek: startWeek,
                durationWeeks: durationWeeks,
                compounds: compounds,
                blends: blends
            )
            
            // Add to cycle
            var updatedCycle = cycle
            updatedCycle.stages.append(updatedStage)
            
            // Save cycle
            dataStore.saveCycle(updatedCycle)
        }
    }
    
    private func configureCompound(_ compound: Compound) {
        tempCompound = compound
        
        // Set default values
        if let route = Compound.Route(rawValue: Compound.Route.intramuscular.rawValue) {
            tempRoute = route
        }
        
        // Set default dosage based on compound class
        switch compound.classType {
        case .testosterone:
            tempDoseMg = 100
            tempFrequencyDays = 3.5
        case .trenbolone:
            tempDoseMg = 50
            tempFrequencyDays = 2
        default:
            tempDoseMg = 50
            tempFrequencyDays = 3.5
        }
        
        isPresentingCompoundPicker = false
        isAddingItem = true
    }
    
    private func configureBlend(_ blend: VialBlend) {
        tempBlend = blend
        
        // Set default values
        if let route = Compound.Route(rawValue: Compound.Route.intramuscular.rawValue) {
            tempRoute = route
        }
        
        // Set default values based on blend concentration
        tempDoseMg = 1.0 // Default to 1mL (will be shown as volume)
        tempFrequencyDays = 3.5 // Default to twice weekly
        
        isPresentingBlendPicker = false
        isAddingItem = true
    }
    
    private func addCompoundItem() {
        guard let compound = tempCompound else { return }
        
        let newItem = CompoundStageItem(
            compoundID: compound.id,
            compoundName: compound.fullDisplayName,
            doseMg: tempDoseMg,
            frequencyDays: tempFrequencyDays,
            administrationRoute: tempRoute.rawValue
        )
        
        compounds.append(newItem)
    }
    
    private func addBlendItem() {
        guard let blend = tempBlend else { return }
        
        let newItem = BlendStageItem(
            blendID: blend.id,
            blendName: blend.name,
            doseMg: tempDoseMg,
            frequencyDays: tempFrequencyDays,
            administrationRoute: tempRoute.rawValue
        )
        
        blends.append(newItem)
    }
}

struct CompoundItemRow: View {
    let item: CompoundStageItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.compoundName)
                .font(.headline)
            
            HStack {
                Text("\(Int(item.doseMg))mg")
                Spacer()
                Text("Every \(formatFrequency(item.frequencyDays))")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            Text("Route: \(item.administrationRoute)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatFrequency(_ days: Double) -> String {
        if days == 1 {
            return "day"
        } else if days == 7 {
            return "week"
        } else if days == 3.5 {
            return "3.5 days"
        } else {
            return "\(days) days"
        }
    }
}

struct BlendItemRow: View {
    let item: BlendStageItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.blendName)
                .font(.headline)
            
            HStack {
                Text("\(Int(item.doseMg))mg")
                Spacer()
                Text("Every \(formatFrequency(item.frequencyDays))")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            Text("Route: \(item.administrationRoute)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatFrequency(_ days: Double) -> String {
        if days == 1 {
            return "day"
        } else if days == 7 {
            return "week"
        } else if days == 3.5 {
            return "3.5 days"
        } else {
            return "\(days) days"
        }
    }
}

struct ItemConfigurationView: View {
    let title: String
    @Binding var doseMg: Double
    @Binding var frequencyDays: Double
    @Binding var route: Compound.Route
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dosage")) {
                    Stepper(value: $doseMg, in: 10...500, step: 10) {
                        Text("Dose: \(Int(doseMg))mg")
                    }
                }
                
                Section(header: Text("Frequency")) {
                    Picker("Frequency", selection: $frequencyDays) {
                        Text("Daily").tag(1.0)
                        Text("Every other day").tag(2.0)
                        Text("Twice weekly").tag(3.5)
                        Text("Weekly").tag(7.0)
                        Text("Every 2 weeks").tag(14.0)
                    }
                    .pickerStyle(InlinePickerStyle())
                }
                
                Section(header: Text("Route")) {
                    Picker("Administration Route", selection: $route) {
                        Text("Intramuscular").tag(Compound.Route.intramuscular)
                        Text("Subcutaneous").tag(Compound.Route.subcutaneous)
                        Text("Oral").tag(Compound.Route.oral)
                        Text("Transdermal").tag(Compound.Route.transdermal)
                    }
                    .pickerStyle(InlinePickerStyle())
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }
            }
        }
    }
}

// Compound Picker View (simplified version)
struct CompoundPickerView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Binding var selectedCompound: Compound?
    let onCompoundSelected: (Compound) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataStore.compoundLibrary.compounds) { compound in
                    Button(action: {
                        selectedCompound = compound
                        onCompoundSelected(compound)
                    }) {
                        HStack {
                            Text(compound.fullDisplayName)
                            Spacer()
                            if selectedCompound?.id == compound.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Compound")
        }
    }
}

// Blend Picker View (simplified version)
struct BlendPickerView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Binding var selectedBlend: VialBlend?
    let onBlendSelected: (VialBlend) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataStore.compoundLibrary.blends) { blend in
                    Button(action: {
                        selectedBlend = blend
                        onBlendSelected(blend)
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(blend.name)
                                    .font(.headline)
                                Text(blend.compositionDescription(using: dataStore.compoundLibrary))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedBlend?.id == blend.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Blend")
        }
    }
}

extension Compound {
    var fullDisplayName: String {
        let className = classType.rawValue.capitalized
        
        if let ester = ester {
            return "\(className) \(ester.capitalized)"
        } else {
            return className
        }
    }
} 