# TestoSim Migration Plan

## Overview

This document outlines the plan for migrating TestoSim from using legacy models (InjectionProtocol and Cycle) to the unified Treatment model. The migration will be performed incrementally to minimize disruption to users.

## Current Status

- The unified Treatment model has been fully implemented
- New UI components using the unified model have been created
- AppDataStore has been refactored to leverage the unified model
- Core Data entities for the unified model are in place

## Migration Steps

### Phase 1: Preparation (Completed)

- ✅ Create the unified Treatment model
- ✅ Implement bidirectional conversion between legacy and unified models
- ✅ Update Core Data entities for the unified model
- ✅ Create a TreatmentViewModel to manage the unified model

### Phase 2: Refactoring (Completed)

- ✅ Refactor AppDataStore to delegate to the unified model
- ✅ Create updated UI components that use the unified model
- ✅ Resolve TODOs in CoreDataManager

### Phase 3: View Migration (In Progress)

1. **ContentView Updates**
   - Replace tab labels with unified terminology
   - Update navigation structure to point to new views

2. **ProtocolListView Migration**
   - Create a new TreatmentListView that replaces ProtocolListView
   - Filter treatments by .simple type in the list
   - Update sorting and filtering options

3. **CyclePlannerView Migration**
   - Create an AdvancedTreatmentView that replaces CyclePlannerView
   - Filter treatments by .advanced type in the list
   - Ensure all stage management functions work with the unified model

4. **Detail View Migration**
   - Replace ProtocolDetailView with TreatmentDetailView
   - Replace CycleDetailView with TreatmentDetailView (filtered for advanced treatments)
   - Update all charts and visualizations to use the unified model

5. **Form View Migration**
   - Replace ProtocolFormView with TreatmentFormView
   - Replace CycleFormView with AdvancedTreatmentFormView
   - Ensure all form validation and submission flows work correctly

### Phase 4: Legacy Code Removal

1. **Remove Legacy Model References**
   - Remove InjectionProtocol, Cycle, and CycleStage references
   - Update all imports to use the unified model

2. **Remove Bridge Methods**
   - Remove deprecated bridge methods from AppDataStore
   - Clean up temporary backward compatibility code

3. **Clean Up Core Data Entities**
   - Mark legacy entities as optional or remove them if safe
   - Ensure migration paths for user data remain intact

4. **Update Tests**
   - Migrate unit tests to use the unified model
   - Add new tests for the unified model functionality

### Phase 5: Final Cleanup and Testing

1. **Code Quality**
   - Remove any remaining TODOs and FIXMEs
   - Ensure consistent naming across the codebase
   - Run SwiftLint or similar tool to enforce style guidelines

2. **Testing**
   - Test all user flows on multiple devices
   - Verify data migration works correctly
   - Check backward compatibility where needed

3. **Documentation**
   - Update inline documentation for the unified model
   - Document common patterns and conventions
   - Create cheat sheets for developers

## File Replacements

| Legacy File | Replacement File | Status |
|-------------|-----------------|--------|
| `ProtocolFormView.swift` | `TreatmentFormView_Updated.swift` | Created |
| `ProtocolDetailView.swift` | `TreatmentDetailView_Updated.swift` | Created |
| `AddBloodworkView.swift` | `AddBloodworkView_Updated.swift` | Created |
| `CyclePlannerView.swift` | `AdvancedTreatmentView.swift` | To Do |
| `AppDataStore.swift` | `AppDataStore_Refactored.swift` | Created |
| `CoreDataManager.swift` | `CoreDataManager_Updated.swift` | Created |

## Timeline

1. **Phase 3: View Migration** - 1-2 weeks
2. **Phase 4: Legacy Code Removal** - 1 week
3. **Phase 5: Final Cleanup and Testing** - 1 week

## Risks and Mitigation

- **Data Loss**: Ensure backward compatibility and thorough testing
- **Performance Issues**: Profile and optimize as needed
- **UI/UX Consistency**: Review designs with stakeholders
- **Migration Bugs**: Implement comprehensive unit tests

## Success Criteria

- All features work with the unified model
- No legacy model references remain in the codebase
- All tests pass
- No data loss during migration
- Clean architecture with clear separation of concerns