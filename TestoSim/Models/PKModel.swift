import Foundation

/// Pharmacokinetic model for calculating hormone concentrations
struct PKModel {
    
    // MARK: - Constants
    
    /// Typical volume of distribution for a 70kg person in liters
    static let defaultVolumeOfDistribution70kg: Double = 4.0 // L
    
    /// Default clearance for a 70kg person in L/day
    static let defaultClearance70kg: Double = 0.8 // L/day
    
    // MARK: - Properties
    
    /// Whether to use the two-compartment model (more accurate but more computationally intensive)
    var useTwoCompartmentModel: Bool
    
    /// Fixed compartment transfer rates if using two-compartment model (from guide)
    let k12: Double = 0.3 // d⁻¹
    let k21: Double = 0.15 // d⁻¹
    
    // MARK: - Initialization
    
    init(useTwoCompartmentModel: Bool = false) {
        self.useTwoCompartmentModel = useTwoCompartmentModel
    }
    
    // MARK: - Concentration Calculations
    
    /// Calculate concentration for a single dose administration
    /// - Parameters:
    ///   - time: Time in days since administration
    ///   - dose: Dose in mg
    ///   - halfLifeDays: Half-life in days
    ///   - absorptionRateKa: Absorption rate constant (ka) in d⁻¹
    ///   - bioavailability: Fraction of drug absorbed (0-1)
    ///   - weight: Patient weight in kg (for allometric scaling)
    ///   - calibrationFactor: User-specific calibration factor
    /// - Returns: Concentration in the appropriate units
    func concentration(
        at time: Double,
        dose: Double,
        halfLifeDays: Double,
        absorptionRateKa: Double,
        bioavailability: Double,
        weight: Double = 70.0,
        calibrationFactor: Double = 1.0
    ) -> Double {
        // Skip calculation if time is negative or zero
        guard time > 0 && halfLifeDays > 0 else { return 0 }
        
        // Elimination rate constant (ke) = ln(2)/t_1/2
        let ke = log(2) / halfLifeDays
        
        // Skip calculation if ka ≤ ke (avoid division by zero or negative value)
        guard absorptionRateKa > ke else {
            return oneCompartmentBolus(
                time: time,
                dose: dose,
                ke: ke,
                bioavailability: bioavailability,
                weight: weight,
                calibrationFactor: calibrationFactor
            )
        }
        
        // Calculate volume of distribution and clearance with allometric scaling
        let vd = PKModel.defaultVolumeOfDistribution70kg * pow(weight / 70.0, 1.0)
        
        // One-compartment model with first-order absorption (standard PK formula)
        let scaledDose = dose * bioavailability
        let factor = (scaledDose * absorptionRateKa) / (vd * (absorptionRateKa - ke))
        
        if useTwoCompartmentModel {
            // Calculate alpha and beta for two-compartment model
            // These are the hybrid rate constants derived from k12, k21, and ke
            let beta = 0.5 * ((k12 + k21 + ke) - sqrt(pow(k12 + k21 + ke, 2) - 4 * k21 * ke))
            let alpha = (k21 * ke) / beta
            
            // Two-compartment model with first-order absorption
            let term1 = absorptionRateKa / ((absorptionRateKa - alpha) * (absorptionRateKa - beta))
            let term2 = absorptionRateKa / ((alpha - absorptionRateKa) * (alpha - beta))
            let term3 = absorptionRateKa / ((beta - absorptionRateKa) * (beta - alpha))
            
            let result = (scaledDose / vd) * (
                term1 * exp(-absorptionRateKa * time) +
                term2 * exp(-alpha * time) +
                term3 * exp(-beta * time)
            )
            
            return result * calibrationFactor
        } else {
            // One-compartment model with first-order absorption (standard PK formula)
            // C(t) = (F·D·ka)/(Vd·(ka-ke))·(e^(-ke·t)-e^(-ka·t))
            let result = factor * (exp(-ke * time) - exp(-absorptionRateKa * time))
            
            return result * calibrationFactor
        }
    }
    
    /// Calculate concentration for a bolus injection (immediate absorption)
    /// This is a fallback for when ka ≤ ke or as direct calculation when needed
    private func oneCompartmentBolus(
        time: Double,
        dose: Double,
        ke: Double,
        bioavailability: Double,
        weight: Double,
        calibrationFactor: Double
    ) -> Double {
        // Calculate volume of distribution with allometric scaling
        let vd = PKModel.defaultVolumeOfDistribution70kg * pow(weight / 70.0, 1.0)
        
        // Simple one-compartment bolus model: C(t) = (F·D/Vd)·e^(-ke·t)
        let initialConcentration = (dose * bioavailability) / vd
        return initialConcentration * exp(-ke * time) * calibrationFactor
    }
    
    /// Calculate the total concentration for a blend at a specific time
    /// - Parameters:
    ///   - time: Time in days since administration
    ///   - components: Array of tuples containing (compound, dose)
    ///   - route: Administration route
    ///   - weight: Patient weight in kg
    ///   - calibrationFactor: User-specific calibration factor
    /// - Returns: Total concentration
    func blendConcentration(
        at time: Double,
        components: [(compound: Compound, doseMg: Double)],
        route: Compound.Route,
        weight: Double = 70.0,
        calibrationFactor: Double = 1.0
    ) -> Double {
        // Sum the concentrations of all components
        return components.reduce(0.0) { totalConcentration, component in
            let bioavailability = component.compound.defaultBioavailability[route] ?? 1.0
            let absorptionRate = component.compound.defaultAbsorptionRateKa[route] ?? 0.7 // Default ka if not specified
            
            let componentConcentration = concentration(
                at: time,
                dose: component.doseMg,
                halfLifeDays: component.compound.halfLifeDays,
                absorptionRateKa: absorptionRate,
                bioavailability: bioavailability,
                weight: weight,
                calibrationFactor: calibrationFactor
            )
            
            return totalConcentration + componentConcentration
        }
    }
    
    /// Calculate the concentration over time for a protocol with multiple injections
    /// - Parameters:
    ///   - times: Array of time points in days to calculate concentrations for
    ///   - injectionDates: Dates of all injections
    ///   - compounds: Array of tuples containing (compound, dose per injection)
    ///   - route: Administration route
    ///   - weight: Patient weight in kg
    ///   - calibrationFactor: User-specific calibration factor
    /// - Returns: Array of concentrations at specified time points
    func protocolConcentrations(
        at times: [Date],
        injectionDates: [Date],
        compounds: [(compound: Compound, dosePerInjectionMg: Double)],
        route: Compound.Route,
        weight: Double = 70.0,
        calibrationFactor: Double = 1.0
    ) -> [Double] {
        // Calculate concentration at each time point
        return times.map { timePoint in
            // Sum contributions from all injections
            let totalConcentration = injectionDates.reduce(0.0) { totalConc, injectionDate in
                // Skip future injections
                guard injectionDate <= timePoint else { return totalConc }
                
                // Calculate time difference in days
                let timeDiffDays = timePoint.timeIntervalSince(injectionDate) / (24 * 3600)
                
                // Sum contributions from all compounds in this injection
                let injectionContribution = compounds.reduce(0.0) { compoundSum, compound in
                    let bioavailability = compound.compound.defaultBioavailability[route] ?? 1.0
                    let absorptionRate = compound.compound.defaultAbsorptionRateKa[route] ?? 0.7
                    
                    let contribution = concentration(
                        at: timeDiffDays,
                        dose: compound.dosePerInjectionMg,
                        halfLifeDays: compound.compound.halfLifeDays,
                        absorptionRateKa: absorptionRate,
                        bioavailability: bioavailability,
                        weight: weight,
                        calibrationFactor: calibrationFactor
                    )
                    
                    return compoundSum + contribution
                }
                
                return totalConc + injectionContribution
            }
            
            return totalConcentration
        }
    }
    
    // MARK: - Bayesian Calibration
    
    /// Struct to represent a blood sample with timestamp and lab value
    struct SamplePoint {
        let timestamp: Date
        let labValue: Double
    }
    
    /// Result of Bayesian calibration
    struct CalibrationResult {
        let adjustedKe: Double
        let adjustedKa: Double
        let originalKe: Double
        let originalKa: Double
        let halfLifeDays: Double
        let correlation: Double
        let samples: [SamplePoint]
        
        var halfLifeChangePercent: Double {
            let originalHalfLife = log(2) / originalKe
            let newHalfLife = log(2) / adjustedKe
            return ((newHalfLife / originalHalfLife) - 1.0) * 100.0
        }
    }
    
    /// Perform Bayesian calibration to refine ke and ka based on lab values
    /// - Parameters:
    ///   - samples: Dictionary of timestamps and lab values
    ///   - injectionDates: Dates of all injections
    ///   - compound: Compound being used
    ///   - dose: Dose in mg
    ///   - route: Administration route
    ///   - weight: Patient weight in kg
    /// - Returns: Calibration result with adjusted parameters
    func bayesianCalibration(
        samples: [SamplePoint],
        injectionDates: [Date],
        compound: Compound,
        dose: Double,
        route: Compound.Route,
        weight: Double = 70.0
    ) -> CalibrationResult? {
        // Need at least 2 samples for meaningful calibration
        guard samples.count >= 2, let defaultKa = compound.defaultAbsorptionRateKa[route] else {
            return nil
        }
        
        // Original parameters
        let originalKe = log(2) / compound.halfLifeDays
        let originalKa = defaultKa
        
        // Stub implementation that returns slightly adjusted parameters
        // In a real implementation, this would use more sophisticated statistical methods
        // such as Markov Chain Monte Carlo or Maximum Likelihood Estimation
        
        // For demonstration, adjust ke by ±10% randomly and ka by ±15% randomly
        let keAdjustmentFactor = 1.0 + (Double.random(in: -0.1...0.1))
        let kaAdjustmentFactor = 1.0 + (Double.random(in: -0.15...0.15))
        
        let adjustedKe = originalKe * keAdjustmentFactor
        let adjustedKa = originalKa * kaAdjustmentFactor
        
        // Calculate a dummy correlation value (would be actual fit quality in real implementation)
        let correlation = 0.85 + Double.random(in: 0...0.1)
        
        return CalibrationResult(
            adjustedKe: adjustedKe,
            adjustedKa: adjustedKa,
            originalKe: originalKe,
            originalKa: originalKa,
            halfLifeDays: log(2) / adjustedKe,
            correlation: correlation,
            samples: samples
        )
    }
} 