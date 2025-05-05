import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Environment(\.dismiss) private var dismiss
    
    // Local state for notification settings
    @State private var notificationsEnabled: Bool
    @State private var soundEnabled: Bool
    @State private var selectedLeadTime: NotificationManager.LeadTime
    
    // Initialize state from the notification manager
    init() {
        let notificationManager = NotificationManager.shared
        _notificationsEnabled = State(initialValue: notificationManager.notificationsEnabled)
        _soundEnabled = State(initialValue: notificationManager.soundEnabled)
        _selectedLeadTime = State(initialValue: notificationManager.selectedLeadTime)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notifications")) {
                    Toggle("Enable Injection Reminders", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { newValue in
                            dataStore.toggleNotifications(enabled: newValue)
                        }
                    
                    if notificationsEnabled {
                        Toggle("Play Sound", isOn: $soundEnabled)
                            .onChange(of: soundEnabled) { newValue in
                                dataStore.setNotificationSound(enabled: newValue)
                            }
                        
                        Picker("Remind Me", selection: $selectedLeadTime) {
                            ForEach(NotificationManager.LeadTime.allCases) { leadTime in
                                Text("Before \(leadTime.rawValue)")
                                    .tag(leadTime)
                            }
                        }
                        .onChange(of: selectedLeadTime) { newValue in
                            dataStore.setNotificationLeadTime(newValue)
                        }
                    }
                }
                
                Section(header: Text("Adherence Statistics")) {
                    NotificationAdherenceStatsView()
                }
                
                Section(header: Text("About Notifications"), footer: Text("Notifications help you stay on schedule with your injections. You'll receive reminders before each scheduled injection based on your preferences.")) {
                    // This section is just for information
                    Label("Notifications help improve adherence", systemImage: "bell.badge")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct NotificationAdherenceStatsView: View {
    @EnvironmentObject var dataStore: AppDataStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let stats = dataStore.adherenceStats()
            let adherencePercent = dataStore.adherencePercentage()
            
            HStack {
                Text("Adherence Rate:")
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "%.1f%%", adherencePercent))
                    .fontWeight(.bold)
                    .foregroundColor(adherenceColor(for: adherencePercent))
            }
            
            if stats.total > 0 {
                Divider()
                
                HStack {
                    Text("On Time:")
                    Spacer()
                    Text("\(stats.onTime) of \(stats.total)")
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Late:")
                    Spacer()
                    Text("\(stats.late) of \(stats.total)")
                        .foregroundColor(.orange)
                }
                
                HStack {
                    Text("Missed:")
                    Spacer()
                    Text("\(stats.missed) of \(stats.total)")
                        .foregroundColor(.red)
                }
            } else {
                Text("No injections recorded yet")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
    
    private func adherenceColor(for percent: Double) -> Color {
        if percent >= 90 {
            return .green
        } else if percent >= 75 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    NotificationSettingsView()
        .environmentObject(AppDataStore())
} 