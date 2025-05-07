import SwiftUI

struct TreatmentFormView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Binding var isPresented: Bool
    
    var treatmentToEdit: Treatment?
    
    @State private var name: String = ""
    @State private var startDate: Date = Date()
    @State private var notes: String = ""
    @State private var treatmentType: Treatment.TreatmentType = .advanced
    @State private var totalWeeks: Int = 12 // Default for advanced treatments
    
    @State private var isPresentingStageForm = false
    @State private var stageToEdit: TreatmentStage?
    
    var body: some View {
        NavigationView {
            Form {
                basicDetailsSection
                
                if treatmentType == .advanced {
                    durationSection
                    stagesSection
                }
            }
            .navigationTitle(treatmentToEdit == nil ? "New Treatment" : "Edit Treatment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTreatment()
                        isPresented = false
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                initializeForm()
            }
            .sheet(isPresented: $isPresentingStageForm) {
                if let treatment = createTreatment() {
                    TreatmentStageFormView(
                        isPresented: $isPresentingStageForm,
                        treatment: treatment,
                        stageToEdit: stageToEdit
                    )
                    .environmentObject(dataStore)
                }
            }
        }
    }
    
    private var basicDetailsSection: some View {
        Section(header: Text("Treatment Details")) {
            TextField("Name", text: $name)
            
            Picker("Type", selection: $treatmentType) {
                Text("Advanced (Multi-Stage)").tag(Treatment.TreatmentType.advanced)
                Text("Simple").tag(Treatment.TreatmentType.simple)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
            
            TextEditor(text: $notes)
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if notes.isEmpty {
                            Text("Notes (optional)")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                )
        }
    }
    
    private var durationSection: some View {
        Section(header: Text("Treatment Duration")) {
            Stepper("Total Weeks: \(totalWeeks)", value: $totalWeeks, in: 4...52)
        }
    }
    
    private var stagesSection: some View {
        Section(header: stagesHeader) {
            if let treatment = createTreatment(), let stages = treatment.stages, !stages.isEmpty {
                ForEach(stages) { stage in
                    StageRow(stage: stage)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            stageToEdit = stage
                            isPresentingStageForm = true
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteStage(stage)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } else {
                Text("No stages added yet")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
    
    private var stagesHeader: some View {
        HStack {
            Text("Stages")
            Spacer()
            Button(action: {
                stageToEdit = nil
                isPresentingStageForm = true
            }) {
                Image(systemName: "plus")
            }
        }
    }
    
    private func initializeForm() {
        if let treatment = treatmentToEdit {
            name = treatment.name
            startDate = treatment.startDate
            notes = treatment.notes ?? ""
            treatmentType = treatment.treatmentType
            totalWeeks = treatment.totalWeeks ?? 12
        }
    }
    
    private func saveTreatment() {
        var treatment = createTreatment()
        
        // Save to AppDataStore
        if treatmentToEdit != nil {
            dataStore.updateTreatment(treatment)
        } else {
            dataStore.addTreatment(treatment)
        }
    }
    
    private func createTreatment() -> Treatment {
        var treatment: Treatment
        
        if let existingTreatment = treatmentToEdit {
            // Update existing treatment
            treatment = existingTreatment
            treatment.name = name
            treatment.startDate = startDate
            treatment.notes = notes
            treatment.treatmentType = treatmentType
            
            if treatmentType == .advanced {
                treatment.totalWeeks = totalWeeks
            }
        } else {
            // Create new treatment
            treatment = Treatment(
                name: name,
                startDate: startDate,
                notes: notes.isEmpty ? nil : notes,
                treatmentType: treatmentType
            )
            
            if treatmentType == .advanced {
                treatment.totalWeeks = totalWeeks
                treatment.stages = []
            }
        }
        
        return treatment
    }
    
    private func deleteStage(_ stage: TreatmentStage) {
        guard var treatment = createTreatment(), var stages = treatment.stages else { return }
        
        if let index = stages.firstIndex(where: { $0.id == stage.id }) {
            stages.remove(at: index)
            treatment.stages = stages
            
            // Update the treatment in AppDataStore
            dataStore.updateTreatment(treatment)
        }
    }
}

struct StageRow: View {
    let stage: TreatmentStage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stage.name)
                .font(.headline)
            
            Text("Week \(stage.startWeek + 1) to \(stage.startWeek + stage.durationWeeks)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("\(stage.compounds.count) compounds, \(stage.blends.count) blends")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}