import SwiftUI

struct CompoundListView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Environment(\.dismiss) var dismiss
    
    @Binding var selectedCompoundID: UUID?
    
    @State private var searchText = ""
    @State private var filterClass: Compound.Class?
    @State private var filterRoute: Compound.Route?
    
    var filteredCompounds: [Compound] {
        let compounds = dataStore.compoundLibrary.compounds
        
        return compounds.filter { compound in
            // Apply search filter
            let matchesSearch = searchText.isEmpty || 
                compound.fullDisplayName.localizedCaseInsensitiveContains(searchText)
            
            // Apply class filter
            let matchesClass = filterClass == nil || compound.classType == filterClass
            
            // Apply route filter - compound must support the selected route
            let matchesRoute = filterRoute == nil || 
                (compound.defaultBioavailability[filterRoute!] ?? 0.0) > 0
            
            return matchesSearch && matchesClass && matchesRoute
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search and filters
                SearchBar(text: $searchText, placeholder: "Search compounds")
                
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
                
                // Route filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        RouteFilterButton(title: "All Routes", isSelected: filterRoute == nil) {
                            filterRoute = nil
                        }
                        
                        ForEach(Compound.Route.allCases, id: \.self) { route in
                            RouteFilterButton(
                                title: route.displayName,
                                isSelected: filterRoute == route
                            ) {
                                filterRoute = route
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Compound list
                List {
                    ForEach(filteredCompounds) { compound in
                        CompoundRow(compound: compound, isSelected: selectedCompoundID == compound.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCompoundID = compound.id
                                dismiss()
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Compound")
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

// MARK: - Supporting Views

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct ClassFilterButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct RouteFilterButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isSelected ? Color.green : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct CompoundRow: View {
    var compound: Compound
    var isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(compound.fullDisplayName)
                    .font(.headline)
                
                Text("Half-life: \(String(format: "%.1f", compound.halfLifeDays)) days")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Show supported routes
                let supportedRoutes = compound.defaultBioavailability.keys.map { $0.displayName }.joined(separator: ", ")
                Text("Routes: \(supportedRoutes)")
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
    CompoundListView(selectedCompoundID: .constant(nil))
        .environmentObject(AppDataStore())
} 