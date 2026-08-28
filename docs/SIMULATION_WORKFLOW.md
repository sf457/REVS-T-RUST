# REVS-T Conference Paper: 6-Model Simulation Workflow

## Overview

This document details the exact simulation workflow for each of the 6 models in the ablation study, tracing through the actual code paths.

---

## Simulation Entry Point

**File**: `run_baseline_comparison.m`

```
run_baseline_comparison.m
    │
    ├── Params()                          # Load configuration
    ├── initializeVehiclePools()          # Create vehicle pools
    │
    └── FOR each (model, malicious%, attack_type, seed):
            │
            ├── initReputationForModel()  # Model-specific initialization
            │
            └── FOR runIndex = 1:1000:
                    │
                    └── simulationUtils.runSimulationWithSelection()
                            │
                            ├── Selection (SmartContract*.m)
                            ├── Offloading (V2VOffloading.m)
                            └── Reputation Update (calculateReputation*.m)
```

---

## Model Dispatch Logic

**File**: `src/simulation/simulationUtils.m:23-40`

```matlab
% Selection dispatch
useNotierSelection = strcmpi(model, 'RUST_NOTIER_baseline');
useMaxRepSelection = strcmpi(model, 'THRESHOLD_MAXREP');
useBaselineSelection = any(strcmpi(model, {'BetaUniform', '3VSL-Binary', 'Iqbal', 'Iqbal2'}));

if useNotierSelection
    SmartContract_Notier(...)           % No tier pool partitioning
elseif useMaxRepSelection
    SmartContract(..., 'MAXREP')        % Max-rep only, no stay-time
elseif useBaselineSelection
    SmartContract_reputationOnly(...)   % Pure max-rep baseline
else
    SmartContract(..., 'StrictTier')    # Tier-aware + composite
```

---

## Detailed Workflow for Each Model

---

### Model 1: REVS-T (Full Framework)

**Internal Name**: `RUST_V2`

| Component | Implementation | File:Line |
|-----------|---------------|-----------|
| **Selection** | `SmartContract.m` → `SelectedVproj2_StrictTier.m` | SmartContract.m:131 |
| **Reputation** | `calculateReputationRUST2_v2.m` | simulationUtils.m:180-181 |
| **Initialization** | ST-conditioned via `getInitialEvidence.m` | getInitialEvidence.m:43-56 |

#### Selection Algorithm (Tier-Aware + Composite)
```
1. fetchVehicles2()          → Get providers in RSU range
2. SortVproj2()              → Filter same direction, sort by (¬isWarning, R desc)
3. SelectedVproj2_StrictTier():
   a. Filter: R ≥ R_min (0.41) AND stayTime > 0
   b. Pool partition:
      - goodMask = R > R_warn (0.50)
      - warningMask = R_min ≤ R ≤ R_warn
      - Use goodMask if any; else warningMask (strict separation)
   c. Normalize stayTime within active pool
   d. Score = w1 × R + w2 × normStayTime  (w1=0.7, w2=0.3)
   e. Select argmax(Score)
```

#### 4-Tier Governance Policy
```matlab
% calculateReputationRUST2_v2.m:209-282

% (A) Track warning streak
if isFailure:
    warningStreak += 1
else:
    warningStreak = max(0, warningStreak - 0.5)

% (B) Escalation threshold varies by reputation tier
if R >= R_boost (0.70): escThreshold = warnEscalationRuns + 2 = 4
elif R >= R_warn (0.50): escThreshold = warnEscalationRuns + 1 = 3
else: escThreshold = warnEscalationRuns = 2

% (C) Streak-based escalation
if warningStreak >= escThreshold:
    isActive = false  # Blacklist
    totalBlacklists++

% (D) R-based tier assignment
elif R < R_min (0.41):
    if isFailure: isActive = false  # Blacklist
    else: isWarning = true          # Warning (survived)
elif R <= R_warn (0.50):
    isWarning = true                # Warning tier
elif R >= R_boost (0.70) AND success:
    R += rewardBoost (0.05)         # Boost reward
else:
    isWarning = false               # Stable tier

% (E) Progressive blackout duration
blackoutCounter = baseRuns × 2^(totalBlacklists-1)
# Strike 1: 3 runs, Strike 2: 6 runs, Strike 3: 12 runs
# After maxStrikes (4): permanent blacklist
```

#### ST-Conditioned Initialization
```matlab
% getInitialEvidence.m

ST_high:         {α=3, β=2, γ=1} → R₀ = (3+0.5×1)/(3+2+1) = 0.583
ST_intermediate: {α=2, β=2, γ=2} → R₀ = (2+0.5×2)/(2+2+2) = 0.500
ST_low:          {α=1, β=2, γ=3} → R₀ = (1+0.5×3)/(1+2+3) = 0.417
```

#### 3VSL Reputation Update
```matlab
% R = b + a0 × u where a0 = 0.5

% Evidence update with Dynamic Honesty (H):
H_base = H_SI × H_ST × (1 - penalty if warning/blackout)
H = min(1, H_base × (1 + 0.02 × successStreak))

if success:
    if latency < T_threshold: Δα = H × I
    else: Δγ = (1-H) × I
else:
    if H > H_high_thresh (0.80): Δγ = (1-H) × I    # Grace: uncertainty
    else: Δβ = (1-H) × I                          # Standard: negative
```

---

### Model 2: REVS-T-Uniform

**Internal Name**: `RUST_Uniform`

| Component | Implementation | Difference from REVS-T |
|-----------|---------------|------------------------|
| **Selection** | Same as REVS-T | None |
| **Reputation** | Same as REVS-T | None |
| **Initialization** | **Uniform: α=β=γ=2 for ALL** | ST ignored |

#### Initialization Difference
```matlab
% run_baseline_comparison.m initialization override

% ALL providers get uniform prior regardless of ST:
α = 2, β = 2, γ = 2  →  R₀ = 0.500 for everyone

% ST field is set to 'intermediate' to disable ST-based advantages
```

**Ablation Insight**: Isolates the contribution of ST-conditioned cold-start initialization.

---

### Model 3: Threshold

**Internal Name**: `Threshold`

| Component | Implementation | Difference from REVS-T |
|-----------|---------------|------------------------|
| **Selection** | Same as REVS-T | None |
| **Reputation** | `calculateReputationThreshold.m` | **Binary governance** |
| **Initialization** | Same as REVS-T | None |

#### Binary Governance (Single-Threshold)
```matlab
% calculateReputationThreshold.m:181-206

% ONLY DIFFERENCE: No warning tier, no streak escalation, no boost
if R < R_min (0.41):
    if isFailure:
        blackoutCounter = penaltyFreezeRuns (3)
        isActive = false    # Blacklist
        totalBlacklists++
    else:
        isActive = true     # Low but active
else:
    isActive = true         # Active

isWarning = false  # Always (no warning tier)
warningStreak = 0  # Always (no streak tracking)
```

**What's Preserved**:
- Same 3VSL evidence update
- Same Dynamic Honesty calculation
- Same Kang-style recommendations
- Same ST-conditioned initialization

**Ablation Insight**: Isolates the contribution of 4-tier governance depth.

---

### Model 4: Threshold-NoTierSel

**Internal Name**: `RUST_NOTIER_baseline`

| Component | Implementation | Difference from Threshold |
|-----------|---------------|---------------------------|
| **Selection** | `SmartContract_Notier.m` → `SelectedVproj.m` | **No tier pool partition** |
| **Reputation** | Same as Threshold | None |
| **Initialization** | Same as REVS-T | None |

#### Selection Algorithm (No-Tier + Composite)
```matlab
% SmartContract_Notier.m:41-56

1. fetchVehicles2()     → Get providers in RSU range
2. SortVproj()          → Filter same direction, R ≥ R_min (NO tier sorting)
3. SelectedVproj():
   a. Filter: R ≥ R_min
   b. NO pool partition (all compete equally)
   c. Score = w1 × R + w2 × normStayTime
   d. Select argmax(Score)

% Key difference: Warning-tier and good-tier providers compete equally
% No preferential treatment for R > R_warn
```

**Ablation Insight**: Isolates the contribution of tier-aware pool partitioning in selection.

---

### Model 5: Threshold-MaxRep

**Internal Name**: `Threshold_MaxRep`

| Component | Implementation | Difference from Threshold-NoTierSel |
|-----------|---------------|-------------------------------------|
| **Selection** | `SmartContract.m` → `SelectedVproj2_MaxRep.m` | **Max-rep only, no stay-time** |
| **Reputation** | Same as Threshold | None |
| **Initialization** | Same as REVS-T | None |

#### Selection Algorithm (Max-Rep Only)
```matlab
% SelectedVproj2_MaxRep.m:30-51

1. Filter: R ≥ R_min
2. Score = R  (no stay-time weighting)
3. Select argmax(R)

% Key difference: Pure reputation-based selection
% No composite scoring with mobility (stay-time)
```

**Ablation Insight**: Isolates the contribution of composite trust-mobility scoring.

---

### Model 6: Beta (Classical BRS Baseline)

**Internal Name**: `BetaUniform`

| Component | Implementation | Difference from Threshold-MaxRep |
|-----------|---------------|----------------------------------|
| **Selection** | `SmartContract_reputationOnly.m` | Same (max-rep) |
| **Reputation** | `calculateReputationBetaUniform.m` | **Classical Beta, no 3VSL** |
| **Initialization** | **Uniform: α=β=1** | Different uniform |

#### Classical Beta Reputation (Jøsang BRS)
```matlab
% calculateReputationBetaUniform.m:68-106

% Uniform prior (different from 3VSL uniform)
prior_alpha = 1
prior_beta = 1

% Aggregate ALL evidence globally (no per-requester split)
total_success = sum(numSuccess across all requesters)
total_failed = sum(numFailed across all requesters)

% Classical Beta formula
alpha = prior_alpha + total_success  # 1 + s
beta = prior_beta + total_failed     # 1 + f

R = alpha / (alpha + beta)           # (1+s) / (2+s+f)
```

#### NO Governance
```matlab
% calculateReputationBetaUniform.m:121-131

% Faithful to Jøsang & Ismail (2002): NO blacklisting
isActive = true     # Always
isWarning = false   # Always
blackoutCounter = 0 # Always
```

**What's Different**:
- No uncertainty (γ) modeling
- No per-requester evidence separation
- No recommendations
- No governance whatsoever
- Uniform α=β=1 (not α=β=γ=2)

**Ablation Insight**: Isolates the contribution of 3VSL uncertainty modeling vs classical Beta.

---

## Attack Pattern Handling

**File**: `src/simulation/V2VOffloading.m:37-89`

All 6 models use the same attack logic in V2VOffloading:

```matlab
if isMalicious AND shouldAttack:
    fVi = fVi × maliciousCapacityFactor (0.5)
    transmissionRate = transmissionRate × maliciousTransmissionFactor (0.7)
```

### Attack Pattern Determination

| Pattern | Logic | Rate |
|---------|-------|------|
| `always` | `shouldAttack = true` | 100% |
| `onoff` | `shouldAttack = (mod(totalInteractions, period) < attacksPerPeriod)` | 50% (period=2, attacks=1) |
| `firsthalf` | `shouldAttack = (totalInteractions >= T/2)` | 50% (honest→attack at midpoint) |

---

## Summary: Feature Isolation Chain

```
REVS-T (Full)
    │
    │ Remove ST-conditioned init
    ↓
REVS-T-Uniform ───────────────────→ Isolates: Cold-start advantage
    │
    │ Remove 4-tier governance
    ↓
Threshold ────────────────────────→ Isolates: Governance depth
    │
    │ Remove tier-aware pool partition
    ↓
Threshold-NoTierSel ──────────────→ Isolates: Pool partitioning benefit
    │
    │ Remove composite scoring
    ↓
Threshold-MaxRep ─────────────────→ Isolates: Trust-mobility scoring
    │
    │ Replace 3VSL with Beta
    ↓
Beta (BRS) ───────────────────────→ Isolates: Uncertainty (γ) contribution
```

---

## Code Path Summary Table

| Model | Selection File | Selection Policy | Reputation File | Governance |
|-------|---------------|------------------|-----------------|------------|
| REVS-T | SmartContract.m | StrictTier | calculateReputationRUST2_v2.m | 4-tier + escalation |
| REVS-T-Uniform | SmartContract.m | StrictTier | calculateReputationRUST2_v2.m | 4-tier + escalation |
| Threshold | SmartContract.m | StrictTier | calculateReputationThreshold.m | Single-threshold |
| Threshold-NoTierSel | SmartContract_Notier.m | NoTier | calculateReputationThreshold.m | Single-threshold |
| Threshold-MaxRep | SmartContract.m | MaxRep | calculateReputationThreshold.m | Single-threshold |
| Beta | SmartContract_reputationOnly.m | MaxRep | calculateReputationBetaUniform.m | None |

---

## Key Parameters

**File**: `config/Params.m`

### Governance Thresholds
```matlab
R_min  = 0.41   % Blacklist threshold
R_warn = 0.50   % Warning tier threshold  
R_boost = 0.70  % Boost tier threshold
penaltyFreezeRuns = 3      % Base blackout duration
warnEscalationRuns = 2     % Warnings before auto-blacklist
maxStrikes = 4             % Blacklists before permanent ban
```

### Selection Weights
```matlab
w1 = 0.7    % Reputation weight
w2 = 0.3    % Stay-time weight
warningPenalty = 0.10  % (unused in StrictTier)
```

### 3VSL Parameters
```matlab
a0 = 0.50              % R = b + a0 × u
H_high_thresh = 0.80   % Grace threshold
H_low_thresh = 0.35    % Harsh penalty threshold
```

### ST-Based Initialization
```matlab
stInit.high = {α=3, β=2, γ=1}           % R₀ = 0.583
stInit.intermediate = {α=2, β=2, γ=2}   % R₀ = 0.500
stInit.low = {α=1, β=2, γ=3}            % R₀ = 0.417
```
