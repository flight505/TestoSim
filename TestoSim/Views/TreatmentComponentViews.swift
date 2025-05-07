import SwiftUI

// Compound Item Row
struct CompoundItemRow: View {
    let item: Treatment.StageCompound
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.compoundName)
                .font(.headline)
            
            HStack {
                Text("\(item.doseMg.isFinite ? Int(item.doseMg) : 0)mg")
                Spacer()
                Text("Every \(formatFrequency(item.frequencyDays))")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            Text("Route: \(item.administrationRoute)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatFrequency(_ days: Double) -> String {
        if days == 1 {
            return "day"
        } else if days == 7 {
            return "week"
        } else if days == 3.5 {
            return "3.5 days"
        } else {
            return "\(days) days"
        }
    }
}

// Blend Item Row
struct BlendItemRow: View {
    let item: Treatment.StageBlend
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.blendName)
                .font(.headline)
            
            HStack {
                Text("\(item.doseMg.isFinite ? Int(item.doseMg) : 0)mg")
                Spacer()
                Text("Every \(formatFrequency(item.frequencyDays))")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            Text("Route: \(item.administrationRoute)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatFrequency(_ days: Double) -> String {
        if days == 1 {
            return "day"
        } else if days == 7 {
            return "week"
        } else if days == 3.5 {
            return "3.5 days"
        } else {
            return "\(days) days"
        }
    }
}

// Item Configuration View
struct ItemConfigurationView: View {
    let title: String
    @Binding var doseMg: Double
    @Binding var frequencyDays: Double
    @Binding var route: Compound.Route
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dosage")) {
                    Stepper(value: $doseMg, in: 10...500, step: 10) {
                        Text("Dose: \(doseMg.isFinite ? Int(doseMg) : 0)mg")
                    }
                }
                
                Section(header: Text("Frequency")) {
                    Picker("Frequency", selection: $frequencyDays) {
                        Text("Daily").tag(1.0)
                        Text("Every other day").tag(2.0)
                        Text("Twice weekly").tag(3.5)
                        Text("Weekly").tag(7.0)
                        Text("Every 2 weeks").tag(14.0)
                    }
                    .pickerStyle(InlinePickerStyle())
                }
                
                Section(header: Text("Route")) {
                    Picker("Administration Route", selection: $route) {
                        Text("Intramuscular").tag(Compound.Route.intramuscular)
                        Text("Subcutaneous").tag(Compound.Route.subcutaneous)
                        Text("Oral").tag(Compound.Route.oral)
                        Text("Transdermal").tag(Compound.Route.transdermal)
                    }
                    .pickerStyle(InlinePickerStyle())
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }
            }
        }
    }
}

// Compound Picker View
struct CompoundPickerView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Binding var selectedCompound: Compound?
    let onCompoundSelected: (Compound) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataStore.compoundLibrary.compounds) { compound in
                    Button(action: {
                        selectedCompound = compound
                        onCompoundSelected(compound)
                    }) {
                        HStack {
                            Text(compound.fullDisplayName)
                            Spacer()
                            if selectedCompound?.id == compound.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Compound")
        }
    }
}

// Blend Picker View
struct BlendPickerView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @Binding var selectedBlend: VialBlend?
    let onBlendSelected: (VialBlend) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataStore.compoundLibrary.blends) { blend in
                    Button(action: {
                        selectedBlend = blend
                        onBlendSelected(blend)
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(blend.name)
                                    .font(.headline)
                                Text(blend.compositionDescription(using: dataStore.compoundLibrary))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedBlend?.id == blend.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Blend")
        }
    }
}