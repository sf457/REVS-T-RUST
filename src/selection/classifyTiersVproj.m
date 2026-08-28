% ---------------------------------------------------------------------------
% INACTIVE REFACTOR ("new selection trio"): NOT used for the frozen thesis
% results. Runs only when Params.useNewSelectionTrio = true (default = false).
% Kept for future consolidation of the selection pipeline. See docs/PROVENANCE.md.
% ---------------------------------------------------------------------------
function [activeMask, tierInfo] = classifyTiersVproj(CandidateVproj)
%CLASSIFYTIERSVPROJ  Classify pre-filtered candidates into priority tiers.
%
% Replaces filterAndSortCandidates (which despite its name, no longer sorts — it just
% filtered by sameDirection + R >= R_min, both of which are now in
% fetchVehicles2_clean).
%
% Output structure:
%   activeMask    : logical (1 x n) — providers selectable THIS round
%                   (= goodMask if any Good-tier, else warningMask)
%   tierInfo      : struct with all four masks (for logging / diagnostics):
%     .goodMask     : R > R_warn AND not shadowed  → Good-tier candidates
%     .warningMask  : R <= R_warn OR shadowed       → Warning-tier candidates
%     .shadowMask   : totalBlacklists > 0 (if Shadow on) → demoted candidates
%     .activeMask   : same as the returned activeMask (mirror)
%
% Only activeMask drives selection. The other masks are for visibility.
%
% Inputs:
%   CandidateVproj : from fetchVehicles2_clean — already filtered for
%                    sameRSU, isIdle, isActive, ~permaban, sameDirection,
%                    and R >= R_min. So we only need tier classification.

    p = Params();
    R_warn = p.R_warn;

    n = numel(CandidateVproj);
    if n == 0
        activeMask = false(1, 0);
        tierInfo = struct('goodMask', false(1,0), 'warningMask', false(1,0), ...
                          'shadowMask', false(1,0), 'activeMask', false(1,0));
        return;
    end

    reputations = [CandidateVproj.reputation];

    % --- Shadow demotion (opt-in via Params.useBlacklistShadow) ---
    % Providers with prior blackout history get demoted to Warning tier
    % regardless of their current R. They remain selectable but never get
    % Good-tier priority again.
    shadowMask = false(1, n);
    if isfield(p,'useBlacklistShadow') && p.useBlacklistShadow
        for i = 1:n
            if isfield(CandidateVproj(i), 'totalBlacklists') && ...
               ~isempty(CandidateVproj(i).totalBlacklists) && ...
               double(CandidateVproj(i).totalBlacklists) > 0
                shadowMask(i) = true;
            end
        end
    end

    % --- Tier classification ---
    % goodMask    : standard high-trust providers
    % warningMask : low-trust OR shadowed providers (fallback pool)
    goodMask    = (reputations > R_warn) & ~shadowMask;
    warningMask = (reputations <= R_warn) | shadowMask;

    % --- Strict tier preference: Good if any exist, else Warning fallback ---
    if any(goodMask)
        activeMask = goodMask;
    elseif any(warningMask)
        activeMask = warningMask;
    else
        activeMask = false(1, n);
    end

    tierInfo = struct('goodMask', goodMask, 'warningMask', warningMask, ...
                      'shadowMask', shadowMask, 'activeMask', activeMask);
end
