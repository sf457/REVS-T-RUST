function [SVpro, Trust_scores] = selectProviderMaxRep( ...
        CandidateVproj, Vreqi, w1, w2, R_warn, R_min)
%SELECTEDVPROJ2_MAXREP  Pure max-reputation selection for Threshold_MaxRep model.
%
% Policy:
%   - Selects the provider with the highest reputation above R_min
%   - No stay-time weighting (pure reputation-based selection)
%   - Used by Threshold_MaxRep model for baseline comparison
%
% Inputs:
%   CandidateVproj : array of candidate provider structs
%   Vreqi          : requester struct (unused, kept for interface compatibility)
%   w1, w2         : weights (unused, kept for interface compatibility)
%   R_warn         : warning threshold (unused for MaxRep)
%   R_min          : minimum reputation threshold
%
% Outputs:
%   SVpro          : selected provider struct (highest reputation)
%   Trust_scores   : reputation values used as scores

    SVpro        = [];
    Trust_scores = [];

    if isempty(CandidateVproj)
        return;
    end

    numCandidates = numel(CandidateVproj);

    % Get reputations
    reputations = [CandidateVproj.reputation];

    % Filter by minimum threshold only (no tier logic)
    baseMask = reputations >= R_min;

    if ~any(baseMask)
        Trust_scores = nan(1, numCandidates);
        return;
    end

    % Trust scores are simply the reputation values
    Trust_scores = nan(1, numCandidates);
    Trust_scores(baseMask) = reputations(baseMask);

    % Select provider with highest reputation
    [~, bestIdx] = max(Trust_scores);
    if isempty(bestIdx) || isnan(bestIdx)
        SVpro = [];
    else
        SVpro = CandidateVproj(bestIdx);
    end
end
