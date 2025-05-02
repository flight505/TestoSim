import Foundation

struct VialBlend: Identifiable, Codable, Hashable {
    struct Component: Codable, Hashable {
        let compoundID: UUID
        let mgPerML: Double
        
        init(compoundID: UUID, mgPerML: Double) {
            self.compoundID = compoundID
            self.mgPerML = mgPerML
        }
    }
    
    let id: UUID
    var name: String
    var manufacturer: String?
    var description: String?
    var components: [Component]
    
    init(id: UUID = UUID(), 
         name: String, 
         manufacturer: String? = nil, 
         description: String? = nil, 
         components: [Component]) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.description = description
        self.components = components
    }
    
    // Total concentration in mg/mL
    var totalConcentration: Double {
        components.reduce(0) { $0 + $1.mgPerML }
    }
    
    // Returns components with their actual compounds (requires CompoundLibrary lookup)
    func resolvedComponents(using library: CompoundLibrary) -> [(compound: Compound, mgPerML: Double)] {
        return components.compactMap { component in
            guard let compound = library.compound(withID: component.compoundID) else {
                return nil
            }
            return (compound: compound, mgPerML: component.mgPerML)
        }
    }
    
    // Creates a descriptive string representing the blend contents
    func compositionDescription(using library: CompoundLibrary) -> String {
        let resolved = resolvedComponents(using: library)
        if resolved.isEmpty {
            return "Unknown composition"
        }
        
        let parts = resolved.map { "\($0.compound.fullDisplayName) \($0.mgPerML, specifier: "%.0f")mg/mL" }
        return parts.joined(separator: ", ")
    }
} 