classdef simulationUtils
    % SIMULATIONUTILS Shared utility functions for simulation experiments
    % Contains functions used by both run_simulation.m and run_attack_comparison.m

    methods (Static)

        function [results, blockchainObj, InteractionData, ucbCounters] = runSimulationWithSelection(...
            results, blockchainObj, InteractionData, globalRatio, runIndex, ...
            Vreqi, VprojSet, scenarioName, seed, model, selection, config, ucbCounters)
            % RUNSIMULATIONWITHSELECTION Run one interaction with specified selection mechanism

            % Selection-affecting Params flags are set EXPLICITLY based on
            % the model name suffix on every call. We do NOT save-and-restore:
            % that pattern leaks when a stale worker process holds a non-
            % default persistent state from a prior session (e.g. earlier
            % shadow-rule smoke run). Explicit-set guarantees the worker's
            % Params matches the model's intent for this iteration.
            modelKey = upper(string(model));
            wantShadow      = any(strcmp(modelKey, ["RUST_V2_SHADOW","RUST_SHADOW","REVST_SHADOW","RUST_V2_BOTH","RUST_BOTH"]));
            wantStreak      = any(strcmp(modelKey, ["RUST_V2_STREAK","RUST_STREAK","REVST_STREAK","RUST_V2_BOTH","RUST_BOTH"]));
            wantStaticExpect = any(strcmp(modelKey, ["RUST_V2_STATICEXPECT","RUST_STATICEXPECT","REVST_STATICEXPECT"]));
            wantExtGrace    = any(strcmp(modelKey, ["RUST_V2_EXTGRACE","RUST_EXTGRACE","REVST_EXTGRACE"]));
            pTmp = Params();
            pTmp.useBlacklistShadow  = wantShadow;
            pTmp.useStreakPenalty    = wantStreak;
            pTmp.useStaticExpectation = wantStaticExpect;
            pTmp.useExtendedGrace    = wantExtGrace;
            Params(pTmp);

            useBaselineSelection = simulationUtils.isBaselineModel(model);

            % Get selection policy from config (default: use SmartContract default = StrictTier)
            if isfield(config, 'selectionPolicy')
                selectionPolicy = config.selectionPolicy;
            else
                selectionPolicy = [];  % Let SmartContract use its default
            end

            % Model-specific selection policy override
            % RUST_NoTier / REVST_NoTier uses SmartContract_Notier directly
            useNotierSelection = strcmpi(model, 'RUST_NoTier') || strcmpi(model, 'RUST_NOTIER_baseline') || ...
                                 strcmpi(model, 'REVST_NoTier') || strcmpi(model, 'REVST_NOTIER_baseline') || ...
                                 strcmpi(model, 'RUST_PerReq_NoTier') || strcmpi(model, 'RUST_V3_NoTier');

            % Threshold_MaxRep uses MAXREP selection policy (pure max-reputation)
            useMaxRepSelection = strcmpi(model, 'THRESHOLD_MAXREP');

            switch selection
                case 'Sorted'
                    if useNotierSelection
                        % Use dedicated SmartContract_Notier for NOTIER models
                        [~, ~, ~, SVpro, Updated_Vreqi, VprojSet] = SmartContract_Notier(Vreqi, InteractionData, VprojSet, runIndex);
                    elseif useMaxRepSelection
                        % Use MAXREP selection policy (pure max-reputation, no stay-time)
                        [~, ~, ~, SVpro, Updated_Vreqi, VprojSet] = SmartContract(Vreqi, InteractionData, VprojSet, runIndex, 'MAXREP');
                    elseif useBaselineSelection
                        [~, ~, ~, SVpro, Updated_Vreqi, VprojSet] = SmartContract_reputationOnly(Vreqi, InteractionData, VprojSet, runIndex);
                    else
                        [~, ~, ~, SVpro, Updated_Vreqi, VprojSet] = SmartContract(Vreqi, InteractionData, VprojSet, runIndex, selectionPolicy);
                    end
                case 'Random'
                    [~, ~, ~, SVpro, Updated_Vreqi, VprojSet] = SmartContract_random(Vreqi, InteractionData, VprojSet, runIndex);
                case 'WeightedRandom'
                    [~, ~, ~, SVpro, Updated_Vreqi, VprojSet] = SmartContract_weightedRandom(Vreqi, InteractionData, VprojSet, runIndex);
                case 'EpsilonGreedy'
                    epsilon = 0.1;
                    if isfield(config, 'epsilonGreedy_epsilon')
                        epsilon = config.epsilonGreedy_epsilon;
                    end
                    [~, ~, ~, SVpro, Updated_Vreqi, VprojSet] = SmartContract_epsilonGreedy(Vreqi, InteractionData, VprojSet, runIndex, epsilon);
                case 'UCB'
                    c = 2.0;
                    if isfield(config, 'UCB_c')
                        c = config.UCB_c;
                    end
                    [~, ~, ~, SVpro, Updated_Vreqi, ucbCounters, VprojSet] = SmartContract_UCB(Vreqi, InteractionData, VprojSet, runIndex, ucbCounters, c);
                otherwise
                    error('Unknown selection mechanism: %s', selection);
            end

            % BLACKOUT FIX: Ensure all providers have blackout decremented once per step
            % fetchCandidatePool decrements counters for sampled VprojSet only.
            % We must also decrement for providers NOT in VprojSet to ensure consistent blackout.
            chain = blockchainObj.blockchain;

            % Build set of PIDs in VprojSet (already decremented by fetchCandidatePool)
            sampledPids = {};
            for i = 1:numel(VprojSet)
                sampledPids{end+1} = VprojSet(i).data.PID;
            end

            % Sync sampled VprojSet back to blockchain
            for i = 1:numel(VprojSet)
                pid = VprojSet(i).data.PID;
                for j = 1:numel(chain)
                    if isfield(chain(j).data, 'PID') && strcmp(chain(j).data.PID, pid)
                        chain(j).data = VprojSet(i).data;
                        break;
                    end
                end
            end

            % Decrement blackout for providers NOT in VprojSet (they weren't processed by fetchCandidatePool)
            for j = 1:numel(chain)
                if ~isfield(chain(j).data, 'VehicleRole') || ~startsWith(chain(j).data.VehicleRole, 'Vpro')
                    continue;  % Skip non-providers
                end
                pid = chain(j).data.PID;
                if ismember(pid, sampledPids)
                    continue;  % Already handled by VprojSet sync
                end
                % Decrement blackout counter for non-sampled provider
                if chain(j).data.blackoutCounter > 0 && ~isinf(chain(j).data.blackoutCounter)
                    chain(j).data.blackoutCounter = chain(j).data.blackoutCounter - 1;
                    if chain(j).data.blackoutCounter == 0
                        chain(j).data.isActive = true;
                        chain(j).data.isWarning = true;
                        chain(j).data.warningStreak = 1;
                    end
                end
            end
            blockchainObj.blockchain = chain;

            if isempty(SVpro)
                % Track service denial (no provider available)
                if isfield(results, 'noProviderAvailable')
                    results.noProviderAvailable(runIndex) = 1;
                end
                return;
            end

            SVproID = SVpro.PID;
            VreqiID = Updated_Vreqi.PID;

            TX = SVpro.Offtransaction.TransactionsID;
            results.offSuccessStatus(runIndex) = TX.offloadingSuccessstatus;
            results.initialReputation(runIndex) = SVpro.reputation;
            results.SVproisMalicious(runIndex) = SVpro.isMalicious;
            results.SVproSocialTrust{runIndex} = SVpro.socialTrustLevel;
            results.latency(runIndex) = TX.totalOffloadingLatency;
            results.selectedPID{runIndex} = SVproID;

            if isfield(SVpro, 'globalFailureStreak')
                results.failureStreak(runIndex) = SVpro.globalFailureStreak;
            end

            % Update reputation
            [updatedRep, isActive, isWarning, ~, ~, SVpro] = simulationUtils.updateReputationByModel(...
                SVpro, runIndex, Updated_Vreqi, blockchainObj, InteractionData, globalRatio, scenarioName, model);

            results.updatedReputation(runIndex) = updatedRep;

            % === GOVERNANCE STATE TRACKING ===
            if isfield(results, 'isActive')
                results.isActive(runIndex) = double(isActive);
                results.isWarning(runIndex) = double(isWarning);
                % Safely check wasActivePrevious (may be struct, empty, or logical)
                wasActiveBefore = false;
                if isfield(SVpro, 'wasActivePrevious') && islogical(SVpro.wasActivePrevious)
                    wasActiveBefore = SVpro.wasActivePrevious;
                elseif isfield(SVpro, 'wasActivePrevious') && isnumeric(SVpro.wasActivePrevious) && ~isempty(SVpro.wasActivePrevious)
                    wasActiveBefore = SVpro.wasActivePrevious ~= 0;
                end
                results.wasBlacklisted(runIndex) = double(~isActive && wasActiveBefore);
                SVpro.wasActivePrevious = logical(isActive);
            end

            % Update failure streak
            if TX.offloadingSuccessstatus == 0
                SVpro.globalFailureStreak = SVpro.globalFailureStreak + 1;
                SVpro.maxFailureStreak = max(SVpro.maxFailureStreak, SVpro.globalFailureStreak);
            else
                SVpro.globalFailureStreak = 0;
            end

            % TTE tracking
            SVpro.totalSelections = SVpro.totalSelections + 1;
            if SVpro.isMalicious && TX.offloadingSuccessstatus == 0
                SVpro.totalFailuresCaused = SVpro.totalFailuresCaused + 1;
            end

            % Track first restriction (warning OR blacklist - whichever comes first)
            if ~isfield(SVpro, 'everRestricted'), SVpro.everRestricted = false; end
            if ~isfield(SVpro, 'selectionsBeforeFirstRestriction'), SVpro.selectionsBeforeFirstRestriction = NaN; end
            if ~SVpro.everRestricted && (isWarning || ~isActive)
                SVpro.everRestricted = true;
                SVpro.firstRestrictionTime = runIndex;
                SVpro.selectionsBeforeFirstRestriction = SVpro.totalSelections;
            end

            % Track first blacklist (stricter tier)
            if ~isActive && ~SVpro.everBlacklisted
                SVpro.everBlacklisted = true;
                SVpro.firstBlacklistTime = runIndex;
                SVpro.selectionsBeforeFirstBlacklist = SVpro.totalSelections;
                SVpro.failuresBeforeFirstBlacklist = SVpro.totalFailuresCaused;
            end

            % Update blockchain
            chain = blockchainObj.blockchain;
            for i = 1:numel(chain)
                if isfield(chain(i).data, 'PID') && strcmp(chain(i).data.PID, SVproID)
                    chain(i).data = SVpro;
                    break;
                end
            end
            for i = 1:numel(chain)
                if isfield(chain(i).data, 'PID') && strcmp(chain(i).data.PID, VreqiID)
                    chain(i).data = Updated_Vreqi;
                    break;
                end
            end
            blockchainObj.blockchain = chain;

            InteractionData.(SVproID) = SVpro.Offtransaction;
            InteractionData.(VreqiID) = Updated_Vreqi.Offtransaction;
            % No restore needed: flags are set explicitly on next entry.
        end

        function isBaseline = isBaselineModel(model)
            % Baseline models use SmartContract_reputationOnly (max reputation only)
            % RUST-based/ablation models use SmartContract (w1*R + (1-w1)*StayTime + tier policy)
            %
            % NOTE: Threshold and ThresholdUniform are RUST ablations (same SL + recommendations,
            % but no tiered governance), so they use the full RUST selection algorithm.
            % Threshold_Baseline and ThresholdUniform_Baseline use simpler selection for
            % comparison as pure baselines.
            % CLEAN STATE: Only journal models
            baselineModels = {'BetaUniform', '3VSL-Binary', 'Iqbal', 'Iqbal2'};
            isBaseline = any(strcmpi(model, baselineModels));
        end

        function [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
            updateReputationByModel(SVpro, runIndex, Updated_Vreqi, blockchainObj, InteractionData, globalRatio, scenarioName, model)

            % EXPLICIT-SET (anti-leak): set the DH / recommendation toggles from the
            % model name on EVERY call, BEFORE the switch. The NoDH/NoRec cases below
            % use save-and-restore, which leaks a stale value when a reused or
            % interrupted parpool worker holds a non-default persistent Params --
            % that made RUST silently run with DH/Rec off and produced different
            % results in parallel vs serial. Setting the flags here means every model
            % starts from a deterministic, history-independent state, so the leak
            % cannot persist into the next cell regardless of pool/worker state.
            modelU  = upper(string(model));
            isNoDH  = any(strcmp(modelU, ["RUST_NODH","RUST_PERREQ_NODH","RUST_V3_NODH","REVST_NODH"]));
            isNoRec = any(strcmp(modelU, ["RUST_NOREC","REVST_NOREC","RUST_PERREQ_NOREC","RUST_V3_NOREC"]));
            pCfg = Params();
            pCfg.useDynamicHonesty  = ~isNoDH;
            pCfg.useRecommendations = ~isNoRec;
            Params(pCfg);

            % CLEAN STATE: Only journal models (12 models)
            switch upper(model)
                % === RUST VARIANTS (all use computeReputationRUST) ===
                case {'RUST_V2', 'REVST', ...
                      'RUST_V2_SHADOW', 'RUST_SHADOW', 'REVST_SHADOW', ...
                      'RUST_V2_STREAK', 'RUST_STREAK', 'REVST_STREAK', ...
                      'RUST_V2_BOTH', 'RUST_BOTH', ...
                      'RUST_V2_STATICEXPECT', 'RUST_STATICEXPECT', 'REVST_STATICEXPECT', ...
                      'RUST_V2_EXTGRACE', 'RUST_EXTGRACE', 'REVST_EXTGRACE'}
                    % SHADOW/STREAK/BOTH variants share the RUST_V2 R-update
                    % path. Their selection-time flags are already set by
                    % runSimulationWithSelection above; the only difference
                    % vs the baseline is what selectProviderTierAware
                    % reads from Params() at selection time.
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        computeReputationRUST(SVpro, runIndex, Updated_Vreqi, blockchainObj, globalRatio, scenarioName);

                case {'RUST_UNIFORM', 'REVST_UNIFORM'}
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        computeReputationRUST(SVpro, runIndex, Updated_Vreqi, blockchainObj, globalRatio, scenarioName);

                case {'RUST_V3', 'REVST_V3', 'RUST_PERREQ'}
                    % Alias of RUST_V2: v2 is now natively per-pair (per
                    % (requester, provider) DH counters), so RUST == RUST-PerReq.
                    % The v3 shim is retired.
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        computeReputationRUST(SVpro, runIndex, Updated_Vreqi, blockchainObj, globalRatio, scenarioName);

                case {'RUST_NOTIER', 'REVST_NOTIER'}
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        computeReputationRUST(SVpro, runIndex, Updated_Vreqi, blockchainObj, globalRatio, scenarioName);

                case {'RUST_NOREC', 'REVST_NOREC'}
                    params = Params();
                    origUseRec = params.useRecommendations;
                    params.useRecommendations = false;
                    Params(params);
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        computeReputationRUST(SVpro, runIndex, Updated_Vreqi, blockchainObj, globalRatio, scenarioName);
                    params.useRecommendations = origUseRec;
                    Params(params);

                case 'RUST_NODH'
                    params = Params();
                    origUseDH = params.useDynamicHonesty;
                    params.useDynamicHonesty = false;
                    Params(params);
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        computeReputationRUST(SVpro, runIndex, Updated_Vreqi, blockchainObj, globalRatio, scenarioName);
                    params.useDynamicHonesty = origUseDH;
                    Params(params);

                % === RUST-PerReq ABLATIONS (v2 is natively per-pair; v3 retired) ===
                case {'RUST_PERREQ_NOREC', 'RUST_V3_NOREC'}
                    params = Params();
                    origUseRec = params.useRecommendations;
                    params.useRecommendations = false;
                    Params(params);
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        computeReputationRUST(SVpro, runIndex, Updated_Vreqi, blockchainObj, globalRatio, scenarioName);
                    params.useRecommendations = origUseRec;
                    Params(params);

                case {'RUST_PERREQ_NODH', 'RUST_V3_NODH'}
                    params = Params();
                    origUseDH = params.useDynamicHonesty;
                    params.useDynamicHonesty = false;
                    Params(params);
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        computeReputationRUST(SVpro, runIndex, Updated_Vreqi, blockchainObj, globalRatio, scenarioName);
                    params.useDynamicHonesty = origUseDH;
                    Params(params);

                case {'RUST_PERREQ_NOTIER', 'RUST_V3_NOTIER'}
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        computeReputationRUST(SVpro, runIndex, Updated_Vreqi, blockchainObj, globalRatio, scenarioName);

                case {'RUST_PERREQ_UNIFORM', 'RUST_V3_UNIFORM'}
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        computeReputationRUST(SVpro, runIndex, Updated_Vreqi, blockchainObj, globalRatio, scenarioName);

                % === THRESHOLD VARIANTS (all use calculateReputationThreshold) ===
                case 'THRESHOLD'
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        calculateReputationThreshold(SVpro, runIndex, Updated_Vreqi, blockchainObj, globalRatio, scenarioName);

                case 'THRESHOLDUNIFORM'
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        calculateReputationThreshold(SVpro, runIndex, Updated_Vreqi, blockchainObj, globalRatio, scenarioName);

                case {'RUST_NOTIER_BASELINE', 'REVST_NOTIER_BASELINE'}
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        calculateReputationThreshold(SVpro, runIndex, Updated_Vreqi, blockchainObj, globalRatio, scenarioName);

                case 'THRESHOLD_MAXREP'
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        calculateReputationThreshold(SVpro, runIndex, Updated_Vreqi, blockchainObj, globalRatio, scenarioName);

                % === EXTERNAL BASELINES ===
                case 'IQBAL'
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        calculateReputationIqbal(SVpro, runIndex, Updated_Vreqi, InteractionData, globalRatio, scenarioName);

                case 'IQBAL2'
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        calculateReputationIqbal2(SVpro, runIndex, Updated_Vreqi, InteractionData, globalRatio, scenarioName);

                case 'BETAUNIFORM'
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        calculateReputationBetaUniform(SVpro, runIndex, Updated_Vreqi, InteractionData, globalRatio, scenarioName);

                case '3VSL-BINARY'
                    [updatedRep, isActive, isWarning, warningStreak, blackoutCounter, SVpro] = ...
                        calculateReputation3VSLBinary(SVpro, runIndex, Updated_Vreqi, InteractionData, globalRatio, scenarioName);

                otherwise
                    error('Unknown reputation model: %s. Valid models: RUST_V2, RUST_V2_Shadow, RUST_V2_Streak, RUST_V2_Both, RUST_Uniform, RUST_NoRec, RUST_NoTier, RUST_NoDH, Threshold, ThresholdUniform, RUST_NOTIER_baseline, Threshold_MaxRep, Iqbal, Iqbal2, BetaUniform, 3VSL-Binary', model);
            end
        end

        function metrics = summarizeMetrics(results, blockchainObj)
            % Compute metrics with 3-layer separation
            metrics = struct();
            chain = blockchainObj.blockchain;

            % Layer 1: Evidence
            metrics.SuccessRate = mean(results.offSuccessStatus, 'omitnan');
            metrics.FailureRate = 1 - metrics.SuccessRate;
            metrics.AvgLatency = mean(results.latency, 'omitnan');
            metrics.AvgInitialRep = mean(results.initialReputation, 'omitnan');
            metrics.AvgUpdatedRep = mean(results.updatedReputation, 'omitnan');
            metrics.AvgFailureStreak = mean(results.failureStreak, 'omitnan');
            metrics.MaxFailureStreak = max(results.failureStreak);

            % Per ST level evidence
            for st = ["high", "intermediate", "low"]
                mask = strcmp(results.SVproSocialTrust, st);
                if any(mask)
                    metrics.(sprintf('%s_SuccessRate', st)) = mean(results.offSuccessStatus(mask), 'omitnan');
                    metrics.(sprintf('%s_FailureRate', st)) = 1 - metrics.(sprintf('%s_SuccessRate', st));
                else
                    metrics.(sprintf('%s_SuccessRate', st)) = NaN;
                    metrics.(sprintf('%s_FailureRate', st)) = NaN;
                end
            end

            % Layer 2: Governance
            gov = struct('active', 0, 'warning', 0, 'blacklisted', 0, 'total', 0);
            govByMal = struct('mal_active', 0, 'mal_warning', 0, 'mal_blacklisted', 0, ...
                              'honest_active', 0, 'honest_warning', 0, 'honest_blacklisted', 0);

            for i = 1:numel(chain)
                if isfield(chain(i).data, 'VehicleRole') && startsWith(chain(i).data.VehicleRole, 'Vpro')
                    d = chain(i).data;
                    gov.total = gov.total + 1;

                    if d.everBlacklisted || ~d.isActive
                        govState = 'blacklisted';
                        gov.blacklisted = gov.blacklisted + 1;
                    elseif isfield(d, 'isWarning') && d.isWarning
                        govState = 'warning';
                        gov.warning = gov.warning + 1;
                    else
                        govState = 'active';
                        gov.active = gov.active + 1;
                    end

                    if d.isMalicious
                        govByMal.(sprintf('mal_%s', govState)) = govByMal.(sprintf('mal_%s', govState)) + 1;
                    else
                        govByMal.(sprintf('honest_%s', govState)) = govByMal.(sprintf('honest_%s', govState)) + 1;
                    end
                end
            end

            metrics.Gov_ActiveRate = simulationUtils.ifelse(gov.total > 0, gov.active / gov.total * 100, NaN);
            metrics.Gov_WarningRate = simulationUtils.ifelse(gov.total > 0, gov.warning / gov.total * 100, NaN);
            metrics.Gov_BlacklistRate = simulationUtils.ifelse(gov.total > 0, gov.blacklisted / gov.total * 100, NaN);

            % Per-interaction governance metrics
            if isfield(results, 'isActive')
                metrics.InteractionActiveRate = mean(results.isActive, 'omitnan') * 100;
                metrics.InteractionWarningRate = mean(results.isWarning, 'omitnan') * 100;
                metrics.BlacklistEventRate = mean(results.wasBlacklisted, 'omitnan') * 100;
                metrics.WarningTierUtilization = metrics.InteractionWarningRate;

                isMal = results.SVproisMalicious == 1;
                isHonest = results.SVproisMalicious == 0;
                if any(isMal)
                    metrics.MalInWarningRate = mean(results.isWarning(isMal), 'omitnan') * 100;
                else
                    metrics.MalInWarningRate = NaN;
                end
                if any(isHonest)
                    metrics.HonestInWarningRate = mean(results.isWarning(isHonest), 'omitnan') * 100;
                else
                    metrics.HonestInWarningRate = NaN;
                end
            end

            % Layer 3: Ground Truth
            metrics.MaliciousSelectionRate = mean(results.SVproisMalicious, 'omitnan');
            metrics.MaliciousAvoidanceRate = (1 - metrics.MaliciousSelectionRate) * 100;

            totalMal = govByMal.mal_active + govByMal.mal_warning + govByMal.mal_blacklisted;
            totalHonest = govByMal.honest_active + govByMal.honest_warning + govByMal.honest_blacklisted;

            metrics.MalExclusionRate = simulationUtils.ifelse(totalMal > 0, govByMal.mal_blacklisted / totalMal * 100, NaN);
            metrics.MalEvasionRate = simulationUtils.ifelse(totalMal > 0, (govByMal.mal_active + govByMal.mal_warning) / totalMal * 100, NaN);
            metrics.HonestRetentionRate = simulationUtils.ifelse(totalHonest > 0, (govByMal.honest_active + govByMal.honest_warning) / totalHonest * 100, NaN);
            metrics.FalseExclusionRate = simulationUtils.ifelse(totalHonest > 0, govByMal.honest_blacklisted / totalHonest * 100, NaN);

            correctDecisions = govByMal.mal_blacklisted + govByMal.honest_active + govByMal.honest_warning;
            metrics.GovernanceAccuracy = simulationUtils.ifelse(gov.total > 0, correctDecisions / gov.total * 100, NaN);

            % Per ST level malicious rate
            for st = ["high", "intermediate", "low"]
                mask = strcmp(results.SVproSocialTrust, st);
                if any(mask)
                    metrics.(sprintf('%s_MalRate', st)) = mean(results.SVproisMalicious(mask), 'omitnan');
                else
                    metrics.(sprintf('%s_MalRate', st)) = NaN;
                end
            end

            % TTE metrics
            tteData = struct('high', [], 'intermediate', [], 'low', []);
            dbdData = struct('high', [], 'intermediate', [], 'low', []);

            for i = 1:numel(chain)
                if isfield(chain(i).data, 'VehicleRole') && startsWith(chain(i).data.VehicleRole, 'Vpro')
                    d = chain(i).data;
                    if d.isMalicious && d.everBlacklisted
                        st = d.socialTrustLevel;
                        tteData.(st)(end+1) = d.selectionsBeforeFirstBlacklist;
                        dbdData.(st)(end+1) = d.failuresBeforeFirstBlacklist;
                    end
                end
            end

            for st = ["high", "intermediate", "low"]
                if ~isempty(tteData.(st))
                    metrics.(sprintf('%s_AvgTTFB', st)) = mean(tteData.(st), 'omitnan');
                    metrics.(sprintf('%s_AvgDBD', st)) = mean(dbdData.(st), 'omitnan');
                else
                    metrics.(sprintf('%s_AvgTTFB', st)) = NaN;
                    metrics.(sprintf('%s_AvgDBD', st)) = NaN;
                end
            end

            if ~isempty(tteData.high) && ~isempty(tteData.low)
                avgHigh = mean(tteData.high, 'omitnan');
                avgLow = mean(tteData.low, 'omitnan');
                if avgLow > 0
                    metrics.HSEF = avgHigh / avgLow;
                else
                    metrics.HSEF = NaN;
                end
            else
                metrics.HSEF = NaN;
            end
        end

        function result = ifelse(condition, trueVal, falseVal)
            if condition
                result = trueVal;
            else
                result = falseVal;
            end
        end

    end
end
