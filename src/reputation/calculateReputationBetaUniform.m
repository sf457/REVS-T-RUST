function [updatedReputation, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
    calculateReputationBetaUniform(SVpro, runIndex, Updated_Vreqi, InteractionData, maliciousPercentage, scenarioName)
% CALCULATEREPUTATIONBETAUNIFORM
% MODEL: Pure Beta Reputation System (Jøsang BRS) with Uniform Prior
%
% Reference: Jøsang & Ismail "The Beta Reputation System" (2002)
%
% Key Characteristics:
%   - Pure Beta distribution: R = (1 + s) / (2 + s + f)
%   - UNIFORM initialization: alpha=1, beta=1 for ALL vehicles (R=0.5)
%   - NO Social Trust (ST) integration
%   - NO uncertainty (gamma) modeling
%   - NO recommendations (pure local evidence)
%   - NO GOVERNANCE (faithful to Jøsang BRS - pure reputation only)
%
% This is the CLEANEST baseline because it isolates what Beta reputation
% can do with direct evidence alone:
%
%   R = (prior_alpha + successes) / (prior_alpha + prior_beta + successes + failures)
%   R = (1 + s) / (2 + s + f)
%
% Comparison with RUST:
%   - No ST-based priors (cold-start vulnerability)
%   - No uncertainty buffer (faster but harsher)
%   - No governance at all (RUST has tiered blacklisting)
%   - No recommendations (single requester view only)
%
% This model highlights RUST's advantages in:
%   1. Cold-start handling via ST-based initialization
%   2. Peer recommendations for broader evidence
%   3. Uncertainty modeling via gamma evidence
%   4. Tiered governance for fairness

    params = Params();
    VERBOSE = params.VERBOSE;

    % =========================
    % 1) Basic extraction
    % =========================
    VreqiID = Updated_Vreqi.PID;
    SVproID = SVpro.PID;
    SVpro_Offtx = SVpro.Offtransaction;
    current_R = SVpro.reputation;
    isMalicious = SVpro.isMalicious;

    TX = SVpro_Offtx.TransactionsID;
    tAll = TX.totalOffloadingLatency;
    MaxT = TX.maximumTime;
    success = double(TX.offloadingSuccessstatus);

    if VERBOSE
        fprintf('\n[BetaUniform][Run %d] Update rep for %s (req=%s)\n', runIndex, SVproID, VreqiID);
    end

    % Initialize fields if missing
    if ~isfield(SVpro, 'blackoutCounter')
        SVpro.blackoutCounter = 0;
    end
    if ~isfield(SVpro, 'totalBlacklists')
        SVpro.totalBlacklists = 0;
    end

    % =========================
    % 2) UNIFORM Prior (Key: Same for ALL vehicles)
    % =========================
    % Jøsang BRS uses uniform prior: alpha=1, beta=1
    % This means R = (1 + s) / (2 + s + f) initially = 0.5
    prior_alpha = 1;  % Uniform prior
    prior_beta  = 1;  % R = 1/(1+1) = 0.5 for all

    % =========================
    % 3) Aggregate ALL Evidence (NO per-requester split)
    % =========================
    % Unlike BetaRec which averages per-requester opinions,
    % BetaUniform aggregates ALL interactions into single Beta

    total_success = 0;
    total_failed = 0;

    if isfield(SVpro_Offtx, 'numSuccess') && isfield(SVpro_Offtx, 'numFailed')
        % Sum across all requesters
        if ~isempty(SVpro_Offtx.numSuccess)
            successFields = fieldnames(SVpro_Offtx.numSuccess);
            for i = 1:numel(successFields)
                total_success = total_success + SVpro_Offtx.numSuccess.(successFields{i});
            end
        end
        if ~isempty(SVpro_Offtx.numFailed)
            failedFields = fieldnames(SVpro_Offtx.numFailed);
            for i = 1:numel(failedFields)
                total_failed = total_failed + SVpro_Offtx.numFailed.(failedFields{i});
            end
        end
    end

    % =========================
    % 4) Pure Beta Reputation (Jøsang BRS Formula)
    % =========================
    % R = alpha / (alpha + beta)
    % where alpha = prior_alpha + successes
    %       beta  = prior_beta + failures

    alpha = prior_alpha + total_success;
    beta  = prior_beta + total_failed;

    R = alpha / (alpha + beta);

    if VERBOSE
        fprintf('[BetaUniform] Evidence: s=%d, f=%d | alpha=%.1f, beta=%.1f | R=%.3f\n', ...
            total_success, total_failed, alpha, beta, R);
    end

    % =========================
    % 5) NO RECOMMENDATIONS (Key difference from BetaRec)
    % =========================
    % BetaUniform uses ONLY direct local evidence
    % This isolates the pure Beta reputation capability

    R_preTier = R;

    % =========================
    % 6) NO GOVERNANCE (faithful to Jøsang & Ismail 2002)
    % =========================
    % Beta BRS is a pure reputation update mechanism with NO blacklisting.
    % Providers always remain active — governance is external to BRS.
    tierAction = "none";
    SVpro.isActive = true;
    SVpro.isWarning = false;
    SVpro.warningStreak = 0;
    SVpro.blackoutCounter = 0;

    % =========================
    % 7) Outputs
    % =========================
    updatedReputation = min(max(R, 0), 1);
    SVpro.reputation = updatedReputation;

    isActive = SVpro.isActive;
    isWarning = false;
    warningStreak = 0;
    blackoutCounter = SVpro.blackoutCounter;

    if VERBOSE
        fprintf('[BetaUniform] %s: R=%.3f active=%d (uniform prior, no recs, no tiers)\n', ...
            SVproID, updatedReputation, isActive);
    end

    % =========================
    % 8) Logging
    % =========================
    if params.enableLogging
        row = struct();
        row.timestamp = string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
        row.runIndex = runIndex;
        row.globalRatio = double(maliciousPercentage);
        row.scenarioName = string(scenarioName);
        row.VreqiID = string(VreqiID);
        row.SVproID = string(SVproID);
        row.socialTrustLevel = string(SVpro.socialTrustLevel);  % Logged but not used
        row.isMalicious = double(isMalicious);
        row.current_R = double(current_R);
        row.success = double(success);
        row.tAll = double(tAll);
        row.MaxT = double(MaxT);
        row.total_success = double(total_success);
        row.total_failed = double(total_failed);
        row.alpha = double(alpha);
        row.beta = double(beta);
        row.R_local = double(R);
        row.R_recommended = NaN;  % No recommendations
        row.numRecommenders = 0;
        row.R_preTier = double(R_preTier);
        row.R_postTier = double(updatedReputation);
        row.tierAction = string(tierAction);
        row.isActive = double(isActive);
        row.isWarning = double(isWarning);
        row.warningStreak = double(warningStreak);
        row.blackoutCounter = double(blackoutCounter);
        row.model = "BetaUniform";

        logFile = strrep(params.logFile, 'reputation_trace', 'reputation_trace_BetaUniform');
        writeReputationTrace(logFile, row);
    end
end
