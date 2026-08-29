# archive/ — superseded material (kept, never deleted)

Holds drafts, one-off experiments, debug scripts, and old outputs that are **not
part of the public release** but are retained for history. Move-only: nothing is
deleted; files are relocated here so the release tree stays clean.

## Archived in the Stage-2 reorganisation (2026-08-22)
Moved here with `git mv` (recoverable from history and tag `pre-reorg-2026-08-22`).
None of these feed the frozen thesis results:

| File (now in archive/) | Original location | Why archived |
|---|---|---|
| `calculateReputationRUST2_v3.m` | `myFunctions/` | self-labelled `[DEPRECATED]`, 0 callers |
| `SimulationConfig.m` | repo root | unused; `Params.m` is the real config |
| `sensitivityState.m` | `myFunctions/` | orphan helper for `run_sensitivity_audit` (script not in repo) |
| `mine.m`, `mine2.m` | `+bc/` | proof-of-work mining; never invoked |
| `Workarea.m` | `+bc/` | scratch/demo script, 0 callers |
| `assertBonusRates.m` | `src/support/` | diagnostic guard (checks live DH bonus rates on client+workers); never called in the release pipeline |

## Note on the clean base
The public base (`journal`) was already curated, so the draft/temp/debug material
below lives on other snapshots and is simply not carried into the clean base.

## Deferred archive list (act when each component is integrated)
These files exist on other branches and should be moved here (move-only) if/when
those components are pulled into the public repo:

- **From `preliminary`:** `Copy_of_MainAlgorithm.mlx`, `test.m`, `untitled5.m`
- **From `REVS` (future `src-revs/`):** `myFunctions/SmartContract.asv`, `Test.mlx`, `untitled.mlx`
- **From `REVST` (reference only; not the release base):** `deprecated/`,
  `deprecated/debug_*.m`, `deprecated/old_outputs/debug_traces/`,
  `docs/debug_*example*.txt`, `docs/DEBUGGING_QUICK_REFERENCE.md`

These branches and the freeze tags remain untouched and fully recoverable.
