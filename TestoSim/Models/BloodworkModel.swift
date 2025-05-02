import Foundation

struct BloodSample: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let value: Double
    let unit: String
    
    init(id: UUID = UUID(), date: Date, value: Double, unit: String) {
        self.id = id
        self.date = date
        self.value = value
        self.unit = unit
    }
} 