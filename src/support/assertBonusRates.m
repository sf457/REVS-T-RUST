function assertBonusRates(expectDC, expectDE)
%ASSERTBONUSRATES  Verify the live DH bonus rates on the client AND every worker.
%
%   assertBonusRates(expectDC, expectDE) aborts (errors) unless the live
%   consistency/experience bonus rates equal expectDC/expectDE — checked on the
%   MATLAB client AND on every open parallel-pool worker.
%
%   Why this exists: the firsthalf betrayal "P2Sel=0 / SecondHalf_MAR=100 / RTB=NaN"
%   bug was caused by parpool WORKERS running a stale cached rate (0.15/0.10) while
%   the client read the correct value (0.05/0.02) from Params.m. A client-only check
%   could not see that. This guard clears the cached Params on the CLIENT (forcing a
%   fresh read from Params.m) and READS Params() on every worker. A freshly started
%   pool loads Params.m from disk, so its workers report the file value; a stale pool
%   reports its cached value and is caught by the assert (fix: restart the pool).
%   Safe with no pool open. (`clear` is illegal inside spmd, so workers are read.)
%
%   Defaults: expectDC = 0.05, expectDE = 0.02 (the finalized bonus rates).

    if nargin < 1 || isempty(expectDC), expectDC = 0.05; end
    if nargin < 2 || isempty(expectDE), expectDE = 0.02; end
    tol = 1e-9;

    % --- client ---
    clear Params
    p  = Params();
    dc = p.consistencyBonusPerSuccess;
    de = p.experienceBonusPerInteraction;
    fprintf('[rate guard] client : delta_c=%.3f  delta_e=%.3f\n', dc, de);
    assert(abs(dc - expectDC) < tol && abs(de - expectDE) < tol, ...
        ['ABORTING: client bonus rates are %.3f/%.3f, expected %.3f/%.3f. ', ...
         'Fix Params.m, run "clear Params", and retry.'], dc, de, expectDC, expectDE);

    % --- workers (only if a pool is already open) ---
    pool = gcp('nocreate');
    if isempty(pool)
        fprintf(['[rate guard] no pool open: parfor will run on the client (safe). ', ...
                 'Start the pool AFTER this check for a verified parallel run.\n']);
        fprintf('[rate guard] OK -- client verified %.3f/%.3f.\n', expectDC, expectDE);
        return;
    end

    % NOTE: `clear` is illegal inside spmd (transparency). We READ each worker's
    % current Params() instead. A freshly started pool loads Params.m from disk on
    % first call, so its workers report the file value; a stale pool reports its
    % cached value and is caught by the assert below (fix: restart the pool).
    spmd
        pw   = Params();
        rloc = [pw.consistencyBonusPerSuccess, pw.experienceBonusPerInteraction];
    end
    allr = vertcat(rloc{:});         % numWorkers x 2
    dcw  = allr(:,1);
    dew  = allr(:,2);
    fprintf('[rate guard] %d workers: delta_c in [%.3f, %.3f]  delta_e in [%.3f, %.3f]\n', ...
        numel(dcw), min(dcw), max(dcw), min(dew), max(dew));
    assert(all(abs(dcw - expectDC) < tol) && all(abs(dew - expectDE) < tol), ...
        ['ABORTING: one or more parpool WORKERS have wrong bonus rates ', ...
         '(delta_c=%s, delta_e=%s), expected %.3f/%.3f. Run ', ...
         '"delete(gcp(''nocreate''))", start a fresh pool so workers reload ', ...
         'Params.m, then retry.'], mat2str(dcw'), mat2str(dew'), expectDC, expectDE);

    fprintf('[rate guard] OK -- client and all %d workers verified %.3f/%.3f.\n', ...
        numel(dcw), expectDC, expectDE);
end
