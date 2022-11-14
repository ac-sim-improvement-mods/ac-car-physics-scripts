local lastAState = false
local lastBState = false
local bmig = 0.03
local bmigMax = 0.09
local bmigMin = 0.00
local bmigRamp = 0.30

local math = math

local function controlBrakeBias(data)
    local dataCphys = ac.getCarPhysics(car.index)

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

    if car.isAIControlled then
        bmigRamp = 0.3
        bmig = 0.03
    end

    local brakeBiasBase = car.brakeBias * 100
    local brakeBiasTotal = (brakeBiasBase + ((math.clamp(data.brake-bmigRamp,0,1)/(1-bmigRamp)) * bmig * brakeBiasBase)) * 100
    -- local bmigCalc = math.round((brakeBiasTotal - brakeBiasBase) / brakeBiasBase * 100,0)
    local torqFront = dataCphys.wheels[0].brakeTorque + dataCphys.wheels[1].brakeTorque
    local torqRear = dataCphys.wheels[2].brakeTorque + dataCphys.wheels[3].brakeTorque
    local torqueTotal = torqFront + torqRear
    local brakeBiasActual = torqFront/torqueTotal*100
    local bbdiff = brakeBiasTotal-brakeBiasActual

    data.controllerInputs[0] = brakeBiasTotal / 100
    data.controllerInputs[1] = bmig * 100
end

function script.update(dt)
    local data = ac.accessCarPhysics()

    controlBrakeBias(data)
end