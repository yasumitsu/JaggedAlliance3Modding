---
--- Gets the spot offset for an object.
---
--- @param obj table The object to get the spot offset for.
--- @param name string The name of the spot.
--- @param idx number The index of the spot (optional).
--- @param state string The state of the object (optional).
--- @param phase number The phase of the object (optional).
--- @return number, number, number, string The x, y, z offsets of the spot, and an error message if any.
---
function GetSpotOffset(obj, name, idx, state, phase)
	assert(obj)
	if not IsValid(obj) then
		return 0, 0, 0, "obj"
	end
	idx = idx or obj:GetSpotBeginIndex(name) or -1
	if idx == -1 then
		return 0, 0, 0, "spot"
	end
	state = state or "idle"
	phase = phase or 0
	local x, y, z = GetEntitySpotPos(obj, state, phase, idx, idx, true):xyz()
	local s = obj:GetWorldScale()
	if s ~= 100 then
		x, y, z = x * s / 100, y * s / 100, z * s / 100
	end
	return x, y, z
end

---
--- Gets the absolute difference between the visual angle of the attached object and the given local angle.
---
--- @param attach table The attached object.
--- @param local_angle number The local angle to compare against.
--- @return number The absolute angle difference.
---
function GetLocalAngleDiff(attach, local_angle)
	return abs(AngleDiff(attach:GetVisualAngleLocal(), local_angle))
end

---
--- Calculates the time required for an attached object to rotate to a given local angle at the specified speed.
---
--- @param attach table The attached object.
--- @param local_angle number The local angle to rotate to.
--- @param speed number The rotation speed.
--- @return number The time in milliseconds required to rotate to the given local angle.
---
function GetLocalRotationTime(attach, local_angle, speed)
	return MulDivRound(1000, GetLocalAngleDiff(attach, local_angle), speed)
end

---
--- Gets the absolute difference between the given angle and the object's angle.
---
--- @param obj table The object to get the angle difference for.
--- @param angle number The angle to compare against.
--- @return number The absolute angle difference.
---
function GetLocalAngle(obj, angle)
	return AngleDiff(angle, obj:GetAngle())
end

----

DefineClass.CompositeBodyPart = {
	__parents = { "ComponentAnim", "ComponentAttach", "ColorizableObject" },
	flags = { gofSyncState = true, efWalkable = false, efApplyToGrids = false, efCollision = false, efSelectable = true },
}

---
--- Gets the name of the CompositeBody part that this object is attached to.
---
--- @return string The name of the CompositeBody part, or nil if this object is not attached to a CompositeBody.
---
function CompositeBodyPart:GetName()
	local parent = self:GetParent()
	while IsValid(parent) do
		if IsKindOf(parent, "CompositeBody") then
			for name, part in pairs(parent.attached_parts) do
				if part == self then
					return name
				end
			end
			return
		else
			parent = parent:GetParent()
		end
	end
end

local function RecomposeBody(obj)
	for name, part in pairs(obj.attached_parts) do
		if part ~= obj then
			obj:RemoveBodyPart(part, name)
		end
	end
	obj.attached_parts = nil
	obj:ComposeBodyParts()
end
		
local function EditorRecomposeBodiesOnMap(obj, root, prop_id, ged)
	if IsValid(obj) then
		RecomposeBody(obj)
	elseif obj.object_class then
		MapForEach("map", obj.object_class, RecomposeBody)
	end
end

local function get_body_parts_count(self)
	local class_name = self.id
	local class = g_Classes[class_name] or empty_table
	local target = self.composite_part_target or class.composite_part_target or class_name
	local composite_part_groups = self.composite_part_groups or class.composite_part_groups or { class_name }
	local part_presets = Presets.CompositeBodyPreset
	local count = 0
	for _, part_name in ipairs(self.composite_part_names or class.composite_part_names) do
		for _, part_group in ipairs(composite_part_groups) do
			for _, part_preset in ipairs(part_presets[part_group] or empty_table) do
				if (not target or part_preset.Target == target) and (part_preset.Parts or empty_table)[part_name] then
					count = count + 1
				end
			end
		end
	end
	return count
end

-- Composite bodies change the entity, scale and colors of the unit."
DefineClass.CompositeBody = {
	__parents = { "Object", "CompositeBodyPart" },

	properties = {
		{ category = "Composite Body", id = "recompose",                name = "Recompose", editor = "buttons", default = false, template = true, buttons = { { name = "Recompose", func = function(...) return EditorRecomposeBodiesOnMap(...) end, } } },
		{ category = "Composite Body", id = "composite_part_names",     name = "Parts", editor = "string_list", template = true, help = "Composite body parts. Each body preset may cover one or more parts. Each part may have another part as a parent and a custom attach spot.", body_part_match = true },
		{ category = "Composite Body", id = "composite_part_main",      name = "Main Part", editor = "choice", items = PropGetter("composite_part_names"), template = true, help = "Main body part to be applied directly to the composite object." },
		{ category = "Composite Body", id = "composite_part_target",    name = "Target", editor = "text", template = true, help = "Will match composite body presets having the same target. If not specified, the class name is used.", body_part_match = true },
		{ category = "Composite Body", id = "composite_part_groups",    name = "Groups", editor = "string_list", items = PresetGroupsCombo("CompositeBodyPreset"), template = true, help = "Will match composite body presets from those groups. If not specified, the class name is used as a group name.", body_part_match = true },
		{ category = "Composite Body", id = "CompositePartCount",       name = "Parts Found", editor = "number", template = true, default = 0, dont_save = true, read_only = 0, getter = get_body_parts_count },
		{ category = "Composite Body", id = "composite_part_parent",    name = "Parent", editor = "prop_table", read_only = true, template = true, help = "Defines custom parent for each body part." },
		{ category = "Composite Body", id = "composite_part_spots",     name = "Spots", editor = "prop_table", read_only = true, template = true, help = "Defines custom attach spots for each body part." },
		{ category = "Composite Body", id = "cycle_colors",             name = "Cycle Colors", editor = "bool", default = false, template = true, help = "If you can cycle through the composite body colors during construction.", },
	},

	flags = { gofSyncState = false, gofPropagateState = true },
	
	composite_seed = false,
	colorization_offset = 0,
	composite_part_target = false,
	composite_part_names = { "Body" },
	composite_part_spots = false,
	composite_part_parent = false,
	composite_part_main = "Body",
	composite_part_groups = false,
	
	attached_parts = false,
	override_parts = false,
	override_parts_spot = false,
	
	InitBodyParts = empty_func,
	SetAutoAttachMode = empty_func,
	ChangeEntityDisabled = empty_func,
}

---
--- Composes the body parts of the CompositeBody object.
---
--- This function is a cheat function that calls the `ComposeBodyParts()` function
--- to compose the body parts of the CompositeBody object.
---
--- @param self CompositeBody The CompositeBody object to compose.
---
function CompositeBody:CheatCompose()
	self:ComposeBodyParts()
end

local props = CompositeBody.properties
for i=1,10 do
	local category = "Composite Body Hierarchy"
	local function no_edit(self)
		local names = self:GetProperty("composite_part_names") or empty_table
		local name = names[i]
		return not name or name == self:GetProperty("composite_part_main")
	end
	local function GetPartName(self)
		local names = self:GetProperty("composite_part_names")
		return names[i] or ""
	end
	local function GetSpotName(self)
		local name = GetPartName(self)
		return name .. " Spot"
	end
	local function GetParentName(self)
		local name = GetPartName(self)
		return name .. " Parent"
	end
	local spot_id = "composite_part_spot_" .. i
	local parent_id = "composite_part_parent_" .. i
	local function getter(self, prop_id)
		local target_id
		if prop_id == spot_id then
			target_id = "composite_part_spots"
		elseif prop_id == parent_id then
			target_id = "composite_part_parent"
		else
			return ""
		end
		local name = GetPartName(self)
		local map = self:GetProperty(target_id)
		return map and map[name] or ""
	end
	local function setter(self, value, prop_id)
		local target_id
		if prop_id == spot_id then
			target_id = "composite_part_spots"
		elseif prop_id == parent_id then
			target_id = "composite_part_parent"
		else
			return
		end
		local name = GetPartName(self)
		local map = self:GetProperty(target_id) or empty_table
		map = table.raw_copy(map)
		map[name] = (value or "") ~= "" and value or nil
		rawset(self, target_id, map)
	end
	local function GetParentItems(self)
		local names = self:GetProperty("composite_part_names") or empty_table
		if names[i] then
			names = table.icopy(names)
			table.remove_value(names, names[i])
		end
		return names, return_true
	end
	table.iappend(props, {
		{ category = category, id = spot_id, name = GetSpotName, editor = "text", default = "", dont_save = true, getter = getter, setter = setter, no_edit = no_edit, template = true },
		{ category = category, id = parent_id, name = GetParentName, editor = "choice", default = "", items = GetParentItems, dont_save = true, getter = getter, setter = setter, no_edit = no_edit, template = true },
	})
	CompositeBody["Get" .. spot_id] = function(self)
		return getter(self, spot_id)
	end
	CompositeBody["Get" .. parent_id] = function(self)
		return getter(self, parent_id)
	end
	CompositeBody["Set" .. spot_id] = function(self, value)
		return setter(self, spot_id, value)
	end
	CompositeBody["Set" .. parent_id] = function(self, value)
		return setter(self, parent_id, value)
	end
end

--- Allows garbage collection of `CompositeBody` objects which otherwise have a non-weak reference to themselves.
function CompositeBody:Done()
	-- allow garbage collection of CompositeBody objects which otherwise have a non-weak reference to themselves
	self.attached_parts = nil
	self.override_parts = nil
end

--- Returns the attached part with the given name.
---
--- @param name string The name of the part to retrieve.
--- @return table|nil The attached part, or nil if not found.
function CompositeBody:GetPart(name)
	local parts = self.attached_parts
	return parts and parts[name]
end

--- Returns the name of the given part in the CompositeBody.
---
--- @param part_to_find table The part to find the name for.
--- @return string|nil The name of the part, or nil if not found.
function CompositeBody:GetPartName(part_to_find)
	for name, part in pairs(self.attached_parts) do
		if part == part_to_find then
			return name
		end
	end
end

--- Iterates over all the body parts attached to the CompositeBody instance and calls the provided function for each part.
---
--- @param func function The function to call for each attached body part.
--- @param ... any Additional arguments to pass to the function.
function CompositeBody:ForEachBodyPart(func, ...)
	local attached_parts = self.attached_parts or empty_table
	for _, name in ipairs(self.composite_part_names) do
		local part = attached_parts[name]
		if part then
			func(part, self, ...)
		end
	end
end

--- Updates the entity associated with the CompositeBody instance by composing the attached body parts.
---
--- @return boolean True if the entity was successfully updated, false otherwise.
function CompositeBody:UpdateEntity()
	return self:ComposeBodyParts()
end

local function ResolveCompositeMainEntity(classdef)
	if not classdef then return end
	local composite_part_groups = classdef.composite_part_groups
	local composite_part_group = composite_part_groups and composite_part_groups[1] or classdef.class
	local part_presets = table.get(Presets, "CompositeBodyPreset", composite_part_group)
	if next(part_presets) then
		local composite_part_target = classdef.composite_part_target
		local composite_part_main = classdef.composite_part_main or "Body"
		for _, part_preset in ipairs(part_presets) do
			if not composite_part_target or composite_part_target == part_preset.Target then
				if (part_preset.Parts or empty_table)[composite_part_main] then
					return part_preset.Entity
				end
			end
		end
	end
	return classdef.entity or classdef.class
end

--- Resolves the template entity associated with the current object.
---
--- @param self table The current object.
--- @return Entity|nil The resolved template entity, or `nil` if not found.
function ResolveTemplateEntity(self)
	local entity = IsValid(self) and self:GetEntity()
	if IsValidEntity(entity) then
		return entity
	end
	local class = self.id or self.class
	local classdef = g_Classes[class]
	if not classdef then return end
	entity = ResolveCompositeMainEntity(classdef)
	return IsValidEntity(entity) and entity
end

--- Resolves the template entity associated with the current object.
---
--- @param self table The current object.
--- @return Entity|nil The resolved template entity, or `nil` if not found.
function TemplateSpotItems(self)
	local entity = ResolveTemplateEntity(self)
	if not entity then return {} end
	local spots = {{ value = false, text = "" }}
	local seen = {}
	local spbeg, spend = GetAllSpots(entity)
	for spot = spbeg, spend do
		local name = GetSpotName(entity, spot)
		if not seen[name] then
			seen[name] = true
			spots[#spots + 1] = { value = name, text = name }
		end
	end
	table.sortby_field(spots, "text")
	return spots
end

--- Collects the best matched body presets for the remaining parts without equipment.
---
--- @param self table The current CompositeBody object.
--- @param part_to_preset table A table to store the matched presets for each part.
--- @param seed number The seed to use for random generation.
--- @return number The updated seed.
function CompositeBody:CollectBodyParts(part_to_preset, seed)
	local target = self.composite_part_target or self.class
	local composite_part_groups = self.composite_part_groups or { self.class }
	local part_presets = Presets.CompositeBodyPreset
	for _, part_name in ipairs(self.composite_part_names) do
		if not part_to_preset[part_name] then
			local matched_preset, matched_presets
			for _, part_group in ipairs(composite_part_groups) do
				for _, part_preset in ipairs(part_presets[part_group]) do
					if (not target or part_preset.Target == target) and (part_preset.Parts or empty_table)[part_name] then
						local matched = true
						for _, filter in ipairs(part_preset.Filters) do
							if not filter:Match(self) then
								matched = false
								break
							end
						end
						if matched then
							if not matched_preset or matched_preset.ZOrder < part_preset.ZOrder then
								matched_preset = part_preset
								matched_presets = nil
							elseif matched_preset.ZOrder == part_preset.ZOrder then
								if matched_presets then
									matched_presets[#matched_presets + 1] = part_preset
								else
									matched_presets = { matched_preset, part_preset }
								end
							end
						end
					end
				end
			end
			if matched_presets then
				seed = self:ComposeBodyRand(seed)
				matched_preset = table.weighted_rand(matched_presets, "Weight", seed)
			end
			if matched_preset then
				part_to_preset[part_name] = matched_preset
			end
		end
	end
	return seed
end

---
--- Copies the construction-related dynamic data from the current CompositeBody object to the provided copy_data table.
---
--- @param self table The current CompositeBody object.
--- @param copy_data table The table to copy the dynamic data to.
---
function CompositeBody:GetConstructionCopyObjectData(copy_data)
	table.rawset_values(copy_data, self,         "composite_seed", "colorization_offset")
end

---
--- Copies the construction-related dynamic data from the current CompositeBody object to the provided cursor_data table.
---
--- @param self table The current CompositeBody object.
--- @param controller table The construction controller object.
--- @param cursor_data table The table to copy the dynamic data to.
---
function CompositeBody:GetConstructionCursorDynamicData(controller, cursor_data)
	table.rawset_values(cursor_data, controller, "composite_seed", "colorization_offset")
end

---
--- Copies the construction-related dynamic data from the current CompositeBody object to the provided controller_data table.
---
--- @param self table The current CompositeBody object.
--- @param controller_data table The table to copy the dynamic data to.
---
function CompositeBody:GetConstructionControllerDynamicData(controller_data)
	table.rawset_values(controller_data, self,   "composite_seed", "colorization_offset")
end

function OnMsg.GatherConstructionInitData(construction_init_data)
	rawset(construction_init_data, "composite_seed", true)
	rawset(construction_init_data, "colorization_offset", true)
end

---
--- Generates a random seed value for the CompositeBody object, optionally using the provided seed value.
---
--- @param self table The current CompositeBody object.
--- @param seed number (optional) The seed value to use. If not provided, a new seed value will be generated.
--- @return number The generated or provided seed value.
---
function CompositeBody:ComposeBodyRand(seed, ...)
	seed = seed or self.composite_seed or self:RandSeed("Body")
	self.composite_seed = self.composite_seed or seed
	return BraidRandom(seed, ...)
end

---
--- Returns the target for the part's FX.
---
--- @param self table The current CompositeBody object.
--- @param part table The part object.
--- @return table The target for the part's FX.
---
function CompositeBody:GetPartFXTarget(part)
	return self
end

---
--- Composes the body parts of the CompositeBody object based on the provided seed value.
---
--- @param self table The current CompositeBody object.
--- @param seed number The seed value to use for composing the body parts.
--- @return boolean Whether the body parts were changed.
---
function CompositeBody:ComposeBodyParts(seed)
	if self:ChangeEntityDisabled() then
		return
	end
	local part_to_preset = { }
	-- collect the best matched body presets for the remaining parts without equipment
	seed = self:CollectBodyParts(part_to_preset, seed) or seed
	
	-- apply the main body entity (all others are attached to this one)
	local main_name = self.composite_part_main	
	local main_preset = main_name and part_to_preset[main_name]
	if not main_preset and not IsValidEntity(self:GetEntity()) then
		return
	end
	local applied_presets = {}
	local changed
	if main_preset then
		local changed_i, seed_i = self:ApplyBodyPart(self, main_preset, main_name, seed)
		assert(IsValidEntity(self:GetEntity()))
		changed = changed_i or changed
		seed = seed_i or seed
		applied_presets = { [main_preset] = true }
	end

	local last_part_class, part_def
	
	local override_parts = self.override_parts or empty_table
	-- apply all the remaining as attaches (removing the unused ones from the previous procedure)
	local attached_parts = self.attached_parts or {}
	attached_parts[main_name] = self
	self.attached_parts = attached_parts
	for _, part_name in ipairs(self.composite_part_names) do
		if part_name == main_name then
			goto continue
		end
		local part_obj = attached_parts[part_name]
		--body part overriding
		local override = override_parts[part_name]
		if override then
			if override ~= part_obj then
				if part_obj then
					self:RemoveBodyPart(part_obj, part_name)
				end
				attached_parts[part_name] = override
				local parent = self
				if override:GetParent() ~= parent then
					local spot = self.override_parts_spot and self.override_parts_spot[part_name]
					spot = spot or self.composite_part_spots[part_name]
					local spot_idx = spot and parent:GetSpotBeginIndex(spot)
					parent:Attach(override, spot_idx)
				end
			end
			goto continue
		end
		--preset search
		local preset = part_to_preset[part_name]
		if preset and not applied_presets[preset] then
			applied_presets[preset] = true
			if preset.Entity ~= "" then
				local part_class = preset.PartClass or "CompositeBodyPart"
				if not IsValid(part_obj) or part_obj.class ~= part_class then
					if last_part_class ~= part_class then
						last_part_class = part_class
						part_def = g_Classes[part_class]
						assert(part_def)
						part_def = part_def or CompositeBodyPart
					end
					DoneObject(part_obj)
					part_obj = part_def:new()
					attached_parts[part_name] = part_obj
					changed = true
				end
				local changed_i, seed_i = self:ApplyBodyPart(part_obj, preset, part_name, seed)
				changed = changed_i or changed
				seed = seed_i or seed 
				goto continue
			end
		end
		-- 1) body part preset not found
		-- 2) part already covered, should be removed
		-- 3) part used to specify a missing part
		if part_obj then
			attached_parts[part_name] = nil
			self:RemoveBodyPart(part_obj, part_name)
		end
		::continue::
	end
	if changed then
		self:NetUpdateHash("BodyChanged", seed)
	end
	self:InitBodyParts()
	return changed
end

local def_scale = range(100, 100)

---
--- Changes the entity of a body part in a composite body.
---
--- @param part CompositeBodyPart The body part to change the entity for.
--- @param preset table The preset containing the entity information.
--- @param name string The name of the body part.
--- @return boolean Whether the entity was changed.
function CompositeBody:ChangeBodyPartEntity(part, preset, name)
	local entity = preset.Entity
	if (preset.AffectedBy or "") ~= "" and (preset.EntityWhenAffected or "") ~= "" and self.attached_parts[preset.AffectedBy] then
		entity = preset.EntityWhenAffected
	end
	
	local current_entity = part:GetEntity()
	if current_entity == entity or not IsValidEntity(entity) then
		return
	end
	if current_entity ~= "" then
		PlayFX("ApplyBodyPart", "end", part, self:GetPartFXTarget(part))
	end
	local state = part:GetGameFlags(const.gofSyncState) == 0 and EntityStates.idle or nil
	part:ChangeEntity(entity, state)
	return true
end

---
--- Changes the scale of a body part in a composite body.
---
--- @param part CompositeBodyPart The body part to change the scale for.
--- @param name string The name of the body part.
--- @param scale number The new scale value.
--- @return boolean Whether the scale was changed.
function CompositeBody:ChangeBodyPartScale(part, name, scale)
	if part:GetScale() ~= scale then
		part:SetScale(scale)
		return true
	end
end

---
--- Applies a body part to a composite body.
---
--- @param part CompositeBodyPart The body part to apply.
--- @param preset table The preset containing the body part information.
--- @param name string The name of the body part.
--- @param seed number The random seed to use for generating values.
--- @return boolean Whether the body part was changed.
--- @return number The updated random seed.
function CompositeBody:ApplyBodyPart(part, preset, name, seed)
	-- entity
	local changed_entity = self:ChangeBodyPartEntity(part, preset, name)
	local changed = changed_entity
	-- mirrored
	if part:GetMirrored() ~= preset.Mirrored then
		part:SetMirrored(preset.Mirrored)
		changed = true
	end
	-- scale
	local scale = 100
	local scale_range = preset.Scale
	if scale_range ~= def_scale then
		local scale_min, scale_max = scale_range.from, scale_range.to
		if scale_min == scale_max then
			scale = scale_min
		else
			scale, seed = self:ComposeBodyRand(seed, scale_min, scale_max)
		end
	end
	if self:ChangeBodyPartScale(part, name, scale) then
		changed = true
	end
	-- color
	seed = self:ColorizeBodyPart(part, preset, name, seed) or seed
	-- attach
	if part ~= self then
		local axis = preset.Axis
		if axis and part:GetAxisLocal() ~= axis then
			part:SetAxis(axis)
			changed = true
		end
		local angle = preset.Angle
		if angle and part:GetAngleLocal() ~= angle then
			part:SetAngle(angle)
			changed = true
		end
		local spot_name = preset.AttachSpot or ""
		if spot_name == "" then
			local spots = self.composite_part_spots
			spot_name = spots and spots[name] or ""
			if spot_name == "" then
				spot_name = "Origin"
			end
		end
		local sync_state = preset.SyncState
		if sync_state == "auto" then
			sync_state = spot_name == "Origin"
		end
		if not sync_state then
			part:ClearGameFlags(const.gofSyncState)
		else
			part:SetGameFlags(const.gofSyncState)
		end
		local prev_parent, prev_spot_idx = part:GetParent(), part:GetAttachSpot()
		local parents = self.composite_part_parent
		local parent_part = preset.Parent or parents and parents[name] or ""
		local parent = parent_part ~= "" and self.attached_parts[parent_part] or self
		local spot_idx = parent:GetSpotBeginIndex(spot_name)
		assert(spot_idx ~= -1, string.format("Failed to attach body part %s to spot %s of %s with state %s", name, spot_name, parent:GetEntity(), parent:GetStateText()))
		if prev_parent ~= parent or prev_spot_idx ~= spot_idx then
			parent:Attach(part, spot_idx)
			changed = true
		end
		local attach_offset = preset.AttachOffset or point30
		local attach_axis = preset.AttachAxis or axis_z
		local attach_angle = preset.AttachAngle or 0
		if attach_offset ~= part:GetAttachOffset() or attach_axis ~= part:GetAttachAxis() or attach_angle ~= part:GetAttachAngle() then
			part:SetAttachOffset(attach_offset)
			part:SetAttachAxis(attach_axis)
			part:SetAttachAngle(attach_angle)
			changed = true
		end
	end
	
	local changed_fx
	local fx_actor_class = (preset.FxActor or "") ~= "" and preset.FxActor or nil
	local current_fx_actor = rawget(part, "fx_actor_class") -- avoid clearing class fx actor with the default FxActor value
	if current_fx_actor ~= fx_actor_class then
		if current_fx_actor then
			PlayFX("ApplyBodyPart", "end", part, self:GetPartFXTarget(part))
		end
		part.fx_actor_class = fx_actor_class
		changed_fx = true
	end

	if changed_fx or changed_entity then
		PlayFX("ApplyBodyPart", "start", part, self:GetPartFXTarget(part))
	end
	
	return changed, seed
end

---
--- Colorizes a body part of a composite body based on the preset and seed.
---
--- @param part CompositeBodyPart The body part to colorize.
--- @param preset table The preset containing the color information.
--- @param name string The name of the body part.
--- @param seed number The seed to use for randomization.
--- @return number The updated seed.
function CompositeBody:ColorizeBodyPart(part, preset, name, seed)
	local inherit_from = preset.ColorInherit
	local colorization = inherit_from ~= "" and table.get(self.attached_parts, inherit_from)
	if not colorization then
		seed = self:ComposeBodyRand(seed)
		local colors = preset.Colors or empty_table
		local idx
		colorization, idx = table.weighted_rand(colors, "Weight", seed)
		local offset = self.colorization_offset
		if idx and offset then
			idx = ((idx + offset - 1) % #colors) + 1
			colorization = colors[idx]
		end
	end
	part:SetColorization(colorization)
	return seed
end

---
--- Sets the colorization offset for the composite body.
---
--- @param offset number The colorization offset to set.
function CompositeBody:SetColorizationOffset(offset)
	local part_to_preset = {}
	local seed = self.composite_seed
	self:CollectBodyParts(part_to_preset, seed)
	local attached_parts = self.attached_parts
	self.colorization_offset = offset
	for _, part_name in ipairs(self.composite_part_names) do
		local preset = part_to_preset[part_name]
		if preset then
			local part = attached_parts[part_name]
			self:ColorizeBodyPart(part, preset, part_name, seed, offset)
		end
	end
end

---
--- Removes a body part from the composite body.
---
--- @param part CompositeBodyPart The body part to remove.
--- @param name string The name of the body part.
function CompositeBody:RemoveBodyPart(part, name)
	DoneObject(part)
end

---
--- Overrides a body part in the composite body.
---
--- @param name string The name of the body part to override.
--- @param obj CompositeBodyPart|string The new body part to use, or the name of an entity to create a new CompositeBodyPart from.
--- @param spot number The spot index to place the new body part at.
--- @return CompositeBodyPart|nil The overridden body part, or nil if the override was removed.
function CompositeBody:OverridePart(name, obj, spot)
	if not IsValid(self) or IsBeingDestructed(self) then
		return
	end
	assert(table.find(self.composite_part_names, name), "Invalid part name")
	if type(obj) == "string" and IsValidEntity(obj) then
		local entity = obj
		obj = CompositeBodyPart:new()
		obj:ChangeEntity(entity)
		AutoAttachObjects(obj)
	end
	if IsValid(obj) then
		self.override_parts = self.override_parts or {}
		assert(not self.override_parts[name], "Part already overridden")
		self.override_parts[name] = obj
		self.override_parts_spot = self.override_parts_spot or {}
		self.override_parts_spot[name] = spot
	elseif self.override_parts then
		obj = self.override_parts[name]
		if self.attached_parts[name] == obj then
			self.attached_parts[name] = nil
		end
		self.override_parts[name] = nil
		self.override_parts_spot[name] = nil
	end
	self:ComposeBodyParts()
	return obj
end

---
--- Removes an overridden body part from the composite body.
---
--- @param name string The name of the body part to remove the override for.
function CompositeBody:RemoveOverridePart(name)
	local part = self:OverridePart(name, false)
	if IsValid(part) then
		self:RemoveBodyPart(part)
	end
end

local composite_body_targets, composite_body_filters, composite_body_parts, composite_body_defs

---
--- Called when a property of the CompositeBody is set in the editor.
---
--- If the property being set is a body part match or body part filter, this function will update the composite body parts accordingly.
---
--- @param prop_id string The ID of the property being set.
--- @param old_value any The previous value of the property.
--- @param ged any The GED object associated with the property.
--- @return any The result of calling the parent class's OnEditorSetProperty method.
function CompositeBody:OnEditorSetProperty(prop_id, old_value, ged)
	local prop_meta = self:GetPropertyMetadata(prop_id) or empty_table
	if prop_meta.body_part_match then
		composite_body_targets = nil
	end
	if prop_meta.body_part_filter then
		self:ComposeBodyParts()
	end
	return Object.OnEditorSetProperty(self, prop_id, old_value, ged)
end

----
-- Editor only code:

local function UpdateItems()
	if composite_body_targets then
		return
	end
	composite_body_filters, composite_body_parts, composite_body_defs = {}, {}, {}
	ClassDescendantsList("CompositeBody", function(class, def)
		local target = def.composite_part_target or class
		
		local filters = composite_body_filters[target] or {}
		for _, prop in ipairs(def:GetProperties()) do
			if prop.body_part_filter then
				filters[prop.id] = filters[prop.id] or prop
			end
		end
		composite_body_filters[target] = filters
		
		local defs = composite_body_defs[target] or {}
		if not defs[class] then
			defs[class] = true
			table.insert(defs, def)
		end
		composite_body_defs[target] = defs
		
		local parts = composite_body_parts[target] or {}
		for _, part in ipairs(def.composite_part_names) do
			table.insert_unique(parts, part)
		end
		composite_body_parts[target] = parts
	end, "")
	composite_body_targets = table.keys2(composite_body_parts, true, "")
end

--- Returns a list of all entity names in the game.
---
--- @return table<string, boolean> A table of entity names, with the values set to true.
function GetBodyPartEntityItems()
	local items = {}
	for entity in pairs(GetAllEntities()) do
		local data = EntityData[entity]
		if data then
			items[#items + 1] = entity
		end
	end
	table.sort(items)
	table.insert(items, 1, "")
	return items
end

---
--- Returns a list of all body part names for the given preset.
---
--- @param preset CompositeBodyPreset The preset to get the body part names for.
--- @return table<string, boolean> A table of body part names, with the values set to true.
function GetBodyPartNameItems(preset)
	UpdateItems()
	return composite_body_parts[preset.Target]
end

---
--- Returns a list of all body part names for the given preset, with an empty string as the first item.
---
--- @param preset CompositeBodyPreset The preset to get the body part names for.
--- @return table<string, boolean> A table of body part names, with the values set to true.
function GetBodyPartNameCombo(preset)
	local items = table.copy(GetBodyPartNameItems(preset) or empty_table)
	table.insert(items, 1, "")
	return items
end

---
--- Returns a list of all composite body target names in the game.
---
--- @return table<string, boolean> A table of composite body target names, with the values set to true.
function GetBodyPartTargetItems(preset)
	UpdateItems()
	return composite_body_targets
end

---
--- Returns a list of all state names for the given entity.
---
--- @param entity string The entity to get the state names for.
--- @return table<string, boolean> A table of state names, with the values set to true.
function EntityStatesCombo(entity, ...)
	entity = entity or ""
	if entity == "" then
		return { ... }
	end
	local anims = GetStates(entity)
	table.sort(anims)
	table.insert(anims, 1, "")
	return anims
end

---
--- Returns a list of all state moment names for the given entity and animation.
---
--- @param entity string The entity to get the state moment names for.
--- @param anim string The animation to get the state moment names for.
--- @return table<string, boolean> A table of state moment names, with the values set to true.
function EntityStateMomentsCombo(entity, anim, ...)
	entity = entity or ""
	anim = anim or ""
	if entity == "" or anim == "" then
		return { ... }
	end
	local moments = GetStateMomentsNames(entity, anim)
	table.insert(moments, 1, "")
	return moments
end

----

DefineClass.CompositeBodyPreset = {
	__parents = { "Preset" },
	properties = {
		{ id = "Target",       name = "Target",        editor = "choice",      default = "",    items = GetBodyPartTargetItems },
		{ id = "Parts",        name = "Covered Parts", editor = "set",         default = false, items = GetBodyPartNameItems },
		{ id = "CustomMatch",  name = "Custom Match",  editor = "bool",        default = false, },
		{ id = "BodiesFound",  name = "Bodies Found",  editor = "text",        default = "", dont_save = true, read_only = 0, lines = 1, max_lines = 3, no_edit = PropChecker("CustomMatch", true) },
		{ id = "Parent",       name = "Parent Part",   editor = "choice",      default = false, items = GetBodyPartNameItems },
		{ id = "Entity",       name = "Entity",        editor = "choice",      default = "",    items = GetBodyPartEntityItems },
		{ id = "PartClass",    name = "Custom Class",  editor = "text",        default = false, translate = false, validate = function(self) return self.PartClass and not g_Classes[self.PartClass] and "Invalid class" end },
		{ id = "AttachSpot",   name = "Attach Spot",   editor = "text",        default = "",    translate = false, help = "Force attach spot" },
		{ id = "Scale",        name = "Scale",         editor = "range",       default = def_scale },
		{ id = "Axis",         name = "Axis",          editor = "point",       default = false, help = "Force a specific axis" },
		{ id = "Angle",        name = "Angle",         editor = "number",      default = false, scale = "deg", min = -180*60, max = 180*60, slider = true, help = "Force a specific angle" },
		{ id = "Mirrored",     name = "Mirrored",      editor = "bool",        default = false },
		{ id = "SyncState",    name = "Sync State",    editor = "choice",      default = "auto", items = {true, false, "auto"}, help = "Force sync state" },
		{ id = "ZOrder",       name = "ZOrder",        editor = "number",      default = 0,     },
		{ id = "Weight",       name = "Weight",        editor = "number",      default = 1000,  min = 0, scale = 10 },
		{ id = "FxActor",      name = "Fx Actor",      editor = "combo",       default = "",    items = ActorFXClassCombo },
		{ id = "Filters",      name = "Filters",       editor = "nested_list", default = false, base_class = "CompositeBodyPresetFilter", inclusive = true },
		{ id = "ColorInherit", name = "Color Inherit", editor = "choice",      default = "",    items = GetBodyPartNameCombo },
		{ id = "Colors",       name = "Colors",        editor = "nested_list", default = false, base_class = "CompositeBodyPresetColor", inclusive = true, no_edit = function(self) return self.ColorInherit ~= "" end },
		{ id = "Lights",       name = "Lights",        editor = "nested_list", default = false, base_class = "CompositeBodyPresetLight", inclusive = true },
		{ id = "AffectedBy",   name = "Affected by",   editor = "choice",      default = "",    items = GetBodyPartNameCombo },
		{ id = "EntityWhenAffected", name = "Entity when affected", editor = "choice", default = "", items = GetBodyPartEntityItems, no_edit = function(o) return not o.AffectedBy end },
		{ id = "AttachOffset", name = "Attach Offset", editor = "point",       default = point30, },
		{ id = "AttachAxis",   name = "Attach Axis",   editor = "point",       default = axis_z, },
		{ id = "AttachAngle",  name = "Attach Angle",  editor = "number",      default = 0, scale = "deg", min = -180*60, max = 180*60, slider = true },
		
		{ id = "ApplyAnim",       name = "Apply Anim",        editor = "choice", default = "", items = function(self) return EntityStatesCombo(self.AnimTestEntity, "") end },
		{ id = "UnapplyAnim",     name = "Unapply Anim",      editor = "choice", default = "", items = function(self) return EntityStatesCombo(self.AnimTestEntity, "") end },
		{ id = "ApplyAnimMoment", name = "Apply Anim Moment", editor = "choice", default = "hit", items = function(self) return EntityStateMomentsCombo(self.AnimTestEntity, self.ApplyAnim, "", "hit") end, },
		{ id = "AnimTestEntity",  name = "Anim Test Entity",  editor = "text",   default = false },
	},
	GlobalMap = "CompositeBodyPresets",
	EditorMenubar = "Editors.Art",
	EditorMenubarName = "Composite Body Parts",
	EditorIcon = "CommonAssets/UI/Icons/atom molecule science.png",
	
	StoreAsTable = false,
}

CompositeBodyPreset.Documentation = [[The composite body system is a matching system for attaching parts to a body.

A body collects its potential parts not from all part presets, but from a specified preset <style GedHighlight>Group</style>. The matched parts are those having the same <style GedHighlight>Target</style> property as the body target property.

If no matching information is specified in the body, then its class name is used instead for all matching.

Each part can contain filters for additional conditions during the matching process.

Each part covers a specific named location on the body specified by <style GedHighlight>Covered Parts</style> property. If several parts are matched for the same location, a single one is chosen based on the <style GedHighlight>ZOrder</style> property. If there are still multiple parts with equal ZOrder, then a part is randomly selected based on the <style GedHighlight>Weight</style> property.]]

---
--- Checks for any errors in the CompositeBodyPreset object.
--- If the `CustomMatch` property is set, no error checking is performed.
--- Otherwise, the function checks the following:
--- - If there are no covered parts specified, returns "No covered parts specified!"
--- - If there are no composite bodies found with the specified `Target`, returns an error message with the target name.
--- - If there are no composite bodies found with the specified `group`, returns an error message with the group name.
--- - If there are no composite bodies found with any of the specified parts, returns an error message with the part names.
---
--- @return string|nil The error message, or `nil` if no errors are found.
function CompositeBodyPreset:GetError()
	if self.CustomMatch then
		return
	end
	local parts = self.Parts
	if not next(parts) then
		return "No covered parts specified!"
	end
	UpdateItems()
	local defs = composite_body_defs[self.Target]
	if not defs then
		return string.format("No composite bodies found with target '%s'", self.Target)
	end
	local group = self.group
	local count_group = 0
	local count_part = 0
	for _, def in ipairs(defs) do
		local composite_part_groups = def.composite_part_groups or { def.class }
		if table.find(composite_part_groups, group) then
			count_group = count_group + 1
			for _, part_name in ipairs(def.composite_part_names) do
				if parts[part_name] then
					count_part = count_part + 1
					break
				end
			end
		end
	end
	if count_group == 0 then
		return string.format("No composite bodies found with group '%s'", tostring(group))
	end
	if count_part == 0 then
		return string.format("No composite bodies found with parts %s", table.concat(table.keys(parts, true)))
	end
end

---
--- Returns a comma-separated string of the composite body classes that have at least one matching part.
---
--- This function first updates the cached composite body definitions, then checks each composite body definition
--- to see if it has a matching part from the `Parts` table of the `CompositeBodyPreset`. If a matching part is found,
--- the class of that composite body is added to the `found` table. The function then returns a comma-separated string
--- of the keys in the `found` table.
---
--- @return string A comma-separated string of the composite body classes that have at least one matching part.
function CompositeBodyPreset:GetBodiesFound()
	UpdateItems()
	local parts = self.Parts
	if not next(parts) then
		return 0
	end
	local found = {}
	for _, def in ipairs(composite_body_defs[self.Target]) do
		local composite_part_groups = def.composite_part_groups or { def.class }
		if table.find(composite_part_groups, self.group) then
			for _, part_name in ipairs(def.composite_part_names) do
				if parts[part_name] then
					found[def.class] = true
					break
				end
			end
		end
	end
	return table.concat(table.keys(found, true), ", ")
end

---
--- Called when a property of the `CompositeBodyPreset` is edited in the editor.
---
--- If the `Entity` property is changed, this function will mark all the `Colors` objects as modified, so their properties can be updated.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The GED (Game Editor Data) object associated with the property change.
---
function CompositeBodyPreset:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Entity" then
		for _, obj in ipairs(self.Colors) do
			ObjModified(obj) -- properties for modifiable colors have changed
		end
	end
end

local function FindParentPreset(obj, member)
	return GetParentTableOfKind(obj, "CompositeBodyPreset")
end

function OnMsg.ClassesGenerate()
	DefineModItemPreset("CompositeBodyPreset", {
		EditorSubmenu = "Other",
		EditorName = "Composite body",
		EditorShortcut = false,
	})
end

----

local function GetBodyFilters(filter)
	UpdateItems()
	local parent = FindParentPreset(filter)
	local props = parent and composite_body_filters[parent.Target]
	if not props then
		return {}
	end
	local filters = {}
	for _, def in ipairs(composite_body_defs[parent.Target]) do
		for name, prop in pairs(props) do
			local items
			if prop.items then
				items = prop_eval(prop.items, def, prop)
			elseif prop.preset_class then
				local filter = prop.preset_filter
				items = {}
				ForEachPreset(prop.preset_class, function(preset, group, items)
					if not filter or filter(preset) then
						items[#items + 1] = preset.id
					end
				end, items)
				table.sort(items)
			end
			if items and #items > 0 then
				local prev_filters = filters[name]
				if not prev_filters then
					filters[name] = items
				else
					for _, value in ipairs(items) do
						table.insert_unique(prev_filters, value)
					end
				end
			end
		end
	end
	return filters
end

local function GetFilterNameItems(filter)
	local filters = GetBodyFilters(filter)
	local items = filters and table.keys(filters, true)
	if items[1] ~= "" then
		table.insert(items, 1, "")
	end
	return items
end

local function GetFilterValueItems(filter)
	local filters = GetBodyFilters(filter)
	return filters and filters[filter.Name] or {""}
end

DefineClass.CompositeBodyPresetFilter = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Name",  name = "Name",  editor = "choice", default = "", items = GetFilterNameItems, },
		{ id = "Value", name = "Value", editor = "choice", default = "", items = GetFilterValueItems, },
		{ id = "Test",  name = "Test",  editor = "choice", default = "=", items = {"=", ">", "<"}, },
	},
	EditorView = Untranslated("<Name> <Test> <Value>"),
}

---
--- Checks if the given object matches the filter criteria defined by this `CompositeBodyPresetFilter` instance.
---
--- @param obj table The object to be matched against the filter.
--- @return boolean True if the object matches the filter, false otherwise.
function CompositeBodyPresetFilter:Match(obj)
	local obj_value, value, test = obj[self.Name], self.Value, self.Test
	if test == '=' then
		return obj_value == value
	elseif test == '>' then
		return obj_value > value
	elseif test == '<' then
		return obj_value < value
	end
end

----

DefineClass.CompositeBodyPresetColor = {
	__parents = { "ColorizationPropSet" },
	properties = {
		{ id = "Weight",  name = "Weight",  editor = "number", default = 1000, min = 0, scale = 10 },
	},
}

---
--- Gets the maximum number of colorization materials for this `CompositeBodyPresetColor` instance.
---
--- If the parent preset has a valid entity, the number of colorization materials for that entity is returned.
--- Otherwise, the default implementation of `ColorizationPropSet.GetMaxColorizationMaterials` is used.
---
--- @return integer The maximum number of colorization materials for this preset.
function CompositeBodyPresetColor:GetMaxColorizationMaterials()
	PopulateParentTableCache(self)
	if not ParentTableCache[self] then
		return ColorizationPropSet.GetMaxColorizationMaterials(self)
	end
	local parent = FindParentPreset(self)
	return parent and ColorizationMaterialsCount(parent.Entity) or 0
end

---
--- Gets an error message if the maximum number of colorization materials for this `CompositeBodyPresetColor` instance is 0.
---
--- If the parent preset has no valid entity, the error message will indicate that the composite body entity is not set.
--- If the parent preset has a valid entity but there are no modifiable colors in the entity, the error message will indicate that there are no modifiable colors.
---
--- @return string The error message, or an empty string if the maximum number of colorization materials is greater than 0.
function CompositeBodyPresetColor:GetError()
	if self:GetMaxColorizationMaterials() == 0 then
		local parent = FindParentPreset(self)
		if not parent or parent.Entity == "" then
			return "The composite body entity is not set."
		else
			return "There are no modifiable colors in the composite body entity."
		end
	end
end

----

local light_props = {}
function OnMsg.ClassesBuilt()
	local function RegisterProps(class, classdef)
		local props = {}
		for _, prop in ipairs(classdef:GetProperties()) do
			if prop.category == "Visuals"
			and not prop_eval(prop.no_edit, classdef, prop)
			and not prop_eval(prop.read_only, classdef, prop) then
				props[#props + 1] = prop
				props[prop.id] = classdef:GetDefaultPropertyValue(prop.id, prop)
			end
		end
		light_props[class] = props
	end
	RegisterProps("Light", Light)
	ClassDescendants("Light", RegisterProps)
end

function OnMsg.GatherFXActors(list)
	for _, preset in pairs(CompositeBodyPresets) do
		if (preset.FxActor or "") ~= "" then
			list[#list + 1] = preset.FxActor
		end
	end
end

function OnMsg.DataLoaded()
	PopulateParentTableCache(Presets.CompositeBodyPreset)
end

local function GetEntitySpotsItems(light)
	local parent = FindParentPreset(light)
	local entity = parent and parent.Entity or ""
	local states = IsValidEntity(entity) and GetStates(entity) or ""
	if #states == 0 then return empty_table end
	local idx = table.find(states, "idle")
	local spots = {}
	local spbeg, spend = GetAllSpots(entity, states[idx] or states[1])
	for spot = spbeg, spend do
		spots[GetSpotName(entity, spot)] = true
	end
	return table.keys(spots, true)
end

DefineClass.CompositeBodyPresetLight = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "LightType",  name = "Light Type", editor = "choice", default = "Light",  items = ToCombo(light_props) },
		{ id = "LightSpot",  name = "Light Spot", editor = "combo",  default = "Origin", items = GetEntitySpotsItems },
		{ id = "LightSIEnable",     name = "SI Apply", editor = "bool", default = true },
		{ id = "LightSIModulation", name = "SI Modulation", editor = "number", default = 255, min = 0, max = 255, slider = true, no_edit = function(self) return not self.LightSIEnable end  },
		{ id = "night_mode", name = "Night mode", editor = "dropdownlist", items = { "Off", "On" }, default = "On" },
		{ id = "day_mode",   name = "Day mode",   editor = "dropdownlist", items = { "Off", "On" }, default = "Off" },
	},
	EditorView = Untranslated("<LightType>: <LightSpot>"),
}

--- Returns an error message if the selected light type is invalid.
---
--- This method checks if the `light_props` table has an entry for the
--- `LightType` property of the `CompositeBodyPresetLight` object. If
--- the entry is missing, it returns an error message indicating that
--- the selected light type is invalid.
---
--- @return string|nil Error message if the light type is invalid, nil otherwise.
function CompositeBodyPresetLight:GetError()
	if not light_props[self.LightType] then
		return "Invalid light type selected!"
	end
end

---
--- Applies the properties of the `CompositeBodyPresetLight` object to the specified light.
---
--- This method iterates through the properties defined in the `light_props` table for the
--- `LightType` of the `CompositeBodyPresetLight` object. For each property, it sets the
--- corresponding property on the `light` object using the `SetProperty` method.
---
--- @param light LightObject The light object to apply the properties to.
---
function CompositeBodyPresetLight:ApplyToLight(light)
	local props = light_props[self.LightType] or empty_table
	for _, prop in ipairs(props) do
		local prop_id = prop.id
		local prop_value = rawget(self, prop_id)
		if prop_value ~= nil then
			light:SetProperty(prop_id, prop_value)
		end
	end
end

---
--- Returns the properties of the `CompositeBodyPresetLight` object, including the properties
--- defined in the `light_props` table for the current `LightType`.
---
--- This method creates a copy of the `properties` table defined in the `CompositeBodyPresetLight`
--- class, and then appends the properties defined in the `light_props` table for the current
--- `LightType`. The resulting table is returned.
---
--- @return table The properties of the `CompositeBodyPresetLight` object.
function CompositeBodyPresetLight:GetProperties()
	local props = table.icopy(self.properties)
	table.iappend(props, light_props[self.LightType] or empty_table)
	return props
end

--- Returns the default property value for the specified property ID and metadata.
---
--- This method first checks if there is a default value defined in the `light_props` table
--- for the current `LightType` of the `CompositeBodyPresetLight` object and the specified
--- property ID. If a default value is found, it is returned.
---
--- If no default value is found in the `light_props` table, this method calls the
--- `GetDefaultPropertyValue` method on the `PropertyObject` class to get the default
--- value.
---
--- @param prop_id string The ID of the property to get the default value for.
--- @param prop_meta table The metadata for the property.
--- @return any The default value for the specified property.
function CompositeBodyPresetLight:GetDefaultPropertyValue(prop_id, prop_meta)
	local def = table.get(light_props, self.LightType, prop_id)
	if def ~= nil then
		return def
	end
	return PropertyObject.GetDefaultPropertyValue(self, prop_id, prop_meta)
end

DefineClass.BaseLightObject = {
	__parents = { "Object" },
}

---
--- Updates the light object with the given light model.
---
--- This method is called when the light model changes, and it updates the properties of the
--- light object to match the new light model.
---
--- @param lm table The new light model to apply to the light object.
--- @param delayed boolean Whether the update should be delayed.
---
function BaseLightObject:UpdateLight(lm, delayed)
end

--- Adds the current `BaseLightObject` instance to the "Lights" label in the game.
---
--- This method is called during the `GameInit` phase to register the light object with the
--- game's "Lights" label, which allows it to be managed and updated along with other
--- light objects in the game.
function BaseLightObject:GameInit()
	Game:AddToLabel("Lights", self)
end

--- Removes the current `BaseLightObject` instance from the "Lights" label in the game.
---
--- This method is called when the light object is no longer needed, and it removes the
--- object from the game's "Lights" label, which allows it to be properly managed and
--- updated along with other light objects in the game.
function BaseLightObject:Done()
	Game:RemoveFromLabel("Lights", self)
end

if FirstLoad then
	UpdateLightsThread = false
end

function OnMsg.DoneMap()
	UpdateLightsThread = false
end

---
--- Updates all light objects in the game with the given light model.
---
--- This function is called when the light model changes, and it updates the properties of all
--- light objects in the game to match the new light model.
---
--- @param lm table The new light model to apply to the light objects.
--- @param delayed boolean Whether the update should be delayed.
---
function UpdateLights(lm, delayed)
	local lights = table.get(Game, "labels", "Lights")
	for _, obj in ipairs(lights) do
		obj:UpdateLight(lm, delayed)
	end
end

---
--- Updates all light objects in the game with the given light model after a delay.
---
--- This function is called when the light model changes, and it updates the properties of all
--- light objects in the game to match the new light model after a specified delay.
---
--- @param lm table The new light model to apply to the light objects.
--- @param delayed_time number The delay in seconds before updating the light objects.
---
function UpdateLightsDelayed(lm, delayed_time)
	DeleteThread(UpdateLightsThread)
	UpdateLightsThread = false
	if delayed_time > 0 then
		UpdateLightsThread = CreateGameTimeThread(function(lm, delayed_time)
			Sleep(delayed_time)
			UpdateLights(lm, true)
			UpdateLightsThread = false
		end, lm, delayed_time)
	else
		UpdateLights(lm)
	end
end

function OnMsg.LightmodelChange(view, lm, time)
	UpdateLightsDelayed(lm, time/2)
end

function OnMsg.GatherAllLabels(labels)
	labels.Lights = true
end

DefineClass.CompositeLightObject = {
	__parents = { "CompositeBody", "BaseLightObject" },

	light_parts = false,
	light_objs = false,
}

---
--- Composes the body parts of a CompositeLightObject and updates the light objects associated with each part.
---
--- This function is called when the body parts of the CompositeLightObject need to be composed, such as when the seed changes.
---
--- It first calls the ComposeBodyParts function of the parent CompositeBody class to compose the body parts. Then, it updates the light objects associated with each part, removing any light objects that are no longer needed and creating new ones for any new parts.
---
--- @param seed number The seed to use when composing the body parts.
--- @return boolean Whether the body parts were changed.
---
function CompositeLightObject:ComposeBodyParts(seed)
	self.light_parts = nil
	
	local changed = CompositeBody.ComposeBodyParts(self, seed)
	
	local light_parts = self.light_parts
	local light_objs = self.light_objs
	for i = #(light_objs or ""),1,-1 do
		local config = light_objs[i]
		local part = light_parts and light_parts[config]
		if not part then
			DoneObject(light_objs[config])
			light_objs[config] = nil
			table.remove_value(light_objs, config)
		end
	end
	for _, config in ipairs(light_parts) do
		light_objs = light_objs or {}
		if light_objs[config] == nil then
			light_objs[config] = false
			light_objs[#light_objs + 1] = config
		end
	end
	self.light_objs = light_objs
	
	return changed
end

---
--- Applies a body part to the CompositeLightObject and associates any light configurations defined in the preset with the part.
---
--- This function first retrieves the `light_parts` table, creating it if it doesn't exist. It then iterates through the `Lights` table in the preset, associating each light configuration with the current part and adding it to the `light_parts` table.
---
--- Finally, it calls the `ApplyBodyPart` function of the parent `CompositeBody` class, passing along the part, preset, and any additional arguments.
---
--- @param part table The body part to apply.
--- @param preset table The preset containing the light configurations to associate with the part.
--- @param ... Any additional arguments to pass to the parent `ApplyBodyPart` function.
--- @return boolean Whether the body part was applied successfully.
---
function CompositeLightObject:ApplyBodyPart(part, preset, ...)
	local light_parts = self.light_parts
	for _, config in ipairs(preset.Lights) do
		light_parts = light_parts or {}
		light_parts[config] = part
		light_parts[#light_parts + 1] = config
	end
	self.light_parts = light_parts
	
	return CompositeBody.ApplyBodyPart(self, part, preset, ...)
end

---
--- Determines whether a body part's light is turned on based on the current time of day.
---
--- This function checks the `night_mode` and `day_mode` properties of the provided `config` table to determine whether the light should be on or off. If the `GameState.Night` flag is set, the `night_mode` property is used, otherwise the `day_mode` property is used.
---
--- @param config table The light configuration table containing the `night_mode` and `day_mode` properties.
--- @return boolean Whether the body part's light is turned on.
---
function CompositeLightObject:IsBodyPartLightOn(config)
	local mode = GameState.Night and config.night_mode or config.day_mode
	return mode == "On"
end

---
--- Updates the lights associated with the CompositeLightObject.
---
--- This function iterates through the `light_objs` table, which contains the light configurations associated with the CompositeLightObject. For each configuration, it checks if the light should be turned on or off based on the current time of day using the `IsBodyPartLightOn` function. If the light should be turned on and it doesn't exist, it creates a new light object and attaches it to the corresponding body part. If the light should be turned off and it exists, it destroys the light object. Finally, it sets the SI modulation on the body part based on the light configuration.
---
--- @param delayed boolean Whether the light update should be delayed.
---
function CompositeLightObject:UpdateLight(delayed)
	local light_objs = self.light_objs or empty_table
	local IsBodyPartLightOn = self.IsBodyPartLightOn
	for _, config in ipairs(light_objs) do
		local light = light_objs[config]
		local part = self.light_parts[config]
		local turned_on = IsBodyPartLightOn(self, config)
		if turned_on and not light then
			light = PlaceObject(config.LightType)
			config:ApplyToLight(light)
			part:Attach(light, GetSpotBeginIndex(part, config.LightSpot))
			light_objs[config] = light
		elseif not turned_on and light then
			DoneObject(light)
			light_objs[config] = false
		end
		if config.LightSIEnable then
			part:SetSIModulation(turned_on and config.LightSIModulation or 0)
		end
	end
end

----

DefineClass.BlendedCompositeBody = {
	__parents = { "CompositeBody", "Object" },
	composite_part_blend = false,
	
	blended_body_parts_params = false,
	blended_body_parts = false,
}

---
--- Initializes the `blended_body_parts_params` and `blended_body_parts` tables for the `BlendedCompositeBody` class.
---
--- This function is called during the initialization of a `BlendedCompositeBody` object to set up the necessary data structures for managing blended body parts.
---
--- @function BlendedCompositeBody:Init
--- @return nil
function BlendedCompositeBody:Init()
	self.blended_body_parts_params = { }
	self.blended_body_parts = { }
end

---
--- Forces the composition of the blended body parts for the `BlendedCompositeBody` object.
---
--- This function initializes the `blended_body_parts_params` and `blended_body_parts` tables, and then calls the `ComposeBodyParts` function to compose the blended body parts.
---
--- @function BlendedCompositeBody:ForceComposeBlendedBodyParts
--- @return nil
function BlendedCompositeBody:ForceComposeBlendedBodyParts()
	self.blended_body_parts_params = { }
	self.blended_body_parts = { }
	self:ComposeBodyParts()
end

---
--- Forces the reversion of the blended body parts for the `BlendedCompositeBody` object.
---
--- This function collects all the attached body parts and their corresponding presets, and then reverts each part to its original entity.
---
--- @function BlendedCompositeBody:ForceRevertBlendedBodyParts
--- @return nil
function BlendedCompositeBody:ForceRevertBlendedBodyParts()
	if next(self.attached_parts) then
		local part_to_preset = {}
		self:CollectBodyParts(part_to_preset)
		for name,preset in sorted_pairs(part_to_preset) do
			local part = self.attached_parts[name]
			local entity = preset.Entity
			if IsValid(part) and IsValidEntity(entity) then
				Msg("RevertBlendedBodyPart", part)
				part:ChangeEntity(entity)
			end
		end
	end
end

---
--- Updates the blended body part parameters for the `BlendedCompositeBody` object.
---
--- This function is called to update the parameters for a blended body part. It returns the entity associated with the part.
---
--- @param params table The parameters for the blended body part
--- @param part Entity The body part entity
--- @param preset table The preset for the body part
--- @param name string The name of the body part
--- @param seed number The seed value for the body part
--- @return Entity The entity associated with the body part
function BlendedCompositeBody:UpdateBlendPartParams(params, part, preset, name, seed)
	return part:GetEntity()
end

---
--- Determines whether a body part should be blended for the `BlendedCompositeBody` object.
---
--- This function is called to check if a body part should be blended. It returns `false` by default, indicating that no blending should occur.
---
--- @param params table The parameters for the blended body part
--- @param part Entity The body part entity
--- @param preset table The preset for the body part
--- @param name string The name of the body part
--- @param seed number The seed value for the body part
--- @return boolean Whether the body part should be blended
function BlendedCompositeBody:ShouldBlendPart(params, part, preset, name, seed)
	return false
end

if FirstLoad then
	g_EntityBlendLocks = { }
	--g_EntityBlendLog = { }
end

local function BlendedEntityLocksGet(entity_name)
	return g_EntityBlendLocks[entity_name] or 0
end

---
--- Checks if the specified entity is locked for blending.
---
--- @param entity_name string The name of the entity to check
--- @return boolean Whether the entity is locked for blending
function BlendedEntityIsLocked(entity_name)
	--table.insert(g_EntityBlendLog, GameTime() .. " lock " .. entity_name)
	return BlendedEntityLocksGet(entity_name) > 0
end

---
--- Locks the specified entity for blending.
---
--- This function is used to lock an entity for blending operations. It increments the lock count for the entity, ensuring that the entity cannot be blended by other parts of the code until it is unlocked.
---
--- @param entity_name string The name of the entity to lock
function BlendedEntityLock(entity_name)
	--table.insert(g_EntityBlendLog, GameTime() .. " unlock " .. entity_name)
	g_EntityBlendLocks[entity_name] = BlendedEntityLocksGet(entity_name) + 1
end

---
--- Unlocks the specified entity for blending.
---
--- This function is used to unlock an entity that was previously locked for blending operations. It decrements the lock count for the entity, allowing the entity to be blended by other parts of the code.
---
--- @param entity_name string The name of the entity to unlock
function BlendedEntityUnlock(entity_name)
	local locks_count = BlendedEntityLocksGet(entity_name)
	assert(locks_count >= 1, "Unlocking a blended entity that isn't locked")
	if locks_count > 1 then
		g_EntityBlendLocks[entity_name] = locks_count - 1
	else
		g_EntityBlendLocks[entity_name] = nil
	end
end

---
--- Waits for any locks on the specified entity to be released before continuing.
---
--- This function is used to ensure that an entity is not currently locked for blending operations before attempting to blend it. It will wait until any existing locks on the entity are released before returning.
---
--- @param obj table The object that is performing the blending operation (optional)
--- @param entity_name string The name of the entity to check for locks
--- @return boolean True if the entity is unlocked and ready to be blended, false if the object became invalid while waiting
---
function WaitBlendEntityLocks(obj, entity_name)
	while BlendedEntityIsLocked(entity_name) do
		if obj and not IsValid(obj) then
			return false
		end
		WaitNextFrame(1)
	end
	
	return true
end

---
--- Blends the specified entity with up to three other entities.
---
--- This function is used to blend the target entity with up to three other entities, using the provided weights. The blending is performed asynchronously, and the function will wait for any existing locks on the target entity to be released before proceeding.
---
--- @param t string The name of the target entity to blend
--- @param e1 string The name of the first entity to blend with the target
--- @param e2 string The name of the second entity to blend with the target
--- @param e3 string The name of the third entity to blend with the target
--- @param w1 number The weight to apply to the first blended entity
--- @param w2 number The weight to apply to the second blended entity
--- @param w3 number The weight to apply to the third blended entity
--- @param m2 number The material blend factor for the second blended entity
--- @param m3 number The material blend factor for the third blended entity
function BlendedCompositeBody:BlendEntity(t, e1, e2, e3, w1, w2, w3, m2, m3)
	--table.insert(g_EntityBlendLog, GameTime() .. " " .. self.class .. " blend " .. t)
	assert(BlendedEntityIsLocked(t), "To blend an entity you must lock it using BlendedEntityLock")
	assert(t ~= e1 and t ~= e2 and t ~= e3)

	SetMaterialBlendMaterials(
		GetEntityIdleMaterial(t), --target
		GetEntityIdleMaterial(e1), --base
		m2, GetEntityIdleMaterial(e2), --weight 1, material
		m3, GetEntityIdleMaterial(e3)) --weight 2, material
	WaitNextFrame(1)
	
	local err = AsyncOpWait(nil, nil, "AsyncMeshBlend", 
		t, 0, --target, LOD
		e1, w1, --entity 1, weight
		e2, w2, --entity 2, weight
		e3, w3) --entity 3, weight
	if err then print("Failed to blend meshes: ", err) end
end

---
--- Asynchronously blends the specified entity with up to three other entities.
---
--- This function is used to blend the target entity with up to three other entities, using the provided weights. The blending is performed asynchronously, and the function will wait for any existing locks on the target entity to be released before proceeding.
---
--- @param obj table The object that is performing the blending operation (optional)
--- @param t string The name of the target entity to blend
--- @param e1 string The name of the first entity to blend with the target
--- @param e2 string The name of the second entity to blend with the target
--- @param e3 string The name of the third entity to blend with the target
--- @param w1 number The weight to apply to the first blended entity
--- @param w2 number The weight to apply to the second blended entity
--- @param w3 number The weight to apply to the third blended entity
--- @param m2 number The material blend factor for the second blended entity
--- @param m3 number The material blend factor for the third blended entity
--- @param callback function A callback function to be called after the blending is complete
--- @return thread The real-time thread that performs the blending operation
function BlendedCompositeBody:AsyncBlendEntity(obj, t, e1, e2, e3, w1, w2, w3, m2, m3, callback)
	return CreateRealTimeThread(function(self, obj, t, e1, e2, e3, w1, w2, w3, m2, m3, callback)
		WaitBlendEntityLocks(obj, t)
		BlendedEntityLock(t)
		
		self:BlendEntity(t, e1, e2, e3, w1, w2, w3, m2, m3)
		
		if callback then
			callback(self, obj, t, e1, e2, e3, w1, w2, w3, m2, m3)
		end
		
		BlendedEntityUnlock(t)
	end, self, obj, t, e1, e2, e3, w1, w2, w3, m2, m3, callback)
end

---
--- Applies a blended body part to the composite body.
---
--- This function is used to apply a blended body part to the composite body. It calls the `CompositeBody.ApplyBodyPart` function with the provided parameters.
---
--- @param blended_entity table The blended entity to apply
--- @param part table The body part to apply
--- @param preset string The preset to apply to the body part
--- @param name string The name of the body part
--- @param seed number The seed to use for the body part
--- @return boolean Whether the body part was successfully applied
function BlendedCompositeBody:ApplyBlendBodyPart(blended_entity, part, preset, name, seed)
	return CompositeBody.ApplyBodyPart(self, preset, name, seed)
end

---
--- Applies the body part when blending fails.
---
--- This function is called when the blending of a body part fails. It falls back to the default `CompositeBody.ApplyBodyPart` function to apply the body part.
---
--- @param blended_entity table The blended entity that failed to apply
--- @param part table The body part to apply
--- @param preset string The preset to apply to the body part
--- @param name string The name of the body part
--- @param seed number The seed to use for the body part
--- @return boolean Whether the body part was successfully applied
function BlendedCompositeBody:BlendBodyPartFailed(blended_entity, part, preset, name, seed)
	return CompositeBody.ApplyBodyPart(self, part, preset, name, seed)
end

-- if the body part is declared as "to be blended"
---
--- Checks if a body part is currently being blended.
---
--- This function checks if the specified body part is currently being blended by the `BlendedCompositeBody` class.
---
--- @param name string The name of the body part to check
--- @return boolean true if the body part is currently being blended, false otherwise
function BlendedCompositeBody:IsBlendBodyPart(name)
	return self.composite_part_blend and self.composite_part_blend[name]
end

-- if the body part is using a blended entity or is being blended at the moment
---
--- Checks if a body part is currently being blended.
---
--- This function checks if the specified body part is currently being blended by the `BlendedCompositeBody` class.
---
--- @param name string The name of the body part to check
--- @return boolean true if the body part is currently being blended, false otherwise
function BlendedCompositeBody:IsCurrentlyBlendedBodyPart(name)
	return self.blended_body_parts and self.blended_body_parts[name]
end

---
--- Colorizes a body part of the composite body.
---
--- This function is used to colorize a specific body part of the composite body. If the body part is currently being blended, the function will return without doing anything.
---
--- @param part table The body part to colorize
--- @param preset string The preset to apply to the body part
--- @param name string The name of the body part
--- @param seed number The seed to use for the body part
--- @return boolean Whether the body part was successfully colorized
function BlendedCompositeBody:ColorizeBodyPart(part, preset, name, seed)
	if self:IsCurrentlyBlendedBodyPart(name) then
		return
	end
	return CompositeBody.ColorizeBodyPart(self, part, preset, name, seed)
end

---
--- Changes the entity of a body part in the composite body.
---
--- This function is used to change the entity of a specific body part in the composite body. If the body part is currently being blended, the function will return without doing anything.
---
--- @param part table The body part to change
--- @param preset string The preset to apply to the body part
--- @param name string The name of the body part
--- @return boolean Whether the body part was successfully changed
function BlendedCompositeBody:ChangeBodyPartEntity(part, preset, name)
	if self:IsCurrentlyBlendedBodyPart(name) then
		return
	end
	return CompositeBody.ChangeBodyPartEntity(self, part, preset, name)
end

---
--- Applies a body part to the composite body, handling blending if necessary.
---
--- This function is used to apply a body part to the composite body. If the body part is currently being blended, the function will handle the blending process. Otherwise, it will simply apply the body part using the `CompositeBody.ApplyBodyPart` function.
---
--- @param part table The body part to apply
--- @param preset string The preset to apply to the body part
--- @param name string The name of the body part
--- @param seed number The seed to use for the body part
--- @return boolean Whether the body part was successfully applied
function BlendedCompositeBody:ApplyBodyPart(part, preset, name, seed)
	if self:IsBlendBodyPart(name) then
		self.blended_body_parts_params = self.blended_body_parts_params or { }
		local params = self.blended_body_parts_params[name]
		if not params or self:ShouldBlendPart(params, part, preset, name, seed) then
			params = params or { }
			local blended_entity = self:UpdateBlendPartParams(params, part, preset, name, seed)
			if IsValidEntity(blended_entity) then
				self.blended_body_parts_params[name] = params
				self.blended_body_parts[name] = (self.blended_body_parts[name] or 0) + 1
				return self:ApplyBlendBodyPart(blended_entity, part, preset, name, seed)
			else
				self.blended_body_parts[name] = nil
				return self:BlendBodyPartFailed(blended_entity, part, preset, name, seed)
			end
		end
	end
	
	return CompositeBody.ApplyBodyPart(self, part, preset, name, seed)
end

---
--- Removes a body part from the composite body, handling blending if necessary.
---
--- This function is used to remove a body part from the composite body. If the body part is currently being blended, the function will remove the blending information for that body part.
---
--- @param part table The body part to remove
--- @param name string The name of the body part
--- @return boolean Whether the body part was successfully removed
function BlendedCompositeBody:RemoveBodyPart(part, name)
	if self:IsBlendBodyPart(name) and self.blended_body_parts_params then
		self.blended_body_parts_params[name] = nil
	end
	return CompositeBody.RemoveBodyPart(self, part, name)
end

---
--- Forces a recomposition of all blended bodies in the game.
---
--- This function iterates through all `BlendedCompositeBody` entities in the game and forces them to revert and recompose their blended body parts. This is useful for ensuring that blended bodies are properly updated after certain game events, such as loading a savegame.
---
--- @return nil
function ForceRecomposeAllBlendedBodies()
	local objs = MapGet("map", "BlendedCompositeBody")
	for i,obj in ipairs(objs) do
		obj:ForceRevertBlendedBodyParts()
	end
	for i,obj in ipairs(objs) do
		obj:ForceComposeBlendedBodyParts()
	end
end

function OnMsg.PostLoadGame()
	ForceRecomposeAllBlendedBodies()
end

function OnMsg.AdditionalEntitiesLoaded()
	if type(__cobjectToCObject) ~= "table" then return end
	ForceRecomposeAllBlendedBodies()
end

local body_to_states
---
--- Retrieves the list of animation states for a composite body.
---
--- This function looks up the list of animation states for a composite body based on its class ID. If the list has not been cached yet, it will resolve the template entity for the class and extract the animation states from it.
---
--- @param classdef table The class definition for the composite body
--- @return table The list of animation states for the composite body
function CompositeBodyAnims(classdef)
	local id = classdef.id or classdef.class
	body_to_states = body_to_states or {}
	local states = body_to_states[id]
	if not states then
		local entity = ResolveTemplateEntity(classdef)
		states = IsValidEntity(entity) and GetStates(entity) or empty_table
		table.sort(states)
		body_to_states[id] = states
	end
	return states
end

---
--- Resets the blended body parts for all BlendedCompositeBody entities in the game.
---
--- This function iterates through all BlendedCompositeBody entities in the game and resets their blended_body_parts table to an empty table. This is useful for ensuring that blended body parts are properly reset after certain game events, such as loading a savegame.
---
--- @return nil
function SavegameFixups.BlendedBodyPartsList()
	MapForEach(true, "BlendedCompositeBody", function(obj)
		obj.blended_body_parts = {}
	end)
end

---
--- Resets the blended body part IDs for all BlendedCompositeBody entities in the game.
---
--- This function iterates through all BlendedCompositeBody entities in the game and resets the blended_body_parts table for each entity, setting the ID for each part to 1. This is useful for ensuring that blended body part IDs are properly reset after certain game events, such as loading a savegame.
---
--- @return nil
function SavegameFixups.BlendedBodyBlendIDs()
	MapForEach(true, "BlendedCompositeBody", function(obj)
		for name in pairs(obj.blended_body_parts) do
			obj.blended_body_parts[name] = 1
		end
	end)
end

---
--- Fixes the sync state flag for all CompositeBody and Building entities in the game.
---
--- This function iterates through all CompositeBody and Building entities in the game and clears the gofSyncState flag and sets the gofPropagateState flag. This is useful for ensuring that the sync state of these entities is properly reset after certain game events, such as loading a savegame.
---
--- @return nil
function SavegameFixups.FixSyncStateFlag2()
	MapForEach(true, "CompositeBody", "Building", function(obj)
		obj:ClearGameFlags(const.gofSyncState)
		obj:SetGameFlags(const.gofPropagateState)
	end)
end
