function [VprojBlockchain, numProviders, numRequesters] = fetchVehicles(Vehicularblockchain, Vreqi)
    % Initialize arrays to store (resource providers) Vproj in the range
    VprojBlockchain = [];

    % Iterate through each vehicle in Vehicularblockchain
    for n = 1:length(Vehicularblockchain)
        % Check if the resource providers Vproj in the range of Vreqi and
        % RSU at the current time t of the sending request 
        %if  (Vehicularblockchain(n).data.RSU_ID == Vreqi.RSU_ID) && (Vehicularblockchain(n).data.resourcStatus == 1)
        if any((Vehicularblockchain(n).data.RSU_ID == Vreqi.RSU_ID) & (Vehicularblockchain(n).data.resourceStatus == 1))
   
        % Add the vehicle to the array of idle resources the providers array
            VprojBlockchain = [VprojBlockchain, Vehicularblockchain(n)]; 
        end
    end
    
    % Calculate the number of providers and requesters
    numProviders = numel(VprojBlockchain);
    numRequesters = length(Vreqi);
    % 
    % % Display the number of providers and requester
    % disp(['Vehicle Requesters (Vreqi) #: ' num2str(numRequesters)]);
    % disp(['Available Provider in Vreqi`s RSU range Vproj #: ' num2str(numProviders)]);
    % disp('---------------------------------------')

    % Check if there are enough providers for the requester
    if numProviders < numRequesters
        disp('There are not enough available vehicles for computation offloading in the range');
    % else
    %     % Display the resource status and other info for each element in the result array
    %     disp('Available Candidate Vproi info in VprojBlockchain:');
    %     for i = 1:numProviders
    %         disp(VprojBlockchain(i).data);
    %         disp('---------------------------------------')
    %     end
    end
end
