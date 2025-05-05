import SwiftUI

struct ProtocolListView: View {
    @EnvironmentObject var dataStore: AppDataStore
    
    var body: some View {
        List {
            if dataStore.profile.protocols.isEmpty {
                Text("No protocols yet. Tap + to add one.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(dataStore.profile.protocols) { injectionProtocol in
                    NavigationLink(destination: ProtocolDetailView(injectionProtocol: injectionProtocol)) {
                        protocolRowContent(for: injectionProtocol)
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
        .navigationTitle("Protocols")
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $dataStore.isPresentingProtocolForm) {
            ProtocolFormView(protocolToEdit: dataStore.protocolToEdit)
                .environmentObject(dataStore)
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
                    dataStore.protocolToEdit = nil
                    dataStore.isPresentingProtocolForm = true
                } label: {
                    Label("Add Protocol", systemImage: "plus")
                }
            }
        }
    }
    
    // Extracted protocol row content
    private func protocolRowContent(for injectionProtocol: InjectionProtocol) -> some View {
        VStack(alignment: .leading) {
            Text(injectionProtocol.name)
                .font(.headline)
            
            // Summary text based on protocol type
            Group {
                switch injectionProtocol.protocolType {
                case .compound:
                    if let compoundID = injectionProtocol.compoundID,
                       let compound = dataStore.compoundLibrary.compound(withID: compoundID) {
                        Text("\(injectionProtocol.doseMg, format: .number.precision(.fractionLength(0))) mg \(compound.fullDisplayName) every \(injectionProtocol.frequencyDays, format: .number.precision(.fractionLength(1))) days")
                    } else {
                        Text("\(injectionProtocol.doseMg, format: .number.precision(.fractionLength(0))) mg every \(injectionProtocol.frequencyDays, format: .number.precision(.fractionLength(1))) days")
                    }
                    
                case .blend:
                    if let blendID = injectionProtocol.blendID,
                       let blend = dataStore.compoundLibrary.blend(withID: blendID) {
                        Text("\(injectionProtocol.doseMg, format: .number.precision(.fractionLength(0))) mg \(blend.name) every \(injectionProtocol.frequencyDays, format: .number.precision(.fractionLength(1))) days")
                    } else {
                        Text("\(injectionProtocol.doseMg, format: .number.precision(.fractionLength(0))) mg every \(injectionProtocol.frequencyDays, format: .number.precision(.fractionLength(1))) days")
                    }
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        dataStore.removeProtocol(at: offsets)
    }
}

#Preview {
    NavigationStack {
        ProtocolListView()
            .environmentObject(AppDataStore())
    }
} 