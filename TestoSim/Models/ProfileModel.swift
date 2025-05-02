import Foundation

struct UserProfile: Codable {
    var id: UUID = UUID()
    var name: String = "My Profile"
    var unit: String = "ng/dL" // Default unit
    var calibrationFactor: Double = 1.0 // Default calibration
    var protocols: [InjectionProtocol] = []
} 