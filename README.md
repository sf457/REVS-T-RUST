# REVS-T with RUST — Trust Framework for Vehicular Computation Offloading

MATLAB reference implementation of the integrated trust framework presented in
the thesis *"<thesis title — replace>"*. The framework combines:

- **REVS** — ST-levels based, credential-aware provider initialisation and selection.
- **RUST** — a Reputation and Uncertainty-aware Subjective-logic update mechanism
  with behaviour-aware (Dynamic Honesty) three-valued evidence routing.
- **REVS-T** — tier-aware provider selection and four-tier progressive governance
  (boost / stable / warning / blacklist) layered on the RUST reputation engine.

The complete framework is referred to as **REVS-T with RUST**.

> Simulation **code only**. Bulk trial outputs (`.mat`/`.csv`) and generated figures
> are reproduced by running the scripts below. The frozen result sets behind the thesis
> numbers live in `results_frozen/` (see *Data availability*).

## Naming convention (code ↔ publication)

| Code label   | Publication name | Meaning                                   |
|--------------|------------------|-------------------------------------------|
| `RUST_V2`    | RUST / REVS-T    | Full integrated framework                 |
| `RUST_NoRec` | REVS-T-NoRec     | No recommendation aggregation (ablation)  |
| `RUST_Uniform`| REVS-T-Uniform  | Uniform prior, no ST-levels init (ablation)|
| `RUST_NoTier`| REVS-NoTierSel   | No tier-aware selection (ablation)         |
| `Threshold`  | Threshold        | Subjective-logic opinion, single threshold |
| `Iqbal`      | ScalarRep-EMA    | Scalar EMA reputation baseline             |
| `Iqbal2`     | ScalarRep-CumReward | Cumulative-reward scalar baseline       |

Model-label strings above match the columns in the frozen result workbooks — do not
rename them.

## Repository layout

```
run_baseline_comparison.m     Main entry point (all models, attacks, seeds).
generate_thesis_*.m           Figure generators for the thesis chapters (4 files).
setup_paths.m                 Puts all source folders on the MATLAB path.
config/
  Params.m                    Centralised parameters (thresholds, weights, priors).
src/
  reputation/                 RUST engine + baseline reputation models.
  selection/                  Provider selection, tier classification, candidate pool.
  contracts/                  RSU smart-contract dispatch (SmartContract*.m).
  simulation/                 Sim orchestration, vehicle/task pools, V2V offloading.
  support/                    Fingerprinting, metrics, diagnostics, logging helpers.
+bc/                          Consortium-ledger emulation (vBlockchain, Block).
thirdparty/
  secp256k1-.../              BSD key-generation utility (David Hill, 2019).
results_frozen/               Frozen result sets behind the thesis (SHA-256 checked).
docs/                         Provenance, notation, workflow notes.
archive/                      Superseded/experimental material (not part of results).
```

## Requirements

Tested with MATLAB **R2024b** (the version stated for the final thesis results).

- **Parallel Computing Toolbox** — required for `parfor` in the runner
  (serial fallback: replace `parfor` with `for`).
- **Statistics and Machine Learning Toolbox** — only for the `signrank` / Wilcoxon
  significance analysis (Chapter 5).
- No other paid toolbox is required for the core simulation.

## Quick start

```matlab
setup_paths            % add config/, src/**, +bc/, thirdparty/ to the path
run_baseline_comparison  % all models, attacks, seeds -> results/<timestamp>/
```

`setup_paths` works from any current directory. Run it once per session before the
runner or any `generate_thesis_*` figure script.

The runner sweeps each model over malicious penetration, attack type
(`always` / `onoff` / `firsthalf`), and random seeds, executing 1,000 offloading
events per configuration. Outputs are written under `results/` (git-ignored).

## Pipeline

```
run_baseline_comparison.m
  ├── setup_paths()                         % path setup
  ├── Params()                              % configuration (config/Params.m)
  ├── initializeVehiclePools()             % requester + provider pools
  └── for each (model, malicious%, attack, seed):
        for runIndex = 1:1000:
            fetchCandidatePool()            % feasible candidates (src/selection)
            SmartContract*()                % selection dispatch (src/contracts)
              └── selectProviderTierAware() % tier-aware selection
            V2VOffloading()                 % offloading outcome (src/simulation)
            computeReputationRUST()         % RUST reputation + governance (src/reputation)
```

## Reproduction — thesis results and figures

All reported numbers come from the frozen workbooks in `results_frozen/`
(see `docs/PROVENANCE.md`). Re-running regenerates equivalent results; the frozen
files remain canonical.

| Thesis item | Backing frozen file | Regenerate with |
|---|---|---|
| Ch 3 REVS (cold-start, 7 ST scenarios) | `revs_coldstart_selection_frozen_2025-01.xlsx` | REVS component (separate) |
| Ch 4 minimal single-threshold (7 models) | `revst_ch4_minimal-threshold_frozen_2026-06-12.csv` | `run_baseline_comparison` |
| Ch 4 / Ch 5 aggregate (13 models, all attacks) | `revst_full_allattacks_moderate-xu_frozen_2026-06-12.csv` | `run_baseline_comparison` |
| Ch 5 per-seed / Wilcoxon (13×10 seeds) | `revst_full_allattacks_perseed_frozen_2026-06-12.csv` | `run_baseline_comparison` |
| REVS-T conference (6 models) | `results_frozen/conference/revst_conference_camera-ready_6models_frozen_2026-05-21.csv` | conference config |

Figures:

```matlab
setup_paths
generate_thesis_result_charts        % SR/MAR bars, ablation chain, phase-shift
generate_thesis_chapter_figures      % trajectories, per-ST convergence
generate_thesis_cumulative_malsel    % cumulative malicious selections
generate_thesis_phaseshift_traces    % reputation traces under phase shift
```

Headline cross-check (frozen aggregate, moderate / persistent / 50% malicious, model `RUST`):
**SR 92.79% · MAR 96.74%** — matches thesis Appendix D.

Integrity check for the frozen set:

```bash
cd results_frozen && sha256sum -c SHA256SUMS.txt     # macOS: shasum -a 256 -c
```

## Data availability

The frozen result sets are in `results_frozen/` with SHA-256 checksums documented in
[`docs/PROVENANCE.md`](docs/PROVENANCE.md). A public data-release decision (in-repo,
Git LFS, or derived CSV summaries) is deferred pending supervisor approval.

## Third-party code

`thirdparty/secp256k1-elliptic-curve-shared-key-generation-gui-1.0.0/` is by David Hill
(2019), redistributed under the 3-clause BSD license retained in its `license.txt`.
It is used only for vehicle key-pair generation.

The `+bc/` package (consortium-ledger helpers) is **adapted from** Aarenstrup's MATLAB
Blockchain Example. The ledger is an **emulation** used to record and audit trust state
for the experiments; it does not perform real mining, consensus, block propagation, or
ledger replication.

## License

Released under the MIT License — see [`LICENSE`](LICENSE).

## Citation

See [`CITATION.cff`](CITATION.cff), or cite the thesis directly:

```bibtex
@phdthesis{<key>,
  title  = {<thesis title>},
  author = {<author>},
  school = {<institution>},
  year   = {2026}
}
```
