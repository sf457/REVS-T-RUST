% function [CandidateVproj, numProviders, numRequesters, VprojBlockchainset] = fetchCandidatePool(VprojBlockchainset, Vreqi)
% %FETCHVEHICLES Return active, idle providers in same RSU as Vreqi.
% % - Persistently decrements blackoutCounter and reactivates when done.
% % - Initializes missing fields so downstream code is safe.
% % - Returns vehicle DATA structs (not blocks) for downstream selection.
% 
%     CandidateVproj = [];
%     disp('VprojBlockchainset in fetch')
%     disp(VprojBlockchainset)
%     disp('VprojBlockchainset.dat')
%     disp(VprojBlockchainset.data)
%     for n = 1:numel(VprojBlockchainset)
%         vData = VprojBlockchainset(n).data;
% 
%         % Decrement blacklist cooldown; reactivate when done
%         if vData.blackoutCounter > 0
%             vData.blackoutCounter = vData.blackoutCounter - 1;
%             if vData.blackoutCounter == 0
%                 vData.isActive = true; % Reactivate after freeze
%                 disp([vData.PID ' reactivated after blacklist freeze.']);
%                 % Optional: clear warning state on return
%                 vData.isWarning = false;
%                 vData.warningStreak = 0;
%             end
%         end
% 
%         % Persist changes back to the blockchain pool
%         VprojBlockchainset(n).data = vData;
%         % Skip inactive nodes
%         if isfield(vData, 'isActive') && ~vData.isActive
%             continue;
%         end 
%         % Gating
%         % Check if provider is in same RSU and is idle
%         sameRSU = (vData.RSU_ID == Vreqi.RSU_ID);
%         isIdle  = (vData.resourceStatus == 1);
%         % ✅ All conditions satisfied → add to candidate providers
%         if sameRSU && isIdle && vData.isActive
%             % Return DATA structs for downstream functions
%             CandidateVproj = [CandidateVproj, vData]; 
%         end
%     end
% 
%     % Count final available providers and requesters
%     numProviders  = numel(CandidateVproj);
%     numRequesters = 1; % Vreqi is a single requester struct
%     % Warn if not enough providers
%     if numProviders < numRequesters
%         disp('[⚠️] Not enough available vehicles for computation offloading.');
%     end
% end

function [CandidateVproj, numProviders, numRequesters, VprojBlockchainset] = fetchCandidatePool(VprojBlockchainset, Vreqi)
%FETCHVEHICLES Return all trusted and idle providers in same RSU as Vreqi
%
% Returns:
%   CandidateVproj      - Array of candidate provider data structs
%   numProviders        - Number of available providers
%   numRequesters       - Number of requesters
%   VprojBlockchainset  - Updated blockchain with decremented blackout counters

    CandidateVproj = [];

    for n = 1:length(VprojBlockchainset)
        vData = VprojBlockchainset(n).data;
        % Ensure isPermanentlyBlacklisted field exists with correct type
        if ~isfield(vData,'isPermanentlyBlacklisted') || ~islogical(vData.isPermanentlyBlacklisted)
            vData.isPermanentlyBlacklisted = false;
        end
        % Check if provider is in same RSU and is idle
        sameRSU = vData.RSU_ID == Vreqi.RSU_ID;
        isIdle = vData.resourceStatus == 1;

wasInBlackout = false;

if vData.blackoutCounter > 0
    wasInBlackout = true;

    if ~isinf(vData.blackoutCounter)
        vData.blackoutCounter = vData.blackoutCounter - 1;

        if vData.blackoutCounter == 0
            vData.isActive = true;
            vData.isWarning = true;
            vData.warningStreak = 1;
            % Debug output suppressed for cleaner experiment logs
            % disp([vData.PID ' reactivated after blacklist freeze']);
            % fprintf("RECOVER %s: active=%d warning=%d blackout=%d\n", ...
            %     vData.PID, vData.isActive, vData.isWarning, vData.blackoutCounter);
        end
    end
end

% Persist changes back
VprojBlockchainset(n).data = vData;

% ✅ If it was in blackout at start of run, skip it this run no matter what
if wasInBlackout
    continue;
end


        if isfield(vData, 'isActive') && ~vData.isActive
            continue;
        end

% % show the candidate data about to be appended
% disp('the candidate data about to be appended')
% disp(vData);

% Guard: skip non-struct entries
if ~isstruct(vData)
    warning('Skipping non-struct vData at n=%d (class=%s).', n, class(vData));
    continue;
end

% Determine existing fieldnames from CandidateVproj in a safe way
if isempty(CandidateVproj)
    fExisting = {};
else
    if iscell(CandidateVproj)
        % CandidateVproj collected as cells: use first cell element
        if ~isempty(CandidateVproj{1}) && isstruct(CandidateVproj{1})
            fExisting = fieldnames(CandidateVproj{1});
        else
            fExisting = {};
        end
    elseif isstruct(CandidateVproj)
        % struct array: use the first element's fields
        fExisting = fieldnames(CandidateVproj(1));
    else
        % unexpected type
        fExisting = {};
    end
end

% New entry fields
fNew = fieldnames(vData);

% Compare (sort to ignore order) - warnings suppressed for cleaner output
% Uncomment fprintf lines below to debug field mismatches
if ~isempty(fExisting) && ~isequal(sort(fExisting), sort(fNew))
    % missingInNew = setdiff(fExisting, fNew);
    % extraInNew   = setdiff(fNew, fExisting);
    % fprintf('Field mismatch at n=%d\n', n);
    % fprintf(' Existing (example): %s\n', strjoin(fExisting, ','));
    % fprintf(' New:                %s\n', strjoin(fNew, ','));
    % fprintf(' Missing in new:     %s\n', strjoin(missingInNew, ','));
    % fprintf(' Extra in new:       %s\n', strjoin(extraInNew, ','));
end

% Now safe to append (choose one approach)
% 1) Append to a cell array (best if shapes legitimately differ):
%    CandidateVprojCell{end+1} = vData;
% 2) Or append to struct array only if fields match:
%    CandidateVproj = [CandidateVproj, vData];

        % ✅ All conditions satisfied → add to candidate providers
        if sameRSU && isIdle
            % Ensure field consistency for struct concatenation
            if isempty(CandidateVproj)
                CandidateVproj = vData;
            else
                % Align fields between existing array and new entry
                existFields = fieldnames(CandidateVproj);
                newFields = fieldnames(vData);
                missingInNew = setdiff(existFields, newFields);
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
    end

    % Count final available providers and requesters
    numProviders = numel(CandidateVproj);
    numRequesters = length(Vreqi);

    % Warn if not enough providers (suppressed for cleaner output)
    % if numProviders < numRequesters
    %     disp('[⚠️] Not enough available vehicles for computation offloading.');
    % end
end
