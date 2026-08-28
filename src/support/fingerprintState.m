function [h, summ, raw] = fingerprintState(blockchainObj)
%FINGERPRINTSTATE  Deterministic fingerprint of the full provider/requester
%   trust state held in the blockchain. Sorted by (type, PID) so the hash is
%   INDEPENDENT of array/storage order -- it reflects content, not position.
%   This is the per-stage state probe for the serial-vs-parallel forensic harness.
%
%   Returns:
%     h    - hex MD5 of the sorted state matrix
%     summ - struct of scalar aggregates (so a divergence shows WHAT changed)
%     raw  - the sorted numeric state matrix (optional, for manual inspection)

    chain = blockchainObj.blockchain;
    n = numel(chain);
    rows = nan(n, 9);
    k = 0;
    for i = 1:n
        d = chain(i).data;
        if ~isfield(d, 'PID'), continue; end
        s = char(string(d.PID));
        pidNum = str2double(regexprep(s, '\D', ''));
        if ~isempty(s) && upper(s(1)) == 'P'
            typ = 1;            % provider
        elseif ~isempty(s) && upper(s(1)) == 'R'
            typ = 0;            % requester
        else
            typ = 2;
        end
        k = k + 1;
        rows(k, :) = [ typ, pidNum, ...
            gf(d,'reputation'), gf(d,'isActive'), gf(d,'isWarning'), ...
            gf(d,'blackoutCounter'), gf(d,'warningStreak'), ...
            gf(d,'totalBlacklists'), gf(d,'isMalicious') ];
    end
    rows = rows(1:k, :);
    rows = sortrows(rows, [1 2]);        % (type, PID) -> order independent

    h = fpHash(rows(:).');

    prov = rows(rows(:,1) == 1, :);      % aggregates over providers only
    summ = struct( ...
        'n',           size(prov,1), ...
        'sumRep',      nsum(prov(:,3)), ...
        'nActive',     nsum(prov(:,4)), ...
        'nWarning',    nsum(prov(:,5)), ...
        'sumBlackout', nsum(prov(:,6)), ...
        'sumWarnStk',  nsum(prov(:,7)), ...
        'sumBlacklst', nsum(prov(:,8)), ...
        'nMalicious',  nsum(prov(:,9)) );

    if nargout > 2, raw = rows; end
end

function v = gf(d, f)
%GF  Safe scalar field get; NaN if absent/non-scalar.
    v = NaN;
    if isfield(d, f)
        x = d.(f);
        if (isnumeric(x) || islogical(x)) && isscalar(x)
            v = double(x);
        end
    end
end

function s = nsum(x)
    s = sum(x(~isnan(x)));
end
