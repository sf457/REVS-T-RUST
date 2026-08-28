function [updatedReputation, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
    calculateReputationRUST2_v3(SVpro, runIndex, Updated_Vreqi, blockchainObj, maliciousPercentage, scenarioName)
%CALCULATEREPUTATIONRUST2_V3  [DEPRECATED] Per-requester dynamic honesty shim.
%
% DEPRECATED: calculateReputationRUST2_v2.m is now natively per-pair
% (per-(requester,provider) DH counters localSuccessStreak/localTotalInteractions)
% with delta_c=0.15, delta_e=0.10, so RUST == RUST-PerReq and this wrapper is
% no longer used by the dispatch in simulationUtils.m. It is retained only for
% history. Do NOT call it: its post-call step writes globalSuccessStreak back
% into the local slots, which v2 no longer updates (v2 updates the local slots
% directly), so calling v3 would overwrite v2's per-pair increment with a stale
% value. Use calculateReputationRUST2_v2 directly.
%
% Ablation B variant of v2. Two changes vs v2:
%
%   1) DH streak/interaction counters are PER-REQUESTER, not global.
%      v2 maintains SVpro.globalSuccessStreak / globalFailureStreak /
%      globalTotalInteractions and feeds these to the embedded
%      calculateHonestyDynamic(). v3 maintains per-requester analogs
%      SVpro.localSuccessStreak.(VreqiID) etc., and feeds those.
%
%      Rationale: Subjective Logic opinions are subjective. A provider's
%      behaviour with requester R_a is not evidence for requester R_b's
%      opinion. Globalising the streak/interaction count injects
%      cross-requester information into the local-opinion update.
%
%   2) DH success bonuses are RESCALED to per-pair scale. v2's defaults
%      were calibrated for global counters where ws_global ~ 6 and
%      n_global > 10 saturate the caps. Per-requester counters stay small
%      (typical ws_local ~ {0..2}, n_local ~ {0..3}), so v2's rates leave
%      the bonuses largely silent. v3 rescales:
%         consistencyBonusPerSuccess    : 0.05 -> 0.15  (saturates at ws_local=2)
%         experienceBonusPerInteraction : 0.02 -> 0.10  (saturates at n_local=2)
%      Caps unchanged (B_c=0.30, B_e=0.20). Net effect: same maximum
%      bonus contribution, but it now fires at the per-pair scale.
%      This preserves the "Dynamic Honesty" mechanism (H grows with
%      observed behaviour) while routing through subjective evidence.
%
% Implementation strategy: this function is a thin wrapper around v2.
% It (a) reads the per-requester local counters, (b) writes them into
% the globalSuccessStreak / globalFailureStreak / globalTotalInteractions
% fields so v2's body sees them, (c) zeroes the success-bonus rates in
% the Params snapshot v2 reads, (d) calls v2, then (e) reads back the
% updated values from the (now-misnamed) global fields and persists
% them into the proper per-requester slots, and (f) restores Params.
%
% This approach minimises code duplication. The honest cost: v2's
% lifecycle-trace recorder will report globalSuccessStreak as the
% LOCAL value, since v3 overwrites it before delegation. Diagnostic
% scripts that read globalSuccessStreak as a network-wide signal will
% need updating. Mark this in the ablation write-up.

    %% --- 1) Resolve requester ID (same logic as v2 top-of-body) ---
    VreqiID = Updated_Vreqi.PID;
    if ~ischar(VreqiID) && ~isstring(VreqiID)
        VreqiID = char(VreqiID);
    end
    VreqiID = matlab.lang.makeValidName(VreqiID);

    %% --- 2) Initialise per-requester counter maps if missing ---
    if ~isfield(SVpro, 'localSuccessStreak')      || ~isstruct(SVpro.localSuccessStreak)
        SVpro.localSuccessStreak = struct();
    end
    if ~isfield(SVpro, 'localFailureStreak')      || ~isstruct(SVpro.localFailureStreak)
        SVpro.localFailureStreak = struct();
    end
    if ~isfield(SVpro, 'localTotalInteractions')  || ~isstruct(SVpro.localTotalInteractions)
        SVpro.localTotalInteractions = struct();
    end

    localSuc  = getLocal(SVpro.localSuccessStreak,     VreqiID);
    localFail = getLocal(SVpro.localFailureStreak,     VreqiID);
    localN    = getLocal(SVpro.localTotalInteractions, VreqiID);

    %% --- 3) Save v2 global fields and overwrite with local ---
    savedGlobalSuc  = getField(SVpro, 'globalSuccessStreak',     0);
    savedGlobalFail = getField(SVpro, 'globalFailureStreak',     0);
    savedGlobalN    = getField(SVpro, 'globalTotalInteractions', 0);

    SVpro.globalSuccessStreak     = localSuc;
    SVpro.globalFailureStreak     = localFail;
    SVpro.globalTotalInteractions = localN;

    %% --- 4) Rescale bonus rates for per-pair counter scale ---
    % Use Params(overrides) so anything v2 reads from Params() sees the
    % rescaled rates. Restored after delegation.
    %   0.05 -> 0.15  (consistency bonus saturates at ws_local = 2)
    %   0.02 -> 0.10  (experience  bonus saturates at n_local  = 2)
    % Caps unchanged.
    savedParams = Params();
    Params(struct( ...
        'consistencyBonusPerSuccess',    0.15, ...
        'experienceBonusPerInteraction', 0.10));

    %% --- 5) Delegate to v2 ---
    try
        [updatedReputation, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
            calculateReputationRUST2_v2(SVpro, runIndex, Updated_Vreqi, blockchainObj, ...
                                         maliciousPercentage, scenarioName);
    catch ME
        % Always restore Params on failure
        Params(struct( ...
            'consistencyBonusPerSuccess',    savedParams.consistencyBonusPerSuccess, ...
            'experienceBonusPerInteraction', savedParams.experienceBonusPerInteraction));
        rethrow(ME);
    end

    %% --- 6) Persist the post-call values to per-requester slots ---
    % v2 has already incremented globalSuccessStreak / etc. based on
    % the outcome (using the local-as-global values we injected). So
    % these post-call fields hold the *new* local counter values.
    SVpro.localSuccessStreak.(VreqiID)     = SVpro.globalSuccessStreak;
    SVpro.localFailureStreak.(VreqiID)     = SVpro.globalFailureStreak;
    SVpro.localTotalInteractions.(VreqiID) = SVpro.globalTotalInteractions;

    %% --- 7) Restore v2's actual global fields ---
    SVpro.globalSuccessStreak     = savedGlobalSuc;
    SVpro.globalFailureStreak     = savedGlobalFail;
    SVpro.globalTotalInteractions = savedGlobalN;

    %% --- 8) Restore Params ---
    Params(struct( ...
        'consistencyBonusPerSuccess',    savedParams.consistencyBonusPerSuccess, ...
        'experienceBonusPerInteraction', savedParams.experienceBonusPerInteraction));
end


% ---------------- helpers ----------------
function v = getLocal(s, fieldName)
    if isfield(s, fieldName) && ~isempty(s.(fieldName)) && isnumeric(s.(fieldName))
        v = double(s.(fieldName));
    else
        v = 0;
    end
end

function v = getField(s, fieldName, defaultVal)
    if isfield(s, fieldName) && ~isempty(s.(fieldName)) && isnumeric(s.(fieldName))
        v = double(s.(fieldName));
    else
        v = defaultVal;
    end
end
