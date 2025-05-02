import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var dataStore: AppDataStore
    
    var body: some View {
        Form {
            Section("User") {
                TextField("Name", text: $dataStore.profile.name)
            }
            
            Section("Settings") {
                Picker("Preferred Unit", selection: $dataStore.profile.unit) {
                    Text("ng/dL").tag("ng/dL")
                    Text("nmol/L").tag("nmol/L")
                }
            }
            
            Section("Calibration") {
                Text("Model Calibration Factor: \(dataStore.profile.calibrationFactor, specifier: "%.2f")")
                Button("Reset Calibration to 1.0") {
                    dataStore.profile.calibrationFactor = 1.0
                    dataStore.recalcSimulation()
                    dataStore.saveProfile()
                }
            }
        }
        .navigationTitle("Profile Settings")
        .onDisappear {
            dataStore.saveProfile()
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppDataStore())
    }
} 