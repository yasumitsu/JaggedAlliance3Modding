--local err, folders = AsyncListFiles(path.assets.exporter, "*", "recursive,relative,folders")

g_AllInteractableIconsCached = false
---
--- Returns a list of all available interactable icons.
--- If the list has not been cached yet, it will be loaded from the file system.
---
--- @return string[] All available interactable icon paths.
---
function AllInteractableIcons()
	if not g_AllInteractableIconsCached then
		local err, files = AsyncListFiles("UI/Hud/", "iw*")
		if not err then
			files = table.map(files, function(f)
				local path, file, ext = SplitPath(f) 
				return path .. file 
			end)
			g_AllInteractableIconsCached = files
		else
			g_AllInteractableIconsCached = {}
		end
	end
	return g_AllInteractableIconsCached
end

--[[@@@
@class CustomInteractable
CustomInteractable is a special type of Interactable object (doesn't have too much in common with Interactables, but provides similar functions).
These objects can be interacted with in only one way - a "custom interaction" that they define through conditions and effects.
Meaning - instead of inheriting from this class, conditions and effects should be assigned, to define it's interaction.
When placed in the world, this object is invisible (can be seen only in editor mode).
It should be made visible in the game through other dummy objects, by putting them all in a collection.
]]
DefineClass.CustomInteractable = {
	__parents = { "EditorVisibleObject", "Interactable", "BoobyTrappable", "Object", "GridMarker" },
	properties = {
		{ category = "Interactable", id = "DisplayName", name = "Display Name", editor = "text", translate = true, default = "" },
		{ category = "Interactable", id = "ActionPoints", name = "Action Points", editor = "number", scale = "AP", default = const["Action Point Costs"].CustomInteractableInteractionCost },
		{ category = "Interactable", id = "InteractionLoadingBar", name = "Interaction Loading Bar", editor = "bool", default = true },
		--{ category = "Interactable", id = "Icon", name = "Icon", editor = "text", default = "UI/Icons/Hud/interact" },
		{ category = "Interactable", id = "Visuals", name = "Visuals", editor = "choice", default = "UI/Hud/iw_examine", items = AllInteractableIcons },
		{ category = "Interactable", id = "highlight", name = "Highlight", editor = "bool", default = true },
		{ category = "Interactable", id = "special_highlight", name = "Special Highlight", editor = "bool", default = true},
		
		{ category = "Interactable", id = "EnabledConditions", name = "Enable conditions", editor = "nested_list", base_class = "Condition", default = false },
		{ category = "Interactable", id = "ConditionalSequentialEffects", name = "Execute Effects Sequentially", editor = "bool", default = true, help = "Whether effects should wait for each other when executing in order."},
		{ category = "Interactable", id = "ConditionalEffects", name = "Effects", editor = "nested_list", base_class = "Effect", all_descendants = true, default = false },
		{ category = "Interactable", id = "MultiSelectBehavior", name = "MultiSelectBehavior", editor = "choice", items = { "all", "nearest" }, default = "all" },
		{ category = "Grid Marker", id = "Type", name = "Type", editor = "dropdownlist", items = PresetGroupCombo("GridMarkerType", "Default"), default = "CustomInteractable", no_edit = true },
		{ category = "Marker", id = "AreaHeight", name = "Area Height", editor = "number", default = 0, help = "Defining a voxel-aligned rectangle with North-South and East-West axes"},
		{ category = "Marker", id = "AreaWidth",  name = "Area Width", editor = "number", default = 0, help = "Defining a voxel-aligned rectangle with North-South and East-West axes"},
	},
	
	entity = "WayPoint",
	EditorIcon = "CommonAssets/UI/Icons/about info information service",
	range_in_tiles = 3
}

--[[@@@
Returns if the custom interaction is available for execution, depending on the assigned conditions.
@function string CustomInteractable@GetUIState(Unit unit, ...)
@param - Unit[] unit - The units that want to interact with this object.
@result - string availability - Possible values "enabled", "disabled", "hidden".
]]
---
--- Gets the UI state of the CustomInteractable object for the given unit.
---
--- @param unit Unit The unit interacting with the CustomInteractable object.
--- @param ... any Additional arguments (not used).
--- @return string The UI state of the CustomInteractable object, either "enabled" or "disabled".
---
function CustomInteractable:GetUIState(unit, ...)
	if self.EnabledConditions then
		return self:IsMarkerEnabled({ target_units = unit, interactable = self, no_log = true }) and "enabled" or "disabled"
	end
	return "enabled"
end

--[[@@@
Performs the action itself by executing all effects and then consumes the required action points.
@function void CustomInteractable@Execute(Unit unit, ...)
@param - Unit[] unit - The units that want to interact with this object.
]]
---
--- Executes the custom interactable object, triggering any associated effects and consuming the required action points.
---
--- @param units Unit[] The units that want to interact with this object.
--- @param ... any Additional arguments (not used).
---
function CustomInteractable:Execute(units, ...)
	if #units > 1 then
		MultiTargetExecute(self.MultiSelectBehavior, units, function(unit, self, ...)
			self:Execute({unit}, ...)
		end, self, ...)
		return
	end
	
	local unit = units[1]
	if self:TriggerTrap(unit) then
		return
	end
	if not self.ConditionalEffects then return end
	
	if self.ConditionalSequentialEffects then
		local endEvent = ExecuteSequentialEffects(self.ConditionalEffects, "CustomInteractable", { unit.handle }, self.handle)
		CreateRealTimeThread(function()
			WaitMsg(endEvent)
			Msg("CustomInteractableEffectsDone", self)
		end)
	else
		ExecuteEffectList(self.ConditionalEffects, unit, { target_units = {unit}, interactable = self })
		Msg("CustomInteractableEffectsDone", self)
	end
end

--- Gets the combat action and icon for the CustomInteractable object when interacting with the given unit.
---
--- @param unit Unit The unit interacting with the CustomInteractable object.
--- @return string, string The combat action and icon for the CustomInteractable object.
---
function CustomInteractable:GetInteractionCombatAction(unit)
	local trapAction, icon = BoobyTrappable.GetInteractionCombatAction(self, unit)
	if trapAction then return trapAction, icon end
	return Presets.CombatAction.Interactions.Interact_CustomInteractable
end

local lconversionTable = {
	["IwExamine"] = "UI/Hud/iw_examine",
	["IwLoot"] = "UI/Hud/iw_loot",
	["IwOpenDoor"] = "UI/Hud/iw_open_door",
	["IwSpeak"] = "UI/Hud/iw_speak",
}

---
--- Gets the interaction visuals (icon) for the CustomInteractable object.
---
--- @return string The icon to use for the interaction.
---
function CustomInteractable:GetInteractionVisuals()
	local trapAction, boobyTrapIcon = BoobyTrappable.GetInteractionCombatAction(self, Selection and Selection[1])
	if trapAction and boobyTrapIcon then return boobyTrapIcon end

	local legacyIcon = lconversionTable[self.Visuals]
	if legacyIcon then return legacyIcon end
	
	return self.Visuals
end

---
--- Gets the highlight color for the CustomInteractable object.
---
--- @return integer The highlight color for the CustomInteractable object.
---
function CustomInteractable:GetHighlightColor()
	if BoobyTrappable.GetHighlightColor(self) == 2 then return 2 end
	return self.special_highlight and 4 or 3
end

---
--- Checks if the CustomInteractable object is discoverable.
---
--- @return boolean True if the CustomInteractable object is discoverable, false otherwise.
---
function CustomInteractable:RunDiscoverability()
	return BoobyTrappable.RunDiscoverability(self) and SpawnedByEnabledMarker(self)
end

---
--- Checks if the CustomInteractable object has a valid DisplayName and returns an error message if not.
---
--- @return string The error message if the DisplayName is empty, or nil if the DisplayName is valid.
---
function CustomInteractable:GetError()
	if self.DisplayName == "" then
		return string.format("CustomInteractable '%s' requires DisplayName", self.ID)
	end
end

DefineClass.ExamineMarker = {
	__parents = {"CustomInteractable"},
	properties = {
		{ category = "Interactable", id = "DisplayName", name = "Display Name", editor = "text", translate = true, default = T(923956407215, "Examine"), no_edit = true },
		{ category = "Interactable", id = "special_highlight", name = "Special Highlight", editor = "bool", default = false},
	},
	range_in_tiles = const.ExamineMarkerInteractionDistance,
	InteractionLoadingBar = false
}

---
--- Returns a list of all unit property IDs that are in the "Stats" category.
---
--- @return table The list of unit property IDs in the "Stats" category.
---
function GetUnitStatsCombo()
	local items = {}
	local props = UnitPropertiesStats:GetProperties()
	for _, prop in ipairs(props) do
		if prop.category == "Stats" then
			items[#items + 1] = prop.id
		end
	end
	return items
end

DefineClass.RangeGrantMarker = {
	__parents = {"CustomInteractable"},

	properties = {
		{ category = "Grant", id = "SkillRequired", name = "Skill Required", editor = "combo", items = GetUnitStatsCombo, default = "" },
		{ category = "Grant", id = "Difficulty", name = "Difficulty", editor = "combo", items = const.DifficultyPresetsNew, arbitrary_value = false, default = "Easy" },
		{ category = "Grant", id = "RandomDifficulty", name = "Randomized Difficulty", editor = "bool", default = true, },
	},

	range_in_tiles = const.HerbMarkerInteractionDistance,
	floating_text_activated = T(898871916829, "Success"),
	combat_log_text_activated = T(148934830580, "(Success) Found"),
	grant_item_class = "Meds",
	grant_item_min = 1,
	grant_item_max = 5,
	
	additional_difficulty = 0,
	activated = false,
	granted = false,
}

---
--- Initializes the `RangeGrantMarker` class.
---
--- If the `RandomDifficulty` property is true and the `SkillRequired` property is not empty, this function sets the `additional_difficulty` property to a random value between -10 and 10 plus the `SkillRequired` value.
---
--- @method GameInit
function RangeGrantMarker:GameInit()
	if self.RandomDifficulty and self.SkillRequired ~= "" then
		self.additional_difficulty = InteractionRand(20, self.SkillRequired) - 10
	end
end

---
--- Retrieves the dynamic data for the `RangeGrantMarker` class.
---
--- If the `RandomDifficulty` property is true, the `additional_difficulty` field is included in the returned data.
--- The `activated` and `granted` fields are also included in the returned data.
---
--- @param data table The table to store the dynamic data in.
---
function RangeGrantMarker:GetDynamicData(data)
	if self.RandomDifficulty then
		data.additional_difficulty = self.additional_difficulty
	end
	data.activated = self.activated or nil
	data.granted = self.granted or nil
end

---
--- Sets the dynamic data for the `RangeGrantMarker` class.
---
--- This function sets the `additional_difficulty`, `activated`, and `granted` properties of the `RangeGrantMarker` instance based on the provided `data` table.
---
--- @param data table The table containing the dynamic data to set.
---
function RangeGrantMarker:SetDynamicData(data)
	self.additional_difficulty = data.additional_difficulty or 0
	self.activated = data.activated or false
	self.granted = data.granted or false
end

---
--- Retrieves the interaction position for the `RangeGrantMarker` class.
---
--- If the `RangeGrantMarker` has been activated and not granted, this function returns the interaction position. Otherwise, it returns `nil`.
---
--- @param unit table The unit interacting with the `RangeGrantMarker`.
--- @return table|nil The interaction position, or `nil` if the `RangeGrantMarker` has been activated and granted.
---
function RangeGrantMarker:GetInteractionPos(unit)
	local interaction_pos = CustomInteractable.GetInteractionPos(self, unit)
	if type(interaction_pos) == "table" then
		if not self.activated or self.granted then
			return
		end
	end
	return interaction_pos
end

---
--- Activates the `RangeGrantMarker` instance.
---
--- This function is called when a unit interacts with the `RangeGrantMarker`. It performs the following actions:
--- - Sends a network update to mark the `RangeMarkerActivated` event
--- - Sets the `activated` property to `true`
--- - Sends a `GrantMarkerDiscovered` message to the unit
--- - Creates a floating text message at the `RangeGrantMarker`'s position with the `floating_text_activated` text
--- - Logs an "important" combat log message with the `combat_log_text_activated` text
--- - Sets the `discovered` property to `true`
--- - Plays a "InteractableFound" voice response for the unit (if `g_Combat` is not true)
---
--- @param unit table The unit that interacted with the `RangeGrantMarker`
---
function RangeGrantMarker:Activate(unit)
	NetUpdateHash("RangeMarkerActivated", unit.session_id)
	self.activated = true
	Msg("GrantMarkerDiscovered", unit, self)
	CreateFloatingText(self:GetPos(), self.floating_text_activated)
	CombatLog("important", T{self.combat_log_text_activated, unit})
	
	self.discovered = true
	if not g_Combat then
		PlayVoiceResponse(unit, "InteractableFound")
	end
end

---
--- Checks the discoverability of the `RangeGrantMarker` instance.
---
--- This function first checks if the `RangeGrantMarker` has been activated. If so, it calls the `RunDiscoverability` function of the base `CustomInteractable` class. If the base class function returns `false`, this function also returns `false`.
---
--- If the `RangeGrantMarker` has not been activated, this function resolves the interactable visual objects for the `RangeGrantMarker`. If there are no valid visual objects, this function returns `false`.
---
--- @param unit table The unit interacting with the `RangeGrantMarker`.
--- @return boolean True if the `RangeGrantMarker` is discoverable, false otherwise.
---
function RangeGrantMarker:RunDiscoverability(unit)
	if self.activated then -- Check for base class only if the range grant marker has been found (activated)
		local baseClassRun = CustomInteractable.RunDiscoverability(self)
		if not baseClassRun then return false end
	end

	local visual = ResolveInteractableVisualObjects(self, nil, nil, "findFirst")
	if not visual then return false end -- No visuals, or destroyed visuals
	return true
end

---
--- Grants the specified item to the given unit.
---
--- This function performs the following actions:
--- - Sets the `granted` property to `true`
--- - Calculates a random grant amount between `grant_item_min` and `grant_item_max`
--- - Applies the `GetItemGainModifier` function to increase the grant amount
--- - Adds the granted item to the unit's squad bag
--- - If there is any leftover amount, adds it to the unit's inventory
---
--- @param unit table The unit receiving the granted item
--- @return number The amount of the item granted
---
function RangeGrantMarker:Grant(unit)
	self.granted = true
	local grant_amount = self.grant_item_min + InteractionRand(self.grant_item_max - self.grant_item_min, "Loot")
	grant_amount = grant_amount + (self:GetItemGainModifier() / 2)
	local left_amount = AddItemToSquadBag(unit.Squad, self.grant_item_class, grant_amount)	
	if left_amount then
		unit:AddToInventory(self.grant_item_class, left_amount)
	end
	return grant_amount
end

---
--- Gets the item gain modifier based on the difficulty of the `RangeGrantMarker`.
---
--- The item gain modifier is retrieved from the `const.DifficultyToItemModifier` table, using the `Difficulty` property of the `RangeGrantMarker` as the key.
---
--- @return number The item gain modifier based on the difficulty.
---
function RangeGrantMarker:GetItemGainModifier()
	return const.DifficultyToItemModifier[self.Difficulty]
end

---
--- Displays floating text and combat log entry when an item is gathered from a RangeGrantMarker.
---
--- @param unit table The unit that gathered the item.
--- @param amount number The amount of the item that was gathered.
---
function RangeGrantMarker:GrantFloatingText(unit, amount)
	if amount then
		CombatLog("short", T{959250382531, "Gathered <Amount> <Item>", {Amount = amount, Item = InventoryItemDefs[self.grant_item_class].DisplayName}})
		if unit then
			CreateFloatingText(unit:GetVisualPos(), T{959250382531, "Gathered <Amount> <Item>", Amount = amount, Item = InventoryItemDefs[self.grant_item_class].DisplayName}, nil, nil, 500)
		end
	end
end

---
--- Gets the UI state for the RangeGrantMarker.
---
--- If the RangeGrantMarker is not activated or has already been granted, the UI state is "disabled". Otherwise, the UI state is determined by the base CustomInteractable.GetUIState function.
---
--- @param units table The units interacting with the RangeGrantMarker.
--- @param ... any Additional arguments passed to the base GetUIState function.
--- @return string The UI state for the RangeGrantMarker.
---
function RangeGrantMarker:GetUIState(units, ...)
	if not self.activated or self.granted then return "disabled" end
	return CustomInteractable.GetUIState(self, units, ...)
end

---
--- Checks if the RangeGrantMarker has been discovered by the given unit.
---
--- If the RangeGrantMarker is already activated, it calls the `CustomInteractable.CheckDiscovered` function.
--- Otherwise, it checks if the RangeGrantMarker has been granted or if the difficulty is less than 0. If either of these conditions is true, the function returns without doing anything.
---
--- If the RangeGrantMarker is not activated, it calculates the difficulty based on the `Difficulty` property and the `additional_difficulty` property. It then performs a skill check on the unit using the `SkillRequired` property. If the skill check is successful, the RangeGrantMarker is activated.
---
--- @param unit table The unit that is checking the RangeGrantMarker.
---
function RangeGrantMarker:CheckDiscovered(unit)
	if self.activated then
		CustomInteractable.CheckDiscovered(self, unit)
		return
	end
	if self.granted or DifficultyToNumber(self.Difficulty) < 0 then return end
	if self.activated then return end

	local difficulty = DifficultyToNumber(self.Difficulty) + self.additional_difficulty
	local result = SkillCheck(unit, self.SkillRequired, difficulty, true)
	if result == "success" then
		self:Activate(unit)
	end
end

---
--- Executes the RangeGrantMarker, granting an item to the first unit in the provided list of units.
---
--- @param units table The units interacting with the RangeGrantMarker.
--- @param ... any Additional arguments passed to the base Execute function.
---
function RangeGrantMarker:Execute(units, ...)
	CustomInteractable.Execute(self, units, ...)
	
	local unit = units[1]
	local amount = self:Grant(unit)
	self:GrantFloatingText(unit, amount)
end

---
--- Returns the display name for the trap.
---
--- @return string The display name for the trap.
---
function RangeGrantMarker:GetTrapDisplayName()
	return T(726087963038, "Trap")
end

DefineClass.HerbMarker = {
	__parents = { "RangeGrantMarker" },

	properties = {
		{ category = "Grant", id = "SkillRequired", name = "Skill Required", editor = "combo", items = GetUnitStatsCombo, default = "Wisdom", read_only = true },
		{ category = "Interactable", id = "special_highlight", name = "Special Highlight", editor = "bool", default = false},
		{ category = "Interactable", id = "Visuals", name = "Visuals", editor = "choice", default = "UI/Hud/iw_loot", items = AllInteractableIcons },
		{ category = "Grid Marker", id = "Groups",  name = "Groups", editor = "string_list", items = function() return GridMarkerGroupsCombo() end, default = {"Herb"}, arbitrary_value = true, },
		{ category = "Grant", id = "Difficulty", name = "Difficulty", editor = "combo", items = const.DifficultyPresetsWisdomMarkersNew, arbitrary_value = false, default = "Easy" },
	},

	floating_text_activated = T(250845372777, "<em>Wisdom</em>: Herbs found"),
	combat_log_text_activated = T(565308531076, "<Nick> found <em>Herbs</em> in the area"),
	grant_item_class = "Meds",
	grant_item_min = 2,
	grant_item_max = 5,
	DisplayName = T(363687811545, "Gather Herbs"),
}

DefineClass.SalvageMarker = {
	__parents = { "RangeGrantMarker" },

	properties = {
		{ category = "Grant", id = "SkillRequired", name = "Skill Required", editor = "combo", items = GetUnitStatsCombo, default = "Mechanical", read_only = true },
		{ category = "Interactable", id = "special_highlight", name = "Special Highlight", editor = "bool", default = false},
		{ category = "Interactable", id = "Visuals", name = "Visuals", editor = "choice", default = "UI/Hud/iw_loot", items = AllInteractableIcons },
		{ category = "Grid Marker", id = "Groups",  name = "Groups", editor = "string_list", items = function() return GridMarkerGroupsCombo() end, default = {"Salvage"}, arbitrary_value = true, },
	},

	floating_text_activated = T(938112938808, "<em>Mechanical</em>: Salvage found"),
	combat_log_text_activated = T(909344877136, "<Nick> found salvageable <em>Parts</em> in the area"),
	grant_item_class = "Parts",
	grant_item_min = 2,
	grant_item_max = 5,
	DisplayName = T(579260739215, "Salvage Parts"),
}

---
--- Displays a floating text message indicating the amount of parts salvaged.
---
--- @param unit table The unit that salvaged the parts.
--- @param amount number The amount of parts salvaged.
---
function SalvageMarker:GrantFloatingText(unit, amount)
	if unit and amount then
		CreateFloatingText(unit:GetVisualPos(), T{178669996888, "Salvaged <Amount> parts", Amount = amount}, nil, nil, 500)
	end
end

DefineClass.HackMarker = {
	__parents = { "RangeGrantMarker" },

	properties = {
		{ category = "Grant", id = "SkillRequired", name = "Skill Required", editor = "combo", items = GetUnitStatsCombo, default = "Mechanical", read_only = true },
		{ category = "Grant", id = "Difficulty", name = "Difficulty", editor = "combo", items = const.DifficultyPresetsNew, arbitrary_value = false, default = "Medium" },
		{ category = "Grant", id = "MoneyWeight", name = "Money Weight", editor = "number", default = 7000, min = 0},
		{ category = "Grant", id = "IntelWeight", name = "Intel Weight", editor = "number", default = 3000, min = 0},
		{ category = "Grant", id = "MoneyAmount", name = "Money to Grant", editor = "number", default = 250},
		{ category = "Interactable", id = "Visuals", name = "Visuals", editor = "choice", default = "UI/Hud/iw_hack", items = AllInteractableIcons },
		{ category = "Grid Marker", id = "Groups",  name = "Groups", editor = "string_list", items = function() return GridMarkerGroupsCombo() end, default = {"Hack"}, arbitrary_value = true, },
	},
	
	floating_text_activated = T(526938056924, "<em>Mechanical</em>: Hackable device found"),
	combat_log_text_activated = T(968826403710, "<Nick> found a <em>Hackable device</em> in the area"),
	grantedItem = "",
	grantedAmount = false,
	DisplayName = T(825733718854, "Hack"),
}

---
--- Executes the HackMarker functionality.
---
--- @param units table The units interacting with the HackMarker.
--- @param ... any Additional arguments passed to the Execute function.
---
function HackMarker:Execute(units, ...)
	RangeGrantMarker.Execute(self, units, ...)
end

---
--- Grants the rewards for successfully hacking a device.
---
--- If the device grants money, a random modifier is applied to the base money amount, and the modified amount is added to the player's money. If the device grants intel, a random intel sector is discovered.
---
--- @param unit table The unit that successfully hacked the device.
---
function HackMarker:Grant(unit)
	local intelSectors = GetSectorsAvailableForIntel(2)
	local weightTable = {{self.MoneyWeight, "Money"}}
	if next(intelSectors) then
		weightTable[#weightTable + 1] = {self.IntelWeight, "Intel"}
	end
	self.grantedItem = #weightTable > 1 and GetWeightedRandom(weightTable, unit:Random()) or "Money"
	
	if self.grantedItem == "Money" then
		local moneyRandomModifier = 1 + unit:Random(4)
		local amount = self.MoneyAmount * (moneyRandomModifier + self:GetItemGainModifier())
		amount = unit:CallReactions_Modify("OnCalcHackMoneyGained", amount)
		AddMoney(amount, "deposit")
		self.grantedAmount = amount
	else
		DiscoverIntelForRandomSector(2)
		unit:CallReactions("OnHackIntelDsicovered")
	end
	self.granted = true
end

---
--- Grants floating text to the unit based on the reward granted from hacking a device.
---
--- If the device grants money, a floating text message is created displaying the amount of money gained.
--- If the device grants intel, a floating text message is created indicating that intel was gained.
---
--- @param unit table The unit that successfully hacked the device.
---
function HackMarker:GrantFloatingText(unit)
	if not unit then return end
	
	if self.grantedItem == "Money" then
		if not self.grantedAmount then return end
		CreateFloatingText(unit:GetVisualPos(), T{596293026247, "Gained <money(Amount)>", Amount = self.grantedAmount}, nil, nil, 500)
	elseif self.grantedItem == "Intel" then
		CreateFloatingText(unit:GetVisualPos(), T(993640719450, "Gained Intel"), nil, nil, 500)
	end
end

---
--- Checks if the hack marker has been discovered by the given unit.
---
--- If the hack marker has already been activated, it calls the `CheckDiscovered` method of the `CustomInteractable` class.
--- If the hack marker has already been granted, or the difficulty is less than 0, the function returns without doing anything.
--- If the unit has the "MrFixit" perk, the difficulty is reduced by the value specified in the `CharacterEffectDefs.MrFixit:ResolveValue("mrfixit_bonus")` property.
--- The function then performs a skill check using the `SkillCheck` function, passing in the unit, the required skill, and the adjusted difficulty. If the result is "success", the `Activate` method of the hack marker is called.
---
--- @param unit table The unit that is checking the hack marker.
---
function HackMarker:CheckDiscovered(unit)
	if self.activated then
		CustomInteractable.CheckDiscovered(self, unit)
		return
	end
	if self.granted or DifficultyToNumber(self.Difficulty) < 0 then return end
	if self.activated then return end

	local difficulty = DifficultyToNumber(self.Difficulty) + self.additional_difficulty
	if HasPerk(unit, "MrFixit") then
		difficulty = difficulty - CharacterEffectDefs.MrFixit:ResolveValue("mrfixit_bonus")
	end
	
	local result = SkillCheck(unit, self.SkillRequired, difficulty, true)
	if result == "success" then
		self:Activate(unit)
	end
end