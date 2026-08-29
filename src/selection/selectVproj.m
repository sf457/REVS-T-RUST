% ---------------------------------------------------------------------------
% INACTIVE REFACTOR ("new selection trio"): NOT used for the frozen thesis
% results. Runs only when Params.useNewSelectionTrio = true (default = false).
% Kept for future consolidation of the selection pipeline. See docs/PROVENANCE.md.
% ---------------------------------------------------------------------------
function [SVpro, Trust_scores] = selectVproj(CandidateVproj, Vreqi, tierInfo)
%SELECTVPROJ  Score candidates in the active tier and pick the best.
%
% Replaces selectProviderTierAware (which conflated tier classification,
% R_min re-checking, and scoring). This function does only scoring +
% argmax — tier classification is upstream in classifyTiersVproj.
%
% Score:
%   Trust_score(i) = w1 * R(i) + w2 * normStayTime(i)
%
% Where:
%   - w1, w2 from Params (reputation vs stay-time weighting)
%   - normStayTime = stayTime / max(stayTime within active tier)
%
% Inputs:
%   CandidateVproj : from fetchVehicles2_clean
%   Vreqi          : requester (for stay-time computation)
%   tierInfo       : from classifyTiersVproj
%
% Outputs:
%   SVpro        : the selected provider (or [] if no eligible candidate)
%   Trust_scores : (1 x n) score per candidate, NaN for non-active-tier

    p = Params();
    w1 = p.w1;
    w2 = p.w2;

    n = numel(CandidateVproj);
    SVpro = [];
    Trust_scores = nan(1, n);

    if n == 0 || ~any(tierInfo.activeMask)
        return;
    end

    % --- Compute stay times for all candidates ---
    stayTimes = nan(1, n);
    for i = 1:n
        stayTimes(i) = calcStayTime(Vreqi, CandidateVproj(i));
    end

    % Restrict to active tier + finite stay time
    validMask = tierInfo.activeMask & isfinite(stayTimes);
    if ~any(validMask)
        return;
    end

    % --- Normalize stay time within the active tier ---
    validStayTimes = stayTimes(validMask);
    maxST = max(validStayTimes);
    normStayTimes = zeros(1, n);
    if maxST > 0
        validIdx = find(validMask);
        normStayTimes(validIdx) = stayTimes(validIdx) / maxST;
    end

    % --- Score active tier ---
    reputations = [CandidateVproj.reputation];
    for i = 1:n
        if validMask(i)
            Trust_scores(i) = w1*reputations(i) + w2*normStayTimes(i);
        end
    end

    % --- Argmax ---
    [~, bestIdx] = max(Trust_scores);
    if ~isempty(bestIdx) && ~isnan(bestIdx) && isfinite(Trust_scores(bestIdx))
        SVpro = CandidateVproj(bestIdx);
    end
end


function V2V_stayTime = calcStayTime(Vreqi, Vproj)
% (identical to the helper inside selectProviderTierAware.m)
    if ~isfield(Vreqi,'x') || ~isfield(Vreqi,'y') || ~isfield(Vreqi,'radius') || ...
       ~isfield(Vproj,'x') || ~isfield(Vproj,'y') || ~isfield(Vproj,'speed')
        V2V_stayTime = -Inf;
        return;
    end

    dx = double(Vproj.x) - double(Vreqi.x);
    dy = double(Vproj.y) - double(Vreqi.y);
    dist2   = dx*dx + dy*dy;
    radius2 = double(Vreqi.radius)^2;

    if dist2 > radius2
        V2V_stayTime = -Inf;
        return;
    end

    remainingDistance = sqrt(max(0, radius2 - dist2));
    relSpeed = abs(double(Vreqi.speed) - double(Vproj.speed));

    if relSpeed > 0
        V2V_stayTime = remainingDistance / relSpeed;
    else
        V2V_stayTime = Inf;
    end
end
