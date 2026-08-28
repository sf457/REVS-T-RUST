%% RUN_BASELINE_COMPARISON.m
% ========================================================================
% PURPOSE: RUST Ablation Study (12 Models - Journal Paper Final Model Set)
% ========================================================================
%
% MODELS COMPARED (Paper Table):
% ┌────────────────────────┬─────────────────────────┬──────────────────────┬─────────────────────────┬──────────────────┐
% │ Model                  │ Governance              │ Selection            │ Reputation Update       │ Initialization   │
% ├────────────────────────┼─────────────────────────┼──────────────────────┼─────────────────────────┼──────────────────┤
% │ RUST                   │ 4-tier + streak escal.  │ TierAware + Composite│ 3VSL Dynamic Honesty    │ ST-conditioned   │
% │ RUST-Uniform           │ 4-tier + streak escal.  │ TierAware + Composite│ 3VSL Dynamic Honesty    │ Uniform (2,2,2)  │
% │ RUST-NoRec             │ 4-tier + streak escal.  │ TierAware + Composite│ 3VSL (no recommendations│ ST-conditioned   │
% │ RUST-NoTier            │ 4-tier + streak escal.  │ NoTier + Composite   │ 3VSL Dynamic Honesty    │ ST-conditioned   │
% │ Threshold              │ Single-threshold        │ TierAware + Composite│ 3VSL Dynamic Honesty    │ ST-conditioned   │
% │ Threshold-NoTierSel    │ Single-threshold        │ NoTier + Composite   │ 3VSL Dynamic Honesty    │ ST-conditioned   │
% │ Threshold-MaxRep       │ Single-threshold        │ Max-Rep only         │ 3VSL Dynamic Honesty    │ ST-conditioned   │
% │ Threshold-Uniform      │ Single-threshold        │ TierAware + Composite│ 3VSL Dynamic Honesty    │ Uniform (2,2,2)  │
% │ ScalarRep-EMA              │ Threshold blacklist     │ Max-Rep only         │ EMA bounded [0,1]       │ R₀=0.5           │
% │ ScalarRep-CumReward            │ None                    │ Max-Rep only         │ Cumulative unbounded    │ ρ₀=0             │
% │ Beta (BRS)             │ Threshold blacklist     │ Max-Rep only         │ Classical Beta BRS      │ Uniform (α=β=1)  │
% │ 3VSL-Binary            │ Threshold blacklist     │ Max-Rep only         │ 3VSL binary evidence    │ ST-conditioned   │
% └────────────────────────┴─────────────────────────┴──────────────────────┴─────────────────────────┴──────────────────┘
%
% ABLATION CHAIN:
%   RUST
%     ↓ remove recommendations
%   RUST-NoRec               → isolates recommendation aggregation contribution
%     ↓ remove tier-aware selection
%   RUST-NoTier              → isolates tier-aware selection within RUST
%     ↓ remove 4-tier governance
%   Threshold                → isolates 4-tier governance contribution
%     ↓ remove tier partition
%   Threshold-NoTierSel      → isolates tier-aware pool partitioning
%     ↓ remove composite scoring
%   Threshold-MaxRep         → isolates composite trust-mobility scoring
%
%   RUST → RUST-Uniform      → isolates ST-conditioned initialization
%   Threshold → Threshold-Uniform → compound ablation: governance + init lower bound
%
% EXTERNAL BASELINES:
%   ScalarRep-EMA    → modern EMA scalar reputation (adapted [0,1])
%   ScalarRep-CumReward  → original cumulative formulation (sanity check)
%   Beta (BRS)   → classical two-parameter reputation
%   3VSL-Binary  → binary 3VSL without honesty weighting
%
% KEY DESIGN PRINCIPLES:
%   - RUST ablation models share identical 3VSL Dynamic Honesty update
%   - External baselines use only their own update mechanism
%   - All models share same blockchain enforcement and simulation environment
%   - Candidate pool: R >= R_min, same direction, not blacklisted (RUST/Threshold)
%   - External baselines: direction filter only via SmartContract_reputationOnly
%
% OUTPUT:
%   results/<timestamp>/baseline_comparison.csv
%   results/<timestamp>/results.mat

%clearvars -except cfg; clc;  % Preserve cfg if passed externally
%clear Params;  % Reset Params() persistent state
fprintf('=== RUST Ablation Study (13 Models - Journal Paper) ===\n');
fprintf('Paper submission experiment runner\n\n');

%% ==================== CONFIGURATION ====================
% Use existing cfg if provided, otherwise create new struct
if ~exist('cfg', 'var'), cfg = struct(); end

% Simulation settings (only set if not already specified)
if ~isfield(cfg, 'numSimulations'), cfg.numSimulations = 1000; end
if ~isfield(cfg, 'numSeeds'), cfg.numSeeds = 10; end
if ~isfield(cfg, 'maliciousPercentages'), cfg.maliciousPercentages = [0.0, 0.1, 0.3, 0.5]; end

% Network topology
if ~isfield(cfg, 'numRequesters'), cfg.numRequesters = 30; end
if ~isfield(cfg, 'numProviders'), cfg.numProviders = 70; end
if ~isfield(cfg, 'numVehicles_min'), cfg.numVehicles_min = 6; end
if ~isfield(cfg, 'numVehicles_max'), cfg.numVehicles_max = 20; end

% Random seed (consistent with all other experiment scripts)
if ~isfield(cfg, 'baseSeed'), cfg.baseSeed = 1234; end

% ============ TRAJECTORY CAPTURE (for paper figures) ============
% Enable to capture (α, β, γ, u) evolution over time for ALL scenarios
if ~isfield(cfg, 'captureTrajectories'), cfg.captureTrajectories = true; end

% ============ CONFIGURABLE: Models to compare ============
% JOURNAL PAPER: Recommended 9-model set (10 with 3VSL-Binary)
%
% ABLATION CHAIN (isolates each contribution):
%   RUST           → Full framework (4-tier + TierAware + ST-init + Recommendations)
%   RUST-Uniform   → Isolates ST-conditioned initialization
%   RUST-NoRec     → Isolates recommendation aggregation
%   RUST-NoTier    → Isolates tier-aware selection from within RUST
%   Threshold      → Isolates 4-tier governance (single threshold only)
%   Threshold-NoTierSel → Isolates tier-aware selection
%   RUST-MaxRep         → Isolates composite scoring (prior-work baseline)
%   ThresholdUniform    → Bridging model (clean ablation chain)
%
% EXTERNAL BASELINES:
%   ScalarRep-EMA      → Modern EMA governance (adapted for [0,1] comparison)
%   Beta (BRS)     → Classical baseline
%   3VSL-Binary    → 3VSL binary evidence update (optional, answers reviewer question)
%
% NOTE: Iqbal2 (faithful paper) included as SANITY CHECK alongside Iqbal.
%       Run both to verify rank ordering of providers is consistent.
%       If Iqbal2 and Iqbal agree on high vs low reputation providers,
%       the EMA adaptation is faithful. Document this in the paper.
%       Iqbal2 has unbounded scores - exclude from [0,1] plots.
%
if ~isfield(cfg, 'models')
    cfg.models = {'RUST_V2', 'RUST_Uniform', 'RUST_NoRec', 'RUST_NoTier', 'RUST_NoDH', ...
                  'Threshold', 'RUST_NOTIER_baseline', 'Threshold_MaxRep', ...
                  'ThresholdUniform', 'Iqbal', 'Iqbal2', 'BetaUniform', '3VSL-Binary'};
end

% Display names for figures/tables (maps internal names to paper names)
if ~isfield(cfg, 'displayNames')
    cfg.displayNames = containers.Map(...
        {'RUST_V2', 'RUST_V3', 'RUST_Uniform', 'RUST_NoRec', 'RUST_NoTier', 'RUST_NoDH', ...
         'RUST_PerReq_NoRec', 'RUST_PerReq_NoTier', 'RUST_PerReq_NoDH', 'RUST_PerReq_Uniform', ...
         'Threshold', 'RUST_NOTIER_baseline', 'Threshold_MaxRep', ...
         'ThresholdUniform', 'Iqbal', 'Iqbal2', 'BetaUniform', '3VSL-Binary'}, ...
        {'RUST', 'RUST-PerReq', 'RUST-Uniform', 'RUST-NoRec', 'RUST-NoTier', 'RUST-NoDH', ...
         'RUST-PerReq-NoRec', 'RUST-PerReq-NoTier', 'RUST-PerReq-NoDH', 'RUST-PerReq-Uniform', ...
         'Threshold', 'Threshold-NoTierSel', 'Threshold-MaxRep', ...
         'Threshold-Uniform', 'ScalarRep-EMA', 'ScalarRep-CumReward', 'Beta (BRS)', '3VSL-Binary'});
end

% ============ PAPER MODEL SPECIFICATIONS ============
%
% | #  | Model              | Governance              | Selection            | Reputation Update    | Init           | Purpose                    |
% |----|--------------------| ------------------------|----------------------|----------------------|----------------|----------------------------|
% | 1  | RUST               | 4-tier + streak escal.  | TierAware + Composite| 3VSL Dynamic Honesty | ST-conditioned | Proposed full framework    |
% | 2  | RUST-Uniform       | 4-tier + streak escal.  | TierAware + Composite| 3VSL Dynamic Honesty | Uniform (2,2,2)| Isolates ST-init           |
% | 3  | RUST-NoRec         | 4-tier + streak escal.  | TierAware + Composite| 3VSL (no recs)       | ST-conditioned | Isolates recommendations   |
% | 4  | RUST-NoTier        | 4-tier + streak escal.  | NoTier + Composite   | 3VSL Dynamic Honesty | ST-conditioned | Isolates tier-aware sel.   |
% | 5  | Threshold          | Single-threshold        | TierAware + Composite| 3VSL Dynamic Honesty | ST-conditioned | Isolates 4-tier governance |
% | 6  | Threshold-NoTierSel| Single-threshold        | NoTier + Composite   | 3VSL Dynamic Honesty | ST-conditioned | Isolates tier-aware sel.   |
% | 7  | Threshold-MaxRep   | Single-threshold        | Max-Rep only         | 3VSL Dynamic Honesty | ST-conditioned | Isolates composite scoring |
% | 8  | Threshold-Uniform  | Single-threshold        | TierAware + Composite| 3VSL Dynamic Honesty | Uniform (2,2,2)| Bridging model             |
% | 9  | ScalarRep-EMA          | Threshold blacklist     | Max-Rep only         | EMA bounded [0,1]    | R₀=0.5         | External: modern EMA       |
% | 10 | ScalarRep-CumReward        | None                    | Max-Rep only         | Cumulative unbounded | ρ₀=0           | SANITY CHECK for Iqbal     |
% | 11 | Beta (BRS)         | Threshold blacklist     | Max-Rep only         | Classical Beta       | α=1,β=1        | External: classical        |
% | 12 | 3VSL-Binary        | Threshold blacklist     | Max-Rep only         | 3VSL binary evidence | Xu Eq.18       | External: closest prior    |
%
% ABLATION CONTRIBUTIONS:
%   governance contribution     = +5.5% SR  (RUST vs Threshold)
%   tier-sel contribution       = +0.3pp SR (Threshold vs Threshold-NoTierSel)
%   composite scoring contrib.  = +7.3% SR  (Threshold-NoTierSel vs RUST-MaxRep)
%   ST-init contribution        = 2.4pp SR  (RUST vs RUST-Uniform)
%
% EXTERNAL BASELINES:
%   Beta (BRS)  → shows 3VSL Dynamic Honesty vs classical BRS
%   ScalarRep-EMA   → shows 3VSL Dynamic Honesty vs modern EMA-based approach

% ============ CONFIGURABLE: Assignment configs ============
% Options: 'xu_aligned', 'moderate'
%   - xu_aligned: malicious → ALL ST_low, honest → ST_high (worst-case)
%   - moderate: malicious → 5% high, 15% intermediate, 80% low (realistic)
if ~isfield(cfg, 'assignmentConfigs'), cfg.assignmentConfigs = {'xu_aligned', 'moderate'}; end

% ============ CONFIGURABLE: Attack types ============
% Options: 'always', 'onoff', 'firsthalf'
%   - always: 100% attack rate
%   - onoff: alternating attack (period=2, 50% duty cycle)
%   - firsthalf: honest first half, attack second half
if ~isfield(cfg, 'attackTypes'), cfg.attackTypes = {'always', 'onoff', 'firsthalf'}; end

% On-off attack parameters
if ~isfield(cfg, 'onOffPeriod'), cfg.onOffPeriod = 2; end
if ~isfield(cfg, 'attacksPerPeriod'), cfg.attacksPerPeriod = 1; end

%% ==================== SETUP ====================
% Put all source folders on the path regardless of the current directory.
addpath(fileparts(mfilename('fullpath')));   % bootstrap so setup_paths is visible
setup_paths();

% Output directory (cfg.outDir overrides the timestamp default — useful
% for sensitivity sweeps that need a stable nested path).
if isfield(cfg, 'outDir') && ~isempty(cfg.outDir)
    outDir = cfg.outDir;
else
    dateStr = char(datetime('now', 'Format', 'yyyy-MM-dd_HH-mm'));
    outDir = fullfile('results', dateStr);
end
if ~exist(outDir, 'dir'), mkdir(outDir); end

% Initialize vehicle pools (once, reused across all experiments)
RSUm = RSUmap();
rng(cfg.baseSeed, 'twister');
[Vreqipool, VprojPool] = initializeVehiclePools(cfg.numRequesters, cfg.numProviders, RSUm);

% Get display names for config output (fall back to internal name if not mapped)
displayModelNames = cellfun(@(m) getDisplayName(cfg.displayNames, m), cfg.models, 'UniformOutput', false);

fprintf('Configuration:\n');
fprintf('  Models: %s\n', strjoin(displayModelNames, ', '));
fprintf('  Assignments: %s\n', strjoin(cfg.assignmentConfigs, ', '));
fprintf('  Attack Types: %s\n', strjoin(cfg.attackTypes, ', '));
fprintf('  Malicious %%: %s\n', mat2str(cfg.maliciousPercentages * 100));
fprintf('  Seeds: %d, Simulations: %d\n', cfg.numSeeds, cfg.numSimulations);
fprintf('  Output: %s\n\n', outDir);

%% ==================== MAIN EXPERIMENT LOOP ====================
allResults = [];
allPerSeedResults = [];
allTrajectories = struct();  % Stores trajectories for each model (when enabled)
allTrustEvolution = struct();  % Stores trustEvolution matrices (for generate_trust_evolution_from_simulation.m)

% --- FORENSIC FINGERPRINT HARNESS (opt-in: cfg.fingerprint = true) ------------
% Hashes the simulation state at each stage and writes one log per cell to
% results/fingerprints/<tag>__<scenario>__seed<s>.mat. Run once with
% cfg.fingerprintTag='serial' (no pool) and once with ='parallel' (pool up),
% then: compare_fingerprints('serial','parallel') -> first divergence stage.
doFP = isfield(cfg,'fingerprint') && cfg.fingerprint;
if doFP
    if isfield(cfg,'fingerprintTag'), fpTag = cfg.fingerprintTag; else, fpTag = 'run'; end
    fpDir = fullfile('results','fingerprints');
    if ~exist(fpDir,'dir'), mkdir(fpDir); end
    fprintf('[fingerprint] ON  tag=%s  dir=%s\n', fpTag, fpDir);
else
    fpTag = ''; fpDir = '';
end
% -----------------------------------------------------------------------------

% Progress tracking
totalConditions = numel(cfg.assignmentConfigs) * numel(cfg.attackTypes) * ...
                  numel(cfg.maliciousPercentages) * numel(cfg.models);
completedConditions = 0;
startTime = tic;

% Create progress window
hWait = waitbar(0, 'Starting simulation...', 'Name', 'RUST Simulation Progress');

for aIdx = 1:numel(cfg.assignmentConfigs)
    assignmentConfig = cfg.assignmentConfigs{aIdx};

    for tIdx = 1:numel(cfg.attackTypes)
        attackType = cfg.attackTypes{tIdx};

        fprintf('\n╔══════════════════════════════════════════════════════════════╗\n');
        fprintf('║ Assignment: %-15s  Attack: %-15s      ║\n', assignmentConfig, attackType);
        fprintf('╚══════════════════════════════════════════════════════════════╝\n');

        % Set parameters for this experiment
        params = Params();
        params.assignmentConfig = assignmentConfig;
        params.attackType = attackType;
        params.onOffPeriod = cfg.onOffPeriod;
        params.attacksPerPeriod = cfg.attacksPerPeriod;
        params.totalSimulationPeriod = cfg.numSimulations;
        params.VERBOSE = false;
        params.enableLogging = false;
        Params(params);

        % Per-experiment overrides that MUST reach every parpool worker.
        % Params() is function-persistent and per-process: the Params(params)
        % call above mutates only the CLIENT's persistent copy. Workers keep
        % the Params.m defaults (e.g. attackType='always'), so a 'firsthalf'
        % run would silently execute as 'always' on the workers -- malicious
        % providers degrading EVERY step instead of only the second half,
        % doubling offload latency and flipping success/fail relative to the
        % serial (client) run. This struct is broadcast into the parfor and
        % applied to each worker's persistent Params so serial == parallel.
        expParams = struct( ...
            'assignmentConfig',      assignmentConfig, ...
            'attackType',            attackType, ...
            'onOffPeriod',           cfg.onOffPeriod, ...
            'attacksPerPeriod',      cfg.attacksPerPeriod, ...
            'totalSimulationPeriod', cfg.numSimulations, ...
            'VERBOSE',               false, ...
            'enableLogging',         false);

        for p = 1:numel(cfg.maliciousPercentages)
            malPct = cfg.maliciousPercentages(p);
            fprintf('\n---------- Malicious = %.0f%% ----------\n', malPct * 100);

            for m = 1:numel(cfg.models)
                model = cfg.models{m};
                % Show display name in progress output
                if isKey(cfg.displayNames, model)
                    displayName = cfg.displayNames(model);
                else
                    displayName = model;
                end
                fprintf('  %s: [seeds 1-%d] ', displayName, cfg.numSeeds);

                % Pre-allocate for parfor (cannot use growing arrays)
                seedMetricsCell = cell(cfg.numSeeds, 1);
                seedTrajectoriesCell = cell(cfg.numSeeds, 1);
                seedTrustEvolutionCell = cell(cfg.numSeeds, 1);

                parfor s = 1:cfg.numSeeds
                    % Reset RNG for reproducibility (each worker gets unique stream)
                    rng(cfg.baseSeed + s * 1000 + p * 100 + aIdx * 10 + tIdx, 'twister');

                    % Initialise the fingerprint log unconditionally so the parfor
                    % temporary is always defined (silences the "Uninitialized
                    % Temporaries" warning). Stays empty unless cfg.fingerprint=true.
                    fpLog = repmat(fpEntry('', ''), 0, 1);

                    % Propagate this experiment's parameters to THIS worker's
                    % persistent Params. Workers maintain their own per-process
                    % persistent Params, so the client-side Params(params) set
                    % above does NOT reach them. Without this, attackType,
                    % assignmentConfig, onOffPeriod, attacksPerPeriod and
                    % totalSimulationPeriod fall back to Params.m defaults on
                    % each worker -- the confirmed cause of serial-vs-parallel
                    % divergence (workers ran 'always' instead of 'firsthalf').
                    Params(expParams);

                    % Apply any caller-supplied parameter overrides on this
                    % worker so they take effect on this iteration's selection
                    % and reputation calls (same per-process reason as above).
                    if isfield(cfg, 'paramOverrides') && ~isempty(cfg.paramOverrides)
                        Params(cfg.paramOverrides);
                    end

                    % Assign malicious using configurable function
                    VprojMal = assignMaliciousConfigurable(VprojPool, malPct, Vreqipool, assignmentConfig);

                    % Initialize blockchain
                    blockchainObj = bc.vBlockchain();
                    blockchainObj.blockchain = AddtoVehicularBlockChain(VprojMal, blockchainObj.blockchain, blockchainObj);
                    blockchainObj.blockchain = AddtoVehicularBlockChain(Vreqipool, blockchainObj.blockchain, blockchainObj);
                    blockchainObj = initModelFields(blockchainObj);

                    % Model-specific initialization for FAIR comparison
                    % Uniform-prior models (BetaUniform, YangUniform, Iqbal) should start at R=0.5
                    % ST-based models (RUST, Threshold) keep ST-based initialization
                    blockchainObj = initReputationForModel(blockchainObj, model);

                    % [fingerprint] stage 1: initial trust state + array ORDER
                    if doFP
                        [hRI, sRI] = fingerprintState(blockchainObj);
                        fpLog(end+1) = fpEntry('repinit', hRI, sRI, fpOrderHash(blockchainObj), '');
                    end

                    % Initialize trajectory capture for ALL scenarios (if enabled)
                    % Pre-initialise so these parfor temporaries are always
                    % defined (silences "Uninitialized Temporaries" warnings);
                    % only populated when trajectory capture is requested.
                    trajectories = [];
                    trustEvolution = [];
                    shouldCapture = cfg.captureTrajectories;
                    if shouldCapture
                        trajectories = initTrajectoryStorage(blockchainObj);
                        trajectories = captureTrajectoryState(trajectories, blockchainObj, 0);  % Initial state
                        % Also initialize trustEvolution matrix format (for generate_trust_evolution_from_simulation.m)
                        trustEvolution = initTrustEvolutionMatrix(blockchainObj, cfg.numSimulations);
                        trustEvolution = captureTrustEvolutionState(trustEvolution, blockchainObj, 1);  % Column 1 = t=0
                        % Store scenario metadata so figures show configuration
                        trustEvolution.scenario.model = model;
                        trustEvolution.scenario.assignment = assignmentConfig;
                        trustEvolution.scenario.attackType = attackType;
                        trustEvolution.scenario.maliciousPct = malPct;
                        trustEvolution.scenario.numSimulations = cfg.numSimulations;
                        trustEvolution.scenario.numRequesters = cfg.numRequesters;
                        trustEvolution.scenario.numProviders = cfg.numProviders;
                    end

                    % Create scenario key for storage
                    scenarioKey = sprintf('%s_%s_%s_mal%.0f', model, assignmentConfig, attackType, malPct*100);

                    % Generate shared randomization
                    cyclesNeeded = ceil(cfg.numSimulations / cfg.numRequesters);
                    shuffledReq = repmat(randperm(cfg.numRequesters), 1, cyclesNeeded);
                    shuffledReq = shuffledReq(1:cfg.numSimulations);
                    subsetSizes = randi([cfg.numVehicles_min, cfg.numVehicles_max], 1, cfg.numSimulations);

                    % Pre-compute random selections for fair comparison across models
                    precomputedRand = precomputeRandomSelections(cfg.numSimulations, cfg.numProviders);

                    % [fingerprint] stage 2: RNG-derived schedule (requester order + subset sizes)
                    if doFP
                        fpLog(end+1) = fpEntry('schedule', ...
                            fpHash([double(shuffledReq(:)); double(subsetSizes(:))]), []);
                    end

                    % Initialize results
                    results = initResults(cfg.numSimulations);
                    InteractionData = struct();

                    % Run simulation
                    for sim = 1:cfg.numSimulations
                        % NOTE: blackoutCounter decrement happens inside
                        % fetchCandidatePool.m:80 (sampled providers) and
                        % simulationUtils.m:117 (non-sampled providers).
                        % Together they cover the full blockchain in exactly
                        % one decrement per simulation step. The earlier
                        % top-of-step decrementBlackoutCounters(blockchainObj)
                        % call here was removed to fix the freeze double-
                        % decrement bug (commit c0a5542 + this commit).

                        subsetSize = subsetSizes(sim);
                        VprojSet = sampleProvidersWithPrecomputed(blockchainObj, subsetSize, malPct, precomputedRand{sim});

                        selectedPID = sprintf('R%d', shuffledReq(sim));
                        Vreqi = getRequester(blockchainObj, selectedPID);
                        [Vreqi.Req, Vreqi.msgReqContent] = generateTaskReq(Vreqi);

                        scenarioName = sprintf('%s_%s_%s_%.0f', model, assignmentConfig, attackType, malPct * 100);

                        [results, blockchainObj, InteractionData, ~] = simulationUtils.runSimulationWithSelection(...
                            results, blockchainObj, InteractionData, malPct, sim, ...
                            Vreqi, VprojSet, scenarioName, s, model, 'Sorted', cfg, []);

                        % Tier at selection time: classify from pre-governance reputation
                        if ~isnan(results.initialReputation(sim))
                            results.selectedTierIsGood(sim) = double(results.initialReputation(sim) > params.R_warn);
                        end

                        % Capture trajectory state after each run (if enabled)
                        if shouldCapture
                            trajectories = captureTrajectoryState(trajectories, blockchainObj, sim);
                            % Also capture in matrix format for trustEvolution
                            trustEvolution = captureTrustEvolutionState(trustEvolution, blockchainObj, sim + 1);  % +1 because col 1 is t=0
                            % Track which provider was selected this run
                            if ~isempty(results.selectedPID{sim})
                                trustEvolution = markProviderSelected(trustEvolution, results.selectedPID{sim}, sim + 1);
                            end
                        end

                        % [fingerprint] stage 3: trust state + array ORDER + selected PID + OFFLOAD OUTCOME
                        if doFP
                            [hST, sST] = fingerprintState(blockchainObj);
                            selp = '';
                            if ~isempty(results.selectedPID{sim}), selp = char(results.selectedPID{sim}); end
                            succ = NaN;
                            if isfield(results,'offSuccessStatus') && numel(results.offSuccessStatus) >= sim
                                succ = double(results.offSuccessStatus(sim));
                            end
                            lat = NaN;
                            if isfield(results,'latency') && numel(results.latency) >= sim
                                lat = double(results.latency(sim));
                            end
                            fpLog(end+1) = fpEntry(sprintf('step_%05d', sim), hST, sST, ...
                                                   fpOrderHash(blockchainObj), selp, succ, lat);
                        end
                    end

                    % Store trajectories for this seed (parfor-compatible)
                    if shouldCapture
                        % Read-only end-of-run snapshot of per-(provider,requester)
                        % DH counters (localTotalInteractions / localSuccessStreak)
                        % + Offtransaction counts, for the per-pair interaction-
                        % distribution audit. Does NOT modify any simulation state
                        % or metric; reads the final blockchain only.
                        trustEvolution.perPairCounters = capturePerPairCounters(blockchainObj);
                        seedTrajectoriesCell{s} = trajectories;
                        seedTrustEvolutionCell{s} = trustEvolution;
                    end

                    % Compute metrics for this seed
                    metrics = computeMetrics(results, blockchainObj);

                    % For firsthalf attacks, compute phase-specific metrics
                    % For other attacks, set to NaN to maintain consistent struct fields
                    if strcmp(attackType, 'firsthalf')
                        phaseMetrics = computeSecondHalfMetrics(results, floor(cfg.numSimulations / 2));
                        metrics.FirstHalf_SR = phaseMetrics.firstHalf_SR;
                        metrics.FirstHalf_MAR = phaseMetrics.firstHalf_MAR;
                        metrics.SecondHalf_SR = phaseMetrics.secondHalf_SR;
                        metrics.SecondHalf_MAR = phaseMetrics.secondHalf_MAR;
                        metrics.SR_Drop = phaseMetrics.SR_drop;
                        metrics.MAR_Drop = phaseMetrics.MAR_drop;

                        % Runs-to-First-Blacklist (published name: RTB).
                        % mean(firstBlacklistTime - switchPoint) over malicious
                        % providers FIRST BLACKLISTED in Phase 2.
                        % SEMANTICS (do not mislabel as "detection"): this is a
                        % GOVERNANCE-route latency. firstBlacklistTime is only
                        % written when a provider is SELECTED, FAILS, and is
                        % governed into blackout (simulationUtils.m:192). Malicious
                        % providers contained purely by AVOIDANCE (never re-selected
                        % after their reputation/tier drops) have firstBlacklistTime
                        % = NaN and are EXCLUDED from this mean. RTB therefore
                        % measures only the blacklist route, over an asymmetric
                        % sub-sample, and UNDERSTATES avoidance-based protection.
                        % The avoidance defense is captured by MAR / Phase-2 MAR /
                        % MalSelected_Phase2, not here. Struct field kept as
                        % 'RunsToDetect' for frozen-CSV compatibility; reported as RTB.
                        switchPoint = floor(cfg.numSimulations / 2);
                        chain = blockchainObj.blockchain;
                        isPro = arrayfun(@(b) isfield(b.data,'VehicleRole') && startsWith(b.data.VehicleRole,'Vpro'), chain);
                        proBlks = chain(isPro);
                        pidsR = arrayfun(@(b) b.data.PID, proBlks, 'UniformOutput', false);
                        [~, liR] = unique(pidsR, 'last');
                        lbR = proBlks(sort(liR));
                        rtdVals = [];
                        for bi = 1:numel(lbR)
                            dd = lbR(bi).data;
                            if ~dd.isMalicious, continue; end
                            if ~isfield(dd,'firstBlacklistTime'), continue; end
                            fbt = dd.firstBlacklistTime;
                            if ~isnumeric(fbt) || isempty(fbt) || isnan(fbt), continue; end
                            if fbt > switchPoint
                                rtdVals(end+1) = fbt - switchPoint;
                            end
                        end
                        if ~isempty(rtdVals)
                            metrics.RunsToDetect = mean(rtdVals);
                        else
                            metrics.RunsToDetect = NaN;
                        end

                        % Phase selection counts + staleness (pass corrected RTD)
                        stalenessMetrics = trackRecommendationStaleness(results, switchPoint, metrics.RunsToDetect);
                        metrics.MalSelected_Phase1 = stalenessMetrics.malSelectedPhase1;
                        metrics.MalSelected_Phase2 = stalenessMetrics.malSelectedPhase2;
                        metrics.MalSelectRatio = stalenessMetrics.malSelectedRatio;
                        metrics.InitialMAR_Phase2 = stalenessMetrics.initialMAR_phase2;
                        metrics.FinalMAR_Phase2 = stalenessMetrics.finalMAR_phase2;
                        metrics.MARImprovement = stalenessMetrics.MARimprovement_phase2;
                        metrics.StalenessScore = stalenessMetrics.stalenessScore;
                    else
                        metrics.FirstHalf_SR = NaN;
                        metrics.FirstHalf_MAR = NaN;
                        metrics.SecondHalf_SR = NaN;
                        metrics.SecondHalf_MAR = NaN;
                        metrics.SR_Drop = NaN;
                        metrics.MAR_Drop = NaN;
                        metrics.MalSelected_Phase1 = NaN;
                        metrics.MalSelected_Phase2 = NaN;
                        metrics.MalSelectRatio = NaN;
                        metrics.InitialMAR_Phase2 = NaN;
                        metrics.FinalMAR_Phase2 = NaN;
                        metrics.MARImprovement = NaN;
                        metrics.RunsToDetect = NaN;
                        metrics.StalenessScore = NaN;
                    end

                    seedMetricsCell{s} = metrics;

                    % [fingerprint] stage 4: final metrics, then write this cell's log
                    if doFP
                        fpLog(end+1) = fpEntry('metrics', fpHash([ ...
                            getfm(metrics,'SuccessRate'), getfm(metrics,'MAR'), ...
                            getfm(metrics,'Availability'), getfm(metrics,'TPR_gov'), ...
                            getfm(metrics,'FPR_gov'),     getfm(metrics,'F1_gov')]), []);
                        parsave_fp(fullfile(fpDir, sprintf('%s__%s__seed%d.mat', fpTag, scenarioKey, s)), fpLog);
                    end
                end  % parfor

                % Merge results from all seeds
                seedMetrics = vertcat(seedMetricsCell{:});

                % Merge trajectory data (use last seed's data for storage)
                if cfg.captureTrajectories
                    safeKey = matlab.lang.makeValidName(sprintf('%s_%s_%s_mal%.0f', model, assignmentConfig, attackType, malPct*100));
                    % Use first non-empty trajectory (seeds have same structure)
                    for ss = 1:cfg.numSeeds
                        if ~isempty(seedTrajectoriesCell{ss})
                            allTrajectories.(safeKey) = seedTrajectoriesCell{ss};
                            allTrustEvolution.(safeKey) = seedTrustEvolutionCell{ss};
                            break;
                        end
                    end
                end

                % Average across seeds
                avgMetrics = averageMetrics(seedMetrics);

                % Capture per-seed results before seedMetrics is lost
                for seedIdx = 1:numel(seedMetrics)
                    perSeed = seedMetrics(seedIdx);
                    if isKey(cfg.displayNames, model)
                        perSeed.Model = string(cfg.displayNames(model));
                    else
                        perSeed.Model = string(model);
                    end
                    perSeed.MaliciousPct = malPct * 100;
                    perSeed.Assignment = string(assignmentConfig);
                    perSeed.AttackType = string(attackType);
                    perSeed.Seed = seedIdx;
                    allPerSeedResults = appendStructRow(allPerSeedResults, perSeed);
                end

                % Use display name for figures/tables
                if isKey(cfg.displayNames, model)
                    avgMetrics.Model = string(cfg.displayNames(model));
                else
                    avgMetrics.Model = string(model);
                end
                avgMetrics.MaliciousPct = malPct * 100;
                avgMetrics.Assignment = string(assignmentConfig);
                avgMetrics.AttackType = string(attackType);

                allResults = appendStructRow(allResults, avgMetrics);
                fprintf('| SR=%.1f%% MAR=%.1f%%', avgMetrics.SuccessRate, avgMetrics.MAR);

                % Update progress bar
                completedConditions = completedConditions + 1;
                progress = completedConditions / totalConditions;
                elapsed = toc(startTime);
                if progress > 0
                    eta = elapsed / progress * (1 - progress);
                    etaStr = sprintf('ETA: %.1f min', eta / 60);
                else
                    etaStr = 'ETA: calculating...';
                end
                fprintf(' [%s]\n', etaStr);

                % Update waitbar
                if ishandle(hWait)
                    msg = sprintf('Seed %d/%d | %s | %s/%s/%.0f%%\nSR=%.1f%% MAR=%.1f%% | %s', ...
                        cfg.numSeeds, cfg.numSeeds, displayName, assignmentConfig, attackType, ...
                        malPct*100, avgMetrics.SuccessRate, avgMetrics.MAR, etaStr);
                    waitbar(progress, hWait, msg);
                end
            end
        end
    end
end

% Close progress window
if ishandle(hWait)
    close(hWait);
end

%% ==================== BUILD RESULTS TABLE ====================
% Strip time-series fields (ts_*) before struct2table — they break CSV
allTimeSeries = struct();

% Normalize ts_ fields across struct array before rmfield
tsFieldsAll = fieldnames(allResults);
tsFieldsAll = tsFieldsAll(startsWith(tsFieldsAll, 'ts_'));
for ri = 1:numel(allResults)
    for ti = 1:numel(tsFieldsAll)
        if ~isfield(allResults(ri), tsFieldsAll{ti})
            allResults(ri).(tsFieldsAll{ti}) = [];
        end
    end
end

for ri = 1:numel(allResults)
    tsFields = fieldnames(allResults(ri));
    tsFields = tsFields(startsWith(tsFields, 'ts_'));
    for ti = 1:numel(tsFields)
        key = sprintf('row%d', ri);
        allTimeSeries.(key).(tsFields{ti}) = allResults(ri).(tsFields{ti});
    end
end
% Strip ts_* fields from the entire struct array at once (avoids
% "Subscripted assignment between dissimilar structures" when rmfield
% is applied row-by-row).
if ~isempty(tsFieldsAll)
    allResults = rmfield(allResults, tsFieldsAll);
end
% Also strip from per-seed results

% Normalize ts_ fields across struct array before rmfield
tsFieldsAll = fieldnames(allPerSeedResults);
tsFieldsAll = tsFieldsAll(startsWith(tsFieldsAll, 'ts_'));
for ri = 1:numel(allPerSeedResults)
    for ti = 1:numel(tsFieldsAll)
        if ~isfield(allPerSeedResults(ri), tsFieldsAll{ti})
            allPerSeedResults(ri).(tsFieldsAll{ti}) = [];
        end
    end
end

if ~isempty(tsFieldsAll)
    allPerSeedResults = rmfield(allPerSeedResults, tsFieldsAll);
end

T = struct2table(allResults);
T = movevars(T, {'Assignment', 'AttackType', 'MaliciousPct', 'Model'}, 'Before', 1);

% Sort by assignment, attack, malicious percentage and model
T = sortrows(T, {'Assignment', 'AttackType', 'MaliciousPct', 'Model'});

disp(' ');
disp('=== RESULTS SUMMARY ===');
disp(T(:, {'Assignment', 'AttackType', 'MaliciousPct', 'Model', 'SuccessRate', 'MAR', 'Availability', 'TPR', 'F1'}));

% Save results
writetable(T, fullfile(outDir, 'baseline_comparison.csv'));
save(fullfile(outDir, 'results.mat'), 'allResults', 'allPerSeedResults', 'allTimeSeries', 'cfg', 'T');

% Save per-seed results for statistical analysis (std, CI, etc.)
if ~isempty(allPerSeedResults)
    Tseeds = struct2table(allPerSeedResults);
    Tseeds = movevars(Tseeds, {'Assignment', 'AttackType', 'MaliciousPct', 'Model', 'Seed'}, 'Before', 1);
    Tseeds = sortrows(Tseeds, {'Assignment', 'AttackType', 'MaliciousPct', 'Model', 'Seed'});
    writetable(Tseeds, fullfile(outDir, 'baseline_comparison_per_seed.csv'));
    fprintf('  - baseline_comparison_per_seed.csv (%d rows)\n', height(Tseeds));
end

% Also save per-config results for easier analysis
for aIdx = 1:numel(cfg.assignmentConfigs)
    for tIdx = 1:numel(cfg.attackTypes)
        assignment = cfg.assignmentConfigs{aIdx};
        attack = cfg.attackTypes{tIdx};
        mask = T.Assignment == assignment & T.AttackType == attack;
        subT = T(mask, :);
        filename = sprintf('results_%s_%s.csv', assignment, attack);
        writetable(subT, fullfile(outDir, filename));
    end
end

totalElapsed = toc(startTime);
fprintf('\n=== EXPERIMENT COMPLETE ===\n');
fprintf('Total time: %.1f minutes (%.0f seconds)\n', totalElapsed/60, totalElapsed);
fprintf('Results saved to: %s\n', outDir);
fprintf('  - baseline_comparison.csv (all results)\n');
fprintf('  - results_<assignment>_<attack>.csv (per-config)\n');
fprintf('  - results.mat (MATLAB data)\n');

%% ==================== TRAJECTORY ANALYSIS (if enabled) ====================
if cfg.captureTrajectories && ~isempty(fieldnames(allTrajectories))
    fprintf('\n=== GENERATING TRAJECTORY FIGURES ===\n');
    fprintf('Captured %d scenario-model combinations\n', numel(fieldnames(allTrajectories)));

    % Create trajectory output directory
    trajDir = fullfile(outDir, 'trajectories');
    if ~exist(trajDir, 'dir'), mkdir(trajDir); end

    % Get all captured scenario keys
    capturedKeys = fieldnames(allTrajectories);
    fprintf('Captured scenarios: %s\n', strjoin(capturedKeys, ', '));

    % Save all trajectory data (comprehensive)
    save(fullfile(trajDir, 'trajectories_all.mat'), 'allTrajectories', 'allTrustEvolution', 'cfg');

    % Save each scenario's trustEvolution separately
    if ~isempty(fieldnames(allTrustEvolution))
        for kIdx = 1:numel(capturedKeys)
            scenarioKey = capturedKeys{kIdx};
            if isfield(allTrustEvolution, scenarioKey)
                trustEvolution = allTrustEvolution.(scenarioKey);
                save(fullfile(trajDir, sprintf('trustEvolution_%s.mat', scenarioKey)), ...
                    'trustEvolution', 'cfg');
            end
        end
    end

    % Generate summary figures for a representative scenario (RUST_V2 + moderate + always + 30%)
    % Users can generate more figures from saved .mat files
    reprKey = 'RUST_V2_moderate_always_mal30';
    if isfield(allTrajectories, reprKey)
        fprintf('Generating representative figures for: %s\n', reprKey);

        % Create single-scenario struct for figure functions
        reprTrajectories = struct();
        reprTrajectories.RUST_V2 = allTrajectories.(reprKey);

        generateEvidenceEvolutionFigure(reprTrajectories, 'RUST_V2', cfg.displayNames, trajDir);
        generateSTLevelTrajectoryFigure(reprTrajectories, 'RUST_V2', cfg.displayNames, trajDir);

        % Save as default trustEvolution.mat for generate_trust_evolution_from_simulation.m
        if isfield(allTrustEvolution, reprKey)
            trustEvolution = allTrustEvolution.(reprKey);
            save(fullfile(trajDir, 'trustEvolution.mat'), 'trustEvolution', 'cfg');
            fprintf('  - trustEvolution.mat (for generate_trust_evolution_from_simulation.m)\n');
        end
    end

    fprintf('Trajectory results saved to: %s/\n', trajDir);
    fprintf('  - trajectories_all.mat (ALL scenarios - comprehensive data)\n');
    fprintf('  - trustEvolution_*.mat (per-scenario trust matrices)\n');
    fprintf('  - *.png (representative figures)\n');
end

%% ==================== HELPER FUNCTIONS ====================

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
            if ~isfield(chain(i).data, 'firstBlacklistTime'), chain(i).data.firstBlacklistTime = NaN; end
            if ~isfield(chain(i).data, 'selectionsBeforeFirstBlacklist'), chain(i).data.selectionsBeforeFirstBlacklist = NaN; end
            if ~isfield(chain(i).data, 'everRestricted'), chain(i).data.everRestricted = false; end
            if ~isfield(chain(i).data, 'firstRestrictionTime'), chain(i).data.firstRestrictionTime = NaN; end
            if ~isfield(chain(i).data, 'selectionsBeforeFirstRestriction'), chain(i).data.selectionsBeforeFirstRestriction = NaN; end
            if ~isfield(chain(i).data, 'trustValue'), chain(i).data.trustValue = 0.5; end
            if ~isfield(chain(i).data, 'lastInteractionRun'), chain(i).data.lastInteractionRun = 0; end
            % Yang2019 specific fields
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
    results.selectedTierIsGood = nan(1, numSim);
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

function metrics = computeMetrics(results, blockchainObj)
    metrics = struct();

    % Basic metrics
    metrics.SuccessRate = mean(results.offSuccessStatus, 'omitnan') * 100;
    metrics.FailureRate = 100 - metrics.SuccessRate;
    metrics.Latency = mean(results.latency, 'omitnan');

    % MAR
    malSelected = results.SVproisMalicious == 1;
    metrics.MAR = (1 - mean(malSelected, 'omitnan')) * 100;

    % === AVAILABILITY METRICS ===
    if isfield(results, 'noProviderAvailable')
        metrics.ServiceDenialRate = mean(results.noProviderAvailable) * 100;
        metrics.ServiceDenialCount = sum(results.noProviderAvailable);
    else
        metrics.ServiceDenialRate = 0;
        metrics.ServiceDenialCount = 0;
    end
    metrics.Availability = 100 - metrics.ServiceDenialRate;

    % Extract provider final states
    chain = blockchainObj.blockchain;
    isPro = arrayfun(@(b) isfield(b.data, 'VehicleRole') && startsWith(b.data.VehicleRole, 'Vpro'), chain);
    proBlocks = chain(isPro);
    pids = arrayfun(@(b) b.data.PID, proBlocks, 'UniformOutput', false);
    [~, lastIdx] = unique(pids, 'last');
    lastBlocks = proBlocks(sort(lastIdx));

    isMal = arrayfun(@(b) b.data.isMalicious, lastBlocks);
    isBlacklisted = arrayfun(@(b) b.data.isActive == false || (isfield(b.data, 'everBlacklisted') && b.data.everBlacklisted), lastBlocks);

    % === POOL AVAILABILITY (end state) ===
    numActive = sum(~isBlacklisted);
    metrics.PoolAvailability = numActive / numel(lastBlocks) * 100;
    metrics.HonestAvailability = sum(~isMal & ~isBlacklisted) / max(sum(~isMal), 1) * 100;

    % === GOVERNANCE METRICS (final blacklist state) ===
    totalMalicious = sum(isMal);
    TP_gov = sum(isMal & isBlacklisted);
    FP_gov = sum(~isMal & isBlacklisted);
    FN_gov = sum(isMal & ~isBlacklisted);
    TN_gov = sum(~isMal & ~isBlacklisted);

    metrics.TPR_gov = TP_gov / max(TP_gov + FN_gov, 1) * 100;
    metrics.FPR_gov = FP_gov / max(FP_gov + TN_gov, 1) * 100;
    metrics.FNR_gov = FN_gov / max(TP_gov + FN_gov, 1) * 100;
    metrics.TNR_gov = TN_gov / max(FP_gov + TN_gov, 1) * 100;
    metrics.Precision_gov = TP_gov / max(TP_gov + FP_gov, 1) * 100;
    metrics.NPV_gov = TN_gov / max(TN_gov + FN_gov, 1) * 100;
    metrics.F1_gov = 2 * TP_gov / max(2 * TP_gov + FP_gov + FN_gov, 1) * 100;

    % At 0% malicious, TPR/FNR/F1/Precision are undefined (no positives)
    if totalMalicious == 0
        metrics.TPR_gov = NaN;
        metrics.FNR_gov = NaN;
        metrics.F1_gov = NaN;
        metrics.Precision_gov = NaN;
        metrics.NPV_gov = NaN;
    end

    % === EXPOSURE-NORMALIZED DETECTION METRIC ===
    % TPR_exp: Detection rate conditioned on exposure (at least 1 interaction)
    % This metric is UNBIASED by selection strategy - it only considers providers
    % that the system actually had a chance to observe and gather evidence about.
    % Formula: TPR_exp = #{malicious blacklisted} / #{malicious with ≥1 interaction}
    if isfield(results, 'selectedPID')
        % Get all unique PIDs that were ever selected (had ≥1 interaction)
        selectedPIDs = results.selectedPID(~cellfun('isempty', results.selectedPID));
        exposedPIDs = unique([selectedPIDs{:}]);

        % Get PIDs of all providers from lastBlocks
        providerPIDs = arrayfun(@(b) b.data.PID, lastBlocks, 'UniformOutput', false);

        % Identify which providers had exposure (were selected at least once)
        hasExposure = cellfun(@(pid) any(ismember(pid, exposedPIDs)), providerPIDs);

        % Malicious providers with exposure
        malWithExposure = isMal & hasExposure;
        numMalExposed = sum(malWithExposure);

        % Malicious providers blacklisted given they had exposure
        malBlacklistedWithExposure = isMal & isBlacklisted & hasExposure;
        numMalBlacklistedExposed = sum(malBlacklistedWithExposure);

        % TPR_exp: exposure-normalized true positive rate
        if numMalExposed > 0
            metrics.TPR_exp = numMalBlacklistedExposed / numMalExposed * 100;
        else
            metrics.TPR_exp = NaN;  % No malicious providers were ever selected
        end

        % Additional exposure statistics
        metrics.MalExposureRate = numMalExposed / max(sum(isMal), 1) * 100;  % % of mal providers that got selected
        metrics.NumMalExposed = numMalExposed;
        metrics.NumMalBlacklistedExposed = numMalBlacklistedExposed;
    else
        metrics.TPR_exp = NaN;
        metrics.MalExposureRate = NaN;
        metrics.NumMalExposed = NaN;
        metrics.NumMalBlacklistedExposed = NaN;
    end

    % === SELECTION-BASED METRICS (per-selection outcome) ===
    isMalSel = results.SVproisMalicious == 1;
    isHonestSel = results.SVproisMalicious == 0;
    isFail = results.offSuccessStatus == 0;
    isSuccess = results.offSuccessStatus == 1;

    TP_sel = sum(isMalSel & isFail, 'omitnan');
    FP_sel = sum(isHonestSel & isFail, 'omitnan');
    TN_sel = sum(isHonestSel & isSuccess, 'omitnan');
    FN_sel = sum(isMalSel & isSuccess, 'omitnan');

    totalMalSel = TP_sel + FN_sel;
    totalHonSel = TN_sel + FP_sel;

    metrics.TPR_sel = TP_sel / max(totalMalSel, 1) * 100;
    metrics.FPR_sel = FP_sel / max(totalHonSel, 1) * 100;
    metrics.FNR_sel = FN_sel / max(totalMalSel, 1) * 100;
    metrics.TNR_sel = TN_sel / max(totalHonSel, 1) * 100;
    metrics.Precision_sel = TP_sel / max(TP_sel + FP_sel, 1) * 100;
    metrics.NPV_sel = TN_sel / max(TN_sel + FN_sel, 1) * 100;
    metrics.F1_sel = 2 * TP_sel / max(2 * TP_sel + FP_sel + FN_sel, 1) * 100;

    % PMTI per paper Section V-A: mean per-provider selections before first blacklist
    % event, averaged over restricted malicious providers. Returns NaN for models
    % with no governance (no providers ever blacklisted). Do not modify without
    % updating paper definition in same commit.
    pmtiVals = [];
    for b = 1:numel(lastBlocks)
        d = lastBlocks(b).data;
        if ~d.isMalicious
            continue;
        end
        % Only include providers that were restricted (have valid selectionsBeforeFirstBlacklist)
        if isfield(d, 'selectionsBeforeFirstBlacklist') && ...
           isnumeric(d.selectionsBeforeFirstBlacklist) && ...
           ~isempty(d.selectionsBeforeFirstBlacklist) && ...
           ~isnan(d.selectionsBeforeFirstBlacklist)
            pmtiVals(end+1) = d.selectionsBeforeFirstBlacklist;
        end
        % if never restricted: exclude from mean (do NOT add 0 or totalSelections)
    end
    if ~isempty(pmtiVals)
        metrics.PMTI = mean(pmtiVals);
    else
        metrics.PMTI = NaN;  % no malicious providers were restricted in this seed
    end

    % Reputation Separation (selection-weighted)
    updR = results.updatedReputation;
    if any(isMalSel) && any(isHonestSel)
        metrics.RepSep = mean(updR(isHonestSel), 'omitnan') - mean(updR(isMalSel), 'omitnan');
    else
        metrics.RepSep = NaN;
    end

    % Reputation Separation (population-level, per-provider end-state)
    finalR = arrayfun(@(b) b.data.reputation, lastBlocks);
    if any(isMal) && any(~isMal)
        metrics.RepSep_provider = mean(finalR(~isMal)) - mean(finalR(isMal));
    else
        metrics.RepSep_provider = NaN;
    end

    % SER_mal (dead metric — CandHasMalicious never set by simulationUtils)
    metrics.SER_mal = NaN;

    % === NEW v6 METRICS ===

    % EarlyMAR_100: MAR over first 100 runs (isolates initialization)
    earlyN = min(100, numel(results.SVproisMalicious));
    earlyMal = results.SVproisMalicious(1:earlyN) == 1;
    metrics.EarlyMAR_100 = (1 - mean(earlyMal, 'omitnan')) * 100;

    % Tier selection distribution (Good vs Warning at selection time)
    validSel = ~isnan(results.selectedTierIsGood);
    if any(validSel)
        metrics.PctGoodSel = mean(results.selectedTierIsGood(validSel)) * 100;
        metrics.PctWarningSel = 100 - metrics.PctGoodSel;
    else
        metrics.PctGoodSel = NaN;
        metrics.PctWarningSel = NaN;
    end
    metrics.PctServiceDenial = metrics.ServiceDenialRate;

    % Failure cause attribution
    failedRuns = isFail;
    numFailed = sum(failedRuns, 'omitnan');
    if numFailed > 0
        metrics.FailMalicious_Pct = sum(isMalSel & failedRuns, 'omitnan') / numFailed * 100;
        metrics.FailHonest_Pct = sum(isHonestSel & failedRuns, 'omitnan') / numFailed * 100;
    else
        metrics.FailMalicious_Pct = NaN;
        metrics.FailHonest_Pct = NaN;
    end

    % Undetected malicious rate
    totalMalProviders = sum(isMal);
    if totalMalProviders > 0
        undetected = sum(isMal & ~isBlacklisted);
        metrics.UndetectedMaliciousRate = undetected / totalMalProviders * 100;
    else
        metrics.UndetectedMaliciousRate = NaN;
    end

    % MAR_OverTime and CumMalSel (per-run vectors, stored separately)
    malSelVec = double(results.SVproisMalicious == 1);
    malSelVec(isnan(results.SVproisMalicious)) = 0;
    validRuns = ~isnan(results.SVproisMalicious);
    cumValid = cumsum(double(validRuns));
    cumMalSel = cumsum(malSelVec);
    metrics.ts_CumMalSel = cumMalSel;
    metrics.ts_MAR_OverTime = (1 - cumMalSel ./ max(cumValid, 1)) * 100;

    % Legacy aliases
    metrics.TPR = metrics.TPR_gov;
    metrics.FPR = metrics.FPR_gov;
    metrics.FNR = metrics.FNR_gov;
    metrics.TNR = metrics.TNR_gov;
    metrics.Precision = metrics.Precision_gov;
    metrics.NPV = metrics.NPV_gov;
    metrics.F1 = metrics.F1_gov;
end

function avgMetrics = averageMetrics(seedMetrics)
    fields = fieldnames(seedMetrics(1));
    avgMetrics = struct();
    for i = 1:numel(fields)
        f = fields{i};
        if startsWith(f, 'ts_')
            % Time-series fields: stack into matrix, average column-wise
            nSeeds = numel(seedMetrics);
            len = numel(seedMetrics(1).(f));
            mat = zeros(nSeeds, len);
            for si = 1:nSeeds
                mat(si, :) = seedMetrics(si).(f);
            end
            avgMetrics.(f) = mean(mat, 1, 'omitnan');
        else
            vals = [seedMetrics.(f)];
            avgMetrics.(f) = mean(vals, 'omitnan');
        end
    end
end

function arr = appendStructRow(arr, s)
% Append struct s to struct-array arr, padding either side with [] for any
% missing fields so MATLAB's "dissimilar structures" rule doesn't fire.
% Different reputation models produce different metric fields; this lets
% them coexist in one results array.
    if isempty(arr)
        arr = s;
        return;
    end
    arrFields = fieldnames(arr);
    sFields = fieldnames(s);
    missingInS = setdiff(arrFields, sFields);
    for k = 1:numel(missingInS)
        s.(missingInS{k}) = [];
    end
    missingInArr = setdiff(sFields, arrFields);
    for k = 1:numel(missingInArr)
        [arr.(missingInArr{k})] = deal([]);
    end
    s = orderfields(s, arr);
    arr = [arr; s];
end

function precomputed = precomputeRandomSelections(numSims, maxProviders)
% PRECOMPUTERANDOMSELECTIONS Pre-compute random permutations for fair comparison

    precomputed = cell(1, numSims);
    for sim = 1:numSims
        precomputed{sim} = struct();
        precomputed{sim}.badPerm = randperm(maxProviders);
        precomputed{sim}.goodPerm = randperm(maxProviders);
        precomputed{sim}.shufflePerm = randperm(maxProviders);
    end
end

function VprojSet = sampleProvidersWithPrecomputed(blockchainObj, subsetSize, malPct, randStruct)
% SAMPLEPROVIDERSWITHPRECOMPUTED Sample providers using pre-computed randomness
%
% NOTE: Providers in blackout (blackoutCounter > 0) are excluded from sampling.
% The blackout counters are decremented at the simulation step level by
% decrementBlackoutCounters() BEFORE this function is called.

    chain = blockchainObj.blockchain;
    isPro = arrayfun(@(b) isfield(b.data, 'VehicleRole') && startsWith(b.data.VehicleRole, 'Vpro'), chain);
    proBlocks = chain(isPro);

    pids = arrayfun(@(b) b.data.PID, proBlocks, 'UniformOutput', false);
    [~, lastIdx] = unique(pids, 'last');
    lastBlocks = proBlocks(sort(lastIdx));

    % Filter out providers in blackout (blackoutCounter > 0)
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
% INITREPUTATIONFORMODEL Set initial reputation based on model type
%
% For FAIR comparison, each model uses its prescribed initialization:
%
% ST-based models (keep existing ST-conditioned initialization):
%   - RUST, RUST_V2, RUST_NoRec, Threshold: ST → R (0.417/0.500/0.583)
%   - Yang (original): ST → α,β priors
%   - SimpleAvg: ST → prior_R
%
% Beta-based uniform models (uniform α=1, β=1 → R=0.5):
%   - BetaUniform: Jøsang BRS, uniform prior
%   - YangUniform: Yang Bayesian, uniform prior
%
% SL uniform models (Kang: α=1, β=1, γ=1 → R=0.5):
%   - KangMWSL: Kang MWSL uniform prior
%
% SL Fix-A uniform models (α=2, β=2, γ=2 → R=0.5):
%   - ThresholdUniform: Threshold with symmetric SL prior
%   - RUST_Uniform: RUST with symmetric SL prior (no ST differentiation)
%
% Scalar uniform models (R=0.5, no Beta params):
%   - Iqbal: EMA-based, R₀=0.5 (per Iqbal et al. 2020 neutral initialization)
%   - Bounaira: Linear trust, T₀=0.5
%
% Cumulative models (R=0, unbounded accumulation):
%   - Iqbal2: Faithful paper, ρ₀=0, cumulative ρᵢ = ρᵢ₋₁ + l

    % === Model Categories ===
    % ST-based / default init: Keep existing initialization
    %   ST-conditioned: RUST*, Threshold, Yang, SimpleAvg, SLFixedGamma
    %   Offset-based:   Yang2019 (starts at trust=0 via initModelFields)
    stBasedModels = {'RUST', 'RUST_V2', 'RUST_V3', 'RUST_PERREQ', 'RUST_NoRec', 'RUST_NoTier', 'RUST_NoDH', ...
                     'RUST_PerReq_NoRec', 'RUST_PerReq_NoTier', 'RUST_PerReq_NoDH', ...
                     'RUST_V3_NoRec', 'RUST_V3_NoTier', 'RUST_V3_NoDH', ...
                     'REVST', 'REVST_V3', 'REVST_NoRec', 'REVST_NoTier', ...
                     'Threshold', 'Threshold_Baseline', 'Threshold_MaxRep', ...
                     'RUST_NOTIER_baseline', 'REVST_NOTIER_baseline', ...
                     'Yang', 'Yang2019', 'SimpleAvg', 'SLFixedGamma', '3VSL-Binary'};

    % Beta-based uniform: Reset to α=1, β=1 → R=0.5
    betaUniformModels = {'BetaUniform', 'YangUniform', 'Beta', 'Beta_BRS'};

    % Subjective Logic uniform (Kang): Reset to α=1, β=1, γ=1 → R=0.5
    slUniformModels = {'KangMWSL'};

    % Subjective Logic uniform Fix-A: Reset to α=2, β=2, γ=2 → R=0.5
    % Same SL structure as REVS-T but with symmetric uniform prior
    slFixAModels = {'ThresholdUniform', 'ThresholdUniform_Baseline', ...
                    'RUST_Uniform', 'REVST_Uniform', ...
                    'RUST_PerReq_Uniform', 'RUST_V3_Uniform'};

    % Scalar uniform: Reset R=0.5 only (no Beta params, they're irrelevant)
    scalarUniformModels = {'Iqbal', 'Bounaira'};

    % Cumulative models: Start at R=0 (faithful paper implementation)
    % Iqbal2 uses cumulative ρᵢ = ρᵢ₋₁ + l, starting from 0
    cumulativeModels = {'Iqbal2'};

    % Determine model category
    if any(strcmpi(model, stBasedModels))
        % ST-based model - keep existing ST-conditioned initialization
        return;
    end

    isBetaUniform = any(strcmpi(model, betaUniformModels));
    isSLUniform = any(strcmpi(model, slUniformModels));
    isSLFixA = any(strcmpi(model, slFixAModels));
    isScalarUniform = any(strcmpi(model, scalarUniformModels));
    isCumulative = any(strcmpi(model, cumulativeModels));

    if ~isBetaUniform && ~isSLUniform && ~isSLFixA && ~isScalarUniform && ~isCumulative
        % Unknown model - keep existing (conservative)
        warning('initReputationForModel: Unknown model "%s", keeping ST-based init', model);
        return;
    end

    % Reset provider reputations based on model type
    chain = blockchainObj.blockchain;
    for i = 1:numel(chain)
        if isfield(chain(i).data, 'VehicleRole') && startsWith(chain(i).data.VehicleRole, 'Vpro')

            % Most uniform models start at R=0.5 (cumulative models override below)
            chain(i).data.reputation = 0.5;

            if isBetaUniform
                % Beta-based uniform: Jøsang BRS uniform prior
                % α=1, β=1 → R = α/(α+β) = 0.5
                chain(i).data.betaAlpha = 1;
                chain(i).data.betaBeta = 1;
                % ST-blind model: reset ST to intermediate for consistency
                % (calculation ignores ST, but makes logging/analysis cleaner)
                chain(i).data.socialTrustLevel = 'intermediate';

            elseif isSLUniform
                % Subjective Logic uniform: Kang MWSL uniform prior
                % α=1, β=1, γ=1 → b=d=u=1/3
                chain(i).data.betaAlpha = 1;
                chain(i).data.betaBeta = 1;
                if isfield(chain(i).data, 'betaGamma')
                    chain(i).data.betaGamma = 1;
                end
                % ST-blind model: reset ST to intermediate for consistency
                chain(i).data.socialTrustLevel = 'intermediate';

            elseif isSLFixA
                % Subjective Logic Fix-A uniform: symmetric prior with more evidence
                % α=2, β=2, γ=2 → R = α/(α+β) = 0.5, balanced uncertainty
                % Same SL structure as RUST but without ST-based differentiation
                chain(i).data.betaAlpha = 2;
                chain(i).data.betaBeta = 2;
                if isfield(chain(i).data, 'betaGamma')
                    chain(i).data.betaGamma = 2;
                end
                % TRUE UNIFORM: Set ALL providers to intermediate ST level
                % This ensures Dynamic Honesty uses H_base=0.60 for ALL providers
                % and grace period is disabled (requires HIGH-ST)
                chain(i).data.socialTrustLevel = 'intermediate';
                % Reset initial evidence fields to uniform (2,2,2)
                if isfield(chain(i).data, 'ini_alpha')
                    chain(i).data.ini_alpha = 2;
                    chain(i).data.ini_beta = 2;
                    chain(i).data.ini_gamma = 2;
                end
                % Reset w_ij (belief, distrust, uncertainty) to uniform
                if isfield(chain(i).data, 'w_ij')
                    % α=2, β=2, γ=2 → S=6 → b=d=u=1/3
                    chain(i).data.w_ij = [1/3; 1/3; 1/3];
                end
                % CRITICAL: Reset per-requester evidence in Offtransaction to uniform (2,2,2)
                % This fixes FPR_gov issue where ST_low honest providers started near R_min
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
                % Scalar uniform: Only reputation matters, no Beta params
                % Iqbal: R₀=0.5 per neutral EMA initialization
                % Bounaira: T₀=0.5 per paper
                if isfield(chain(i).data, 'trustValue')
                    chain(i).data.trustValue = 0.5;  % Bounaira
                end
                % ST-blind model: reset ST to intermediate for consistency
                chain(i).data.socialTrustLevel = 'intermediate';
                % Note: betaAlpha/betaBeta are irrelevant for scalar models
                % but we don't modify them to avoid confusion

            elseif isCumulative
                % Cumulative models: Start at R=0 (faithful paper implementation)
                % Iqbal2: ρ₀ = 0, rewards accumulate via ρᵢ = ρᵢ₋₁ + l
                chain(i).data.reputation = 0;
            end

            % NOTE: For ALL ST-blind models (isBetaUniform, isSLUniform, isSLFixA,
            % isScalarUniform), ST level is set to 'intermediate' for consistency.
            % This ensures fair comparison: ST-blind models can't exploit ST correlation.
            % ST-based models (REVST, Threshold) preserve ST from assignment.
        end
    end
    blockchainObj.blockchain = chain;
end

function name = getDisplayName(displayNames, model)
%GETDISPLAYNAME Get display name for model, fall back to internal name
    if displayNames.isKey(model)
        name = displayNames(model);
    else
        name = model;
        fprintf('WARNING: No display name for model "%s" — using internal name.\n', model);
    end
end

%% ==================== TRAJECTORY CAPTURE FUNCTIONS ====================

function trajectories = initTrajectoryStorage(blockchainObj)
%INITTRAJECTORYSORAGE Initialize storage for provider trajectories
    trajectories = struct();
    chain = blockchainObj.blockchain;

    for i = 1:numel(chain)
        if isfield(chain(i).data, 'VehicleRole') && startsWith(chain(i).data.VehicleRole, 'Vpro')
            pid = chain(i).data.PID;
            safePid = matlab.lang.makeValidName(pid);

            trajectories.(safePid) = struct();
            trajectories.(safePid).PID = pid;
            trajectories.(safePid).isMalicious = chain(i).data.isMalicious;
            trajectories.(safePid).socialTrustLevel = chain(i).data.socialTrustLevel;

            % Pre-allocate arrays (will grow dynamically)
            trajectories.(safePid).runIndex = [];
            trajectories.(safePid).reputation = [];
            trajectories.(safePid).alpha = [];
            trajectories.(safePid).beta = [];
            trajectories.(safePid).gamma = [];
            trajectories.(safePid).belief = [];
            trajectories.(safePid).disbelief = [];
            trajectories.(safePid).uncertainty = [];
            trajectories.(safePid).isActive = [];
            trajectories.(safePid).isWarning = [];
            trajectories.(safePid).numSelections = [];
        end
    end
end

function trajectories = captureTrajectoryState(trajectories, blockchainObj, runIndex)
%CAPTURETRAJECTORYSTATE Capture current state of all providers
    chain = blockchainObj.blockchain;

    for i = 1:numel(chain)
        if isfield(chain(i).data, 'VehicleRole') && startsWith(chain(i).data.VehicleRole, 'Vpro')
            d = chain(i).data;
            safePid = matlab.lang.makeValidName(d.PID);

            if isfield(trajectories, safePid)
                trajectories.(safePid).runIndex(end+1) = runIndex;
                trajectories.(safePid).reputation(end+1) = d.reputation;

                % Get α, β, γ - RUST stores per-requester, need to aggregate
                [alpha, beta_val, gamma] = getProviderEvidence(d);

                trajectories.(safePid).alpha(end+1) = alpha;
                trajectories.(safePid).beta(end+1) = beta_val;
                trajectories.(safePid).gamma(end+1) = gamma;

                % Compute b, d, u from evidence
                S = alpha + beta_val + gamma;
                if S > 0
                    b = alpha / S;
                    dis = beta_val / S;
                    u = gamma / S;
                else
                    b = 0.5; dis = 0.5; u = 0;
                end

                trajectories.(safePid).belief(end+1) = b;
                trajectories.(safePid).disbelief(end+1) = dis;
                trajectories.(safePid).uncertainty(end+1) = u;

                trajectories.(safePid).isActive(end+1) = d.isActive;
                trajectories.(safePid).isWarning(end+1) = getFieldOr(d, 'isWarning', false);
                trajectories.(safePid).numSelections(end+1) = getFieldOr(d, 'totalSelections', 0);
            end
        end
    end
end

function ppc = capturePerPairCounters(blockchainObj)
%CAPTUREPERPAIRCOUNTERS Read-only end-of-run snapshot of per-(provider,requester)
%   DH counters and interaction counts. Does NOT modify any simulation state.
%   One row per (provider, requester) pair that has >=1 interaction, for
%   measuring the per-pair interaction-count distribution (validates whether
%   per-pair streaks reach the bonus saturation point).
    chain = blockchainObj.blockchain;
    ppc = struct('providerPID',{},'requesterID',{},'isMalicious',{}, ...
                 'socialTrustLevel',{},'localTotalInteractions',{}, ...
                 'localSuccessStreak',{},'numTransactions',{}, ...
                 'numSuccess',{},'numFailed',{});
    for i = 1:numel(chain)
        d = chain(i).data;
        if ~isfield(d,'VehicleRole') || ~startsWith(d.VehicleRole,'Vpro'); continue; end
        reqIDs = {};
        if isfield(d,'localTotalInteractions') && isstruct(d.localTotalInteractions)
            reqIDs = fieldnames(d.localTotalInteractions);
        elseif isfield(d,'Offtransaction') && isstruct(d.Offtransaction) && isfield(d.Offtransaction,'numTransactions')
            reqIDs = fieldnames(d.Offtransaction.numTransactions);
        end
        for r = 1:numel(reqIDs)
            req = reqIDs{r};
            row = struct();
            row.providerPID            = d.PID;
            row.requesterID            = req;
            row.isMalicious            = getFieldOr(d,'isMalicious',false);
            row.socialTrustLevel       = getFieldOr(d,'socialTrustLevel','');
            row.localTotalInteractions = readPairCounter(d,'localTotalInteractions',req);
            row.localSuccessStreak     = readPairCounter(d,'localSuccessStreak',req);
            if isfield(d,'Offtransaction') && isstruct(d.Offtransaction)
                row.numTransactions = readPairCounter(d.Offtransaction,'numTransactions',req);
                row.numSuccess      = readPairCounter(d.Offtransaction,'numSuccess',req);
                row.numFailed       = readPairCounter(d.Offtransaction,'numFailed',req);
            else
                row.numTransactions = NaN; row.numSuccess = NaN; row.numFailed = NaN;
            end
            ppc(end+1) = row; %#ok<AGROW>
        end
    end
end

function v = readPairCounter(s, field, key)
%READPAIRCOUNTER Safe read of s.(field).(key); NaN if absent. Read-only.
    v = NaN;
    if isfield(s, field) && isstruct(s.(field)) && isfield(s.(field), key)
        val = s.(field).(key);
        if isnumeric(val) && ~isempty(val); v = double(val); end
    end
end

function [alpha, beta_val, gamma] = getProviderEvidence(d)
%GETPROVIDEREVIDENCE Extract total α, β, γ evidence from provider data
%   Handles both RUST (per-requester in Offtransaction) and Beta models (global fields)

    % Try RUST format first: aggregate across all requesters
    if isfield(d, 'Offtransaction') && isfield(d.Offtransaction, 'numAlpha')
        alphaStruct = d.Offtransaction.numAlpha;
        betaStruct = d.Offtransaction.numBeta;
        gammaStruct = d.Offtransaction.numGamma;

        % Sum across all requesters
        alpha = 0; beta_val = 0; gamma = 0;
        reqIDs = fieldnames(alphaStruct);
        for r = 1:numel(reqIDs)
            reqID = reqIDs{r};
            alpha = alpha + alphaStruct.(reqID);
            if isfield(betaStruct, reqID)
                beta_val = beta_val + betaStruct.(reqID);
            end
            if isfield(gammaStruct, reqID)
                gamma = gamma + gammaStruct.(reqID);
            end
        end
        return;
    end

    % Fall back to global Beta fields
    alpha = getFieldOr(d, 'betaAlpha', 1);
    beta_val = getFieldOr(d, 'betaBeta', 1);
    gamma = getFieldOr(d, 'slGamma', getFieldOr(d, 'betaGamma', 0));
end

function val = getFieldOr(s, fieldName, defaultVal)
%GETFIELDOR Get field value or default if not present
    if isfield(s, fieldName)
        val = s.(fieldName);
    else
        val = defaultVal;
    end
end

%% ==================== TRAJECTORY FIGURE GENERATION ====================

function generateEvidenceEvolutionFigure(allTrajectories, modelName, displayNames, outDir)
%GENERATEEVIDENCEEVOLUTIONFIGURE Plot α, β, γ evolution for malicious vs honest
    safeName = matlab.lang.makeValidName(modelName);
    if ~isfield(allTrajectories, safeName)
        return;
    end

    traj = allTrajectories.(safeName);
    fields = fieldnames(traj);

    % Separate malicious and honest
    malAlpha = []; malBeta = []; malGamma = []; malRuns = [];
    honAlpha = []; honBeta = []; honGamma = []; honRuns = [];

    for i = 1:numel(fields)
        f = fields{i};
        if isfield(traj.(f), 'isMalicious')
            if traj.(f).isMalicious
                if ~isempty(traj.(f).alpha)
                    malAlpha = [malAlpha; traj.(f).alpha(:)'];
                    malBeta = [malBeta; traj.(f).beta(:)'];
                    malGamma = [malGamma; traj.(f).gamma(:)'];
                    malRuns = traj.(f).runIndex;
                end
            else
                if ~isempty(traj.(f).alpha)
                    honAlpha = [honAlpha; traj.(f).alpha(:)'];
                    honBeta = [honBeta; traj.(f).beta(:)'];
                    honGamma = [honGamma; traj.(f).gamma(:)'];
                    honRuns = traj.(f).runIndex;
                end
            end
        end
    end

    if isempty(malAlpha) || isempty(honAlpha)
        fprintf('  Skipping evidence evolution figure (insufficient data)\n');
        return;
    end

    fig = figure('Position', [100 100 1200 400], 'Visible', 'off');

    % Alpha
    subplot(1,3,1);
    hold on;
    plot(honRuns, mean(honAlpha, 1), 'b-', 'LineWidth', 2, 'DisplayName', 'Honest');
    plot(malRuns, mean(malAlpha, 1), 'r-', 'LineWidth', 2, 'DisplayName', 'Malicious');
    xlabel('Run Index');
    ylabel('\alpha (Positive Evidence)');
    title('\alpha Evolution');
    legend('Location', 'best');
    grid on;

    % Beta
    subplot(1,3,2);
    hold on;
    plot(honRuns, mean(honBeta, 1), 'b-', 'LineWidth', 2, 'DisplayName', 'Honest');
    plot(malRuns, mean(malBeta, 1), 'r-', 'LineWidth', 2, 'DisplayName', 'Malicious');
    xlabel('Run Index');
    ylabel('\beta (Negative Evidence)');
    title('\beta Evolution');
    legend('Location', 'best');
    grid on;

    % Gamma
    subplot(1,3,3);
    hold on;
    plot(honRuns, mean(honGamma, 1), 'b-', 'LineWidth', 2, 'DisplayName', 'Honest');
    plot(malRuns, mean(malGamma, 1), 'r-', 'LineWidth', 2, 'DisplayName', 'Malicious');
    xlabel('Run Index');
    ylabel('\gamma (Uncertainty Evidence)');
    title('\gamma Evolution');
    legend('Location', 'best');
    grid on;

    dispName = getDisplayNameSafe(displayNames, modelName);
    sgtitle(sprintf('%s: Evidence Evolution (\\alpha, \\beta, \\gamma)', dispName));
    saveas(fig, fullfile(outDir, sprintf('evidence_evolution_%s.png', modelName)));
    close(fig);

    fprintf('  Saved: evidence_evolution_%s.png\n', modelName);
end

function generateUncertaintyDecayFigure(allTrajectories, models, displayNames, outDir)
%GENERATEUNCERTAINTYDECAYFIGURE Plot uncertainty decay comparison
    fig = figure('Position', [100 100 800 500], 'Visible', 'off');
    hold on;

    colors = lines(numel(models));

    for m = 1:numel(models)
        model = models{m};
        safeName = matlab.lang.makeValidName(model);

        if ~isfield(allTrajectories, safeName)
            continue;
        end

        traj = allTrajectories.(safeName);
        fields = fieldnames(traj);

        % Collect uncertainty for malicious providers only
        allU = [];
        runs = [];

        for i = 1:numel(fields)
            f = fields{i};
            if isfield(traj.(f), 'isMalicious') && traj.(f).isMalicious
                if ~isempty(traj.(f).uncertainty)
                    allU = [allU; traj.(f).uncertainty(:)'];
                    runs = traj.(f).runIndex;
                end
            end
        end

        if ~isempty(allU)
            dispName = getDisplayNameSafe(displayNames, model);
            plot(runs, mean(allU, 1), 'LineWidth', 2, 'Color', colors(m,:), ...
                'DisplayName', dispName);
        end
    end

    xlabel('Run Index');
    ylabel('Uncertainty (u)');
    title('Uncertainty Decay for Malicious Providers');
    legend('Location', 'best');
    grid on;

    saveas(fig, fullfile(outDir, 'uncertainty_decay_comparison.png'));
    close(fig);

    fprintf('  Saved: uncertainty_decay_comparison.png\n');
end

function generateSTLevelTrajectoryFigure(allTrajectories, modelName, displayNames, outDir)
%GENERATESTLEVELTRAJECTORFIGURE Plot reputation by ST level
    safeName = matlab.lang.makeValidName(modelName);
    if ~isfield(allTrajectories, safeName)
        return;
    end

    traj = allTrajectories.(safeName);
    fields = fieldnames(traj);

    % Group by ST level and malicious status
    groups = struct();
    for st = ["high", "intermediate", "low"]
        for mal = [0, 1]
            key = sprintf('%s_%s', st, ternaryStr(mal, 'mal', 'hon'));
            groups.(key).rep = [];
            groups.(key).runs = [];
        end
    end

    for i = 1:numel(fields)
        f = fields{i};
        if isfield(traj.(f), 'socialTrustLevel') && isfield(traj.(f), 'isMalicious')
            st = lower(string(traj.(f).socialTrustLevel));
            mal = traj.(f).isMalicious;
            key = sprintf('%s_%s', st, ternaryStr(mal, 'mal', 'hon'));

            if isfield(groups, key) && ~isempty(traj.(f).reputation)
                groups.(key).rep = [groups.(key).rep; traj.(f).reputation(:)'];
                groups.(key).runs = traj.(f).runIndex;
            end
        end
    end

    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    % Honest providers
    subplot(1,2,1);
    hold on;
    stColors = struct('high', [0 0.5 0], 'intermediate', [0 0 0.8], 'low', [0.8 0 0]);
    for st = ["high", "intermediate", "low"]
        key = sprintf('%s_hon', st);
        if ~isempty(groups.(key).rep)
            plot(groups.(key).runs, mean(groups.(key).rep, 1), ...
                'LineWidth', 2, 'Color', stColors.(st), 'DisplayName', sprintf('ST=%s', st));
        end
    end
    xlabel('Run Index');
    ylabel('Reputation');
    title('Honest Providers');
    legend('Location', 'best');
    grid on;
    ylim([0 1]);

    % Malicious providers
    subplot(1,2,2);
    hold on;
    for st = ["high", "intermediate", "low"]
        key = sprintf('%s_mal', st);
        if ~isempty(groups.(key).rep)
            plot(groups.(key).runs, mean(groups.(key).rep, 1), ...
                'LineWidth', 2, 'Color', stColors.(st), 'DisplayName', sprintf('ST=%s', st));
        end
    end
    xlabel('Run Index');
    ylabel('Reputation');
    title('Malicious Providers');
    legend('Location', 'best');
    grid on;
    ylim([0 1]);

    dispName = getDisplayNameSafe(displayNames, modelName);
    sgtitle(sprintf('%s: Reputation by Social Trust Level', dispName));
    saveas(fig, fullfile(outDir, sprintf('st_level_trajectory_%s.png', modelName)));
    close(fig);

    fprintf('  Saved: st_level_trajectory_%s.png\n', modelName);
end

function generateDetectionTimeFigure(allTrajectories, models, displayNames, outDir)
%GENERATEDETECTIONTIMEFIGURE Plot time to first blacklist
    fig = figure('Position', [100 100 600 400], 'Visible', 'off');

    detectionTimes = [];
    modelLabels = {};

    for m = 1:numel(models)
        model = models{m};
        safeName = matlab.lang.makeValidName(model);

        if ~isfield(allTrajectories, safeName)
            continue;
        end

        traj = allTrajectories.(safeName);
        fields = fieldnames(traj);

        % Find first blacklist time for malicious providers
        times = [];
        for i = 1:numel(fields)
            f = fields{i};
            if isfield(traj.(f), 'isMalicious') && traj.(f).isMalicious
                % Find first time isActive becomes false
                activeIdx = find(traj.(f).isActive == 0, 1);
                if ~isempty(activeIdx)
                    times(end+1) = traj.(f).runIndex(activeIdx);
                end
            end
        end

        if ~isempty(times)
            detectionTimes(end+1) = mean(times);
            modelLabels{end+1} = getDisplayNameSafe(displayNames, model);
        end
    end

    if ~isempty(detectionTimes)
        bar(detectionTimes);
        set(gca, 'XTickLabel', modelLabels, 'XTickLabelRotation', 45);
        ylabel('Mean Run Index to First Blacklist');
        title('Time to Detection (Malicious Providers)');
        grid on;
    end

    saveas(fig, fullfile(outDir, 'detection_time_comparison.png'));
    close(fig);

    fprintf('  Saved: detection_time_comparison.png\n');
end

function generateEvidenceRateFigure(allTrajectories, models, displayNames, outDir)
%GENERATEEVIDENCERATEFIGURE Plot evidence accumulation rates
    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1,2,1);
    hold on;
    colors = lines(numel(models));

    for m = 1:numel(models)
        model = models{m};
        safeName = matlab.lang.makeValidName(model);

        if ~isfield(allTrajectories, safeName)
            continue;
        end

        traj = allTrajectories.(safeName);
        fields = fieldnames(traj);

        % Compute dα/dt for honest providers
        allDa = [];
        for i = 1:numel(fields)
            f = fields{i};
            if isfield(traj.(f), 'isMalicious') && ~traj.(f).isMalicious
                if length(traj.(f).alpha) > 1
                    da = diff(traj.(f).alpha);
                    allDa = [allDa; da(:)'];
                end
            end
        end

        if ~isempty(allDa)
            meanDa = mean(allDa, 1);
            dispName = getDisplayNameSafe(displayNames, model);
            plot(1:length(meanDa), meanDa, 'LineWidth', 1.5, 'Color', colors(m,:), ...
                'DisplayName', dispName);
        end
    end
    xlabel('Interaction');
    ylabel('\Delta\alpha per interaction');
    title('\alpha Accumulation Rate (Honest)');
    legend('Location', 'best');
    grid on;

    subplot(1,2,2);
    hold on;

    for m = 1:numel(models)
        model = models{m};
        safeName = matlab.lang.makeValidName(model);

        if ~isfield(allTrajectories, safeName)
            continue;
        end

        traj = allTrajectories.(safeName);
        fields = fieldnames(traj);

        % Compute dβ/dt for malicious providers
        allDb = [];
        for i = 1:numel(fields)
            f = fields{i};
            if isfield(traj.(f), 'isMalicious') && traj.(f).isMalicious
                if length(traj.(f).beta) > 1
                    db = diff(traj.(f).beta);
                    allDb = [allDb; db(:)'];
                end
            end
        end

        if ~isempty(allDb)
            meanDb = mean(allDb, 1);
            dispName = getDisplayNameSafe(displayNames, model);
            plot(1:length(meanDb), meanDb, 'LineWidth', 1.5, 'Color', colors(m,:), ...
                'DisplayName', dispName);
        end
    end
    xlabel('Interaction');
    ylabel('\Delta\beta per interaction');
    title('\beta Accumulation Rate (Malicious)');
    legend('Location', 'best');
    grid on;

    sgtitle('Evidence Accumulation Rate Comparison');
    saveas(fig, fullfile(outDir, 'evidence_rate_comparison.png'));
    close(fig);

    fprintf('  Saved: evidence_rate_comparison.png\n');
end

function summaryTable = generateTrajectorySummaryTable(allTrajectories, models, displayNames)
%GENERATETRAJECTORYSUMMARYTABLE Generate summary table of trajectory characteristics
    rows = {};

    for m = 1:numel(models)
        model = models{m};
        safeName = matlab.lang.makeValidName(model);

        if ~isfield(allTrajectories, safeName)
            continue;
        end

        traj = allTrajectories.(safeName);
        fields = fieldnames(traj);

        % Compute summary stats
        malFinalRep = []; honFinalRep = [];
        malFinalU = []; honFinalU = [];
        detectionTimes = [];

        for i = 1:numel(fields)
            f = fields{i};
            if isfield(traj.(f), 'isMalicious')
                if traj.(f).isMalicious
                    if ~isempty(traj.(f).reputation)
                        malFinalRep(end+1) = traj.(f).reputation(end);
                        malFinalU(end+1) = traj.(f).uncertainty(end);
                    end
                    activeIdx = find(traj.(f).isActive == 0, 1);
                    if ~isempty(activeIdx)
                        detectionTimes(end+1) = traj.(f).runIndex(activeIdx);
                    end
                else
                    if ~isempty(traj.(f).reputation)
                        honFinalRep(end+1) = traj.(f).reputation(end);
                        honFinalU(end+1) = traj.(f).uncertainty(end);
                    end
                end
            end
        end

        row = struct();
        row.Model = string(getDisplayNameSafe(displayNames, model));
        row.MalFinalRep = mean(malFinalRep, 'omitnan');
        row.HonFinalRep = mean(honFinalRep, 'omitnan');
        row.RepSeparation = row.HonFinalRep - row.MalFinalRep;
        row.MalFinalU = mean(malFinalU, 'omitnan');
        row.HonFinalU = mean(honFinalU, 'omitnan');
        row.MeanDetectionTime = mean(detectionTimes, 'omitnan');
        row.DetectionRate = length(detectionTimes) / max(length(malFinalRep), 1) * 100;

        rows{end+1} = row;
    end

    if ~isempty(rows)
        summaryTable = struct2table([rows{:}]);
    else
        summaryTable = table();
    end
end

function result = ternaryStr(cond, trueVal, falseVal)
%TERNARYSTR Ternary operator for strings
    if cond
        result = trueVal;
    else
        result = falseVal;
    end
end

function name = getDisplayNameSafe(displayNames, model)
%GETDISPLAYNAMESAFE Get display name, handle both internal and valid names
    % First try the model name as-is
    if displayNames.isKey(model)
        name = displayNames(model);
        return;
    end

    % Try to convert valid name back to internal name and look up
    % e.g., RUST_V2 is already valid, but some might have been converted
    name = model;  % Fall back to model name itself
end

%% ==================== TRUST EVOLUTION MATRIX FUNCTIONS ====================
% These functions create the trustEvolution struct compatible with
% generate_trust_evolution_from_simulation.m

function te = initTrustEvolutionMatrix(blockchainObj, numSimulations)
%INITTRUSTEVOLUTIONMATRIX Initialize trustEvolution in matrix format
%   Creates [nProviders × (numSimulations+1)] matrices where column 1 is t=0

    chain = blockchainObj.blockchain;

    % Count providers and collect metadata
    providerPIDs = {};
    isMalicious = [];
    socialTrustLevel = {};

    for i = 1:numel(chain)
        if isfield(chain(i).data, 'VehicleRole') && startsWith(chain(i).data.VehicleRole, 'Vpro')
            providerPIDs{end+1} = chain(i).data.PID;
            isMalicious(end+1) = chain(i).data.isMalicious;
            socialTrustLevel{end+1} = chain(i).data.socialTrustLevel;
        end
    end

    nProviders = numel(providerPIDs);
    nTimeSteps = numSimulations + 1;  % +1 for t=0

    % Initialize matrices with NaN
    te = struct();
    te.providerPIDs = providerPIDs;
    te.isMalicious = isMalicious(:);
    te.socialTrustLevel = socialTrustLevel;
    te.timeSteps = 0:numSimulations;

    % Pre-allocate matrices
    te.reputation = NaN(nProviders, nTimeSteps);
    te.belief = NaN(nProviders, nTimeSteps);
    te.distrust = NaN(nProviders, nTimeSteps);
    te.uncertainty = NaN(nProviders, nTimeSteps);
    te.alpha = NaN(nProviders, nTimeSteps);
    te.beta = NaN(nProviders, nTimeSteps);
    te.gamma = NaN(nProviders, nTimeSteps);
    te.isActive = NaN(nProviders, nTimeSteps);
    te.isWarning = NaN(nProviders, nTimeSteps);
    te.warningStreak = NaN(nProviders, nTimeSteps);
    te.blackoutCounter = NaN(nProviders, nTimeSteps);
    te.totalBlacklists = NaN(nProviders, nTimeSteps);
    % Option A: cumulative recommendation impact per provider per timestep
    te.rec_calls    = NaN(nProviders, nTimeSteps);
    te.rec_sum_lift = NaN(nProviders, nTimeSteps);
    te.rec_sum_absl = NaN(nProviders, nTimeSteps);
    te.wasSelected = false(nProviders, nTimeSteps);

    % Create PID to index map for fast lookup
    te.pidToIndex = containers.Map(providerPIDs, 1:nProviders);
end

function te = captureTrustEvolutionState(te, blockchainObj, colIndex)
%CAPTURETRUSTEVOLUTIONSTATE Capture current state into column colIndex

    chain = blockchainObj.blockchain;

    for i = 1:numel(chain)
        if isfield(chain(i).data, 'VehicleRole') && startsWith(chain(i).data.VehicleRole, 'Vpro')
            d = chain(i).data;
            pid = d.PID;

            if te.pidToIndex.isKey(pid)
                pIdx = te.pidToIndex(pid);

                te.reputation(pIdx, colIndex) = d.reputation;

                % Get α, β, γ - use aggregation for RUST models
                [alpha, beta_val, gamma] = getProviderEvidence(d);

                te.alpha(pIdx, colIndex) = alpha;
                te.beta(pIdx, colIndex) = beta_val;
                te.gamma(pIdx, colIndex) = gamma;

                % Compute b, d, u
                S = alpha + beta_val + gamma;
                if S > 0
                    te.belief(pIdx, colIndex) = alpha / S;
                    te.distrust(pIdx, colIndex) = beta_val / S;
                    te.uncertainty(pIdx, colIndex) = gamma / S;
                else
                    te.belief(pIdx, colIndex) = 0.5;
                    te.distrust(pIdx, colIndex) = 0.5;
                    te.uncertainty(pIdx, colIndex) = 0;
                end

                te.isActive(pIdx, colIndex) = d.isActive;
                te.isWarning(pIdx, colIndex) = getFieldOr(d, 'isWarning', false);
                % Governance state for blackout-cause attribution. Captured
                % AFTER any state transitions in this run, so a row showing
                % warningStreak >= warnEscalationRuns AND isActive=false in
                % the same column = streak escalation just fired.
                te.warningStreak(pIdx, colIndex)   = getFieldOr(d, 'warningStreak', 0);
                te.blackoutCounter(pIdx, colIndex) = getFieldOr(d, 'blackoutCounter', 0);
                te.totalBlacklists(pIdx, colIndex) = getFieldOr(d, 'totalBlacklists', 0);
                % Cumulative recommendation impact (Option A)
                te.rec_calls(pIdx, colIndex)    = getFieldOr(d, 'rec_calls', 0);
                te.rec_sum_lift(pIdx, colIndex) = getFieldOr(d, 'rec_sum_lift', 0);
                te.rec_sum_absl(pIdx, colIndex) = getFieldOr(d, 'rec_sum_absl', 0);
            end
        end
    end
end

function te = markProviderSelected(te, pid, colIndex)
%MARKPROVIDERSELECTED Mark a provider as selected in the wasSelected matrix
    if te.pidToIndex.isKey(pid)
        pIdx = te.pidToIndex(pid);
        te.wasSelected(pIdx, colIndex) = true;
    end
end

% decrementBlackoutCounters() was removed on 2026-05-30 along with its
% only call site (former line 319). The freeze double-decrement bug it
% caused is documented in the forensics commit c0a5542 and in
% src/support/diagnosticHelpers.m. Decrement now happens exactly once
% per simulation step, partitioned between fetchCandidatePool.m:80 (for
% sampled providers) and simulationUtils.m:117 (for non-sampled
% providers). Together they cover the full blockchain in a single pass
% with no overlap.
