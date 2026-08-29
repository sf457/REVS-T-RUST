function [SVpro, Trust_scores] = selectProviderTierAware( ...
        CandidateVproj, Vreqi, w1, w2, R_warn, R_min)
%SELECTEDVPROJ2_STRICTTIER  Strict tier-based selection (ablation variant).
%
% Policy:
%   - Good-tier providers (R > R_warn) are strongly preferred
%   - Warning-tier providers (R_min <= R <= R_warn) used ONLY if no good-tier exists
%   - This creates a single-point-of-failure: if all good-tier providers are
%     malicious, the system has no fallback competition from warning-tier
%
% This is the "old" selection policy for ablation comparison.

    SVpro        = [];
    Trust_scores = [];

    if isempty(CandidateVproj)
        return;
    end

    numCandidates = numel(CandidateVproj);

    % 1) Mobility: predicted stay time
    stayTimes = nan(1, numCandidates);
    for i = 1:numCandidates
        stayTimes(i) = calcStayTime(Vreqi, CandidateVproj(i));
    end

    % 2) Base feasibility
    reputations = [CandidateVproj.reputation];
    baseMask = isfinite(stayTimes) & (reputations >= R_min);

    if ~any(baseMask)
        Trust_scores = nan(1, numCandidates);
        return;
    end

    % 3) Strict tier preference: good-tier first, warning-tier only as fallback
    goodMask    = baseMask & (reputations > R_warn);
    warningMask = baseMask & (reputations >= R_min) & (reputations <= R_warn);

    if any(goodMask)
        activeMask = goodMask;
    elseif any(warningMask)
        activeMask = warningMask;
    else
        Trust_scores = nan(1, numCandidates);
        return;
    end

    % 4) Normalize stay time among active candidates
    validIdx       = find(activeMask);
    validStayTimes = stayTimes(validIdx);

    normStayTimes = zeros(1, numCandidates);
    maxST = max(validStayTimes);
    if maxST > 0
        normStayTimes(validIdx) = validStayTimes / maxST;
    end

    % 5) Compute scores (tier exclusion handles penalties)
    Trust_scores = nan(1, numCandidates);
    for i = 1:numCandidates
        if activeMask(i)
            Trust_scores(i) = w1 * reputations(i) + w2 * normStayTimes(i);
        end
    end

    % 6) Select best
    [~, bestIdx] = max(Trust_scores);
    if isempty(bestIdx) || isnan(bestIdx)
        SVpro = [];
    else
        SVpro = CandidateVproj(bestIdx);
    end
end


function V2V_stayTime = calcStayTime(Vreqi, Vproj)
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
