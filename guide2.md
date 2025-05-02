**Planning TestoSim improvement**

To improve the app, we'll add new testosterone esters, steroids, and fix some modeling accuracy. The goal is to include features like notifications, a cycle builder, AI insights, and a user profile. I'll need to gather current data on steroid half-lives, esters, and common anabolic steroids. I'll also research SwiftUI design ideas for charts, UX best practices, and guidelines for notifications and local storage. We need input from at least 15 reputable sources for a detailed part 2 of the implementation guide.

**Planning Part 2 Improvements**

For Part 2, I'll be adding new features like user profiles, notifications, cycle builders, and AI insights. I’ll organize this with sections: an overview of the improvements, additional pharmacokinetic data (new steroid esters and half-lives), modeling refinements (like multi-compartment models), and improved UI/UX designs (Lottie animations, SwiftUI charts). I'll need to gather sources for half-life values, modeling approaches, and SwiftUI guidelines. I'll also look up relevant search terms for testosterone esters, pharmacokinetics, and Apple documentation.

**Gathering reliable sources**

I need to collect at least 15 sources from a mix of reputable domains: PubMed, NCBI Books, FDA documents, and other trusted resources. I could also look at academic journals and bodybuilding websites, but it's important to focus on credible ones for accuracy. I'll search for the relevant information by running queries to gather these sources. After that, I'll be sure to cite everything clearly, so I have strong references for the implementation guide.


**Gathering more sources**

I’ll need to gather at least 15 reliable sources from a variety of domains like PubMed, academic journals, and official documents like FDA guidelines and Apple Developer docs. I’ll also need some sources for Lottie animations in SwiftUI, so I’m thinking of checking out GitHub and other design guidelines. To find these resources, I’ll search for terms like "Lottie SwiftUI animation guide" to ensure I get the most current and relevant information.


**Structuring Part 2 Stories**

I now have several sources gathered, so it’s time to reference them properly in my answer. The next step is crafting Part 2 of the Implementation Guide in checklist format, with newly added data models like additional esters and steroids. I’ll continue from the existing Stories 1-7 and create new stories numbered 8-14. I'll focus on integrating these stories incrementally as we move from polishing and testing to implementing these new features. This structure will allow us to add more detail and maintain clear progression.

**Structuring Part 2 Task List**

I need to organize tasks for parts of Story 8 through Story 15. For example, Story 8 involves expanding data with additional esters and steroids, while Story 9 focuses on refining pharmacokinetic models. Story 10 will add multiple administration routes, and Stories 11 and 12 prioritize user profile improvements and scheduling features. Story 13 tackles cycle building with AI insights, and Story 14 is about UI/UX enhancements. Story 15 is for final testing. I'll include proper headers and a summary paragraph as the guide specifies, along with citations throughout the document.


Thought for 55 seconds


Below is **Part 2 IMPLEMENTATION GUIDE.md** — a continuation of the original checklist that adds richer data, more accurate PK math, new user-facing features (cycle builder, reminders, AI insights), and polish for an “App Store-ready” SwiftUI experience.
It introduces **Stories 8 - 14**; each task is an unchecked checkbox `[ ]` you can drop straight into Xcode tickets.

---

## Story 8 – Expand the Compound Library

*Data models for many esters & popular AAS, ready for simulation and cycle-planning.*

* [ ] **Create `Compound.swift` in *Models***

  ```swift
  struct Compound: Identifiable, Codable, Hashable {
      enum Class : String, Codable { case testosterone, nandrolone, trenbolone, boldenone /*…*/ }
      enum Route : String, Codable { case intramuscular, subcutaneous, oral, transdermal }
      let id: UUID
      var commonName: String
      var classType: Class
      var ester: String?        // e.g. "Phenylpropionate"
      var halfLifeDays: Double  // default literature t½
      var defaultBioavailability: Double // 1.0 IM/SC, 0.05 oral TU etc.
      var defaultAbsorptionRateKa: Double //  day-¹  (see Story 9)
  }
  ```

* [ ] **Populate `CompoundLibrary.swift`** with static constants & an `all` array.
  Use the half-lives below as defaults (users/calibration may override):

  | Compound                          | Ester   | t½ (days) | Sources |
  | --------------------------------- | ------- | --------- | ------- |
  | **Testosterone Acetate**          | Acetate | ≈1.0      |         |
  | **Testosterone Phenylpropionate** | PP      | ≈4.5      |         |
  | **Testosterone Isocaproate**      | IC      | ≈9        |         |
  | **Testosterone Decanoate**        | Dec     | ≈15       |         |
  | **Nandrolone Decanoate**          | Dec     | 6-12      |         |
  | **Trenbolone Acetate**            | Ac      | 1-2       |         |
  | **Trenbolone Enanthate**          | E       | ≈11       |         |
  | **Boldenone Undecylenate**        | U       | ≈14       |         |

* [ ] **Migrate existing `TestosteroneEster` uses to `Compound`**

  * InjectionProtocol now stores `compound: Compound` instead of `ester`.

* [ ] **Add search & filter utilities** (e.g., `CompoundLibrary.class(_:)`, route filters).

---

## Story 9 – Refined PK Engine

*One-compartment with first-order absorption + elimination, optional dual-phase.*

* [ ] **Create `PKModel.swift`** with:

  ```swift
  struct PKModel {
      static func concentration(
          doseMg: Double,
          tSinceDoseDays t: Double,
          ka: Double,
          ke: Double,
          bio: Double = 1.0,
          Vd_L_per_kg: Double = 1.0,
          bodyWeightKg: Double = 80.0
      ) -> Double {
          guard t >= 0 else { return 0 }
          let F = bio
          let Vd = Vd_L_per_kg * bodyWeightKg
          return (F * doseMg * ka / (Vd * (ka - ke))) * (exp(-ke*t) - exp(-ka*t))
      }
  }
  ```

  *Defaults stem from adult male IM/SC TE models* .

* [ ] **Extend `calculateLevel`**

  * For each previous injection, sum `PKModel.concentration(...)`.
  * Pull `ka`, `ke`, and `bio` from the `Compound` defaults; allow protocol-level overrides.

* [ ] **Add oral & transdermal handling** (e.g., oral TU t½ 2.5 h, F≈0.05) .

* [ ] **Introduce Bayesian calibration placeholder** – multiple blood samples → update ka & ke (future work).

---

## Story 10 – User Profile 2.0 & Persistence

*Demographics, BSA, and optional iCloud sync.*

* [ ] **Augment `UserProfile`**

  ```swift
  var dateOfBirth: Date?
  var heightCm: Double?
  var weightKg: Double?
  var biologicalSex: String? // “male”, “female”, “other”
  var usesICloudSync: Bool = false
  ```

  *Computed var `bodySurfaceArea` using DuBois.*

* [ ] **Switch persistence to CoreData + CloudKit** *(opt-in)*.

  * Model: `UserProfileEntity`, `InjectionProtocolEntity`, `CompoundEntity`.
  * Use Apple’s `new CoreData + CloudKit` template; migrate from UserDefaults.


* [ ] **Add migration helper** that copies old JSON into CoreData on first launch.

---

## Story 11 – Notifications & Adherence

*Remind users when injections or orals are due.*

* [ ] **Request permission** with `UNUserNotificationCenter.current().requestAuthorization`.

* [ ] **Schedule repeating notifications** when a protocol is created/edited:

  ```swift
  var content = UNMutableNotificationContent()
  content.title = "Injection due"
  content.body  = "\(protocol.name) today (\(dose) mg)"
  let trigger = UNTimeIntervalNotificationTrigger(timeInterval: nextDoseSeconds, repeats:false)
  ```



* [ ] **Handle rescheduling** after user logs an injection.

---

## Story 12 – Cycle Builder

*A timeline composer for multi-compound performance cycles.*

* [ ] **Create `Cycle.swift` (Models)** with `name`, `startDate`, `weeks`, `stages:[CycleStage]`.

* [ ] **Each `CycleStage`** references one `InjectionProtocol` and relative start-week.

* [ ] **UI – `CyclePlannerView`**

  * Horizontal `ScrollView` of weeks; drag-&-drop compounds.
  * Use Swift Charts Gantt-like bars plus compound icons.

* [ ] **Tap “Simulate Cycle”** → merges stages into temporary protocols → re-uses PK engine.

---

## Story 13 – AI Insights

*Optional on-device or server LLM summaries.*

* [ ] **Add `InsightsGenerator` service** – pass latest simulation & profile; receive JSON with:

  * Predicted peaks/troughs.
  * Adherence tips (e.g., “consider splitting weekly 200 mg TE into 2×100 mg”).
* [ ] **Prototype with `openAI` or Core ML-powered model (if offline required).**

---

## Story 14 – UI/UX Polish & Animations

*Delightful, accessible, and on-brand.*

* [ ] **Adopt Swift Charts 2-D interactions** (scroll-zoom, selection marks).&#x20;
* [ ] **Animate curve reveal** – `.animation(.easeInOut(duration:1.2), value:dataStore.simulationData)`.
* [ ] **Add Lottie onboarding & success animations** (e.g., injection logged).

  * Import via SPM `airbnb/lottie-ios` ([github.com][1]).
* [ ] **Haptics & sounds** when user records an injection.
* [ ] **Dark-mode friendly color palette** using semantic `Color` assets.

---

## Story 15 – Extended Testing & Validation

* [ ] **Unit-test PKModel** against literature Cmax/Ctrough values for TE, TPP, ND.
* [ ] **UI tests** – notification permission flow, cycle builder drag-drop.
* [ ] **Performance tests** – simulate 5-compound 20-week cycle under 50 ms.

---

### References (ordered by appearance)

1. SC vs IM testosterone PK one-compartment model&#x20;
2. Half-life data for common Sustanon esters&#x20;
3. Nandrolone decanoate elimination profile&#x20;
4. Trenbolone acetate half-life 1-2 days&#x20;
5. Trenbolone enanthate ≈ 11 days&#x20;
6. Boldenone undecylenate PK overview&#x20;
7. Phenylpropionate & isocaproate detectability (WADA)&#x20;
8. Oral TU short half-life 150 min&#x20;
9. Local notification scheduling guide&#x20;
10. Swift Charts documentation (animations, interactions)&#x20;
11. CoreData + CloudKit integration tutorial&#x20;
12. Lottie-iOS library ([github.com][1])

Feel free to adjust t½ defaults or add more compounds; the checklist above slots seamlessly after Story 7 of your original plan and equips TestoSim with the breadth, brains, and beauty to wow first-wave users while leaving room for future cloud sync and AI calibration.

[1]: https://github.com/airbnb/lottie-ios "airbnb/lottie-ios: An iOS library to natively render After Effects vector ..."
