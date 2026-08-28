% function [taskRequest, msgReqContent] = generateTaskReq(Vreqi)
%     % Generate random task request parameters
%     % Task type (tt), input data size (St), CPU cycle required (Ct), and service price (CPt)
% 
%     % Unique task identifier (between 1 and 10)
%     taskID = randi(10);
% 
%     % Randomly select one of 5 different task types
%     taskType = randi([1, 5]);
% 
%     % Variable input data size based on realistic scenarios
%     inputDataSizeBits =randi([50, 500] ) * 1024 * 8;  % KB to bits
% 
%     % Total cycles required for each task (in billions)
%      cpuCycleRequired = randi([0.2* 1e9, 3.2* 1e9]) ;  % Conversion to cycles
% 
%     % CPU frequency(using a minimum value in a range of 10  to 5 GHz for vehicles)
%     CPUFrequency = 5e9; 
%     % Maximum tolerable delay (seconds*1000ms)
%     maxTt = (cpuCycleRequired / CPUFrequency)*1000;  
% 
%     % Service price: Adjust based on task complexity and urgency
%     minPrice = 50; % Adjusted minimum price
%     maxPrice = 200; % Adjusted maximum price
%     servicePrice = randi([minPrice, maxPrice]);
% 
%     % Retrieve vehicle request information from Vreqi
%     Task_Vreq_PID = Vreqi.PID;
%     Task_Vreq_signature = Vreqi.signature;
%     Task_Vreq_RSU_ID = Vreqi.RSU_ID;
% 
%     % Construct task request structure
%     taskRequest = struct('Task_Vreq_PID', Task_Vreq_PID, ...
%                          'Task_Vreq_signature', Task_Vreq_signature, ...
%                          'Task_Vreq_RSU_ID', Task_Vreq_RSU_ID, ...
%                          'taskID', taskID, ...
%                          'taskType', taskType, ...
%                          'inputDataSize', inputDataSizeBits, ...
%                          'cpuCycleRequired', cpuCycleRequired, ...
%                          'servicePrice', servicePrice, ...
%                          'maxTt', maxTt);
% 
%     % Construct message content string
%     msgReqContent = sprintf('%s||%s||%d||%d||%d||%.0f||%.0f||%d||%.6f', ...
%                             taskRequest.Task_Vreq_PID, ...
%                             taskRequest.Task_Vreq_signature, ...
%                             taskRequest.Task_Vreq_RSU_ID, ...
%                             taskRequest.taskID, ...
%                             taskRequest.taskType, ...
%                             taskRequest.inputDataSize, ...
%                             taskRequest.cpuCycleRequired, ...
%                             taskRequest.servicePrice, ...
%                             taskRequest.maxTt);
% end



% Service coefficient in the range of [0.2, 0.4] GHz/KB
    %serviceCoefficient = 0.2 + (0.4 - 0.2) * rand; % Random value in the range

function [taskRequest, msgReqContent] = generateTaskReq(Vreqi)
% GENERATETASKREQ  Create a task request with explicit unit fields.
%
% Units:
%   - inputDataSizeBits : bits
%   - cpuCycleRequired  : cycles
%   - maxTt_ms          : milliseconds (deadline)
%
% Used by:
%   - Vreqi.Req (or REq)
%   - computeRequiredStayTime(taskRequest, SVpro)

    % === 1) Identifier and type ===
    taskID   = randi(10);        % unique-ish ID [1..10]
    taskType = randi([1, 5]);    % one of 5 task classes

    % === 2) Input data size ===
    % Sample size in KB, then convert to bits
    inputSizeKB       = randi([50, 500]);          % KB
    inputDataSizeBits = inputSizeKB * 1024 * 8;    % bits (double)

    % === 3) CPU cycles required ===
    % range: 0.2e9 .. 3.2e9 cycles (integers)
    minCycles        = round(0.2e9);
    maxCycles        = round(3.2e9);
    cpuCycleRequired = randi([minCycles, maxCycles]);  % cycles (double)

    % === 4) Deadline (max tolerable delay) ===
    % Assume nominal CPU frequency of requester (or profile) in Hz
    CPUFrequency = 5e9;  % 5 GHz
    % Max tolerable delay derived from computation only (can later combine with tx)
    maxTt = (cpuCycleRequired / CPUFrequency) * 1000;   % milliseconds

    % === 5) Service price ===
    minPrice     = 50;
    maxPrice     = 200;
    servicePrice = randi([minPrice, maxPrice]);

    % === 6) Build taskRequest struct ===
    taskRequest = struct( ...
        'Task_Vreq_PID',       Vreqi.PID, ...
        'Task_Vreq_signature', Vreqi.signature, ...
        'Task_Vreq_RSU_ID',    Vreqi.RSU_ID, ...
        'taskID',              taskID, ...
        'taskType',            taskType, ...
        'inputDataSize',   inputDataSizeBits, ...
        'cpuCycleRequired',    cpuCycleRequired, ...
        'servicePrice',        servicePrice, ...
        'maxTt',            maxTt ...
    );

    % === 7) Serialize to message content string ===
    msgReqContent = sprintf('%s||%s||%d||%d||%d||%.0f||%.0f||%d||%.3f', ...
        taskRequest.Task_Vreq_PID, ...
        taskRequest.Task_Vreq_signature, ...
        taskRequest.Task_Vreq_RSU_ID, ...
        taskRequest.taskID, ...
        taskRequest.taskType, ...
        taskRequest.inputDataSize, ...
        taskRequest.cpuCycleRequired, ...
        taskRequest.servicePrice, ...
        taskRequest.maxTt);
end
