function VProjOut = assignMaliciousConfigurable(Vproj, maliciousPercentage, VreqPool, configName)
% ASSIGNMALICIOUSCONFIGURABLE  Configurable malicious assignment strategies
%
% Supports multiple assignment configurations for fair comparison:
%
%   'xu_aligned'       - Xu et al. style (NO intermediate):
%                        Malicious → ST_low (100%)
%                        Honest → ST_high (100%)
%
%   'xu_preserve'      - Xu malicious + preserve honest:
%                        Malicious → ST_low (100%)
%                        Honest → PRESERVE original ST from VprojPool
%
%   'xu_with_intermediate' - Xu-style with intermediate:
%                        Malicious → [0% high, 10% int, 90% low]
%                        Honest → [90% high, 10% int, 0% low]
%
%   'rust_distributed' - RUST original: malicious distributed across tiers
%                        Malicious → [10% high, 30% int, 60% low]
%                        Honest → PRESERVE original ST from VprojPool
%
%   'uniform_random'   - Random ST assignment (uniform distribution)
%                        Both malicious/honest → [33%, 34%, 33%]
%                        (Baseline for ablation - no ST-malicious correlation)
%
%   'moderate'         - Less extreme than rust_distributed
%                        Malicious → [5% high, 15% int, 80% low]
%                        Honest → [60% high, 25% int, 15% low]
%
% Usage:
%   Vproj = assignMaliciousConfigurable(Vproj, 0.3, VreqPool, 'xu_aligned');
%
% Inputs:
%   Vproj              - Array of provider structs
%   maliciousPercentage - Fraction [0,1] of providers to be malicious
%   VreqPool           - Pool of requesters (for Offtransaction init)
%   configName         - Assignment configuration name (string)
%
% Outputs:
%   VProjOut - Updated provider array

    if nargin < 4
        configName = 'xu_aligned';  % Default to Xu et al. for baseline comparison
    end

    params = Params();
    numProviders = numel(Vproj);
    numMalicious = round(maliciousPercentage * numProviders);
    requesterPIDs = {VreqPool.PID};

    % Define assignment configurations
    % Format: struct with malicious ST distribution [high, intermediate, low]
    configs = struct();

    % Xu et al.: All malicious are ST_low, all honest are ST_high
    % NOTE: Eliminates intermediate - used for direct Xu et al. comparison only
    configs.xu_aligned = struct(...
        'maliciousDist', [0, 0, 1.0], ...     % 0% high, 0% intermediate, 100% low
        'honestDist', [1.0, 0, 0], ...        % 100% high, 0% intermediate, 0% low
        'description', 'Xu et al. aligned: malicious→ST_low, honest→ST_high (no intermediate)');

    % Xu-style malicious (all low) but preserve honest ST from pool
    configs.xu_preserve = struct(...
        'maliciousDist', [0, 0, 1.0], ...     % All malicious → ST_low
        'honestDist', 'preserve', ...         % Honest keep original ST from VprojPool
        'description', 'Xu malicious (all low), honest ST preserved from pool');

    % Xu with intermediate: malicious mostly low, honest mostly high, but uses intermediate
    configs.xu_with_intermediate = struct(...
        'maliciousDist', [0, 0.1, 0.9], ...   % 0% high, 10% intermediate, 90% low
        'honestDist', [0.9, 0.1, 0], ...      % 90% high, 10% intermediate, 0% low
        'description', 'Xu-style with 10% intermediate for both groups');

    % RUST distributed: malicious more likely to be low ST, honest keep original
    configs.rust_distributed = struct(...
        'maliciousDist', [0.1, 0.3, 0.6], ... % 10% high, 30% intermediate, 60% low
        'honestDist', 'preserve', ...         % Keep original ST from VprojPool
        'description', 'RUST distributed: malicious weighted, honest ST preserved');

    % Moderate: Less extreme than RUST
    configs.moderate = struct(...
        'maliciousDist', [0.05, 0.15, 0.8], ... % 5% high, 15% intermediate, 80% low
        'honestDist', [0.6, 0.25, 0.15], ...    % 60% high, 25% intermediate, 15% low
        'description', 'Moderate: malicious mostly ST_low, honest mostly ST_high');

    % Uniform random: No correlation between malicious and ST
    configs.uniform_random = struct(...
        'maliciousDist', [0.33, 0.34, 0.33], ... % Equal distribution
        'honestDist', [0.33, 0.34, 0.33], ...    % Equal distribution
        'description', 'Uniform random: no ST-malicious correlation (ablation)');

    % Inverse (adversarial): Malicious are high ST (worst case for detection)
    configs.adversarial = struct(...
        'maliciousDist', [0.6, 0.3, 0.1], ... % 60% high, 30% intermediate, 10% low
        'honestDist', [0.2, 0.3, 0.5], ...    % 20% high, 30% intermediate, 50% low
        'description', 'Adversarial: malicious weighted toward ST_high');

    % Get selected configuration
    if ~isfield(configs, configName)
        error('Unknown configName: %s. Valid options: %s', ...
            configName, strjoin(fieldnames(configs), ', '));
    end
    cfg = configs.(configName);

    % Log to file for persistent record
    logFile = fullfile(params.baseLogDir, 'assignment_summary.txt');
    if ~exist(params.baseLogDir, 'dir'), mkdir(params.baseLogDir); end
    fid = fopen(logFile, 'a');
    fprintf(fid, '[%s] %s - %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), upper(configName), cfg.description);
    fclose(fid);

    % Randomly select which providers are malicious
    allIdx = randperm(numProviders);
    maliciousIdx = allIdx(1:numMalicious);
    honestIdx = allIdx((numMalicious+1):end);

    % Assign ST levels based on configuration
    stLevels = {'high', 'intermediate', 'low'};

    % Assign malicious providers
    maliciousST = assignSTLevels(numel(maliciousIdx), cfg.maliciousDist, stLevels);
    for i = 1:numel(maliciousIdx)
        idx = maliciousIdx(i);
        Vproj(idx).isMalicious = true;
        Vproj(idx).socialTrustLevel = maliciousST{i};
    end

    % Assign honest providers
    if ischar(cfg.honestDist) && strcmp(cfg.honestDist, 'preserve')
        % Preserve original ST from VprojPool
        for i = 1:numel(honestIdx)
            idx = honestIdx(i);
            Vproj(idx).isMalicious = false;
            % socialTrustLevel already set from VprojPool - keep it
        end
    else
        % Force distribution
        honestST = assignSTLevels(numel(honestIdx), cfg.honestDist, stLevels);
        for i = 1:numel(honestIdx)
            idx = honestIdx(i);
            Vproj(idx).isMalicious = false;
            Vproj(idx).socialTrustLevel = honestST{i};
        end
    end

    % Initialize evidence based on ST level
    % NOTE: RUST dynamic priors = Xu et al. Eq. 18 (identical values)
    for i = 1:numProviders
        stLevel = Vproj(i).socialTrustLevel;

        % Get initial evidence (same for both RUST and Xu)
        [ini_alpha, ini_beta, ini_gamma] = getSTEvidence(stLevel);

        Vproj(i).ini_alpha = ini_alpha;
        Vproj(i).ini_beta = ini_beta;
        Vproj(i).ini_gamma = ini_gamma;

        % Calculate initial reputation
        S = ini_alpha + ini_beta + ini_gamma;
        ini_belief = ini_alpha / S;
        ini_distrust = ini_beta / S;
        ini_uncertainty = ini_gamma / S;

        Vproj(i).w_ij = [ini_belief; ini_distrust; ini_uncertainty];
        Vproj(i).reputation = ini_belief + params.a0 * ini_uncertainty;

        % Initialize Offtransaction
        Vproj(i).Offtransaction = initOfftx(requesterPIDs, ini_alpha, ini_beta, ini_gamma);
    end

    % Print summary
    printSummary(Vproj, configName);

    VProjOut = Vproj;
end

%% Helper Functions

function stAssignments = assignSTLevels(n, distribution, stLevels)
% Assign ST levels to n providers based on distribution
    if n == 0
        stAssignments = {};
        return;
    end

    % Calculate counts for each ST level
    counts = round(distribution * n);

    % Adjust for rounding errors
    diff = n - sum(counts);
    if diff > 0
        [~, maxIdx] = max(distribution);
        counts(maxIdx) = counts(maxIdx) + diff;
    elseif diff < 0
        [~, maxIdx] = max(counts);
        counts(maxIdx) = counts(maxIdx) + diff;
    end

    % Create assignment array
    stAssignments = cell(1, n);
    idx = 1;
    for level = 1:3
        for j = 1:counts(level)
            if idx <= n
                stAssignments{idx} = stLevels{level};
                idx = idx + 1;
            end
        end
    end

    % Shuffle to randomize order
    stAssignments = stAssignments(randperm(n));
end

function [alpha, beta, gamma] = getSTEvidence(stLevel)
% ST-based evidence initialization (RUST = Xu et al. Eq. 18)
% Both use identical values:
%   high:         {α=3, β=2, γ=1} → R₀=0.583
%   intermediate: {α=2, β=2, γ=2} → R₀=0.500
%   low:          {α=1, β=2, γ=3} → R₀=0.417
    switch lower(stLevel)
        case 'high'
            alpha = 3; beta = 2; gamma = 1;
        case 'intermediate'
            alpha = 2; beta = 2; gamma = 2;
        case 'low'
            alpha = 1; beta = 2; gamma = 3;
        otherwise
            alpha = 2; beta = 2; gamma = 2;
    end
end

function Offtx = initOfftx(requesterPIDs, alpha, beta, gamma)
% Initialize Offtransaction structure
    numTx = struct();
    numSuc = struct();
    numFail = struct();
    numA = struct();
    numB = struct();
    numG = struct();

    for i = 1:numel(requesterPIDs)
        id = requesterPIDs{i};
        numTx.(id) = 0;
        numSuc.(id) = 0;
        numFail.(id) = 0;
        numA.(id) = alpha;
        numB.(id) = beta;
        numG.(id) = gamma;
    end

    Offtx = struct('numTransactions', numTx, 'numSuccess', numSuc, ...
        'numFailed', numFail, 'numAlpha', numA, 'numBeta', numB, 'numGamma', numG);
end

function printSummary(Vproj, configName)
% Print assignment summary to log file for persistent record
    params = Params();
    logFile = fullfile(params.baseLogDir, 'assignment_summary.txt');
    if ~exist(params.baseLogDir, 'dir'), mkdir(params.baseLogDir); end
    fid = fopen(logFile, 'a');

    numProviders = numel(Vproj);
    numMal = sum([Vproj.isMalicious]);

    stLevels = {Vproj.socialTrustLevel};
    isMal = [Vproj.isMalicious];

    % Count by ST level and malicious status
    malHigh = sum(strcmp(stLevels, 'high') & isMal);
    malInt = sum(strcmp(stLevels, 'intermediate') & isMal);
    malLow = sum(strcmp(stLevels, 'low') & isMal);

    honHigh = sum(strcmp(stLevels, 'high') & ~isMal);
    honInt = sum(strcmp(stLevels, 'intermediate') & ~isMal);
    honLow = sum(strcmp(stLevels, 'low') & ~isMal);

    fprintf(fid, '\n  Assignment Summary (%s):\n', configName);
    fprintf(fid, '  +──────────────+────────+────────+────────+────────+\n');
    fprintf(fid, '  |              | ST_high| ST_int | ST_low | Total  |\n');
    fprintf(fid, '  +──────────────+────────+────────+────────+────────+\n');
    fprintf(fid, '  | Malicious    | %6d | %6d | %6d | %6d |\n', malHigh, malInt, malLow, numMal);
    fprintf(fid, '  | Honest       | %6d | %6d | %6d | %6d |\n', honHigh, honInt, honLow, numProviders - numMal);
    fprintf(fid, '  +──────────────+────────+────────+────────+────────+\n');
    fprintf(fid, '  | Total        | %6d | %6d | %6d | %6d |\n', ...
        malHigh + honHigh, malInt + honInt, malLow + honLow, numProviders);
    fprintf(fid, '  +──────────────+────────+────────+────────+────────+\n\n');

    fclose(fid);
end
