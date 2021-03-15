while true 
    KbQueueStart(keyboardID);
    [pressed, firstPress, firstRelease, lastPress, lastRelease] = KbQueueCheck(keyboardID);
    if any(ismember(g_h, find(firstRelease))) % pressed
        break;
    end
end