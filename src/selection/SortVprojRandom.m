function SortedCanditateVproj_D = SortVprojRandom(VprojBlockchain)
% Filter to same‐direction + rep≥minReputation, then sort descending by rep.
 % 1. Get vehicles in the same direction as Vreqi with enough rep
  
    Vproj_SameD = getVehicle_SameDirection(VprojBlockchain);
    % %added for random selection 
    %  if ~isempty(Vproj_SameD)
    % SortedCanditateVproj_R_D=Vproj_SameD;
    % else
    %     disp( 'No vehicles in the same direction  or there reputation value is less than 0.4');
    %     SortedCanditateVproj_R_D = [];
    %  end
SortedCanditateVproj_D=Vproj_SameD;
    
 % % 2.Sort these vehicles by reputation descending from highest to lowest
 %    if ~isempty(Vproj_SameD)
 %        [~, sortOrder] = sort([Vproj_SameD.reputation], 'descend');
 %        SortedCanditateVproj_R_D = Vproj_SameD(sortOrder);
 %    else
 %        disp( 'No vehicles in the same direction  or there reputation value is less than 0.4');
 %        SortedCanditateVproj_R_D = [];
 %    end
end

%% Helper function
function Vproj_SameD = getVehicle_SameDirection(Vproj)
numVehicles = length(Vproj); 
% disp('Vproj(1).data before adding to tempVproj_SameD')
% disp(Vproj(1).data);
% 
    % Initialize an empty array to store vehicles in the same direction
    tempVproj_SameD = [];

    % Iterate through the vehicles array
    for i = 1:numVehicles
 % Check if the current vehicle has the same direction and reputation > 0.4
        if strcmp(Vproj(i).direction, 'Same direction') 
            % Append the vehicle details to the temporary array
            %disp(tempVproj_SameD)
            %disp(Vproj(i).data);
            tempVproj_SameD = [tempVproj_SameD, Vproj(i)];
        % else
        %     disp( [num2str(Vproj(i).PID),' is not in the same direction  or its reputation value is less than 0.5']);
        %     disp(['direction: ', Vproj(i).data.direction]);
        %     disp(['reputation: ', num2str(Vproj(i).data.reputation)]);
        end
    end

    if ~isempty(tempVproj_SameD)
        Vproj_SameD = tempVproj_SameD;
    else
         Vproj_SameD = [];
          % disp( 'No vehicles in the same direction ');
    end
end

% 
% function sameDirBlocks = getVehicle_SameDirection(allBlocks, minReputation)
% % Return only those bc.Block objects whose data.direction  
% % is 'Same direction' AND whose data.reputation >= minReputation.
% 
%     % Pull out just the .data structs
%     D = [ allBlocks.data ];
% 
%     % Build a logical mask
%     mask = strcmp({D.direction}, 'Same direction') & [D.reputation] >= minReputation;
% 
%     % Index into the original array of blocks
%     sameDirBlocks = allBlocks(mask);
% end