# REVS-T Conference Paper: Reproduction Guide

## Repository Reference

- **Branch**: `claude/march3-baseline-TzPMX`
- **Tag**: `revs-t-conference-freeze-v2`

To checkout the frozen version:
```bash
git fetch origin
git checkout revs-t-conference-freeze-v2
```

## Entry Point

```matlab
run_baseline_comparison.m
```

## Expected Outputs

At 50% malicious, moderate assignment, persistent (always) attack:

| Metric | Expected Value |
|--------|---------------|
| SR (Success Rate) | 91.9% |
| MAR (Malicious Avoidance Rate) | 96.7% |

## Running the Full Experiment

```matlab
% Run complete ablation study (6 models x 4 malicious% x 2 assignments x 3 attacks)
run_baseline_comparison
```

This generates:
- `results/<timestamp>/baseline_comparison.csv` - All metrics
- `results/<timestamp>/results.mat` - Full simulation data

## Quick Verification (Single Config)

For fast verification, modify `run_baseline_comparison.m` lines 100-103:

```matlab
% Original (full sweep):
cfg.models = {'RUST_V2', 'RUST_Uniform', 'RUST_NoRec', 'RUST_NoTier', ...
              'Threshold', 'RUST_NOTIER_baseline', 'Threshold_MaxRep', ...
              'ThresholdUniform', 'Iqbal', 'Iqbal2', 'BetaUniform', '3VSL-Binary'};

% Quick verification (RUST only):
cfg.models = {'RUST_V2'};
```

And reduce to single configuration:
```matlab
cfg.maliciousPercentages = [0.5];        % 50% only
cfg.assignmentConfigs = {'moderate'};    % moderate only
cfg.attackTypes = {'always'};            % persistent only
cfg.numSimulations = 100;                % faster (vs 1000)
```

Run time: ~2-5 minutes for single config vs ~2-4 hours for full sweep.

## Where Results Are Saved

```
results/
└── <YYYY-MM-DD_HH-MM-SS>/
    ├── baseline_comparison.csv    # Summary table
    ├── results.mat                # Full data
    └── trajectories/              # (if captureTrajectories=true)
        └── *.mat                  # Per-model trajectory data
```

## Verifying Results

After running, load and check:
```matlab
load('results/<timestamp>/results.mat');

% Find RUST at 50% malicious, moderate, always
idx = find(strcmp({allResults.Model}, 'RUST_V2') & ...
           [allResults.MaliciousPct] == 0.5 & ...
           strcmp({allResults.Assignment}, 'moderate') & ...
           strcmp({allResults.AttackType}, 'always'));

fprintf('SR: %.1f%%\n', allResults(idx).SR);
fprintf('MAR: %.1f%%\n', allResults(idx).MAR);
```

## Troubleshooting

**Out of memory**: Reduce `cfg.numSimulations` or run fewer models.

**Path errors**: Ensure you're in the repository root and run:
```matlab
setup_paths;
addpath(genpath('+bc'));
```

**Different results**: Verify `cfg.baseSeed = 1234` for reproducibility.
