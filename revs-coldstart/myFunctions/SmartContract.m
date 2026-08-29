function [VprojBlockchain, CandidateVproj,SVpro,Updated_Vreqi] = SmartContract(Vehicularblockchain, Vreqi)
% Initialize outputs
VprojBlockchain = [];
CandidateVproj = [];
SVpro = [];
Updated_Vreqi=Vreqi;
% %for main result 
% w1 = 0.7;  % Weight for reputation
% w2 = 0.3;  % Weight for stay time
% %for main result 

% %for result 2
% w1 = 0.3;  % Weight for reputation
% w2 = 0.7;  % Weight for stay time
% %for result 2
% 
% %for result 3
% w1 = 0.5;  % Weight for reputation
% w2 = 0.5;  % Weight for stay time
% %for result 3

%for result 4
w1 = 1.0;  % Weight for reputation
w2 = 0.0;  % Weight for stay time
%for result 4

% A1. Fetch available vehicles (Vproi) in the RSU range
[VprojBlockchain, numProviders, numRequesters] = fetchVehicles(Vehicularblockchain, Vreqi);

% B. Sort the available providers Vproi to find the candidate ones
if numProviders >= numRequesters
    % Sort vehicles based on direction and reputation
    CandidateVproj = SortVproj(VprojBlockchain);

    if ~isempty(CandidateVproj)
        % Display sorted vehicle details
        % disp('Sorted vehicle details for all vehicles with the same direction:');
        % for i = 1:numel(CandidateVproj)
        %     disp(CandidateVproj(i));
        %     disp('---------------------------------------');
        % end

        % C. Select the best one (SVpro) that meets the criteria
        [SVpro,CandidateVproj] = SelectedVproj(CandidateVproj, Vreqi,w1, w2);
        %SVpro = SelectedVprojRandom(CandidateVproj);
        % if SVpro.isMalicious
        %     disp('Selected a malicious provider!');
        % else
        %     disp('Selected an honest provider.');
        % end
        % D. Simulate offloading process
        [transmissionTime, executionTime, totalOffloadingLatency, totalCost, offloadingSuccessstatus] = V2VOffloading3(Vreqi.Req, SVpro, Vreqi);
        % E.1 Update SVpro offloading field
        VreqiID = Vreqi.PID;
        %update Transaction numbers
        SVpro.Offtransaction.numTransactions.(VreqiID) = SVpro.Offtransaction.numTransactions.(VreqiID) + 1;

        % Update Success and Failed transaction numbers based on offloading success
        if offloadingSuccessstatus
            SVpro.Offtransaction.numSuccess.(VreqiID) = SVpro.Offtransaction.numSuccess.(VreqiID) + 1;
        else
            SVpro.Offtransaction.numFailed.(VreqiID) = SVpro.Offtransaction.numFailed.(VreqiID) + 1;
        end

        % E.2 Update Vreqi offloading field
        SVproID = SVpro.PID;
        %update Transaction numbers
        Vreqi.Offtransaction.numTransactions.(SVproID) = Vreqi.Offtransaction.numTransactions.(SVproID) + 1;

        % Update Success and Failed transaction numbers based on offloading success
        if offloadingSuccessstatus
            Vreqi.Offtransaction.numSuccess.(SVproID) = Vreqi.Offtransaction.numSuccess.(SVproID) + 1;
        else
            Vreqi.Offtransaction.numFailed.(SVproID) = Vreqi.Offtransaction.numFailed.(SVproID) + 1;
        end

        % F.1 Create transaction field SVpro
        TransactionsID1 = [num2str(SVpro.PID), '_', num2str(Vreqi.PID)];
        %SVpro.Offtransaction.(['TransactionsID', TransactionsID1])= struct( ...
        SVpro.Offtransaction.TransactionsID= struct( ...
            'TransactionsID',TransactionsID1, ...
            'offloadingSuccessstatus', offloadingSuccessstatus, ...
            'transmissionTime', transmissionTime, ...
            'executionTime', executionTime, ...
            'totalOffloadingLatency', totalOffloadingLatency, ...
            'totalCost', totalCost);

        % F.2 Create transaction field for Vreqi

        Updated_Vreqi.Offtransaction.numTransactions=Vreqi.Offtransaction.numTransactions;
        Updated_Vreqi.Offtransaction.numSuccess=Vreqi.Offtransaction.numSuccess;
        Updated_Vreqi.Offtransaction.numFailed=Vreqi.Offtransaction.numFailed;

        TransactionsID2 = [num2str(Vreqi.PID), '_', num2str(SVpro.PID)];
        Updated_Vreqi.Offtransaction.TransactionsID = struct( ...
            'TransactionsID1',TransactionsID2, ...
            'offloadingSuccessstatus', offloadingSuccessstatus, ...
            'transmissionTime', transmissionTime, ...
            'executionTime', executionTime, ...
            'totalOffloadingLatency', totalOffloadingLatency, ...
            'totalCost', totalCost);

        % % Display debug information
        % disp('Vreqi_Offtransaction:');
        % disp(Updated_Vreqi.Offtransaction.numTransactions);
        % disp(Vreqi.Offtransaction. TransactionsID);
        % disp('SVpro_Offtransaction:');
        % disp(SVpro.Offtransaction.numTransactions);
        % %disp(SVpro.Offtransaction.TransactionsID);
    else
        disp('No suitable vehicle found for offloading.');
        SVpro = [];
    end
else
    disp('Not enough available vehicles found to select.');
end
end
