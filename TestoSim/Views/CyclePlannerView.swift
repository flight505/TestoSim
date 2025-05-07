import SwiftUI
import Charts

struct AdvancedTreatmentView_Impl: View {
    @EnvironmentObject var dataStore: AppDataStore
    @State private var isAddingTreatment = false
    @State private var selectedTreatment: Treatment?
    @State private var isPresentingStageForm = false
    @State private var stageToEdit: TreatmentStage?
    @State private var showingDeleteAlert = false
    @State private var treatmentToDelete: Treatment?
    
    private var advancedTreatments: [Treatment] {
        dataStore.treatments.filter { $0.treatmentType == .advanced }
    }
    
    var body: some View {
        VStack {
            if advancedTreatments.isEmpty {
                emptyTreatmentsView
            } else {
                HStack {
                    Spacer()
                    Button(action: {
                        isAddingTreatment = true
                    }) {
                        Label("New", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
                
                HStack(alignment: .top, spacing: 0) {
                    // Treatment list
                    VStack {
                        Text("Advanced Treatments")
                            .font(.headline)
                            .padding(.top)
                        
                        List(advancedTreatments) { treatment in
                            treatmentRow(for: treatment)
                        }
                        .listStyle(PlainListStyle())
                    }
                    .frame(width: 220)
                    .background(Color(.systemGray6))
                    
                    // Detail view
                    ScrollView {
                        if let selectedTreatment = selectedTreatment {
                            TreatmentDetailPanel_Impl(
                                treatment: selectedTreatment,
                                onAddStage: {
                                    stageToEdit = nil
                                    isPresentingStageForm = true
                                },
                                onEditStage: { stage in
                                    stageToEdit = stage
                                    isPresentingStageForm = true
                                },
                                onDeleteStage: { stageID in
                                    deleteStage(withID: stageID, from: selectedTreatment)
                                },
                                onDelete: {
                                    treatmentToDelete = selectedTreatment
                                    showingDeleteAlert = true
                                }
                            )
                            .environmentObject(dataStore)
                            .padding()
                        } else {
                            Text("Select a treatment to view details")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .padding()
                        }
                    }
                }
            }
        }
        .navigationTitle("Advanced Treatments")
        .sheet(isPresented: $isAddingTreatment) {
            AdvancedTreatmentFormView_Impl(isPresented: $isAddingTreatment)
                .environmentObject(dataStore)
        }
        .sheet(isPresented: $isPresentingStageForm) {
            if let selectedTreatment = selectedTreatment {
                TreatmentStageFormView(
                    isPresented: $isPresentingStageForm,
                    treatment: selectedTreatment,
                    stageToEdit: stageToEdit
                )
                .environmentObject(dataStore)
            }
        }
        .alert("Delete Treatment", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let treatment = treatmentToDelete {
                    dataStore.deleteTreatment(with: treatment.id)
                    if selectedTreatment?.id == treatment.id {
                        selectedTreatment = nil
                    }
                }
            }
        } message: {
            if let treatment = treatmentToDelete {
                Text("Are you sure you want to delete '\(treatment.name)'? This action cannot be undone.")
            } else {
                Text("Are you sure you want to delete this treatment? This action cannot be undone.")
            }
        }
        .onAppear {
            // Select the first treatment by default if nothing is selected
            if selectedTreatment == nil && !advancedTreatments.isEmpty {
                selectedTreatment = advancedTreatments.first
                if let treatment = advancedTreatments.first {
                    dataStore.selectTreatment(id: treatment.id)
                }
            }
        }
    }
    
    private var emptyTreatmentsView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Advanced Treatments Yet")
                .font(.title2)
                .bold()
            
            Text("Create your first advanced treatment to plan and visualize multi-compound regimens.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            Button("Create Advanced Treatment") {
                isAddingTreatment = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
            
            Spacer()
        }
        .padding()
    }
    
    private func treatmentRow(for treatment: Treatment) -> some View {
        let isSelected = selectedTreatment?.id == treatment.id
        
        return HStack {
            VStack(alignment: .leading) {
                Text(treatment.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(formattedDateRange(startDate: treatment.startDate, weeks: treatment.totalWeeks ?? 0))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            dataStore.selectTreatment(id: treatment.id)
            selectedTreatment = treatment
        }
    }
    
    private func formattedDateRange(startDate: Date, weeks: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        
        let startDateString = formatter.string(from: startDate)
        
        let endDate = Calendar.current.date(byAdding: .day, value: weeks * 7, to: startDate) ?? startDate
        let endDateString = formatter.string(from: endDate)
        
        return "\(startDateString) - \(endDateString)"
    }
    
    private func deleteStage(withID stageID: UUID, from treatment: Treatment) {
        var updatedTreatment = treatment
        
        if var stages = updatedTreatment.stages {
            stages.removeAll { $0.id == stageID }
            updatedTreatment.stages = stages
            
            // Save the updated treatment
            dataStore.updateTreatment(updatedTreatment)
            
            // Update the selectedTreatment to reflect the changes
            if let index = advancedTreatments.firstIndex(where: { $0.id == treatment.id }) {
                selectedTreatment = advancedTreatments[index]
            }
        }
    }
}

struct TreatmentDetailPanel_Impl: View {
    @EnvironmentObject var dataStore: AppDataStore
    let treatment: Treatment
    let onAddStage: () -> Void
    let onEditStage: (TreatmentStage) -> Void
    let onDeleteStage: (UUID) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Treatment header
            HStack {
                VStack(alignment: .leading) {
                    Text(treatment.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(treatment.totalWeeks ?? 0) weeks total")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button(action: onAddStage) {
                        Label("Add Stage", systemImage: "plus")
                    }
                    Button(action: onDelete) {
                        Label("Delete Treatment", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                }
            }
            .padding([.horizontal, .top])
            
            // Timeline visualization
            treatmentTimeline
                .padding(.horizontal)
            
            // Stages list
            stagesList
            
            // Visualization
            TreatmentSimulationChart(simulationData: dataStore.treatmentSimulationData)
                .frame(height: 300)
                .padding()
        }
        .background(Color(.systemBackground))
    }
    
    private var treatmentTimeline: some View {
        let totalWeeks = treatment.totalWeeks ?? 0
        
        return VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.headline)
            
            // Week indicator bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 30)
                    
                    HStack(spacing: 0) {
                        ForEach(0..<totalWeeks, id: \.self) { week in
                            Text("\(week+1)")
                                .font(.caption)
                                .frame(width: max(20, geometry.size.width / CGFloat(totalWeeks)), height: 20)
                        }
                    }
                    
                    // Stage indicators
                    if let stages = treatment.stages {
                        ForEach(stages) { stage in
                            let startOffset = CGFloat(stage.startWeek) / CGFloat(totalWeeks) * geometry.size.width
                            let width = CGFloat(stage.durationWeeks) / CGFloat(totalWeeks) * geometry.size.width
                            
                            VStack(spacing: 2) {
                                Rectangle()
                                    .fill(stageColor(for: stage))
                                    .frame(width: max(width, 10), height: 12)
                                
                                Text(stage.name)
                                    .font(.caption)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .lineLimit(1)
                            }
                            .position(x: startOffset + width / 2, y: 40)
                        }
                    }
                }
                .frame(height: 60)
            }
            .frame(height: 60)
            .padding(.vertical)
        }
    }
    
    private var stagesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stages")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    if let stages = treatment.stages, !stages.isEmpty {
                        ForEach(stages.sorted(by: { $0.startWeek < $1.startWeek })) { stage in
                            stageRow(for: stage)
                        }
                    } else {
                        Text("No stages defined")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                    
                    Button(action: onAddStage) {
                        Label("Add Stage", systemImage: "plus")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .frame(height: 250)
        }
    }
    
    private func stageRow(for stage: TreatmentStage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stage.name)
                    .font(.headline)
                
                Spacer()
                
                Text("Week \(stage.startWeek + 1) - \(stage.startWeek + stage.durationWeeks)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                // Compounds count
                if !stage.compounds.isEmpty {
                    HStack {
                        Image(systemName: "cross.vial.fill")
                            .foregroundColor(.blue)
                        Text("\(stage.compounds.count) Compounds")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                }
                
                // Blends count
                if !stage.blends.isEmpty {
                    HStack {
                        Image(systemName: "flask.fill")
                            .foregroundColor(.orange)
                        Text("\(stage.blends.count) Blends")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
                }
                
                Spacer()
                
                // Edit button
                Button(action: {
                    onEditStage(stage)
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                // Delete button
                Button(action: {
                    onDeleteStage(stage.id)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            // Compounds and blends lists
            if !stage.compounds.isEmpty {
                Text("Compounds")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                ForEach(stage.compounds) { compound in
                    if let actualCompound = dataStore.compoundLibrary.compound(withID: compound.compoundID) {
                        HStack {
                            Text(actualCompound.fullDisplayName)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text("\(Int(compound.doseMg)) mg every \(compound.frequencyDays, specifier: "%.1f") days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            
            if !stage.blends.isEmpty {
                Text("Blends")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.top, 4)
                
                ForEach(stage.blends) { blend in
                    if let actualBlend = dataStore.compoundLibrary.blend(withID: blend.blendID) {
                        HStack {
                            Text(actualBlend.name)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text("\(Int(blend.doseMg)) mg every \(blend.frequencyDays, specifier: "%.1f") days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding()
        .background(stageColor(for: stage).opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private func stageColor(for stage: TreatmentStage) -> Color {
        let stageIndex = treatment.stages?.firstIndex(where: { $0.id == stage.id }) ?? 0
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .yellow, .teal]
        return colors[stageIndex % colors.count]
    }
}

// TreatmentStageFormView is imported from separate file

// Simple form for creating advanced treatments
struct AdvancedTreatmentFormView_Impl: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Binding var isPresented: Bool
    
    @State private var name: String = ""
    @State private var startDate = Date()
    @State private var totalWeeks: String = "12"
    @State private var notes: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Treatment Details")) {
                    TextField("Name", text: $name)
                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                    TextField("Total Weeks", text: $totalWeeks)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("New Advanced Treatment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTreatment()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && Int(totalWeeks) != nil && Int(totalWeeks) ?? 0 > 0
    }
    
    private func createTreatment() {
        guard let totalWeeksInt = Int(totalWeeks) else { return }
        
        var newTreatment = Treatment(
            name: name,
            startDate: startDate,
            notes: notes.isEmpty ? nil : notes,
            treatmentType: .advanced
        )
        
        newTreatment.totalWeeks = totalWeeksInt
        
        // Save the treatment
        dataStore.addTreatment(newTreatment)
        
        // Close the form
        isPresented = false
    }
}

// Component views are imported from TreatmentComponentViews.swift

// Preview removed to avoid ambiguity
/*
#Preview {
    NavigationView {
        AdvancedTreatmentView()
            .environmentObject(AppDataStore())
    }
}
*/