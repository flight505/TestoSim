import Foundation
import CoreData

// MARK: - Treatment Extensions

extension Treatment {
    // Create a Treatment from a Core Data CDTreatment
    init?(from cdTreatment: CDTreatment) {
        guard let id = cdTreatment.id,
              let name = cdTreatment.name,
              let startDate = cdTreatment.startDate,
              let typeString = cdTreatment.treatmentType,
              let type = TreatmentType(rawValue: typeString) else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.startDate = startDate
        self.notes = cdTreatment.notes
        self.treatmentType = type
        
        // Extract data based on type
        switch type {
        case .simple:
            self.doseMg = cdTreatment.doseMg
            self.frequencyDays = cdTreatment.frequencyDays
            self.compoundID = cdTreatment.compoundID
            self.blendID = cdTreatment.blendID
            self.selectedRoute = cdTreatment.selectedRoute
            
            // Extract blood samples
            if let cdSamples = cdTreatment.bloodSamples as? Set<CDBloodSample> {
                self.bloodSamples = cdSamples.compactMap { BloodSample(from: $0) }
            } else {
                self.bloodSamples = []
            }
            
            // Set advanced properties to nil
            self.totalWeeks = nil
            self.stages = nil
            
        case .advanced:
            self.totalWeeks = Int(cdTreatment.totalWeeks)
            
            // Extract stages
            if let cdStages = cdTreatment.stages as? Set<CDTreatmentStage> {
                self.stages = cdStages.map { TreatmentStage(from: $0) }
                    .sorted(by: { $0.startWeek < $1.startWeek })
            } else {
                self.stages = []
            }
            
            // Set simple properties to nil
            self.doseMg = nil
            self.frequencyDays = nil
            self.compoundID = nil
            self.blendID = nil
            self.selectedRoute = nil
            self.bloodSamples = nil
        }
    }
    
    // Save/update Treatment to Core Data
    func saveToCD(context: NSManagedObjectContext) -> CDTreatment {
        // Check if treatment already exists
        let fetchRequest: NSFetchRequest<CDTreatment> = CDTreatment.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", self.id as CVarArg)
        
        var cdTreatment: CDTreatment
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingTreatment = results.first {
                cdTreatment = existingTreatment
            } else {
                cdTreatment = CDTreatment(context: context)
                cdTreatment.id = self.id
            }
            
            // Update common properties
            cdTreatment.name = self.name
            cdTreatment.startDate = self.startDate
            cdTreatment.notes = self.notes
            cdTreatment.treatmentType = self.treatmentType.rawValue
            
            // Update type-specific properties
            switch self.treatmentType {
            case .simple:
                cdTreatment.doseMg = self.doseMg ?? 0
                cdTreatment.frequencyDays = self.frequencyDays ?? 0
                cdTreatment.compoundID = self.compoundID
                cdTreatment.blendID = self.blendID
                cdTreatment.selectedRoute = self.selectedRoute
                cdTreatment.totalWeeks = 0 // Not used for simple
                
                // Handle blood samples
                // First, remove all existing samples
                if let existingSamples = cdTreatment.bloodSamples as? Set<CDBloodSample> {
                    for sample in existingSamples {
                        context.delete(sample)
                    }
                }
                
                // Then add all current samples
                if let samples = self.bloodSamples {
                    for sample in samples {
                        let cdSample = sample.saveToCD(context: context)
                        cdTreatment.addToBloodSamples(cdSample)
                    }
                }
                
                // Remove any stages (should be none for simple type)
                if let existingStages = cdTreatment.stages as? Set<CDTreatmentStage> {
                    for stage in existingStages {
                        context.delete(stage)
                    }
                }
                
            case .advanced:
                cdTreatment.totalWeeks = Int32(self.totalWeeks ?? 0)
                cdTreatment.doseMg = 0 // Not used for advanced
                cdTreatment.frequencyDays = 0 // Not used for advanced
                cdTreatment.compoundID = nil
                cdTreatment.blendID = nil
                cdTreatment.selectedRoute = nil
                
                // Remove any blood samples (should be none for advanced type)
                if let existingSamples = cdTreatment.bloodSamples as? Set<CDBloodSample> {
                    for sample in existingSamples {
                        context.delete(sample)
                    }
                }
                
                // Handle stages
                // First, remove all existing stages
                if let existingStages = cdTreatment.stages as? Set<CDTreatmentStage> {
                    for stage in existingStages {
                        context.delete(stage)
                    }
                }
                
                // Then add all current stages
                if let stages = self.stages {
                    for stage in stages {
                        let cdStage = stage.saveToCD(context: context)
                        cdTreatment.addToStages(cdStage)
                    }
                }
            }
            
        } catch {
            print("Error saving Treatment to CoreData: \(error)")
            cdTreatment = CDTreatment(context: context)
            cdTreatment.id = self.id
            cdTreatment.name = self.name
        }
        
        return cdTreatment
    }
}

// MARK: - TreatmentStage Extensions

extension TreatmentStage {
    // Create a TreatmentStage from a Core Data CDTreatmentStage
    init(from cdStage: CDTreatmentStage) {
        self.id = cdStage.id ?? UUID()
        self.name = cdStage.name ?? "Unnamed Stage"
        self.startWeek = Int(cdStage.startWeek)
        self.durationWeeks = Int(cdStage.durationWeeks)
        
        // Parse compounds and blends from JSON
        if let compoundsData = cdStage.compoundsData, 
           let compoundsArray = try? JSONDecoder().decode([CompoundStageItem].self, from: compoundsData) {
            self.compounds = compoundsArray
        } else {
            self.compounds = []
        }
        
        if let blendsData = cdStage.blendsData,
           let blendsArray = try? JSONDecoder().decode([BlendStageItem].self, from: blendsData) {
            self.blends = blendsArray
        } else {
            self.blends = []
        }
    }
    
    // Save/update TreatmentStage to Core Data
    func saveToCD(context: NSManagedObjectContext) -> CDTreatmentStage {
        // Check if stage already exists
        let fetchRequest: NSFetchRequest<CDTreatmentStage> = CDTreatmentStage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", self.id as CVarArg)
        
        var cdStage: CDTreatmentStage
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingStage = results.first {
                cdStage = existingStage
            } else {
                cdStage = CDTreatmentStage(context: context)
                cdStage.id = self.id
            }
            
            // Update properties
            cdStage.name = self.name
            cdStage.startWeek = Int32(self.startWeek)
            cdStage.durationWeeks = Int32(self.durationWeeks)
            
            // Save compounds and blends as JSON
            do {
                cdStage.compoundsData = try JSONEncoder().encode(self.compounds)
                cdStage.blendsData = try JSONEncoder().encode(self.blends)
            } catch {
                print("Error encoding stage items: \(error)")
            }
            
        } catch {
            print("Error saving TreatmentStage to CoreData: \(error)")
            cdStage = CDTreatmentStage(context: context)
            cdStage.id = self.id
        }
        
        return cdStage
    }
}

// MARK: - UserProfile Extension for Treatments

extension UserProfile {
    // Add a new property to store treatments
    var treatments: [Treatment] {
        get {
            // Combine the legacy protocols (as simple treatments) and cycles (as advanced treatments)
            let simpleTreatments = protocols.map { Treatment(from: $0) }
            // Cycles would be handled separately in the data model
            return simpleTreatments
        }
        set {
            // Extract simple treatments back into protocols
            protocols = newValue
                .filter { $0.treatmentType == .simple }
                .compactMap { $0.toLegacyProtocol() }
            
            // Cycles would be handled separately in the data model
        }
    }
}