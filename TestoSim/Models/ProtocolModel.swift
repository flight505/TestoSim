import Foundation

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
        
        // Find the first injection date that is on or after the simulation's start date
        while current < simulationStartDate {
            // Check for zero/negative frequency to avoid infinite loop
            guard frequencyDays > 0 else {
                // If first injection is before sim start, add it if it's the *only* injection
                if injectionIndex == 0 && current <= endDate { dates.append(current) }
                return dates // Only one injection possible
            }
            injectionIndex += 1
            current = Calendar.current.date(byAdding: .day, value: Int(frequencyDays * Double(injectionIndex)), to: startDate)! // More robust date calculation
            // Safety Break
            if injectionIndex > 10000 { break }
        }
        
        // Now add dates within the simulation range [simStartDate, endDate]
        // Reset index based on where we are starting relative to protocol start
        injectionIndex = Int(round(current.timeIntervalSince(startDate) / (frequencyDays * 24 * 3600)))
        
        while current <= endDate {
            // Only add if it's within the simulation's actual display window start
            if current >= simulationStartDate {
                dates.append(current)
            }
            
            // Check for zero/negative frequency
            guard frequencyDays > 0 else { break } // Should only add the first one if freq <= 0
            
            injectionIndex += 1
            // Use calendar calculation for adding days to avoid potential DST issues if frequency isn't integer days
            // However, since frequency is Double, TimeInterval is more direct. Stick to TimeInterval for consistency with PK math.
            current = startDate.addingTimeInterval(Double(injectionIndex) * frequencyDays * 24 * 3600)
            // Safety Break
            if injectionIndex > 10000 { break }
        }
        return dates
    }
}

// MARK: - Protocol type enum

enum ProtocolType: String, Codable {
    case compound    // Using single Compound
    case blend       // Using VialBlend
} 