% function [CandidateVproj, SortedCanditateVproj_R_D, Trust_scores, SVpro, Updated_Vreqi] = SmartContract_random(Vreqi, InteractionData, VprojBlockchainset, runIndex)
% % SmartContract_random
% % - Fetch candidates in same RSU and idle.
% % - DO NOT sort; pick a provider uniformly at random from the candidates.
% % - Perform offloading, update requester/provider histories locally.
% %
% % Notes
% % - This function does NOT persist updated provider back to VprojBlockchainset.
% %   If you need persistence, do it in the caller (by PID or pool index).
% %
% % Returns
% % - CandidateVproj: whatever fetch returns (blocks or data)
% % - SortedCanditateVproj_R_D: empty (not used for random)
% % - Trust_scores: empty (not used for random)
% % - SVpro: selected provider (vehicle DATA struct)
% % - Updated_Vreqi: requester with updated Offtransaction
% 
%     Trust_scores = [];
%     SortedCanditateVproj_R_D = [];
%     SVpro = [];
%     Updated_Vreqi = Vreqi;
% 
%     % A) Fetch available vehicles 
% 
%         [CandidateVproj, numProviders, numRequesters] = fetchCandidatePool(VprojBlockchainset, Vreqi);
% 
% 
%     if ~(numProviders >= numRequesters) || isempty(CandidateVproj)
%         % disp('No suitable vehicle found for offloading.');  % Suppressed
%         return;
%     end
% 
% 
%     % C) Randomly select one provider (block) and extract DATA struct
%      SVpro = SelectedVprojRandom(CandidateVproj);
% 
%     % D) Simulate Offloading
%     [transmissionTime, executionTime, totalOffloadingLatency, totalCost, offloadingSuccessstatus] = ...
%         V2VOffloading(Vreqi.Req, SVpro, Vreqi);
% 
%     % E) Histories and offloading records
% 
%     % IDs
%     VreqiID = Vreqi.PID;
%     SVproID = SVpro.PID;
%     taskRequest = Vreqi.Req;
%     tnMax = taskRequest.maxTt; % Maximum allowable time
% 
%     % E1) Load/Init Interaction History for SVpro (provider view)
%     if isfield(InteractionData, SVproID)
%         interactionDataSVproID = InteractionData.(SVproID);
%     else
%         interactionDataSVproID = struct();
%         interactionDataSVproID.numTransactions = struct();
%         interactionDataSVproID.numSuccess     = struct();
%         interactionDataSVproID.numFailed      = struct();
%     end
%     if ~isfield(interactionDataSVproID.numTransactions, VreqiID)
%         interactionDataSVproID.numTransactions.(VreqiID) = 0;
%         interactionDataSVproID.numSuccess.(VreqiID)       = 0;
%         interactionDataSVproID.numFailed.(VreqiID)        = 0;
%     end
% 
%     % E2) Load/Init Interaction History for Vreqi (requester view)
%     if isfield(InteractionData, VreqiID)
%         Updated_Vreqi.Offtransaction = InteractionData.(VreqiID);
%     else
%         Updated_Vreqi.Offtransaction = struct();
%         Updated_Vreqi.Offtransaction.numTransactions = struct();
%         Updated_Vreqi.Offtransaction.numSuccess     = struct();
%         Updated_Vreqi.Offtransaction.numFailed      = struct();
%     end
%     if ~isfield(Updated_Vreqi.Offtransaction.numTransactions, SVproID)
%         Updated_Vreqi.Offtransaction.numTransactions.(SVproID) = 0;
%         Updated_Vreqi.Offtransaction.numSuccess.(SVproID)       = 0;
%         Updated_Vreqi.Offtransaction.numFailed.(SVproID)        = 0;
%     end
% 
%     % E3) Update counters (provider view)
%     SVpro.Offtransaction.numTransactions.(VreqiID) = interactionDataSVproID.numTransactions.(VreqiID) + 1;
%     if offloadingSuccessstatus
%         SVpro.Offtransaction.numSuccess.(VreqiID) = interactionDataSVproID.numSuccess.(VreqiID) + 1;
%     else
%         SVpro.Offtransaction.numFailed.(VreqiID) = interactionDataSVproID.numFailed.(VreqiID) + 1;
%     end
% 
%     % E4) Update counters (requester view)
%     Updated_Vreqi.Offtransaction.numTransactions.(SVproID) = Updated_Vreqi.Offtransaction.numTransactions.(SVproID) + 1;
%     if offloadingSuccessstatus
%         Updated_Vreqi.Offtransaction.numSuccess.(SVproID) = Updated_Vreqi.Offtransaction.numSuccess.(SVproID) + 1;
%     else
%         Updated_Vreqi.Offtransaction.numFailed.(SVproID) = Updated_Vreqi.Offtransaction.numFailed.(SVproID) + 1;
%     end
% 
%     % E5) Store offloading transaction details (provider view)
%     SVpro.Offtransaction.TransactionsID = struct( ...
%         'TransactionsID',            [SVproID, '_', VreqiID], ...
%         'VreqiID',                   VreqiID, ...
%         'offloadingSuccessstatus',   offloadingSuccessstatus, ...
%         'transmissionTime',          transmissionTime, ...
%         'executionTime',             executionTime, ...
%         'totalOffloadingLatency',    totalOffloadingLatency, ...
%         'totalCost',                 totalCost, ...
%         'maximumTime',               tnMax, ...
%         'timestamp',                 datetime("now"), ...
%         'runIndex',                  runIndex);
% 
%     % Append to provider history
%     if ~isfield(SVpro.Offtransaction, 'history') || isempty(SVpro.Offtransaction.history)
%         SVpro.Offtransaction.history = SVpro.Offtransaction.TransactionsID;
%     else
%         SVpro.Offtransaction.history(end+1) = SVpro.Offtransaction.TransactionsID;
%     end
% 
%     % E6) Store offloading transaction details (requester view)
%     Updated_Vreqi.Offtransaction.TransactionsID = struct( ...
%         'TransactionsID',            [VreqiID, '_', SVproID], ...
%         'SVproID',                   SVproID, ...
%         'offloadingSuccessstatus',   offloadingSuccessstatus, ...
%         'transmissionTime',          transmissionTime, ...
%         'executionTime',             executionTime, ...
%         'totalOffloadingLatency',    totalOffloadingLatency, ...
%         'totalCost',                 totalCost, ...
%         'maximumTime',               tnMax, ...
%         'timestamp',                 datetime("now"), ...
%         'runIndex',                  runIndex);
% 
%     % Append to requester history
%     if ~isfield(Updated_Vreqi.Offtransaction, 'history') || isempty(Updated_Vreqi.Offtransaction.history)
%         Updated_Vreqi.Offtransaction.history = Updated_Vreqi.Offtransaction.TransactionsID;
%     else
%         Updated_Vreqi.Offtransaction.history(end+1) = Updated_Vreqi.Offtransaction.TransactionsID;
%     end
% 
%     % Note: If you need to persist SVpro back to pool, do it in the caller:
%     %   idx = find(strcmp({VprojBlockchainset.data}.PID, SVpro.PID), 1);
%     %   if ~isempty(idx), VprojBlockchainset(idx).data = SVpro; end
% end




function [CandidateVproj, SortedCanditateVproj_D,Trust_scores,SVpro,Updated_Vreqi,VprojBlockchainset] = SmartContract_random(Vreqi,InteractionData,VprojBlockchainset, runIndex)
% Initialize outputs & Weight Parameteres
Trust_scores = [];
SortedCanditateVproj_D = [];
SVpro = [];
Updated_Vreqi=Vreqi;


% Load weights from Params (optimal: w1=0.6, w2=0.4)
p = Params();
w1 = p.w1;  % Weight for reputation
w2 = p.w2;  % Weight for stay time

 % disp('Provider vehicle set details:');
 %        for i = 1:numel(Vproj)
 %            disp(Vproj(i).data);
 %            disp('---------------------------------------');
 %        end

% A. Fetch available vehicles (Vproi) in the RSU range
[CandidateVproj, numProviders, numRequesters, VprojBlockchainset] =fetchCandidatePool(VprojBlockchainset, Vreqi); 
 % disp('CanditateVproj vehicle set details:');
 %        for i = 1:numel(CandidateVproj)
 %            disp(CandidateVproj(i).data);
 %            disp('---------------------------------------');
 %        end
%dont need it since all in
%Vehicularblockchain is VprojBlockchainset
 % % Calculate the number of providers and requesters here 
 %    numProviders = numel(VprojBlockchainset);
 %    numRequesters = length(Vreqi);
% B. Sort the available providers Vproi to find the candidate ones
if numProviders >= numRequesters
    % % B. Filter by SAME DIRECTION (Physical Constraint ONLY)
    SortedCanditateVproj_D = SortVprojRandom(CandidateVproj);

    if ~isempty(SortedCanditateVproj_D)
        % Display sorted vehicle details
        % disp('Sorted vehicle details for all vehicles with the same direction:');
        % for i = 1:numel(SortedCanditateVproj_R_D)
        %     disp(SortedCanditateVproj_R_D(i));
        %     disp('---------------------------------------');
        % end

        % C. Select the best one (SVpro) that meets the criteria
       % [SVpro, Trust_scores] = SelectedVproj2(SortedCanditateVproj_R_D, Vreqi,w1, w2);
        SVpro = SelectedVprojRandom(SortedCanditateVproj_D);

        % if SVpro.isMalicious
        %     disp('Selected a malicious provider!');
        %     disp(['SVpro Reputation: ', num2str(SVpro.reputation)]);
        % else
        %     disp('Selected an honest provider.');
        %     disp(['SVpro Reputation: ', num2str(SVpro.reputation)]);
        % end
        % Ensure SVproID is properly initialized
        if isempty(SVpro)
            warning('No provider selected.');
            return;
        end

        % % Display debug information
        % disp('Checking Vreqi and Offtransaction before transaction update:');
        % disp(Vreqi);
        % disp(Vreqi.Offtransaction)
        % disp('Vreqi.Offtransaction.numTransactions')
        % disp(Vreqi.Offtransaction.numTransactions)
        % 
        % disp('Checking SVpro and Offtransaction before transaction update:');
        % disp(SVpro);
        % disp(SVpro.Offtransaction)
        % disp('SVpro.Offtransaction.numTransactions')
        % disp(SVpro.Offtransaction.numTransactions)

        % D. Simulate Offloading Process
        [transmissionTime, executionTime, totalOffloadingLatency, totalCost, offloadingSuccessstatus] = ...
            V2VOffloading(Vreqi.Req, SVpro, Vreqi, runIndex);

         % E. Load & Update Interaction Histories and updateOffloadingRecords
    % -----------------------
    % 1. Checks/initializes interaction fields for both SVpro & Vreqi
    % 2. Increments success/failure counters
    % 3. Attaches transaction details to both vehicles
    % 4. Commits the updated data back into the InteractionData struct

    % Define SVproID and VreqiID
        VreqiID = Vreqi.PID;
        SVproID = SVpro.PID;
        taskRequest=Vreqi.Req;
        tnMax = taskRequest.maxTt; % Maximum allowable time
 recentReput   = SVpro.reputation;


        % E1. Ensure SVpro.Offtransaction has required fields (from blockchain)
        % IMPORTANT: Use blockchain data as source of truth. Only initialize
        % missing fields, never overwrite with InteractionData cache.
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

        % E3. Update Transaction Counts for `SVpro` (increment from blockchain state)
        SVpro.Offtransaction.numTransactions.(VreqiID) = SVpro.Offtransaction.numTransactions.(VreqiID) + 1;
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
            'offloadingSuccessstatus', offloadingSuccessstatus, ...
            'transmissionTime', transmissionTime, ...
            'executionTime', executionTime, ...
            'totalOffloadingLatency', totalOffloadingLatency, ...
            'totalCost', totalCost, ...
            'maximumTime',tnMax, ...
            'timestamp', datetime("now"), ...
            'runIndex', runIndex);
      
       disp('SVpro.Offtransaction.TransactionsID ')
       disp(SVpro.Offtransaction.TransactionsID )

        % E.6 Store Offloading Transaction Details for `Vreqi`
        Updated_Vreqi.Offtransaction.TransactionsID  = struct( ...
            'TransactionsID', [VreqiID, '_', SVproID], ...
            'SVproID',      SVproID, ...
            'SVprorecentReput',recentReput, ...
            'offloadingSuccessstatus', offloadingSuccessstatus, ...
            'transmissionTime', transmissionTime, ...
            'executionTime', executionTime, ...
            'totalOffloadingLatency', totalOffloadingLatency, ...
            'totalCost', totalCost, ...
            'maximumTime',tnMax, ...
             'timestamp', datetime("now"), ...
             'runIndex', runIndex);
% disp('Updated_Vreqi.Offtransaction.TransactionsID ')
%  disp(Updated_Vreqi.Offtransaction.TransactionsID )
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

% disp('SVpro.Offtransaction.history(end)')
% disp(SVpro.Offtransaction.history(end))
% disp('Updated_Vreqi.Offtransaction.history(end)')
% disp(Updated_Vreqi.Offtransaction.history(end))


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
        % disp('SVpro_Offtransaction.numTransactions after updating:');
        % disp(SVpro.Offtransaction.numTransactions);
        % disp(SVpro.Offtransaction.TransactionsID);
        % disp('InteractionData.(SVproID) after updating');
        % disp(InteractionData.(SVproID));
        % disp(InteractionData.(SVproID).numTransactions);

    else
        % disp('No suitable vehicle found for offloading.');  % Suppressed
        SVpro = [];
    end
else
    % disp('Not enough available vehicles found to select.');
end
end
