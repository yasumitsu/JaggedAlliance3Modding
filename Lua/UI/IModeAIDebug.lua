DefineClass.IModeAIDebug = {
	__parents = { "InterfaceModeDialog" },
	HandleMouse = true,

	selected_unit = false,	
	ai_context = false,
	forced_behavior = false,
	forced_action = false,
	think_data = false,
	
	selected_voxel = false,
	voxel_rollover = false,
	squares_fx = false,
	selected_voxel_fx = false,
	best_voxel_fx = false,
	end_voxel_fx = false,
	fallback_voxel_fx = false,
	
	--optimal_scores = false,
	--reachable_scores = false,
	time_decision = false,
	time_context = false,
	time_optimal = false,
	time_endturn = false,
	time_action = false,
	time_start_ai = false,
	running_turn = false,
}

--- Opens the AI Debug interface mode.
---
--- This function is called when the AI Debug interface mode is opened. It performs the following actions:
--- - Updates the interface mode
--- - Spawns and sets up the AI Debug rollover UI element
--- - Rebuilds the visibility field for the map
--- - Makes all units visible in the hierarchy
--- - Calls the parent class's Open function to complete the initialization
---
--- @param self IModeAIDebug The instance of the IModeAIDebug class
--- @param ... Any additional arguments passed to the Open function
--- @return boolean True if the interface mode was successfully opened, false otherwise
function IModeAIDebug:Open(...)
	self:Update()
	
	self.voxel_rollover = XTemplateSpawn("AIDebugRollover", self, self)
	self.voxel_rollover:SetVisible(false)
	
	local sizex, sizey = terrain.GetMapSize()
	local bbox = box(0, 0, 0, sizex, sizey, MapSlabsBBox_MaxZ)
	
	RebuildVisField(bbox)
	
	MapForEach("map", "Unit", function(o) o:SetHierarchyEnumFlags(const.efVisible) end)
	
	return InterfaceModeDialog.Open(self, ...)
end

--- Cleans up the AI Debug interface mode.
---
--- This function is called when the AI Debug interface mode is closed. It performs the following actions:
--- - Clears any visible voxel effects
--- - Destroys the selected voxel effect, best voxel effect, end voxel effect, and fallback voxel effect objects
---
--- @param self IModeAIDebug The instance of the IModeAIDebug class
function IModeAIDebug:Done()
	self:ClearVoxelFx()
	if self.selected_voxel_fx then
		DoneObject(self.selected_voxel_fx)
		self.selected_voxel_fx = nil
	end
	if self.best_voxel_fx then
		DoneObject(self.best_voxel_fx)
		self.best_voxel_fx = nil
	end
	if self.end_voxel_fx then
		DoneObject(self.end_voxel_fx)
		self.end_voxel_fx = nil
	end
	if self.fallback_voxel_fx then
		DoneObject(self.fallback_voxel_fx)
		self.fallback_voxel_fx = nil
	end
end

--- Handles the mouse position event for the AI Debug interface mode.
---
--- This function is called when the mouse position changes while the AI Debug interface mode is active. It performs the following actions:
--- - If there is no selected unit, the function returns without doing anything.
--- - It gets the current cursor position on the terrain.
--- - If the cursor is over the same voxel as the previously selected voxel, the function returns without doing anything.
--- - If the cursor is not over a voxel, it hides the voxel rollover and clears the selected voxel effect.
--- - If the cursor is over a voxel, it places a blue square effect at the voxel position, makes the voxel rollover visible, and attaches the voxel rollover to the voxel position.
---
--- @param self IModeAIDebug The instance of the IModeAIDebug class
--- @param pt table The current cursor position
function IModeAIDebug:OnMousePos(pt)
	if not self.selected_unit then
		return
	end
	
	local voxel = GetCursorPassSlab()
	
	if voxel == self.selected_voxel then
		return
	end
	self.selected_voxel = voxel and point_pack(voxel)
	
	if not voxel then
		self.voxel_rollover:SetVisible(false)
		if self.selected_voxel_fx then
			self.selected_voxel_fx:ClearEnumFlags(const.efVisible)
		end
		return
	end
	
	self.selected_voxel_fx = PlaceSquareFX(5*guic, voxel, const.clrBlue, self.selected_voxel_fx)
	self.selected_voxel_fx:SetEnumFlags(const.efVisible)
	self.voxel_rollover:SetVisible(true)
	self.voxel_rollover:AddDynamicPosModifier({id = "attached_ui", target = voxel:SetTerrainZ()})
	ObjModified(self)
end

--- Handles the mouse button down event for the AI Debug interface mode.
---
--- This function is called when the user clicks the mouse button while the AI Debug interface mode is active. It performs the following actions:
--- - If the left mouse button is clicked and the selected unit is not the same as the clicked object, it sets the forced behavior and action to false, and creates a new game time thread to process the clicked object.
--- - If the right mouse button is clicked and there is a valid selected unit, it sets the selected unit's position to the cursor position on the terrain, resets the combat path, and processes the selected unit.
---
--- @param self IModeAIDebug The instance of the IModeAIDebug class
--- @param pt table The current cursor position
--- @param button string The mouse button that was clicked ("L" for left, "R" for right)
--- @return string "break" if the left mouse button was clicked, otherwise nil
function IModeAIDebug:OnMouseButtonDown(pt, button)
	local obj = SelectionMouseObj()
	obj = IsKindOf(obj, "Unit") and obj or nil
	local selu = self.selected_unit
	
	if button == "L" then
		if obj ~= selu then
			self.forced_behavior = false
			self.forced_action = false
			CreateGameTimeThread(self.Process, self, obj)
		end
		return "break"
	elseif button == "R" and IsValid(selu) then
		local pos = GetCursorPassSlab()
		if pos then
			CreateGameTimeThread(function()
				selu:SetPos(pos)
				CombatPathReset(selu)
				self:Process(selu)
			end)
		end
	end	
end

---
--- Processes the selected unit in the AI Debug interface mode.
---
--- This function is called to update the state of the selected unit in the AI Debug interface mode. It performs the following actions:
--- - If there is no current thread, it creates a new real-time thread to call this function.
--- - It sets the selected unit to the provided unit, if it is a valid target.
--- - If the selected unit is valid and aware, it checks if the unit has the "ManningEmplacement" status effect and if it is not assigned to an emplacement, and if so, it plays the "MGLeave" combat action.
--- - It sets the selected unit's visibility flag.
--- - It initializes the `think_data` table with `optimal_scores` and `reachable_scores` fields.
--- - It clears the `g_AIDestEnemyLOSCache` and `g_AIDestIndoorsCache` caches, and sets the `ai_context` of the selected unit to `nil`.
--- - If the selected unit starts its AI, it records the time it took to start the AI, and then calls the `Think` function of the unit's behavior.
--- - It calls `AIChooseSignatureAction` on the unit's AI context for debugging purposes.
--- - If the unit has an AI destination, it precalculates the enemy damage score for that destination.
--- - Finally, it clears any existing voxel effects and updates the UI.
---
function IModeAIDebug:Process(unit)
	if not CurrentThread() then
		CreateRealTimeThread(self.Process, self, unit)
		return
	end
	self.selected_unit = IsValidTarget(unit) and unit
	if IsValid(unit) and unit:IsAware() then	
		if unit:HasStatusEffect("ManningEmplacement") and not g_Combat:GetEmplacementAssignment(unit) then
			AIPlayCombatAction("MGLeave", unit, 0)
		end
	
		local start_time = GetPreciseTicks()
		local t, step_start_time = start_time, start_time
		
		unit:SetEnumFlags(const.efVisible)

		self.think_data = {
			optimal_scores = {},
			reachable_scores = {},
		}
	
		local t = GetPreciseTicks()
		g_AIDestEnemyLOSCache = {}
		g_AIDestIndoorsCache = {}
		unit.ai_context = nil
		if unit:StartAI(self.think_data, self.forced_behavior) then
			self.time_start_ai = GetPreciseTicks() - t
			local context = unit.ai_context
			self.ai_context = context
					
			context.behavior:Think(unit, self.think_data)
			
			AIChooseSignatureAction(context) -- for debug purposes
			
			if context.ai_destination then
				context.dbg_enemy_damage_score = {}
				AIPrecalcDamageScore(context, {context.ai_destination}, nil, context.dbg_enemy_damage_score)
			end
		end
	end
	self:ClearVoxelFx()
	self:Update()	
end

--- Moves the camera to view the specified voxel.
---
--- @param voxel table The voxel to view, represented as a table with x, y, and z fields.
function IModeAIDebug:ViewVoxel(voxel)
	local x, y, z = point_unpack(voxel)
	ViewPos(point(x, y, z))
end

---
--- Formats a voxel as a hyperlink that, when clicked, will move the camera to view the specified voxel.
---
--- @param voxel table The voxel to format as a hyperlink, represented as a table with x, y, and z fields.
--- @return string The formatted hyperlink string.
---
function IModeAIDebug:FormatVoxelHyperlink(voxel)
	local x, y, z = point_unpack(voxel)
	return string.format("<h ViewVoxel %d 255 255 255>%d, %d %s</h>", voxel, x, y, z and (", " .. z) or "")
end

---
--- Formats a destination as a hyperlink that, when clicked, will move the camera to view the specified voxel.
---
--- @param dest table The destination to format as a hyperlink, represented as a table with x, y, z, and stance_idx fields.
--- @return string The formatted hyperlink string.
---
function IModeAIDebug:FormatDestHyperlink(dest)
	local x, y, z, stance_idx = stance_pos_unpack(dest)
	return string.format("<h ViewVoxel %d 255 255 255>%d, %d %s</h>", point_pack(x, y, z), x, y, z and (", " .. z) or "")
end

---
--- Converts a voxel table to a point.
---
--- @param voxel table The voxel to convert, represented as a table with x, y, and z fields.
--- @return point The point representation of the voxel.
---
local function VoxelToPoint(voxel)
	return point(point_unpack(voxel))
end

local function DestToPoint(dest)
	local x, y, z = stance_pos_unpack(dest)
	return point(x, y, z)
end

---
--- Clears the voxel effects associated with this IModeAIDebug instance.
---
--- @param new_fx table|nil A table of new voxel effects to associate with this instance. If not provided, the existing voxel effects will be cleared.
---
function IModeAIDebug:ClearVoxelFx(new_fx)
	for _, fx in ipairs(self.squares_fx or empty_table) do
		DoneObject(fx)
	end
	self.squares_fx = new_fx
end

local function PlaceTextFx(text, pos, color)
	local dbg_text = Text:new()
	dbg_text:SetText(tostring(text))
	dbg_text:SetPos(pos)
	if color then
		dbg_text:SetColor(color)
	end
	return dbg_text
end

local ap_scale = const.Scale.AP

local function format_ap(ap)
	return ap and string.format("%d.%d", ap / ap_scale, (10*ap / ap_scale) / 10) or "N/A"
end

--- Shows the AI voxels for the selected unit based on the specified group.
---
--- @param group string The group of voxels to show. Can be one of "candidates", "collapsed", "combatpath_ap", "combatpath_score", "combatpath_dist", "combatpath_optscore", or "pathtotarget".
function IModeAIDebug:ShowAIVoxels(group)
	local fx = {}
	self:ClearVoxelFx(fx)
	if not self.selected_unit then
		return
	end
		
	if group == "candidates" then
		for _, dest in ipairs(self.ai_context.best_dests or empty_table) do
			fx[#fx + 1] = PlaceSquareFX(5*guic, DestToPoint(dest), const.clrSilverGray)			
		end
	elseif group == "collapsed" then
		for _, dest in ipairs(self.ai_context.collapsed or empty_table) do
			fx[#fx + 1] = PlaceSquareFX(5*guic, DestToPoint(dest), const.clrSilverGray)
		end
	elseif group == "combatpath_ap" then
		for _, dest in ipairs(self.ai_context.destinations or empty_table) do
			local pt = DestToPoint(dest)
			local ap = self.ai_context.dest_ap[dest]
			fx[#fx + 1] = PlaceSquareFX(5*guic, pt, const.clrYellow)
			fx[#fx + 1] = PlaceTextFx(format_ap(ap), pt, const.clrYellow)
		end
	elseif group == "combatpath_score" then
		local dest_scores = self.think_data.reachable_scores or empty_table
		local threshold = MulDivRound(self.ai_context.best_end_score, const.AIDecisionThreshold, 100)
		for _, dest in ipairs(self.ai_context.destinations or empty_table) do
			local scores = dest_scores[dest] or empty_table
			local pt =  DestToPoint(dest)
			local score = scores.final_score or 0
			local color = (score >= threshold) and const.clrWhite or const.clrOrange
			fx[#fx + 1] = PlaceSquareFX(5*guic, pt, color)
			fx[#fx + 1] = PlaceTextFx(string.format("%d", scores.final_score or 0), pt, color)
		end
	elseif group == "combatpath_dist" then
		local dists = self.ai_context.dest_dist or empty_table
		for _, dest in ipairs(self.ai_context.destinations or empty_table) do
			local dist = dists[dest]
			local pt =  DestToPoint(dest)
			fx[#fx + 1] = PlaceSquareFX(5*guic, pt, const.clrYellow)
			fx[#fx + 1] = PlaceTextFx(string.format("%s", tostring(dist)), pt, const.clrYellow)
		end
	elseif group == "combatpath_optscore" then
		local dest_scores = self.think_data.optimal_scores or empty_table
		local threshold = MulDivRound(self.ai_context.best_end_score, const.AIDecisionThreshold, 100)
		for _, dest in ipairs(self.ai_context.destinations or empty_table) do
			local scores = dest_scores[dest] or empty_table
			local pt =  DestToPoint(dest)
			local score = scores.final_score or 0
			local color = (score >= threshold) and const.clrWhite or const.clrOrange
			fx[#fx + 1] = PlaceSquareFX(5*guic, pt, color)
			fx[#fx + 1] = PlaceTextFx(string.format("%d", score), pt, color)
		end
	elseif group == "pathtotarget" then
		local reachable = self.ai_context.voxel_to_dest or empty_table
		
		for _, voxel in ipairs(self.ai_context.path_to_target or empty_table) do
			local dest = reachable[voxel]
			local clr = reachable[voxel] and const.clrYellow or const.clrRed
			local pt = VoxelToPoint(voxel)
			fx[#fx + 1] = PlaceSquareFX(5*guic, pt, clr)
			fx[#fx + 1] = PlaceTextFx(tostring(self.ai_context.dest_dist[dest]), pt, const.clrYellow)
		end
	end	
end

---
--- Sets the stance of the selected unit.
---
--- @param stance_type string The type of stance to set for the unit.
---
function IModeAIDebug:SetUnitStance(stance_type)
	local unit = self.selected_unit 
	if not IsKindOf(unit, "Unit") then
		return
	end
	
	local archetype = unit:GetArchetype()
	
	if archetype:HasMember(stance_type) then
		unit.stance = archetype[stance_type]
		unit:UpdateMoveAnim()
		unit:SetCommand("Idle")
		self:Process(unit)
	end
end

---
--- Begins the turn for the selected unit.
---
--- This function is called to start the turn for the currently selected unit in the AI debug mode.
--- It calls the `BeginTurn` method on the selected unit, passing `true` to indicate that the turn is being forced.
--- After the turn has begun, the `Process` method is called on the AI debug mode to update the UI and any other state.
---
--- @param self IModeAIDebug The AI debug mode instance.
---
function IModeAIDebug:UnitBeginTurn()
	if self.selected_unit then
		self.selected_unit:BeginTurn(true)
		self:Process(self.selected_unit)
	end
end

---
--- Executes the turn for the selected unit in the AI debug mode.
---
--- This function is called to execute the turn for the currently selected unit in the AI debug mode.
--- It first asserts that the `ai_context` is valid and that the unit in the context matches the selected unit.
--- It then creates a new game time thread to execute the turn.
--- Within the thread, it first has the unit's behavior take a stance, then begins the unit's movement if there is a destination.
--- If the unit is still valid and not dead, it then has the behavior play.
--- If the unit is still valid and not dead, it then executes any forced action or takes cover.
--- Finally, it sets the `running_turn` flag to false and calls the `Process` method to update the UI and any other state.
---
--- @param self IModeAIDebug The AI debug mode instance.
---
function IModeAIDebug:UnitExecuteTurn()
	if self.selected_unit then
		assert(self.ai_context and self.ai_context.unit == self.selected_unit)
		self.running_turn = true
		CreateGameTimeThread(function()
			local unit = self.selected_unit
			local context = self.ai_context
			context.behavior:TakeStance(unit)
			local dest = context.ai_destination
			if dest then
				context.behavior:BeginMovement(unit)
				WaitCombatActionsEnd(unit)
			end
			if IsValid(unit) and not unit:IsDead() then
				context.behavior:Play(unit)
			end
			if IsValid(unit) and not unit:IsDead() then
				local action = self.forced_action and self.ai_context.choose_actions[self.forced_action].action
				local status = AIPlayAttacks(unit, context, action) or AITakeCover(unit)
			end
			self.running_turn = false
			self:Process(self.selected_unit)
		end)
		self:Update()
	end
end

---
--- Forces the behavior of the selected unit in the AI debug mode.
---
--- This function is used to force a specific behavior on the selected unit in the AI debug mode.
--- It first retrieves the behavior data from the `think_data.behaviors` table based on the provided index.
--- If the behavior data is found, it sets the `forced_behavior` field to the behavior, and then calls the `Process` method to update the UI and any other state.
---
--- @param self IModeAIDebug The AI debug mode instance.
--- @param index number The index of the behavior to force.
---
function IModeAIDebug:UnitForceBehavior(index)
	local data = self.think_data.behaviors and self.think_data.behaviors[index]
	if data then
		self.forced_behavior = data.behavior
		self:Process(self.selected_unit)
	end
end

---
--- Forces a specific action on the selected unit in the AI debug mode.
---
--- This function is used to force a specific action on the selected unit in the AI debug mode.
--- It first retrieves the action data from the `ai_context.choose_actions` table based on the provided index.
--- If the action data is found, it sets the `forced_action` field to the index, and then calls the `Update` method to update the UI and any other state.
---
--- @param self IModeAIDebug The AI debug mode instance.
--- @param index number The index of the action to force.
---
function IModeAIDebug:UnitForceAction(index)
	assert(self.ai_context and #(self.ai_context.choose_actions or empty_table) >= index)
	self.forced_action = index
	self:Update()
end

---
--- Wakes up the selected unit in the AI debug mode.
---
--- This function is used to wake up the selected unit in the AI debug mode. It first checks if the selected unit is valid and not dead, and if the unit is not already aware. If the unit is unaware, it removes the "Unaware" status effect from the unit.
---
--- If the `reposition` parameter is true, the function sets the `running_turn` flag to true and creates a new game time thread to handle the repositioning of the unit. It first checks if the game is not in combat, and if so, it sets up a new combat instance and starts it. It then sets the unit as repositioned in the combat instance, sets the unit's command to "Reposition", and waits for the unit to become idle. Finally, it waits for any combat actions to end and sets the `running_turn` flag to false before calling the `Process` method to update the UI and any other state.
---
--- If the `reposition` parameter is false, the function simply calls the `Process` method to update the UI and any other state.
---
--- @param self IModeAIDebug The AI debug mode instance.
--- @param reposition boolean Whether to reposition the unit after waking it up.
---
function IModeAIDebug:WakeUp(reposition)
	local unit = IsValid(self.selected_unit) and self.selected_unit
	if not unit or unit:IsDead() or unit:IsAware() then
		return
	end
	
	unit:RemoveStatusEffect("Unaware")
	if reposition then
		self.running_turn = true
		CreateGameTimeThread(function()
			if not g_Combat then
				--setup combat
				local combat = Combat:new{
					stealth_attack_start = g_LastAttackStealth,
					last_attack_kill = g_LastAttackKill,
				}
				g_Combat = combat
				g_Combat.starting_unit = SelectedObj

				g_CurrentTeam = table.find(g_Teams, SelectedObj.team)

				--start combat
				combat:Start()
				WaitMsg("CombatStart")
			end
		
			g_Combat:SetRepositioned(unit, nil)
			unit:SetCommand("Reposition")
			while not unit:IsIdleCommand() do
				WaitMsg("Idle", 100)
			end
			WaitCombatActionsEnd(unit)
			self.running_turn = false
			self:Process(unit)			
		end)
		self:Update()
	else
		self:Process(unit)
	end
end

---
--- This function is used to make the selected unit unaware in the AI debug mode. It first checks if the selected unit is valid and not dead, and if the unit is already aware. If the unit is aware, it adds the "Unaware" status effect to the unit.
---
--- After adding the "Unaware" status effect, the function calls the `Process` method to update the UI and any other state.
---
--- @param self IModeAIDebug The AI debug mode instance.
---
function IModeAIDebug:MakeUnaware()
	local unit = IsValid(self.selected_unit) and self.selected_unit
	if unit and not unit:IsDead() and unit:IsAware() then
		unit:AddStatusEffect("Unaware")
		self:Process(unit)
	end
end

---
--- Processes emplacements for the selected unit.
---
--- @param self IModeAIDebug The AI debug mode instance.
--- @param mode string The mode to process emplacements, either "assign" or "reset".
---
function IModeAIDebug:ProcessEmplacements(mode)
	local unit = self.selected_unit
	if not IsValid(unit) then return end
	if mode == "assign" then
		AIAssignToEmplacements(unit.team)
	elseif mode == "reset" then
		MapForEach("map", "MachineGunEmplacement", function(obj)
			if obj.appeal then
				obj.appeal[self.selected_obj.team] = nil
			end
		end)
	end
	self:Process(self.selected_unit)
end

---
--- Updates the UI display for the AI debug mode.
---
--- This function is responsible for updating the UI text display for the AI debug mode. It checks the state of the selected unit and the AI context, and generates a detailed text report about the unit's current status, AI behavior, and other relevant information.
---
--- The function also handles the placement of various visual effects on the map, such as highlighting the best destination voxel, the fallback voxel, and the end turn destination voxel.
---
--- @param self IModeAIDebug The AI debug mode instance.
---
function IModeAIDebug:Update()
	local ctrl = self:ResolveId("idText")
	if not ctrl then return end
	
	local text = ""
	
	if not g_Combat then
		text = "<color 255 0 0>WARNING: out of combat!\n</color>\n\n"
	end
	
	if not self.selected_unit then	
		text = text .. "No unit selected"
	elseif self.running_turn then
		text = text .. string.format("Executing AI turn (%s)...", self.selected_unit.session_id)
	elseif not self.selected_unit:IsAware() then
		text = text .. string.format("Selected unit: %s, AP = %d", self.selected_unit.session_id, (self.selected_unit.ActionPoints / const.Scale.AP))
		text = text .. string.format("\n   Archetype: %s (Unaware)", self.selected_unit:GetArchetype().id)
		text = text .. string.format("\n   AI Keywords: %s", table.concat(self.selected_unit.AIKeywords or empty_table, ","))
		
		text = text .. "\n\n<center><h WakeUp 255 255 255><color 0 255 255>Alert</color></h>"
		text = text .. "   <h WakeUp reposition 255 255 255><color 0 255 255>Alert+Reposition</color></h>"				
	elseif not self.ai_context then
		text = text .. string.format("Selected unit: %s, AP = %d", self.selected_unit.session_id, (self.selected_unit.ActionPoints / const.Scale.AP))
		text = text .. string.format("\n   Archetype: %s (AI disabled)", self.selected_unit:GetArchetype().id)		
		text = text .. string.format("\n   AI Keywords: %s", table.concat(self.selected_unit.AIKeywords or empty_table, ","))
	else				
		text = text .. string.format("Selected unit: %s, AP = %d", self.selected_unit.session_id, (self.selected_unit.ActionPoints / const.Scale.AP))
		text = text .. string.format("\n   Archetype: %s", self.selected_unit:GetArchetype().id)
		text = text .. string.format("\n   AI Keywords: %s", table.concat(self.selected_unit.AIKeywords or empty_table, ","))
		
		text = text .. string.format("\n   Behavior : %s", self.ai_context.behavior:GetEditorView())
		for _, data in ipairs(self.think_data.behaviors or empty_table) do
			local score_text
			if data.disabled then
				score_text = "disabled"
			elseif data.priority then
				score_text = "priority"
			else
				score_text = data.score and tostring(data.score) or "N/A"
			end
			local behavior_text = string.format("<h UnitForceBehavior %d 255 255 255><color 255 255 0>%s</color></h>", data.index, data.name)
			text = text .. string.format("\n     %s: %s", behavior_text, score_text)
		end
		
		for _, step in ipairs(self.think_data.thihk_steps or empty_table) do
			text = text .. string.format("\n   %s: %s ms", step.label, tostring(step.time))
		end
		text = text .. string.format("\n   StartAI: %s ms", tostring(self.time_start_ai))
		text = text .. "\nCurrent unit voxel: " .. self:FormatVoxelHyperlink(self.ai_context.unit_world_voxel)
		local best_dest = self.ai_context.best_dest or self.ai_context.unit_world_voxel
		text = text .. "\n\n<color 0 255 0>Best</color> dest: " .. self:FormatDestHyperlink(best_dest)
		text = text .. string.format("\nBest voxel score: %d", self.ai_context.best_score or 0)
		local best_scores = self.think_data.optimal_scores[best_dest] or empty_table
		for i = 1, #best_scores, 2 do
			text = text .. string.format("\n  %s: %d", best_scores[i], best_scores[i+1])
		end
		self.best_voxel_fx = PlaceSquareFX(15*guic, DestToPoint(best_dest), const.clrGreen, self.best_voxel_fx)
		
		if self.ai_context.closest_dest then
			self.fallback_voxel_fx = PlaceSquareFX(15*guic, DestToPoint(self.ai_context.closest_dest), const.clrMagenta, self.fallback_voxel_fx)
		end

		if self.ai_context.best_end_dest then
			text = text .. "\n\n<color 0 255 255>End Turn</color> dest: " .. self:FormatDestHyperlink(self.ai_context.best_end_dest)
			text = text .. string.format("\nEnd Turn voxel score: %d", self.ai_context.best_end_score)
			local reach_scores = self.think_data.reachable_scores[self.ai_context.best_end_dest] or empty_table
			for i = 1, #reach_scores, 2 do
				text = text .. string.format("\n  %s: %d", reach_scores[i], reach_scores[i+1])
			end
			
			self.end_voxel_fx = PlaceSquareFX(10*guic, DestToPoint(self.ai_context.best_end_dest), const.clrCyan, self.end_voxel_fx)
		elseif self.end_voxel_fx then
			DoneObject(self.end_voxel_fx)
			self.end_voxel_fx = nil
		end
		
		if self.ai_context.ai_destination and self.ai_context.dbg_enemy_damage_score then
			text = text .. "\n\nPotential targets:"
			local target_scores = {}
			for target, score in pairs(self.ai_context.dbg_enemy_damage_score) do
				table.insert(target_scores, {target = target, score = score})
			end
			table.sortby_field_descending(target_scores, "score")
			for _, target_score in ipairs(target_scores) do
				text = text .. string.format("\n  %s: %d", target_score.target.session_id, target_score.score)
			end
		end
		
		if self.ai_context.choose_actions then
			text = text .. "\n\nActions:"
			for i, descr in ipairs(self.ai_context.choose_actions) do
				local action_name = descr.action and descr.action:GetEditorView() or "Base Attack"
				if self.forced_action == i then
					text = text .. string.format("\n  <color 0 255 0>%s: %s</color>", action_name, descr.priority and "(priority)" or tostring(descr.weight))
				elseif (descr.weight or 0) > 0 then
					text = text .. string.format("\n  <h UnitForceAction %d 255 255 255><color 255 255 0>%s: %s</color></h>", i, action_name, descr.priority and "(priority)" or tostring(descr.weight))
				else
					text = text .. string.format("\n  %s: %s", action_name, descr.priority and "(priority)" or tostring(descr.weight))
				end
			end
		end
		
		text = text .. "\n\n<center><h UnitBeginTurn 255 255 255><color 0 255 0>Begin Turn</color></h>"
		text = text .. "   <h UnitExecuteTurn 255 255 255><color 0 255 0>Execute Turn</color></h>"
		
		text = text .. "\n\n<center><h ShowAIVoxels candidates 255 255 255><color 0 255 255>Optimal Candidates</color></h>"
		text = text .. "   <h ShowAIVoxels collapsed 255 255 255><color 0 255 255>Collapsed Candidates</color></h>"
		text = text .. "\n<h ShowAIVoxels combatpath_ap 255 255 255><color 0 255 255>Combat Path (AP)</color></h>"
		text = text .. "   <h ShowAIVoxels combatpath_score 255 255 255><color 0 255 255>Combat Path (Score)</color></h>"
		text = text .. "   <h ShowAIVoxels combatpath_dist 255 255 255><color 0 255 255>Combat Path (Dist)</color></h>"
		text = text .. "\n<h ShowAIVoxels combatpath_optscore 255 255 255><color 0 255 255>Optimal Score (Reachable)</color></h>"		
		text = text .. "\n<h ShowAIVoxels pathtotarget 255 255 255><color 0 255 255>Path to Target</color></h>"
		text = text .. "\n<h ClearVoxelFx 255 255 255><color 0 255 255>Clear</color></h>"
		
		text = text .. "\n\n<h SetUnitStance MoveStance 255 255 255><color 0 255 255>Move Stance</color></h>"
		text = text .. "   <h SetUnitStance PrefStance 255 255 255><color 0 255 255>Pref Stance</color></h>"				
		text = text .. "   <h MakeUnaware 255 255 255><color 0 255 255>Make Unaware</color></h>"
		
		text = text .. "\n\n<h ProcessEmplacements assign 255 255 255><color 0 255 255>Assign Emplacements Tick (Team)</color></h>"
		text = text .. "\n\n<h ProcessEmplacements reset 255 255 255><color 0 255 255>Reset Emplacements Appeal (Team)</color></h>"
	end	

	ctrl:SetText(text)
end

---
--- Generates the rollover text for the selected voxel in the AI debug mode.
---
--- @param self IModeAIDebug The instance of the IModeAIDebug class.
--- @return string The rollover text for the selected voxel.
function IModeAIDebug:GetVoxelRolloverText()
	if not self.ai_context then
		return ""
	end
	local x, y, z = point_unpack(self.selected_voxel)
	local dest = self.ai_context.voxel_to_dest[self.selected_voxel]
	local opt_dest = dest or stance_pos_pack(x, y, z, StancesList[self.ai_context.archetype.PrefStance])
	
	local opt_scores = self.think_data.optimal_scores[opt_dest] or empty_table
	local rch_scores = self.think_data.reachable_scores[dest]
	
	local arch = self.selected_unit:GetArchetype()
	
	local x, y, z = point_unpack(self.selected_voxel)
	local text = string.format("Selected voxel: %d, %d%s", x, y, z and (", " .. z) or "")
	if dest then
		local dx, dy, dz, ds = stance_pos_unpack(dest)
		text = text .. string.format("\n  Dest: %d, %d%s, %s", dx, dy, dz and (", " .. dz) or "", StancesList[ds])
		text = text .. string.format("\n  Pathfind dist: %s", self.ai_context.dest_dist and tostring(self.ai_context.dest_dist[dest]) or "N/A")
	end
	
	local move_stance_idx = StancesList[arch.MoveStance]
	local pref_stance_idx = StancesList[arch.PrefStance]
	
	text = text .. string.format("\n  Available AP: %s (%s), %s (%s)\n",
		arch.MoveStance, format_ap(self.ai_context.dest_ap[stance_pos_pack(x, y, z, move_stance_idx)]),
		arch.PrefStance, format_ap(self.ai_context.dest_ap[stance_pos_pack(x, y, z, pref_stance_idx)]))
	
	text = text .. "\nVoxel score: " .. (opt_scores.final_score or "N/A")
	for i = 1, #opt_scores, 2 do
		text = text .. string.format("\n  %s: %d", opt_scores[i], opt_scores[i+1])
	end
	
	if rch_scores then
		text = text .. string.format("\n\nEnd Turn score: %d", rch_scores.final_score)
		for i = 1, #rch_scores, 2 do
			text = text .. string.format("\n  %s: %d", rch_scores[i], rch_scores[i+1])
		end		
	end
	
	return text
end

---
--- Places a square-shaped visual effect at the specified position.
---
--- @param fx_lines_offset number The vertical offset of the effect from the terrain height.
--- @param pos Vector3 The position to place the effect.
--- @param color Color The color of the effect.
--- @param fx Polyline The existing polyline object to use for the effect, or nil to create a new one.
--- @return Polyline The polyline object used for the effect.
function PlaceSquareFX(fx_lines_offset, pos, color, fx)
	local border = 5*guic
	local trim = const.SlabSizeX / 10
	local x, y, z = pos:xyz()
	z = (z or terrain.GetHeight(pos)) + fx_lines_offset
	local w1 = const.SlabSizeX / 2 - border
	local w2 = w1 - trim
	local path = pstr("")
	path:AppendVertex(x - w1, y - w2, z, color)
	path:AppendVertex(x - w2, y - w1, z)
	path:AppendVertex(x + w2, y - w1, z)
	path:AppendVertex(x + w1, y - w2, z)
	path:AppendVertex(x + w1, y + w2, z)
	path:AppendVertex(x + w2, y + w1, z)
	path:AppendVertex(x - w2, y + w1, z)
	path:AppendVertex(x - w1, y + w2, z)
	path:AppendVertex(x - w1, y - w2, z)
	
	if not IsValid(fx) then
		fx = PlaceObject("Polyline")
	end
	fx:SetPos(x, y, z)
	fx:SetMesh(path)
	return fx
end