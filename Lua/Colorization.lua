MapVar("g_Colorization", {}, weak_keys_meta)

---
--- Adds a color modification to the specified object.
---
--- @param obj table The object to apply the color modification to.
--- @param color_mod table The color modification to apply.
--- @param reason string The reason for applying the color modification.
---
function AddColorization(obj, color_mod, reason)
	local curr_colorization = g_Colorization[obj]
	if not curr_colorization then
		curr_colorization = { original = obj:GetColorModifier(), modifiers = {} }
		g_Colorization[obj] = curr_colorization
	end
	
	curr_colorization.modifiers[reason] = color_mod
	local active_mod
	for _, mod in sorted_pairs(curr_colorization.modifiers) do
		active_mod = mod
	end
	if active_mod then
		obj:SetColorModifier(active_mod)
	end
end

---
--- Removes a color modification from the specified object.
---
--- @param obj table The object to remove the color modification from.
--- @param reason string The reason for removing the color modification.
---
function RemoveColorization(obj, reason)
	local curr_colorization = g_Colorization[obj]
	if not curr_colorization or not curr_colorization.modifiers then
		return
	end
	
	curr_colorization.modifiers[reason] = nil
	local active_mod
	for _, mod in sorted_pairs(curr_colorization.modifiers) do
		active_mod = mod
	end
	if active_mod then
		obj:SetColorModifier(active_mod)
	else
		obj:SetColorModifier(curr_colorization.original)
		g_Colorization[obj] = nil
	end
end