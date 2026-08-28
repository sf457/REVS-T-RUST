function [CandidateVproj, SortedCanditateVproj_R_D,Trust_scores,SVpro,Updated_Vreqi,VprojBlockchainset] = SmartContract(Vreqi,InteractionData,VprojBlockchainset, runIndex, selectionPolicy)
%SMARTCONTRACT  RSU-mediated provider selection and offloading orchestration
%
% =========================================================================
% DATA OWNERSHIP MODEL - BLOCKCHAIN AS SINGLE SOURCE OF TRUTH
% =========================================================================
%
% BLOCKCHAIN (Distributed Ledger - Maintained by RSU)
% ─────────────────────────────────────────────────────
%   • Single source of truth for all vehicle data
%   • Replicated across all RSU nodes (distributed ledger)
%   • Each RSU maintains a copy; consensus ensures consistency
%   • Abstract implementation for simulation (focus on reputation algorithms)
%
%   Block.data stores:
%   ┌─────────────────────────────────────────────────────────────────────┐
%   │  VEHICLE STATE (Provider or Requester)                              │
%   ├─────────────────────────────────────────────────────────────────────┤
%   │  Identity:                                                          │
%   │    • PID, VehicleRole, publicKey, privateKey                       │
%   │                                                                     │
%   │  Trust & Reputation:                                                │
%   │    • reputation (current R value)                                  │
%   │    • socialTrustLevel (high/intermediate/low)                      │
%   │    • isActive, isWarning, blackoutCounter, warningStreak           │
%   │                                                                     │
%   │  Resources:                                                         │
%   │    • computationCapacity, transmissionRate                         │
%   │    • x, y, direction, speed, RSU_ID                                │
%   │                                                                     │
%   │  Transaction History (Offtransaction):                             │
%   │    • numTransactions.(reqID) - count per requester                 │
%   │    • numSuccess.(reqID)      - successes per requester             │
%   │    • numFailed.(reqID)       - failures per requester              │
%   │    • numAlpha/Beta/Gamma     - Jøsang evidence per requester       │
%   │    • history[]               - full transaction log                │
%   └─────────────────────────────────────────────────────────────────────┘
%
% DATA FLOW
% ─────────
%   1. RSU reads blockchain → provides candidate list to requester
%   2. SmartContract executes selection & offloading
%   3. Reputation calculated based on outcome
%   4. Blockchain updated (primary write)
%   5. InteractionData synced (cache for efficiency)
%
%   ┌─────────────┐     query      ┌─────────────┐
%   │  Requester  │ ───────────→  │     RSU     │
%   │             │               │  (has full  │
%   │  • Cannot   │  ←─────────── │  blockchain)│
%   │    read     │   candidates  │             │
%   │    chain    │               │  • Selects  │
%   │    directly │               │    provider │
%   └─────────────┘               │  • Updates  │
%                                 │    chain    │
%   ┌─────────────┐               │             │
%   │  Provider   │ ←───────────  └─────────────┘
%   │             │    task          │
%   │  • Cannot   │                  │ updates
%   │    modify   │                  ↓
%   │    own rep  │         ┌───────────────┐
%   └─────────────┘         │  BLOCKCHAIN   │
%                           │  (distributed │
%                           │   ledger)     │
%                           └───────────────┘
%
% =========================================================================
%
% Inputs:
%   Vreqi                : requester struct (must have PID and Req)
%   InteractionData      : cache of blockchain Offtransaction data
%   VprojBlockchainset   : array of provider blocks (chain entries with .data)
%   runIndex             : simulation index
%
% Outputs:
%   CandidateVproj                 : array of candidate provider blocks
%   SortedCanditateVproj_R_D       : sorted candidate providers (struct array)
%   Trust_scores                   : selection scores
%   SVpro                          : selected provider (updated state)
%   Updated_Vreqi                  : requester (updated state)
%
% Post-call (in runSimulationScenarios):
%   Blockchain updated first (single source of truth), then InteractionData synced
%
% See also: runSimulationScenarios, fetchCandidatePool, filterAndSortCandidates, V2VOffloading

% Initialize outputs & Weight Parameteres
Trust_scores = [];
SortedCanditateVproj_R_D = [];
SVpro = [];
Updated_Vreqi=Vreqi;

% Load weights from Params (optimal: w1=0.6, w2=0.4)
 p = Params();
 w1 = p.w1;  % Weight for reputation
 w2 = p.w2;  % Weight for stay time
 R_min = p.R_min;
 R_warn = p.R_warn;
 % A) Candidate providers
% Fetch available vehicles (Vproj) in the RSU range. When the opt-in
% Params.useNewSelectionTrio is true, use the refactored fetcher which
% performs all eligibility filtering in one pass (sameRSU, isActive,
% ~permaban, sameDirection, R >= R_min) and returns a ready-to-classify
% candidate list.
if isfield(p, 'useNewSelectionTrio') && p.useNewSelectionTrio
    [CandidateVproj, numProviders, numRequesters, VprojBlockchainset] = ...
        fetchVehicles2_clean(VprojBlockchainset, Updated_Vreqi);
else
    [CandidateVproj, numProviders, numRequesters, VprojBlockchainset] = ...
        fetchCandidatePool(VprojBlockchainset, Updated_Vreqi);
end
if numProviders < numRequesters
        % disp('Not enough available vehicles found to select.');
        return;
 end
 % disp('CanditateVproj vehicle set details:');
 %        for i = 1:numel(CandidateVproj)
 %            % disp(CandidateVproj(i).data);
 %            % disp('---------------------------------------');
 %        end

  % B) Sort / classify CanditateVproj
    if isfield(p, 'useNewSelectionTrio') && p.useNewSelectionTrio
        % New trio skips filterAndSortCandidates (vestigial after argmax selection)
        % and goes straight to tier classification.
        if isempty(CandidateVproj)
            return;
        end
        SortedCanditateVproj_R_D = CandidateVproj;
    else
        SortedCanditateVproj_R_D = filterAndSortCandidates(CandidateVproj);
        if isempty(SortedCanditateVproj_R_D)
            return;
        end
    end

        %  C) Select the best provider (SVpro) that meets the criteria
        if nargin < 5 || isempty(selectionPolicy)
            selectionPolicy = 'StrictTier';  % Default: strict tier-based selection
        end
        switch upper(selectionPolicy)
            case 'STRICTTIER'
                if isfield(p, 'useNewSelectionTrio') && p.useNewSelectionTrio
                    % Ablation A: optionally use isWarning-based tier
                    % classification instead of R > R_warn.
                    if isfield(p, 'useIsWarningTier') && p.useIsWarningTier
                        [~, tierInfo] = classifyTiersVproj_isWarning(SortedCanditateVproj_R_D);
                    else
                        [~, tierInfo] = classifyTiersVproj(SortedCanditateVproj_R_D);
                    end
                    [SVpro, Trust_scores] = selectVproj(SortedCanditateVproj_R_D, Updated_Vreqi, tierInfo);
                else
                    [SVpro, Trust_scores] = selectProviderTierAware(SortedCanditateVproj_R_D, Updated_Vreqi, w1, w2, R_warn, R_min);
                end
            case 'NOTIER'
                [SVpro, Trust_scores] = selectProviderNoTier(SortedCanditateVproj_R_D, Updated_Vreqi, w1, w2, R_warn, R_min);
            case 'MAXREP'
                [SVpro, Trust_scores] = selectProviderMaxRep(SortedCanditateVproj_R_D, Updated_Vreqi, w1, w2, R_warn, R_min);
            otherwise
                [SVpro, Trust_scores] = selectProviderTierAware(SortedCanditateVproj_R_D, Updated_Vreqi, w1, w2, R_warn, R_min);
        end
        %SVpro = SelectedVprojRandom(SortedCanditateVproj_R_D); % for
        %random selection 
        % Ensure SVproID is properly initialized
        if isempty(SVpro)
            warning('No provider selected.');
            return;
        end
        % 
        % % Display debug information
        % disp('Checking Vreqi and Offtransaction before transaction update:');
        % disp(Updated_Vreqi);
        % disp(Updated_Vreqi.Offtransaction)
        % disp('Vreqi.Offtransaction.numTransactions')
        % disp(Updated_Vreqi.Offtransaction.numTransactions)
        % 
        % disp('Checking SVpro and Offtransaction before transaction update:');
        % disp(SVpro);
        % disp(SVpro.Offtransaction)
        % disp('SVpro.Offtransaction.numTransactions')
        % disp(SVpro.Offtransaction.numTransactions)

          % D) Simulate V2V offloading Process
        [transmissionTime, executionTime, totalOffloadingLatency, totalCost, offloadingSuccessstatus] = ...
            V2VOffloading(Updated_Vreqi.Req, SVpro, Updated_Vreqi, runIndex);

         % E) Load & Update Interaction Histories and update OffloadingRecords
    % -----------------------
    % 1. Checks/initializes interaction fields for both SVpro & Vreqi
    % 2. Increments (numTransactions/Success/Failed) counters
    % 3. Attaches transaction details to both vehicles
    % 4. Commits the updated data back into the InteractionData struct

    % Define SVproID and VreqiID
        VreqiID = Updated_Vreqi.PID;
        SVproID = SVpro.PID;
        taskRequest=Updated_Vreqi.Req;
        tnMax = taskRequest.maxTt; % Maximum allowable time
        recentReput   = SVpro.reputation;
        isMalicious = SVpro.isMalicious; 

        % E1. Ensure SVpro.Offtransaction has required fields (from blockchain)
        % IMPORTANT: Use blockchain data (SVpro.Offtransaction) as source of truth.
        % Only initialize missing fields, never overwrite with InteractionData cache.
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

        % E3. Update Transaction Counts for `SVpro`
        SVpro.Offtransaction.numTransactions.(VreqiID) =SVpro.Offtransaction.numTransactions.(VreqiID) + 1;
        if offloadingSuccessstatus
            SVpro.Offtransaction.numSuccess.(VreqiID) = SVpro.Offtransaction.numSuccess.(VreqiID) + 1;
        else
            SVpro.Offtransaction.numFailed.(VreqiID) = SVpro.Offtransaction.numFailed.(VreqiID) + 1;
        end
       
        % E4. Update Transaction Counts for `Vreqi`
        Updated_Vreqi.Offtransaction.numTransactions.(SVproID) = Updated_Vreqi.Offtransaction.numTransactions.(SVproID) + 1;
        if offloadingSuccessstatus
            Updated_Vreqi.Offtransaction.numSuccess.(SVproID) = Updated_Vreqi.Offtransaction.numSuccess.(SVproID) + 1;
        else
            Updated_Vreqi.Offtransaction.numFailed.(SVproID) = Updated_Vreqi.Offtransaction.numFailed.(SVproID) + 1;
        end
        
        

        % E5. Store Offloading Transaction Details for `SVpro`
        SVpro.Offtransaction.TransactionsID  = struct( ...
            'TransactionsID', [SVproID, '_', VreqiID], ...
            'VreqiID',      VreqiID, ...
            'SVproisMalicious',      isMalicious, ...
            'SVprorecentReput',recentReput, ...
            'offloadingSuccessstatus', offloadingSuccessstatus, ...
            'transmissionTime', transmissionTime, ...
            'executionTime', executionTime, ...
            'totalOffloadingLatency', totalOffloadingLatency, ...
            'totalCost', totalCost, ...
            'maximumTime',tnMax, ...
            'timestamp', datetime("now"), ...
            'runIndex', runIndex);
     

        % E.6 Store Offloading Transaction Details for `Vreqi`
        Updated_Vreqi.Offtransaction.TransactionsID  = struct( ...
            'TransactionsID', [VreqiID, '_', SVproID], ...
            'SVproID',      SVproID, ...
            'SVproisMalicious',      isMalicious, ...
            'SVprorecentReput',recentReput, ...
            'offloadingSuccessstatus', offloadingSuccessstatus, ...
            'transmissionTime', transmissionTime, ...
            'executionTime', executionTime, ...
            'totalOffloadingLatency', totalOffloadingLatency, ...
            'totalCost', totalCost, ...
            'maximumTime',tnMax, ...
             'timestamp', datetime("now"), ...
             'runIndex', runIndex);

% Append full transaction to provider history
if ~isfield(SVpro.Offtransaction, 'history') || isempty(SVpro.Offtransaction.history)
    SVpro.Offtransaction.history = SVpro.Offtransaction.TransactionsID;
else
    SVpro.Offtransaction.history(end+1) = SVpro.Offtransaction.TransactionsID;
end

% Append full transaction to requester history
if ~isfield(Updated_Vreqi.Offtransaction, 'history') || isempty(Updated_Vreqi.Offtransaction.history)
    Updated_Vreqi.Offtransaction.history = Updated_Vreqi.Offtransaction.TransactionsID;
else
    Updated_Vreqi.Offtransaction.history(end+1) = Updated_Vreqi.Offtransaction.TransactionsID;
end

        % % E7.Save Updated Interaction Data
        InteractionData.(SVproID) = SVpro.Offtransaction;
        InteractionData.(VreqiID) = Updated_Vreqi.Offtransaction;
        % save('interaction_data.mat', 'InteractionData');
        % 
        % % Display debug information
        % disp('Updated_Vreqi_Offtransaction.numTransactions after updating:');
        % disp(Updated_Vreqi.Offtransaction);
        % disp(Updated_Vreqi.Offtransaction.numTransactions);
        % disp(Updated_Vreqi.Offtransaction.TransactionsID);
        % disp ('InteractionData.(VreqiID) after updating')
        % disp(InteractionData.(VreqiID));
        % disp(InteractionData.(VreqiID).numTransactions);
        % disp ('Updated_Vreqi.Offtransaction.history after updating')
        % disp(Updated_Vreqi.Offtransaction.history);
        % disp(Updated_Vreqi.Offtransaction.history(end));
        % disp('SVpro_Offtransaction.numTransactions after updating:');
        % disp(SVpro.Offtransaction.numTransactions);
        % disp(SVpro.Offtransaction.TransactionsID);
        % disp('InteractionData.(SVproID) after updating');
        % disp(InteractionData.(SVproID));
        % disp(InteractionData.(SVproID).numTransactions); 
        %  disp ('SVpro.Offtransaction.history after updating')
        % disp(SVpro.Offtransaction.history);
        % disp(SVpro.Offtransaction.history(end));
      
end
