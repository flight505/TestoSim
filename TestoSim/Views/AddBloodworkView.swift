import SwiftUI

struct AddBloodworkView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Environment(\.dismiss) var dismiss
    
    let injectionProtocol: InjectionProtocol
    
    @State private var date: Date = Date()
    @State private var valueText: String = ""
    @State private var selectedUnit: String = "ng/dL"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Blood Test Details")) {
                    DatePicker("Date", selection: $date, in: injectionProtocol.startDate..., displayedComponents: [.date, .hourAndMinute])
                    
                    #if os(iOS)
                    TextField("Testosterone Level", text: $valueText)
                        .keyboardType(.decimalPad)
                    #else
                    TextField("Testosterone Level", text: $valueText)
                    #endif
                    
                    Picker("Unit", selection: $selectedUnit) {
                        Text("ng/dL").tag("ng/dL")
                        Text("nmol/L").tag("nmol/L")
                    }
                }
                
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Protocol: \(injectionProtocol.name)")
                                .font(.subheadline)
                            Text("\(injectionProtocol.doseMg, format: .number.precision(.fractionLength(0))) mg \(injectionProtocol.ester.name) every \(injectionProtocol.frequencyDays, format: .number.precision(.fractionLength(1))) days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Add Blood Test Result")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBloodwork()
                    }
                    .disabled(Double(valueText) == nil)
                }
            }
            .onAppear {
                // Default to user's preferred unit
                selectedUnit = dataStore.profile.unit
            }
        }
    }
    
    private func saveBloodwork() {
        guard let value = Double(valueText) else { return }
        
        let newSample = BloodSample(
            date: date,
            value: value,
            unit: selectedUnit
        )
        
        if let index = dataStore.profile.protocols.firstIndex(where: { $0.id == injectionProtocol.id }) {
            dataStore.profile.protocols[index].bloodSamples.append(newSample)
            dataStore.saveProfile()
            dismiss()
        }
    }
}

#Preview {
    AddBloodworkView(injectionProtocol: InjectionProtocol(
        name: "Test Protocol",
        ester: .cypionate,
        doseMg: 100,
        frequencyDays: 7,
        startDate: Date().addingTimeInterval(-30 * 24 * 3600) // 30 days ago
    ))
    .environmentObject(AppDataStore())
} 