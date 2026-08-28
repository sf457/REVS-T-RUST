function [updatedReputation, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
    calculateReputation3VSLBinary(SVpro, runIndex, Updated_Vreqi, InteractionData, maliciousPercentage, scenarioName)
% CALCULATEREPUTATION3VSLBINARY 3VSL-Binary model without tiered governance
%
% This implements the 3VSL-Binary reputation mechanism for fair comparison.
% KEY DIFFERENCE FROM RUST/THRESHOLD: NO tier-based actions (warning/blacklist)
%
% What this model does:
%   1. Simple evidence update: α++ for success, β++ for failure
%   2. Subjective logic opinion: b=α/S, d=β/S, u=γ/S
%   3. Scalar reputation: R = b + a0*u
%   4. NO governance enforcement - provider always selectable
%
% Purpose:
%   Shows that reputation tracking alone (without governance) does NOT
%   prevent malicious providers from being selected and causing damage.
%   Detection ≠ Action
%
% Inputs:
%   SVpro          : selected provider struct
%   runIndex       : current simulation index
%   Updated_Vreqi  : requester struct
%   InteractionData: struct of historical transactions
%   maliciousPercentage: global malicious ratio
%   scenarioName   : scenario identifier
%
% Outputs:
%   updatedReputation : scalar R = b + a0*u
%   isActive          : always 1 (no blacklist)
%   isWarning         : always 0 (no warning tier)
%   warningStreak     : always 0 (no streak tracking)
%   blackoutCounter   : always 0 (never frozen)
%   SVpro             : updated provider struct

    % =========================
    % 1) Parameters
    % =========================
    params  = Params();
    VERBOSE = params.VERBOSE;
    a0      = params.a0;  % Base rate for uncertainty in R calculation

    % =========================
    % 2) Basic extraction
    % =========================
    VreqiID       = Updated_Vreqi.PID;
    SVproID       = SVpro.PID;
    SVpro_Offtx   = SVpro.Offtransaction;
    current_R     = SVpro.reputation;
    isMalicious   = SVpro.isMalicious;

    TX      = SVpro_Offtx.TransactionsID;
    success = double(TX.offloadingSuccessstatus);

    if VERBOSE
        fprintf('\n[3VSL-Binary][Run %d] Update rep for %s (req=%s)\n', runIndex, SVproID, VreqiID);
    end

    % =========================
    % 3) Simple Evidence Update (Xu et al. style)
    % =========================
    % α++ for success, β++ for failure
    % γ remains unchanged (represents initial uncertainty)

    alpha = SVpro_Offtx.numAlpha.(VreqiID);
    beta  = SVpro_Offtx.numBeta.(VreqiID);
    gamma = SVpro_Offtx.numGamma.(VreqiID);

    if success == 1
        alpha = alpha + 1;  % Success → increase belief
    else
        beta = beta + 1;    % Failure → increase distrust
    end

    % Persist updated evidence
    SVpro.Offtransaction.numAlpha.(VreqiID) = alpha;
    SVpro.Offtransaction.numBeta.(VreqiID)  = beta;
    SVpro.Offtransaction.numGamma.(VreqiID) = gamma;

    % =========================
    % 4) Subjective Logic Opinion
    % =========================
    S = alpha + beta + gamma;
    b = alpha / S;  % Belief
    d = beta / S;   % Distrust
    u = gamma / S;  % Uncertainty

    if VERBOSE
        fprintf('[3VSL-Binary] Evidence: α=%d, β=%d, γ=%d → b=%.3f, d=%.3f, u=%.3f\n', ...
            alpha, beta, gamma, b, d, u);
    end

    % =========================
    % 5) Scalar Reputation
    % =========================
    R = b + a0 * u;

    if VERBOSE
        fprintf('[3VSL-Binary] R = b + a0*u = %.3f + %.2f*%.3f = %.4f\n', b, a0, u, R);
    end

    % =========================
    % 6) NO GOVERNANCE (Key difference)
    % =========================
    % 3VSL-Binary tracks reputation for "detection" but specifies no
    % enforcement actions. Provider remains selectable regardless of R.

    SVpro.isActive = true;        % Always active - never blacklisted
    SVpro.isWarning = false;      % No warning tier
    SVpro.blackoutCounter = 0;    % Never frozen
    SVpro.warningStreak = 0;      % No streak tracking

    % Initialize totalBlacklists if missing (will always be 0)
    if ~isfield(SVpro, 'totalBlacklists')
        SVpro.totalBlacklists = 0;
    end

    % =========================
    % 7) Outputs
    % =========================
    updatedReputation = min(max(R, 0), 1);
    SVpro.reputation  = updatedReputation;

    isActive        = true;   % Always active
    isWarning       = false;  % No warning tier
    warningStreak   = 0;      % No streak
    blackoutCounter = 0;      % Never frozen

    if VERBOSE
        fprintf('[3VSL-Binary] %s: R=%.3f (NO GOVERNANCE - always active)\n', ...
            SVproID, updatedReputation);
    end

    % =========================
    % 8) Logging (optional)
    % =========================
    if params.enableLogging
        row = struct();
        row.timestamp     = string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
        row.runIndex      = runIndex;
        row.globalRatio   = double(maliciousPercentage);
        row.scenarioName  = string(scenarioName);
        row.VreqiID       = string(VreqiID);
        row.SVproID       = string(SVproID);
        row.socialTrustLevel = string(SVpro.socialTrustLevel);
        row.isMalicious      = double(isMalicious);
        row.current_R        = double(current_R);
        row.success          = double(success);
        row.alpha_after      = double(alpha);
        row.beta_after       = double(beta);
        row.gamma_after      = double(gamma);
        row.b                = double(b);
        row.d                = double(d);
        row.u                = double(u);
        row.R_final          = double(updatedReputation);
        row.tierAction       = "none";  % 3VSL-Binary takes no tier-based action
        row.isActive         = 1;       % Always active
        row.isWarning        = 0;
        row.warningStreak    = 0;
        row.blackoutCounter  = 0;
        row.model            = "3VSL-Binary";

        logFile = strrep(params.logFile, 'reputation_trace', 'reputation_trace_3VSL-Binary');
        writeReputationTrace(logFile, row);
    end
end
