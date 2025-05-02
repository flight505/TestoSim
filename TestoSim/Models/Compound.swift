import Foundation

struct Compound: Identifiable, Codable, Hashable {
    enum Class: String, Codable, CaseIterable {
        case testosterone, nandrolone, trenbolone,
             boldenone, drostanolone, stanozolol, metenolone,
             trestolone, dhb
        
        var displayName: String {
            switch self {
            case .testosterone: return "Testosterone"
            case .nandrolone: return "Nandrolone"
            case .trenbolone: return "Trenbolone"
            case .boldenone: return "Boldenone"
            case .drostanolone: return "Drostanolone (Masteron)"
            case .stanozolol: return "Stanozolol (Winstrol)"
            case .metenolone: return "Metenolone (Primobolan)"
            case .trestolone: return "Trestolone (MENT)"
            case .dhb: return "1-Testosterone (DHB)"
            }
        }
    }
    
    enum Route: String, Codable, CaseIterable {
        case intramuscular, subcutaneous, oral, transdermal
        
        var displayName: String {
            switch self {
            case .intramuscular: return "Intramuscular (IM)"
            case .subcutaneous: return "Subcutaneous (SubQ)"
            case .oral: return "Oral"
            case .transdermal: return "Transdermal"
            }
        }
    }
    
    let id: UUID
    var commonName: String
    var classType: Class
    var ester: String?          // nil for suspensions
    var halfLifeDays: Double
    var defaultBioavailability: [Route: Double]
    var defaultAbsorptionRateKa: [Route: Double] // d-¹ (per day)
    
    init(id: UUID = UUID(), 
         commonName: String, 
         classType: Class, 
         ester: String? = nil, 
         halfLifeDays: Double, 
         defaultBioavailability: [Route: Double], 
         defaultAbsorptionRateKa: [Route: Double]) {
        self.id = id
        self.commonName = commonName
        self.classType = classType
        self.ester = ester
        self.halfLifeDays = halfLifeDays
        self.defaultBioavailability = defaultBioavailability
        self.defaultAbsorptionRateKa = defaultAbsorptionRateKa
    }
    
    // Returns the full display name with class and ester, e.g. "Testosterone Enanthate"
    var fullDisplayName: String {
        if let ester = ester {
            return "\(classType.displayName) \(ester)"
        } else {
            return "\(classType.displayName) Suspension"
        }
    }
} 