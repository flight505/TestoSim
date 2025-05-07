import Foundation

/// Pharmacokinetic model for calculating hormone concentrations
struct PKModel {
    
    // MARK: - Constants
    
    /// Typical volume of distribution for a 70kg person in liters
    static let defaultVolumeOfDistribution70kg: Double = 15.0 // L (corrected from 70.0, typical Vd for testosterone)
    
    /// Default clearance for a 70kg person in L/day
    static let defaultClearance70kg: Double = 2.4 // L/day (Updated based on literature)
    
    /// Endogenous testosterone production rate in mg/day for adult males
    static let endogenousProductionRate: Double = 7.0 // mg/day
    
    /// Minimum reportable concentration to avoid numerical issues
    static let minimumReportableConcentration: Double = 0.01
    
    // MARK: - Properties
    
    /// Using two-compartment model (more accurate but more computationally intensive)
    /// Modern devices can handle this computation without issues
    var useTwoCompartmentModel: Bool = true
    
    /// Fixed compartment transfer rates for two-compartment model
    let k12: Double = 0.3 // d⁻¹
    let k21: Double = 0.15 // d⁻¹
    
    /// Flag to include endogenous production in calculations
    var includeEndogenousProduction: Bool = true
    
    // MARK: - Initialization
    
    init(useTwoCompartmentModel: Bool = true, includeEndogenousProduction: Bool = true) {
        // Always use two-compartment model, parameter kept for backward compatibility
        self.useTwoCompartmentModel = true
        self.includeEndogenousProduction = includeEndogenousProduction
    }
    
    // MARK: - Concentration Calculations
    
    /// Calculate concentration for a single dose administration, including endogenous production
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
        guard time > 0 && halfLifeDays > 0 else { 
            return includeEndogenousProduction ? calculateBaselineConcentration(weight: weight) : 0
        }
        
        // Elimination rate constant (ke) = ln(2)/t_1/2
        let ke = log(2) / halfLifeDays
        
        // Calculate volume of distribution with allometric scaling
        let vd = PKModel.defaultVolumeOfDistribution70kg * pow(weight / 70.0, 1.0)
        
        // Calculate baseline concentration (endogenous testosterone)
        let baselineConcentration = includeEndogenousProduction ? calculateBaselineConcentration(weight: weight) : 0
        
        // Skip calculation if ka ≤ ke (avoid division by zero or negative value)
        // Also skip two-compartment when ka is close to ke to avoid numerical instability
        if absorptionRateKa <= (ke * 1.05) {
            let exogenousConcentration = oneCompartmentBolus(
                time: time,
                dose: dose,
                ke: ke,
                bioavailability: bioavailability,
                weight: weight,
                calibrationFactor: calibrationFactor
            )
            return exogenousConcentration + baselineConcentration
        }
        
        // Two-compartment model parameters
        // Using standard Bateman equation for PK with first-order absorption
        let scaledDose = dose * bioavailability
        
        // Calculate hybrid rate constants for two-compartment model
        // α and β are the hybrid first-order rate constants
        let sum = k12 + k21 + ke
        let product = k21 * ke
        
        // Check if discriminant will be positive to avoid numerical issues
        guard sum * sum > 4 * product else {
            // If discriminant would be negative, use one-compartment model
            let oneCompResult = oneCompartmentBolus(
                time: time,
                dose: dose,
                ke: ke,
                bioavailability: bioavailability,
                weight: weight,
                calibrationFactor: calibrationFactor
            )
            return oneCompResult + baselineConcentration
        }
        
        let discriminant = sqrt(sum * sum - 4 * product)
        
        // Special case handling for eigenvalues
        let alpha: Double
        let beta: Double
        
        if abs(k12 + ke - k21) < 0.001 {
            // Handle special case where eigenvalues are very close
            let eigenvalue = (k12 + k21 + ke) / 2
            alpha = eigenvalue
            beta = eigenvalue
            
            // Use one-compartment model for this special case
            let oneCompResult = oneCompartmentBolus(
                time: time,
                dose: dose,
                ke: ke,
                bioavailability: bioavailability,
                weight: weight,
                calibrationFactor: calibrationFactor
            )
            return oneCompResult + baselineConcentration
        } else {
            // Standard calculation
            alpha = 0.5 * (sum + discriminant)
            beta = 0.5 * (sum - discriminant)
        }
        
        // Prevent potential division by zero or very small denominators
        // This can happen when rate constants are very close to each other
        let epsilon = 0.001
        if abs(absorptionRateKa - alpha) < epsilon || 
           abs(absorptionRateKa - beta) < epsilon || 
           abs(alpha - beta) < epsilon {
            // Fall back to one-compartment model if the rate constants are too close
            let oneCompResult = oneCompartmentBolus(
                time: time,
                dose: dose,
                ke: ke,
                bioavailability: bioavailability,
                weight: weight,
                calibrationFactor: calibrationFactor
            )
            return oneCompResult + baselineConcentration
        }
        
        // Calculate coefficients for the triexponential equation
        let A = (alpha - k21) * absorptionRateKa / (vd * (alpha - beta) * (absorptionRateKa - alpha))
        let B = (beta - k21) * absorptionRateKa / (vd * (beta - alpha) * (absorptionRateKa - beta))
        let C = k21 * absorptionRateKa / (vd * (absorptionRateKa - alpha) * (absorptionRateKa - beta))
        
        // Calculate concentration using the standard triexponential equation
        let exogenousConcentration = scaledDose * (
            A * (exp(-alpha * time)) +
            B * (exp(-beta * time)) +
            C * (exp(-absorptionRateKa * time))
        )
        
        // Check for numerical issues
        if exogenousConcentration.isNaN || exogenousConcentration.isInfinite {
            // Log warning and use one-compartment model
            print("Warning: Two-compartment model produced NaN/Infinite result. Parameters: ka=\(absorptionRateKa), ke=\(ke), k12=\(k12), k21=\(k21), Vd=\(vd)")
            let oneCompResult = oneCompartmentBolus(
                time: time,
                dose: dose,
                ke: ke,
                bioavailability: bioavailability,
                weight: weight,
                calibrationFactor: calibrationFactor
            )
            return oneCompResult + baselineConcentration
        }
        
        // Apply calibration factor to exogenous concentration only
        let calibratedExogenousConcentration = max(0, exogenousConcentration * calibrationFactor)
        
        // Near-zero check
        if calibratedExogenousConcentration < PKModel.minimumReportableConcentration {
            print("Near-zero exogenous concentration calculated at time \(time): \(calibratedExogenousConcentration)")
        }
        
        // Add exogenous (from injection) and endogenous (baseline) concentrations
        return calibratedExogenousConcentration + baselineConcentration
    }
    
    /// Calculate baseline testosterone concentration from endogenous production
    /// - Parameter weight: Patient weight in kg
    /// - Returns: Baseline concentration
    private func calculateBaselineConcentration(weight: Double) -> Double {
        // Calculate clearance with allometric scaling
        let clearance = PKModel.defaultClearance70kg * pow(weight / 70.0, 0.75)
        
        // For steady state, Concentration = Production Rate / Clearance
        let baseConcentration = PKModel.endogenousProductionRate / clearance
        
        // Convert to concentration units (ng/dL)
        // Assuming clearance is in L/day, we convert mg/L to ng/dL
        // 1 mg/L = 100 ng/dL
        return baseConcentration * 100
    }
    
    /// Calculate concentration for a bolus injection (immediate absorption)
    /// This is a fallback for when ka ≤ ke or as direct calculation when needed
    /// Returns only the exogenous contribution (does NOT include baseline)
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
        let result = initialConcentration * exp(-ke * time)
        
        // Apply log transformation for small values to avoid numerical issues
        if result > 0 && result < PKModel.minimumReportableConcentration {
            // Log-transform the calculation to avoid underflow
            let logResult = log(initialConcentration) - ke * time
            let transformedResult = exp(logResult)
            return max(0, transformedResult * calibrationFactor)
        }
        
        return max(0, result * calibrationFactor) // Ensure non-negative result
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
        guard !components.isEmpty else {
            // If no components, return only baseline concentration
            return includeEndogenousProduction ? calculateBaselineConcentration(weight: weight) : 0
        }
        
        // For endogenous production, we should only add it once for the blend,
        // not for each component, to avoid double-counting
        let baselineConcentration = includeEndogenousProduction ? calculateBaselineConcentration(weight: weight) : 0
        
        // Create a copy of the current model with endogenous production turned off
        // to avoid adding baseline multiple times
        var tempModel = self
        tempModel.includeEndogenousProduction = false
        
        // Sum the exogenous concentrations of all components
        let totalExogenousConcentration = components.reduce(0.0) { totalConcentration, component in
            let bioavailability = component.compound.defaultBioavailability[route] ?? 1.0
            let absorptionRate = component.compound.defaultAbsorptionRateKa[route] ?? 0.7 // Default ka if not specified
            
            let componentConcentration = tempModel.concentration(
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
        
        // Add baseline concentration once for the entire blend
        return totalExogenousConcentration + baselineConcentration
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
        // Basic validation check
        if times.isEmpty {
            return []
        }
        
        if injectionDates.isEmpty || compounds.isEmpty {
            // Return baseline concentrations if no injections or compounds
            if includeEndogenousProduction {
                let baselineConcentration = calculateBaselineConcentration(weight: weight)
                return Array(repeating: baselineConcentration, count: times.count)
            } else {
                return Array(repeating: 0.0, count: times.count)
            }
        }
        
        // For endogenous production, we should only add baseline once per time point
        let baselineConcentration = includeEndogenousProduction ? calculateBaselineConcentration(weight: weight) : 0
        
        // Create a copy of the model with endogenous production turned off to avoid double-counting
        var tempModel = self
        tempModel.includeEndogenousProduction = false
        
        // Calculate concentration at each time point
        let results = times.map { timePoint in
            // Sum contributions from all injections (exogenous only)
            let totalExogenousConcentration = injectionDates.reduce(0.0) { totalConc, injectionDate in
                // Skip future injections
                guard injectionDate <= timePoint else { return totalConc }
                
                // Calculate time difference in days
                let timeDiffDays = timePoint.timeIntervalSince(injectionDate) / (24 * 3600)
                
                // Skip negative time differences (should not happen, but just in case)
                guard timeDiffDays >= 0 else { return totalConc }
                
                // Sum contributions from all compounds in this injection
                let injectionContribution = compounds.reduce(0.0) { compoundSum, compound in
                    let bioavailability = compound.compound.defaultBioavailability[route] ?? 1.0
                    let absorptionRate = compound.compound.defaultAbsorptionRateKa[route] ?? 0.7
                    
                    let contribution = tempModel.concentration(
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
            
            // Add baseline concentration once per time point
            return totalExogenousConcentration + baselineConcentration
        }
        
        return results
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
        
        // Bioavailability for this route
        let bioavailability = compound.defaultBioavailability[route] ?? 1.0
        
        // Set up parameter bounds (ke and ka can't vary too much from literature values)
        let keMin = originalKe * 0.5  // Allow halving the elimination rate
        let keMax = originalKe * 2.0  // Allow doubling the elimination rate
        let kaMin = originalKa * 0.5  // Allow halving the absorption rate
        let kaMax = originalKa * 2.0  // Allow doubling the absorption rate
        
        // Initial parameter guesses
        var currentKe = originalKe
        var currentKa = originalKa
        var bestKe = originalKe
        var bestKa = originalKa
        var bestError = Double.greatestFiniteMagnitude
        
        // Function to calculate sum of squared errors for given parameters
        func calculateError(ke: Double, ka: Double) -> Double {
            var sumSquaredError = 0.0
            
            for sample in samples {
                // Calculate predicted concentration at this sample time
                var predictedLevel = 0.0
                
                for injectionDate in injectionDates {
                    // Skip future injections
                    guard injectionDate <= sample.timestamp else { continue }
                    
                    // Calculate time difference in days
                    let timeDiffDays = sample.timestamp.timeIntervalSince(injectionDate) / (24 * 3600)
                    guard timeDiffDays >= 0 else { continue }
                    
                    // Calculate concentration for this injection
                    let vd = PKModel.defaultVolumeOfDistribution70kg * pow(weight / 70.0, 1.0)
                    
                    // Skip if ka and ke are too close (would cause division by zero)
                    if abs(ka - ke) < 0.001 {
                        continue
                    }
                    
                    // One-compartment model with first-order absorption formula
                    let factor = (dose * bioavailability * ka) / (vd * (ka - ke))
                    let contribution = factor * (exp(-ke * timeDiffDays) - exp(-ka * timeDiffDays))
                    
                    predictedLevel += contribution
                }
                
                // Calculate squared error for this sample
                let error = sample.labValue - predictedLevel
                sumSquaredError += error * error
            }
            
            return sumSquaredError
        }
        
        // Gradient descent parameters
        let learningRate = 0.01
        let iterations = 100
        let earlyStopThreshold = 0.0001
        
        // Perform gradient descent optimization
        for _ in 0..<iterations {
            let baseError = calculateError(ke: currentKe, ka: currentKa)
            
            // Calculate gradient for ke
            let keStep = currentKe * 0.01
            let keGradient = (calculateError(ke: currentKe + keStep, ka: currentKa) - baseError) / keStep
            
            // Calculate gradient for ka
            let kaStep = currentKa * 0.01
            let kaGradient = (calculateError(ke: currentKe, ka: currentKa + kaStep) - baseError) / kaStep
            
            // Update parameters
            currentKe -= learningRate * keGradient
            currentKa -= learningRate * kaGradient
            
            // Keep parameters within bounds
            currentKe = max(keMin, min(keMax, currentKe))
            currentKa = max(kaMin, min(kaMax, currentKa))
            
            // Check if this is the best result so far
            let currentError = calculateError(ke: currentKe, ka: currentKa)
            if currentError < bestError {
                bestError = currentError
                bestKe = currentKe
                bestKa = currentKa
            }
            
            // Early stopping if improvement is minimal
            if abs(baseError - currentError) < earlyStopThreshold {
                break
            }
        }
        
        // Calculate correlation coefficient
        let correlation = calculateCorrelation(
            ke: bestKe,
            ka: bestKa,
            samples: samples,
            injectionDates: injectionDates,
            dose: dose,
            bioavailability: bioavailability,
            weight: weight
        )
        
        return CalibrationResult(
            adjustedKe: bestKe,
            adjustedKa: bestKa,
            originalKe: originalKe,
            originalKa: originalKa,
            halfLifeDays: log(2) / bestKe,
            correlation: correlation,
            samples: samples
        )
    }
    
    /// Calculate correlation between observed and predicted values
    private func calculateCorrelation(
        ke: Double,
        ka: Double,
        samples: [SamplePoint],
        injectionDates: [Date],
        dose: Double,
        bioavailability: Double,
        weight: Double
    ) -> Double {
        // Calculate predicted values
        var observed: [Double] = []
        var predicted: [Double] = []
        
        for sample in samples {
            observed.append(sample.labValue)
            
            var predictedLevel = 0.0
            for injectionDate in injectionDates {
                guard injectionDate <= sample.timestamp else { continue }
                
                let timeDiffDays = sample.timestamp.timeIntervalSince(injectionDate) / (24 * 3600)
                guard timeDiffDays >= 0 else { continue }
                
                let vd = PKModel.defaultVolumeOfDistribution70kg * pow(weight / 70.0, 1.0)
                
                if abs(ka - ke) < 0.001 {
                    // For very close ka and ke, use bolus approximation
                    let initialConcentration = (dose * bioavailability) / vd
                    predictedLevel += initialConcentration * exp(-ke * timeDiffDays)
                } else {
                    let factor = (dose * bioavailability * ka) / (vd * (ka - ke))
                    predictedLevel += factor * (exp(-ke * timeDiffDays) - exp(-ka * timeDiffDays))
                }
            }
            
            predicted.append(predictedLevel)
        }
        
        // Calculate means
        let observedMean = observed.reduce(0.0, +) / Double(observed.count)
        let predictedMean = predicted.reduce(0.0, +) / Double(predicted.count)
        
        // Calculate Pearson correlation coefficient
        var numerator = 0.0
        var observedDenominator = 0.0
        var predictedDenominator = 0.0
        
        for i in 0..<observed.count {
            let observedDiff = observed[i] - observedMean
            let predictedDiff = predicted[i] - predictedMean
            
            numerator += observedDiff * predictedDiff
            observedDenominator += observedDiff * observedDiff
            predictedDenominator += predictedDiff * predictedDiff
        }
        
        let denominator = sqrt(observedDenominator * predictedDenominator)
        
        // Protect against division by zero
        guard denominator > 0 else { return 0.0 }
        
        return numerator / denominator
    }
    
    // MARK: - Time to Peak and Maximum Concentration
    
    /// Calculate the time to peak concentration for a given dose
    /// - Parameters:
    ///   - dose: Dose in mg
    ///   - halfLifeDays: Half-life in days
    ///   - absorptionRateKa: Absorption rate constant (ka) in d⁻¹
    ///   - bioavailability: Fraction of drug absorbed (0-1)
    ///   - weight: Patient weight in kg (for allometric scaling)
    ///   - calibrationFactor: User-specific calibration factor
    /// - Returns: Time to peak concentration in days
    func calculateTimeToMaxConcentration(
        dose: Double,
        halfLifeDays: Double,
        absorptionRateKa: Double,
        bioavailability: Double = 1.0,
        weight: Double = 70.0,
        calibrationFactor: Double = 1.0
    ) -> Double {
        // Skip calculation if impossible parameters
        guard halfLifeDays > 0 && absorptionRateKa > 0 else { return 0 }
        
        // Elimination rate constant (ke) = ln(2)/t_1/2
        let ke = log(2) / halfLifeDays
        
        // For one-compartment model with first-order absorption,
        // Tp = ln(ka/ke) / (ka - ke)
        // This is derived by setting the derivative of the concentration equation to zero
        guard absorptionRateKa > ke else {
            // If ka <= ke, then Tp is effectively 0 (immediate peak for IV bolus)
            return 0
        }
        
        // For two-compartment model, need numerical approach to find Tp
        // This is a simplified approximation - would use a more sophisticated
        // numerical method in a full implementation
        
        // Calculate alpha and beta for two-compartment model
        let beta = 0.5 * ((k12 + k21 + ke) - sqrt(pow(k12 + k21 + ke, 2) - 4 * k21 * ke))
        let _ = (k21 * ke) / beta
        
        // Approximate Tp using numerical search (rough estimate)
        var bestTime = 0.0
        var maxConc = 0.0
        
        // Search from 0 to about 5 half-lives with small steps
        let searchEnd = 5 * halfLifeDays
        let step = halfLifeDays / 50.0
        
        for t in stride(from: 0, through: searchEnd, by: step) {
            let conc = concentration(
                at: t,
                dose: dose,
                halfLifeDays: halfLifeDays,
                absorptionRateKa: absorptionRateKa,
                bioavailability: bioavailability,
                weight: weight,
                calibrationFactor: calibrationFactor
            )
            
            if conc > maxConc {
                maxConc = conc
                bestTime = t
            }
        }
        
        return bestTime
    }
    
    /// Calculate the maximum concentration for a given dose
    /// - Parameters:
    ///   - dose: Dose in mg
    ///   - halfLifeDays: Half-life in days
    ///   - absorptionRateKa: Absorption rate constant (ka) in d⁻¹
    ///   - bioavailability: Fraction of drug absorbed (0-1)
    ///   - weight: Patient weight in kg (for allometric scaling)
    ///   - calibrationFactor: User-specific calibration factor
    /// - Returns: Maximum concentration
    func calculateMaxConcentration(
        dose: Double,
        halfLifeDays: Double,
        absorptionRateKa: Double,
        bioavailability: Double = 1.0,
        weight: Double = 70.0,
        calibrationFactor: Double = 1.0
    ) -> Double {
        // Calculate time to peak
        let tp = calculateTimeToMaxConcentration(
            dose: dose,
            halfLifeDays: halfLifeDays,
            absorptionRateKa: absorptionRateKa,
            bioavailability: bioavailability,
            weight: weight,
            calibrationFactor: calibrationFactor
        )
        
        // Calculate concentration at time to peak
        return concentration(
            at: tp,
            dose: dose,
            halfLifeDays: halfLifeDays,
            absorptionRateKa: absorptionRateKa,
            bioavailability: bioavailability,
            weight: weight,
            calibrationFactor: calibrationFactor
        )
    }
    
    /// Calculate the time to peak and maximum concentration for a blend
    /// - Parameters:
    ///   - components: Array of tuples containing (compound, dose)
    ///   - route: Administration route
    ///   - weight: Patient weight in kg
    ///   - calibrationFactor: User-specific calibration factor
    /// - Returns: Tuple containing (time to peak in days, max concentration)
    func calculateBlendPeakDetails(
        components: [(compound: Compound, doseMg: Double)],
        route: Compound.Route,
        weight: Double = 70.0,
        calibrationFactor: Double = 1.0
    ) -> (timeToMaxDays: Double, maxConcentration: Double) {
        // For blends, we need to do a numerical search to find overall Tp and Cmax
        // as different components will peak at different times
        
        // Search time range (0 to 30 days should cover most scenarios)
        let searchEnd = 30.0
        let step = 0.1 // Refine step size for better precision
        
        var maxConc = 0.0
        var maxTime = 0.0
        
        for t in stride(from: 0, through: searchEnd, by: step) {
            let conc = blendConcentration(
                at: t,
                components: components,
                route: route,
                weight: weight,
                calibrationFactor: calibrationFactor
            )
            
            if conc > maxConc {
                maxConc = conc
                maxTime = t
            }
        }
        
        return (timeToMaxDays: maxTime, maxConcentration: maxConc)
    }
    
    /// Calculate peak details for a protocol (multiple injections)
    /// - Parameters:
    ///   - injectionDates: Dates of all injections
    ///   - compounds: Array of tuples containing (compound, dose per injection)
    ///   - route: Administration route
    ///   - timeWindow: Date range to search for peak
    ///   - weight: Patient weight in kg
    ///   - calibrationFactor: User-specific calibration factor
    /// - Returns: Tuple containing (peak date, max concentration)
    func calculateProtocolPeakDetails(
        injectionDates: [Date],
        compounds: [(compound: Compound, dosePerInjectionMg: Double)],
        route: Compound.Route,
        timeWindow: (start: Date, end: Date),
        weight: Double = 70.0,
        calibrationFactor: Double = 1.0
    ) -> (peakDate: Date, maxConcentration: Double) {
        // For multiple injections, we need to search the entire time window
        let totalHours = timeWindow.end.timeIntervalSince(timeWindow.start) / 3600
        let step = 6.0 // 6-hour steps for reasonable precision
        
        var maxConc = 0.0
        var maxDate = timeWindow.start
        
        // Generate timepoints to evaluate
        var timePoints: [Date] = []
        for hour in stride(from: 0, through: totalHours, by: step) {
            let date = timeWindow.start.addingTimeInterval(hour * 3600)
            timePoints.append(date)
        }
        
        // Calculate concentrations at each timepoint
        let concentrations = protocolConcentrations(
            at: timePoints,
            injectionDates: injectionDates,
            compounds: compounds,
            route: route,
            weight: weight,
            calibrationFactor: calibrationFactor
        )
        
        // Find the maximum
        for (index, conc) in concentrations.enumerated() {
            if conc > maxConc {
                maxConc = conc
                maxDate = timePoints[index]
            }
        }
        
        return (peakDate: maxDate, maxConcentration: maxConc)
    }
} 