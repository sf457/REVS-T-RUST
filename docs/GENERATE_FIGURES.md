# Generating Conference Paper Figures

## Overview

This guide explains how to generate publication-quality figures for the REVS-T conference paper using the available scripts.

---

## Workflow Summary

```
┌────────────────────────────────┐
│  Step 1: Run Experiments       │
│  run_baseline_comparison.m     │
└──────────────┬─────────────────┘
               │
               ▼
┌────────────────────────────────┐
│  Results saved to:             │
│  results/<timestamp>/          │
│    ├── baseline_comparison.csv │
│    └── results.mat             │
└──────────────┬─────────────────┘
               │
               ▼
┌────────────────────────────────┐
│  Step 2: Generate Figures      │
│  generate_baseline_figures.m   │
│  plot_reputation_comparison.m  │
└──────────────┬─────────────────┘
               │
               ▼
┌────────────────────────────────┐
│  Figures saved to:             │
│  figures/<config>/             │
│    ├── fig1_success_rate.pdf   │
│    ├── fig2_mar_comparison.pdf │
│    └── ...                     │
└────────────────────────────────┘
```

---

## Step 1: Run Experiments

### Run Full Ablation Study
```matlab
% In MATLAB, from REVS-RUST directory:
run_baseline_comparison
```

This runs:
- **6 models**: REVS-T, REVS-T-Uniform, Threshold, Threshold-NoTierSel, Threshold-MaxRep, Beta
- **4 malicious %**: 0%, 10%, 30%, 50%
- **2 assignments**: xu_aligned, moderate
- **3 attack types**: always, onoff, firsthalf
- **1000 simulations** per scenario

**Output**: `results/<timestamp>/baseline_comparison.csv`

### Expected Runtime
- Full run: ~2-4 hours (depending on hardware)
- Quick test: Modify `cfg.numSimulations = 100` for faster iteration

---

## Step 2: Generate Figures

### Option A: generate_baseline_figures.m (Recommended)

**Usage:**
```matlab
% Auto-find latest results, use first config
generate_baseline_figures

% Specify assignment and attack type
generate_baseline_figures('', 'xu_aligned', 'always')
generate_baseline_figures('', 'moderate', 'onoff')
generate_baseline_figures('', 'xu_aligned', 'firsthalf')

% Specify results folder
generate_baseline_figures('results/2024-02-14_15-30', 'xu_aligned', 'always')

% Filter to specific models
generate_baseline_figures('', 'xu_aligned', 'always', {'RUST_V2', 'Threshold', 'BetaUniform'})
```

**Figures Generated:**

| Figure | Filename | Description |
|--------|----------|-------------|
| Fig 1 | `fig1_success_rate.pdf` | Success Rate vs Malicious % (line chart) |
| Fig 2 | `fig2_mar_comparison.pdf` | MAR at 30% and 50% malicious (bar chart) |
| Fig 3 | `fig3_detection_metrics.pdf` | TPR, Precision, F1 at 50% (grouped bar) |
| Fig 4 | `fig4_latency.pdf` | Latency comparison (line chart) |
| Fig 5 | `fig5_heatmap.pdf` | All metrics heatmap at 50% |
| Fig 6 | `fig6_summary.pdf` | Summary comparison (grouped bar) |
| Fig 7a | `fig7a_attack_comparison_mar.pdf` | MAR across attack types |
| Fig 7b | `fig7b_attack_comparison_sr.pdf` | Success Rate across attack types |
| Fig 7c | `fig7c_attack_robustness_heatmap.pdf` | Attack robustness heatmap |

**Output Location**: `figures/<assignment>_<attack>/`

---

### Option B: plot_reputation_comparison.m

**Purpose**: Shows reputation evolution over time (trajectory plots)

**Usage:**
```matlab
% Run simulations and generate figures
plot_reputation_comparison

% Force re-run (ignore saved data)
runMode = 'run';
plot_reputation_comparison

% Load specific saved data
runMode = 'results/rep_comparison_2024-02-14/rep_comparison_data.mat';
plot_reputation_comparison
```

**Figures Generated:**

| Figure | Filename | Description |
|--------|----------|-------------|
| Fig 1 | `malicious_rep_suppression.png` | Mean reputation of malicious providers over time |
| Fig 2 | `malicious_rep_confidence.png` | Same with confidence bands (mean ± std) |
| Fig 3 | `rep_evolution_comparison.png` | Side-by-side: malicious vs honest trajectories |
| Fig 4 | `time_to_blacklist.png` | Mean interactions until R drops below R_min |

**Output Location**: `results/rep_comparison_<timestamp>/`

---

## Conference Paper Figure Mapping

### Main Results (Section VI)

| Paper Figure | Script | Config | Description |
|--------------|--------|--------|-------------|
| Fig. 3 | `generate_baseline_figures` | xu_aligned, always | Success Rate vs Malicious % |
| Fig. 4 | `generate_baseline_figures` | xu_aligned, always | MAR Comparison |
| Fig. 5 | `generate_baseline_figures` | *, always | Attack Type Robustness |
| Fig. 6 | `plot_reputation_comparison` | - | Reputation Evolution |
| Fig. 7 | `generate_baseline_figures` | xu_aligned, 50% | Detection Metrics (TPR, F1) |

### Ablation Study Figures

| Paper Section | Script | Models to Include |
|---------------|--------|-------------------|
| Ablation Chain | `generate_baseline_figures` | All 6 models |
| ST-Init Impact | Compare RUST_V2 vs RUST_Uniform | |
| Governance Depth | Compare RUST_Uniform vs Threshold | |
| Tier Selection | Compare Threshold vs RUST_NOTIER_baseline | |
| Composite Score | Compare RUST_NOTIER_baseline vs Threshold_MaxRep | |
| 3VSL vs Beta | Compare Threshold_MaxRep vs BetaUniform | |

---

## Generating Specific Figures

### 1. Success Rate Line Chart (Fig. 3)
```matlab
generate_baseline_figures('', 'xu_aligned', 'always')
% Output: figures/xu_aligned_always/fig1_success_rate.pdf
```

### 2. MAR Bar Chart (Fig. 4)
```matlab
generate_baseline_figures('', 'xu_aligned', 'always')
% Output: figures/xu_aligned_always/fig2_mar_comparison.pdf
```

### 3. Attack Robustness Comparison
```matlab
% Requires running all 3 attack types first
generate_baseline_figures('', 'xu_aligned', 'always')
% Output: figures/xu_aligned_always/fig7c_attack_robustness_heatmap.pdf
```

### 4. Reputation Evolution
```matlab
plot_reputation_comparison
% Output: results/rep_comparison_*/malicious_rep_suppression.png
```

### 5. Ablation-Only Comparison
```matlab
% Only 6 ablation models, exclude external baselines
generate_baseline_figures('', 'xu_aligned', 'always', ...
    {'RUST_V2', 'RUST_Uniform', 'Threshold', 'RUST_NOTIER_baseline', 'Threshold_MaxRep', 'BetaUniform'})
```

---

## Output Formats

All figures are saved in three formats:
- `.fig` - MATLAB figure (editable)
- `.pdf` - Vector format (publication quality)
- `.png` - Raster format (300 DPI)

---

## Customization

### Changing Colors

Edit `defineModelColors()` in `generate_baseline_figures.m:459-488`:

```matlab
colorMap('RUST_V2') = [0.0 0.4 0.8];      % Blue
colorMap('Threshold') = [0.0 0.6 0.6];    % Teal
colorMap('BetaUniform') = [0.7 0.5 0.2];  % Orange
```

### Changing Figure Size

Edit figure creation lines:
```matlab
fig1 = figure('Position', [100 100 800 500], 'Color', 'w');
%                          x    y   width height
```

### Changing Y-Axis Limits

Edit after each plot:
```matlab
ylim([60 100]);  % For percentage metrics
ylim([0 200]);   % For latency in ms
```

---

## Troubleshooting

### "No results found"
```matlab
% Check if results exist
ls results/
% Run experiments first
run_baseline_comparison
```

### "No 50% malicious data"
Ensure `cfg.maliciousPercentages` includes 0.5 in `run_baseline_comparison.m`

### Figures look different
MATLAB version differences may affect fonts/rendering. Use:
```matlab
set(groot, 'defaultAxesFontName', 'Arial')
set(groot, 'defaultAxesFontSize', 12)
```

---

## Quick Reference

```matlab
%% Full pipeline
run_baseline_comparison                                    % ~2-4 hours
generate_baseline_figures('', 'xu_aligned', 'always')      % ~30 seconds
generate_baseline_figures('', 'moderate', 'always')        % ~30 seconds
plot_reputation_comparison                                 % ~5 minutes

%% Outputs
% results/<timestamp>/baseline_comparison.csv
% figures/xu_aligned_always/*.pdf
% figures/moderate_always/*.pdf
% results/rep_comparison_*/*.png
```
