function [updatedReputation, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
    calculateReputationIqbal(SVpro, runIndex, Updated_Vreqi, InteractionData, maliciousPercentage, scenarioName)
% CALCULATEREPUTATIONIQBAL
% MODEL: Iqbal et al. (2020) Scalar Reward-Based Reputation
%
% Reference: Iqbal et al. "Trust Management in Vehicular Networks"
%
% Key Characteristics:
%   - SCALAR reputation (NOT Subjective Logic)
%   - Reward function: l = λΩ / (Ω - Tₜ)
%   - Where: Ω = deadline, Tₜ = actual latency, λ = scaling factor
%   - Reputation update: R_new = (1-α)*R_old + α*l
%   - NO GOVERNANCE (no blacklisting, no thresholds) - faithful to paper
%   - NO Social Trust integration
%
% Key Differences from RUST:
%   - No Subjective Logic (scalar only)
%   - No ST-based priors (cold-start vulnerability)
%   - No governance at all (RUST has tiered blacklisting)
%   - No recommendations
%
% Inputs:
%   SVpro              : selected provider struct
%   runIndex           : current simulation index
%   Updated_Vreqi      : requester struct
%   InteractionData    : struct of historical transactions (unused)
%   maliciousPercentage: global malicious ratio (unused)
%   scenarioName       : scenario identifier
%
% Outputs:
%   updatedReputation : scalar R in [0, 1]
%   isActive          : always 1 (no governance)
%   isWarning         : always 0 (no warning tier)
%   warningStreak     : always 0 (no streak tracking)
%   blackoutCounter   : always 0 (no blacklisting)
%   SVpro             : updated provider struct

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
    tAll = TX.totalOffloadingLatency;      % Actual latency (ms)
    MaxT = TX.maximumTime;                  % Deadline Ω (ms)
    success = double(TX.offloadingSuccessstatus);

    if VERBOSE
        fprintf('\n[Iqbal][Run %d] Update rep for %s (req=%s)\n', runIndex, SVproID, VreqiID);
    end

    % Initialize fields if missing
    if ~isfield(SVpro, 'blackoutCounter')
        SVpro.blackoutCounter = 0;
    end
    if ~isfield(SVpro, 'totalBlacklists')
        SVpro.totalBlacklists = 0;
    end

    % =========================
    % 2) Iqbal Reward Function
    % =========================
    % l = λΩ / (Ω - Tₜ)  when Tₜ < Ω (success)
    % l = 0              when Tₜ >= Ω (failure)
    %
    % Intuition: Faster completion → higher reward
    % λ is a scaling factor to normalize to [0, 1]

    lambda = 0.1;  % Scaling factor (tunable)

    if success == 1 && tAll < MaxT
        % Reward for successful completion
        % Higher reward when latency is much less than deadline
        reward = lambda * MaxT / (MaxT - tAll + lambda * MaxT);
        reward = min(reward, 1.0);  % Cap at 1
    else
        % Failed task: zero reward
        reward = 0;
    end

    if VERBOSE
        fprintf('[Iqbal] tAll=%.1f ms, MaxT=%.1f ms, success=%d → reward=%.3f\n', ...
            tAll, MaxT, success, reward);
    end

    % =========================
    % 3) Exponential Moving Average Update
    % =========================
    % R_new = (1 - α) * R_old + α * l
    % α controls how fast reputation adapts to new evidence

    alpha_ema = 0.3;  % Learning rate (tunable)
    R_new = (1 - alpha_ema) * current_R + alpha_ema * reward;

    if VERBOSE
        fprintf('[Iqbal] R_old=%.3f, α=%.2f → R_new=%.3f\n', current_R, alpha_ema, R_new);
    end

    % =========================
    % 4) NO GOVERNANCE (faithful to Iqbal et al. 2020)
    % =========================
    % Iqbal's original paper has NO blacklisting, NO thresholds.
    % The model is purely EMA score update — providers always remain active.
    tierAction = "none";
    SVpro.isActive = true;
    SVpro.isWarning = false;
    SVpro.warningStreak = 0;
    SVpro.blackoutCounter = 0;

    % =========================
    % 5) Outputs
    % =========================
    updatedReputation = min(max(R_new, 0), 1);
    SVpro.reputation = updatedReputation;

    isActive = SVpro.isActive;
    isWarning = false;
    warningStreak = 0;
    blackoutCounter = SVpro.blackoutCounter;

    if VERBOSE
        fprintf('[Iqbal] %s: R=%.3f active=%d (scalar reward, no tiers)\n', ...
            SVproID, updatedReputation, isActive);
    end

    % =========================
    % 6) Logging
    % =========================
    if params.enableLogging
        row = struct();
        row.timestamp = string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
        row.runIndex = runIndex;
        row.globalRatio = double(maliciousPercentage);
        row.scenarioName = string(scenarioName);
        row.VreqiID = string(VreqiID);
        row.SVproID = string(SVproID);
        row.socialTrustLevel = string(SVpro.socialTrustLevel);
        row.isMalicious = double(isMalicious);
        row.current_R = double(current_R);
        row.success = double(success);
        row.tAll = double(tAll);
        row.MaxT = double(MaxT);
        row.reward = double(reward);
        row.alpha_ema = double(alpha_ema);
        row.R_new = double(R_new);
        row.R_postTier = double(updatedReputation);
        row.tierAction = string(tierAction);
        row.isActive = double(isActive);
        row.isWarning = double(isWarning);
        row.warningStreak = double(warningStreak);
        row.blackoutCounter = double(blackoutCounter);
        row.model = "Iqbal";

        logFile = strrep(params.logFile, 'reputation_trace', 'reputation_trace_Iqbal');
        writeReputationTrace(logFile, row);
    end
end
