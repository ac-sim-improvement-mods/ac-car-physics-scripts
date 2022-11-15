local brakemigration = {}

local lastAState = car.extraA
local lastBState = car.extraB
local bmig = 0.03
local bmigMin = 0.00
local bmigMax = 0.09
local bmigRamp = 0.30

function brakemigration.control(data,dataCphys)
    data.brake = 1
    data.gas = 0

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

    local brakeBiasBase = car.brakeBias
    local brakeBiasTotal = brakeBiasBase + ((math.clamp(data.brake-bmigRamp,0,1)/(1-bmigRamp)) * bmig * brakeBiasBase)
    local bmigCalc = math.round((brakeBiasTotal - brakeBiasBase) / brakeBiasBase * 100,0)
    local torqueFront = dataCphys.wheels[0].brakeTorque + dataCphys.wheels[1].brakeTorque
    local torqueRear = dataCphys.wheels[2].brakeTorque + dataCphys.wheels[3].brakeTorque
    local torqueTotal = torqueFront + torqueRear
    local brakeBiasActual = torqueFront/torqueTotal
    local bbdiff = brakeBiasTotal-brakeBiasActual

    ac.debug('bba',brakeBiasActual)
    ac.debug('bmigCalc',bmigCalc)
    ac.debug('bbdiff',bbdiff)
    ac.debug('bbb',brakeBiasBase)
    ac.debug('bbt',brakeBiasTotal)
    ac.debug('torqueTotal',torqueTotal)

    data.controllerInputs[0] = brakeBiasTotal
    data.controllerInputs[1] = bmig * 100
end

return brakemigration
