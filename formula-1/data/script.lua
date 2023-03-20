local lastAState = car.extraA
local lastBState = car.extraB
local bmig = 0.03
local bmigMin = 0.00
local bmigMax = 0.09
local bmigRamp = 0.30

local function brakeMigration(data, dataCphys)
	if lastAState ~= car.extraA then
		if bmig == bmigMax then
			bmig = bmigMin
		else
			bmig = math.clamp(bmig + 0.01, bmigMin, bmigMax)
		end
		lastAState = car.extraA
	end
	if lastBState ~= car.extraB then
		if bmig == bmigMin then
			bmig = bmigMax
		else
			bmig = math.clamp(bmig - 0.01, bmigMin, bmigMax)
		end
		lastBState = car.extraB
	end

	local brakeBiasBase = car.brakeBias
	local brakeBiasTotal = brakeBiasBase + math.clamp((data.brake - bmigRamp), 0, 1) / (1 - bmigRamp) * bmig
	local torqueFront = dataCphys.wheels[0].brakeTorque + dataCphys.wheels[1].brakeTorque
	local torqueRear = dataCphys.wheels[2].brakeTorque + dataCphys.wheels[3].brakeTorque
	local torqueTotal = torqueFront + torqueRear
	local brakeBiasActual = torqueFront / torqueTotal
	local bbdiff = brakeBiasTotal - brakeBiasActual

	-- ac.debug("bmig.bba", brakeBiasActual)
	-- ac.debug("bmig.bbdiff", bbdiff)
	-- ac.debug("bmig.bbb", brakeBiasBase)
	-- ac.debug("bmig.bbt", brakeBiasTotal)
	-- ac.debug("bmig.torqueTotal", torqueTotal)
	-- ac.debug("state.a", car.extraA)
	-- ac.debug("state.b", car.extraB)

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
local step = 9.090909090909091
local entryDiff = 5
local midDiff = 75
local hispdDiff = 90

local function hispdDiffSwitch(data)
	local groundSpeed = car.speedKmh
	local longAccel = car.acceleration.z
	local isHispd = false
	if longAccel > 0 then
		isHispd = true
	elseif groundSpeed > 185 or groundSpeed < 1 then
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
	local diffMaxValue = 100

	if diffMode == DifferentialModes.ENTRY then
		diffValue = entryDiff
	elseif diffMode == DifferentialModes.MID then
		diffValue = midDiff
	elseif diffMode == DifferentialModes.HISPD then
		diffValue = hispdDiff
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

	-- ac.debug("car.driver", ac.getDriverName(car.index))
	-- ac.debug("script.diff.mode", diffMode)
	-- ac.debug("script.diff.entry", entryDiff)
	-- ac.debug("script.diff.mid", midDiff)
	-- ac.debug("script.diff.hispd", hispdDiff)
	-- ac.debug("script.diff.exit", exitDiff)
	-- ac.debug("car.speed", data.speedKmh)
	-- ac.debug("data.diff.coast", car.differentialCoast)
	-- ac.debug("data.diff.power", car.differentialPower)
	-- ac.debug("state.c", car.extraC)
	-- ac.debug("state.d", car.extraD)
	-- ac.debug("state.e", car.extraE)

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
