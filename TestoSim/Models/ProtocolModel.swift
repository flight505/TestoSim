import Foundation

@available(*, deprecated, message: "Use Treatment with treatmentType = .simple instead")
struct InjectionProtocol: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var doseMg: Double
    var frequencyDays: Double
    var startDate: Date
    var notes: String?
    var bloodSamples: [BloodSample] = []
    
    // Properties for compound/blend support
    var compoundID: UUID?
    var blendID: UUID?
    var selectedRoute: String? // Stores Compound.Route.rawValue
    
    // Computed property to determine protocol type
    var protocolType: ProtocolType {
        if compoundID != nil {
            return .compound
        } else if blendID != nil {
            return .blend
        } else {
            // This should not happen in new protocols
            return .compound // Default to compound
        }
    }
    
    // MARK: - Injection dates calculation
    
    func injectionDates(from simulationStartDate: Date, upto endDate: Date) -> [Date] {
        var dates: [Date] = []
        var current = startDate
        var injectionIndex = 0
        
        // Check for zero/negative frequency to avoid infinite loop
        guard frequencyDays > 0 else {
            // For zero/negative frequency, just include the start date if it's in range
            if startDate <= endDate && startDate >= simulationStartDate {
                dates.append(startDate)
            }
            return dates
        }
        
        // Calculate how many injections would have occurred before the simulation start
        // by determining the injection index offset
        if simulationStartDate > startDate {
            let daysSinceStart = simulationStartDate.timeIntervalSince(startDate) / (24 * 3600)
            injectionIndex = Int(floor(daysSinceStart / frequencyDays))
            // Set current to the first injection that's on or after simulationStartDate
            current = startDate.addingTimeInterval(Double(injectionIndex) * frequencyDays * 24 * 3600)
        }
        
        // Now add all injections from current date up to endDate
        while current <= endDate {
            dates.append(current)
            
            injectionIndex += 1
            current = startDate.addingTimeInterval(Double(injectionIndex) * frequencyDays * 24 * 3600)
            
            // Safety break to prevent infinite loops
            if injectionIndex > 10000 { 
                print("Safety break in injection dates calculation")
                break 
            }
        }
        
        return dates
    }
}

// MARK: - Protocol type enum

@available(*, deprecated, message: "Use Treatment.ContentType instead")
enum ProtocolType: String, Codable {
    case compound    // Using single Compound
    case blend       // Using VialBlend
} 