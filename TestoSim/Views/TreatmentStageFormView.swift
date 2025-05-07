import SwiftUI

struct TreatmentStageFormView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Binding var isPresented: Bool
    
    var treatment: Treatment
    var stageToEdit: TreatmentStage?
    
    @State private var stageName: String = ""
    @State private var startWeek: Int = 0
    @State private var durationWeeks: Int = 4
    @State private var isPresentingCompoundPicker = false
    @State private var isPresentingBlendPicker = false
    
    // Stage items
    @State private var compounds: [Treatment.StageCompound] = []
    @State private var blends: [Treatment.StageBlend] = []
    
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
                            ForEach(Array(0..<(treatment.totalWeeks ?? 0)), id: \.self) { week in
                                Text("Week \(week + 1)").tag(week)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    Stepper("Duration: \(durationWeeks) weeks", value: $durationWeeks, in: 1...max(1, (treatment.totalWeeks ?? 0) - startWeek))
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
            if let stages = treatment.stages, !stages.isEmpty {
                let lastStage = stages.max(by: { $0.startWeek + $0.durationWeeks < $1.startWeek + $1.durationWeeks })
                if let lastStage = lastStage {
                    startWeek = min(lastStage.startWeek + lastStage.durationWeeks, (treatment.totalWeeks ?? 0) - 1)
                }
            }
            
            // Default stage name if creating new
            if let stages = treatment.stages {
                stageName = "Stage \(stages.count + 1)"
            } else {
                stageName = "Stage 1"
            }
        }
    }
    
    private func saveStage() {
        // Create a new stage or update existing
        var updatedStage: TreatmentStage
        
        if let existingStage = stageToEdit {
            // Update existing stage
            updatedStage = existingStage
            updatedStage.name = stageName
            updatedStage.startWeek = startWeek
            updatedStage.durationWeeks = durationWeeks
            updatedStage.compounds = compounds
            updatedStage.blends = blends
            
            // Find and replace in treatment
            var updatedTreatment = treatment
            if var stages = updatedTreatment.stages, let index = stages.firstIndex(where: { $0.id == existingStage.id }) {
                stages[index] = updatedStage
                updatedTreatment.stages = stages
            }
            
            // Save treatment
            dataStore.updateTreatment(updatedTreatment)
        } else {
            // Create new stage
            updatedStage = TreatmentStage(
                name: stageName,
                startWeek: startWeek,
                durationWeeks: durationWeeks,
                compounds: compounds,
                blends: blends
            )
            
            // Add to treatment
            var updatedTreatment = treatment
            if var stages = updatedTreatment.stages {
                stages.append(updatedStage)
                updatedTreatment.stages = stages
            } else {
                updatedTreatment.stages = [updatedStage]
            }
            
            // Save treatment
            dataStore.updateTreatment(updatedTreatment)
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
        
        let newItem = Treatment.StageCompound(
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
        
        let newItem = Treatment.StageBlend(
            blendID: blend.id,
            blendName: blend.name,
            doseMg: tempDoseMg,
            frequencyDays: tempFrequencyDays,
            administrationRoute: tempRoute.rawValue
        )
        
        blends.append(newItem)
    }
}