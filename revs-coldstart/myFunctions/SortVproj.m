function SortedCanditateVproj_R_D = SortVproj(VprojBlockchain)
 % Fetch reputations and related vehicle details for vehicles with the same direction
 % 1. Get vehicles in the same direction as Vreqi
    Vproj_SameD = getVehicle_SameDirection(VprojBlockchain);
    % %added for random selection 
    %  if ~isempty(Vproj_SameD)
    % SortedCanditateVproj_R_D=Vproj_SameD;
    % else
    %     disp( 'No vehicles in the same direction  or there reputation value is less than 0.4');
    %     SortedCanditateVproj_R_D = [];
    %  end
 % 2.Sort these vehicles based on reputation from highest to lowest
    if ~isempty(Vproj_SameD)
        [~, sortOrder] = sort([Vproj_SameD.reputation], 'descend');
        SortedCanditateVproj_R_D = Vproj_SameD(sortOrder);
    else
        disp( 'No vehicles in the same direction  or there reputation value is less than 0.4');
        SortedCanditateVproj_R_D = [];
    end
end

%% Helper function
function Vproj_SameD = getVehicle_SameDirection(Vproj)
numVehicles = length(Vproj);    
%disp(Vproj);
   
    % Initialize an empty array to store vehicles in the same direction
    tempVproj_SameD = [];

    % Iterate through the vehicles array
    for i = 1:numVehicles
 % Check if the current vehicle has the same direction and reputation > 0.4
        if strcmp(Vproj(i).data.direction, 'Same direction') && Vproj(i).data.reputation >= 0.4
            % Append the vehicle details to the temporary array
            tempVproj_SameD = [tempVproj_SameD, Vproj(i).data];
        % else
        %     disp( [num2str(Vproj(i).PID),' is not in the same direction  or its reputation value is less than 0.5']);
        %     disp(['direction: ', Vproj(i).data.direction]);
        %     disp(['reputation: ', num2str(Vproj(i).data.reputation)]);
        end
    end

    % Convert the temporary array to a struct array
    Vproj_SameD = struct('PID', {}, 'resourcStatus', {}, 'socialTrustLevel', {}, 'w_ij', {}, ...
                         'reputation', {}, 'privateKey', {}, 'publicKeyX', {}, 'publicKeyY', {}, ...
                         'publicKey', {}, 'direction', {}, 'speed', {}, 'x', {}, 'y', {}, ...
                         'radius', {}, 'RSU_ID', {}, 'interactionHistory', {}, 'eventHistory', {}, ...
                         'computationCapacity', {}, 'transmissionRate', {}, 'Offtransaction', {}, ...
                         'signature', {});

    if ~isempty(tempVproj_SameD)
        Vproj_SameD = tempVproj_SameD;
    end
end