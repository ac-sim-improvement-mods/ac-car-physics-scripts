local connection = ac.connect({
	ac.StructItem.key("ext_car_0"),
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

-- Stored between sessions
local stored = ac.storage({
	bmig = 0.03,
	diffMode = DifferentialModes.ENTRY,
	entryDiff = 5,
	midDiff = 75,
	hispdDiff = 90,
})

local lastExtraA = car.extraA
local lastExtraB = car.extraB
local lastExtraC = car.extraC
local lastExtraD = car.extraD
local lastExtraE = car.extraE

local bmig = stored.bmig
local bmigMin = 0.00
local bmigMax = 0.09
local bmigRamp = 0.30
local bbFine = 0.00
local brakeBiasBase = car.brakeBias

local function brakeMigration(data, dataCphys)
	if bmig ~= connection.brakeMigration then
		bmig = connection.brakeMigration
	end
	if bmigRamp ~= connection.brakeMigrationRamp then
		bmigRamp = connection.brakeMigrationRamp
	end
	if bbFine ~= connection.brakeBiasFine then
		bbFine = connection.brakeBiasFine
	end

	if lastExtraA ~= car.extraA then
		if ac.isJoystickButtonPressed(0, 0) then
			bbFine = math.clamp(bbFine + 0.001, 0, 0.009)
			print(bbFine)
			print(car.brakeBias)
		else
			if bmig == bmigMax then
				bmig = bmigMin
			else
				bmig = math.clamp(bmig + 0.01, bmigMin, bmigMax)
			end
		end
		lastExtraA = car.extraA
	end

	if lastExtraB ~= car.extraB then
		if ac.isJoystickButtonPressed(0, 0) then
			bbFine = math.clamp(bbFine - 0.001, 0, 0.09)
			print(bbFine)
			print(car.brakeBias)
		else
			if bmig == bmigMin then
				bmig = bmigMax
			else
				bmig = math.clamp(bmig - 0.01, bmigMin, bmigMax)
			end
		end
		lastExtraB = car.extraB
	end

	brakeBiasBase = car.brakeBias + bbFine

	local brakeBiasTotal = brakeBiasBase + math.clamp((data.brake - bmigRamp), 0, 1) / (1 - bmigRamp) * bmig
	-- local torqueFront = dataCphys.wheels[0].brakeTorque + dataCphys.wheels[1].brakeTorque
	-- local torqueRear = dataCphys.wheels[2].brakeTorque + dataCphys.wheels[3].brakeTorque
	-- local torqueTotal = torqueFront + torqueRear
	-- local brakeBiasActual = torqueFront / torqueTotal
	-- local bbdiff = brakeBiasTotal - brakeBiasActual

	stored.bmig = bmig
	-- connection.brakeMigration = bmig
	-- connection.brakeBiasBase = brakeBiasBase
	-- connection.brakeBiasFine = bbFine
	data.controllerInputs[0] = brakeBiasTotal
	data.controllerInputs[1] = bmig

	-- ac.debug("bmig.bba", brakeBiasActual)
	-- ac.debug("bmig.bbdiff", bbdiff)
	-- ac.debug("bmig.bbb", brakeBiasBase)
	-- ac.debug("bmig.bbt", brakeBiasTotal)
	-- ac.debug("bmig.torqueTotal", torqueTotal)
	-- ac.debug("state.a", car.extraA)
	-- ac.debug("state.b", car.extraB)
end

local step = 9.090909090909091
local diffMode = stored.diffMode
local entryDiff = stored.entryDiff
local midDiff = stored.midDiff
local hispdDiff = stored.hispdDiff

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

	if lastExtraD ~= car.extraD then
		diffValue = math.clamp(diffValue + step, diffMinValue, diffMaxValue)
		lastExtraD = car.extraD
	end
	if lastExtraE ~= car.extraE then
		diffValue = math.clamp(diffValue - step, diffMinValue, diffMaxValue)
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

	stored.entryDiff = entryDiff
	stored.midDiff = midDiff
	stored.hispdDiff = hispdDiff
	stored.diffMode = diffMode
	data.controllerInputs[2] = exitDiff
	data.controllerInputs[3] = entryDiff
	data.controllerInputs[4] = midDiff
	data.controllerInputs[5] = hispdDiff
	data.controllerInputs[6] = diffMode

	-- ac.debug("car.driver", ac.getDriverName(car.index))
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

function script.update(dt)
	local data = ac.accessCarPhysics()
	local dataCphys = ac.getCarPhysics(car.index)
	local sim = ac.getSim()

	brakeMigration(data, dataCphys)
	differential(data)

	if sim.timeToSessionStart > -3000 and sim.timeToSessionStart < 3000 and car.isAIControlled then
		car_launch(data, true)
	end
end
