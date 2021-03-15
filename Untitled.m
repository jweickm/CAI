ListenChar(2);
WaitSecs(3);
while true
    [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
    if ~all(ismember(find(match_g_h), find(keyCode)))
        break;
    end
    disp(secs);
end
Beeper();
ListenChar();


WaitSecs(3);
while all(ismember(find(match_g_h), find(keyCode)))
    [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
    
    disp(secs);
end
Beeper();