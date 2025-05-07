# Unified Treatment Model Implementation Checklist

## Overview

This document tracks the progress of transitioning TestoSim from legacy models (InjectionProtocol and Cycle) to the unified Treatment model.

## Implementation Status

### Core Models
- [x] Create unified Treatment model with support for both simple and advanced treatments
  - Implemented in Treatment.swift with two treatment types (.simple and .advanced)
  - Added handling for both compound and blend-based treatments
  - Created stage-based implementation for advanced treatments
- [x] Add bidirectional conversion methods between legacy and unified models
  - Added init(from:) constructors for conversion from legacy to unified model
  - Added toLegacyProtocol() and toLegacyCycle() methods for backward compatibility
  - Implemented stage-level conversions for advanced treatments
- [x] Add deprecation annotations to legacy types
  - Added @available(*, deprecated, message: "...") to all legacy types in CycleModel, ProtocolModel
  - Added explanatory messages directing to unified Treatment model equivalents
- [x] Update Core Data entities and relationships
  - Added CDTreatment and CDTreatmentStage entities to Core Data model
  - Implemented persistence methods for the unified model
  - Created fetchRequestWithID method to address naming conflicts

### ViewModels
- [x] Update TreatmentViewModel to use unified Treatment model
  - Added methods for managing unified Treatment objects
  - Implemented layer ordering for visualization model
  - Added conversion utilities between legacy and unified models
- [x] Update AIInsightsGenerator to use unified Treatment model
  - Renamed methods to work with unified Treatment model
  - Added bridge methods for backward compatibility
  - Updated mock implementation methods for both treatment types
  - Implemented proper type checking and branching based on treatment type
- [x] Update OpenAIService to use unified Treatment model
  - Added generateInsights and generateAdvancedTreatmentInsights methods
  - Created new prompt building methods for both treatment types
  - Updated parsing logic to work with unified Treatment model
  - Added deprecated bridge methods for backward compatibility
- [x] Update AppDataStore to use unified Treatment model
  - Added treatmentSimulationData property for unified model visualizations
  - Implemented selectTreatment, simulateTreatment, and generateSimulationData methods
  - Added bridge methods for Cycle management (addTreatmentFromCycle, deleteCycleAndTreatment)
  - Added bridge methods to convert between legacy and unified models
  - Added scheduleNotificationsForTreatments for unified model notifications
  - Updated existing methods to work with both legacy and unified models
  - Enhanced Core Data integration to maintain model consistency
  - Added automatic detection and creation of unified models from legacy types
  - Updated default profile creation to use the unified Treatment model
- [x] Update NotificationManager to use unified Treatment model
  - Added scheduleNotifications method for unified Treatment model
  - Updated InjectionRecord to support treatment types
  - Improved notification identification with both legacy and new identifiers
  - Implemented enhanced notification content with treatment type information
  - Added bridge methods for legacy compatibility
  - Updated all notification-related methods to use "treatment" terminology

### UI Components
- [x] Update AIInsightsView to use unified Treatment model
  - Changed to accept treatmentID instead of separate protocolID and cycleID
  - Updated UI text to use "treatment" terminology
  - Implemented fallback mechanism for legacy types during transition
- [x] Update ProfileView to use unified Treatment model
  - Added treatment counts section to display simple and advanced treatments
  - Updated terminology throughout to reference "treatments" instead of "protocols"
  - Added navigation to treatment management screens
  - Enhanced calibration section with treatment-specific information
  - Updated adherence tracking terminology
- [x] Update TreatmentFormView to replace ProtocolFormView
  - Created TreatmentFormAdapter to integrate TreatmentFormView with AppDataStore
  - Added callback hooks to TreatmentViewModel for AppDataStore integration
  - Implemented adapter pattern to allow new TreatmentFormView to work with legacy AppDataStore
  - Created proper bidirectional data flow between ViewModels
- [x] Update InjectionHistoryView to use unified Treatment model
  - Renamed components to use "Treatment" terminology (TreatmentAdherenceStatsView)
  - Added treatment type filtering (simple vs advanced)
  - Updated UI to reflect unified model concepts
  - Improved record display and filtering mechanism
- [ ] Update advanced treatment UI components (replacing cycle-related views)
  - Will need to create new UI components based on Treatment.Stage model
  - Requires updating CycleStageFormView to use unified model
  - Should maintain visual consistency with current UI during transition
- [x] Update ProtocolListView to use unified Treatment model
  - Modified to show simple treatments (filtered by treatmentType)
  - Updated UI to use "Treatments" terminology
  - Implemented new deletion method that works with unified model
  - Enhanced display of treatment information with proper optional handling
- [x] Update visualization components to use unified Treatment model
  - Added layer management to VisualizationModel
  - Implemented layer ordering interface elements
  - Added support for different treatment types
  - Enhanced visualization for multi-stage treatments

## Implementation Issues Encountered and Resolved

1. **Type Conversion Issues:**
   - Fixed incorrect property types between CycleCompoundItem and Treatment.StageCompound
   - Added proper bidirectional conversion methods for stages and their contents
   - Created adapter methods to seamlessly convert between legacy and unified types
   - Implemented proper type checking to handle different treatment types

2. **Core Data Integration:**
   - Fixed naming conflict with Core Data auto-generated methods using renamed methods
   - Created fetchRequestWithID method to avoid conflicts with auto-generated fetchRequest()
   - Added proper serialization for stage compounds and blends in Core Data
   - Ensured backward compatibility for existing data during migration

3. **Immutable Property Issues:**
   - Changed `treatmentType` in Treatment.swift from `let` to `var` to allow modifications
   - Modified property initialization to support both construction and conversion methods
   - Updated accessors to ensure type safety when switching between treatment types

4. **Optional Handling Issues:**
   - Fixed incorrect optional handling for blend components in findCompoundForTreatment
   - Improved optional chain handling in AIInsightsGenerator for safety
   - Added proper nil checks in conversion methods to prevent runtime crashes
   - Implemented graceful fallbacks when conversions between types aren't possible

5. **Bridge Method Implementation:**
   - Successfully implemented bridge methods in AIInsightsGenerator to maintain compatibility
   - Used @available annotations to provide clear migration guidance in IDE
   - Created clear parameter type checks to route requests to the correct implementation
   - Added proper documentation to explain the transition approach

## Unified Model Transition Checklist

As we continue the transition, follow these steps for each component:

1. **For each ViewModel/Service:** ✅
   - ✅ Add methods that accept the unified Treatment model
   - ✅ Add bridge methods that convert from legacy types to Treatment
   - ✅ Add deprecation annotations to legacy methods
   - ✅ Update implementation to use the unified model internally
   - ✅ Completed for: TreatmentViewModel, AIInsightsGenerator, OpenAIService, AppDataStore, NotificationManager

2. **For each View:** 🔄
   - ✅ Update to accept Treatment objects instead of InjectionProtocol/Cycle
   - ✅ Update UI text to use "treatment" terminology instead of "protocol"/"cycle"
   - ✅ Use Treatment.treatmentType to determine UI behavior where needed
   - ✅ Completed for: AIInsightsView, TreatmentFormView, ProtocolListView, InjectionHistoryView, ProfileView
   - ⚠️ Still pending: Advanced treatment UI components (stages, compounds, blends)

3. **For each usage site:** 🔄
   - 🔄 Replace direct usages of legacy types with Treatment
   - ✅ Use conversion methods where needed during transition 
   - 🔄 Ongoing process: Systematically replacing all direct usages

## Transition Strategy for Removing Legacy Code

1. **Phase 1 - Deprecation:** ✅
   - ✅ Add @available(*, deprecated, message: "...") annotations to all legacy types
   - ✅ Create bridge methods for backward compatibility
   - ✅ Update documentation to encourage using the new unified model

2. **Phase 2 - Replacement: (Current Phase)** 🔄
   - 🔄 Systematically replace all direct usages of legacy types with the unified model
   - ✅ Use compiler warnings to identify remaining usages
   - ✅ Keep backward compatibility bridge methods for now
   - ✅ Major components migrated: AppDataStore, NotificationManager, All ViewModels, Most UI components

3. **Phase 3 - Cleanup:** ⏱️
   - ⏱️ Remove all bridge methods after all direct usages are replaced
   - ⏱️ Remove legacy types completely if possible or hide them behind internal access control
   - ⏱️ Remove compatibility code in persistence layer

## Next Steps

1. **Remaining UI Components:**
   - ⚠️ Implement new UI for advanced treatments (stages, compounds, blends)
     - Create UI components for Treatment.Stage model
     - Update CycleStageFormView to work with unified model
     - Maintain visual consistency during transition
   - ⚠️ Update all preview providers to use the unified model
     - Ensure they create realistic treatment data rather than legacy types
     - Update preview factories to support both simple and advanced treatments

2. **Complete NotificationManager:**
   - ⚠️ Add dedicated treatment notification methods for advanced treatments
     - Support stage-specific notifications for advanced treatments
     - Create notification management for treatment stage transitions
   - ⚠️ Update remaining notification content to use "treatment" terminology

3. **Final Phase 2 Tasks:**
   - ⚠️ Identify and replace any remaining direct usage of legacy types
   - ⚠️ Conduct comprehensive testing with unified treatment model
   - ⚠️ Create test suite specific to unified treatment functionality
   - ⚠️ Update all documentation to reference unified treatment model

4. **Prepare for Phase 3 (Cleanup):**
   - ⚠️ Create inventory of all bridge methods to be removed
   - ⚠️ Plan legacy type removal strategy
   - ⚠️ Develop persistence layer cleanup plan
   - ⚠️ Schedule code cleanup sprints

## Recently Completed Work

- **UI Migration for ProfileView:**
  - Updated to use the unified Treatment model with treatment type awareness
  - Added a dedicated Treatments section to display simple and advanced treatment counts
  - Renamed UI elements to use proper "treatment" terminology 
  - Updated Notifications & Adherence section to be treatment-focused
  - Added treatment-specific information to the calibration section
  - Updated AllometricInfoView to reference treatment models
  - Enhanced UI with proper navigation to treatment management screens
  - Improved user experience by providing treatment-specific guidance

- **UI Migration for InjectionHistoryView:**
  - Updated to use the unified Treatment model with proper type filtering
  - Renamed components to use "Treatment" terminology (InjectionAdherenceStatsView → TreatmentAdherenceStatsView)
  - Added segmented control for filtering between simple and advanced treatments
  - Updated treatment picker to filter based on selected treatment type
  - Improved treatment record display with optional handling
  - Enhanced the UI to reflect unified model concepts
  - Renamed UI elements to align with treatment terminology
  - Added support for both simple and advanced treatment types

- **UI Migration for TreatmentFormView and ProtocolListView:**
  - Created TreatmentFormAdapter to integrate existing TreatmentFormView with AppDataStore
  - Added callback hooks in TreatmentViewModel for AppDataStore integration
  - Implemented bidirectional data flow between AppDataStore and TreatmentViewModel
  - Updated ProtocolListView to display unified Treatment model objects
  - Enhanced display of treatment information with proper optional handling
  - Updated UI terminology to use "Treatment" instead of "Protocol"
  - Improved deletion handling to work with unified model
  - Created adapter pattern to allow new UI to work with legacy code
  - Implemented proper property observation with Combine publishers/subscribers

- **AppDataStore Core Data Integration for Unified Model:**
  - Enhanced saveTreatment to properly associate with user profile
  - Implemented detection and creation of missing treatments for existing legacy models
  - Added proper relationship management between user profile and treatments
  - Updated default model creation to use the unified Treatment model directly
  - Added methods to maintain both models during transition period
  - Fixed initialization sequence to properly sync legacy and unified models

- **AppDataStore Cycle Management Bridge Methods:**
  - Added addTreatmentFromCycle for converting legacy cycles to unified treatments
  - Implemented deleteCycleAndTreatment to maintain consistency between models
  - Created selectCycleAsTreatment for visualization with both models
  - Added bridge methods with deprecation annotations for backward compatibility
  - Updated removeProtocol and removeCycles to maintain consistency between models
  - Implemented scheduleNotificationsForTreatments for unified notification support

- **OpenAIService Migration:**
  - Added new methods to work with unified Treatment model
  - Created separate prompt builders for simple and advanced treatments
  - Updated JSON parsing logic to use Treatment model
  - Added deprecated bridge methods for backward compatibility
  - Used consistent method naming with other migrated components

- **AIInsightsGenerator Migration:**
  - Updated to use the unified Treatment model with proper type checking
  - Added robust bridge methods for legacy type compatibility
  - Created complete mock implementation methods for both treatment types
  - Implemented unified method naming convention (generateInsights/generateAdvancedTreatmentInsights)
  - Added detailed documentation comments explaining parameter usage and type expectations

- **AIInsightsView Updates:**
  - Simplified interface by using treatmentID instead of separate protocolID and cycleID
  - Added backwards compatibility for legacy usage during transition period
  - Updated UI text to use "treatment" terminology for consistency
  - Improved error handling and loading state management

- **Documentation:**
  - Added comprehensive migration documentation in ai_docs/insight_generator_migration.md
  - Added detailed documentation in ai_docs/appdata_store_migration.md
  - Updated consolidate.md with current implementation status
  - Added detailed descriptions of completed work and encountered issues
  - Created clear next steps for continuing the migration process
  - Documented bridge method patterns for future component migrations

- **Testing and Validation:**
  - Verified successful build with only expected deprecation warnings
  - Ensured AIInsightsGenerator properly distinguishes between treatment types
  - Validated proper interaction between AIInsightsGenerator and AIInsightsView
  - Confirmed backward compatibility with legacy types works as expected
  - Verified AppDataStore maintains consistency between legacy and unified models
  - Tested bridge methods for proper deprecation annotations and warnings