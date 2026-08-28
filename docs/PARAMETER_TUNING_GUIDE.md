# REVS-RUST Parameter Tuning Guide

## Overview

This guide documents the comprehensive parameter tuning system for the REVS-RUST vehicular edge computing simulation framework. The system provides centralized configuration management and systematic parameter optimization through grid search and sensitivity analysis.

## Quick Start

```matlab
% Create configuration with default values
config = SimulationConfig();

% Or use a preset
config = SimulationConfig('preset', 'conservative');

% Modify specific parameters
config.reputation.R_min = 0.35;
config.selection.w1 = 0.75;

% Validate configuration
[isValid, errors] = config.validate();

% View configuration summary
disp(config);
```

## Files Created

| File | Description |
|------|-------------|
| `SimulationConfig.m` | Centralized configuration class with all tunable parameters |
| `ParameterTuning.m` | Grid search, random search, and sensitivity analysis tools |
| `run_parameter_tuning.m` | Example script demonstrating usage |

---

## Complete Parameter Reference

### 1. Simulation Control Parameters

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `numSimulations` | 1000 | [100, 10000] | Iterations per seed |
| `numSeeds` | 10 | [3, 20] | Monte Carlo runs |
| `maliciousPercentages` | [0, 0.1, 0.3, 0.5] | [0, 1] | Malicious ratios to test |
| `randomSeed` | 42 | Any integer | Base RNG seed |

### 2. Vehicle Pool Parameters

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `numRequesters` | 30 | [10, 100] | Number of requester vehicles |
| `numProviders` | 70 | [20, 200] | Number of provider vehicles |
| `numVehicles_min` | 10 | [5, 30] | Minimum subset size |
| `numVehicles_max` | 30 | [10, 50] | Maximum subset size |
| `fixedReputationValue` | 0.6 | [0.4, 0.8] | Fixed scenario reputation |

### 3. Trust Distribution Parameters

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `probabilities.high` | 0.40 | [0.2, 0.5] | High trust proportion |
| `probabilities.intermediate` | 0.50 | [0.3, 0.6] | Intermediate trust proportion |
| `probabilities.low` | 0.10 | [0.05, 0.3] | Low trust proportion |

**Initial Belief Parameters (Dempster-Shafer):**

| Trust Level | Alpha | Beta | Gamma | Initial Reputation |
|-------------|-------|------|-------|-------------------|
| High | 3 | 2 | 1 | 0.583 |
| Intermediate | 2 | 2 | 2 | 0.500 |
| Low | 1 | 2 | 3 | 0.417 |

### 4. Reputation System Parameters

#### Thresholds

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `R_min` | 0.40 | [0.30, 0.50] | Blacklist threshold |
| `R_warn` | 0.50 | [0.40, 0.60] | Warning threshold |
| `R_boost` | 0.60 | [0.50, 0.70] | Reward threshold |

**Constraint:** `R_min < R_warn < R_boost`

#### Reward/Penalty

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `rewardBoost` | 0.05 | [0.02, 0.10] | Reputation increase for good performers |
| `penaltyFreezeRuns` | 3 | [2, 5] | Blacklist freeze duration |
| `maxWarningStreak` | 3 | [2, 5] | Warnings before escalation |

#### Opinion Combination Weights

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `zeta` | 0.6 | [0.4, 0.8] | Recent interaction weight |
| `sigma` | 0.4 | [0.2, 0.6] | Past interaction weight (1 - zeta) |
| `theta` | 0.3 | [0.2, 0.5] | Positive effect weight |
| `tau` | 0.7 | [0.5, 0.8] | Negative effect weight (1 - theta) |
| `rho` | 0.5 | [0.3, 0.7] | Recommended opinion fusion weight |

**Constraints:** `zeta + sigma = 1`, `theta + tau = 1`

#### Honesty Scores

| Trust Level | Success | Failure |
|-------------|---------|---------|
| High | 1.0 | 0.5 |
| Intermediate | 0.6 | 0.4 |
| Low | 0.4 | 1.0 |

### 5. Provider Selection Parameters

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `w1` | 0.70 | [0.5, 0.9] | Reputation weight |
| `w2` | 0.30 | [0.1, 0.5] | Stay-time weight (1 - w1) |
| `minReputationThreshold` | 0.40 | [0.3, 0.5] | Minimum reputation to consider |

**Constraint:** `w1 + w2 = 1`

**Trust Score Formula:**
```
Trust_score = w1 * reputation + w2 * normalized_stay_time
```

### 6. Malicious Behavior Parameters

#### Probability by Trust Tier

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `probabilities.high` | 0.10 | [0.05, 0.20] | High trust malicious probability |
| `probabilities.intermediate` | 0.30 | [0.20, 0.40] | Intermediate trust malicious probability |
| `probabilities.low` | 0.60 | [0.50, 0.80] | Low trust malicious probability |

#### Performance Degradation

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `computationCapacityFactor` | 0.50 | [0.3, 0.7] | Capacity multiplier for malicious |
| `transmissionRateFactor` | 0.70 | [0.5, 0.9] | Rate multiplier for malicious |

### 7. Vehicle Properties

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `computationCapacity` | 10e9 Hz | [5e9, 20e9] | Default CPU capacity |
| `transmissionRate` | 86e6 bps | [50e6, 150e6] | Default transmission rate |
| `communicationRadius` | 250 m | [100, 500] | V2V communication range |
| `baseSpeed` | 60 km/h | [40, 80] | Base vehicle speed |
| `speedStdDev` | 10 km/h | [5, 20] | Speed variation |

### 8. Task Generation Parameters

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `inputDataSizeRange` | [50, 500] KB | [10, 1000] | Task data size range |
| `cpuCycleRange` | [0.2e9, 3.2e9] | [0.1e9, 5e9] | CPU cycles range |
| `CPUFrequency` | 5e9 Hz | [3e9, 10e9] | Reference CPU for deadline |
| `servicePriceRange` | [50, 200] | [10, 500] | Service price range |

### 9. V2V Offloading Cost Parameters

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `psiV2V` | 0.5 | [0.2, 1.0] | Transmission cost coefficient |
| `etaV2V` | 1.0 | [0.5, 2.0] | Execution cost coefficient |

**Cost Formula:**
```
Total_cost = psiV2V * transmission_time + etaV2V * execution_time
```

---

## Configuration Presets

### Conservative Preset
- Stricter reputation thresholds
- Quicker blacklisting
- Best for high-security scenarios

```matlab
config = SimulationConfig('preset', 'conservative');
% R_min=0.45, R_warn=0.55, R_boost=0.65, rewardBoost=0.03
```

### Aggressive Preset
- More lenient thresholds
- Gives vehicles more chances
- Best for high-availability scenarios

```matlab
config = SimulationConfig('preset', 'aggressive');
% R_min=0.35, R_warn=0.45, R_boost=0.55, rewardBoost=0.08
```

### Fast Test Preset
- Reduced iterations for quick testing
- Use during development

```matlab
config = SimulationConfig('preset', 'fast_test');
% numSimulations=100, numSeeds=3
```

---

## Parameter Tuning Methods

### Grid Search

Exhaustively evaluates all parameter combinations:

```matlab
tuner = ParameterTuning(config);
tuner = tuner.defineParameterSpace(...
    'reputation_R_min', [0.35, 0.40, 0.45], ...
    'selection_w1', [0.6, 0.7, 0.8]);

[results, tuner] = tuner.gridSearch(@runSimulation, ...
    'maxEvaluations', 100);
```

### Random Search

Randomly samples from parameter space:

```matlab
[results, tuner] = tuner.randomSearch(@runSimulation, 50);
```

### Sensitivity Analysis

Analyzes impact of single parameter:

```matlab
[sensResults, tuner] = tuner.sensitivityAnalysis(...
    @runSimulation, ...
    'reputation_R_min', ...
    0.30:0.05:0.50);

tuner.plotSensitivityAnalysis(sensResults);
```

---

## Creating a Simulation Wrapper

To use parameter tuning, wrap your simulation to accept `SimulationConfig`:

```matlab
function metrics = runSimulationWithConfig(config)
    % Extract parameters
    numSims = config.simulation.numSimulations;
    R_min = config.reputation.R_min;
    w1 = config.selection.w1;

    % Initialize vehicle pools
    [Vreqipool, VprojPool] = initializeVehiclePools(...
        config.vehiclePool.numRequesters, ...
        config.vehiclePool.numProviders);

    % Run simulation loop
    % ... your existing simulation code ...

    % Return metrics
    metrics = struct();
    metrics.AvgSuccessRate = mean(successRates);
    metrics.AvgLatency = mean(latencies);
    metrics.MaliciousAvoidanceRate = malAvoidRate;
end
```

---

## Tuning Best Practices

### 1. Start with Sensitivity Analysis
Identify which parameters have the most impact before full grid search:

```matlab
% Test each key parameter independently
params = {'reputation_R_min', 'reputation_R_boost', 'selection_w1'};
for p = params
    [sens, tuner] = tuner.sensitivityAnalysis(@runSim, p{1}, values);
end
```

### 2. Use Coarse-to-Fine Approach
Start with wide ranges, then narrow:

```matlab
% Round 1: Coarse search
tuner = tuner.defineParameterSpace('reputation_R_min', [0.3, 0.4, 0.5]);

% Round 2: Fine search around best
tuner = tuner.defineParameterSpace('reputation_R_min', [0.38, 0.40, 0.42]);
```

### 3. Use Fast Test Preset for Development
```matlab
config = SimulationConfig('preset', 'fast_test');
% Quick validation before full runs
```

### 4. Monitor Constraint Satisfaction
Ensure complementary parameters sum correctly:
- `w1 + w2 = 1`
- `zeta + sigma = 1`
- `theta + tau = 1`
- Trust distribution probabilities sum to 1

### 5. Save Progress
```matlab
[results, tuner] = tuner.gridSearch(@runSim, 'saveProgress', true);
tuner.exportResults('tuning_results.mat');
tuner.generateReport('tuning_report.txt');
```

---

## Output Files

| File | Description |
|------|-------------|
| `tuning_results.mat` | Complete tuning data |
| `tuning_report.txt` | Human-readable summary |
| `config_export.csv` | Parameters in spreadsheet format |
| `sensitivity_plot.png` | Sensitivity visualization |

---

## Troubleshooting

### Invalid Configuration Error
```matlab
[isValid, errors] = config.validate();
if ~isValid
    disp(errors);  % Shows specific issues
end
```

### Common Issues
1. **Threshold ordering**: Ensure `R_min < R_warn < R_boost`
2. **Weight sums**: Ensure complementary weights sum to 1
3. **Probability bounds**: All probabilities must be in [0, 1]

### Performance Tips
- Use `'maxEvaluations'` to limit grid search
- Use random search for large parameter spaces (>1000 combinations)
- Enable `'parallelEval'` if Parallel Computing Toolbox is available

---

## API Reference

### SimulationConfig

```matlab
config = SimulationConfig()              % Default config
config = SimulationConfig('preset', 'conservative')  % With preset
[isValid, errors] = config.validate()    % Validate
config.saveConfig('file.mat')            % Save
config.exportToCSV('params.csv')         % Export
disp(config)                             % Display summary
SimulationConfig.printParameterRanges()  % Show recommended ranges
```

### ParameterTuning

```matlab
tuner = ParameterTuning(config)          % Create tuner
tuner = tuner.defineParameterSpace(...)  % Set search space
[r, t] = tuner.gridSearch(@fn)           % Grid search
[r, t] = tuner.randomSearch(@fn, n)      % Random search
[r, t] = tuner.sensitivityAnalysis(...)  % Sensitivity analysis
tuner.plotGridSearchResults(results)     % Visualize
tuner.generateReport('report.txt')       % Generate report
ParameterTuning.compareConfigs(c1, c2)   % Compare configs
```

---

## Version History

- **v1.0** (2024): Initial release with grid search, random search, and sensitivity analysis

## Authors

REVS-RUST Team
