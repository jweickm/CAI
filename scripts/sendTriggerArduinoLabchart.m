function sendTriggerArduinoLabchart(ard, outputPinNumber)
    %SENDTRIGGERARDUINOLABCHART sends trigger to labchart using arduino's analog out 
    writeDigitalPin(ard, outputPinNumber, true);
    writeDigitalPin(ard, outputPinNumber, false);
end

