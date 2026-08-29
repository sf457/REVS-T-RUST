function updatedReputationScore = calculateReputation2(SVpro, N, Vreqi, Updated_Vreqi, reputationData)

    % ✅ Step 1: Extract Requester & Provider IDs
    VreqiID = Vreqi.PID;
    SVproID = SVpro.PID;
    disp(['Calculating Reputation for Provider: ', SVproID, ' with Requester: ', VreqiID]);

    % ✅ Step 2: Extract past trust history
    socialTrustLevel = SVpro.socialTrustLevel;
    tAll = SVpro.Offtransaction.TransactionsID.totalOffloadingLatency;  
    offloading_success = SVpro.Offtransaction.TransactionsID.offloadingSuccessstatus;

    % ✅ Step 3: Assign alpha, beta, gamma based on social trust level
    switch socialTrustLevel
        case 'high', ini_alpha = 3; ini_beta = 2; ini_gamma = 1;
        case 'intermediate', ini_alpha = 2; ini_beta = 2; ini_gamma = 2;
        case 'low', ini_alpha = 1; ini_beta = 2; ini_gamma = 3;
        otherwise, error('Invalid trust level');
    end

    % ✅ Step 4: Compute Local Subjective Trust
    subjectiveOpinion = calculateLocalSubjectiveTrust(ini_alpha, ini_beta, ini_gamma, tAll, socialTrustLevel, offloading_success);

    % ✅ Step 5: Compute Interaction Frequency (IF_ij)
    totalInteractions = sum(structfun(@(x) x, SVpro.Offtransaction.numTransactions, 'UniformOutput', true));

    if isfield(SVpro.Offtransaction.numTransactions, VreqiID)
        N_ij = SVpro.Offtransaction.numTransactions.(VreqiID);
    else
        N_ij = 0;
    end

    IF_ij = (totalInteractions > 0) * (N_ij / totalInteractions);  % Prevent division by zero

    % ✅ Step 6: Compute Recommended Opinions
    if totalInteractions == 0  
        recommendedOpinion = [0.5, 0.5, 0.5];  
    else
        recommendedOpinion = calculateRecommendedOpinion(SVpro, Vreqi, subjectiveOpinion);
    end

    % ✅ Step 7: Ensure no NaN values before combining opinions
    subjectiveOpinion(isnan(subjectiveOpinion)) = 0.5;
    recommendedOpinion(isnan(recommendedOpinion)) = 0.5;

    % ✅ Step 8: Compute Final Trust
    combinedOpinions = combineOpinions(subjectiveOpinion, recommendedOpinion);
    updatedReputationScore = computeFinalReputation(combinedOpinions);

    % ✅ Step 9: Ensure reputation is within [0,1]
    updatedReputationScore = max(0, min(1, updatedReputationScore));

    % ✅ Step 10: Save updated reputation
    SVpro.reputation = updatedReputationScore;
    disp(['Updated Reputation for ', SVproID, ': ', num2str(updatedReputationScore)]);
end
