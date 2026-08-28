function [stalenessMetrics] = trackRecommendationStaleness(results, switchPoint, correctedRTD)
% TRACKRECOMMENDATIONSTALENESS Analyze how stale recommendations affect detection
%
% For First-Half attacks:
%   - Phase 1 (runs 1-switchPoint): Malicious behave honestly
%   - Phase 2 (runs switchPoint+1-end): Malicious attack
%
% Stale recommendations from Phase 1 persist into Phase 2, delaying detection.
% This function quantifies this "recommendation staleness" effect.
%
% Inputs:
%   results     - struct with simulation results including:
%                 - offSuccessStatus: success/failure per run
%                 - SVproisMalicious: whether selected provider was malicious
%                 - updatedReputation: reputation after each run
%                 - Optional: R_direct, R_recommended (if tracked)
%   switchPoint - when attack starts (default: 500)
%
% Outputs:
%   stalenessMetrics - struct with staleness analysis:
%     .avgRepGap_phase2      - Avg gap between R_recommended and R_direct in attack phase
%     .malDetectionDelay     - Runs until first malicious blacklisted in Phase 2
%     .malSelectedPhase1     - Count of malicious selected in honest phase
%     .malSelectedPhase2     - Count of malicious selected in attack phase
%     .malSelectedRatio      - Phase2/Phase1 ratio (>1 means more mal selected during attack)
%     .avgRepMalPhase1       - Avg reputation of malicious at end of Phase 1
%     .avgRepMalPhase2End    - Avg reputation of malicious at end of Phase 2
%     .repDropMalicious      - Reputation drop for malicious (Phase1End - Phase2End)
%     .runsToDetect50pct     - Runs in Phase 2 until 50% of malicious below R_warn

    if nargin < 2 || isempty(switchPoint)
        switchPoint = 500;
    end

    totalRuns = length(results.offSuccessStatus);
    stalenessMetrics = struct();

    %% Basic phase separation
    phase1_idx = 1:switchPoint;
    phase2_idx = (switchPoint+1):totalRuns;

    %% Malicious selection per phase
    malSelected = results.SVproisMalicious == 1;

    stalenessMetrics.malSelectedPhase1 = sum(malSelected(phase1_idx), 'omitnan');
    stalenessMetrics.malSelectedPhase2 = sum(malSelected(phase2_idx), 'omitnan');

    if stalenessMetrics.malSelectedPhase1 > 0
        stalenessMetrics.malSelectedRatio = stalenessMetrics.malSelectedPhase2 / stalenessMetrics.malSelectedPhase1;
    else
        stalenessMetrics.malSelectedRatio = NaN;
    end

    %% Success rate per phase when malicious selected
    malSelected_phase1 = malSelected(phase1_idx);
    malSelected_phase2 = malSelected(phase2_idx);
    success_phase1 = results.offSuccessStatus(phase1_idx);
    success_phase2 = results.offSuccessStatus(phase2_idx);

    % Success rate when malicious was selected (should be high in Phase 1, low in Phase 2)
    if sum(malSelected_phase1) > 0
        stalenessMetrics.malSuccessRate_phase1 = sum(success_phase1(malSelected_phase1) == 1) / sum(malSelected_phase1) * 100;
    else
        stalenessMetrics.malSuccessRate_phase1 = NaN;
    end

    if sum(malSelected_phase2) > 0
        stalenessMetrics.malSuccessRate_phase2 = sum(success_phase2(malSelected_phase2) == 1) / sum(malSelected_phase2) * 100;
    else
        stalenessMetrics.malSuccessRate_phase2 = NaN;
    end

    %% Reputation tracking (if available)
    if isfield(results, 'updatedReputation')
        rep = results.updatedReputation;

        % Average reputation when malicious selected
        if sum(malSelected_phase1) > 0
            stalenessMetrics.avgRepMal_phase1 = mean(rep(phase1_idx(malSelected_phase1)), 'omitnan');
        else
            stalenessMetrics.avgRepMal_phase1 = NaN;
        end

        if sum(malSelected_phase2) > 0
            stalenessMetrics.avgRepMal_phase2 = mean(rep(phase2_idx(malSelected_phase2)), 'omitnan');
        else
            stalenessMetrics.avgRepMal_phase2 = NaN;
        end

        % Reputation drop for malicious
        stalenessMetrics.repDropMal = stalenessMetrics.avgRepMal_phase1 - stalenessMetrics.avgRepMal_phase2;
    end

    %% Detection delay analysis
    % How many runs into Phase 2 until malicious avoidance improves?
    if isfield(results, 'SVproisMalicious')
        % Calculate rolling MAR in Phase 2
        windowSize = 50;  % 50-run sliding window
        phase2_mal = malSelected(phase2_idx);

        rollingMAR = zeros(1, length(phase2_mal) - windowSize + 1);
        for i = 1:length(rollingMAR)
            windowMal = phase2_mal(i:i+windowSize-1);
            rollingMAR(i) = (1 - mean(windowMal, 'omitnan')) * 100;
        end

        % Find when MAR exceeds 70% (detection threshold)
        detectionThreshold = 70;
        detectionIdx = find(rollingMAR >= detectionThreshold, 1, 'first');

        if ~isempty(detectionIdx)
            stalenessMetrics.runsToDetect = detectionIdx + windowSize/2;  % Center of window
        else
            stalenessMetrics.runsToDetect = NaN;  % Never reached threshold
        end

        % Initial MAR in Phase 2 (first 100 runs)
        stalenessMetrics.initialMAR_phase2 = (1 - mean(phase2_mal(1:min(100, length(phase2_mal))), 'omitnan')) * 100;

        % Final MAR in Phase 2 (last 100 runs)
        stalenessMetrics.finalMAR_phase2 = (1 - mean(phase2_mal(max(1,end-99):end), 'omitnan')) * 100;

        % MAR improvement during Phase 2
        stalenessMetrics.MARimprovement_phase2 = stalenessMetrics.finalMAR_phase2 - stalenessMetrics.initialMAR_phase2;
    end

    %% Direct vs Recommended reputation gap (if tracked)
    if isfield(results, 'R_direct') && isfield(results, 'R_recommended')
        R_direct = results.R_direct;
        R_rec = results.R_recommended;

        % Gap in Phase 2 (positive = recommendations inflating reputation)
        gap_phase2 = R_rec(phase2_idx) - R_direct(phase2_idx);
        stalenessMetrics.avgRepGap_phase2 = mean(gap_phase2(malSelected_phase2), 'omitnan');
        stalenessMetrics.maxRepGap_phase2 = max(gap_phase2(malSelected_phase2));

        % Gap over time in Phase 2
        stalenessMetrics.gapDecayRate = NaN;  % Could fit exponential decay
    else
        stalenessMetrics.avgRepGap_phase2 = NaN;
        stalenessMetrics.maxRepGap_phase2 = NaN;
    end

    %% Staleness score (composite metric)
    % Uses corrected per-provider RTD if provided, else internal rolling-MAR RTD
    if nargin >= 3 && ~isnan(correctedRTD)
        rtdForScore = correctedRTD;
    else
        rtdForScore = stalenessMetrics.runsToDetect;
    end

    if ~isnan(stalenessMetrics.malSelectedRatio) && ...
       ~isnan(stalenessMetrics.MARimprovement_phase2) && ...
       ~isnan(rtdForScore)

        ratioScore = min(stalenessMetrics.malSelectedRatio, 2) / 2;
        delayScore = min(rtdForScore, 250) / 250;
        improvementScore = stalenessMetrics.MARimprovement_phase2 / 50;

        stalenessMetrics.stalenessScore = (ratioScore + delayScore + improvementScore) / 3 * 100;
    else
        stalenessMetrics.stalenessScore = NaN;
    end

    %% Store metadata
    stalenessMetrics.switchPoint = switchPoint;
    stalenessMetrics.totalRuns = totalRuns;
end
