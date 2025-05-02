import Foundation

struct TestosteroneEster: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let halfLifeDays: Double
    
    init(id: UUID = UUID(), name: String, halfLifeDays: Double) {
        self.id = id
        self.name = name
        self.halfLifeDays = halfLifeDays
    }
    
    static let propionate = TestosteroneEster(name: "Propionate", halfLifeDays: 0.8)
    static let enanthate = TestosteroneEster(name: "Enanthate", halfLifeDays: 4.5)
    static let cypionate = TestosteroneEster(name: "Cypionate", halfLifeDays: 7.0)
    static let undecanoate = TestosteroneEster(name: "Undecanoate", halfLifeDays: 30.0)
    
    static let all: [TestosteroneEster] = [.propionate, .enanthate, .cypionate, .undecanoate]
} 