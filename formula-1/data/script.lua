local lastAState = car.extraA
local lastBState = car.extraB
local bmig = 0
local bmigMin = 0
local bmigMax = 0
local bmigRamp = 0

local function brakeMigration(data, dataCphys)
	if lastAState ~= car.extraA then
		if bmig == bmigMax then
			bmig = bmigMin
		else
			bmig = math.clamp(bmig + 0, bmigMin, bmigMax)
		end
		lastAState = car.extraA
	end
	if lastBState ~= car.extraB then
		if bmig == bmigMin then
			bmig = bmigMax
		else
			bmig = math.clamp(bmig - 0, bmigMin, bmigMax)
		end
		lastBState = car.extraB
	end

	local brakeBiasBase = car.brakeBias
	local brakeBiasTotal = brakeBiasBase + math.clamp((data.brake - bmigRamp), 0, 1) / (1 - bmigRamp) * bmig
	local bmigCalc = math.round((brakeBiasTotal - brakeBiasBase) / brakeBiasBase * 100, 0)
	local torqueFront = dataCphys.wheels[0].brakeTorque + dataCphys.wheels[1].brakeTorque
	local torqueRear = dataCphys.wheels[2].brakeTorque + dataCphys.wheels[3].brakeTorque
	local torqueTotal = torqueFront + torqueRear
	local brakeBiasActual = torqueFront / torqueTotal
	local bbdiff = brakeBiasTotal - brakeBiasActual

	-- ac.debug("bba", brakeBiasActual)
	-- ac.debug("bmigCalc", bmigCalc)
	-- ac.debug("bbdiff", bbdiff)
	-- ac.debug("bbb", brakeBiasBase)
	-- ac.debug("bbt", brakeBiasTotal)
	-- ac.debug("torqueTotal", torqueTotal)

	data.controllerInputs[0] = brakeBiasTotal
	data.controllerInputs[1] = bmig * 100
end

local lastCState = car.extraC
local lastDState = car.extraD
local lastEState = car.extraE

local DifferentialModes = {
	ENTRY = 0,
	MID = 1,
	HISPD = 2,
}

local diffMode = DifferentialModes.ENTRY
local step = 5
local entryDiff = 5
local midDiff = 75
local hispdDiff = 90

local function hispdDiffSwitch(data)
	local groundSpeed = car.speedKmh
	local longAccel = car.acceleration.z
	local isHispd = false
	if longAccel > 0 then
		isHispd = true
	elseif groundSpeed > 185 then
		isHispd = true
	end
	return isHispd
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
	local diffMinValue = 0
	local diffMaxValue = 1

	if diffMode == DifferentialModes.ENTRY then
		diffValue = entryDiff
		diffMinValue = 0
		diffMaxValue = 55
	elseif diffMode == DifferentialModes.MID then
		diffValue = midDiff
		diffMinValue = 45
		diffMaxValue = 100
	elseif diffMode == DifferentialModes.HISPD then
		diffValue = hispdDiff
		diffMinValue = 45
		diffMaxValue = 100
	end

	if lastDState ~= car.extraD then
		diffValue = math.clamp(diffValue + step, diffMinValue, diffMaxValue)
		lastDState = car.extraD
	end
	if lastEState ~= car.extraE then
		diffValue = math.clamp(diffValue - step, diffMinValue, diffMaxValue)
		lastEState = car.extraE
	end

	if diffMode == DifferentialModes.ENTRY then
		entryDiff = diffValue
	elseif diffMode == DifferentialModes.MID then
		midDiff = diffValue
	elseif diffMode == DifferentialModes.HISPD then
		hispdDiff = diffValue
	end

	local exitDiff = 0
	if hispdDiffSwitch(data) then
		exitDiff = hispdDiff
	else
		exitDiff = midDiff
	end

	-- ac.debug("driver", ac.getDriverName(car.index))
	-- ac.debug("diffMode", diffMode)
	-- ac.debug("entry", entryDiff)
	-- ac.debug("mid", midDiff)
	-- ac.debug("hispd", hispdDiff)
	-- ac.debug("exit", exitDiff)
	-- ac.debug("speed", data.speedKmh)
	-- ac.debug("coast", car.differentialCoast)
	-- ac.debug("power", car.differentialPower)

	data.controllerInputs[2] = exitDiff
	data.controllerInputs[3] = entryDiff
	data.controllerInputs[4] = midDiff
	data.controllerInputs[5] = hispdDiff
	data.controllerInputs[6] = diffMode
end

function script.update(dt)
	local data = ac.accessCarPhysics()
	local dataCphys = ac.getCarPhysics(car.index)
	brakeMigration(data, dataCphys)
	differential(data)
end
