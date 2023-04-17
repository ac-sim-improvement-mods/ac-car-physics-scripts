local connection = ac.connect({
	ac.StructItem.key("ext_car_" .. car.index),
	brakeBiasBase = ac.StructItem.float(),
	brakeBiasFine = ac.StructItem.float(),
	brakeMigration = ac.StructItem.float(),
	brakeMigrationRamp = ac.StructItem.float(),
	diffEntry = ac.StructItem.float(),
	diffMid = ac.StructItem.float(),
	diffHispd = ac.StructItem.float(),
}, true, ac.SharedNamespace.CarScript)

local DifferentialModes = {
	ENTRY = 0,
	MID = 1,
	HISPD = 2,
}

local lastExtraA = car.extraA
local lastExtraB = car.extraB
local lastExtraC = car.extraC
local lastExtraD = car.extraD
local lastExtraE = car.extraE

local bmig = 4
local bmigMin = 1
local bmigMax = 10
local bmigRamp = 30
local brakeBiasFine = 0
local brakeBiasFineMin = 0
local brakeBiasFineMax = 9
local brakeBiasBase = car.brakeBias

local function brakeMigration(data)
	if bmig ~= connection.brakeMigration then
		bmig = connection.brakeMigration
	end
	if bmigRamp ~= connection.brakeMigrationRamp then
		bmigRamp = connection.brakeMigrationRamp
	end
	if brakeBiasFine ~= connection.brakeBiasFine then
		brakeBiasFine = connection.brakeBiasFine
	end

	if lastExtraA ~= car.extraA then
		if ac.isJoystickButtonPressed(0, 0) then
			brakeBiasFine = math.clamp(brakeBiasFine + 1, brakeBiasFineMin, brakeBiasFineMax)
		else
			if bmig == bmigMax then
				bmig = bmigMin
			else
				bmig = math.clamp(bmig + 1, bmigMin, bmigMax)
			end
		end
		lastExtraA = car.extraA
	end

	if lastExtraB ~= car.extraB then
		if ac.isJoystickButtonPressed(0, 0) then
			brakeBiasFine = math.clamp(brakeBiasFine - 1, brakeBiasFineMin, brakeBiasFineMax)
		else
			if bmig == bmigMin then
				bmig = bmigMax
			else
				bmig = math.clamp(bmig - 1, bmigMin, bmigMax)
			end
		end
		lastExtraB = car.extraB
	end

	brakeBiasBase = car.brakeBias + (brakeBiasFine / 1000)

	local brakeBiasTotal = brakeBiasBase
		+ math.clamp((data.brake - (bmigRamp / 100)), 0, 1) / (1 - (bmigRamp / 100)) * ((bmig - 1) / 100)
	-- local torqueFront = dataCphys.wheels[0].brakeTorque + dataCphys.wheels[1].brakeTorque
	-- local torqueRear = dataCphys.wheels[2].brakeTorque + dataCphys.wheels[3].brakeTorque
	-- local torqueTotal = torqueFront + torqueRear
	-- local brakeBiasActual = torqueFront / torqueTotal
	-- local bbdiff = brakeBiasTotal - brakeBiasActual

	-- ac.debug("bb.bba", brakeBiasActual)
	-- ac.debug("bb.bbdiff", bbdiff)
	-- ac.debug("bb.base", math.round(brakeBiasBase * 100, 1))
	-- ac.debug("bb.fine", brakeBiasFine)
	-- ac.debug("bb.total", math.round(brakeBiasTotal * 100, 1))
	-- ac.debug("bb.mig", bmig)
	-- ac.debug("bb.mig.ramp", bmigRamp)
	-- -- ac.debug("bb.torqueTotal", torqueTotal)
	-- ac.debug("state.a", car.extraA)
	-- ac.debug("state.b", car.extraB)

	connection.brakeMigration = bmig
	connection.brakeBiasBase = brakeBiasBase
	connection.brakeBiasFine = brakeBiasFine
	data.controllerInputs[0] = brakeBiasTotal
	data.controllerInputs[1] = bmig
end

local diffMode = DifferentialModes.ENTRY
local entryDiff = 1
local midDiff = 4
local hispdDiff = 5

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
	if entryDiff ~= connection.diffEntry then
		entryDiff = connection.diffEntry
	end
	if midDiff ~= connection.diffMid then
		midDiff = connection.diffMid
	end
	if hispdDiff ~= connection.diffHispd then
		hispdDiff = connection.diffHispd
	end

	if lastExtraC ~= car.extraC then
		if diffMode == DifferentialModes.HISPD then
			diffMode = DifferentialModes.ENTRY
		else
			diffMode = diffMode + 1
		end
		lastExtraC = car.extraC
	end

	local diffValue = 1
	local diffMinValue = 1
	local diffMaxValue = 12

	if diffMode == DifferentialModes.ENTRY then
		diffValue = entryDiff
	elseif diffMode == DifferentialModes.MID then
		diffValue = midDiff
	elseif diffMode == DifferentialModes.HISPD then
		diffValue = hispdDiff
	end

	if lastExtraD ~= car.extraD then
		diffValue = math.clamp(diffValue + 1, diffMinValue, diffMaxValue)
		lastExtraD = car.extraD
	end
	if lastExtraE ~= car.extraE then
		diffValue = math.clamp(diffValue - 1, diffMinValue, diffMaxValue)
		lastExtraE = car.extraE
	end

	if diffMode == DifferentialModes.ENTRY then
		entryDiff = diffValue
	elseif diffMode == DifferentialModes.MID then
		midDiff = diffValue
	elseif diffMode == DifferentialModes.HISPD then
		hispdDiff = diffValue
	end

	local exitDiff = hispdDiffSwitch(data) and hispdDiff or midDiff

	-- ac.debug("_car.driver", ac.getDriverName(car.index))
	-- ac.debug("_car.index", car.index)
	-- ac.debug("script.diff.mode", diffMode)
	-- ac.debug("script.diff.entry", entryDiff)
	-- ac.debug("script.diff.mid", midDiff)
	-- ac.debug("script.diff.hispd", hispdDiff)
	-- ac.debug("script.diff.exit", exitDiff)
	-- ac.debug("car.speed", data.speedKmh)
	-- ac.debug("data.diff.coast", car.differentialCoast)
	-- ac.debug("data.diff.power", car.differentialPower)
	-- ac.debug("data.diff.preload", car.differentialPreload)
	-- ac.debug("state.c", car.extraC)
	-- ac.debug("state.d", car.extraD)
	-- ac.debug("state.e", car.extraE)

	connection.diffEntry = entryDiff
	connection.diffMid = midDiff
	connection.diffHispd = hispdDiff
	data.controllerInputs[2] = exitDiff
	data.controllerInputs[3] = entryDiff
	data.controllerInputs[4] = midDiff
	data.controllerInputs[5] = hispdDiff
	data.controllerInputs[6] = diffMode
end

local function car_launch(data, launch)
	local rear_slip = data.wheels[2].ndSlip + data.wheels[3].ndSlip / 2
	if launch then
		data.gas = math.clamp(1 / math.clamp((rear_slip - 0.5), 1, 4), 0, 1)
		data.steer = math.clamp(data.steer, -0.05, 0.05)
	else
		car.gear = 2
		data.gas = math.clamp(1 / (rear_slip * 2), 0, 0.5)
	end
end

local function resetExtraStates()
	lastExtraA = false
	lastExtraB = false
	lastExtraC = false
	lastExtraD = false
	lastExtraE = false
end

function script.update(dt)
	local data = ac.accessCarPhysics()
	-- local dataCphys = ac.getCarPhysics(car.index)
	local sim = ac.getSim()

	if sim.isInMainMenu then
		resetExtraStates()
	end

	brakeMigration(data)
	differential(data)

	if sim.timeToSessionStart > -3000 and sim.timeToSessionStart < 3000 and car.isAIControlled then
		car_launch(data, true)
	end
end
