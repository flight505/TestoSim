import SwiftUI
import Charts

struct CyclePlannerView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @State private var isPresentingNewCycleForm = false
    @State private var isPresentingStageForm = false
    @State private var selectedCycle: Cycle?
    @State private var selectedStageID: UUID?
    @State private var zoomLevel: Double = 1.0
    @State private var weekViewWidth: CGFloat = 70
    
    var body: some View {
        NavigationView {
            VStack {
                if dataStore.cycles.isEmpty {
                    emptyCyclesView
                } else {
                    cycleListView
                }
            }
            .navigationTitle("Cycle Planner")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        isPresentingNewCycleForm = true
                    }) {
                        Label("Add Cycle", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewCycleForm) {
                CycleFormView(isPresented: $isPresentingNewCycleForm)
            }
            .sheet(item: $selectedCycle) { cycle in
                CycleDetailView(cycle: cycle)
            }
            
            // Detail view placeholder when no cycle is selected
            if dataStore.selectedCycleID == nil {
                Text("Select a cycle to view details")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var emptyCyclesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Cycles Yet")
                .font(.title2)
                .bold()
            
            Text("Create your first cycle to plan and visualize multi-compound treatments.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            Button(action: {
                isPresentingNewCycleForm = true
            }) {
                Text("Create Cycle")
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
    
    private var cycleListView: some View {
        List {
            Section(header: Text("My Cycles")) {
                ForEach(dataStore.cycles) { cycle in
                    CycleRowView(cycle: cycle)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dataStore.selectedCycleID = cycle.id
                            if dataStore.isCycleSimulationActive == false {
                                dataStore.simulateCycle(cycle)
                            }
                            selectedCycle = cycle
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(dataStore.selectedCycleID == cycle.id ? Color.accentColor.opacity(0.1) : Color.clear)
                        )
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        if index < dataStore.cycles.count {
                            dataStore.deleteCycle(with: dataStore.cycles[index].id)
                        }
                    }
                }
            }
            
            if dataStore.isCycleSimulationActive, !dataStore.cycleSimulationData.isEmpty {
                Section(header: Text("Simulation Results")) {
                    VStack(alignment: .leading) {
                        Text("Combined Concentration Curve")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        CycleChartView(simulationData: dataStore.cycleSimulationData)
                            .frame(height: 200)
                    }
                    .padding(.vertical)
                }
            }
        }
    }
}

struct CycleRowView: View {
    let cycle: Cycle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(cycle.name)
                .font(.headline)
            
            HStack {
                Text("Start: \(formatDate(cycle.startDate))")
                Spacer()
                Text("\(cycle.totalWeeks) weeks")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            Text("\(cycle.stages.count) stages")
                .font(.caption)
                .foregroundColor(.secondary)
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

struct CycleChartView: View {
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

// Placeholder for Cycle Form View - to be implemented
struct CycleFormView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Binding var isPresented: Bool
    @State private var cycleName: String = ""
    @State private var startDate: Date = Date()
    @State private var totalWeeks: Int = 12
    @State private var notes: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Cycle Details")) {
                    TextField("Cycle Name", text: $cycleName)
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    
                    Stepper("Duration: \(totalWeeks) weeks", value: $totalWeeks, in: 1...52)
                    
                    VStack(alignment: .leading) {
                        Text("Notes")
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                    }
                }
            }
            .navigationTitle("New Cycle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCycle()
                        isPresented = false
                    }
                    .disabled(cycleName.isEmpty)
                }
            }
        }
    }
    
    private func saveCycle() {
        let newCycle = Cycle(
            name: cycleName,
            startDate: startDate,
            totalWeeks: totalWeeks,
            notes: notes.isEmpty ? nil : notes
        )
        
        dataStore.saveCycle(newCycle)
    }
}

// Placeholder for Cycle Detail View - to be implemented
struct CycleDetailView: View {
    let cycle: Cycle
    @EnvironmentObject var dataStore: AppDataStore
    @State private var isPresentingEditForm = false
    @State private var isPresentingStageForm = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Cycle information
                    VStack(alignment: .leading, spacing: 8) {
                        Text(cycle.name)
                            .font(.title)
                            .bold()
                        
                        HStack {
                            Text("Start: \(formatDate(cycle.startDate))")
                            Spacer()
                            Text("End: \(formatDate(cycle.endDate))")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        if let notes = cycle.notes, !notes.isEmpty {
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
                    if cycle.stages.isEmpty {
                        emptyStagesView
                    } else {
                        stagesTimelineView
                    }
                    
                    // Simulation Results
                    if dataStore.isCycleSimulationActive, !dataStore.cycleSimulationData.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Simulation Results")
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            CycleChartView(simulationData: dataStore.cycleSimulationData)
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
                        isPresentingStageForm = true
                    }) {
                        Label("Add Stage", systemImage: "plus")
                    }
                }
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
            
            Text("Add stages to build your cycle timeline")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: {
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
    
    private var stagesTimelineView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.headline)
                .padding(.bottom, 5)
            
            // Timeline visualization will go here
            Text("Timeline visualization placeholder")
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
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

struct CyclePlannerView_Previews: PreviewProvider {
    static var previews: some View {
        CyclePlannerView()
            .environmentObject(AppDataStore())
    }
} 