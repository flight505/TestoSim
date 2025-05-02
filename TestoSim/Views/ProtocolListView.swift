import SwiftUI

struct ProtocolListView: View {
    @EnvironmentObject var dataStore: AppDataStore
    
    var body: some View {
        List {
            if dataStore.profile.protocols.isEmpty {
                Text("No protocols yet. Tap + to add one.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(dataStore.profile.protocols) { protocol in
                    NavigationLink(destination: ProtocolDetailView(protocol: `protocol`)) {
                        VStack(alignment: .leading) {
                            Text(`protocol`.name)
                                .font(.headline)
                            Text("\(`protocol`.doseMg, specifier: "%.0f") mg \(`protocol`.ester.name) every \(`protocol`.frequencyDays, specifier: "%.1f") days")
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