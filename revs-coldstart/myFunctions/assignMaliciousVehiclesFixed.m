
function [VProjwithMaliciousFixed,Vehicularblockchain] = assignMaliciousVehiclesFixed(Vproj, maliciousPercentage, seed, fixedReputationValue)

    % Set random seed for consistent results
    rng(seed);

    % Number of providers

    numProviders = length(Vproj);
      %disp(['Length of Vproj befor MaliciousFixed: ', num2str(length(Vproj))]);


    % Number of malicious vehicles to assign (capped at maliciousPercentage)
    numMalicious = round(maliciousPercentage * numProviders);

    % Randomly select indices for malicious vehicles
    maliciousIndices = randperm(numProviders, numMalicious);

    % Initialize a new structure for updated vehicles
    VProjwithMaliciousFixed = Vproj;


    % Assign malicious behavior and set fixed reputation
    for i = 1:numProviders
        % Assign a uniform social trust level and fixed reputation value
        %VProjwithMaliciousFixed(i).reputation = fixedReputationValue;
        VProjwithMaliciousFixed(i).socialTrustLevel = 'intermediate'; % Uniform trust level for fixed configuration
        %VProjwithMaliciousFixed(i). w_ij=fixedwij;
        [VProjwithMaliciousFixed(i).reputation, VProjwithMaliciousFixed(i). w_ij] = calculateInitialOpinion(VProjwithMaliciousFixed(i).socialTrustLevel,fixedReputationValue);
        % Check if the vehicle is malicious based on the selected indices
        if ismember(i, maliciousIndices)

            % Update the new structure with malicious-specific adjustments
            VProjwithMaliciousFixed(i).isMalicious = true;
            VProjwithMaliciousFixed(i).computationCapacity = Vproj(i).computationCapacity * 0.5;% Reduced capacity
            VProjwithMaliciousFixed(i).transmissionRate = Vproj(i).transmissionRate * 0.7;% Slower transmission
        else
            Vproj(i).isMalicious = false; % Mark as honest

            % Keep the honest attributes in the new structure
            VProjwithMaliciousFixed(i).isMalicious = false;
            VProjwithMaliciousFixed(i).computationCapacity = Vproj(i).computationCapacity;
            VProjwithMaliciousFixed(i).transmissionRate = Vproj(i).transmissionRate;
        end
    end

    % % Display information about the number of malicious and honest vehicles
    % disp(['Total Providers: ', num2str(numProviders)]);
    % disp(['Malicious Providers Assigned (Fixed): ', num2str(numMalicious)]);
    % disp(['Honest Providers Assigned (Fixed): ', num2str(numProviders - numMalicious)]);
    %disp(VProjwithMaliciousFixed)
     % 5. Add Vproj to Blockchain
    blockchainObj = bc.vBlockchain();
    Vehicularblockchain = blockchainObj.blockchain;
    Vehicularblockchain = AddtoVehicularBlockChain(VProjwithMaliciousFixed, Vehicularblockchain, blockchainObj);

end


% Function to calculate the initial opinion based on social trust level
function [reputation, w_ij] = calculateInitialOpinion(socialTrustLevel,fixedReputationValue)
    switch socialTrustLevel
        case 'high'
            alpha = 3;
            beta = 2;
            gamma = 1;
        case 'intermediate'
            alpha = 2;
            beta = 2;
            gamma = 2;
        case 'low'
            alpha = 1;
            beta = 2;
            gamma = 3;
        otherwise
            error('Invalid trust level');
    end

    % Calculate belief
    ini_belief = alpha / (alpha + beta + gamma);
    ini_distrust = beta / (alpha + beta + gamma);
    ini_uncertainty = gamma / (alpha + beta + gamma);

    % Calculate local subjective trust w_ij
    w_ij = [ini_belief; ini_distrust; ini_uncertainty];
    reputation = fixedReputationValue;
end

% function [VProjwithMaliciousFixed, Vehicularblockchain] = assignMaliciousVehiclesFixed(Vproj, maliciousPercentage, seed, fixedReputationValue)
%     % Set random seed for consistent results
%     rng(seed);
% 
%     % Number of providers
%     numProviders = length(Vproj);
%     disp(['[Fixed] Length of Vproj before Malicious Assignment: ', num2str(numProviders)]);
% 
%     % Number of malicious vehicles to assign
%     numMalicious = round(maliciousPercentage * numProviders);
%     disp(['[Fixed] Malicious Percentage: ', num2str(maliciousPercentage * 100), ...
%           '%, Calculated Malicious Vehicles: ', num2str(numMalicious)]);
% 
%     % Randomly select indices for malicious vehicles
%     maliciousIndices = randperm(numProviders, numMalicious);
% 
%     % Initialize updated vehicles
%     VProjwithMaliciousFixed = Vproj;
% 
%     % Debug: Display selected malicious indices
%     disp(['[Fixed] Selected Malicious Indices: ', mat2str(maliciousIndices)]);
% 
%     % Assign malicious behavior and set fixed reputation
%     for i = 1:numProviders
%         % Assign uniform social trust level and calculate initial opinion
%         VProjwithMaliciousFixed(i).socialTrustLevel = 'intermediate'; % Uniform trust level for fixed configuration
%         [VProjwithMaliciousFixed(i).reputation, VProjwithMaliciousFixed(i).w_ij] = ...
%             calculateInitialOpinion(VProjwithMaliciousFixed(i).socialTrustLevel, fixedReputationValue);
% 
%         if ismember(i, maliciousIndices)
%             % Assign malicious attributes
%             VProjwithMaliciousFixed(i).isMalicious = true;
%             VProjwithMaliciousFixed(i).computationCapacity = Vproj(i).computationCapacity * 0.5; % Reduced capacity
%             VProjwithMaliciousFixed(i).transmissionRate = Vproj(i).transmissionRate * 0.7; % Slower transmission
% 
%             % Debug: Log malicious vehicle assignment
%             disp(['[Fixed] Vehicle ', num2str(i), ' assigned as Malicious.']);
%         else
%             % Assign honest attributes
%             VProjwithMaliciousFixed(i).isMalicious = false;
%             VProjwithMaliciousFixed(i).computationCapacity = Vproj(i).computationCapacity;
%             VProjwithMaliciousFixed(i).transmissionRate = Vproj(i).transmissionRate;
%         end
%     end
% 
%     % Debug: Summary of assignments
%     totalMalicious = sum([VProjwithMaliciousFixed.isMalicious]);
%     totalHonest = numProviders - totalMalicious;
%     disp(['[Fixed] Total Providers: ', num2str(numProviders)]);
%     disp(['[Fixed] Malicious Providers Assigned: ', num2str(totalMalicious)]);
%     disp(['[Fixed] Honest Providers Assigned: ', num2str(totalHonest)]);
% 
%     % Add Vproj to Blockchain
%     blockchainObj = bc.vBlockchain();
%     Vehicularblockchain = blockchainObj.blockchain;
%     Vehicularblockchain = AddtoVehicularBlockChain(VProjwithMaliciousFixed, Vehicularblockchain, blockchainObj);
% end
% 
% % Function to calculate the initial opinion based on social trust level
% function [reputation, w_ij] = calculateInitialOpinion(socialTrustLevel, fixedReputationValue)
%     switch socialTrustLevel
%         case 'high'
%             alpha = 3;
%             beta = 2;
%             gamma = 1;
%         case 'intermediate'
%             alpha = 2;
%             beta = 2;
%             gamma = 2;
%         case 'low'
%             alpha = 1;
%             beta = 2;
%             gamma = 3;
%         otherwise
%             error('[Fixed] Invalid trust level');
%     end
% 
%     % Calculate belief, distrust, and uncertainty
%     ini_belief = alpha / (alpha + beta + gamma);
%     ini_distrust = beta / (alpha + beta + gamma);
%     ini_uncertainty = gamma / (alpha + beta + gamma);
% 
%     % Calculate local subjective trust w_ij
%     w_ij = [ini_belief; ini_distrust; ini_uncertainty];
%     reputation = fixedReputationValue;
% 
%     % Debug: Display calculated opinion
%     disp(['[Fixed] Calculated Opinion for ', socialTrustLevel, ...
%           ': Belief = ', num2str(ini_belief), ...
%           ', Distrust = ', num2str(ini_distrust), ...
%           ', Uncertainty = ', num2str(ini_uncertainty)]);
% end

% function VprojBlockchain = assignMaliciousVehiclesFixed(VprojBlockchain, maliciousPercentage, seed, fixedReputationValue)
%     % Set random seed for consistent results
%     rng(seed);
% 
%     % Number of providers
%     numProviders = length(VprojBlockchain);
% 
%     % Number of malicious vehicles to assign
%     numMalicious = round(maliciousPercentage * numProviders);
% 
%     % Randomly select indices for malicious vehicles
%     maliciousIndices = randperm(numProviders, numMalicious);
% 
%     % Assign malicious behavior and set fixed reputation
%     for i = 1:numProviders
%         VprojBlockchain(i).data.reputation = fixedReputationValue;
%         VprojBlockchain(i).data.socialTrustLevel = 'intermediate'; % Uniform level
% 
%         if ismember(i, maliciousIndices)
%             VprojBlockchain(i).data.isMalicious = true; % Mark as malicious
%             VprojBlockchain(i).data.computationCapacity = VprojBlockchain(i).data.computationCapacity * 0.5; % Reduced capacity
%             VprojBlockchain(i).data.transmissionRate = VprojBlockchain(i).data.transmissionRate * 0.7; % Slower transmission
%         else
%             VprojBlockchain(i).data.isMalicious = false; % Honest provider
%         end
%     end
% end
