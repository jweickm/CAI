% Function to calculate the RRi (R-peak - R-peak - interval)

function [RRi] = getRRI(ard, inputPinNumber, duration)
startTime = GetSecs();
last_ECG_Status = [];
counter = 0;

% preallocate the array
array = zeros(1, 2*duration);

while true
    if GetSecs() - startTime >= duration
        break;
    end
    current_ECG_Status = getECGStatus(ard, inputPinNumber);
    % add a 'warmup' to avoid starting during an R-peak
    if counter == 0
        if current_ECG_Status == "OFF"
            counter = 1;
        end
    else
        if current_ECG_Status == "ON" && last_ECG_Status == "OFF"
            array(counter) = GetSecs();
            counter = counter + 1;
        end
    end
            
        
            
            
end

return