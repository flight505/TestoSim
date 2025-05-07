import SwiftUI

struct ProtocolListView: View {
    @EnvironmentObject var dataStore: AppDataStore
    
    var body: some View {
        List {
            if dataStore.treatments.filter({ $0.treatmentType == .simple }).isEmpty {
                Text("No treatments yet. Tap + to add one.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(dataStore.treatments.filter { $0.treatmentType == .simple }) { treatment in
                    NavigationLink(destination: ProtocolDetailView(injectionProtocol: treatment.toLegacyProtocol() ?? InjectionProtocol(id: treatment.id, name: treatment.name, doseMg: treatment.doseMg ?? 0, frequencyDays: treatment.frequencyDays ?? 0, startDate: treatment.startDate))) {
                        treatmentRowContent(for: treatment)
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
        .navigationTitle("Treatments")
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $dataStore.isPresentingTreatmentForm) {
            TreatmentFormView(
                viewModel: dataStore.treatmentFormAdapter.viewModel,
                compoundLibrary: dataStore.compoundLibrary,
                treatment: dataStore.treatmentToEdit
            )
        }
    }
    
    // Extracted toolbar content
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .automatic) {
                NavigationLink(destination: ProfileView()) {
                    Label("Profile", systemImage: "person.circle")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    dataStore.treatmentToEdit = nil
                    dataStore.isPresentingTreatmentForm = true
                } label: {
                    Label("Add Treatment", systemImage: "plus")
                }
            }
        }
    }
    
    // Extracted treatment row content
    private func treatmentRowContent(for treatment: Treatment) -> some View {
        VStack(alignment: .leading) {
            Text(treatment.name)
                .font(.headline)
            
            // Summary text based on content type
            Group {
                if let compoundID = treatment.compoundID,
                   let compound = dataStore.compoundLibrary.compound(withID: compoundID),
                   let doseMg = treatment.doseMg,
                   let frequencyDays = treatment.frequencyDays {
                    // Compound-based treatment
                    Text("\(doseMg, format: .number.precision(.fractionLength(0))) mg \(compound.fullDisplayName) every \(frequencyDays, format: .number.precision(.fractionLength(1))) days")
                } else if let blendID = treatment.blendID,
                          let blend = dataStore.compoundLibrary.blend(withID: blendID),
                          let doseMg = treatment.doseMg,
                          let frequencyDays = treatment.frequencyDays {
                    // Blend-based treatment
                    Text("\(doseMg, format: .number.precision(.fractionLength(0))) mg \(blend.name) every \(frequencyDays, format: .number.precision(.fractionLength(1))) days")
                } else if let doseMg = treatment.doseMg,
                          let frequencyDays = treatment.frequencyDays {
                    // Generic case
                    Text("\(doseMg, format: .number.precision(.fractionLength(0))) mg every \(frequencyDays, format: .number.precision(.fractionLength(1))) days")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        // Get the treatments that are being deleted
        let simpleTreatments = dataStore.treatments.filter { $0.treatmentType == .simple }
        let idsToDelete = offsets.map { simpleTreatments[$0].id }
        
        // Delete each treatment
        for id in idsToDelete {
            dataStore.deleteTreatment(with: id)
        }
    }
}

#Preview {
    NavigationStack {
        ProtocolListView()
            .environmentObject(AppDataStore())
    }
} 