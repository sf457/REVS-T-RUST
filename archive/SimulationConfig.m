classdef SimulationConfig
    %SIMULATIONCONFIG Centralized configuration for REVS-RUST simulation parameters
    %   This class provides a single point of control for all tunable parameters
    %   in the vehicular edge computing simulation framework.
    %
    %   Usage:
    %       config = SimulationConfig();           % Default configuration
    %       config = SimulationConfig('preset', 'aggressive');  % Use preset
    %       config.reputation.R_min = 0.35;        % Modify specific parameter
    %       config.validate();                     % Validate all parameters
    %
    %   Author: REVS-RUST Team
    %   Version: 1.0

    properties
        %% ==================== SIMULATION CONTROL ====================
        simulation = struct(...
            'numSimulations', 1000, ...          % Number of simulation iterations per seed
            'numSeeds', 10, ...                  % Number of Monte Carlo runs (seeds)
            'maliciousPercentages', [0.0, 0.1, 0.3, 0.5], ... % Malicious vehicle ratios to test
            'randomSeed', 42, ...                % Base random seed for reproducibility
            'enableParallel', false, ...         % Enable parallel computing
            'saveIntermediateResults', true, ... % Save results after each seed
            'verboseOutput', true ...            % Enable detailed console output
        );

        %% ==================== VEHICLE POOL ====================
        vehiclePool = struct(...
            'numRequesters', 30, ...             % Number of requester vehicles
            'numProviders', 70, ...              % Number of provider vehicles
            'numVehicles_min', 10, ...           % Minimum subset size per simulation
            'numVehicles_max', 30, ...           % Maximum subset size per simulation
            'fixedReputationValue', 0.6 ...      % Fixed reputation value for fixed scenario
        );

        %% ==================== TRUST LEVEL DISTRIBUTION ====================
        trustDistribution = struct(...
            'levels', {{'high', 'intermediate', 'low'}}, ... % Trust level names
            'probabilities', [0.4, 0.5, 0.1], ...            % Distribution probabilities
            'initialAlpha', struct('high', 3, 'intermediate', 2, 'low', 1), ... % Belief params
            'initialBeta', struct('high', 2, 'intermediate', 2, 'low', 2), ...  % Distrust params
            'initialGamma', struct('high', 1, 'intermediate', 2, 'low', 3) ...  % Uncertainty params
        );

        %% ==================== REPUTATION SYSTEM ====================
        reputation = struct(... % Reputation system parameters
            'R_min', 0.40, ...           % Blacklist threshold (reputation < R_min)
            'R_warn', 0.50, ...          % Warning threshold (R_min <= rep < R_warn)
            'R_boost', 0.60, ...         % Reward threshold (reputation >= R_boost)
            'rewardBoost', 0.05, ...     % Reputation boost for high performers
            'penaltyFreezeRuns', 3, ...  % Number of runs to freeze blacklisted vehicles
            'maxWarningStreak', 3, ...   % Consecutive warnings before escalation
            'zeta', 0.6, ...             % Timeline weight: recent interactions
            'sigma', 0.4, ...            % Timeline weight: past interactions (1 - zeta)
            'theta', 0.3, ...            % Effect weight: positive interactions
            'tau', 0.7, ...              % Effect weight: negative interactions (1 - theta)
            'rho', 0.5, ...              % Recommended opinion fusion weight
            'H_threshold', 0.5, ...      % Honesty classification threshold
            'honestySuccess', struct('high', 1.0, 'intermediate', 0.7, 'low', 0.5), ...
            'honestyFailure', struct('high', 0.4, 'intermediate', 0.3, 'low', 0.2), ...
            'I_high_threshold', 0.6, ... % Above this -> alpha increment
            'I_low_threshold', 0.3, ...  % Below this -> beta increment
            'honestyWeight', 0.4, ...    % Weight for honesty in trustworthiness
            'efficiencyWeight', 0.6, ... % Weight for task efficiency
            'enableDecay', false, ...    % Enable temporal decay of trust parameters
            'decayFactor', 0.95, ...     % Decay factor per interaction
            'fusionMethod', 'cumulative', ... % 'cumulative' or 'averaging'
            'fusionEpsilon', 1e-6 ...    % Epsilon for numerical stability
        );

        %% ==================== DYNAMIC BASE RATE (Jøsang) ====================
        baseRate = struct(... % Dynamic base rate (Josang) parameters
            'weights', struct('history', 0.4, 'social', 0.3, 'experience', 0.2, 'trend', 0.1), ...
            'socialPrior', struct('high', 0.7, 'intermediate', 0.5, 'low', 0.3), ...
            'experienceLambda', 10, ...  % Saturation rate for experience factor
            'recentWindow', 5, ...       % Number of recent runs for trend
            'minValue', 0.1, ...         % Minimum base rate
            'maxValue', 0.9 ...          % Maximum base rate
        );

        %% ==================== PROVIDER SELECTION ====================
        selection = struct(...
            'w1', 0.7, ...               % Weight for reputation in trust score
            'w2', 0.3, ...               % Weight for stay-time in trust score (1 - w1)
            'minReputationThreshold', 0.4 ... % Minimum reputation to be considered
        );

        %% ==================== MALICIOUS BEHAVIOR ====================
        malicious = struct(... % Malicious behavior parameters
            'probabilities', struct('high', 0.1, 'intermediate', 0.3, 'low', 0.6), ...
            'computationCapacityFactor', 0.5, ...  % Multiply capacity by this factor
            'transmissionRateFactor', 0.7 ...      % Multiply transmission rate by this factor
        );

        %% ==================== VEHICLE PROPERTIES ====================
        vehicle = struct(... % Vehicle property parameters
            'computationCapacity', 10e9, ...   % Default computation capacity (10 GHz)
            'transmissionRate', 86e6, ...      % Default transmission rate (86 Mbps)
            'communicationRadius', 250, ...    % Communication range in meters
            'baseSpeed', 60, ...               % Base speed in km/h
            'speedStdDev', 10, ...             % Speed standard deviation
            'speedAdjustmentRange', [5, 10], ... % Provider speed adjustment range
            'laneOffset', 7.5, ...             % Y-offset for opposite direction
            'xPositionRange', [-30, 30] ...    % X-position range relative to requester
        );

        %% ==================== TASK GENERATION ====================
        task = struct(... % Task generation parameters
            'inputDataSizeRange', [50, 500], ...    % Input data size range in KB
            'cpuCycleRange', [0.2e9, 3.2e9], ...   % CPU cycles required range
            'numTaskTypes', 5, ...                  % Number of different task types
            'CPUFrequency', 5e9, ...                % Reference CPU frequency (5 GHz)
            'servicePriceRange', [50, 200] ...      % Service price range
        );

        %% ==================== V2V OFFLOADING COST ====================
        offloading = struct(...
            'psiV2V', 0.5, ...            % Transmission time cost coefficient
            'etaV2V', 1.0 ...             % Execution time cost coefficient
        );

        %% ==================== FILE PATHS ====================
        files = struct(...
            'blockchainPrefix', 'blockchain_data_', ...
            'interactionPrefix', 'interaction_data_', ...
            'basePoolPrefix', 'base_pool_', ...
            'resultsPrefix', 'results_', ...
            'summaryPrefix', 'allResults_' ...
        );
    end

    methods
        function obj = SimulationConfig(varargin)
            %SIMULATIONCONFIG Constructor with optional preset configuration
            %   config = SimulationConfig()
            %   config = SimulationConfig('preset', 'conservative')
            %   config = SimulationConfig('preset', 'aggressive')
            %   config = SimulationConfig('preset', 'balanced')

            if nargin > 0
                p = inputParser;
                addParameter(p, 'preset', 'default', @ischar);
                parse(p, varargin{:});

                switch lower(p.Results.preset)
                    case 'conservative'
                        obj = obj.applyConservativePreset();
                    case 'aggressive'
                        obj = obj.applyAggressivePreset();
                    case 'balanced'
                        obj = obj.applyBalancedPreset();
                    case 'fast_test'
                        obj = obj.applyFastTestPreset();
                    case 'default'
                        % Use default values
                    otherwise
                        warning('Unknown preset: %s. Using default values.', p.Results.preset);
                end
            end
        end

        function obj = applyConservativePreset(obj)
            %APPLYCONSERVATIVEPRESET More strict reputation thresholds
            obj.reputation.R_min = 0.45;
            obj.reputation.R_warn = 0.55;
            obj.reputation.R_boost = 0.65;
            obj.reputation.rewardBoost = 0.03;
            obj.reputation.maxWarningStreak = 2;
            obj.selection.minReputationThreshold = 0.45;
        end

        function obj = applyAggressivePreset(obj)
            %APPLYAGGRESSIVEPRESET More lenient reputation thresholds
            obj.reputation.R_min = 0.35;
            obj.reputation.R_warn = 0.45;
            obj.reputation.R_boost = 0.55;
            obj.reputation.rewardBoost = 0.08;
            obj.reputation.maxWarningStreak = 4;
            obj.selection.minReputationThreshold = 0.35;
        end

        function obj = applyBalancedPreset(obj)
            %APPLYBALANCEDPRESET Balanced configuration (same as default)
            % Default values are already balanced
        end

        function obj = applyFastTestPreset(obj)
            %APPLYFASTTESTPRESET Quick testing configuration
            obj.simulation.numSimulations = 100;
            obj.simulation.numSeeds = 3;
            obj.simulation.maliciousPercentages = [0.0, 0.3];
            obj.vehiclePool.numRequesters = 10;
            obj.vehiclePool.numProviders = 20;
        end

        function [isValid, errors] = validate(obj)
            %VALIDATE Validate all configuration parameters
            %   [isValid, errors] = config.validate()
            %   Returns true if valid, false otherwise with error messages

            errors = {};

            % Simulation validation
            if obj.simulation.numSimulations < 1
                errors{end+1} = 'numSimulations must be >= 1';
            end
            if obj.simulation.numSeeds < 1
                errors{end+1} = 'numSeeds must be >= 1';
            end
            if any(obj.simulation.maliciousPercentages < 0) || any(obj.simulation.maliciousPercentages > 1)
                errors{end+1} = 'maliciousPercentages must be in [0, 1]';
            end

            % Vehicle pool validation
            if obj.vehiclePool.numRequesters < 1
                errors{end+1} = 'numRequesters must be >= 1';
            end
            if obj.vehiclePool.numProviders < 1
                errors{end+1} = 'numProviders must be >= 1';
            end
            if obj.vehiclePool.numVehicles_min > obj.vehiclePool.numVehicles_max
                errors{end+1} = 'numVehicles_min must be <= numVehicles_max';
            end

            % Trust distribution validation
            if abs(sum(obj.trustDistribution.probabilities) - 1.0) > 1e-6
                errors{end+1} = 'Trust distribution probabilities must sum to 1.0';
            end

            % Reputation validation
            if obj.reputation.R_min >= obj.reputation.R_warn
                errors{end+1} = 'R_min must be < R_warn';
            end
            if obj.reputation.R_warn >= obj.reputation.R_boost
                errors{end+1} = 'R_warn must be < R_boost';
            end
            if obj.reputation.R_min < 0 || obj.reputation.R_boost > 1
                errors{end+1} = 'Reputation thresholds must be in [0, 1]';
            end
            if abs(obj.reputation.zeta + obj.reputation.sigma - 1.0) > 1e-6
                errors{end+1} = 'zeta + sigma must equal 1.0';
            end
            if abs(obj.reputation.theta + obj.reputation.tau - 1.0) > 1e-6
                errors{end+1} = 'theta + tau must equal 1.0';
            end

            % Selection validation
            if abs(obj.selection.w1 + obj.selection.w2 - 1.0) > 1e-6
                errors{end+1} = 'w1 + w2 must equal 1.0';
            end

            % Malicious validation
            malProbs = [obj.malicious.probabilities.high, ...
                        obj.malicious.probabilities.intermediate, ...
                        obj.malicious.probabilities.low];
            if any(malProbs < 0) || any(malProbs > 1)
                errors{end+1} = 'Malicious probabilities must be in [0, 1]';
            end
            if obj.malicious.computationCapacityFactor <= 0 || obj.malicious.computationCapacityFactor > 1
                errors{end+1} = 'computationCapacityFactor must be in (0, 1]';
            end
            if obj.malicious.transmissionRateFactor <= 0 || obj.malicious.transmissionRateFactor > 1
                errors{end+1} = 'transmissionRateFactor must be in (0, 1]';
            end

            % Vehicle validation
            if obj.vehicle.computationCapacity <= 0
                errors{end+1} = 'computationCapacity must be > 0';
            end
            if obj.vehicle.transmissionRate <= 0
                errors{end+1} = 'transmissionRate must be > 0';
            end
            if obj.vehicle.communicationRadius <= 0
                errors{end+1} = 'communicationRadius must be > 0';
            end

            % Task validation
            if obj.task.inputDataSizeRange(1) > obj.task.inputDataSizeRange(2)
                errors{end+1} = 'inputDataSizeRange(1) must be <= inputDataSizeRange(2)';
            end
            if obj.task.cpuCycleRange(1) > obj.task.cpuCycleRange(2)
                errors{end+1} = 'cpuCycleRange(1) must be <= cpuCycleRange(2)';
            end

            % Base rate validation
            baseRateWeights = obj.baseRate.weights.history + obj.baseRate.weights.social + ...
                              obj.baseRate.weights.experience + obj.baseRate.weights.trend;
            if abs(baseRateWeights - 1.0) > 1e-6
                errors{end+1} = 'Base rate weights must sum to 1.0';
            end
            if obj.baseRate.minValue >= obj.baseRate.maxValue
                errors{end+1} = 'baseRate.minValue must be < baseRate.maxValue';
            end
            if obj.baseRate.minValue < 0 || obj.baseRate.maxValue > 1
                errors{end+1} = 'Base rate bounds must be in [0, 1]';
            end
            if obj.baseRate.experienceLambda <= 0
                errors{end+1} = 'experienceLambda must be > 0';
            end

            isValid = isempty(errors);

            if ~isValid && nargout < 2
                fprintf('Configuration validation failed:\n');
                for i = 1:length(errors)
                    fprintf('  - %s\n', errors{i});
                end
            end
        end

        function summary = getSummary(obj)
            %GETSUMMARY Get a summary string of key parameters
            summary = sprintf([...
                '=== REVS-RUST Configuration Summary ===\n' ...
                'Simulation: %d iterations x %d seeds\n' ...
                'Vehicles: %d requesters, %d providers\n' ...
                'Malicious %%: %s\n' ...
                'Trust Distribution: High=%.0f%%, Mid=%.0f%%, Low=%.0f%%\n' ...
                'Reputation Thresholds: R_min=%.2f, R_warn=%.2f, R_boost=%.2f\n' ...
                'Selection Weights: w1=%.2f (rep), w2=%.2f (stay)\n' ...
                'Malicious Probabilities: High=%.1f, Mid=%.1f, Low=%.1f\n' ...
                'Base Rate Weights: hist=%.1f, social=%.1f, exp=%.1f, trend=%.1f\n' ...
                'Base Rate Priors: High=%.2f, Mid=%.2f, Low=%.2f\n' ...
                'Fusion Method: %s\n' ...
                '========================================\n'], ...
                obj.simulation.numSimulations, obj.simulation.numSeeds, ...
                obj.vehiclePool.numRequesters, obj.vehiclePool.numProviders, ...
                mat2str(obj.simulation.maliciousPercentages * 100), ...
                obj.trustDistribution.probabilities(1) * 100, ...
                obj.trustDistribution.probabilities(2) * 100, ...
                obj.trustDistribution.probabilities(3) * 100, ...
                obj.reputation.R_min, obj.reputation.R_warn, obj.reputation.R_boost, ...
                obj.selection.w1, obj.selection.w2, ...
                obj.malicious.probabilities.high, ...
                obj.malicious.probabilities.intermediate, ...
                obj.malicious.probabilities.low, ...
                obj.baseRate.weights.history, obj.baseRate.weights.social, ...
                obj.baseRate.weights.experience, obj.baseRate.weights.trend, ...
                obj.baseRate.socialPrior.high, obj.baseRate.socialPrior.intermediate, ...
                obj.baseRate.socialPrior.low, ...
                obj.reputation.fusionMethod);
        end

        function disp(obj)
            %DISP Display configuration summary
            fprintf('%s', obj.getSummary());
        end

        function saveConfig(obj, filename)
            %SAVECONFIG Save configuration to a MAT file
            if nargin < 2
                filename = sprintf('config_%s.mat', datestr(now, 'yyyymmdd_HHMMSS'));
            end
            config = obj; %#ok<NASGU>
            save(filename, 'config');
            fprintf('Configuration saved to %s\n', filename);
        end

        function obj = loadConfig(obj, filename)
            %LOADCONFIG Load configuration from a MAT file
            data = load(filename);
            if isfield(data, 'config')
                obj = data.config;
                fprintf('Configuration loaded from %s\n', filename);
            else
                error('File does not contain a valid configuration');
            end
        end

        function configStruct = toStruct(obj)
            %TOSTRUCT Convert configuration to a flat structure for easy access
            configStruct = struct();
            configStruct.simulation = obj.simulation;
            configStruct.vehiclePool = obj.vehiclePool;
            configStruct.trustDistribution = obj.trustDistribution;
            configStruct.reputation = obj.reputation;
            configStruct.selection = obj.selection;
            configStruct.malicious = obj.malicious;
            configStruct.vehicle = obj.vehicle;
            configStruct.task = obj.task;
            configStruct.offloading = obj.offloading;
            configStruct.files = obj.files;
        end

        function exportToCSV(obj, filename)
            %EXPORTTOCSV Export key parameters to CSV for documentation
            if nargin < 2
                filename = sprintf('config_export_%s.csv', datestr(now, 'yyyymmdd'));
            end

            fid = fopen(filename, 'w');
            fprintf(fid, 'Category,Parameter,Value,Description\n');

            % Simulation parameters
            fprintf(fid, 'Simulation,numSimulations,%d,Number of simulation iterations\n', obj.simulation.numSimulations);
            fprintf(fid, 'Simulation,numSeeds,%d,Number of Monte Carlo seeds\n', obj.simulation.numSeeds);
            fprintf(fid, 'Simulation,maliciousPercentages,"%s",Malicious ratios to test\n', mat2str(obj.simulation.maliciousPercentages));

            % Vehicle pool
            fprintf(fid, 'VehiclePool,numRequesters,%d,Number of requester vehicles\n', obj.vehiclePool.numRequesters);
            fprintf(fid, 'VehiclePool,numProviders,%d,Number of provider vehicles\n', obj.vehiclePool.numProviders);
            fprintf(fid, 'VehiclePool,fixedReputationValue,%.2f,Fixed reputation for fixed scenario\n', obj.vehiclePool.fixedReputationValue);

            % Reputation
            fprintf(fid, 'Reputation,R_min,%.2f,Blacklist threshold\n', obj.reputation.R_min);
            fprintf(fid, 'Reputation,R_warn,%.2f,Warning threshold\n', obj.reputation.R_warn);
            fprintf(fid, 'Reputation,R_boost,%.2f,Reward threshold\n', obj.reputation.R_boost);
            fprintf(fid, 'Reputation,rewardBoost,%.2f,Reputation boost amount\n', obj.reputation.rewardBoost);
            fprintf(fid, 'Reputation,zeta,%.2f,Timeline weight (recent)\n', obj.reputation.zeta);
            fprintf(fid, 'Reputation,rho,%.2f,Recommended opinion weight\n', obj.reputation.rho);

            % Selection
            fprintf(fid, 'Selection,w1,%.2f,Reputation weight\n', obj.selection.w1);
            fprintf(fid, 'Selection,w2,%.2f,Stay-time weight\n', obj.selection.w2);

            % Malicious
            fprintf(fid, 'Malicious,prob_high,%.2f,Malicious probability (high trust)\n', obj.malicious.probabilities.high);
            fprintf(fid, 'Malicious,prob_intermediate,%.2f,Malicious probability (intermediate trust)\n', obj.malicious.probabilities.intermediate);
            fprintf(fid, 'Malicious,prob_low,%.2f,Malicious probability (low trust)\n', obj.malicious.probabilities.low);

            % Vehicle
            fprintf(fid, 'Vehicle,computationCapacity,%.2e,Computation capacity (Hz)\n', obj.vehicle.computationCapacity);
            fprintf(fid, 'Vehicle,transmissionRate,%.2e,Transmission rate (bps)\n', obj.vehicle.transmissionRate);
            fprintf(fid, 'Vehicle,communicationRadius,%d,Communication range (m)\n', obj.vehicle.communicationRadius);

            % Offloading
            fprintf(fid, 'Offloading,psiV2V,%.2f,Transmission cost coefficient\n', obj.offloading.psiV2V);
            fprintf(fid, 'Offloading,etaV2V,%.2f,Execution cost coefficient\n', obj.offloading.etaV2V);

            fclose(fid);
            fprintf('Configuration exported to %s\n', filename);
        end
    end

    methods (Static)
        function config = fromFile(filename)
            %FROMFILE Create configuration from a MAT file
            data = load(filename);
            if isfield(data, 'config')
                config = data.config;
            else
                error('File does not contain a valid configuration');
            end
        end

        function printParameterRanges()
            %PRINTPARAMETERRANGES Print recommended parameter ranges for tuning
            fprintf('\n=== Recommended Parameter Ranges for Tuning ===\n\n');

            fprintf('REPUTATION THRESHOLDS:\n');
            fprintf('  R_min:        [0.30, 0.50]  (Blacklist threshold)\n');
            fprintf('  R_warn:       [0.40, 0.60]  (Warning threshold)\n');
            fprintf('  R_boost:      [0.50, 0.70]  (Reward threshold)\n');
            fprintf('  rewardBoost:  [0.02, 0.10]  (Reputation increment)\n\n');

            fprintf('OPINION WEIGHTS:\n');
            fprintf('  zeta:         [0.4, 0.8]   (Recent interaction weight)\n');
            fprintf('  rho:          [0.3, 0.7]   (Recommended opinion weight)\n');
            fprintf('  theta:        [0.2, 0.5]   (Positive effect weight)\n\n');

            fprintf('SELECTION WEIGHTS:\n');
            fprintf('  w1:           [0.5, 0.9]   (Reputation weight)\n');
            fprintf('  w2:           [0.1, 0.5]   (Stay-time weight)\n\n');

            fprintf('MALICIOUS PROBABILITIES:\n');
            fprintf('  high:         [0.05, 0.20] (High trust tier)\n');
            fprintf('  intermediate: [0.20, 0.40] (Intermediate trust tier)\n');
            fprintf('  low:          [0.50, 0.80] (Low trust tier)\n\n');

            fprintf('TRUST DISTRIBUTION:\n');
            fprintf('  high:         [0.20, 0.50] (High trust proportion)\n');
            fprintf('  intermediate: [0.30, 0.60] (Intermediate trust proportion)\n');
            fprintf('  low:          [0.05, 0.30] (Low trust proportion)\n\n');

            fprintf('================================================\n');
        end
    end
end
