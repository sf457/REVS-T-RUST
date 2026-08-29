# revs-coldstart/ — REVS cold-start selection (Thesis Ch 3 / VTC conference)

Self-contained MATLAB code for the **REVS** cold-start provider-selection study:
credential-aware, ST-levels **Dynamic** reputation initialisation versus a
**Fixed** flat initialisation, evaluated as the malicious-provider fraction rises.
This is the Chapter 3 component of *REVS-T with RUST*; it runs independently of the
RUST/REVS-T code in the repository root.

> Self-contained on purpose. This folder ships its **own** `+bc/` package and
> `myFunctions/`, which differ from the RUST versions at the repo root. Do not
> mix the two. The only shared dependency is `thirdparty/secp256k1-*` at the repo
> root (key generation).

## Requirements

- **MATLAB R2024b** — `MainAlgorithm.mlx` was authored in R2024b and the `.mlx`
  (Live Script) format requires that release (or newer) to open.
- **Parallel Computing Toolbox** — `MainAlgorithm.mlx` uses `parfor` over the
  malicious-percentage sweep (serial fallback: replace `parfor` with `for`).

## Entry point

`MainAlgorithm.mlx` — the cold-start experiment. Default configuration:

| Setting | Value |
|---|---|
| `numSimulations` | 1000 offloading events per point |
| `maliciousPercentages` | `[0.1 0.2 0.3 0.4 0.5]` |
| `fixedReputationValue` | 0.6 (the Fixed-init baseline) |
| Seeding | per-simulation `rng(sim)` |
| Compared | **Dynamic** (ST-levels credential-aware init) vs **Fixed** (flat 0.6) |

Metrics recorded per malicious %: Success Rate, Avg Initial Reputation, Avg
Updated Reputation, Avg isMalicious (→ Malicious Avoidance Rate = 1 − isMalicious),
Avg Latency.

## Quick start

```matlab
cd revs-coldstart
setup_paths_revs        % adds this folder, myFunctions/, +bc parent, thirdparty/secp256k1
open MainAlgorithm.mlx  % then Run
```

Outputs are written next to the script as `simulation_results_*.mat` and
`allResults_*.csv`, plus the comparison figures.

## Reproducing the frozen result set

The frozen workbook behind the thesis Ch 3 numbers is
`results_frozen/revs_coldstart_selection_frozen_2025-01.xlsx` (**PRIVATE** — see
`results_frozen/README.md`). It is **not the output of a single run**: it is an
**assembly of several scenario / weighting configurations** (the historical
`allResults_1`, `_1_2`, `_1_3`, `_1_4`, `_1_4_4`, `_4_randomAssign`, `_5`, `_6`
sheets). To regenerate an equivalent set, run `MainAlgorithm.mlx` once per
scenario/weight configuration and append the per-run CSVs into one workbook.

As with the RUST code, re-running yields results **statistically equivalent** to
the frozen workbook; the frozen file remains canonical. Exact reproduction uses
the frozen snapshot (branch `REVS`, tag `revs-vtc-2025-freeze`).

## Call graph (verified)

```
MainAlgorithm.mlx
└─ runSimulations (nested)
   ├─ assignMaliciousBehaviorDynamic · assignMaliciousVehiclesFixed
   ├─ runsimulation.m
   │   ├─ createVreq · generateTaskReq · generateVproj2
   │   ├─ AddtoVehicularBlockChain · calculateReputation2
   │   └─ SmartContract.m
   │       └─ fetchVehicles · SortVproj · SelectedVproj · SelectedVprojRandom · V2VOffloading3
   ├─ SmartContract · calculateReputation2 · AddtoVehicularBlockChain
```

`createVreq` / `generateVproj2` call `secp256k1` (repo-root `thirdparty/`).

## Provenance & files not carried over

Source of record: branch **`REVS`** (commit `029e80e`), freeze tag
**`revs-vtc-2025-freeze`**. Only the verified-active files are included here.
The following REVS-branch files were **deliberately not carried over** (dead /
scratch / duplicates); they remain fully recoverable on the `REVS` branch and the
freeze tag:

- `myFunctions/generateVproj3.m` — superseded by `generateVproj2`, 0 callers
- `myFunctions/SmartContract.asv` — MATLAB autosave scratch
- root `V2VOffloading3.m` — byte-identical duplicate of `myFunctions/V2VOffloading3.m`
- `Test.mlx`, `untitled.mlx` — scratch live scripts
- `+bc/mine.m`, `+bc/mine2.m`, `+bc/Workarea.m` — proof-of-work mining / scratch,
  referenced only in `% FIXME` comments (never invoked)

## Blockchain note

`+bc/` is an **emulated** consortium ledger (adapted from Aarenstrup's MATLAB
Blockchain Example): it records and audits trust state for the experiments and
does **not** perform real mining, consensus, propagation, or replication —
consistent with the RUST code's ledger.
