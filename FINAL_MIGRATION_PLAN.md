# TestoSim Unified Treatment Model: Final Migration Plan

## Overview

This document provides a comprehensive plan for completing the migration from legacy models (InjectionProtocol and Cycle) to the unified Treatment model. The unified model is designed to consolidate both simple and advanced treatments into a single cohesive data structure, simplifying the architecture while maintaining all functionality.

## Current Status

The unified Treatment model has been implemented and is ready for use. Several components have been updated to work with the new model, but the migration is not yet complete:

✅ Unified Treatment model fully implemented  
✅ Core Data entities for the unified model created  
✅ TreatmentViewModel implemented for managing the unified model  
✅ Bidirectional conversion between legacy and unified models  
✅ Updated UI components created (but not yet deployed)  
✅ Pharmacokinetic integration with the unified model  
✅ Multi-layered visualization system  

## Migration Tasks

### 1. File Replacements

Replace the legacy files with their updated counterparts:

| Legacy File | Replacement File | Status |
|-------------|-----------------|--------|
| `AppDataStore.swift` | `AppDataStore_Refactored.swift` | Ready to replace |
| `CoreDataManager.swift` | `CoreDataManager_Updated.swift` | Ready to replace |
| `ContentView.swift` | `ContentView_Updated.swift` | Ready to replace |
| `ProtocolFormView.swift` | `TreatmentFormView_Updated.swift` | Ready to replace |
| `ProtocolDetailView.swift` | `TreatmentDetailView_Updated.swift` | Ready to replace |
| `CyclePlannerView.swift` | `AdvancedTreatmentView.swift` | Ready to replace |
| `AddBloodworkView.swift` | `AddBloodworkView_Updated.swift` | Ready to replace |

**Action:** Run the `rename-updated-files.sh` script to perform the replacements and create backups of the original files.

```bash
./rename-updated-files.sh
```

### 2. Fix Import References

After replacing the files, update any imports that reference the legacy models:

1. Search for legacy import references:
   - `import ProtocolModel`
   - `import CycleModel`

2. Replace with:
   - `import Foundation` (if no other models are needed)
   - Or add specific imports as needed

3. Address any remaining compilation errors related to:
   - Renamed properties
   - Changed method signatures
   - Updated model references

### 3. Remove Legacy Models

Remove or mark as deprecated the following files:

- `TestoSim/Models/ProtocolModel.swift`
- `TestoSim/Models/CycleModel.swift`
- `TestoSim/Models/TreatmentCoreDataExtensions.swift` (already removed)

If there are still components that depend on these models, mark them as deprecated with appropriate Swift annotations:

```swift
@available(*, deprecated, message: "Use Treatment model instead")
struct InjectionProtocol {
    // ...
}
```

### 4. Update Core Data Model

1. Verify Core Data migration path:
   - Test with sample data to ensure all properties are correctly migrated
   - Verify that legacy `CDInjectionProtocol` and `CDCycle` entities can be converted to `CDTreatment`

2. Key Core Data entities to verify:
   - `CDTreatment` - Main entity for all treatments
   - `CDTreatmentStage` - Entity for stages within advanced treatments
   - `CDBloodSample` - Entity for blood test samples linked to treatments

3. Check JSON serialization for complex structures:
   - Proper serialization of `Treatment.StageCompound` and `Treatment.StageBlend` data
   - Correct relationship between `CDTreatment` and its stages
   - Preservation of blood sample relationships

### 5. Update Tests

1. Update unit tests to use the unified model:
   - `TestoSimTests/TestoSimTests.swift`
   - `TestoSimTests/TreatmentModelTests.swift`

2. Focus on validation tests for:
   - PK model accuracy
   - Treatment stage simulation
   - Effect index calculations

3. Use these validation targets:

| Test     | Target                                                      | Pass criteria |
|----------|-------------------------------------------------------------|---------------|
| **Unit** | 250 mg Test E single IM → C_max ≈ 1540 ng/dL @ 72 h; 50% peak by day 9 | Δ ≤ 10%       |
| **Unit** | 100 mg Tren A Q2D × 14 d steady-state ~6× baseline          | Δ ≤ 10%       |
| **UI**   | Treatment form and visualization interaction                | No crashes    |
| **Perf** | Simulate 5-compound 20-week plan                            | < 50 ms avg   |

### 6. UI/UX Integration

1. Verify all updated views render correctly:
   - `TreatmentFormView` (replaces `ProtocolFormView`)
   - `TreatmentDetailView` (replaces `ProtocolDetailView`)
   - `AdvancedTreatmentView` (replaces `CyclePlannerView`)
   - `AddBloodworkView` (updated version)

2. Update navigation flows:
   - Update tab view labels to use unified terminology
   - Ensure proper view transitions and state management
   - Verify data persistence across navigation

3. Test visualization components:
   - Verify multi-layered visualization works for all treatment types
   - Check layer visibility controls and customization options
   - Test effect index calculations and display

### 7. Documentation Updates

1. Update inline code documentation with proper comments:
   - Add clear descriptions of public methods and properties
   - Document complex algorithms and calculations
   - Add examples for key components

2. Create architecture diagrams showing:
   - Unified model structure
   - Relationship between components
   - Data flow through the application

## Testing Checklist

### Basic Functionality
- [ ] Create simple treatment
- [ ] Create advanced treatment
- [ ] Add stages to advanced treatments
- [ ] Edit existing treatments
- [ ] Delete treatments
- [ ] Convert between simple and advanced treatments

### Bloodwork and Visualization
- [ ] Add blood samples
- [ ] Calibrate using blood samples
- [ ] Check visualization for simple treatments
- [ ] Check visualization for advanced treatments
- [ ] Verify layer visibility controls
- [ ] Test effect index calculations

### System Integration
- [ ] Test notifications
- [ ] Test data migration from legacy formats
- [ ] Test iCloud sync
- [ ] Verify UI on multiple device sizes

## Code Conventions & Naming Guidelines

To maintain consistency in the codebase:

| Issue | Convention |
|-------|------------|
| Swift Keywords | Never use Swift reserved keywords (`protocol`, `class`, `struct`, etc.) as variable names |
| Treatment Variables | Use `treatment` for Treatment variables |
| Struct Names | Prefix struct names with context (e.g., `TreatmentStageFormView`, `TreatmentDetailView`) |
| Common Error Avoidance | When looping through treatment collections, always use: `for treatment in treatments` |

## Unified Model Architecture

The unified Treatment model combines both simple and advanced treatments:

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

## Implementation Progress Context

The unified Treatment model is part of the broader application development:

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

## Future UI/UX Enhancements (Story 14)

After completing the unified model migration, focus will shift to these visual enhancements:

### 1. Chart Component Architecture

- Create a flexible `ChartContainer` component
  - Implement time scale switching capabilities
  - Add data aggregation functionality based on selected time scale
  - Build state management for smooth transitions
  - Implement progressive disclosure pattern with expandable views

- Design component hierarchy with separation of concerns
  - Build `TimeScaleSelector` component with options for '4-week', 'quarterly', 'all-time'
  - Create `TestosteroneLineChart` for core visualization
  - Implement `ReferenceRangeOverlay` to show normal ranges
  - Add `InteractionLayer` for user selection and tooltips

### 2. Time Scale Implementation

- Build dedicated `TimeScaleManager` class
  - Implement 4-week view with daily precision
  - Create intermediate view (3-6 months) with weekly aggregation
  - Design all-time view with monthly/quarterly aggregation
  - Add trend highlighting for long-term views

- Create smooth transitions between time scales
  - Implement animation system for transitioning between scales (300-500ms duration)
  - Maintain context when switching by keeping focal point consistent
  - Add calculation for proper data aggregation based on scale
  - Implement intelligent date formatting that adapts to each scale

### 3. Dashboard Optimization with Pre-attentive Principles

- Redesign dashboard layout following NN/g principles
  - Place critical metrics in upper-left corner (current level and days until next dose)
  - Group related metrics visually using consistent spacing and subtle backgrounds
  - Implement clean information hierarchy with 5-7 key metrics maximum
  - Create visual distinction between primary and secondary metrics

- Optimize pre-attentive attributes
  - Use length-based visualizations (bar charts) for comparing quantities
  - Implement 2D position (line charts) for showing relationships over time
  - Apply color strategically as secondary attribute for highlighting
  - Create sufficient white space between information groups

### 4. Chart Visualization Enhancement

- Implement Apple HIG "Charting Data" principles
  - Create uncluttered axes with minimal but sufficient gridlines
  - Design clear call-outs for important data points
  - Implement proper data range scaling to maximize visibility
  - Add contextual information display around chart

- Add Swift Charts 2D interactions
  - Implement scroll-zoom functionality for exploring data
  - Create selection marks for important data points
  - Add pinch-to-zoom gesture support
  - Implement double-tap to reset view

### 5. Animation System

- Create curve reveal animations
  - Implement easeInOut animation for data presentation (1.2s duration)
  - Create sequential animation for multi-dataset charts
  - Add fade-in effects for chart elements (axes, labels, gridlines)
  - Design visual transitions for data updates

- Implement micro-animations for user feedback
  - Create subtle animations for user interactions (150-200ms)
  - Design feedback animations for selections and taps
  - Implement loading states with branded skeleton screens
  - Add subtle pulse animations for highlighting new data

- Add celebration animations
  - Design milestone celebration animations (800-1200ms)
  - Create visual feedback for completing injections
  - Implement progress celebrations for adherence achievements
  - Add confetti or similar effects for major milestones

### 6. Haptic and Sound Integration

- Implement haptic feedback system
  - Add light impact haptics for selections and navigation
  - Design medium impact haptics for confirming injections
  - Create notification haptics for reminders
  - Implement success haptics for completed actions

- Add sound design
  - Create subtle sound effects for primary interactions
  - Design success sounds for completed injections
  - Implement notification sounds for reminders
  - Add option to disable sounds in settings

### 7. Visual Design System

- Create focused color palette
  - Implement primary palette with deep blues and teal accents
  - Design accent colors (vibrant orange/red) for highlighting
  - Create semantic color system (green for improvements, red for declines)
  - Ensure proper contrast ratios for accessibility

- Design typography system
  - Implement SF Pro (iOS native) font family
  - Create clear hierarchy with 2-3 weights
  - Define consistent text sizes for different UI elements
  - Ensure proper line height and letter spacing for readability

- Build dark mode compatibility
  - Create semantic color assets that adapt to light/dark mode
  - Design dark mode variants of all UI components
  - Adjust contrast and brightness appropriately for dark mode
  - Test color combinations in both modes for accessibility

### 8. Component Pattern Implementation

- Create card-based organization system
  - Design subtle shadows and rounded corners (consistent 8px or 12px radius)
  - Implement proper elevation hierarchy (1-3 levels of cards)
  - Create consistent internal padding (16px or 20px)
  - Add subtle hover/press states for interactive cards

- Build navigation patterns
  - Implement bottom tab navigation for main sections
  - Create floating action buttons for primary actions
  - Design slide-up sheets for detailed information
  - Add animation for navigation transitions

- Define spacing system
  - Create 8px increment-based spacing system
  - Implement consistent margins between UI elements
  - Design proper whitespace distribution
  - Create balanced component density

### 9. Nike-Inspired Visual Elements

- Implement minimalist chart styling
  - Create clean, thin chart lines with subtle animations
  - Design ample white space around charts
  - Add subtle gradient fills under trend lines
  - Implement subtle grid lines that don't compete with data

- Create performance zone visualization
  - Design color-coded zones for different testosterone ranges
  - Implement subtle background color bands for zones
  - Add indicators for optimal ranges
  - Create tooltips explaining each zone

- Build consistent visual language
  - Design unified icon system
  - Create consistent corner radius across all elements
  - Implement uniform shadow treatment
  - Design consistent animation timing across UI

### 10. Progressive Disclosure Implementation

- Create layered information architecture
  - Design summary views that expand to detailed charts
  - Implement "Learn more" expansions for complex information
  - Create hierarchy of importance for displayed metrics
  - Build collapsible sections for detailed information

- Implement interaction patterns for exploration
  - Design clear affordances for expandable content
  - Create smooth transitions for expanding/collapsing
  - Add breadcrumbs for navigating complex data
  - Implement information tooltips for advanced metrics

### 11. Component Implementation Examples

#### Current Level Dashboard Card

```swift
// Example structure for CurrentLevelCard
struct CurrentLevelCard: View {
    @ObservedObject var dataStore: AppDataStore
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with current level
            HStack {
                Text("Current Level")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                // Trend indicator
                TrendIndicator(change: dataStore.levelChange)
            }
            
            // Primary value with large display
            Text("\(formattedCurrentLevel) ng/dL")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            
            // Days until next dose
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.accentColor)
                Text("\(dataStore.daysUntilNextDose) days until next dose")
                    .font(.callout)
            }
            
            // Expand button
            Button {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            } label: {
                Text(isExpanded ? "Show less" : "Show chart")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .buttonStyle(.plain)
            
            // Expanded chart
            if isExpanded {
                TestosteroneChart(data: dataStore.recentLevels)
                    .frame(height: 200)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.primary.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
    
    private var formattedCurrentLevel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: dataStore.currentLevel)) ?? "0"
    }
}
```

#### Time Scale Selector with Transitions

```swift
struct TimeScaleSelector: View {
    @Binding var selectedTimeScale: TimeScale
    @State private var isTransitioning = false
    let onChange: (TimeScale) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Segmented control
            Picker("Time Scale", selection: $selectedTimeScale) {
                Text("4 Week").tag(TimeScale.fourWeek)
                Text("Quarterly").tag(TimeScale.quarterly)
                Text("All Time").tag(TimeScale.allTime)
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedTimeScale) { newScale in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isTransitioning = true
                }
                
                // Allow time for animation to start
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    onChange(newScale)
                }
                
                // Reset transition state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTransitioning = false
                }
            }
            
            // Date range display
            Text(dateRangeText)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .cornerRadius(8)
    }
    
    private var dateRangeText: String {
        switch selectedTimeScale {
        case .fourWeek:
            return "Last 28 days"
        case .quarterly:
            return "Last 3 months"
        case .allTime:
            return "Complete history"
        }
    }
}

enum TimeScale {
    case fourWeek, quarterly, allTime
}
```

#### Testosterone Chart with Animations

```swift
struct TestosteroneChart: View {
    let data: [DataPoint]
    @State private var showChart = false
    @State private var selectedPoint: DataPoint?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Chart title
            Text("Testosterone Levels")
                .font(.headline)
                .padding(.horizontal)
            
            // Chart container
            Chart {
                // Reference range area
                RectangleMark(
                    xStart: .value("Start", data.first?.date ?? Date()),
                    xEnd: .value("End", data.last?.date ?? Date()),
                    yStart: .value("Min", 350),
                    yEnd: .value("Max", 1000)
                )
                .foregroundStyle(Color.green.opacity(0.1))
                .cornerRadius(4)
                
                // Data line
                if showChart {
                    LineMark(
                        x: .value("Date", data.map { $0.date }),
                        y: .value("Level", data.map { $0.level })
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .foregroundStyle(Color.accentColor.gradient)
                    .interpolationMethod(.catmullRom)
                    
                    // Data points
                    ForEach(data) { point in
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Level", point.level)
                        )
                        .foregroundStyle(Color.accentColor)
                        .symbolSize(point.id == selectedPoint?.id ? 120 : 60)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel() {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic) { value in
                    AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel() {
                        if let level = value.as(Double.self) {
                            Text("\(Int(level))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(height: 220)
            .padding(.horizontal, 8)
            .padding(.bottom)
            .onAppear {
                // Animate chart appearance
                withAnimation(.easeInOut(duration: 1.2)) {
                    showChart = true
                }
            }
            
            // Selected point details
            if let selectedPoint = selectedPoint {
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text(selectedPoint.date.formatted(.dateTime.day().month().year()))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(Int(selectedPoint.level)) ng/dL")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    StatusIndicator(level: selectedPoint.level)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let x = value.location.x - geometry.frame(in: .local).minX
                                if let (date, _) = proxy.value(atX: x),
                                   let nearestPoint = findNearestPoint(to: date) {
                                    selectedPoint = nearestPoint
                                    HapticFeedback.selection.trigger()
                                }
                            }
                    )
            }
        }
    }
    
    private func findNearestPoint(to date: Date) -> DataPoint? {
        guard !data.isEmpty else { return nil }
        
        return data.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
}
```

### 12. Animation and Transition Strategy

- Define a consistent animation timing system
  - Quick feedback: 150-200ms
  - UI transitions: 300-500ms
  - Progress celebrations: 800-1200ms
  - Data visualizations: 1000-1500ms

- Create a centralized animation manager
  - Define standard curves for different interaction types
  - Create consistent entry/exit animations for views
  - Design staggered animations for related elements
  - Implement spring animations for natural movements

- Build celebration animation system
  - Create success animations for completed injections
  - Design milestone celebrations for adherence achievements
  - Implement subtle progress indicators
  - Add confetti or similar effects for major milestones

## Help Center Architecture (Story 16)

After the UI/UX polish, work on the in-app help center:

1. Core Help Center Architecture
   - Create `HelpCenterView` as the main entry point for all documentation
   - Implement topic-based navigation with hierarchical structure
   - Create consistent visual styling and interactive elements
   - Design for high readability with appropriate typography and spacing
   - Add global access through navigation bar help button

2. PK Model Documentation
   - Create detailed explanations of the two-compartment model
   - Develop interactive visualizations showing compound movement between compartments
   - Include scientific foundation with simplified explanations
   - Provide practical examples showing how the model predicts real-world concentrations
   - Explain key pharmacokinetic parameters (ke, ka, α, β, Vd)

3. Educational Content Modules
   - **PKModelExplanationView**: Two-compartment model details and benefits
   - **AllometricScalingView**: Enhanced version of existing content
   - **ApplicationGuideView**: Practical usage tutorials
   - **CyclePlannerGuideView**: Multi-compound cycle documentation

## Resolution Strategy

If issues are encountered during migration:

1. Check backup files to compare behaviors
2. Use bidirectional conversion to troubleshoot data inconsistencies
3. Consider implementing a feature flag to toggle between legacy and unified models during testing
4. Prioritize fixing core functionality before addressing visual enhancements

## Conclusion

The unified Treatment model provides significant benefits:

1. **Simplified Architecture**: Single model for all treatment types reduces complexity
2. **Improved Maintainability**: Clearer separation of concerns in the codebase
3. **Enhanced User Experience**: Consistent UI approach for different treatment types
4. **Future-Proof Design**: More flexible model allows for future enhancements
5. **Performance Optimization**: Streamlined code with fewer redundant operations

By following this migration plan, we can ensure a smooth transition from the legacy models to the unified Treatment model, while maintaining all existing functionality and preparing for future enhancements.