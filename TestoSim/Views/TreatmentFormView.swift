import SwiftUI

/// Form view for creating and editing treatments
struct TreatmentFormView: View {
    // MARK: - Environment & Dependencies
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var viewModel: TreatmentViewModel
    let compoundLibrary: CompoundLibrary
    
    // MARK: - State Properties
    @State private var treatmentName: String = ""
    @State private var treatmentType: Treatment.TreatmentType = .simple
    @State private var startDate: Date = Date()
    @State private var notes: String = ""
    
    // Simple treatment properties
    @State private var doseMg: Double = 100.0
    @State private var frequencyDays: Double = 7.0
    @State private var selectedCompoundID: UUID?
    @State private var selectedBlendID: UUID?
    @State private var selectedContentType: ContentType = .compound
    @State private var selectedRouteRawValue: String = Compound.Route.intramuscular.rawValue
    
    // Advanced treatment properties
    @State private var totalWeeks: Int = 12
    @State private var stages: [TreatmentStage] = []
    @State private var isAddingStage: Bool = false
    @State private var stageToEdit: TreatmentStage?
    
    // Validation
    @State private var errorMessage: String?
    @State private var showingValidationError = false
    
    // UI States
    @State private var showingCompoundPicker = false
    @State private var showingBlendPicker = false
    
    // MARK: - Content Types
    enum ContentType: String, CaseIterable {
        case compound = "Compound"
        case blend = "Blend"
    }
    
    // MARK: - Initialization
    
    /// Initialize for creating a new treatment
    init(viewModel: TreatmentViewModel, compoundLibrary: CompoundLibrary) {
        self.viewModel = viewModel
        self.compoundLibrary = compoundLibrary
        
        // Select the first compound by default
        if let firstCompound = compoundLibrary.compounds.first {
            _selectedCompoundID = State(initialValue: firstCompound.id)
        }
    }
    
    /// Initialize for editing an existing treatment
    init(viewModel: TreatmentViewModel, compoundLibrary: CompoundLibrary, treatment: Treatment) {
        self.viewModel = viewModel
        self.compoundLibrary = compoundLibrary
        
        // Set up basic properties
        _treatmentName = State(initialValue: treatment.name)
        _treatmentType = State(initialValue: treatment.treatmentType)
        _startDate = State(initialValue: treatment.startDate)
        _notes = State(initialValue: treatment.notes ?? "")
        
        // Set up type-specific properties
        switch treatment.treatmentType {
        case .simple:
            _doseMg = State(initialValue: treatment.doseMg ?? 100.0)
            _frequencyDays = State(initialValue: treatment.frequencyDays ?? 7.0)
            _selectedCompoundID = State(initialValue: treatment.compoundID)
            _selectedBlendID = State(initialValue: treatment.blendID)
            
            // Determine content type
            if treatment.compoundID != nil {
                _selectedContentType = State(initialValue: .compound)
            } else if treatment.blendID != nil {
                _selectedContentType = State(initialValue: .blend)
            }
            
            // Set route
            _selectedRouteRawValue = State(initialValue: treatment.selectedRoute ?? Compound.Route.intramuscular.rawValue)
            
        case .advanced:
            _totalWeeks = State(initialValue: treatment.totalWeeks ?? 12)
            _stages = State(initialValue: treatment.stages ?? [])
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Basic information section
                Section(header: Text("Basic Information")) {
                    TextField("Treatment Name", text: $treatmentName)
                    
                    Picker("Treatment Type", selection: $treatmentType) {
                        Text("Simple").tag(Treatment.TreatmentType.simple)
                        Text("Advanced").tag(Treatment.TreatmentType.advanced)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    
                    TextField("Notes", text: $notes)
                        .frame(height: 80)
                        .multilineTextAlignment(.leading)
                }
                
                // Type-specific sections
                if treatmentType == .simple {
                    simpleTypeSection
                } else {
                    advancedTypeSection
                }
                
                // Error message section (if any)
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationBarTitle(viewModel.treatmentToEdit == nil ? "New Treatment" : "Edit Treatment", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveForm()
                }
            )
            .alert(isPresented: $showingValidationError) {
                Alert(
                    title: Text("Validation Error"),
                    message: Text(errorMessage ?? "Please check your inputs"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $isAddingStage) {
                TreatmentStageFormView(
                    compoundLibrary: compoundLibrary,
                    stage: stageToEdit,
                    onSave: { stage in
                        if let index = stages.firstIndex(where: { $0.id == stage.id }) {
                            stages[index] = stage
                        } else {
                            stages.append(stage)
                        }
                        isAddingStage = false
                        stageToEdit = nil
                    },
                    onCancel: {
                        isAddingStage = false
                        stageToEdit = nil
                    }
                )
            }
        }
    }
    
    // MARK: - Sections
    
    /// Section for simple treatment type
    private var simpleTypeSection: some View {
        Group {
            Section(header: Text("Content Type")) {
                Picker("Content Type", selection: $selectedContentType) {
                    ForEach(ContentType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section(header: Text("Treatment Details")) {
                if selectedContentType == .compound {
                    compoundSelectionView
                } else {
                    blendSelectionView
                }
                
                HStack {
                    Text("Dose (mg)")
                    Spacer()
                    TextField("Dose", value: $doseMg, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Frequency (days)")
                    Spacer()
                    TextField("Frequency", value: $frequencyDays, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                Picker("Administration Route", selection: $selectedRouteRawValue) {
                    ForEach(Compound.Route.allCases, id: \.self) { route in
                        Text(route.displayName).tag(route.rawValue)
                    }
                }
            }
        }
    }
    
    /// Compound selection view
    private var compoundSelectionView: some View {
        HStack {
            Text("Compound")
            Spacer()
            if let selectedCompoundID = selectedCompoundID, 
               let compound = compoundLibrary.compound(withID: selectedCompoundID) {
                Button(compound.fullDisplayName) {
                    showingCompoundPicker = true
                }
                .foregroundColor(.blue)
                .sheet(isPresented: $showingCompoundPicker) {
                    compoundPickerSheet
                }
            } else {
                Button("Select Compound") {
                    showingCompoundPicker = true
                }
                .foregroundColor(.blue)
                .sheet(isPresented: $showingCompoundPicker) {
                    compoundPickerSheet
                }
            }
        }
    }
    
    /// Compound picker sheet
    private var compoundPickerSheet: some View {
        NavigationView {
            List {
                ForEach(compoundLibrary.compounds) { compound in
                    Button(action: {
                        selectedCompoundID = compound.id
                        showingCompoundPicker = false
                    }) {
                        HStack {
                            Text(compound.fullDisplayName)
                            Spacer()
                            if selectedCompoundID == compound.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationBarTitle("Select Compound", displayMode: .inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    showingCompoundPicker = false
                }
            )
        }
    }
    
    /// Blend selection view
    private var blendSelectionView: some View {
        HStack {
            Text("Vial Blend")
            Spacer()
            if let selectedBlendID = selectedBlendID, 
               let blend = compoundLibrary.blend(withID: selectedBlendID) {
                Button(blend.name) {
                    showingBlendPicker = true
                }
                .foregroundColor(.blue)
                .sheet(isPresented: $showingBlendPicker) {
                    blendPickerSheet
                }
            } else {
                Button("Select Blend") {
                    showingBlendPicker = true
                }
                .foregroundColor(.blue)
                .sheet(isPresented: $showingBlendPicker) {
                    blendPickerSheet
                }
            }
        }
    }
    
    /// Blend picker sheet
    private var blendPickerSheet: some View {
        NavigationView {
            List {
                ForEach(compoundLibrary.blends) { blend in
                    Button(action: {
                        selectedBlendID = blend.id
                        showingBlendPicker = false
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(blend.name)
                                    .font(.headline)
                                Text(blend.compositionDescription(using: compoundLibrary))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedBlendID == blend.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationBarTitle("Select Blend", displayMode: .inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    showingBlendPicker = false
                }
            )
        }
    }
    
    /// Section for advanced treatment type
    private var advancedTypeSection: some View {
        Group {
            Section(header: Text("Advanced Treatment Details")) {
                Stepper(value: $totalWeeks, in: 1...52) {
                    Text("Total Weeks: \(totalWeeks)")
                }
            }
            
            Section(header: Text("Treatment Stages")) {
                if stages.isEmpty {
                    Text("No stages added yet")
                        .italic()
                        .foregroundColor(.secondary)
                } else {
                    ForEach(stages.sorted(by: { $0.startWeek < $1.startWeek })) { stage in
                        Button(action: {
                            stageToEdit = stage
                            isAddingStage = true
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(stage.name)
                                        .font(.headline)
                                    
                                    Text("Week \(stage.startWeek+1) to \(stage.startWeek + stage.durationWeeks)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if !stage.compounds.isEmpty || !stage.blends.isEmpty {
                                        Text("\(stage.compounds.count) compounds, \(stage.blends.count) blends")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    .onDelete { indexSet in
                        stages.remove(atOffsets: indexSet)
                    }
                }
                
                Button(action: {
                    stageToEdit = nil
                    isAddingStage = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Stage")
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    /// Validate form and save the treatment
    private func saveForm() {
        // Validate form
        guard validateForm() else {
            showingValidationError = true
            return
        }
        
        // Create or update treatment
        let treatment: Treatment
        if let editingTreatment = viewModel.treatmentToEdit {
            // Update existing treatment
            treatment = updateTreatment(editingTreatment)
        } else {
            // Create new treatment
            treatment = createNewTreatment()
        }
        
        // Save to view model
        if viewModel.treatmentToEdit != nil {
            viewModel.updateTreatment(treatment)
        } else {
            viewModel.addTreatment(treatment)
        }
        
        // Dismiss form
        presentationMode.wrappedValue.dismiss()
    }
    
    /// Create a new treatment from form data
    private func createNewTreatment() -> Treatment {
        // Create a treatment with common properties
        var treatment = Treatment(
            name: treatmentName,
            startDate: startDate,
            notes: notes.isEmpty ? nil : notes,
            treatmentType: treatmentType
        )
        
        // Set type-specific properties
        if treatmentType == .simple {
            treatment.doseMg = doseMg
            treatment.frequencyDays = frequencyDays
            treatment.selectedRoute = selectedRouteRawValue
            
            if selectedContentType == .compound {
                treatment.compoundID = selectedCompoundID
            } else {
                treatment.blendID = selectedBlendID
            }
            
            treatment.bloodSamples = []
            
        } else { // Advanced type
            treatment.totalWeeks = totalWeeks
            treatment.stages = stages
        }
        
        return treatment
    }
    
    /// Update an existing treatment with form data
    private func updateTreatment(_ existing: Treatment) -> Treatment {
        // Start with a copy of the existing treatment
        var treatment = existing
        
        // Update common properties
        treatment.name = treatmentName
        treatment.startDate = startDate
        treatment.notes = notes.isEmpty ? nil : notes
        
        // Handle type change if needed
        if treatment.treatmentType != treatmentType {
            treatment.treatmentType = treatmentType
            
            if treatmentType == .simple {
                // Convert to simple type
                treatment.doseMg = doseMg
                treatment.frequencyDays = frequencyDays
                treatment.selectedRoute = selectedRouteRawValue
                
                if selectedContentType == .compound {
                    treatment.compoundID = selectedCompoundID
                    treatment.blendID = nil
                } else {
                    treatment.blendID = selectedBlendID
                    treatment.compoundID = nil
                }
                
                // Keep existing blood samples if any
                if treatment.bloodSamples == nil {
                    treatment.bloodSamples = []
                }
                
                // Clear advanced properties
                treatment.totalWeeks = nil
                treatment.stages = nil
                
            } else { // Convert to advanced type
                // Set advanced properties
                treatment.totalWeeks = totalWeeks
                treatment.stages = stages
                
                // Clear simple properties
                treatment.doseMg = nil
                treatment.frequencyDays = nil
                treatment.compoundID = nil
                treatment.blendID = nil
                treatment.selectedRoute = nil
                treatment.bloodSamples = nil
            }
        } else {
            // Just update type-specific properties
            if treatmentType == .simple {
                treatment.doseMg = doseMg
                treatment.frequencyDays = frequencyDays
                treatment.selectedRoute = selectedRouteRawValue
                
                if selectedContentType == .compound {
                    treatment.compoundID = selectedCompoundID
                    treatment.blendID = nil
                } else {
                    treatment.blendID = selectedBlendID
                    treatment.compoundID = nil
                }
                
            } else { // Advanced type
                treatment.totalWeeks = totalWeeks
                treatment.stages = stages
            }
        }
        
        return treatment
    }
    
    /// Validate the form data
    private func validateForm() -> Bool {
        // Validate common fields
        guard !treatmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Treatment name is required"
            return false
        }
        
        // Validate type-specific fields
        if treatmentType == .simple {
            guard doseMg > 0 else {
                errorMessage = "Dose must be greater than 0"
                return false
            }
            
            guard frequencyDays > 0 else {
                errorMessage = "Frequency must be greater than 0"
                return false
            }
            
            if selectedContentType == .compound {
                guard selectedCompoundID != nil else {
                    errorMessage = "Please select a compound"
                    return false
                }
            } else {
                guard selectedBlendID != nil else {
                    errorMessage = "Please select a blend"
                    return false
                }
            }
            
        } else { // Advanced type
            guard totalWeeks > 0 else {
                errorMessage = "Total weeks must be greater than 0"
                return false
            }
            
            guard !stages.isEmpty else {
                errorMessage = "Please add at least one stage"
                return false
            }
            
            // Validate stages cover the total duration and don't overlap
            let stagesSorted = stages.sorted(by: { $0.startWeek < $1.startWeek })
            
            // Check for overlaps
            for i in 0..<stagesSorted.count-1 {
                let currentStage = stagesSorted[i]
                let nextStage = stagesSorted[i+1]
                
                let currentEndWeek = currentStage.startWeek + currentStage.durationWeeks
                if currentEndWeek > nextStage.startWeek {
                    errorMessage = "Stages overlap: \(currentStage.name) and \(nextStage.name)"
                    return false
                }
            }
            
            // Check coverage
            if let lastStage = stagesSorted.last {
                let lastWeek = lastStage.startWeek + lastStage.durationWeeks
                if lastWeek < totalWeeks {
                    errorMessage = "Stages don't cover the full treatment duration (missing weeks \(lastWeek+1) to \(totalWeeks))"
                    return false
                }
                
                if lastWeek > totalWeeks {
                    errorMessage = "Stages exceed the total treatment duration by \(lastWeek - totalWeeks) weeks"
                    return false
                }
            }
        }
        
        // All validations passed
        errorMessage = nil
        return true
    }
}

/// Form view for creating and editing treatment stages
struct TreatmentStageFormView: View {
    // MARK: - Dependencies
    let compoundLibrary: CompoundLibrary
    
    // MARK: - Callbacks
    let onSave: (TreatmentStage) -> Void
    let onCancel: () -> Void
    
    // MARK: - State
    @State private var name: String = ""
    @State private var startWeek: Int = 0
    @State private var durationWeeks: Int = 4
    @State private var compounds: [CompoundStageItem] = []
    @State private var blends: [BlendStageItem] = []
    @State private var isAddingCompound = false
    @State private var isAddingBlend = false
    @State private var stageID: UUID
    
    // Validation
    @State private var errorMessage: String?
    @State private var showingValidationError = false
    
    // MARK: - Initialization
    init(compoundLibrary: CompoundLibrary, stage: TreatmentStage?, onSave: @escaping (TreatmentStage) -> Void, onCancel: @escaping () -> Void) {
        self.compoundLibrary = compoundLibrary
        self.onSave = onSave
        self.onCancel = onCancel
        
        if let stage = stage {
            _name = State(initialValue: stage.name)
            _startWeek = State(initialValue: stage.startWeek)
            _durationWeeks = State(initialValue: stage.durationWeeks)
            _compounds = State(initialValue: stage.compounds)
            _blends = State(initialValue: stage.blends)
            _stageID = State(initialValue: stage.id)
        } else {
            _stageID = State(initialValue: UUID())
        }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Stage Information")) {
                    TextField("Stage Name", text: $name)
                    
                    Stepper(value: $startWeek, in: 0...51) {
                        Text("Start Week: \(startWeek + 1)")
                    }
                    
                    Stepper(value: $durationWeeks, in: 1...52) {
                        Text("Duration: \(durationWeeks) weeks")
                    }
                }
                
                Section(header: Text("Compounds")) {
                    if compounds.isEmpty {
                        Text("No compounds added")
                            .italic()
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(compounds) { item in
                            CompoundStageItemRow(
                                item: item,
                                compoundLibrary: compoundLibrary,
                                onEdit: { editedItem in
                                    if let index = compounds.firstIndex(where: { $0.id == editedItem.id }) {
                                        compounds[index] = editedItem
                                    }
                                }
                            )
                        }
                        .onDelete { indexSet in
                            compounds.remove(atOffsets: indexSet)
                        }
                    }
                    
                    Button(action: {
                        isAddingCompound = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Compound")
                        }
                    }
                    .sheet(isPresented: $isAddingCompound) {
                        StageCompoundFormView(
                            compoundLibrary: compoundLibrary,
                            onSave: { newItem in
                                compounds.append(newItem)
                                isAddingCompound = false
                            },
                            onCancel: {
                                isAddingCompound = false
                            }
                        )
                    }
                }
                
                Section(header: Text("Blends")) {
                    if blends.isEmpty {
                        Text("No blends added")
                            .italic()
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(blends) { item in
                            BlendStageItemRow(
                                item: item,
                                compoundLibrary: compoundLibrary,
                                onEdit: { editedItem in
                                    if let index = blends.firstIndex(where: { $0.id == editedItem.id }) {
                                        blends[index] = editedItem
                                    }
                                }
                            )
                        }
                        .onDelete { indexSet in
                            blends.remove(atOffsets: indexSet)
                        }
                    }
                    
                    Button(action: {
                        isAddingBlend = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Blend")
                        }
                    }
                    .sheet(isPresented: $isAddingBlend) {
                        StageBlendFormView(
                            compoundLibrary: compoundLibrary,
                            onSave: { newItem in
                                blends.append(newItem)
                                isAddingBlend = false
                            },
                            onCancel: {
                                isAddingBlend = false
                            }
                        )
                    }
                }
                
                // Error message section (if any)
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationBarTitle("Treatment Stage", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                },
                trailing: Button("Save") {
                    saveStage()
                }
            )
            .alert(isPresented: $showingValidationError) {
                Alert(
                    title: Text("Validation Error"),
                    message: Text(errorMessage ?? "Please check your inputs"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // MARK: - Actions
    
    /// Save stage after validation
    private func saveStage() {
        // Validate
        guard validateStage() else {
            showingValidationError = true
            return
        }
        
        // Create stage
        let stage = TreatmentStage(
            id: stageID,
            name: name,
            startWeek: startWeek,
            durationWeeks: durationWeeks,
            compounds: compounds,
            blends: blends
        )
        
        // Save
        onSave(stage)
    }
    
    /// Validate stage data
    private func validateStage() -> Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Stage name is required"
            return false
        }
        
        guard compounds.count > 0 || blends.count > 0 else {
            errorMessage = "Add at least one compound or blend"
            return false
        }
        
        // All validations passed
        errorMessage = nil
        return true
    }
}

// MARK: - Helper Views

/// Row view for compound stage item
struct CompoundStageItemRow: View {
    let item: CompoundStageItem
    let compoundLibrary: CompoundLibrary
    let onEdit: (CompoundStageItem) -> Void
    
    @State private var isEditing = false
    @State private var editedDose: Double
    @State private var editedFrequency: Double
    @State private var editedRoute: String
    
    init(item: CompoundStageItem, compoundLibrary: CompoundLibrary, onEdit: @escaping (CompoundStageItem) -> Void) {
        self.item = item
        self.compoundLibrary = compoundLibrary
        self.onEdit = onEdit
        
        _editedDose = State(initialValue: item.doseMg)
        _editedFrequency = State(initialValue: item.frequencyDays)
        _editedRoute = State(initialValue: item.administrationRoute)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(item.compoundName)
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    isEditing.toggle()
                }) {
                    Text("Edit")
                        .font(.caption)
                }
            }
            
            if let compound = compoundLibrary.compound(withID: item.compoundID) {
                Text(compound.fullDisplayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(Int(item.doseMg))mg every \(formatFrequency(item.frequencyDays)) via \(formatRoute(item.administrationRoute))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $isEditing) {
            NavigationView {
                Form {
                    Section(header: Text("Dosing Details")) {
                        HStack {
                            Text("Dose (mg)")
                            Spacer()
                            TextField("Dose", value: $editedDose, formatter: NumberFormatter())
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Frequency (days)")
                            Spacer()
                            TextField("Frequency", value: $editedFrequency, formatter: NumberFormatter())
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        Picker("Administration Route", selection: $editedRoute) {
                            ForEach(Compound.Route.allCases, id: \.self) { route in
                                Text(route.displayName).tag(route.rawValue)
                            }
                        }
                    }
                }
                .navigationBarTitle("Edit Compound", displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") {
                        isEditing = false
                    },
                    trailing: Button("Save") {
                        var updatedItem = item
                        updatedItem.doseMg = editedDose
                        updatedItem.frequencyDays = editedFrequency
                        updatedItem.administrationRoute = editedRoute
                        onEdit(updatedItem)
                        isEditing = false
                    }
                )
            }
        }
    }
    
    private func formatFrequency(_ days: Double) -> String {
        if days == 1 {
            return "day"
        } else if days == 7 {
            return "week"
        } else if days == 14 {
            return "2 weeks"
        } else if days == 30 {
            return "month"
        } else {
            return "\(days) days"
        }
    }
    
    private func formatRoute(_ routeString: String) -> String {
        if let route = Compound.Route(rawValue: routeString) {
            return route.displayName
        }
        return routeString
    }
}

/// Row view for blend stage item
struct BlendStageItemRow: View {
    let item: BlendStageItem
    let compoundLibrary: CompoundLibrary
    let onEdit: (BlendStageItem) -> Void
    
    @State private var isEditing = false
    @State private var editedDose: Double
    @State private var editedFrequency: Double
    @State private var editedRoute: String
    
    init(item: BlendStageItem, compoundLibrary: CompoundLibrary, onEdit: @escaping (BlendStageItem) -> Void) {
        self.item = item
        self.compoundLibrary = compoundLibrary
        self.onEdit = onEdit
        
        _editedDose = State(initialValue: item.doseMg)
        _editedFrequency = State(initialValue: item.frequencyDays)
        _editedRoute = State(initialValue: item.administrationRoute)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(item.blendName)
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    isEditing.toggle()
                }) {
                    Text("Edit")
                        .font(.caption)
                }
            }
            
            if let blend = compoundLibrary.blend(withID: item.blendID) {
                Text(blend.compositionDescription(using: compoundLibrary))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(Int(item.doseMg))mg every \(formatFrequency(item.frequencyDays)) via \(formatRoute(item.administrationRoute))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $isEditing) {
            NavigationView {
                Form {
                    Section(header: Text("Dosing Details")) {
                        HStack {
                            Text("Dose (mg)")
                            Spacer()
                            TextField("Dose", value: $editedDose, formatter: NumberFormatter())
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Frequency (days)")
                            Spacer()
                            TextField("Frequency", value: $editedFrequency, formatter: NumberFormatter())
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        Picker("Administration Route", selection: $editedRoute) {
                            ForEach(Compound.Route.allCases, id: \.self) { route in
                                Text(route.displayName).tag(route.rawValue)
                            }
                        }
                    }
                }
                .navigationBarTitle("Edit Blend", displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") {
                        isEditing = false
                    },
                    trailing: Button("Save") {
                        var updatedItem = item
                        updatedItem.doseMg = editedDose
                        updatedItem.frequencyDays = editedFrequency
                        updatedItem.administrationRoute = editedRoute
                        onEdit(updatedItem)
                        isEditing = false
                    }
                )
            }
        }
    }
    
    private func formatFrequency(_ days: Double) -> String {
        if days == 1 {
            return "day"
        } else if days == 7 {
            return "week"
        } else if days == 14 {
            return "2 weeks"
        } else if days == 30 {
            return "month"
        } else {
            return "\(days) days"
        }
    }
    
    private func formatRoute(_ routeString: String) -> String {
        if let route = Compound.Route(rawValue: routeString) {
            return route.displayName
        }
        return routeString
    }
}

// MARK: - Component Form Views

/// Form for adding a compound to a stage
struct StageCompoundFormView: View {
    let compoundLibrary: CompoundLibrary
    let onSave: (CompoundStageItem) -> Void
    let onCancel: () -> Void
    
    @State private var selectedCompoundID: UUID?
    @State private var compoundName: String = ""
    @State private var doseMg: Double = 100.0
    @State private var frequencyDays: Double = 7.0
    @State private var selectedRouteRawValue: String = Compound.Route.intramuscular.rawValue
    @State private var showingCompoundPicker = false
    
    @State private var errorMessage: String?
    @State private var showingValidationError = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Compound")) {
                    HStack {
                        Text("Compound")
                        Spacer()
                        if let selectedCompoundID = selectedCompoundID, 
                           let compound = compoundLibrary.compound(withID: selectedCompoundID) {
                            Button(compound.fullDisplayName) {
                                showingCompoundPicker = true
                            }
                            .foregroundColor(.blue)
                        } else {
                            Button("Select Compound") {
                                showingCompoundPicker = true
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .sheet(isPresented: $showingCompoundPicker) {
                        NavigationView {
                            List {
                                ForEach(compoundLibrary.compounds) { compound in
                                    Button(action: {
                                        selectedCompoundID = compound.id
                                        compoundName = compound.fullDisplayName
                                        showingCompoundPicker = false
                                    }) {
                                        HStack {
                                            Text(compound.fullDisplayName)
                                            Spacer()
                                            if selectedCompoundID == compound.id {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    .foregroundColor(.primary)
                                }
                            }
                            .navigationBarTitle("Select Compound", displayMode: .inline)
                            .navigationBarItems(
                                trailing: Button("Cancel") {
                                    showingCompoundPicker = false
                                }
                            )
                        }
                    }
                }
                
                Section(header: Text("Dosing")) {
                    HStack {
                        Text("Dose (mg)")
                        Spacer()
                        TextField("Dose", value: $doseMg, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Frequency (days)")
                        Spacer()
                        TextField("Frequency", value: $frequencyDays, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Administration Route", selection: $selectedRouteRawValue) {
                        ForEach(Compound.Route.allCases, id: \.self) { route in
                            Text(route.displayName).tag(route.rawValue)
                        }
                    }
                }
                
                // Error message section (if any)
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationBarTitle("Add Compound", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                },
                trailing: Button("Add") {
                    saveCompound()
                }
            )
            .alert(isPresented: $showingValidationError) {
                Alert(
                    title: Text("Validation Error"),
                    message: Text(errorMessage ?? "Please check your inputs"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func saveCompound() {
        // Validate inputs
        guard let compoundID = selectedCompoundID else {
            errorMessage = "Please select a compound"
            showingValidationError = true
            return
        }
        
        guard doseMg > 0 else {
            errorMessage = "Dose must be greater than 0"
            showingValidationError = true
            return
        }
        
        guard frequencyDays > 0 else {
            errorMessage = "Frequency must be greater than 0"
            showingValidationError = true
            return
        }
        
        // Create compound stage item
        let compoundItem = CompoundStageItem(
            compoundID: compoundID,
            compoundName: compoundName,
            doseMg: doseMg,
            frequencyDays: frequencyDays,
            administrationRoute: selectedRouteRawValue
        )
        
        // Save
        onSave(compoundItem)
    }
}

/// Form for adding a blend to a stage
struct StageBlendFormView: View {
    let compoundLibrary: CompoundLibrary
    let onSave: (BlendStageItem) -> Void
    let onCancel: () -> Void
    
    @State private var selectedBlendID: UUID?
    @State private var blendName: String = ""
    @State private var doseMg: Double = 100.0
    @State private var frequencyDays: Double = 7.0
    @State private var selectedRouteRawValue: String = Compound.Route.intramuscular.rawValue
    @State private var showingBlendPicker = false
    
    @State private var errorMessage: String?
    @State private var showingValidationError = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Blend")) {
                    HStack {
                        Text("Vial Blend")
                        Spacer()
                        if let selectedBlendID = selectedBlendID, 
                           let blend = compoundLibrary.blend(withID: selectedBlendID) {
                            Button(blend.name) {
                                showingBlendPicker = true
                            }
                            .foregroundColor(.blue)
                        } else {
                            Button("Select Blend") {
                                showingBlendPicker = true
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .sheet(isPresented: $showingBlendPicker) {
                        NavigationView {
                            List {
                                ForEach(compoundLibrary.blends) { blend in
                                    Button(action: {
                                        selectedBlendID = blend.id
                                        blendName = blend.name
                                        showingBlendPicker = false
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(blend.name)
                                                    .font(.headline)
                                                Text(blend.compositionDescription(using: compoundLibrary))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            if selectedBlendID == blend.id {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    .foregroundColor(.primary)
                                }
                            }
                            .navigationBarTitle("Select Blend", displayMode: .inline)
                            .navigationBarItems(
                                trailing: Button("Cancel") {
                                    showingBlendPicker = false
                                }
                            )
                        }
                    }
                }
                
                Section(header: Text("Dosing")) {
                    HStack {
                        Text("Dose (mg)")
                        Spacer()
                        TextField("Dose", value: $doseMg, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Frequency (days)")
                        Spacer()
                        TextField("Frequency", value: $frequencyDays, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Administration Route", selection: $selectedRouteRawValue) {
                        ForEach(Compound.Route.allCases, id: \.self) { route in
                            Text(route.displayName).tag(route.rawValue)
                        }
                    }
                }
                
                // Error message section (if any)
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationBarTitle("Add Blend", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                },
                trailing: Button("Add") {
                    saveBlend()
                }
            )
            .alert(isPresented: $showingValidationError) {
                Alert(
                    title: Text("Validation Error"),
                    message: Text(errorMessage ?? "Please check your inputs"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func saveBlend() {
        // Validate inputs
        guard let blendID = selectedBlendID else {
            errorMessage = "Please select a blend"
            showingValidationError = true
            return
        }
        
        guard doseMg > 0 else {
            errorMessage = "Dose must be greater than 0"
            showingValidationError = true
            return
        }
        
        guard frequencyDays > 0 else {
            errorMessage = "Frequency must be greater than 0"
            showingValidationError = true
            return
        }
        
        // Create blend stage item
        let blendItem = BlendStageItem(
            blendID: blendID,
            blendName: blendName,
            doseMg: doseMg,
            frequencyDays: frequencyDays,
            administrationRoute: selectedRouteRawValue
        )
        
        // Save
        onSave(blendItem)
    }
}