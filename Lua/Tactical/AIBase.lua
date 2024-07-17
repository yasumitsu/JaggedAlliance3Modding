--- Returns a table of all the unique bias IDs used in the AI archetypes and behaviors.
---
--- This function iterates through all the AI archetypes and their associated behaviors,
--- extracting the unique bias IDs used in the signature actions and behaviors. The
--- resulting table is returned.
---
--- @return table The table of unique bias IDs.
function AIBiasCombo()
	local items = {}
	
	ForEachPreset("AIArchetype", function(item)
		for _, action in ipairs(item.SignatureActions) do
			local id = action.BiasId
			if id and id ~= "" then
				table.insert_unique(items, id)
			end
		end
		for _, behavior in ipairs(item.Behaviors) do
			local id = behavior.BiasId
			if id and id ~= "" then
				table.insert_unique(items, id)
			end
			for _, action in ipairs(behavior.SignatureActions) do
				local id = action.BiasId
				if id and id ~= "" then
					table.insert_unique(items, id)
				end
			end
		end
	end)

	return items
end

DefineClass.AIBiasModification = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "BiasId", editor = "choice", default = false, items = AIBiasCombo, },
		{ id = "Effect", editor = "choice", default = "modify", items = { "modify", "disable", "priority" }, },
		{ id = "Value", editor = "number", default = 0, no_edit = function(self) return self.Effect ~= "modify" end, },
		{ id = "Period", editor = "number", default = 1, help = "in turns", },
		{ id = "ApplyTo", editor = "choice", default = "Self", items = { "Self", "Team" }, },
	},
}

--- Returns a string representation of the AIBiasModification object for the editor.
---
--- This function generates a string that describes the effect of the AIBiasModification
--- object, based on its properties. The string is used to display the modification
--- in the editor UI.
---
--- @return string The string representation of the AIBiasModification object.
function AIBiasModification:GetEditorView()
	if self.BiasId and self.BiasId ~= "" then
		if self.Effect == "modify" then
			return string.format("%s %+d%% to %s for %d turns", self.BiasId, self.Value, self.ApplyTo, self.Period)
		elseif self.Effect == "priority" then
			return string.format("Make %s Priority to %s for %d turns", self.BiasId, self.ApplyTo, self.Period)
		elseif self.Effect == "disable" then
			return string.format("Disable %s for %s for %d turns", self.BiasId, self.ApplyTo, self.Period)
		end		
	end
	return self.class
end

DefineClass.AIBiasObj = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "BiasId", name = "Bias Id", editor = "combo", default = false, items = AIBiasCombo },
		{ id = "Weight", editor = "number", default = 100, },
		{ id = "Priority", editor = "bool", default = false, },
		{ id = "OnActivationBiases", name = "OnActivation Biases", editor = "nested_list", default = false, base_class = "AIBiasModification", inclusive = true, },
	},
}

MapVar("g_AIBiases", {})

---
--- Activates the AIBiasObj and applies any OnActivation biases to the specified unit or the unit's team.
---
--- This function is called when the AIBiasObj is activated. It iterates through the OnActivationBiases
--- property of the AIBiasObj and applies the specified biases to the unit or the unit's team. The biases
--- are stored in the global g_AIBiases table, with the bias ID as the key and a table of bias modifications
--- as the value. The bias modifications are added to the appropriate table (unit or team) and include
--- the end turn, value, disable, and priority properties.
---
--- @param unit table The unit to which the biases should be applied.
---
function AIBiasObj:OnActivate(unit)
	for _, mod in ipairs(self.OnActivationBiases or empty_table) do
		local id = mod.BiasId
		if id then
			local bias = g_AIBiases[id] or {}
			g_AIBiases[id] = bias

			local list 
			if mod.ApplyTo == "Self" then
				list = bias[unit] or {}
				bias[unit] = list
			else
				list = bias[unit.team] or {}
				bias[unit.team] = list
			end
			list[#list + 1] = { 
				end_turn = g_Combat.current_turn + mod.Period, 
				value = mod.Value,
				disable = mod.Effect == "disable",
				priority = mod.Effect == "priority",
			}
		end
	end
end

---
--- Updates the global `g_AIBiases` table by iterating through the biases and removing any expired biases.
---
--- This function is called to update the `g_AIBiases` table, which stores the AI biases for units and teams.
--- It iterates through the table and for each bias, it removes any biases that have expired (i.e. their `end_turn`
--- value is less than the current turn). It also calculates the total value of the remaining biases and sets the
--- `disable` and `priority` flags based on the individual bias properties.
---
--- @function AIUpdateBiases
--- @return nil
function AIUpdateBiases()
	for id, item_mods in pairs(g_AIBiases) do
		for obj, mods in pairs(item_mods) do
			local total = 0
			mods.disable = false
			mods.priority = false
			for i = #mods, 1, -1 do
				if mods[i].end_turn < g_Combat.current_turn then
					table.remove(mods, i)
				else
					total = total + mods[i].value
					mods.disable = mods.disable or mods[i].disable
					mods.priority = mods.priority or mods[i].priority
				end
			end
			mods.total = total
		end
	end
end

---
--- Calculates the AI bias for a given unit or team.
---
--- This function takes an ID and a unit, and returns the weight modifier, disable flag, and priority flag for the AI bias.
--- It looks up the bias modifiers in the `g_AIBiases` table, and combines the total values, disable flags, and priority flags for the unit and its team.
--- The weight modifier is the sum of the individual bias values, and the disable and priority flags are set if any of the individual biases have those flags set.
---
--- @param id string The ID of the bias to look up
--- @param unit table The unit to calculate the bias for
--- @return number The weight modifier for the AI bias
--- @return boolean Whether the AI bias should disable the unit
--- @return boolean Whether the AI bias should give the unit priority
---
function AIGetBias(id, unit)
	local weight_mod, disable, priority = 100, false, false

	if id and id ~= "" then
		local mods = g_AIBiases[id] or empty_table
		if mods[unit] then 
			weight_mod = weight_mod + mods[unit].total 
			disable = disable or mods[unit].disable
			priority = priority or mods[unit].priority
		end
		if mods[unit.team] then 
			weight_mod = weight_mod + mods[unit.team].total
			disable = disable or mods[unit.team].disable
			priority = priority or mods[unit.team].priority
		end
	end
	
	disable = disable or (weight_mod <= 0)	
	return weight_mod, disable, priority
end

---
--- Calculates the archetype for a unit based on its current HP percentage.
---
--- If the unit's current HP percentage is below the specified threshold, the function will return the provided alternative archetype.
---
--- @param unit table The unit to calculate the archetype for
--- @param alt_archetype string The alternative archetype to use if the unit's HP is below the threshold
--- @param threshold number The HP percentage threshold to trigger the alternative archetype
--- @return string The calculated archetype for the unit
---
function AIAltArchetypeBelowHpPercent(unit, alt_archetype, threshold)
	local archetype = unit.archetype
	if MulDivRound(unit.HitPoints, 100, unit.MaxHitPoints) < threshold then
		archetype = alt_archetype
	end
	return archetype
end

---
--- This function calculates the archetype for a unit based on the number of allied units that have died.
---
--- If the number of allied units that have died exceeds the specified count, the function will return the provided alternative archetype.
---
--- @param unit table The unit to calculate the archetype for
--- @param alt_archetype string The alternative archetype to use if the number of allied deaths exceeds the threshold
--- @param count number The threshold number of allied deaths to trigger the alternative archetype
--- @return string The calculated archetype for the unit
---
function AIAltArchetypeOnAllyDeath(unit, alt_archetype, count)
	local archetype = unit.archetype
	local last_dead = unit:GetEffectValue("aa_num_team_dead") or 0
	local dead = 0
	count = count or 1
	
	for _, other in ipairs(unit.team and unit.team.units) do
		dead = dead + 1
	end
	
	if dead >= last_dead + count then
		unit:SetEffectValue("aa_num_team_dead", dead)
		archetype = alt_archetype
	end
	return archetype
end

---
--- This function calculates the archetype for a unit based on the number of enemy units that have died.
---
--- If the number of enemy units that have died is the same as the last time this function was called, the function will return the provided alternative archetype.
---
--- @param unit table The unit to calculate the archetype for
--- @param alt_archetype string The alternative archetype to use if the number of enemy deaths is the same as the last time
--- @return string The calculated archetype for the unit
---
function AIAltArchetypeOnNoEnemyDeath(unit, alt_archetype)
	local archetype = unit.archetype
	local last_dead = unit:GetEffectValue("aa_num_dead_enemies") or 0
	local dead = 0
	local unit_team = unit.team
	if unit_team then
		for _, team in ipairs(g_Teams) do
			if unit_team:IsEnemySide(team) then
				for _, other in ipairs(team.units) do
					if other:IsDead() then
						dead = dead + 1
					end
				end
			end
		end
	end
	unit:SetEffectValue("aa_num_dead_enemies", dead)
	if dead == last_dead then
		archetype = alt_archetype
	end
	return archetype
end