AppendClass.Debris = {
	__parents = { "GameDynamicSpawnObject" },
}

--- Gets the dynamic data for the debris object.
---
--- @param data table A table to store the dynamic data in.
function Debris:GetDynamicData(data)
	data.opacity = self.opacity
	local fade_time = GameTime() - self.time_fade_away_start
	data.time_fade_away = (fade_time > self.time_fade_away) and 0 or (self.time_fade_away - fade_time)
	data.time_disappear = self.time_disappear
	
	local p = self.spawning_obj
	if p then
		data.parent_handle = p.handle
	end
end

--- Sets the dynamic data for the debris object.
---
--- @param data table A table containing the dynamic data to set.
--- @field data.opacity number The opacity of the debris object.
--- @field data.time_fade_away number The time in seconds for the debris object to fade away.
--- @field data.time_disappear number The time in seconds for the debris object to disappear.
--- @field data.parent_handle number The handle of the parent object of the debris object.
function Debris:SetDynamicData(data)
	self.opacity = data.opacity
	self:StartPhase("FadeAway", data.time_fade_away, data.time_disappear)
	
	local ph = data.parent_handle
	if ph then
		local p = HandleToObject[ph]
		self.spawning_obj = p
		self:SetColorization(p)
	end
end

--[[
--return in case of floating debris
function Debris:ShouldBeVisibileWhileFading()
	return not not GetPassSlab(self)
end
]]

local prev_func = Debris.enum_obj
--- Checks if the given object should be enumerated, excluding TreeTop objects.
---
--- @param obj any The object to check.
--- @param ... any Additional arguments passed to the previous enum_obj function.
--- @return boolean True if the object should be enumerated, false otherwise.
function Debris.enum_obj(obj, ...)
	if prev_func(obj, ...) and not IsKindOf(obj, "TreeTop") then
		return true
	end
end