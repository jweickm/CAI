% Written by Jakob Weickmann

function[skipTrial, terminate] = reactToKeyPresses_(pahandle, keyCodes)
% check for breakKeys (Esc to end to programm, G for attention grabber, P to pause)
    [~, ~, keyCode] = KbCheck();
    terminate = 0; % variable used to abort the experiment early
    skipTrial = 0;
    if find(keyCode) == keyCodes(3) % abort exp key ('Escape')
        % Stop Audio Playback
        PsychPortAudio('Close', []);
        textprogressbar('aborted by user');
        terminate = 1;
        return;
    elseif find(keyCode) == keyCodes(6) % skip trial key ('X')
        % Skip to next trial
        skipTrial = 1;
    elseif find(keyCode) == keyCodes(7) % pause key ('P')
        % wait 
        PsychPortAudio('Stop', pahandle);
        WaitSecs(1);
        KbWait();
        WaitSecs(0.2);
    end
return