function Vproj = generateVproj2(numVehicles, Vreqi, RSUm)
    % Initialize an empty array to store vehicle structures
    Vproj = repmat(struct('PID', '', 'resourceStatus', 1, 'VehicleRole', '', 'socialTrustLevel', '', 'w_ij', [], ...
        'reputation', 0, ...
        'privateKey', '', 'publicKeyX', '', 'publicKeyY', '', 'publicKey', [], ...
        'direction', '', 'speed', 0, 'x', 0, 'y', 0, 'radius', 250, 'RSU_ID', 1, ...
        'computationCapacity', 10 * 1e9, 'transmissionRate', 86e6, ...
        'Offtransaction', [], 'signature', 0, 'isMalicious', false), numVehicles, 1);

    % Adjust provider vehicle speed
    speedAdjustment = randi([5, 10]);

% Set the random seed for reproducibility
%rng(42); % mat i need to use it

    % Generate random data for each provider vehicle (Vproj)
    for i = 1:numVehicles
        % Assign unique PID and vehicle role
        vehicle.PID = ['V' num2str(i+1)];
        vehicle.resourceStatus = 1; % Since it's a provider
        vehicle.VehicleRole = ['Vpro' num2str(i)];
        
        % For result 5
        %Generate random social trust level for reputation initialization
        socialTrustLevels = {'high', 'intermediate', 'low'};
        probabilities = rand(1, 3);  % Dynamic probabilities for each level
        probabilities = probabilities / sum(probabilities); % Normalize to sum to 1
        cumulativeProbabilities = cumsum(probabilities);
        randomNumber = rand();
        index = find(cumulativeProbabilities >= randomNumber, 1, 'first');
        vehicle.socialTrustLevel = socialTrustLevels{index};
        % For result 5

        % %for result_1
        %  % Generate random social trust level for reputation initialization
        % socialTrustLevels = {'high', 'intermediate', 'low'};
        % probabilities = [0.4, 0.5, 0.1];  %  probabilities for each level
        % cumulativeProbabilities = cumsum(probabilities);
        % randomNumber = rand();
        % index = find(cumulativeProbabilities >= randomNumber, 1, 'first');
        % vehicle.socialTrustLevel = socialTrustLevels{index};
        % %for result_1

        % %for results_2
        % socialTrustLevels = {'high', 'intermediate', 'low'};
        % probabilities = [0.33, 0.33, 0.33];  % Probabilities for each level
        % 
        % % Normalize probabilities to ensure they sum to 1
        % probabilities = probabilities / sum(probabilities);
        % 
        % % Generate cumulative probabilities
        % cumulativeProbabilities = cumsum(probabilities);
        % 
        % % Generate a random number
        % randomNumber = rand();
        % %
        % % % Debug outputs
        % % disp('Cumulative Probabilities:');
        % % disp(cumulativeProbabilities);
        % %
        % % disp('Random Number:');
        % % disp(randomNumber);
        % 
        % % Find the index of the chosen level
        % index = find(cumulativeProbabilities >= randomNumber, 1, 'first');
        % 
        % % Handle edge cases where index is empty
        % if isempty(index)
        %     warning('Random number did not match any cumulative probability. Defaulting to last level.');
        %     index = length(socialTrustLevels); % Default to the last level
        % end
        % 
        % vehicle.socialTrustLevel = socialTrustLevels{index};
        % %for results_2

        % %for result_3
        %  % Generate random social trust level for reputation initialization
        % socialTrustLevels = {'high', 'intermediate', 'low'};
        % probabilities = [0.3, 0.3, 0.4];  %  probabilities for each level
        % cumulativeProbabilities = cumsum(probabilities);
        % randomNumber = rand();
        % index = find(cumulativeProbabilities >= randomNumber, 1, 'first');
        % vehicle.socialTrustLevel = socialTrustLevels{index};
        % %for result_3

        % %for result_4 balanced 
        %  % Generate random social trust level for reputation initialization
        % socialTrustLevels = {'high', 'intermediate', 'low'};
        % probabilities = [0.3, 0.4, 0.3];  %  probabilities for each level
        % cumulativeProbabilities = cumsum(probabilities);
        % randomNumber = rand();
        % index = find(cumulativeProbabilities >= randomNumber, 1, 'first');
        % vehicle.socialTrustLevel = socialTrustLevels{index};
        % %for result_4

        

        % Initialize reputation and opinion weights based on social trust level
        [vehicle.reputation, vehicle.w_ij] = calculateInitialOpinion(vehicle.socialTrustLevel);

        % Assign malicious behavior based on social trust level
        vehicle.isMalicious = false;


        % Generate cryptographic keys
        vehicle.privateKey = generatePrivateKey();
        [q1, q2] = secp256k1(vehicle.privateKey, [], []);
        vehicle.publicKeyX = char(q1);
        vehicle.publicKeyY = char(q2);
        vehicle.publicKey = {vehicle.publicKeyX, vehicle.publicKeyY};

        % Assign direction and speed,  0 for opposite, 1 for same
        vehicle.direction = randi([0, 1]);
        if vehicle.direction == 1
            vehicle.direction = 'Same direction';
            vehicle.y = Vreqi.y;
            vehicle.speed = Vreqi.speed + (-1)^randi([0, 1]) * speedAdjustment;
        else
            vehicle.direction = 'Opposite direction';
            vehicle.y = Vreqi.y + 7.5;
            vehicle.speed = Vreqi.speed + (-1)^randi([0, 1]) * speedAdjustment;
        end

        % Random x-coordinate within a logical range based on the Vreqi location
        vehicle.x = Vreqi.x + randi([-30, 30]);
        
        % Communication range
        vehicle.radius = 250;

        % Related RSU info
        % vehicle.RSU_ID = randi([1, numel(RSUm)]);
        vehicle.RSU_ID =1;
        % Initialize offloading transaction struct
        vehicle.Offtransaction = initializeOffloadingTransactions(numVehicles, Vreqi.PID, i);

        % Assign highest computation capacity
            vehicle.computationCapacity = 10 * 1e9;
            vehicle.transmissionRate = 86e6;

        % Adjust attributes for malicious vehicles
        if vehicle.isMalicious
            vehicle.computationCapacity = vehicle.computationCapacity * 0.5; % Reduced capacity
            vehicle.transmissionRate = vehicle.transmissionRate * 0.7; % Slower transmission
        end

        % Add a random signature
        vehicle.signature = rand;

        % Add the vehicle structure to the array
        Vproj(i) = vehicle;
    end
end

% Helper function to assign malicious behavior probabilistically
function isMalicious = assignMaliciousBehavior(socialTrustLevel, currentMaliciousCount, maxMaliciousCount)
    % Ensure the total number of malicious vehicles does not exceed the max limit
    if currentMaliciousCount >= maxMaliciousCount
        isMalicious = false; % No more malicious vehicles allowed
        return;
    end

    % Assign malicious behavior based on social trust level probabilities
    switch socialTrustLevel
        case 'high'
            probability = 0.1; % 10% chance
        case 'intermediate'
            probability = 0.3; % 30% chance
        case 'low'
            probability = 0.6; % 60% chance
        otherwise
            error('Invalid social trust level');
    end

    % Determine if the vehicle is malicious
    isMalicious = rand() < probability;
end



% Function to generate a 64-character hexadecimal private key
function privateKey = generatePrivateKey()
    privateKey = dec2hex(randi([0, 15], 1, 64), 1);
end

% Function to calculate the initial opinion based on social trust level
function [reputation, w_ij] = calculateInitialOpinion(socialTrustLevel)
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
    reputation = ini_belief + (0.5 * ini_uncertainty);
end

% Function to initialize offloading transactions
function Offtransaction = initializeOffloadingTransactions(numVehicles, VreqiPID, currentVehicleIndex)
    numTransactions = struct();
    numSuccess = struct();
    numFailed = struct();
    for i = 1:numVehicles
        if i ~= currentVehicleIndex
            targetVehicleID = VreqiPID;
            targetVehicleID2 = ['V' num2str(i+1)];
            numSuccess.(targetVehicleID) = 0;
            numFailed.(targetVehicleID) = 0;
            numSuccess.(targetVehicleID2) = 0;
            numFailed.(targetVehicleID2) = 0;
            numTransactions.(targetVehicleID) = 0;
            numTransactions.(targetVehicleID2) = 0;
        end
    end
    Offtransaction = struct('numTransactions', numTransactions, 'numSuccess', numSuccess, 'numFailed', numFailed);
end