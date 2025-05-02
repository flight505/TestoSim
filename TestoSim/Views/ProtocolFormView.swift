import SwiftUI

struct ProtocolFormView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Environment(\.dismiss) var dismiss
    
    var protocolToEdit: InjectionProtocol?
    
    @State private var name: String = ""
    @State private var selectedEster: TestosteroneEster = .cypionate
    @State private var doseMg: String = ""
    @State private var frequencyDays: String = ""
    @State private var startDate: Date = Date()
    @State private var notes: String = ""
    
    var isEditing: Bool {
        protocolToEdit != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Protocol Details")) {
                    TextField("Name", text: $name)
                    
                    Picker("Testosterone Ester", selection: $selectedEster) {
                        ForEach(TestosteroneEster.all) { ester in
                            Text(ester.name).tag(ester)
                        }
                    }
                    
                    #if os(iOS)
                    TextField("Dose (mg)", text: $doseMg)
                        .keyboardType(.decimalPad)
                    #else
                    TextField("Dose (mg)", text: $doseMg)
                    #endif
                    
                    #if os(iOS)
                    TextField("Frequency (days)", text: $frequencyDays)
                        .keyboardType(.decimalPad)
                    #else
                    TextField("Frequency (days)", text: $frequencyDays)
                    #endif
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle(isEditing ? "Edit Protocol" : "New Protocol")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") {
                        saveProtocol()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let protocolToEdit = protocolToEdit {
                    // Fill form with existing protocol data
                    name = protocolToEdit.name
                    selectedEster = protocolToEdit.ester
                    doseMg = String(format: "%.1f", protocolToEdit.doseMg)
                    frequencyDays = String(format: "%.1f", protocolToEdit.frequencyDays)
                    startDate = protocolToEdit.startDate
                    notes = protocolToEdit.notes ?? ""
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && Double(doseMg) != nil && Double(frequencyDays) != nil
    }
    
    private func saveProtocol() {
        guard let doseValue = Double(doseMg),
              let frequencyValue = Double(frequencyDays) else {
            return
        }
        
        if isEditing, let protocolToEdit = protocolToEdit {
            var updatedProtocol = protocolToEdit
            updatedProtocol.name = name
            updatedProtocol.ester = selectedEster
            updatedProtocol.doseMg = doseValue
            updatedProtocol.frequencyDays = frequencyValue
            updatedProtocol.startDate = startDate
            updatedProtocol.notes = notes.isEmpty ? nil : notes
            
            dataStore.updateProtocol(updatedProtocol)
        } else {
            let newProtocol = InjectionProtocol(
                name: name,
                ester: selectedEster,
                doseMg: doseValue,
                frequencyDays: frequencyValue,
                startDate: startDate,
                notes: notes.isEmpty ? nil : notes
            )
            
            dataStore.addProtocol(newProtocol)
        }
        
        dismiss()
    }
}

#Preview {
    ProtocolFormView()
        .environmentObject(AppDataStore())
} 