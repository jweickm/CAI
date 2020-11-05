function screenNumber = getScreenNumber(screenName)
    % define known dimensions
    dimsMainDisplay = [544 303];        % TODO find screen dims of new main screen
    dimsSideDisplay = [376 301];
    dimsPresentationDisplay = [477 268];

    % get dimsnsions for each screen number
    try
        [w1, h1] = Screen('DisplaySize', 1);
        dims1 = [w1, h1];
    catch
        dims1 = [-1 -1];
    end
    try
        [w2, h2] = Screen('DisplaySize', 2);
        dims2 = [w2, h2];
    catch
        dims2 = [-1 -1];
    end
    try
        [w3 h3] = Screen('DisplaySize', 3);
        dims3 = [w3, h3];
    catch
        dims3 = [-1 -1];
    end
    
    % choose dims of selected screen
    switch screenName
        case 'main'
            dimsSelected = dimsMainDisplay;
        case 'side'
            dimsSelected = dimsSideDisplay;
        case 'presentation'
            dimsSelected = dimsPresentationDisplay;
        otherwise
            error("Invalid Screen Name [valid options: 'main', 'side', 'presentation']");
    end
    
    
    % match selected dims and queried dims
    if dimsSelected == dims1
        screenNumber = 1;
    elseif dimsSelected == dims2
        screenNumber = 2;
    elseif dimsSelected == dims3
        screenNumber = 3;
    else
        error("Couldn't find the right screen. Sorry :'(");
    end    
end

