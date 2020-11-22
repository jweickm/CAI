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
% - [ ] faster while loop for searching the arduino signal:
    % draw fix
    % WaitSecs
    % search while loop
    % break
    % show stimuli 
% - [x] Umlaute auf Deutsch einfügen (ä, ö, ü)
% - [ ] handedness in export
% - [ ] more beautiful instructions would be nice

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
Fullscreen = 1;
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

nTrials = 360;
blockLength = 90;
nBlocks = nTrials/blockLength;

% 2 (congruence) x 2 (timings) x 3 pictures = incongruent index, incongruent
% middle, congruent index, congruent middle x heat beat timing

trialMat = zeros(3, nTrials);
trialMat(1,:) = randperm(nTrials);
trialMat(2,:) = repmat([1,2,3], 1, 120); % stimulus type 
trialMat(3,:) = repmat([1,2], 1, 180); % correct finger
trialMat(4,:) = [repmat([1], 1, 180), repmat([2], 1, 180)]; % synchronous or asynchronous
trialMat = sortrows(trialMat')'; 

% + practice Trials extra generieren
practiceMat = trialMat(:,randi(nTrials, 1, 12));

syncTrialDur = 1.500; % in seconds duration of sync trial
trialDuration = [syncTrialDur, syncTrialDur - 0.300]; % trial duration in s for synchronous/asynchronous trials
jitter = .2; % +- jitter in seconds

% delay between R peak and stimulus presentation 
syncDur = 0.250; % in synchronous trials
asyncDur = 0.550; % in asynchronous trials

% preallocate responsesMat
responsesMat = zeros(3,nTrials);

%% Set up keys

% provide a consistent mapping of keyCodes to key names on all operating systems.
KbName('UnifyKeyNames');

% keyCodes: [Space, Return, Escape, G, H, X, P]
abortExpKey = 'ESCAPE';
pauseKey = 'P';
abortBlockKey = 'X';
keyCodes = [KbName('SPACE'), KbName('RETURN'), KbName(abortExpKey), ...
    KbName(abortBlockKey), KbName(pauseKey), KbName('G'), KbName('H')];


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
match_g_h = zeros(1,256);
match_g_h(KbName({'g', 'h'})) = 1;
ListenChar(2); % suppress listening to Matlab
oldenablekeys = RestrictKeysForKbCheck([keyCodes]);
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
    
    current_jitter = (rand(1) * 2 * jitter) - jitter; % jitter 
    
    trial_frames = currentTrialDur/ifi + current_jitter/ifi; % fixation cross duration in frames
    max_frames = (currentTrialDur + 1.5)/ifi; % maximum trial duration
    
    if practiceTrial(4) == 1 % synchronous trial
        peak_frames = syncDur / ifi;
    elseif practiceTrial(4) == 2 % asynchronous trial
        peak_frames = asyncDur / ifi;
    end
    
    while true
        DrawFormattedText(windowPtr, 'Drücken und halten Sie [G] und [H]', 'center', 'center', 0, 77);
        Screen('Flip', windowPtr);
        WaitSecs(0.2);
        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
        
       %% Check for key presses
        [skipTrial, terminate] = reactToKeyPressesAIT(keyCodes);
        if terminate
               % Close up shop
               exit_routineAIT(subjectCode, origin_folder, trialMat, responsesMat);
               return
        end
            
        if isequal(keyCode, match_g_h)           
            measured = 0;
            startTime = 0;
            current_frame = 0;
            
            while true
                %% Check for key presses
                [skipTrial, terminate] = reactToKeyPressesAIT(keyCodes);
                if terminate
                   % Close up shop
                   exit_routineAIT(subjectCode, origin_folder, trialMat, responsesMat);
                   return
                end
                %% -------------------------------------
                    
                current_frame = current_frame + 1;
                if ECG_Active
                    current_ECG_Status = getECGStatus(ard, inputPinNumber);
                    % do the timing with the R peak, signal is coming from the
                    % arduino
                    
                    % when fixation cross was fully shown and the first R
                    % peak is registered
                    if (current_frame >= trial_frames) && (current_ECG_Status == "ON") && (measured == 0)
                        RPeak_timing = current_frame;
                        measured = 1;
                    end
                    
                    if RPeak_timing > 0 && current_frame >= (RPeak_timing + peak_frames + 2.0/ifi) % if 2 seconds passed after stimulus was shown
                        reactedTooLate = 1; % abort the trial and feedback that the reaction was too slow
                        break;
                    
                    elseif RPeak_timing > 0 && current_frame >= (RPeak_timing + peak_frames)
                        % timing of stimulus drawing
                        % Draw the image for this trial on the screen
                        % time = 0
                        Screen('DrawTexture', windowPtr, currentTexture, [], stimulusRect);
                        
                        % Get the timing of stimulus presentation
                        if startTime == 0
                            startTime = GetSecs();
                            % send trigger to labchart
                            sendTriggerArduinoLabchart(ard, outputPinNumber);
                        end
                        
                        Screen('Flip', windowPtr);
                        
                        % Check that both keys are still down
                        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
                        if ~isequal(keyCode, match_g_h) 
                            completed = 1;
                            break;
                        end
                        
                    elseif RPeak_timing > 0 && current_frame >= (RPeak_timing + peak_frames - 0.200/ifi)
                        % Check that both keys are still down
                        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
                        if ~isequal(keyCode, match_g_h) 
                            earlyRelease = 1;
                            break;
                        end
                        % Draw the neutral starting image on the screen
                        % time = -200
                        Screen('DrawTexture', windowPtr, startTexture, [], stimulusRect);
                        Screen('Flip', windowPtr);
                        
                    else   
                        % Check that both keys are still down
                        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
                        if ~isequal(keyCode, match_g_h) 
                            earlyRelease = 1;
                            break;
                        end
                        % Draw the fixation cross in black, set it to the center of screen
                        Screen('DrawLines', windowPtr, allCoords, lineWidthPix, black, [xCenter yCenter]);
                        Screen('Flip', windowPtr);
                    end 
                    
                else % no ARDUINO
                    
                    if current_frame >= (trial_frames + peak_frames + 2.0/ifi) % if 2 seconds passed after stimulus was shown
                        reactedTooLate = 1; % abort the trial and feedback that the reaction was too slow
                        break;

                    elseif current_frame >= (trial_frames + peak_frames)
                        % timing of stimulus drawing
                        % Draw the image for this trial on the screen
                        % time = 0
                        Screen('DrawTexture', windowPtr, currentTexture, [], stimulusRect);
                        
                        % Get the timing of stimulus presentation
                        if startTime == 0
                            startTime = GetSecs();
                        end
                        
                        Screen('Flip', windowPtr);
                        
                        % Check that both keys are still down
                        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
                        if ~isequal(keyCode, match_g_h) 
                            completed = 1;
                            break;
                        end
                        
                    elseif current_frame >= (trial_frames + peak_frames - 0.200/ifi)
                        % Draw the neutral starting image on the screen
                        % time = -200
                        Screen('DrawTexture', windowPtr, startTexture, [], stimulusRect);
                        Screen('Flip', windowPtr);
                        % Check that both keys are still down
                        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
                        if ~isequal(keyCode, match_g_h) 
                            earlyRelease = 1;
                            break;
                        end
                        
                    else
                        % Draw the fixation cross in black, set it to the center of screen
                        Screen('DrawLines', windowPtr, allCoords, lineWidthPix, black, [xCenter yCenter]);
                        Screen('Flip', windowPtr);
                        
                        % Check that both keys are still down
                        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
                        if ~isequal(keyCode, match_g_h) 
                            earlyRelease = 1;
                            break;
                        end
                    end 
                end
            end
            
            if earlyRelease
                DrawFormattedText(windowPtr, 'Sie haben den Finger zu früh gehoben.', 'center', 'center', 0, 77);
                Screen('Flip', windowPtr);
                responsesMat(2,practiceTrial(1)) = NaN;
                responsesMat(1,practiceTrial(1)) = responseCheck(hand, finger, keyCode);
                WaitSecs(1);
                break;
                
            elseif reactedTooLate
                DrawFormattedText(windowPtr, 'Bitte reagieren Sie schneller.', 'center', 'center', 0, 77);
                Screen('Flip', windowPtr);
                responsesMat(2,practiceTrial(1)) = 99;
                responsesMat(1,practiceTrial(1)) = responseCheck(hand, finger, keyCode);
                WaitSecs(1);
                break;
                
            elseif completed
                % disp(finger); % output the correct response to the terminal
                Screen('Flip', windowPtr);
                responsesMat(2,practiceTrial(1)) = GetSecs() - startTime;
                responsesMat(1,practiceTrial(1)) = responseCheck(hand, finger, keyCode);
                
                WaitSecs(0.2);
                disp(responsesMat(:,practiceTrial(1)));
                WaitSecs(0.2);
                break;
            end
        end
    end
    Screen('Close', currentTexture);
end

% Display message
DrawFormattedText(windowPtr, 'Dies ist das Ende der Übungstrials.', 'center', 'center', 0, 77);
Screen('Flip', windowPtr);
disp('Press SPACEBAR or ENTER to continue.');
WaitSecs(1);
KbWait();
    
%% =======================================
% EXPERIMENTAL BLOCKS
% =============================================
for block = 1:nBlocks
    startTrialID = (block-1) + 1;
    endTrialID   = block * blockLength;
    for expTrial = trialMat(:,startTrialID : endTrialID)
        
        currentTrialDur = trialDuration(expTrial(4)); % 1 if synchronous, 2 if asynchronous         
        currentTexture = Screen('MakeTexture', windowPtr, images{expTrial(3),expTrial(2)});

        % disp('Press G and H');
        keyCode = zeros(1, 256);
        finger = expTrial(3);

        completed = 0;
        earlyRelease = 0;
        reactedTooLate = 0;
        RPeak_timing = 0;

        current_jitter = (rand(1) * 2 * jitter) - jitter; % jitter
        disp(['Dur: ', num2str(currentTrialDur + current_jitter)]);
        responsesMat(3, expTrial(1)) = currentTrialDur + current_jitter;
        trial_frames = currentTrialDur/ifi + current_jitter/ifi; % fixation cross duration in frames
        max_frames = (currentTrialDur + 1.5)/ifi; % maximum trial duration

        if expTrial(4) == 1 % synchronous trial
            peak_frames = syncDur / ifi;
            disp('sync trial');
        elseif expTrial(4) == 2 % asynchronous trial
            peak_frames = asyncDur / ifi;
            disp('async trial');
        end

        while true
            DrawFormattedText(windowPtr, 'Drücken und halten Sie [G] und [H]', 'center', 'center', 0, 77);
            Screen('Flip', windowPtr);
            WaitSecs(0.2);
            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
            
           %% Check for key presses
            [skipTrial, terminate] = reactToKeyPressesAIT(keyCodes);
            if terminate
                   % Close up shop
                   exit_routineAIT(subjectCode, origin_folder, trialMat, responsesMat);
                   return
            end
           %%
            if isequal(keyCode, match_g_h)           
                measured = 0;
                startTime = 0;
                current_frame = 0;
                
                buttonPressTiming = GetSecs();
                
                while true 
                    %% Check for key presses
                    [skipTrial, terminate] = reactToKeyPressesAIT(keyCodes);
                    if terminate
                       % Close up shop
                       exit_routineAIT(subjectCode, origin_folder, trialMat, responsesMat);
                       return
                    end
                    %%
                    
                    current_frame = current_frame + 1;
                    
                    if ECG_Active
                        current_ECG_Status = getECGStatus(ard, inputPinNumber);
                        
                        if current_frame >= trial_frames && measured == 0
                        % send trigger to labchart
                            sendTriggerArduinoLabchart(ard, outputPinNumber);
                        end
                        
                        
                        % Get the first R peak that is measured after the
                        % fixation cross duration has completed
                        if (current_frame >= trial_frames) && (current_ECG_Status == "ON") && (measured == 0)
                            RPeak_timing = current_frame;
                            measured = 1; % will only be executed once
                            % send trigger to labchart
                            sendTriggerArduinoLabchart(ard, outputPinNumber);
                        end
                        
                        % if 2 seconds passed after stimulus was shown
                        if RPeak_timing > 0 && current_frame >= (RPeak_timing + peak_frames + 2.0/ifi) 
                            reactedTooLate = 1; % abort the trial and feedback that the reaction was too slow
                            break;
                        
                        elseif RPeak_timing > 0 && current_frame >= (RPeak_timing + peak_frames)
                            % timing of stimulus drawing
                            % Draw the image for this trial on the screen
                            % time = 0
                            Screen('DrawTexture', windowPtr, currentTexture, [], stimulusRect);

                            % Get the first timing of stimulus presentation
                            if startTime == 0
                                startTime = GetSecs();
                                % send trigger to labchart
                                sendTriggerArduinoLabchart(ard, outputPinNumber);
                                disp(num2str(buttonPressTiming - GetSecs()));
                            end
                            Screen('Flip', windowPtr);
                            % Check that both keys are still down
                            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
                            if ~isequal(keyCode, match_g_h) 
                                completed = 1;
                                break;
                            end

                        elseif RPeak_timing > 0 && current_frame >= (RPeak_timing + peak_frames - 0.200/ifi)
                            % Check that both keys are still down
                            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
                            if ~isequal(keyCode, match_g_h) 
                                earlyRelease = 1;
                                break;
                            end
                            % Draw the neutral starting image on the screen
                            % time = -200
                            Screen('DrawTexture', windowPtr, startTexture, [], stimulusRect);
                            Screen('Flip', windowPtr);

                        else   
                            % Check that both keys are still down
                            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
                            if ~isequal(keyCode, match_g_h) 
                                earlyRelease = 1;
                                break;
                            end
                            % Draw the fixation cross in black, set it to the center of screen
                            Screen('DrawLines', windowPtr, allCoords, lineWidthPix, black, [xCenter yCenter]);
                            Screen('Flip', windowPtr);
                        end 

                    else % no ARDUINO
                        
                        if current_frame >= (trial_frames + peak_frames + 2.0/ifi) % if 2 seconds passed after stimulus was shown
                            reactedTooLate = 1; % abort the trial and feedback that the reaction was too slow
                            break;
                        
                        elseif current_frame >= (trial_frames + peak_frames)
                            % timing of stimulus drawing
                            % Draw the image for this trial on the screen
                            % time = 0
                            Screen('DrawTexture', windowPtr, currentTexture, [], stimulusRect);

                            % Get the timing of stimulus presentation
                            if startTime == 0
                                startTime = GetSecs();
                            end

                            Screen('Flip', windowPtr);

                            % Check that both keys are still down
                            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
                            if ~isequal(keyCode, match_g_h) 
                                completed = 1;
                                break;
                            end

                        elseif current_frame >= (trial_frames + peak_frames - 0.200/ifi)
                            % Draw the neutral starting image on the screen
                            % time = -200
                            Screen('DrawTexture', windowPtr, startTexture, [], stimulusRect);
                            Screen('Flip', windowPtr);
                            % Check that both keys are still down
                            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
                            if ~isequal(keyCode, match_g_h) 
                                earlyRelease = 1;
                                break;
                            end

                        else
                            % Draw the fixation cross in black, set it to the center of screen
                            Screen('DrawLines', windowPtr, allCoords, lineWidthPix, black, [xCenter yCenter]);
                            Screen('Flip', windowPtr);

                            % Check that both keys are still down
                            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck();
                            if ~isequal(keyCode, match_g_h) 
                                earlyRelease = 1;
                                break;
                            end
                        end 
                    end
                end

                if earlyRelease
                    DrawFormattedText(windowPtr, 'Sie haben den Finger zu früh gehoben.', 'center', 'center', 0, 77);
                    Screen('Flip', windowPtr);
                    responsesMat(2,practiceTrial(1)) = 77;
                    responsesMat(1,practiceTrial(1)) = responseCheck(hand, finger, keyCode);
                    WaitSecs(1);
                    break;
                
                elseif reactedTooLate
                    DrawFormattedText(windowPtr, 'Bitte reagieren Sie schneller.', 'center', 'center', 0, 77);
                    Screen('Flip', windowPtr);
                    responsesMat(2,expTrial(1)) = 99;
                    responsesMat(1,expTrial(1)) = responseCheck(hand, finger, keyCode);
                    WaitSecs(1);
                    break;
                    
                elseif completed
                    disp(finger); % output the correct response to the terminal
                    Screen('Flip', windowPtr);
                    responsesMat(2,expTrial(1)) = GetSecs() - startTime;
                    responsesMat(1,expTrial(1)) = responseCheck(hand, finger, keyCode);
                    WaitSecs(0.2);
                    disp(responsesMat(:,expTrial(1)));
                    WaitSecs(0.2);
                    break;
                end
            end
        end
        Screen('Close', currentTexture);
    end
    % Display message
    DrawFormattedText(windowPtr, pauseText, 'center', 'center', 0, 77);
    Screen('Flip', windowPtr);
    disp('Press SPACEBAR or ENTER to continue.');
    WaitSecs(1);
    KbWait();
end

ListenChar();
Screen('CloseAll');
RestrictKeysForKbCheck([]);

%% DATA EXPORT 
% Close up shop
exit_routineAIT(subjectCode, origin_folder, trialMat, responsesMat);
return
