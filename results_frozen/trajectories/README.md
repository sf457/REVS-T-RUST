# results_frozen/trajectories/ — trajectory records for illustrative figures

Per-scenario reputation-trajectory records backing the single-seed illustrative
figures of Chapter 5 (phase-shift adaptation traces, cumulative malicious-selection
curves, per-social-trust-class reputation evolution). Same **2026-06-05_23-23**
evaluation run that produced the frozen result workbooks, so figures and tables
share one provenance.

Subset committed here (moderate assignment, 50% malicious — the cells the figures use):
- `trustEvolution_<model>_moderate_firsthalf_mal50.mat` — all 13 models (phase-shift figures)
- `trustEvolution_RUST_V2_moderate_always_mal50.mat` — per-ST persistent evolution

Integrity: `cd results_frozen/trajectories && sha256sum -c SHA256SUMS.txt`.

STATUS: **released publicly under the MIT license** (same as the parent `results_frozen/`).
These records back the illustrative figures only; all reported numbers come from the
frozen workbooks in `results_frozen/`.
