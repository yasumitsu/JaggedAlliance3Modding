local easingIndex = GetEasingIndex("Sin in")
local Lerp = Lerp
local EaseCoeff = EaseCoeff
local easeInterval = 25

DefineClass.SneakProjector = {
	flags = { efApplyToGrids = false },
	__parents = { "CommandObject", "GameDynamicDataObject", "EditorObject" },
	properties = {
		category = "Game Logic",
		{ id = "Positions", name = "Positions", editor = "point_list", helper = "relative_pos_list", default = false },
		{ id = "SweepDuration", name = "Sweep Duration", editor = "number", default = 10000 },
		{ id = "SweepDurationPerCombatTurn", name = "Combat Sweep Segment (Time)", editor = "number", default = 2000 },
		{ id = "SweepBetween", name = "Time Between Sweeps", editor = "number", default = 5000 },
	},
	
	base_euler = false, -- The one the object was spawned with.
	
	-- State
	last_point = 0,
	target_point = 0,
	starting_yaw = false, -- The yaw at the start of the current interpolation
	time_passed = false,
	time_between = false,
	
	attaches_destroyed = false
}

---
--- Sets the dynamic data for the SneakProjector object.
---
--- @param data table The dynamic data to set.
---   @field target_point number The target point for the projection.
---   @field last_point number The last point of the projection.
---   @field time_passed number The time passed since the last projection.
---   @field time_between number The time between projections.
---   @field starting_yaw number The starting yaw of the projection.
---   @field base_euler table The base Euler angles of the projection.
function SneakProjector:SetDynamicData(data)
	self.target_point = data.target_point or 0
	self.last_point = data.last_point or 0
	self.time_passed = data.time_passed
	self.time_between = data.time_between
	self:SetCommand("Idle")
	self.starting_yaw = data.starting_yaw
	self.base_euler = data.base_euler
end

---
--- Gets the dynamic data for the SneakProjector object.
---
--- @param data table The table to store the dynamic data in.
---   @field target_point number The target point for the projection.
---   @field last_point number The last point of the projection.
---   @field time_passed number The time passed since the last projection.
---   @field time_between number The time between projections.
---   @field starting_yaw number The starting yaw of the projection.
---   @field base_euler table The base Euler angles of the projection.
function SneakProjector:GetDynamicData(data)
	data.target_point = self.target_point
	data.last_point = self.last_point
	data.time_passed = self.time_passed
	data.time_between = self.time_between
	data.starting_yaw = self.starting_yaw
	data.base_euler = self.base_euler
end

---
--- Initializes the base Euler angles for the SneakProjector object.
---
--- This function is called during the initialization of the SneakProjector object.
--- It sets the initial base Euler angles of the projection by calling the `GetRollPitchYaw()` function.
---
function SneakProjector:GameInit()
	self.base_euler = {self:GetRollPitchYaw()}
end

---
--- Called when the editor is exited.
--- This function sets the base Euler angles of the SneakProjector object to the current roll, pitch, and yaw, and sets the command to "Idle".
---
--- This is likely done to ensure the SneakProjector is in a known state when the editor is exited, in case new points have been added to the projection.
---
function SneakProjector:EditorExit()
	self.base_euler = {self:GetRollPitchYaw()}
	self:SetCommand("Idle") -- New points might have been added and so
end

---
--- Handles the idle state of the SneakProjector object.
---
--- This function is called when the SneakProjector is in the "Idle" state. It checks if there are any living enemy units on the map, and if not, it stops the sweep and light effects. If there are living enemies, it attaches any destroyed objects and handles the light effects. If the SneakProjector has no positions defined, it halts the execution. Otherwise, it sets the target point for the next sweep and starts the "Sweep" command, unless the game is in combat mode.
---
--- @param self SneakProjector The SneakProjector object.
---
function SneakProjector:Idle()
	-- Stop sweep and light if no enemies on map.
	local enemyTeam1 = table.find_value(g_Teams, "side", "enemy1")
	local anyLivingEnemies = false
	for i, u in ipairs(enemyTeam1 and enemyTeam1.units) do
		if not u:IsDead() then
			anyLivingEnemies = true
			break
		end
	end
	if not anyLivingEnemies then
		local enemyTeam2 = table.find_value(g_Teams, "side", "enemy2")
		for i, u in ipairs(enemyTeam2 and enemyTeam2.units) do
			if not u:IsDead() then
				anyLivingEnemies = true
				break
			end
		end
	end

	local showProjectors = 
		(not gv_Sectors or	not gv_CurrentSectorId) or
		(gv_Sectors[gv_CurrentSectorId].Side ~= "player1" and anyLivingEnemies) 
	if showProjectors then
		if self.attaches_destroyed then
			assert(self:IsValidPos(), "SneakProjector tries to create auto attaches while still invalid!")
			self:AutoAttachObjects()
			self:ForEachAttach("Light", Stealth_HandleLight)
		end
		if type(self.attaches_destroyed) == "table" then
			self:SetSIModulation(self.attaches_destroyed.SIModulation)
		end
		self.attaches_destroyed = false
	else
		local lights = self:GetAttaches("Light")
		for i, l in ipairs(lights) do
			KillStealthLightForLight(l)
		end
		self:DestroyAttaches()
		self.attaches_destroyed = {SIModulation = self:GetSIModulation()}
		self:SetSIModulation(0)
		
		Halt()
		return
	end
	
	Msg("ProjectorIdle", self)
	if not self.Positions or #self.Positions == 0 then Halt() end

	if self.last_point > #self.Positions or self.last_point == 0 then
		self.last_point = 0
	end
	self.target_point = self.last_point + 1
	if self.target_point > #self.Positions then
		self.target_point = 1
	end
	
	-- Dont automatically sweep in combat.
	if g_Combat then
		Halt()
		return
	end

	-- Start auto sweeping
	self:SetCommand("Sweep")
end

--- Returns the yaw angle of the SneakProjector object.
---
--- This function extracts the yaw angle from the roll, pitch, and yaw values
--- returned by the `GetRollPitchYaw()` function. The yaw angle represents the
--- rotation around the vertical axis.
---
--- @return number The yaw angle of the SneakProjector object.
function SneakProjector:GetYaw()
	local r, p, y = self:GetRollPitchYaw()
	return y
end

---
--- Sweeps the SneakProjector object through a series of positions, rotating the object to face each position in turn.
---
--- The sweep can be performed in two modes:
--- - "segment" mode: Sweeps for a fixed duration of `SweepDurationPerCombatTurn` seconds.
--- - "snap-to-segment" mode: Snaps the sweep to the next combat turn segment.
---
--- The sweep can be interrupted by entering combat mode, in which case the sweep is paused and resumed when combat ends.
---
--- @param length string The sweep mode, either "segment" or "snap-to-segment".
function SneakProjector:Sweep(length)
	if self:GetEnumFlags(const.efApplyToGrids) ~= 0 then
		self:ClearEnumFlags(const.efApplyToGrids)
		StoreErrorSource(self, "SneakProjector enum flags cleared!. Resave the map.")
	end

	local timePassed = self.time_passed or 0
	self.time_passed = timePassed
	local max_time

	if length == "snap-to-segment" then
		if not self.time_passed then
			length = "segment"
		else
			max_time = MulDivRound(self.time_passed, 1, self.SweepDurationPerCombatTurn) * self.SweepDurationPerCombatTurn
		end
	end
	
	if length == "segment" then -- Used for combat
		max_time = timePassed + self.SweepDurationPerCombatTurn
	end

	-- Resuming in between wait.
	if self.time_between then
		if max_time then -- In combat the wait is in turns.
			self.time_between = self.time_between - 1
			if self.time_between == 0 then self.time_between = false end
		else
			self:BetweenSweepWait()
		end
		return
	end

	local p = self.Positions and self.Positions[self.target_point]
	if not p then
		self.last_point = self.last_point + 1
		self:SetCommand("Idle")
		return
	end
	
	local startingYaw = self.starting_yaw or self:GetYaw()
	self.starting_yaw = startingYaw
	
	local finalAngle = atan(p)
	local prevTime = GameTime()
	local sweepDuration = self.SweepDuration
	local lerpFunc = AngleLerp(startingYaw, finalAngle, sweepDuration, true)
	while sweepDuration >= timePassed do
		local deltaTime = (GameTime() - prevTime)
		timePassed = timePassed + deltaTime
		prevTime = GameTime()
		self.time_passed = timePassed

		local angle = lerpFunc(EaseCoeff(easingIndex, timePassed, sweepDuration))

		-- Rotate only around Z (yaw) and keep the roll and pitch level designers placed it with.
		self:SetRollPitchYaw(self.base_euler[1], self.base_euler[2], angle, easeInterval)
		Sleep(easeInterval)
		
		if not g_Combat then ResetVoxelStealthParamsCache() end
		if max_time and timePassed >= max_time then
			ResetVoxelStealthParamsCache()
			self:SetCommand("Idle")
			return
		end
	end
	
	-- Snap to end to prevent accumulated imprecision.
	self:SetRollPitchYaw(self.base_euler[1], self.base_euler[2], finalAngle)
	ResetVoxelStealthParamsCache()
	self.last_point = self.target_point
	self:Reset()
	
	if max_time then
		self.time_between = 1 -- In combat the wait is in turns.
	else
		self:BetweenSweepWait()
	end
end

---
--- Waits for a specified duration between sweeps of the SneakProjector.
---
--- @param max_time number|nil Maximum time to wait, in seconds. If not provided, the wait duration is determined by the SweepBetween property.
---
function SneakProjector:BetweenSweepWait(max_time)
	local timePassed = self.time_between or 0
	self.time_between = timePassed
	
	while timePassed < self.SweepBetween do
		Sleep(easeInterval)
		timePassed = timePassed + easeInterval
		self.time_between = timePassed
	end
	self.time_between = false
	self:SetCommand("Idle")
end

---
--- Resets the state of the SneakProjector object.
---
--- This function resets the following properties of the SneakProjector object:
--- - `target_point`: Set to `false`.
--- - `start_time`: Set to `false`.
--- - `time_passed`: Set to `false`.
--- - `starting_yaw`: Set to `false`.
---
--- This function is typically called to prepare the SneakProjector for a new sweep or sweep sequence.
---
function SneakProjector:Reset()
	self.target_point = false
	self.start_time = false
	self.time_passed = false
	self.starting_yaw = false
end

MapVar("MapHasProjectors", false)
MapVar("ProjectorsCombatTurnExecuted", false)
function OnMsg.CombatStart()
	MapForEach("map", "SneakProjector", function(obj)
		MapHasProjectors = true
	
		-- If waiting between sweeps, stop.
		if obj.time_between then
			obj.time_between = false
			obj:SetCommand("Idle")
		else
		-- If sweeping, snap to the next combat sweep segment.
			obj:SetCommand("Sweep", "snap-to-segment")
		end
	end)
end

local function lResetExplorationSneakProjects()
	MapForEach("map", "SneakProjector", function(obj)
		obj:SetCommand("Idle")
	end)
	ProjectorsCombatTurnExecuted = false
end

function OnMsg.EnterSector()
	lResetExplorationSneakProjects()
end

function OnMsg.DbgStartExploration()
	lResetExplorationSneakProjects()
end

function OnMsg.CombatEnd()
	lResetExplorationSneakProjects()
end

--- Returns a table of all the SneakProjector lights in the game.
---
--- This function iterates through the `StealthLights` table and returns a new table containing only the lights that are parented to a `SneakProjector` object.
---
--- @return table The table of SneakProjector lights.
function GetSneakProjectorLights()
	local objs = {}
	for i, o in ipairs(StealthLights) do
		local ogLight = o.original_light
		local projector = ogLight and ogLight:GetParent()
		if IsKindOf(projector, "SneakProjector") and IsValid(o) then
			objs[#objs + 1] = o
		end
	end
	return objs
end

--- Runs the projectors' sweep command and waits for them to finish.
---
--- This function iterates through all the SneakProjector objects in the current map,
--- sets their command to "Sweep" with the "segment" parameter, and then waits for
--- each projector to finish its sweep and return to the "Idle" state.
---
--- Once all projectors have finished sweeping, the function sets the
--- `ProjectorsCombatTurnExecuted` global variable to the current combat turn.
function RunProjectorTurnAndWait()
	local projectors = MapGet("map", "SneakProjector")
	for i, p in ipairs(projectors or empty_table) do
		p:SetCommand("Sweep", "segment")
	end
	
	for i, p in ipairs(projectors or empty_table) do
		while p.command ~= "Idle" do
			WaitMsg("ProjectorIdle", 500)
		end
	end
	
	ProjectorsCombatTurnExecuted = g_Combat.current_turn
end