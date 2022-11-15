local lastAState = car.extraA
local lastBState = car.extraB
local bmig = 0.03
local bmigMin = 0.00
local bmigMax = 0.09
local bmigRamp = 0.30

local function brakeMigration(data,dataCphys)
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

local lastCState = car.extraC
local lastDState = car.extraD
local lastEState = car.extraE

local DifferentialModes = {
    ENTRY = 0,
    MID = 1,
    HISPD = 2
}

local diffMode = DifferentialModes.ENTRY
local step = 0.01
local entryDiff = 0.15
local midDiff = 0.40
local hispdDiff = 0.60

local function midDiffSwitch(data)
    return data.speedKmh < 200 and true or false
end

local function differential(data)

    if lastCState ~= car.extraC then
        if diffMode == DifferentialModes.HISPD then
            diffMode = DifferentialModes.ENTRY
        else
            diffMode = diffMode + 1
        end
        lastCState = car.extraC
    end

    local diffValue = 0
    
    if diffMode == DifferentialModes.ENTRY then
        diffValue = entryDiff
    elseif diffMode == DifferentialModes.MID then
        diffValue = midDiff
    else
        diffValue = hispdDiff
    end

    if lastDState ~= car.extraD then
        if diffValue == 1 then
            diffValue = 0
        else
            diffValue = math.clamp(diffValue+step,0,1)
        end
        lastDState = car.extraD
    end

    if lastEState ~= car.extraE then
        if diffValue == 0 then
            diffValue = 1
        else
            diffValue = math.clamp(diffValue-step,0,1)
        end
        lastEState = car.extraE
    end

    if diffMode == DifferentialModes.ENTRY then
        entryDiff = diffValue
    elseif diffMode == DifferentialModes.MID then
        midDiff = diffValue
    else
        hispdDiff = diffValue
    end

    ac.debug('e',car.extraE)

    local exitDiff = 0
    if midDiffSwitch(data) then
        exitDiff = midDiff
    else
        exitDiff = hispdDiff
    end

    ac.debug('driver',ac.getDriverName(car.index))
    ac.debug('diffMode',diffMode)
    ac.debug('entryDiff',entryDiff)
    ac.debug('midDiff',midDiff)
    ac.debug('hispdDiff',hispdDiff)
    ac.debug('exitDiff',exitDiff)
    ac.debug('speed',data.speedKmh)

    data.controllerInputs[2] = exitDiff
    data.controllerInputs[3] = entryDiff
    data.controllerInputs[4] = midDiff
    data.controllerInputs[5] = hispdDiff
    data.controllerInputs[6] = diffMode
end

function script.update(dt)
    local data = ac.accessCarPhysics()
    local dataCphys = ac.getCarPhysics(car.index)

    brakeMigration(data,dataCphys)
    differential(data)
end