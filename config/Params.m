function params = Params(newParams)
% PARAMS  Centralized parameters + persistent overrides.
% Usage:
%   p = Params();                 % get current params
%   p = Params(struct(...));      % override fields persistently this session
%
% NOTE: Editing this file or calling CLEAR FUNCTIONS resets the persistent P.

    persistent P

    % === Apply overrides if provided ===
    if nargin == 1 && ~isempty(newParams) && isstruct(newParams)
        if isempty(P), P = localDefaults(); end
        f = fieldnames(newParams);
        for k = 1:numel(f)
            P.(f{k}) = newParams.(f{k});
        end
        params = P;         % return after override
        return;
    end

    % === Initialize defaults once per MATLAB session ===
    if isempty(P)
        P = localDefaults(); 
    end

    params = P;
end

function P = localDefaults()
    P = struct();
    P.resultname="allResults_18_4_S3_2"; 

    % === SortedCanditateVproj thresholds in filterAndSortCandidates  ===
    P.minReputation = 0.41;  % for selection (matches R_min)


    % === Tier thresholds & policy ===
    % Reverted to original defaults (sweep params showed worse governance metrics)
    P.R_min              = 0.41;   % blacklist threshold
    P.R_warn             = 0.50;   % warning tier threshold
    P.R_boost            = 0.70;   % boost tier threshold
    P.rewardBoost        = 0.05;   % boost tier reward increment
    P.penaltyFreezeRuns  = 3;
    P.warnEscalationRuns = 2;
    P.maxFailureStreak = 3;   % 2 = aggressive; 3 = moderate

    % === Selection weights ===
    % Trust_score = w1 * R + w2 * normStayTime
    P.w1 = 0.7;  % Reputation weight
    P.w2 = 0.3;  % Stay-time weight (1 - w1)

    % === Selection penalty for warning-tier providers ===
    % Warning providers (R_min <= R < R_warn) receive this score penalty
    % This allows them to compete, but good-tier providers are preferred
    % Set to 0 to disable penalty (equal competition)
    % Example: w1=0.7, warningPenalty=0.10 means warning provider needs
    %          ~0.14 higher normalized stayTime (with w2=0.3) to win
    P.warningPenalty = 0.10;


    % === Subjective-logic scalarization ===
    P.a0 = 0.50;  % R = b + a0*u

     % === Kang-style recommendation weights ===
     % Reverted to original defaults
     P.theta = 0.4;   % positive weight
     P.tau   = 0.6;   % negative (1 - theta)
     P.zeta  = 0.6;   % recent weight
     P.sigma = 0.4;   % past (1 - zeta)
     P.rho   = 1.0;   % base recommender weight
     P.windowK = 3;   % recent 3 interactions

    % === Honesty thresholds for evidence update ===
    P.H_high_thresh = 0.80;
    P.H_low_thresh  = 0.35;
    P.I_high_thresh = P.H_high_thresh;
    P.I_low_thresh  = P.H_low_thresh;
    P.T_threshold   = 150;   % ms
    P.H_threshold   = 0.50;

    % === Dynamic Honesty Parameters ===
    % Base honesty per ST level (used by calculateHonestyDynamic)
    P.H_base_high   = 0.80;
    P.H_base_interm = 0.60;
    P.H_base_low    = 0.40;
    % Consistency bonus: B_c = min(delta_c * perPairSuccessStreak, Bc_max).
    % delta_c = 0.05 saturates the bonus at a per-pair success streak of 6.
    % Finalized published value (Table: Simulation Parameters).
    P.consistencyBonusPerSuccess    = 0.05;   % delta_c
    P.maxConsistencyBonus           = 0.30;   % Bc_max
    % Experience bonus: B_e = min(delta_e * perPairTotalInteractions, Be_max).
    % delta_e = 0.02 saturates the bonus at 10 per-pair interactions.
    % Finalized published value (Table: Simulation Parameters).
    P.experienceBonusPerInteraction = 0.02;   % delta_e
    P.maxExperienceBonus            = 0.20;   % Be_max
    % Failure penalty (PUBLISHED MODEL: RUST_V2 / computeReputationRUST.m).
    % Asymmetric, ST-conditional: H = H_base - p_fail(ST), with
    % p_fail = {HIGH: 0.50, INT: 0.30, LOW: 0.30}. These are the values
    % reported in the paper and read by the RUST_V2 dynamic-honesty function.
    P.failurePenalty_high   = 0.50;
    P.failurePenalty_interm = 0.30;
    P.failurePenalty_low    = 0.30;
    P.baseFailurePenalty            = P.failurePenalty_interm;   % legacy alias
    % Alternative symmetric-penalty variant: H = H_base - (P_base +
    % min(delta_f * fStreak, F_max)). NOT used in the published results;
    % retained only for the sensitivity-audit scripts.
    P.failurePenalty_base    = 0.30;   % P_base
    P.failureStreakBonus     = 0.05;   % delta_f
    P.failureStreakCap       = 0.20;   % F_max
    % Clamp range
    P.H_clamp_min = 0.05;
    P.H_clamp_max = 0.95;

    % === DEPRECATED: Legacy honesty fields (not read by current code) ===
    % Retained for backward compatibility with old analysis scripts.
    % The active parameters are P.H_base_high/interm/low above.
    P.H_SI_high = 0.80;            % DEPRECATED: use P.H_base_high
    P.H_SI_intermediate = 0.60;    % DEPRECATED: use P.H_base_interm
    P.H_ST_high = 0.90;            % DEPRECATED
    P.H_ST_intermediate = 0.80;    % DEPRECATED
    P.H_ST_low = 0.60;             % DEPRECATED
    P.penalty_high = 0.50;         % DEPRECATED: stale (code uses flat 0.30)
    P.penalty_intermediate = 0.30; % DEPRECATED
    P.penalty_low = 0.30;          % DEPRECATED

    % === Logging (absolute base dir for safety) ===
    P.enableLogging = true;
    P.baseLogDir    = fullfile(pwd, 'logs');              % ABSOLUTE
    if ~exist(P.baseLogDir,'dir'), mkdir(P.baseLogDir); end
    P.logFile       = fullfile(P.baseLogDir, 'reputation_trace.csv');

    % === Malicious Attack Parameters ===
    % Attack types:
    %   'always'    - Attack 100% of the time
    %   'onoff'     - Alternating attack/honest (Malicious 2: [1,0,1,0,...])
    %   'firsthalf' - First half honest, second half attack (Malicious 1: [1,1,...,0,0,...])
    P.attackType = 'always';        % 'always', 'onoff', or 'firsthalf'

    % On-Off attack parameters (Malicious 2)
    P.onOffPeriod = 3;             % For on-off: cycle length
    P.attacksPerPeriod = 1;        % How many attacks per period (integer)
                                   % Example: period=3, attacks=1 → 33% attack rate
                                   % Use integers to avoid floor() rounding bugs!
    P.onOffDuty = 0.33;            % (DEPRECATED) Kept for documentation only
                                   % Actual rate = attacksPerPeriod / onOffPeriod

    % First-half attack parameters (Malicious 1)
    P.totalSimulationPeriod = 1000; % Total simulation period T
                                    % For 'firsthalf': honest [0, T/2), attack [T/2, T]

    % Degradation factors when attacking
    P.maliciousCapacityFactor = 0.5;   % Degradation factor for computation
    P.maliciousTransmissionFactor = 0.7; % Degradation factor for transmission

    % === Diagnostics ===
    P.VERBOSE = false;

    % === Model Comparison Parameters ===
    % Supported models: 'RUST', 'SimpleAvg', 'Beta', 'Threshold', 'Yang', 'YangUniform', 'KangMWSL'
    %
    % Model Comparison Table:
    % ┌─────────────┬───────────┬─────────────┬──────────────┬────────────┬───────────────┐
    % │ Model       │ Evidence  │ ST-Prior    │ Uncertainty  │ Recs       │ Tiers         │
    % ├─────────────┼───────────┼─────────────┼──────────────┼────────────┼───────────────┤
    % │ RUST        │ α,β,γ     │ YES (ST)    │ YES (γ)      │ YES (IF)   │ HYBRID        │
    % │ SimpleAvg   │ counts    │ YES (ST)    │ NO           │ NO         │ Simple        │
    % │ Beta        │ α,β       │ YES (ST)    │ NO           │ NO         │ Simple        │
    % │ Threshold   │ α,β       │ YES (ST)    │ NO           │ YES (IF)   │ Simple        │
    % │ Yang        │ α,β       │ YES (ST)    │ NO           │ YES        │ HYBRID        │
    % │ YangUniform │ α,β       │ NO (uniform)│ NO           │ YES        │ Simple        │
    % │ KangMWSL    │ α,β,γ     │ NO (uniform)│ YES (static) │ YES (IF)   │ Simple        │
    % └─────────────┴───────────┴─────────────┴──────────────┴────────────┴───────────────┘
    %
    % Key Comparisons to Highlight RUST Benefits:
    %   RUST vs YangUniform: Shows ST-based cold-start handling advantage
    %   RUST vs KangMWSL:    Shows tiered governance + VCOff-specific adaptations
    %   RUST vs Yang:        Shows uncertainty (γ) contribution
    %   RUST vs Beta:        Shows recommendations + uncertainty + tiers
    %
    P.defaultModel = 'RUST_V2';

    % === Recommendation Settings ===
    % Set to false for fair comparison (SimpleAvg and Beta don't use recommendations)
    P.useRecommendations = true;  % true = enable, false = disable for all models
    P.useDynamicHonesty = true;   % true = DH routing, false = binary (success→α++, failure→β++)
    % Post-blackout shadow: when true, providers with totalBlacklists>0
    % are demoted to the Warning-tier fallback group in StrictTier
    % selection regardless of their R. They remain selectable via the
    % fallback rule only, never via the Good-tier preference round.
    % Default false (preserves current baseline behavior). Tested in
    % run_smoke_shadow.m as an opt-in mitigation for malicious re-
    % selection after the blackout cooldown elapses.
    P.useBlacklistShadow = false;
    % Streak penalty inside the Good tier: when true, the StrictTier
    % score is reduced by streakPenaltyWeight * warningStreak for each
    % candidate, so providers with recent failures lose priority within
    % the Good tier without being excluded. Default off (preserves
    % current ranking). Softer than useBlacklistShadow because it does
    % not demote providers across tiers; it only tie-breaks within tier.
    P.useStreakPenalty       = false;
    P.streakPenaltyWeight    = 0.05;   % score units per warningStreak unit
    % Opt-in switch to the refactored selection trio:
    %   fetchVehicles2_clean + classifyTiersVproj + selectVproj
    % Replaces the legacy fetchCandidatePool + filterAndSortCandidates +
    % selectProviderTierAware path inside SmartContract.m STRICTTIER.
    % Default false to preserve published v7 numbers. Equivalence is
    % asserted by tests/smoke_selection_refactor.m (diffs CSVs from
    % old vs new pipeline over a small grid; expects |Delta| < 1e-3 on
    % SR, MAR, Avail, TPR_gov, FPR_gov).
    P.useNewSelectionTrio    = false;
    % Ablation A: tier classification by isWarning flag instead of by
    % R > R_warn. Requires useNewSelectionTrio = true (the new trio is
    % the only consumer of classifyTiersVproj). When useIsWarningTier
    % is true, SmartContract.m calls classifyTiersVproj_isWarning,
    % which derives Good vs Warning from the governance-set isWarning
    % flag (carries warningStreak history) rather than the
    % instantaneous R > R_warn test.
    P.useIsWarningTier       = false;
    % Static-expectation evidence routing: ST-conditional alpha/beta/gamma
    % mapping instead of Dynamic Honesty bonus-based H. Off by default.
    % When true: HIGH success -> alpha, INT/LOW success -> gamma, HIGH
    % first-failure-w/prior-success -> grace gamma, INT failure -> gamma
    % (symmetric uncertainty), LOW/HIGH non-grace failure -> beta.
    P.useStaticExpectation   = false;
    % Extended grace: remove the isHighST restriction from the grace
    % 5-gate so first-failure-w/prior-success forgiveness applies to
    % all ST levels, not just HIGH. The other four gate conditions
    % (failure, isFirstFailure, hasPriorSuccess, notAlreadyGoverned)
    % stay in place — the hasPriorSuccess check is what prevents
    % attackers from exploiting the forgiveness.
    P.useExtendedGrace       = false;

    % Beta Reputation System (Model 2) parameters
    P.betaUniformPrior = true;  % Start with α=1, β=1 (uniform prior)

    % Simple Averaging (Model 1) parameters
    P.simpleAvgDecay = 1.0;     % No decay (set <1 for recency weighting)

    % Threshold-Only (Model 4) parameters
    % Uses same R_min threshold but no warning/boost tiers
    P.thresholdOnlyMode = false;  % Set true to disable tiers in RUST

    % === Simulation Fairness Settings ===
    % Subset sampling options
    P.fixedSubsetSize = 0;        % 0 = random [min,max], >0 = fixed size
    P.exactMaliciousRatio = true; % true = enforce exact ratio in subset

    % Recommendation limits
    P.maxRecommenders = Inf;      % No limit - use all available recommenders

    % === Malicious Assignment Configuration ===
    % Controls how malicious providers are distributed across ST levels
    %
    % Options:
    %   'xu_aligned'       - Xu et al.: malicious→ST_low, honest→ST_high (no intermediate)
    %   'rust_distributed' - RUST: malicious weighted toward low (10/30/60 for H/I/L)
    %   'moderate'         - Less extreme (5/15/80 for malicious)
    %   'uniform_random'   - No correlation between malicious and ST (ablation)
    %   'adversarial'      - Malicious weighted toward ST_high (worst case)
    %
    % Use assignMaliciousConfigurable(Vproj, pct, VreqPool, P.assignmentConfig)
    P.assignmentConfig = 'xu_aligned';  % Default for baseline comparison

    % === Xu et al. Evidence Space Initialization (Eq. 18) ===
    % Social Trust based Subjective Logic Initialization
    % Reference: Xu et al. "Reputation-Based..."
    %
    % ST_high:         {α=3, β=2, γ=1} → favors belief     (R₀ ≈ 0.583)
    % ST_intermediate: {α=2, β=2, γ=2} → neutral           (R₀ = 0.500)
    % ST_low:          {α=1, β=2, γ=3} → favors distrust   (R₀ ≈ 0.417)
    %
    % Key insight: Malicious 1 & 2 → ST_low, Normal → ST_high

    % === ST-based Evidence Initialization ===
    % RUST dynamic priors = Xu et al. Eq. 18 (IDENTICAL values)
    % Both systems use the same ST-based initial evidence:
    %   high:         {α=3, β=2, γ=1} → R₀=0.583
    %   intermediate: {α=2, β=2, γ=2} → R₀=0.500
    %   low:          {α=1, β=2, γ=3} → R₀=0.417
    P.stInit = struct();
    P.stInit.high = struct('alpha', 3, 'beta', 2, 'gamma', 1);
    P.stInit.intermediate = struct('alpha', 2, 'beta', 2, 'gamma', 2);
    P.stInit.low = struct('alpha', 1, 'beta', 2, 'gamma', 3);

    % === Provider Heterogeneity ===
    P.heterogeneousProviders = false;  % true = variable capacity/transmission
    P.minComputationCapacity = 5e9;    % 5 GHz minimum
    P.maxComputationCapacity = 15e9;   % 15 GHz maximum
    P.minTransmissionRate = 50e6;      % 50 Mbps minimum
    P.maxTransmissionRate = 120e6;     % 120 Mbps maximum
end


   % % === Kang-style recommendation weights ===
    % P.zeta  = 0.60;                 % recent
    % P.sigma = 1 - P.zeta;           % past
    % P.theta = 0.30;                 % success weight
    % P.tau   = 1 - P.theta;          % failure weight
    % P.rho   = 0.50;                 % IF fusion weight
    % 
    % % Recency window 
    % P.windowK = 3;
   % P.capIF   = 3;