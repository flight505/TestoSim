import Foundation
import CoreData
import CloudKit

class CoreDataManager {
    static let shared = CoreDataManager()
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "TestoSim")
        
        // Configure the CloudKit integration
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.yourcompany.TestoSim"
        )
        
        // Set sync policy to manual - allows user to toggle sync
        description.cloudKitContainerOptions?.databaseScope = .private
        
        // Initialize the Core Data stack
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        // Enable automatic merging of changes from the parent context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Core Data operations
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // MARK: - Background task
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
    
    // MARK: - iCloud Sync Control
    
    func enableCloudSync(_ enable: Bool) {
        guard let description = persistentContainer.persistentStoreDescriptions.first,
              let options = description.cloudKitContainerOptions else {
            return
        }
        
        if enable {
            // Set up CloudKit sync
            options.databaseScope = .private
        } else {
            // Disable CloudKit sync
            description.cloudKitContainerOptions = nil
        }
        
        // Update the persistent stores - this would ideally be done when rebuilding the stack
        // For simplicity, we'll just update the flag for now
        UserDefaults.standard.set(enable, forKey: "usesICloudSync")
    }
    
    // MARK: - Migration
    
    func migrateUserProfileFromJSON() {
        // Check if we've already migrated
        if UserDefaults.standard.bool(forKey: "migrated") {
            return
        }
        
        // Get the profile data from UserDefaults
        guard let profileData = UserDefaults.standard.data(forKey: "userProfileData") else {
            // No data to migrate
            UserDefaults.standard.set(true, forKey: "migrated")
            return
        }
        
        let decoder = JSONDecoder()
        
        do {
            // Decode the JSON data into our model struct
            let profile = try decoder.decode(UserProfile.self, from: profileData)
            
            // Create Core Data versions of the entities
            let context = persistentContainer.viewContext
            
            // Create CDUserProfile
            let cdProfile = CDUserProfile(context: context)
            cdProfile.id = profile.id
            cdProfile.name = profile.name
            cdProfile.unit = profile.unit
            cdProfile.calibrationFactor = profile.calibrationFactor
            cdProfile.dateOfBirth = profile.dateOfBirth
            cdProfile.heightCm = profile.heightCm ?? 0
            cdProfile.weight = profile.weight ?? 0
            cdProfile.biologicalSex = profile.biologicalSex.rawValue
            cdProfile.usesICloudSync = profile.usesICloudSync
            
            // Create any referenced compounds from the library first
            // (Typically we'd load these from CompoundLibrary)
            var compoundMap = [UUID: CDCompound]()
            
            // Create CDInjectionProtocol entries
            for p in profile.protocols {
                let cdProtocol = CDInjectionProtocol(context: context)
                cdProtocol.id = p.id
                cdProtocol.name = p.name
                
                // Find or create the ester compound
                let esterID = p.ester.id
                let cdEster: CDCompound
                if let existingEster = compoundMap[esterID] {
                    cdEster = existingEster
                } else {
                    // Create a new compound
                    cdEster = CDCompound(context: context)
                    cdEster.id = esterID
                    cdEster.commonName = p.ester.name
                    cdEster.halfLifeDays = p.ester.halfLifeDays
                    cdEster.classType = "testosterone" // Default during migration
                    
                    // We'd need to handle the dictionaries by serializing them, omitted for brevity
                    compoundMap[esterID] = cdEster
                }
                
                cdProtocol.ester = cdEster
                cdProtocol.doseMg = p.doseMg
                cdProtocol.frequencyDays = p.frequencyDays
                cdProtocol.startDate = p.startDate
                cdProtocol.notes = p.notes
                
                // Add protocol to profile
                cdProfile.addToProtocols(cdProtocol)
                
                // Create CDBloodSample entries
                for sample in p.bloodSamples {
                    let cdSample = CDBloodSample(context: context)
                    cdSample.id = sample.id
                    cdSample.date = sample.date
                    cdSample.value = sample.value
                    cdSample.unit = sample.unit
                    
                    // Add sample to protocol
                    cdProtocol.addToBloodSamples(cdSample)
                }
            }
            
            // Save the context
            try context.save()
            
            // Mark as migrated
            UserDefaults.standard.set(true, forKey: "migrated")
            
        } catch {
            print("Failed to migrate data: \(error)")
        }
    }
} 