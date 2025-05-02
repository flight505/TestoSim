import SwiftUI

struct ProtocolDetailView: View {
    @EnvironmentObject var dataStore: AppDataStore
    @State private var showingAddBloodSheet = false
    @State private var showingCalibrateConfirm = false
    
    let injectionProtocol: InjectionProtocol
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Protocol summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dose: \(injectionProtocol.doseMg, specifier: "%.0f") mg")
                        .font(.headline)
                    Text("Ester: \(injectionProtocol.ester.name)")
                        .font(.headline)
                    Text("Frequency: Every \(injectionProtocol.frequencyDays, specifier: "%.1f") days")
                        .font(.headline)
                    Text("Started: \(formatDate(injectionProtocol.startDate))")
                        .font(.headline)
                    
                    if let notes = injectionProtocol.notes, !notes.isEmpty {
                        Text("Notes:")
                            .font(.headline)
                            .padding(.top, 4)
                        Text(notes)
                            .font(.body)
                    }
                }
                .padding(.bottom, 8)
                
                // Latest blood work display
                if let latestSample = injectionProtocol.bloodSamples.max(by: { $0.date < $1.date }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Latest Blood Test")
                            .font(.headline)
                        
                        let modelPrediction = dataStore.calculateLevel(at: latestSample.date, 
                                                                      for: injectionProtocol, 
                                                                      using: dataStore.profile.calibrationFactor)
                        
                        Text("Date: \(formatDate(latestSample.date))")
                        Text("Measured: \(dataStore.formatValue(latestSample.value, unit: latestSample.unit)) \(latestSample.unit)")
                        Text("Predicted: \(dataStore.formatValue(modelPrediction, unit: dataStore.profile.unit)) \(dataStore.profile.unit)")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Simulation chart
                TestosteroneChart(injectionProtocol: injectionProtocol)
                
                // Action buttons
                HStack(spacing: 20) {
                    Button {
                        showingAddBloodSheet = true
                    } label: {
                        Label("Add Blood Test", systemImage: "drop.fill")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        dataStore.calibrateProtocol(injectionProtocol)
                        showingCalibrateConfirm = true
                    } label: {
                        Label("Recalibrate Model", systemImage: "slider.horizontal.3")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.bordered)
                    .disabled(injectionProtocol.bloodSamples.isEmpty)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle(injectionProtocol.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    dataStore.protocolToEdit = injectionProtocol
                    dataStore.isPresentingProtocolForm = true
                }
            }
        }
        .onAppear {
            dataStore.selectProtocol(id: injectionProtocol.id)
        }
        .alert("Calibration Updated", isPresented: $showingCalibrateConfirm) {
            Button("OK", role: .cancel) { }
        }
        .sheet(isPresented: $showingAddBloodSheet) {
            AddBloodworkView(injectionProtocol: injectionProtocol)
                .environmentObject(dataStore)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ProtocolDetailView(injectionProtocol: InjectionProtocol(
            name: "Test Protocol",
            ester: .cypionate,
            doseMg: 100,
            frequencyDays: 7,
            startDate: Date()
        ))
        .environmentObject(AppDataStore())
    }
} 