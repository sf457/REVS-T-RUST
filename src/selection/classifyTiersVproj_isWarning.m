% ---------------------------------------------------------------------------
% INACTIVE REFACTOR ("new selection trio"): NOT used for the frozen thesis
% results. Runs only when Params.useNewSelectionTrio = true (default = false).
% Kept for future consolidation of the selection pipeline. See docs/PROVENANCE.md.
% ---------------------------------------------------------------------------
function [activeMask, tierInfo] = classifyTiersVproj_isWarning(CandidateVproj)
%CLASSIFYTIERSVPROJ_ISWARNING  Tier classification using governance flag.
%
% Ablation A variant of classifyTiersVproj. Replaces the R > R_warn test
% with the governance-set isWarning flag. The motivation:
%
%   classifyTiersVproj         : tier = (R > R_warn) -- instantaneous R
%   classifyTiersVproj_isWarning: tier = ~isWarning  -- governance state
%
% isWarning is set inside computeReputationRUST.m by the 4-tier
% governance block. It is true when (R <= R_warn) AND ws >= escalation
% threshold, false on recovery. So it carries warningStreak history that
% pure R does not.
%
% Expected paper-relevant differences vs the R-based variant:
%   * a provider with R = 0.48 but ws = 0 is *not* Warning here (Good).
%     Under R-based classification it would be Warning.
%   * a provider with R = 0.55 but ws ~= 4 (rising) *is* Warning here.
%     Under R-based classification it would be Good.
%
% Hypothesis: this tier signal is closer to "trust-tier" in the paper's
% sense than R-based classification, and may reduce FPR_gov by not
% punishing one-off R dips on otherwise-stable providers.
%
% Wire-up: switch SmartContract.m STRICTTIER's classifyTiersVproj() call
% to this function and re-run the smoke. The selectVproj() call is
% unchanged -- only the masks change.
%
% Inputs / outputs: identical to classifyTiersVproj.

    p = Params();
    R_warn = p.R_warn;  % kept for fallback path below

    n = numel(CandidateVproj);
    if n == 0
        activeMask = false(1, 0);
        tierInfo = struct('goodMask', false(1,0), 'warningMask', false(1,0), ...
                          'shadowMask', false(1,0), 'activeMask', false(1,0));
        return;
    end

    reputations = [CandidateVproj.reputation];

    % --- Shadow demotion (opt-in via Params.useBlacklistShadow) ---
    % Same logic as classifyTiersVproj. Providers with prior blackout
    % history are demoted to Warning regardless of governance flag.
    shadowMask = false(1, n);
    if isfield(p,'useBlacklistShadow') && p.useBlacklistShadow
        for i = 1:n
            if isfield(CandidateVproj(i), 'totalBlacklists') && ...
               ~isempty(CandidateVproj(i).totalBlacklists) && ...
               double(CandidateVproj(i).totalBlacklists) > 0
                shadowMask(i) = true;
            end
        end
    end

    % --- Tier classification by isWarning flag ---
    % If isWarning field is missing on a candidate (e.g., a model that
    % does not set it), fall back to the R-based test for that candidate
    % so this variant remains safe across the full model matrix.
    warningFlags = false(1, n);
    for i = 1:n
        if isfield(CandidateVproj(i), 'isWarning') && ...
           ~isempty(CandidateVproj(i).isWarning)
            warningFlags(i) = logical(CandidateVproj(i).isWarning);
        else
            % Fallback: instantaneous R test
            warningFlags(i) = reputations(i) <= R_warn;
        end
    end

    goodMask    = ~warningFlags & ~shadowMask;
    warningMask = warningFlags | shadowMask;

    % --- Strict tier preference: Good if any exist, else Warning fallback ---
    if any(goodMask)
        activeMask = goodMask;
    elseif any(warningMask)
        activeMask = warningMask;
    else
        activeMask = false(1, n);
    end

    tierInfo = struct('goodMask', goodMask, 'warningMask', warningMask, ...
                      'shadowMask', shadowMask, 'activeMask', activeMask);
end
