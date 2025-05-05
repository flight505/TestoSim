import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @State private var dobString: String = ""
    @State private var showingNotificationSettings = false
    @State private var showingInjectionHistory = false
    @State private var showingModelInfo = false
    @State private var showingAllometricInfo = false
    
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
                
                Button {
                    showingAllometricInfo = true
                } label: {
                    HStack {
                        Image(systemName: "scalemass")
                            .frame(width: 25, height: 25)
                            .foregroundColor(.blue)
                        Text("How physical measurements improve accuracy")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                .sheet(isPresented: $showingAllometricInfo) {
                    AllometricInfoView()
                }
            }
            
            Section("Notifications & Adherence") {
                Button {
                    showingNotificationSettings = true
                } label: {
                    HStack {
                        Image(systemName: "bell")
                            .frame(width: 25, height: 25)
                            .foregroundColor(.blue)
                        Text("Notification Settings")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                
                Button {
                    showingInjectionHistory = true
                } label: {
                    HStack {
                        Image(systemName: "list.clipboard")
                            .frame(width: 25, height: 25)
                            .foregroundColor(.blue)
                        Text("Injection History")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                
                // Show adherence rate if we have any data
                if dataStore.adherenceStats().total > 0 {
                    HStack {
                        Text("Adherence Rate:")
                        Spacer()
                        Text(String(format: "%.1f%%", dataStore.adherencePercentage()))
                            .fontWeight(.bold)
                    }
                }
            }
            
            Section("Settings") {
                Picker("Preferred Unit", selection: $dataStore.profile.unit) {
                    Text("ng/dL").tag("ng/dL")
                    Text("nmol/L").tag("nmol/L")
                }
                
                Toggle("Use iCloud Sync", isOn: $dataStore.profile.usesICloudSync)
                
                Toggle(isOn: $dataStore.profile.useTwoCompartmentModel) {
                    HStack {
                        Text("Two-Compartment Model")
                        Button {
                            showingModelInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .alert("Advanced PK Model", isPresented: $showingModelInfo) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("The two-compartment model provides more accurate concentration predictions, especially for long-acting compounds, but requires more processing power. Turn this off on older devices if you experience lag.")
                }
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
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
                .environmentObject(dataStore)
        }
        .sheet(isPresented: $showingInjectionHistory) {
            InjectionHistoryView()
                .environmentObject(dataStore)
        }
    }
}

struct AllometricInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("How Your Measurements Improve Accuracy")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.bottom, 6)
                        
                        Text("TestoSim uses allometric scaling to personalize pharmacokinetic predictions based on your physical measurements.")
                            .font(.headline)
                            .padding(.bottom, 6)
                        
                        Text("What is Allometric Scaling?")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Allometric scaling is a scientific approach that accounts for how drug metabolism and distribution scales with body size. People with different body sizes process medications differently.")
                        
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                                .padding()
                            
                            VStack(alignment: .leading) {
                                Text("Volume of Distribution")
                                    .fontWeight(.bold)
                                Text("Vd(user) = Vd(70kg) × (Weight/70)¹·⁰")
                                Text("How your bodyweight affects how widely the compound distributes throughout your body.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                                .padding()
                            
                            VStack(alignment: .leading) {
                                Text("Clearance Rate")
                                    .fontWeight(.bold)
                                Text("CL(user) = CL(70kg) × (Weight/70)⁰·⁷⁵")
                                Text("How your bodyweight affects how quickly your body eliminates the compound.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Group {
                        Text("Benefits of Providing Your Measurements")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.top)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("More accurate peak and trough predictions", systemImage: "checkmark.circle")
                            Label("Better timing recommendations for blood tests", systemImage: "checkmark.circle")
                            Label("More precise dosing guidance", systemImage: "checkmark.circle")
                            Label("Personalized pharmacokinetic calculations", systemImage: "checkmark.circle")
                        }
                        .padding(.leading)
                        
                        Text("Scientific Basis")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.top)
                        
                        Text("This approach is based on peer-reviewed research on how testosterone pharmacokinetics vary with body size. The scaling exponents (1.0 for volume, 0.75 for clearance) are derived from population studies.")
                        
                        Text("TestoSim applies these principles to all compounds in the library to provide you with the most accurate predictions possible.")
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppDataStore())
    }
} 