classdef diagnosticHelpers
%DIAGNOSTICHELPERS Shared helper functions extracted from run_baseline_comparison.m
%   These functions are local to run_baseline_comparison.m and not accessible
%   from external scripts. This class re-exposes them as static methods
%   for use by the diagnostic verification protocol.
%
%   Usage:
%     blockchainObj = diagnosticHelpers.initModelFields(blockchainObj);
%     results = diagnosticHelpers.initResults(100);
%     etc.

    methods (Static)

        function blockchainObj = initModelFields(blockchainObj)
            chain = blockchainObj.blockchain;
            for i = 1:numel(chain)
                if isfield(chain(i).data, 'VehicleRole') && startsWith(chain(i).data.VehicleRole, 'Vpro')
                    if ~isfield(chain(i).data, 'betaAlpha'), chain(i).data.betaAlpha = 1; end
                    if ~isfield(chain(i).data, 'betaBeta'), chain(i).data.betaBeta = 1; end
                    if ~isfield(chain(i).data, 'globalFailureStreak'), chain(i).data.globalFailureStreak = 0; end
                    if ~isfield(chain(i).data, 'maxFailureStreak'), chain(i).data.maxFailureStreak = 0; end
                    if ~isfield(chain(i).data, 'totalSelections'), chain(i).data.totalSelections = 0; end
                    if ~isfield(chain(i).data, 'totalFailuresCaused'), chain(i).data.totalFailuresCaused = 0; end
                    if ~isfield(chain(i).data, 'everBlacklisted'), chain(i).data.everBlacklisted = false; end
                    if ~isfield(chain(i).data, 'selectionsBeforeFirstBlacklist'), chain(i).data.selectionsBeforeFirstBlacklist = NaN; end
                    if ~isfield(chain(i).data, 'trustValue'), chain(i).data.trustValue = 0.5; end
                    if ~isfield(chain(i).data, 'lastInteractionRun'), chain(i).data.lastInteractionRun = 0; end
                    if ~isfield(chain(i).data, 'yangTrustValue'), chain(i).data.yangTrustValue = 0; end
                    if ~isfield(chain(i).data, 'yangPositiveRatings'), chain(i).data.yangPositiveRatings = 0; end
                    if ~isfield(chain(i).data, 'yangNegativeRatings'), chain(i).data.yangNegativeRatings = 0; end
                end
            end
            blockchainObj.blockchain = chain;
        end

        function results = initResults(numSim)
            results.offSuccessStatus = nan(1, numSim);
            results.initialReputation = nan(1, numSim);
            results.updatedReputation = nan(1, numSim);
            results.SVproisMalicious = nan(1, numSim);
            results.SVproSocialTrust = cell(1, numSim);
            results.latency = nan(1, numSim);
            results.isActive = nan(1, numSim);
            results.isWarning = nan(1, numSim);
            results.wasBlacklisted = nan(1, numSim);
            results.noProviderAvailable = zeros(1, numSim);
            results.failureStreak = zeros(1, numSim);
            results.selectedPID = cell(1, numSim);
        end

        function reqData = getRequester(bcObj, pid)
            chain = bcObj.blockchain;
            isReq = arrayfun(@(b) isfield(b.data, 'VehicleRole') && startsWith(b.data.VehicleRole, 'Vreq'), chain);
            reqBlocks = chain(isReq);
            pids = arrayfun(@(b) b.data.PID, reqBlocks, 'UniformOutput', false);
            [~, lastIdx] = unique(pids, 'last');
            lastBlocks = reqBlocks(lastIdx);
            idx = find(strcmp(pids(lastIdx), pid), 1);
            reqData = lastBlocks(idx).data;
        end

        function precomputed = precomputeRandomSelections(numSims, maxProviders)
            precomputed = cell(1, numSims);
            for sim = 1:numSims
                precomputed{sim} = struct();
                precomputed{sim}.badPerm = randperm(maxProviders);
                precomputed{sim}.goodPerm = randperm(maxProviders);
                precomputed{sim}.shufflePerm = randperm(maxProviders);
            end
        end

        function VprojSet = sampleProvidersWithPrecomputed(blockchainObj, subsetSize, malPct, randStruct)
            chain = blockchainObj.blockchain;
            isPro = arrayfun(@(b) isfield(b.data, 'VehicleRole') && startsWith(b.data.VehicleRole, 'Vpro'), chain);
            proBlocks = chain(isPro);
            pids = arrayfun(@(b) b.data.PID, proBlocks, 'UniformOutput', false);
            [~, lastIdx] = unique(pids, 'last');
            lastBlocks = proBlocks(sort(lastIdx));
            isInBlackout = arrayfun(@(b) isfield(b.data, 'blackoutCounter') && ...
                b.data.blackoutCounter > 0, lastBlocks);
            lastBlocks = lastBlocks(~isInBlackout);
            isMal = arrayfun(@(b) b.data.isMalicious, lastBlocks);
            badBlocks = lastBlocks(isMal);
            goodBlocks = lastBlocks(~isMal);
            numBad = min(numel(badBlocks), round(subsetSize * malPct));
            numGood = min(numel(goodBlocks), subsetSize - numBad);
            selectedBad = []; selectedGood = [];
            if numel(badBlocks) > 0 && numBad > 0
                badIdx = randStruct.badPerm(1:min(numBad, numel(badBlocks)));
                badIdx = badIdx(badIdx <= numel(badBlocks));
                selectedBad = badBlocks(badIdx);
            end
            if numel(goodBlocks) > 0 && numGood > 0
                goodIdx = randStruct.goodPerm(1:min(numGood, numel(goodBlocks)));
                goodIdx = goodIdx(goodIdx <= numel(goodBlocks));
                selectedGood = goodBlocks(goodIdx);
            end
            VprojSet = [selectedBad, selectedGood];
            if ~isempty(VprojSet)
                shuffleIdx = randStruct.shufflePerm(1:numel(VprojSet));
                shuffleIdx = mod(shuffleIdx - 1, numel(VprojSet)) + 1;
                VprojSet = VprojSet(shuffleIdx);
            end
        end

        function blockchainObj = initReputationForModel(blockchainObj, model)
            stBasedModels = {'RUST', 'RUST_V2', 'RUST_V3', 'RUST_PERREQ', ...
                             'RUST_NoRec', 'RUST_NoTier', 'RUST_NoDH', ...
                             'RUST_PerReq_NoRec', 'RUST_PerReq_NoTier', 'RUST_PerReq_NoDH', ...
                             'RUST_V3_NoRec', 'RUST_V3_NoTier', 'RUST_V3_NoDH', ...
                             'REVST', 'REVST_NoRec', 'REVST_NoTier', ...
                             'Threshold', 'Threshold_Baseline', 'Threshold_MaxRep', ...
                             'RUST_NOTIER_baseline', 'REVST_NOTIER_baseline', ...
                             'Yang', 'Yang2019', 'SimpleAvg', 'SLFixedGamma', '3VSL-Binary'};
            betaUniformModels = {'BetaUniform', 'YangUniform', 'Beta', 'Beta_BRS'};
            slUniformModels = {'KangMWSL'};
            slFixAModels = {'ThresholdUniform', 'ThresholdUniform_Baseline', ...
                            'RUST_Uniform', 'REVST_Uniform', ...
                            'RUST_PerReq_Uniform', 'RUST_V3_Uniform'};
            scalarUniformModels = {'Iqbal', 'Bounaira'};
            cumulativeModels = {'Iqbal2'};

            if any(strcmpi(model, stBasedModels)), return; end

            isBetaUniform = any(strcmpi(model, betaUniformModels));
            isSLFixA = any(strcmpi(model, slFixAModels));
            isScalarUniform = any(strcmpi(model, scalarUniformModels));
            isCumulative = any(strcmpi(model, cumulativeModels));
            isSLUniform = any(strcmpi(model, slUniformModels));

            if ~isBetaUniform && ~isSLUniform && ~isSLFixA && ~isScalarUniform && ~isCumulative
                warning('initReputationForModel: Unknown model "%s", keeping ST-based init', model);
                return;
            end

            chain = blockchainObj.blockchain;
            for i = 1:numel(chain)
                if isfield(chain(i).data, 'VehicleRole') && startsWith(chain(i).data.VehicleRole, 'Vpro')
                    chain(i).data.reputation = 0.5;
                    if isBetaUniform
                        chain(i).data.betaAlpha = 1;
                        chain(i).data.betaBeta = 1;
                        chain(i).data.socialTrustLevel = 'intermediate';
                    elseif isSLUniform
                        chain(i).data.betaAlpha = 1;
                        chain(i).data.betaBeta = 1;
                        if isfield(chain(i).data, 'betaGamma'), chain(i).data.betaGamma = 1; end
                        chain(i).data.socialTrustLevel = 'intermediate';
                    elseif isSLFixA
                        chain(i).data.betaAlpha = 2;
                        chain(i).data.betaBeta = 2;
                        if isfield(chain(i).data, 'betaGamma'), chain(i).data.betaGamma = 2; end
                        chain(i).data.socialTrustLevel = 'intermediate';
                        if isfield(chain(i).data, 'ini_alpha')
                            chain(i).data.ini_alpha = 2;
                            chain(i).data.ini_beta = 2;
                            chain(i).data.ini_gamma = 2;
                        end
                        if isfield(chain(i).data, 'w_ij')
                            chain(i).data.w_ij = [1/3; 1/3; 1/3];
                        end
                        if isfield(chain(i).data, 'Offtransaction')
                            offtx = chain(i).data.Offtransaction;
                            if isfield(offtx, 'numAlpha')
                                reqIDs = fieldnames(offtx.numAlpha);
                                for r = 1:numel(reqIDs)
                                    offtx.numAlpha.(reqIDs{r}) = 2;
                                    offtx.numBeta.(reqIDs{r}) = 2;
                                    offtx.numGamma.(reqIDs{r}) = 2;
                                end
                                chain(i).data.Offtransaction = offtx;
                            end
                        end
                    elseif isScalarUniform
                        if isfield(chain(i).data, 'trustValue')
                            chain(i).data.trustValue = 0.5;
                        end
                        chain(i).data.socialTrustLevel = 'intermediate';
                    elseif isCumulative
                        chain(i).data.reputation = 0;
                    end
                end
            end
            blockchainObj.blockchain = chain;
        end

        % decrementBlackoutCounters was removed on 2026-05-29.
        %
        % This function used to be called at the TOP of every simulation
        % step. Combined with the body-of-step decrement loop in
        % simulationUtils.m:107-124 (which runs inside
        % runSimulationWithSelection), it caused every blackouted provider
        % to be decremented TWICE per step — halving freeze durations.
        % Bug introduced 2026-04-05 (commit 431bcd0), noticed and
        % reverted 2026-05-21 (commit 874fd83) for run_baseline_comparison.m.
        %
        % Three non-main runners (run_sensitivity_analysis.m,
        % run_cross_validation.m, run_joint_sweep.m) and four test sites
        % in tests/diagnostic_verification.m were still calling this
        % function — they were also affected by the double-decrement.
        %
        % The function is permanently deleted. Sites 1 (fetchCandidatePool.m:80)
        % and Site 2 (simulationUtils.m:117) together handle the entire
        % blockchain in one decrement per step — no caller should be
        % decrementing manually any more.

    end
end
