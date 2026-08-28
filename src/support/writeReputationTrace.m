function writeReputationTrace(csvFile, row)
% WRITEREPUTATIONTRACE Append a single struct row to a CSV.
% Creates the file and header if missing. Works with the compact row struct
% created by calculateLocalSubjectiveOpinion below.
%
% Usage:
%   writeReputationTrace('rep_trace_log.csv', rowStruct);

    if ~isstruct(row)
        warning('writeReputationTrace: row must be a struct'); return;
    end

    % Ensure directory exists (with error handling)
    [p, ~, ~] = fileparts(csvFile);
    if ~isempty(p) && ~exist(p, 'dir')
        try
            mkdir(p);
            fprintf('Created log directory: %s\n', p);
        catch ME
            warning('writeReputationTrace: Cannot create directory %s: %s', p, ME.message);
            return;
        end
    end

   % Stable column order 
cols = { ...
   'timestamp','runIndex','globalRatio','scenarioName', ...
  'VreqiID','SVproID','socialTrustLevel','isMalicious','current_R', ...
  'success','tAll','MaxT', ...
  'Honest_ij','TE_ij','I_ij', ...
  'alpha_before','beta_before','gamma_before', ...
  'alpha_inc','beta_inc','gamma_inc', ...
  'alpha_after','beta_after','gamma_after', ...
  'subj_b','subj_d','subj_u', ...
  'rec_b','rec_d','rec_u', ... % Recommendation statistics
  'numHistoryEntries','numOtherRequesters','numAllVreqIDs', ...
  'numRecommenders','IFij','IF_mean','IF_std','IF_max', ... % Reputation timeline
  'R_preTier','R_postTier','tierAction', ...
  'isActive','isWarning','warningStreak','blackoutCounter','totalBlacklists' ...
  % Params snapshot deliberately omitted here (you can add them back if needed)
  % ... % Params snapshot
  % 'R_min','R_warn','R_boost','rewardBoost','penaltyFreezeRuns','warnEscalationRuns', ...
  % 'a0','zeta','sigma','theta','tau','rho','windowK','capIF', ...
  % 'H_threshold','I_high_thresh','I_low_thresh' ...
};

    % Build a cell array of values for the columns (fill missing with "")
    vals = cell(1, numel(cols));
    for k = 1:numel(cols)
        f = cols{k};
        if isfield(row, f)
            v = row.(f);
            % convert datetime to char for CSV
            if isdatetime(v), v = char(v); end
            vals{k} = v;
        else
            vals{k} = "";
        end
    end

    T = cell2table(vals, 'VariableNames', matlab.lang.makeValidName(cols));

    % Retry parameters for file locking issues (common on Windows)
    maxRetries = 3;
    retryDelay = 0.1;  % seconds

    if ~isfile(csvFile)
        % write with header
        success = false;
        for attempt = 1:maxRetries
            try
                writetable(T, csvFile, 'WriteVariableNames', true);
                success = true;
                break;
            catch ME
                if attempt < maxRetries
                    pause(retryDelay * attempt);  % exponential backoff
                else
                    % fallback: low-level write
                    fid = fopen(csvFile,'w');
                    if fid < 0
                        warning('Cannot create log file %s (tried %d times): %s', csvFile, maxRetries, ME.message);
                        return;
                    end
                    fprintf(fid, '%s\n', strjoin(cols, ','));
                    fclose(fid);
                    try
                        writetable(T, csvFile, 'WriteVariableNames', false, 'WriteMode','append');
                        success = true;
                    catch
                        warning('Cannot write to log file %s', csvFile);
                        return;
                    end
                end
            end
        end
    else
        % append without header (with retry for file lock issues)
        success = false;
        for attempt = 1:maxRetries
            try
                writetable(T, csvFile, 'WriteVariableNames', false, 'WriteMode','append');
                success = true;
                break;
            catch ME
                if attempt < maxRetries
                    pause(retryDelay * attempt);  % exponential backoff
                else
                    % fallback: low-level write
                    fid = fopen(csvFile,'a');
                    if fid < 0
                        % Only warn once per unique file to avoid spam
                        persistent warnedFiles;
                        if isempty(warnedFiles), warnedFiles = {}; end
                        if ~ismember(csvFile, warnedFiles)
                            warning('Cannot append to log file %s (tried %d times, file may be locked): %s', ...
                                csvFile, maxRetries, ME.message);
                            warnedFiles{end+1} = csvFile;
                        end
                        return;
                    end
                    % write CSV line manually
                    line = strjoin(cellfun(@(c) toCsvSafe(c), vals, 'UniformOutput', false), ',');
                    fprintf(fid, '%s\n', line);
                    fclose(fid);
                    success = true;
                end
            end
        end
    end
end

function s = toCsvSafe(v)
    if isempty(v)
        s = '';
    elseif isnumeric(v)
        s = num2str(v);
    else
        s = char(v);
        % escape quotes
        s = strrep(s, '"', '""');
        if contains(s, ',') || contains(s, '"') || contains(s, newline)
            s = ['"' s '"'];
        end
    end
end