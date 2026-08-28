function [updatedReputation, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
    calculateReputationIqbal2(SVpro, runIndex, Updated_Vreqi, InteractionData, maliciousPercentage, scenarioName)
% CALCULATEREPUTATIONIQBAL2
% MODEL: Iqbal et al. (2020) - Faithful Paper Implementation
%
% Reference: Iqbal et al. "Trust Management in Vehicular Networks" Section III-D
%
% This implementation follows the EXACT paper specification:
%
% REPUTATION UPDATE - CUMULATIVE (not EMA):
%   "The reward ρᵢ at time instant i is defined as: ρᵢ = ρᵢ₋₁ + l"
%   Score is unbounded upward (grows forever with successes)
%
% REWARD FUNCTION (Equation 5):
%   l = λΩ / (Ω - Tₜ)   if Tₜ < Ω (success)
%   l = 0               otherwise (failure)
%
%   Where: Ω = deadline (MaxT), Tₜ = actual latency, λ = scaling factor
%
% GOVERNANCE - NONE:
%   No blacklist thresholds, no warning tiers, no freeze periods
%   Vehicles are selected purely by accumulated score
%
% KEY DIFFERENCES FROM IQBAL (EMA adaptation):
%   - Cumulative update (paper) vs EMA update (Iqbal model)
%   - Correct reward formula without regularisation term
%   - No governance at all (paper) vs threshold blacklisting (Iqbal model)
%   - Unbounded score vs [0,1] bounded (Iqbal model)
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
%   updatedReputation : scalar ρ (UNBOUNDED, can exceed 1.0)
%   isActive          : always 1 (no governance)
%   isWarning         : always 0 (no warning tier)
%   warningStreak     : always 0 (no streak tracking)
%   blackoutCounter   : always 0 (no blackout)
%   SVpro             : updated provider struct

    params = Params();
    VERBOSE = params.VERBOSE;

    % =========================
    % 1) Basic extraction
    % =========================
    VreqiID = Updated_Vreqi.PID;
    SVproID = SVpro.PID;
    SVpro_Offtx = SVpro.Offtransaction;
    current_rho = SVpro.reputation;  % Cumulative reputation (ρ)
    isMalicious = SVpro.isMalicious;

    TX = SVpro_Offtx.TransactionsID;
    tAll = TX.totalOffloadingLatency;      % Actual latency Tₜ (ms)
    MaxT = TX.maximumTime;                  % Deadline Ω (ms)
    success = double(TX.offloadingSuccessstatus);

    if VERBOSE
        fprintf('\n[Iqbal2][Run %d] Update rep for %s (req=%s)\n', runIndex, SVproID, VreqiID);
    end

    % =========================
    % 2) Iqbal Reward Function (Equation 5 - EXACT)
    % =========================
    % l = λΩ / (Ω - Tₜ)  when Tₜ < Ω (success)
    % l = 0              when Tₜ >= Ω (failure)
    %
    % NOTE: The paper uses λΩ/(Ω - Tₜ) without any regularisation term.
    % The reward blows up numerically as Tₜ → Ω. We guard against this
    % by setting reward=0 for near-deadline completions (semantically:
    % barely making the deadline shouldn't yield infinite reward).

    lambda = 0.1;  % Scaling factor (from paper)

    if success == 1 && tAll < MaxT
        % CORRECT formula per Equation 5: λΩ / (Ω - Tₜ)
        if (MaxT - tAll) < 1e-6
            % Near-deadline edge case: avoid numerical blowup
            reward = 0;
        else
            reward = lambda * MaxT / (MaxT - tAll);
        end
    else
        % Failed task: zero reward
        reward = 0;
    end

    if VERBOSE
        fprintf('[Iqbal2] tAll=%.1f ms, MaxT=%.1f ms, success=%d → reward=%.3f\n', ...
            tAll, MaxT, success, reward);
    end

    % =========================
    % 3) Cumulative Update (Paper Section III-D)
    % =========================
    % "The reward ρᵢ at time instant i is defined as: ρᵢ = ρᵢ₋₁ + l"
    % This is simple accumulation - rewards stack up indefinitely.
    % NO EMA, NO decay, NO forgetting. Score is unbounded upward.

    rho_new = current_rho + reward;

    if VERBOSE
        fprintf('[Iqbal2] ρ_old=%.3f + l=%.3f → ρ_new=%.3f (CUMULATIVE)\n', ...
            current_rho, reward, rho_new);
    end

    % =========================
    % 4) NO Governance (Paper has zero governance)
    % =========================
    % No blacklist thresholds, no warning tiers, no freeze periods, no R_min.
    % Vehicles are selected purely by accumulated score and workload.

    SVpro.isActive = true;
    SVpro.isWarning = false;
    SVpro.warningStreak = 0;
    SVpro.blackoutCounter = 0;

    tierAction = "none";  % No tier system exists

    % =========================
    % 5) Outputs
    % =========================
    % NOTE: Reputation is UNBOUNDED (can exceed 1.0)
    % This is faithful to the paper's cumulative scheme
    updatedReputation = rho_new;
    SVpro.reputation = updatedReputation;

    isActive = true;       % Always active (no governance)
    isWarning = false;     % No warning tier
    warningStreak = 0;     % No streak tracking
    blackoutCounter = 0;   % No blackout

    if VERBOSE
        fprintf('[Iqbal2] %s: ρ=%.3f active=1 (cumulative, no governance)\n', ...
            SVproID, updatedReputation);
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
        row.current_rho = double(current_rho);
        row.success = double(success);
        row.tAll = double(tAll);
        row.MaxT = double(MaxT);
        row.reward = double(reward);
        row.rho_new = double(rho_new);
        row.tierAction = string(tierAction);
        row.isActive = double(isActive);
        row.isWarning = double(isWarning);
        row.warningStreak = double(warningStreak);
        row.blackoutCounter = double(blackoutCounter);
        row.model = "Iqbal2";

        logFile = strrep(params.logFile, 'reputation_trace', 'reputation_trace_Iqbal2');
        writeReputationTrace(logFile, row);
    end
end
