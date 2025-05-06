import Foundation
import SwiftUI
import CoreData // Make sure CoreData is imported

@MainActor
class AppDataStore: ObservableObject {
    // MARK: - Published Properties
    @Published var profile: UserProfile
    @Published var simulationData: [DataPoint] = []
    @Published var selectedProtocolID: UUID?
    @Published var isPresentingProtocolForm = false
    @Published var protocolToEdit: InjectionProtocol?
    @Published var compoundLibrary = CompoundLibrary()

    // Cycle management
    @Published var cycles: [Cycle] = []
    @Published var selectedCycleID: UUID?
    @Published var isPresentingCycleForm = false // Used for presenting cycle creation form
    @Published var cycleToEdit: Cycle?          // Used for editing existing cycles
    @Published var isCycleSimulationActive = false
    @Published var cycleSimulationData: [DataPoint] = []

    // MARK: - Private Properties
    private static let coreDataManager = CoreDataManager.shared
    private let coreDataManager = CoreDataManager.shared
    private let notificationManager = NotificationManager.shared
    // PKModel instance - always use two-compartment model as per latest decision
    private let pkModel = PKModel(useTwoCompartmentModel: true)

    // MARK: - Constants
    let simulationDurationDays: Double = 90.0 // Default simulation length

    // MARK: - Computed Properties (Removed simulationEndDate as it's calculated dynamically now)

    // MARK: - Initialization
    init() {
        // Initialize profile with a default empty profile first
        self.profile = UserProfile()

        // Check migration status and load data accordingly
        if UserDefaults.standard.bool(forKey: "migrated") {
            // Load profile from Core Data
            if let loadedProfile = AppDataStore.loadProfileFromCoreData() {
                self.profile = loadedProfile
            } else {
                // If loading fails after migration, create default and save
                self.profile = AppDataStore.createDefaultProfile()
                let context = coreDataManager.persistentContainer.viewContext
                _ = self.profile.saveToCD(context: context)
                do {
                    try context.save()
                } catch {
                    print("Error saving default profile to Core Data after failed load: \(error)")
                }
            }
            // Load cycles from Core Data if migrated
            loadCyclesFromCoreData()
        } else {
            // Not migrated yet, try loading from UserDefaults (old method)
            if let savedData = UserDefaults.standard.data(forKey: "userProfileData"),
               let decodedProfile = try? JSONDecoder().decode(UserProfile.self, from: savedData) {
                self.profile = decodedProfile
                // Trigger migration to Core Data
                coreDataManager.migrateUserProfileFromJSON() // This saves the migrated data
                UserDefaults.standard.set(true, forKey: "migrated") // Mark as migrated
                print("Successfully migrated profile from UserDefaults to Core Data.")
            } else {
                // No old data and not migrated: Create default profile and save to Core Data
                self.profile = AppDataStore.createDefaultProfile()
                let context = coreDataManager.persistentContainer.viewContext
                _ = self.profile.saveToCD(context: context)
                do {
                    try context.save()
                } catch {
                    print("Error saving initial default profile to Core Data: \(error)")
                }
                UserDefaults.standard.set(true, forKey: "migrated") // Mark as migrated even if creating default
            }
        }

        // Set initial selected protocol if any exist
        if !profile.protocols.isEmpty {
             // Ensure the selected protocol ID actually exists in the loaded profile
             if let firstValidProtocolID = profile.protocols.first?.id {
                  selectedProtocolID = firstValidProtocolID
             }
        } else {
             selectedProtocolID = nil // Explicitly nil if no protocols
        }


        // Generate initial simulation data for the selected protocol (if any)
        recalcSimulation() // This will handle the case where selectedProtocolID is nil

        // Schedule notifications for all protocols if enabled
        if notificationManager.notificationsEnabled {
            Task {
                await scheduleAllNotifications()
            }
        }
    }

    // MARK: - Helper: Create PK Model
    // Ensures the PK Model is created consistently with app settings
    private func createPKModel() -> PKModel {
        // Always use two-compartment model with endogenous production included
        return PKModel(useTwoCompartmentModel: true, includeEndogenousProduction: true)
    }

    // MARK: - Helper: Generate Simulation Dates
    // Generates an array of Dates for simulation points
    private func generateSimulationDates(startDate: Date, endDate: Date, interval: Double) -> [Date] {
        guard startDate <= endDate, interval > 0 else { return [] } // Basic validation

        var dates: [Date] = []
        var currentDate = startDate
        let intervalSeconds = interval * 24 * 3600 // Convert days to seconds

        while currentDate <= endDate {
            dates.append(currentDate)
            // Ensure adding interval doesn't cause infinite loop with very small intervals near precision limits
            if let nextDate = Calendar.current.date(byAdding: .second, value: Int(intervalSeconds.rounded()), to: currentDate), nextDate > currentDate {
                currentDate = nextDate
            } else {
                // Fallback or break if interval is too small or date calculation fails
                currentDate = currentDate.addingTimeInterval(intervalSeconds)
                if currentDate <= dates.last ?? startDate { // Prevent infinite loop
                    print("Warning: Simulation date interval too small or calculation failed. Breaking loop.")
                    break
                }
            }
            // Safety break
            if dates.count > 5000 { // Limit number of points to prevent excessive calculation
                print("Warning: Simulation date generation exceeded 5000 points. Breaking loop.")
                break
            }
        }
        // Ensure the end date is included if it wasn't hit exactly by the stride
        if let lastDate = dates.last, lastDate < endDate {
            dates.append(endDate)
        }
        return dates
    }
    
    // MARK: - Helper: Find Legacy Compound (Temporary Fix)
    // Attempts to find a matching compound based on legacy notes/name
    private func findLegacyCompound(for injectionProtocol: InjectionProtocol) -> Compound? {
         let esterNames = ["propionate", "phenylpropionate", "isocaproate", "enanthate",
                           "cypionate", "decanoate", "undecanoate"]
         let notes = injectionProtocol.notes ?? ""
         let name = injectionProtocol.name

         // Prioritize finding ester name in the dedicated field within notes if available
         var foundEsterName: String? = nil
         if let notesRange = notes.range(of: "---EXTENDED_DATA---") {
             let jsonString = String(notes[notesRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
             if let jsonData = jsonString.data(using: .utf8),
                let extendedData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] {
                 // Check if compoundID exists and find compound directly
                 if let compoundIDStr = extendedData["compoundID"], let uuid = UUID(uuidString: compoundIDStr) {
                    if let directCompound = compoundLibrary.compound(withID: uuid) {
                         print("Legacy Fix: Found compound via ID in extended data.")
                         return directCompound
                    }
                 }
                 // Otherwise, continue searching by name/notes
             }
         }

         // If not found via ID, search by name/notes string matching
         foundEsterName = esterNames.first { ester in
             name.lowercased().contains(ester) || notes.lowercased().contains(ester)
         }

         if let esterName = foundEsterName {
             let matchingCompound = compoundLibrary.compounds.first {
                 $0.classType == .testosterone && $0.ester?.lowercased() == esterName.lowercased()
             }
             if matchingCompound != nil { print("Legacy Fix: Found compound via name/notes string matching.") }
             return matchingCompound
         }
         print("Legacy Fix: Could not find matching compound for protocol '\(name)'")
         return nil
     }


    // MARK: - Core Data Loading/Saving
    private static func loadProfileFromCoreData() -> UserProfile? {
        let context = coreDataManager.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<CDUserProfile> = CDUserProfile.fetchRequest()
        do {
            let results = try context.fetch(fetchRequest)
            if let cdProfile = results.first {
                print("Profile loaded successfully from Core Data.")
                return UserProfile(from: cdProfile)
            } else {
                print("No profile found in Core Data.")
            }
        } catch {
            print("Error fetching profile from Core Data: \(error)")
        }
        return nil
    }

    func saveProfile() {
        // Always save to Core Data now
        let context = coreDataManager.persistentContainer.viewContext
        _ = profile.saveToCD(context: context) // This handles create/update
        // Note: The actual context save is handled by CoreDataManager.saveContext()
        // which might be called elsewhere (e.g., on app background) or explicitly if needed immediately.
        // For robustness, you might call it here too, but be mindful of performance if called frequently.
        // coreDataManager.saveContext() // Uncomment if immediate save is desired after every profile change
        print("Profile prepared for saving to Core Data.")
    }

    // MARK: - Default Profile Creation
    private static func createDefaultProfile() -> UserProfile {
        print("Creating default profile.")
        var profile = UserProfile()
        // Set up a complete test profile with realistic user data
        profile.name = "Test User"
        profile.unit = "ng/dL"
        profile.calibrationFactor = 1.0
        profile.dateOfBirth = Calendar.current.date(byAdding: .year, value: -35, to: Date())!
        profile.heightCm = 175.0 // cm
        profile.weight = 85.0 // kg
        profile.biologicalSex = .male
        profile.usesICloudSync = false

        // Add a variety of test protocols with compounds
        let compoundLibrary = CompoundLibrary() // Use a local instance for default creation

        // 1. Standard TRT protocol (cypionate)
        var weeklyProtocol = InjectionProtocol(
            name: "Weekly Cypionate",
            doseMg: 100.0,
            frequencyDays: 7.0,
            startDate: Calendar.current.date(byAdding: .day, value: -60, to: Date())!,
            notes: "Standard TRT protocol with weekly injections"
        )
        if let cypionate = compoundLibrary.compounds.first(where: { $0.classType == .testosterone && $0.ester?.lowercased() == "cypionate" }) {
            weeklyProtocol.compoundID = cypionate.id
            weeklyProtocol.selectedRoute = Compound.Route.intramuscular.rawValue
            // Add some test blood samples to the protocol
            weeklyProtocol.bloodSamples = [
                BloodSample(date: Calendar.current.date(byAdding: .day, value: -30, to: Date())!, value: 650.0, unit: "ng/dL"),
                BloodSample(date: Calendar.current.date(byAdding: .day, value: -15, to: Date())!, value: 720.0, unit: "ng/dL")
            ]
            profile.protocols.append(weeklyProtocol)
        } else { print("Warning: Could not find Testosterone Cypionate in library for default profile.") }


        // 2. Split dose protocol (enanthate)
        var splitDoseProtocol = InjectionProtocol(
            name: "Split Dose Enanthate",
            doseMg: 75.0,
            frequencyDays: 3.5,
            startDate: Calendar.current.date(byAdding: .day, value: -45, to: Date())!,
            notes: "Split dose protocol for more stable levels"
        )
        if let enanthate = compoundLibrary.compounds.first(where: { $0.classType == .testosterone && $0.ester?.lowercased() == "enanthate" }) {
            splitDoseProtocol.compoundID = enanthate.id
            splitDoseProtocol.selectedRoute = Compound.Route.intramuscular.rawValue
            profile.protocols.append(splitDoseProtocol)
        } else { print("Warning: Could not find Testosterone Enanthate in library for default profile.") }


        // 3. Propionate protocol (more frequent injections)
        var propionateProtocol = InjectionProtocol(
            name: "EOD Propionate",
            doseMg: 30.0,
            frequencyDays: 2.0,
            startDate: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
            notes: "Every other day protocol with propionate"
        )
        if let propionate = compoundLibrary.compounds.first(where: { $0.classType == .testosterone && $0.ester?.lowercased() == "propionate" }) {
            propionateProtocol.compoundID = propionate.id
            propionateProtocol.selectedRoute = Compound.Route.subcutaneous.rawValue // Example different route
            profile.protocols.append(propionateProtocol)
        } else { print("Warning: Could not find Testosterone Propionate in library for default profile.") }

        return profile
    }

    // MARK: - Protocol Management
    func addProtocol(_ newProtocol: InjectionProtocol) {
        profile.protocols.append(newProtocol)
        selectedProtocolID = newProtocol.id // Select the newly added protocol
        recalcSimulation() // Simulate the newly added protocol
        saveProfile() // Prepare profile for saving
        coreDataManager.saveContext() // Save immediately
        // Schedule notifications for the new protocol
        if notificationManager.notificationsEnabled {
            notificationManager.scheduleNotifications(for: newProtocol, using: compoundLibrary)
        }
        print("Added protocol: \(newProtocol.name)")
    }

    func updateProtocol(_ updatedProtocol: InjectionProtocol) {
        if let index = profile.protocols.firstIndex(where: { $0.id == updatedProtocol.id }) {
            profile.protocols[index] = updatedProtocol
            if updatedProtocol.id == selectedProtocolID {
                recalcSimulation() // Resimulate if the selected protocol was updated
            }
            saveProfile() // Prepare profile for saving
            coreDataManager.saveContext() // Save immediately
            // Update notifications for the modified protocol
            if notificationManager.notificationsEnabled {
                notificationManager.scheduleNotifications(for: updatedProtocol, using: compoundLibrary)
            }
            print("Updated protocol: \(updatedProtocol.name)")
        } else {
            print("Error: Protocol to update not found (ID: \(updatedProtocol.id))")
        }
    }

    func removeProtocol(at offsets: IndexSet) {
        let deletedProtocols = offsets.map { profile.protocols[$0] }
        let deletedIDs = deletedProtocols.map { $0.id }

        profile.protocols.remove(atOffsets: offsets)

        // Check if selected protocol was deleted
        if let selectedID = selectedProtocolID, deletedIDs.contains(selectedID) {
            // Select the first remaining protocol, or none if list is empty
            selectedProtocolID = profile.protocols.first?.id
            recalcSimulation() // Recalculate simulation for new selection or empty state
        }

        saveProfile() // Prepare profile for saving
        coreDataManager.saveContext() // Save immediately

        // Cancel notifications for deleted protocols
        for item in deletedProtocols {
            notificationManager.cancelNotifications(for: item.id)
            print("Removed protocol: \(item.name)")
        }
    }

    func selectProtocol(id: UUID?) { // Allow nil to deselect
        guard let id = id else {
             selectedProtocolID = nil
             simulationData = [] // Clear simulation if no protocol selected
             print("Protocol deselected.")
             return
        }
        
        // Only proceed if the selected ID exists in the profile
        guard profile.protocols.contains(where: { $0.id == id }) else {
            print("Error: Attempted to select non-existent protocol ID: \(id)")
            // Optionally select the first available protocol if selection is invalid
            if let firstID = profile.protocols.first?.id {
                 selectedProtocolID = firstID
                 simulateProtocol(id: firstID) // Simulate the first one instead
            } else {
                 selectedProtocolID = nil
                 simulationData = []
            }
            return
        }

        // Check if selection actually changed or if simulation needs recalculating
        if selectedProtocolID != id || simulationData.isEmpty {
            selectedProtocolID = id
            simulateProtocol(id: id) // Always simulate when protocol is explicitly selected
            print("Selected protocol: \(profile.protocols.first { $0.id == id }?.name ?? "Unknown")")
        }
    }

    // MARK: - Simulation Core Logic

    // Recalculates simulation based on the currently selected protocol
    func recalcSimulation() {
        guard let currentSelectedID = selectedProtocolID else {
            simulationData = [] // Clear data if no protocol is selected
            print("RecalcSimulation: No protocol selected, clearing data.")
            return
        }
        // Ensure the selected protocol exists before simulating
        if profile.protocols.contains(where: { $0.id == currentSelectedID }) {
             simulateProtocol(id: currentSelectedID)
        } else {
             print("RecalcSimulation: Selected protocol ID \(currentSelectedID) not found in profile. Clearing data.")
             simulationData = []
             selectedProtocolID = nil // Deselect invalid ID
        }
    }
    
    // Simulate a specific protocol - called by selectProtocol and recalcSimulation
    func simulateProtocol(id: UUID) {
        guard let treatmentProtocol = profile.protocols.first(where: { $0.id == id }) else {
            print("SimulateProtocol Error: Protocol with ID \(id) not found.")
            simulationData = [] // Clear data if protocol not found
            return
        }

        simulationData = generateSimulationData(for: treatmentProtocol)
        print("Simulation generated for protocol: \(treatmentProtocol.name)")
    }

    // Generates the DataPoint array for a given protocol's simulation
    // ** THIS IS THE REFACTORED VERSION **
    func generateSimulationData(for injectionProtocol: InjectionProtocol) -> [DataPoint] {
        // 1. Determine simulation time range
        let calendar = Calendar.current
        let now = Date()
        let simulationStartDate: Date
        let daysBeforeStart = -7 // Show a week before start or now

        if injectionProtocol.startDate > now {
            // Future protocol: start simulation view a week before protocol start
            simulationStartDate = calendar.date(byAdding: .day, value: daysBeforeStart, to: injectionProtocol.startDate) ?? injectionProtocol.startDate
        } else {
            // Protocol already started: show from a week before now or protocol start, whichever is earlier
            let aWeekBeforeNow = calendar.date(byAdding: .day, value: daysBeforeStart, to: now) ?? now
            simulationStartDate = min(aWeekBeforeNow, injectionProtocol.startDate)
        }

        // Determine end date: Ensure at least 90 days from protocol start AND 30 days from now are shown
        let minEndDate = calendar.date(byAdding: .day, value: Int(simulationDurationDays), to: injectionProtocol.startDate) ?? now // Use constant duration
        let thirtyDaysFromNow = calendar.date(byAdding: .day, value: 30, to: now) ?? now
        let simulationEndDate = max(minEndDate, thirtyDaysFromNow)

        // 2. Generate time points for the chart
        let simulationDates = generateSimulationDates(
            startDate: simulationStartDate,
            endDate: simulationEndDate,
             // Dynamic interval based on frequency, minimum 6 hours (0.25 days)
            interval: max(0.25, injectionProtocol.frequencyDays / 16.0) 
        )

        if simulationDates.isEmpty {
            print("Warning: No simulation dates generated for protocol \(injectionProtocol.name)")
            return []
        }

        // 3. Generate ALL relevant injection dates up to the simulation end date
        let allInjectionDates = injectionProtocol.injectionDates(
            from: injectionProtocol.startDate, // Base calculation from protocol start
            upto: simulationEndDate             // Include all injections needed for the simulation window
        )

        // 4. Get compounds/blend details
        var compounds: [(compound: Compound, dosePerInjectionMg: Double)] = []
        let route: Compound.Route
        if let routeString = injectionProtocol.selectedRoute, let selectedRoute = Compound.Route(rawValue: routeString) {
            route = selectedRoute
        } else {
            route = .intramuscular // Default route
        }

        // Determine the compounds and doses based on protocol type
        switch injectionProtocol.protocolType {
            case .compound:
                if let compoundID = injectionProtocol.compoundID, let compound = compoundLibrary.compound(withID: compoundID) {
                     if (compound.defaultBioavailability[route] ?? 0) > 0 {
                          compounds = [(compound: compound, dosePerInjectionMg: injectionProtocol.doseMg)]
                     } else {
                          print("Warning: Selected route \(route.displayName) not supported for compound \(compound.commonName). Using default route.")
                          // Fallback to first supported route or default if none found
                          if let _ = compound.defaultBioavailability.keys.first(where: { (compound.defaultBioavailability[$0] ?? 0) > 0 }) {
                               compounds = [(compound: compound, dosePerInjectionMg: injectionProtocol.doseMg)]
                               // Note: Ideally, update protocol's selectedRoute here, but that could trigger unwanted UI updates.
                          } else {
                               print("Error: Compound \(compound.commonName) has no supported routes defined.")
                               return [] // Cannot simulate without a valid route/compound combo
                          }
                     }
                }
            case .blend:
                if let blendID = injectionProtocol.blendID, let blend = compoundLibrary.blend(withID: blendID) {
                     // Blends usually assume IM, route check less critical here unless supporting SubQ blends later
                     let resolvedComponents = blend.resolvedComponents(using: compoundLibrary)
                     // Check if totalConcentration is valid before division
                      guard blend.totalConcentration > 0 else {
                         print("Error: Blend \(blend.name) has zero total concentration.")
                         return []
                      }
                      compounds = resolvedComponents.map {
                         (compound: $0.compound, dosePerInjectionMg: $0.mgPerML * injectionProtocol.doseMg / blend.totalConcentration)
                      }
                }
        }
        
        // Final check for compounds, potentially attempt legacy fix
         if compounds.isEmpty {
              print("Warning: No valid compounds initially determined for protocol \(injectionProtocol.name). Attempting legacy fix...")
              if let fixedCompound = findLegacyCompound(for: injectionProtocol) {
                   // Ensure the route is valid for the fixed compound
                   if (fixedCompound.defaultBioavailability[route] ?? 0) > 0 {
                        // Valid route - use it
                   } else if let firstSupported = fixedCompound.defaultBioavailability.keys.first(where: { (fixedCompound.defaultBioavailability[$0] ?? 0) > 0 }) {
                        print("Legacy Fix: Using route \(firstSupported.displayName) for compound \(fixedCompound.commonName)")
                    } else {
                        print("Legacy Fix Error: Compound \(fixedCompound.commonName) has no supported routes.")
                        return []
                    }
                   compounds = [(compound: fixedCompound, dosePerInjectionMg: injectionProtocol.doseMg)]
                   print("Legacy fix applied. Using compound: \(fixedCompound.fullDisplayName)")
              } else {
                   print("Error: No valid compounds found for protocol \(injectionProtocol.name), even after legacy check. Cannot simulate.")
                   return []
              }
         }


        // 5. Call PKModel calculation ONCE
        let pkModel = createPKModel() // Ensure we use the correct model settings
        
        // Print summary of simulation setup (keep this but make it less verbose)
        print("Simulating protocol \(injectionProtocol.name): \(allInjectionDates.count) injections, \(compounds.count) compounds")
        
        let concentrations = pkModel.protocolConcentrations(
            at: simulationDates,
            injectionDates: allInjectionDates, // Pass ALL injection dates needed for the full timeline
            compounds: compounds,
            route: route, // Use the determined (or default) route
            weight: profile.weight ?? 70.0, // Use profile weight or default
            calibrationFactor: profile.calibrationFactor
        )
        
        // Keep brief summary of results
        let maxConcentration = concentrations.max() ?? 0
        print("Max concentration: \(Int(maxConcentration)) \(profile.unit)")

        // 6. Zip dates and concentrations into DataPoints
        let dataPoints = zip(simulationDates, concentrations).map { date, level in
            DataPoint(time: date, level: level.isNaN ? 0 : level) // Handle potential NaN results gracefully
        }

        return dataPoints
    }

    // MARK: - Single Point Level Calculation (for Calibration, etc.)
    // Calculates the concentration at a *single* specific date.
    private func calculateLevelForDate(_ date: Date, for injectionProtocol: InjectionProtocol) -> Double {
        // 1. Get compounds/blend details
        var compounds: [(compound: Compound, dosePerInjectionMg: Double)] = []
        let route: Compound.Route
        if let routeString = injectionProtocol.selectedRoute, let selectedRoute = Compound.Route(rawValue: routeString) {
            route = selectedRoute
        } else {
            route = .intramuscular // Default route
        }

        switch injectionProtocol.protocolType {
            case .compound:
                if let compoundID = injectionProtocol.compoundID, let compound = compoundLibrary.compound(withID: compoundID) {
                     if (compound.defaultBioavailability[route] ?? 0) > 0 {
                          compounds = [(compound: compound, dosePerInjectionMg: injectionProtocol.doseMg)]
                     } else { return 0.0 } // Invalid route for compound
                }
            case .blend:
                 if let blendID = injectionProtocol.blendID, let blend = compoundLibrary.blend(withID: blendID) {
                      guard blend.totalConcentration > 0 else { return 0.0 }
                      compounds = blend.resolvedComponents(using: compoundLibrary).map {
                         (compound: $0.compound, dosePerInjectionMg: $0.mgPerML * injectionProtocol.doseMg / blend.totalConcentration)
                      }
                 }
        }

        // Attempt legacy fix if needed
         if compounds.isEmpty {
              if let fixedCompound = findLegacyCompound(for: injectionProtocol) {
                   // Check if route is valid, otherwise just use it anyway (the route validation should happen elsewhere)
                   if (fixedCompound.defaultBioavailability[route] ?? 0) <= 0 {
                        // Route not supported, but we'll use it anyway and let the PKModel handle it
                        print("Warning: Selected route not optimal for legacy compound")
                   }
                   compounds = [(compound: fixedCompound, dosePerInjectionMg: injectionProtocol.doseMg)]
              } else {
                   print("Error: No valid compounds found for single date calculation: \(injectionProtocol.name)")
                   return 0.0
              }
         }

        // 2. Get ALL injection dates UP TO the target date
        let injectionDates = injectionProtocol.injectionDates(
            from: injectionProtocol.startDate, // Base calculation from protocol start
            upto: date                         // Only include injections up to the specific date
        )

        // 3. Call PKModel calculation for the single date
        let pkModel = createPKModel()
        let concentrations = pkModel.protocolConcentrations(
            at: [date], // Calculate only for this specific date
            injectionDates: injectionDates,
            compounds: compounds,
            route: route,
            weight: profile.weight ?? 70.0,
            calibrationFactor: profile.calibrationFactor // Use current factor for prediction
        )

        return concentrations.first ?? 0.0
    }

    // MARK: - Predicted Level (for UI display, potentially)
    // Primarily uses interpolation on existing simulation data for performance.
    func predictedLevel(on date: Date, for injectionProtocol: InjectionProtocol) -> Double {
        // Option 1: Interpolate from existing simulationData (fast)
        if !simulationData.isEmpty,
            let firstDate = simulationData.first?.time,
            let lastDate = simulationData.last?.time,
            date >= firstDate && date <= lastDate {

            // Find the two points surrounding the date using binary search for efficiency
             var lowerBound = 0
             var upperBound = simulationData.count - 1
             var midIndex = 0

             while lowerBound <= upperBound {
                 midIndex = lowerBound + (upperBound - lowerBound) / 2
                 let midDate = simulationData[midIndex].time

                 if midDate == date {
                      return simulationData[midIndex].level // Exact match
                 } else if midDate < date {
                      lowerBound = midIndex + 1
                 } else {
                      upperBound = midIndex - 1
                 }
             }

             // After loop, lowerBound points to the index *after* the target date's position
             // The surrounding points are at indices lowerBound - 1 and lowerBound
            
            // Check bounds
             guard lowerBound > 0 && lowerBound < simulationData.count else {
                // Date is outside the range or at the exact start/end
                if date <= firstDate { return simulationData.first?.level ?? 0 }
                if date >= lastDate { return simulationData.last?.level ?? 0 }
                print("Interpolation index out of bounds.")
                return 0.0 // Should not happen if date is within range
             }


            let p1 = simulationData[lowerBound - 1]
            let p2 = simulationData[lowerBound]

            // Linear interpolation
            let timeIntervalTotal = p2.time.timeIntervalSince(p1.time)
            if timeIntervalTotal <= 0 { return p1.level } // Avoid division by zero or negative interval

            let timeIntervalFromP1 = date.timeIntervalSince(p1.time)
            let fraction = timeIntervalFromP1 / timeIntervalTotal

            // Clamp fraction to [0, 1] to avoid extrapolation issues at edges
            let clampedFraction = max(0.0, min(1.0, fraction))

            return p1.level + (p2.level - p1.level) * clampedFraction
        }

        // Option 2: Date is outside the simulation range. Recalculate (can be slow if called often).
        print("Warning: Predicted level requested for date \(date) outside current simulation range. Recalculating single point.")
        return calculateLevelForDate(date, for: injectionProtocol) // Use the dedicated single-point calculator
    }

    // MARK: - Protocol Calibration

    // Simple calibration using the latest blood sample
    func calibrateProtocol(_ protocolToCalibrate: InjectionProtocol) {
        guard let latestSample = protocolToCalibrate.bloodSamples.max(by: { $0.date < $1.date }) else {
            print("Cannot calibrate: No blood samples available for protocol \(protocolToCalibrate.name).")
            return
        }

        // Calculate the model's prediction AT THE SAMPLE DATE using the CURRENT calibration factor
        let modelPrediction = calculateLevelForDate(latestSample.date, for: protocolToCalibrate) // Uses the correct single-point calculation method

        guard modelPrediction.isFinite, modelPrediction > 0.01 else {
            print("Calibration failed: Model prediction is zero or invalid (\(modelPrediction)) at sample date \(latestSample.date). Cannot calculate ratio.")
            return
        }

        // Calculate the adjustment ratio needed to match the latest sample
        let adjustmentRatio = latestSample.value / modelPrediction

         // Apply the adjustment to the global factor
         // Add bounds to prevent extreme calibration factors (e.g., 0.1x to 10x)
         let newFactor = max(0.1, min(10.0, profile.calibrationFactor * adjustmentRatio))
        
         print("Simple Calibration:")
         print("  - Latest Sample: \(latestSample.value) \(latestSample.unit) on \(latestSample.date)")
         print("  - Model Prediction (at sample date, current factor \(profile.calibrationFactor)): \(modelPrediction)")
         print("  - Adjustment Ratio: \(adjustmentRatio)")
         print("  - Old Factor: \(profile.calibrationFactor)")
         print("  - New Factor (Clamped): \(newFactor)")


        profile.calibrationFactor = newFactor
        recalcSimulation() // Update chart data with the new factor
        saveProfile()      // Persist the new factor
        coreDataManager.saveContext() // Save immediately
    }

    // Bayesian calibration (currently applies result as a simple factor adjustment)
    func calibrateProtocolWithBayesian(_ protocolToCalibrate: InjectionProtocol) {
        guard !protocolToCalibrate.bloodSamples.isEmpty, protocolToCalibrate.bloodSamples.count >= 2 else {
            print("Bayesian calibration requires at least 2 blood samples. Falling back to simple calibration.")
            calibrateProtocol(protocolToCalibrate) // Fallback if not enough samples
            return
        }

        // Determine the compound/blend and dose for calibration
        var compoundForCalibration: Compound?
        var doseForCalibration: Double = protocolToCalibrate.doseMg
        let route: Compound.Route = {
            if let routeString = protocolToCalibrate.selectedRoute, let r = Compound.Route(rawValue: routeString) { return r }
            return .intramuscular
        }()

        switch protocolToCalibrate.protocolType {
        case .compound:
            compoundForCalibration = protocolToCalibrate.compoundID.flatMap { compoundLibrary.compound(withID: $0) }
        case .blend:
            // Use the component with the largest contribution or longest half-life for calibration?
            // For now, using the first component as an approximation. A more robust approach might be needed.
            if let blendID = protocolToCalibrate.blendID,
               let blend = compoundLibrary.blend(withID: blendID),
               let mainComponent = blend.resolvedComponents(using: compoundLibrary).max(by: { $0.mgPerML < $1.mgPerML }) { // Choose component with highest mg/mL
                compoundForCalibration = mainComponent.compound
                // Adjust dose proportionally for the main component
                 guard blend.totalConcentration > 0 else {
                      print("Bayesian Calibration Error: Blend has zero total concentration.")
                      calibrateProtocol(protocolToCalibrate); return // Fallback
                 }
                 doseForCalibration = mainComponent.mgPerML * protocolToCalibrate.doseMg / blend.totalConcentration
            }
        }

        guard let compound = compoundForCalibration else {
            print("Bayesian calibration failed: Could not determine valid compound for protocol \(protocolToCalibrate.name). Falling back.")
            calibrateProtocol(protocolToCalibrate)
            return
        }

        // Convert blood samples
        let samplePoints = protocolToCalibrate.bloodSamples.map {
            PKModel.SamplePoint(timestamp: $0.date, labValue: $0.value)
        }

        // Determine relevant injection dates (look back further for Bayesian)
        let firstSampleDate = protocolToCalibrate.bloodSamples.map { $0.date }.min() ?? Date()
        let lastSampleDate = protocolToCalibrate.bloodSamples.map { $0.date }.max() ?? Date()
        // Look back significantly to capture buildup phase effects for Bayesian
        let historyStartDate = Calendar.current.date(byAdding: .day, value: -180, to: firstSampleDate) ?? firstSampleDate
        let injectionDates = protocolToCalibrate.injectionDates(from: historyStartDate, upto: lastSampleDate)

        // Perform Bayesian calibration using the PKModel
        if let calibrationResult = pkModel.bayesianCalibration(
            samples: samplePoints,
            injectionDates: injectionDates,
            compound: compound,
            dose: doseForCalibration, // Use the potentially adjusted dose for blends
            route: route,
            weight: profile.weight ?? 70.0
        ) {
            // --- Apply Calibration Result ---
            // Option 1 (Current): Adjust the global calibration factor based on the overall fit improvement.
            // Calculate average error before and after Bayesian adjustment to find the improvement factor.
            let avgLabValue = samplePoints.reduce(0.0) { $0 + $1.labValue } / Double(samplePoints.count)
            
             // Calculate average prediction using the *original* parameters but *current* calibration factor
             // This represents the state *before* this Bayesian run, but after any previous simple calibrations
             let avgPredictionBeforeBayesian = samplePoints.reduce(0.0) { sum, point in
                  sum + calculateLevelForDate(point.timestamp, for: protocolToCalibrate) // Uses current profile.calibrationFactor internally
             } / Double(samplePoints.count)

            guard avgPredictionBeforeBayesian > 0.01 else {
                 print("Bayesian Calibration Apply Failed: Pre-Bayesian prediction average is too low.")
                 calibrateProtocol(protocolToCalibrate) // Fallback
                 return
            }

            // Calculate the ratio needed to align the pre-Bayesian average prediction with the average lab value
            let adjustmentRatio = avgLabValue / avgPredictionBeforeBayesian
            let newFactor = max(0.1, min(10.0, profile.calibrationFactor * adjustmentRatio)) // Apply adjustment relative to current factor

            // Log details
            print("--- Bayesian Calibration Results ---")
            print("  Compound Used: \(compound.fullDisplayName)")
            print("  Original Half-life: \(String(format: "%.2f", log(2) / calibrationResult.originalKe)) days (ke: \(calibrationResult.originalKe))")
            print("  Calibrated Half-life: \(String(format: "%.2f", calibrationResult.halfLifeDays)) days (ke: \(calibrationResult.adjustedKe))")
            print("  Half-life Change: \(String(format: "%.1f", calibrationResult.halfLifeChangePercent))%")
            print("  Original Ka: \(String(format: "%.2f", calibrationResult.originalKa))")
            print("  Calibrated Ka: \(String(format: "%.2f", calibrationResult.adjustedKa))")
            print("  Model Fit Correlation: \(String(format: "%.3f", calibrationResult.correlation))")
             print("  Adjustment Applied:")
             print("    Avg Lab Value: \(avgLabValue)")
             print("    Avg Prediction (Before Bayesian, Factor \(profile.calibrationFactor)): \(avgPredictionBeforeBayesian)")
             print("    Adjustment Ratio: \(adjustmentRatio)")
             print("    Old Global Factor: \(profile.calibrationFactor)")
             print("    New Global Factor (Clamped): \(newFactor)")
            print("------------------------------------")


            // Apply the adjusted global factor
            profile.calibrationFactor = newFactor
            
            // Option 2 (Future): Store adjusted ke/ka per compound (more complex)
            // This would involve updating the CompoundLibrary or creating user-specific compound parameters.

            // Update simulation and save
            recalcSimulation()
            saveProfile()
            coreDataManager.saveContext() // Save immediately
        } else {
            print("Bayesian calibration failed to produce results. Falling back to simple calibration.")
            calibrateProtocol(protocolToCalibrate)
        }
    }

    // MARK: - Value Formatting
    func formatValue(_ value: Double, unit: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if unit == "nmol/L" {
            formatter.maximumFractionDigits = 1
        } else if unit == "%" {
             formatter.maximumFractionDigits = 1
        } else { // ng/dL typically whole numbers
            formatter.maximumFractionDigits = 0
        }
        formatter.minimumFractionDigits = formatter.maximumFractionDigits // Ensure consistency
        // Handle potential NaN or infinity
        if !value.isFinite {
             return "N/A"
        }
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Peak Predictions
    func calculatePeakDetails(for injectionProtocol: InjectionProtocol) -> (peakDate: Date, maxConcentration: Double) {
        // Reuse the logic from generateSimulationData to get compounds and route
         var compounds: [(compound: Compound, dosePerInjectionMg: Double)] = []
         let route: Compound.Route
         if let routeString = injectionProtocol.selectedRoute, let selectedRoute = Compound.Route(rawValue: routeString) {
             route = selectedRoute
         } else {
             route = .intramuscular // Default route
         }

         switch injectionProtocol.protocolType {
             case .compound:
                 if let compoundID = injectionProtocol.compoundID, let compound = compoundLibrary.compound(withID: compoundID) {
                      if (compound.defaultBioavailability[route] ?? 0) > 0 {
                           compounds = [(compound: compound, dosePerInjectionMg: injectionProtocol.doseMg)]
                      }
                 }
             case .blend:
                  if let blendID = injectionProtocol.blendID, let blend = compoundLibrary.blend(withID: blendID) {
                       guard blend.totalConcentration > 0 else { return (injectionProtocol.startDate, 0) }
                       compounds = blend.resolvedComponents(using: compoundLibrary).map {
                          (compound: $0.compound, dosePerInjectionMg: $0.mgPerML * injectionProtocol.doseMg / blend.totalConcentration)
                       }
                  }
         }
        
         if compounds.isEmpty {
              if let fixedCompound = findLegacyCompound(for: injectionProtocol) {
                   // Check if route is valid, otherwise just use it anyway (the route validation should happen elsewhere)
                   if (fixedCompound.defaultBioavailability[route] ?? 0) <= 0 {
                        // Route not supported, but we'll try anyway
                        print("Warning: Selected route not optimal for peak calculation")
                        if !fixedCompound.defaultBioavailability.keys.contains(where: { (fixedCompound.defaultBioavailability[$0] ?? 0) > 0 }) {
                             return (peakDate: injectionProtocol.startDate, maxConcentration: 0) // No valid routes at all
                        }
                   }
                   compounds = [(compound: fixedCompound, dosePerInjectionMg: injectionProtocol.doseMg)]
              } else {
                   print("Error calculating peak: No valid compounds for protocol \(injectionProtocol.name)")
                   return (peakDate: injectionProtocol.startDate, maxConcentration: 0)
              }
         }


        // Define time window (e.g., first 90 days of the protocol)
        let timeWindow = (
            start: injectionProtocol.startDate,
            end: injectionProtocol.startDate.addingTimeInterval(simulationDurationDays * 24 * 3600)
        )

        // Get all injection dates within the window
        let injectionDates = injectionProtocol.injectionDates(
            from: timeWindow.start, // Need injections from the actual start
            upto: timeWindow.end
        )

        // Use PKModel to calculate peak details
        let pkModel = createPKModel()
        return pkModel.calculateProtocolPeakDetails(
            injectionDates: injectionDates,
            compounds: compounds,
            route: route,
            timeWindow: timeWindow,
            weight: profile.weight ?? 70.0,
            calibrationFactor: profile.calibrationFactor
        )
    }

    func calculateSingleDosePeakDetails(for injectionProtocol: InjectionProtocol) -> (timeToMaxDays: Double, maxConcentration: Double) {
         // Reuse logic to get compounds and route
         var compounds: [(compound: Compound, doseMg: Double)] = []
         let route: Compound.Route
         if let routeString = injectionProtocol.selectedRoute, let selectedRoute = Compound.Route(rawValue: routeString) {
             route = selectedRoute
         } else {
             route = .intramuscular // Default route
         }

         switch injectionProtocol.protocolType {
             case .compound:
                 if let compoundID = injectionProtocol.compoundID, let compound = compoundLibrary.compound(withID: compoundID) {
                      if (compound.defaultBioavailability[route] ?? 0) > 0 {
                           compounds = [(compound: compound, doseMg: injectionProtocol.doseMg)]
                      }
                 }
             case .blend:
                  if let blendID = injectionProtocol.blendID, let blend = compoundLibrary.blend(withID: blendID) {
                       guard blend.totalConcentration > 0 else { return (0, 0) }
                       compounds = blend.resolvedComponents(using: compoundLibrary).map {
                          (compound: $0.compound, doseMg: $0.mgPerML * injectionProtocol.doseMg / blend.totalConcentration)
                       }
                  }
         }
        
         if compounds.isEmpty {
              if let fixedCompound = findLegacyCompound(for: injectionProtocol) {
                   // Check if route is valid, otherwise just use it anyway (the route validation should happen elsewhere)
                   if (fixedCompound.defaultBioavailability[route] ?? 0) <= 0 {
                        // Route not supported, but we'll try anyway
                        print("Warning: Selected route not optimal for single dose peak calculation")
                        if !fixedCompound.defaultBioavailability.keys.contains(where: { (fixedCompound.defaultBioavailability[$0] ?? 0) > 0 }) {
                             return (0, 0) // No valid routes at all
                        }
                   }
                   compounds = [(compound: fixedCompound, doseMg: injectionProtocol.doseMg)]
              } else {
                  print("Error calculating single dose peak: No valid compounds.")
                   return (timeToMaxDays: 0, maxConcentration: 0)
              }
         }


        // For single dose peak, if it's a blend, use the specialized blend peak calculation
        if injectionProtocol.protocolType == .blend {
            let pkModel = createPKModel()
            return pkModel.calculateBlendPeakDetails(
                components: compounds,
                route: route,
                weight: profile.weight ?? 70.0,
                calibrationFactor: profile.calibrationFactor
            )
        }
        // Otherwise (single compound), use the standard single dose calculation
        else if let firstCompound = compounds.first {
            let bioavailability = firstCompound.compound.defaultBioavailability[route] ?? 1.0
            let absorptionRate = firstCompound.compound.defaultAbsorptionRateKa[route] ?? 0.7
            let pkModel = createPKModel()
            let timeToMax = pkModel.calculateTimeToMaxConcentration(
                dose: firstCompound.doseMg,
                halfLifeDays: firstCompound.compound.halfLifeDays,
                absorptionRateKa: absorptionRate,
                bioavailability: bioavailability,
                weight: profile.weight ?? 70.0,
                calibrationFactor: profile.calibrationFactor
            )
            let maxConc = pkModel.calculateMaxConcentration(
                dose: firstCompound.doseMg,
                halfLifeDays: firstCompound.compound.halfLifeDays,
                absorptionRateKa: absorptionRate,
                bioavailability: bioavailability,
                weight: profile.weight ?? 70.0,
                calibrationFactor: profile.calibrationFactor
            )
            return (timeToMaxDays: timeToMax, maxConcentration: maxConc)
        }

        return (timeToMaxDays: 0, maxConcentration: 0) // Fallback
    }

    // MARK: - Adherence Tracking Interface
    func acknowledgeInjection(protocolID: UUID, injectionDate: Date) {
        notificationManager.acknowledgeInjection(protocolID: protocolID, injectionDate: injectionDate)
        print("Acknowledged injection for protocol \(protocolID) scheduled on \(injectionDate)")
    }

    func adherenceStats() -> (total: Int, onTime: Int, late: Int, missed: Int) {
        return notificationManager.adherenceStats()
    }

    func adherencePercentage() -> Double {
        return notificationManager.adherencePercentage()
    }

    func injectionHistory(for protocolID: UUID? = nil) -> [NotificationManager.InjectionRecord] {
        return notificationManager.injectionHistory(for: protocolID)
    }

    func cleanupOldRecords() {
        notificationManager.cleanupOldRecords()
        print("Cleaned up old injection records.")
    }

    // MARK: - Cycle Management
    func loadCyclesFromCoreData() {
        let context = coreDataManager.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<CDCycle> = CDCycle.fetchRequest()
        // Add sort descriptor to load cycles in a consistent order (e.g., by start date)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        do {
            let cdCycles = try context.fetch(fetchRequest)
            self.cycles = cdCycles.map { Cycle(from: $0, context: context) } // Pass context if needed by Cycle init
            print("Loaded \(self.cycles.count) cycles from Core Data.")
        } catch {
            print("Error loading cycles from Core Data: \(error)")
            self.cycles = [] // Ensure cycles is empty on error
        }
    }

    func saveCycle(_ cycle: Cycle) {
        let context = coreDataManager.persistentContainer.viewContext
        // Save to Core Data (create or update)
        _ = cycle.save(to: context)
        do {
            try context.save()
            // Refresh cycles from Core Data to update the @Published array
            loadCyclesFromCoreData()
            print("Saved cycle: \(cycle.name)")
        } catch {
            print("Error saving cycle \(cycle.name): \(error)")
        }
    }

    func deleteCycle(with id: UUID) {
        let context = coreDataManager.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<CDCycle> = CDCycle.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        do {
            if let cdCycle = try context.fetch(fetchRequest).first {
                let cycleName = cdCycle.name ?? "Unknown"
                context.delete(cdCycle)
                try context.save()
                // Refresh cycles from Core Data
                loadCyclesFromCoreData()
                // If this was the selected cycle, deselect it
                if selectedCycleID == id {
                    selectedCycleID = nil
                    isCycleSimulationActive = false
                    cycleSimulationData = []
                }
                print("Deleted cycle: \(cycleName)")
            } else {
                print("Error deleting cycle: Cycle with ID \(id) not found.")
            }
        } catch {
            print("Error deleting cycle with ID \(id): \(error)")
        }
    }
    
    func selectCycle(id: UUID?) {
         guard let id = id else {
              selectedCycleID = nil
              cycleSimulationData = []
              isCycleSimulationActive = false
              print("Cycle deselected.")
              return
         }
        
         // Only proceed if the selected ID exists
         guard cycles.contains(where: { $0.id == id }) else {
              print("Error: Attempted to select non-existent cycle ID: \(id)")
              // Optionally select the first available cycle if selection is invalid
              if let firstID = cycles.first?.id {
                   selectedCycleID = firstID
                   simulateCycle(id: firstID) // Simulate the first one instead
              } else {
                   selectedCycleID = nil
                   cycleSimulationData = []
                   isCycleSimulationActive = false
              }
              return
         }

         // Simulate if selection changed or simulation isn't active
         if selectedCycleID != id || !isCycleSimulationActive {
              selectedCycleID = id
              simulateCycle(id: id)
              print("Selected cycle: \(cycles.first { $0.id == id }?.name ?? "Unknown")")
         }
     }


    func simulateCycle(id: UUID) { // Changed parameter to non-optional for clarity
        guard let cycle = cycles.first(where: { $0.id == id }) else {
            print("SimulateCycle Error: Cycle with ID \(id) not found.")
            cycleSimulationData = []
            isCycleSimulationActive = false
            return
        }

        // Create temporary protocols for simulation
        let tempProtocols = cycle.generateTemporaryProtocols(compoundLibrary: compoundLibrary)

        if tempProtocols.isEmpty {
            print("No protocols generated for cycle \(cycle.name). Clearing simulation.")
            cycleSimulationData = []
            isCycleSimulationActive = false
            return
        }

        print("Simulating cycle: \(cycle.name) with \(tempProtocols.count) derived protocols...")
        let pkModel = createPKModel()
        cycleSimulationData = [] // Clear previous data

        // Determine simulation range based on cycle dates
        let calendar = Calendar.current
        let startDate = cycle.startDate
        // Ensure end date calculation is robust
        guard let endDate = calendar.date(byAdding: .day, value: cycle.totalWeeks * 7, to: startDate) else {
            print("Error calculating cycle end date.")
            cycleSimulationData = []
            isCycleSimulationActive = false
            return
        }

        let simulationDates = generateSimulationDates(
            startDate: startDate,
            endDate: endDate,
            interval: 0.5 // Consistent interval for cycle charts (e.g., twice daily)
        )

        if simulationDates.isEmpty {
            print("Error: No simulation dates generated for cycle.")
            cycleSimulationData = []
            isCycleSimulationActive = false
            return
        }

        var totalConcentrations = Array(repeating: 0.0, count: simulationDates.count)
        let weight = profile.weight ?? 70.0

        // Accumulate concentrations from each derived protocol
        for treatmentProtocol in tempProtocols {
            var compounds: [(compound: Compound, dosePerInjectionMg: Double)] = []
            let route: Compound.Route = {
                if let routeString = treatmentProtocol.selectedRoute, let r = Compound.Route(rawValue: routeString) { return r }
                return .intramuscular
            }()

            // Get compounds/blend for this temporary protocol
            switch treatmentProtocol.protocolType {
                case .compound:
                    if let compoundID = treatmentProtocol.compoundID, let c = compoundLibrary.compound(withID: compoundID), (c.defaultBioavailability[route] ?? 0) > 0 {
                        compounds = [(c, treatmentProtocol.doseMg)]
                    }
                case .blend:
                    if let blendID = treatmentProtocol.blendID, let b = compoundLibrary.blend(withID: blendID), b.totalConcentration > 0 {
                         compounds = b.resolvedComponents(using: compoundLibrary).map { rc in
                             (rc.compound, treatmentProtocol.doseMg * (rc.mgPerML / b.totalConcentration))
                         }
                    }
            }
            
            if compounds.isEmpty {
                print("Warning: Skipping empty/invalid protocol '\(treatmentProtocol.name)' in cycle simulation.")
                continue // Skip this protocol if no valid compounds
            }

            // Generate injection dates for this specific protocol within the cycle's timeframe
            let injectionDates = treatmentProtocol.injectionDates(from: startDate, upto: endDate)

            // Calculate concentrations for this protocol
            let concentrations = pkModel.protocolConcentrations(
                at: simulationDates,
                injectionDates: injectionDates,
                compounds: compounds,
                route: route,
                weight: weight,
                calibrationFactor: profile.calibrationFactor
            )

            // Add to the total concentrations
            for i in 0..<min(totalConcentrations.count, concentrations.count) {
                totalConcentrations[i] += concentrations[i]
            }
        }

        // Convert to DataPoints
        cycleSimulationData = zip(simulationDates, totalConcentrations).map {
            DataPoint(time: $0, level: $1.isNaN ? 0 : $1)
        }
        isCycleSimulationActive = true // Mark simulation as active
        print("Cycle simulation complete for \(cycle.name). Generated \(cycleSimulationData.count) points.")
    }

    // MARK: - Notification Management Interface
    func toggleNotifications(enabled: Bool) {
        notificationManager.notificationsEnabled = enabled
        if enabled {
            Task {
                let granted = await notificationManager.requestNotificationPermission()
                if granted {
                    await scheduleAllNotifications()
                    print("Notifications enabled and scheduled.")
                } else {
                    // Permission denied - update state and potentially UI
                    await MainActor.run {
                        notificationManager.notificationsEnabled = false
                        self.profile.usesICloudSync = false // Example UI update if needed
                        print("Notification permission denied.")
                    }
                }
            }
        } else {
            notificationManager.cancelAllNotifications()
            print("Notifications disabled and cancelled.")
        }
    }

    func setNotificationSound(enabled: Bool) {
        notificationManager.soundEnabled = enabled
        // Reschedule all notifications to apply sound setting change
        if notificationManager.notificationsEnabled {
            Task {
                await scheduleAllNotifications()
                print("Notification sound setting updated and notifications rescheduled.")
            }
        }
    }

    func setNotificationLeadTime(_ leadTime: NotificationManager.LeadTime) {
        notificationManager.selectedLeadTime = leadTime
        // Reschedule all notifications to apply lead time change
        if notificationManager.notificationsEnabled {
            Task {
                await scheduleAllNotifications()
                print("Notification lead time updated to \(leadTime.rawValue) and notifications rescheduled.")
            }
        }
    }

    // Schedules notifications for ALL current protocols
    func scheduleAllNotifications() async {
        guard notificationManager.notificationsEnabled else { return }

        // Ensure permission is granted before scheduling
        let granted = await notificationManager.requestNotificationPermission()
        if !granted {
            await MainActor.run {
                 notificationManager.notificationsEnabled = false // Reflect denial in state
                 // Maybe update UI toggle? Requires binding or callback
            }
            print("Cannot schedule notifications: Permission denied.")
            return
        }

        print("Scheduling notifications for \(profile.protocols.count) protocols...")
        // Cancel all existing first to avoid duplicates if rescheduling
        notificationManager.cancelAllNotifications()
        // Schedule for each protocol
        for p in profile.protocols {
            notificationManager.scheduleNotifications(for: p, using: compoundLibrary)
        }
        print("Notification scheduling complete.")
    }
} // End of AppDataStore class