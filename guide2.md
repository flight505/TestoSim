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
  | Propionate          | 0.70                   | —      | inj q2-3 d advised ([Wikipedia][1]) |
  | Phenylpropionate    | 0.50                   | —      | —                                   |
  | Isocaproate         | 0.35                   | —      | —                                   |
  | Decanoate           | 0.18                   | —      | —                                   |
  | Hex-carb            | 0.20                   | —      | —                                   |
  | Acetate (Tren/Test) | 1.00                   | —      | very fast                           |
  | Stanozolol susp     | 1.50                   | —      | 24 h t½ ([Wikipedia][11])           |
  | Oral TU             | —                      | 0.07   | t½ 1.6 h ([Wikipedia][6])           |
  | MENT Ac             | 2.00                   | —      | 40 min IV t½ ([PubMed][14])         |

* [x] **Blend handling**: loop through each `Component` and sum concentrations.

* [x] **Bayesian calibration stub** – accept `[TimeStamp:LabT]` to refine $k_e,k_a$.

* [ ] **Fix temporarily disabled `compoundFromEster` method** - Currently returning nil to use legacy calculation system due to initialization issues. Need to re-enable proper Compound matching.

* [ ] **Test PK model accuracy** - Verify that simulation curves match expected pharmacokinetics after re-enabling advanced model.

---

## Story 10 — User Profile 2.0 & Persistence

*Personalisation + seamless cloud backup.*

* [x] Extend `UserProfile` with DOB, height cm, weight kg, biologicalSex, `usesICloudSync`; compute `bodySurfaceArea` (DuBois).
* [ ] Migrate storage to **Core Data + CloudKit** with `NSPersistentCloudKitContainer` ([Apple Developer][18])
* [x] Write one-time JSON-to-CoreData migrator flag `UserDefaults.migrated = true`.
* [ ] **Re-enable CloudKit integration** - temporarily disabled to fix crashing issues with hardcoded container ID
* [ ] **Test Core Data migration** - ensure smooth transitions from JSON to CoreData storage

---

## Story 11 — Notifications & Adherence

*Keep users on-schedule.*

* [ ] Request permission via `UNUserNotificationCenter.requestAuthorization` ([Apple Developer][19])
* [ ] After each protocol edit, schedule next-dose alert with `UNCalendarNotificationTrigger`.
* [ ] Add settings: lead-time (1 h / 6 h / 12 h) and sound toggle.

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
* [ ] **Add `InsightsGenerator` service** – pass latest simulation & profile; receive JSON with:

  * Predicted peaks/troughs.
  * Adherence tips (e.g., "consider splitting weekly 200 mg TE into 2×100 mg").
* [ ] **Prototype with `openAI`** model O4 (research model and api)



## Story 13 – AI Insights

*Optional on-device or server LLM summaries.*

* [ ] **Add `InsightsGenerator` service** – pass latest simulation & profile; receive JSON with:

  * Predicted peaks/troughs.
  * Adherence tips (e.g., "consider splitting weekly 200 mg TE into 2×100 mg").
* [ ] **Prototype with `openAI` or Core ML-powered model (if offline required).**

---

## Story 14 — UI/UX Polish & Animations

*Delightful & accessible.*

* [ ] Follow **Apple HIG "Charting Data"** for uncluttered axes & call-outs ([Apple Developer][21])
* [ ] Dashboard card shows *current level* + *days until next dose*; layout guided by NN/g pre-attentive dashboard rules ([Nielsen Norman Group][22])
* [ ] Add `.animation(.easeInOut, value:data)` to curve reveal.
* [ ] Integrate **Lottie** via SPM `airbnb/lottie-spm` 4.5 + ([GitHub][23])
* [ ] Provide haptics (`UIImpactFeedbackGenerator`) and system sounds on log-dose success.
* [ ] Define semantic color assets for light/dark compliance.
* [ ] **Add `InsightsGenerator` service** – pass latest simulation & profile; receive JSON with:

  * Predicted peaks/troughs.
  * Adherence tips (e.g., "consider splitting weekly 200 mg TE into 2×100 mg").
* [ ] **Prototype with `openAI` model O4.**
---


## Story 15 — Testing & Validation

| Test     | Target                                                                                                             | Pass criteria            |
| -------- | ------------------------------------------------------------------------------------------------------------------ | ------------------------ |
| **Unit** | 250 mg Test E single IM → C<sub>max</sub> ≈ 1540 ng/dL @ 72 h; 50 % peak by day 9 ([World Anti Doping Agency][24]) | Δ ≤ 10 %                 |
|          | 100 mg Tren A Q2D × 14 d steady-state \~6× baseline ([Wikipedia][10])                                              | Δ ≤ 10 %                 |
| **UI**   | Notification permission flow, drag-drop in cycle builder                                                           | No crash, state persists |
| **Perf** | Simulate 5-compound 20-week plan on iPhone 12                                                                      | < 50 ms average          |



## Story 14 – UI/UX Polish & Animations

*Delightful, accessible, and on-brand.*

* [ ] **Adopt Swift Charts 2-D interactions** (scroll-zoom, selection marks).&#x20;
* [ ] **Animate curve reveal** – `.animation(.easeInOut(duration:1.2), value:dataStore.simulationData)`.
* [ ] **Add Lottie onboarding & success animations** (e.g., injection logged).

  * Import via SPM `airbnb/lottie-ios` ([github.com][1]).
* [ ] **Haptics & sounds** when user records an injection.
* [ ] **Dark-mode friendly color palette** using semantic `Color` assets.


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
16. Allometric scaling study (TE) ([PubMed][17])
17. UF "Useful PK equations" sheet ([UF College of Pharmacy][16])
18. Apple CoreData + CloudKit doc ([Apple Developer][18])
19. Apple Charting-Data HIG ([Apple Developer][21])
20. WWDC23 Swift Charts interactivity ([Apple Developer][20])
21. UNUserNotificationCenter API page ([Apple Developer][19])
22. Lottie-SPM install guide ([GitHub][23])
23. NN/g dashboard pre-attentive article ([Nielsen Norman Group][22])
24. WADA blood detection of testosterone esters ([World Anti Doping Agency][24])

---

*Everything from models and math to UX, AI, and QA is now in one place—ready for your code assistant to execute.*

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
[19]: https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/requestauthorization "Failed"
[20]: https://developer.apple.com/videos/play/wwdc2023/10037 "Explore pie charts and interactivity in Swift Charts - WWDC23 - Videos - Apple Developer"
[21]: https://developer.apple.com/design/human-interface-guidelines/charting-data "Charting data | Apple Developer Documentation"
[22]: https://www.nngroup.com/articles/dashboards-preattentive/?utm_source=chatgpt.com "Dashboards: Making Charts and Graphs Easier to Understand - NN/g"
[23]: https://github.com/airbnb/lottie-spm?utm_source=chatgpt.com "airbnb/lottie-spm: Swift Package Manager support for Lottie ... - GitHub"
[24]: https://www.wada-ama.org/en/resources/scientific-research/detection-testosterone-esters-blood-sample?utm_source=chatgpt.com "Detection of testosterone esters in blood sample - WADA"


[1]: https://github.com/airbnb/lottie-ios "airbnb/lottie-ios: An iOS library to natively render After Effects vector ..."
