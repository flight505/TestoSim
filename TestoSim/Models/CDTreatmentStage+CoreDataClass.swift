import Foundation
import CoreData

@objc(CDTreatmentStage)
public class CDTreatmentStage: NSManagedObject {
    // MARK: - Utility Methods
    
    // Deserialize stored compounds data
    func getCompounds() -> [Treatment.StageCompound]? {
        guard let compoundsData = self.compoundsData else { return nil }
        
        let decoder = JSONDecoder()
        return try? decoder.decode([Treatment.StageCompound].self, from: compoundsData)
    }
    
    // Set and serialize compounds data
    func setCompounds(_ compounds: [Treatment.StageCompound]) {
        let encoder = JSONEncoder()
        self.compoundsData = try? encoder.encode(compounds)
    }
    
    // Deserialize stored blends data
    func getBlends() -> [Treatment.StageBlend]? {
        guard let blendsData = self.blendsData else { return nil }
        
        let decoder = JSONDecoder()
        return try? decoder.decode([Treatment.StageBlend].self, from: blendsData)
    }
    
    // Set and serialize blends data
    func setBlends(_ blends: [Treatment.StageBlend]) {
        let encoder = JSONEncoder()
        self.blendsData = try? encoder.encode(blends)
    }
}