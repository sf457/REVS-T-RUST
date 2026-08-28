% ---------------------------------------------------------------------------
% INACTIVE REFACTOR ("new selection trio"): NOT used for the frozen thesis
% results. Runs only when Params.useNewSelectionTrio = true (default = false).
% Kept for future consolidation of the selection pipeline. See docs/PROVENANCE.md.
% ---------------------------------------------------------------------------
function [CandidateVproj, numProviders, numRequesters, VprojBlockchainset] = ...
    fetchVehicles2_clean(VprojBlockchainset, Vreqi)
%FETCHVEHICLES2_CLEAN  Single-pass candidate filtering for selection.
%
% Refactored version of fetchCandidatePool.m that applies ALL feasibility
% filters in one place. Currently a SAFE DROP-IN ALTERNATIVE to
% fetchCandidatePool + filterAndSortCandidates — produces the same candidate set, just
% with cleaner code organization.
%
% Behavior change from fetchCandidatePool:
%   - direction filter ('Same direction') moved here from filterAndSortCandidates
%   - R >= R_min filter moved here from filterAndSortCandidates/SelectedVproj2_*
%     (both downstream functions still re-check; they are no-ops now)
%   - explicit isPermanentlyBlacklisted check (was implicit via isActive)
%
% NOT changed:
%   - blackout-counter decrement logic (Site 1) — unchanged
%   - candidate appending pattern — unchanged
%   - return signature — same as fetchCandidatePool
%
% Inputs:
%   VprojBlockchainset : array of provider blocks (chain entries with .data)
%   Vreqi              : requester struct
%
% Outputs:
%   CandidateVproj      : array of eligible candidate vData structs
%   numProviders        : numel(CandidateVproj)
%   numRequesters       : length(Vreqi)
%   VprojBlockchainset  : updated chain (decremented blackout counters)

    p = Params();
    R_min = p.R_min;
    CandidateVproj = [];

    for n = 1:length(VprojBlockchainset)
        vData = VprojBlockchainset(n).data;

        % Ensure isPermanentlyBlacklisted field exists with correct type
        if ~isfield(vData,'isPermanentlyBlacklisted') || ~islogical(vData.isPermanentlyBlacklisted)
            vData.isPermanentlyBlacklisted = false;
        end

        % --- Site 1: blackout-counter decrement for sampled providers ---
        wasInBlackout = false;
        if vData.blackoutCounter > 0
            wasInBlackout = true;
            if ~isinf(vData.blackoutCounter)
                vData.blackoutCounter = vData.blackoutCounter - 1;
                if vData.blackoutCounter == 0
                    vData.isActive = true;
                    vData.isWarning = true;
                    vData.warningStreak = 1;
                end
            end
        end
        VprojBlockchainset(n).data = vData;       % persist change

        if wasInBlackout, continue; end           % skip this round even if just freed

        % --- All eligibility filters (single pass, single source of truth) ---
        if vData.isPermanentlyBlacklisted,                continue; end
        if isfield(vData,'isActive') && ~vData.isActive,  continue; end
        if vData.RSU_ID ~= Vreqi.RSU_ID,                  continue; end
        if vData.resourceStatus ~= 1,                     continue; end
        if ~strcmp(vData.direction, 'Same direction'),    continue; end
        if vData.reputation < R_min,                      continue; end

        % --- Eligible — append to candidate list (preserve field-alignment behavior) ---
        if isempty(CandidateVproj)
            CandidateVproj = vData;
        else
            existFields    = fieldnames(CandidateVproj);
            newFields      = fieldnames(vData);
            missingInNew   = setdiff(existFields, newFields);
            missingInExist = setdiff(newFields, existFields);
            for mf = missingInNew'
                vData.(mf{1}) = struct();
            end
            for mf = missingInExist'
                for ci = 1:numel(CandidateVproj)
                    CandidateVproj(ci).(mf{1}) = struct();
                end
            end
            CandidateVproj = [CandidateVproj, vData];
        end
    end

    numProviders  = numel(CandidateVproj);
    numRequesters = length(Vreqi);
end
