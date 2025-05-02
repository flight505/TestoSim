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
                        VStack(alignment: .leading) {
                            Text(injectionProtocol.name)
                                .font(.headline)
                            Text("\(injectionProtocol.doseMg, specifier: "%.0f") mg \(injectionProtocol.ester.name) every \(injectionProtocol.frequencyDays, specifier: "%.1f") days")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
        .navigationTitle("Protocols")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
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
        .sheet(isPresented: $dataStore.isPresentingProtocolForm) {
            ProtocolFormView(protocolToEdit: dataStore.protocolToEdit)
                .environmentObject(dataStore)
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