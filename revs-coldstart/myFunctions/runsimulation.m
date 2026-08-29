function [Vreqi, Req, Vproj, Vehicularblockchain, VprojBlockchain, CandidateVproj, SVpro, updatedReputationScore, updatedVehicularblockchain, VProjwithMalicious] = runSimulation(blockchainObj, maliciousPercentage)
    
% Simulation parameters
    numVehicles_min = 6; % Minimum number of vehicles
    numVehicles_max = 20; % Maximum number of vehicles
    j = randi([numVehicles_min, numVehicles_max]); % Number of vehicles
    
    % Initialize outputs with default values
    updatedReputationScore = 0;
    updatedVehicularblockchain = [];
    VprojBlockchain = [];
    CandidateVproj = [];
    SVpro = [];
  VProjwithMalicious = []; % Initialize the new structure
%     % Define dynamic thresholds
% trustThresholds = struct('high', 0.3, 'intermediate', 0.5, 'low', 0.7); % Adjusted thresholds
% seed=123;

    % 1. Define Vreq (requester)
    Vreqi = createVreq(j);

    % 2. Define RSUs
    RSU1 = struct('ID', 1, 'Location', [20, 90], 'range', 300, 'connectedVehicles', []);
    RSU2 = struct('ID', 2, 'Location', [320, 90], 'range', 300, 'connectedVehicles', []);
    RSUm = [RSU1, RSU2];

    % 3. Generate task request
    [Vreqi.Req, Vreqi.msgReqContent] = generateTaskReq(Vreqi);
    Req = Vreqi.Req;

    % 4. Generate provider vehicles (Vproj)
    Vproj = generateVproj2(j, Vreqi) ;                                                 

%    % 5. Assign malicious behavior probabilistically
% 
% %VProjwithMalicious=assignMaliciousBehaviorDynamic(Vproj, maliciousPercentage, 123);
% 
% VProjwithMalicious = assignMaliciousBehaviorDynamic(Vproj, maliciousPercentage, seed, trustThresholds);
% 
%     % 6. Add Vproj to Blockchain
%     blockchainObj = bc.vBlockchain();
%     Vehicularblockchain = blockchainObj.blockchain;
%     Vehicularblockchain = AddtoVehicularBlockChain(VProjwithMalicious, Vehicularblockchain, blockchainObj);
% 
%     % 7. Smart Contract Implementation for Offloading
%     [VprojBlockchain, CandidateVproj, SVpro, Updated_Vreqi] = SmartContract(Vehicularblockchain, Vreqi);
% 
%     % 8. Trust Model Development
%     if ~isempty(SVpro)
%         updatedReputationScore = calculateReputation2(SVpro, VprojBlockchain, Vreqi, Updated_Vreqi);
%         SVpro.reputation = updatedReputationScore;
% 
%         % Update the blockchain with SVpro and Updated_Vreqi
%         updatedVehicularblockchain = AddtoVehicularBlockChain(SVpro, Vehicularblockchain, blockchainObj);
%         updatedVehicularblockchain = AddtoVehicularBlockChain(Updated_Vreqi, updatedVehicularblockchain, blockchainObj);
%     else
%         % If no provider is selected, maintain the original blockchain
%         updatedVehicularblockchain = Vehicularblockchain;
%     end
% end
% 
% % % Helper function to assign malicious behavior probabilistically
% 
% function VProjwithMalicious = assignMaliciousBehaviorDynamic(Vproj, maliciousPercentage, seed, trustThresholds)
%     % Set random seed for consistent results
%     rng(seed);
% 
%     % Total vehicles and max malicious count
%     numProviders = numel(Vproj);
%     maxMaliciousCount = round(maliciousPercentage * numProviders);
% 
%     % Group vehicles by trust level
%     highTrustIndices = find(strcmp({Vproj.socialTrustLevel}, 'high'));
%     intermediateTrustIndices = find(strcmp({Vproj.socialTrustLevel}, 'intermediate'));
%     lowTrustIndices = find(strcmp({Vproj.socialTrustLevel}, 'low'));
% 
%     % % Debug output
%     % disp(['[Dynamic] Total Vehicles: ', num2str(numProviders), ...
%     %       ', Max Malicious Allowed: ', num2str(maxMaliciousCount)]);
%     % disp(['[Dynamic] High Trust Vehicles: ', num2str(numel(highTrustIndices))]);
%     % disp(['[Dynamic] Intermediate Trust Vehicles: ', num2str(numel(intermediateTrustIndices))]);
%     % disp(['[Dynamic] Low Trust Vehicles: ', num2str(numel(lowTrustIndices))]);
% 
%     % Default trust thresholds if not provided
%     if nargin < 4
%         trustThresholds = struct('high', 0.1, 'intermediate', 0.3, 'low', 0.6);
%     end
% 
%     % Malicious assignment by group
%     [Vproj, assignedLow] = assignMaliciousByGroup(Vproj, lowTrustIndices, maxMaliciousCount, trustThresholds.low, 'Low');
%     remainingQuota = maxMaliciousCount - assignedLow;
% 
%     % Adjust quota to intermediate group if no low vehicles are available
%     if isempty(lowTrustIndices)
%         trustThresholds.intermediate = trustThresholds.intermediate + trustThresholds.low * 0.5; % Prioritize intermediate trust
%         trustThresholds.high = trustThresholds.high + trustThresholds.low * 0.5; % Adjust high trust to maintain overall balance
%     end
% 
%     [Vproj, assignedIntermediate] = assignMaliciousByGroup(Vproj, intermediateTrustIndices, remainingQuota, trustThresholds.intermediate, 'Intermediate');
%     remainingQuota = remainingQuota - assignedIntermediate;
% 
%     [Vproj, assignedHigh] = assignMaliciousByGroup(Vproj, highTrustIndices, remainingQuota, trustThresholds.high, 'High');
% 
%     % Total malicious assigned
%     totalAssignedMalicious = assignedLow + assignedIntermediate + assignedHigh;
% 
%     % % Debug output
%     % disp(['[Dynamic] Total Malicious Assigned: ', num2str(totalAssignedMalicious), ...
%     %       ' (Expected: ', num2str(maxMaliciousCount), ')']);
% 
%     VProjwithMalicious = Vproj;
% end
% 
% function [Vproj, assignedCount] = assignMaliciousByGroup(Vproj, indices, maxMaliciousCount, probability, groupName)
%     % Malicious assignment for a specific group
%     assignedCount = 0;
%     if isempty(indices)
%         %disp(['[Dynamic - ', groupName, '] No vehicles in group.']);
%         return;
%     end
% 
%     %disp(['[Dynamic - ', groupName, '] Attempting Malicious Assignment.']);
% 
%     for i = indices
%         if assignedCount >= maxMaliciousCount
%            % disp(['[Dynamic - ', groupName, '] Max malicious count reached. Stopping assignment.']);
%             break;
%         end
%         if rand() < probability
%             Vproj(i).isMalicious = true;
%             Vproj(i).computationCapacity = Vproj(i).computationCapacity * 0.5;
%             Vproj(i).transmissionRate = Vproj(i).transmissionRate * 0.7;
%             assignedCount = assignedCount + 1;
%             %disp(['[Dynamic - ', groupName, '] Vehicle ', num2str(i), ' assigned as malicious.']);
%         end
%     end
% 
%     % % Debug output
%     % disp(['[Dynamic - ', groupName, '] Total Malicious Assigned: ', num2str(assignedCount)]);
% end


%% 
% function VProjwithMalicious = assignMaliciousBehaviorDynamic(Vproj, maliciousPercentage, seed)
%     % Set random seed for consistent results
%     rng(seed);
% 
%     % Calculate the cap for malicious vehicles
%     numProviders = numel(Vproj);
%     maxMaliciousCount = round(maliciousPercentage * numProviders);
% 
%     % Group vehicles by social trust level
%     highTrustIndices = find(strcmp({Vproj.socialTrustLevel}, 'high'));
%     intermediateTrustIndices = find(strcmp({Vproj.socialTrustLevel}, 'intermediate'));
%     lowTrustIndices = find(strcmp({Vproj.socialTrustLevel}, 'low'));
% 
%     % Debug output: Group sizes
%     disp(['Total Vehicles: ', num2str(numProviders)]);
%     disp(['High Trust Vehicles: ', num2str(numel(highTrustIndices))]);
%     disp(['Intermediate Trust Vehicles: ', num2str(numel(intermediateTrustIndices))]);
%     disp(['Low Trust Vehicles: ', num2str(numel(lowTrustIndices))]);
% 
%     % Determine allocation of malicious vehicles per trust level
%     totalVehicles = [numel(highTrustIndices), numel(intermediateTrustIndices), numel(lowTrustIndices)];
%     totalVehiclesSum = sum(totalVehicles);
% 
%     % Assign a proportional cap for each trust level
%     maliciousAllocation = round(maxMaliciousCount * totalVehicles / totalVehiclesSum);
%     maliciousAllocation = min(maliciousAllocation, totalVehicles); % Ensure allocation does not exceed group size
%     allocatedMaliciousCount = sum(maliciousAllocation);
% 
%     % Debug output: Initial allocation plan
%     disp(['Malicious Allocation (High): ', num2str(maliciousAllocation(1))]);
%     disp(['Malicious Allocation (Intermediate): ', num2str(maliciousAllocation(2))]);
%     disp(['Malicious Allocation (Low): ', num2str(maliciousAllocation(3))]);
% 
%     % Adjust allocation if under-assigned
%     while allocatedMaliciousCount < maxMaliciousCount
%         remainingQuota = maxMaliciousCount - allocatedMaliciousCount;
%         for idx = 3:-1:1 % Prioritize low trust first (3 -> low, 2 -> intermediate, 1 -> high)
%             if totalVehicles(idx) > maliciousAllocation(idx)
%                 maliciousAllocation(idx) = maliciousAllocation(idx) + 1;
%                 allocatedMaliciousCount = allocatedMaliciousCount + 1;
%                 if allocatedMaliciousCount >= maxMaliciousCount
%                     break;
%                 end
%             end
%         end
%     end
% 
%     % Debug output: Final allocation after adjustment
%     disp(['Adjusted Malicious Allocation (High): ', num2str(maliciousAllocation(1))]);
%     disp(['Adjusted Malicious Allocation (Intermediate): ', num2str(maliciousAllocation(2))]);
%     disp(['Adjusted Malicious Allocation (Low): ', num2str(maliciousAllocation(3))]);
% 
%     % Assign malicious behavior for each trust level
%     Vproj = assignMaliciousByGroup(Vproj, highTrustIndices, maliciousAllocation(1), 0.1, 'High');
%     Vproj = assignMaliciousByGroup(Vproj, intermediateTrustIndices, maliciousAllocation(2), 0.3, 'Intermediate');
%     Vproj = assignMaliciousByGroup(Vproj, lowTrustIndices, maliciousAllocation(3), 0.6, 'Low');
% 
%     % Validate malicious assignment
%     totalMalicious = sum([Vproj.isMalicious]);
%     % disp(['Final Malicious Vehicles Assigned (Capped): ', num2str(totalMalicious)]);
% 
%     VProjwithMalicious = Vproj;
% end
% 
% function Vproj = assignMaliciousByGroup(Vproj, indices, numMalicious, maliciousProbability, groupName)
%     % Assign malicious behavior within a specific group
%     if isempty(indices) || numMalicious == 0
%         % disp([groupName, ' Trust Group: No malicious assignment needed.']);
%         return;
%     end
% 
%     % Shuffle indices for random selection
%     indices = indices(randperm(numel(indices)));
% 
%     % Assign malicious behavior probabilistically
%     assignedCount = 0;
%     disp([groupName, ' Trust Group: Attempting probabilistic assignment.']);
%     for i = indices
%         if assignedCount >= numMalicious
%             break;
%         end
% 
%         randomValue = rand();
%         % disp(['Vehicle Index: ', num2str(i), ', Random Value: ', num2str(randomValue), ', Probability: ', num2str(maliciousProbability)]);
%         if randomValue < maliciousProbability
%             Vproj(i).isMalicious = true;
%             Vproj(i).computationCapacity = Vproj(i).computationCapacity * 0.5; % Reduced capacity
%             Vproj(i).transmissionRate = Vproj(i).transmissionRate * 0.7; % Slower transmission
%             assignedCount = assignedCount + 1;
%         else
%             Vproj(i).isMalicious = false;
%         end
%     end
% 
%     % Debug output: Probabilistic assignment results
%     disp(['Assigned Malicious in Group (Probabilistic): ', num2str(assignedCount)]);
% 
%     % Force assignment to meet the required count if probabilistic logic under-assigns
%     remainingQuota = numMalicious - assignedCount;
%     if remainingQuota > 0
%         additionalIndices = indices(~[Vproj(indices).isMalicious]);
%         additionalIndices = additionalIndices(1:min(remainingQuota, numel(additionalIndices)));
%         for i = additionalIndices
%             Vproj(i).isMalicious = true;
%             Vproj(i).computationCapacity = Vproj(i).computationCapacity * 0.5;
%             Vproj(i).transmissionRate = Vproj(i).transmissionRate * 0.7;
%         end
%         % disp(['Assigned Malicious in Group (Forced): ', num2str(numel(additionalIndices))]);
%     else
%         disp(['No forced assignment needed for ', groupName, ' Trust Group.']);
%     end
% 
%     % Debug output: Final malicious count for the group
%     totalAssigned = assignedCount + remainingQuota;
%     disp(['Total Assigned Malicious in Group (', groupName, '): ', num2str(totalAssigned)]);
% end

% function VProjwithMalicious = assignMaliciousBehaviorDynamic(Vproj, maliciousPercentage, seed)
%     % Set random seed for consistent results
%     rng(seed);
% 
%     % Calculate the cap for malicious vehicles
%     numProviders = numel(Vproj);
%     maxMaliciousCount = round(maliciousPercentage * numProviders);
% 
%     % Group vehicles by social trust level
%     highTrustIndices = find(strcmp({Vproj.socialTrustLevel}, 'high'));
%     intermediateTrustIndices = find(strcmp({Vproj.socialTrustLevel}, 'intermediate'));
%     lowTrustIndices = find(strcmp({Vproj.socialTrustLevel}, 'low'));
% 
%     % Debug output: Group sizes
%     disp(['Total Vehicles: ', num2str(numProviders)]);
%     disp(['High Trust Vehicles: ', num2str(numel(highTrustIndices))]);
%     disp(['Intermediate Trust Vehicles: ', num2str(numel(intermediateTrustIndices))]);
%     disp(['Low Trust Vehicles: ', num2str(numel(lowTrustIndices))]);
% 
%     % Determine allocation of malicious vehicles per trust level
%     totalVehicles = [numel(highTrustIndices), numel(intermediateTrustIndices), numel(lowTrustIndices)];
%     totalVehiclesSum = sum(totalVehicles);
% 
%     % Prioritize low trust group
%     lowTrustQuota = round(maxMaliciousCount * 0.5); % 50% of malicious go to "low"
%     remainingQuota = maxMaliciousCount - lowTrustQuota;
% 
%     % Allocate remaining malicious vehicles proportionally to high and intermediate groups
%     remainingVehicles = totalVehicles(1:2);
%     remainingAllocations = round(remainingQuota * remainingVehicles / sum(remainingVehicles));
% 
%     % Final malicious allocation
%     maliciousAllocation = [remainingAllocations(1), remainingAllocations(2), lowTrustQuota];
%     maliciousAllocation = min(maliciousAllocation, totalVehicles); % Ensure allocation does not exceed group size
%     allocatedMaliciousCount = sum(maliciousAllocation);
% 
%     % Debug output: Initial allocation plan
%     disp(['Malicious Allocation (High): ', num2str(maliciousAllocation(1))]);
%     disp(['Malicious Allocation (Intermediate): ', num2str(maliciousAllocation(2))]);
%     disp(['Malicious Allocation (Low): ', num2str(maliciousAllocation(3))]);
% 
%     % Adjust allocation if under-assigned
%     while allocatedMaliciousCount < maxMaliciousCount
%         remainingQuota = maxMaliciousCount - allocatedMaliciousCount;
%         for idx = 3:-1:1 % Prioritize low trust first (3 -> low, 2 -> intermediate, 1 -> high)
%             if totalVehicles(idx) > maliciousAllocation(idx)
%                 maliciousAllocation(idx) = maliciousAllocation(idx) + 1;
%                 allocatedMaliciousCount = allocatedMaliciousCount + 1;
%                 if allocatedMaliciousCount >= maxMaliciousCount
%                     break;
%                 end
%             end
%         end
%     end
% 
%     % Debug output: Final allocation after adjustment
%     disp(['Adjusted Malicious Allocation (High): ', num2str(maliciousAllocation(1))]);
%     disp(['Adjusted Malicious Allocation (Intermediate): ', num2str(maliciousAllocation(2))]);
%     disp(['Adjusted Malicious Allocation (Low): ', num2str(maliciousAllocation(3))]);
% 
%     % Assign malicious behavior for each trust level
%     Vproj = assignMaliciousByGroup(Vproj, highTrustIndices, maliciousAllocation(1), 0.1, 'High');
%     Vproj = assignMaliciousByGroup(Vproj, intermediateTrustIndices, maliciousAllocation(2), 0.3, 'Intermediate');
%     Vproj = assignMaliciousByGroup(Vproj, lowTrustIndices, maliciousAllocation(3), 0.6, 'Low');
% 
%     % Validate malicious assignment
%     totalMalicious = sum([Vproj.isMalicious]);
%     disp(['Final Malicious Vehicles Assigned (Capped): ', num2str(totalMalicious)]);
% 
%     VProjwithMalicious = Vproj;
% end
% 
% function Vproj = assignMaliciousByGroup(Vproj, indices, numMalicious, maliciousProbability, groupName)
%     % Assign malicious behavior within a specific group
%     if isempty(indices) || numMalicious == 0
%         return;
%     end
% 
%     % Shuffle indices for random selection
%     indices = indices(randperm(numel(indices)));
% 
%     % Assign malicious behavior probabilistically
%     assignedCount = 0;
%     disp([groupName, ' Trust Group: Attempting probabilistic assignment.']);
%     for i = indices
%         if assignedCount >= numMalicious
%             break;
%         end
% 
%         % Adjust threshold for "low" trust group
%         if strcmp(groupName, 'Low')
%             adjustedProbability = maliciousProbability + 0.2; % Boost probability for "low"
%         else
%             adjustedProbability = maliciousProbability;
%         end
% 
%         randomValue = rand();
%         if randomValue < adjustedProbability
%             Vproj(i).isMalicious = true;
%             Vproj(i).computationCapacity = Vproj(i).computationCapacity * 0.5; % Reduced capacity
%             Vproj(i).transmissionRate = Vproj(i).transmissionRate * 0.7; % Slower transmission
%             assignedCount = assignedCount + 1;
%         else
%             Vproj(i).isMalicious = false;
%         end
%     end
% 
%     % Debug output
%     disp(['Assigned Malicious in Group (Probabilistic): ', num2str(assignedCount)]);
% 
%     % Force assignment to meet required count
%     remainingQuota = numMalicious - assignedCount;
%     if remainingQuota > 0
%         additionalIndices = indices(~[Vproj(indices).isMalicious]);
%         additionalIndices = additionalIndices(1:min(remainingQuota, numel(additionalIndices)));
%         for i = additionalIndices
%             Vproj(i).isMalicious = true;
%             Vproj(i).computationCapacity = Vproj(i).computationCapacity * 0.5;
%             Vproj(i).transmissionRate = Vproj(i).transmissionRate * 0.7;
%         end
%     else
%         disp(['No forced assignment needed for ', groupName, ' Trust Group.']);
%     end
% 
%     % Debug output
%     totalAssigned = assignedCount + remainingQuota;
%     disp(['Total Assigned Malicious in Group (', groupName, '): ', num2str(totalAssigned)]);
% end


% function isMalicious = assignMaliciousBehaviorDynamic(Vproj, currentMaliciousCount, maxMaliciousCount, randomValue, trustThresholds)
%     % Ensure the total number of malicious vehicles does not exceed the max limit
%     if currentMaliciousCount >= maxMaliciousCount
%         isMalicious = false; % No more malicious vehicles allowed
%         return;
%     end
%     socialTrustLevel=Vproj.socialTrustLevel;
% 
%     % Retrieve or define thresholds dynamically
%     if nargin < 5
%         trustThresholds = struct('high', 0.1, 'intermediate', 0.1, 'low', 0.3);
%     end
% 
%     % Assign probabilities based on thresholds
%     switch socialTrustLevel
%         case 'high'
%             probability = trustThresholds.high; % Default: 5%
%         case 'intermediate'
%             probability = trustThresholds.intermediate; % Default: 20%
%         case 'low'
%             probability = trustThresholds.low; % Default: 50%
%         otherwise
%             error('Invalid social trust level');
%     end
% 
%     % Assign malicious behavior probabilistically
%     isMalicious = randomValue < probability;
% end
                                                
% function isMalicious = assignMaliciousBehavior(socialTrustLevel, currentMaliciousCount, maxMaliciousCount, randomValue, trustThresholds)
%     % Ensure the total number of malicious vehicles does not exceed the max limit
%     if currentMaliciousCount >= maxMaliciousCount
%         isMalicious = false; % No more malicious vehicles allowed
%         return;
%     end
% 
%     % Retrieve or define thresholds dynamically
%     if nargin < 5
%         trustThresholds = struct('high', 0.1, 'intermediate', 0.3, 'low', 0.6);
%     end
% 
%     % Assign probabilities based on thresholds
%     switch socialTrustLevel
%         case 'high'
%             probability = trustThresholds.high; % Default: 10%
%         case 'intermediate'
%             probability = trustThresholds.intermediate; % Default: 30%
%         case 'low'
%             probability = trustThresholds.low; % Default: 60%
%         otherwise
%             error('Invalid social trust level');
%     end

    % % Adjust probability dynamically based on current malicious count
    % adjustmentFactor = 1 - (currentMaliciousCount / maxMaliciousCount); % Scale down as malicious count increases
    % adjustedProbability = probability * adjustmentFactor;
    % 
    % % Determine if the vehicle is malicious
    % isMalicious = randomValue < adjustedProbability;
    % 
    % % Debugging output
    % disp(['Social Trust Level: ', socialTrustLevel, ...
    %       ', Base Probability: ', num2str(probability), ...
    %       ', Adjustment Factor: ', num2str(adjustmentFactor), ...
    %       ', Adjusted Probability: ', num2str(adjustedProbability), ...
    %       ', Random Value: ', num2str(randomValue), ...
    %       ', Is Malicious: ', num2str(isMalicious)]);
    % 
    % % Debugging output
    % disp(['Social Trust Level: ', socialTrustLevel, ', Probability: ', num2str(probability), ...
    %       ', Random Value: ', num2str(randomValue), ', Is Malicious: ', num2str(isMalicious)]);

    % Determine if the vehicle is malicious
%     isMalicious = rand() < probability;
%     % disp(['Social Trust Level: ', socialTrustLevel, ', Probability: ', num2str(probability), ...
%     %       ', Is Malicious: ', num2str(isMalicious)]);
% end


% function Vproj = assignMaliciousVehicles(Vproj, maliciousPercentage, seed)
%     % Set random seed for consistent results
%     rng(seed);
% 
%     % Number of malicious vehicles to assign
%     numVehicles = numel(Vproj);
%     numMalicious = round(maliciousPercentage * numVehicles);
% 
%     % Randomly select indices for malicious vehicles
%     maliciousIndices = randperm(numVehicles, numMalicious);
% 
%     % Assign malicious behavior
%     for i = 1:numVehicles
%         if ismember(i, maliciousIndices)
%             Vproj(i).isMalicious = true; % Mark as malicious
%             Vproj(i).computationCapacity = Vproj(i).computationCapacity * 0.5; % Reduced capacity
%             Vproj(i).transmissionRate = Vproj(i).transmissionRate * 0.7; % Reduced transmission rate
%         else
%             Vproj(i).isMalicious = false; % Honest provider
%         end
%     end
% end
% 
% % Adjust malicious vehicles to match percentage requirement
% function Vproj = adjustMaliciousPercentage(Vproj, maliciousPercentage, seed)
%     rng(seed); % Set seed for reproducibility
% 
%     % Calculate required number of malicious vehicles
%     numVehicles = numel(Vproj);
%     targetMaliciousCount = round(maliciousPercentage * numVehicles);
%     currentMaliciousCount = sum([Vproj.isMalicious]);
% 
%     if currentMaliciousCount < targetMaliciousCount
%         % Assign additional malicious vehicles randomly
%         nonMaliciousIndices = find(~[Vproj.isMalicious]);
%         additionalMaliciousCount = targetMaliciousCount - currentMaliciousCount;
%         additionalMaliciousIndices = nonMaliciousIndices(randperm(numel(nonMaliciousIndices), additionalMaliciousCount));
% 
%         for idx = additionalMaliciousIndices
%             Vproj(idx).isMalicious = true;
%             Vproj(idx).computationCapacity = Vproj(idx).computationCapacity * 0.5;
%             Vproj(idx).transmissionRate = Vproj(idx).transmissionRate * 0.7;
%         end
% 
%     elseif currentMaliciousCount > targetMaliciousCount
%         % Revert some malicious vehicles to honest
%         maliciousIndices = find([Vproj.isMalicious]);
%         excessMaliciousCount = currentMaliciousCount - targetMaliciousCount;
%         revertMaliciousIndices = maliciousIndices(randperm(numel(maliciousIndices), excessMaliciousCount));
% 
%         for idx = revertMaliciousIndices
%             Vproj(idx).isMalicious = false;
%             Vproj(idx).computationCapacity = 10 * 1e9; % Restore default capacity
%             Vproj(idx).transmissionRate = 86e6; % Restore default rate
%         end
%     end
% end
