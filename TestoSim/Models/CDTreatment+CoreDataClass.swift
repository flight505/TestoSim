import Foundation
import CoreData

@objc(CDTreatment)
public class CDTreatment: NSManagedObject {
    // MARK: - Fetch Requests
    
    /// Create a fetch request to find a treatment by ID
    static func fetchRequestWithID(_ id: UUID) -> NSFetchRequest<CDTreatment> {
        let request = CDTreatment.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }
    // MARK: - Convenience Methods
    
    // Convert from a Treatment struct to Core Data
    static func from(treatment: Treatment, in context: NSManagedObjectContext) -> CDTreatment {
        let cdTreatment = CDTreatment(context: context)
        cdTreatment.id = treatment.id
        cdTreatment.name = treatment.name
        cdTreatment.startDate = treatment.startDate
        cdTreatment.notes = treatment.notes
        cdTreatment.treatmentType = treatment.treatmentType.rawValue
        
        // Handle simple treatment properties
        if treatment.treatmentType == .simple {
            cdTreatment.doseMg = treatment.doseMg ?? 0
            cdTreatment.frequencyDays = treatment.frequencyDays ?? 0
            cdTreatment.selectedRoute = treatment.selectedRoute
            
            if let compoundID = treatment.compoundID {
                cdTreatment.compoundID = compoundID
            }
            
            if let blendID = treatment.blendID {
                cdTreatment.blendID = blendID
            }
        }
        
        // Handle advanced treatment properties
        if treatment.treatmentType == .advanced {
            cdTreatment.totalWeeks = Int32(treatment.totalWeeks ?? 0)
            
            // Create stages
            if let stages = treatment.stages {
                for stage in stages {
                    let cdStage = CDTreatmentStage(context: context)
                    cdStage.id = stage.id
                    cdStage.name = stage.name
                    cdStage.startWeek = Int32(stage.startWeek)
                    cdStage.durationWeeks = Int32(stage.durationWeeks)
                    
                    // Serialize compounds and blends data
                    let encoder = JSONEncoder()
                    if let data = try? encoder.encode(stage.compounds) {
                        cdStage.compoundsData = data
                    }
                    
                    if let data = try? encoder.encode(stage.blends) {
                        cdStage.blendsData = data
                    }
                    
                    cdStage.treatment = cdTreatment
                }
            }
        }
        
        return cdTreatment
    }
    
    // Convert from Core Data to a Treatment struct
    func toTreatment() -> Treatment? {
        guard let id = self.id,
              let name = self.name,
              let startDate = self.startDate,
              let typeString = self.treatmentType,
              let treatmentType = Treatment.TreatmentType(rawValue: typeString) else {
            return nil
        }
        
        let treatment = Treatment(
            id: id,
            name: name, 
            startDate: startDate,
            notes: self.notes,
            treatmentType: treatmentType
        )
        
        var updatedTreatment = treatment
        
        // Handle simple treatment properties
        if treatmentType == .simple {
            updatedTreatment.doseMg = self.doseMg
            updatedTreatment.frequencyDays = self.frequencyDays
            updatedTreatment.selectedRoute = self.selectedRoute
            updatedTreatment.compoundID = self.compoundID
            updatedTreatment.blendID = self.blendID
            
            // Convert blood samples
            if let cdBloodSamples = self.bloodSamples as? Set<CDBloodSample> {
                var bloodSamples: [BloodSample] = []
                for cdSample in cdBloodSamples {
                    let sample = BloodSample(
                        id: cdSample.id ?? UUID(),
                        date: cdSample.date ?? Date(),
                        value: cdSample.value,
                        unit: cdSample.unit ?? "ng/dL"
                    )
                    bloodSamples.append(sample)
                }
                updatedTreatment.bloodSamples = bloodSamples
            }
        }
        
        // Handle advanced treatment properties
        if treatmentType == .advanced {
            updatedTreatment.totalWeeks = Int(self.totalWeeks)
            
            // Convert stages
            if let cdStages = self.stages as? Set<CDTreatmentStage> {
                var stages: [Treatment.Stage] = []
                
                for cdStage in cdStages {
                    if let id = cdStage.id, let name = cdStage.name {
                        var stage = Treatment.Stage(
                            id: id,
                            name: name,
                            startWeek: Int(cdStage.startWeek),
                            durationWeeks: Int(cdStage.durationWeeks)
                        )
                        
                        // Deserialize compounds data
                        if let compoundsData = cdStage.compoundsData {
                            let decoder = JSONDecoder()
                            if let compounds = try? decoder.decode([Treatment.StageCompound].self, from: compoundsData) {
                                stage.compounds = compounds
                            }
                        }
                        
                        // Deserialize blends data
                        if let blendsData = cdStage.blendsData {
                            let decoder = JSONDecoder()
                            if let blends = try? decoder.decode([Treatment.StageBlend].self, from: blendsData) {
                                stage.blends = blends
                            }
                        }
                        
                        stages.append(stage)
                    }
                }
                
                updatedTreatment.stages = stages
            }
        }
        
        return updatedTreatment
    }
}