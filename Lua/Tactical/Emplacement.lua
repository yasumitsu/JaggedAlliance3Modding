DefineClass.MachineGunEmplacement = {
	__parents = { "Interactable", "Object", "GameDynamicDataObject", "EditorObject", "VoxelSnappingObj", "StripComponentAttachProperties", "EntityChangeKeepsFlags" },	
	entity = "WayPoint",
	variable_entity	= true,
	flags = { efCollision = true, efApplyToGrids = false, efWalkable = false },
	properties = {
		{ category = "Emplacement", id = "weapon_template", name = "Weapon Template", editor = "preset_id", default = "BrowningM2HMG", 
			preset_class = "InventoryItemCompositeDef", preset_filter = function (preset, obj) return preset.object_class == "MachineGun" end, },
		{ category = "Emplacement", id = "ammo_template", name = "Ammo Template", editor = "preset_id", default = false, 
			preset_class = "InventoryItemCompositeDef", preset_filter = function (preset, obj)
				local wt = InventoryItemDefs[obj.weapon_template]
				return wt and preset.object_class == "Ammo" and preset.Caliber == wt.Caliber
			end, 
			no_edit = function(self) return not InventoryItemDefs[self.weapon_template] end },
		{ category = "Emplacement", id = "target_dist", name = "Target Distance", editor = "number", scale = "m", min = 3*guim, max = 20*guim, default = 10*guim, slider = true },
		
		{ category = "Usage", id = "appeal_per_target", name = "Appeal Per Target", editor = "number", default = 1000, help = "Base Appeal score per target in threatened area." },
		{ category = "Usage", id = "appeal_optimal_dist", name = "Appeal Optimal Distance", editor = "number", scale = "m", default = 15*guim, min = 0, help = "Distance at which targets in threatened area score their base Appeal Per Target points." },
		{ category = "Usage", id = "appeal_per_meter", name = "Appeal/m", editor = "number", scale = "%", default = -10, help = "Appeal modifier applied additively for each meter difference from Appeal Optimal Distance value." },
		{ category = "Usage", id = "appeal_decay", name = "Appeal Decay", editor = "number", scale = "%", default = 30, min = 0, help = "Appeal lost at the start of new turn before reevaluating potential targets.", },
		{ category = "Usage", id = "appeal_use_threshold", name = "Use Threshold", editor = "number", default = 150, help = "Appeal score above which the AI will seek to use this Emplacement." },		
		{ category = "Usage", id = "exploration_manned", name = "Manned in Exploration", editor = "bool", default = false },
		{ category = "Usage", id = "personnel_search_dist", name = "Personnel Search Distance", editor = "number", scale = "m", default = 10*guim, min = 0, no_edit = function(self) return not self.exploration_manned end, help = "Units closer than this distance can be assigned to this Emplacement." },
		{ category = "Usage", id = "start_combat_appeal", name = "Start Combat Appeal", editor = "number", default = 1000, no_edit = function(self) return not self.exploration_manned end, help = "Initial Appeal score in combat if the Emplacement is already manned." },
	},
	area_visual = false,
	interaction_visuals = false,
	manned_by = false,
	appeal = false, -- appeal score by team
	weapon = false,
	updating = false,
	exploration_personnel_chosen = false,
	exploration_update_thread = false,
}

--- Initializes the MachineGunEmplacement object.
---
--- This function is called during the object's initialization process.
--- It sets the `efCollision` flag on the object, which is typically cleared
--- by the `__PlaceObject()` function because the entity has no surfaces.
--- Ensuring the `efCollision` flag is set is important for the proper
--- functioning of the MachineGunEmplacement object.
function MachineGunEmplacement:Init()
	-- efCollision is cleared by __PlaceObject(), because the entity has no surfaces
	self:SetEnumFlags(const.efCollision)
end

--- Initializes the MachineGunEmplacement object.
---
--- This function is called during the object's initialization process.
--- It sets up an update thread that periodically calls the `ExplorationUpdateTick()` function
--- to handle updates related to the emplacement's exploration state.
---
--- @function MachineGunEmplacement:GameInit
--- @return nil
function MachineGunEmplacement:GameInit()
	if IsEditorActive() then
		self:EditorEnter()
	else
		self:EditorExit()
	end
	self.exploration_update_thread = CreateGameTimeThread(function(self)
		while IsValid(self) do
			self:ExplorationUpdateTick()
			Sleep(1000)
		end
		self.exploration_update_thread = nil
	end, self)
end

--- Cleans up the resources associated with the MachineGunEmplacement object.
---
--- This function is called when the MachineGunEmplacement object is being destroyed.
--- It performs the following cleanup tasks:
--- - Removes the area visual object, if it exists.
--- - Removes the weapon object, if it exists.
--- - Removes all interaction visual objects.
--- - Deletes the exploration update thread, if it exists.
---
--- @function MachineGunEmplacement:Done
--- @return nil
function MachineGunEmplacement:Done()
	if self.area_visual then
		DoneObject(self.area_visual)
		self.area_visual = nil
	end
	
	if self.weapon then
		DoneObject(self.weapon)
		self.weapon = nil
	end
	for _, obj in ipairs(self.interaction_visuals) do
		DoneObject(obj)
	end
	self.interaction_visuals = nil
	if IsValidThread(self.exploration_update_thread) then
		DeleteThread(self.exploration_update_thread)
		self.exploration_update_thread = nil
	end
end

--- Destroys the MachineGunEmplacement object.
---
--- If the emplacement is currently manned by a unit, the unit is forced to leave the emplacement.
--- The function then calls the `Object.Destroy()` function to destroy the emplacement object.
---
--- @function MachineGunEmplacement:Destroy
--- @return boolean # Returns the result of the `Object.Destroy()` call.
function MachineGunEmplacement:Destroy()
	if IsValid(self.manned_by) and not self.manned_by:IsDead() then
		self.manned_by:LeaveEmplacement(true)
	end
	return Object.Destroy(self)
end

--- Sets the position of the MachineGunEmplacement object.
---
--- This function is called to update the position of the emplacement object. It calls the `Interactable.SetPos()` function to set the position, and then calls the `MachineGunEmplacement:Update()` function to update the emplacement.
---
--- @function MachineGunEmplacement:SetPos
--- @param ... # The position parameters to pass to `Interactable.SetPos()`
--- @return nil
function MachineGunEmplacement:SetPos(...)
	Interactable.SetPos(self, ...)
	self:Update()
end

--- Sets the angle of the MachineGunEmplacement object.
---
--- This function is called to update the angle of the emplacement object. It calls the `Interactable.SetAngle()` function to set the angle, and then calls the `MachineGunEmplacement:Update()` function to update the emplacement.
---
--- @function MachineGunEmplacement:SetAngle
--- @param ... # The angle parameters to pass to `Interactable.SetAngle()`
--- @return nil
function MachineGunEmplacement:SetAngle(...)
	Interactable.SetAngle(self, ...)
	self:Update()
end

--- Sets a property of the MachineGunEmplacement object.
---
--- This function is used to set a property of the MachineGunEmplacement object. If the property being set is "weapon_template" or "target_dist", and the object is not currently updating, the `MachineGunEmplacement:Update()` function is called to update the emplacement.
---
--- @function MachineGunEmplacement:SetProperty
--- @param name string # The name of the property to set
--- @param value any # The value to set the property to
--- @return nil
function MachineGunEmplacement:SetProperty(name, value)
	PropertyObject.SetProperty(self, name, value)
	if name == "weapon_template" or name == "target_dist" and not self.updating then
		self:Update()
	end
end

--- Called when a property of the MachineGunEmplacement object is changed.
---
--- This function is called whenever the "weapon_template" or "target_dist" property of the MachineGunEmplacement object is changed. If the object is not currently updating, the `MachineGunEmplacement:Update()` function is called to update the emplacement.
---
--- @param prop_id string # The ID of the property that was changed
--- @return nil
function MachineGunEmplacement:OnPropertyChanged(prop_id)
	if prop_id == "weapon_template" or prop_id == "target_dist" and not self.updating then
		self:Update()		
	end
end

--- Called when the MachineGunEmplacement object enters the editor.
---
--- This function is called when the MachineGunEmplacement object enters the editor. It changes the entity of the object to the current entity, and then calls the `MachineGunEmplacement:Update()` function to update the emplacement.
---
--- @function MachineGunEmplacement:EditorEnter
--- @return nil
function MachineGunEmplacement:EditorEnter()
	self:ChangeEntity(self.entity)
	self:Update()
end

--- Called when the MachineGunEmplacement object exits the editor.
---
--- This function is called when the MachineGunEmplacement object exits the editor. It changes the entity of the object to an empty string, and then calls the `MachineGunEmplacement:Update()` function to update the emplacement.
---
--- @function MachineGunEmplacement:EditorExit
--- @return nil
function MachineGunEmplacement:EditorExit()
	self:ChangeEntity("")
	self:Update()
end

--- Sets the collision property of the MachineGunEmplacement object and its weapon visual.
---
--- This function sets the collision property of the MachineGunEmplacement object. If the object has a weapon, it also sets the collision property of the weapon's visual object.
---
--- @function MachineGunEmplacement:SetCollision
--- @param value boolean # The new collision value to set
--- @return nil
function MachineGunEmplacement:SetCollision(value)
	CObject.SetCollision(self, value)
	local weapon_visual = self.weapon and self.weapon:GetVisualObj()
	if weapon_visual then
		weapon_visual:SetCollision(value)
	end
end

--- Updates the MachineGunEmplacement object.
---
--- This function is responsible for updating the MachineGunEmplacement object. It checks if the weapon_template or target_dist properties have changed, and if so, it updates the weapon and its associated properties. It also sets up the visual and interaction properties of the emplacement.
---
--- @param self MachineGunEmplacement # The MachineGunEmplacement object to update
--- @return nil
function MachineGunEmplacement:Update()
	local weapon = self.weapon
	local ammo = weapon and weapon.ammo
	local need_update

	self.updating = true

	if weapon then
		need_update = weapon.class ~= self.weapon_template 
		if ammo then 
			need_update = need_update or (ammo.class ~= self.class)
		else
			need_update = need_update or not not InventoryItemDefs[self.class]
		end
	else
		need_update = not not InventoryItemDefs[self.weapon_template]
	end
	if need_update then
		if weapon then
			DoneObject(weapon)
			self.weapon = nil
			weapon = nil
		end
		
		if InventoryItemDefs[self.weapon_template] then
			weapon = PlaceInventoryItem(self.weapon_template)
			self.weapon = weapon
			
			local ammo_template = self.ammo_template
			if not ammo_template then
				local ammo = GetAmmosWithCaliber(weapon.Caliber, "sort")[1]
				ammo_template = ammo and ammo.id
			end
			
			if InventoryItemDefs[ammo_template] then
				local ammo = PlaceInventoryItem(ammo_template)
				ammo.Amount = weapon.MagazineSize
				weapon:Reload(ammo, "suspend fx")
				DoneObject(ammo)
			end
		end
		
		if weapon then
			-- custom prop meta for target_dist
			local min_aim_range = weapon:GetOverwatchConeParam("MinRange") * const.SlabSizeX
			local max_aim_range = weapon:GetOverwatchConeParam("MaxRange") * const.SlabSizeX
			
			self.properties = table.copy(g_Classes[self.class].properties)
			local idx = table.find(self.properties, "id", "target_dist")
			if idx then
				self.properties[idx] = { category = "Emplacement", id = "target_dist", name = "Target Distance", editor = "number", scale = "m", min = min_aim_range, max = max_aim_range, default = min_aim_range, slider = max_aim_range > min_aim_range, read_only = min_aim_range == max_aim_range }
				self:SetProperty("target_dist", min_aim_range)
			end
		else
			-- default prop meta for target_dist
			self.properties = nil
			local meta = self:GetPropertyMetadata("target_dist")
			self:SetProperty("target_dist", meta.default)
		end
	end
	
	local pos = self:GetPos()
	local angle = self:GetAngle()
	
	local visual = weapon and weapon:GetVisualObj()
	if visual then
		self:Attach(visual)
		visual:SetCollision(self:GetCollision())
	end
	
	for _, obj in ipairs(self.interaction_visuals) do
		DoneObject(obj)
	end
	self.interaction_visuals = nil
	
	if weapon and IsEditorActive() then
		-- create overwatch area
		local cone_angle = weapon.OverwatchAngle
		local min_aim_range = weapon:GetOverwatchConeParam("MinRange") * const.SlabSizeX
		local max_aim_range = weapon:GetOverwatchConeParam("MaxRange") * const.SlabSizeX
		local distance = Clamp(self.target_dist, min_aim_range, max_aim_range)
		self.target_dist = distance
		local target = pos + Rotate(point(distance, 0, 0), angle)
		local step_positions, step_objs = GetStepPositionsInArea(pos, distance, 0, cone_angle, angle, "force2d")
		step_objs = empty_table
		self.area_visual = CreateAOETilesSector(step_positions, step_objs, empty_table, self.area_visual, pos, target, 1*guim, distance, cone_angle, "Overwatch_WeaponEditor")
		
		-- interaction pos
		self.interaction_visuals = {}
		local valid = self:GetValidInteractionPositions()
		for _, pos in ipairs(valid) do
			local obj = AppearanceObject:new()
			obj:SetPos(point_unpack(pos))
			obj:ApplyAppearance("Soldier_Local_01")
			obj:SetHierarchyGameFlags(const.gofWhiteColored)
			self.interaction_visuals[#self.interaction_visuals + 1] = obj
		end
		
		if self.area_visual then
			self.area_visual:SetColorModifier((not valid or #valid == 0) and RGB(255, 0, 0) or RGB(128, 128, 128))
		end
	else
		if self.area_visual then
			DoneObject(self.area_visual)
			self.area_visual = nil
		end
	end
	ObjModified(self)
	self.updating = false
end

---
--- Returns a list of enemy units within the weapon's overwatch area.
---
--- @param attacker Unit The unit that is attacking with the emplacement.
--- @return table A list of enemy units within the overwatch area.
function MachineGunEmplacement:GetEnemyUnitsInArea(attacker)
	local weapon = self.weapon
	local units = {}

	if not weapon or not self:IsValidPos() then
		return units
	end

	local pos = self:GetPos()
	local angle = self:GetAngle()
	local target = pos + Rotate(point(self.target_dist, 0, 0), angle)

	local aoe_params = {
		cone_angle = weapon.OverwatchAngle,
		min_range = weapon:GetOverwatchConeParam("MinRange"),
		max_range = weapon:GetOverwatchConeParam("MaxRange"),
		weapon = weapon,
		attacker = attacker,
		step_pos = pos,
		target_pos = target,
		used_ammo = 1,
		damage_mod = 100,
		attribute_bonus = 0,
		dont_destroy_covers = true,
		prediction = true,
	}
	local aoe = GetAreaAttackResults(aoe_params)
	for i, aoeHit in ipairs(aoe) do
		if IsKindOf(aoeHit.obj, "Unit") and attacker:IsOnEnemySide(aoeHit.obj) then
			table.insert_unique(units, aoeHit.obj)
		end
	end
	return units
end

---
--- Retrieves the dynamic data for the MachineGunEmplacement object.
---
--- @param data table A table to store the dynamic data.
---
--- If the emplacement is manned, the handle of the manned unit is stored in the `manned_by` field of the `data` table.
--- The current condition of the emplacement's weapon is stored in the `condition` field of the `data` table.
---
function MachineGunEmplacement:GetDynamicData(data)
	if IsValid(self.manned_by) then
		data.manned_by = self.manned_by.handle
	end
	data.condition = self.weapon and self.weapon.Condition or nil
end

---
--- Sets the dynamic data for the MachineGunEmplacement object.
---
--- @param data table A table containing the dynamic data to set.
---
--- If the `data.manned_by` field is set, the corresponding unit object is stored in the `manned_by` field of the MachineGunEmplacement.
--- The `weapon.Condition` field is set to the value of the `data.condition` field, if the `weapon` field is valid.
---
function MachineGunEmplacement:SetDynamicData(data)
	if data.manned_by then
		self.manned_by = HandleToObject[data.manned_by]
	end
	self:Update() -- create the weapon before restoring its condition
	if self.weapon and data.condition then
		self.weapon.Condition = data.condition
	end
end

---
--- Returns the title of the MachineGunEmplacement object.
---
--- @return string The title of the MachineGunEmplacement object.
---
function MachineGunEmplacement:GetTitle()
	return T(163835576952, "Machine Gun")
end

---
--- Returns the appropriate CombatAction for a unit to interact with the MachineGunEmplacement.
---
--- If the emplacement is already manned, this function returns `nil` to indicate that interaction is not possible.
---
--- @param unit Unit The unit attempting to interact with the emplacement.
--- @return CombatAction|nil The appropriate CombatAction for the unit to interact with the emplacement, or `nil` if interaction is not possible.
---
function MachineGunEmplacement:GetInteractionCombatAction(unit)
	if self.manned_by then return end
	return Presets.CombatAction.Interactions.Interact_ManEmplacement
end

---
--- Returns the position where a unit can operate the MachineGunEmplacement.
---
--- @return Vector3|nil The position where a unit can operate the MachineGunEmplacement, or `nil` if the emplacement is not valid.
---
function MachineGunEmplacement:GetOperatePos()
	local visual = self.weapon and self.weapon:GetVisualObj()
	local spot = visual and visual:GetSpotBeginIndex("Unit")
	local pos = visual and visual:GetSpotPos(spot)
	return pos
end

---
--- Returns the position where a unit can interact with the MachineGunEmplacement.
---
--- If the unit is already at the operate position, this function returns that position.
--- Otherwise, it returns the closest melee range position to the operate position.
---
--- @param unit Unit The unit attempting to interact with the emplacement.
--- @return Vector3|false The position where the unit can interact with the emplacement, or `false` if the emplacement is not valid.
---
function MachineGunEmplacement:GetInteractionPos(unit)
	if not IsValid(self) then return false end
	local operate_pos = self:GetOperatePos()
	local passx, passy, passz = SnapToPassSlabXYZ(operate_pos or self)
	if unit:IsEqualPos(passx, passy, passz) then
		return point(passx, passy, passz)
	end
	local pos = unit:GetClosestMeleeRangePos(self, operate_pos, nil, "interaction")
	return pos
end

---
--- Ends the interaction between a unit and a MachineGunEmplacement.
---
--- This function performs the following actions:
--- - Enters the unit into the emplacement
--- - Recalculates the unit's UI actions
--- - Updates the unit's outfit
--- - Sets the unit's target for the machine gun based on the emplacement's angle and target distance
--- - Queues a command for the unit to set up the machine gun
---
--- @param unit Unit The unit interacting with the emplacement
---
function MachineGunEmplacement:EndInteraction(unit)
	unit:EnterEmplacement(self, false)
	unit:RecalcUIActions(true)
	unit:UpdateOutfit()
	local dist = Min(self.target_dist, CombatActions.Overwatch:GetMaxAimRange(unit, self.weapon) * const.SlabSizeX)
	local target = RotateRadius(dist, self:GetAngle(), self)
	unit:QueueCommand("MGTarget", "MGSetup", 0, {target = target})
end

---
--- Returns a list of positions where a unit can interact with the MachineGunEmplacement.
---
--- The positions returned are the closest melee range positions to the operate position of the emplacement.
---
--- @return table<Vector3> A table of positions where a unit can interact with the emplacement.
---
function MachineGunEmplacement:GetValidInteractionPositions()
	return GetMeleeRangePositions(nil, self, nil, true)
end

---
--- Returns a string describing any errors with the MachineGunEmplacement.
---
--- This function checks the following conditions and returns an error message if any are not met:
--- - The ammo template is compatible with the weapon template
--- - There are valid interaction positions for the emplacement
---
--- @return string|nil A string describing any errors, or `nil` if there are no errors.
---
function MachineGunEmplacement:GetError()
	local errors = {}
	local ammo = InventoryItemDefs[self.ammo_template]
	local weapon = InventoryItemDefs[self.weapon_template]
	if not ammo or ammo.caliber ~= weapon.caliber then
		local default_ammo
		ForEachPreset("InventoryItemCompositeDef", function(obj)
			if obj.object_class == "Ammo" and obj.Caliber == weapon.Caliber then
				default_ammo = obj.id
				return "break"
			end
		end)
	
		if default_ammo then
			self.ammo_template = default_ammo
			errors[#errors+1] = "Missing or incorrect ammo set for MG Emplacement, replaced with " .. default_ammo
		else
			errors[#errors+1] = "Missing or incorrect ammo set for MG Emplacement, compatible ammo not found"
		end
	end	
	if #(self:GetValidInteractionPositions() or "") == 0 then
		errors[#errors+1] = "MG Emplacement has no valid interaction positions"
	end
	if next(errors) then
		return table.concat(errors, "\n")
	end
end

function OnMsg.UnitDied(unit)
	MapForEach("map", "MachineGunEmplacement", function(obj)
		if obj.manned_by == unit then
			obj.manned_by = false
		end
	end)
end

function OnMsg.DeploymentModeSet()
	-- On deployment unman all machine guns
	for i, u in ipairs(g_Units) do
		if u:HasStatusEffect("ManningEmplacement") then
			u:RemoveStatusEffect("ManningEmplacement")
		end
		if u:HasStatusEffect("StationedMachineGun") then
			u:RemoveStatusEffect("StationedMachineGun")
		end
	end
end

function OnMsg.EnterSector()
	-- Clear manning emplacements leftover from other sectors or from deleted machine guns etc.
	for i, u in ipairs(g_Units) do
		if not u:HasStatusEffect("ManningEmplacement") then goto continue end
			
		local emplacementSector = u:GetEffectValue("hmg_sector")
		if emplacementSector and emplacementSector ~= gv_CurrentSectorId then
			u:RemoveStatusEffect("ManningEmplacement")
			goto continue
		end
			
		local emplacementHandle = u:GetEffectValue("hmg_emplacement")
		local emplacementObj = HandleToObject[emplacementHandle]
		if not emplacementObj then
			u:RemoveStatusEffect("ManningEmplacement")
			goto continue
		end
		
		::continue::
	end

	-- On enter sector check for emplacements that are no longer manned.
	MapForEach("map", "MachineGunEmplacement", function(obj)
		local manned = obj.manned_by
		if not IsValid(manned) or (manned and not manned:HasStatusEffect("ManningEmplacement")) then
			obj.manned_by = false
		end
	end)
end

function OnMsg.CombatStarting()
	MapForEach("map", "MachineGunEmplacement", function(obj)
		obj.appeal = {}
		if IsValid(obj.manned_by) and obj.manned_by.team and obj.manned_by.team.player_enemy then
			obj.appeal[obj.manned_by.team.side] = 1000
			g_Combat:AssignEmplacement(obj, obj.manned_by)
		end
	end) 
end

--- Periodically checks for eligible enemy units within the given radius of the machine gun emplacement, and assigns the closest eligible unit to man the emplacement.
---
--- This function is called on each tick to update the exploration state of the emplacement. It first checks if the emplacement is already manned or if combat is in progress, in which case it returns early. Otherwise, it searches for eligible enemy units within the personnel search distance and assigns the closest one to man the emplacement if possible.
---
--- @param self MachineGunEmplacement The emplacement object.
function MachineGunEmplacement:ExplorationUpdateTick()
	if self.exploration_personnel_chosen then
		if self.exploration_personnel_chosen.command == "InteractWith" then
			return
		end
		self.exploration_personnel_chosen = false
	end
	if g_Combat or not self.exploration_manned or IsValid(self.manned_by) then
		return
	end
	-- look for eligible (enemy) units in the given radius
	local gunner 
	local mindist = self.personnel_search_dist + 1
	for _, team in ipairs(g_Teams) do
		if team.player_enemy then
			for _, unit in ipairs(team.units) do
				if IsCloser(self, unit, gunner or mindist) then
					if not unit:IsIncapacitated() and not unit:HasStatusEffect("Unconscious") then
						gunner = unit
					end
				end
			end
		end
	end
	if gunner then
		-- tell the unit to interact with the emplacement and mark them somehow so we don't find another on the next tick
		local action = self:GetInteractionCombatAction(gunner)
		if action and gunner:CanInteractWith(self) then
			if AIStartCombatAction(action.id, gunner, 0, {target = self}) then
				self.exploration_personnel_chosen = gunner
			end
		end
	end
end
