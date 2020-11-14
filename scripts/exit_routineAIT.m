% Written by Jakob Weickmann
function[] = exit_routineAIT(subjectCode, origin_folder, trialMat, responsesMat)
    ListenChar();
    Screen('CloseAll');
    
   % Save Data
    disp('Saving output data to ./output/...');
    
    
    TrialMatConcat = [trialMat', responsesMat'];
    
    U = array2table(TrialMatConcat);
    U.Properties.VariableNames = {'Trial', 'StimulusType_Con_1_Inc_2_Nt_3', 'CorrectFinger', 'Sync_1_Async_2', 'ResponseCorrect', 'ReactionTime', 'FiXDuration'};
    U.Properties.Description = strcat('Output Data for Subject', sprintf(' %02s', num2str(subjectCode)));
    % U = addvars(U, trialDuration(1,:)', trialDuration(2,:)', trialDuration(3,:)', trialDuration(4,:)', 'NewVariableNames', {'TrialOnset', 'AttentionGrabberDuration', 'StimulusDuration', 'FixationPercent'});
    
    disp('Please wait...');
    subjectString = strcat('Subject_', sprintf('%02s', num2str(subjectCode))); % to pad the subjectCode with zeroes if necessary 
    save(strcat('./Output/', subjectString, '.mat'),  'trialMat', 'responsesMat'); 
    % this saves all the above variables to a file called Subject_.mat
    % and to a CSV file
    if exist(strcat('./output/', subjectString, '.csv'), 'file')
        delete(strcat('./output/', subjectString, '.csv'));
    end
    writetable(U, strcat('./output/', subjectString, '.csv'));
    disp('Saved successfully.');
    
   % Close up shop
    sca;
    clear Screen;
    ShowCursor();
    RestrictKeysForKbCheck([]);
    disp('End of Experiment. Please stop recording.')
    cd(origin_folder);
return