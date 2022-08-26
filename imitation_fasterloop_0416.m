% This is the experimental script for running the automatic imitation task
% using PsychToolBox
% Written by Jakob Weickmann, MA BSc

%% TODO:
% - [x] add start.bmp before each trial (200ms) 
% - [x] Bildtiming dann passend auf den Heartbeat
% - [x] Systole (synchron) 250 ms nach R peak (= getECGStatus.m returns
% "ON")
% - [x] Diastole (asynchron) 550 ms nach R peak (= getECGStatus.m returns
% "OFF")
% - [ ] update instructions
% - [x] heartbeat timings (getECGStatus.m)
% - [x] refer to ibeat_main.m (Set up Arduino)
% - [x] trialMat mit synchron/asynchron (gleiche Anzahl) auf 360 trials in
% 90er Bloecken + 12 Uebungstrials
% - [x] Fix cross mit variabler dauer + jitter:
% - [x]     Synchron:  [1500 ms +- 500 ms] + variable R peak timing 
% - [x]     Asynchron: [1200 ms +- 500 ms] + variable R peak timing
% - [x] implement maximum response time
% - [x] implement data export
% - [x] implement keys to abort experiment
% - [x] implement block design with breaks (90 trials per block)

% BONUS:
% - [x] left-handed stimuli
% - [x] faster while loop for searching the arduino signal:
    % draw fix
    % WaitSecs
    % search while loop
    % break
    % show stimuli 
% - [x] Umlaute auf Deutsch einfügen (ä, ö, ü)
% - [ ] handedness in export
% - [ ] more beautiful instructions would be nice
% - [ ] record interbeat interval and save in export

% - [ ] interbeat interval estimate in the beginning

% CAREFUL: Set "Fixed width pulse" under 'Setup' -> 'Fast Response Output'
% to ~ 24 ms ( 0.024 s) (= 1.5 x framerate)

% -------------------------
% Initialization 
% -------------------------

% Clear everything
close all;
clear mem;
sca;
clc;

PsychDefaultSetup(2);

disp('Initializing script...');

origin_folder = cd;
addpath 'stimuli';
addpath 'scripts';

AssertOpenGL;

ECG_Active = 1; % if arduino is connected: 1
Fullscreen = 0;
SkipTests = 0;
test_mode = 1;
SCREEN_NAME = 'side';       % options: 'side', 'main', 'presentation'

if test_mode
    screens = Screen('Screens');
    screenNumber = max(screens);
    SkipTests = 1;
    ECG_Active = 0;
else
    screenNumber = getScreenNumber(SCREEN_NAME);
end

neutralStimuliIncluded = 1;

%% ===================================================
%                       SCREEN SETUP
% ==========================================================

% Fullscreen
if Fullscreen
    screenRect = [];
else
    screenRect = [10 10 710 710];
end

% Here we call some default settings for setting up Psychtoolbox
PsychDefaultSetup(2);
rng('shuffle');
   
% disable syn tests when coding/debugging but not when running ex periments!!
if SkipTests
    Screen('Preference', 'SkipSyncTests', 1);
else
    Screen('Preference', 'SkipSyncTests', 0);
end

% Checking Psychtoolbox: Break and issue an eror message if installed
% Psychtoolbox is not based on OpenGL or Screen() is not working properly.
AssertOpenGL;

% Get black and white index of the system.
% white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);

if ECG_Active
    %----------------------------------------------------------------------
    %                        Set up Arduino
    %----------------------------------------------------------------------
    if ~exist('ard', 'var') 
        try
            disp("Connecting Arduino...");
            ard = arduino();
            inputPinNumber = 'A0';   % analog input pin on arduino that is connected to powerlab
            outputPinNumber = 'D7'; % output pin used to send triggers to labchart
            lastECGStatus = "OFF";  
            disp("...done.");
        catch e
            showErrorMsg("Arduino could not be set up. Terminating.", e);
            sca();
            return;
        end
    else 
        disp('Connection to Arduino already initiated.');
    end
end


%% ===================================================
%               PARTICIPANT'S DETAILS DIALOG
% ==========================================================

%% Get the participant's details
% prompt = {'Subject number (integer):','Subject Initials:', 'Age:', 'Gender (f/m/d or leave empty):', 'Handedness (L/R/0):'};
% title = 'Please enter the participant''s details';
% dims = [1 20; 1 15; 1 10; 1 40; 1 30];
% definput = {'1','A.B.', '99', 'f', 'R'};
% answer = inputdlg(prompt,title,dims,definput);
% subjectCode = answer{1};
% [num, sub, age, gender, hand] = deal(answer{:}); % store answers in separate variables
% 
% subNum = str2double(num); % convert Subject number from string to number if needed
% subInfo = [{'Subject Number'}, {'Name'}, {'Sex'}, {'Age'}, {'Handedness'};...
%     {num}, {sub}, {age}, {gender}, {hand}]; % store together in a single variable

[subjectCode, handedness] = getParticipantDetailsAIT();



%% -------------------------------
% TRIAL STRUCTURE
% -------------------------------
% 1. Press 'G' or 'H' and keep it pressed
% 2. 500 ms Fixation Cross
% 3. 200 ms Images mirrored left hand in resting position
% 4. max 2000 ms 2nd picture (or until key press) (1 of three conditions)
% 5. lift finger in response to the NUMBER on the picture

% 12 practice trials
% 360 experimental trials 
%       120 congruent (davon 60 sync, async)
%       120 incongruent (davon 60 sync, async)
%       120 neutral (davon 60 sync, async)
%  every 90 trials: optional break

nTrials = 360; % needs to be multiple of 6
nPracticeTrials = 12;
blockLength = 90;
nBlocks = nTrials/blockLength;

% 2 (congruence) x 2 (timings) x 3 pictures = incongruent index, incongruent
% middle, congruent index, congruent middle x heat beat timing

trialMat = zeros(3, nTrials);
trialMat(1,:) = randperm(nTrials);
if neutralStimuliIncluded
    trialMat(2,:) = repmat([1,2,3], 1, nTrials/3); % stimulus type 
else
    trialMat(2,:) = repmat([1,3], 1, nTrials/2); % stimulus type
end
trialMat(3,:) = repmat([1,2], 1, nTrials/2); % correct finger
trialMat(4,:) = [repmat([1], 1, nTrials/2), repmat([2], 1, nTrials/2)]; % synchronous or asynchronous
trialMat = sortrows(trialMat')'; 

% + practice Trials extra generieren
practiceMat = trialMat(:,randi(nTrials, 1, nPracticeTrials));

syncTrialDur = 1.500; % in seconds duration of sync trial
trialDuration = [syncTrialDur, syncTrialDur - 0.300]; % trial duration in s for synchronous/asynchronous trials
jitter = .2; % +- jitter in seconds

% delay between R peak and stimulus presentation 
syncDur = 0.250; % in synchronous trials
asyncDur = 0.550; % in asynchronous trials

% preallocate responsesMat
responsesMat = zeros(3,nTrials);

%% ===================================================
% Set up keys
% ===================================================

% provide a consistent mapping of keyCodes to key names on all operating systems.
KbName('UnifyKeyNames');

% keyCodes: [Space, Return, Escape, G, H, X, P]
abortExpKey = 'ESCAPE';
pauseKey = 'P';
abortBlockKey = 'X';
keyCodes = [KbName('SPACE'), KbName('RETURN'), KbName(abortExpKey), ...
    KbName(abortBlockKey), KbName(pauseKey), KbName('G'), KbName('H')];

% Setup of response keys
match_g_h = zeros(1,256);
match_g_h(KbName({'G', 'H'})) = 1;
g_h = KbName({'G', 'H'});
% ------------------------------------------
% suppress listening to Matlab
% ListenChar(2); % must be disabled for use with KbQueueCheck
% ------------------------------------------
oldenablekeys = RestrictKeysForKbCheck(keyCodes);

keyboardID = 0;
KbQueueCreate(keyboardID, match_g_h);



%% ===================================================
%                   LOAD IMAGES
% ==========================================================
if handedness == 1
    hand = 'r';
elseif handedness == 2
    hand = 'l';
else 
    warning('Handedness was not correctly recognized. Please enter it in the beginning.');
end

% if no preloaded stimuli already exist in the folder
if ~exist('./stimuli/images.mat', 'file')
    directory_1 = dir(['./stimuli/1*', hand,'.bmp']);
    directory_2 = dir(['./stimuli/2*', hand,'.bmp']);
    directory_startbmp = dir(['./stimuli/start_', hand, '.bmp']);
    images = cell(2,3);
    
    for current_frame = 1:3
        images{1,current_frame} = imread([directory_1(current_frame).folder, filesep, directory_1(current_frame).name]);
        images{2,current_frame} = imread([directory_2(current_frame).folder, filesep, directory_2(current_frame).name]);
    end
    
    start_image = imread([directory_startbmp.folder, filesep, directory_startbmp.name]);
    
else
    disp('images.mat found');
    textprogressbar('Loading images:        ');
    load('./stimuli/images.mat', 'facialStimuli');
    try
        textprogressbar(100);
    catch
        textprogressbar('Loading images:        ');
        textprogressbar(100);
    end
    textprogressbar('done');
end


%% ===================================================
%                     OPEN ON-SCREEN WINDOW
% ==========================================================

disp('Opening on-screen window...');

% Background Colour when opening window
bgc = 216;
% using Screen
bgColour_RGB = bgc * ones(1,3); % convert to RGB
BGC_Psychimaging = bgColour_RGB ./255;

%[windowPtr, windowRect] = PsychImaging('OpenWindow', screenNumber, BGC_Psychimaging, screenRect);
[windowPtr, windowRect] = Screen('OpenWindow', screenNumber, bgColour_RGB, screenRect);

% using Psychimaging
%bgColour = bgc/255; % 0 - 1
%[windowPtr, windowRect] = PsychImaging('OpenWindow', screenNumber, bgColour, screenRect);

% Retreive the maximum priority number
topPriorityLevel = MaxPriority(windowPtr);

% set priority level for accurate timing
Priority(topPriorityLevel);

% Query the frame duration (inter frame interval; framerate = 1/ifi)
ifi = Screen('GetFlipInterval', windowPtr);


%% ---------------------------------------------------
%                          FIXATION CROSS
% ----------------------------------------------------------
[xCenter, yCenter] = RectCenter(windowRect);
% Set the radius of the fixation cross
fixRadius = 40;

% Now we set the coordinates (these are all relative to zero we will let
% the drawing routine center the cross in the center of our monitor for us)
xCoords = [-fixRadius fixRadius 0 0];
yCoords = [0 0 -fixRadius fixRadius];
allCoords = [xCoords; yCoords];

% Set the line width for our fixation cross
lineWidthPix = 4;

%% Stimulus size
% stimulus sizes in pixels
stimulusRadius = 200; % adjust for bigger or smaller stimuli

ratio = 2/3; % this is the original image ratio
% in this target area
stimulusRect = [xCenter - (stimulusRadius/ratio), yCenter - (stimulusRadius),...
                     xCenter + (stimulusRadius/ratio), yCenter + (stimulusRadius)];



%% ---------------------------------------------------
%                  PREALLOCATING VARIABLES
% ----------------------------------------------------------


%% =======================================
%               INSTRUCTIONS
% =============================================

waitText = ['Bitte warten Sie auf Anweisung \ndurch die '...
    'Versuchsleitung.'];
if handedness == 1
    handText = 'rechten';
    key1 = '[G]';
    key2 = '[H]';
else 
    handText = 'linken';
    key1 = '[H]';
    key2 = '[G]';
end
instrText = ['Legen Sie Ihren ', handText, ' Zeigefinger auf die ',key1,'-Taste\n'...
    'und Ihren ', handText,' Mittelfinger auf die ',key2,'-Taste.\n'...
    'Sie werden nun mehrere Bilder nacheinander sehen.\n'...
    'Wenn Sie ein Bild mit einer kleinen [1] sehen, dann heben Sie bitte Ihren Zeigefinger.\n'...
    'Wenn Sie ein Bild mit einer kleinen [2] sehen, dann heben Sie bitte Ihren Mittelfinger.'];
pauseText = 'Gönnen Sie sich eine kurze Pause. Sobald Sie weitermachen möchten, drücken Sie die Leertaste.';


%% **************************************************
%  |                   WELCOME SCREEN                     |
%  ********************************************************

Screen('Preference','TextEncodingLocale', 'UTF-8');
Screen('TextFont', windowPtr, 'Calibri');
Screen('TextSize', windowPtr, 44);

% Display message
DrawFormattedText(windowPtr, waitText, 'center', 'center', 0, 77);
Screen('Flip', windowPtr);
disp('Press SPACEBAR or ENTER to continue.');
KbWait();

% display instructions before 1st block
DrawFormattedText(windowPtr, instrText, 'center', 'center', 0, 77);
Screen('Flip', windowPtr);

disp('Press SPACEBAR or ENTER to continue.');
WaitSecs(1);
KbWait();

fprintf('\nExperiment is about to begin.\n\n');
DrawFormattedText(windowPtr, 'Das Experiment beginnt ', 'center', 'center', 0, 77);
Screen('Flip', windowPtr);
WaitSecs(0.5);
disp('Experiment begins in 3...');
DrawFormattedText(windowPtr, 'Das Experiment beginnt .', 'center', 'center', 0, 77);
Screen('Flip', windowPtr);
WaitSecs(0.5);
disp('                     2...');
DrawFormattedText(windowPtr, 'Das Experiment beginnt ..', 'center', 'center', 0, 77);
Screen('Flip', windowPtr);
WaitSecs(0.5);
disp('                     1...');
DrawFormattedText(windowPtr, 'Das Experiment beginnt ...', 'center', 'center', 0, 77);
Screen('Flip', windowPtr);
WaitSecs(0.5);
disp('-------------------------');


%% =======================================
% EXPERIMENTAL LOOP
% =============================================
startTexture = Screen('MakeTexture', windowPtr, start_image);

%% =======================================
% PRACTICE BLOCKS
% =============================================
skipPractice = 0;
for practiceTrial = practiceMat
    if skipPractice == 1
        break;
    end
    
    if practiceTrial(4) == 1
        disp('sync trial');
    else
        disp('async trial');
    end
    currentTrialDur = trialDuration(practiceTrial(4)); % 1 if synchronous, 2 if asynchronous

    currentTexture = Screen('MakeTexture', windowPtr, images{practiceTrial(3),practiceTrial(2)});
    
    % disp('Press G and H');
    keyCode = zeros(1, 256);
    finger = practiceTrial(3);
    
    completed = 0;
    earlyRelease = 0;
    reactedTooLate = 0;
    RPeak_timing = 0;
    
    currentJitter = (rand(1) * 2 * jitter) - jitter; % jitter 
    
    currentFixDuration = currentTrialDur + currentJitter; % fixation cross duration in seconds
    currentFixFrames = currentFixDuration/ifi; % fixation cross duration in frames
    maxTrialDuration = currentTrialDur + 1.5; % maximum trial duration in seconds
    maxTrialFrames = maxTrialDuration/ifi; % maximum trial duration in frames
    maxReactionTime = 1.0; % maximum reaction time in seconds
    
    if practiceTrial(4) == 1 % synchronous trial
        peakDelay = syncDur; % delay after first R peak until stimulus presentation in seconds
    elseif practiceTrial(4) == 2 % asynchronous trial
        peakDelay = asyncDur;
    end
    peakDelayFrames = peakDelay / ifi; % delay after 1st R peak until stim presentation in frames
    
    while true
        DrawFormattedText(windowPtr, 'Drücken und halten Sie [G] und [H]', 'center', 'center', 0, 77);
        % KbQueueStart(keyboardID);
        Screen('Flip', windowPtr);
        
        % Check the keyboard
        WaitSecs(0.5);
                
        [~, ~, keyCode] = KbCheck(); % must be disabled for use with
        % KbQueueCheck
        
       %% Check for key presses
        [skipTrial, terminate] = reactToKeyPressesAIT(keyCodes);
        if terminate
               % Close up shop
               exit_routineAIT(subjectCode, origin_folder, trialMat, responsesMat);
               return
        end
            
        if all(ismember(g_h, find(keyCode)))       
            % Start the Trial
            measured = 0;
            stimulusTiming = 0;
            current_frame = 0;
            trialStartTime = GetSecs();
            currentPhase = 0;
            
            while true
                [~, ~, keyCode] = KbCheck();
                if ~all(ismember(g_h, find(keyCode)))
                    break;
                end
                
                elapsedTime = GetSecs() - trialStartTime;  
                % Check for key presses
                [skipTrial, terminate] = reactToKeyPressesAIT(keyCodes);
                if terminate
                   % Close up shop
                   exit_routineAIT(subjectCode, origin_folder, trialMat, responsesMat);
                   return
                end
                    
                %% Phase 0: Fix Cross
                if currentPhase == 0
                    % Draw the fixation cross in black, set it to the center of screen
                    Screen('DrawLines', windowPtr, allCoords, lineWidthPix, black, [xCenter yCenter]);
                    Screen('Flip', windowPtr);
                    currentPhase = 1;
                end

                %% Phase 1 ECG: Get 1st R peak
                % when fixation cross was fully shown, register the first R Peak
                if currentPhase == 1 && elapsedTime >= currentFixDuration && ECG_Active
                    current_ECG_Status = getECGStatus(ard, inputPinNumber);
                    % do the timing with the R peak, signal is coming from the
                    % arduino
                    if current_ECG_Status == "ON"
                        RPeak_timing = GetSecs() - trialStartTime;
                        currentPhase = 2;
                    end
                end

                %% Phase 2: Draw the neutral starting image on the screen
                % time = -200
                if (currentPhase == 2 && elapsedTime >= RPeak_timing + peakDelay - .200) || ... % with ECG
                        (currentPhase == 1 && elapsedTime >= currentFixDuration && ~ECG_Active) % without ECG
                    Screen('DrawTexture', windowPtr, startTexture, [], stimulusRect);
                    Screen('Flip', windowPtr);
                    currentPhase = 3;
                end

                %% Phase 3: Draw the stimulus image for this trial on the screen
                % time = 0
                if (currentPhase == 3 && elapsedTime >= RPeak_timing + peakDelay && ECG_Active) || ... % with ECG
                        (currentPhase == 3 && elapsedTime >= currentFixDuration + .200 && ~ECG_Active) % without ECG
                    Screen('DrawTexture', windowPtr, currentTexture, [], stimulusRect);
                    % Get the timing of stimulus presentation
                    stimulusTiming = GetSecs();
                    if ECG_Active
                        % send trigger to labchart
                        sendTriggerArduinoLabchart(ard, outputPinNumber);
                    end
                    Screen('Flip', windowPtr);
                    currentPhase = 4;
                end

                %% Phase 4: Reaction too late
                if currentPhase == 4 && elapsedTime >= stimulusTiming + maxReactionTime
                    currentPhase = 5;
                    break;
                end
            end       
            
            Beeper();
            %% Save the result of the trial
            % Trial ended too early
            if currentPhase <= 3
                DrawFormattedText(windowPtr, 'Sie haben den Finger zu früh gehoben.', 'center', 'center', 0, 77);
                Screen('Flip', windowPtr);
                WaitSecs(1);
                continue;

            % Trial completed
            elseif currentPhase == 4
                Screen('Flip', windowPtr);
                WaitSecs(0.2);
                break;

            % Reaction too late
            elseif currentPhase == 5
                DrawFormattedText(windowPtr, 'Bitte reagieren Sie schneller.', 'center', 'center', 0, 77);
                Screen('Flip', windowPtr);
                WaitSecs(1);
                break;
            end
        end
    end
    Screen('Close', currentTexture');
    WaitSecs(1);
end

% Display message
DrawFormattedText(windowPtr, 'Dies ist das Ende der Übungstrials.', 'center', 'center', 0, 77);
Screen('Flip', windowPtr);
disp('Press SPACEBAR or ENTER to continue.');
WaitSecs(1);
RestrictKeysForKbCheck(KbName('space', 'return')); % changes the acceptable keys for KbCheck to only space and return
KbWait();
RestrictKeysForKbCheck(keyCodes); % unlocks all other keys again for KbCheck

%% =======================================
% EXPERIMENTAL BLOCKS
% =============================================

for block = 1:nBlocks
    startTrialID = (block-1) + 1;
    endTrialID   = block * blockLength;
    
    for expTrial = trialMat(:,startTrialID : endTrialID)
        if expTrial(4) == 1
            disp('sync trial');
        else
            disp('async trial');
        end
        currentTrialDur = trialDuration(expTrial(4)); % 1 if synchronous, 2 if asynchronous

        currentTexture = Screen('MakeTexture', windowPtr, images{expTrial(3),expTrial(2)});

        % disp('Press G and H');
        keyCode = zeros(1, 256);
        finger = expTrial(3);

        completed = 0;
        earlyRelease = 0;
        reactedTooLate = 0;
        RPeak_timing = 0;

        currentJitter = (rand(1) * 2 * jitter) - jitter; % jitter 

        currentFixDuration = currentTrialDur + currentJitter; % fixation cross duration in seconds
        currentFixFrames = currentFixDuration/ifi; % fixation cross duration in frames
        maxTrialDuration = currentTrialDur + 1.5; % maximum trial duration in seconds
        maxTrialFrames = maxTrialDuration/ifi; % maximum trial duration in frames
        maxReactionTime = 1.0; % maximum reaction time in seconds

        if expTrial(4) == 1 % synchronous trial
            peakDelay = syncDur; % delay after first R peak until stimulus presentation in seconds
        elseif expTrial(4) == 2 % asynchronous trial
            peakDelay = asyncDur;
        end
        peakDelayFrames = peakDelay / ifi; % delay after 1st R peak until stim presentation in frames

        while true
            DrawFormattedText(windowPtr, 'Drücken und halten Sie [G] und [H]', 'center', 'center', 0, 77);
            % KbQueueStart(keyboardID);
            Screen('Flip', windowPtr);

            % Check the keyboard
            WaitSecs(0.5);

            [~, ~, keyCode] = KbCheck(); % must be disabled for use with
            % KbQueueCheck

           %% Check for key presses
            [skipTrial, terminate] = reactToKeyPressesAIT(keyCodes);
            if terminate
                   % Close up shop
                   exit_routineAIT(subjectCode, origin_folder, trialMat, responsesMat);
                   return
            end

            if all(ismember(g_h, find(keyCode)))       
                % Start the Trial
                measured = 0;
                stimulusTiming = 0;
                current_frame = 0;
                trialStartTime = GetSecs();
                currentPhase = 0;

                while true
                    [~, ~, keyCode] = KbCheck();
                    if ~all(ismember(g_h, find(keyCode)))
                        break;
                    end

                    elapsedTime = GetSecs() - trialStartTime;  
                    % Check for key presses
                    [skipTrial, terminate] = reactToKeyPressesAIT(keyCodes);
                    if terminate
                       % Close up shop
                       exit_routineAIT(subjectCode, origin_folder, trialMat, responsesMat);
                       return
                    end

                    %% Phase 0: Fix Cross
                    if currentPhase == 0
                        % Draw the fixation cross in black, set it to the center of screen
                        Screen('DrawLines', windowPtr, allCoords, lineWidthPix, black, [xCenter yCenter]);
                        Screen('Flip', windowPtr);
                        currentPhase = 1;
                    end

                    %% Phase 1 ECG: Get 1st R peak
                    % when fixation cross was fully shown, register the first R Peak
                    if currentPhase == 1 && elapsedTime >= currentFixDuration && ECG_Active
                        current_ECG_Status = getECGStatus(ard, inputPinNumber);
                        % do the timing with the R peak, signal is coming from the
                        % arduino
                        if current_ECG_Status == "ON"
                            RPeak_timing = GetSecs() - trialStartTime;
                            currentPhase = 2;
                        end
                    end

                    %% Phase 2: Draw the neutral starting image on the screen
                    % time = -200
                    if (currentPhase == 2 && elapsedTime >= RPeak_timing + peakDelay - .200) || ... % with ECG
                            (currentPhase == 1 && elapsedTime >= currentFixDuration && ~ECG_Active) % without ECG
                        Screen('DrawTexture', windowPtr, startTexture, [], stimulusRect);
                        Screen('Flip', windowPtr);
                        currentPhase = 3;
                    end

                    %% Phase 3: Draw the stimulus image for this trial on the screen
                    % time = 0
                    if (currentPhase == 3 && elapsedTime >= RPeak_timing + peakDelay && ECG_Active) || ... % with ECG
                            (currentPhase == 3 && elapsedTime >= currentFixDuration + .200 && ~ECG_Active) % without ECG
                        Screen('DrawTexture', windowPtr, currentTexture, [], stimulusRect);
                        % Get the timing of stimulus presentation
                        stimulusTiming = GetSecs();
                        if ECG_Active
                            % send trigger to labchart
                            sendTriggerArduinoLabchart(ard, outputPinNumber);
                        end
                        Screen('Flip', windowPtr);
                        currentPhase = 4;
                    end

                    %% Phase 4: Reaction too late
                    if currentPhase == 4 && elapsedTime >= stimulusTiming + maxReactionTime
                        currentPhase = 5;
                        break;
                    end
                end       

                Beeper();
                %% Save the result of the trial
                % Trial ended too early
                if currentPhase <= 3
                    DrawFormattedText(windowPtr, 'Sie haben den Finger zu früh gehoben.', 'center', 'center', 0, 77);
                    Screen('Flip', windowPtr);
                    WaitSecs(1);
                    continue;

                % Trial completed
                elseif currentPhase == 4
                    Screen('Flip', windowPtr);
                    responsesMat(2,expTrial(1)) = GetSecs() - stimulusTiming;
                    responsesMat(1,expTrial(1)) = responseCheck(hand, finger, keyCode);
                    WaitSecs(0.2);
                    disp(responsesMat(:,expTrial(1)));
                    WaitSecs(0.2);
                    break;

                % Reaction too late
                elseif currentPhase == 5
                    DrawFormattedText(windowPtr, 'Bitte reagieren Sie schneller.', 'center', 'center', 0, 77);
                    Screen('Flip', windowPtr);
                    responsesMat(2,expTrial(1)) = 99;
                    responsesMat(1,expTrial(1)) = responseCheck(hand, finger, keyCode);
                    WaitSecs(1);
                    break;
                end
            end
        end
        Screen('Close', currentTexture');
        WaitSecs(1);
    end
end

ListenChar();
Screen('CloseAll');
RestrictKeysForKbCheck([]);

%% DATA EXPORT 
% Close up shop
exit_routineAIT(subjectCode, origin_folder, trialMat, responsesMat);
return