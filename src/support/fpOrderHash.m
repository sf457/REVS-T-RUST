function h = fpOrderHash(blockchainObj)
%FPORDERHASH  MD5 of all PIDs in ARRAY ORDER (NOT sorted). Detects whether the
%   blockchain is stored/traversed in a different order between serial (client)
%   and parallel (worker). Order matters because provider selection breaks
%   reputation ties by candidate array position (filterAndSortCandidates -> SelectedVproj2).
    chain = blockchainObj.blockchain;
    parts = strings(numel(chain), 1);
    k = 0;
    for i = 1:numel(chain)
        d = chain(i).data;
        if isfield(d, 'PID')
            k = k + 1;
            parts(k) = string(d.PID);
        end
    end
    if k == 0
        h = fpHash('');
    else
        h = fpHash(char(strjoin(parts(1:k), '|')));
    end
end
