function [transmissionTime, executionTime, totalOffloadingLatency, totalCost, offloadingSuccessstatus] = V2VOffloading3(taskRequest, SVpro, Vreq)
    % Validate input parameters
    if isempty(taskRequest) || isempty(SVpro) || isempty(Vreq)
        error('Invalid input parameters');
    end

    % Constants for V2V cost calculation
    psiV2V = 0.5; % Transmission time cost constant
    etaV2V = 1; % Execution time cost constant

    % Extract computation capacity and transmission rate from SVpro
    fVi = SVpro.computationCapacity;
    transmissionRate = SVpro.transmissionRate;

    % Extract taskRequest information
    Dn = taskRequest.inputDataSize; % Input data size in bytes
    Bn = taskRequest.cpuCycleRequired; % CPU cycles required
    tnMax = taskRequest.maxTt; % Maximum allowable time

    % Calculate transmission time, execution time, total offloading latency, total cost, and offloading success status
    [transmissionTime, executionTime, totalOffloadingLatency, totalCost, offloadingSuccessstatus] = calculateV2VOffloading(Dn, Bn, fVi, tnMax, psiV2V, etaV2V, transmissionRate);

    % % Display debug information
    % disp('Task Request Information:');
    % disp(['Input Data Size (Dn): ', num2str(Dn), ' bits']);
    % disp(['CPU Cycles Required (Bn): ', num2str(Bn)]);
    % disp(['Maximum Allowable Time (tnMax): ', num2str(tnMax), ' ms']);
    % disp(['Transmission Rate: ', num2str(transmissionRate), ' Mbps']);
    % disp(['Computation Capacity (fVi): ', num2str(fVi), ' cycles/ms']);
    % disp('Calculated Metrics:');
    % disp(['Transmission Time: ', num2str(transmissionTime), ' ms']);
    % disp(['Execution Time: ', num2str(executionTime), ' ms']);
    % disp(['Total Offloading Latency: ', num2str(totalOffloadingLatency), ' ms']);
    % disp(['Total Cost of V2V Computing: ', num2str(totalCost)]);
    % disp(['Offloading Success Status: ', num2str(offloadingSuccessstatus)]);

    % Display performance metrics
    offloadingSuccessRate = calculateOffloadingSuccessRate(offloadingSuccessstatus);
    avgTaskCompletionTime = calculateTaskCompletionTime(transmissionTime, executionTime, offloadingSuccessstatus);
    % disp('Performance Metrics:');
    % disp(['Offloading Success Rate: ', num2str(offloadingSuccessRate), ' %']);
    % disp(['Average Task Completion Time: ', num2str(avgTaskCompletionTime), ' ms']);
end

%% Helper functions
function [transmissionTime, executionTime, totalOffloadingLatency, totalCost, offloadingSuccess] = calculateV2VOffloading(Dn, Bn, fVi, tnMax, psiV2V, etaV2V, transmissionRate)
    % Calculate transmission time from Vn to Vi
    transmissionTime = Dn  / transmissionRate; 

    % Calculate execution time of Vi
    executionTime = Bn / fVi;

    % Calculate total offloading latency from Vn to Vi
    totalOffloadingLatency = (transmissionTime + executionTime) *1000;

    % Calculate total cost of V2V computing
    totalCost = psiV2V * transmissionTime + etaV2V * executionTime;

    % Check if task completion is within deadline (tnMax)
    if totalOffloadingLatency <= tnMax
        % Task completed within deadline
        offloadingSuccess = true;
    else
        % Task not completed within deadline
        offloadingSuccess = false;
    end
end

function offloadingSuccessRate = calculateOffloadingSuccessRate(offloadingSuccess)
    % Calculate offloading success rate
    offloadingSuccessRate = mean(offloadingSuccess) * 100 ;% Convert to percentage
end

function avgTaskCompletionTime = calculateTaskCompletionTime(transmissionTime, executionTime, offloadingSuccess)
    % Calculate average task completion time for successful offloading
    successfulLatencies = offloadingSuccess .* (transmissionTime + executionTime);
    avgTaskCompletionTime = mean(successfulLatencies(successfulLatencies > 0)) ;% Only consider successful latencies
end
