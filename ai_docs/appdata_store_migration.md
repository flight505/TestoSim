# AppDataStore Migration to Unified Treatment Model

## Overview

This document describes the migration of the AppDataStore class to support the unified Treatment model in TestoSim. The AppDataStore is a central component that manages all data operations, including loading, saving, simulating, and visualizing treatment data.

## Migration Strategy

The migration follows these key principles:

1. **Inside-Out Pattern**: Starting with core models, then ViewModels, and finally UI components
2. **Bridge Methods**: Adding compatibility methods for legacy types during transition
3. **Deprecation Annotations**: Marking legacy methods with `@available(*, deprecated, ...)` to guide future usage
4. **Parallel Support**: Maintaining both legacy and unified models simultaneously during transition

## Implemented Changes

### New Properties

```swift
// Unified treatment model properties
@Published var treatments: [Treatment] = []
@Published var selectedTreatmentID: UUID?
@Published var isPresentingTreatmentForm = false
@Published var treatmentToEdit: Treatment?
@Published var treatmentSimulationData: [DataPoint] = []
```

### Core Treatment Management Methods

1. **Loading Treatments**:
   ```swift
   func loadTreatmentsFromCoreData()
   ```
   - Fetches all CDTreatment entities from Core Data
   - Converts to Treatment model objects
   - Handles initialization of selectedTreatmentID

2. **Saving Treatments**:
   ```swift
   func saveTreatment(_ treatment: Treatment)
   ```
   - Saves a Treatment to Core Data through Treatment.saveToCD()
   - Reloads treatments after saving to keep the published array updated

3. **Deleting Treatments**:
   ```swift
   func deleteTreatment(with id: UUID)
   ```
   - Removes a Treatment from Core Data
   - Updates selection state if the deleted treatment was selected

### Treatment Simulation Methods

1. **Selection and Simulation**:
   ```swift
   func selectTreatment(id: UUID?)
   func simulateTreatment(id: UUID)
   ```
   - Handles treatment selection state
   - Triggers simulation for the selected treatment

2. **Simulation Data Generation**:
   ```swift
   func generateSimulationData(for treatment: Treatment) -> [DataPoint]
   ```
   - Handles both simple and advanced treatments through type checking
   - For simple treatments: generates pharmacokinetic simulation data
   - For advanced treatments: uses VisualizationFactory to create multi-layered visualizations

### Bridge Methods for Legacy Models

1. **Protocol Management**:
   ```swift
   @available(*, deprecated, message: "Use addTreatment(_:) instead")
   func addProtocol(_ newProtocol: InjectionProtocol)
   
   @available(*, deprecated, message: "Use updateTreatment(_:) instead")
   func updateProtocol(_ updatedProtocol: InjectionProtocol)
   
   @available(*, deprecated, message: "Use deleteTreatment(with:) instead")
   func removeProtocol(at offsets: IndexSet)
   
   @available(*, deprecated, message: "Use selectTreatment(id:) instead")
   func selectProtocol(id: UUID?)
   ```
   - Convert between legacy Protocol and unified Treatment model
   - Maintain both models in sync during transition

2. **Cycle Management**:
   ```swift
   @available(*, deprecated, message: "Use addTreatment(_:) with treatmentType = .advanced instead")
   func addTreatmentFromCycle(_ cycle: Cycle)
   
   @available(*, deprecated, message: "Use deleteTreatment(with:) instead")
   func deleteCycleAndTreatment(with id: UUID)
   
   @available(*, deprecated, message: "Use selectTreatment(id:) instead")
   func selectCycleAsTreatment(id: UUID?)
   
   @available(*, deprecated, message: "Use deleteTreatment(with:) instead")
   func removeCycles(at offsets: IndexSet)
   ```
   - Support conversion between legacy Cycle and unified Treatment model
   - Handle dual state management during transition

### Notification Integration

```swift
func scheduleNotificationsForTreatments() async
```
- Added support for scheduling notifications for unified treatment model
- Maintains backward compatibility with legacy notification methods
- Integrated with existing notification scheduling system

## Testing and Validation

1. **Build Testing**:
   - Verified successful build with expected deprecation warnings
   - Ensured no runtime errors during operation

2. **Type Safety**:
   - Added robust type checking between simple and advanced treatments
   - Implemented optional handling to prevent runtime crashes

3. **Dual Model Support**:
   - Verified that both legacy and unified models can operate simultaneously
   - Ensured changes to one model are reflected in the other during transition

## Core Data Integration Enhancements

The following improvements were made to enhance Core Data integration:

1. **Profile Association**:
   ```swift
   func saveTreatment(_ treatment: Treatment) {
       // Save treatment to Core Data
       let cdTreatment = treatment.saveToCD(context: context)
       
       // Associate with user profile if not already
       if cdTreatment.userProfile == nil {
           // Fetch user profile
           let fetchRequest: NSFetchRequest<CDUserProfile> = CDUserProfile.fetchRequest()
           do {
               if let userProfile = try context.fetch(fetchRequest).first {
                   cdTreatment.userProfile = userProfile
                   userProfile.addToTreatments(cdTreatment)
               }
           } catch {
               print("Error fetching user profile: \(error)")
           }
       }
       
       // Continue with saving...
   }
   ```

2. **Model Sync Mechanism**:
   - Added detection and automatic creation of missing treatments for existing legacy models:
   ```swift
   // If there are protocols but no treatments, create treatments from protocols
   if !profile.protocols.isEmpty && treatments.isEmpty {
       createTreatmentsFromProtocols()
       // Reload treatments after creating them
       loadTreatmentsFromCoreData()
   }
   
   // Create treatments from cycles if they don't exist yet
   if !cycles.isEmpty {
       let cycleIDs = cycles.map { $0.id }
       let missingCycles = cycleIDs.filter { cycleID in
           !treatments.contains { $0.id == cycleID }
       }
       
       if !missingCycles.isEmpty {
           for cycle in cycles where missingCycles.contains(cycle.id) {
               let treatment = Treatment(from: cycle)
               saveTreatment(treatment)
           }
           // Reload treatments after creating them
           loadTreatmentsFromCoreData()
       }
   }
   ```

3. **Default Model Creation**:
   - Updated default profile creation to directly create a unified Treatment model:
   ```swift
   // Instead of creating a legacy Cycle, create an advanced Treatment directly
   var advancedTreatment = Treatment(
       name: "Test Cycle",
       startDate: Calendar.current.date(byAdding: .day, value: -20, to: Date())!,
       notes: "Example test cycle with multiple compounds",
       treatmentType: .advanced
   )
   
   // Set advanced treatment properties
   advancedTreatment.totalWeeks = 12
   
   // Create a stage with compound components
   var bulkingStage = Treatment.Stage(...)
   let stageCompound = Treatment.StageCompound(...)
   bulkingStage.compounds.append(stageCompound)
   
   // Add the stage to the treatment
   advancedTreatment.stages = [bulkingStage]
   ```

## Remaining Tasks

1. **NotificationManager Integration**:
   - Create direct notification methods for Treatment model
   - Update user notification content to use "treatment" terminology

2. **User Interface Integration**:
   - Update treatment-related views to use unified model
   - Replace legacy protocol and cycle views with unified treatment views

## Migration Approach

The migration uses a gradual approach:

1. **Add Support**: First add support for the unified model alongside the legacy model
2. **Bridge**: Create bridge methods to connect legacy and unified models
3. **Deprecate**: Mark legacy methods as deprecated to guide future development
4. **Replace**: Systematically replace legacy usage with unified model
5. **Remove**: Eventually remove legacy code completely

This approach allows for continuous operation during the transition while moving toward a cleaner, more unified codebase.