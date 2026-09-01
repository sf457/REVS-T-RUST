# results_frozen/ — canonical frozen result sets

Holds the **frozen result files that back the numbers reported in the thesis**
(and the REVS-T conference paper). Canonical source of record: reported tables and
figures come from these files, not regenerated ad hoc.

> STATUS: **released publicly under the MIT license** alongside the simulation code.

## Naming convention
`<framework>_<experiment>_<config>_frozen_<YYYY-MM-DD>.<ext>`
- `results_frozen/`            — thesis result sets
- `results_frozen/conference/` — REVS-T conference artifacts (not thesis results)
- `results/` (repo root)       — regenerable trial outputs, **git-ignored**

Freeze dates: REVS-T/RUST **2026-06-12** (thesis provenance note: "ALL numbers
verified 12 Jun 2026"); REVS **2025-01** (VTC-2025 timeframe; month precision) and conference **2026-05-21** are the
git freeze-tag commit dates (`revs-vtc-2025-freeze`, `revs-t-conf-camera-ready`) —
confirm/replace with the actual run dates if you have them.

## Files (old name → current name)
| Current file | Was | Backs | Models |
|---|---|---|---|
| `revst_full_allattacks_moderate-xu_frozen_2026-06-12.csv` | `RUST_final_results_v10_freeze.csv` | Ch4/Ch5 + App D aggregate | 13 |
| `revst_full_allattacks_perseed_frozen_2026-06-12.csv` | `RUST_final_results_v10_freeze__per_seed.csv` | App C per-seed / Wilcoxon | 13 × 10 seeds |
| `revst_ch4_minimal-threshold_frozen_2026-06-12.csv` | `RUST_ch4_baseline_comparison.csv` | Ch4 / App D on-off | 7 |
| `conference/revst_conference_camera-ready_6models_frozen_2026-05-21.csv` | `REVST_final_results_freeze_v6_afterfirstHalfAttafixed_corrected_6models.csv` | REVS-T conference (not thesis) | 6 |
| `revs_coldstart_selection_frozen_2025-01.xlsx` | `allResults_Append.xlsx` | Ch 3 REVS cold-start (Dynamic vs Fixed init; scenarios S1–S7) | .xlsx (canonical) |

⚠ The REVS file is the **canonical `.xlsx`**. The RUST/REVS-T/conference files are
**CSV exports** — their canonical `.xlsx` originals should be renamed to the same
basenames and added here. The thesis `.tex` cites the `.xlsx` names — keep them in
lockstep (see `docs/PROVENANCE.md`).

## Integrity check
```bash
cd results_frozen && sha256sum -c SHA256SUMS.txt   # macOS: shasum -a 256 -c
```
