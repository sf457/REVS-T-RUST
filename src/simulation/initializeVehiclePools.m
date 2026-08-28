function [VreqPool, Vprojpool] = initializeVehiclePools(numRequesters, numProviders,RSUm)
    % runsimulation initializes the requester and provider vehicle pools
    % Inputs:
    %   - numRequesters: number of vehicles that will request offloading tasks
    %   - numProviders: number of vehicles that will act as offloading service providers
    % Outputs:
    %   - VreqPool: array of requester vehicle structs
    %   - Vprojpool: array of provider vehicle structs

    %RSUm = RSUmap();  % Get RSU configuration (position and range)
    % % 2. Define RSUs
    % RSU1 = struct('ID', 1, 'Location', [20, 90], 'range', 300, 'connectedVehicles', []);
    % RSU2 = struct('ID', 2, 'Location', [320, 90], 'range', 300, 'connectedVehicles', []);
    % RSUm = [RSU1, RSU2];

    % Create the requester pool based on RSU mapping and number of vehicles
    VreqPool  = createVreqPool(numRequesters, numProviders, RSUm);

    % Create the provider pool based on requesters and RSU distribution
    Vprojpool = generateVprojpool(numProviders, VreqPool, RSUm);
end



% function [VreqPool, Vprojpool] = runsimulation(numRequesters,numProviders)
% 
% % % Simulation parameters
% %     numVehicles_min = 6; % Minimum number of vehicles
% %     numVehicles_max = 20; % Maximum number of vehicles
% %     j = randi([numVehicles_min, numVehicles_max]); % Number of vehicles
% 
% % % 2. Define RSUs
% %     RSU1 = struct('ID', 1, 'Location', [20, 90], 'range', 300, 'connectedVehicles', []);
% %     RSU2 = struct('ID', 2, 'Location', [320, 90], 'range', 300, 'connectedVehicles', []);
% %     RSUm = [RSU1, RSU2];
% 
% RSUm = RSUmap();
%     % 1. Define Vreq (requester)
%     %Vreqi = createVreq(poolSize);
% %VreqPool = createVreqPool(numRequesters, providerpoolSize);
%     VreqPool  = createVreqPool(numRequesters,numProviders, RSUm);
% 
% 
%     % % 3. Generate task request
%     % [Vreqi.Req, Vreqi.msgReqContent] = generateTaskReq(Vreqi);
%     % Req = Vreqi.Req;
% 
%     % 4. Generate provider vehicles pool (Vprojs)
%     %Vprojs = generateVproj2(poolSize, Vreqi) ;                                                 
% Vprojpool = generateVprojpool(numProviders, VreqPool, RSUm);
% end
% 
% function RSUs = RSUmap()
%     % Define RSUs as a struct array with IDs, positions, and region ranges
%     RSUs(1).ID = 1;
%     RSUs(1).xRange = [0, 250];
%     RSUs(1).y = 70;
% 
%     RSUs(2).ID = 2;
%     RSUs(2).xRange = [300, 550];
%     RSUs(2).y = 70;
% 
%     % Add more RSUs if needed
% end