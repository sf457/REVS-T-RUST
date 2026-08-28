function [CandidateVproj, SortedVproj, Trust_scores, SVpro, Updated_Vreqi, VprojBlockchainset] = ...
    SmartContract_reputationOnly(Vreqi, InteractionData, VprojBlockchainset, runIndex)
% SMARTCONTRACT_REPUTATIONONLY  Provider selection using ONLY reputation
%
% Selection Mechanism:
%   - Filter by same direction (physical constraint)
%   - Select provider with HIGHEST REPUTATION only
%   - NO stay time consideration
%   - NO tier awareness (warning/boost)
%   - NO minimum reputation threshold
%
% This is the appropriate selection for baseline models (Yang, Beta, etc.)
% that don't have RUST's sophisticated tier governance.
%
% Use Cases:
%   - Yang, BetaRec: Pure Bayesian trust, select by R
%   - Beta, SimpleAvg: Simple reputation models
%   - KangMWSL: Subjective logic without tiers
%
% Comparison:
%   - RUST uses: 0.7*R + 0.3*StayTime + tier preference + R_min filter
%   - Baselines use: max(R) only
%
% This ensures fair comparison by giving each model selection criteria
% appropriate to its design philosophy.

    Trust_scores = [];
    SortedVproj = [];
    SVpro = [];
    Updated_Vreqi = Vreqi;

    % A) Fetch available vehicles in RSU range
    [CandidateVproj, numProviders, numRequesters, VprojBlockchainset] = fetchCandidatePool(VprojBlockchainset, Vreqi);

    if numProviders < numRequesters || isempty(CandidateVproj)
        % disp('No suitable vehicle found for offloading.');  % Suppressed
        return;
    end

    % B) Filter by same direction ONLY (no reputation threshold)
    SortedVproj = filterSameDirection(CandidateVproj);

    if isempty(SortedVproj)
        % disp('No vehicles in same direction.');  % Suppressed
        return;
    end

    % C) Select by HIGHEST REPUTATION ONLY
    [SVpro, Trust_scores] = selectByReputationOnly(SortedVproj);

    if isempty(SVpro)
        warning('No provider selected.');
        return;
    end

    % D) Simulate V2V offloading
    [transmissionTime, executionTime, totalOffloadingLatency, totalCost, offloadingSuccessstatus] = ...
        V2VOffloading(Vreqi.Req, SVpro, Vreqi, runIndex);

    % E) Update interaction histories
    [SVpro, Updated_Vreqi, InteractionData] = updateInteractionHistories(...
        SVpro, Vreqi, InteractionData, offloadingSuccessstatus, ...
        transmissionTime, executionTime, totalOffloadingLatency, totalCost, runIndex);
end

function SortedVproj = filterSameDirection(CandidateVproj)
    % Filter by same direction only - NO reputation threshold
    % This allows all providers to be considered regardless of R
    SortedVproj = [];
    for i = 1:numel(CandidateVproj)
        v = CandidateVproj(i);
        if strcmp(v.direction, 'Same direction')
            SortedVproj = [SortedVproj, v];
        end
    end
end

function [SVpro, Trust_scores] = selectByReputationOnly(candidates)
    % Select provider with HIGHEST REPUTATION only
    % No stay time, no tier awareness, no thresholds
    %
    % This is the simplest reputation-based selection:
    %   Score = R
    %   Select = argmax(R)

    if isempty(candidates)
        SVpro = [];
        Trust_scores = [];
        return;
    end

    n = numel(candidates);
    Trust_scores = zeros(1, n);

    % Score = reputation only
    for i = 1:n
        Trust_scores(i) = candidates(i).reputation;
    end

    % Select highest reputation
    [~, idx] = max(Trust_scores);
    SVpro = candidates(idx);
end

function [SVpro, Updated_Vreqi, InteractionData] = updateInteractionHistories(...
    SVpro, Vreqi, InteractionData, offloadingSuccessstatus, ...
    transmissionTime, executionTime, totalOffloadingLatency, totalCost, runIndex)
    % Standard interaction history update
    %
    % IMPORTANT: Use blockchain data (SVpro.Offtransaction, Vreqi.Offtransaction)
    % as source of truth. Only initialize missing fields, never overwrite with
    % InteractionData cache.

    Updated_Vreqi = Vreqi;
    VreqiID = Vreqi.PID;
    SVproID = SVpro.PID;
    taskRequest = Vreqi.Req;
    tnMax = taskRequest.maxTt;
    recentReput = SVpro.reputation;
    isMalicious = SVpro.isMalicious;

    % E1. Ensure SVpro.Offtransaction has required fields (from blockchain)
    if ~isfield(SVpro.Offtransaction, 'numTransactions')
        SVpro.Offtransaction.numTransactions = struct();
        SVpro.Offtransaction.numSuccess = struct();
        SVpro.Offtransaction.numFailed = struct();
    end
    if ~isfield(SVpro.Offtransaction.numTransactions, VreqiID)
        SVpro.Offtransaction.numTransactions.(VreqiID) = 0;
        SVpro.Offtransaction.numSuccess.(VreqiID) = 0;
        SVpro.Offtransaction.numFailed.(VreqiID) = 0;
    end

    % E2. Ensure Updated_Vreqi.Offtransaction has required fields (from blockchain)
    % NOTE: Do NOT overwrite with InteractionData - blockchain is source of truth
    if ~isfield(Updated_Vreqi.Offtransaction, 'numTransactions')
        Updated_Vreqi.Offtransaction.numTransactions = struct();
        Updated_Vreqi.Offtransaction.numSuccess = struct();
        Updated_Vreqi.Offtransaction.numFailed = struct();
    end
    if ~isfield(Updated_Vreqi.Offtransaction.numTransactions, SVproID)
        Updated_Vreqi.Offtransaction.numTransactions.(SVproID) = 0;
        Updated_Vreqi.Offtransaction.numSuccess.(SVproID) = 0;
        Updated_Vreqi.Offtransaction.numFailed.(SVproID) = 0;
    end

    % E3. Update SVpro counters (increment from current blockchain state)
    SVpro.Offtransaction.numTransactions.(VreqiID) = SVpro.Offtransaction.numTransactions.(VreqiID) + 1;
    if offloadingSuccessstatus
        SVpro.Offtransaction.numSuccess.(VreqiID) = SVpro.Offtransaction.numSuccess.(VreqiID) + 1;
    else
        SVpro.Offtransaction.numFailed.(VreqiID) = SVpro.Offtransaction.numFailed.(VreqiID) + 1;
    end

    % E4. Update Vreqi counters
    Updated_Vreqi.Offtransaction.numTransactions.(SVproID) = Updated_Vreqi.Offtransaction.numTransactions.(SVproID) + 1;
    if offloadingSuccessstatus
        Updated_Vreqi.Offtransaction.numSuccess.(SVproID) = Updated_Vreqi.Offtransaction.numSuccess.(SVproID) + 1;
    else
        Updated_Vreqi.Offtransaction.numFailed.(SVproID) = Updated_Vreqi.Offtransaction.numFailed.(SVproID) + 1;
    end

    % E5. Store transaction details for SVpro
    SVpro.Offtransaction.TransactionsID = struct( ...
        'TransactionsID', [SVproID, '_', VreqiID], ...
        'VreqiID', VreqiID, ...
        'SVproisMalicious', isMalicious, ...
        'SVprorecentReput', recentReput, ...
        'offloadingSuccessstatus', offloadingSuccessstatus, ...
        'transmissionTime', transmissionTime, ...
        'executionTime', executionTime, ...
        'totalOffloadingLatency', totalOffloadingLatency, ...
        'totalCost', totalCost, ...
        'maximumTime', tnMax, ...
        'timestamp', datetime("now"), ...
        'runIndex', runIndex);

    if ~isfield(SVpro.Offtransaction, 'history') || isempty(SVpro.Offtransaction.history)
        SVpro.Offtransaction.history = SVpro.Offtransaction.TransactionsID;
    else
        SVpro.Offtransaction.history(end+1) = SVpro.Offtransaction.TransactionsID;
    end

    % E6. Store transaction details for Vreqi
    Updated_Vreqi.Offtransaction.TransactionsID = struct( ...
        'TransactionsID', [VreqiID, '_', SVproID], ...
        'SVproID', SVproID, ...
        'SVproisMalicious', isMalicious, ...
        'SVprorecentReput', recentReput, ...
        'offloadingSuccessstatus', offloadingSuccessstatus, ...
        'transmissionTime', transmissionTime, ...
        'executionTime', executionTime, ...
        'totalOffloadingLatency', totalOffloadingLatency, ...
        'totalCost', totalCost, ...
        'maximumTime', tnMax, ...
        'timestamp', datetime("now"), ...
        'runIndex', runIndex);

    if ~isfield(Updated_Vreqi.Offtransaction, 'history') || isempty(Updated_Vreqi.Offtransaction.history)
        Updated_Vreqi.Offtransaction.history = Updated_Vreqi.Offtransaction.TransactionsID;
    else
        Updated_Vreqi.Offtransaction.history(end+1) = Updated_Vreqi.Offtransaction.TransactionsID;
    end

    % E7. Save to InteractionData
    InteractionData.(SVproID) = SVpro.Offtransaction;
    InteractionData.(VreqiID) = Updated_Vreqi.Offtransaction;
end
