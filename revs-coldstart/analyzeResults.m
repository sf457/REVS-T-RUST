function analysis = analyzeResults(Vproj)
    % Analyze the number of malicious vs honest providers
    numMalicious = sum([Vproj.isMalicious]);
    numHonest = numel(Vproj) - numMalicious;

    % Calculate average reputation
    avgReputation = mean([Vproj.reputation]);

    % Collect results
    analysis = struct();
    analysis.numMalicious = numMalicious;
    analysis.numHonest = numHonest;
    analysis.avgReputation = avgReputation;

    % Display results (optional)
    disp(['Malicious Vehicles: ', num2str(numMalicious)]);
    disp(['Honest Vehicles: ', num2str(numHonest)]);
    disp(['Average Reputation: ', num2str(avgReputation)]);
end
