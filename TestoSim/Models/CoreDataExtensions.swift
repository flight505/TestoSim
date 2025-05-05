import Foundation
import CoreData

// MARK: - UserProfile Extensions

extension UserProfile {
    // Create a UserProfile from a Core Data CDUserProfile
    init(from cdProfile: CDUserProfile) {
        self.id = cdProfile.id ?? UUID()
        self.name = cdProfile.name ?? "My Profile"
        self.unit = cdProfile.unit ?? "ng/dL"
        self.calibrationFactor = cdProfile.calibrationFactor
        self.dateOfBirth = cdProfile.dateOfBirth
        self.heightCm = cdProfile.heightCm
        self.weight = cdProfile.weight
        
        // Convert string biologicalSex to enum
        if let sexString = cdProfile.biologicalSex,
           let sex = BiologicalSex(rawValue: sexString) {
            self.biologicalSex = sex
        } else {
            self.biologicalSex = .male
        }
        
        self.usesICloudSync = cdProfile.usesICloudSync
        self.useTwoCompartmentModel = cdProfile.useTwoCompartmentModel
        
        // Extract protocols
        if let cdProtocols = cdProfile.protocols as? Set<CDInjectionProtocol> {
            self.protocols = cdProtocols.compactMap { InjectionProtocol(from: $0) }
        } else {
            self.protocols = []
        }
    }
    
    // Save/update UserProfile to Core Data
    func saveToCD(context: NSManagedObjectContext) -> CDUserProfile {
        // Check if profile already exists
        let fetchRequest: NSFetchRequest<CDUserProfile> = CDUserProfile.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", self.id as CVarArg)
        
        var cdProfile: CDUserProfile
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingProfile = results.first {
                cdProfile = existingProfile
            } else {
                cdProfile = CDUserProfile(context: context)
                cdProfile.id = self.id
            }
            
            // Update properties
            cdProfile.name = self.name
            cdProfile.unit = self.unit
            cdProfile.calibrationFactor = self.calibrationFactor
            cdProfile.dateOfBirth = self.dateOfBirth
            cdProfile.heightCm = self.heightCm ?? 0
            cdProfile.weight = self.weight ?? 0
            cdProfile.biologicalSex = self.biologicalSex.rawValue
            cdProfile.usesICloudSync = self.usesICloudSync
            cdProfile.useTwoCompartmentModel = self.useTwoCompartmentModel
            
            // Handle protocols (this will be more complex due to relationships)
            // We'd need to compare existing protocols with new ones
            // For now, we'll just replace them all
            
            // First, remove all existing protocols
            if let existingProtocols = cdProfile.protocols as? Set<CDInjectionProtocol> {
                for p in existingProtocols {
                    context.delete(p)
                }
            }
            
            // Then add all current protocols
            for p in self.protocols {
                let cdProtocol = p.saveToCD(context: context)
                cdProfile.addToProtocols(cdProtocol)
            }
            
            // Save the context
            try context.save()
            
        } catch {
            print("Error saving UserProfile to CoreData: \(error)")
            cdProfile = CDUserProfile(context: context)
            cdProfile.id = self.id
            cdProfile.name = self.name
        }
        
        return cdProfile
    }
}

// MARK: - InjectionProtocol Extensions

extension InjectionProtocol {
    // Create an InjectionProtocol from a Core Data CDInjectionProtocol
    init?(from cdProtocol: CDInjectionProtocol) {
        guard let id = cdProtocol.id,
              let name = cdProtocol.name,
              let startDate = cdProtocol.startDate else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.doseMg = cdProtocol.doseMg
        self.frequencyDays = cdProtocol.frequencyDays
        self.startDate = startDate
        self.notes = cdProtocol.notes
        
        // Try to extract extended properties from notes
        if let notes = cdProtocol.notes, notes.contains("---EXTENDED_DATA---") {
            if let range = notes.range(of: "---EXTENDED_DATA---") {
                let startIndex = range.upperBound
                let jsonString = String(notes[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !jsonString.isEmpty, let jsonData = jsonString.data(using: .utf8) {
                    do {
                        if let extendedData = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String] {
                            // Extract properties
                            if let protocolTypeStr = extendedData["protocolType"], 
                               let _ = ProtocolType(rawValue: protocolTypeStr) {
                                // Protocol type will be set via computed property
                            }
                            
                            if let compoundIDStr = extendedData["compoundID"], !compoundIDStr.isEmpty {
                                self.compoundID = UUID(uuidString: compoundIDStr)
                            }
                            
                            if let blendIDStr = extendedData["blendID"], !blendIDStr.isEmpty {
                                self.blendID = UUID(uuidString: blendIDStr)
                            }
                            
                            if let routeStr = extendedData["selectedRoute"], !routeStr.isEmpty {
                                self.selectedRoute = routeStr
                            }
                        }
                    } catch {
                        print("Error parsing extended data JSON: \(error)")
                    }
                }
            }
        }
        
        // Extract blood samples
        if let cdSamples = cdProtocol.bloodSamples as? Set<CDBloodSample> {
            self.bloodSamples = cdSamples.compactMap { BloodSample(from: $0) }
        } else {
            self.bloodSamples = []
        }
    }
    
    // Save/update InjectionProtocol to Core Data
    func saveToCD(context: NSManagedObjectContext) -> CDInjectionProtocol {
        // Check if protocol already exists
        let fetchRequest: NSFetchRequest<CDInjectionProtocol> = CDInjectionProtocol.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", self.id as CVarArg)
        
        var cdProtocol: CDInjectionProtocol
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingProtocol = results.first {
                cdProtocol = existingProtocol
            } else {
                cdProtocol = CDInjectionProtocol(context: context)
                cdProtocol.id = self.id
            }
            
            // Update properties
            cdProtocol.name = self.name
            cdProtocol.doseMg = self.doseMg
            cdProtocol.frequencyDays = self.frequencyDays
            cdProtocol.startDate = self.startDate
            
            // Store extended properties in notes field as JSON
            var userNotes = self.notes ?? ""
            
            // Remove existing extended data section if present
            if let range = userNotes.range(of: "---EXTENDED_DATA---") {
                userNotes = String(userNotes[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Create the extended data dictionary
            let extendedData: [String: String] = [
                "protocolType": self.protocolType.rawValue,
                "compoundID": self.compoundID?.uuidString ?? "",
                "blendID": self.blendID?.uuidString ?? "",
                "selectedRoute": self.selectedRoute ?? ""
            ]
            
            if let extendedJSON = try? JSONEncoder().encode(extendedData),
               let jsonString = String(data: extendedJSON, encoding: .utf8) {
                // Append to notes
                if !userNotes.isEmpty {
                    cdProtocol.notes = userNotes + "\n\n---EXTENDED_DATA---\n" + jsonString
                } else {
                    cdProtocol.notes = "---EXTENDED_DATA---\n" + jsonString
                }
            } else {
                cdProtocol.notes = userNotes
            }
            
            // Handle blood samples
            // First, remove all existing samples
            if let existingSamples = cdProtocol.bloodSamples as? Set<CDBloodSample> {
                for sample in existingSamples {
                    context.delete(sample)
                }
            }
            
            // Then add all current samples
            for sample in self.bloodSamples {
                let cdSample = sample.saveToCD(context: context)
                cdProtocol.addToBloodSamples(cdSample)
            }
            
        } catch {
            print("Error saving InjectionProtocol to CoreData: \(error)")
            cdProtocol = CDInjectionProtocol(context: context)
            cdProtocol.id = self.id
            cdProtocol.name = self.name
        }
        
        return cdProtocol
    }
}

// MARK: - BloodSample Extensions

extension BloodSample {
    // Create a BloodSample from a Core Data CDBloodSample
    init?(from cdSample: CDBloodSample) {
        guard let id = cdSample.id,
              let date = cdSample.date,
              let unit = cdSample.unit else {
            return nil
        }
        
        self.id = id
        self.date = date
        self.value = cdSample.value
        self.unit = unit
    }
    
    // Save/update BloodSample to Core Data
    func saveToCD(context: NSManagedObjectContext) -> CDBloodSample {
        // Check if sample already exists
        let fetchRequest: NSFetchRequest<CDBloodSample> = CDBloodSample.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", self.id as CVarArg)
        
        var cdSample: CDBloodSample
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingSample = results.first {
                cdSample = existingSample
            } else {
                cdSample = CDBloodSample(context: context)
                cdSample.id = self.id
            }
            
            // Update properties
            cdSample.date = self.date
            cdSample.value = self.value
            cdSample.unit = self.unit
            
        } catch {
            print("Error saving BloodSample to CoreData: \(error)")
            cdSample = CDBloodSample(context: context)
            cdSample.id = self.id
        }
        
        return cdSample
    }
}

// MARK: - Compound Extensions

extension Compound {
    // Create a Compound from a Core Data CDCompound
    init?(from cdCompound: CDCompound) {
        guard let id = cdCompound.id,
              let commonName = cdCompound.commonName,
              let classTypeString = cdCompound.classType,
              let classType = Class(rawValue: classTypeString) else {
            return nil
        }
        
        // Default values for dictionaries if serialized data not available
        let bioavailability: [Route: Double] = [.intramuscular: 1.0]
        let absorptionRates: [Route: Double] = [.intramuscular: 0.7]
        
        // Deserialize the dictionary data if available
        if cdCompound.routeBioavailabilityData != nil {
            // We would implement proper deserialization here
            // For now, using default values
        }
        
        if cdCompound.routeKaData != nil {
            // We would implement proper deserialization here
            // For now, using default values
        }
        
        self.id = id
        self.commonName = commonName
        self.classType = classType
        self.ester = cdCompound.ester
        self.halfLifeDays = cdCompound.halfLifeDays
        self.defaultBioavailability = bioavailability
        self.defaultAbsorptionRateKa = absorptionRates
    }
    
    // Save/update Compound to Core Data
    func saveToCD(context: NSManagedObjectContext) -> CDCompound {
        // Check if compound already exists
        let fetchRequest: NSFetchRequest<CDCompound> = CDCompound.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", self.id as CVarArg)
        
        var cdCompound: CDCompound
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingCompound = results.first {
                cdCompound = existingCompound
            } else {
                cdCompound = CDCompound(context: context)
                cdCompound.id = self.id
            }
            
            // Update properties
            cdCompound.commonName = self.commonName
            cdCompound.classType = self.classType.rawValue
            cdCompound.ester = self.ester
            cdCompound.halfLifeDays = self.halfLifeDays
            
            // Serialize the dictionaries
            // This is just a placeholder - we would need proper serialization
            // cdCompound.routeBioavailabilityData = serializeDictionary(self.defaultBioavailability)
            // cdCompound.routeKaData = serializeDictionary(self.defaultAbsorptionRateKa)
            
        } catch {
            print("Error saving Compound to CoreData: \(error)")
            cdCompound = CDCompound(context: context)
            cdCompound.id = self.id
        }
        
        return cdCompound
    }
}

// MARK: - VialBlend Extensions

extension VialBlend {
    // Create a VialBlend from a Core Data CDVialBlend
    init?(from cdBlend: CDVialBlend) {
        guard let id = cdBlend.id,
              let name = cdBlend.name else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.manufacturer = cdBlend.manufacturer
        self.description = cdBlend.blendDescription
        
        // Extract components
        if let cdComponents = cdBlend.components as? Set<CDVialComponent> {
            self.components = cdComponents.compactMap { Component(from: $0) }
        } else {
            self.components = []
        }
    }
    
    // Save/update VialBlend to Core Data
    func saveToCD(context: NSManagedObjectContext) -> CDVialBlend {
        // Check if blend already exists
        let fetchRequest: NSFetchRequest<CDVialBlend> = CDVialBlend.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", self.id as CVarArg)
        
        var cdBlend: CDVialBlend
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingBlend = results.first {
                cdBlend = existingBlend
            } else {
                cdBlend = CDVialBlend(context: context)
                cdBlend.id = self.id
            }
            
            // Update properties
            cdBlend.name = self.name
            cdBlend.manufacturer = self.manufacturer
            cdBlend.blendDescription = self.description
            
            // Handle components
            // First, remove all existing components
            if let existingComponents = cdBlend.components as? Set<CDVialComponent> {
                for component in existingComponents {
                    context.delete(component)
                }
            }
            
            // Then add all current components
            for component in self.components {
                let cdComponent = CDVialComponent(context: context)
                cdComponent.mgPerML = component.mgPerML
                
                // Find the compound
                let compoundFetchRequest: NSFetchRequest<CDCompound> = CDCompound.fetchRequest()
                compoundFetchRequest.predicate = NSPredicate(format: "id == %@", component.compoundID as CVarArg)
                
                let compoundResults = try context.fetch(compoundFetchRequest)
                if let cdCompound = compoundResults.first {
                    cdComponent.compound = cdCompound
                } else {
                    // Compound not found - this is an error condition
                    print("Error: Compound with ID \(component.compoundID) not found in Core Data")
                    continue
                }
                
                cdBlend.addToComponents(cdComponent)
            }
            
        } catch {
            print("Error saving VialBlend to CoreData: \(error)")
            cdBlend = CDVialBlend(context: context)
            cdBlend.id = self.id
        }
        
        return cdBlend
    }
}

// MARK: - VialBlend.Component Extensions

extension VialBlend.Component {
    init?(from cdComponent: CDVialComponent) {
        guard let compound = cdComponent.compound,
              let compoundID = compound.id else {
            return nil
        }
        
        self.compoundID = compoundID
        self.mgPerML = cdComponent.mgPerML
    }
}

// MARK: - Cycle Extensions

extension Cycle {
    init(from cdCycle: CDCycle, context: NSManagedObjectContext) {
        self.id = cdCycle.id ?? UUID()
        self.name = cdCycle.name ?? "Unnamed Cycle"
        self.startDate = cdCycle.startDate ?? Date()
        self.totalWeeks = Int(cdCycle.totalWeeks)
        self.notes = cdCycle.notes
        
        // Load stages if they exist
        if let cdStages = cdCycle.stages as? Set<CDCycleStage>, !cdStages.isEmpty {
            self.stages = cdStages.map { CycleStage(from: $0) }.sorted { $0.startWeek < $1.startWeek }
        }
    }
    
    func save(to context: NSManagedObjectContext) -> CDCycle {
        let cdCycle: CDCycle
        
        // Try to find existing entity first
        let fetchRequest: NSFetchRequest<CDCycle> = CDCycle.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", self.id as CVarArg)
        
        if let existingCycle = try? context.fetch(fetchRequest).first {
            cdCycle = existingCycle
        } else {
            cdCycle = CDCycle(context: context)
            cdCycle.id = self.id
        }
        
        // Update properties
        cdCycle.name = self.name
        cdCycle.startDate = self.startDate
        cdCycle.totalWeeks = Int32(self.totalWeeks)
        cdCycle.notes = self.notes
        
        // Remove old stages
        if let existingStages = cdCycle.stages as? Set<CDCycleStage> {
            for stage in existingStages {
                context.delete(stage)
            }
        }
        
        // Add new stages
        for stage in self.stages {
            let cdStage = stage.save(to: context)
            cdStage.cycle = cdCycle
        }
        
        return cdCycle
    }
}

extension CycleStage {
    init(from cdStage: CDCycleStage) {
        self.id = cdStage.id ?? UUID()
        self.name = cdStage.name ?? "Unnamed Stage"
        self.startWeek = Int(cdStage.startWeek)
        self.durationWeeks = Int(cdStage.durationWeeks)
        
        // Parse compounds and blends from JSON
        if let compoundsData = cdStage.compoundsData, 
           let compoundsArray = try? JSONDecoder().decode([CompoundStageItem].self, from: compoundsData) {
            self.compounds = compoundsArray
        }
        
        if let blendsData = cdStage.blendsData,
           let blendsArray = try? JSONDecoder().decode([BlendStageItem].self, from: blendsData) {
            self.blends = blendsArray
        }
    }
    
    func save(to context: NSManagedObjectContext) -> CDCycleStage {
        let cdStage: CDCycleStage
        
        // Try to find existing entity first
        let fetchRequest: NSFetchRequest<CDCycleStage> = CDCycleStage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", self.id as CVarArg)
        
        if let existingStage = try? context.fetch(fetchRequest).first {
            cdStage = existingStage
        } else {
            cdStage = CDCycleStage(context: context)
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
        
        return cdStage
    }
} 