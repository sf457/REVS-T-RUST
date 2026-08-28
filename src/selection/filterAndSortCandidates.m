function SortedCanditateVproj_R_D = filterAndSortCandidates(VprojBlockchain)
%SORTVPROJ2  Filter providers by direction and reputation floor.
%
% Returns providers matching (direction == 'Same direction') AND
% (reputation >= params.minReputation).
%
% The legacy sort step (by [isWarning, -reputation]) was removed
% because the downstream consumer selection functions
% (selectProviderTierAware, selectProviderNoTier,
% selectProviderMaxRep) all use argmax-based scoring and do not
% depend on input order. The sort was vestigial work.
%
% Function name retained as-is for backward compatibility with
% callers (SmartContract.m). Output variable name kept _R_D for the
% same reason, even though the array is no longer sorted by R or D.

    params = Params();
    minReputation = params.minReputation;

    Vproj_SameD = getVehicle_SameDirection(VprojBlockchain, minReputation);

    if isempty(Vproj_SameD)
        SortedCanditateVproj_R_D = [];
        return;
    end

    SortedCanditateVproj_R_D = Vproj_SameD;
end


function Vproj_SameD = getVehicle_SameDirection(Vproj, minReputation)
    tempVproj_SameD = [];

    for i = 1:length(Vproj)
        v = Vproj(i);
        if strcmp(v.direction, 'Same direction') && v.reputation >= minReputation
            tempVproj_SameD = [tempVproj_SameD, v];
        end
    end

    if isempty(tempVproj_SameD)
        Vproj_SameD = [];
    else
        Vproj_SameD = tempVproj_SameD;
    end
end

