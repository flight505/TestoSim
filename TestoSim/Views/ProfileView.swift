import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @State private var dobString: String = ""
    
    var body: some View {
        Form {
            Section("User") {
                TextField("Name", text: $dataStore.profile.name)
                
                Picker("Biological Sex", selection: $dataStore.profile.biologicalSex) {
                    Text("Male").tag(UserProfile.BiologicalSex.male)
                    Text("Female").tag(UserProfile.BiologicalSex.female)
                }
                
                DatePicker(
                    "Date of Birth",
                    selection: Binding(
                        get: { dataStore.profile.dateOfBirth ?? Date() },
                        set: { dataStore.profile.dateOfBirth = $0 }
                    ),
                    displayedComponents: .date
                )
                
                if let age = dataStore.profile.age {
                    Text("Age: \(age) years")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Physical Measurements") {
                HStack {
                    Text("Height")
                    Spacer()
                    TextField("Height", value: Binding(
                        get: { dataStore.profile.heightCm ?? 0 },
                        set: { dataStore.profile.heightCm = $0 > 0 ? $0 : nil }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    Text("cm")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("Weight", value: Binding(
                        get: { dataStore.profile.weight ?? 0 },
                        set: { dataStore.profile.weight = $0 > 0 ? $0 : nil }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    Text("kg")
                        .foregroundColor(.secondary)
                }
                
                if let bsa = dataStore.profile.bodySurfaceArea {
                    Text("Body Surface Area: \(bsa, specifier: "%.2f") m²")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Settings") {
                Picker("Preferred Unit", selection: $dataStore.profile.unit) {
                    Text("ng/dL").tag("ng/dL")
                    Text("nmol/L").tag("nmol/L")
                }
                
                Toggle("Use iCloud Sync", isOn: $dataStore.profile.usesICloudSync)
            }
            
            Section("Calibration") {
                Text("Model Calibration Factor: \(dataStore.profile.calibrationFactor.formatted(.number.precision(.fractionLength(2))))")
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