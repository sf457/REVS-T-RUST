function Vprojpool = generateVprojpool(numVehicles, VreqPool, RSUm) 
    % Initialize an empty array to store vehicle structures
    Vprojpool = repmat(struct('PID', '', 'resourceStatus', 1, 'VehicleRole', '', 'socialTrustLevel', '', 'w_ij', [], ...
        'reputation', 0, 'ini_alpha', 0, 'ini_beta',0 , 'ini_gamma',0, ...
        'privateKey', '', 'publicKeyX', '', 'publicKeyY', '', 'publicKey', [], ...
        'direction', '', 'speed', 0, 'x', 0, 'y', 0, 'radius', 250, 'RSU_ID', 1, ...
        'computationCapacity', 10 * 1e9, 'transmissionRate', 86e6, ...
        'Offtransaction', [], 'signature', 0, 'isMalicious', false,'isActive', true,'isWarning', false,'blackoutCounter' , 0,'warningStreak',0,'failureStreak',0,'totalBlacklists',0,'isPermanentlyBlacklisted', false), numVehicles, 1);
    %%old
    % % Adjust provider vehicle speed
    speedAdjustmentRange = randi([5, 10]);
    %  RSU = RSUm(1);                      % single RSU
    
% 
%     RSU = RSUm(1);          % single RSU
% 
% % ---- precompute spaced x-positions for all providers ----
% x_min = RSU.xRange(1);
% x_max = RSU.xRange(2);
% roadLength = x_max - x_min;
% 
% % create a grid a bit larger than numVehicles and sample without replacement
% K = max(numVehicles*2, numVehicles + 5);
% gridX = linspace(x_min + 5, x_max - 5, K);   % avoid edges a bit
% idx    = randperm(K, numVehicles);
% baseX  = sort(gridX(idx));                  % one x per provider, spaced
% 
% laneOffset = 7.5;   % distance between directions (lanes)

 % Single RSU geometry
    RSU = RSUm(1);
    xMin = RSU.xRange(1);
    xMax = RSU.xRange(2);
    margin    = 10;
    laneOffset = 7.5;       % distance between lanes (m)

    % evenly spaced x positions for providers
    baseX = linspace(xMin+margin, xMax-margin, numVehicles);


 % 1) Precompute exact counts from your desired probabilities
  % p = [0.4, 0.5, 0.1];   % high / intermediate / low scenario 1 worst
    p =[0.3, 0.3, 0.4];     % high / intermediate / low scenario 3 best
    N = numVehicles;
    rawCounts = p * N;          % [0.4,0.5,0.1]*20 = [8,10,2]
    counts    = floor(rawCounts);
    remainder = N - sum(counts);   % account for any rounding drift

    % Distribute the remainder to the largest probabilities first:
    [~, order] = sort(p, 'descend');  % e.g. [2,1,3] if intermediate>high>low
    for i = 1:remainder
      counts(order(i)) = counts(order(i)) + 1;
    end
    % now counts sums exactly to N, e.g. [8,10,2]

    % 2) Build and shuffle the exact trust‐level vector
    socialTrustLevels = {'high', 'intermediate', 'low'};
    levelsFixed = repelem(socialTrustLevels, counts);
    levelsFixed = levelsFixed(randperm(N));

    % Generate random data for each provider vehicle (Vproj)
    for i = 1:numVehicles
        % Assign unique PID and vehicle role
        vehicle.PID = ['P' num2str(i)];
        vehicle.resourceStatus = 1; % Since it's a provider
        vehicle.VehicleRole = ['Vpro' num2str(i)];

        
        % For new assign the fixed trust level result 1
        vehicle.socialTrustLevel = levelsFixed{i};
         % For new assign the fixed trust level result 1

        % %   for result_3
        % %  Generate random social trust level for reputation initialization
        % % socialTrustLevels = {'high', 'intermediate', 'low'};
        % % probabilities = [0.3, 0.3, 0.4];  %  probabilities for each level
        % % cumulativeProbabilities = cumsum(probabilities);
        % % randomNumber = rand();
        % % index = find(cumulativeProbabilities >= randomNumber, 1, 'first');
        % % vehicle.socialTrustLevel = socialTrustLevels{index};
        % % for result_3

        % Initialize reputation and opinion weights based on social trust level
        [vehicle.reputation, vehicle.w_ij,vehicle.ini_alpha , vehicle.ini_beta , vehicle.ini_gamma] = calculateInitialOpinion(vehicle.socialTrustLevel);
        % vehicle.alphaG= vehicle.ini_alpha;
        % vehicle.betaG=vehicle.ini_beta;
        % vehicle.gammaG=vehicle.ini_gamma;

        % Assign malicious behavior based on social trust level
        vehicle.isMalicious   = false;
        vehicle.isActive      = true;
        vehicle.isWarning     = false;
        vehicle.blackoutCounter = 0;
        vehicle.warningStreak   = 0;
        vehicle.failureStreak   =0;
        vehicle.totalBlacklists = 0;
        vehicle.isPermanentlyBlacklisted = false;


        % Generate cryptographic keys
        vehicle.privateKey = generatePrivateKey();
        [q1, q2] = secp256k1(vehicle.privateKey, [], []);
        vehicle.publicKeyX = char(q1);
        vehicle.publicKeyY = char(q2);
        vehicle.publicKey = {vehicle.publicKeyX, vehicle.publicKeyY};

        
        % Communication range
        %vehicle.radius = 250;

        % % % RSU assignment (2)
        %RSU = RSUm(mod(i-1, numel(RSUm)) + 1);
       
        %  vehicle.RSU_ID = RSU.ID;
        %  vehicle.y = RSU.y;
        %  vehicle.x = randi(RSU.xRange);
        % 
        % % Direction
        % vehicle.direction = randi([0, 1]);
        % if vehicle.direction == 1
        %     vehicle.direction = 'Same direction';
        % else
        %     vehicle.direction = 'Opposite direction';
        % end
        % % Speed logic
        % vehicle.speed = 60 + (-1)^randi([0 1]) * randi([5 10]);

         % --- direction, lane and speed relative to requester ---
        idxReq = randi(numel(VreqPool));
        Vreqi  = VreqPool(idxReq);
        speedAdjustment = randi(speedAdjustmentRange);

        % if randi([0 1]) == 1
        %     vehicle.direction = 'Same direction';
        %     vehicle.y         = Vreqi.y;
        %     vehicle.speed     = Vreqi.speed + (-1)^randi([0 1]) * speedAdjustment;
        % else
        %     vehicle.direction = 'Opposite direction';
        %     vehicle.y         = Vreqi.y + 7.5;
        %     vehicle.speed     = Vreqi.speed + (-1)^randi([0 1]) * speedAdjustment;
        % end

%         % ---- spatial placement along the road ----
% 
% 
% % assign base x from precomputed spaced positions
% vehicle.x = baseX(i);
% 
% % choose direction: same or opposite lane
% if randi([0 1]) == 1
%     vehicle.direction = 'Same direction';
%     vehicle.y = RSU.y;                        % lane 1
% else
%     vehicle.direction = 'Opposite direction';
%     vehicle.y = RSU.y + laneOffset;           % lane 2
% end
% 
% % speed around 60 mph with a small random variation
% vehicle.speed = 60 + (-1)^randi([0 1]) * randi([5 10]);
% 
% 
%         xCandidate = Vreqi.x + randi([-30, 30]);
%         xCandidate = max(RSU.xRange(1), min(RSU.xRange(2), xCandidate));
%         vehicle.x  = xCandidate;
% 
%         vehicle.RSU_ID = RSU.ID;
%         vehicle.radius = 250;

 % communication range & RSU association
        vehicle.radius = 250;
        vehicle.RSU_ID = RSU.ID;

        % evenly spaced along the road
        vehicle.x = baseX(i);

        % random direction = lane1 or lane2
        if randi([0 1]) == 1
            vehicle.direction = 'Same direction';
            vehicle.y         = RSU.y;
        else
            vehicle.direction = 'Opposite direction';
            vehicle.y         = RSU.y + laneOffset;
        end

        % speed around 60 mph
        vehicle.speed = 60 + (-1)^randi([0 1]) * randi([5 10]);
        

        %   % Assign direction and speed,  0 for opposite, 1 for same (1)
        % vehicle.direction = randi([0, 1]);
        % if vehicle.direction == 1
        %     vehicle.direction = 'Same direction';
        %     vehicle.y = Vreqi.y;
        %     vehicle.speed = Vreqi.speed + (-1)^randi([0, 1]) * speedAdjustment;
        % else
        %     vehicle.direction = 'Opposite direction';
        %     vehicle.y = Vreqi.y + 7.5;
        %     vehicle.speed = Vreqi.speed + (-1)^randi([0, 1]) * speedAdjustment;
        % end
        % 
        % % Random x-coordinate within a logical range based on the Vreqi location
        % vehicle.x = Vreqi.x + randi([-30, 30]);

        % Related RSU info
        % vehicle.RSU_ID = randi([1, numel(RSUm)]);
        %vehicle.RSU_ID =1;

        % Initialize offloading transaction struct
        requesterPIDs = {VreqPool.PID};  % Cell array of all requester IDs

        vehicle.Offtransaction = initializeOffloadingTransactions(requesterPIDs, vehicle.ini_alpha , vehicle.ini_beta , vehicle.ini_gamma);

        % Assign computation capacity and transmission rate
        params = Params();
        if params.heterogeneousProviders
            % Variable capacity: uniform random in [min, max]
            vehicle.computationCapacity = params.minComputationCapacity + ...
                rand() * (params.maxComputationCapacity - params.minComputationCapacity);
            vehicle.transmissionRate = params.minTransmissionRate + ...
                rand() * (params.maxTransmissionRate - params.minTransmissionRate);
        else
            % Homogeneous: fixed values (original behavior)
            vehicle.computationCapacity = 10 * 1e9;
            vehicle.transmissionRate = 86e6;
        end

        % % Adjust attributes for malicious vehicles
        % if vehicle.isMalicious
        %     vehicle.computationCapacity = vehicle.computationCapacity * 0.5; % Reduced capacity
        %     vehicle.transmissionRate = vehicle.transmissionRate * 0.7; % Slower transmission
        % end

        % Add a random signature
        vehicle.signature = rand;

        % Add the vehicle structure to the array
        Vprojpool(i) = vehicle;
    end
end



% Function to generate a 64-character hexadecimal private key
function privateKey = generatePrivateKey()
    privateKey = dec2hex(randi([0, 15], 1, 64), 1);
end

% Function to calculate the initial opinion based on social trust level
function [reputation, w_ij,ini_alpha , ini_beta , ini_gamma] = calculateInitialOpinion(socialTrustLevel)
    switch socialTrustLevel
        case 'high'
            ini_alpha = 3;
            ini_beta = 2;
            ini_gamma = 1;
        case 'intermediate'
            ini_alpha = 2;
            ini_beta = 2;
            ini_gamma = 2;
        case 'low'
            ini_alpha = 1;
            ini_beta = 2;
            ini_gamma = 3;
        otherwise
            error('Invalid trust level');
    end
params = Params();
    % Calculate belief
    ini_belief = ini_alpha / (ini_alpha + ini_beta + ini_gamma);
    ini_distrust = ini_beta / (ini_alpha + ini_beta + ini_gamma);
    ini_uncertainty = ini_gamma / (ini_alpha + ini_beta + ini_gamma);

    % Calculate local subjective trust w_ij
    w_ij = [ini_belief; ini_distrust; ini_uncertainty];
    reputation = ini_belief + params.a0 * ini_uncertainty;
end

% Function to initialize offloading transactions
function Offtransaction = initializeOffloadingTransactions(requesterPIDs, ini_alpha , ini_beta , ini_gamma)
    % Initialize structs for transaction statistics
    numTransactions = struct();
    numSuccess = struct();
    numFailed = struct();


    % Loop over all requesters
    for i = 1:numel(requesterPIDs)
        targetID = requesterPIDs{i};
        numTransactions.(targetID) = 0;
        numSuccess.(targetID) = 0;
        numFailed.(targetID) = 0;

         % Belief parameters (initial α, β, γ)
        numAlpha.(targetID) = ini_alpha;     % from social trust
        numBeta.(targetID)  = ini_beta;
        numGamma.(targetID) = ini_gamma;
    end

   
    % Return offloading transaction structure
    Offtransaction = struct( ...
        'numTransactions', numTransactions, ...
        'numSuccess', numSuccess, ...
        'numFailed', numFailed, ...
        'numAlpha', numAlpha, ...
        'numBeta', numBeta, ...
        'numGamma', numGamma ...
    );
end


