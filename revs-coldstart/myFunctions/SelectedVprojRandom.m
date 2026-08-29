function SVpro = SelectedVprojRandom(CandidateVproj)
    % Ensure there are candidates to choose from
    if isempty(CandidateVproj)
        error('No candidates available for selection.');
    end

    % Randomly select a candidate
    idx = randi([1, numel(CandidateVproj)]); % Generate a random index
    SVpro = CandidateVproj(idx);

    % % Display the selected provider for debugging
    % disp(['Randomly selected provider: ' SVpro.PID]);
end