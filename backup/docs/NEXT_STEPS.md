# TestoSim Migration: Final Steps

This document outlines the final steps needed to complete the migration from legacy models (InjectionProtocol and Cycle) to the unified Treatment model.

## Completed Tasks

✅ Created unified Treatment model  
✅ Created updated views using the unified model  
✅ Updated CoreDataManager to handle migration  
✅ Refactored AppDataStore to delegate to TreatmentViewModel  
✅ Created migration plan  
✅ Updated README with unified model overview  
✅ Created replacement script for updated files  

## Implementation Progress Context

The unified Treatment model implementation is the latest major architectural improvement to TestoSim, building on previously completed work:

| Story | Description | Status |
|-------|-------------|--------|
| 8 | Compound Library & Blends | ✅ 100% Complete |
| 9 | Refined PK Engine | ✅ 100% Complete |
| 10 | User Profile 2.0 & Persistence | ✅ 100% Complete |
| 11 | Notifications & Adherence | ✅ 100% Complete |
| 12 | Cycle Builder | ✅ 100% Complete |
| 13 | AI Insights | ✅ 100% Complete |
| 14 | UI/UX Polish & Animations | ❌ 0% Not Started |
| 15 | Testing & Validation | ❌ 0% Not Started |
| 16 | Help Center & Documentation | ❌ 0% Not Started |

The unified Treatment model specifically enhances and consolidates stories 8 and 12, providing a more coherent architecture for both simple and advanced treatments.

## Unified Model Visualization

Below is a representation of the unified model architecture:

```
Treatment
├── Core Properties (id, name, startDate, notes)
├── TreatmentType (simple, advanced)
├── Simple Treatment Properties
│   ├── doseMg
│   ├── frequencyDays
│   ├── compoundID / blendID
│   ├── selectedRoute
│   └── bloodSamples
└── Advanced Treatment Properties
    ├── totalWeeks
    └── stages: [TreatmentStage]
        ├── name, startWeek, durationWeeks
        ├── compounds: [StageCompound]
        │   └── compoundID, doseMg, frequencyDays, route
        └── blends: [StageBlend]
            └── blendID, doseMg, frequencyDays, route

VisualizationModel
├── Layers: [Layer]
│   ├── CompoundCurve (individual compounds)
│   ├── TotalCurve (combined concentration)
│   ├── AnabolicIndex (anabolic effect metrics)
│   └── AndrogenicIndex (androgenic effect metrics)
└── Statistics
    ├── Concentration metrics
    └── Effect indices and ratios
```

This architecture supports:
- Simple testosterone replacement protocols
- Complex multi-compound cycles with varying schedules
- Detailed pharmacokinetic simulations
- Multi-layered visualizations with compound-specific curves

## Code Conventions & Naming Guidelines

To maintain consistency in the codebase:

| Issue | Convention |
|-------|------------|
| Swift Keywords | Never use Swift reserved keywords (`protocol`, `class`, `struct`, etc.) as variable names |
| Treatment Variables | Use `treatment` for Treatment variables |
| Struct Names | Prefix struct names with context (e.g., `TreatmentStageFormView`, `TreatmentDetailView`) |
| Common Error Avoidance | When looping through treatment collections, always use: `for treatment in treatments` |

## Pending Tasks

### 1. File Replacements

Run the provided script to replace legacy files with their updated versions:

```bash
./rename-updated-files.sh
```

This will:
- Create backups of the original files in a `backup` directory
- Replace legacy files with their updated counterparts
- Preserve the original file names to maintain compatibility

### 2. Fix Import References

Search for and update any imports that may be affected by the file replacements:

```swift
// Example: Update imports in affected files
import ProtocolModel   // Change to: import Treatment
```

### 3. Legacy Model Cleanup

Remove or mark as deprecated the following legacy files:

- `TestoSim/Models/ProtocolModel.swift`
- `TestoSim/Models/CycleModel.swift`
- `TestoSim/Models/TreatmentCoreDataExtensions.swift` (already removed)

### 4. Update Core Data Model

The Core Data model has been updated with new properties, but you may need to perform migration testing:

1. Test with sample data to ensure all properties are correctly migrated
2. Check that legacy `CDInjectionProtocol` and `CDCycle` entities can be converted to `CDTreatment`

Key visualization entities to verify:
- Proper serialization of `Treatment.StageCompound` and `Treatment.StageBlend` data
- Correct relationship between `CDTreatment` and its stages
- Preservation of blood sample relationships

### 5. Update Tests

Migrate any tests that use the old models to the new unified model:

- Update `TestoSimTests/TestoSimTests.swift`
- Update `TestoSimTests/TreatmentModelTests.swift`

Focus on validation tests for:
1. PK model accuracy 
2. Treatment stage simulation
3. Effect index calculations

Use these validation targets:
| Test     | Target                                                             | Pass criteria |
| -------- | ------------------------------------------------------------------ | ------------- |
| **Unit** | 250 mg Test E single IM → C_max ≈ 1540 ng/dL @ 72 h; 50% peak by day 9 | Δ ≤ 10%       |
| **Unit** | 100 mg Tren A Q2D × 14 d steady-state ~6× baseline                 | Δ ≤ 10%       |
| **UI**   | Treatment form and visualization interaction                        | No crashes    |
| **Perf** | Simulate 5-compound 20-week plan                                   | < 50 ms avg   |

### 6. Build and Test

Complete thorough testing to ensure the migration works as expected:

1. Verify all views render correctly
2. Test data persistence and retrieval
3. Test migration from legacy data
4. Test visualization features
5. Test notifications

### 7. Documentation Updates

Update documentation to reflect the new unified model:

1. Update inline code documentation with proper JSDoc-style comments
2. Create architecture diagrams if needed
3. Document common patterns and usage examples

### 8. Future Considerations

Consider these items for future development:

1. Complete removal of legacy model types (once migration is stable)
2. Enhanced visualization features leveraging the unified model
   - Time scale transitions for visualizations
   - Improved interactive charts
   - Enhanced visual design with proper animation
3. Additional metrics and analytics based on the new data structure
4. UX improvements based on the unified model's capabilities

## Testing Checklist

### Basic Functionality
- [ ] Create new simple treatment
- [ ] Create new advanced treatment
- [ ] Add stages to advanced treatments
- [ ] Edit existing treatments
- [ ] Delete treatments

### Bloodwork and Visualization
- [ ] Add blood samples and calibrate
- [ ] Check visualization for all treatment types
- [ ] Verify layer visibility controls work
- [ ] Test effect index calculations

### System Integration
- [ ] Test notifications
- [ ] Test data migration from legacy formats
- [ ] Test iCloud sync
- [ ] Verify proper UI rendering on multiple device sizes

## Resolution Strategy

If issues are found during testing:

1. Check the backup files to compare behaviors
2. Use the migration path to troubleshoot data inconsistencies
3. Consult the MIGRATION_PLAN.md for details on the intended architecture
4. Consider implementing a feature flag to toggle between legacy and unified models during the transition period

## Priority Items for UI/UX Enhancement (After Unified Model)

After completing the unified model migration, focus on these visual enhancements:

1. **Chart Component Architecture**
   - Create flexible visualization components for the unified model
   - Implement smooth transitions between time scales
   - Add interactive elements for data exploration

2. **Progressive Disclosure Implementation**
   - Layer information appropriately for advanced treatments
   - Create expandable sections for detailed stage information
   - Implement information hierarchy for visualization layers

3. **Visual Design System**
   - Update color palette for treatment type differentiation
   - Create consistent styling for simple vs. advanced treatments
   - Implement consistent animation patterns

These enhancements will build on the solid foundation provided by the unified Treatment model.