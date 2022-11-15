local differential = {}

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

function differential.control(data,dataCphys)

    if lastEState ~= car.extraC then
        if diffMode == DifferentialModes.HISPD then
            diffMode = DifferentialModes.ENTRY
        else
            diffMode = diffMode + 1
        end
        lastEState = car.extraC
    end

    local diffValue = 0
    if diffMode == DifferentialModes.ENTRY then
        diffValue = entryDiff
    elseif diffMode == DifferentialModes.MID then
        diffValue = midDiff
    else
        diffValue = hispdDiff
    end

    if lastCState ~= car.extraD then
        if diffValue == 1 then
            diffValue = 0
        else
            diffValue = math.clamp(diffValue+step,0,1)
        end
        lastCState = car.extraD
    end

    if lastDState ~= car.extraE then
        if diffValue == 0 then
            diffValue = 1
        else
            diffValue = math.clamp(diffValue-step,0,1)
        end
        lastDState = car.extraE
    end

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
    
    data.controllerInputs[2] = entryDiff
    data.controllerInputs[3] = exitDiff
end

return differential
