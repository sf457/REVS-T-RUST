
function RSUs = RSUmap()
    % RSUmap defines the locations and spatial coverage ranges of RSUs
    % Output:
    %   - RSUs: an array of structs, each representing an RSU with an ID, x-range, and y-position

    RSUs(1).ID = 1;          % RSU 1 ID
    RSUs(1).xRange = [0, 250]; % RSU 1 covers x-coordinates from 0 to 250
    RSUs(1).y = 70;          % RSU 1 y-coordinate

    % RSUs(2).ID = 2;          % RSU 2 ID
    % RSUs(2).xRange = [300, 550]; % RSU 2 covers x-coordinates from 300 to 550
    % RSUs(2).y = 70;          % RSU 2 y-coordinate

    % Additional RSUs can be added here if needed for more complex simulations
end