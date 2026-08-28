function [SVpro, Trust_scores] = selectProviderNoTier( ...
        CandidateVproj, Vreqi, w1, w2, ~, R_min)
%SELECTEDVPROJ2_NOTIER  Selection WITHOUT tier awareness (baseline comparison).
%
% Policy:
%   - Score = w1*R + w2*normalizedStayTime for ALL eligible candidates
%   - NO warning-tier penalty
%   - NO strict tier separation (good/warning compete equally)
%   - Only R >= R_min filtering (basic eligibility)
%
% This represents the "old" selection algorithm before tier governance was
% added. Used to demonstrate the improvement from tier-aware selection.
%
% Comparison with current policies:
%   NoTier:            All R >= R_min compete equally
%   Penalty:           Warning-tier gets -0.10 penalty
%   StrictTier:        Good-tier preferred, warning only as fallback
%   PenaltyUncertainty: Penalty + uncertainty deduction

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

    % 2) Basic eligibility: R >= R_min and finite stay time
    reputations = [CandidateVproj.reputation];
    eligibleMask = isfinite(stayTimes) & (reputations >= R_min);

    if ~any(eligibleMask)
        Trust_scores = nan(1, numCandidates);
        return;
    end

    % 3) NO TIER LOGIC — all eligible candidates compete equally

    % 4) Normalize stay time among eligible candidates
    validIdx       = find(eligibleMask);
    validStayTimes = stayTimes(validIdx);

    normStayTimes = zeros(1, numCandidates);
    maxST = max(validStayTimes);
    if maxST > 0
        normStayTimes(validIdx) = validStayTimes / maxST;
    end

    % 5) Compute scores — NO penalty, NO tier exclusion
    Trust_scores = nan(1, numCandidates);
    for i = 1:numCandidates
        if eligibleMask(i)
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
