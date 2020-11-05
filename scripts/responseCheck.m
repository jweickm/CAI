function[answerCorrect] = responseCheck(hand, finger, keyCode)
answerCorrect = logical(finger - 1); % middle finger becomes correct

if find(keyCode) == KbName('H') % which means that 'G' was released
    answerCorrect = ~answerCorrect; % in this case flip the logit
end

if ((hand == 'L') || (hand == 'l'))
    answerCorrect = ~answerCorrect; % in this case flip the logit
end
return