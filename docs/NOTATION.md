# REVS-T: Mathematical Notation Reference

This document clarifies the notation used in the REVS-T system and its relationship to prior work.

## Global Reputation: R_j

**R_j** is the **global on-chain reputation scalar** for provider j.

- **Subscript**: Provider-only (no requester index)
- **Storage**: `SVpro.reputation` in code
- **Scope**: Global, visible to all requesters via blockchain
- **Computation**: R_j = b_j + a0 * u_j (after opinion fusion)

This follows the architectural precedent of **Yang [3]**, which uses a single global reputation per provider rather than per-pair reputations.

## Per-Pair Evidence: alpha_ij, beta_ij, gamma_ij

Evidence triples are maintained **per requester-provider pair**.

- **Notation**: alpha_ij, beta_ij, gamma_ij (subscripts: i=requester, j=provider)
- **Storage**: Always requester-keyed in code:
  ```matlab
  SVpro.Offtransaction.numAlpha.(VreqiID)   % alpha_ij
  SVpro.Offtransaction.numBeta.(VreqiID)    % beta_ij
  SVpro.Offtransaction.numGamma.(VreqiID)   % gamma_ij
  ```
- **Source**: ST-conditioned initialization follows **Xu [8]** Equation 18

### Evidence Initialization (Xu [8] Eq. 18)

| Social Trust | alpha | beta | gamma | Initial R |
|-------------|-------|------|-------|-----------|
| High | 3 | 2 | 1 | 0.583 |
| Intermediate | 2 | 2 | 2 | 0.500 |
| Low | 1 | 2 | 3 | 0.417 |

## Local Subjective Opinion: omega_ij_sub

The **local subjective opinion** from requester i about provider j.

- **Notation**: omega_ij_sub = (b_ij, d_ij, u_ij)
- **Computation**:
  ```
  S_ij = alpha_ij + beta_ij + gamma_ij
  b_ij = alpha_ij / S_ij
  d_ij = beta_ij / S_ij
  u_ij = gamma_ij / S_ij
  ```

## Recommended Opinion: omega_rj_rec

The **IF-weighted recommended opinion** aggregates evidence from other requesters.

- **Notation**: omega_rj_rec = weighted combination of opinions from requesters r != i
- **Weights**: IF (Interaction Factor) based on interaction counts
- **Fusion**: Dempster-Shafer combination with omega_ij_sub

## Important: R_ij Does NOT Exist

**R_ij does NOT exist as a scalar in this system.**

- There is no per-pair reputation scalar stored or computed
- Evidence (alpha_ij, beta_ij, gamma_ij) is per-pair
- Reputation R_j is **global** (provider-only subscript)

This design choice follows Yang [3]: individual opinions aggregate into a single global reputation that governs selection and governance decisions.

## References

- **[3] Yang et al.**: Architectural precedent for global R_j (single reputation per provider)
- **[8] Xu et al.**: Source of ST-conditioned evidence triples (Eq. 18)

## Code Mapping

| Paper Symbol | Code Location |
|--------------|---------------|
| R_j | `SVpro.reputation` |
| alpha_ij | `SVpro.Offtransaction.numAlpha.(VreqiID)` |
| beta_ij | `SVpro.Offtransaction.numBeta.(VreqiID)` |
| gamma_ij | `SVpro.Offtransaction.numGamma.(VreqiID)` |
| omega_ij_sub | Return value of `calculateLocalSubjectiveOpinion3()` |
| omega_rj_rec | Return value of `calculateOpinionMatrix()` |
| R_min | `params.R_min` (0.41) |
| R_warn | `params.R_warn` (0.50) |
| R_boost | `params.R_boost` (0.70) |
| a0 | `params.a0` (0.50) |
