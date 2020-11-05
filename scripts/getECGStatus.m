% ard := Arduino, pinNumber = Analog pin that is connected to powerlab (ie 'A0')
function status = getECGStatus(ard, pinNumber)
    voltage = readVoltage(ard, pinNumber);
    if voltage > 0.1
        status = "ON";
    else
        status = "OFF";
    end
end

