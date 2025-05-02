import SwiftUI
import Charts

struct TestosteroneChart: View {
    @EnvironmentObject var dataStore: AppDataStore
    let injectionProtocol: InjectionProtocol
    
    var simStartDate: Date {
        dataStore.simulationData.first?.time ?? injectionProtocol.startDate
    }
    
    var simEndDate: Date {
        dataStore.simulationData.last?.time ?? dataStore.simulationEndDate
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Simulated Testosterone Levels")
                .font(.headline)
                .padding(.bottom, 4)
            
            if dataStore.simulationData.isEmpty {
                Text("No simulation data available")
                    .foregroundColor(.secondary)
            } else {
                Chart {
                    // Simulation curve
                    ForEach(dataStore.simulationData) { point in
                        LineMark(
                            x: .value("Date", point.time),
                            y: .value("Level", point.level)
                        )
                        .foregroundStyle(.blue)
                        
                        AreaMark(
                            x: .value("Date", point.time),
                            y: .value("Level", point.level)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue.opacity(0.3), .blue.opacity(0.0)]), 
                                startPoint: .top, 
                                endPoint: .bottom
                            )
                        )
                    }
                    
                    // Injection markers
                    ForEach(injectionProtocol.injectionDates(from: simStartDate, upto: simEndDate), id: \.self) { injDate in
                        RuleMark(x: .value("Injection Date", injDate))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                            .foregroundStyle(.gray)
                            .annotation(position: .bottom, alignment: .center) {
                                Image(systemName: "syringe")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                    }
                    
                    // Blood sample points
                    ForEach(injectionProtocol.bloodSamples) { sample in
                        PointMark(
                            x: .value("Sample Date", sample.date),
                            y: .value("Sample Level", sample.value)
                        )
                        .foregroundStyle(.red)
                        .annotation(position: .top) {
                            Text(dataStore.formatValue(sample.value, unit: sample.unit))
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.bottom, 8)
                        }
                    }
                }
                .frame(height: 300)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 8)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day(), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartYAxisLabel("Level (\(dataStore.profile.unit))")
                .chartXAxisLabel("Date")
            }
        }
        .padding()
    }
}

#Preview {
    TestosteroneChart(injectionProtocol: InjectionProtocol(
        name: "Test Protocol",
        ester: .cypionate,
        doseMg: 100,
        frequencyDays: 7,
        startDate: Date()
    ))
    .environmentObject(AppDataStore())
} 