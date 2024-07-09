local function ActionFXTypesCombo()
	local list_back = { "Inherit Action", "Inherit Moment", "Inherit Actor", "FX Remove" }
	local added = { [""] = true, ["any"] = true }
	for i = 1, #list_back do
		added[list_back[i]] = true
	end
	local list = {}
	ClassDescendantsList("ActionFX", function(name, class)
		if not added[class.fx_type] then
			list[#list+1] = class.fx_type
			added[class.fx_type] = true
		end
	end)
	table.sort(list, CmpLower)
	table.insert(list, 1, "any")
	for i = 1, #list_back do
		list[#list+1] = list_back[i]
	end
	return list
end

local fx_class_list = false
function OnMsg.ClassesBuilt()
	fx_class_list = {}
	ClassDescendantsList("ActionFX", function(name, class)
		if class.fx_type ~= "" and not class:IsKindOf("ModItem") then
			fx_class_list[#fx_class_list+1] = class
		end
	end)
	ClassDescendantsList("ActionFXInherit", function(name, class)
		if class.fx_type ~= "" then
			fx_class_list[#fx_class_list+1] = class
		end
	end)
	table.sort(fx_class_list, function(c1, c2) return c1.fx_type < c2.fx_type end)
end

local function GetInheritActionFX(action)
	local fxlist = FXLists.ActionFXInherit_Action or {}
	if action == "any" then
		return table.copy(fxlist)
	end
	local rules = (FXInheritRules_Actions or RebuildFXInheritActionRules())[action]
	if not rules then return end
	local inherit = { [action] = true}
	for i = 1, #rules do
		inherit[rules[i]] = true
	end
	local list = {}
	for i = 1, #fxlist do
		local fx = fxlist[i]
		if inherit[fx.Action] then
			list[#list+1] = fx
		end
	end
	return list
end

local function GetInheritMomentFX(moment)
	local fxlist = FXLists.ActionFXInherit_Moment or {}
	if moment == "any" then
		return table.copy(fxlist)
	end
	local rules = (FXInheritRules_Moments or RebuildFXInheritMomentRules())[moment]
	if not rules then return end
	local inherit = { [moment] = true}
	for i = 1, #rules do
		inherit[rules[i]] = true
	end
	local list = {}
	for i = 1, #fxlist do
		local fx = fxlist[i]
		if inherit[fx.Moment] then
			list[#list+1] = fx
		end
	end
	return list
end

local function GetInheritActorFX(actor)
	local fxlist = FXLists.ActionFXInherit_Actor or {}
	if actor == "any" then
		return table.copy(fxlist)
	end
	local rules = (FXInheritRules_Actors or RebuildFXInheritActorRules())[actor]
	if not rules then return end
	local inherit = { [actor] = true}
	for i = 1, #rules do
		inherit[rules[i]] = true
	end
	local list = {}
	for i = 1, #fxlist do
		local fx = fxlist[i]
		if inherit[fx.Actor] then
			list[#list+1] = fx
		end
	end
	return list
end

if FirstLoad then
	DuplicatedFX = {}
end

local function MatchActionFX(actionFXClass, actionFXMoment, actorFXClass, targetFXClass, source, game_states, fx_type, match_type, detail_level, save_in, duplicates)
	local list = {}
	local remove_ids
	local inherit_actions = actionFXClass  and (FXInheritRules_Actions or RebuildFXInheritActionRules())[actionFXClass]
	local inherit_moments = actionFXMoment and (FXInheritRules_Moments or RebuildFXInheritMomentRules())[actionFXMoment]
	local inherit_actors  = actorFXClass   and (FXInheritRules_Actors  or RebuildFXInheritActorRules() )[actorFXClass]
	local inherit_targets = targetFXClass  and (FXInheritRules_Actors  or RebuildFXInheritActorRules() )[targetFXClass]
	detail_level = detail_level or 0
	
	local i, action
	if actionFXClass == "any" then
		action = next(FXRules)
	else
		i, action = 0, actionFXClass
	end
	local duplicated = DuplicatedFX
	while action do
		local rules1 = FXRules[action]
		if rules1 then
			local i, moment
			if actionFXMoment == "any" then
				moment = next(rules1)
			else
				i, moment = 0, actionFXMoment
			end
			while moment do
				local rules2 = rules1[moment]
				if rules2 then
					local i, actor
					if actorFXClass == "any" then
						actor = next(rules2)
					else
						i, actor = 0, actorFXClass
					end
					while actor do
						local rules3 = actor and rules2[actor]
						if rules3 then
							local i, target
							if targetFXClass == "any" then
								target = next(rules3)
							else
								i, target = 0, targetFXClass
							end
							while target do
								local rules4 = target and rules3[target]
								if rules4 then
									for i = 1, #rules4 do
										local fx = rules4[i]
										local match = not IsKindOf(fx, "ActionFX") or fx:GameStatesMatched(game_states)
										match = match and (not fx_type or fx_type == "any" or fx_type == fx.fx_type)
										match = match and (detail_level == 0 or detail_level == fx.DetailLevel)
										match = match and (not save_in or save_in == fx.save_in)
										match = match and (not duplicates or duplicated[fx])
										match = match and (source == "any" or fx.Source == source)
										if match then
											list[fx] = true
										end
									end
								end
								if targetFXClass == "any" then
									target = next(rules3, target)
								else
									if target == "any" or match_type == "Exact" then break end
									i = i + 1
									target = inherit_targets and inherit_targets[i] or match_type ~= "NoAny" and "any"
								end
							end
						end
						if actorFXClass == "any" then
							actor = next(rules2, actor)
						else
							if actor == "any" or match_type == "Exact" then break end
							i = i + 1
							actor = inherit_actors and inherit_actors[i] or match_type ~= "NoAny" and "any"
						end
					end
				end
				if actionFXMoment == "any" then
					moment = next(rules1, moment)
				else
					if moment == "any" or match_type == "Exact" then break end
					i = i + 1
					moment = inherit_moments and inherit_moments[i] or match_type ~= "NoAny" and "any"
				end
			end
		end
		if actionFXClass == "any" then
			action = next(FXRules, action)
		else
			if action == "any" or match_type == "Exact" then break end
			i = i + 1
			action = inherit_actions and inherit_actions[i] or match_type ~= "NoAny" and "any"
		end
	end
	return list
end

local function GetFXListForEditor(filter)
	filter = filter or ActionFXFilter -- to get defaults
	filter:ResetDebugFX()
	if filter.Type == "Inherit Action" then
		return GetInheritActionFX(filter.Action) or {}
	elseif filter.Type == "Inherit Moment" then
		return GetInheritMomentFX(filter.Moment) or {}
	elseif filter.Type == "Inherit Actor" then
		return GetInheritActorFX(filter.Actor) or {}
	else
		return MatchActionFX(
			filter.Action, filter.Moment, filter.Actor, filter.Target, filter.Source,
			filter.GameStatesFilters, filter.Type, filter.MatchType,
			filter.DetailLevel, filter.SaveIn, filter.Duplicates)
	end
end

if FirstLoad or ReloadForDlc then
	FXLists = {}
end

DefineClass.FXPreset = {
	__parents = { "Preset", "InitDone"},
	properties = {
		{ id = "Id", editor = false, no_edit = true, },
	},

	-- Preset
	PresetClass = "FXPreset",
	id = "",
	EditorView = Untranslated("<DescribeForEditor>"),
	GedEditor = "GedFXEditor",
	EditorMenubarName = "FX Editor",
	EditorShortcut = "Ctrl-Alt-F",
	EditorMenubar = "Editors.Art",
	EditorIcon = "CommonAssets/UI/Icons/atom electron molecule nuclear science.png",
	FilterClass = "ActionFXFilter",
}

--- Initializes a new FXPreset instance and adds it to the FXLists table for its class.
---
--- This function is called when a new FXPreset instance is created. It adds the new instance to the FXLists table for its class, creating a new table if one doesn't already exist.
---
--- @param self FXPreset The FXPreset instance being initialized.
function FXPreset:Init()
	local list = FXLists[self.class]
	if not list then
		list = {}
		FXLists[self.class] = list
	end
	list[#list+1] = self
end

---
--- Removes the current FXPreset instance from the FXLists table for its class.
---
--- This function is called when an FXPreset instance is no longer needed. It removes the instance from the FXLists table for its class, ensuring that the table only contains active instances.
---
--- @param self FXPreset The FXPreset instance being removed.
function FXPreset:Done()
	table.remove_value(FXLists and FXLists[self.class], self)
end

---
--- Checks if the FXPreset instance has an error condition.
---
--- This function checks if the FXPreset instance has a "UI" source and a "GameTime" value set. If both of these conditions are true, it returns an error message indicating that UI FXs should not be GameTime.
---
--- @return string|nil The error message if an error condition is detected, or nil if no error is found.
function FXPreset:GetError()
	if self.Source == "UI" and self.GameTime then 
		return "UI FXs should not be GameTime"
	end
end

---
--- Gets the status text for the currently selected FXPreset in the editor.
---
--- This function is used to generate the status text that is displayed in the editor for the currently selected FXPreset. It checks if there is a multi-selection of FXPresets, and if so, it counts the number of each type of FXPreset that is selected and returns a comma-separated string of the counts.
---
--- @return string The status text for the currently selected FXPreset(s)
function FXPreset:GetPresetStatusText()
	local ged = FindPresetEditor("FXPreset")
	if not ged then return end
	
	local sel = ged:ResolveObj("SelectedPreset")
	if IsKindOf(sel, "GedMultiSelectAdapter") then
		local count_by_type = {}
		for _, fx in ipairs(sel.__objects) do
			local fx_type = fx.fx_type
			count_by_type[fx_type] = (count_by_type[fx_type] or 0) + 1
		end
		local t = {}
		for _, fx_type in ipairs(ActionFXTypesCombo()) do
			local count = count_by_type[fx_type]
			if count then
				t[#t + 1] = string.format("%d %s%s", count, fx_type, (count == 1 or fx_type:ends_with("s")) and "" or "s")
			end
		end
		return table.concat(t, ", ") .. " selected"
	end
	return ""
end

---
--- Sorts the presets in the Presets table for the current PresetClass or class.
---
--- This function first sorts the presets in the Presets table by their group. It then performs a stable sort on each group, sorting the presets by their description as returned by the DescribeForEditor function.
---
--- After sorting the presets, the function calls ObjModified to notify the editor that the presets have been modified.
---
--- @param self FXPreset The FXPreset instance.
function FXPreset:SortPresets()
	local presets = Presets[self.PresetClass or self.class] or empty_table
	table.sort(presets, function(a, b) return a[1].group < b[1].group end)

	local keys = {}
	for _, group in ipairs(presets) do
		for _, preset in ipairs(group) do
			keys[preset] = preset:DescribeForEditor()
		end
	end

	for _, group in ipairs(presets) do
		table.stable_sort(group, function(a, b) 
			return keys[a] < keys[b]
		end)
	end

	ObjModified(presets)
end

---
--- Returns the save path for the FXPreset instance.
---
--- The save path is constructed by combining the save folder, the PresetClass, and the class of the FXPreset instance.
---
--- @param self FXPreset The FXPreset instance.
--- @return string The save path for the FXPreset instance.
function FXPreset:GetSavePath()
	local folder = self:GetSaveFolder()
	if not folder then return end

	return string.format("%s/%s/%s.lua", folder, self.PresetClass, self.class)
end

---
--- Saves all FXPreset instances, ensuring each has a unique preset ID.
---
--- This function iterates over all FXPreset instances and generates a unique ID for each one if the current ID is already in use. It then calls the SaveAll function from the Preset class to save all the FXPreset instances.
---
--- @param self FXPreset The FXPreset instance.
--- @return boolean True if the save was successful, false otherwise.
function FXPreset:SaveAll(...)
	local used_handles = {}
	ForEachPresetExtended(FXPreset, function(fx)
		while used_handles[fx.id] do
			fx.id = fx:GenerateUniquePresetId()
		end
		used_handles[fx.id] = true
	end)
	return Preset.SaveAll(self, ...)
end

---
--- Generates a unique preset ID for an FXPreset instance.
---
--- This function generates a unique 48-bit preset ID for an FXPreset instance using a random encoding function.
---
--- @return string The unique preset ID.
function FXPreset:GenerateUniquePresetId()
	return random_encode64(48)
end

---
--- Called when a new FXPreset instance is created in the editor.
---
--- This function is responsible for adding the new FXPreset instance to the appropriate rules, depending on its class. If the FXPreset is an ActionFX, it is added to the FX rules. If it is an ActionFXInherit_Action, ActionFXInherit_Moment, or ActionFXInherit_Actor, the corresponding inherit rules are rebuilt.
---
--- @param self FXPreset The FXPreset instance.
function FXPreset:OnEditorNew()
	if self:IsKindOf("ActionFX") then
		self:AddInRules()
	elseif self.class == "ActionFXInherit_Action" then
		RebuildFXInheritActionRules()
	elseif self.class == "ActionFXInherit_Moment" then
		RebuildFXInheritMomentRules()
	elseif self.class == "ActionFXInherit_Actor" then
		RebuildFXInheritActorRules()
	end
end

---
--- Called when the FXPreset data has been reloaded.
---
--- This function rebuilds the FX rules after the FXPreset data has been reloaded.
---
function FXPreset:OnDataReloaded()
	RebuildFXRules()
end

local function format_match(action, moment, actor, target)
	return string.format("%s-%s-%s-%s", action, moment, actor, target)
end

---
--- Describes an FXPreset instance for the editor.
---
--- This function generates a string description of an FXPreset instance that can be displayed in the editor. The description includes information about the type of FX, its properties, and any matching information.
---
--- @param self FXPreset The FXPreset instance to describe.
--- @return string The description of the FXPreset instance.
function FXPreset:DescribeForEditor()
	local str_desc = ""
	local str_info = ""
	local class = IsKindOf(self, "ModItem") and self.ModdedPresetClass or self.class
	
	if class == "ActionFXParticles" then
		str_desc = string.format("%s", self.Particles)
	elseif class == "ActionFXUIParticles" then
		str_desc = string.format("%s", self.Particles)
	elseif class == "ActionFXObject" or class == "ActionFXDecal" then
		str_desc = string.format("%s", self.Object)
		str_info = string.format("%s", self.Animation)
	elseif class == "ActionFXSound" then
		str_desc = string.format("%s", self.Sound) .. (self.DistantSound ~= "" and " "..self.DistantSound or "")
	elseif class == "ActionFXLight" then
		local r, g, b, a = GetRGBA(self.Color)
		str_desc = string.format("<color %d %d %d>%d %d %d %s</color>", r, g, b, r, g, b, a ~= 255 and tostring(a) or "")
		str_info = string.format("%d", self.Intensity)
	elseif class == "ActionFXRadialBlur" then
		str_desc = string.format("Strength %s", self.Strength)
		str_info = string.format("Duration %s", self.Duration)
	elseif class == "ActionFXControllerRumble" then
		str_desc = string.format("%s", self.Power)
		str_info = string.format("Duration %s", self.Duration)
	elseif class == "ActionFXCameraShake" then
		str_desc = string.format("%s", self.Preset)
	elseif class == "ActionFXInherit_Action" then
		local str_match = string.format("Inherit Action: %s -> %s", self.Action, self.Inherit)
		return string.format("<color blue>%s</color>", str_match)
	elseif class == "ActionFXInherit_Moment" then
		local str_match = string.format("Inherit Moment: %s -> %s", self.Moment, self.Inherit)
		return string.format("<color blue>%s</color>", str_match)
	elseif class == "ActionFXInherit_Actor" then
		local str_match = string.format("Inherit Actor: %s -> %s", self.Actor, self.Inherit)
		return string.format("<color blue>%s</color>", str_match)
	end
	if self.Source ~= "" and self.Spot ~= "" then
		local space = str_info ~= "" and " " or ""
		str_info = str_info .. space .. string.format("%s.%s", self.Source, self.Spot)
	end
	
	if self.Solo then
		str_info = string.format("%s (Solo)", str_info)
	end
	
	local str_match = format_match(self.Action, self.Moment, self.Actor, self.Target)
	local clr_match = self.Disabled and "255 0 0" or "75 105 198"
	local str_preset = self.Comment ~= "" and (" <color 0 128 0>" .. self.Comment .. "</color>") or ""
	if self.save_in ~= "" and self.save_in ~= "none" then
		str_preset = str_preset .. " <color 128 128 128> - " .. self.save_in .. "</color>"
	end
	
	local fx_type = IsKindOf(self, "ModItem") and "" or string.format("<color 128 128 128>%s</color> ", self.fx_type)
	str_desc = str_desc ~= "" and str_desc.." " or ""
	if fx_type == "" and str_desc == "" and str_info == "" and (self.FxId or "") == "" then
		return string.format("<color %s>%s</color>%s", clr_match, str_match, str_preset)
	end
	return string.format("<color %s>%s</color>%s\n%s%s<color 128 128 128>%s</color> <color 0 128 0>%s</color>", clr_match, str_match, str_preset, fx_type, str_desc, str_info, self.FxId or "")
end
 
--- Deletes the FXPreset object and any associated InitDone object.
---
--- This function is part of the FXPreset class and is responsible for cleaning up the object when it is deleted.
---
--- @function FXPreset:delete
--- @return nil
function FXPreset:delete()
	Preset.delete(self)
	InitDone.delete(self)
end

--- Overrides the default EditorContext method to remove certain classes from the context.
---
--- This method is part of the FXPreset class and is responsible for customizing the editor context
--- for this class. It removes the PresetClass, "ActionFX", and "ActionFXInherit" classes from the
--- context, which are likely not relevant for this specific class.
---
--- @return table The customized editor context
function FXPreset:EditorContext()
	local context = Preset.EditorContext(self)
	table.remove_value(context.Classes, self.PresetClass)
	table.remove_value(context.Classes, "ActionFX")
	table.remove_value(context.Classes, "ActionFXInherit")
	return context
end

-- for ValidatePresetDataIntegrity
--- Returns a string representation of the FXPreset object that can be used for editor identification.
---
--- This method is part of the FXPreset class and is responsible for providing a textual description of the
--- FXPreset object that can be used to identify it in the editor. The description is generated by
--- concatenating various properties of the FXPreset object, such as the source, spot, action, moment,
--- actor, target, and any additional comments or save location information.
---
--- @return string A string representation of the FXPreset object for editor identification
function FXPreset:GetIdentification()
	return self:DescribeForEditor():strip_tags()
end

DefineClass.ActionFXFilter = {
	__parents = { "GedFilter" },

	properties = {
		{ id = "DebugFX", category = "Match", default = false, editor = "bool", },
		{ id = "Duplicates", category = "Match", default = false, editor = "bool", help = "Works only after using the tool 'Check duplicates'!" },
		{ id = "Action", category = "Match", default = "any", editor = "combo", items = function(fx) return ActionFXClassCombo(fx) end },
		{ id = "Moment", category = "Match", default = "any", editor = "combo", items = function(fx) return ActionMomentFXCombo(fx) end },
		{ id = "Actor", category = "Match", default = "any", editor = "combo", items = function(fx) return ActorFXClassCombo(fx) end },
		{ id = "Target", category = "Match", default = "any", editor = "combo", items = function(fx) return TargetFXClassCombo(fx) end },
		{ id = "Source", category = "Match", default = "any", editor = "choice", items = { "UI", "Actor", "ActorParent", "ActorOwner", "Target", "ActionPos", "Camera" } },
		{ id = "SaveIn", name = "Save in", category = "Match", editor = "choice", default = false, items = function(fx)
			local locs = GetDefaultSaveLocations()
			table.insert(locs, 1, { text = "All", value = false })
			return locs
		end, },
		
		{ id = "GameStatesFilter", name="Game State", category = "Match", editor = "set", default = set(), three_state = true, 
			items = function() return GetGameStateFilter() end
		},
		{ id = "DetailLevel", category = "Match", default = 0, editor = "combo", items = function()
			local levels = table.copy(ActionFXDetailLevelCombo())
			table.insert(levels, 1, {value = 0, text = "any"})
			return levels
		end },
		{ id = "Type", category = "Match", editor = "choice", items = ActionFXTypesCombo, default = "any", buttons = {{name = "Create New", func = "CreateNew"}}},
		{ id = "MatchType", category = "Match", default = "Exact", editor = "choice", items = { "All", "Exact", "NoAny" }, },
		{ id = "ResetButton", category = "Match", editor = "buttons",  buttons = {{name = "Reset filter", func = "ResetAction"} }, default = false },
		
		{ id = "FxCounter", category = "Match", editor = "number", default = 0, read_only = true, },
	},

	fx_counter = false,
	last_lists = false,
}

---
--- Attempts to reset the ActionFXFilter object based on the provided GedFilter operation and view.
---
--- This method is part of the ActionFXFilter class and is responsible for handling the reset logic when certain GedFilter operations occur. It checks if the operation is a preset deletion, and if the new view contains a hidden object that is not matched by the current filter. If these conditions are met, the method will call the base GedFilter.TryReset() method to reset the filter.
---
--- @param ged table The GedFilter object associated with the filter.
--- @param op string The GedFilter operation that triggered the reset.
--- @param to_view table The new view being set for the GedFilter.
--- @return boolean True if the filter was successfully reset, false otherwise.
function ActionFXFilter:TryReset(ged, op, to_view)
	if op == GedOpPresetDelete then
		return
	end
	if to_view and #to_view == 2 and type(to_view[1]) == "table" then
		-- check if the new item is hidden and only then reset the filter
		local obj = ged:ResolveObj("root", table.unpack(to_view[1]))
		local matched_fxs = GetFXListForEditor(self)
		if not matched_fxs[obj] then
			return GedFilter.TryReset(self, ged, op, to_view)
		end
	else
		return GedFilter.TryReset(self, ged, op, to_view)
	end
end

---
--- Attempts to reset the ActionFXFilter object and the target filter.
---
--- This method is part of the ActionFXFilter class and is responsible for handling the reset logic when the "Reset filter" button is clicked. It first calls the `TryReset()` method to reset the filter, and if successful, it also calls the `ResetTarget()` method to reset the target filter.
---
--- @param root table The root object of the GedFilter.
--- @param prop_id string The property ID of the GedFilter.
--- @param ged table The GedFilter object associated with the filter.
--- @return nil
function ActionFXFilter:ResetAction(root, prop_id, ged)
	if self:TryReset(ged) then
		self:ResetTarget(ged)
	end
end

---
--- Creates a new preset for the ActionFXFilter object.
---
--- This method is part of the ActionFXFilter class and is responsible for creating a new preset for the filter. It first checks if the `Type` property is set to "any", and if so, it prints a message and returns. Otherwise, it finds the index of the `fx_type` in the `fx_class_list` table, and if found, it creates a new preset using the `GedOpNewPreset` operation with the corresponding class.
---
--- @param root table The root object of the GedFilter.
--- @param prop_id string The property ID of the GedFilter.
--- @param ged table The GedFilter object associated with the filter.
--- @return nil
function ActionFXFilter:CreateNew(root, prop_id, ged)
	if self.Type == "any" then
		print("Please specify the fx TYPE first")
		return
	end
	
	local idx = table.find(fx_class_list, "fx_type", self.Type)
	if idx then
		local old_value = self.Type
		ged:Op(nil, "GedOpNewPreset", "root", { false, fx_class_list[idx].class })
		self.Type = old_value
		ObjModified(self)
	end
end 

---
--- Gets the total number of FX presets.
---
--- This method is part of the `ActionFXFilter` class and is responsible for calculating and returning the total number of FX presets. It first checks if the `fx_counter` property has already been calculated, and if not, it iterates through the `Presets.FXPreset` table and counts the total number of presets. The result is stored in the `fx_counter` property and returned.
---
--- @return integer The total number of FX presets.
function ActionFXFilter:GetFxCounter()
	if not self.fx_counter then
		local counter = 0
		for _, group in ipairs(Presets.FXPreset) do
			counter = counter + #group
		end
		self.fx_counter = counter
	end
	return self.fx_counter
end

---
--- Filters an object based on the ActionFXFilter's properties.
---
--- This method is part of the `ActionFXFilter` class and is responsible for filtering an object based on the filter's properties. It first checks if the object is an instance of `ActionFXInherit` and then checks if the object's `Action`, `Moment`, or `Actor` properties match the corresponding properties of the filter. If the object is not an instance of `ActionFXInherit`, it checks if the object is in the `last_lists` table, which is a cache of the previous filtering results.
---
--- @param obj table The object to be filtered.
--- @return boolean True if the object passes the filter, false otherwise.
function ActionFXFilter:FilterObject(obj)
	if obj:IsKindOf("ActionFXInherit") then
		return
			obj:IsKindOf("ActionFXInherit_Action") and (self.Action == "any" or obj.Action == self.Action or obj.Inherit == self.Action) or
			obj:IsKindOf("ActionFXInherit_Moment") and (self.Moment == "any" or obj.Moment == self.Moment or obj.Inherit == self.Moment) or
			obj:IsKindOf("ActionFXInherit_Actor")  and (self.Actor  == "any" or obj.Actor  == self.Actor  or obj.Inherit == self.Actor )
	end
	if self.last_lists then
		return self.last_lists[obj]
	end
	return true
end

---
--- Resets the debug flags for the ActionFXFilter.
---
--- This method is responsible for resetting the debug flags for the ActionFXFilter based on the current filter settings. If the DebugFX flag is true, the method sets the DebugFX, DebugFXAction, DebugFXMoment, and DebugFXTarget flags based on the current filter settings. If the DebugFX flag is false, the method sets all the debug flags to false.
---
--- @param self ActionFXFilter The ActionFXFilter instance.
function ActionFXFilter:ResetDebugFX()
	if self.DebugFX then
		DebugFX       = self.Actor  ~= "any" and self.Actor  or true
		DebugFXAction = self.Action ~= "any" and self.Action or false
		DebugFXMoment = self.Moment ~= "any" and self.Moment or false
		DebugFXTarget = self.Target ~= "any" and self.Target or false
	else
		DebugFX       = false
		DebugFXAction = false
		DebugFXMoment = false
		DebugFXTarget = false
	end
end

---
--- Prepares the ActionFXFilter for filtering by getting the FX list for the editor.
---
--- This method is part of the `ActionFXFilter` class and is responsible for preparing the filter for filtering by getting the FX list for the editor. It sets the `last_lists` property of the filter to the result of calling the `GetFXListForEditor` function with the filter as an argument.
---
--- @param self ActionFXFilter The ActionFXFilter instance.
function ActionFXFilter:PrepareForFiltering()
	self.last_lists = GetFXListForEditor(self)
end

---
--- Notifies the ActionFXFilter that the filtering process has completed.
---
--- This method is called after the filtering process has completed, and it updates the `fx_counter` property of the ActionFXFilter instance to the provided `count` value. If the `fx_counter` property has changed, it also notifies that the object has been modified.
---
--- @param self ActionFXFilter The ActionFXFilter instance.
--- @param count number The number of filtered objects.
function ActionFXFilter:DoneFiltering(count)
	if self.fx_counter ~= count then
		self.fx_counter = count
		ObjModified(self)
	end
end

function OnMsg.GedClosing(ged_id)
	local ged = GedConnections[ged_id]
	if ged.app_template == "GedFXEditor" then
		local filter = ged:FindFilter("root")
		filter.DebugFX = false
		filter:ResetDebugFX()
	end
end

---
--- Applies the selected FX preset to the root filter of the given GED.
---
--- This function is used to apply the selected FX preset to the root filter of the given GED. It retrieves the preset from the root object at the given selection indices, and then updates the properties of the root filter accordingly.
---
--- @param ged table The GED instance.
--- @param root table The root object.
--- @param sel table The selection indices.
function GedOpFxUseAsFilter(ged, root, sel)
	local preset = root[sel[1]][sel[2]]
	if preset then
		local filter = ged:FindFilter("root")
		filter.Action = preset.Action
		filter.Moment = preset.Moment
		filter.Actor = preset.Actor
		filter.Target = preset.Target
		filter.SaveIn = preset.SaveIn
		filter:ResetTarget(ged)
	end
end

---
--- Checks for duplicate FX in the FXRules table.
---
--- This function iterates through the FXRules table and checks for duplicate FX. It ignores certain classes and properties, and generates a string representation of each FX based on its properties. If a duplicate FX is found, it is added to the DuplicatedFX table and an error is logged.
---
--- @return number The number of duplicate FX found.
function CheckForDuplicateFX()
	local count = 0
	local type_to_props = {}
	local ignore_classes = {
		ActionFXBehavior = true,
	}
	local ignore_props = {
		id = true,
	}
	local duplicated = {}
	DuplicatedFX = duplicated
	for action_id, actions in pairs(FXRules) do
		for moment_id, moments in pairs(actions) do
			for actor_id, actors in pairs(moments) do
				for target_id, targets in pairs(actors) do
					local str_to_fx = {}
					for _, fx in ipairs(targets) do
						local class = fx.class
						if not ignore_classes[class] then
							local str = pstr(class, 1024)
							local props = type_to_props[class]
							if not props then
								props = {}
								type_to_props[class] = props
								for _, prop in ipairs(g_Classes[class]:GetProperties()) do
									local id = prop.id
									if not ignore_props[id] then
										props[#props + 1] = id
									end
								end
							end
							for _, id in ipairs(props) do
								str:append("\n")
								ValueToLuaCode(fx:GetProperty(id), "", str)
							end
							local key = tostring(str)
							local prev_fx = str_to_fx[key]
							if prev_fx then
								GameTestsError("Duplicate FX:", fx.fx_type, action_id, moment_id, actor_id, target_id)
								count = count + 1
								duplicated[prev_fx] = true
								duplicated[fx] = true
							else
								str_to_fx[key] = fx
							end
						end
					end
				end
			end
		end
	end
	GameTestsPrintf("%d duplicated FX found!", count)
	return count
end

---
--- Checks for duplicate FX in the game.
---
--- This function is used to detect and report any duplicate FX that may exist in the game's FX system.
--- It iterates through all the FX rules, moments, actors, and targets, and checks for any duplicate FX
--- based on their properties. If any duplicates are found, they are reported and counted.
---
--- @return number The number of duplicate FX found.
function GameTests.TestActionFX()
	CheckForDuplicateFX()
end

---
--- Checks for duplicate FX in the game.
---
--- This function is used to detect and report any duplicate FX that may exist in the game's FX system.
--- It iterates through all the FX rules, moments, actors, and targets, and checks for any duplicate FX
--- based on their properties. If any duplicates are found, they are reported and counted.
---
--- @return number The number of duplicate FX found.
function GedOpFxCheckDuplicates(ged, root, sel)
	CheckForDuplicateFX()
end