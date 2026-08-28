# REVS-RUST Metrics Reference

This document describes all evaluation metrics used in the REVS-RUST vehicular edge computing simulation framework.

## Overview

The framework uses three categories of metrics to evaluate reputation system performance:

1. **Blacklist Coverage (BC) Metrics** - Final blacklist state (exposure-dependent)
2. **Exposure-Normalized Metrics** - Detection conditioned on evidence availability
3. **Selection-Based Metrics** - Per-selection outcome evaluation

---

## 1. Blacklist Coverage (BC) Metrics

> **Formerly named TPR_gov** - Renamed to clarify exposure dependency

### Important: Selection Dependency

BC metrics measure the **system-wide eventual blacklisting rate**, which **depends on exposure**:

- **Higher MAR** (avoiding malicious providers) -> less evidence -> fewer blacklists -> **lower BC**
- **Lower MAR** (selecting malicious providers) -> more evidence -> more blacklists -> **higher BC**

This is the **opposite direction** of selection-based metrics (TPR_sel).

### Metrics

| Metric | Formula | Description |
|--------|---------|-------------|
| `BC` | TP / (TP + FN) | Blacklist Coverage - % of malicious providers blacklisted |
| `BC_FPR` | FP / (FP + TN) | False positive rate - honest providers incorrectly blacklisted |
| `BC_FNR` | FN / (TP + FN) | False negative rate - malicious providers not blacklisted |
| `BC_TNR` | TN / (FP + TN) | True negative rate - honest providers correctly not blacklisted |
| `BC_Precision` | TP / (TP + FP) | Precision of blacklist decisions |
| `BC_NPV` | TN / (TN + FN) | Negative predictive value |
| `BC_F1` | 2*TP / (2*TP + FP + FN) | F1 score for blacklist decisions |

### Confusion Matrix (Final State)

|  | Blacklisted | Not Blacklisted |
|--|-------------|-----------------|
| **Malicious** | TP_gov | FN_gov |
| **Honest** | FP_gov | TN_gov |

### Legacy Aliases

For backward compatibility, the following aliases exist:
- `TPR_gov` = `BC`
- `FPR_gov` = `BC_FPR`
- `FNR_gov` = `BC_FNR`
- etc.

> **Warning**: BC/TPR_gov is exposure-dependent and will appear lower for models with high MAR. A model that effectively avoids malicious providers gathers less evidence, resulting in fewer blacklists even if its detection capability is strong. Use `TPR_exp` for fair cross-model comparison.

---

## 2. Exposure-Normalized Detection Metric

### TPR_exp (Exposure-Conditioned True Positive Rate)

This metric is **UNBIASED by selection strategy** because it only considers providers that the system actually had a chance to observe.

**Formula:**
```
TPR_exp = #{malicious providers blacklisted} / #{malicious providers with >= 1 interaction}
```

### Why TPR_exp Matters

Consider two selection models:
- **Model A**: High MAR (avoids malicious) - may have many unobserved malicious providers
- **Model B**: Low MAR (selects malicious) - observes most malicious providers

With standard BC:
- Model A might have low BC because it never gathered evidence on many malicious providers
- Model B might have high BC because it observed all malicious providers

With TPR_exp:
- Both models are evaluated only on providers they actually observed
- This isolates the **detection capability** from the **avoidance capability**

### Supporting Metrics

| Metric | Description |
|--------|-------------|
| `TPR_exp` | Detection rate among exposed malicious providers (%) |
| `MalExposureRate` | % of malicious providers that were selected at least once |
| `NumMalExposed` | Count of malicious providers with >= 1 interaction |
| `NumMalBlacklistedExposed` | Count of exposed malicious providers that were blacklisted |

---

## 3. Selection-Based Metrics

These metrics evaluate detection **at the point of selection** - per-interaction outcomes.

### Metrics

| Metric | Formula | Description |
|--------|---------|-------------|
| `TPR_sel` | TP_sel / (TP_sel + FN_sel) | % of malicious selections that failed (detected) |
| `FPR_sel` | FP_sel / (FP_sel + TN_sel) | % of honest selections that failed (false alarm) |
| `FNR_sel` | FN_sel / (TP_sel + FN_sel) | % of malicious selections that succeeded (missed) |
| `TNR_sel` | TN_sel / (FP_sel + TN_sel) | % of honest selections that succeeded |
| `Precision_sel` | TP_sel / (TP_sel + FP_sel) | Precision of failure detection |
| `NPV_sel` | TN_sel / (TN_sel + FN_sel) | Negative predictive value |
| `F1_sel` | 2*TP_sel / (2*TP_sel + FP_sel + FN_sel) | F1 score |

### Confusion Matrix (Per-Selection)

|  | Task Failed | Task Succeeded |
|--|-------------|----------------|
| **Malicious Selected** | TP_sel | FN_sel |
| **Honest Selected** | FP_sel | TN_sel |

---

## 4. Other Key Metrics

### Avoidance Metrics

| Metric | Description |
|--------|-------------|
| `MAR` | Malicious Avoidance Rate - % of selections that avoided malicious providers |
| `PMTI` | Precision_sel × MAR / 100. Event-independent composite metric. Lower = better (less pre-containment exposure). |
| `SER_mal` | P(malicious selected \| malicious available). Conditional mistake rate. Undefined (NaN) if no malicious ever in pool. |

### Reputation Metrics

| Metric | Description |
|--------|-------------|
| `RepSep` | Reputation Separation - gap between mean honest and mean malicious reputation |

### Availability Metrics

| Metric | Description |
|--------|-------------|
| `Availability` | % of requests with available providers |
| `PoolAvailability` | % of providers not blacklisted |
| `HonestAvailability` | % of honest providers not blacklisted |
| `ServiceDenialRate` | % of requests with no available provider |

### Performance Metrics

| Metric | Description |
|--------|-------------|
| `SuccessRate` | % of offloading tasks that succeeded |
| `FailureRate` | % of offloading tasks that failed |
| `Latency` | Average task completion latency |

---

## Metric Relationships

```
Selection Strategy (high/low MAR)
        |
        v
+-------+--------+
|                |
v                v
Exposure         TPR_sel
(who gets        (per-selection
observed)        detection)
|
v
+-----------------+
|                 |
v                 v
BC (Blacklist     TPR_exp (detection
Coverage)         given exposure)
exposure-         exposure-
dependent         normalized
```

**Key insight**:
- BC depends on both detection ability AND exposure
- TPR_exp isolates detection ability by conditioning on exposure
- TPR_sel measures immediate detection at selection time

---

## Quick Reference

| Goal | Metric | Notes |
|------|--------|-------|
| Evaluate overall system effectiveness | `BC`, `MAR` | |
| Compare detection across models | `TPR_exp` | Removes selection bias by conditioning on exposure |
| Immediate task-level detection | `TPR_sel` | |
| Composite evaluation | `PMTI`, `F1` | PMTI = Precision_sel × MAR / 100 (event-independent) |

---

## Version History

- **v2.0** (2026-03): Added BC naming, TPR_exp exposure-normalized metric
- **v1.0** (2024): Initial metrics (TPR_gov, TPR_sel, MAR)
