import SwiftUI

struct InjectionHistoryView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @State private var filterBy: UUID? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                InjectionAdherenceStatsView()
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 1)
                    .padding(.horizontal)
                
                protocolFilterPicker
                
                List {
                    if historyRecords.isEmpty {
                        Text("No injection records found")
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(historyRecords) { record in
                            InjectionRecordRow(record: record)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Injection History")
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
    
    private var protocolFilterPicker: some View {
        Picker("Filter by Protocol", selection: $filterBy) {
            Text("All Protocols").tag(nil as UUID?)
            
            ForEach(dataStore.profile.protocols) { treatmentProtocol in
                Text(treatmentProtocol.name).tag(treatmentProtocol.id as UUID?)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .padding(.horizontal)
    }
    
    private var historyRecords: [NotificationManager.InjectionRecord] {
        dataStore.injectionHistory(for: filterBy)
            .sorted(by: { $0.scheduledDate > $1.scheduledDate })
    }
}

struct InjectionRecordRow: View {
    let record: NotificationManager.InjectionRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(record.compoundOrBlendName) \(Int(record.doseMg))mg")
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

struct InjectionAdherenceStatsView: View {
    @EnvironmentObject var dataStore: AppDataStore
    
    private var allRecords: [NotificationManager.InjectionRecord] {
        dataStore.injectionHistory()
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
            Text("Adherence Rate: \(Int(adherencePercentage))%")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(spacing: 20) {
                StatItem(label: "On Time", value: onTimeCount, color: .green)
                StatItem(label: "Late", value: lateCount, color: .orange)
                StatItem(label: "Missed", value: missedCount, color: .red)
            }
        }
    }
}

struct StatItem: View {
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