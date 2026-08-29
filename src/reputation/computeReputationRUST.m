function [updatedReputation, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
    computeReputationRUST(SVpro, runIndex, Updated_Vreqi, blockchainObj, maliciousPercentage, scenarioName)
% CALCULATEREPUTATIONRUST2_V2
% RUST v2 = Dynamic Honesty + Single-threshold Evidence Updates
%
% Key differences from v1:
%   - Dynamic H: grows with consistent successful behavior
%   - Single thresholds (0.80/0.35) for ALL ST levels
%   - HIGH-ST grace for first failure only
%   - Streak-based consistency bonuses
%
% Inputs:
%   SVpro          : selected provider struct
%   runIndex       : current simulation index
%   Updated_Vreqi  : requester struct
%   blockchainObj  : blockchain object (SINGLE SOURCE OF TRUTH)
%
% Outputs:
%   updatedReputation : scalar R = b + a0*u after fusion (+ tier policy)
%   isActive, isWarning, warningStreak, blackoutCounter, SVpro

    % =========================
    % 1) Centralized parameters
    % =========================
    params  = Params();
    VERBOSE = params.VERBOSE;

    % =========================
    % 2) Basic extraction
    % =========================
    VreqiID       = Updated_Vreqi.PID;
    Vreqi_Offtx   = Updated_Vreqi.Offtransaction;

    SVproID       = SVpro.PID;
    SVpro_Offtx   = SVpro.Offtransaction;
    SVpro_STLevel = SVpro.socialTrustLevel;
    current_R     = SVpro.reputation;
    isMalicious   = SVpro.isMalicious;

    % Expect the current transaction to be attached already
    TX      = SVpro_Offtx.TransactionsID;
    tAll    = TX.totalOffloadingLatency;
    MaxT    = TX.maximumTime;
    success = double(TX.offloadingSuccessstatus);

    if VERBOSE
        fprintf('\n[Run %d][v2] Update rep for %s (req=%s)\n', runIndex, SVproID, VreqiID);
    end

    % =========================
    % 3) STEP 1: Local subjective opinion
    % =========================
    alpha = SVpro_Offtx.numAlpha.(VreqiID);
    beta  = SVpro_Offtx.numBeta.(VreqiID);
    gamma = SVpro_Offtx.numGamma.(VreqiID);

    if VERBOSE
        fprintf('[%s<- %s] α=%g, β=%g, γ=%g (local)\n', SVproID, VreqiID, alpha, beta, gamma);
    end

    isFirst = (SVpro_Offtx.numTransactions.(VreqiID) == 1);
    isFirstFailure = (SVpro_Offtx.numFailed.(VreqiID) == 1);

    % Calculate if provider has prior successful interactions with this requester
    % Grace requires proven track record - prevents malicious from exploiting grace on first failure
    numSuccess = SVpro_Offtx.numSuccess.(VreqiID);
    hasPriorSuccess = numSuccess > 0;  % At least one success before this interaction

    % Get current governance state (from previous interaction)
    currentIsWarning = SVpro.isWarning;
    currentIsActive = SVpro.isActive;
    currentBlackoutCounter = SVpro.blackoutCounter;

    % Get PER-PAIR streak info (per requester-provider pair, keyed by VreqiID)
    if ~isfield(SVpro, 'localSuccessStreak') || ~isstruct(SVpro.localSuccessStreak)
        SVpro.localSuccessStreak = struct();
    end
    if ~isfield(SVpro, 'localTotalInteractions') || ~isstruct(SVpro.localTotalInteractions)
        SVpro.localTotalInteractions = struct();
    end
    % Ensure numeric
    if isfield(SVpro.localSuccessStreak, VreqiID) && isnumeric(SVpro.localSuccessStreak.(VreqiID))
        successStreak = double(SVpro.localSuccessStreak.(VreqiID));
    else
        successStreak = 0;
    end
    if isfield(SVpro.localTotalInteractions, VreqiID) && isnumeric(SVpro.localTotalInteractions.(VreqiID))
        totalInteractions = double(SVpro.localTotalInteractions.(VreqiID));
    else
        totalInteractions = 0;
    end

    % Call embedded subjective opinion function (v2 with dynamic H)
    [subjectiveOpinion, alphaNew, betaNew, gammaNew, localMetrics] = ...
        calculateLocalSubjectiveOpinion3(alpha, beta, gamma, ...
            SVpro_STLevel, success, params, isFirst, isFirstFailure, ...
            successStreak, totalInteractions, hasPriorSuccess, ...
            currentIsWarning, currentIsActive, currentBlackoutCounter);

    b_subj = subjectiveOpinion(1);
    d_subj = subjectiveOpinion(2);
    u_subj = subjectiveOpinion(3);

    if VERBOSE
        disp('subjectiveOpinion = [b d u]'); disp(subjectiveOpinion.');
        fprintf('α_new=%g, β_new=%g, γ_new=%g\n', alphaNew, betaNew, gammaNew);
    end

    % --- increments from this interaction ---
    da = alphaNew - alpha;
    db = betaNew  - beta;
    dg = gammaNew - gamma;

    % Update PER-PAIR streak counter (keyed by VreqiID)
    if success
        SVpro.localSuccessStreak.(VreqiID) = successStreak + 1;
    else
        SVpro.localSuccessStreak.(VreqiID) = 0;
    end
    SVpro.localTotalInteractions.(VreqiID) = totalInteractions + 1;

    % Persist α/β/γ per requester
    SVpro.Offtransaction.numAlpha.(VreqiID) = alphaNew;
    SVpro.Offtransaction.numBeta.(VreqiID)  = betaNew;
    SVpro.Offtransaction.numGamma.(VreqiID) = gammaNew;

    % =========================
    % 4) STEP 2: Kang-style recommended opinion
    % =========================
    recommendedOpinion = [];
    recStats = struct('numHistoryEntries', 0, 'numAllVreqIDs', 0, ...
                      'numOtherRequesters', 0, 'numRecommenders', 0, ...
                      'IF_mean', NaN, 'IF_std', NaN, 'IF_max', NaN);

    if params.useRecommendations
        [recommendedOpinion, recStats] = calculateOpinionMatrix( ...
            VreqiID, SVpro, SVproID, Vreqi_Offtx, runIndex, params, blockchainObj);

        if VERBOSE
            if isempty(recommendedOpinion)
                disp('recommendedOpinion = [] (subj)');
            else
                disp('recommendedOpinion = [b d u]'); disp(recommendedOpinion);
            end
        end
    elseif VERBOSE
        fprintf('[RUST] Recommendations DISABLED\n');
    end

    % =========================
    % Store recommendation statistics
    % =========================
    R_subjective = b_subj + params.a0 * u_subj;

    SVpro.lastRecStats = struct( ...
        'recommendationsEnabled', params.useRecommendations, ...
        'recommendationsUsed', ~isempty(recommendedOpinion), ...
        'numRecommenders', recStats.numRecommenders, ...
        'numOtherRequesters', recStats.numOtherRequesters, ...
        'IF_mean', recStats.IF_mean, ...
        'IF_std', recStats.IF_std, ...
        'IF_max', recStats.IF_max, ...
        'R_subjective', R_subjective ...
    );

    % =========================
    % 5) STEP 3/4: Fuse subjective (+ recommended) → R
    % =========================
    if ~isempty(recommendedOpinion)
        fusedOpinion = combineOpinions(subjectiveOpinion, recommendedOpinion(:));
        b_final = fusedOpinion(1);
        u_final = fusedOpinion(3);
        if VERBOSE
            fprintf('R(%s) fused subj+rec pre-tier = %.4f\n', ...
                SVproID, b_final + params.a0*u_final);
        end
    else
        b_final = b_subj;
        u_final = u_subj;
    end

    R_preTier = b_final + params.a0 * u_final;

    % =========================
    % Option A: aggregate recommendation impact per provider
    % =========================
    % Track running sums so the trajectory schema can expose per-provider
    % mean rec lift without enabling full per-call trace logging.
    %   rec_calls    : number of times the rep function was invoked
    %   rec_sum_subj : sum of R_subjective values
    %   rec_sum_full : sum of R_fused values (R_preTier)
    %   rec_sum_lift : sum of (R_fused - R_subjective)  (signed)
    %   rec_sum_absl : sum of |R_fused - R_subjective|  (magnitude)
    if ~isfield(SVpro, 'rec_calls') || isempty(SVpro.rec_calls) || isstruct(SVpro.rec_calls)
        SVpro.rec_calls = 0;
        SVpro.rec_sum_subj = 0;
        SVpro.rec_sum_full = 0;
        SVpro.rec_sum_lift = 0;
        SVpro.rec_sum_absl = 0;
    end
    SVpro.rec_calls     = SVpro.rec_calls + 1;
    SVpro.rec_sum_subj  = SVpro.rec_sum_subj + R_subjective;
    SVpro.rec_sum_full  = SVpro.rec_sum_full + R_preTier;
    SVpro.rec_sum_lift  = SVpro.rec_sum_lift + (R_preTier - R_subjective);
    SVpro.rec_sum_absl  = SVpro.rec_sum_absl + abs(R_preTier - R_subjective);

    if VERBOSE
        fprintf("ENTER TIER %s: active=%d warning=%d blackout=%d R=%.3f\n", ...
            SVpro.PID, SVpro.isActive, SVpro.isWarning, SVpro.blackoutCounter, R_preTier);
    end

    % =========================
    % 6) HYBRID Tier Policy with PROGRESSIVE BLACKOUT
    % =========================
    R = R_preTier;
    isFailure = (success == 0);
    tierAction = "stable";

    % ---- PROGRESSIVE BLACKLIST PARAMETERS ----
    maxStrikes = 3;           % Permanent after 3 blacklists
    baseBlackoutRuns = 3;     % Base blackout duration

    % ---- CHECK FOR PERMANENT BLACKLIST (early exit) ----
    % Defensive: ensure isPermanentlyBlacklisted is initialized and is a scalar logical
    if ~isfield(SVpro, 'isPermanentlyBlacklisted') || ~islogical(SVpro.isPermanentlyBlacklisted) || ~isscalar(SVpro.isPermanentlyBlacklisted)
        SVpro.isPermanentlyBlacklisted = false;
    end
    if SVpro.isPermanentlyBlacklisted
        SVpro.isActive = false;
        SVpro.isWarning = false;        % permanent ban supersedes all flags
        SVpro.blackoutCounter = Inf;    % truly permanent (was 9999 magic — let decrementBlackoutCounters skip via isinf check)
        tierAction = "permanent_blacklist";
        % Skip all other tier logic
    else
        % ---- (A) Always track warning streak ----
        if isFailure
            SVpro.warningStreak = SVpro.warningStreak + 1;
        else
            SVpro.warningStreak = max(0, SVpro.warningStreak - 0.5);
        end

        % ---- (B) Determine escalation threshold based on R ----
        if R >= params.R_boost
            escThreshold = params.warnEscalationRuns + 2;
        elseif R >= params.R_warn
            escThreshold = params.warnEscalationRuns + 1;
        else
            escThreshold = params.warnEscalationRuns;
        end

        % ---- (C) Check streak escalation ----
        if SVpro.warningStreak >= escThreshold
            SVpro.isActive = false;
            SVpro.isWarning = false;       % blackout supersedes warning (consistent with lowR+fail path)
            SVpro.warningStreak = 0;
            SVpro.totalBlacklists = SVpro.totalBlacklists + 1;
            tierAction = "streak->blacklist";

        % ---- (D) R-based tiers ----
        elseif R < params.R_min
            if isFailure
                SVpro.isActive = false;
                SVpro.isWarning = false;
                SVpro.warningStreak = 0;
                SVpro.totalBlacklists = SVpro.totalBlacklists + 1;
                tierAction = "lowR+fail->blacklist";
            else
                SVpro.isActive = true;
                SVpro.isWarning = true;
                tierAction = "lowR-success-warning";
            end

        elseif R <= params.R_warn
            SVpro.isActive = true;
            SVpro.isWarning = true;
            tierAction = "warning";

        elseif R >= params.R_boost
            SVpro.isActive = true;
            SVpro.isWarning = false;
            if ~isFailure
                R = min(R + params.rewardBoost, 1);
                tierAction = "boosted";
            else
                tierAction = "high-no-boost";
            end

        else
            SVpro.isActive = true;
            SVpro.isWarning = false;
            tierAction = "stable";
        end

        % ---- PROGRESSIVE BLACKOUT WITH PERMANENT BAN ----
        if contains(tierAction, "blacklist") && ~contains(tierAction, "permanent")
            if SVpro.totalBlacklists >= maxStrikes
                % PERMANENT BLACKLIST after maxStrikes
                SVpro.blackoutCounter = Inf;   % truly permanent — let isinf check in decrementBlackoutCounters short-circuit
                SVpro.isActive = false;
                SVpro.isWarning = false;       % permanent ban supersedes all flags
                SVpro.isPermanentlyBlacklisted = true;
                tierAction = "permanent_blacklist";
            else
                % PROGRESSIVE BLACKOUT (doubles each time)
                % Strike 1: 3 runs, Strike 2: 6 runs, Strike 3+: permanent ban
                SVpro.blackoutCounter = baseBlackoutRuns * (2 ^ (SVpro.totalBlacklists - 1));
            end
        end
    end

    % =========================
    % 7) STEP 6: Outputs
    % =========================
    updatedReputation = min(max(R, 0), 1);
    SVpro.reputation  = updatedReputation;

    isActive        = SVpro.isActive;
    isWarning       = SVpro.isWarning;
    warningStreak   = SVpro.warningStreak;
    blackoutCounter = SVpro.blackoutCounter;

    if VERBOSE
        fprintf('[Debug] %s streak=%d, active=%d, rep=%.3f, blackout=%d\n', ...
            SVproID, warningStreak, isActive, updatedReputation, blackoutCounter);
    end

    % =========================
    % 8) Logging
    % =========================
    if params.enableLogging
        row = struct();

        row.timestamp     = string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
        row.runIndex      = runIndex;
        row.globalRatio   = double(maliciousPercentage);
        row.scenarioName  = string(scenarioName);
        row.VreqiID       = string(VreqiID);
        row.SVproID       = string(SVproID);

        row.socialTrustLevel = string(SVpro_STLevel);
        row.isMalicious      = double(isMalicious);
        row.current_R        = double(current_R);
        row.success          = double(success);
        row.tAll             = double(tAll);
        row.MaxT             = double(MaxT);

        row.Honest_ij = double(localMetrics.H);
        row.I_ij      = double(localMetrics.I);

        row.alpha_before = double(alpha);
        row.beta_before  = double(beta);
        row.gamma_before = double(gamma);

        row.alpha_inc   = double(da);
        row.beta_inc    = double(db);
        row.gamma_inc   = double(dg);

        row.alpha_after = double(alphaNew);
        row.beta_after  = double(betaNew);
        row.gamma_after = double(gammaNew);

        row.subj_b = double(b_subj);
        row.subj_d = double(d_subj);
        row.subj_u = double(u_subj);

        if isempty(recommendedOpinion)
            row.rec_b = NaN; row.rec_d = NaN; row.rec_u = NaN;
        else
            row.rec_b = double(recommendedOpinion(1));
            row.rec_d = double(recommendedOpinion(2));
            row.rec_u = double(recommendedOpinion(3));
        end

        if exist('recStats','var') && ~isempty(recStats)
            row.numHistoryEntries = double(recStats.numHistoryEntries);
            row.numOtherRequesters= double(recStats.numOtherRequesters);
            row.numAllVreqIDs     = double(recStats.numAllVreqIDs);
            row.numRecommenders   = double(recStats.numRecommenders);
            row.IF_mean           = double(recStats.IF_mean);
            row.IF_std            = double(recStats.IF_std);
            row.IF_max            = double(recStats.IF_max);
        else
            row.numHistoryEntries = NaN;
            row.numOtherRequesters= NaN;
            row.numAllVreqIDs     = NaN;
            row.numRecommenders   = 0;
            row.IF_mean           = NaN;
            row.IF_std            = NaN;
            row.IF_max            = NaN;
        end

        row.R_min   = params.R_min;    row.R_warn = params.R_warn;   row.R_boost = params.R_boost;
        row.rewardBoost       = params.rewardBoost;
        row.penaltyFreezeRuns = params.penaltyFreezeRuns;
        row.warnEscalationRuns= params.warnEscalationRuns;
        row.a0      = params.a0;

        row.zeta    = params.zeta;     row.sigma = params.sigma;
        row.theta   = params.theta;    row.tau   = params.tau;
        row.rho     = params.rho;
        row.windowK = params.windowK;

        row.H_threshold   = localMetrics.I_high_thresh;
        row.I_high_thresh = localMetrics.I_high_thresh;
        row.I_low_thresh  = 0.35;

        row.R_preTier      = double(R_preTier);
        row.R_postTier     = double(updatedReputation);
        row.tierAction     = string(tierAction);
        row.isActive       = double(isActive);
        row.isWarning      = double(isWarning);
        row.warningStreak  = double(warningStreak);
        row.blackoutCounter= double(blackoutCounter);
        if isfield(SVpro,'totalBlacklists')
            row.totalBlacklists = double(SVpro.totalBlacklists);
        else
            row.totalBlacklists = 0;
        end

        writeReputationTrace(params.logFile, row);
    end
end

%% ====================================================================
%% EMBEDDED: calculateLocalSubjectiveOpinion3 with Dynamic H
%% ====================================================================
function [subjectiveOpinion, updated_alpha, updated_beta, updated_gamma, metrics] = ...
    calculateLocalSubjectiveOpinion3(alpha, beta, gamma, socialTrustLevel, ...
        offloading_success, params, isFirst, isFirstFailure, successStreak, totalInteractions, ...
        hasPriorSuccess, isWarning, isActive, blackoutCounter)
% CALCULATELOCALSUBJECTIVEOPINION3 - Evidence mapping with Dynamic H
%
% Dynamic H allows providers at any ST level to earn positive evidence
% through consistent successful behavior.
%
% Grace requires ALL of (same as v1):
%   1. Failed interaction
%   2. High social trust
%   3. First failure (for this requester)
%   4. Has prior success (proven track record - prevents gaming)
%   5. Not already governed (warning/blackout/inactive)

    % Handle missing parameters (backward compatibility)
    if nargin < 9,  successStreak = 0;      end
    if nargin < 10, totalInteractions = 0;  end
    if nargin < 11, hasPriorSuccess = false; end
    if nargin < 12, isWarning = false;      end
    if nargin < 13, isActive = true;        end
    if nargin < 14, blackoutCounter = 0;    end

    % =========================================================
    % SINGLE THRESHOLD FOR ALL ST LEVELS (read from Params)
    % =========================================================
    I_high_thresh = params.I_high_thresh;
    I_low_thresh  = params.I_low_thresh;

    % =========================================================
    % CALCULATE DYNAMIC H
    % =========================================================
    H = calculateHonestyDynamic(socialTrustLevel, offloading_success, ...
                                 successStreak, totalInteractions, params);
    I = H;

    % =========================================================
    % GRACE GATING (anti-abuse) - SAME AS V1
    % =========================================================
    st = lower(string(socialTrustLevel));
    isHighST = strcmpi(st, "high");

    % Grace allowed only if provider is not already governed
    notAlreadyGoverned = (isActive == true) && ...
                         (isWarning == false) && ...
                         (blackoutCounter == 0);

    % Grace requires ALL 5 conditions (same as v1):
    %   1. Failed interaction
    %   2. High social trust
    %   3. First failure (for this requester)
    %   4. Has prior success (proven track record - prevents gaming)
    %   5. Not already governed (warning/blackout/inactive)
    useGrace = (~offloading_success) && isHighST && ...
               isFirstFailure && hasPriorSuccess && notAlreadyGoverned;

    % =========================================================
    % EVIDENCE MAPPING
    % =========================================================
    if ~params.useDynamicHonesty
        % NoDH mode: binary routing, no H-conditional ambiguity, no grace
        if offloading_success
            da = 1; db = 0; dg = 0;
            rule = "succBinary";
        else
            da = 0; db = 1; dg = 0;
            rule = "failBinary";
        end
    elseif useGrace
        da = 0; db = 0; dg = 1;   % γ++ (grace uncertainty)
        rule = "graceFirstFailHigh";

    elseif offloading_success
        % SUCCESS: Check if H reached threshold
        if H >= I_high_thresh
            da = 1; db = 0; dg = 0;   % α++ (proven trustworthy)
            rule = "succHighH";
        else
            da = 0; db = 0; dg = 1;   % γ++ (still building trust)
            rule = "succMidH";
        end
    else
        % FAILURE (no grace) — three-zone H routing.
        % With ST-specific failure penalties (HIGH=0.50, INT=LOW=0.30) all
        % three classes land H < I_low_thresh, so failLowH (-> beta) is the
        % typical path. failMidH is retained for parameter robustness: if
        % future tuning reduces failurePenalty_high below 0.45 or raises
        % I_low_thresh above 0.50, HIGH-ST post-fail could land in mid band
        % and route to gamma. Grace remains the primary forgiveness path.
        if H <= I_low_thresh
            da = 0; db = 1; dg = 0;
            rule = "failLowH";
        else
            da = 0; db = 0; dg = 1;
            rule = "failMidH";
        end
    end

    % Update evidence
    updated_alpha = alpha + da;
    updated_beta  = beta  + db;
    updated_gamma = gamma + dg;

    % Compute subjective opinion
    S = updated_alpha + updated_beta + updated_gamma;
    b = updated_alpha / S;
    d = updated_beta  / S;
    u = updated_gamma / S;
    subjectiveOpinion = [b; d; u];

    % Metrics for logging
    metrics = struct('H', H, 'I', I, 'I_high_thresh', I_high_thresh, ...
                     'successStreak', successStreak, 'totalInteractions', totalInteractions, ...
                     'useGrace', useGrace, 'hasPriorSuccess', hasPriorSuccess, ...
                     'notAlreadyGoverned', notAlreadyGoverned, 'rule', rule);
end

%% ====================================================================
%% EMBEDDED: calculateHonestyDynamic
%% ====================================================================
function H = calculateHonestyDynamic(socialTrustLevel, offloading_success, ...
                                      successStreak, totalInteractions, params)
% CALCULATEHONESTYDYNAMIC - Dynamic honesty based on behavior history
%
% H grows with consistent successful behavior, allowing LOW-ST providers
% to eventually reach the α++ threshold.
%
% All parameters read from Params() for sweepability.
%
% RESULT (with default params):
%   HIGH-ST: reaches 0.80 immediately → α++ from interaction 1
%   INT-ST:  reaches 0.80 at interaction 4 → α++ from interaction 4
%   LOW-ST:  reaches 0.80 at interaction 7 → α++ from interaction 7

    % Backward compatibility: if params not passed, load from Params()
    if nargin < 5 || isempty(params)
        params = Params();
    end

    % Ensure numeric types (may come from blockchain as different types)
    if ~isnumeric(successStreak)
        successStreak = double(successStreak);
    end
    if ~isnumeric(totalInteractions)
        totalInteractions = double(totalInteractions);
    end
    if isempty(successStreak) || isnan(successStreak)
        successStreak = 0;
    end
    if isempty(totalInteractions) || isnan(totalInteractions)
        totalInteractions = 0;
    end

    % Base honesty from social trust (read from params)
    switch lower(string(socialTrustLevel))
        case "high"
            H_base = params.H_base_high;
        case "intermediate"
            H_base = params.H_base_interm;
        case "low"
            H_base = params.H_base_low;
        otherwise
            H_base = 0.50;
    end

    % Read dynamic honesty parameters from Params
    consistencyBonusPerSuccess    = params.consistencyBonusPerSuccess;
    maxConsistencyBonus           = params.maxConsistencyBonus;
    experienceBonusPerInteraction = params.experienceBonusPerInteraction;
    maxExperienceBonus            = params.maxExperienceBonus;

    if offloading_success
        % SUCCESS: H grows with consistent behavior
        consistencyBonus = min(consistencyBonusPerSuccess * successStreak, maxConsistencyBonus);
        experienceBonus = min(experienceBonusPerInteraction * totalInteractions, maxExperienceBonus);
        H = H_base + consistencyBonus + experienceBonus;
    else
        % FAILURE: H drops by ST-specific penalty.
        % HIGH penalty is larger (0.50) so post-failure H lands in the
        % failLowH band, making grace the sole gamma route for HIGH-ST.
        switch lower(string(socialTrustLevel))
            case 'high',         penalty = params.failurePenalty_high;
            case 'intermediate', penalty = params.failurePenalty_interm;
            case 'low',          penalty = params.failurePenalty_low;
            otherwise,           penalty = params.failurePenalty_interm;
        end
        H = H_base - penalty;
    end

    % Clamp to valid range
    H = max(params.H_clamp_min, min(params.H_clamp_max, H));
end

%% ====================================================================
%% EMBEDDED: calculateOpinionMatrix (same as v1)
%% ====================================================================
function [recommendedOpinion, recStats] = calculateOpinionMatrix( ...
    VreqiID, SVpro, SVproID, Vreqi_Offtx, runIndex, params, blockchainObj)
% calculateOpinionMatrix  Compute recommended opinion from other requesters

    zeta    = params.zeta;
    sigma   = params.sigma;
    theta   = params.theta;
    tau     = params.tau;
    rhoBase = params.rho;
    windowK = params.windowK;

    recommendedOpinion = [];
    recStats = struct( ...
        'numHistoryEntries',  0, ...
        'numAllVreqIDs',      0, ...
        'numOtherRequesters', 0, ...
        'numRecommenders',    0, ...
        'IF_mean',            NaN, ...
        'IF_std',             NaN, ...
        'IF_max',             NaN );

    SVpro_Offtx = SVpro.Offtransaction;

    if isfield(SVpro_Offtx, 'numTransactions') && ~isempty(SVpro_Offtx.numTransactions)
        allIDs = fieldnames(SVpro_Offtx.numTransactions);
        txCounts = struct2cell(SVpro_Offtx.numTransactions);
        txCounts = cell2mat(txCounts);
        allVreqIDs = allIDs(txCounts > 0);
    else
        allVreqIDs = {};
    end

    recStats.numAllVreqIDs = numel(allVreqIDs);

    if isfield(SVpro_Offtx, 'history') && ~isempty(SVpro_Offtx.history)
        historyArray_SVpro = SVpro_Offtx.history;
        historyVreqIDs     = unique({historyArray_SVpro.VreqiID});
    else
        historyArray_SVpro = [];
        historyVreqIDs     = {};
    end
    recStats.numHistoryEntries = numel(historyArray_SVpro);

    if isempty(historyArray_SVpro)
        return;
    end
    hasOtherHistory = any(~strcmp({historyArray_SVpro.VreqiID}, VreqiID));
    if ~hasOtherHistory
        return;
    end

    validWithCounters = intersect(allVreqIDs, historyVreqIDs);
    otherRequesters   = setdiff(validWithCounters, VreqiID);
    recStats.numOtherRequesters = numel(otherRequesters);

    if params.maxRecommenders > 0 && numel(otherRequesters) > params.maxRecommenders
        interactionCounts = zeros(numel(otherRequesters), 1);
        for j = 1:numel(otherRequesters)
            reqID = otherRequesters{j};
            if isfield(SVpro_Offtx.numTransactions, reqID)
                interactionCounts(j) = SVpro_Offtx.numTransactions.(reqID);
            end
        end
        [~, sortIdx] = sort(interactionCounts, 'descend');
        otherRequesters = otherRequesters(sortIdx(1:params.maxRecommenders));
    end

    chain = blockchainObj.blockchain;
    allProviderHistories = struct();

    for b = 1:numel(chain)
        blk = chain(b);
        if ~isfield(blk.data, 'VehicleRole'), continue; end
        if ~startsWith(blk.data.VehicleRole, 'Vpro'), continue; end
        if ~isfield(blk.data, 'Offtransaction'), continue; end
        if ~isfield(blk.data.Offtransaction, 'history'), continue; end

        provHistory = blk.data.Offtransaction.history;
        if isempty(provHistory), continue; end

        providerPID = blk.data.PID;

        for h = 1:numel(provHistory)
            entry = provHistory(h);
            if ~isfield(entry, 'SVproID') || isempty(entry.SVproID)
                entry.SVproID = providerPID;
            end
            reqID = entry.VreqiID;
            if ~isfield(allProviderHistories, reqID)
                allProviderHistories.(reqID) = entry;
            else
                allProviderHistories.(reqID)(end+1) = entry;
            end
        end
    end

    recOps   = [];
    recIF    = [];
    recDelta = [];

    for r = 1:numel(otherRequesters)
        otherVreq = otherRequesters{r};

        if ~isfield(allProviderHistories, otherVreq)
            continue;
        end
        h_all = allProviderHistories.(otherVreq);
        if isempty(h_all), continue; end

        hasABC = isfield(SVpro_Offtx,'numAlpha') && ...
                 isfield(SVpro_Offtx,'numBeta')  && ...
                 isfield(SVpro_Offtx,'numGamma') && ...
                 isfield(SVpro_Offtx.numAlpha, otherVreq) && ...
                 isfield(SVpro_Offtx.numBeta,  otherVreq) && ...
                 isfield(SVpro_Offtx.numGamma, otherVreq);
        if ~hasABC, continue; end

        a_ij = SVpro_Offtx.numAlpha.(otherVreq);
        b_ij = SVpro_Offtx.numBeta.(otherVreq);
        g_ij = SVpro_Offtx.numGamma.(otherVreq);
        S_ij = a_ij + b_ij + g_ij;
        if S_ij <= 0, continue; end

        subj_i = [a_ij, b_ij, g_ij] / S_ij;

        % DISABLED: In sparse vehicular environments, we need all available
        % recommendations even from less experienced recommenders. History is
        % still being built, so filtering out uncertain opinions would discard
        % valuable evidence during the critical early trust formation phase.
        % Original filter:
        %   - Skip if uncertainty > 50%: subj_i(3) > 0.5
        %   - Skip if fewer than 3 interactions: S_ij < 3
        % if subj_i(3) > 0.5 || S_ij < 3
        %     continue;
        % end

        provs = unique({h_all.SVproID});
        numS  = numel(provs);
        N_i_s = zeros(1, numS);
        N_ij  = 0;

        for p = 1:numS
            provID = provs{p};
            maskProvAll = strcmp({h_all.SVproID}, provID);
            h_ps = h_all(maskProvAll);

            if isempty(h_ps)
                N_i_s(p) = 0;
                continue;
            end

            runs_s = [h_ps.runIndex];
            [~, sortIdx_s] = sort(runs_s);
            numTx_s = numel(h_ps);
            K_s = min(windowK, numTx_s);
            recentIdx_s = sortIdx_s(end-K_s+1:end);

            recentMask_s = false(1, numTx_s);
            recentMask_s(recentIdx_s) = true;

            alpha_i1_s = sum([h_ps(recentMask_s).offloadingSuccessstatus] == 1);
            beta_i1_s  = sum([h_ps(recentMask_s).offloadingSuccessstatus] == 0);
            alpha_i2_s = sum([h_ps(~recentMask_s).offloadingSuccessstatus] == 1);
            beta_i2_s  = sum([h_ps(~recentMask_s).offloadingSuccessstatus] == 0);

            alpha_i_s = zeta * theta * alpha_i1_s + sigma * theta * alpha_i2_s;
            beta_i_s  = zeta * tau   * beta_i1_s  + sigma * tau   * beta_i2_s;

            N_i_s(p) = alpha_i_s + beta_i_s;

            if strcmp(provID, SVproID)
                N_ij = N_i_s(p);
            end
        end

        if N_ij <= 0
            continue;
        end

        Ni_bar = mean(N_i_s);
        if Ni_bar <= 0
            Ni_bar = 1;
        end

        IFij = N_ij / Ni_bar;
        delta_ij = rhoBase * IFij;

        recOps(end+1,:)   = subj_i;
        recIF(end+1)      = IFij;
        recDelta(end+1)   = delta_ij;
    end

    recStats.numRecommenders = numel(recIF);
    if ~isempty(recIF)
        recStats.IF_mean = mean(recIF);
        recStats.IF_std  = std(recIF);
        recStats.IF_max  = max(recIF);
    end

    if isempty(recOps)
        return;
    end

    sw = sum(recDelta);
    w = recDelta(:).' / sw;

    b_rec = sum(w .* recOps(:,1).');
    d_rec = sum(w .* recOps(:,2).');
    u_rec = sum(w .* recOps(:,3).');

    Srec = b_rec + d_rec + u_rec;
    b_rec = b_rec / Srec;
    d_rec = d_rec / Srec;
    u_rec = u_rec / Srec;

    recommendedOpinion = [b_rec, d_rec, u_rec];
end

%% ====================================================================
%% EMBEDDED: combineOpinions
%% ====================================================================
function combinedOpinion = combineOpinions(subjectiveOpinion, recommendedOpinion)
    b1 = subjectiveOpinion(1); d1 = subjectiveOpinion(2); u1 = subjectiveOpinion(3);
    b2 = recommendedOpinion(1); d2 = recommendedOpinion(2); u2 = recommendedOpinion(3);

    k = (u1 + u2 - u1*u2);
    if abs(k) < 1e-10
        b_final = (b1 + b2) / 2;
        d_final = (d1 + d2) / 2;
        u_final = (u1 + u2) / 2;
    else
        b_final = (b1*u2 + b2*u1) / k;
        d_final = (d1*u2 + d2*u1) / k;
        u_final = (u1*u2) / k;
    end
    combinedOpinion = [b_final, d_final, u_final];
end
