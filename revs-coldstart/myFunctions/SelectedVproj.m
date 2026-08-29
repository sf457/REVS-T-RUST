% function [SVpro,CandidateVproj] = SelectedVproj(CandidateVproj, Vreqi, w1, w2)
%     % Initialize scores
%     Trust_scores = zeros(1, numel(CandidateVproj));
% 
%     % Loop through candidates and calculate scores
%     for i = 1:numel(CandidateVproj)
%         V2V_stayTime = calculateStayTime2(Vreqi, CandidateVproj(i));
%         CandidateVproj(i).V2V_StayTime = V2V_stayTime;
% 
%         % Calculate score based on weights
%          Trust_scores = w1 * CandidateVproj(i).reputation + w2 * CandidateVproj(i).V2V_StayTime;
%          CandidateVproj(i).Trust_scores=Trust_scores;
%     end
% 
%     % Find the candidate with the maximum score
%     [~, idx] = max(Trust_scores);
%     SVpro = CandidateVproj(idx);
% end

%updated function to make sure the hiest one is selrcted 
function [SVpro, CandidateVproj] = SelectedVproj(CandidateVproj, Vreqi, w1, w2)
    % Initialize scores
    Trust_scores = zeros(1, numel(CandidateVproj));

    % Loop through candidates and calculate scores
    for i = 1:numel(CandidateVproj)
        V2V_stayTime = calculateStayTime2(Vreqi, CandidateVproj(i));
        CandidateVproj(i).V2V_StayTime = V2V_stayTime;

        % Calculate score based on weights
        Trust_scores(i) = w1 * CandidateVproj(i).reputation + w2 * CandidateVproj(i).V2V_StayTime;
        CandidateVproj(i).Trust_scores = Trust_scores(i);
    end

    % Find the candidate with the maximum score
    [~, idx] = max(Trust_scores);
    SVpro = CandidateVproj(idx);
end

function V2V_stayTime = calculateStayTime2(Vreqi, Vproj)
    % Calculate the squared distance between Vreqi and Vproj based on RAZA
    distanceSquared = (Vproj.x - Vreqi.x)^2 + (Vproj.y - Vreqi.y)^2;

    % Ensure the vehicle is within the communication radius
    if distanceSquared > Vreqi.radius^2
        disp(['Vehicle ' Vproj.PID ' is out of Vreqi communication range']);
        V2V_stayTime = 0;
        return;
    end

    % Calculate the remaining distance within the radius
    remainingDistance = sqrt(Vreqi.radius^2 - distanceSquared);

    % Calculate the relative speed
    relativeSpeed = abs(Vreqi.speed - Vproj.speed);

    % Calculate the stay time within the coverage
    if relativeSpeed > 0
        V2V_stayTime = remainingDistance / relativeSpeed;
    else
        disp(['Relative speed between ' Vreqi.PID ' and ' Vproj.PID ' is zero']);
        V2V_stayTime = inf; % Infinite stay time if relative speed is zero
    end
end
