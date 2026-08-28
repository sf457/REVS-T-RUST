# PROVENANCE — thesis ↔ code ↔ frozen data

Traceability record for the simulation code and the frozen result workbooks that
produce the thesis numbers. Prepared on branch `cleanup/stage0-3` (non-destructive
staging; no algorithm changes, no reruns).

## Code snapshots (git)
| Thesis chapter | Framework | Branch (commit) | Freeze tag (commit) | Entry point |
|----------------|-----------|-----------------|---------------------|-------------|
| Ch 3 — REVS | REVS, state-reset version | `REVS` (`029e80e`) | `revs-vtc-2025-freeze` (`94be6fc`) | `MainAlgorithm.mlx` |
| Ch 4 — RUST | Integrated code, minimal single-threshold config | `journal` (`61e2884`) | `rust-journal-freeze-v2` (`6fc8c2f`) | `run_baseline_comparison.m` (model `Threshold-Uniform-NoTierSel`) |
| Ch 5 — REVS-T with RUST | Integrated framework (full) | `journal` (`61e2884`) | `rust-journal-freeze-v2` (`6fc8c2f`) | `run_baseline_comparison.m` (model `RUST_V2` → REVS-T) |

Notes:
- **Ch 4 and Ch 5 share the same integrated codebase** (`journal`); they differ only
  by model configuration, not by code version.
- This public base is built on `journal` (clean, code-only). Ch 3 REVS will be
  included later as a separate `src-revs/` component (not yet added).
- Do not change model/ablation labels — they must stay identical to the workbook
  column names for traceability.

## Frozen result workbooks — checksums
⚠ These files are **local-only** (not present in the cleanup environment). Populate
`results_frozen/` and generate `SHA256SUMS.txt` (see `results_frozen/README.md`).

**CSV exports committed** (verify with `cd results_frozen && sha256sum -c SHA256SUMS.txt`).
Provenance check PASSED: aggregate `moderate/persistent/50%/RUST` = SR 92.79 / MAR 96.74
matches thesis Appendix D.

| Committed file (CSV export) | Was | Backs | SHA256 |
|---|---|---|---|
| `results_frozen/revst_full_allattacks_moderate-xu_frozen_2026-06-12.csv` | `RUST_final_results_v10_freeze.csv` | Ch4/Ch5 + App D aggregate (13 models) | `892b897318b59f08a3141824643cf657a3df940c2ffc487ac89cdb58babbe76f` |
| `results_frozen/revst_full_allattacks_perseed_frozen_2026-06-12.csv` | `RUST_final_results_v10_freeze__per_seed.csv` | App C per-seed / Wilcoxon (13×10) | `1bf4e5af2abc1ab4ef011cd5879dd8919bdfc23658832f75271e0bb54d4c2e10` |
| `results_frozen/revst_ch4_minimal-threshold_frozen_2026-06-12.csv` | `RUST_ch4_baseline_comparison.csv` | Ch4 / App D on-off (7 models) | `d69b3f617442a0080d7bbc6b5ed8165a10c6219f490e2416f4b5e3760ef6823b` |
| `results_frozen/conference/revst_conference_camera-ready_6models_frozen_2026-05-21.csv` | `REVST_..._6models.csv` | REVS-T **conference** (6 models, not thesis) | `f33a1d94aff2c96d09e1effe570e163a3107d145bd514328b00f547ed80c55a4` |
| `results_frozen/revs_coldstart_selection_frozen_2025-01.xlsx` **(canonical .xlsx)** | `allResults_Append.xlsx` | Ch 3 REVS cold-start (Dynamic vs Fixed init; 7 ST scenarios S1–S7) | `6c2f4e0880bb6bd2db360c06534619830d142e5467eaef04f515d9d94ff14280` |

Content is byte-identical to the originals (rename only; SHA256 unchanged, `sha256sum -c` = OK).
Thesis `.tex` cites the `.xlsx` originals — update those citations to the new basenames
(with `.xlsx`) so thesis ↔ file names stay in lockstep (see thesis change-map).

Model-family note: display labels `ScalarRep-EMA` = `calculateReputationIqbal.m`,
`ScalarRep-CumReward` = `calculateReputationIqbal2.m` (both active external baselines).

⚠ The Ch 3 REVS file is the committed **canonical `.xlsx`**. The RUST/REVS-T/conference
rows above are **CSV exports** — their canonical `.xlsx` originals still need to be
added + checksummed under the same basenames.

## Headline numbers (cross-check only; do not rerun to "re-verify")
SR 92.79% · MAR 96.74% · F1_gov 68.15% · Runs-to-First-Blacklist 64.7 vs 234.1.

## Reproduction (regenerates equivalent results; frozen files remain canonical)
```matlab
addpath(genpath(pwd));
run_baseline_comparison        % Ch 4 / Ch 5 integrated framework
```

## Open provenance items
- Confirm `journal`'s `Params.m` values match the workbook model columns (by inspection).
- Ch 3 REVS result file: **recorded** as `revs_coldstart_selection_frozen_2025-01.xlsx`
  (freeze date is month-precision; confirm exact day if known).
- Add the canonical `.xlsx` originals for the three RUST/REVS-T files (only `.csv`
  exports are committed so far).
- MATLAB version: thesis Ch 3 states **R2024b**; the `journal` README states
  **R2021a or later** — resolve this discrepancy (see README flag).
