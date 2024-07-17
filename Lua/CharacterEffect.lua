UndefineClass("CharacterEffect")
UndefineClass("StatusEffect")
UndefineClass("Perk")

DefineClass("CharacterEffect", "Modifiable", "CharacterEffectProperties")
DefineClass("StatusEffect", "CharacterEffect")
DefineClass("Perk", "CharacterEffect", "PerkProperties")

const.DbgStatusEffects = false

---
--- Resolves the value of a property for the `CharacterEffect` object.
---
--- First, it checks if the property value is defined directly on the `CharacterEffect` object. If so, it returns that value.
---
--- If the property is not defined on the `CharacterEffect` object, it checks if the object has `InstParameters` (instance parameters) and if a parameter with the same name as the property key exists. If so, it returns the value of that parameter.
---
--- If the property is not found in the `InstParameters`, it checks the `CharacterEffectDefs` table for a template with the same class as the `CharacterEffect` object. If a template is found, it recursively calls the `ResolveValue` function on the template to try to resolve the property value.
---
--- @param self CharacterEffect The `CharacterEffect` object to resolve the property value for.
--- @param key string The name of the property to resolve.
--- @return any The resolved value of the property, or `nil` if the property could not be found.
function CharacterEffect:ResolveValue(key)
	local value = self:GetProperty(key)
	if value then return value end
	
	-- Check in the instance parameters first.
	if self.InstParameters then
		local found = table.find_value(self.InstParameters, "Name", key)
		if found then
			return found.Value
		end
	end
	-- Check in the template
	local template = CharacterEffectDefs[self.class]
	return template and template:ResolveValue(key)
end

---
--- Generates a Lua code string that places a CharacterEffect object with the specified properties.
---
--- @param self CharacterEffect The CharacterEffect object to generate the code for.
--- @param indent string (optional) The indentation to use for the generated code.
--- @param pstr string (optional) A string buffer to append the generated code to.
--- @param GetPropFunc function (optional) A function to get the property value for the CharacterEffect object.
--- @return string The generated Lua code that places the CharacterEffect object.
---
function CharacterEffect:__toluacode(indent, pstr, GetPropFunc)
	if not pstr then
		return string.format("PlaceCharacterEffect('%s', %s)", self.class, ObjPropertyListToLuaCode(self, indent, GetPropFunc))
	end
	pstr:appendf("PlaceCharacterEffect('%s', ", self.class)
	ObjPropertyListToLuaCode(self, indent, GetPropFunc, pstr)
	return pstr:append(")")
end

---
--- Returns the character effect ID for the given object.
---
--- If the object is a `CharacterEffect`, the function returns the class name of the `CharacterEffect`.
--- If the object is a `CharacterEffectCompositeDef`, the function returns the ID of the `CharacterEffectCompositeDef`.
---
--- @param self any The object to get the character effect ID for.
--- @return string The character effect ID.
---
function GetCharacterEffectId(self)
	if IsKindOf(self, "CharacterEffect") then 
		return self.class 
	end
	if IsKindOf(self, "CharacterEffectCompositeDef") then 
		return self.id 
	end
end

-- CompositeDef code
DefineClass.CharacterEffectCompositeDef = {
	__parents = { "CompositeDef", "MsgActorReactionsPreset" },
	
	-- Composite def
	ObjectBaseClass = "CharacterEffect",
	ComponentClass = false,
	
	-- Preset
	EditorMenubarName = "Character Effect Editor",
	EditorMenubar = "Combat",
	EditorMenubarSortKey = "-8",
	EditorShortcut = "",
	EditorIcon = "CommonAssets/UI/Icons/atom molecule science.png",
	EditorPreview = Untranslated("<Group> <StatValue>"),
	GlobalMap = "CharacterEffectDefs",
	Documentation = CompositeDef.Documentation .. "\n\nCreates a new character effect preset that could be added/removed from a unit.",
	
	HasParameters = true,
	HasSortKey = true,
	
	-- 'true' is much faster, but it doesn't call property setters & clears default properties upon saving
	StoreAsTable = false,
	-- Serialize props as an array => {key, value, key value}
	store_as_obj_prop_list = true
}

DefineModItemCompositeObject("CharacterEffectCompositeDef", {
	EditorName = "Character effect",
	EditorSubmenu = "Unit",
	TestDescription = "Adds the status effect to the selected merc."
})

if config.Mods then 
	function ModItemCharacterEffectCompositeDef:delete()
		CharacterEffectCompositeDef.delete(self)
		ModItemCompositeObject.delete(self)
	end


	function ModItemCharacterEffectCompositeDef:TestModItem(ged)
		ModItemCompositeObject.TestModItem(self, ged)
		if IsKindOf(SelectedObj, "Unit") then
			SelectedObj:AddStatusEffect(self.id)
		else
			ModLog(T(187070922299, "Cannot add the status effect as no unit is selected."))
		end
	end
end

---
--- Deletes the `CharacterEffectCompositeDef` object.
---
--- This function overrides the `delete()` method of the `MsgReactionsPreset` class, which is one of the parent classes of `CharacterEffectCompositeDef`.
---
--- When a `CharacterEffectCompositeDef` object is deleted, this function ensures that the object is properly removed from the underlying data structures.
---
--- @function CharacterEffectCompositeDef:delete
--- @return nil
function CharacterEffectCompositeDef:delete()
	MsgReactionsPreset.delete(self)
end

---
--- Resolves the value of a given property key for the `CharacterEffectCompositeDef` object.
---
--- If the property key is found in the object's properties, the corresponding value is returned.
--- If the object has parameters and the parameter name matches the given key, the parameter's value is returned.
---
--- @param key string The property key to resolve
--- @return any The resolved value, or `nil` if the key is not found
function CharacterEffectCompositeDef:ResolveValue(key)
	local value = self:GetProperty(key)
	if value then return value end

	if self.HasParameters and self.Parameters then
		local found = table.find_value(self.Parameters, "Name", key)
		if found then
			return found.Value
		end
	end
end

---
--- Verifies if the given reaction event and actor are valid for the `CharacterEffectCompositeDef` object.
---
--- This function checks if the given `actor` is an instance of `StatusEffectObject`. If it is, it then checks if the event is either "StatusEffectAdded" or "StatusEffectRemoved", and if the status effect ID matches the ID of the `CharacterEffectCompositeDef` object. If the event is not one of those two, it simply checks if the actor has the status effect associated with the `CharacterEffectCompositeDef` object.
---
--- @param event string The event that triggered the reaction
--- @param reaction_def table The reaction definition
--- @param actor table The actor involved in the reaction
--- @param ... any Additional arguments passed to the reaction
--- @return boolean True if the reaction is valid, false otherwise
function CharacterEffectCompositeDef:VerifyReaction(event, reaction_def, actor, ...)
	if not IsKindOf(actor, "StatusEffectObject") then
		return
	end
	
	local id = GetCharacterEffectId(self)
	if actor and (event == "StatusEffectAdded" or event == "StatusEffectRemoved") then
		local _id = select(2, ...)
		return id == _id
	end
	return actor:HasStatusEffect(id)
end

---
--- Gets the list of actors that have the status effect associated with the `CharacterEffectCompositeDef` object.
---
--- This function iterates through the `gv_UnitData` table, which contains data for all units in the game session. For each unit, it checks if the unit has the status effect associated with the `CharacterEffectCompositeDef` object. If the unit has the status effect, it is added to the `objs` table, which is then sorted by session ID and returned.
---
--- @param event string The event that triggered the reaction
--- @param reaction_def table The reaction definition
--- @param ... any Additional arguments passed to the reaction
--- @return table A table of actors that have the status effect associated with the `CharacterEffectCompositeDef` object
function CharacterEffectCompositeDef:GetReactionActors(event, reaction_def, ...)
	local objs = {}
	local id = GetCharacterEffectId(self)
	for session_id, data in pairs(gv_UnitData) do
		local obj = ZuluReactionResolveUnitActorObj(session_id, data)
		if obj:HasStatusEffect(id) then
			objs[#obj + 1] = obj
		end
	end
	table.sortby_field(objs, "session_id")
	return objs
end

-- Overwrite of the old PlaceCharacterEffect
---
--- Places a character effect object in the game world.
---
--- This function creates a new instance of the character effect class specified by the `item_id` parameter. If the class is not found, it attempts to create a "MissingEffect" class instead.
---
--- The function checks if the `CharacterEffectCompositeDef.store_as_obj_prop_list` flag is set. If it is, the function creates the new instance using the `new()` method and sets the object properties using the `SetObjPropertyList()` function. Otherwise, it creates the new instance using the `new()` method with the `instance` parameter.
---
--- @param item_id string The ID of the character effect class to create
--- @param instance table The instance data to use when creating the new object
--- @param ... any Additional arguments to pass to the `new()` method
--- @return table The newly created character effect object
function PlaceCharacterEffect(item_id, instance, ...)
	local id = item_id
	
	local class = g_Classes[id]
	if not class then
		assert(string.format("Class %s not found", id))
		-- In case the class was deleted and we're loading an older save file
		return PlaceCharacterEffect("MissingEffect", instance, ...)
	end
	
	local obj
	if CharacterEffectCompositeDef.store_as_obj_prop_list then
		obj = class:new({}, ...)
		SetObjPropertyList(obj, instance)
	else
		obj = class:new(instance, ...)
	end
	
	return obj
end
-- end of CompositeDef code

DefineClass.StatusEffectObject = {
	__parents = { "PropertyObject", "InitDone" },
	
	properties = {
		{ id = "StatusEffects", editor = "nested_list", default = false, no_edit = true, },
		{ id = "StatusEffectImmunity", editor = "nested_list", default = false, no_edit = true, },
		{ id = "StatusEffectReceivedTime", editor = "nested_list", default = false, no_edit = true, },
	},
}

---
--- Initializes the status effect properties of the object.
---
--- The `StatusEffects` table stores the active status effects on the object.
--- The `StatusEffectImmunity` table stores the status effects that the object is immune to, and the reasons for the immunity.
--- The `StatusEffectReceivedTime` table stores the time when each status effect was applied to the object.
---
function StatusEffectObject:Init()
	self.StatusEffects = {}
	self.StatusEffectImmunity = {}
	self.StatusEffectReceivedTime = {}
end

---
--- Updates the index of the status effects stored in the `StatusEffects` table.
---
--- This function iterates through the `StatusEffects` table and updates the index of each effect
--- based on its `class` property. This allows for efficient lookup of status effects by their class.
---
--- @param self StatusEffectObject The object whose status effect index is being updated.
---
function StatusEffectObject:UpdateStatusEffectIndex()
	local effects = self.StatusEffects
	for i, effect in ipairs(effects) do
		if effect and effect.class then
			effects[effect.class] = i
		end
	end
end

---
--- Gets the status effect with the given ID from the object's `StatusEffects` table.
---
--- @param self StatusEffectObject The object to get the status effect from.
--- @param id string The ID of the status effect to get.
--- @return table|nil The status effect object, or `nil` if it doesn't exist.
---
function StatusEffectObject:GetStatusEffect(id)
	local idx = self.StatusEffects[id]
	return idx and self.StatusEffects[idx]
end

---
--- Checks if the object has the specified status effect.
---
--- @param self StatusEffectObject The object to check for the status effect.
--- @param id string The ID of the status effect to check for.
--- @return boolean True if the object has the specified status effect, false otherwise.
---
function StatusEffectObject:HasStatusEffect(id)
	return self.StatusEffects[id]
end

---
--- Returns a constant indicating whether debug status effects are enabled.
---
--- @return boolean True if debug status effects are enabled, false otherwise.
---
function StatusEffectObject:ReportStatusEffectsInLog()
	return const.DbgStatusEffects
end

---
--- Adds an immunity to the specified status effect for the given reason.
---
--- If the object already has an immunity to the specified status effect, the reason is added to the existing immunity.
--- If the object has the specified status effect, it is removed.
---
--- @param self StatusEffectObject The object to add the status effect immunity to.
--- @param effect string The ID of the status effect to add immunity to.
--- @param reason string The reason for the immunity.
---
function StatusEffectObject:AddStatusEffectImmunity(effect, reason)
	self.StatusEffectImmunity[effect] = self.StatusEffectImmunity[effect] or {}
	self.StatusEffectImmunity[effect][reason] = true
	self:RemoveStatusEffect(effect)
end

---
--- Removes an immunity to the specified status effect for the given reason.
---
--- If the object no longer has any immunities to the specified status effect, the immunity is removed entirely.
---
--- @param self StatusEffectObject The object to remove the status effect immunity from.
--- @param effect string The ID of the status effect to remove immunity from.
--- @param reason string The reason for the immunity to remove.
---
function StatusEffectObject:RemoveStatusEffectImmunity(effect, reason)
	if self.StatusEffectImmunity[effect] then
		self.StatusEffectImmunity[effect][reason] = nil
		if next(self.StatusEffectImmunity[effect]) == nil then
			self.StatusEffectImmunity[effect] = nil
		end
	end
end

---
--- Adds a status effect to the object.
---
--- If the object already has the specified status effect, the stacks are increased up to the maximum allowed.
--- If the object is immune to the status effect or is dead, the status effect is not added.
---
--- @param id string The ID of the status effect to add.
--- @param stacks number The number of stacks to add. Defaults to 1.
--- @return CharacterEffect The added status effect, or nil if the status effect was not added.
---
function StatusEffectObject:AddStatusEffect(id, stacks)
	NetUpdateHash("StatusEffectObject:AddStatusEffect", self, id, IsValid(self) and self:HasMember("GetPos") and self:GetPos())
	if self.StatusEffectImmunity[id] or (IsKindOfClasses(self, "Unit", "UnitData") and self:IsDead()) then 
		return 
	end
	stacks = stacks or 1
	local preset = CharacterEffectDefs[id]
	local effect = self:GetStatusEffect(id)
	local cur_stacks = effect and effect.stacks or 0
	if cur_stacks >= preset:GetProperty("max_stacks") then
		return
	end
	
	local context = {}
	context.target_units = {self}
	local ok = EvalConditionList(preset:GetProperty("Conditions"), self, context)
	if not ok then
		return
	end	
	
	local refresh
	local newStack = false
	
	if not effect then
		effect = PlaceCharacterEffect(id)
		effect.stacks = Min(stacks, effect.max_stacks)
		table.insert(self.StatusEffects, effect)
		self.StatusEffects[id] = #self.StatusEffects
		newStack = true
		
		table.sort(self.StatusEffects, function(a,b) 
			return CharacterEffectDefs[a.class].SortKey < CharacterEffectDefs[b.class].SortKey
		end)
		self:UpdateStatusEffectIndex()
		
		for _, mod in ipairs(preset:GetProperty("Modifiers")) do
			self:AddModifier("StatusEffect:"..id, mod.target_prop, mod.mod_mul*10, mod.mod_add)
		end
		self.StatusEffectReceivedTime[id] = GameTime()
		self:AddReactions(effect, effect.unit_reactions)
		effect:OnAdded(self)
	else
		newStack = effect.stacks
		effect.stacks = Min(effect.stacks + stacks, effect.max_stacks)
		newStack = effect.stacks > newStack
		refresh = true
	end
	effect.CampaignTimeAdded = Game.CampaignTime
	if Platform.developer and self:ReportStatusEffectsInLog() and newStack then
		if not self:IsDead() then
			CombatLog("debug", T{Untranslated("<em><effect></em> (<name>)"), name = self:GetLogName(), effect = effect.DisplayName or Untranslated(id)})
		end
	end
	if effect.AddEffectText and effect.AddEffectText ~= "" and not refresh then
		if not self:IsDead() then
			CombatLog("short", T{effect.AddEffectText, self})
		end		
	end	
	if IsValid(self) and effect.HasFloatingText and newStack then
		CreateMapRealTimeThread(function()
			WaitPlayerControl()
			CreateFloatingText(self, T{961020758708, "+ <DisplayName>", effect}, nil, nil, true)
		end)
	end
	
	if effect.lifetime ~= "Indefinite" and IsKindOf(self, "Unit") and g_Combat then
		local duration = effect.lifetime == "Until End of Next Turn" and 1 or 0
		if g_CurrentTeam and g_Teams[g_CurrentTeam] and not g_Teams[g_CurrentTeam].player_team then
			duration = duration + 1
		end
		self:SetEffectExpirationTurn(id, "expiration", g_Combat.current_turn + duration)
	end

	ObjModified(self.StatusEffects)
	Msg("StatusEffectAdded", self, id, stacks)
	self:CallReactions("OnStatusEffectAdded", id, stacks)
	return effect
end

---
--- Removes a status effect from the StatusEffectObject.
---
--- @param id string The ID of the status effect to remove.
--- @param stacks number|"all" The number of stacks to remove, or "all" to remove all stacks.
--- @param reason string The reason for removing the status effect (e.g. "death").
---
--- @return boolean true if the status effect was removed, false otherwise.
---
function StatusEffectObject:RemoveStatusEffect(id, stacks, reason)
	local has = self:HasStatusEffect(id)
	if not has then return end
	NetUpdateHash("StatusEffectObject:RemoveStatusEffect", self, id, self:HasMember("GetPos") and self:GetPos())
	
	local effect = self.StatusEffects[has]
	local preset = CharacterEffectDefs[id]
	if not effect.stacks then -- shield from faulty effects
		table.remove(self.StatusEffects, has)
		self.StatusEffects[id] = nil
		self.StatusEffectReceivedTime[id] = nil
		self:UpdateStatusEffectIndex()
		for _, mod in ipairs(preset:GetProperty("Modifiers")) do
			self:RemoveModifier("StatusEffect:"..id, mod.target_prop)
		end
		self:RemoveReactions(effect)
		effect:OnRemoved(self)
		return
	end
	
	if reason == "death" and effect.dontRemoveOnDeath then
		return
	end
	
	local lost
	local to_remove = (stacks == "all" and effect.stacks) or stacks or 1
	local removedStacks = Min(effect.stacks, to_remove)
	effect.stacks = Max(0, effect.stacks - to_remove)
	if effect.stacks == 0 then
		table.remove(self.StatusEffects, has)
		self.StatusEffects[id] = nil
		self.StatusEffectReceivedTime[id] = nil
		self:UpdateStatusEffectIndex()
		for _, mod in ipairs(preset:GetProperty("Modifiers")) do
			self:RemoveModifier("StatusEffect:"..id, mod.target_prop)
		end
		self:RemoveReactions(effect)
		effect:OnRemoved(self)
		lost = true
		if Platform.developer and self:ReportStatusEffectsInLog() then
			if not self:IsDead() then
				CombatLog("debug", T{Untranslated("<name> lost effect <effect>"), name = self:GetLogName(), effect = effect.DisplayName or Untranslated(id)})
			end
		end
		if effect.RemoveEffectText then
			if not self:IsDead() then
				CombatLog("short", T{effect.RemoveEffectText, self})
			end
		end
	end

	ObjModified(self.StatusEffects)
	Msg("StatusEffectRemoved", self, id, removedStacks, reason)
	self:CallReactions("OnStatusEffectRemoved", id, effect.stacks)
end

--- Checks if the StatusEffectObject has any visible effects.
---
--- @return boolean true if the object has any visible effects, false otherwise
function StatusEffectObject:HasVisibleEffects()
	for _, effect in ipairs(self.StatusEffects) do
		if effect.Shown then
			return true
		end
	end
	return false
end

---
--- Returns a table of all visible status effects on the StatusEffectObject.
---
--- @param addBadgeHidden boolean (optional) If true, include status effects that are hidden on the badge.
--- @return table The table of visible status effects.
function StatusEffectObject:GetUIVisibleStatusEffects(addBadgeHidden)
	local vis = {}
	
	for _, effect in ipairs(self.StatusEffects) do
		if effect and effect.Shown and effect.Icon and (addBadgeHidden or not effect.HideOnBadge) then
			vis[#vis + 1] = effect
		end
	end
	
	return vis
end

--- Removes all status effects from the StatusEffectObject.
---
--- This function iterates through the StatusEffects table and removes each status effect one by one.
---
--- @param reason string (optional) The reason for removing the status effects.
function StatusEffectObject:RemoveAllCharacterEffects(reason)
end
function StatusEffectObject:RemoveAllCharacterEffects()
	while #self.StatusEffects > 0 do
		self:RemoveStatusEffect(self.StatusEffects[1].class, "all")
	end
end

--- Removes all status effects from the StatusEffectObject.
---
--- This function iterates through the StatusEffects table and removes each status effect one by one.
---
--- @param reason string (optional) The reason for removing the status effects.
function StatusEffectObject:RemoveAllStatusEffects(reason)
	for i = #self.StatusEffects, 1, -1 do
		local effect = self.StatusEffects[i]
		if IsKindOf(effect, "StatusEffect") then
			self:RemoveStatusEffect(effect.class, "all", reason)
		end
	end
end

PerkSortTable = {
	Personal = 1,
	Personality = 2,
	Specialization = 3,
	Quirk = 4,
	Gold = 5,
	Silver = 6,
	Bronze = 7,
}

--- Returns a table of perks that match the specified tier level and sorting criteria.
---
--- @param tier_level number (optional) The tier level of the perks to return. If not specified, all perks are returned.
--- @param sort boolean (optional) Whether to sort the returned perks by their tier level.
--- @return table The table of perks that match the specified criteria.
function StatusEffectObject:GetPerks(tier_level, sort)
	if not self.StatusEffects then return empty_table end
	local result = table.ifilter(self.StatusEffects, function(i, s)	
		return IsKindOf(s, "Perk") 
				and (not tier_level or s.Tier==tier_level)
	end)
	
	if sort then
		table.sort(result, function(a, b)
			local z = PerkSortTable[a.Tier] or 0
			local x = PerkSortTable[b.Tier] or 0
			if z==x then 
				return a.class<b.class 
			end
			return z < x
		end)
	end
	
	return result
end

--- Returns a table of perks that match the specified stat.
---
--- @param stat string The stat to filter the perks by.
--- @return table The table of perks that match the specified stat.
function StatusEffectObject:GetPerksByStat(stat)
	if not self.StatusEffects or not stat then return empty_table end
	return table.ifilter(self.StatusEffects, function(i, s)	
		return IsKindOf(s, "Perk") and (s.Stat == stat)
	end)
end

--- Returns whether the StatusEffectObject has any StatusEffect objects attached to it.
---
--- @return boolean True if the StatusEffectObject has any StatusEffect objects, false otherwise.
function StatusEffectObject:HasAnyStatusEffects()
	for _, effect in ipairs(self.StatusEffects) do
		if IsKindOf(effect, "StatusEffect") then
			return true
		end
	end
	return false
end

--- Returns a table of merc names and their corresponding editor open functions, where the mercs have the specified perk in their starting perks.
---
--- @param o table The perk object.
--- @return table A table of merc names and their corresponding editor open functions.
function PersonalPerkStartingOfButtons(o)
	local mercs = {}
	ForEachPreset("UnitDataCompositeDef", function(data)
		if data.StartingPerks and table.find(data.StartingPerks, o.id) then
			mercs[#mercs + 1] = {
				name = data.id,
				func = function()
					 data:OpenEditor()
				end
			}
		end
	end)
	return mercs
end

--- Cleans up the StatusEffects table by removing any entries that do not have a corresponding CharacterEffectDefs entry.
---
--- This function iterates through the StatusEffects table and removes any entries where the key is a string and there is no corresponding CharacterEffectDefs entry. It first builds a table of the values to remove, then removes them from the StatusEffects table.
---
--- @param self StatusEffectObject The StatusEffectObject instance to clean up.
function StatusEffectObject:StatusEffectsCleanUp()
	local effects = self.StatusEffects
	local toRemove = {}
	for key, value in pairs(effects) do
		if type(key) == "string" and not CharacterEffectDefs[key] then
			toRemove[#toRemove+1] = value
			effects[key] = nil
		end
	end
	for _, idx in ipairs(toRemove) do
		table.remove(effects, idx)
	end
end

DefineClass.UnitModifier = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "target_prop", name = "Property Name", editor = "combo", items = function() return ClassModifiablePropsNonTranslatableCombo(g_Classes.Unit) end, default = "" },
		{ id = "mod_add", name = "Add", editor = "number", default = 0,},
		{ id = "mod_mul", name = "Mul", editor = "number", scale = 100, default = 100 },
	},
	StoreAsTable = true,
	EditorView = Untranslated("Unit Modifier: (<u(target_prop)> + <mod_add>) * <FormatAsFloat(mod_mul, 100, 2)>"),
}

-- Remove marked StatusEffects on SatView Travel
function OnMsg.SquadStartedTravelling(squad)
	for _, id in ipairs(squad.units) do
		local unit = g_Units[id]
		if IsValid(unit) then
			for i = #unit.StatusEffects, 1, -1 do
				local effect = unit.StatusEffects[i]
				if effect.RemoveOnSatViewTravel then
					unit:RemoveStatusEffect(effect.class)
				end
			end
		end
		
		local unitData = gv_UnitData[id]
		for i = #unitData.StatusEffects, 1, -1 do
			local effect = unitData.StatusEffects[i]
			if effect.RemoveOnSatViewTravel then
				unitData:RemoveStatusEffect(effect.class)
			end
		end
	end
end

-- Remove marked StatusEffects on Campaign Time resume
function OnMsg.CampaignTimeAdvanced(time, ot)
	for _, unit in ipairs(g_Units) do
		if IsValid(unit) then
			for i = #unit.StatusEffects, 1, -1 do
				local effect = unit.StatusEffects[i]
				if effect.RemoveOnCampaignTimeAdvance or effect.RemoveOnEndCombat then
					unit:RemoveStatusEffect(effect.class)
					
					local unitData = gv_UnitData[unit.session_id]
					unitData:RemoveStatusEffect(effect.class)
				end
			end
		end
	end
end

function OnMsg.ExplorationTick()
	for _, unit in ipairs(g_Units) do
		for _, effect in ripairs(unit.StatusEffects) do
			if effect.RemoveOnEndCombat and (GameTime() > (unit.StatusEffectReceivedTime[effect.class] or 0) + 5000) then
				unit:RemoveStatusEffect(effect.class)
			end
		end
	end
end