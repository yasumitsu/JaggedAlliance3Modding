----- Status effects exclusivity

if FirstLoad then
	ExclusiveStatusEffects, RemoveStatusEffects = {}, {}
end

local exclusive_status_effects, remove_status_effects = ExclusiveStatusEffects, RemoveStatusEffects
---
--- Builds the maps of exclusive and removable status effects.
--- This function is called when the game's mods are reloaded or data is loaded.
--- It iterates through all `StatusEffect` classes and builds two maps:
--- - `ExclusiveStatusEffects`: a map of status effect IDs to sets of other status effect IDs that are mutually exclusive.
--- - `RemoveStatusEffects`: a map of status effect IDs to sets of other status effect IDs that are removed when the current status effect is added.
---
--- The exclusivity and removal relationships are built based on the `Incompatible` and `RemoveStatusEffects` properties of each `StatusEffect` class.
---
--- @function BuildStatusEffectExclusivityMaps
--- @return nil
function BuildStatusEffectExclusivityMaps()
	ExclusiveStatusEffects, RemoveStatusEffects = {}, {}
	exclusive_status_effects, remove_status_effects = ExclusiveStatusEffects, RemoveStatusEffects
	for name, class in pairs(ClassDescendants("StatusEffect")) do
		local exclusive = exclusive_status_effects[name] or {}
		local remove = remove_status_effects[name] or {}
		ForEachPreset(name, function(preset)
			local id1 = preset.id
			for _, id2 in ipairs(preset.Incompatible) do
				exclusive[id1] = table.create_add_set(exclusive[id1], id2)
				exclusive[id2] = table.create_add_set(exclusive[id2], id1)
			end
			for _, id2 in ipairs(preset.RemoveStatusEffects) do
				remove[id1] = table.create_add_set(remove[id1], id2)
				local back_referenced = table.get(remove, id2, id1)
				if back_referenced then
					exclusive[id1] = nil
				else
					exclusive[id2] = table.create_add_set(exclusive[id2], id1)
				end
			end
		end)
		exclusive_status_effects[name] = exclusive
		remove_status_effects[name] = remove
	end
end

OnMsg.ModsReloaded = BuildStatusEffectExclusivityMaps
OnMsg.DataLoaded = BuildStatusEffectExclusivityMaps

----- StatusEffect

DefineClass.StatusEffect = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Status Effect", id = "IsCompatible", editor = "expression", params = "self, owner, ..." },
		{ category = "Status Effect", id = "Incompatible", name = "Incompatible", help = "Defines mutually exclusive status effects that cannot coexist. A status effect cannot be added if there are exclusive ones already present. The relationship is symmetric.", 
			editor = "preset_id_list", default = {}, preset_class = function(obj) return obj.class end, item_default = "", },
		{ category = "Status Effect", id = "RemoveStatusEffects", name = "Remove", help = "Status effects to be removed when this one is added. A removed status effect cannot be added later if the current status effect is present, unless they are set to remove each other.", 
			editor = "preset_id_list", default = {}, preset_class = function(obj) return obj.class end, item_default = "", },
		{ category = "Status Effect", id = "ExclusiveResults", name = "Exclusive To",
			editor = "text", default = false, dont_save = true, read_only = true, max_lines = 2, },
		{ category = "Status Effect", id = "OnAdd", editor = "func", params = "self, owner, ..." },
		{ category = "Status Effect", id = "OnRemove", editor = "func", params = "self, owner, ..." },
		{ category = "Status Effect Limit", id = "StackLimit", name = "Stack limit", editor = "number", default = 0, min = 0,
			no_edit = function(self) return not self.HasLimit end, dont_save = function(self) return not self.HasLimit end,
			help = "When the Stack limit count is reached, OnStackLimitReached() is called" },
		{ category = "Status Effect Limit", id = "StackLimitCounter", name = "Stack limit counter", editor = "expression",
			default = function (self, owner) return self.id end,
			no_edit = function(self) return self.StackLimit == 0 end, dont_save = function(self) return self.StackLimit == 0 end,
			help = "Returns the name of the limit counter used to count the StatusEffects. For example different StatusEffects can share the same counter."},
		{ category = "Status Effect Limit", id = "OnStackLimitReached", editor = "func", params = "self, owner, ...",
			no_edit = function(self) return self.StackLimit == 0 end, dont_save = function(self) return self.StackLimit == 0 end, },
		{ category = "Status Effect Expiration", id = "Expiration", name = "Auto expire", editor = "bool", default = false, 
			no_edit = function(self) return not self.HasExpiration end, dont_save = function(self) return not self.HasExpiration end, },
		{ category = "Status Effect Expiration", id = "ExpirationTime", name = "Expiration time", editor = "number", default = 480000, scale = "h", min = 0,
			no_edit = function(self) return not self.Expiration end, dont_save = function(self) return not self.Expiration end, },
		{ category = "Status Effect Expiration", id = "ExpirationRandom", name = "Expiration random", editor = "number", default = 0, scale = "h", min = 0,
			no_edit = function(self) return not self.Expiration end, dont_save = function(self) return not self.Expiration end,
			help = "Expiration time + random(Expiration random)" },
		{ category = "Status Effect Expiration", id = "ExpirationLimits", name = "Expiration Limits (ms)", editor = "range", default = false,
			no_edit = function(self) return not self.Expiration end, dont_save = true, read_only = true },
		{ category = "Status Effect Expiration", id = "OnExpire", editor = "func", params = "self, owner",
			no_edit = function(self) return not self.Expiration end, dont_save = function(self) return not self.Expiration end, },
	},
	StoreAsTable = true,

	HasLimit = true,
	HasExpiration = true,

	Instance = false,
	expiration_time = false,
}

local find = table.find
local find_value = table.find_value
local remove_value = table.remove_value

--- Returns the range of expiration time for this status effect.
---
--- The expiration time is calculated as:
--- `ExpirationTime + random(ExpirationRandom)`
---
--- This function returns a tuple containing the minimum and maximum expiration time in milliseconds.
---
--- @return number, number The minimum and maximum expiration time in milliseconds.
function StatusEffect:GetExpirationLimits()
	return range(self.ExpirationTime, self.ExpirationTime + self.ExpirationRandom)
end

---
--- Checks if the status effect is compatible with the given owner.
---
--- This function always returns `true`, as there are no compatibility checks
--- implemented in the base `StatusEffect` class. Derived classes may override
--- this function to implement their own compatibility logic.
---
--- @param owner table The owner object to check compatibility with.
--- @return boolean `true` if the status effect is compatible, `false` otherwise.
function StatusEffect:IsCompatible(owner)
	return true
end

---
--- Called when the status effect is added to an owner.
---
--- This function is called when the status effect is added to an owner object.
--- Derived classes can override this function to implement custom behavior when
--- the status effect is added.
---
--- @param owner table The owner object that the status effect is being added to.
---
function StatusEffect:OnAdd(owner)
end

---
--- Called when the status effect is removed from an owner.
---
--- This function is called when the status effect is removed from an owner object.
--- Derived classes can override this function to implement custom behavior when
--- the status effect is removed.
---
--- @param owner table The owner object that the status effect is being removed from.
---
function StatusEffect:OnRemove(owner)
end

---
--- Called when the stack limit for this status effect is reached.
---
--- This function is called when the number of stacked instances of this status effect
--- on the owner reaches the `StackLimit` value. Derived classes can override this
--- function to implement custom behavior when the stack limit is reached.
---
--- @param owner table The owner object that the status effect is stacked on.
--- @param ... any Additional arguments passed to the function.
---
function StatusEffect:OnStackLimitReached(owner, ...)
end

---
--- Called when the status effect expires and needs to be removed from the owner.
---
--- This function is called when the status effect has expired and needs to be removed from the owner object. It calls the `RemoveStatusEffect` function on the owner to remove the status effect.
---
--- @param owner table The owner object that the status effect is being removed from.
---
function StatusEffect:OnExpire(owner)
	owner:RemoveStatusEffect(self, "expire")
end

---
--- Removes the status effect from the given owner object.
---
--- This function is called to remove the status effect from the owner object. It calls the `RemoveStatusEffect` function on the owner to remove the status effect.
---
--- @param owner table The owner object that the status effect is being removed from.
--- @param reason string The reason for removing the status effect.
---
function StatusEffect:RemoveFromOwner(owner, reason)
	owner:RemoveStatusEffect(self, reason)
end

---
--- Fixes the `__index` metamethod for instances of the `StatusEffect` class that are loaded from saved games.
---
--- This function is called during the `PostLoad` phase of the `StatusEffect` class. It sets the `__index` metamethod of the class to itself, which ensures that instances loaded from saved games have the correct behavior.
---
--- This is necessary because Lua tables can have a custom `__index` metamethod, which is used to look up missing fields in the table. When instances of the `StatusEffect` class are loaded from saved games, the `__index` metamethod may not be set correctly, leading to unexpected behavior. This function ensures that the `__index` metamethod is set correctly for all instances of the `StatusEffect` class.
---
function StatusEffect:PostLoad()
	self.__index = self -- fix for instances in saved games
end

---
--- Called when a property of the `StatusEffect` class is set in the editor.
---
--- This function is called when a property of the `StatusEffect` class is set in the editor. If the `Incompatible` or `RemoveStatusEffects` property is set, it calls the `BuildStatusEffectExclusivityMaps` function to update the exclusivity maps for status effects.
---
--- @param prop_id string The ID of the property that was set.
--- @param old_value any The old value of the property.
--- @param ged table The GED (Game Editor) object that triggered the property change.
--- @return any The result of calling the `Preset.OnEditorSetProperty` function.
---
function StatusEffect:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Incompatible" or prop_id == "RemoveStatusEffects" then
		BuildStatusEffectExclusivityMaps()
	end
	return Preset.OnEditorSetProperty(self, prop_id, old_value, ged)
end

---
--- Returns a comma-separated string of the IDs of status effects that are exclusive to the current status effect.
---
--- This function retrieves the list of status effects that are exclusive to the current status effect, and returns a comma-separated string of their IDs. This can be used to display the list of incompatible status effects in the game UI.
---
--- @return string A comma-separated string of the IDs of status effects that are exclusive to the current status effect.
---
function StatusEffect:GetExclusiveResults()
	return table.concat(table.keys(table.get(ExclusiveStatusEffects, self.class, self.id), true), ", ")
end

----- StatusEffectsObject

DefineClass.StatusEffectsObject = {
	__parents = { "Object" },
	status_effects = false,
	status_effects_can_remove = true,
	status_effects_limits = false,
}

local table = table
local empty_table = empty_table

---
--- Adds a status effect to the `StatusEffectsObject`.
---
--- This function adds a new status effect to the `StatusEffectsObject`. It checks if the status effect is compatible with the object, and if it doesn't conflict with any exclusive status effects. It then updates the status effect limits and adds the effect to the list of active status effects.
---
--- @param effect StatusEffect The status effect to add.
--- @param ... any Additional arguments to pass to the status effect's `OnAdd` function.
--- @return StatusEffect|nil The added status effect, or `nil` if the status effect could not be added.
---
function StatusEffectsObject:AddStatusEffect(effect, ...)
	if not effect:IsCompatible(self, ...) then return end
	local class = effect.class
	for _, id in ipairs(exclusive_status_effects[class][effect.id]) do
		if self:FirstEffectByIdClass(id, class) then
			return
		end
	end
	local limit = effect.StackLimit
	if limit > 0 then
		local status_effects_limits = self.status_effects_limits
		if not status_effects_limits then
			status_effects_limits = {}
			self.status_effects_limits = status_effects_limits
		end
		local counter = effect:StackLimitCounter() or false
		local count = status_effects_limits[counter] or 0
		if limit == 1 then -- for Modal effects (StackLimit == 1) keep a reference to the effect itself in the limits table
			if count ~= 0 then
				return effect:OnStackLimitReached(self, ...)
			end
			status_effects_limits[counter] = effect
		else
			if count >= limit then
				return effect:OnStackLimitReached(self, ...)
			end
			status_effects_limits[counter] = count + 1
		end
	end
	self:RefreshExpiration(effect)
	local status_effects = self.status_effects
	if not status_effects then
		status_effects = {}
		self.status_effects = status_effects
	end
	for _, id in ipairs(remove_status_effects[class][effect.id]) do
		local effect
		repeat
			effect = self:FirstEffectByIdClass(id, class)
			if effect then
				effect:RemoveFromOwner(self, "exclusivity")
			end
		until not effect
	end
	status_effects[#status_effects + 1] = effect
	effect:OnAdd(self, ...)
	return effect
end

---
--- Refreshes the expiration time of the given status effect.
---
--- If the status effect has an expiration time, this function will update the `expiration_time` field of the effect to the current game time plus the effect's `ExpirationTime` and a random value within the `ExpirationRandom` range.
---
--- @param effect StatusEffect The status effect to refresh the expiration time for.
function StatusEffectsObject:RefreshExpiration(effect)
	if effect.Expiration then
		assert(effect.Instance) -- effects with expiration have to be instanced
		effect.expiration_time = GameTime() + effect.ExpirationTime + InteractionRand(effect.ExpirationRandom, "status_effect", self)
	end
end

---
--- Removes a status effect from the owner.
---
--- This function removes the given status effect from the owner's list of active status effects. If the status effect has a stack limit, the function will update the stack limit counter accordingly.
---
--- @param effect StatusEffect The status effect to remove.
--- @param ... Any additional arguments to pass to the `OnRemove` callback of the status effect.
---
function StatusEffectsObject:RemoveStatusEffect(effect, ...)
	assert(self.status_effects_can_remove)
	local n = remove_value(self.status_effects, effect)
	assert(n) -- removing an effect that is not added
	if not n then return end
	local limit = effect.StackLimit
	if limit > 0 then
		local status_effects_limits = self.status_effects_limits
		local counter = effect:StackLimitCounter() or false
		if status_effects_limits then
			local count = status_effects_limits[counter] or 1
			if limit == 1 or count == 1 then
				status_effects_limits[counter] = nil
			else
				status_effects_limits[counter] = count - 1
			end
		end
	end
	effect:OnRemove(self, ...)
end

-- Modal effects are the ones with StackLimit == 1
---
--- Gets the modal status effect for the given counter.
---
--- Modal effects are the ones with StackLimit == 1. This function returns the modal status effect associated with the given counter, or `false` if no such effect exists.
---
--- @param counter string|boolean The counter to get the modal status effect for. If `false`, the function will return the first modal status effect regardless of counter.
--- @return StatusEffect|false The modal status effect, or `false` if none exists.
function StatusEffectsObject:GetModalStatusEffect(counter)
	local status_effects_limits = self.status_effects_limits
	local effect = status_effects_limits and status_effects_limits[counter or false] or false
	assert(not effect or type(effect) == "table")
	return effect
end

---
--- Gets the status effect associated with the given counter.
---
--- This function returns the status effect associated with the given counter, or `false` if no such effect exists. If the effect has a stack limit greater than 1, the function will return the first effect with the given counter.
---
--- @param counter string|boolean The counter to get the status effect for. If `false`, the function will return the first effect regardless of counter.
--- @return StatusEffect|false The status effect, or `false` if none exists.
function StatusEffectsObject:FirstEffectByCounter(counter)
	local status_effects_limits = self.status_effects_limits
	local effect = status_effects_limits and status_effects_limits[counter or false] or false
	if not effect then return end
	if type(effect) == "table" then
		assert(effect:StackLimitCounter() == counter)
		return effect
	end
	for _, effect in ipairs(self.status_effects or empty_table) do
		if effect.StackLimit > 1 and effect:StackLimitCounter() == counter then
			return effect
		end
	end
end

---
--- Expires status effects that have reached their expiration time.
---
--- This function checks all the status effects associated with the `StatusEffectsObject` and removes any that have reached their expiration time. The expiration time is determined by the `expiration_time` field of the status effect.
---
--- @param time number|nil The current game time. If not provided, the current game time will be used.
function StatusEffectsObject:ExpireStatusEffects(time)
	time = time or GameTime()
	local expired_effects
	local status_effects = self.status_effects or empty_table
	for _, effect in ipairs(status_effects) do
		assert(effect)
		if effect and (effect.expiration_time or time) - time < 0 then
			expired_effects = expired_effects or {}
			expired_effects[#expired_effects + 1] = effect
		end
	end
	if not expired_effects then return end
	for i, effect in ipairs(expired_effects) do
		if i == 1 or find(status_effects, effect) then
			effect:OnExpire(self)
			effect.expiration_time = nil
		end
	end
end

---
--- Gets the status effect associated with the given ID.
---
--- This function returns the status effect associated with the given ID, or `false` if no such effect exists.
---
--- @param id string The ID of the status effect to get.
--- @return StatusEffect|false The status effect, or `false` if none exists.
function StatusEffectsObject:FirstEffectById(id)
	return find_value(self.status_effects, "id", id)
end

---
--- Gets the first status effect associated with the given group.
---
--- This function returns the first status effect associated with the given group, or `false` if no such effect exists.
---
--- @param group string The group of the status effect to get.
--- @return StatusEffect|false The status effect, or `false` if none exists.
function StatusEffectsObject:FirstEffectByGroup(group)
	return group and find_value(self.status_effects, "group", group)
end

---
--- Gets the first status effect associated with the given ID and class.
---
--- This function returns the first status effect associated with the given ID and class, or `nil` if no such effect exists.
---
--- @param id string The ID of the status effect to get.
--- @param class table The class of the status effect to get.
--- @return StatusEffect|nil The status effect, or `nil` if none exists.
--- @return integer|nil The index of the status effect in the `status_effects` table, or `nil` if none exists.
function StatusEffectsObject:FirstEffectByIdClass(id, class)
	for i, effect in ipairs(self.status_effects) do
		if effect.id == id and IsKindOf(effect, class) then
			return effect, i
		end
	end
end

---
--- Iterates over all status effects of the given class and calls the provided function for each one.
---
--- This function iterates over all status effects in the `status_effects` table that are of the given class, and calls the provided function `func` for each one, passing the effect and any additional arguments to the function.
---
--- The function temporarily disables the ability to remove status effects while iterating, to avoid issues with the iteration. After the iteration is complete, the ability to remove status effects is restored to its previous state.
---
--- @param class table The class of the status effects to iterate over.
--- @param func function The function to call for each status effect.
--- @param ... any Additional arguments to pass to the function.
--- @return any The return value of the last call to the provided function, or `nil` if the function was not called.
function StatusEffectsObject:ForEachEffectByClass(class, func, ...)
	local can_remove = self.status_effects_can_remove
	self.status_effects_can_remove = false
	local res
	for _, effect in ipairs(self.status_effects or empty_table) do
		if IsKindOf(effect, class) then
			res = func(effect, ...)
			if res then break end
		end
	end
	if can_remove then
		self.status_effects_can_remove = nil
	end
	return res
end

---
--- Chooses a random status effect from the given list, optionally with a chance of returning no effect.
---
--- This function takes a list of status effects, either as a list of strings or a list of tables with a `effect` field and an optional `weight` field. It will randomly choose one of the effects from the list, with the chance of choosing no effect controlled by the `none_chance` parameter.
---
--- If `none_chance` is greater than 0 and a random number between 1 and 100 is less than `none_chance`, the function will return `nil`, indicating no effect.
---
--- If the list contains only one effect, and it is a string, the function will return that string if the effect is not filtered out by the `templates` parameter.
---
--- If the list contains multiple effects, the function will choose one randomly, with the chance of each effect proportional to its `weight` field (or 1 if no `weight` field is present).
---
--- @param none_chance number The chance (0-100) of returning no effect.
--- @param list table A list of status effect strings or tables with `effect` and `weight` fields.
--- @param templates table An optional table of allowed status effect templates.
--- @return string|nil The chosen status effect, or `nil` if no effect was chosen.
function StatusEffectsObject:ChooseStatusEffect(none_chance, list, templates)
	if not list or #list == 0 or none_chance > 0 and InteractionRand(100, "status_effect", self) < none_chance then
		return
	end
	local cons = list[1]
	if type(cons) == "string" then
		if #list == 1 then
			if not templates or templates[cons] then
				return cons
			end
		else
			local weight = 0
			for _, cons in ipairs(list) do
				if not templates or templates[cons] then
					weight = weight + 1
				end
			end
			weight = InteractionRand(weight, "status_effect", self)
			for _, cons in ipairs(list) do
				if not templates or templates[cons] then
					weight = weight - 1
					if weight < 0 then
						return cons
					end
				end
			end
		end
	else
		assert(type(cons) == "table")
		if #list == 1 then
			if not templates or templates[cons.effect] then
				return cons.effect
			end
		else
			local weight = 0
			for _, cons in ipairs(list) do
				if not templates or templates[cons.effect] then
					weight = weight + cons.weight
				end
			end
			weight = InteractionRand(weight, "status_effect", self)
			for _, cons in ipairs(list) do
				if not templates or templates[cons.effect] then
					weight = weight - cons.weight
					if weight < 0 then
						return cons.effect
					end
				end
			end
		end
	end
end
