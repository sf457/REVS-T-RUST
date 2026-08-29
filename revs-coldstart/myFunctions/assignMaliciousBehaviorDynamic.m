function VProjwithMalicious = assignMaliciousBehaviorDynamic(Vproj, maliciousPercentage, seed, maliciousProbabilities)

% Set random seed for consistent results
    rng(seed);

    % Total vehicles and max malicious count
    numProviders = numel(Vproj);
    maxMaliciousCount = round(maliciousPercentage * numProviders);

    % Group vehicles by trust level
    highTrustIndices = find(strcmp({Vproj.socialTrustLevel}, 'high'));
    intermediateTrustIndices = find(strcmp({Vproj.socialTrustLevel}, 'intermediate'));
    lowTrustIndices = find(strcmp({Vproj.socialTrustLevel}, 'low'));

    % % Debug output
    % disp(['[Dynamic] Total Vehicles: ', num2str(numProviders), ...
    %       ', Max Malicious Allowed: ', num2str(maxMaliciousCount)]);
    % disp(['[Dynamic] High Trust Vehicles: ', num2str(numel(highTrustIndices))]);
    % disp(['[Dynamic] Intermediate Trust Vehicles: ', num2str(numel(intermediateTrustIndices))]);
    % disp(['[Dynamic] Low Trust Vehicles: ', num2str(numel(lowTrustIndices))]);

    % Default trust thresholds if not provided
    if nargin < 4
        maliciousProbabilities = struct('high', 0.1, 'intermediate', 0.3, 'low', 0.6);
    end

    % Malicious assignment by group
    [Vproj, assignedLow] = assignMaliciousByGroup(Vproj, lowTrustIndices, maxMaliciousCount, maliciousProbabilities.low, 'Low');
    remainingQuota = maxMaliciousCount - assignedLow;

    % Adjust quota to intermediate group if no low vehicles are available
    if isempty(lowTrustIndices)
        maliciousProbabilities.intermediate = maliciousProbabilities.intermediate + maliciousProbabilities.low * 0.5; % Prioritize intermediate trust
        maliciousProbabilities.high = maliciousProbabilities.high + maliciousProbabilities.low * 0.5; % Adjust high trust to maintain overall balance
    end

    [Vproj, assignedIntermediate] = assignMaliciousByGroup(Vproj, intermediateTrustIndices, remainingQuota, maliciousProbabilities.intermediate, 'Intermediate');
    remainingQuota = remainingQuota - assignedIntermediate;

    [Vproj, assignedHigh] = assignMaliciousByGroup(Vproj, highTrustIndices, remainingQuota, maliciousProbabilities.high, 'High');

    % Total malicious assigned
    totalAssignedMalicious = assignedLow + assignedIntermediate + assignedHigh;

    % % Debug output
    % disp(['[Dynamic] Total Malicious Assigned: ', num2str(totalAssignedMalicious), ...
    %       ' (Expected: ', num2str(maxMaliciousCount), ')']);

    VProjwithMalicious = Vproj;
end

function [Vproj, assignedCount] = assignMaliciousByGroup(Vproj, indices, maxMaliciousCount, probability, groupName)
    % Malicious assignment for a specific group
    assignedCount = 0;
    if isempty(indices)
        %disp(['[Dynamic - ', groupName, '] No vehicles in group.']);
        return;
    end

    %disp(['[Dynamic - ', groupName, '] Attempting Malicious Assignment.']);

    for i = indices
        % if assignedCount >= maxMaliciousCount
        %    % disp(['[Dynamic - ', groupName, '] Max malicious count reached. Stopping assignment.']);
        %     break;
        % end
        if assignedCount >= min(maxMaliciousCount, numel(indices))
             break;
        end

        if rand() < probability
            Vproj(i).isMalicious = true;
            Vproj(i).computationCapacity = Vproj(i).computationCapacity * 0.5;
            Vproj(i).transmissionRate = Vproj(i).transmissionRate * 0.7;
            assignedCount = assignedCount + 1;
            %disp(['[Dynamic - ', groupName, '] Vehicle ', num2str(i), ' assigned as malicious.']);
        end
    end

    % % Debug output
    %disp(['[Dynamic - ', groupName, '] Total Malicious Assigned: ', num2str(assignedCount)]);
end
