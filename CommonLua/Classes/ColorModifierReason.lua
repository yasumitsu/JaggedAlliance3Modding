ColorModifierReasons = {
	--override this in your project
	--{id = "reason_name", weight = default reason weight number, color = default reason color},
}

MapVar("ColorModifierReasonsData", false)
local table_find = table.find
local SetColorModifier = CObject.SetColorModifier
local GetColorModifier = CObject.GetColorModifier
local clrNoModifier = const.clrNoModifier
local default_color_modifier = RGBA(100, 100, 100, 0)

---
--- Sets a color modifier reason on the specified object.
---
--- @param obj table The object to set the color modifier reason on.
--- @param reason string The reason for the color modifier.
--- @param color? table The color to use for the modifier.
--- @param weight? number The weight of the modifier.
--- @param blend? number The blend factor for the modifier.
--- @param skip_attaches? boolean Whether to skip applying the modifier to attached objects.
---
--- @return void
function SetColorModifierReason(obj, reason, color, weight, blend, skip_attaches)
	assert(reason)
	if not reason then
		return
	end
	local color_value = color
	
	if obj:GetRadius() > 0 then
		local data = ColorModifierReasonsData
		if not data then
			data = {}
			ColorModifierReasonsData = data 
		end
		local mrt = data[obj]
		local orig_color
		if not mrt then
			orig_color = GetColorModifier(obj)
			mrt = { orig_color = orig_color }
			data[obj] = mrt
		end
		
		local rt = ColorModifierReasons
		local idx = table_find(rt, "id", reason)
		local rdata = idx and rt[idx] or false
		
		color = color or rdata and rdata.color or nil
		if not color then
			printf("[WARNING] SetColorModifierReason no color! reason %s, color %s, weight %s", reason, tostring(color), tostring(weight))
			return
		end
		weight = weight or rdata and rdata.weight or const.DefaultColorModWeight
		if not weight then
			printf("[WARNING] SetColorModifierReason no weight! reason %s, color %s, weight %s", reason, tostring(color), tostring(weight))
			return
		end
		
		if blend then
			orig_color = orig_color or mrt.orig_color
			if orig_color ~= clrNoModifier then
				color = InterpolateRGB(orig_color, color, blend, 100)
			end
		end
		local idx = table_find(mrt, "reason", reason)
		local entry = idx and mrt[idx]
		if entry then
			entry.weight = weight
			entry.color = color
		else
			entry = { reason = reason, weight = weight, color = color }
			table.insert(mrt, entry)
		end
		table.stable_sort(mrt, function(a, b)
			return a.weight < b.weight
		end)
		SetColorModifier(obj, mrt[#mrt].color)
	end
	if skip_attaches then
		return
	end
	obj:ForEachAttach(SetColorModifierReason, reason, color_value, weight, blend)
end

---
--- Sets the original color modifier for the specified object.
---
--- @param obj table The object to set the original color modifier for.
--- @param color table The new original color modifier.
--- @param skip_attaches boolean (optional) If true, the function will not recursively set the original color modifier for attached objects.
---
function SetOrigColorModifier(obj, color, skip_attaches)
	local data = ColorModifierReasonsData
	local mrt = data and data[obj]
	if not mrt then
		SetColorModifier(obj, color)
	else
		mrt.orig_color = color
	end
	if skip_attaches then return end
	obj:ForEachAttach(SetOrigColorModifier, color)
end

---
--- Gets the original color modifier for the specified object.
---
--- @param obj table The object to get the original color modifier for.
--- @return table The original color modifier for the object.
---
function GetOrigColorModifier(obj)
	local modifier = GetColorModifier(obj)
	return modifier == default_color_modifier and table.get(ColorModifierReasonsData, obj, "orig_color") or modifier
end

---
--- Validates the color modifier reasons data.
---
function ValidateColorReasons()
	table.validate_map(ColorModifierReasonsData)
end

---
--- Clears the color modifier reason for the specified object.
---
--- @param obj table The object to clear the color modifier reason for.
--- @param reason string The color modifier reason to clear.
--- @param skip_color_change boolean (optional) If true, the function will not update the color modifier of the object.
--- @param skip_attaches boolean (optional) If true, the function will not recursively clear the color modifier reasons for attached objects.
---

function ClearColorModifierReason(obj, reason, skip_color_change, skip_attaches)	
	assert(reason)
	if not reason then
		return
	end
	local data = ColorModifierReasonsData
	local mrt = data and data[obj]
	if mrt then
		if not IsValid(obj) then
			data[obj] = nil
			return
		end
		local idx = table_find(mrt, "reason", reason)
		if not idx then
			return
		end
		local update = idx == #mrt
		table.remove(mrt, idx)
		if #mrt == 0 then
			data[obj] = nil
			DelayedCall(1000, ValidateColorReasons)
			if not next(data) then
				ColorModifierReasonsData = false
			end
		end
		if update and not skip_color_change then
			local active = mrt[#mrt]
			local color = active and active.color or mrt.orig_color or const.clrNoModifier
			SetColorModifier(obj, color)
		end
	end
	if skip_attaches then
		return
	end
	obj:ForEachAttach(ClearColorModifierReason, reason, skip_color_change)
end

---
--- Clears the color modifier reasons for the specified object and its attached objects.
---
--- @param obj table The object to clear the color modifier reasons for.
---
function ClearColorModifierReasons(obj)
	local data = ColorModifierReasonsData
	local mrt = data and data[obj]
	if not mrt then
		return
	end
	if IsValid(obj) then
		SetColorModifier(obj, mrt.orig_color or const.clrNoModifier)
		obj:ForEachAttach(ClearColorModifierReasons)
	end
	data[obj] = nil
end

OnMsg.StartSaveGame = ValidateColorReasons
	
----

MapVar("InvisibleReasons", {}, weak_keys_meta)

local efVisible = const.efVisible

---
--- Sets an invisible reason for the specified object.
---
--- If the object already has invisible reasons, the new reason is added to the existing list.
--- If the object has no invisible reasons, a new entry is created in the `InvisibleReasons` table.
--- When an invisible reason is set, the object's hierarchy enum flags are cleared of the `efVisible` flag.
---
--- @param obj table The object to set the invisible reason for.
--- @param reason string The reason to set as invisible.
---
function SetInvisibleReason(obj, reason)
	local invisible_reasons = InvisibleReasons
	local obj_reasons = invisible_reasons[obj]
	if obj_reasons then
		obj_reasons[reason] = true
		return
	end
	invisible_reasons[obj] = { [reason] = true }
	obj:ClearHierarchyEnumFlags(efVisible)
end

---
--- Clears the invisible reason for the specified object.
---
--- If the object has no invisible reasons, this function does nothing.
--- If the object has multiple invisible reasons, this function removes the specified reason.
--- If the object has only one invisible reason, this function removes the entire entry from the `InvisibleReasons` table and sets the `efVisible` hierarchy enum flag on the object.
---
--- @param obj table The object to clear the invisible reason for.
--- @param reason string The reason to clear as invisible.
---
function ClearInvisibleReason(obj, reason)
	local invisible_reasons = InvisibleReasons
	local obj_reasons = invisible_reasons[obj]
	if not obj_reasons or not obj_reasons[reason] then
		return
	end
	obj_reasons[reason] = nil
	if next(obj_reasons) then
		return
	end
	invisible_reasons[obj] = nil
	obj:SetHierarchyEnumFlags(efVisible)
end

---
--- Clears all invisible reasons for the specified object.
---
--- If the object has no invisible reasons, this function does nothing.
--- If the object has any invisible reasons, this function removes the entire entry from the `InvisibleReasons` table and sets the `efVisible` hierarchy enum flag on the object.
---
--- @param obj table The object to clear all invisible reasons for.
---
function ClearInvisibleReasons(obj)
	local invisible_reasons = InvisibleReasons
	if not invisible_reasons[obj] then
		return
	end
	invisible_reasons[obj] = nil
	obj:SetHierarchyEnumFlags(efVisible)
end

----