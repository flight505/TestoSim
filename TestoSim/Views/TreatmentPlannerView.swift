import SwiftUI
import Charts

struct TreatmentPlannerView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @State private var isPresentingNewTreatmentForm = false
    @State private var isPresentingStageForm = false
    @State private var selectedTreatment: Treatment?
    
    var body: some View {
        VStack {
            if dataStore.treatments.filter({ $0.treatmentType == .advanced }).isEmpty {
                emptyTreatmentsView
            } else {
                treatmentListView
            }
        }
        .navigationTitle("Treatment Planner")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    isPresentingNewTreatmentForm = true
                }) {
                    Label("Add Treatment", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingNewTreatmentForm) {
            TreatmentFormView(isPresented: $isPresentingNewTreatmentForm)
                .environmentObject(dataStore)
        }
        .sheet(item: $selectedTreatment) { treatment in
            TreatmentDetailView(treatment: treatment)
                .environmentObject(dataStore)
        }
    }
    
    private var emptyTreatmentsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Advanced Treatments Yet")
                .font(.title2)
                .bold()
            
            Text("Create your first advanced treatment to plan and visualize multi-compound protocols.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            Button(action: {
                isPresentingNewTreatmentForm = true
            }) {
                Text("Create Treatment")
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
        .padding()
    }
    
    private var treatmentListView: some View {
        List {
            treatmentListSection
            
            simulationResultsSection
        }
    }
    
    private var treatmentListSection: some View {
        Section(header: Text("My Advanced Treatments")) {
            treatmentRows
        }
    }
    
    private var treatmentRows: some View {
        ForEach(dataStore.treatments.filter { $0.treatmentType == .advanced }) { treatment in
            treatmentRow(for: treatment)
        }
        .onDelete(perform: handleDelete)
    }
    
    private func treatmentRow(for treatment: Treatment) -> some View {
        TreatmentRowView(treatment: treatment)
            .contentShape(Rectangle())
            .onTapGesture {
                dataStore.selectedTreatmentID = treatment.id
                dataStore.simulateTreatment(id: treatment.id)
                selectedTreatment = treatment
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(dataStore.selectedTreatmentID == treatment.id ? Color.accentColor.opacity(0.1) : Color.clear)
            )
    }
    
    private func handleDelete(at indexSet: IndexSet) {
        let advancedTreatments = dataStore.treatments.filter { $0.treatmentType == .advanced }
        for index in indexSet {
            if index < advancedTreatments.count {
                dataStore.deleteTreatment(with: advancedTreatments[index].id)
            }
        }
    }
    
    private var simulationResultsSection: some View {
        Group {
            if let selectedID = dataStore.selectedTreatmentID,
               let treatment = dataStore.treatments.first(where: { $0.id == selectedID }),
               treatment.treatmentType == .advanced,
               !dataStore.treatmentSimulationData.isEmpty {
                Section(header: Text("Simulation Results")) {
                    VStack(alignment: .leading) {
                        Text("Combined Concentration Curve")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        TreatmentChartView(simulationData: dataStore.treatmentSimulationData)
                            .frame(height: 200)
                    }
                    .padding(.vertical)
                }
            }
        }
    }
}

struct TreatmentRowView: View {
    let treatment: Treatment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(treatment.name)
                .font(.headline)
            
            HStack {
                Text("Start: \(formatDate(treatment.startDate))")
                Spacer()
                if let weeks = treatment.totalWeeks {
                    Text("\(weeks) weeks")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            if let stages = treatment.stages {
                Text("\(stages.count) stages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct TreatmentChartView: View {
    let simulationData: [DataPoint]
    
    var body: some View {
        Chart {
            ForEach(simulationData, id: \.time) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.time),
                    y: .value("Level", dataPoint.level)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.blue.gradient)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.day().month())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}

struct TreatmentDetailView: View {
    let treatment: Treatment
    @EnvironmentObject var dataStore: AppDataStore
    @State private var isPresentingEditForm = false
    @State private var isPresentingStageForm = false
    @State private var stageToEdit: TreatmentStage?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Treatment information
                    VStack(alignment: .leading, spacing: 8) {
                        Text(treatment.name)
                            .font(.title)
                            .bold()
                        
                        HStack {
                            Text("Start: \(formatDate(treatment.startDate))")
                            Spacer()
                            Text("End: \(formatDate(treatment.endDate))")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        if let notes = treatment.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.body)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                    
                    // Stages Timeline
                    if treatment.stages == nil || treatment.stages!.isEmpty {
                        emptyStagesView
                    } else {
                        stagesListView
                    }
                    
                    // Simulation Results
                    if !dataStore.treatmentSimulationData.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Simulation Results")
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            TreatmentChartView(simulationData: dataStore.treatmentSimulationData)
                                .frame(height: 200)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        isPresentingEditForm = true
                    }) {
                        Text("Edit")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        stageToEdit = nil
                        isPresentingStageForm = true
                    }) {
                        Label("Add Stage", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingStageForm) {
                TreatmentStageFormView(
                    isPresented: $isPresentingStageForm,
                    treatment: treatment,
                    stageToEdit: stageToEdit
                )
                .environmentObject(dataStore)
            }
            .sheet(isPresented: $isPresentingEditForm) {
                TreatmentFormView(
                    isPresented: $isPresentingEditForm,
                    treatmentToEdit: treatment
                )
                .environmentObject(dataStore)
            }
        }
    }
    
    private var emptyStagesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Stages Yet")
                .font(.headline)
            
            Text("Add stages to build your treatment timeline")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: {
                stageToEdit = nil
                isPresentingStageForm = true
            }) {
                Text("Add Stage")
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    private var stagesListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stages")
                .font(.headline)
                .padding(.bottom, 5)
            
            VStack(spacing: 12) {
                if let stages = treatment.stages?.sorted(by: { $0.startWeek < $1.startWeek }) {
                    ForEach(stages) { stage in
                        StageDetailRow(stage: stage)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                stageToEdit = stage
                                isPresentingStageForm = true
                            }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct StageDetailRow: View {
    let stage: TreatmentStage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stage.name)
                .font(.headline)
            
            Text("Weeks \(stage.startWeek + 1) to \(stage.startWeek + stage.durationWeeks)")
                .font(.subheadline)
            
            Divider()
            
            HStack(alignment: .top) {
                if !stage.compounds.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Compounds")
                            .font(.caption)
                            .bold()
                        
                        ForEach(stage.compounds) { compound in
                            Text("\(compound.compoundName) - \(Int(compound.doseMg))mg")
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if !stage.blends.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Blends")
                            .font(.caption)
                            .bold()
                        
                        ForEach(stage.blends) { blend in
                            Text("\(blend.blendName) - \(Int(blend.doseMg))mg")
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}