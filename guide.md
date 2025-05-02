Okay, this is an excellent and highly detailed implementation plan. Let's transform it into the precise checklist format suitable for a code assistant. Each item will be a specific, actionable task with an unchecked checkbox `[ ]`.

Here is the detailed checklist:

**Testosterone Pharmacokinetics Simulation App – Detailed Implementation Checklist**

**Instructions for Code Assistant:** Follow this checklist step-by-step. Each `[ ]` represents a task to complete. Implement the code exactly as described, using the provided names, structures, formulas, and UI components. Assume you are working within an Xcode project targeting iOS 16+ and macOS 13+.

---

### Story 1: Project Setup and Structure

*   [x] **Initialize SwiftUI Project:**
    *   Create a new Xcode project using the **SwiftUI App** template.
    *   Name the project `TestoSim`.
    *   Ensure the targets include **iOS** (and optionally **macOS**).
    *   Set the minimum deployment target to **iOS 16.0** and **macOS 13.0**.
*   [x] **Create Project Groups:**
    *   In the Xcode Project Navigator, create the following groups (folders):
        *   `Models`
        *   `Views`
        *   `ViewModels` (or `Stores`)
        *   `Resources` (for assets like AppIcon later)
*   [x] **Add Frameworks:**
    *   Confirm the **Charts** framework is available (part of SwiftUI on iOS 16+). Add `import Charts` in files that will use it.
    *   *(Optional - If adding Lottie)* Add the Lottie package via Swift Package Manager: `File > Add Packages...`, search for `airbnb/lottie-ios`, and add the package dependency.
*   [x] **Setup SwiftUI App Struct:**
    *   Open the main App struct file (e.g., `TestoSimApp.swift`).
    *   Declare an `@StateObject` for the central data store (which will be created later).
    *   Provide this store as an `@EnvironmentObject` to the `ContentView`.
    ```swift
    import SwiftUI

    @main
    struct TestoSimApp: App {
        @StateObject private var dataStore = AppDataStore() // Implementation follows in Story 3

        var body: some Scene {
            WindowGroup {
                ContentView() // Implementation follows in Story 4
                    .environmentObject(dataStore)
            }
        }
    }
    ```

---

### Story 2: Data Models and Persistence

*   [x] **Define Testosterone Ester Data:**
    *   Create a new Swift file named `EsterData.swift` inside the `Models` group.
    *   Define the `TestosteroneEster` struct:
        *   Make it conform to `Identifiable` and `Codable`.
        *   Include properties: `id: UUID`, `name: String`, `halfLifeDays: Double`.
        *   Define static constants for the supported esters using the provided half-life values:
            *   `propionate`: name "Propionate", halfLifeDays `0.8`
            *   `enanthate`: name "Enanthate", halfLifeDays `4.5`
            *   `cypionate`: name "Cypionate", halfLifeDays `7.0`
            *   `undecanoate`: name "Undecanoate", halfLifeDays `30.0`
        *   Add a static property `all: [TestosteroneEster]` containing all defined esters.
    ```swift
    import Foundation

    struct TestosteroneEster: Identifiable, Codable, Hashable { // Added Hashable for potential use in Pickers
        let id: UUID
        let name: String
        let halfLifeDays: Double

        // Default initializer if needed, or rely on memberwise
        init(id: UUID = UUID(), name: String, halfLifeDays: Double) {
            self.id = id
            self.name = name
            self.halfLifeDays = halfLifeDays
        }

        static let propionate = TestosteroneEster(name: "Propionate", halfLifeDays: 0.8)
        static let enanthate = TestosteroneEster(name: "Enanthate", halfLifeDays: 4.5)
        static let cypionate = TestosteroneEster(name: "Cypionate", halfLifeDays: 7.0)
        static let undecanoate = TestosteroneEster(name: "Undecanoate", halfLifeDays: 30.0)

        static let all: [TestosteroneEster] = [ .propionate, .enanthate, .cypionate, .undecanoate ]
    }
    ```
*   [x] **Define Injection Protocol Model:**
    *   Create a new Swift file named `ProtocolModel.swift` inside the `Models` group.
    *   Define the `InjectionProtocol` struct:
        *   Make it conform to `Identifiable` and `Codable`.
        *   Include properties:
            *   `id: UUID`
            *   `name: String`
            *   `ester: TestosteroneEster`
            *   `doseMg: Double`
            *   `frequencyDays: Double`
            *   `startDate: Date`
            *   `notes: String?` (optional)
            *   `bloodSamples: [BloodSample]` (initialize as `[]`. `BloodSample` defined next).
    ```swift
    import Foundation

    struct InjectionProtocol: Identifiable, Codable {
        var id: UUID = UUID() // Use var if you might need to replace it during edits
        var name: String
        var ester: TestosteroneEster
        var doseMg: Double
        var frequencyDays: Double
        var startDate: Date
        var notes: String?
        var bloodSamples: [BloodSample] = [] // BloodSample struct defined next
    }
    ```
*   [x] **Define Bloodwork Model:**
    *   Create a new Swift file named `BloodworkModel.swift` inside the `Models` group.
    *   Define the `BloodSample` struct:
        *   Make it conform to `Identifiable` and `Codable`.
        *   Include properties:
            *   `id: UUID`
            *   `date: Date`
            *   `value: Double`
            *   `unit: String` (e.g., "ng/dL" or "nmol/L")
    ```swift
    import Foundation

    struct BloodSample: Identifiable, Codable, Hashable { // Added Hashable for ForEach iteration if needed
        let id: UUID
        let date: Date
        let value: Double
        let unit: String

        // Default initializer if needed
        init(id: UUID = UUID(), date: Date, value: Double, unit: String) {
            self.id = id
            self.date = date
            self.value = value
            self.unit = unit
        }
    }
    ```
*   [x] **Define User Profile Model:**
    *   Create a new Swift file named `ProfileModel.swift` inside the `Models` group.
    *   Define the `UserProfile` struct:
        *   Make it conform to `Codable`.
        *   Include properties:
            *   `id: UUID`
            *   `name: String`
            *   `unit: String` (default "ng/dL")
            *   `calibrationFactor: Double` (default `1.0`)
            *   `protocols: [InjectionProtocol]` (initialize as `[]`)
    ```swift
    import Foundation

    struct UserProfile: Codable {
        var id: UUID = UUID()
        var name: String = "My Profile"
        var unit: String = "ng/dL" // Default unit
        var calibrationFactor: Double = 1.0 // Default calibration
        var protocols: [InjectionProtocol] = []
    }
    ```
*   [x] **Implement Default Data Creation:**
    *   Inside the `AppDataStore` class initializer (to be created in Story 3), implement logic to create a default `UserProfile` if none is loaded.
    *   This default profile should include at least one sample `InjectionProtocol`. Example:
        *   Name: "Default TRT"
        *   Ester: `.cypionate`
        *   Dose: `100.0` mg
        *   Frequency: `7.0` days
        *   Start Date: `Date()` (today)
*   [x] **Implement Persistence Logic (in AppDataStore):**
    *   Inside the `AppDataStore` class (Story 3), add methods for saving and loading the `UserProfile`.
    *   **Saving:** Create `func saveProfile()`. Use `JSONEncoder` to encode the `profile` property and save it to `UserDefaults` under the key `"userProfileData"`.
    *   **Loading:** In the `init()` of `AppDataStore`, attempt to load data from `UserDefaults` using the key `"userProfileData"`. Use `JSONDecoder` to decode it into a `UserProfile`. If loading fails or no data exists, create the default profile (as defined in the previous step). Handle potential decoding errors (e.g., using `try?` and falling back to default).

---

### Story 3: Pharmacokinetic Simulation Logic

*   [x] **Define Simulation Parameters:**
    *   In `AppDataStore`, add properties to control the simulation duration.
    *   `let simulationDurationDays: Double = 90.0` (or adjust based on half-life later if desired).
    *   Add a computed property `simulationEndDate` based on the *selected* protocol's `startDate` and `simulationDurationDays`.
*   [x] **Implement Level Calculation Function:**
    *   Create a helper function, perhaps within `AppDataStore` or as a static method, to calculate the concentration at a specific time `t` for a given protocol.
    *   Signature idea: `func calculateLevel(at targetDate: Date, for protocol: InjectionProtocol, using calibrationFactor: Double) -> Double`
    *   Implement the logic based on the formula:
        1.  Calculate time `t_days` in days from `protocol.startDate` to `targetDate`. Return 0 if `targetDate` is before `startDate`.
        2.  Calculate the elimination constant `k = log(2) / protocol.ester.halfLifeDays`. Use `log` from `Foundation` (natural logarithm).
        3.  Initialize `totalLevel = 0.0`.
        4.  Iterate through injection indices `n = 0, 1, 2, ...`.
        5.  For each `n`, calculate injection time `injTime_days = Double(n) * protocol.frequencyDays`.
        6.  If `injTime_days > t_days`, break the loop.
        7.  Calculate time since this injection: `timeDiff_days = t_days - injTime_days`.
        8.  Calculate contribution: `contribution = protocol.doseMg * exp(-k * timeDiff_days)`. Use `exp` from `Foundation`.
        9.  Add contribution to `totalLevel`.
        10. After the loop, multiply `totalLevel` by the `calibrationFactor`.
        11. Return the final `totalLevel`.
    ```swift
    // Example placement inside AppDataStore or a dedicated utility struct/file
    func calculateLevel(at targetDate: Date, for protocol: InjectionProtocol, using calibrationFactor: Double) -> Double {
        let t_days = targetDate.timeIntervalSince(protocol.startDate) / (24 * 3600) // Time in days since start
        guard t_days >= 0 else { return 0.0 }

        guard protocol.ester.halfLifeDays > 0 else { return 0.0 } // Avoid division by zero if halfLife is 0
        let k = log(2) / protocol.ester.halfLifeDays // Natural log

        var totalLevel = 0.0
        var injIndex = 0
        while true {
            let injTime_days = Double(injIndex) * protocol.frequencyDays
            // Optimization: If frequency is 0 or negative, only consider the first injection
            if protocol.frequencyDays <= 0 && injIndex > 0 { break }

            if injTime_days > t_days { break } // Stop if injection time is after target time

            let timeDiff_days = t_days - injTime_days
            if timeDiff_days >= 0 { // Ensure we only calculate for times after injection
                 let contribution = protocol.doseMg * exp(-k * timeDiff_days)
                 totalLevel += contribution
            }

            // Check for infinite loop condition if frequency is 0
             if protocol.frequencyDays <= 0 { break }

            injIndex += 1
             // Safety break if index gets excessively large (e.g., > 10000) though unlikely with date limits
             if injIndex > 10000 { break }
        }

        return totalLevel * calibrationFactor
    }
    ```
*   [x] **Define DataPoint Struct:**
    *   Create a simple struct to hold simulation data points for the chart. Place it maybe near `AppDataStore` or in `Models`.
    ```swift
    import Foundation

    struct DataPoint: Identifiable {
        let id = UUID() // For ForEach iteration if needed
        let time: Date // Use Date for direct use with Swift Charts axis
        let level: Double
    }
    ```
*   [x] **Implement Data Series Generation Function:**
    *   Create a method in `AppDataStore`, e.g., `func generateSimulationData(for protocol: InjectionProtocol) -> [DataPoint]`.
    *   Determine the `endDate` (e.g., `protocol.startDate + simulationDurationDays * 24 * 3600`).
    *   Define the time step (e.g., `stepInterval: TimeInterval = 24 * 3600` for daily points, or smaller like `4 * 3600` for 4-hourly).
    *   Iterate from `protocol.startDate` up to `endDate` with the chosen `stepInterval`.
    *   In each step, call `calculateLevel(at: currentDate, for: protocol, using: profile.calibrationFactor)`.
    *   Create a `DataPoint` with the `currentDate` and calculated `level`.
    *   Append the `DataPoint` to an array.
    *   Return the completed array of `DataPoint`.
*   [x] **Setup AppDataStore Class:**
    *   Create a new Swift file named `AppDataStore.swift` inside the `ViewModels` group.
    *   Define the class `AppDataStore: ObservableObject`. Mark it with `@MainActor`.
    *   Add `@Published var profile: UserProfile`.
    *   Add `@Published var simulationData: [DataPoint] = []`.
    *   Add `@Published var selectedProtocolID: UUID?`.
    *   Add `@Published var isPresentingProtocolForm = false`. // For add/edit sheet
    *   Add `@Published var protocolToEdit: InjectionProtocol?`. // To know if adding or editing

    *   Implement the `init()` method:
        *   Call the loading logic (defined in Story 2) to load `profile` from UserDefaults or create a default one.
        *   If `profile.protocols` is not empty, set `selectedProtocolID = profile.protocols.first?.id`.
        *   Call `recalcSimulation()` to generate initial data for the selected protocol.
*   [x] **Implement AppDataStore Methods:**
    *   Implement `func addProtocol(_ newProtocol: InjectionProtocol)`:
        *   Append `newProtocol` to `profile.protocols`.
        *   Optionally set `selectedProtocolID = newProtocol.id`.
        *   Call `recalcSimulation()`.
        *   Call `saveProfile()`.
    *   Implement `func updateProtocol(_ updatedProtocol: InjectionProtocol)`:
        *   Find the index of the protocol with the same `id` in `profile.protocols`.
        *   If found, replace the protocol at that index with `updatedProtocol`.
        *   If the updated protocol is the currently selected one (`updatedProtocol.id == selectedProtocolID`), call `recalcSimulation()`.
        *   Call `saveProfile()`.
    *   Implement `func removeProtocol(at offsets: IndexSet)` (for List onDelete):
        *   Remove protocols from `profile.protocols` using the provided `offsets`.
        *   If the deleted protocol was the selected one, potentially select the first remaining one or set `selectedProtocolID = nil`.
        *   Recalculate simulation data if selection changed or list is now empty.
        *   Call `saveProfile()`.
    *   Implement `func selectProtocol(id: UUID)`:
        *   Set `selectedProtocolID = id`.
        *   Call `recalcSimulation()`.
    *   Implement `func recalcSimulation()`:
        *   Guard that `selectedProtocolID` is not nil and find the corresponding `protocol` in `profile.protocols`.
        *   If found, call `generateSimulationData(for: foundProtocol)` and assign the result to the `@Published var simulationData`.
        *   If not found (e.g., protocol was deleted), clear `simulationData = []`.
        *   *(Optimization Note: Consider DispatchQueue only if generation proves slow for very long durations/small steps)*.
    *   Implement placeholder `func calibrateProtocol(_ protocol: InjectionProtocol)` (logic in Story 6).
    *   Implement placeholder `func predictedLevel(on date: Date, for protocol: InjectionProtocol) -> Double` (reuse `calculateLevel`).
*   [x] **Implement Helper Function: Injection Dates:**
    *   Add this instance method to the `InjectionProtocol` struct in `ProtocolModel.swift`.
    ```swift
    // Inside struct InjectionProtocol
    func injectionDates(from simulationStartDate: Date, upto endDate: Date) -> [Date] {
        var dates: [Date] = []
        var current = startDate // Protocol's own start date
        var injectionIndex = 0

        // Find the first injection date that is on or after the simulation's start date
        while current < simulationStartDate {
            // Check for zero/negative frequency to avoid infinite loop
            guard frequencyDays > 0 else {
                // If first injection is before sim start, add it if it's the *only* injection
                if injectionIndex == 0 && current <= endDate { dates.append(current) }
                return dates // Only one injection possible
            }
            injectionIndex += 1
            current = Calendar.current.date(byAdding: .day, value: Int(frequencyDays * Double(injectionIndex)), to: startDate)! // More robust date calculation
            // Safety Break
            if injectionIndex > 10000 { break }
        }


        // Now add dates within the simulation range [simStartDate, endDate]
        // Reset index based on where we are starting relative to protocol start
        injectionIndex = Int(round(current.timeIntervalSince(startDate) / (frequencyDays * 24 * 3600)))


        while current <= endDate {
            // Only add if it's within the simulation's actual display window start
             if current >= simulationStartDate {
                 dates.append(current)
             }

             // Check for zero/negative frequency
             guard frequencyDays > 0 else { break } // Should only add the first one if freq <= 0

            injectionIndex += 1
            // Use calendar calculation for adding days to avoid potential DST issues if frequency isn't integer days
            // However, since frequency is Double, TimeInterval is more direct. Stick to TimeInterval for consistency with PK math.
            current = startDate.addingTimeInterval(Double(injectionIndex) * frequencyDays * 24 * 3600)
             // Safety Break
             if injectionIndex > 10000 { break }
        }
        return dates
    }
    ```
    *   *Correction:* The chart needs dates relative to the simulation window, not just the protocol start. The `injectionDates` function needs the simulation's start/end. Update signature and logic.
*   [x] **Implement Helper Function: Formatting Value:**
    *   Add a helper function, maybe in `AppDataStore` or a utility file, to format numbers.
    ```swift
    func formatValue(_ value: Double, unit: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if unit == "nmol/L" {
            formatter.maximumFractionDigits = 1
        } else { // ng/dL typically whole numbers
            formatter.maximumFractionDigits = 0
        }
        formatter.minimumFractionDigits = formatter.maximumFractionDigits // Ensure consistency
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // Add unit conversion helper if needed later, for now assume values are stored correctly
    // let NGDL_PER_NMOL = 28.85
    ```

---

### Story 4: UI – Protocol List & Navigation

*   [x] **Implement ContentView:**
    *   Create `ContentView.swift` in the `Views` group.
    *   Use `NavigationStack`.
    *   Embed `ProtocolListView`.
    *   Inject `AppDataStore` using `@EnvironmentObject`.
    ```swift
    import SwiftUI

    struct ContentView: View {
        @EnvironmentObject var dataStore: AppDataStore

        var body: some View {
            NavigationStack {
                ProtocolListView()
            }
        }
    }
    ```
*   [x] **Implement ProtocolListView:**
    *   Create `ProtocolListView.swift` in the `Views` group.
    *   Use `@EnvironmentObject var dataStore: AppDataStore`.
    *   Use a `List` to display `dataStore.profile.protocols`.
    *   Inside the `List`, use `ForEach` over the protocols.
    *   Each row should be a `NavigationLink` pointing to `ProtocolDetailView(protocol: proto)`.
    *   The `NavigationLink` label should display the protocol `name` (e.g., `.headline`) and a summary (`dose`, `ester`, `frequency` - e.g., `.subheadline`, `.secondary`).
    *   Add `.navigationTitle("Protocols")`.
    *   Handle the case where `dataStore.profile.protocols` is empty (display a message like "No protocols yet. Tap + to add one.").
*   [x] **Implement List Delete Functionality:**
    *   Add the `.onDelete(perform: deleteItems)` modifier to the `ForEach` inside the `List`.
    *   Implement the `private func deleteItems(at offsets: IndexSet)` method in `ProtocolListView`.
    *   This method should call the corresponding removal function in `dataStore` (e.g., `dataStore.removeProtocol(at: offsets)`).
*   [x] **Implement Toolbar Actions:**
    *   Add a `.toolbar` modifier to the `List` or containing `VStack`.
    *   Add a `ToolbarItem(placement: .primaryAction)` with a `Button` containing a `Label("Add Protocol", systemImage: "plus")`.
    *   The button's action should set `dataStore.protocolToEdit = nil` and `dataStore.isPresentingProtocolForm = true`.
    *   Add a `ToolbarItem(placement: .navigationBarLeading)` with a `NavigationLink` to `ProfileView()` using a `Label("Profile", systemImage: "person.circle")`.
*   [x] **Implement Sheet Presentation for Form:**
    *   Add the `.sheet(isPresented: $dataStore.isPresentingProtocolForm)` modifier.
    *   The sheet's content should be `ProtocolFormView(protocolToEdit: dataStore.protocolToEdit)`. ( `ProtocolFormView` is defined later).
    *   Pass the `environmentObject` to the sheet content: `.environmentObject(dataStore)`.
*   [x] **Implement ProfileView:**
    *   Create `ProfileView.swift` in the `Views` group.
    *   Use `@EnvironmentObject var dataStore: AppDataStore`.
    *   Use a `Form` for the layout.
    *   Add a `Section("User")` with a `TextField("Name", text: $dataStore.profile.name)`.
    *   Add a `Section("Settings")` with a `Picker("Preferred Unit", selection: $dataStore.profile.unit)` containing options "ng/dL" and "nmol/L". Use `Text` views for the options.
    *   Add a `Section("Calibration")` displaying the current `dataStore.profile.calibrationFactor` (read-only for now, or add a Reset button).
        ```swift
        Text("Model Calibration Factor: \(dataStore.profile.calibrationFactor, specifier: "%.2f")")
        Button("Reset Calibration to 1.0") {
            dataStore.profile.calibrationFactor = 1.0
            dataStore.recalcSimulation() // Recalculate if factor changed
             dataStore.saveProfile() // Save change
        }
        ```
    *   Use `.onChange` or `.onDisappear` to trigger `dataStore.saveProfile()` when relevant profile properties change. Add `.navigationTitle("Profile Settings")`.
    *   *Note on Binding:* To bind directly to `dataStore.profile.name` etc., ensure `AppDataStore` publishes changes correctly when sub-properties of `profile` are modified. Wrapping setters in `objectWillChange.send()` might be needed if direct binding doesn't trigger saves, or trigger save `onDisappear`. A simple approach is adding explicit save calls.

---

### Story 5: UI – Protocol Detail & Simulation Chart

*   [ ] **Implement ProtocolDetailView Structure:**
    *   Create `ProtocolDetailView.swift` in the `Views` group.
    *   Add `@EnvironmentObject var dataStore: AppDataStore`.
    *   Add `let protocol: InjectionProtocol` property (passed via `NavigationLink`).
    *   Use a `ScrollView` containing a `VStack(alignment: .leading, spacing: 16)`.
    *   Add `Text` views to display the protocol summary (Dose, Ester, Frequency).
    *   Add a placeholder where the chart will go.
    *   Use `.padding()` on the `VStack`.
    *   Set `.navigationTitle(protocol.name)`.
    *   Add `.navigationBarTitleDisplayMode(.inline)` if preferred.
*   [ ] **Implement Detail View Data Loading:**
    *   Add an `.onAppear` modifier to the main view inside `ProtocolDetailView`.
    *   Inside `.onAppear`, call `dataStore.selectProtocol(id: protocol.id)`. This ensures the `simulationData` in the store corresponds to *this* protocol when the view appears.
*   [ ] **Implement Last Bloodwork Display:**
    *   Inside the `VStack`, add logic to display info about the latest blood sample:
    *   Find the latest sample: `let latestSample = protocol.bloodSamples.max(by: { $0.date < $1.date })`.
    *   If `latestSample` exists:
        *   Calculate the model's prediction for that date: `let modelPrediction = dataStore.calculateLevel(at: latestSample.date, for: protocol, using: dataStore.profile.calibrationFactor)`
        *   Display `Text` showing the sample date, measured value (`formatValue`), and the model prediction (`formatValue`) using the profile's preferred unit (`dataStore.profile.unit`). Format the date clearly.
*   [ ] **Implement Detail View Action Buttons:**
    *   Add an `HStack` below the chart area.
    *   Add a `Button` with `Label("Add Bloodwork", systemImage: "drop.fill")`.
        *   Action: Set `@State private var showingAddBloodSheet = false` to `true`.
    *   Add a `Button` with `Label("Recalibrate Model", systemImage: "slider.horizontal.3")`.
        *   Action: Call `dataStore.calibrateProtocol(protocol)` (implement logic in Story 6). Show confirmation alert: `@State private var showingCalibrateConfirm = false`. Set this state bool to true in the button action.
        *   Disable this button if `protocol.bloodSamples.isEmpty`. Use `.disabled(protocol.bloodSamples.isEmpty)`.
*   [ ] **Implement Detail View Toolbar/Sheet:**
    *   Add a `.toolbar` modifier.
    *   Add `ToolbarItem(placement: .primaryAction)` with a `Button("Edit")`.
        *   Action: Set `dataStore.protocolToEdit = protocol` and `dataStore.isPresentingProtocolForm = true`.
    *   Add the `.sheet(isPresented: $showingAddBloodSheet)` modifier.
        *   Content: `AddBloodworkView(protocol: protocol)`. Pass environment object. (`AddBloodworkView` defined in Story 6).
    *   Add the `.alert("Calibration Updated", isPresented: $showingCalibrateConfirm)` modifier with a dismiss Button("OK").
*   [x] **Implement TestosteroneChart View:**
    *   Create `TestosteroneChart.swift` in the `Views` group (or embed code directly in `ProtocolDetailView`).
    *   Add `@EnvironmentObject var dataStore: AppDataStore`.
    *   Add `let protocol: InjectionProtocol`.
    *   Import `Charts`.
    *   The `body` should return a `Chart { ... }`.
    *   Set a frame, e.g., `.frame(height: 300)`.
*   [x] **Implement Chart: Simulation Curve:**
    *   Inside `Chart`, add `ForEach(dataStore.simulationData) { point in ... }`. (Ensure `DataPoint` is `Identifiable`).
    *   Inside the `ForEach`, add `LineMark(x: .value("Date", point.time), y: .value("Level", point.level))`. Style with `.foregroundStyle(.blue)`.
    *   Inside the `ForEach`, also add `AreaMark(x: .value("Date", point.time), y: .value("Level", point.level))`. Style with `.foregroundStyle(LinearGradient(...))` using blue opacity gradient from top (e.g., 0.3) to bottom (0.0).
*   [x] **Implement Chart: Injection Markers:**
    *   Calculate the simulation start/end dates needed for `injectionDates`. Use `dataStore.simulationData.first?.time` and `dataStore.simulationData.last?.time` if available, or calculate based on `protocol.startDate` and `simulationDurationDays`.
    *   Add `ForEach(protocol.injectionDates(from: simStartDate, upto: simEndDate), id: \.self) { injDate in ... }`.
    *   Inside, add `RuleMark(x: .value("Injection Date", injDate))`.
    *   Style it: `.lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))`, `.foregroundStyle(.gray)`.
    *   Add an annotation: `.annotation(position: .bottom, alignment: .center) { Image(systemName: "syringe").font(.caption).foregroundColor(.gray) }`.
*   [x] **Implement Chart: Bloodwork Points:**
    *   Add `ForEach(protocol.bloodSamples) { sample in ... }`.
    *   Inside, add `PointMark(x: .value("Sample Date", sample.date), y: .value("Sample Level", sample.value))`.
    *   Style it: `.foregroundStyle(.red)`.
    *   Add annotation: `.annotation(position: .overlay, alignment: .top) { Text(formatValue(sample.value, unit: sample.unit)).font(.caption).foregroundColor(.red).padding(.bottom, 8) }`. Adjust position/padding as needed.
    *   *(Optional: Add `.symbol(by: .value("Data Type", "Bloodwork"))` if a legend distinguishing points is desired).*
*   [x] **Implement Chart Axes Customization:**
    *   Add `.chartXAxis { AxisMarks(values: .automatic(desiredCount: 8)) { AxisGridLine() AxisValueLabel(format: .dateTime.month().day(), centered: true) } }`. Adjust desiredCount and format as needed.
    *   Add `.chartYAxis { AxisMarks { AxisGridLine() AxisValueLabel() } }`.
    *   Add `.chartYAxisLabel("Level (\(dataStore.profile.unit))")`.
    *   Add `.chartXAxisLabel("Date")`.
    *   *(Optional: Hide legend if automatically generated and not needed: `.chartLegend(.hidden)`)*.

---

### Story 6: UI – Add Bloodwork and Calibration

*   [ ] **Implement AddBloodworkView Structure:**
    *   Create `AddBloodworkView.swift` in the `Views` group.
    *   Add `@EnvironmentObject var dataStore: AppDataStore`.
    *   Add `@Environment(\.dismiss) var dismiss`.
    *   Add `let protocol: InjectionProtocol`.
    *   Add `@State private var date: Date = Date()`.
    *   Add `@State private var valueText: String = ""`.
    *   Add `@State private var selectedUnit: String = "ng/dL"`. // Default or initialize from profile.unit
    *   Use a `NavigationView` (to get a toolbar in the sheet). Inside, use a `Form`. Set a `.navigationTitle("Add Blood Test Result")`.
*   [ ] **Implement AddBloodworkView Fields:**
    *   Inside the `Form`, add a `DatePicker("Date", selection: $date, in: protocol.startDate..., displayedComponents: [.date, .hourAndMinute])`. Limit the range from protocol start date onwards.
    *   Add a `TextField("Testosterone Level", text: $valueText)`. Use `.keyboardType(.decimalPad)`.
    *   Add a `Picker("Unit", selection: $selectedUnit)` with `Text("ng/dL").tag("ng/dL")` and `Text("nmol/L").tag("nmol/L")`.
*   [ ] **Implement AddBloodworkView Save/Cancel Toolbar:**
    *   Add a `.toolbar` to the `NavigationView`.
    *   Add `ToolbarItem(placement: .navigationBarLeading)` with a `Button("Cancel") { dismiss() }`.
    *   Add `ToolbarItem(placement: .navigationBarTrailing)` with a `Button("Save") { saveBloodwork() }`. Disable the Save button if `valueText` is empty or not a valid number: `.disabled(Double(valueText) == nil)`.
*   [ ] **Implement AddBloodworkView Save Logic:**
    *   Create `private func saveBloodwork()`.
    *   Inside the function:
        1.  Guard that `valueText` can be converted to a `Double`, else return. `guard let value = Double(valueText) else { return }`.
        2.  Create a `newSample = BloodSample(date: date, value: value, unit: selectedUnit)`.
        3.  Find the index of the current `protocol` in `dataStore.profile.protocols`.
        4.  If found, append `newSample` to `dataStore.profile.protocols[index].bloodSamples`.
        5.  Call `dataStore.saveProfile()`.
        6.  Call `dismiss()`.
*   [ ] **Implement Calibration Logic Function:**
    *   Implement the `func calibrateProtocol(_ protocolToCalibrate: InjectionProtocol)` method in `AppDataStore`.
    *   Inside the function:
        1.  Find the protocol in the `profile.protocols` array using `protocolToCalibrate.id`. Ensure it exists.
        2.  Get the latest blood sample: `guard let latestSample = protocolToCalibrate.bloodSamples.max(by: { $0.date < $1.date }) else { return }` (or handle error/message).
        3.  Calculate the model's prediction *at the sample date*, using the *current* calibration factor: `let modelPrediction = calculateLevel(at: latestSample.date, for: protocolToCalibrate, using: profile.calibrationFactor)`.
        4.  Guard against division by zero or near-zero: `guard modelPrediction > 0.01 else { print("Model prediction too low, cannot calibrate."); return }`.
        5.  Calculate the required factor *relative to the current one*: `let adjustmentRatio = latestSample.value / modelPrediction`.
        6.  Update the profile's factor: `profile.calibrationFactor *= adjustmentRatio`.
        7.  Call `recalcSimulation()` to update the chart data with the new factor.
        8.  Call `saveProfile()` to persist the new factor.
*   [ ] **Connect Calibration UI:**
    *   Verify the "Recalibrate Model" button in `ProtocolDetailView` correctly calls `dataStore.calibrateProtocol(protocol)` and sets the state variable to show the confirmation alert.

---

### Story 7: Polish and Testing

*   [ ] **UI Polish: Appearance:**
    *   Test the app in both **Light Mode** and **Dark Mode**. Ensure text is legible and colors (especially chart colors) look good. Adjust opacities or use adaptive colors if needed.
    *   Check font sizes and text wrapping. Ensure UI elements resize reasonably on different screen sizes (e.g., iPhone vs iPad if supported).
    *   Verify padding and spacing provide a clean layout.
*   [ ] **UI Polish: App Icon & Launch Screen:**
    *   *(Optional)* Add a custom AppIcon asset set in `Resources`.
    *   *(Optional)* Configure a basic Launch Screen (e.g., using `Info.plist` settings or a Launch Screen storyboard - though SwiftUI prefers quick launch).
*   [ ] **UI Polish: Optional Animation:**
    *   *(Optional)* If Lottie was included, integrate a simple `LottieView` animation (e.g., a checkmark animation shown briefly after saving or calibration).
*   [ ] **Accessibility:**
    *   *(Basic Pass)* Ensure standard controls (Buttons, TextFields, Pickers) have default accessibility support. Add `.accessibilityLabel` or `.accessibilityHint` to custom controls or complex elements if time permits (especially chart elements).
*   [ ] **Testing: Simulation Accuracy:**
    *   Manually run simulations for known protocols (e.g., 100mg Cypionate weekly). Check if the plotted curve visually matches expected pharmacokinetics (e.g., reaches steady state, trough levels relative to peak look reasonable based on half-life). Print key values (peak, trough after X weeks) to console if needed for verification.
    *   Test with different esters (Propionate, Enanthate, Undecanoate) to ensure their different half-lives produce visibly different curve shapes.
*   [ ] **Testing: Calibration:**
    *   Add a blood sample manually. Note the model's prediction at that point.
    *   Press "Recalibrate Model".
    *   Verify the chart curve shifts and now passes through (or very close to) the blood sample point used for calibration.
    *   Verify the `calibrationFactor` stored in `UserProfile` has changed.
*   [ ] **Testing: Bug Fixes & Edge Cases:**
    *   Test deleting the last protocol. Does the UI update gracefully?
    *   Test adding the first protocol.
    *   Test editing a protocol (dose, frequency, ester). Does the chart update correctly when returning to the detail view?
    *   Attempt to add bloodwork with a date *before* the protocol start date (should be prevented by the `DatePicker` range).
    *   Attempt to save bloodwork with non-numeric input (Save button should be disabled).
    *   Test calibration with only one sample. Test recalibrating with a second, different sample.
*   [ ] **Documentation & Preparation:**
    *   Create a basic `README.md` file in the project root explaining the app's purpose and how to build/run it.
    *   Add comments to complex code sections (especially `calculateLevel` and `calibrateProtocol`).
    *   Add a `LICENSE` file (e.g., MIT).
*   [ ] **Multi-Platform Testing (If Applicable):**
    *   If macOS target was enabled, run the app on macOS. Check for any layout issues or platform-specific behaviors that need adjustment (e.g., toolbar items, sheet presentation).

---

This checklist should provide a clear, sequential path for the code assistant to implement the TestoSim application.