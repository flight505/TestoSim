import Foundation

struct UserProfile: Codable {
    var id: UUID = UUID()
    var name: String = "My Profile"
    var unit: String = "ng/dL" // Default unit
    var calibrationFactor: Double = 1.0 // Default calibration
    var protocols: [InjectionProtocol] = []
    
    // New parameters for Story 9 and 10
    var dateOfBirth: Date?
    var heightCm: Double?
    var weight: Double? = 70.0 // Default weight in kg
    
    enum BiologicalSex: String, Codable, CaseIterable {
        case male, female
    }
    var biologicalSex: BiologicalSex = .male
    
    var usesICloudSync: Bool = false
    
    // PK Model settings - always use the more accurate two-compartment model
    var useTwoCompartmentModel: Bool = true
    
    // Computed property for body surface area (DuBois formula)
    var bodySurfaceArea: Double? {
        guard let weight = weight, let heightCm = heightCm else {
            return nil
        }
        // DuBois formula: BSA (m²) = 0.007184 × height(cm)^0.725 × weight(kg)^0.425
        return 0.007184 * pow(heightCm, 0.725) * pow(weight, 0.425)
    }
    
    // Computed property for age
    var age: Int? {
        guard let dob = dateOfBirth else {
            return nil
        }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
        return ageComponents.year
    }
} 