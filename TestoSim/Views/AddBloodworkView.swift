import SwiftUI

struct AddBloodworkView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Environment(\.dismiss) var dismiss
    
    var injectionProtocol: InjectionProtocol
    
    @State private var bloodValue: String = ""
    @State private var bloodDate: Date = Date()
    @State private var notes: String = ""
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Sample Details") {
                    TextField("Blood Level Value (\(dataStore.profile.unit))", text: $bloodValue)
                        .keyboardType(.numbersAndPunctuation)
                    
                    DatePicker("Sample Date", selection: $bloodDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                Section("Actions") {
                    Button("Add Sample and Calibrate") {
                        saveBloodwork(andCalibrate: true)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                    
                    Button("Add Sample Only") {
                        saveBloodwork(andCalibrate: false)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
                }
            }
            .navigationTitle("Add Blood Sample")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(alertMessage, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
    
    private func saveBloodwork(andCalibrate: Bool) {
        guard let valueDouble = Double(bloodValue) else {
            alertMessage = "Please enter a valid number for the blood level"
            showingAlert = true
            return
        }
        
        // Create a new sample
        let newSample = BloodSample(
            date: bloodDate,
            value: valueDouble,
            unit: dataStore.profile.unit
        )
        
        // Add to the protocol
        var updatedProtocol = injectionProtocol
        updatedProtocol.bloodSamples.append(newSample)
        
        // Save back to the data store
        dataStore.updateProtocol(updatedProtocol)
        
        // If requested, perform calibration
        if andCalibrate {
            dataStore.calibrateProtocol(updatedProtocol)
        }
        
        dismiss()
    }
}

#Preview {
    AddBloodworkView(injectionProtocol: InjectionProtocol(
        name: "Test Protocol",
        doseMg: 100,
        frequencyDays: 7,
        startDate: Date().addingTimeInterval(-30 * 24 * 3600) // 30 days ago
    ))
    .environmentObject(AppDataStore())
} 