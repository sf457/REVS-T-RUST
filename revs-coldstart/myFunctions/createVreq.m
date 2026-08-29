function Vreqi = createVreq(numVehicles)
    % Initialize an empty structure
    Vreqi = struct();

    % Initialize structures for transactions
    numTransactions = struct();
    numSuccess = struct();
    numFailed = struct();
    TransactionsID = struct();

    % Assign data to fields of the structure
    Vreqi.PID = 'V1'; % since it's the requester
    Vreqi.resourceStatus = 0;
    Vreqi.VehicleRole = 'Vreq1';
    Vreqi.reputation = 0.8577; % Assume it has high reputation (honest)

    % Step 1: Generate random private key
    Vreqi.privateKey = generatePrivateKey();
    
    % Step 2: Generate the corresponding public key using the secp256k1 function
    [q1, q2] = secp256k1(Vreqi.privateKey, [], []);
    
    % Step 3: Assign the public key to vehicle structure
    Vreqi.publicKeyX = char(q1);
    Vreqi.publicKeyY = char(q2);
    
    % Step 4: Combine the public key coordinates into one variable
    Vreqi.publicKey = [Vreqi.publicKeyX, Vreqi.publicKeyY];

    % Generate random speeds from normal distribution
     %meanSpeed = 60;  % Mean speed in mph
     %stdDevSpeed = 10;  % Standard deviation of speed in mph
    Vreqi.speed=normrnd(60,10,1);  

    Vreqi.direction = 'North';
    Vreqi.x = 50;
    Vreqi.y = 70;

    Vreqi.radius = 250;  % Communication range
    Vreqi.RSU_ID = 1;

    % Initialize interaction and event history for each vehicle
    for i = 1:numVehicles
        for j = 1 : numVehicles
            if i ~= j
                % Generate target vehicle IDs
                targetVehicleID2 = ['V' num2str(i+1)];

                % Store events for positive and negative interactions
                numSuccess.(targetVehicleID2) = 0;
                numFailed.(targetVehicleID2) = 0;

                % Store the number of interactions with other vehicles
                numTransactions.(targetVehicleID2) = 0;
            end
        end
    end

% %    Initialize interaction and event history for each vehicle
% for i = 1:numVehicles
%     for j = 1:numVehicles
%         if i ~= j
%             Generate target vehicle ID
%             targetVehicleID2 = ['V' num2str(j)];
% 
%             Initialize interaction history
%             numSuccess.(targetVehicleID2) = 0;
%             numFailed.(targetVehicleID2) = 0;
%             numTransactions.(targetVehicleID2) = 0;
%         end
%     end
% end


    % Assign interaction and event history to the vehicle
    Vreqi.Offtransaction = struct('numTransactions', numTransactions, 'numSuccess', numSuccess, 'numFailed', numFailed, 'TransactionsID', TransactionsID);

    Vreqi.signature = 0.8144;
end

%% Helper Function
% Function to generate a 64-character hexadecimal private key
function privateKey = generatePrivateKey()
    privateKey = dec2hex(randi([0, 15], 1, 64), 1);
end
