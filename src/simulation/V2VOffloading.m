function [transmissionTime, executionTime, totalOffloadingLatency, totalCost, offloadingSuccessstatus] = V2VOffloading(taskRequest, SVpro, Vreq, runIndex)
%V2VOFFLOADING  Compute offload metrics for one request-provider service pair.
% Units:
%  - taskRequest.inputDataSizeBits (bits)
%  - taskRequest.cpuCycleRequired (cycles)
%  - SVpro.transmissionRate (bits/sec)
%  - SVpro.computationCapacity (cycles/sec)
%  - deadlines and returned latency in milliseconds
%  - runIndex: global simulation run counter (1..T), used by 'firsthalf'
%
% Attack Pattern Support:
%  - 'always'    : Malicious providers attack 100% of the time
%  - 'onoff'     : Alternating attack/honest based on per-provider interaction count
%  - 'firsthalf' : Honest for global runs [1, T/2), attack for [T/2, T] (Malicious 1)
%
% Attack Patterns from Literature:
%   Malicious 1: [1,1,...,1, 0,0,...,0] - First half normal, second half attack
%   Malicious 2: [1,0,1,0,...,1,0]      - Alternating normal and attack

    % Validate input parameters
    if isempty(taskRequest) || isempty(SVpro) || isempty(Vreq)
        error('Invalid input parameters');
    end

    % Get attack parameters
    params = Params();

    % cost weights (units: cost per second or per-cycle whichever prefer)
    % Constants for V2V cost calculation (ignore it currentlly)
    psiV2V = 0.5; % Transmission time cost constant
    etaV2V = 1; % Execution time cost constant

    % Extract base computation capacity and transmission rate from SVpro
    fVi = SVpro.computationCapacity; % cycles/sec
    transmissionRate = SVpro.transmissionRate; % bits/sec

    % === On-Off Attack Logic ===
    % Check if provider is malicious and apply attack pattern
    if isfield(SVpro, 'isMalicious') && SVpro.isMalicious
        % Get total interactions for this provider (across all requesters)
        totalInteractions = 0;
        if isfield(SVpro, 'Offtransaction') && isfield(SVpro.Offtransaction, 'numTransactions')
            txFields = fieldnames(SVpro.Offtransaction.numTransactions);
            for i = 1:numel(txFields)
                totalInteractions = totalInteractions + SVpro.Offtransaction.numTransactions.(txFields{i});
            end
        end

        % Determine if this interaction is an attack
        shouldAttack = false;

        if strcmpi(params.attackType, 'always')
            % Always attack (100% attack rate)
            % Pattern: [0,0,0,...,0] (all attacks)
            shouldAttack = true;

        elseif strcmpi(params.attackType, 'onoff')
            % On-off attack (Malicious 2 style): alternating attack/honest
            % Pattern: attack for first N interactions of each period, then honest
            %
            % Attack rate = attacksPerPeriod / onOffPeriod
            %   - run_baseline_comparison.m uses period=2, attacks=1 → 50%
            %   - Params.m default is period=3, attacks=1 → 33%
            %
            % Example with period=2 (50% attack rate):
            %   positions: 0(A), 1(H), 0(A), 1(H), ...
            %
            % IMPORTANT: Use attacksPerPeriod (integer) instead of duty*period
            % to avoid floor() rounding bugs (e.g., floor(0.33*3)=0, not 1!)
            cyclePosition = mod(totalInteractions, params.onOffPeriod);
            shouldAttack = (cyclePosition < params.attacksPerPeriod);

        elseif strcmpi(params.attackType, 'firsthalf')
            % First-half honest, second-half attack (Malicious 1 style)
            % All malicious providers switch simultaneously at the global
            % simulation midpoint, matching Xu et al. 2021 "Malicious 1".
            % Uses the global run index (not per-provider interaction count)
            % so that the phase transition is synchronous and observable.
            halfPoint = floor(params.totalSimulationPeriod / 2);
            shouldAttack = (runIndex > halfPoint);
        end

        % Apply degradation if attacking
        if shouldAttack
            fVi = fVi * params.maliciousCapacityFactor;
            transmissionRate = transmissionRate * params.maliciousTransmissionFactor;
        end
    end

    % Extract taskRequest information
    Dn = taskRequest.inputDataSize; % Input data size in bits
    Bn = taskRequest.cpuCycleRequired; % CPU cycles required
    tnMax = taskRequest.maxTt; % Maximum allowable time

    % Calculate transmission time, execution time, total offloading latency, total cost, and offloading success status
    [transmissionTime, executionTime, totalOffloadingLatency, totalCost, offloadingSuccessstatus] = calculateV2VOffloading(Dn, Bn, fVi, tnMax, psiV2V, etaV2V, transmissionRate);

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

    % Check if task completion is within deadline (tnMax).
    if totalOffloadingLatency <= tnMax
        % Task completed within deadline
        offloadingSuccess = true;
    else
        % Task not completed within deadline
        offloadingSuccess = false;
    end
end

