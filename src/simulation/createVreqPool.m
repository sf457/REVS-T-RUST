function VreqPool = createVreqPool(numRequesters, numVehicles, RSUs)
    % % Pre-allocate empty
    % VreqTemplate = struct(); % temporary
    % VreqPool = repmat(VreqTemplate, numRequesters, 1);  % Dummy init, will fix below
    RSU = RSUs(1);                 % single RSU
    xMin = RSU.xRange(1);
    xMax = RSU.xRange(2);
    margin = 10;                   % leave 10 m margin at each end

    % evenly spaced x positions for requesters
    baseX = linspace(xMin+margin, xMax-margin, numRequesters);
% Initialize an empty array to store requester structures
VreqPool = repmat(struct( ...
    'PID', '', ...
    'VehicleRole', '', ...
    'resourceStatus', 0, ...
    'reputation', 0.85, ...
    'privateKey', '', ...
    'publicKeyX', '', ...
    'publicKeyY', '', ...
    'publicKey', [], ...
    'direction', 'North', ...
    'speed', 0.0, ...
    'x', 0, ...
    'y', 0, ...
    'radius', 250, ...
    'RSU_ID', 1, ...
    'Offtransaction', [], ...
    'signature', 0.0 ...
), numRequesters, 1);
 % Use the first RSU (assumes RSUmap() returns exactly one RSU)
  
    for i = 1:numRequesters
        %RSU = RSUs(mod(i-1, numel(RSUs)) + 1);  % Round-robin RSU assignment
        Vreq.PID = ['R' num2str(i)];
        Vreq.VehicleRole = ['Vreq' num2str(i)];
        Vreq.resourceStatus = 0;
        Vreq.reputation = 0.85;
        % Vreq.direction = 'North';
        % Vreq.y = RSU.y;
        % Vreq.x = randi(RSU.xRange);
        % Vreq.radius = 250;
        % Vreq.speed = 60 + 10*randn;
        % Vreq.RSU_ID = RSU.ID;

         % position along the road
        Vreq.x      = baseX(i);
        Vreq.y      = RSU.y;
        Vreq.radius = 250;

        % simple motion model
        Vreq.direction = 'North';
        Vreq.speed     = 60 + 10*randn;

        % RSU association
        Vreq.RSU_ID = RSU.ID;


        Vreq.privateKey = generatePrivateKey();
        [qx, qy] = secp256k1(Vreq.privateKey, [], []);
        Vreq.publicKeyX = char(qx);
        Vreq.publicKeyY = char(qy);
        Vreq.publicKey = {Vreq.publicKeyX, Vreq.publicKeyY};


        % Init interaction records
        numTransactions = struct(); numSuccess = struct(); numFailed = struct(); 
       
        % for j = 1:numVehicles
        %     targetID = ['P' num2str(j)];
        %     numTransactions.(targetID) = 0;
        %     numSuccess.(targetID) = 0;
        %     numFailed.(targetID) = 0;
        % end

        Vreq.Offtransaction = struct( ...
            'numTransactions', numTransactions, ...
            'numSuccess', numSuccess, ...
            'numFailed', numFailed ...
        );

        Vreq.signature = rand();

        % Fix struct shape on first iteration
        % if i == 1
        %     VreqPool(numRequesters,1) = Vreq;
        % end
        VreqPool(i) = Vreq;
    end
end


%% Helper functions
function privateKey = generatePrivateKey()
    privateKey = dec2hex(randi([0, 15], 1, 64), 1);
end


