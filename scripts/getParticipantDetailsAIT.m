% Written by Jakob Weickmann

function [subjectCode, handedness] = getParticipantDetailsAIT()

prompt1 = 'Please enter the participant ID (integer):\n';
subjectCode = [];
prompt2 = 'Participant''s handedness (R/L)\n';
handedness = [];
righthanded = ["R", "r", "right", "rechts", "Right", "Rechtshändig", "rechtshändig"];
yes = ["y", "Y", "yes", "Yes", "YES", "absolutely"];

while true
    try subjectCode = input(prompt1);
        subjectString = strcat('./output/Subject_', sprintf('%02s', num2str(subjectCode)), '.mat'); % to pad the subjectCode with zeroes if necessary
        if exist(subjectString, 'file')
            fprintf(repmat('\b',1, 1 + length(num2str(subjectCode))));
            fprintf('Subject %02d already exists.\n\n', subjectCode);
            if ~ismember(input('Do you really want to continue? (Y/N)\n', 's'), yes)
                subjectCode = [];
                fprintf(repmat('\b',1, 40));
                continue;
            end
            fprintf(repmat('\b',1, 40));
        else
            fprintf(repmat('\b',1, 1 + length(num2str(subjectCode))));
        end

        while true
            try handednessString = input(prompt2, 's');
                if ismember(handednessString, righthanded)
                    handedness = 1;
                    handstr = 'right-handed';
                else 
                    handedness = 2;
                    handstr = 'left-handed';
                end
                    fprintf(repmat('\b',1, 1 + length(num2str(handednessString))));
                    break;                      
            catch
                warning('Input must be a string indicating handedness.');
                handedness = [];
                continue;
            end
        end

            fprintf('\n----------------------------');            
            fprintf(['\nParticipant ID: %2d\n'...
                       'Handedness: %6d (%s)\n'], subjectCode, handedness, handstr);


        if ismember(input('Is that correct? (Y/N)\n', 's'), yes)
            fprintf(repmat('\b',1, 25));
            disp('============================');
            break;
        else
            subjectCode = [];
            handedness = [];
            fprintf('\b\b');
            disp('----------------------------');
            continue;
        end
    catch
        warning('ID must be an integer.');
    end
end

return