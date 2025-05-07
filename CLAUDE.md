# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

```bash
# Build without launching simulator (recommended)
./build-test.sh [clean]    # Add "clean" parameter for clean build

# Close all simulators (useful when multiple are running)
./close-simulators.sh

# Build, install, and launch in a specific simulator
./launch-test.sh [device_name]    # e.g., ./launch-test.sh "iPhone 16 Pro"
```

### Viewing Device Logs

```bash
xcrun simctl spawn booted log stream --predicate 'processImagePath contains "TestoSim"' --style compact
```

## Project Architecture

### Core Concepts

TestoSim is a pharmacokinetics simulation app for testosterone and related compounds. It helps visualize injection protocols and predicts hormone levels over time.

1. **Unified Treatment Model**: The core model (`Treatment.swift`) integrates both simple and advanced treatment protocols:
   - Simple treatment: Single compound/blend with fixed schedule
   - Advanced treatment: Multi-stage protocol with varying compounds/doses over time

2. **Compound System**:
   - `Compound`: Individual substances with pharmacokinetic parameters
   - `VialBlend`: Combinations of compounds in specific ratios

3. **Visualization System**:
   - Multi-layered visualization model with different chart types
   - Shows compound concentrations, total levels, and anabolic/androgenic indices
   - Charts can be customized with layer visibility and opacity controls

4. **Core Data + CloudKit**:
   - Data persistence with CoreData and optional iCloud synchronization
   - Migration paths for legacy data models to unified treatment model

### Key Components

1. **Models**:
   - `Treatment`: Unified treatment model replacing older Protocol/Cycle models
   - `Compound`: Pharmacokinetic properties of individual substances
   - `VialBlend`: Multi-compound injectable blends
   - `PKModel`: Pharmacokinetic calculations
   - `VisualizationModel`: Chart and visualization data structure

2. **ViewModels**:
   - `TreatmentViewModel`: Manages treatment data and visualization
   - `CoreDataManager`: Handles data persistence and CloudKit integration
   - `AppDataStore`: Central store for application data
   - `AIInsightsGenerator`: Integrates with OpenAI for analysis

3. **Views**:
   - Treatment creation/editing
   - Visualization and charting
   - Compound and blend management
   - Profile and configuration

### Technical Framework

- **Swift/SwiftUI**: UI is built with SwiftUI
- **CoreData**: Persistence framework with CloudKit integration
- **OpenAI Integration**: Uses OpenAI API for protocol insights
- **Configuration**: Uses Config.xcconfig and Config.plist (excluded from git)

## Important Implementation Notes

### API Keys

- API keys are stored in Config.plist and Config.xcconfig (not in repository)
- Sample files (Config-Sample.plist, Config-Sample.xcconfig) are included
- The copy-config.sh script creates real config files from samples on first build

### CloudKit Integration

- App uses NSPersistentCloudKitContainer for Core Data + CloudKit integration
- CloudKit sync can be toggled with the `usesICloudSync` user default
- Container ID is "iCloud.flight505.TestoSim"

### Data Migration

- The system supports migration from legacy protocol/cycle models to the unified treatment model
- `migrateAllToUnifiedModel()` in TreatmentViewModel handles this migration
- There's also legacy JSON to CoreData migration support in CoreDataManager
- Consolidate.md contains a checklist for correctly migrating to the new treatment model

### Treatment Models and Visualization

1. The new unified treatment model supports both simple and multi-stage advanced treatments
2. Visualization uses a multi-layered approach where each compound/metric is a separate layer
3. Layers can be toggled on/off and have adjustable opacity
4. The system calculates anabolic and androgenic indices based on compound properties

### Key Takeaways

1. **Type Design Considerations**
   - ALWAYS ensure types are consistent in nullability between legacy and new models
   - When creating conversion methods, match property types exactly to avoid subtle errors
   - Use explicit type annotations to avoid type inference issues during conversion
2. **Immutability Challenges**
   - Be cautious with let properties that might need to change (e.g., treatmentType)
   - Consider future flexibility when deciding between let and var for model properties
   - Review all consumer code to understand how properties are used before deciding on mutability
3. **Optional Handling Best Practices**
   - Pay close attention to optionality differences in APIs (e.g., compoundID in one struct was optional while non-optional in another)
   - Use explicit conditional binding with proper optionality checks
   - Avoid force unwrapping optionals during conversion processes
4. **Deprecation Strategy**
   - Early use of @available(*, deprecated, message: "...") annotations helps identify all usages
   - Include clear guidance in deprecation messages about what to use instead
   - Mark both model types AND their extensions as deprecated for complete coverage
5. **Methodical Transition Approach**
   - Inside-out approach works best: Core models → ViewModels → UI components
   - Module-by-module replacement prevents scattered, incomplete transitions
   - Always ensure tests pass after each module's conversion

### Do's and Don'ts

**Do's**
- ✅ Create bidirectional conversion methods between legacy and new models
- ✅ Add comprehensive deprecation annotations to legacy types and extensions
- ✅ Update Core Data entities and persistency code before UI components
- ✅ Maintain feature parity during transition
- ✅ Create clear checkpoints and validation criteria for the transition

**Don'ts**
- ❌ Don't assume type compatibility between similar models without verification
- ❌ Don't leave properties as immutable (let) if they might need to change
- ❌ Don't mix legacy and new models in the same component without clear conversion
- ❌ Don't remove legacy code until all its usages are replaced
- ❌ Don't rush through complete codebase changes - follow a systematic approach

### Lessons from Core Data Migration & Legacy Code Replacement

**Key Technical Insights**

1. **Method Naming for Core Data Classes**
   - Avoid naming conflicts with auto-generated Core Data methods (e.g., fetchRequest)
   - Use distinctive naming patterns like fetchRequestWithID() instead of fetchRequest(forID:)
   - Always check generated CoreData interfaces before adding custom methods
2. **Systematic Approach to Legacy Code Warnings**
   - Deprecation annotations work as intended, highlighting usage throughout the codebase
   - Build warnings provide a clear roadmap of files that need updating
   - Inside-out approach (models → ViewModels → UI) is confirmed as the right strategy
3. **Progressive Data Migration Setup**
   - CoreDataManager was already properly configured with shouldMigrateStoreAutomatically = true
   - Notification observers for migration events were in place
   - No custom mapping model was needed due to the direct conversion methods in model classes
4. **Code Organization Patterns**
   - Well-designed conversion methods between legacy and unified models simplify migration
   - ViewModels with conditional loading (try unified first, fall back to legacy) provide smooth transition
   - Keeping legacy code functional during transition ensures app stability

**Do's and Don'ts**

Do's
- ✅ Verify auto-generated Core Data code before adding custom extensions
- ✅ Use clear method naming that avoids conflicts with framework-provided methods
- ✅ Use deprecation warnings as a guided checklist for systematic replacement
- ✅ Complete the inside layers (data/models) before moving to outside layers (UI)
- ✅ Test builds regularly to catch issues early in the migration process

Don'ts
- ❌ Don't assume method names are available for use with Core Data entities
- ❌ Don't attempt to replace all legacy code at once; follow a systematic approach
- ❌ Don't modify UI components until the underlying models and ViewModels are updated
- ❌ Don't remove deprecated types until all their usages are replaced
- ❌ Don't forget to update fetch requests when method names change