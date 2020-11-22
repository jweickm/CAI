function[answerCorrect] = responseCheck_KbQueue(hand, finger, firstRelease)
answerCorrect = logical(finger - 1); % middle finger becomes correct

if any(find(firstRelease) == KbName('G')) % which means that 'G' was released
    answerCorrect = ~answerCorrect; % in this case flip the logit
end

if ((hand == 'L') || (hand == 'l'))
    answerCorrect = ~answerCorrect; % in this case flip the logit
end
return