local brakemigration = {}

local lastAState = car.extraA
local lastBState = car.extraB
local bmig = 0.03
local bmigMin = 0.00
local bmigMax = 0.09
local bmigRamp = 0.30

function brakemigration.control(data,dataCphys)
    if lastAState ~= car.extraA then
        if bmig == bmigMax then
            bmig = bmigMin
        else
            bmig = math.clamp(bmig+0.01,bmigMin,bmigMax)
        end
        lastAState = car.extraA
    end

    if lastBState ~= car.extraB then
        if bmig == bmigMin then
            bmig = bmigMax
        else
            bmig = math.clamp(bmig-0.01,bmigMin,bmigMax)
        end
        lastBState = car.extraB
    end

    local brakeBiasBase = car.brakeBias * 100
    local brakeBiasTotal = brakeBiasBase + ((math.clamp(data.brake-bmigRamp,0,1)/(1-bmigRamp)) * bmig * brakeBiasBase)
    -- local bmigCalc = math.round((brakeBiasTotal - brakeBiasBase) / brakeBiasBase * 100,0)
    local torqueFront = dataCphys.wheels[0].brakeTorque + dataCphys.wheels[1].brakeTorque
    local torqueRear = dataCphys.wheels[2].brakeTorque + dataCphys.wheels[3].brakeTorque
    local torqueTotal = torqueFront + torqueRear
    local brakeBiasActual = torqueFront/torqueTotal*100
    local bbdiff = (brakeBiasTotal*100)-brakeBiasActual

    data.controllerInputs[0] = brakeBiasTotal
    data.controllerInputs[1] = bmig * 100
end

return brakemigration
