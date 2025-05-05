import SwiftUI

struct VialBlendListView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Environment(\.dismiss) var dismiss
    
    @Binding var selectedBlendID: UUID?
    
    @State private var searchText = ""
    @State private var filterClass: Compound.Class?
    
    var filteredBlends: [VialBlend] {
        let blends = dataStore.compoundLibrary.blends
        
        return blends.filter { blend in
            // Apply search filter
            let matchesSearch = searchText.isEmpty || 
                blend.name.localizedCaseInsensitiveContains(searchText) ||
                (blend.manufacturer?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            // Apply class filter (check if blend contains any compound of the selected class)
            let matchesClass: Bool
            if let filterClass = filterClass {
                matchesClass = blend.resolvedComponents(using: dataStore.compoundLibrary)
                    .contains { $0.compound.classType == filterClass }
            } else {
                matchesClass = true
            }
            
            return matchesSearch && matchesClass
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search and filters
                SearchBar(text: $searchText, placeholder: "Search blends")
                
                // Class filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ClassFilterButton(title: "All", isSelected: filterClass == nil) {
                            filterClass = nil
                        }
                        
                        ForEach(Compound.Class.allCases, id: \.self) { classType in
                            ClassFilterButton(
                                title: classType.displayName,
                                isSelected: filterClass == classType
                            ) {
                                filterClass = classType
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Blend list
                List {
                    ForEach(filteredBlends) { blend in
                        BlendRow(
                            blend: blend, 
                            library: dataStore.compoundLibrary,
                            isSelected: selectedBlendID == blend.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedBlendID = blend.id
                            dismiss()
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Blend")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BlendRow: View {
    var blend: VialBlend
    var library: CompoundLibrary
    var isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(blend.name)
                    .font(.headline)
                
                if let manufacturer = blend.manufacturer {
                    Text(manufacturer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(blend.compositionDescription(using: library))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text("Total: \(String(format: "%.0f", blend.totalConcentration)) mg/mL")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VialBlendListView(selectedBlendID: .constant(nil))
        .environmentObject(AppDataStore())
} 