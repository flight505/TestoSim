# AIInsightsGenerator Migration

This document outlines the migration of the `AIInsightsGenerator` class to the unified Treatment model in TestoSim.

## Changes Made

1. Updated the main insight generation methods to work with the unified `Treatment` model:
   - Renamed `generateInsights(for treatmentProtocol: InjectionProtocol, ...)` to `generateInsights(for treatment: Treatment, ...)`
   - Renamed `generateCycleInsights(for cycle: Cycle, ...)` to `generateAdvancedTreatmentInsights(for treatment: Treatment, ...)`

2. Added bridge methods to maintain backward compatibility:
   - Kept the original methods with `@available(*, deprecated, message: "...")` annotations
   - Added conversion from legacy types to the unified Treatment model

3. Updated mock implementation methods:
   - Created `createMockInsightsForSimpleTreatment` (replacing `createMockInsightsForProtocol`)
   - Created `createMockInsightsForAdvancedTreatment` (replacing `createMockInsightsForCycle`)
   - Created `createMockBlendExplanationForTreatment` (replacing `createMockBlendExplanation`)
   - Added corresponding deprecated bridge methods for backward compatibility

4. Updated `AIInsightsView` to work with the unified Treatment model:
   - Replaced separate `protocolID` and `cycleID` fields with a unified `treatmentID`
   - Updated the insight generation process to check for a Treatment first, then fall back to legacy types during the transition period
   - Updated UI text to reference "treatments" instead of "protocols" or "cycles"

## Structure of the Unified Approach

The `AIInsightsGenerator` now follows a unified approach:

1. **Main public methods:**
   - `generateInsights(for treatment: Treatment, ...)` - For simple treatments
   - `generateAdvancedTreatmentInsights(for treatment: Treatment, ...)` - For advanced treatments

2. **Mock implementation methods (private):**
   - `generateMockInsights(for treatment: Treatment, ...)` - For simple treatments
   - `generateMockAdvancedTreatmentInsights(for treatment: Treatment, ...)` - For advanced treatments

3. **Insight creation methods (private):**
   - `createMockInsightsForSimpleTreatment(_ treatment: Treatment, ...)` - For simple treatments
   - `createMockInsightsForAdvancedTreatment(_ treatment: Treatment, ...)` - For advanced treatments
   - `createMockBlendExplanationForTreatment(_ treatment: Treatment, ...)` - For blends in simple treatments

4. **OpenAI service methods (coming next):**
   - `makeOpenAIAPICall(for treatment: Treatment, ...)`

## Next Steps

1. Update the `OpenAIService` to work directly with the unified Treatment model:
   - Add methods that accept Treatment instead of InjectionProtocol or Cycle
   - Add bridge methods for backward compatibility

2. Update remaining views that use the AIInsightsGenerator:
   - Update all views to pass Treatment objects instead of InjectionProtocol or Cycle objects

3. Remove backward compatibility methods once all direct usages are migrated:
   - After all call sites are updated, remove the legacy deprecated methods

## Implementation Pattern

This migration follows the inside-out approach defined in the unified treatment model transition plan:

1. Update core models first (done previously with Treatment.swift)
2. Update ViewModels next (this current work with AIInsightsGenerator)
3. Update UI components last (started with AIInsightsView)

The bridge methods ensure that the system continues to function during the transition, with proper deprecation warnings to guide further code changes.