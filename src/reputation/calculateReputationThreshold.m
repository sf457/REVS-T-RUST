function [updatedReputation, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
    calculateReputationThreshold(SVpro, runIndex, Updated_Vreqi, blockchainObj, maliciousPercentage, scenarioName)
% CALCULATEREPUTATIONTHRESHOLD
% TRUE ABLATION of RUST_V2: Identical local opinion, Dynamic H, Kang recs
% ONLY difference: Binary governance (no warning tier, no progressive blackout)
%
% Shares with RUST_V2:
%   - Same Dynamic H (calculateHonestyDynamic)
%   - Same 5-condition grace gating
%   - Same evidence mapping rules
%   - Same Kang-style recommendations (calculateOpinionMatrix via blockchainObj)
%   - Same opinion fusion (Jøsang cumulative)
%   - Same R = b + a0*u
%
% Only difference from RUST_V2:
%   - Binary governance: if R < R_min AND failure → blacklist, else active
%   - No warning tier, no streak escalation, no progressive blackout, no reward boost
%
% Inputs:
%   SVpro              : selected provider struct
%   runIndex           : current simulation index
%   Updated_Vreqi      : requester struct
%   blockchainObj      : blockchain object (SINGLE SOURCE OF TRUTH)
%   maliciousPercentage: global malicious ratio
%   scenarioName       : scenario identifier
%
% Outputs:
%   updatedReputation : scalar R = b + a0*u
%   isActive          : 1 if R >= R_min (or succeeded)
%   isWarning         : always 0 (no warning tier)
%   warningStreak     : always 0 (no streak)
%   blackoutCounter   : remaining frozen runs
%   SVpro             : updated provider struct

    % =========================
    % 1) Centralized parameters
    % =========================
    params  = Params();
    VERBOSE = params.VERBOSE;

    % =========================
    % 2) Basic extraction
    % =========================
    VreqiID       = Updated_Vreqi.PID;
    SVproID       = SVpro.PID;
    SVpro_Offtx   = SVpro.Offtransaction;
    SVpro_STLevel = SVpro.socialTrustLevel;
    Vreqi_Offtx   = Updated_Vreqi.Offtransaction;
    current_R     = SVpro.reputation;
    isMalicious   = SVpro.isMalicious;

    TX      = SVpro_Offtx.TransactionsID;
    tAll    = TX.totalOffloadingLatency;
    MaxT    = TX.maximumTime;
    success = double(TX.offloadingSuccessstatus);

    if VERBOSE
        fprintf('\n[Threshold][Run %d] Update rep for %s (req=%s)\n', runIndex, SVproID, VreqiID);
    end

    % Initialize fields if missing
    if ~isfield(SVpro, 'blackoutCounter'), SVpro.blackoutCounter = 0; end
    if ~isfield(SVpro, 'totalBlacklists'), SVpro.totalBlacklists = 0; end

    % =========================
    % 3) Local subjective opinion (IDENTICAL to RUST_V2)
    % =========================
    alpha = SVpro_Offtx.numAlpha.(VreqiID);
    beta  = SVpro_Offtx.numBeta.(VreqiID);
    gamma = SVpro_Offtx.numGamma.(VreqiID);

    isFirst = (SVpro_Offtx.numTransactions.(VreqiID) == 1);
    isFirstFailure = (SVpro_Offtx.numFailed.(VreqiID) == 1);

    % Grace requires proven track record
    numSuccess = SVpro_Offtx.numSuccess.(VreqiID);
    hasPriorSuccess = numSuccess > 0;

    % Get current governance state
    currentIsWarning = false;  % No warning tier in Threshold
    currentIsActive = SVpro.isActive;
    currentBlackoutCounter = SVpro.blackoutCounter;

    % Get PER-PAIR streak info (per requester-provider pair, keyed by VreqiID; same as RUST_V2)
    if ~isfield(SVpro, 'localSuccessStreak') || ~isstruct(SVpro.localSuccessStreak)
        SVpro.localSuccessStreak = struct();
    end
    if ~isfield(SVpro, 'localFailureStreak') || ~isstruct(SVpro.localFailureStreak)
        SVpro.localFailureStreak = struct();
    end
    if ~isfield(SVpro, 'localTotalInteractions') || ~isstruct(SVpro.localTotalInteractions)
        SVpro.localTotalInteractions = struct();
    end
    if isfield(SVpro.localSuccessStreak, VreqiID) && isnumeric(SVpro.localSuccessStreak.(VreqiID))
        successStreak = double(SVpro.localSuccessStreak.(VreqiID));
    else
        successStreak = 0;
    end
    if isfield(SVpro.localFailureStreak, VreqiID) && isnumeric(SVpro.localFailureStreak.(VreqiID))
        failureStreak = double(SVpro.localFailureStreak.(VreqiID));
    else
        failureStreak = 0;
    end
    if isfield(SVpro.localTotalInteractions, VreqiID) && isnumeric(SVpro.localTotalInteractions.(VreqiID))
        totalInteractions = double(SVpro.localTotalInteractions.(VreqiID));
    else
        totalInteractions = 0;
    end

    % Call SAME Dynamic H opinion function as RUST_V2 (v8 signature)
    [subjectiveOpinion, alphaNew, betaNew, gammaNew, localMetrics] = ...
        calculateLocalSubjectiveOpinion_DynamicH(alpha, beta, gamma, ...
            SVpro_STLevel, success, params, isFirst, isFirstFailure, ...
            successStreak, failureStreak, totalInteractions, hasPriorSuccess, ...
            currentIsWarning, currentIsActive, currentBlackoutCounter);

    b_subj = subjectiveOpinion(1);
    d_subj = subjectiveOpinion(2);
    u_subj = subjectiveOpinion(3);

    % --- increments from this interaction ---
    da = alphaNew - alpha;
    db = betaNew  - beta;
    dg = gammaNew - gamma;

    % Update PER-PAIR streak counters (keyed by VreqiID; hard reset on opposite outcome)
    if success
        SVpro.localSuccessStreak.(VreqiID) = successStreak + 1;
        SVpro.localFailureStreak.(VreqiID) = 0;
    else
        SVpro.localSuccessStreak.(VreqiID) = 0;
        SVpro.localFailureStreak.(VreqiID) = failureStreak + 1;
    end
    SVpro.localTotalInteractions.(VreqiID) = totalInteractions + 1;

    % Persist α/β/γ per requester
    SVpro.Offtransaction.numAlpha.(VreqiID) = alphaNew;
    SVpro.Offtransaction.numBeta.(VreqiID)  = betaNew;
    SVpro.Offtransaction.numGamma.(VreqiID) = gammaNew;

    % =========================
    % 4) Kang-style recommended opinion (IDENTICAL to RUST_V2)
    % =========================
    recommendedOpinion = [];
    recStats = struct('numHistoryEntries', 0, 'numAllVreqIDs', 0, ...
                      'numOtherRequesters', 0, 'numRecommenders', 0, ...
                      'IF_mean', NaN, 'IF_std', NaN, 'IF_max', NaN);

    if params.useRecommendations
        [recommendedOpinion, recStats] = calculateOpinionMatrix( ...
            VreqiID, SVpro, SVproID, Vreqi_Offtx, runIndex, params, blockchainObj);
    elseif VERBOSE
        fprintf('[Threshold] Recommendations DISABLED\n');
    end

    % =========================
    % Store recommendation statistics (IDENTICAL to RUST_V2)
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
    % 5) Fuse opinions (IDENTICAL to RUST_V2)
    % =========================
    if ~isempty(recommendedOpinion)
        fusedOpinion = combineOpinions(subjectiveOpinion, recommendedOpinion(:));
        b_final = fusedOpinion(1);
        u_final = fusedOpinion(3);
    else
        b_final = b_subj;
        u_final = u_subj;
    end

    R = b_final + params.a0 * u_final;

    if VERBOSE
        fprintf('[Threshold] R_fused = %.4f\n', R);
    end

    % =========================
    % 6) BINARY GOVERNANCE (ONLY DIFFERENCE FROM RUST_V2)
    % =========================
    % No warning tier, no progressive blackout, no reward boost
    % Simple: if R < R_min AND failure → blacklist, else active
    tierAction = "stable";
    isFailure = (success == 0);

    if R < params.R_min
        if isFailure
            SVpro.blackoutCounter = params.penaltyFreezeRuns;
            SVpro.isActive = false;
            SVpro.totalBlacklists = SVpro.totalBlacklists + 1;
            tierAction = "blacklist";
        else
            SVpro.isActive = true;
            tierAction = "lowR-active";
        end
    else
        SVpro.isActive = true;
        tierAction = "stable";
    end

    % No warning tier, no streak
    SVpro.isWarning = false;
    SVpro.warningStreak = 0;

    % =========================
    % 7) Outputs
    % =========================
    updatedReputation = min(max(R, 0), 1);
    SVpro.reputation  = updatedReputation;

    isActive        = SVpro.isActive;
    isWarning       = false;
    warningStreak   = 0;
    blackoutCounter = SVpro.blackoutCounter;

    if VERBOSE
        fprintf('[Threshold] %s: active=%d, rep=%.3f, blackout=%d\n', ...
            SVproID, isActive, updatedReputation, blackoutCounter);
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
        row.Honest_ij        = double(localMetrics.H);
        row.I_ij             = double(localMetrics.I);
        row.alpha_after      = double(alphaNew);
        row.beta_after       = double(betaNew);
        row.gamma_after      = double(gammaNew);
        row.subj_b           = double(b_subj);
        row.subj_d           = double(d_subj);
        row.subj_u           = double(u_subj);
        row.I_high_thresh = localMetrics.I_high_thresh;
        row.I_low_thresh  = 0.35;
        row.R_preTier        = double(R);
        row.R_postTier       = double(updatedReputation);
        row.tierAction       = string(tierAction);
        row.isActive         = double(isActive);
        row.isWarning        = double(isWarning);
        row.warningStreak    = double(warningStreak);
        row.blackoutCounter  = double(blackoutCounter);
        row.model            = "Threshold";

        logFile = strrep(params.logFile, 'reputation_trace', 'reputation_trace_Threshold');
        writeReputationTrace(logFile, row);
    end
end

%% ====================================================================
%% EMBEDDED: calculateLocalSubjectiveOpinion with Dynamic H
%% (Identical to RUST_V2's calculateLocalSubjectiveOpinion3)
%% ====================================================================
function [subjectiveOpinion, updated_alpha, updated_beta, updated_gamma, metrics] = ...
    calculateLocalSubjectiveOpinion_DynamicH(alpha, beta, gamma, socialTrustLevel, ...
        offloading_success, params, isFirst, isFirstFailure, successStreak, failureStreak, totalInteractions, ...
        hasPriorSuccess, isWarning, isActive, blackoutCounter)
% v8 signature: includes failureStreak, pure threshold routing, no grace.

    if nargin < 9,  successStreak = 0;      end
    if nargin < 10, failureStreak = 0;      end
    if nargin < 11, totalInteractions = 0;  end
    if nargin < 12, hasPriorSuccess = false; end
    if nargin < 13, isWarning = false;      end
    if nargin < 14, isActive = true;        end
    if nargin < 15, blackoutCounter = 0;    end

    I_high_thresh = params.I_high_thresh;
    I_low_thresh  = params.I_low_thresh;

    H = calculateHonestyDynamic(socialTrustLevel, offloading_success, ...
                                successStreak, failureStreak, totalInteractions, params);

    % Pure threshold routing on H
    if ~params.useDynamicHonesty
        if offloading_success
            da = 1; db = 0; dg = 0; rule = "succBinary";
        else
            da = 0; db = 1; dg = 0; rule = "failBinary";
        end
    elseif H >= I_high_thresh
        da = 1; db = 0; dg = 0; rule = "alpha";
    elseif H <= I_low_thresh
        da = 0; db = 1; dg = 0; rule = "beta";
    else
        da = 0; db = 0; dg = 1; rule = "gamma";
    end

    updated_alpha = alpha + da;
    updated_beta  = beta  + db;
    updated_gamma = gamma + dg;

    S = updated_alpha + updated_beta + updated_gamma;
    subjectiveOpinion = [updated_alpha/S; updated_beta/S; updated_gamma/S];

    metrics = struct('H', H, 'I', H, 'I_high_thresh', I_high_thresh, ...
                     'I_low_thresh', I_low_thresh, ...
                     'successStreak', successStreak, 'failureStreak', failureStreak, ...
                     'totalInteractions', totalInteractions, ...
                     'rule', rule);
end

%% ====================================================================
%% EMBEDDED: calculateHonestyDynamic (Identical to RUST_V2, reads from Params)
%% ====================================================================
function H = calculateHonestyDynamic(socialTrustLevel, offloading_success, ...
                                      successStreak, failureStreak, totalInteractions, params)
% v7 ST-specific DH (mirrors computeReputationRUST.m).
% Threshold differs from RUST only in tier governance; the DH formula
% must match so the ablation isolates the governance dimension cleanly.
    if nargin < 6 || isempty(params), params = Params(); end

    if ~isnumeric(successStreak),     successStreak = double(successStreak); end
    if ~isnumeric(failureStreak),     failureStreak = double(failureStreak); end %#ok<NASGU>
    if ~isnumeric(totalInteractions), totalInteractions = double(totalInteractions); end
    if isempty(successStreak)     || isnan(successStreak),     successStreak = 0; end
    if isempty(totalInteractions) || isnan(totalInteractions), totalInteractions = 0; end

    switch lower(string(socialTrustLevel))
        case "high",         H_base = params.H_base_high;
        case "intermediate", H_base = params.H_base_interm;
        case "low",          H_base = params.H_base_low;
        otherwise,           H_base = 0.50;
    end

    if offloading_success
        consistencyBonus = min(params.consistencyBonusPerSuccess    * successStreak,    params.maxConsistencyBonus);
        experienceBonus  = min(params.experienceBonusPerInteraction * totalInteractions, params.maxExperienceBonus);
        H = H_base + consistencyBonus + experienceBonus;
    else
        switch lower(string(socialTrustLevel))
            case "high",         penalty = params.failurePenalty_high;
            case "intermediate", penalty = params.failurePenalty_interm;
            case "low",          penalty = params.failurePenalty_low;
            otherwise,           penalty = params.failurePenalty_interm;
        end
        H = H_base - penalty;
    end

    H = max(params.H_clamp_min, min(params.H_clamp_max, H));
end

%% ====================================================================
%% EMBEDDED: calculateOpinionMatrix (Identical to RUST_V2)
%% Uses blockchainObj for recommendation data
%% ====================================================================
function [recommendedOpinion, recStats] = calculateOpinionMatrix( ...
    VreqiID, SVpro, SVproID, Vreqi_Offtx, runIndex, params, blockchainObj)

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

    if isempty(historyArray_SVpro), return; end
    hasOtherHistory = any(~strcmp({historyArray_SVpro.VreqiID}, VreqiID));
    if ~hasOtherHistory, return; end

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

    % Build requester histories from blockchain (same as RUST_V2)
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

        if N_ij <= 0, continue; end

        Ni_bar = mean(N_i_s);
        if Ni_bar <= 0, Ni_bar = 1; end

        IFij = N_ij / Ni_bar;
        delta_ij = rhoBase * IFij;

        recOps(end+1,:) = subj_i;
        recIF(end+1) = IFij;
        recDelta(end+1) = delta_ij;
    end

    recStats.numRecommenders = numel(recIF);
    if ~isempty(recIF)
        recStats.IF_mean = mean(recIF);
        recStats.IF_std = std(recIF);
        recStats.IF_max = max(recIF);
    end

    if isempty(recOps), return; end

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
%% EMBEDDED: combineOpinions (Identical to RUST_V2)
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
