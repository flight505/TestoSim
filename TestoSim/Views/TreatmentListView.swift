import SwiftUI

struct TreatmentListView: View {
    @ObservedObject var viewModel: TreatmentViewModel
    @State private var showingFilterOptions = false
    @State private var filterType: TreatmentType = .all
    
    enum TreatmentType {
        case all, simple, advanced
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with filter controls
            HStack {
                Text("Treatments")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    showingFilterOptions.toggle()
                }) {
                    HStack {
                        Text(filterLabel)
                        Image(systemName: "chevron.down")
                    }
                    .padding(6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .popover(isPresented: $showingFilterOptions) {
                    VStack(alignment: .leading, spacing: 12) {
                        Button("All Treatments") {
                            filterType = .all
                            showingFilterOptions = false
                        }
                        .foregroundColor(filterType == .all ? .blue : .primary)
                        
                        Button("Simple Treatments") {
                            filterType = .simple
                            showingFilterOptions = false
                        }
                        .foregroundColor(filterType == .simple ? .blue : .primary)
                        
                        Button("Advanced Treatments") {
                            filterType = .advanced
                            showingFilterOptions = false
                        }
                        .foregroundColor(filterType == .advanced ? .blue : .primary)
                    }
                    .padding()
                }
                
                Button(action: {
                    viewModel.isAddingTreatment = true
                }) {
                    Image(systemName: "plus")
                        .padding(8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.2)),
                alignment: .bottom
            )
            
            // List of treatments
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredTreatments) { treatment in
                        TreatmentListItem(
                            treatment: treatment,
                            isSelected: viewModel.selectedTreatmentID == treatment.id,
                            onSelect: {
                                viewModel.selectTreatment(id: treatment.id)
                            },
                            onEdit: {
                                viewModel.treatmentToEdit = treatment
                                viewModel.isEditingTreatment = true
                            },
                            onDelete: {
                                viewModel.deleteTreatment(treatment)
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        // Sheet to add new treatment (would be implemented separately)
        .sheet(isPresented: $viewModel.isAddingTreatment) {
            TreatmentFormView(viewModel: viewModel, compoundLibrary: CompoundLibrary())
        }
        // Sheet to edit existing treatment
        .sheet(isPresented: $viewModel.isEditingTreatment) {
            if let treatment = viewModel.treatmentToEdit {
                TreatmentFormView(viewModel: viewModel, compoundLibrary: CompoundLibrary(), treatment: treatment)
            }
        }
    }
    
    // Filter treatments based on selected filter type
    var filteredTreatments: [Treatment] {
        switch filterType {
        case .all:
            return viewModel.treatments
        case .simple:
            return viewModel.simpleTreatments
        case .advanced:
            return viewModel.advancedTreatments
        }
    }
    
    // Label for the filter button
    var filterLabel: String {
        switch filterType {
        case .all: return "All Treatments"
        case .simple: return "Simple Treatments"
        case .advanced: return "Advanced Treatments"
        }
    }
}

struct TreatmentListItem: View {
    let treatment: Treatment
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        HStack {
            // Type indicator
            ZStack {
                Circle()
                    .fill(typeColor)
                    .frame(width: 12, height: 12)
            }
            .frame(width: 24)
            
            // Treatment details
            VStack(alignment: .leading, spacing: 4) {
                Text(treatment.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label(dateRangeText, systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if treatment.treatmentType == .simple {
                        if let dose = treatment.doseMg {
                            Label("\(Int(dose))mg", systemImage: "syringe")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let weeks = treatment.totalWeeks {
                        Label("\(weeks) weeks", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                }
                
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                }
                .confirmationDialog(
                    "Delete Treatment",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive, action: onDelete)
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to delete this treatment? This action cannot be undone.")
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    // Format date range for display
    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        let startString = formatter.string(from: treatment.startDate)
        let endString = formatter.string(from: treatment.endDate)
        
        return "\(startString) - \(endString)"
    }
    
    // Color based on treatment type
    var typeColor: Color {
        switch treatment.treatmentType {
        case .simple:
            if treatment.contentType == .blend {
                return .orange // Blend treatments
            } else {
                return .blue   // Simple compound treatments
            }
        case .advanced:
            return .purple // Advanced treatments
        }
    }
}

// Preview
struct TreatmentListView_Previews: PreviewProvider {
    static var previews: some View {
        TreatmentListView(viewModel: TreatmentViewModel())
            .previewLayout(.sizeThatFits)
            .padding()
    }
}