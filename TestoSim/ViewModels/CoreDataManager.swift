import Foundation
import CoreData
import CloudKit

class CoreDataManager {
    static let shared = CoreDataManager()
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        // Set up the CloudKit container
        let cloudKitContainerID = "iCloud.flight505.TestoSim"
        
        // Check if iCloud sync is enabled via UserDefaults
        let usesICloudSync = UserDefaults.standard.bool(forKey: "usesICloudSync")
        
        // Use NSPersistentCloudKitContainer if iCloud sync is enabled, otherwise use regular NSPersistentContainer
        let container: NSPersistentContainer
        
        if usesICloudSync {
            container = NSPersistentCloudKitContainer(name: "TestoSim")
            print("Using CloudKit-enabled persistent container")
            
            // Configure CloudKit integration
            if let cloudStoreDescription = container.persistentStoreDescriptions.first {
                // Enable CloudKit
                cloudStoreDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerID)
                
                // Enable history tracking (required for CloudKit sync)
                cloudStoreDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                cloudStoreDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            }
        } else {
            container = NSPersistentContainer(name: "TestoSim")
            print("Using standard persistent container (CloudKit disabled)")
        }
        
        // Configure for progressive migration
        if let storeDescription = container.persistentStoreDescriptions.first {
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
            
            // Add migration progress notification
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name.NSPersistentStoreCoordinatorStoresWillChange,
                object: container.persistentStoreCoordinator,
                queue: .main
            ) { notification in
                print("Migration about to start")
                // Post notification to UI if needed
            }
            
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name.NSPersistentStoreCoordinatorStoresDidChange,
                object: container.persistentStoreCoordinator,
                queue: .main
            ) { notification in
                print("Migration completed")
                // Post notification to UI if needed
            }
        }
        
        // Initialize the Core Data stack
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                print("Unresolved error loading persistent stores: \(error), \(error.userInfo)")
                
                // Log CloudKit specific issues if present
                if let cloudError = error.userInfo[NSUnderlyingErrorKey] as? NSError,
                   cloudError.domain == CKErrorDomain {
                    print("CloudKit error: \(cloudError.localizedDescription)")
                }
                
                // Log migration errors specifically
                if error.domain == NSCocoaErrorDomain && 
                   (error.code == NSPersistentStoreIncompatibleVersionHashError ||
                    error.code == NSMigrationError ||
                    error.code == NSMigrationMissingSourceModelError) {
                    print("Migration failed: \(error.localizedDescription)")
                }
            } else {
                print("Successfully loaded persistent store: \(storeDescription)")
                
                // Initialize CloudKit schema if CloudKit is enabled
                if let cloudKitOptions = storeDescription.cloudKitContainerOptions,
                   let cloudKitContainer = container as? NSPersistentCloudKitContainer {
                    do {
                        try cloudKitContainer.initializeCloudKitSchema(options: [.printSchema])
                        print("CloudKit schema initialized successfully")
                    } catch {
                        print("Error initializing CloudKit schema: \(error)")
                    }
                }
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
                print("Context saved successfully")
            } catch {
                let nserror = error as NSError
                print("Unresolved error saving context: \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // MARK: - Background task
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
    
    // MARK: - iCloud Sync Control
    
    func enableCloudSync(_ enable: Bool) {
        let currentSetting = UserDefaults.standard.bool(forKey: "usesICloudSync")
        
        // Only update if the setting has changed
        if currentSetting != enable {
            UserDefaults.standard.set(enable, forKey: "usesICloudSync")
            
            // Notify the user that a restart is required
            let notification = Notification(name: Notification.Name("CloudKitSyncSettingChanged"), 
                                           object: nil, 
                                           userInfo: ["enabled": enable])
            NotificationCenter.default.post(notification)
            
            print("CloudKit sync \(enable ? "enabled" : "disabled") - app restart required for changes to take effect")
        }
    }
    
    func isCloudSyncEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "usesICloudSync")
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
            
            // Create CDInjectionProtocol entries
            for p in profile.protocols {
                let cdProtocol = CDInjectionProtocol(context: context)
                cdProtocol.id = p.id
                cdProtocol.name = p.name
                cdProtocol.doseMg = p.doseMg
                cdProtocol.frequencyDays = p.frequencyDays
                cdProtocol.startDate = p.startDate
                cdProtocol.notes = p.notes
                
                // TODO: The Core Data model needs to be updated to include these properties:
                // - compoundID (UUID)
                // - blendID (UUID)
                // - selectedRoute (String)
                // Once added, uncomment the following lines:
                /*
                cdProtocol.compoundID = p.compoundID
                cdProtocol.blendID = p.blendID
                cdProtocol.selectedRoute = p.selectedRoute
                */
                
                // For now, store this information in the notes field
                var extendedInfo = ""
                if let compoundID = p.compoundID {
                    extendedInfo += "CompoundID: \(compoundID.uuidString)\n"
                }
                if let blendID = p.blendID {
                    extendedInfo += "BlendID: \(blendID.uuidString)\n"
                }
                if let route = p.selectedRoute {
                    extendedInfo += "Route: \(route)\n"
                }
                
                if !extendedInfo.isEmpty {
                    if cdProtocol.notes != nil {
                        cdProtocol.notes = cdProtocol.notes! + "\n\n---EXTENDED_DATA---\n" + extendedInfo
                    } else {
                        cdProtocol.notes = "---EXTENDED_DATA---\n" + extendedInfo
                    }
                }
                
                // Create blood samples
                for sample in p.bloodSamples {
                    let cdSample = CDBloodSample(context: context)
                    cdSample.id = sample.id
                    cdSample.date = sample.date
                    cdSample.value = sample.value
                    cdSample.unit = sample.unit
                    
                    cdProtocol.addToBloodSamples(cdSample)
                }
                
                cdProfile.addToProtocols(cdProtocol)
            }
            
            // Save to Core Data
            try context.save()
            
            // Mark as migrated
            UserDefaults.standard.set(true, forKey: "migrated")
            print("Successfully migrated user profile from JSON to Core Data")
            
        } catch {
            print("Error migrating from JSON: \(error)")
        }
    }
} 