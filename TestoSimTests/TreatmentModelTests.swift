import XCTest
@testable import TestoSim

class TreatmentModelTests: XCTestCase {
    
    // Test dependencies
    var compoundLibrary: CompoundLibrary!
    
    override func setUp() {
        super.setUp()
        compoundLibrary = CompoundLibrary()
    }
    
    override func tearDown() {
        compoundLibrary = nil
        super.tearDown()
    }
    
    // MARK: - Simple Treatment Tests
    
    func testSimpleTreatmentInitialization() {
        // Create a simple treatment
        let treatment = Treatment(
            name: "Test Treatment",
            startDate: Date(),
            notes: "Test notes",
            treatmentType: .simple
        )
        
        // Verify type and properties
        XCTAssertEqual(treatment.treatmentType, .simple)
        XCTAssertEqual(treatment.name, "Test Treatment")
        XCTAssertEqual(treatment.notes, "Test notes")
        
        // Verify default values for type-specific properties
        XCTAssertNil(treatment.totalWeeks)
        XCTAssertNil(treatment.stages)
    }
    
    func testSimpleTreatmentWithCompound() {
        // Get a compound from the library
        guard let testCompound = compoundLibrary.compounds.first else {
            XCTFail("No compounds in library")
            return
        }
        
        // Create a simple treatment with compound
        var treatment = Treatment(
            name: "Test Compound Treatment",
            startDate: Date(),
            notes: "Test notes",
            treatmentType: .simple
        )
        
        // Set simple treatment properties
        treatment.doseMg = 100.0
        treatment.frequencyDays = 7.0
        treatment.compoundID = testCompound.id
        treatment.selectedRoute = Compound.Route.intramuscular.rawValue
        
        // Verify properties
        XCTAssertEqual(treatment.doseMg, 100.0)
        XCTAssertEqual(treatment.frequencyDays, 7.0)
        XCTAssertEqual(treatment.compoundID, testCompound.id)
        XCTAssertEqual(treatment.selectedRoute, Compound.Route.intramuscular.rawValue)
        
        // Verify computed property
        XCTAssertEqual(treatment.contentType, .compound)
    }
    
    func testSimpleTreatmentWithBlend() {
        // Get a blend from the library
        guard let testBlend = compoundLibrary.blends.first else {
            XCTFail("No blends in library")
            return
        }
        
        // Create a simple treatment with blend
        var treatment = Treatment(
            name: "Test Blend Treatment",
            startDate: Date(),
            notes: "Test notes",
            treatmentType: .simple
        )
        
        // Set simple treatment properties
        treatment.doseMg = 100.0
        treatment.frequencyDays = 7.0
        treatment.blendID = testBlend.id
        treatment.selectedRoute = Compound.Route.intramuscular.rawValue
        
        // Verify properties
        XCTAssertEqual(treatment.doseMg, 100.0)
        XCTAssertEqual(treatment.frequencyDays, 7.0)
        XCTAssertEqual(treatment.blendID, testBlend.id)
        XCTAssertEqual(treatment.selectedRoute, Compound.Route.intramuscular.rawValue)
        
        // Verify computed property
        XCTAssertEqual(treatment.contentType, .blend)
    }
    
    func testInjectionDatesCalculation() {
        // Create a simple treatment
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        var treatment = Treatment(
            name: "Test Treatment",
            startDate: startDate,
            treatmentType: .simple
        )
        
        // Set frequency to weekly injections
        treatment.frequencyDays = 7.0
        
        // Calculate injection dates for the past 60 days
        let simulationStartDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let endDate = Date()
        
        let injectionDates = treatment.injectionDates(from: simulationStartDate, upto: endDate)
        
        // Verify that we get correct number of injections
        // Should be approximately 30 days / 7 days per injection = ~4 injections
        // Exact number depends on calendar calculations
        XCTAssertGreaterThanOrEqual(injectionDates.count, 4)
        
        // Verify that the first injection date is on or after the treatment start date
        XCTAssertGreaterThanOrEqual(injectionDates.first!, startDate)
        
        // Verify that the last injection date is before or on the end date
        XCTAssertLessThanOrEqual(injectionDates.last!, endDate)
        
        // Verify that injections are 7 days apart (with small tolerance for calendar calculations)
        for i in 0..<injectionDates.count-1 {
            let days = Calendar.current.dateComponents([.day], from: injectionDates[i], to: injectionDates[i+1]).day ?? 0
            XCTAssertEqual(Double(days), treatment.frequencyDays!, accuracy: 0.1)
        }
    }
    
    // MARK: - Advanced Treatment Tests
    
    func testAdvancedTreatmentInitialization() {
        // Create an advanced treatment
        let treatment = Treatment(
            name: "Test Advanced Treatment",
            startDate: Date(),
            notes: "Test notes",
            treatmentType: .advanced
        )
        
        // Verify type and properties
        XCTAssertEqual(treatment.treatmentType, .advanced)
        XCTAssertEqual(treatment.name, "Test Advanced Treatment")
        XCTAssertEqual(treatment.notes, "Test notes")
        
        // Verify default values for type-specific properties
        XCTAssertNil(treatment.doseMg)
        XCTAssertNil(treatment.frequencyDays)
        XCTAssertNil(treatment.compoundID)
        XCTAssertNil(treatment.blendID)
    }
    
    func testAdvancedTreatmentWithStages() {
        // Get a test compound
        guard let testCompound = compoundLibrary.compounds.first else {
            XCTFail("No compounds in library")
            return
        }
        
        // Create an advanced treatment
        var treatment = Treatment(
            name: "Test Advanced Treatment",
            startDate: Date(),
            treatmentType: .advanced
        )
        
        // Set advanced treatment properties
        treatment.totalWeeks = 12
        
        // Create test stages
        let stage1 = TreatmentStage(
            name: "Stage 1",
            startWeek: 0,
            durationWeeks: 6,
            compounds: [
                CompoundStageItem(
                    compoundID: testCompound.id,
                    compoundName: testCompound.fullDisplayName,
                    doseMg: 100.0,
                    frequencyDays: 7.0,
                    administrationRoute: Compound.Route.intramuscular.rawValue
                )
            ]
        )
        
        let stage2 = TreatmentStage(
            name: "Stage 2",
            startWeek: 6,
            durationWeeks: 6,
            compounds: [
                CompoundStageItem(
                    compoundID: testCompound.id,
                    compoundName: testCompound.fullDisplayName,
                    doseMg: 50.0,
                    frequencyDays: 7.0,
                    administrationRoute: Compound.Route.intramuscular.rawValue
                )
            ]
        )
        
        treatment.stages = [stage1, stage2]
        
        // Verify properties
        XCTAssertEqual(treatment.totalWeeks, 12)
        XCTAssertEqual(treatment.stages?.count, 2)
        
        // Verify contentType is nil for advanced treatments
        XCTAssertNil(treatment.contentType)
    }
    
    func testGenerateSimpleTreatments() {
        // Get a test compound
        guard let testCompound = compoundLibrary.compounds.first else {
            XCTFail("No compounds in library")
            return
        }
        
        // Create an advanced treatment
        let startDate = Date()
        var treatment = Treatment(
            name: "Test Advanced Treatment",
            startDate: startDate,
            treatmentType: .advanced
        )
        
        // Set advanced treatment properties
        treatment.totalWeeks = 12
        
        // Create test stages
        let stage1 = TreatmentStage(
            name: "Stage 1",
            startWeek: 0,
            durationWeeks: 6,
            compounds: [
                CompoundStageItem(
                    compoundID: testCompound.id,
                    compoundName: testCompound.fullDisplayName,
                    doseMg: 100.0,
                    frequencyDays: 7.0,
                    administrationRoute: Compound.Route.intramuscular.rawValue
                )
            ]
        )
        
        let stage2 = TreatmentStage(
            name: "Stage 2",
            startWeek: 6,
            durationWeeks: 6,
            compounds: [
                CompoundStageItem(
                    compoundID: testCompound.id,
                    compoundName: testCompound.fullDisplayName,
                    doseMg: 50.0,
                    frequencyDays: 7.0,
                    administrationRoute: Compound.Route.intramuscular.rawValue
                )
            ]
        )
        
        treatment.stages = [stage1, stage2]
        
        // Generate simple treatments
        let simpleTreatments = treatment.generateSimpleTreatments(compoundLibrary: compoundLibrary)
        
        // Verify correct number of simple treatments
        XCTAssertEqual(simpleTreatments.count, 2)
        
        // Verify properties of first simple treatment
        let firstTreatment = simpleTreatments[0]
        XCTAssertEqual(firstTreatment.treatmentType, .simple)
        XCTAssertEqual(firstTreatment.name, "Stage 1 - \(testCompound.fullDisplayName)")
        XCTAssertEqual(firstTreatment.doseMg, 100.0)
        XCTAssertEqual(firstTreatment.frequencyDays, 7.0)
        XCTAssertEqual(firstTreatment.compoundID, testCompound.id)
        XCTAssertEqual(firstTreatment.startDate, startDate)
        
        // Verify properties of second simple treatment
        let secondTreatment = simpleTreatments[1]
        XCTAssertEqual(secondTreatment.treatmentType, .simple)
        XCTAssertEqual(secondTreatment.name, "Stage 2 - \(testCompound.fullDisplayName)")
        XCTAssertEqual(secondTreatment.doseMg, 50.0)
        XCTAssertEqual(secondTreatment.frequencyDays, 7.0)
        XCTAssertEqual(secondTreatment.compoundID, testCompound.id)
        
        // Verify start date of second treatment
        // Should be 6 weeks after start date
        let stage2ExpectedStartDate = Calendar.current.date(byAdding: .day, value: 6 * 7, to: startDate)!
        XCTAssertEqual(secondTreatment.startDate, stage2ExpectedStartDate)
    }
    
    // MARK: - Conversion Tests
    
    func testConversionFromLegacyProtocol() {
        // Create a legacy protocol
        let legacyProtocol = InjectionProtocol(
            name: "Legacy Protocol",
            doseMg: 100.0,
            frequencyDays: 7.0,
            startDate: Date(),
            notes: "Legacy notes"
        )
        
        // Convert to unified treatment
        let treatment = Treatment(from: legacyProtocol)
        
        // Verify type and properties
        XCTAssertEqual(treatment.treatmentType, .simple)
        XCTAssertEqual(treatment.name, "Legacy Protocol")
        XCTAssertEqual(treatment.notes, "Legacy notes")
        XCTAssertEqual(treatment.doseMg, 100.0)
        XCTAssertEqual(treatment.frequencyDays, 7.0)
        XCTAssertEqual(treatment.id, legacyProtocol.id)
    }
    
    func testConversionFromLegacyCycle() {
        // Create a legacy cycle with stages
        let startDate = Date()
        var legacyCycle = Cycle(
            name: "Legacy Cycle",
            startDate: startDate,
            totalWeeks: 12,
            notes: "Legacy cycle notes"
        )
        
        // Add test stages
        var stage1 = CycleStage(
            name: "Cycle Stage 1",
            startWeek: 0,
            durationWeeks: 6
        )
        
        var stage2 = CycleStage(
            name: "Cycle Stage 2",
            startWeek: 6,
            durationWeeks: 6
        )
        
        legacyCycle.stages = [stage1, stage2]
        
        // Convert to unified treatment
        let treatment = Treatment(from: legacyCycle)
        
        // Verify type and properties
        XCTAssertEqual(treatment.treatmentType, .advanced)
        XCTAssertEqual(treatment.name, "Legacy Cycle")
        XCTAssertEqual(treatment.notes, "Legacy cycle notes")
        XCTAssertEqual(treatment.totalWeeks, 12)
        XCTAssertEqual(treatment.id, legacyCycle.id)
        
        // Verify stages
        XCTAssertEqual(treatment.stages?.count, 2)
        XCTAssertEqual(treatment.stages?[0].name, "Cycle Stage 1")
        XCTAssertEqual(treatment.stages?[0].startWeek, 0)
        XCTAssertEqual(treatment.stages?[0].durationWeeks, 6)
        XCTAssertEqual(treatment.stages?[1].name, "Cycle Stage 2")
        XCTAssertEqual(treatment.stages?[1].startWeek, 6)
        XCTAssertEqual(treatment.stages?[1].durationWeeks, 6)
    }
    
    func testConversionToLegacyProtocol() {
        // Create a simple treatment
        var treatment = Treatment(
            name: "Simple Treatment",
            startDate: Date(),
            notes: "Test notes",
            treatmentType: .simple
        )
        
        // Set simple treatment properties
        treatment.doseMg = 100.0
        treatment.frequencyDays = 7.0
        if let testCompound = compoundLibrary.compounds.first {
            treatment.compoundID = testCompound.id
        }
        treatment.selectedRoute = Compound.Route.intramuscular.rawValue
        
        // Convert back to legacy protocol
        guard let legacyProtocol = treatment.toLegacyProtocol() else {
            XCTFail("Failed to convert to legacy protocol")
            return
        }
        
        // Verify properties
        XCTAssertEqual(legacyProtocol.name, "Simple Treatment")
        XCTAssertEqual(legacyProtocol.notes, "Test notes")
        XCTAssertEqual(legacyProtocol.doseMg, 100.0)
        XCTAssertEqual(legacyProtocol.frequencyDays, 7.0)
        XCTAssertEqual(legacyProtocol.compoundID, treatment.compoundID)
        XCTAssertEqual(legacyProtocol.selectedRoute, Compound.Route.intramuscular.rawValue)
        XCTAssertEqual(legacyProtocol.id, treatment.id)
    }
    
    func testConversionToLegacyCycle() {
        // Create an advanced treatment
        var treatment = Treatment(
            name: "Advanced Treatment",
            startDate: Date(),
            notes: "Test notes",
            treatmentType: .advanced
        )
        
        // Set advanced treatment properties
        treatment.totalWeeks = 12
        
        // Create test stages
        let stage1 = TreatmentStage(
            name: "Stage 1",
            startWeek: 0,
            durationWeeks: 6,
            compounds: []
        )
        
        let stage2 = TreatmentStage(
            name: "Stage 2",
            startWeek: 6,
            durationWeeks: 6,
            compounds: []
        )
        
        treatment.stages = [stage1, stage2]
        
        // Convert back to legacy cycle
        guard let legacyCycle = treatment.toLegacyCycle() else {
            XCTFail("Failed to convert to legacy cycle")
            return
        }
        
        // Verify properties
        XCTAssertEqual(legacyCycle.name, "Advanced Treatment")
        XCTAssertEqual(legacyCycle.notes, "Test notes")
        XCTAssertEqual(legacyCycle.totalWeeks, 12)
        XCTAssertEqual(legacyCycle.id, treatment.id)
        
        // Verify stages
        XCTAssertEqual(legacyCycle.stages.count, 2)
        XCTAssertEqual(legacyCycle.stages[0].name, "Stage 1")
        XCTAssertEqual(legacyCycle.stages[0].startWeek, 0)
        XCTAssertEqual(legacyCycle.stages[0].durationWeeks, 6)
        XCTAssertEqual(legacyCycle.stages[1].name, "Stage 2")
        XCTAssertEqual(legacyCycle.stages[1].startWeek, 6)
        XCTAssertEqual(legacyCycle.stages[1].durationWeeks, 6)
    }
    
    // MARK: - Effect Index Tests
    
    func testCalculateAnabolicEffect() {
        // Get a test compound - use testosterone as it has anabolic factor of 1.0
        guard let testCompound = compoundLibrary.compounds.first(where: { $0.classType == .testosterone }) else {
            XCTFail("No testosterone compound found")
            return
        }
        
        // Create a simple treatment
        var treatment = Treatment(
            name: "Test Treatment",
            startDate: Date(),
            treatmentType: .simple
        )
        
        // Set simple treatment properties - 100mg weekly
        treatment.doseMg = 100.0
        treatment.frequencyDays = 7.0
        treatment.compoundID = testCompound.id
        
        // Calculate anabolic effect - should be 100mg * 1.0 (weekly dose * anabolic factor)
        let anabolicEffect = treatment.calculateAnabolicEffectIndex(using: compoundLibrary)
        
        // Testosterone at 100mg weekly should have anabolic effect of approximately 100
        XCTAssertEqual(anabolicEffect, 100.0, accuracy: 1.0)
        
        // Change the dose to twice weekly (same total)
        treatment.doseMg = 50.0
        treatment.frequencyDays = 3.5
        
        // Calculate anabolic effect again - should still be ~100
        let anabolicEffectSplit = treatment.calculateAnabolicEffectIndex(using: compoundLibrary)
        XCTAssertEqual(anabolicEffectSplit, 100.0, accuracy: 1.0)
    }
    
    func testCalculateAndrogenicEffect() {
        // Get a test compound - use testosterone as it has androgenic factor of 1.0
        guard let testCompound = compoundLibrary.compounds.first(where: { $0.classType == .testosterone }) else {
            XCTFail("No testosterone compound found")
            return
        }
        
        // Create a simple treatment
        var treatment = Treatment(
            name: "Test Treatment",
            startDate: Date(),
            treatmentType: .simple
        )
        
        // Set simple treatment properties - 100mg weekly
        treatment.doseMg = 100.0
        treatment.frequencyDays = 7.0
        treatment.compoundID = testCompound.id
        
        // Calculate androgenic effect - should be 100mg * 1.0 (weekly dose * androgenic factor)
        let androgenicEffect = treatment.calculateAndrogenicEffectIndex(using: compoundLibrary)
        
        // Testosterone at 100mg weekly should have androgenic effect of approximately 100
        XCTAssertEqual(androgenicEffect, 100.0, accuracy: 1.0)
    }
    
    func testAdvancedTreatmentEffectIndices() {
        // Get testosterone for testing
        guard let testCompound = compoundLibrary.compounds.first(where: { $0.classType == .testosterone }) else {
            XCTFail("No testosterone compound found")
            return
        }
        
        // Create an advanced treatment
        var treatment = Treatment(
            name: "Test Advanced Treatment",
            startDate: Date(),
            treatmentType: .advanced
        )
        
        // Set advanced treatment properties
        treatment.totalWeeks = 12
        
        // Create test stages with different doses
        let stage1 = TreatmentStage(
            name: "Stage 1",
            startWeek: 0,
            durationWeeks: 6,
            compounds: [
                CompoundStageItem(
                    compoundID: testCompound.id,
                    compoundName: testCompound.fullDisplayName,
                    doseMg: 100.0,
                    frequencyDays: 7.0,
                    administrationRoute: Compound.Route.intramuscular.rawValue
                )
            ]
        )
        
        let stage2 = TreatmentStage(
            name: "Stage 2",
            startWeek: 6,
            durationWeeks: 6,
            compounds: [
                CompoundStageItem(
                    compoundID: testCompound.id,
                    compoundName: testCompound.fullDisplayName,
                    doseMg: 50.0,
                    frequencyDays: 7.0,
                    administrationRoute: Compound.Route.intramuscular.rawValue
                )
            ]
        )
        
        treatment.stages = [stage1, stage2]
        
        // Calculate effect indices
        let anabolicEffect = treatment.calculateAnabolicEffectIndex(using: compoundLibrary)
        let androgenicEffect = treatment.calculateAndrogenicEffectIndex(using: compoundLibrary)
        
        // Expected values: weighted average of both stages
        // Stage 1: 100mg weekly * 1.0 anabolic factor = 100
        // Stage 2: 50mg weekly * 1.0 anabolic factor = 50
        // Weighted average: (100 * 6 + 50 * 6) / 12 = 75
        XCTAssertEqual(anabolicEffect, 75.0, accuracy: 1.0)
        XCTAssertEqual(androgenicEffect, 75.0, accuracy: 1.0) // Same for androgenic with testosterone
    }
}