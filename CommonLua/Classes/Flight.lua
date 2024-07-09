local FlightTile = const.FlightTile
if not FlightTile then
	return -- flight logic not supported
end

FlightDbgResults = empty_func
FlightDbgMark = empty_func
FlightDbgBreak = empty_func

local efResting = const.efResting

local pfFinished = const.pfFinished
local pfFailed = const.pfFailed
local pfTunnel = const.pfTunnel
local pfDestLocked = const.pfDestLocked
local pfSmartDestlockDist = const.pfSmartDestlockDist

local tfrPassClass = const.tfrPassClass
local tfrLimitDist = const.tfrLimitDist
local tfrCanDestlock = const.tfrCanDestlock
local tfrLuaFilter = const.tfrLuaFilter

local Min, Max, Clamp, AngleDiff = Min, Max, Clamp, AngleDiff
local IsValid, IsValidPos = IsValid, IsValidPos
local ResolveZ = ResolveZ

local InvalidZ = const.InvalidZ
local anim_min_time = 100
local time_ahead = 10
local tplCheck = const.tplCheck
local step_search_dist = 2*FlightTile
local dest_search_dist = 4*FlightTile
local max_search_dist = 10*FlightTile
local max_takeoff_dist = 64*guim

local flight_default_flags = const.ffpSplines | const.ffpPhysics | const.ffpSmooth
local ffpAdjustTarget = const.ffpAdjustTarget

local flight_flags_values = {
	Splines = const.ffpSplines,
	Physics = const.ffpPhysics,
	Smooth = const.ffpSmooth,
	AdjustTarget = const.ffpAdjustTarget,
	Debug = const.ffpDebug,
}
local flight_flags_names = table.keys(flight_flags_values, true)
local function FlightFlagsToSet(flags)
	local fset = {}
	for name, flag in pairs(flight_flags_values) do
		if (flags & flag) ~= 0 then
			fset[name] = true
		end
	end
	return fset
end
local function FlightSetToFlags(fset)
	local flags = 0
	for name in pairs(fset) do
		flags = flags | flight_flags_values[name]
	end
	return flags
end
local path_errors = {
	invalid = const.fpsInvalid,
	max_iters = const.fpsMaxIters,
	max_steps = const.fpsMaxSteps,
	max_loops = const.fpsMaxLoops,
	max_stops = const.fpsMaxStops,
}
---
--- Returns a table of error names corresponding to the given path status.
---
--- @param status number The path status bitfield.
--- @return table|nil A table of error names, or nil if no errors are present.
function FlightGetErrors(status)
	status = status or 0
	local errors
	for name, value in pairs(path_errors) do
		if status & value ~= 0 then
			errors = table.create_add(errors, name)
		end
	end
	if errors then
		table.sort(errors)
		return errors
	end
end

---
--- Initializes the variables used for flight calculations.
---
--- This function sets the initial values for various flight-related variables, such as the flight map, energy, source and destination, flags, and other parameters. It is typically called when the game or a specific map is loaded, or when the flight calculations need to be reset.
---
--- @function FlightInitVars
--- @return nil
function FlightInitVars()
	FlightMap = false
	FlightEnergy = false
	FlightFrom = false
	FlightTo = false
	FlightFlags = 0
	FlightDestRange = 0
	FlightMarkFrom = false
	FlightMarkTo = false
	FlightMarkBorder = 0
	FlightMarkMinHeight = 0
	FlightMarkObjRadius = 0
	FlightMarkIdx = 0
	FlightArea = false
	FlightEnergyMin = false
	FlightSlopePenalty = 0
	FlightSmoothDist = 0
	FlightGrowObstacles = false
	FlightTimestamp = 0
	FlightPassVersion = false
end

if FirstLoad then
	FlightInitVars()
end

function OnMsg.DoneMap()
	if FlightMap then
		FlightMap:free()
	end
	if FlightEnergy then
		FlightEnergy:free()
	end
	FlightInitVars()
end

local StayAboveMapItems = {
	{ value = const.FlightRestrictNone,          text = "None",             help = "The object is allowed to fall under the flight map" },
	{ value = const.FlightRestrictAboveTerrain,  text = "Above Terrain",    help = "The object is allowed to fall under the flight map, but not under the terrain" },
	{ value = const.FlightRestrictAboveWalkable, text = "Above Walkable",   help = "The object is allowed to fall under the flight map, but not under a walkable surface (inlcuding the terrain)" },
	{ value = const.FlightRestrictAboveMap,      text = "Above Flight Map", help = "The object is not allowed to fall under the flight map" },
}

----

MapVar("FlyingObjs", function() return sync_set() end)

DefineClass.FlyingObj = {
	__parents = { "Object" },
	flags = { cofComponentInterpolation = true, cofComponentCurvature = true },
	properties = {
		{ category = "Flight", id = "FlightMinPitch",        name = "Pitch Min",                editor = "number", default = -2700,    scale = "deg", template = true },
		{ category = "Flight", id = "FlightMaxPitch",        name = "Pitch Max",                editor = "number", default = 2700,    scale = "deg", template = true },
		{ category = "Flight", id = "FlightPitchSmooth",     name = "Pitch Smooth",             editor = "number", default = 100,     min = 0, max = 500, scale = 100, slider = true, template = true, help = "Smooth the pitch angular speed changes" },
		{ category = "Flight", id = "FlightMaxPitchSpeed",   name = "Pitch Speed Limit (deg/s)",editor = "number", default = 90*60,   scale = 60, template = true, help = "Smooth the pitch angular speed changes" },
		{ category = "Flight", id = "FlightSpeedToPitch",    name = "Speed to Pitch",           editor = "number", default = 100,     min = 0, max = 100, scale = "%", slider = true, template = true, help = "How much the flight speed affects the pitch angle" },
		{ category = "Flight", id = "FlightMaxRoll",         name = "Roll Max",                 editor = "number", default = 2700,    min = 0, max = 180*60, scale = "deg", slider = true, template = true },
		{ category = "Flight", id = "FlightMaxRollSpeed",    name = "Roll Speed Limit (deg/s)", editor = "number", default = 90*60,   scale = 60, template = true, help = "Smooth the row angular speed changes" },
		{ category = "Flight", id = "FlightRollSmooth",      name = "Roll Smooth",              editor = "number", default = 100,     min = 0, max = 500, scale = 100, slider = true, template = true, help = "Smooth the row angular speed changes" },
		{ category = "Flight", id = "FlightSpeedToRoll",     name = "Speed to Roll",            editor = "number", default = 0,       min = 0, max = 100, scale = "%", slider = true, template = true, help = "How much the flight speed affects the roll angle" },
		{ category = "Flight", id = "FlightYawSmooth",       name = "Yaw Smooth",               editor = "number", default = 100,     min = 0, max = 500, scale = 100, slider = true, template = true, help = "Smooth the yaw angular speed changes" },
		{ category = "Flight", id = "FlightMaxYawSpeed",     name = "Yaw Speed Limit (deg/s)",  editor = "number", default = 360*60,  scale = 60, template = true, help = "Smooth the yaw angular speed changes" },
		{ category = "Flight", id = "FlightYawRotToRoll",    name = "Yaw Rot to Roll",          editor = "number", default = 100,     min = 0, max = 300, scale = "%", slider = true, template = true, help = "Links the row angle to the yaw rotation speed" },
		{ category = "Flight", id = "FlightYawRotFriction",  name = "Yaw Rot Friction",         editor = "number", default = 100,     min = 0, max = 1000, scale = "%", slider = true, template = true, help = "Friction caused by 90 deg/s yaw rotation speed" },
		{ category = "Flight", id = "FlightSpeedStop",       name = "Speed Stop (m/s)",         editor = "number", default = false,       scale = guim, template = true, help = "Will use the min speed if not specified. Stopping is possible only if the deceleration distance is not zero" },
		{ category = "Flight", id = "FlightSpeedMin",        name = "Speed Min (m/s)",          editor = "number", default = 6 * guim,    scale = guim, template = true },
		{ category = "Flight", id = "FlightSpeedMax",        name = "Speed Max (m/s)",          editor = "number", default = 15 * guim,   scale = guim, template = true },
		{ category = "Flight", id = "FlightFriction",        name = "Friction",                 editor = "number", default = 30, min = 0, max = 300, slider = true, scale = "%", template = true, help = "Friction coefitient, affects the max achievable speed. Should be adjusted so that both the max speed and the achievable one are matching." },
		{ category = "Flight", id = "FlightAccelMax",        name = "Accel Max (m/s^2)",        editor = "number", default = 10*guim, scale = guim, template = true },
		{ category = "Flight", id = "FlightDecelMax",        name = "Decel Max (m/s^2)",        editor = "number", default = 20*guim, scale = guim, template = true },
		{ category = "Flight", id = "FlightAccelDist",       name = "Accel Dist",               editor = "number", default = 20*guim, scale = "m", template = true },
		{ category = "Flight", id = "FlightDecelDist",       name = "Decel Dist",               editor = "number", default = 20*guim, scale = "m", template = true },
		{ category = "Flight", id = "FlightStopDist",        name = "Force Stop Dist",          editor = "number", default = 1*guim, scale = "m", template = true, help = "Critical distance where to dorce a stop animation even if the conditions for such are not met" },
		{ category = "Flight", id = "FlightStopMinTime",     name = "Min Stop Time",            editor = "number", default = 50, min = 0, template = true, help = "Try to play stop anim only if enough time is available" },
		{ category = "Flight", id = "FlightPathStepMax",     name = "Path Step Max",            editor = "number", default = 2*guim,  scale = "m", template = true, help = "Step dist at max speed" },
		{ category = "Flight", id = "FlightPathStepMin",     name = "Path Step Min",            editor = "number", default = guim,  scale = "m", template = true, help = "Step dist at min speed" },
		{ category = "Flight", id = "FlightAnimStart",       name = "Anim Fly Start",           editor = "text",   default = false, template = true },
		{ category = "Flight", id = "FlightAnim",            name = "Anim Fly",                 editor = "text",   default = false, template = true },
		{ category = "Flight", id = "FlightAnimDecel",       name = "Anim Fly Decel",           editor = "text",   default = false, template = true },
		{ category = "Flight", id = "FlightAnimStop",        name = "Anim Fly Stop",            editor = "text",   default = false, template = true },
		
		{ category = "Flight", id = "FlightAnimIdle",        name = "Anim Fly Idle",            editor = "text",   default = false, template = true },
		{ category = "Flight", id = "FlightAnimSpeedMin",    name = "Anim Speed Min",           editor = "number", default = 1000, min = 0, max = 1000, scale = 1000, slider = true, template = true },
		{ category = "Flight", id = "FlightAnimSpeedMax",    name = "Anim Speed Max",           editor = "number", default = 1000, min = 1000, max = 3000, scale = 1000, slider = true, template = true },
		{ category = "Flight", id = "FlightAnimStopFOV",     name = "Anim Fly Stop FoV",        editor = "number", default = 90*60, min = 0, max = 360*60, scale = "deg", slider = true, template = true, help = "Required FoV towards the target in order to switch to anim_stop/landing anim" },
		
		{ category = "Flight Path", id = "FlightSimHeightMin",      name = "Min Height",           editor = "number", default = 3*guim, min = guim, max = 50*guim, slider = true, scale = "m", template = true, sim = true, help = "Min flight height. If below, the flying obj will try to go up (lift)." },
		{ category = "Flight Path", id = "FlightSimHeightMax",      name = "Max Height",           editor = "number", default = 5*guim, min = guim, max = 50*guim, slider = true, scale = "m", template = true, sim = true, help = "Max flight height. If above, the flying obj will try to go down (weight)." },
		{ category = "Flight Path", id = "FlightSimHeightRestrict", name = "Height Restriction",   editor = "choice", default = const.FlightRestrictNone, template = true, sim = true, items = StayAboveMapItems, help = "Avoid entering the height map. As the height map is not precise, this could lead to strange visual behavior." },
		{ category = "Flight Path", id = "FlightSimSpeedLimit",     name = "Speed Limit (m/s)",    editor = "number", default = 10*guim, min = 1, max = 50*guim, slider = true, scale = guim, template = true, sim = true, help = "Max speed during simulation. Should be limited to ensure precision." },
		{ category = "Flight Path", id = "FlightSimInertia",        name = "Inertia",              editor = "number", default = 100, min = 10, max = 1000, slider = true, exponent = 2, scale = 100, template = true, sim = true, help = "How inert is the object." },
		{ category = "Flight Path", id = "FlightSimFrictionXY",     name = "Friction XY",          editor = "number", default = 20, min = 1, max = 300, slider = true, scale = "%", template = true, sim = true, help = "Horizontal friction min coefitient." },
		{ category = "Flight Path", id = "FlightSimFrictionZ",      name = "Friction Z",           editor = "number", default = 50, min = 1, max = 300, slider = true, scale = "%", template = true, sim = true, help = "Vertical friction coefitient." },
		{ category = "Flight Path", id = "FlightSimFrictionStop",   name = "Friction Stop",        editor = "number", default = 80, min = 1, max = 300, slider = true, scale = "%", template = true, sim = true, help = "Horizontal friction max coefitient." },
		{ category = "Flight Path", id = "FlightSimAttract",        name = "Attract",              editor = "number", default = guim, min = 0, max = 30*guim, slider = true, scale = 1000, template = true, sim = true, help = "Attraction force per energy unit difference. The force pushing the unit towards its final destination." },
		{ category = "Flight Path", id = "FlightSimLift",           name = "Lift",                 editor = "number", default = guim/3, min = 0, max = 30*guim, slider = true, scale = 1000, template = true, sim = true, help = "Lift force per meter. The force trying to bring back UP the unit at its best height level." },
		{ category = "Flight Path", id = "FlightSimMaxLift",        name = "Max Lift",             editor = "number", default = 10*guim, min = 0, max = 30*guim, slider = true, scale = 1000, template = true, sim = true, help = "Max lift force." },
		{ category = "Flight Path", id = "FlightSimWeight",         name = "Weight",               editor = "number", default = guim/3, min = 0, max = 20*guim, slider = true, scale = 1000, template = true, sim = true, help = "Weight force per meter. The force trying to bring back DOWN the unit at its best height level." },
		{ category = "Flight Path", id = "FlightSimMaxWeight",      name = "Max Weight",           editor = "number", default = 3*guim, min = 0, max = 20*guim, slider = true, scale = 1000, template = true, sim = true, help = "Max weight force." },
		{ category = "Flight Path", id = "FlightSimMaxThrust",      name = "Max Thrust",           editor = "number", default = 10*guim, min = 0, max = 50*guim, slider = true, scale = 1000, template = true, sim = true, help = "Max cummulative thrust." },
		{ category = "Flight Path", id = "FlightSimInterval",       name = "Update Interval (ms)", editor = "number", default = 50, min = 1, max = 1000, slider = true, template = true, sim = true, help = "Simulation update interval. Lower values ensure better precision, but makes the sim more expensive" },
		{ category = "Flight Path", id = "FlightSimMinStep",        name = "Min Path Step",        editor = "number", default = FlightTile, min = 0, max = 100*guim, scale = "m", slider = true, template = true, sim = true, help = "Min path step (approx)." },
		{ category = "Flight Path", id = "FlightSimMaxStep",        name = "Max Path Step",        editor = "number", default = 8*FlightTile, min = 0, max = 100*guim, scale = "m", slider = true, template = true, sim = true, help = "Max path step (approx)." },
		{ category = "Flight Path", id = "FlightSimDecelDist",      name = "Decel Dist",           editor = "number", default = 10*guim, min = 1, max = 300*guim, slider = true, scale = "m", template = true, sim = true, help = "At that distance to the target, the movement will try to go towards the target ignoring most considerations." },
		{ category = "Flight Path", id = "FlightSimLookAhead",      name = "Look Ahead",           editor = "number", default = 4000, min = 0, max = 10000, scale = "sec", slider = true, template = true, sim = true, help = "Give some time to adjust the flight height before reaching a too high obstacle." },
		{ category = "Flight Path", id = "FlightSimSplineAlpha",    name = "Spline Alpha",         editor = "number", default = 1365, min = 0, max = 4096, scale = 4096, slider = true, template = true, sim = true, help = "Defines the spline smoothness." },
		{ category = "Flight Path", id = "FlightSimSplineErr",      name = "Spline Tolerance",     editor = "number", default = FlightTile/4, min = 0, max = FlightTile, scale = "m", slider = true, template = true, sim = true, help = "Max spline deviation form the precise trajectory. Lower values imply more path steps as the longer splines deviate stronger." },
		{ category = "Flight Path", id = "FlightSimMaxIters",       name = "Max Compute Iters",    editor = "number", default = 16 * 1024, template = true, sim = true, help = "Max number of compute iterations. Used for a sanity check against infinite loops." },
		
		{ category = "Flight Path", id = "FlightSlopePenalty",      name = "Slope Penalty",        editor = "number", default = 300, scale = "%", template = true, sim = true, min = 10, max = 1000, slider = true, exponent = 2, help = "How difficult it is to flight over against going around obstacles." },
		{ category = "Flight Path", id = "FlightSmoothDist",        name = "Smooth Obstacles Dist",editor = "number", default = 0, template = true, sim = true, help = "Better obstacle avoidance withing that distance at the expense of more processing." },
		{ category = "Flight Path", id = "FlightMinObstacleHeight", name = "Min Obstacle Height",  editor = "number", default = 0, scale = "m", template = true, sim = true, step = const.FlightScale, help = "Ignored obstacle height." },
		{ category = "Flight Path", id = "FlightObjRadius",         name = "Object Radius",        editor = "number", default = 0, scale = "m", template = true, sim = true, help = "To consider when avoiding obstacles." },
		
		{ category = "Flight Path", id = "FlightFlags",             name = "Flight Flags",         editor = "set",    default = function(self) return FlightFlagsToSet(flight_default_flags) end, items = flight_flags_names },
		{ category = "Flight Path", id = "FlightPathErrors",        name = "Path Errors",          editor = "set",    default = set(), items = table.keys(path_errors, true), read_only = true, dont_save = true },
		{ category = "Flight Path", id = "FlightPathSplines",       name = "Path Splines",         editor = "number", default = 0, read_only = true, dont_save = true },
		{ category = "Flight Path", id = "flight_path_iters",       name = "Path Iters",           editor = "number", default = 0, read_only = true, dont_save = true },

	},
	flight_target = false,
	flight_target_range = 0,
	flight_path = false,
	flight_path_status = 0,
	flight_path_flags = false,
	flight_path_collision = false,
	flight_spline_idx = 0,
	flight_spline_dist = 0,
	flight_spline_len = 0,
	flight_spline_time = 0,
	flight_stop_on_passable = false, -- in order to achieve landing
	flight_flags = flight_default_flags,
	
	ResolveFlightTarget = pf.ResolveGotoTargetXYZ,
	CanFlyTo = return_true,
}

--- Initializes a FlyingObj instance and adds it to the FlyingObjs collection.
function FlyingObj:Init()
	FlyingObjs:insert(self)
end

---
--- Removes the FlyingObj instance from the FlyingObjs collection and unlocks the flight destination.
---
function FlyingObj:Done()
	FlyingObjs:remove(self)
	self:UnlockFlightDest()
end

---
--- Returns a table of flight path error flags that are set for the current flight path.
---
--- @return table<string, boolean> A table of flight path error flags, where the keys are the error flag names and the values are boolean indicating if the error is set.
---
function FlyingObj:GetFlightPathErrors()
	return table.invert(FlightGetErrors(self.flight_path_status))
end

---
--- Returns the number of splines in the flight path.
---
--- @return number The number of splines in the flight path.
---
function FlyingObj:GetFlightPathSplines()
	return #(self.flight_path or "")
end

---
--- Sets or clears a specific flight flag for the FlyingObj instance.
---
--- @param flag integer The flight flag to set or clear.
--- @param enable boolean Whether to enable (true) or disable (false) the flight flag.
--- @return boolean True if the flight flag was successfully set or cleared, false otherwise.
---
function FlyingObj:SetFlightFlag(flag, enable)
	enable = enable or false
	local flight_flags = self.flight_flags
	local enabled = (flight_flags & flag) ~= 0
	if enable == enabled then
		return
	end
	if enable then
		self.flight_flags = flight_flags | flag
	else
		self.flight_flags = flight_flags & ~flag
	end
	return true
end

---
--- Returns whether the specified flight flag is enabled for the FlyingObj instance.
---
--- @param flag integer The flight flag to check.
--- @return boolean True if the flight flag is enabled, false otherwise.
---
function FlyingObj:GetFlightFlag(flag)
	return (self.flight_flags & flag) ~= 0
end

---
--- Sets the flight flags for the FlyingObj instance.
---
--- @param fset table<string, boolean> A table of flight flag names and their corresponding boolean values.
---
function FlyingObj:SetFlightFlags(fset)
	self.flight_flags = FlightSetToFlags(fset)
end

---
--- Returns a table of enabled flight flags for the FlyingObj instance.
---
--- @return table<string, boolean> A table of flight flag names and their corresponding boolean values.
---
function FlyingObj:GetFlightFlags()
	return FlightFlagsToSet(self.flight_flags)
end

---
--- Sets or clears the 'adjust target' flight flag for the FlyingObj instance.
---
--- @param enable boolean Whether to enable (true) or disable (false) the 'adjust target' flight flag.
--- @return boolean True if the flight flag was successfully set or cleared, false otherwise.
---
function FlyingObj:SetAdjustFlightTarget(enable)
	return self:SetFlightFlag(ffpAdjustTarget, enable)
end

---
--- Returns whether the 'adjust target' flight flag is enabled for the FlyingObj instance.
---
--- @return boolean True if the 'adjust target' flight flag is enabled, false otherwise.
---
function FlyingObj:GetAdjustFlightTarget()
	return self:GetFlightFlag(ffpAdjustTarget)
end

---
--- Stops the flight of the FlyingObj instance by decelerating it to a stop.
---
--- If the FlyingObj is already at the final position of its flight path, this function does nothing.
---
--- Otherwise, this function calculates the final position and time it will take to decelerate the FlyingObj to a stop, sets the FlyingObj's position to that final position, and sets the FlyingObj's acceleration to the maximum deceleration value.
---
--- @return number The time it took to decelerate the FlyingObj to a stop.
---
function FlyingObj:FlightStop()
	if self:TimeToPosInterpolationEnd() == 0 then
		return
	end
	local a = -self.FlightDecelMax
	local x, y, z, dt0 = self:GetFinalPosAndTime(0, a)
	if not x then
		return
	end
	self:SetPos(x, y, z, dt0)
	self:SetAcceleration(a)
	return dt0
end

---
--- Calculates a flight path between the FlyingObj instance and the specified target position, within the given range.
---
--- @param target table The target position, as a table with x, y, z fields.
--- @param range number The maximum distance the FlyingObj is allowed to travel to reach the target.
--- @param flight_flags table A table of flight flag names and their corresponding boolean values.
--- @param debug_iter number (optional) The maximum number of iterations to use when calculating the flight path.
---
--- @return table|nil The calculated flight path, as a table of waypoints.
--- @return number|nil The error status of the flight path calculation.
--- @return table|nil The position of the first collision detected along the flight path.
---
function FlyingObj:FindFlightPath(target, range, flight_flags, debug_iter)
	if not IsValidPos(target) then
		return
	end
	flight_flags = flight_flags or self.flight_flags
	local path, error_status, collision_pos, iters = FlightCalcPathBetween(
		self, target, flight_flags,
		self.FlightMinObstacleHeight, self.FlightObjRadius, self.FlightSlopePenalty, self.FlightSmoothDist,
		range, debug_iter)
	self.flight_path = path
	self.flight_path_status = error_status
	self.flight_path_iters = iters
	self.flight_path_flags = flight_flags
	self.flight_path_collision = collision_pos
	self.flight_target = target
	self.flight_target_range = range or nil
	self.flight_spline_idx = nil
	self.flight_spline_dist = nil
	self.flight_spline_len = nil
	self.flight_spline_time = nil
	dbg(FlightDbgResults(self))
	return path, error_status, collision_pos
end

---
--- Recalculates the flight path for the FlyingObj instance based on the current flight target and flight path flags.
---
--- @return table|nil The calculated flight path, as a table of waypoints.
--- @return number|nil The error status of the flight path calculation.
--- @return table|nil The position of the first collision detected along the flight path.
---
function FlyingObj:RecalcFlightPath()
	return self:FindFlightPath(self.flight_target, self.flight_target_range, self.flight_path_flags)
end

---
--- Marks the flight area for the FlyingObj instance around the specified target.
---
--- @param target table|nil The target object to mark the flight area around. If nil, the FlyingObj instance itself is used.
---
--- @return boolean Whether the flight area was successfully marked.
---
function FlyingObj:MarkFlightArea(target)
	return FlightMarkBetween(self, target or self, self.FlightMinObstacleHeight, self.FlightObjRadius)
end

---
--- Marks the flight area for the FlyingObj instance around the specified target.
---
--- @param target table|nil The target object to mark the flight area around. If nil, the FlyingObj instance itself is used.
--- @param border number|nil The border size to use for the flight area. If nil, the default value of the FlyingObj instance is used.
---
--- @return boolean Whether the flight area was successfully marked.
---
function FlyingObj:MarkFlightAround(target, border)
	target = target or self
	return FlightMarkBetween(target, target, self.FlightMinObstacleHeight, self.FlightObjRadius, border)
end

---
--- Locks the flight destination for the FlyingObj instance to the specified coordinates.
---
--- @param x number The x-coordinate of the flight destination.
--- @param y number The y-coordinate of the flight destination.
--- @param z number The z-coordinate of the flight destination.
--- @return number, number, number The locked flight destination coordinates.
---
function FlyingObj:LockFlightDest(x, y, z)
	return x, y, z
end
FlyingObj.UnlockFlightDest = empty_func

---
--- Calculates a hash value for the flight path of the FlyingObj instance.
---
--- @param seed number The seed value to use for the hash calculation.
--- @return number|nil The calculated hash value, or nil if the flight path is empty.
---
function FlyingObj:GetPathHash(seed)
	local flight_path = self.flight_path
	if not flight_path or #flight_path == 0 then return end
	local start_idx = self.flight_spline_idx
	local spline = flight_path[start_idx]
	local hash = xxhash(seed, spline[1], spline[2], spline[3], spline[4])
	for i=start_idx + 1,#flight_path do
		spline = flight_path[i]
		hash = xxhash(hash, spline[2], spline[3], spline[4])
	end
	return hash
end

---
--- Performs a single step of the flight path for the FlyingObj instance.
---
--- @param pt table The target point for the flight path.
--- @param ... any Additional arguments for the flight path calculation.
--- @return number The time in milliseconds until the next step should be performed.
---
function FlyingObj:Step(pt, ...)
	-- TODO: implement in C
	local fx, fy, fz, range = self:ResolveFlightTarget(pt, ...)
	local tx, ty, tz = self:LockFlightDest(fx, fy, fz)
	if not tx then
		return pfFailed 
	end
	local visual_z = ResolveZ(tx, ty, tz)
	if self:IsCloser(tx, ty, visual_z, range + 1) then
		if range == 0 then
			self:SetPos(tx, ty, tz)
			self:SetAcceleration(0)
		end
		fz = fz or InvalidZ
		tz = tz or InvalidZ
		if fx ~= tx or fy ~= ty or fz ~= tz then
			return pfDestLocked 
		end
		return pfFinished
	end
	local v0 = self:GetVelocity()
	local path = self.flight_path
	local flight_target = self.flight_target
	local prev_range = self.flight_target_range
	local prev_flags = self.flight_path_flags
	local find_path = not path or not flight_target or prev_flags ~= self.flight_flags
	local time_now = GameTime()
	local spline_idx, spline_dist, spline_len
	local same_target = prev_range == range and flight_target and flight_target:Equal(tx, ty, tz)
	if not find_path and not same_target then
		-- recompute path only if the new target is far enough from the old target
		local error_dist = flight_target:Dist(tx, ty, tz)
		local retarget_offset_pct = 30
		local threshold_dist = error_dist * 100 / retarget_offset_pct
		if v0 > 0 then
			local min_retarget_time = 3000
			threshold_dist = Min(threshold_dist, v0 * min_retarget_time / 1000)
		end
		local x, y, z = ResolveVisualPosXYZ(flight_target)
		find_path = self:IsCloser(x, y, z, 1 + threshold_dist)
	end
	local step_finished
	if find_path then
		flight_target = point(tx, ty, tz)
		path = self:FindFlightPath(flight_target, range)
		if not path or #path == 0 then
			return pfFailed
		end
		assert(flight_target == self.flight_target)
		spline_idx = 0
		spline_dist = 0
		spline_len = 0
		step_finished = true
		same_target = true
	else
		spline_idx = self.flight_spline_idx
		spline_dist = self.flight_spline_dist
		spline_len = self.flight_spline_len
		step_finished = time_now - self.flight_spline_time >= 0
	end
	local spline
	local last_step
	local BS3_GetSplineLength3D = BS3_GetSplineLength3D
	if spline_dist < spline_len or not step_finished then
		spline = path[spline_idx]
	else
		while spline_dist >= spline_len do
			spline_idx = spline_idx + 1
			spline = path[spline_idx]
			if not spline then
				return pfFailed
			end
			spline_dist = 0
			spline_len = BS3_GetSplineLength3D(spline)
		end
		self.flight_spline_idx = spline_idx
		self.flight_spline_len = spline_len
	end
	assert(spline)
	if not spline then
		return pfFailed
	end
	local last_spline = path[#path]
	local flight_dest = last_spline[4]
	tx, ty, tz = flight_dest:xyz()
	local speed_min, speed_max, speed_stop = self.FlightSpeedMin, self.FlightSpeedMax, self.FlightSpeedStop
	if step_finished then
		local min_step, max_step = self.FlightPathStepMin, self.FlightPathStepMax
		assert(speed_min == speed_max and min_step == max_step or speed_min < speed_max and min_step < max_step)
		local spline_step
		if v0 <= speed_min then
			spline_step = min_step
		elseif v0 >= speed_max then
			spline_step = max_step
		else
			spline_step = min_step + (max_step - min_step) * (v0 - speed_min) / (speed_max - speed_min)
		end
		spline_step = Min(spline_step, spline_len)
		spline_dist = spline_dist + spline_step
		if spline_dist + spline_step / 2 > spline_len then
			spline_dist = spline_len
			last_step = spline_idx == #path
		end
		self.flight_spline_dist = spline_dist
	end
	
	speed_stop = speed_stop or speed_min
	local max_roll, roll_max_speed = self.FlightMaxRoll, self.FlightMaxRollSpeed
	local pitch_min, pitch_max = self.FlightMinPitch, self.FlightMaxPitch
	local yaw_max_speed, pitch_max_speed = self.FlightMaxYawSpeed, self.FlightMaxPitchSpeed
	local decel_dist = self.FlightDecelDist
	local remaining_len = spline_len - spline_dist
	local anim_stop
	local fly_anim = self.FlightAnim
	local x0, y0, z0 = self:GetVisualPosXYZ()
	local speed_lim = speed_max
	local x, y, z, dirx, diry, dirz, curvex, curvey, curvez
	local roll, pitch, yaw, accel, v, dt
	local max_dt = max_int
	if decel_dist > 0 and self:IsCloser(flight_dest, decel_dist) and (not self.flight_stop_on_passable or terrain.FindPassableZ(flight_dest, self, 0, 0)) then
		local total_remaining_len = remaining_len
		local deceleration = true
		for i = spline_idx + 1, #path do
			if total_remaining_len >= decel_dist then
				deceleration = false
				break
			end
			total_remaining_len = total_remaining_len + BS3_GetSplineLength3D(path[i])
		end
		if deceleration then
			speed_lim = speed_stop + (speed_max - speed_stop) * total_remaining_len / decel_dist
		end
		fly_anim = self.FlightAnimDecel or fly_anim
		
		local use_velocity_fov = true
		local tz1 = tz + 50 -- make LOS work for positions on a floor
		local critical_stop = deceleration and total_remaining_len < self.FlightStopDist
		local fly_anim_stop = self.FlightAnimStop
		if fly_anim and fly_anim_stop and deceleration
		and (critical_stop or self:HasFov(tx, ty, tz1, self.FlightAnimStopFOV, 0, use_velocity_fov) and TestPointsLOS(tx, ty, tz1, self, tplCheck)) then
			dt = GetAnimDuration(self:GetEntity(), fly_anim_stop) -- as the anim speed may varry
			dbg(ReportZeroAnimDuration(self, fly_anim_stop, dt))
			if dt == 0 then
				dt = 1000
			end
			x, y, z, dirx, diry, dirz = BS3_GetSplinePosDir(last_spline, 4096)
			accel, v = self:GetAccelerationAndFinalSpeed(x, y, z, dt)
			local speed_stop = Max(v0, speed_min)
			if v <= speed_stop then
				anim_stop = true
				local anim_speed = 1000
				if v < 0 then
					local stop_time
					accel, stop_time = self:GetAccelerationAndTime(x, y, z, speed_stop)
					if stop_time > self.FlightStopMinTime then
						anim_speed = 1000 * dt / stop_time
					else
						anim_stop = false
					end
				end
				if anim_stop then
					if dirx == 0 and diry == 0 then
						dirx, diry = x - x0, y - y0
					end
					yaw = atan(diry, dirx)
					roll, pitch = 0, 0
					self:SetState(fly_anim_stop)
					self:SetAnimSpeed(1, anim_speed)
					self.flight_spline_dist = spline_len
					last_step = true
				end
			end
		end
	end
	if not anim_stop then
		local roll0, pitch0, yaw0 = self:GetRollPitchYaw()
		x, y, z, dirx, diry, dirz, curvex, curvey, curvez = BS3_GetSplinePosDirCurve(spline, spline_dist, spline_len)
		if dirx == 0 and diry == 0 and dirz == 0 then
			dirx, diry, dirz = x - x0, y - y0, z - z0
		end
		
		pitch, yaw = GetPitchYaw(dirx, diry, dirz)
		pitch, yaw = pitch or pitch0, yaw or yaw0

		local step_len = self:GetVisualDist(x, y, z)
		local friction = self.FlightFriction
		local dyaw = AngleDiff(yaw, yaw0) * 100 / (100 + self.FlightYawSmooth)
		dt = v0 > 0 and MulDivRound(1000, step_len, v0) or 0 -- step time estimate
		local yaw_rot_est = dt == 0 and 0 or Clamp(1000 * dyaw / dt, -yaw_max_speed, yaw_max_speed)
		if yaw_rot_est ~= 0 then
			friction = friction + MulDivRound(self.FlightYawRotFriction, abs(yaw_rot_est), 90 * 60)
		end
		local speed_to_roll, speed_to_pitch = self.FlightSpeedToRoll, self.FlightSpeedToPitch
		local accel_max = self.FlightAccelMax
		local accel0 = accel_max - v0 * friction / 100
		v, dt = self:GetFinalSpeedAndTime(x, y, z, accel0, v0)
		v = v or speed_min
		v = Min(v, speed_lim)
		v = Max(v, Min(speed_min, v0))
		local at_max_speed = v == speed_max
		accel, dt = self:GetAccelerationAndTime(x, y, z, v)
		if not at_max_speed and speed_to_pitch > 0 then
			local mod_pitch = pitch * v / speed_max
			if speed_to_pitch == 100 then
				pitch = mod_pitch
			else
				pitch = pitch + (mod_pitch - pitch) * speed_to_pitch / 100
			end
		end
		pitch = Clamp(pitch, pitch_min, pitch_max)
		local dpitch = AngleDiff(pitch, pitch0) * 100 / (100 + self.FlightPitchSmooth)
		local pitch_rot = dt > 0 and Clamp(1000 * dpitch / dt, -pitch_max_speed, pitch_max_speed) or 0
		local yaw_rot = dt > 0 and Clamp(1000 * dyaw / dt, -yaw_max_speed, yaw_max_speed) or 0
		roll = -yaw_rot * self.FlightYawRotToRoll / 100
		if not at_max_speed and speed_to_roll > 0 then
			local mod_roll = roll * v / speed_max
			if speed_to_roll == 100 then
				roll = mod_roll
			else
				roll = roll + (mod_roll - roll) * speed_to_roll / 100
			end
		end
		roll = Clamp(roll, -max_roll, max_roll)
		local droll = AngleDiff(roll, roll0) * 100 / (100 + self.FlightRollSmooth)
		local roll_rot = dt > 0 and Clamp(1000 * droll / dt, -roll_max_speed, roll_max_speed) or 0
		if dt > 0 then
			-- limit the rotation speed
			droll = roll_rot * dt / 1000
			dyaw = yaw_rot * dt / 1000
			dpitch = pitch_rot * dt / 1000
		end
		roll = roll0 + droll
		yaw = yaw0 + dyaw
		pitch = pitch0 + dpitch
		if fly_anim then
			local anim = GetStateName(self)
			if anim ~= fly_anim then
				local fly_anim_start = self.FlightAnimStart
				if anim ~= fly_anim_start then
					self:SetState(fly_anim_start)
				else
					local remaining_time = self:TimeToAnimEnd()
					if remaining_time > anim_min_time then
						max_dt = remaining_time
					else
						self:SetState(fly_anim)
					end
				end
			else
				local min_anim_speed, max_anim_speed = self.FlightAnimSpeedMin, self.FlightAnimSpeedMax
				if dt > 0 and min_anim_speed < max_anim_speed then
					local curve = Max(GetLen(curvex, curvey, curvez), 1)
					local coef = 1024 + 1024 * curvez / curve + 1024 * abs(accel0) / accel_max
					local anim_speed = min_anim_speed + (max_anim_speed - min_anim_speed) * Clamp(coef, 0, 2048) / 2048
					self:SetAnimSpeed(1, anim_speed)
				end
			end
		end
	end

	self:SetRollPitchYaw(roll, pitch, yaw, dt)
	self:SetPos(x, y, z, dt)
	self:SetAcceleration(accel)
	
	--if self == SelectedObj then DbgSetText(self, print_format("v", v, "t", abs(rotation_speed)/60, "r", roll/60, "dt", dt)) else DbgSetText(self) end
	if not last_step and not anim_stop and dt > time_ahead then
		dt = dt - time_ahead -- fix the possibility of rendering the object immobile at the end of the interpolation
	end
	self.flight_spline_time = time_now + dt
	local sleep = Min(dt, max_dt)
	return sleep
end

---
--- Clears the flight path of the `FlyingObj` instance.
---
--- This function sets the following properties of the `FlyingObj` instance to `nil`:
--- - `flight_path`: The flight path of the object.
--- - `flight_path_status`: The status of the flight path.
--- - `flight_path_iters`: The number of iterations for the flight path.
--- - `flight_path_flags`: The flags for the flight path.
--- - `flight_path_collision`: The collision information for the flight path.
--- - `flight_target`: The target of the flight.
--- - `flight_spline_idx`: The index of the current spline in the flight path.
--- - `flight_flags`: The flags for the flight.
--- - `flight_stop_on_passable`: A flag indicating whether the flight should stop on a passable surface.
---
--- The function also unlocks the flight destination of the `FlyingObj` instance.
---
function FlyingObj:ClearFlightPath()
	self.flight_path = nil
	self.flight_path_status = nil
	self.flight_path_iters = nil
	self.flight_path_flags = nil
	self.flight_path_collision = nil
	self.flight_target = nil
	self.flight_spline_idx = nil
	self.flight_flags = nil
	self.flight_stop_on_passable = nil
	self:UnlockFlightDest()
end

FlyingObj.ClearPath = FlyingObj.ClearFlightPath

---
--- Resets the orientation of the `FlyingObj` instance to the specified `yaw` angle over the given `time`.
---
--- This function sets the roll and pitch angles of the `FlyingObj` instance to 0, and updates the yaw angle over the specified `time`.
---
--- @param time number The time in seconds over which to reset the orientation.
---
function FlyingObj:ResetOrientation(time)
	local _, _, yaw = self:GetRollPitchYaw()
	self:SetRollPitchYaw(0, 0, yaw, time)
end

---
--- Rotates the `FlyingObj` instance to face the specified `target` over the given `time`.
---
--- This function calculates the pitch and yaw angles required to rotate the `FlyingObj` instance to face the `target`, and then sets the roll, pitch, and yaw angles of the object over the specified `time`.
---
--- @param target table The target object to face.
--- @param time number The time in seconds over which to rotate the object.
---
function FlyingObj:Face(target, time)
	local pitch, yaw = GetPitchYaw(self, target)
	self:SetRollPitchYaw(0, pitch, yaw, time)
end

---
--- Returns the final destination of the flight path.
---
--- @return table|nil The final destination of the flight path, or `nil` if the flight path is empty.
---
function FlyingObj:GetFlightDest()
	local path = self.flight_path
	local last_spline = path and path[#path]
	return last_spline and last_spline[4]
end

---
--- Returns the final direction vector of the flight path.
---
--- If the flight path is empty, this function returns the current velocity vector of the `FlyingObj` instance.
--- Otherwise, it calculates the direction vector of the last spline in the flight path.
---
--- @return number, number, number The x, y, and z components of the final flight direction vector.
---
function FlyingObj:GetFinalFlightDirXYZ()
	local path = self.flight_path
	local last_spline = path and path[#path]
	if not last_spline then
		return self:GetVelocityVectorXYZ()
	end
	return BS3_GetSplineDir(last_spline, 4096, 4096)
end

---
--- Checks if the flight area for the `FlyingObj` instance is marked.
---
--- This function checks if the flight area for the `FlyingObj` instance is marked, taking into account various conditions such as the current game time, the existence of the `FlightArea` and `FlightMap` tables, the `FlightPassVersion` value, and the `FlightMinObstacleHeight` and `FlightObjRadius` properties of the `FlyingObj` instance.
---
--- If the flight area is marked, the function returns `true`. Otherwise, it returns `nil`.
---
--- @param flight_target table|nil The target object to check the flight area for. If not provided, the `flight_target` property of the `FlyingObj` instance is used.
--- @param mark_border boolean|nil Whether to check the border of the flight area. If not provided, the border is not checked.
--- @return boolean|nil `true` if the flight area is marked, `nil` otherwise.
---
function FlyingObj:IsFlightAreaMarked(flight_target, mark_border)
	flight_target = flight_target or self.flight_target
	if not flight_target
	or GameTime() ~= FlightTimestamp
	or not FlightArea or not FlightMap
	or FlightPassVersion ~= PassVersion
	or FlightMarkMinHeight ~= self.FlightMinObstacleHeight
	or FlightMarkObjRadius ~= self.FlightObjRadius then
		return
	end
	return FlightIsMarked(FlightArea, FlightMarkFrom, FlightMarkTo, FlightMarkBorder, self, flight_target, mark_border)
end

---
--- Gets the height at the specified position in the flight map.
---
--- @param x number The x-coordinate of the position.
--- @param y number The y-coordinate of the position.
--- @return number The height at the specified position.
---
function FlightGetHeightAt(x, y)
	return FlightGetHeight(FlightMap, FlightArea, x, y)
end


----

DefineClass("FlyingMovableAutoResolve")

DefineClass.FlyingMovable = {
	__parents = { "FlyingObj", "Movable", "FlyingMovableAutoResolve" },
	properties = {
		{ category = "Flight", id = "FlightPlanning",        name = "Flight Planning",          editor = "bool",   default = false, template = true, help = "Complex flight planning" },
		{ category = "Flight", id = "FlightMaxFailures",     name = "Flight Plan Max Failures", editor = "number", default = 5, template = true, help = "How many times the flight plan can fail before giving up", no_edit = PropChecker("FlightPlanning", false) },
		{ category = "Flight", id = "FlightFailureCooldown", name = "Flight Failure Cooldown",  editor = "number", default = 333, template = true, scale = "sec", help = "How often the flight plan can fail before giving up", no_edit = PropChecker("FlightPlanning", false) },
		{ category = "Flight", id = "FlightMaxWalkDist",     name = "Max Walk Dist",            editor = "number", default = 32 * guim, scale = "m", template = true, help = "Defines the max area where to use walking"},
		{ category = "Flight", id = "FlightMinDist",         name = "Min Flight Dist",          editor = "number", default = 16 * guim, scale = "m", template = true, help = "Defines the min distance to use flying"},
		{ category = "Flight", id = "FlightWalkExcess",      name = "Walk To Fly Excess",       editor = "number", default = 30, scale = "%", min = 0, template = true, help = "How much longer should be the walk path to prefer flying", },
		{ category = "Flight", id = "FlightIsHovering",      name = "Is Hovering",              editor = "bool",   default = false, template = true, help = "Is the walking above the ground" },
	},
	flying = false,
	flight_stop_on_passable = true,
	
	flight_pf_ready = false, -- pf path found
	flight_landed = false,
	flight_land_pos = false, -- land pos found
	flight_land_retry = -1,
	flight_land_target_pos = false,
	flight_takeoff_pos = false, -- take-off pos found
	flight_takeoff_retry = -1,
	flight_start_velocity = false,
	
	flight_plan_failed = 0,
	flight_plan_failures = 0,
	flight_plan_force_land = true,
	
	FlightSimHeightRestrict = const.FlightRestrictAboveWalkable,
	
	OnFlyingChanged = empty_func,
	CanTakeOff = return_true,
}

---
--- Checks if the object is on a passable terrain.
---
--- @return boolean True if the object is on a passable terrain, false otherwise.
---
function FlyingMovable:IsOnPassable()
	return terrain.FindPassableZ(self, 0, 0)
end

---
--- Checks if the object is on a passable terrain and sets the flying state accordingly.
---
--- This function is called when the object has moved. If the object is flying and the new position is on a passable terrain, the flying state is set to false.
---
--- @param self FlyingMovable The object instance.
---
function FlyingMovable:OnMoved()
	if self.flying and terrain.FindPassableZ(self, 0, 0) then
		self:SetFlying(false)
	end
end

---
--- Sets the flying state of the object.
---
--- If the object is already in the specified flying state, this function does nothing.
---
--- When setting the object to flying state:
--- - The object's acceleration is set to 0.
--- - The object's orientation is reset.
--- - The object's flight destination is unlocked.
--- - The object's resting enum flag is cleared.
---
--- When setting the object to non-flying state:
--- - The object's flight path is cleared.
--- - The object's acceleration is set to 0.
--- - The object's orientation is reset.
--- - The object's flight destination is unlocked.
--- - The object's resting enum flag is set.
---
--- @param self FlyingMovable The object instance.
--- @param flying boolean The new flying state.
---
function FlyingMovable:SetFlying(flying)
	flying = flying or false
	if self.flying == flying then
		return
	end
	self:SetAnimSpeed(1, 1000)
	if not flying then
		self:ClearFlightPath()
		self:SetAcceleration(0)
		self:ResetOrientation(0)
		self:UnlockFlightDest()
		self:SetEnumFlags(efResting)
	else
		pf.ClearPath(self)
		assert(self:GetPathPointCount() == 0)
		self:SetGravity(0)
		self:SetCurvature(false)
		self:ClearEnumFlags(efResting)
		local start_velocity = self.flight_start_velocity
		if start_velocity then
			if start_velocity == point30 then
				self:StopInterpolation()
			else
				self:SetPos(self:GetVisualPos() + start_velocity, 1000)
			end
			self.flight_start_velocity = nil
		end
	end
	self.flying = flying
	self:OnFlyingChanged(flying)
end

FlyingMovable.OnFlyingChanged = empty_func

--- Called when the FlyingMovableAutoResolve object stops moving.
---
--- If the object is flying, this function will either set the flying state to false if the object is exactly on a passable level, or clear the flight path.
---
--- It also resets various flight-related properties of the object, such as the flight path readiness, landing status, takeoff position, and start velocity.
---
--- @param self FlyingMovableAutoResolve The object instance.
--- @param pf_status boolean The pathfinding status.
function FlyingMovableAutoResolve:OnStopMoving(pf_status)
	if self.flying then
		if pf_status and IsExactlyOnPassableLevel(self) then
			-- fix flying status after landing for not planned paths
			self:SetFlying(false)
		else
			self:ClearFlightPath()
		end
	end
	self.flight_pf_ready = nil
	self.flight_landed = nil
	self.flight_land_pos = nil
	self.flight_land_target_pos = nil
	self.flight_takeoff_pos = nil
	self.flight_start_velocity = nil
	self.flight_takeoff_retry = nil
	self.flight_land_retry = nil
	self.FlightPlanning = nil
end

local function CanFlyToFilter(x, y, z, self)
	return self:CanFlyTo(x, y, z)
end

---
--- Finds a suitable landing position for the FlyingMovable object.
---
--- This function first marks the flight area around the last destination in the `flight_dests` table. It then iterates through the first 4 destinations in the table, and tries to find a landing position around each one using `FlightFindLandingAround()`. If a landing position is found, it is returned.
---
--- If no landing position is found around the destinations, the function calls `FlightFindReachableLanding()` to try to find a reachable landing position.
---
--- If no reachable landing position is found, the function checks if any of the destinations are passable. If so, it returns the first passable destination that the object can fly to.
---
--- If none of the destinations are passable, the function uses `terrain.FindReachable()` to try to find a reachable landing position around the destinations, using the `CanFlyToFilter()` function to check if the position is valid.
---
--- @param self FlyingMovable The FlyingMovable object instance.
--- @param flight_dests table A table of destination positions to search for a landing position.
--- @return table|nil The landing position, or `nil` if no suitable landing position was found.
function FlyingMovable:FindLandingPos(flight_dests)
	if not next(flight_dests) then
		return
	end
	self:MarkFlightArea(flight_dests[#flight_dests])
	local count = Min(4, #flight_dests)
	for i=1,count do
		local land_pos = FlightFindLandingAround(flight_dests[i], self, dest_search_dist)
		if land_pos then
			assert(IsPosOutside(land_pos))
			return land_pos
		end
	end
	local land_pos = FlightFindReachableLanding(flight_dests, self)
	if land_pos then
		return land_pos
	end
	local has_passable
	for _, pt in ipairs(flight_dests) do
		if self:CheckPassable(pt) then
			if self:CanFlyTo(pt) then
				return pt
			end
			has_passable = true
		end
	end
	if not has_passable then
		return
	end
	for _, pt in ipairs(flight_dests) do
		local land_pos = terrain.FindReachable(pt,
			tfrPassClass, self,
			tfrCanDestlock, self,
			tfrLimitDist, max_search_dist, 0,
			tfrLuaFilter, CanFlyToFilter, self)
		if land_pos then
			return land_pos
		end
	end
end

--- Finds a suitable takeoff position for the FlyingMovable object.
---
--- The function first marks the flight area around the object using `MarkFlightAround()`. It then attempts to find a landing position around the object using `FlightFindLandingAround()`. If no landing position is found, it tries to find a reachable landing position using `FlightFindReachableLanding()`. If that also fails and the object can take off, the object's current position is used as the takeoff position.
---
--- The function returns the takeoff position and a boolean indicating whether the takeoff position was reached.
---
--- @param self FlyingMovable The FlyingMovable object instance.
--- @return table, boolean The takeoff position and a boolean indicating whether the takeoff position was reached.
function FlyingMovable:FindTakeoffPos()
	self:MarkFlightAround(self, max_takeoff_dist)
	--DbgClear(true) DbgAddCircle(self, max_takeoff_dist) FlightDbgShow{ show_flight_map = true }
	
	local takeoff_pos, takeoff_reached = FlightFindLandingAround(self, self, max_search_dist)
	if not takeoff_pos then
		takeoff_pos, takeoff_reached = FlightFindReachableLanding(self, self, "takeoff", max_takeoff_dist)
		if not takeoff_pos and self:CanTakeOff() then
			takeoff_pos, takeoff_reached = self, true
		end
	end
	assert(IsPosOutside(takeoff_pos))
	return takeoff_pos, takeoff_reached
end
		
--- Checks if the current path of the FlyingMovable object is short enough to be walked instead of flown.
---
--- The function first checks if the path is partial. If so, it returns without further checks.
---
--- If the path is not partial, the function calculates the linear distance between the FlyingMovable object and the first path point. If the distance is greater than the provided `max_walk_dist` parameter, the function returns without further checks.
---
--- The function then calculates a "short path length" based on the linear distance, the provided `walk_excess` parameter, and the optional `min_flight_dist` parameter. It then checks the actual path length up to the short path length, ignoring tunnels. If the actual path length is less than or equal to the short path length, the function returns `true`, indicating that the path is short enough to be walked.
---
--- @param self FlyingMovable The FlyingMovable object instance.
--- @param walk_excess number The percentage of the linear distance to use as the maximum walk distance.
--- @param max_walk_dist number The maximum distance the object can walk.
--- @param min_flight_dist number The minimum distance the object must fly.
--- @return boolean True if the path is short enough to be walked, false otherwise.
function FlyingMovable:IsShortPath(walk_excess, max_walk_dist, min_flight_dist)
	if self:IsPathPartial() then
		return
	end
	local last = self:GetPathPointCount() > 0 and self:GetPathPoint(1)
	if not last then
		return true
	end
	local dist = pf.GetLinearDist(self, last)
	if max_walk_dist and dist > max_walk_dist then
		return
	end
	local short_path_len = Max(min_flight_dist or 0, Min(max_walk_dist or max_int, dist * (100 + (walk_excess or 0)) / 100))
	local ignore_tunnels = true
	local path_len = self:GetPathLen(1, short_path_len, ignore_tunnels)
	return path_len <= short_path_len
end

--- Handles the step logic for a FlyingMovable object, which can either walk or fly to a destination.
---
--- The function first checks if the object is currently flying. If so, it attempts to continue the flight path. If the flight planning is not active or the object has reached the retry time for landing, it simply calls the `FlyingObj.Step` function.
---
--- If the object is flying and the destination is a moving target, the function checks if the object can fly to the destination. If so, it clears the `flight_land_pos` and calls `FlyingObj.Step`.
---
--- If the object is flying and does not have a valid `flight_land_pos`, the function attempts to find a landing position. If a landing position is found, it is stored in `flight_land_pos` and the function calls `FlyingObj.Step` with the landing position. If a landing position cannot be found and the object is not forced to land, the function sets the `flight_land_retry` time and continues the flight.
---
--- If the object is not flying, the function checks if the `FlightWalkExcess` property is set. If so, it attempts to resolve the flight target and calls `Movable.Step` if the path is short enough to walk. If the path is not short enough, the function sets the object to flying mode and calls `self:Step(dest, ...)` again.
---
--- If the object is in flight planning mode and is not currently landed or in a retry period, the function attempts to find a takeoff position. If a takeoff position is found and the object has reached it, the function clears the `flight_takeoff_pos` and sets the object to flying mode. If the takeoff position cannot be found, the function sets the `flight_takeoff_retry` time and continues walking.
---
--- Finally, the function checks the passability of the destination and sets the object to flying mode if necessary. It then calls `self:Step(dest, ...)` again to continue the movement.
function FlyingMovable:Step(dest, ...)
	local flight_planning = self.FlightPlanning
	if self.flying then
		if not flight_planning or self.flight_land_retry > GameTime() then
			return FlyingObj.Step(self, dest, ...)
		end
		local moving_target = IsValid(dest) and dest:TimeToPosInterpolationEnd() > 0
		if moving_target and self:CanFlyTo(dest) then
			self.flight_land_pos = nil
			return FlyingObj.Step(self, dest, ...)
		end
		local land_pos = self.flight_land_pos
		if land_pos and moving_target then
			local prev_target_pos = self.flight_land_target_pos
			if not prev_target_pos or not dest:IsCloser(prev_target_pos, self.FlightMaxWalkDist / 2) then
				land_pos = false
			end
		end
		if not land_pos then
			local dests = pf.ResolveGotoDests(self, dest, ...)
			if not dests then
				return pfFailed
			end
			land_pos = self:FindLandingPos(dests)
			if not land_pos then
				if self.flight_plan_force_land then
					return pfFailed
				end
				self:SetAdjustFlightTarget(true)
				self.flight_land_retry = GameTime() + 10000 -- try continue walking
				return FlyingObj.Step(self, dest, ...)
			end
			self.flight_land_pos = land_pos
			self.flight_land_retry = nil
			self.flight_land_target_pos = moving_target and dest:GetVisualPos()
			--DbgAddVector(land_pos, 10*guim, blue) DbgAddSegment(land_pos, self, blue)
		end
		local status = FlyingObj.Step(self, land_pos)
		if status == pfFinished then
			self.flight_land_pos = nil
			self.flight_landed = true
			self:SetFlying(false)
			return self:Step(dest, ...)
		end
		return status
	end
	local walk_excess = self.FlightWalkExcess
	if not walk_excess then
		return Movable.Step(self, dest, ...)
	end
	local tx, ty, tz, max_range, min_range, dist, sl = self:ResolveFlightTarget(dest, ...)
	if sl then
		return Movable.Step(self, dest, ...)
	end
	if not tx then
		return pfFailed
	end
	local max_walk_dist, min_flight_dist = self.FlightMaxWalkDist, self.FlightMinDist
	if not self.FlightPlanning then
		local flight_pf_ready = self.flight_pf_ready
		local can_fly_to = self:CanFlyTo(tx, ty, tz)
		if not flight_pf_ready and max_walk_dist and can_fly_to then
			-- no flight planning: restrict the pf to find a path only if close enough
			if dist > max_walk_dist then
				self:SetFlying(true)
				return self:Step(dest, ...)
			end
			self:RestrictArea(max_walk_dist) -- if the pf fails then force flying
		end
		self.flight_pf_ready = true
		local status, new_path = Movable.Step(self, dest, ...)
		if status == pfFinished or not can_fly_to or (status >= 0 or status == pfTunnel) and self:IsShortPath(walk_excess, max_walk_dist, min_flight_dist) then
			return status
		end
		self:SetFlying(true)
		return self:Step(dest, ...)
	end
	if self.flight_landed or self.flight_takeoff_retry > GameTime() then
		return Movable.Step(self, dest, ...)
	end
	self.flight_start_velocity = self:GetVelocityVector(-1)
	local takeoff_pos = self.flight_takeoff_pos
	local takeoff_reached
	if not takeoff_pos then
		local pf_step = true
		local flight_pf_ready = self.flight_pf_ready
		if self:CheckPassable() then
			if not flight_pf_ready then
				pf_step = max_range == 0 and ConnectivityCheck(self, dest, ...)
			else
				pf_step = self:IsShortPath(walk_excess, max_walk_dist, min_flight_dist)
			end
		end
		if pf_step then
			self.flight_pf_ready = true
			return Movable.Step(self, dest, ...)
		end
		takeoff_pos, takeoff_reached = self:FindTakeoffPos()
		if not takeoff_pos then
			self.flight_takeoff_retry = GameTime() + 10000 -- stop searching takeoff location and continue walking
			--DbgDrawPath(self, yellow)
			return self:Step(dest, ...)
		elseif not takeoff_reached then
			-- TODO: if the takeoff path + landing path is not quite shorter than the pf path ignore the flight
			self.flight_pf_ready = nil
			self.flight_takeoff_pos = takeoff_pos
			--DbgAddVector(takeoff_pos, 10*guim, green) DbgAddSegment(takeoff_pos, self, green)
		end
	end
	if not takeoff_reached then
		local status = Movable.Step(self, takeoff_pos)
		if status ~= pfFinished then
			return status
		end
	end
	self.flight_takeoff_pos = nil
	if not terrain.IsPassable(tx, ty, tz, 0) then
		-- the destination cannot be reached by walking
		if not self:CanFlyTo(tx, ty, tz) then
			return pfFailed
		end
		self:SetFlying(true) 
	else
		local dests = pf.ResolveGotoDests(self, dest, ...)
		local land_pos = self:FindLandingPos(dests)
		if not land_pos or self:IsCloserWalkDist(land_pos, min_flight_dist) then
			self.flight_takeoff_retry = GameTime() + 10000 -- try continue walking
		else
			self.flight_land_pos = land_pos
			self:SetFlying(true)
		end
	end
	return self:Step(dest, ...)
end

---
--- Attempts to continue the movement of a flying movable object. This function is called when the previous movement attempt failed.
---
--- If the movable object is not in flight planning mode, it delegates the movement to the base `Movable:TryContinueMove()` function.
---
--- If the movable object is in flight planning mode, it first tries to continue the movement using the base `Movable:TryContinueMove()` function. If that fails, it checks the current state of the flight:
--- - If the movable object is currently flying, it checks if a landing position is set. If not, it returns without doing anything.
--- - If the movable object has landed, it clears the `flight_landed` flag and tries to take off again.
--- - If a takeoff position is set, it clears the `flight_takeoff_pos` and tries to find a new takeoff position.
--- - If the movable object can take off and the current status is not `pfDestLocked` or the linear distance to the destination is greater than or equal to `FlightTile`, it sets the `take_off` flag.
---
--- If the movable object has failed to plan a flight path recently, it checks if the failure cooldown has expired. If not, it increments the failure count. If the failure count exceeds the `FlightMaxFailures` limit, it gives up and returns without doing anything.
---
--- If the `take_off` flag is set, it calls the `TakeOff()` function to initiate the takeoff process.
---
--- Returns `true` if the movement was successfully continued, `false` otherwise.
---
function FlyingMovable:TryContinueMove(status, ...)
	if status == pfFinished then
		return
	end
	if not self.FlightPlanning then
		return Movable.TryContinueMove(self, status, ...)
	end
	local success = Movable.TryContinueMove(self, status, ...)
	if success then
		return true
	end
	local take_off
	if self.flying then
		if not self.flight_land_pos then
			return 
		end
		self.flight_land_pos = nil -- try finding another land pos?
	elseif self.flight_landed then
		self.flight_landed = nil -- try to take-off again
	elseif self.flight_takeoff_pos then
		self.flight_takeoff_pos = nil -- try to find a new take-off position
	elseif self:CanTakeOff() and (status ~= pfDestLocked or pf.GetLinearDist(self, ...) >= FlightTile) then
		take_off = true
	else
		return
	end
	local time = GameTime()
	if time - self.flight_plan_failed > self.FlightFailureCooldown then
		self.flight_plan_failures = nil
	elseif self.flight_plan_failures < self.FlightMaxFailures then
		self.flight_plan_failures = self.flight_plan_failures + 1
	else
		return -- give up
	end
	self.flight_plan_failed = time
	if take_off then
		self:TakeOff()
	end
	return true
end

--- Clears the flight path of the `FlyingMovable` object.
---
--- If the object is currently flying, this function calls `ClearFlightPath()` to clear the flight path.
--- Otherwise, it calls `Movable.ClearPath()` to clear the path.
---
--- @return boolean `true` if the path was successfully cleared, `false` otherwise.
function FlyingMovable:ClearPath()
	if self.flying then
		return self:ClearFlightPath()
	end
	return Movable.ClearPath(self)
end

--- Returns the path hash for the `FlyingMovable` object.
---
--- If the object is currently flying, this function calls `FlyingObj.GetPathHash()` to get the path hash.
--- Otherwise, it calls `Movable.GetPathHash()` to get the path hash.
---
--- @param seed number The seed value to use for generating the path hash.
--- @return number The path hash for the object.
function FlyingMovable:GetPathHash(seed)
	if self.flying then
		return FlyingObj.GetPathHash(self, seed)
	end
	return Movable.GetPathHash(self, seed)
end

--- Locks the flight destination for the `FlyingMovable` object.
---
--- This function sets the flight destination for the object and checks if the destination is reachable and passable.
--- If the destination is not reachable or passable, the function will try to find a nearby reachable and passable location as the new flight destination.
---
--- @param x number The x-coordinate of the flight destination.
--- @param y number The y-coordinate of the flight destination.
--- @param z number The z-coordinate of the flight destination.
--- @return number, number, number The x, y, and z coordinates of the final flight destination.
function FlyingMovable:LockFlightDest(x, y, z)
	local visual_z = ResolveZ(x, y, z)
	if not visual_z then
		return
	end
	-- TODO: fying destlocks
	if self.outside_pathfinder
	or not self:IsCloser(x, y, visual_z, pfSmartDestlockDist)
	or not self:CheckPassable(x, y, z)
	or PlaceDestlock(self, x, y, z) then
		return x, y, z
	end
	local flight_target = self.flight_target
	if not flight_target or flight_target:Equal(x, y, z) or not PlaceDestlock(self, flight_target) then
		-- previous target cannot be destlocked as well
		flight_target = terrain.FindReachable(x, y, z,
			tfrPassClass, self,
			tfrCanDestlock, self)
		if not flight_target then
			return
		end
		local destlocked = PlaceDestlock(self, flight_target)
		assert(destlocked)
	end
	return flight_target:xyz()
end

--- Unlocks the flight destination for the `FlyingMovable` object.
---
--- This function removes the destlock for the `FlyingMovable` object, allowing it to move to a new destination.
---
--- @return boolean `true` if the destlock was successfully removed, `false` otherwise.
function FlyingMovable:UnlockFlightDest()
	if IsValid(self) then
		return self:RemoveDestlock()
	end
end
	
--- Attempts to land the `FlyingMovable` object.
---
--- This function checks if the `FlyingMovable` object is currently flying, and if so, it attempts to find a passable location to land the object. It sets the object's position to the landing location, plays the landing animation, and sets the object's flying state to `false`.
---
--- @return boolean `true` if the landing was successful, `false` otherwise.
function FlyingMovable:TryLand()
	if not self.flying then
		return
	end
	local z = terrain.FindPassableZ(self, 32*guim) -- TODO: should go to a suitable height first
	if not z then
		return
	end
	self:ClearPath()
	local visual_z = z == InvalidZ and terrain.GetHeight(self) or z
	local x, y, z0 = self:GetVisualPosXYZ()
	local anim = self.FlightAnimStop
	local dt = anim and self:GetAnimDuration(anim) or 0
	if dt > 0 then
		self:SetState(anim)
	else
		dt = 1000
	end
	self:SetPos(x, y, visual_z, dt)
	self:SetAcceleration(0)
	self:ResetOrientation(dt)
	self:SetAnimSpeed(1, 1000)
	self:SetFlying(false)
end

--- Attempts to take off the `FlyingMovable` object.
---
--- This function calls the `TakeOff()` function to initiate the take off sequence for the `FlyingMovable` object. It returns `true` if the take off was successful.
---
--- @return boolean `true` if the take off was successful, `false` otherwise.
function FlyingMovable:TryTakeOff()
	self:TakeOff()
	return true
end

---
--- Initiates the take off sequence for the `FlyingMovable` object.
---
--- This function clears the object's path, sets the object's position to a minimum height above its current position, plays the take off animation, and sets the object's flying state to `true`.
---
--- @return number The duration of the take off animation in milliseconds.
function FlyingMovable:TakeOff()
	if self.flying then
		return
	end
	self:ClearPath()
	local x, y, z0 = self:GetVisualPosXYZ()
	local z = z0 + self.FlightSimHeightMin
	local anim = self.FlightAnimStart
	local dt = anim and self:GetAnimDuration(anim) or 0
	if dt > 0 then
		self:SetState(anim)
	else
		dt = 1000
	end
	self:SetPos(x, y, z, dt)
	self:SetAcceleration(0)
	self:SetFlying(true)
	return dt
end

---
--- Rotates the `FlyingMovable` object to face the specified target.
---
--- If the object is currently flying, this function calls the `Face()` method of the `FlyingObj` class to rotate the object. Otherwise, it calls the `Face()` method of the `Movable` class.
---
--- @param target table The target object or position to face.
--- @param time number The duration of the rotation in milliseconds.
--- @return boolean `true` if the rotation was successful, `false` otherwise.
function FlyingMovable:Face(target, time)
	if self.flying then
		return FlyingObj.Face(self, target, time)
	end
	return Movable.Face(self, target, time)
end

----

local efFlightObstacle = const.efFlightObstacle

DefineClass.FlightObstacle = {
	__parents = { "CObject" },
	flags = { cofComponentFlightObstacle = true, efFlightObstacle = true },
	FlightInitObstacle = FlightInitBox,
}

--- Clears the `efFlightObstacle` flag from the `FlightObstacle` object.
---
--- This function is called during the initialization of the `FlightObstacle` object to ensure that the `efFlightObstacle` flag is not set by default. This allows the `CompleteElementConstruction()` function to properly set the flag later on.
function FlightObstacle:InitElementConstruction()
	self:ClearEnumFlags(efFlightObstacle)
end

---
--- Completes the construction of a `FlightObstacle` object.
---
--- This function is called after the `FlightObstacle` object has been constructed. It checks if the object has the `cofComponentFlightObstacle` flag set, and if so, it sets the `efFlightObstacle` flag and calls the `FlightInitObstacle()` function to initialize the obstacle.
---
--- @return nil
function FlightObstacle:CompleteElementConstruction()
	if self:GetComponentFlags(const.cofComponentFlightObstacle) == 0 then
		return
	end
	self:SetEnumFlags(efFlightObstacle)
	self:FlightInitObstacle()
end

---
--- Called when the `FlightObstacle` object has been moved.
---
--- This function is responsible for re-initializing the flight obstacle after the object has been moved. It calls the `FlightInitObstacle()` function to ensure the obstacle is properly set up in the flight system.
---
--- @return nil
function FlightObstacle:OnMoved()
	self:FlightInitObstacle()
end

----

---
--- Initializes the flight grid maps.
---
--- This function checks if the `FlightMap` and `FlightEnergy` global variables are already set. If not, it creates the flight grid maps using the `FlightCreateGrids()` function and stores them in the global variables.
---
--- @return table, table The flight map and energy map grids.
function FlightInitGrids()
	local flight_map, energy_map = FlightMap, FlightEnergy
	if not flight_map then
		flight_map, energy_map = FlightCreateGrids(mapdata.PassBorder)
		FlightMap, FlightEnergy = flight_map, energy_map
	end
	return flight_map, energy_map
end

local test_box = box()

---
--- Marks the flight area between two points, taking into account obstacles and the map border.
---
--- This function calculates the flight area between the given `ptFrom` and `ptTo` points, considering the minimum height and object radius. It marks the obstacles and the map border, and returns the flight area and a boolean indicating whether the area was marked.
---
--- @param ptFrom table The starting point of the flight path.
--- @param ptTo table The ending point of the flight path.
--- @param min_height number The minimum height for the flight path.
--- @param obj_radius number The radius of objects to consider as obstacles.
--- @param mark_border boolean Whether to mark the map border as an obstacle.
--- @return table, boolean The flight area and a boolean indicating whether the area was marked.
function FlightMarkBetween(ptFrom, ptTo, min_height, obj_radius, mark_border)
	min_height = min_height or 0
	obj_radius = obj_radius or 0
	local marked
	local flight_area = FlightArea
	local now = GameTime()
	
	if now ~= FlightTimestamp
	or not flight_area
	or FlightPassVersion ~= PassVersion
	or FlightMarkMinHeight ~= min_height
	or FlightMarkObjRadius ~= obj_radius
	or not FlightIsMarked(flight_area, FlightMarkFrom, FlightMarkTo, FlightMarkBorder, ptFrom, ptTo, mark_border) then
		local flight_border
		local flight_map = FlightInitGrids()
		--local st = GetPreciseTicks()
		flight_area, flight_border = FlightMarkObstacles(flight_map, ptFrom, ptTo, min_height, obj_radius, mark_border)
		if not flight_area then
			return
		end
		--print("FlightMarkObstacles", GetPreciseTicks() - st)
		FlightEnergyMin = false -- mark the energy map as invalid
		FlightMarkMinHeight, FlightMarkObjRadius = min_height, obj_radius
		FlightMarkFrom, FlightMarkTo = ResolveVisualPos(ptFrom), ResolveVisualPos(ptTo) 
		FlightArea = flight_area or false
		FlightTimestamp = now
		FlightPassVersion = PassVersion
		FlightMarkBorder = flight_border
		marked = true
	end
	--dbg(FlightDbgMark(ptFrom, ptTo))
	return flight_area, marked
end

---
--- Calculates the minimum energy required to reach the given destination point, considering the flight area, slope penalty, and whether to grow obstacles.
---
--- This function calculates the minimum energy required to reach the given `ptTo` point, taking into account the `flight_area`, `slope_penalty`, and `grow_obstacles` parameters. It caches the calculated energy map to avoid redundant calculations.
---
--- @param ptTo table The destination point.
--- @param flight_area table The flight area to consider.
--- @param slope_penalty number The penalty for steep slopes.
--- @param grow_obstacles boolean Whether to grow obstacles when calculating the energy map.
--- @return table The minimum energy map, or `false` if the calculation failed.
function FlightCalcEnergyTo(ptTo, flight_area, slope_penalty, grow_obstacles)
	flight_area = flight_area or FlightArea
	slope_penalty = slope_penalty or 0
	grow_obstacles = grow_obstacles or false
	if not FlightEnergyMin
	or FlightArea ~= flight_area
	or FlightSlopePenalty ~= slope_penalty
	or FlightGrowObstacles ~= grow_obstacles
	or not FlightEnergyMin:Equal2D(GameToFlight(ptTo)) then
		--local st = GetPreciseTicks()
		FlightEnergyMin = FlightCalcEnergy(FlightMap, FlightEnergy, ptTo, flight_area, slope_penalty, grow_obstacles) or false
		FlightSlopePenalty = slope_penalty
		FlightGrowObstacles = grow_obstacles
		--print("FlightCalcEnergy", GetPreciseTicks() - st)
		if not FlightEnergyMin then
			return
		end
	end
	return FlightEnergyMin
end

---
--- Calculates the path between two points, considering obstacles, slope penalties, and smoothing.
---
--- This function calculates the path between the given `ptFrom` and `ptTo` points, taking into account obstacles, slope penalties, and smoothing. It first marks the flight area between the two points, then calculates the minimum energy required to reach the destination. If the calculation is successful, it returns the path using the `FlightFindPath` function.
---
--- @param ptFrom table The starting point.
--- @param ptTo table The destination point.
--- @param flags number The path-finding flags to use.
--- @param min_height number The minimum height to consider.
--- @param obj_radius number The radius of objects to consider.
--- @param slope_penalty number The penalty for steep slopes.
--- @param smooth_dist number The distance to consider for smoothing the path.
--- @param range number The maximum range to search for the path.
--- @param debug_iter number The number of debug iterations to perform.
--- @return table The calculated path, or `nil` if the calculation failed.
function FlightCalcPathBetween(ptFrom, ptTo, flags, min_height, obj_radius, slope_penalty, smooth_dist, range, debug_iter)
	assert(ptTo and terrain.IsPointInBounds(ptTo, mapdata.PassBorder))
	--local st = GetPreciseTicks()
	local flight_area, marked = FlightMarkBetween(ptFrom, ptTo, min_height, obj_radius)
	if not flight_area then
		return
	end
	local grow_obstacles = smooth_dist and IsCloser2D(ptFrom, ptTo, smooth_dist)
	if not FlightCalcEnergyTo(ptTo, flight_area, slope_penalty, grow_obstacles) then
		return
	end
	flags = flags or flight_default_flags
	range = range or 0
	assert(flags ~= 0)
	FlightFrom, FlightTo, FlightFlags, FlightSmoothDist, FlightDestRange = ptFrom, ptTo, flags, smooth_dist, range
	return FlightFindPath(ptFrom, ptTo, FlightMap, FlightEnergy, flight_area, flags, range, debug_iter)
end

----

---
--- Initializes the list of flight obstacles on the map.
---
--- This function iterates through all objects on the map and marks those that have the `efFlightObstacle` flag set as flight obstacles. It uses the `MapForEach` function to efficiently iterate through the objects in the play box, which is grown by the maximum object radius to ensure all relevant objects are included.
---
--- @function FlightInitObstacles
function FlightInitObstacles()
	local _, max_surf_radius = GetMapMaxObjRadius()
	local ebox = GetPlayBox():grow(max_surf_radius)
	MapForEach(ebox, efFlightObstacle, function(obj)
		return obj:FlightInitObstacle()
	end)
end

---
--- Initializes the flight obstacles for a list of objects.
---
--- This function iterates through the given list of objects and initializes the flight obstacle for each object that has the `efFlightObstacle` flag set.
---
--- @param objs table A list of objects to initialize flight obstacles for.
---
function FlightInitObstaclesList(objs)
	local GetEnumFlags = CObject.GetEnumFlags
	for _, obj in ipairs(objs) do
		if GetEnumFlags(obj, efFlightObstacle) ~= 0 then
			obj:FlightInitObstacle(obj)
		end
	end
end

function OnMsg.NewMap()
	SuspendProcessing("FlightInitObstacle", "MapLoading", true)
end

function OnMsg.PostNewMapLoaded()
	ResumeProcessing("FlightInitObstacle", "MapLoading", true)
	if not mapdata.GameLogic then
		return
	end
	FlightInitObstacles()
end

function OnMsg.PrefabPlaced(name, objs)
	if not mapdata.GameLogic or IsProcessingSuspended("FlightInitObstacle") then
		return
	end
	FlightInitObstaclesList(objs)
end

---
--- Invalidates the flight paths of flying objects that intersect the given bounding box.
---
--- This function checks the flight paths and landing/takeoff positions of all flying objects and invalidates them if they intersect the given bounding box or if the landing/takeoff positions are no longer passable or outside the map.
---
--- @param box table|nil The bounding box to check for intersections. If nil, all flight paths and landing/takeoff positions will be checked.
---
function FlightInvalidatePaths(box)
	local CheckPassable = pf.CheckPassable
	local IsPosOutside = IsPosOutside or return_true
	local Point2DInside = box and box.Point2DInside or return_true
	local FlightPathIntersectEst = FlightPathIntersectEst
	for _, obj in ipairs(FlyingObjs) do
		local flight_path = obj.flight_path
		if flight_path and #flight_path > 0 and (not box or FlightPathIntersectEst(flight_path, box, obj.flight_spline_idx)) then
			obj.flight_path = nil
		end
		local flight_land_pos = obj.flight_land_pos
		if flight_land_pos and Point2DInside(box, flight_land_pos) then
			if not CheckPassable(obj, flight_land_pos) or not IsPosOutside(flight_land_pos) then
				obj.flight_land_pos = nil
			end
		end
		local flight_takeoff_pos = obj.flight_takeoff_pos
		if flight_takeoff_pos and Point2DInside(box, flight_takeoff_pos) then
			if not CheckPassable(obj, flight_takeoff_pos) or not IsPosOutside(flight_takeoff_pos) then
				obj.flight_takeoff_pos = nil
			end
		end
	end
end

OnMsg.OnPassabilityChanged = FlightInvalidatePaths

----

---
--- Calculates the parameters for a spline between two positions with given start and end speeds.
---
--- @param start_pos Vector3 The starting position of the spline.
--- @param start_speed Vector3 The starting speed vector.
--- @param end_pos Vector3 The ending position of the spline.
--- @param end_speed Vector3 The ending speed vector.
---
--- @return table The spline points, the length of the spline, the start and end speeds, and the estimated time for the spline.
---
function GetSplineParams(start_pos, start_speed, end_pos, end_speed)
	local v0 = start_speed:Len()
	local v1 = end_speed:Len()
	local dist = start_pos:Dist(end_pos)
	assert((v0 > 0 or v1 > 0) and (v0 >= 0 and v1 >= 0))
	assert(dist >= 3)
	local pa = (dist >= 3 and v0 > 0) and (start_pos + SetLen(start_speed, dist / 3)) or start_pos
	local pb = (dist >= 3 and v1 > 0) and (end_pos - SetLen(end_speed, dist / 3)) or end_pos
	local spline = { start_pos, pa, pb, end_pos }
	local len = Max(BS3_GetSplineLength3D(spline), 1)
	local time_est = MulDivRound(1000, 2 * len, v1 + v0)
	return spline, len, v0, v1, time_est
end

---
--- Waits for an object to follow a spline path.
---
--- @param obj table The object to follow the spline.
--- @param spline table The spline points to follow.
--- @param len number The length of the spline.
--- @param v0 number The starting velocity of the object.
--- @param v1 number The ending velocity of the object.
--- @param step_time number The time in milliseconds between each step.
--- @param min_step number The minimum step size.
--- @param max_step number The maximum step size.
--- @param orient boolean Whether to orient the object along the spline.
--- @param yaw_to_roll_pct number The percentage of yaw to apply to roll.
---
--- @return nil
---
function WaitFollowSpline(obj, spline, len, v0, v1, step_time, min_step, max_step, orient, yaw_to_roll_pct)
	if not IsValid(obj) then
		return
	end
	len = len or S3_GetSplineLength3D(spline)
	v0 = v0 or obj:GetVelocityVector()
	v1 = v1 or v0
	step_time = step_time or 50
	min_step = min_step or Max(1, len/100)
	max_step = max_step or Max(min_step, len/10)
	local yaw0 = 0
	if orient and (yaw_to_roll_pct or 0) ~= 0 then
		roll, pitch, yaw0 = obj:GetRollPitchYaw()
	end
	local v = v0
	local dist = 0
	while true do
		local step = Clamp(step_time * v / 1000, min_step, max_step)
		dist = dist + step
		if dist > len - step / 2 then
			dist = len
		end
		local x, y, z, dirx, diry, dirz = BS3_GetSplinePosDir(spline, dist, len)
		v = v0 + (v1 - v0) * dist / len
		local accel, dt = obj:GetAccelerationAndTime(x, y, z, v)
		if orient then
			pitch, yaw = GetPitchYaw(dirx, diry, dirz)
			if yaw0 then
				roll = 10 * AngleDiff(yaw, yaw0) * yaw_to_roll_pct / dt
				yaw0 = yaw
			end
			obj:SetRollPitchYaw(roll, pitch, yaw, dt)
		end
		obj:SetPos(x, y, z, dt)
		obj:SetAcceleration(accel)
		if dist == len then
			Sleep(dt)
			break
		end
		Sleep(dt - dt/10)
	end
	if IsValid(obj) then
		obj:SetAcceleration(0)
	end
end

local tfpLanding = const.tfpPassClass | const.tfpCanDestlock | const.tfpLimitDist | const.tfpLuaFilter

--- Finds a valid landing position around the given position, within the specified radius range.
---
--- @param pos Vector3 The position to search around
--- @param unit Unit The unit that will be landing
--- @param max_radius number The maximum radius to search within
--- @param min_radius number The minimum radius to search within
--- @return Vector3, boolean The landing position and whether it is valid
function FlightFindLandingAround(pos, unit, max_radius, min_radius)
	local flight_map, flight_area = FlightMap, FlightArea
	local landing, valid = FlightIsLandingPos(pos, flight_map, flight_area)
	if not valid then
		return
	end
	max_radius = max_radius or max_search_dist
	min_radius = min_radius or 0
	if not unit:CheckPassable(pos) then
		return terrain.FindPassableTile(pos, tfpLanding, max_radius, min_radius, unit, unit, FlightIsLandingPos, flight_map, flight_area)
	end
	if min_radius <= 0 and landing then
		if not unit or unit:CheckPassable(pos, true) then
			return pos, true
		end
	end
	--DbgAddCircle(pt, FlightTile, red) DbgAddVector(pt, guim, red)
	return terrain.FindReachable(pos,
		tfrPassClass, unit,
		tfrCanDestlock, unit,
		tfrLimitDist, max_radius, min_radius,
		tfrLuaFilter, FlightIsLandingPos, flight_map, flight_area)
end

--- Finds a reachable landing position around the given target position, within the specified radius range.
---
--- @param target Vector3 The target position to search around
--- @param unit Unit The unit that will be landing
--- @param takeoff boolean Whether this is for a takeoff or landing
--- @param radius number The maximum radius to search within
--- @return Vector3, boolean The landing position and whether it is valid
function FlightFindReachableLanding(target, unit, takeoff, radius)
	local flight_map = FlightMap
	if not flight_map then
		return
	end
	local pfclass = unit and unit:GetPfClass() or 0
	local max_dist, min_dist = radius or max_int, 0
	local x, y, z, reached = FlightFindLanding(flight_map, target, max_dist, min_dist, unit, ConnectivityCheck, target, pfclass, 0, takeoff)
	if not x then
		return
	end
	assert(IsPosOutside(x, y, z))
	local landing = point(x, y, z)
	if reached then
		return landing, true
	end
	local src, dst
	if takeoff then
		src, dst = target, landing
	else
		src, dst = landing, target
	end
	local path, has_path = pf.GetPosPath(src, dst, pfclass)
	if not path or not has_path then
		return
	end
	local i1, i2, di
	if takeoff then
		i1, i2, di = #path - 1, 2, -1
	else
		i1, i2, di = 2, #path - 1, 1
	end
	local last_pt
	for i=i1,i2,di do
		local pt = path[i]
		if not pt then break end
		if IsValidPos(pt) then
			local found = FlightFindLandingAround(pt, unit, step_search_dist)
			--DbgAddVector(pt, guim, found and green or red) DbgAddCircle(pt, step_search_dist, found and green or red) DbgAddSegment(pt, last_pt or pt) DbgAddSegment(pt, found or pt, green)
			if found then
				assert(IsPosOutside(found))
				landing = found
				break
			end
			last_pt = pt
		end
	end
	return landing
end

----

--- Recalculates the flight path for the current FlyingObj instance.
---
--- This function is used to force a recalculation of the flight path for the
--- current FlyingObj instance. It is typically called when the target position
--- or other relevant parameters have changed, and the flight path needs to be
--- updated accordingly.
---
--- @function FlyingObj:CheatRecalcPath
--- @return nil
function FlyingObj:CheatRecalcPath()
	self:RecalcFlightPath()
end