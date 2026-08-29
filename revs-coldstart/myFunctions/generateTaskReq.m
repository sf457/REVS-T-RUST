function [taskRequest, msgReqContent] = generateTaskReq(Vreqi)
    % Generate random task request parameters
    % Task type (tt), input data size (St), CPU cycle required (Ct), and service price (CPt)

    % Unique task identifier (between 1 and 10)
    taskID = randi(10);

    % Randomly select one of 5 different task types
    taskType = randi([1, 5]);

    % Variable input data size based on realistic scenarios
    inputDataSizeBits =randi([50, 500] ) * 1024 * 8;  % KB to bits
    
    % Total cycles required for each task (in billions)
     cpuCycleRequired = randi([0.2* 1e9, 3.2* 1e9]) ;  % Conversion to cycles

    % CPU frequency(using a minimum value in a range of 10  to 5 GHz for vehicles)
    CPUFrequency = 5e9; 
    % Maximum tolerable delay (seconds*1000ms)
    maxTt = (cpuCycleRequired / CPUFrequency)*1000;  

    % Service price: Adjust based on task complexity and urgency
    minPrice = 50; % Adjusted minimum price
    maxPrice = 200; % Adjusted maximum price
    servicePrice = randi([minPrice, maxPrice]);

    % Retrieve vehicle request information from Vreqi
    Task_Vreq_PID = Vreqi.PID;
    Task_Vreq_signature = Vreqi.signature;
    Task_Vreq_RSU_ID = Vreqi.RSU_ID;

    % Construct task request structure
    taskRequest = struct('Task_Vreq_PID', Task_Vreq_PID, ...
                         'Task_Vreq_signature', Task_Vreq_signature, ...
                         'Task_Vreq_RSU_ID', Task_Vreq_RSU_ID, ...
                         'taskID', taskID, ...
                         'taskType', taskType, ...
                         'inputDataSize', inputDataSizeBits, ...
                         'cpuCycleRequired', cpuCycleRequired, ...
                         'servicePrice', servicePrice, ...
                         'maxTt', maxTt);

    % Construct message content string
    msgReqContent = sprintf('%s||%s||%d||%d||%d||%.0f||%.0f||%d||%.6f', ...
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



% Service coefficient in the range of [0.2, 0.4] GHz/KB
    %serviceCoefficient = 0.2 + (0.4 - 0.2) * rand; % Random value in the range