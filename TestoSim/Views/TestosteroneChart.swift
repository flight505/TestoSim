import SwiftUI
import Charts

struct TestosteroneChart: View {
    @EnvironmentObject var dataStore: AppDataStore
    let treatmentProtocol: InjectionProtocol
    
    @State private var selectedDataPoint: DataPoint?
    @State private var selectedDate: Date?
    
    // Find reasonable min/max for Y axis
    private var yAxisRange: ClosedRange<Double> {
        if dataStore.simulationData.isEmpty {
            return 0...1000
        }
        
        let levels = dataStore.simulationData.map { $0.level }
        let minLevel = max(0, levels.min() ?? 0)
        let maxLevel = max(1000, levels.max() ?? 1000)
        
        // Add 20% padding at top
        return minLevel...(maxLevel * 1.2)
    }
    
    // Find dates for X axis to avoid super tiny display
    private var dateRange: ClosedRange<Date> {
        guard !dataStore.simulationData.isEmpty else {
            return Date()...(Date().addingTimeInterval(30*24*3600))
        }
        
        if let firstDate = dataStore.simulationData.first?.time,
           let lastDate = dataStore.simulationData.last?.time {
            return firstDate...lastDate
        }
        
        return Date()...(Date().addingTimeInterval(30*24*3600))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Concentration Chart")
                    .font(.headline)
                Spacer()
                Text(dataStore.profile.unit)
                    .foregroundColor(.secondary)
            }
            
            ZStack(alignment: .topLeading) {
                // Chart
                Chart {
                    // Main concentration line
                    ForEach(dataStore.simulationData) { dataPoint in
                        LineMark(
                            x: .value("Date", dataPoint.time),
                            y: .value("Level", dataPoint.level)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                    
                    // Highlight selected point
                    if let selectedPoint = selectedDataPoint {
                        PointMark(
                            x: .value("Date", selectedPoint.time),
                            y: .value("Level", selectedPoint.level)
                        )
                        .symbolSize(100)
                        .foregroundStyle(Color.blue.opacity(0.3))
                    }
                    
                    // Injection dates markers
                    let injectionDates = treatmentProtocol.injectionDates(
                        from: dateRange.lowerBound,
                        upto: dateRange.upperBound
                    )
                    
                    ForEach(injectionDates, id: \.self) { date in
                        // Add point markers for injections
                        PointMark(
                            x: .value("Injection", date),
                            y: .value("Level", findLevelAt(date: date))
                        )
                        .foregroundStyle(Color.green)
                        .symbolSize(30)
                        
                        // Add vertical lines
                        RuleMark(
                            x: .value("Injection", date)
                        )
                        .foregroundStyle(Color.green.opacity(0.2))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    
                    // Show selected date vertical line
                    if let date = selectedDate {
                        RuleMark(
                            x: .value("Selected", date)
                        )
                        .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                }
                .chartYScale(domain: yAxisRange)
                .chartXScale(domain: dateRange)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                        let level = value.as(Double.self) ?? 0
                        AxisValueLabel("\(level.isFinite ? Int(level) : 0)")
                        AxisGridLine()
                    }
                }
                .frame(height: 250)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let x = value.location.x - geo.frame(in: .local).origin.x
                                        guard let date = proxy.value(atX: x, as: Date.self) else { return }
                                        
                                        selectedDate = date
                                        if let closestPoint = findClosestDataPoint(to: date) {
                                            selectedDataPoint = closestPoint
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedDate = nil
                                        selectedDataPoint = nil
                                    }
                            )
                    }
                }
                
                // If no data, show message
                if dataStore.simulationData.isEmpty {
                    Text("No data available for chart")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGray6).opacity(0.5))
                }
            }
            
            // Display selected point info
            if let selected = selectedDataPoint {
                HStack {
                    VStack(alignment: .leading) {
                        Text(selected.time, style: .date)
                            .font(.caption)
                        Text(selected.time, style: .time)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Text("\(selected.level.isFinite ? Int(selected.level) : 0) \(dataStore.profile.unit)")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func findClosestDataPoint(to date: Date) -> DataPoint? {
        guard !dataStore.simulationData.isEmpty else { return nil }
        
        return dataStore.simulationData.min(by: { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) })
    }
    
    private func findLevelAt(date: Date) -> Double {
        guard !dataStore.simulationData.isEmpty else { return 0 }
        
        if let closestPoint = findClosestDataPoint(to: date) {
            return closestPoint.level
        }
        
        // If no close point found, try to calculate directly
        return dataStore.predictedLevel(on: date, for: treatmentProtocol)
    }
} 