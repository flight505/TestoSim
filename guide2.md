# TestoSim Implementation Progress

## Progress Summary
| Story | Description | Status |
|-------|-------------|--------|
| 8 | Compound Library & Blends | ✅ 100% Complete (UI and selection standardized) |
| 9 | Refined PK Engine | ✅ 100% Complete (UI and allometric scaling explained) |
| 10 | User Profile 2.0 & Persistence | ✅ 100% Complete (CloudKit integration fixed) |
| 11 | Notifications & Adherence | ✅ 100% Complete |
| 12 | Cycle Builder | ✅ 100% Complete |
| 13 | AI Insights | ✅ 100% Complete (OpenAI integration with GPT-4o-mini model and free test API key - $20 limit) |
| 14 | UI/UX Polish & Animations | ❌ 0% Not Started (Next in pipeline) |
| 15 | Testing & Validation | ❌ 0% Not Started (Final stage) |
| 16 | Help Center & Documentation | ❌ 0% Not Started |

## Code Conventions & Naming Guidelines

To avoid build errors and conflicts in the codebase, follow these naming conventions:

| Issue | Convention |
|-------|------------|
| Swift Keywords | Never use Swift reserved keywords (`protocol`, `class`, `struct`, etc.) as variable names |
| Protocol Variables | Use `treatmentProtocol` or `protocolItem` instead of `protocol` for InjectionProtocol variables |
| Struct Names | Prefix struct names with context (e.g., `InjectionAdherenceStatsView`, `NotificationAdherenceStatsView`) |
| Common Error Avoidance | When looping through protocol collections, always use: `for treatmentProtocol in protocols` or `for item in protocols` |

### Fixed Codebase Issues:
- ✅ AppDataStore.swift - Fixed `for protocol in deletedProtocols` to `for item in deletedProtocols`
- ✅ InjectionHistoryView.swift - Fixed duplicate struct `AdherenceStatsView` to `InjectionAdherenceStatsView`
- ✅ NotificationSettingsView.swift - Renamed `AdherenceStatsView` to `NotificationAdherenceStatsView`
- ✅ Protocol parameter in functions - Changed to `treatmentProtocol` where used as a parameter name

**Note**: Using Swift keywords as variable names results in compile-time errors like `expected pattern` or `expected Sequence expression`.

## Missing Frontend Implementations

The following backend features have been implemented but need UI components:

| Feature | Backend Status | Frontend Status | Description |
|---------|---------------|-----------------|-------------|
| Compound Library & Blends | ✅ Complete | ✅ Implemented | UI for selecting from full compound library and blends has been added |
| VialBlend Presets | ✅ Complete | ✅ Implemented | Added VialBlendListView to select pre-defined commercial blends |
| Bayesian Calibration Details | ✅ Complete | ✅ Implemented | Added CalibrationResultView to display detailed calibration results |
| Route Selection | ✅ Complete | ✅ Implemented | Added dropdown to protocol form for selecting administration route |
| Two-Compartment Toggle | ✅ Complete | ✅ Implemented | Added toggle in Profile Settings with explanatory info popup |
| Allometric Scaling Info | ✅ Complete | ✅ Implemented | Added explanatory view in Profile explaining how measurements affect calculations |
| CloudKit Sync Toggle | ✅ Complete | ✅ Added | Toggle exists in settings and CloudKit integration has been fixed |
| Compound Selection Standardization | ✅ Complete | ✅ Implemented | Simplified UI to use the Compound model instead of redundant TestosteroneEster model |
| Notification & Adherence System | ✅ Complete | ✅ Implemented | Added full notification system with adherence tracking and statistics |
| Help Center & Documentation | ⚠️ Partial | ❌ Not Started | Need to create centralized help system with dedicated views for each topic |

**Priority Tasks:**
0. ✅ start by adding a test user profile to the app and fill in the values, as well as a test protocol, this will help us testing the app with out having to type in the values every time, it should be easy to delete this after testing. (also add in this document when we should remove this test data)
   * ✅ Created a dedicated test profile with realistic user information in AppDataStore
   * ✅ Added multiple test protocols with various compounds and routes
   * ✅ Implemented a `resetToDefaultProfile()` function for easy cleanup
   * ✅ Added test blood samples to evaluate calibration functionality
   * Target removal: After completing implementation of Stories 8-10

1. ✅ Add UI for compound library and blend selection in protocol form
   * ✅ Created `CompoundListView` to display and filter compounds by class/route
   * ✅ Created `VialBlendListView` to browse pre-defined commercial blends
   * ✅ Updated `ProtocolFormView` with a segmented control to choose between:
     - Single Compound selection
     - Vial Blend selection
   * ✅ Added compound/blend picker that replaces the existing testosterone ester picker
   * ✅ Updated `InjectionProtocol` model to support either compound or blend

2. ✅ Add route selection dropdown to protocol form
   * ✅ Added a `Picker` for `Compound.Route` in `ProtocolFormView`
   * ✅ Updated the UI to dynamically show/hide route picker based on context
   * ✅ Updated `InjectionProtocol` to store the selected route
   * ✅ Added validation to ensure route is compatible with selected compound
   * ✅ Connected route selection to the PK engine calculations

3. ✅ Create CalibrationResultView to show detailed Bayesian calibration results
   * ✅ Created new view to display:
     - Correlation coefficient (model fit quality)
     - Original vs. calibrated parameter values
     - Visual representation of fit improvement
   * ✅ Added navigation link from ProtocolDetailView to CalibrationResultView
   * ✅ Implemented the model parameter adjustment visualization
   * ✅ Added explanatory text about the meaning of calibration parameters
   * ✅ Fixed Swift keyword issue by renaming 'protocol' to 'treatmentProtocol'
   * ✅ Fixed DataPoint parameter references to use 'time' and 'level' instead of 'date' and 'value'

4. ✅ Complete the Tp, Cmax predictions in the PK Engine
   * ✅ Added `calculateTimeToMaxConcentration()` and `calculateMaxConcentration()` functions to `PKModel`
   * ✅ Implemented the time-to-peak calculation for one and two-compartment models
   * ✅ Added specialized methods for blend and protocol peak finding
   * ✅ Exposed these values in the UI on the protocol detail screen
   * ✅ Added visual markers on the chart for Tp and Cmax points with toggle

5. ✅ Bug fixes and code quality improvements
   * ✅ Fixed property name mismatches in UserProfile references (dob→dateOfBirth, height→heightCm)
   * ✅ Fixed mutable properties declarations in AppDataStore (let→var for variables that need modification)
   * ✅ Fixed Swift keyword usage in CalibrationResultView.swift (renamed 'protocol' parameter to 'treatmentProtocol')
   * ✅ Fixed parameter naming in DataPoint references (time/level instead of date/value)
   * ✅ Updated all references to match the new parameter names
   * ✅ Resolved "unable to type-check this expression in reasonable time" error in ProtocolListView by breaking down complex views
   * ✅ Re-enabled TestosteroneChart in ProtocolDetailView after resolving compiler issues
   * ✅ Build is now successful and app runs cleanly

6. ✅ Re-enable CloudKit integration for data persistence
   * ✅ Fixed container ID issues in CoreDataManager
     * Used "iCloud.flight505.TestoSim" as the CloudKit container ID, matching the entitlements file
     * Added conditional logic to use NSPersistentCloudKitContainer only when iCloud sync is enabled
     * Fixed CoreDataManager to properly cast the container when initializing CloudKit schema
   * ✅ Fixed migration logic for seamless transition
     * Updated CoreDataManager.migrateUserProfileFromJSON() to handle new properties
     * Stored extended properties (protocolType, compoundID, blendID, selectedRoute) in notes field as JSON
   * ✅ Added proper error handling for CloudKit operations
     * Improved error logging for CloudKit-specific issues
     * Added notification for when CloudKit sync settings are changed
   * ✅ Added sync status indicators in the UI
     * Added isCloudSyncEnabled() method to check current sync status
     * Improved enableCloudSync method to notify when a restart is required

7. ✅ UI standardization for compound selection
   * ✅ Removed redundant TestosteroneEster option from protocol creation
   * ✅ Updated ProtocolFormView to focus on Compound and Blend selection options
   * ✅ Added automatic conversion of legacy protocols to use the Compound model
   * ✅ Updated ProtocolDetailView to display compound information for all protocols
   * ✅ Updated ProtocolListView to use proper compound/blend protocol display
   * ✅ Maintained backward compatibility for existing protocols

8. ✅ Implement notification system for injection adherence
   * ✅ **Created NotificationManager class**
     * ✅ Implemented `UNUserNotificationCenter.requestAuthorization` for permissions
     * ✅ Added methods to schedule, update, and cancel injection reminders
     * ✅ Added support for different notification sounds and actions

   * ✅ **Integrated with protocol management**
     * ✅ After each protocol edit, scheduled next-dose alert with `UNCalendarNotificationTrigger` 
     * ✅ Implemented proper notification timing based on protocol schedule
     * ✅ Added update notifications for protocol changes and deletions

   * ✅ **Added notification preferences**
     * ✅ Created UI settings for lead-time options (1h / 6h / 12h before injection)
     * ✅ Added toggle for notification sounds
     * ✅ Implemented proper notification handling with feedback
     
   * ✅ **Implemented adherence tracking**
     * ✅ Created system to record when users acknowledge injections
     * ✅ Added tracking for adherence statistics (on-time, late, missed)
     * ✅ Created InjectionHistoryView to visualize adherence data
     * ✅ Added adherence rate display in profile view

---

## Story 8 — Compound Library & Blends

*Data and utilities for single esters **and** multi-ester vials.*

* [x] **Create `Compound.swift`** data model (see code block).
* [x] **Create `VialBlend.swift`** to describe commercial mixtures (each `Component` maps to a `Compound`).
* [x] **Populate `CompoundLibrary.swift`** with the literature half-lives below:

  * [x] Testosterone propionate 0.8 d ([Wikipedia][1])
  * [x] Testosterone phenylpropionate 2.5 d ([Iron Daddy][2])
  * [x] Testosterone isocaproate 3.1 d ([Cayman Chemical][3])
  * [x] Testosterone decanoate 7-14 d (use 10 d midpoint) ([BloomTechz][4])
  * [x] Injectable testosterone undecanoate 18-24 d ([PubMed][5], [Wikipedia][6])
  * [x] Oral testosterone undecanoate t½ 1.6 h, F = 0.07 ([Wikipedia][6])
  * [x] Nandrolone decanoate 6-12 d ([Wikipedia][7])
  * [x] Boldenone undecylenate ≈123 h ([ScienceDirect][8])
  * [x] Trenbolone acetate 1-2 d ([ScienceDirect][9])
  * [x] Trenbolone enanthate 11 d / hexahydrobenzylcarbonate 8 d ([Wikipedia][10])
  * [x] Stanozolol IM suspension 24 h ([Wikipedia][11])
  * [x] Drostanolone propionate 2 d ([Wikipedia][12])
  * [x] Drostanolone enanthate ≈5 d ([Wikipedia][12])
  * [x] Metenolone enanthate 10.5 d ([Wikipedia][13])
  * [x] Trestolone (MENT) acetate t½ 40 min IV ≈ 2 h SC ([PubMed][14])
  * [x] 1-Testosterone (DHB) cypionate ≈8 d (class analogue) ([Wikipedia][15])
* [x] **Define `VialBlend` constants** for: Sustanon 250/350/400, Winstrol Susp 50, Masteron P 100 & E 200, Primobolan E 100, Tren Susp 50, Tren A 100, Tren E 200, Tren Hex 76, Tren Mix 150, Cut-Stack 150 & 250, MENT Ac 50, DHB Cyp 100 (per-mL mg in guide's table).
* [x] **Library helpers**: `blends(containing:)`, `class(is:)`, `route(_:)`, and half-life range filters.
* [x] **UI: Create CompoundView** to browse and select from all compounds.
* [x] **UI: Create VialBlendView** to browse and select from pre-defined blends.
* [x] **UI: Update ProtocolFormView** to allow selection of any Compound or VialBlend instead of just TestosteroneEster.
* [x] **UI: Add route selection** dropdown to protocol form for choosing administration route.

```swift
struct Compound: Identifiable, Codable, Hashable {
    enum Class: String, Codable { case testosterone, nandrolone, trenbolone,
                                   boldenone, drostanolone, stanozolol, metenolone,
                                   trestolone, dhb }
    enum Route: String, Codable { case intramuscular, subcutaneous, oral, transdermal }
    let id: UUID
    var commonName: String
    var classType: Class
    var ester: String?          // nil for suspensions
    var halfLifeDays: Double
    var defaultBioavailability: [Route: Double]
    var defaultAbsorptionRateKa: [Route: Double] // d-¹
}
```

---

## Story 9 — Refined PK Engine

*Accurate curves for any route, any blend.*

* [x] **Implement `PKModel.concentration`**

  $$
  C(t)=\frac{F\,D\,k_a}{V_d\,(k_a-k_e)}\bigl(e^{-k_e t}-e^{-k_a t}\bigr)
  $$

  where $k_e=\ln2/t_{1/2}$.\* Units = days\* ([UF College of Pharmacy][16])

* [x] **Optional two-compartment flag**; derive α, β from $k_{12}=0.3$, $k_{21}=0.15$ d⁻¹ ([UF College of Pharmacy][16])

* [x] **Allometric scaling**:
  $V_{d,\text{user}} = V_{d,70}(WT/70)^{1.0}$;
  $CL_{\text{user}} = CL_{70}(WT/70)^{0.75}$ ([PubMed][17])

* [x] **Route parameters** (defaults in `CompoundLibrary`):

  | Ester               | k<sub>a</sub> (d⁻¹ IM) | Oral F | Notes                               |
  | ------------------- | ---------------------- | ------ | ----------------------------------- |
  | Propionate          | 0.70                   | —      | Fastest IM absorption               |
  | Phenylpropionate    | 0.50                   | —      | Moderate-fast absorption            |
  | Isocaproate         | 0.35                   | —      | Medium absorption                   |
  | Enanthate           | 0.30                   | —      | Medium absorption                   |
  | Cypionate           | 0.25                   | —      | Longer absorption                   |
  | Decanoate           | 0.18                   | —      | Extended absorption                 |
  | Undecanoate         | 0.15                   | 0.07   | Slowest IM absorption; low oral F   |

* [x] **Fix compoundFromEster method** to properly match TestosteroneEster to Compound with safe error handling

* [x] **Bayesian calibration** using trough samples
  * Implemented with gradient descent optimization
  * Adjusts elimination (ke) and absorption (ka) rates based on blood samples
  * Maintains parameters within reasonable bounds (0.5x to 2.0x of literature values)
  * Includes correlation calculation to evaluate model fit quality

* [x] **Accurate T<sub>p</sub>, C<sub>max</sub>** predictions

* [x] **UI: Create CalibrationResultView** to show detailed Bayesian calibration results including correlation coefficient and parameter adjustments.
* [x] **UI: Add two-compartment model toggle** in Profile Settings to enable/disable more accurate but intensive calculations.
  * Added toggle in UserProfile model with proper Core Data persistence
  * Created helper method in AppDataStore to consistently create PKModel instances
  * Updated all simulation methods to use the user's two-compartment model preference
  * Added informational popup explaining the benefits and performance implications

* [x] **UI: Add explainer for allometric scaling** to inform users how their physical measurements improve calculation accuracy.
  * Created comprehensive AllometricInfoView with visual explanations of scaling equations
  * Added button in Physical Measurements section to access the explainer
  * Included scientific basis and benefits of providing accurate measurements
  * Used clear visualizations to demonstrate how body size affects pharmacokinetics

---

## Story 10 — User Profile 2.0 & Persistence

*Personalisation + seamless cloud backup.*

* [x] Extend `UserProfile` with DOB, height cm, weight kg, biologicalSex, `usesICloudSync`; compute `bodySurfaceArea` (DuBois).
* [x] Migrate storage to **Core Data + CloudKit** with `NSPersistentCloudKitContainer` ([Apple Developer][18])
  * Core Data model has been created with proper entity relationships and attributes
  * Container configuration implemented with proper container identifier
* [x] Write one-time JSON-to-CoreData migrator flag `UserDefaults.migrated = true`.
* [x] **Re-enable CloudKit integration**
  * Fixed crashing issues with the proper container ID
  * Added proper CloudKit schema initialization
  * Implemented conditional container creation based on user preferences

---

## Story 11 — Notifications & Adherence

*Keep users on-schedule.*

* [x] **Created NotificationManager class**
  * [x] Implemented `UNUserNotificationCenter.requestAuthorization` for permissions
  * [x] Added methods to schedule, update, and cancel injection reminders
  * [x] Added support for different notification sounds and actions

* [x] **Integrated with protocol management**
  * [x] After each protocol edit, scheduled next-dose alert with `UNCalendarNotificationTrigger` 
  * [x] Calculated proper notification times based on protocol schedule
  * [x] Updated notifications when protocols are deleted or modified

* [x] **Added notification preferences**
  * [x] Created UI settings for lead-time options (1h / 6h / 12h before injection)
  * [x] Added toggle for notification sounds
  * [x] Implemented proper notification handling with feedback
  
* [x] **Implemented adherence tracking**
  * [x] Created system to record when users acknowledge injections
  * [x] Added tracking for adherence statistics (on-time, late, missed)
  * [x] Created InjectionHistoryView to visualize adherence data
  * [x] Added adherence rate display in profile view

---

## Story 12 — Cycle Builder

*Visual timeline for multi-compound plans.*

* [x] **`Cycle` and `CycleStage` data models** for representing comprehensive multi-compound treatment plans
  * [x] Created `Cycle` with name, startDate, totalWeeks, and collection of stages
  * [x] Created `CycleStage` with startWeek, durationWeeks, and collections of compounds/blends
  * [x] Implemented `CompoundStageItem` and `BlendStageItem` to handle different component types
  * [x] Added conversion methods to generate temporary protocols for simulation

* [x] **Core Data integration** for persistence
  * [x] Added `CDCycle` and `CDCycleStage` entities with proper relationships
  * [x] Created extension methods for model-entity conversion
  * [x] Implemented JSON serialization for compound/blend collections
  * [x] Connected cycles to user profiles for organization

* [x] **Cycle Management in AppDataStore**
  * [x] Added CRUD operations for cycles (load, save, delete)
  * [x] Implemented cycle simulation by combining multiple compounds/blends
  * [x] Created data accumulation logic to properly visualize combined effects

* [x] **SwiftUI CyclePlannerView** for visual planning
  * [x] Created main interface with cycles list and simulation results
  * [x] Added `CycleFormView` for creating and editing cycles
  * [x] Implemented `CycleStageFormView` for configuring stages with compounds/blends
  * [x] Created support views for compound and blend selection and configuration

* [x] **Visualization Components**
  * [x] Implemented `CycleChartView` using Swift Charts for concentration visualization
  * [x] Added date formatting and timeline representation
  * [x] Created placeholder for detailed Gantt-style visualization (to be enhanced)

* [x] **Navigation and Integration**
  * [x] Updated ContentView to use TabView for easy navigation
  * [x] Added tab for Cycles alongside existing Protocols and Profile tabs
  * [x] Implemented proper state management between views

---

## Story 13 — AI Insights

*Contextual coaching for optimized therapy.*

* [x] **`InsightsGenerator` Architecture**
  * [x] Created a dedicated module to orchestrate AI interactions
  * [x] Designed JSON schema for structured insights responses
  * [x] Implemented caching system to reduce redundant API calls
  * [x] Added appropriate disclaimers for AI-generated content

* [x] **Core Insight Types**
  * [x] **Blend Explainer** - Provides plain-English breakdown of multi-ester blends
    * Explains expected pharmacokinetic behavior (e.g., "Sustanon 250 contains four esters with varying release times, creating an initial spike followed by sustained release")
    * Uses visualization aids to explain compound interactions
    * Implements similarity search for educational content

  * [x] **Protocol Analysis** - Evaluates user's protocol design
    * Identifies suboptimal dosing schedules (e.g., suggests splitting weekly injections for more stable levels)
    * Compares protocols against evidence-based best practices
    * Suggests protocol modifications based on user's blood test results

  * [x] **Adherence Coach** - Helps users maintain consistent therapy
    * Analyzes adherence patterns to provide personalized feedback
    * Suggests routine adjustments to improve consistency
    * Provides education on the importance of therapy consistency

* [x] **Implementation Details**
  * [x] **Complete OpenAI Integration**
    * Uses GPT-4o-mini model to balance cost-effectiveness and quality
    * Implements structured JSON response format for consistent UI presentation
    * Added free test API key for all users with $20 spending limit
    * Includes API key management UI with option to use personal key or test key
    * Implements proper error handling and loading states
  
  * [x] **Robust Offline Fallback**
    * Created mock implementation that works without internet connection
    * Pre-generates common insights for basic functionality
    * Automatically falls back to mock data when API is unavailable

  * [x] **Prompt Engineering**
    * Developed specialized prompts for protocol and cycle analysis
    * Includes relevant user profile data for personalized insights
    * Structured to generate consistent, actionable advice
    * Optimized token usage for cost efficiency

* [x] **UI Integration**
  * [x] Created dedicated "Insights" tab in the app interface
  * [x] Implemented interactive UI with expandable key points
  * [x] Added color-coded insights by category (information, warnings, suggestions, positive feedback)
  * [x] Created settings view for API key management
  * [x] Added visual indicators for test API key usage
  * [x] Implemented auto-refresh when API settings change

* [x] **Cache and Performance**
  * [x] Implemented intelligent caching to minimize API calls
  * [x] Added force refresh option for updated results
  * [x] Created proper loading and error states in the UI

## Next Steps

With Stories 8-13 now complete, the application has all its core functional requirements implemented. The focus will now shift to:

### Story 14 — UI/UX Polish & Animations
The next step is to enhance the visual appeal and user experience of the application. This will include implementing smooth animations, improving visual consistency, optimizing the interface for accessibility, and adding delightful interactions to make the app more engaging.

### Story 15 — Testing & Validation
The final stage will focus on comprehensive testing of all features, validation of pharmacokinetic calculations against reference data, and ensuring the application performs well across different devices and scenarios.

These remaining stories will complete the application's development cycle and prepare it for release.

---

## Story 14 — UI/UX Polish & Animations

*Delightful & accessible.*

* [ ] Follow **Apple HIG "Charting Data"** for uncluttered axes & call-outs ([Apple Developer][21])
* [ ] Dashboard card shows *current level* + *days until next dose*; layout guided by NN/g pre-attentive dashboard rules ([Nielsen Norman Group][22])
* [ ] **Adopt Swift Charts 2-D interactions** (scroll-zoom, selection marks)
* [ ] **Animate curve reveal** – `.animation(.easeInOut(duration:1.2), value:dataStore.simulationData)`
* [ ] **Add Lottie onboarding & success animations** (e.g., injection logged)
  * Import via SPM `airbnb/lottie-ios` ([github.com][1])
* [ ] **Haptics & sounds** when user records an injection
* [ ] **Dark-mode friendly color palette** using semantic `Color` assets

---

## Story 15 — Testing & Validation

| Test     | Target                                                                                                             | Pass criteria            |
| -------- | ------------------------------------------------------------------------------------------------------------------ | ------------------------ |
| **Unit** | 250 mg Test E single IM → C<sub>max</sub> ≈ 1540 ng/dL @ 72 h; 50 % peak by day 9 ([World Anti Doping Agency][24]) | Δ ≤ 10 %                 |
|          | 100 mg Tren A Q2D × 14 d steady-state \~6× baseline ([Wikipedia][10])                                              | Δ ≤ 10 %                 |
| **UI**   | Notification permission flow, drag-drop in cycle builder                                                           | No crash, state persists |
| **Perf** | Simulate 5-compound 20-week plan on iPhone 12                                                                      | < 50 ms average          |

---

## Story 16 — Help Center & Documentation

*Comprehensive in-app learning center*

* [ ] **Core Help Center Architecture**
  * [ ] Create `HelpCenterView` as the main entry point for all documentation
  * [ ] Implement topic-based navigation with hierarchical structure
  * [ ] Create consistent visual styling and interactive elements
  * [ ] Design for high readability with appropriate typography and spacing
  * [ ] Add global access through navigation bar help button

* [ ] **PK Model Documentation**
  * [ ] Create detailed explanations of the two-compartment model
  * [ ] Develop interactive visualizations showing compound movement between compartments
  * [ ] Include scientific foundation with simplified explanations
  * [ ] Provide practical examples showing how the model predicts real-world concentrations
  * [ ] Explain key pharmacokinetic parameters (ke, ka, α, β, Vd)

* [ ] **Educational Content Modules**
  * [ ] **PKModelExplanationView**: Two-compartment model details and benefits
    * Visual representation of central and peripheral compartments
    * Animation showing compound distribution and elimination
    * Explanation of why two compartments produces more accurate predictions
    * Comparison with simpler one-compartment models

  * [ ] **AllometricScalingView**: Enhanced version of existing content
    * Expanded visualization of scaling equations
    * Clearer connection to PK model concepts
    * Additional scientific foundation with accessible explanations

  * [ ] **ApplicationGuideView**: Practical usage tutorials
    * Protocol creation walkthrough
    * Blood test integration explanation
    * Calibration process explanation
    * Step-by-step instructions with screenshots

  * [ ] **CyclePlannerGuideView**: Multi-compound cycle documentation
    * Explanation of cycle planner functionality
    * Multi-compound interactions and considerations
    * Visual interpretation guide for cycle simulations
    * Best practices for monitoring during cycles

* [ ] **UI Implementation**
  * [ ] Add global help button in navigation bar across app
    ```swift
    .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingHelpCenter = true
            } label: {
                Image(systemName: "questionmark.circle")
            }
        }
    }
    .sheet(isPresented: $showingHelpCenter) {
        HelpCenterView()
    }
    ```
  * [ ] Create consistent section styling with cards and grid layouts
  * [ ] Implement topic filtering and search functionality
  * [ ] Design expandable sections for progressive disclosure
  * [ ] Support both light and dark mode with appropriate contrast

* [ ] **Content Organization**
  * [ ] Move existing explanatory content into the centralized Help Center
  * [ ] Remove redundant "Advanced PK Model" explanatory text from ProfileView
  * [ ] Create new illustrations and animations for complex concepts
  * [ ] Ensure content is scientifically accurate but accessible to users

* [ ] **Integration Plan**
  * [ ] Create Help directory in Views folder with modular components
  * [ ] Update ContentView and primary feature views with Help button
  * [ ] Add state variables to manage help presentation
  * [ ] Implement deep-linking to specific help topics from relevant screens

* [ ] **Clean-up Tasks**
  * [ ] Remove or consolidate scattered explanatory content
  * [ ] Establish consistent typography and visual hierarchy
  * [ ] Ensure all help content is accessible with proper semantic markup
  * [ ] Add contextual help links in appropriate locations

---

## References

1. Testosterone propionate half-life 0.8 d ([Wikipedia][1])
2. Testosterone PP half-life 2.5 d ([Iron Daddy][2])
3. Testosterone isocaproate info ([Cayman Chemical][3])
4. Testosterone decanoate 7–14 d ([BloomTechz][4])
5. TU depot half-life 18–24 d ([PubMed][5])
6. Oral TU bioavailability 0.07, t½ 1.6 h ([Wikipedia][6])
7. Nandrolone decanoate 6–12 d ([Wikipedia][7])
8. Boldenone undecylenate \~123 h ([ScienceDirect][8])
9. Trenbolone acetate 1-2 d ([ScienceDirect][9])
10. Trenbolone hex/enanthate data ([Wikipedia][10])
11. Stanozolol suspension 24 h ([Wikipedia][11])
12. Drostanolone propionate 2 d; enanthate \~5 d ([Wikipedia][12])
13. Metenolone enanthate 10.5 d ([Wikipedia][13])
14. Trestolone acetate 40 min IV t½ ([PubMed][14])
15. DHB overview (1-Testosterone) ([Wikipedia][15])
16. UF "Useful PK equations" sheet ([UF College of Pharmacy][16])
17. Allometric scaling study (TE) ([PubMed][17])
18. Apple CoreData + CloudKit doc ([Apple Developer][18])
19. UNUserNotificationCenter API page ([Apple Developer][19])
20. WWDC23 Swift Charts interactivity ([Apple Developer][20])
21. Apple Charting-Data HIG ([Apple Developer][21])
22. NN/g dashboard pre-attentive article ([Nielsen Norman Group][22])
23. Lottie-SPM install guide ([GitHub][23])
24. WADA blood detection of testosterone esters ([World Anti Doping Agency][24])

[1]: https://en.wikipedia.org/wiki/Testosterone_propionate?utm_source=chatgpt.com "Testosterone propionate - Wikipedia"
[2]: https://iron-daddy.to/product-category/injectable-steroids/testosterone-phenylpropionate/?utm_source=chatgpt.com "Testosterone Phenylpropionate Half Life - Iron-Daddy.to"
[3]: https://www.caymanchem.com/product/22547/testosterone-isocaproate?srsltid=AfmBOoqMzkbumL-PTe0EBkhjjakJVRLR66OsRIFjNbNDIX5YwYpMLPer&utm_source=chatgpt.com "Testosterone Isocaproate (CAS 15262-86-9) - Cayman Chemical"
[4]: https://www.bloomtechz.com/info/what-is-the-half-life-of-testosterone-decanoat-93380289.html?utm_source=chatgpt.com "What Is The Half Life Of Testosterone Decanoate? - BLOOM TECH"
[5]: https://pubmed.ncbi.nlm.nih.gov/9876028/?utm_source=chatgpt.com "A pharmacokinetic study of injectable testosterone undecanoate in ..."
[6]: https://en.wikipedia.org/wiki/Testosterone_undecanoate?utm_source=chatgpt.com "Testosterone undecanoate - Wikipedia"
[7]: https://en.wikipedia.org/wiki/Nandrolone_decanoate?utm_source=chatgpt.com "Nandrolone decanoate - Wikipedia"
[8]: https://www.sciencedirect.com/science/article/abs/pii/S1567576921005750?utm_source=chatgpt.com "Boldenone undecylenate disrupts the immune system and induces ..."
[9]: https://www.sciencedirect.com/science/article/abs/pii/S002228602030452X?utm_source=chatgpt.com "Structural studies of Trenbolone, Trenbolone Acetate ..."
[10]: https://en.wikipedia.org/wiki/Trenbolone?utm_source=chatgpt.com "Trenbolone"
[11]: https://en.wikipedia.org/wiki/Stanozolol?utm_source=chatgpt.com "Stanozolol - Wikipedia"
[12]: https://en.wikipedia.org/wiki/Drostanolone_propionate?utm_source=chatgpt.com "Drostanolone propionate - Wikipedia"
[13]: https://en.wikipedia.org/wiki/Metenolone_enanthate?utm_source=chatgpt.com "Metenolone enanthate - Wikipedia"
[14]: https://pubmed.ncbi.nlm.nih.gov/9283946/?utm_source=chatgpt.com "Pharmacokinetics of 7 alpha-methyl-19-nortestosterone in men and ..."
[15]: https://en.wikipedia.org/wiki/1-Testosterone?utm_source=chatgpt.com "1-Testosterone - Wikipedia"
[16]: https://pharmacy.ufl.edu/files/2013/01/5127-28-equations.pdf?utm_source=chatgpt.com "[PDF] Useful Pharmacokinetic Equations"
[17]: https://pubmed.ncbi.nlm.nih.gov/37180212/?utm_source=chatgpt.com "Allometric Scaling of Testosterone Enanthate Pharmacokinetics to ..."
[18]: https://developer.apple.com/documentation/coredata/setting-up-core-data-with-cloudkit "Setting Up Core Data with CloudKit | Apple Developer Documentation"
[19]: https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/requestauthorization "UNUserNotificationCenter - Apple Developer Documentation"
[20]: https://developer.apple.com/videos/play/wwdc2023/10037 "Explore pie charts and interactivity in Swift Charts - WWDC23 - Videos - Apple Developer"
[21]: https://developer.apple.com/design/human-interface-guidelines/charting-data "Charting data | Apple Developer Documentation"
[22]: https://www.nngroup.com/articles/dashboards-preattentive/?utm_source=chatgpt.com "Dashboards: Making Charts and Graphs Easier to Understand - NN/g"
[23]: https://github.com/airbnb/lottie-ios "airbnb/lottie-ios: An iOS library to natively render After Effects vector animations"
[24]: https://www.wada-ama.org/en/resources/scientific-research/detection-testosterone-esters-blood-sample?utm_source=chatgpt.com "Detection of testosterone esters in blood sample - WADA"

## Code Cleanup

As part of our ongoing refinement of the application architecture, we've made the following improvements:

1. [x] Removed redundant TestosteroneEster model
   * The legacy TestosteroneEster model has been completely removed
   * All protocols now use the more flexible Compound model
   * Protocol creation process has been simplified to just two options: Compound and Blend
   * Core Data persistence has been updated to store compound/blend references in the notes field until the data model is updated

2. [x] Simplified protocol type selection
   * Protocols now clearly identify as either compound-based or blend-based
   * UI has been streamlined to show only the relevant options for each type
   * Added proper route selection for all protocol types

3. [x] Improved database efficiency
   * Protocols now store direct references to compounds and blends instead of duplicating data
   * Added support for extended property serialization in the Core Data persistence layer
   * Prepared the application for future data model updates

These changes have resulted in a more maintainable codebase and a clearer user experience when creating and managing protocols.

4. [x] Added comprehensive notification system
   * Created NotificationManager class to handle all notification-related functionality
   * Integrated notification scheduling with protocol management
   * Added adherence tracking system to monitor user compliance
   * Created UI for managing notification preferences and viewing adherence data
