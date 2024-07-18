DefineClass.ZuluModifiable = {
	-- this class handles the case of Modifiable objects that need to save/load their applied modifiers in Zulu via ObjPropertyListToLuaCode
	__parents = { "Modifiable" },
	properties = {
		{ id = "applied_modifiers", editor = "prop_table", default = false, read_only = true, no_edit = true, base_class = "", },
	},
}

---
--- Adds a modifier to the `ZuluModifiable` object.
---
--- This function is responsible for managing the `applied_modifiers` table, which keeps track of all the modifiers that have been applied to the object.
---
--- If a modifier with the same `id` and `prop` already exists, it will be removed before the new modifier is added.
---
--- @param id string The identifier of the modifier to add.
--- @param prop string The property that the modifier should be applied to.
--- @param ... any The parameters to pass to the modifier.
--- @return boolean Whether the modifier was successfully added.
function ZuluModifiable:AddModifier(id, prop, ...)
	self.applied_modifiers = self.applied_modifiers or {}
	self:RemoveModifier(id, prop) -- one source can only modify the same property once in Zulu
	local mod_params = {...} 
	mod_params[1] = mod_params[1] or false
	table.insert(self.applied_modifiers, { id = id, prop = prop, params = mod_params })
	return Modifiable.AddModifier(self, id, prop, table.unpack(mod_params))
end

---
--- Removes a modifier from the `ZuluModifiable` object.
---
--- This function is responsible for removing a modifier from the `applied_modifiers` table, based on the provided `id` and `prop`.
---
--- @param id string The identifier of the modifier to remove.
--- @param prop string The property that the modifier was applied to.
--- @return boolean Whether the modifier was successfully removed.
function ZuluModifiable:RemoveModifier(id, prop)
	for i = #(self.applied_modifiers or empty_table), 1, -1 do
		local data = self.applied_modifiers[i]
		if data.id == id and data.prop == prop then
			table.remove(self.applied_modifiers, i)
		end
	end
	return Modifiable.RemoveModifier(self, id, prop)
end

---
--- Removes all modifiers with the specified `id` from the `ZuluModifiable` object.
---
--- This function iterates through the `applied_modifiers` table and removes any modifiers that match the provided `id`. It then calls the `Modifiable.RemoveModifier` function to remove the modifier from the object.
---
--- @param id string The identifier of the modifiers to remove.
function ZuluModifiable:RemoveModifiers(id)
	for i = #(self.applied_modifiers or empty_table), 1, -1 do
		local data = self.applied_modifiers[i]
		if data.id == id then
			Modifiable.RemoveModifier(self, data.id, data.prop)
			table.remove(self.applied_modifiers, i)
		end
	end
end

---
--- Resets all modifiers applied to the `ZuluModifiable` object.
---
--- This function removes all modifiers that have been applied to the object, both through the `AddModifier` function and the `modifications` table. It then resets the `applied_modifiers` table to `nil`.
---
--- @return nil
function ZuluModifiable:ResetModifiers()
	for _, data in ipairs(self.applied_modifiers or empty_table) do
		Modifiable.RemoveModifier(self, data.id, data.prop)
	end
	
	for prop, list in pairs(self.modifications or empty_table) do
		for _, mod in ipairs(list) do
			Modifiable.RemoveModifier(self, mod.id, prop)
		end
	end
	self.applied_modifiers = nil	
end

---
--- Applies a list of modifiers to the `ZuluModifiable` object.
---
--- This function takes a list of modifier data and applies them to the object. If the `add` parameter is `false`, it first resets all modifiers on the object by calling `ResetModifiers()`. Then, it iterates through the `list` of modifier data and applies each modifier using the `AddModifier()` function.
---
--- @param list table A list of modifier data, where each entry is a table with the following fields:
---   - `id`: string The identifier of the modifier
---   - `prop`: string The property the modifier is applied to
---   - `params`: table The parameters to pass to the `AddModifier()` function
--- @param add boolean If `false`, the modifiers will be reset before applying the new ones. If `true`, the new modifiers will be added to the existing ones.
function ZuluModifiable:ApplyModifiersList(list, add)
	if not add then
		self:ResetModifiers()
	end
	for _, data in ipairs(list) do
		if self:GetPropertyMetadata(data.prop) then
			-- table.unpack will fail if data.params[1] is nil, so make sure there's a value in it
			data.params[1] = data.params[1] or false
			self:AddModifier(data.id, data.prop, table.unpack(data.params))
		end
	end
end

---
--- Saves the properties of the `ZuluModifiable` object to Lua code, while preserving the modified property values.
---
--- This function first removes the currently applied modifiers to save the base values of the modified properties. It then dumps the properties to Lua code using the `ObjPropertyListToLuaCode` function. Finally, it reapplies the modifiers to restore the values of the modified properties.
---
--- @param indent string The indentation string to use for the Lua code.
--- @param GetPropFunc function A function to get the property value.
--- @param pstr string A format string for the property name.
--- @param ... any Additional arguments to pass to the `GetPropFunc` function.
--- @return string The Lua code representing the object's properties.
function ZuluModifiable:SavePropsToLuaCode(indent, GetPropFunc, pstr, ...)
	-- remove the currently applied modifiers to save the base values of the modified properties
	local old_value = {}
	for _, data in ipairs(self.applied_modifiers) do
		local prop_meta = self:GetPropertyMetadata(data.prop)
		if prop_meta then
			local base_value = self["base_" .. data.prop]
			if base_value then
				if not old_value[data.prop] then
					old_value[data.prop] = self[data.prop]
					self[data.prop] = base_value
				end
			else
				Modifiable.RemoveModifier(self, data.id, data.prop)
			end
		else
			Modifiable.RemoveModifier(self, data.id, data.prop)
		end
	end
	
	-- dump props to lua code
	local result = ObjPropertyListToLuaCode(self, indent, GetPropFunc, pstr, ...)

	-- reapply the modifiers to restore the values of the modified properties
	for _, data in ipairs(self.applied_modifiers) do
		local prop_meta = self:GetPropertyMetadata(data.prop)
		if prop_meta then
			if old_value[data.prop] then
				self[data.prop] = old_value[data.prop]
			else
				-- table.unpack will fail if data.params[1] is nil, so make sure there's a value in it
				data.params[1] = data.params[1] or false
				Modifiable.AddModifier(self, data.id, data.prop, table.unpack(data.params))
			end
		end
	end
	
	return result
end

---
--- Gets the stat boost modifiers from equipped items.
---
--- This function retrieves all the stat boost modifiers that are applied from equipped items. It filters the modifications list to only include modifiers that have an ID starting with "StatBoostItem-".
---
--- @param stat string The stat to get the modifiers for.
--- @return table The list of stat boost modifiers from equipped items.
function ZuluModifiable:GetStatBoostItemMods(stat) -- From equipable items
	if not (self.modifications and self.modifications[stat]) then return end
	local mods = {}
	for _, mod in ipairs(self.modifications[stat] or empty_table) do
		if string.match(mod.id, "StatBoostItem-.*") then
			mods[#mods+1] = mod
		end
	end
	return mods
end

---
--- Gets the non-stat boost modifiers from equipped items.
---
--- This function retrieves all the modifiers that are applied from equipped items, excluding the stat boost modifiers. It filters the modifications list to only include modifiers that do not have an ID starting with "StatBoostItem-".
---
--- @param stat string The stat to get the modifiers for.
--- @return table The list of non-stat boost modifiers from equipped items.
function ZuluModifiable:GetNonStatBoostItemMods(stat)
	if not (self.modifications and self.modifications[stat]) then return end
	local mods = {}
	for _, mod in ipairs(self.modifications[stat] or empty_table) do
		if not string.match(mod.id, "StatBoostItem-.*") then
			mods[#mods+1] = mod
		end
	end
	return mods
end

---
--- Gets the total modifiers by type for the given stat.
---
--- This function retrieves all the modifiers for the given stat and categorizes them by type, such as studying, training, stat gain, and item boosts. It returns a table with the total values for each modifier type.
---
--- @param stat string The stat to get the modifiers for.
--- @return table The total modifiers by type for the given stat.
function ZuluModifiable:GetTotalModsByType(stat)
	if not (self.modifications and self.modifications[stat]) then return end
	local mods = {}
	for _, mod in ipairs(self.modifications[stat] or empty_table) do
		if string.starts_with(mod.id, "StatBoostBook") then
			mods.studying = (mods.studying or 0) + mod.add
		elseif string.starts_with(mod.id, "StatTraining") then
			mods.training = (mods.training or 0) + mod.add
		elseif string.starts_with(mod.id, "StatGain") then
			mods.statGain = (mods.statGain or 0) + mod.add
		elseif string.starts_with(mod.id, "StatBoostItem") then
			mods.item = (mods.item or 0) + mod.add
		end
	end
	return mods
end