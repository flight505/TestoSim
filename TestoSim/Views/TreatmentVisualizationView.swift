import SwiftUI

struct TreatmentVisualizationView: View {
    @ObservedObject var viewModel: TreatmentViewModel
    @State private var showingLayerControls = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Visualization header
            HStack {
                Text("Treatment Visualization")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if viewModel.visualizationModel != nil {
                    Button(action: {
                        showingLayerControls.toggle()
                    }) {
                        Label("Layers", systemImage: "square.3.layers.3d")
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
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
            
            // Visualization content
            if let visualizationModel = viewModel.visualizationModel {
                ZStack {
                    // Chart view
                    ChartView(model: visualizationModel)
                    
                    // Layer controls overlay (when active)
                    if showingLayerControls {
                        LayerControlsOverlay(
                            model: visualizationModel,
                            onToggleVisibility: { layerId, isVisible in
                                viewModel.updateLayerVisibility(layerID: layerId, isVisible: isVisible)
                            },
                            onChangeOpacity: { layerId, opacity in
                                viewModel.updateLayerOpacity(layerID: layerId, opacity: opacity)
                            },
                            onMoveLayerUp: { layerId in
                                viewModel.moveLayerUp(layerID: layerId)
                            },
                            onMoveLayerDown: { layerId in
                                viewModel.moveLayerDown(layerID: layerId)
                            },
                            onDismiss: {
                                showingLayerControls = false
                            }
                        )
                    }
                }
                
                // Statistics panel
                if let statistics = viewModel.visualizationStatistics {
                    StatisticsPanel(statistics: statistics, unit: visualizationModel.baseUnit)
                }
            } else {
                // No visualization selected state
                VStack(spacing: 20) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Select a treatment to view visualization")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
    }
}

// Placeholder for the chart view (would integrate with a charting library)
struct ChartView: View {
    let model: VisualizationModel
    
    var body: some View {
        VStack {
            Text("Treatment Chart")
                .font(.headline)
            
            // This is a placeholder for the actual chart implementation
            // In a real implementation, this would be a SwiftUI wrapper around
            // a charting library like SciChart or SwiftUICharts
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                
                VStack(spacing: 12) {
                    Text("Chart for date range:")
                        .font(.subheadline)
                    
                    Text("\(formattedDate(model.startDate)) to \(formattedDate(model.endDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Layer information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visible Layers:")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        ForEach(model.visibleLayers) { layer in
                            HStack {
                                Circle()
                                    .fill(Color(hex: layer.color))
                                    .frame(width: 8, height: 8)
                                
                                Text(layer.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .frame(height: 300)
            .padding()
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// Layer controls overlay view
struct LayerControlsOverlay: View {
    let model: VisualizationModel
    let onToggleVisibility: (UUID, Bool) -> Void
    let onChangeOpacity: (UUID, Double) -> Void
    let onMoveLayerUp: (UUID) -> Void
    let onMoveLayerDown: (UUID) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onDismiss()
                }
            
            // Layer controls panel
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Layer Controls")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
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
                
                // Layer list
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(model.layers) { layer in
                            LayerControlRow(
                                layer: layer,
                                onToggleVisibility: { isVisible in
                                    onToggleVisibility(layer.id, isVisible)
                                },
                                onChangeOpacity: { opacity in
                                    onChangeOpacity(layer.id, opacity)
                                },
                                onMoveUp: {
                                    onMoveLayerUp(layer.id)
                                },
                                onMoveDown: {
                                    onMoveLayerDown(layer.id)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 8)
            .frame(width: 320, height: 400)
        }
    }
}

// Single layer control row
struct LayerControlRow: View {
    let layer: VisualizationModel.Layer
    let onToggleVisibility: (Bool) -> Void
    let onChangeOpacity: (Double) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    @State private var opacity: Double
    
    init(layer: VisualizationModel.Layer, 
         onToggleVisibility: @escaping (Bool) -> Void,
         onChangeOpacity: @escaping (Double) -> Void,
         onMoveUp: @escaping () -> Void,
         onMoveDown: @escaping () -> Void) {
        self.layer = layer
        self.onToggleVisibility = onToggleVisibility
        self.onChangeOpacity = onChangeOpacity
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self._opacity = State(initialValue: layer.opacity)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Layer name and visibility toggle
            HStack {
                Circle()
                    .fill(Color(hex: layer.color))
                    .frame(width: 12, height: 12)
                
                Text(layer.name)
                    .font(.subheadline)
                
                Spacer()
                
                // Layer ordering buttons
                HStack(spacing: 4) {
                    Button(action: onMoveUp) {
                        Image(systemName: "arrow.up")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .disabled(false) // Could be controlled based on layer position
                    
                    Button(action: onMoveDown) {
                        Image(systemName: "arrow.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .disabled(false) // Could be controlled based on layer position
                }
                .padding(.trailing, 8)
                
                Toggle("", isOn: Binding(
                    get: { layer.isVisible },
                    set: { onToggleVisibility($0) }
                ))
                .labelsHidden()
            }
            
            // Opacity slider (only shown for visible layers)
            if layer.isVisible {
                HStack {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $opacity, in: 0.1...1.0, step: 0.1)
                        .onChange(of: opacity) { newValue in
                            onChangeOpacity(newValue)
                        }
                    
                    Text("\(Int(opacity * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.leading, 24)
            }
        }
    }
}

// Statistics panel
struct StatisticsPanel: View {
    let statistics: VisualizationStatistics
    let unit: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Treatment Statistics")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.2)),
                alignment: .top
            )
            
            // Statistics content
            HStack(alignment: .top, spacing: 20) {
                // Concentration stats
                VStack(alignment: .leading, spacing: 4) {
                    Text("Concentration")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    StatItem(label: "Max Total", value: "\(formattedValue(statistics.maxConcentration)) \(unit)")
                    StatItem(label: "Max Compound", value: "\(formattedValue(statistics.maxCompoundConcentration)) \(unit)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Effect indices
                VStack(alignment: .leading, spacing: 4) {
                    Text("Effect Indices")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    StatItem(label: "Anabolic", value: "\(formattedValue(statistics.averageAnabolicIndex))")
                    StatItem(label: "Androgenic", value: "\(formattedValue(statistics.averageAndrogenicIndex))")
                    StatItem(label: "Anabolic/Androgenic Ratio", value: "\(formattedValue(statistics.anabolicToAndrogenicRatio))")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    private func formattedValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}

// Single statistics item
struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Previews
struct TreatmentVisualizationView_Previews: PreviewProvider {
    static var previews: some View {
        TreatmentVisualizationView(viewModel: TreatmentViewModel())
            .previewLayout(.fixed(width: 600, height: 800))
    }
}