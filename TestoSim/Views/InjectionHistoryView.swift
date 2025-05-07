import SwiftUI

struct InjectionHistoryView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @State private var filterBy: UUID? = nil
    @State private var selectedTreatmentType: String = "simple"
    
    var body: some View {
        NavigationView {
            VStack {
                TreatmentAdherenceStatsView(treatmentType: selectedTreatmentType)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 1)
                    .padding(.horizontal)
                
                // Treatment type selector
                Picker("Treatment Type", selection: $selectedTreatmentType) {
                    Text("Simple Treatments").tag("simple")
                    Text("Advanced Treatments").tag("advanced")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                
                treatmentFilterPicker
                
                List {
                    if historyRecords.isEmpty {
                        Text("No treatment administration records found")
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(historyRecords) { record in
                            TreatmentAdministrationRow(record: record)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Treatment Administration History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear Old") {
                        dataStore.cleanupOldRecords()
                    }
                }
            }
        }
    }
    
    private var treatmentFilterPicker: some View {
        Picker("Filter by Treatment", selection: $filterBy) {
            Text("All Treatments").tag(nil as UUID?)
            
            // Use treatments from dataStore and filter by selected treatment type
            ForEach(dataStore.treatments.filter { 
                $0.treatmentType == (selectedTreatmentType == "simple" ? .simple : .advanced)
            }) { treatment in
                Text(treatment.name).tag(treatment.id as UUID?)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .padding(.horizontal)
    }
    
    private var historyRecords: [NotificationManager.InjectionRecord] {
        // Use the new method that supports the unified treatment model
        dataStore.injectionHistory(for: filterBy, treatmentType: selectedTreatmentType)
            .sorted(by: { $0.scheduledDate > $1.scheduledDate })
    }
}

struct TreatmentAdministrationRow: View {
    let record: NotificationManager.InjectionRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(record.compoundOrBlendName) \(record.doseMg.isFinite ? Int(record.doseMg) : 0)mg")
                    .font(.headline)
                
                Spacer()
                
                statusBadge
            }
            
            HStack {
                Label {
                    Text(record.scheduledDate, style: .date)
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Label {
                    Text(record.scheduledDate, style: .time)
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                }
            }
            
            if let acknowledgedDate = record.acknowledgedDate {
                Text("Taken: \(acknowledgedDate, style: .date) at \(acknowledgedDate, style: .time)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch record.status {
        case .onTime:
            return .green
        case .late:
            return .orange
        case .missed:
            return .red
        }
    }
    
    private var statusText: String {
        switch record.status {
        case .onTime:
            return "On Time"
        case .late:
            return "Late"
        case .missed:
            return "Missed"
        }
    }
}

struct TreatmentAdherenceStatsView: View {
    @EnvironmentObject var dataStore: AppDataStore
    let treatmentType: String
    
    private var allRecords: [NotificationManager.InjectionRecord] {
        // Use the new method that supports the unified treatment model
        dataStore.injectionHistory(treatmentType: treatmentType)
    }
    
    private var onTimeCount: Int {
        allRecords.filter { $0.status == .onTime }.count
    }
    
    private var lateCount: Int {
        allRecords.filter { $0.status == .late }.count
    }
    
    private var missedCount: Int {
        allRecords.filter { $0.status == .missed }.count
    }
    
    private var adherencePercentage: Double {
        if allRecords.isEmpty {
            return 0
        }
        return Double(onTimeCount + lateCount) / Double(allRecords.count) * 100
    }
    
    var body: some View {
        VStack {
            Text("Adherence Rate: \(adherencePercentage.isFinite ? Int(adherencePercentage) : 0)%")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(spacing: 20) {
                TreatmentAdherenceStatItem(label: "On Time", value: onTimeCount, color: .green)
                TreatmentAdherenceStatItem(label: "Late", value: lateCount, color: .orange)
                TreatmentAdherenceStatItem(label: "Missed", value: missedCount, color: .red)
            }
        }
    }
}

struct TreatmentAdherenceStatItem: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct InjectionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        InjectionHistoryView()
            .environmentObject(AppDataStore())
    }
}

struct TreatmentAdherenceStatsView_Previews: PreviewProvider {
    static var previews: some View {
        TreatmentAdherenceStatsView(treatmentType: "simple")
            .environmentObject(AppDataStore())
            .padding()
            .previewLayout(.sizeThatFits)
    }
} 