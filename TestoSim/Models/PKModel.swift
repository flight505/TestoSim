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
        
        if useTwoCompartmentModel {
            // For two-compartment model, need numerical approach to find Tp
            // This is a simplified approximation - would use a more sophisticated
            // numerical method in a full implementation
            
            // Calculate alpha and beta for two-compartment model
            let beta = 0.5 * ((k12 + k21 + ke) - sqrt(pow(k12 + k21 + ke, 2) - 4 * k21 * ke))
            let alpha = (k21 * ke) / beta
            
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
        } else {
            // One-compartment model with analytical solution
            let tp = log(absorptionRateKa / ke) / (absorptionRateKa - ke)
            return max(0, tp) // Ensure non-negative
        }
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