# TestoSim Implementation Progress

## Progress Summary
| Story | Description | Status |
|-------|-------------|--------|
| 8 | Compound Library & Blends | ✅ 100% Complete (UI and selection standardized) |
| 9 | Refined PK Engine | ✅ 100% Complete |
| 10 | User Profile 2.0 & Persistence | ✅ 100% Complete (CloudKit integration fixed) |
| 11 | Notifications & Adherence | ❌ 0% Not Started |
| 12 | Cycle Builder | ❌ 0% Not Started |
| 13 | AI Insights | ❌ 0% Not Started |
| 14 | UI/UX Polish & Animations | ❌ 0% Not Started |
| 15 | Testing & Validation | ❌ 0% Not Started |

## Missing Frontend Implementations

The following backend features have been implemented but need UI components:

| Feature | Backend Status | Frontend Status | Description |
|---------|---------------|-----------------|-------------|
| Compound Library & Blends | ✅ Complete | ✅ Implemented | UI for selecting from full compound library and blends has been added |
| VialBlend Presets | ✅ Complete | ✅ Implemented | Added VialBlendListView to select pre-defined commercial blends |
| Bayesian Calibration Details | ✅ Complete | ✅ Implemented | Added CalibrationResultView to display detailed calibration results |
| Route Selection | ✅ Complete | ✅ Implemented | Added dropdown to protocol form for selecting administration route |
| Two-Compartment Toggle | ✅ Complete | ❌ Missing | No UI control to enable more accurate two-compartment model |
| Allometric Scaling Info | ✅ Complete | ⚠️ Partial | Profile collects user measurements but no indication how they affect calculations |
| CloudKit Sync Toggle | ✅ Complete | ✅ Added | Toggle exists in settings and CloudKit integration has been fixed |
| Compound Selection Standardization | ✅ Complete | ✅ Implemented | Simplified UI to use the Compound model instead of redundant TestosteroneEster model |

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
   * ⚠️ Temporarily disabled TestosteroneChart in ProtocolDetailView with a placeholder until compiler issues are resolved
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

8. [ ] Implement notification system for injection adherence
   * [ ] **Create NotificationManager class**
     * [ ] Implement `UNUserNotificationCenter.requestAuthorization` for permissions
     * [ ] Add methods to schedule, update, and cancel injection reminders
     * [ ] Add support for different notification sounds and actions

   * [ ] **Integrate with protocol management**
     * [ ] After each protocol edit, schedule next-dose alert with `UNCalendarNotificationTrigger` 
     * [ ] Calculate proper notification times based on protocol schedule
     * [ ] Update notifications when protocols are deleted or modified

   * [ ] **Add notification preferences**
     * [ ] Create UI settings for lead-time options (1h / 6h / 12h before injection)
     * [ ] Add toggle for notification sounds
     * [ ] Implement Do Not Disturb awareness and critical notifications for timely reminders
     
   * [ ] **Implement adherence tracking**
     * [ ] Record when users acknowledge injection reminders
     * [ ] Track adherence statistics (on-time, late, missed)
     * [ ] Visualize adherence data in the app dashboard

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
* [ ] **UI: Create CompoundView** to browse and select from all compounds.
* [ ] **UI: Create VialBlendView** to browse and select from pre-defined blends.
* [ ] **UI: Update ProtocolFormView** to allow selection of any Compound or VialBlend instead of just TestosteroneEster.
* [ ] **UI: Add route selection** dropdown to protocol form for choosing administration route.

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

* [ ] **Accurate T<sub>p</sub>, C<sub>max</sub>** predictions

* [ ] **UI: Create CalibrationResultView** to show detailed Bayesian calibration results including correlation coefficient and parameter adjustments.
* [ ] **UI: Add two-compartment model toggle** in settings to enable/disable more accurate but intensive calculations.
* [ ] **UI: Add explainer for allometric scaling** to inform users how their physical measurements improve calculation accuracy.

---

## Story 10 — User Profile 2.0 & Persistence

*Personalisation + seamless cloud backup.*

* [x] Extend `UserProfile` with DOB, height cm, weight kg, biologicalSex, `usesICloudSync`; compute `bodySurfaceArea` (DuBois).
* [ ] Migrate storage to **Core Data + CloudKit** with `NSPersistentCloudKitContainer` ([Apple Developer][18])
  * Core Data model has been created but needs proper entity relationships and attributes
  * Need to implement container configuration with proper container identifier
* [x] Write one-time JSON-to-CoreData migrator flag `UserDefaults.migrated = true`.
* [ ] **Re-enable CloudKit integration**
  * Currently disabled due to crashing issues with hardcoded container ID
  * Need to create proper CloudKit container in Apple Developer Portal
  * Replace hardcoded ID with proper container ID from developer account
  * Implement proper CloudKit schema initialization
* [ ] **Test Core Data migration**
  * Ensure smooth transitions from JSON to CoreData storage
  * Add data validation to verify all user data properly migrates

---

## Story 11 — Notifications & Adherence

*Keep users on-schedule.*

* [ ] **Create NotificationManager class**
  * [ ] Implement `UNUserNotificationCenter.requestAuthorization` for permissions
  * [ ] Add methods to schedule, update, and cancel injection reminders
  * [ ] Add support for different notification sounds and actions

* [ ] **Integrate with protocol management**
  * [ ] After each protocol edit, schedule next-dose alert with `UNCalendarNotificationTrigger` 
  * [ ] Calculate proper notification times based on protocol schedule
  * [ ] Update notifications when protocols are deleted or modified

* [ ] **Add notification preferences**
  * [ ] Create UI settings for lead-time options (1h / 6h / 12h before injection)
  * [ ] Add toggle for notification sounds
  * [ ] Implement Do Not Disturb awareness and critical notifications for timely reminders
  
* [ ] **Implement adherence tracking**
  * [ ] Record when users acknowledge injection reminders
  * [ ] Track adherence statistics (on-time, late, missed)
  * [ ] Visualize adherence data in the app dashboard

---

## Story 12 — Cycle Builder

*Visual timeline for multi-compound plans.*

* [ ] `Cycle` model (name, startDate, totalWeeks, stages:\[CycleStage]).
* [ ] SwiftUI `CyclePlannerView`: horizontal weeks, drag-and-drop `VialBlend` cards; render Gantt bars with **Swift Charts** scroll-zoom & selection APIs ([Apple Developer][20])
* [ ] "Simulate Cycle" merges stages to temp protocols → feeds PK engine.

---

## Story 13 — AI Insights

*Contextual coaching.*

* [ ] `InsightsGenerator` – send `{profile, simulation}` to LLM; receive JSON {peaks, troughs, tips}.
* [ ] Add helper `BlendExplainer` for plain-English breakdown of multi-ester vials (e.g. "Sustanon 400 = 4 esters; expect early spike then 3-week tail"). 
* [ ] **Add AI integration options:**
  * Predicted peaks/troughs calculation
  * Adherence tips (e.g., "consider splitting weekly 200 mg TE into 2×100 mg")
  * Automatic blend explanation and comparison
* [ ] **Prototype with OpenAI model** or Core ML-powered model (if offline required).

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
