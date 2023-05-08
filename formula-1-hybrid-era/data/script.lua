-- if car.isAIControlled then
-- 	return nil
-- end

local sim = ac.getSim()
local data = ac.accessCarPhysics()
local cdata = ac.getCarPhysics(car.index)

local debug = {
	car = true,
	ebb = true,
	diff = false,
	antistall = false,
	controls = false,
}

local ext_car = ac.connect({
	ac.StructItem.key(ac.getCarID(car.index) .. "_ext_car_" .. car.index),
	connected = ac.StructItem.boolean(),
	brakeBiasTotal = ac.StructItem.float(),
	brakeMigration = ac.StructItem.float(),
	brakeMagic = ac.StructItem.boolean(),
	diffModeCurrent = ac.StructItem.float(),
	diffEntry = ac.StructItem.float(),
	diffMid = ac.StructItem.float(),
	diffExitHispd = ac.StructItem.float(),
	diffMidHispdSwitch = ac.StructItem.boolean(),
	engineAntistall = ac.StructItem.boolean(),
	engineStalled = ac.StructItem.boolean(),
}, true, ac.SharedNamespace.CarScript)
ext_car.connected = true

-- Setup ID to section key map logic from Ilja
local setupINI = ac.INIConfig.carData(car.index, "setup.ini")
local setupIDToSectionKeyMap = {}
for k, v in pairs(setupINI.sections) do
	if string.startsWith(k, "CUSTOM_SCRIPT_ITEM_") and v["ID"] then
		setupIDToSectionKeyMap[v["ID"][1]] = k
	end
end

setupINI:iterate("CUSTOM_SCRIPT_ITEM")

local isExtControls = false

local last = {
	extraA = car.extraA,
	extraB = car.extraB,
	extraC = car.extraC,
	extraD = car.extraD,
	extraE = car.extraE,
	BRAKE_MIGRATION_UP = false,
	BRAKE_MIGRATION_DN = false,
	BRAKE_BIAS_FINE_UP = false,
	BRAKE_BIAS_FINE_DN = false,
	BRAKE_MAGIC = false,
	DIFF_MODE_UP = false,
	DIFF_ENTRY_UP = false,
	DIFF_ENTRY_DN = false,
	DIFF_MID_UP = false,
	DIFF_MID_DN = false,
	DIFF_EXIT_HISPD_UP = false,
	DIFF_EXIT_HISPD_DN = false,
}

local extControlsBindings = {}

local function resetExtraStates()
	last.extraA = false
	last.extraB = false
	last.extraC = false
	last.extraD = false
	last.extraE = false
end

local diffMode = {
	ENTRY = 0,
	MID = 1,
	EXIT_HISPD = 2,
}

local diffModeToString = function(mode)
	local diffModeStrings = {
		"ENTRY",
		"MID",
		"EXIT/HISPD",
	}
	return diffModeStrings[mode + 1]
end

local diffModeCurrent = diffMode.ENTRY

local sectionToMessage = {
	BRAKE_MIGRATION = "Brake Migration",
	DIFF_ENTRY = "Differential ENTRY",
	DIFF_MID = "Differential MID",
	DIFF_EXIT_HISPD = "Differential EXIT/HISPD",
}

local function setupItemStepper(section, lut, value, min, max, step, stepDownBinding, stepUpBinding, skipMessage)
	local updated = false
	local sectionUp = section .. "_UP"
	local sectionDn = section .. "_DN"

	if last[sectionUp] == false and stepUpBinding == true then
		last[sectionUp] = true
		if value == max then
			value = min
		else
			value = math.clamp(value + step, min, max)
		end

		if section ~= "DIFF_MODE" then
			ac.setScriptSetupValue(section, value)
		end
		updated = true
	elseif last[sectionUp] == true and stepUpBinding == false then
		last[sectionUp] = false
	end

	if last[sectionDn] == false and stepDownBinding == true then
		last[sectionDn] = true

		if value == min then
			value = max
		else
			value = math.clamp(value - step, min, max)
		end

		if section ~= "DIFF_MODE" then
			ac.setScriptSetupValue(section, value)
		end
		updated = true
	elseif last[sectionDn] == true and stepDownBinding == false then
		last[sectionDn] = false
	end

	if updated then
		if skipMessage then
			return value
		elseif section == "DIFF_MODE" then
			ac.setSystemMessage("Differential Mode: " .. diffModeToString(value))
		else
			ac.setSystemMessage(
				tostring(sectionToMessage[section])
					.. ": "
					.. lut:getPointInput(value)
					.. "/"
					.. lut:getPointInput(#lut - 1)
			)
		end
	end

	return value
end

-- Check buttons pressed for each button configured in preset
local function controlBindingListener(section)
	local bindingJoy = tonumber(extControlsBindings[section]["JOY"][1]) ~= nil
			and tonumber(extControlsBindings[section]["JOY"][1])
		or -1
	local bindingButton = tonumber(extControlsBindings[section]["BUTTON"][1]) ~= nil
			and tonumber(extControlsBindings[section]["BUTTON"][1])
		or -1
	local pressed = false

	if ac.isJoystickButtonPressed(bindingJoy, bindingButton - 1) then
		pressed = true
	end

	return pressed
end

local SMO = function()
	local cancelSystemMessage = false
	local lastIntervalID = -1
	return function(section, msg, description, value, lastValue)
		if lastValue ~= value then
			lastValue = value
			clearInterval(lastIntervalID)

			lastIntervalID = setInterval(function()
				ac.setSystemMessage(msg, description)
			end, 0, section .. "_interval")

			setTimeout(function()
				cancelSystemMessage = true
			end, 5, section .. "_timeout")
		elseif cancelSystemMessage then
			clearInterval(lastIntervalID)
			cancelSystemMessage = false
		end

		return lastValue
	end
end

local systemMessageOverride = SMO()

local PTMAP = function()
	local throttle = 0
	local maxPwr = 0
	local optRPM = car.rpmLimiter

	return function()
		data.gas = data.rpm > data.gas * optRPM and math.lerp(data.gas, 0, data.gas * optRPM) or data.gas

		if car.drivetrainPower > maxPwr then
			optRPM = data.rpm
			maxPwr = car.drivetrainPower
		end

		throttle = data.gas < 0.99
				and data.gas > 0.05
				and math.clamp(math.exp((-(data.rpm / (optRPM * data.gas) - 1) ^ 2) * 3), 0, 1)
			or data.gas

		data.gas = throttle
	end
end

local EBB = function()
	local brakeBiasFineSection = "BRAKE_BIAS_FINE"
	local brakeBiasFineUpSection = brakeBiasFineSection .. "_UP"
	local brakeBiasFineDnSection = brakeBiasFineSection .. "_DN"
	local brakeBiasFineItem = ac.getScriptSetupValue(brakeBiasFineSection) or refnumber(0)
	local brakeMigrationSection = "BRAKE_MIGRATION"
	local brakeMigrationUpSection = brakeMigrationSection .. "_UP"
	local brakeMigrationDnSection = brakeMigrationSection .. "_DN"
	local brakeMigrationItem = ac.getScriptSetupValue(brakeMigrationSection) or refnumber(0)
	local brakeMigrationRampSection = "BRAKE_MIGRATION_RAMP"
	local brakeMigrationRampItem = ac.getScriptSetupValue(brakeMigrationRampSection) or refnumber(0)
	local brakeMagicSection = "BRAKE_MAGIC"
	local brakeMagicItem = ac.getScriptSetupValue(brakeMagicSection) or refnumber(0)

	local brakeBiasFineLutFile = setupINI:get(setupIDToSectionKeyMap[brakeBiasFineSection], "LUT", "")
	local brakeBiasFineLut = {}
	if brakeBiasFineLutFile then
		brakeBiasFineLut = ac.DataLUT11.carData(car.index, brakeBiasFineLutFile)
	end
	local brakeBiasFineMin = 0
	local brakeBiasFineMax = 20
	local brakeBiasFineStep = 1

	local brakeMigrationLutFile = setupINI:get(setupIDToSectionKeyMap[brakeMigrationSection], "LUT", "")
	local brakeMigrationLut = {}
	if brakeMigrationLutFile then
		brakeMigrationLut = ac.DataLUT11.carData(car.index, brakeMigrationLutFile)
	end
	local brakeMigrationMin = brakeMigrationLut:get(0)
	local brakeMigrationMax = brakeMigrationLut:get(#brakeMigrationLut)
	local brakeMigrationStep = 1

	local brakeBiasCorrection = 0

	local brakeBiasLast = car.brakeBias

	return function()
		local brakeBiasFine = brakeBiasFineItem()
		local brakeMigration = brakeMigrationItem()
		local brakeBiasBase = car.brakeBias - brakeMigration / 100 + brakeBiasFine / 1000
		local brakeBiasTotal = car.brakeBias + brakeBiasFine / 1000
		local brakeMigration = brakeMigrationItem()
		local brakeMigrationRamp = brakeMigrationRampItem()
		local brakeMagic = brakeMagicItem()
		local brakePedal = data.brake
		local brakeBiasLive = brakeBiasBase
			+ math.clamp((brakePedal - brakeMigrationRamp / 100), 0, 1)
				/ (1 - brakeMigrationRamp / 100)
				* brakeMigration
				/ 100

		local brakeMigrationUp, brakeMigrationDn, brakeBiasFineUp, brakeBiasFineDn, brakeMagicOn =
			car.extraA, car.extraB, false, false, false

		brakeBiasLast = systemMessageOverride(
			"FRONT_BIAS",
			"Brake Bias",
			string.format("%.1f %%", brakeBiasTotal * 100),
			brakeBiasTotal,
			brakeBiasLast
		)

		if isExtControls then
			brakeMigrationUp = controlBindingListener(brakeMigrationUpSection)
			brakeMigrationDn = controlBindingListener(brakeMigrationDnSection)
			brakeBiasFineUp = controlBindingListener(brakeBiasFineUpSection)
			brakeBiasFineDn = controlBindingListener(brakeBiasFineDnSection)
			brakeMagicOn = controlBindingListener(brakeMagicSection)
		end

		setupItemStepper(
			brakeMigrationSection,
			brakeMigrationLut,
			brakeMigration,
			brakeMigrationMin,
			brakeMigrationMax,
			brakeMigrationStep,
			brakeMigrationDn,
			brakeMigrationUp
		)

		setupItemStepper(
			brakeBiasFineSection,
			brakeBiasFineLut,
			brakeBiasFine + 10,
			brakeBiasFineMin,
			brakeBiasFineMax,
			brakeBiasFineStep,
			brakeBiasFineDn,
			brakeBiasFineUp,
			true
		)

		if debug.ebb then
			local brakeTorqueFront = cdata.wheels[0].brakeTorque + cdata.wheels[1].brakeTorque
			local brakeTorqueRear = cdata.wheels[2].brakeTorque + cdata.wheels[3].brakeTorque
			local brakeTorqueTotal = brakeTorqueFront + brakeTorqueRear
			local brakeTorqueBalance = brakeTorqueFront / brakeTorqueTotal
			local brakeTorqueDelta = brakeTorqueBalance - brakeBiasLive

			-- stylua: ignore start
			ac.debug("ebb.mig.lut.get.min", brakeMigrationLut:get(0))
			ac.debug("ebb.mig.lut.get.max", brakeMigrationLut:get(#brakeMigrationLut))
			ac.debug("ebb.mig.lut.get.max.input", brakeMigrationLut:getPointInput(brakeMigrationLut:get(#brakeMigrationLut)))
			ac.debug("ebb.mig.lut.get.min.input", brakeMigrationLut:getPointInput(brakeMigrationLut:get(0)))
			ac.debug("ebb.bias.total", tostring(math.round(brakeBiasTotal * 100, 1)) .. "%")
			ac.debug("ebb.bias.live", tostring(math.round(brakeBiasLive * 100, 1)) .. "%")
			ac.debug("ebb.bias.base", tostring(math.round(brakeBiasBase * 100, 1)) .. "%")

			ac.debug("ebb.fine", tostring(brakeBiasFine/10) .. "%")
			ac.debug("ebb.fine.lut.get.min",brakeBiasFineLut:get(0))
			ac.debug("ebb.fine.lut.get.max",  brakeBiasFineLut:get(#brakeBiasFineLut))
			ac.debug("ebb.fine.lut.get.max.input",  brakeBiasFineLut:getPointInput(brakeBiasFineLut:get(#brakeBiasFineLut)))
			ac.debug("ebb.fine.lut.get.min.input", brakeBiasFineLut:getPointInput(brakeBiasFineLut:get(0)))
			ac.debug("ebb.mig", tostring(brakeMigration) .. "%")
			ac.debug("ebb.mig.ramp", tostring(brakeMigrationRamp) .. "%")
			ac.debug("ebb.mig.applied", tostring(math.round(math.clamp((brakePedal - brakeMigrationRamp / 100), 0, 1) / (1 - brakeMigrationRamp / 100),3) * 100) .. "%")
			ac.debug("ebb.brake.pedal", tostring(math.round(data.brake * 100, 1)) .. "%")
			ac.debug("ebb.trq.front", brakeTorqueFront)
			ac.debug("ebb.trq.rear", brakeTorqueRear)
			ac.debug("ebb.trq.total", brakeTorqueTotal)
			ac.debug("ebb.bias.calculated", brakeTorqueBalance * 100)
			ac.debug("ebb.bias.calc-live.delta", brakeTorqueDelta * 100)
			ac.debug("extraA", car.extraA)
			ac.debug("extraB", car.extraB)
			-- stylua: ignore end
		end

		ext_car.brakeBiasTotal = brakeBiasTotal
		ext_car.brakeMigration = brakeMigration
		ext_car.brakeMagic = brakeMagicOn
		data.controllerInputs[0] = brakeMagicOn and brakeMagic or brakeBiasLive
	end
end

local function isHispdSwitch(speed)
	local groundSpeed = data.speedKmh
	local longAccel = car.acceleration.z
	local isHispd = false
	if longAccel > 0 or groundSpeed > speed or groundSpeed < 1 then
		isHispd = true
	end
	return isHispd
end

local DIFF = function()
	local diffEntrySection = "DIFF_ENTRY"
	local diffEntryUpSection = diffEntrySection .. "_UP"
	local diffEntryDnSection = diffEntrySection .. "_DN"
	local diffEntryItem = ac.getScriptSetupValue(diffEntrySection) or refnumber(0)
	local diffMidSection = "DIFF_MID"
	local diffMidUpSection = diffMidSection .. "_UP"
	local diffMidDnSection = diffMidSection .. "_DN"
	local diffMidItem = ac.getScriptSetupValue(diffMidSection) or refnumber(0)
	local diffExitHispdSection = "DIFF_EXIT_HISPD"
	local diffExitHispdUpSection = diffExitHispdSection .. "_UP"
	local diffExitHispdDnSection = diffExitHispdSection .. "_DN"
	local diffExitHispdItem = ac.getScriptSetupValue(diffExitHispdSection) or refnumber(0)
	local diffMidHispdSwitchSection = "DIFF_MID_HISPD_SWITCH"
	local diffMidHispdSwitchItem = ac.getScriptSetupValue(diffMidHispdSwitchSection) or refnumber(0)

	local diffLutFile = setupINI:get(setupIDToSectionKeyMap[diffEntrySection], "LUT", "")
	local diffLut = {}

	if diffLutFile then
		diffLut = ac.DataLUT11.carData(car.index, diffLutFile)
	end

	local diffMin = diffLut:get(0)
	local diffMax = diffLut:get(#diffLut)
	local diffStep = 1

	return function()
		local diffEntry = diffEntryItem()
		local diffMid = diffMidItem()
		local diffExitHispd = diffExitHispdItem()
		local diffMidHispdSwitch = diffMidHispdSwitchItem()
		local diffSection, diffValue

		if not isExtControls then
			diffModeCurrent = setupItemStepper("DIFF_MODE", nil, diffModeCurrent, 0, 2, 1, false, car.extraC)

			if diffModeCurrent == diffMode.ENTRY then
				diffSection = diffEntrySection
				diffValue = diffEntry
			elseif diffModeCurrent == diffMode.MID then
				diffSection = diffMidSection
				diffValue = diffMid
			elseif diffModeCurrent == diffMode.EXIT_HISPD then
				diffSection = diffExitHispdSection
				diffValue = diffExitHispd
			end

			setupItemStepper(diffSection, diffLut, diffValue, diffMin, diffMax, diffStep, car.extraE, car.extraD)
		else
			local diffEntryUp, diffEntryDn, diffMidUp, diffMidDn, diffExitHispdUp, diffExitHispdDn

			diffEntryUp = controlBindingListener(diffEntryUpSection)
			diffEntryDn = controlBindingListener(diffEntryDnSection)
			diffMidUp = controlBindingListener(diffMidUpSection)
			diffMidDn = controlBindingListener(diffMidDnSection)
			diffExitHispdUp = controlBindingListener(diffExitHispdUpSection)
			diffExitHispdDn = controlBindingListener(diffExitHispdDnSection)

			setupItemStepper(diffEntrySection, diffLut, diffEntry, diffMin, diffMax, diffStep, diffEntryDn, diffEntryUp)
			setupItemStepper(diffMidSection, diffLut, diffMid, diffMin, diffMax, diffStep, diffMidDn, diffMidUp)
			setupItemStepper(
				diffExitHispdSection,
				diffLut,
				diffExitHispd,
				diffMin,
				diffMax,
				diffStep,
				diffExitHispdDn,
				diffExitHispdUp
			)
		end

		local diffCoast = diffEntry
		local diffPower = isHispdSwitch(diffMidHispdSwitch) and diffExitHispd or diffMid

		if debug.diff then
			ac.debug("diff.lut.get.min", diffLut:get(0))
			ac.debug("diff.lut.get.max", diffLut:get(#diffLut - 1))
			ac.debug("diff.lut.get.max.input", diffLut:getPointInput(diffLut:get(#diffLut)))
			ac.debug("diff.lut.get.min.input", diffLut:getPointInput(diffLut:get(0)))
			ac.debug("diff.mode", diffModeCurrent)
			ac.debug("diff.entry", diffEntry)
			ac.debug("diff.mid", diffMid)
			ac.debug("diff.hispd", diffExitHispd)
			ac.debug("diff.exit", diffPower)
			ac.debug("diff.step.min", diffMin)
			ac.debug("diff.step.max", diffMax)
			ac.debug("diff.midHispdSwitch", diffMidHispdSwitch)
			ac.debug("diff.midHispdSwitchActive", isHispdSwitch(diffMidHispdSwitch))
			ac.debug("diff.data.controller.coast", math.round(ac.getDynamicController("ctrl_diff_coast.ini")(), 1))
			ac.debug("diff.data.controller.power", math.round(ac.getDynamicController("ctrl_diff_power.ini")(), 1))
			-- ac.debug("diff.data.coast", math.round(car.differentialCoast * 100, 1))
			-- ac.debug("diff.data.power", math.round(car.differentialPower * 100, 1))
			-- ac.debug("diff.data.preload", car.differentialPreload)
			ac.debug("extraC", car.extraC)
			ac.debug("extraD", car.extraD)
			ac.debug("extraE", car.extraE)
		end

		ext_car.diffModeCurrent = diffModeCurrent
		ext_car.diffEntry = diffEntry
		ext_car.diffMid = diffMid
		ext_car.diffExitHispd = diffExitHispd
		ext_car.diffMidHispdSwitch = diffMidHispdSwitch
		data.controllerInputs[1] = diffCoast
		data.controllerInputs[2] = diffPower
	end
end

local STALL = function()
	local antistallTimer = 0
	local isAntistallActive = false
	local isCarStalled = false
	local engineINI = ac.INIConfig.carData(car.index, "engine.ini")
	local rpmMinimum = engineINI:get("ENGINE_DATA", "MINIMUM", 0)
	ac.setEngineStalling(false)

	return function()
		if data.gear ~= 1 then
			if data.rpm >= rpmMinimum + 50 then
				antistallTimer = 0
				isAntistallActive = false
				isCarStalled = false
			elseif data.rpm < rpmMinimum + 50 then
				if not isAntistallActive and not isCarStalled and data.clutch == 1 then
					isAntistallActive = true
					antistallTimer = os.clock() + 2
					data.clutch = 0
				elseif antistallTimer > os.clock() then
					data.clutch = 0
				elseif data.rpm > rpmMinimum then
					isAntistallActive = false
				else
					isAntistallActive = false
				end

				if data.rpm < rpmMinimum and data.clutch < 1 then
					isCarStalled = true
					isAntistallActive = false
				end
			end
		else
			isAntistallActive = false
		end

		if isCarStalled then
			data.gas = 0
		end

		if debug.antistall then
			ac.debug("data.clutch", data.clutch)
			ac.debug("antistall.active", isAntistallActive)
			ac.debug("antistall.car.stalled", isCarStalled)
			ac.debug("antistall.rpmMin", rpmMinimum)
			ac.debug("antistall.timer", math.clamp(antistallTimer - os.clock(), 0, 100))
		end

		ext_car.engineAntistall = isAntistallActive
		ext_car.engineStalled = isCarStalled
	end
end

extControlsBindings = stringify.parse(ac.load("ext_controls"))
isExtControls = ac.load("ext_controls.enabled") == 1 and true or false

if debug.controls then
	ac.debug("controls.isExtControls", isExtControls)
end

local ptmap = PTMAP()
local ebb = EBB()
local diff = DIFF()
local stall = STALL()

function script.update(dt)
	if sim.isInMainMenu then
		resetExtraStates()
	end

	if debug.car then
		ac.debug("car.track.position", ac.worldCoordinateToTrackProgress(car.position))
		ac.debug("car.rpm", math.floor(data.rpm))
		ac.debug("car.driver", ac.getDriverName(car.index))
		ac.debug("car.index", car.index)
		ac.debug("car.accel.z", car.acceleration.z)
		ac.debug("car.speed", math.round(data.speedKmh, 2))
	end

	ebb()
	diff()

	--ptmap()
	--stall()
end
