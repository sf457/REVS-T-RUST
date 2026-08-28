function [metrics] = computeSecondHalfMetrics(results, switchPoint)
% COMPUTESECONDHALFMETRICS Compute phase-specific metrics for first-half attacks
%
% The First-Half attack pattern means:
%   - Runs 1 to switchPoint: Malicious providers behave honestly
%   - Runs switchPoint+1 to end: Malicious providers attack
%
% Overall SR averages both phases, hiding true differences.
% This function computes separate metrics for each phase.
%
% Usage:
%   metrics = computeSecondHalfMetrics(results, 500);
%
% Inputs:
%   results     - struct with offSuccessStatus and SVproisMalicious arrays
%   switchPoint - when attack starts (default: half of total runs)
%
% Outputs:
%   metrics - struct with phase-specific SR and MAR

    % Determine total runs from results
    if isfield(results, 'offSuccessStatus')
        totalRuns = length(results.offSuccessStatus);
    else
        error('results must have offSuccessStatus field');
    end

    if nargin < 2 || isempty(switchPoint)
        switchPoint = floor(totalRuns / 2);
    end

    % Extract arrays
    successArr = results.offSuccessStatus;
    maliciousArr = results.SVproisMalicious;

    %% First Half (Honest Phase): runs 1 to switchPoint
    firstHalf_success = sum(successArr(1:switchPoint) == 1, 'omitnan');
    firstHalf_total = switchPoint;
    firstHalf_malSelected = sum(maliciousArr(1:switchPoint) == 1, 'omitnan');

    metrics.firstHalf_SR = (firstHalf_success / firstHalf_total) * 100;
    metrics.firstHalf_MAR = ((firstHalf_total - firstHalf_malSelected) / firstHalf_total) * 100;
    metrics.firstHalf_MalSelected = firstHalf_malSelected;

    %% Second Half (Attack Phase): runs switchPoint+1 to end
    secondHalf_success = sum(successArr(switchPoint+1:end) == 1, 'omitnan');
    secondHalf_total = totalRuns - switchPoint;
    secondHalf_malSelected = sum(maliciousArr(switchPoint+1:end) == 1, 'omitnan');

    metrics.secondHalf_SR = (secondHalf_success / secondHalf_total) * 100;
    metrics.secondHalf_MAR = ((secondHalf_total - secondHalf_malSelected) / secondHalf_total) * 100;
    metrics.secondHalf_MalSelected = secondHalf_malSelected;

    %% Overall (for verification)
    metrics.overall_SR = (sum(successArr == 1, 'omitnan') / totalRuns) * 100;
    metrics.overall_MAR = ((totalRuns - sum(maliciousArr == 1, 'omitnan')) / totalRuns) * 100;

    %% Additional: Drop in performance (attack impact)
    metrics.SR_drop = metrics.firstHalf_SR - metrics.secondHalf_SR;
    metrics.MAR_drop = metrics.firstHalf_MAR - metrics.secondHalf_MAR;

    %% Store metadata
    metrics.switchPoint = switchPoint;
    metrics.totalRuns = totalRuns;
end
