function [CandidateVproj, SortedCanditateVproj_R_D, Trust_scores, SVpro, Updated_Vreqi, VprojBlockchainset] = SmartContract_Notier(Vreqi, InteractionData, VprojBlockchainset, runIndex)
%SMARTCONTRACT_NOTIER  RSU-mediated provider selection WITHOUT tier awareness
%
% This is the NOTIER baseline - no tier governance, selection based on
% reputation and stay time. Used for comparison with tier-aware selection.
%
% Policy:
%   - Score = w1*reputation + w2*normalizedStayTime for ALL eligible candidates
%   - NO warning-tier penalty
%   - NO strict tier separation (good/warning compete equally)
%   - Only R >= R_min filtering (basic eligibility)
%
% Inputs:
%   Vreqi               : requester struct (must have PID and Req)
%   InteractionData     : cache of blockchain Offtransaction data
%   VprojBlockchainset  : array of provider blocks (chain entries with .data)
%   runIndex            : simulation index
%
% Outputs:
%   CandidateVproj              : array of candidate provider blocks
%   SortedCanditateVproj_R_D    : sorted candidate providers (struct array)
%   Trust_scores                : selection scores
%   SVpro                       : selected provider (updated state)
%   Updated_Vreqi               : requester (updated state)
%   VprojBlockchainset          : updated blockchain set
%
% See also: SmartContract, selectProviderNoTier

% Initialize outputs
Trust_scores = [];
SortedCanditateVproj_R_D = [];
SVpro = [];
Updated_Vreqi = Vreqi;

% Load weights from Params (optimal: w1=0.6, w2=0.4)
p = Params();
w1 = p.w1;      % Weight for reputation
w2 = p.w2;      % Weight for stay time
R_min = p.R_min; % Minimum reputation threshold

% A. Fetch available vehicles (Vproj) in the RSU range
[CandidateVproj, numProviders, numRequesters, VprojBlockchainset] = fetchCandidatePool(VprojBlockchainset, Vreqi);

if ~(numProviders >= numRequesters) || isempty(CandidateVproj)
    return;
end

% B. Sort the available providers Vproj to find the candidate ones
SortedCanditateVproj_R_D = SortVproj(CandidateVproj, R_min);

if isempty(SortedCanditateVproj_R_D)
    return;
end

% C. Select the best one (SVpro) based on trust scores
[SVpro, SortedCanditateVproj_R_D] = SelectedVproj(SortedCanditateVproj_R_D, Vreqi, w1, w2);

if isempty(SVpro)
    warning('No provider selected.');
    return;
end

% Extract trust scores from candidates
Trust_scores = [SortedCanditateVproj_R_D.Trust_scores];

% D. Simulate Offloading Process
[transmissionTime, executionTime, totalOffloadingLatency, totalCost, offloadingSuccessstatus] = ...
    V2VOffloading(Vreqi.Req, SVpro, Vreqi, runIndex);

% E. Load & Update Interaction Histories and updateOffloadingRecords
VreqiID = Vreqi.PID;
SVproID = SVpro.PID;
taskRequest = Vreqi.Req;
tnMax = taskRequest.maxTt;
recentReput = SVpro.reputation;
isMalicious = SVpro.isMalicious;

% E1. Ensure SVpro.Offtransaction has required fields
if ~isfield(SVpro, 'Offtransaction') || isempty(SVpro.Offtransaction)
    SVpro.Offtransaction = struct();
end
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

% E2. Ensure Updated_Vreqi.Offtransaction has required fields
if ~isfield(Updated_Vreqi, 'Offtransaction') || isempty(Updated_Vreqi.Offtransaction)
    Updated_Vreqi.Offtransaction = struct();
end
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

% E3. Update Transaction Counts for SVpro
SVpro.Offtransaction.numTransactions.(VreqiID) = SVpro.Offtransaction.numTransactions.(VreqiID) + 1;
if offloadingSuccessstatus
    SVpro.Offtransaction.numSuccess.(VreqiID) = SVpro.Offtransaction.numSuccess.(VreqiID) + 1;
else
    SVpro.Offtransaction.numFailed.(VreqiID) = SVpro.Offtransaction.numFailed.(VreqiID) + 1;
end

% E4. Update Transaction Counts for Vreqi
Updated_Vreqi.Offtransaction.numTransactions.(SVproID) = Updated_Vreqi.Offtransaction.numTransactions.(SVproID) + 1;
if offloadingSuccessstatus
    Updated_Vreqi.Offtransaction.numSuccess.(SVproID) = Updated_Vreqi.Offtransaction.numSuccess.(SVproID) + 1;
else
    Updated_Vreqi.Offtransaction.numFailed.(SVproID) = Updated_Vreqi.Offtransaction.numFailed.(SVproID) + 1;
end

% E5. Store Offloading Transaction Details for SVpro
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

% Append to provider history
if ~isfield(SVpro.Offtransaction, 'history') || isempty(SVpro.Offtransaction.history)
    SVpro.Offtransaction.history = SVpro.Offtransaction.TransactionsID;
else
    SVpro.Offtransaction.history(end+1) = SVpro.Offtransaction.TransactionsID;
end

% E6. Store Offloading Transaction Details for Vreqi
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

% Append to requester history
if ~isfield(Updated_Vreqi.Offtransaction, 'history') || isempty(Updated_Vreqi.Offtransaction.history)
    Updated_Vreqi.Offtransaction.history = Updated_Vreqi.Offtransaction.TransactionsID;
else
    Updated_Vreqi.Offtransaction.history(end+1) = Updated_Vreqi.Offtransaction.TransactionsID;
end

% E7. Save Updated Interaction Data
InteractionData.(SVproID) = SVpro.Offtransaction;
InteractionData.(VreqiID) = Updated_Vreqi.Offtransaction;

end


%% ========================================================================
%  LOCAL FUNCTIONS FOR NOTIER CASE
%  ========================================================================

function SortedCanditateVproj_R_D = SortVproj(CandidateVproj, R_min)
% SORTVPROJ Sort vehicle providers by direction and reputation
%   For NOTIER case - filters by same direction and sorts by reputation
%
% Inputs:
%   CandidateVproj - Array of candidate provider data structs (from fetchCandidatePool)
%   R_min - Minimum reputation threshold (from Params)
%
% Outputs:
%   SortedCanditateVproj_R_D - Sorted array of candidates (highest reputation first)

    % 1. Get vehicles in the same direction with reputation >= R_min
    Vproj_SameD = getVehicle_SameDirection(CandidateVproj, R_min);

    % 2. Sort these vehicles based on reputation from highest to lowest
    if ~isempty(Vproj_SameD)
        [~, sortOrder] = sort([Vproj_SameD.reputation], 'descend');
        SortedCanditateVproj_R_D = Vproj_SameD(sortOrder);
    else
        SortedCanditateVproj_R_D = [];
    end
end


function Vproj_SameD = getVehicle_SameDirection(Vproj, R_min)
% GETVEHICLE_SAMEDIRECTION Helper function to get vehicles in the same direction
%   Filters vehicles by direction and minimum reputation threshold
%
% Inputs:
%   Vproj - Array of vehicle provider data structs (from fetchCandidatePool)
%   R_min - Minimum reputation threshold (from Params)
%
% Outputs:
%   Vproj_SameD - Array of vehicles in the same direction with reputation >= R_min

    Vproj_SameD = [];

    for i = 1:numel(Vproj)
        % Check if the current vehicle has the same direction and reputation >= R_min
        if strcmp(Vproj(i).direction, 'Same direction') && Vproj(i).reputation >= R_min
            if isempty(Vproj_SameD)
                Vproj_SameD = Vproj(i);
            else
                Vproj_SameD = [Vproj_SameD, Vproj(i)];
            end
        end
    end
end


function [SVpro, CandidateVproj] = SelectedVproj(CandidateVproj, Vreqi, w1, w2)
% SELECTEDVPROJ Select the best vehicle provider based on trust scores
%   For NOTIER case - selects provider with highest weighted trust score
%
% Inputs:
%   CandidateVproj - Array of candidate providers
%   Vreqi - The requesting vehicle
%   w1 - Weight for reputation component
%   w2 - Weight for normalized stay time component
%
% Outputs:
%   SVpro - Selected provider vehicle (highest trust score)
%   CandidateVproj - Updated candidates with calculated scores

    numCandidates = numel(CandidateVproj);

    % 1. Calculate all stay times first
    stayTimes = zeros(1, numCandidates);
    for i = 1:numCandidates
        stayTimes(i) = calculateStayTime2(Vreqi, CandidateVproj(i));
        CandidateVproj(i).V2V_StayTime = stayTimes(i);
    end

    % 2. Normalize stay times (0 to 1 range)
    validStayTimes = stayTimes(isfinite(stayTimes) & stayTimes > 0);
    if ~isempty(validStayTimes)
        maxStayTime = max(validStayTimes);
    else
        maxStayTime = 1;  % Avoid division by zero
    end

    normStayTimes = zeros(1, numCandidates);
    for i = 1:numCandidates
        if isfinite(stayTimes(i)) && maxStayTime > 0
            normStayTimes(i) = stayTimes(i) / maxStayTime;
        else
            normStayTimes(i) = 0;
        end
        CandidateVproj(i).normStayTime = normStayTimes(i);
    end

    % 3. Calculate trust scores with normalized stay time
    Trust_scores = zeros(1, numCandidates);
    for i = 1:numCandidates
        Trust_scores(i) = w1 * CandidateVproj(i).reputation + w2 * normStayTimes(i);
        CandidateVproj(i).Trust_scores = Trust_scores(i);
    end

    % 4. Find the candidate with the maximum score
    [~, idx] = max(Trust_scores);
    SVpro = CandidateVproj(idx);
end


function V2V_stayTime = calculateStayTime2(Vreqi, Vproj)
% CALCULATESTAYTIME2 Calculate the stay time between two vehicles
%   Computes how long Vproj will remain within Vreqi's communication range
%
% Inputs:
%   Vreqi - The requesting vehicle
%   Vproj - The provider vehicle
%
% Outputs:
%   V2V_stayTime - Estimated stay time within communication range

    % Calculate the squared distance between Vreqi and Vproj based on RAZA
    distanceSquared = (Vproj.x - Vreqi.x)^2 + (Vproj.y - Vreqi.y)^2;

    % Ensure the vehicle is within the communication radius
    if distanceSquared > Vreqi.radius^2
        V2V_stayTime = 0;
        return;
    end

    % Calculate the remaining distance within the radius
    remainingDistance = sqrt(Vreqi.radius^2 - distanceSquared);

    % Calculate the relative speed
    relativeSpeed = abs(Vreqi.speed - Vproj.speed);

    % Calculate the stay time within the coverage
    if relativeSpeed > 0
        V2V_stayTime = remainingDistance / relativeSpeed;
    else
        V2V_stayTime = inf; % Infinite stay time if relative speed is zero
    end
end
