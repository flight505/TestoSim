# Why your testosterone model flatlines: Technical fixes for the TestoSim app

## Bottom line up front
The near-zero concentration values in TestoSim's two-compartment pharmacokinetic model likely stem from one of three core issues: mathematical implementation errors in the differential equations solver, failure to account for testosterone's unique pharmacokinetic properties, or improper Bayesian calibration implementation. The most probable culprit is either incorrect eigenvalue calculation in the model solution or failure to account for endogenous testosterone production. Your immediate fixes should include verifying all rate constant implementations (especially k12/k21), implementing robust numerical methods with proper error handling, and incorporating baseline testosterone production (approximately 7 mg/day) into your model. Implementing these changes will likely resolve the concentration graph issues.

## Mathematical formulation errors causing flat graphs

### Eigenvalue calculation issues
Two-compartment models require accurate calculation of eigenvalues (α and β) derived from the micro-rate constants. Implementation errors here can cause catastrophic calculation failures:

```
α = (ks + √(ks² - 4 × k₁₀ × k₂₁))/2
β = (ks - √(ks² - 4 × k₁₀ × k₂₁))/2
```

Where ks = k₁₀ + k₁₂ + k₂₁

**Incorrect matrix formulation** or eigendecomposition in the solver can cause systematic errors producing near-zero concentrations. Special case handling is also critical - when eigenvalues are equal or very close (when k₀₁ equals either α or β), standard equations become indeterminate and require alternative formulations.

### Parameter magnitude and unit errors
PK models are extremely sensitive to parameter magnitude and unit consistency. Common errors include:

- Using minutes for some rate constants but hours for others
- Setting absorption or elimination rate constants orders of magnitude too high, causing rapid drug disappearance
- Volume overestimation artificially reducing calculated concentrations
- Confusion between micro-constants (k12, k21) and macro-constants (α, β)

When implementing the concentration calculation equation:

```
C(t) = Dose × k₀₁ × [((α-k₂₁)/(α-β)) × ((e^(-k₀₁×t) - e^(-α×t))/(α-k₀₁)) 
       + ((k₂₁-β)/(α-β)) × ((e^(-k₀₁×t) - e^(-β×t))/(β-k₀₁))] / V₁
```

Even small errors in any component can produce significantly distorted concentration profiles.

### Numerical computation problems
Two-compartment models can exhibit "stiffness" when rate constants differ by orders of magnitude, causing standard numerical solvers to fail. This produces instability that often manifests as near-zero values.

Verify the numerical method TestoSim uses - fixed-step explicit methods like forward Euler will fail with stiff equations, while adaptive implicit methods (backward differentiation formulas) are more appropriate.

## Testosterone-specific modeling considerations

### Missing endogenous production term
Unlike most drugs, testosterone is produced endogenously at approximately 7 mg/day in healthy males. **Models that don't incorporate baseline testosterone production** will show artificially low or near-zero values, especially at trough times.

The model should include a zero-order production rate term in the central compartment differential equation:

```
dA₁/dt = k₀₁ × A₀ - (k₁₂ + k₁₀) × A₁ + k₂₁ × A₂ + Rendo
```

Where Rendo represents endogenous testosterone production rate.

### Protein binding effects
97-99.5% of circulating testosterone binds to plasma proteins, with only 0.5-3.0% remaining as free testosterone. If your model doesn't account for protein binding, concentration calculations may be inaccurate:

- 30-44% binds to sex hormone-binding globulin (SHBG) 
- 54-68% binds to albumin

At low concentrations, non-linear pharmacokinetics from saturable protein binding may require Michaelis-Menten kinetics rather than simple first-order elimination.

### Realistic parameter ranges
For troubleshooting, verify your parameters against these physiological ranges for testosterone:

| Parameter | Description | Expected Range | Units |
|-----------|-------------|----------------|-------|
| CL | Clearance | 2.0-3.5 | kL/day |
| Vc | Central compartment volume | 10-20 | kL |
| Q | Intercompartmental clearance | 0.5-2.0 | kL/day |
| Vp | Peripheral compartment volume | 20-50 | kL |
| ka | Absorption rate constant | 0.2-2.0 | 1/hour |

Parameters significantly outside these ranges will produce physiologically implausible results.

## Bayesian calibration implementation issues

### Proper implementation requirements
Bayesian calibration combines prior parameter distributions with a likelihood function through Bayes' theorem:

```
p(θ|Y) ∝ p(Y|θ) × p(θ)
```

For TestoSim's `calibrateProtocolWithBayesian` function to work properly, it must:

1. Use appropriate prior distributions for testosterone-specific parameters
2. Implement an accurate likelihood function based on observation model
3. Use robust MCMC sampling methods (e.g., Metropolis-Hastings or Hamiltonian Monte Carlo)
4. Include sufficient burn-in period and convergence diagnostics

### Common calibration failures
Several issues can cause Bayesian calibration to produce physiologically implausible parameter estimates:

- **Overly restrictive priors** preventing the model from finding true parameter values
- **Improper initialization** of MCMC chains outside plausible parameter space
- **Insufficient sampling** or premature convergence declaration
- **Parameter correlation** causing identifiability issues, especially between volume and clearance parameters

If your implementation suffers from poor chain mixing or convergence, it may settle on parameter values that produce near-zero concentrations.

## Debugging your implementation

### Systematic verification process
Follow this systematic debugging process to identify the root cause:

1. **Verify mathematical implementation**: Review eigenvalue calculations and the analytical solution for the two-compartment model
2. **Implement log-transformed calculations**: Convert concentration calculations to log space to address numerical issues with small values
3. **Check parameter physiological plausibility**: Confirm all parameters are within expected ranges
4. **Add endogenous testosterone production**: Incorporate baseline production (7 mg/day) into your model
5. **Validate with simplified cases**: Test one-compartment model with same parameters, then gradually increase complexity

### Diagnostics and validation
Implement these diagnostics to validate your model:

1. **Mass balance check**: Total drug in system should equal administered dose minus eliminated amount
2. **Residual analysis**: Systematic errors in predictions may indicate model misspecification
3. **Analytical solution verification**: Compare numerical solutions with closed-form solutions for simple cases
4. **Cross-validation**: Validate against established PK software (NONMEM, SimCYP, etc.)

### Implementation best practices
For robust implementation, consider these best practices:

```
// Special case handling for eigenvalues
if (Math.abs(k12 + k10 - k21) < EPSILON) {
    // Handle special case where eigenvalues are very close
    alpha = beta = (k12 + k10 + k21) / 2;
    // Use special solution form for equal eigenvalues
} else {
    // Standard calculation
    double term = Math.sqrt((k12 + k10 + k21) * (k12 + k10 + k21) - 4 * k10 * k21);
    alpha = ((k12 + k10 + k21) + term) / 2;
    beta = ((k12 + k10 + k21) - term) / 2;
}

// Handle near-zero concentrations
if (concentration < MINIMUM_REPORTABLE_CONCENTRATION) {
    // Log warning
    logger.warn("Near-zero concentration calculated at time {}: {}", time, concentration);
    
    // Verify parameter values
    logger.debug("Parameters: k01={}, k10={}, k12={}, k21={}, V1={}", k01, k10, k12, k21, V1);
    
    // Check for numerical issues
    if (hasNumericalInstability()) {
        // Apply alternative calculation method
        concentration = calculateUsingLogTransformation();
    }
}
```

## Conclusion
The TestoSim app's near-zero concentration values likely stem from either mathematical implementation errors, failure to account for testosterone's unique properties, or issues in the Bayesian calibration process. By systematically reviewing these areas—particularly verifying rate constant implementations, accounting for endogenous testosterone production, and implementing robust numerical methods—you can identify and resolve the underlying issue. The solutions presented here provide a comprehensive troubleshooting framework specifically tailored to two-compartment pharmacokinetic models for testosterone.