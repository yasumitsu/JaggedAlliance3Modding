---
--- Returns the attaches for the given object and entity state.
---
--- @param obj Object The object to get the attaches for.
--- @param entity string The entity to get the attaches for. If not provided, the object's entity will be used.
--- @return table|nil The attaches for the given object and entity state, or nil if none are found.
---
function GetObjStateAttaches(obj, entity)
	entity = entity or (obj:GetEntity() or obj.entity)
	
	local state = obj and GetStateName(obj:GetState()) or "idle"
	local entity_attaches = Attaches[entity]
	
	return entity_attaches and entity_attaches[state]
end

---
--- Returns a list of auto attach modes for the given object and entity.
---
--- @param obj Object The object to get the auto attach modes for.
--- @param entity string The entity to get the auto attach modes for. If not provided, the object's entity will be used.
--- @return table The list of auto attach modes.
---
function GetEntityAutoAttachModes(obj, entity)
	local attaches = GetObjStateAttaches(obj, entity)
	local modes = {""}
	for _, attach in ipairs(attaches or empty_table) do
		if attach.required_state then
			local mode = string.trim_spaces(attach.required_state)
			table.insert_unique(modes, mode)
		end
	end
	
	return modes
end

--[[@@@
@class AutoAttachCallback
Inherit this if you want a callback when an objects is autoattached to its parent
--]]

DefineClass.AutoAttachCallback = {
	__parents = {"InitDone"},
}

---
--- Called when the object is attached to its parent.
---
--- @param parent Object The parent object that the object is being attached to.
--- @param spot string The spot name that the object is being attached to on the parent.
---
function AutoAttachCallback:OnAttachToParent(parent, spot)
end

--[[@@@
@class AutoAttachObject
Objects from this type are able to attach a preset of objects on their creation based on their spot annotations.
--]]

DefineClass.AutoAttachObject =
{
	__parents = { "Object", "ComponentAttach" },
	auto_attach_props_description = false,

	properties = {
		{ id = "AutoAttachMode", editor = "choice", default = "", items = function(obj) return GetEntityAutoAttachModes(obj) or {} end },
		{ id = "AllAttachedLightsToDetailLevel", editor = "choice", default = false, items = {"Essential", "Optional", "Eye Candy"}},
	},

	auto_attach_at_init = true,
	auto_attach_mode = false,
	is_forced_lod_min = false,
	
	max_colorization_materials_attaches = 0,
}

local gofAutoAttach = const.gofAutoAttach

---
--- Checks if the given attachment is an auto-attach.
---
--- @param attach table The attachment to check.
--- @return boolean True if the attachment is an auto-attach, false otherwise.
---
function IsAutoAttach(attach)
	return attach:GetGameFlags(gofAutoAttach) ~= 0
end

---
--- Destroys all auto-attached objects associated with this object.
---
function AutoAttachObject:DestroyAutoAttaches()
	self:DestroyAttaches(IsAutoAttach)
end

---
--- Clears all attached members from the object.
---
--- This function iterates through all the object's state attaches and removes any attached members from the object.
---
--- @param self AutoAttachObject The object to clear attached members from.
---
function AutoAttachObject:ClearAttachMembers()
	local attaches = GetObjStateAttaches(self)
	for _, attach in ipairs(attaches) do
		if attach.member then
			self[attach.member] = nil
		end
	end
end

---
--- Sets the auto-attach mode for the object and performs necessary cleanup and re-attachment.
---
--- When the auto-attach mode is changed, this function will:
--- - Update the `auto_attach_mode` property of the object
--- - Destroy all existing auto-attached objects associated with the object
--- - Clear all attached members from the object
--- - Re-attach all auto-attached objects
---
--- @param self AutoAttachObject The object to set the auto-attach mode for.
--- @param value string The new auto-attach mode to set.
---
function AutoAttachObject:SetAutoAttachMode(value)
	self.auto_attach_mode = value
	self:DestroyAutoAttaches()
	self:ClearAttachMembers()
	self:AutoAttachObjects()
end

---
--- Handles changes to the `AllAttachedLightsToDetailLevel` and `StateText` properties of the `AutoAttachObject`.
---
--- When either of these properties are changed, this function will update the auto-attach mode of the object by calling `SetAutoAttachMode()`.
---
--- @param self AutoAttachObject The object that the property was changed on.
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged any The GED (Game Editor) object associated with the property change.
---
function AutoAttachObject:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "AllAttachedLightsToDetailLevel" or prop_id == "StateText" then
		self:SetAutoAttachMode(self:GetAutoAttachMode())
	end
	Object.OnEditorSetProperty(self, prop_id, old_value, ged)
end

---
--- Gets the current auto-attach mode for the object.
---
--- If the current auto-attach mode is not set in the object's list of valid auto-attach modes, this function will return the first valid mode in the list.
---
--- @param self AutoAttachObject The object to get the auto-attach mode for.
--- @param mode string (optional) The auto-attach mode to check for. If not provided, the object's current auto-attach mode will be used.
--- @return string The current auto-attach mode for the object.
---
function AutoAttachObject:GetAutoAttachMode(mode)
	local mode_set = GetEntityAutoAttachModes(self)
	if not mode_set then
		return ""
	end
	if table.find(mode_set, mode or self.auto_attach_mode) then
		return self.auto_attach_mode
	end
	return mode_set[1] or ""
end

---
--- Gets the set of valid auto-attach modes for the object.
---
--- @param self AutoAttachObject The object to get the auto-attach mode set for.
--- @return table The set of valid auto-attach modes for the object.
---
function AutoAttachObject:GetAttachModeSet()
	return GetEntityAutoAttachModes(self)
end

if FirstLoad then
	s_AutoAttachedLightDetailsBaseObject = false
end

---
--- Handles the auto-attachment of objects to a parent object.
---
--- This function is responsible for attaching objects to a parent object based on the attachment information stored in the parent object. It will create new objects and attach them to the parent, as well as set various properties on the attached objects.
---
--- @param obj AutoAttachObject The parent object to attach objects to.
--- @param context string The context in which the auto-attachment is happening (e.g. "init", "placementcursor").
---
function AutoAttachObjects(obj, context)
	if not s_AutoAttachedLightDetailsBaseObject and obj.AllAttachedLightsToDetailLevel then
		s_AutoAttachedLightDetailsBaseObject = obj
	end
	
	local selectable = obj:GetEnumFlags(const.efSelectable) ~= 0
	local attaches = GetObjStateAttaches(obj)
	local max_colorization_materials = 0
	for i = 1, #(attaches or "") do
		local attach = attaches[i]
		local class = GetAttachClass(obj, attach[2])

		local spot_attaches = {}
		local place, detail_class = PlaceCheck(obj, attach, class, context)
		if place then
			local o = PlaceAtSpot(obj, attach.spot_idx, class, context)
			if o then
				if attach.mirrored then
					o:SetMirrored(true)
				end
				if attach.offset then
					o:SetAttachOffset(attach.offset)
				end
				if attach.axis and attach.angle and attach.angle ~= 0 then
					o:SetAttachAxis(attach.axis)
					o:SetAttachAngle(attach.angle)
				end
				if selectable then 
					o:SetEnumFlags(const.efSelectable)
				end
				if attach.inherited_properties then
					for key, value in sorted_pairs(attach.inherited_properties) do
						o:SetProperty(key, value)
					end
				end
				if IsKindOf(o, "SubstituteByRandomChildEntity") then
					-- NOTE:	when substituting entity the object is still not attached so it can't be
					--			destroyed in SubstituteByRandomChildEntity and we have to do it manually here
					if o:IsForcedLODMinAttach() and o:GetDetailClass() ~= "Essential" then
						DoneObject(o)
						o = nil
					else
						local top_parent = GetTopmostParent(o)
						ApplyCurrentEnvColorizedToObj(top_parent) -- entity changed, possibly colorization too.
						top_parent:DestroyRenderObj(true)
					end
				else
					o:SetDetailClass(detail_class)
				end
				if o then
					if attach.inherit_colorization then
						o:SetGameFlags(const.gofInheritColorization)
						max_colorization_materials = Max(max_colorization_materials, o:GetMaxColorizationMaterials())
					end
					o:SetForcedLODMin(rawget(obj, "is_forced_lod_min") or obj:GetForcedLODMin())
					spot_attaches[#spot_attaches+1] = o
				end
			end
		end
		if context ~= "placementcursor" then
			SetObjMembers(obj, attach, spot_attaches)
		end
	end
	if max_colorization_materials > AutoAttachObject.max_colorization_materials_attaches then
		obj.max_colorization_materials_attaches = max_colorization_materials
	end
	
	if s_AutoAttachedLightDetailsBaseObject == obj then
		s_AutoAttachedLightDetailsBaseObject = false
	end
end

---
--- Returns the maximum number of colorization materials for this object.
---
--- This takes into account any additional colorization materials that were attached to the object
--- through the auto-attach system, in addition to the base colorization materials of the object.
---
--- @return number The maximum number of colorization materials for this object.
function AutoAttachObject:GetMaxColorizationMaterials()
	return Max(self.max_colorization_materials_attaches, CObject.GetMaxColorizationMaterials(self))
end

---
--- Determines whether the object can be colorized.
---
--- The object can be colorized if it has additional colorization materials attached through the auto-attach system, or if the base object can be colorized.
---
--- @return boolean True if the object can be colorized, false otherwise.
---
function AutoAttachObject:CanBeColorized()
	return self.max_colorization_materials_attaches and self.max_colorization_materials_attaches > 1 or CObject.CanBeColorized(self)
end

AutoAttachObject.AutoAttachObjects = AutoAttachObjects

---
--- Removes object members from the specified list.
---
--- If the `attach.member` field is set, this function will remove the corresponding object member from the list.
--- If the `attach.memberlist` field is set, this function will remove the list from the corresponding object member.
---
--- @param obj table The object to remove members from.
--- @param attach table The attachment information, containing the `member` and `memberlist` fields.
--- @param list table The list of members to remove.
---
function RemoveObjMembers(obj, attach, list)
	if attach.member then
		local o = obj[attach.member]
		for i = 1, #list do 
			if o == list[i] then
				obj[attach.member] = false
				break
			end
		end
	end
	if attach.memberlist and obj[attach.memberlist] and type(obj[attach.memberlist]) == "table" then
		table.remove_entry(obj[attach.memberlist], list)
	end
end

-- local functions used in the class methods
local AutoAttachObjects, RemoveObjMembers = AutoAttachObjects, RemoveObjMembers

---
--- Initializes the AutoAttachObject and automatically attaches the object if `auto_attach_at_init` is true.
---
--- @function AutoAttachObject:Init
--- @return nil
function AutoAttachObject:Init()
	if self.auto_attach_at_init then
		AutoAttachObjects(self, "init")
	end
end

---
--- Initializes an AutoAttachObject from a Lua code representation.
---
--- @param props table A table of properties to set on the object.
--- @param arr table An array of additional data to set on the object.
--- @param handle number The handle of the object.
--- @return AutoAttachObject The initialized AutoAttachObject.
---
function AutoAttachObject:__fromluacode(props, arr, handle)
	local obj = ResolveHandle(handle)
	
	if obj and obj[true] then
		StoreErrorSource(obj, "Duplicate handle", handle)
		assert(false, string.format("Duplicate handle %d: new '%s', prev '%s'", handle, self.class, obj.class))
		obj = nil
	end
	
	local idx = table.find(props, "AllAttachedLightsToDetailLevel")
	local attached_lights_detail = idx and props[idx + 1]
	if attached_lights_detail then
		obj.AllAttachedLightsToDetailLevel = attached_lights_detail
	end

	local idx = table.find(props, "LowerLOD")
	
	if idx ~= nil then
		obj.is_forced_lod_min = props[idx + 1]
	else
		idx = table.find(props, "ForcedLODState")
		obj.is_forced_lod_min = idx and (props[idx + 1] == "Minimum")
	end
	
	obj = self:new(obj)
	SetObjPropertyList(obj, props)
	SetArray(obj, arr)
	obj.is_forced_lod_min = nil
	
	return obj
end

AutoAttachObject.ShouldAttach = return_true
AutoResolveMethods.ShouldAttach = "and"

---
--- Called when an attachment is created for this object.
---
--- @param attach table The attachment that was created.
--- @param spot table The attachment spot that the attachment was created on.
---
function AutoAttachObject:OnAttachCreated(attach, spot)
end

---
--- Marks the entities that are attached to this AutoAttachObject.
---
--- @param entities table An optional table of entities to mark. If not provided, a new table will be created.
--- @return table The table of marked entities.
---
function AutoAttachObject:MarkAttachEntities(entities)
	if not IsValid(self) then return entities end
	
	entities = entities or {}
	
	self:__MarkEntities(entities)
	
	local cur_mode = self.auto_attach_mode
	local modes = self:GetAttachModeSet()
	for _, mode in ipairs(modes) do
		self:SetAutoAttachMode(mode)
		self:__MarkEntities(entities)
	end
	self:SetAutoAttachMode(cur_mode)
	
	return entities
end

---
--- Sets the members and member lists of the given object based on the provided attachment information.
---
--- @param obj table The object to set the members and member lists for.
--- @param attach table The attachment information containing the member and memberlist properties.
--- @param list table A list of values to set for the members and member lists.
---
function SetObjMembers(obj, attach, list)
	if attach.member then
		local name = attach.member
		if #list == 0 then
			if not rawget(obj, name) then
				obj[name] = false -- initialize on init
			end
		else
			assert(#list == 1 and not rawget(obj, name), 'Duplicate member "'..name..'" in the auto-attaches of class "'..obj.class..'"')
			obj[name] = list[1]
		end
	end
	if attach.memberlist then
		local name = attach.memberlist
		if not rawget(obj, name) or not type(obj[name]) == "table" or not IsValid(obj[name][1]) then
			obj[name] = {}
		end
		if #list > 0 then
			obj[name][#obj[name] + 1] = list
		end
	end
end

---
--- Selects a random class from a table of classes with associated probabilities.
---
--- @param self AutoAttachObject The AutoAttachObject instance.
--- @param classes table A table of classes and their associated probabilities.
--- @return string|boolean The selected class, or false if no class is selected.
---
function GetAttachClass(self, classes)
	if type(classes) == "string" then
		return classes
	end
	assert(type(classes) == "table")
	local rnd = self:Random(100)
	local cur_prob = 0
	for class, prob in pairs(classes) do
		cur_prob = cur_prob + prob
		if rnd <= cur_prob then
			return class
		end
	end
	-- probability of nothing left
	return false
end

local IsKindOf = IsKindOf
local shapeshifter_class_whitelist = { "Light", "AutoAttachSIModulator", "ParSystem" } -- classes that are alowed to be instantiated even in shapeshifters
local function IsObjectClassAllowedInShapeshifter(class_to_spawn)
	for _, class_name in ipairs(shapeshifter_class_whitelist) do
		if IsKindOf(class_to_spawn, class_name) then
			return true
		end
	end
	return false
end

local gofDetailClassMask = const.gofDetailClassMask

---
--- Checks if an object can be attached to another object based on various conditions.
---
--- @param obj AutoAttachObject The object to attach to.
--- @param attach table The attachment configuration.
--- @param class string The class of the object to be attached.
--- @param context string The context of the attachment (e.g. "placementcursor", "shapeshifter").
--- @return boolean, string Whether the attachment is allowed, and the detail class to use.
---
function PlaceCheck(obj, attach, class, context)
	if not obj:ShouldAttach(attach) then
		return false
	end
	
	-- placement cursor check
	if context == "placementcursor" then
		if not attach.show_at_placement and not attach.placement_only then
			return false
		end
	elseif attach.placement_only then
		return false
	end
	if attach.required_state and IsKindOf(obj, "AutoAttachObject") and attach.required_state ~= obj.auto_attach_mode then
		return false
	end

	-- condition check
	local condition = attach.condition
	if condition then
		assert(type(condition) == "function" or type(condition) == "string")
		if type(condition) == "function" then
			if not condition(obj, attach) then
				return false
			end
		else
			if obj:HasMember(condition) and not obj[condition] then
				return false
			end
		end
	end
	
	local detail_class = s_AutoAttachedLightDetailsBaseObject and
		IsKindOf(g_Classes[class], "Light") and
		s_AutoAttachedLightDetailsBaseObject.AllAttachedLightsToDetailLevel		
	detail_class = detail_class or (attach.DetailClass ~= "Default" and attach.DetailClass)
	if not detail_class then
		-- try to extract from the class
		local detail_mask = GetClassGameFlags(class, gofDetailClassMask)
		local detail_from_class = GetDetailClassMaskName(detail_mask)
		detail_class = detail_from_class ~= "Default" and detail_from_class
	end
	local forced_lod_min = rawget(obj, "is_forced_lod_min") or obj:GetForcedLODMin()
	if forced_lod_min and detail_class ~= "Essential" then
		return false
	end
	
	return true, detail_class
end

---
--- Places an object at the specified spot on the given object.
---
--- @param obj table The object to attach the new object to.
--- @param spot number The spot index on the object to attach the new object to.
--- @param class string The class name of the object to place.
--- @param context string The context in which the object is being placed, either "placementcursor" or "shapeshifter".
--- @return table|nil The newly placed object, or nil if the placement failed.
---
function PlaceAtSpot(obj, spot, class, context)
	local o
	if g_Classes[class] then
		if context == "placementcursor" then
			if g_Classes[class]:IsKindOfClasses("TerrainDecal", "BakedTerrainDecal") then
				o = PlaceObject("PlacementCursorAttachmentTerrainDecal")
			else
				o = PlaceObject("PlacementCursorAttachment")
			end
			o:ChangeClass(class)
			AutoAttachObjects(o, "placementcursor")
		elseif context == "shapeshifter" and not IsObjectClassAllowedInShapeshifter(g_Classes[class]) then
			o = PlaceObject("Shapeshifter", nil, const.cofComponentAttach)
			if IsValidEntity(class) then
				o:ChangeEntity(class)
			end
		else
			o = PlaceObject(class, nil, const.cofComponentAttach)
		end
	else
		print("once", 'AutoAttach: unknown class/particle "' .. class .. '" for [object "' .. obj.class .. '", spot "' .. obj:GetSpotName(spot) .. '"]')
	end
	if not o then
		return
	end
	local err = obj:Attach(o, spot)
	if err then
		print("once", "Error attaching", o.class, "to", obj.class, ":", err)
		return
	end
	o:SetGameFlags(const.gofAutoAttach)
	if not IsKindOf(obj, "Shapeshifter") then
		obj:OnAttachCreated(o, spot)
	end
	if IsKindOf(o, "AutoAttachCallback") then
		o:OnAttachToParent(obj, spot)
	end

	return o
end

if FirstLoad then
	Attaches = {}  -- global table that keeps the inherited auto_attaches
end

--- Attaches objects to the placement cursor.
---
--- @param obj table The object to attach objects to.
function AutoAttachObjectsToPlacementCursor(obj)
	AutoAttachObjects(obj, "placementcursor")
end

--[Deprecated]
---
--- Attaches objects to the Shapeshifter.
---
--- @param obj table The object to attach objects to.
function AutoAttachObjectsToShapeshifter(obj)
	AutoAttachObjects(obj)
end

---
--- Attaches objects to the Shapeshifter.
---
--- @param obj table The object to attach objects to.
function AutoAttachShapeshifterObjects(obj)
	AutoAttachObjects(obj, "shapeshifter")
end

local function CanInheritColorization(parent_entity, child_entity)
	return true
end

---
--- Retrieves the auto-attach table for the specified entity.
---
--- @param entity string The name of the entity.
--- @param auto_attach table|nil The existing auto-attach table for the entity.
--- @return table The auto-attach table for the entity.
function GetEntityAutoAttachTable(entity, auto_attach)
	auto_attach = auto_attach or false
	
	local states = GetStates(entity)
	for _, state in ipairs(states) do
		local spbeg, spend = GetAllSpots(entity, state)
		for spot = spbeg, spend do
			local str = GetSpotAnnotation(entity, spot)
			if str and #str > 0 then
				local item
				for w in string.gmatch(str,"%s*(.[^,]+)[, ]?") do
					local lw = string.lower(w)
					if not item then
						-- auto attach description
						if lw ~= "att" and lw~="autoattach" then
							break
						end
						item = {}
						item.spot_idx = spot
					elseif lw=="show at placement" or lw=="show_at_placement" or lw=="show" then -- show at placement
						item.show_at_placement = true
					elseif lw=="placement only" or lw=="placement_only" then -- placement only
						item.placement_only = true
					elseif lw=="mirrored" or lw=="mirror" then
						item.mirrored = true
					elseif not item[2] then
						item[2] = w
						if not g_Classes[w] then
							print("once", "Invalid autoattach", w, "for entity", entity)
						end
					end
				end
				if item then
					item.inherit_colorization = CanInheritColorization(entity, item[2])
					auto_attach = auto_attach or {}
					auto_attach[state] = auto_attach[state] or {}
					table.insert(auto_attach[state], item)
				end
			end
		end
	end
	
	return auto_attach
end

local function IsAutoAttachObject(entity)
	local entity_data = EntityData and EntityData[entity] and EntityData[entity].entity
	local classes = entity_data and entity_data.class_parent and entity_data.class_parent or ""
	for class in string.gmatch(classes, "[^%s,]+%s*") do
		if IsKindOf(g_Classes[class], "AutoAttachObject") then
			return true
		end
	end
end

local function TransferMatchingIdleAttachesToAllState(auto_attach, states)
	local idle_attaches = auto_attach["idle"]
	if not idle_attaches then return end
	
	local attach_modes
	for _, attach in ipairs(idle_attaches) do
		if attach.required_state then
			attach_modes = true
			break
		end
	end
	if not attach_modes then return end
	
	for _, state in ipairs(states) do
		auto_attach[state] = auto_attach[state] or {}
		table.iappend(auto_attach[state], idle_attaches)
	end
end

-- build autoattach table
---
--- Rebuilds the autoattach table for all entities in the game.
---
--- This function is called when the game entities are loaded, or when an AutoAttachPreset is saved.
---
--- It iterates through all entities, checks if they are AutoAttachObjects, and then builds the autoattach table for each entity.
--- The autoattach table contains information about which objects should be automatically attached to the entity.
---
--- If an entity has autoattach data defined in presets, that data is used to build the autoattach table.
--- The function also ensures that autoattach data is transferred to all states of the entity, not just the "idle" state.
---
--- @function RebuildAutoattach
--- @return nil
function RebuildAutoattach()
	if not config.LoadAutoAttachData then return end
	
	local ae = GetAllEntities()
	for entity, _ in sorted_pairs(ae) do
		local auto_attach = IsAutoAttachObject(entity) and GetEntityAutoAttachTable(entity)
		auto_attach = GetEntityAutoAttachTableFromPresets(entity, auto_attach)
		if auto_attach then
			local states = GetStates(entity)
			table.remove_value(states, "idle")
			if #states > 0 then
				-- transfer auto attaches to all states since AutoAttachEditor can define only in "idle" state
				TransferMatchingIdleAttachesToAllState(auto_attach, states)
			end
			Attaches[entity] = auto_attach
		else
			Attaches[entity] = nil
		end
	end
end

OnMsg.EntitiesLoaded = RebuildAutoattach

function OnMsg.PresetSave(name)
	local class = g_Classes[name]
	if IsKindOf(class, "AutoAttachPreset") then
		RebuildAutoattach()
	end
end

local function PlaceFadingObjects(category, init_pos)
	local ae = GetAllEntities()
	local init_pos = init_pos or GetTerrainCursor()
	local pos = init_pos
	for k,v in pairs(ae) do
		if EntityData[k] and EntityData[k].entity and EntityData[k].entity.fade_category == category then
			local o = PlaceObject(k)
			o:ChangeEntity(k)
			o:SetPos(pos)
			o:SetGameFlags(const.gofPermanent)
			pos = pos + point(10*guim, 0)
			if (pos:x() / (600*guim) > 0) then
				pos = point(init_pos:x(), pos:y() + 20*guim)
			end
		elseif not EntityData[k] then
			print("No EntityData for: ", k)
		elseif EntityData[k] and not EntityData[k].entity then
			print("No EntityData[].entity for: ", k)
		end
	end
end

---
--- Utility function to place fading objects of different categories at specified positions on the terrain.
---
--- @param category string The category of fading objects to place
--- @param init_pos point The initial position to start placing the objects
function TestFadeCategories(category, init_pos)
	-- Implementation details omitted
end
function TestFadeCategories()
	local cat = {
		"PropsUltraSmall",
		"PropsSmall",
		"PropsMedium",
		"PropsBig",
	}
	local pos = point(100*guim, 100*guim)
	for i=1, #cat do
		PlaceFadingObjects(cat[i], pos)
		pos = pos + point(0, 100*guim)
	end
end

---
--- Utility function to get the count of autoattach spots for all entities in the game.
---
--- @param filter_count number The minimum number of autoattach spots to include in the output
function GetEntitiesAutoattachCount(filter_count)
	local el = GetAllEntities()
	local filter_count = filter_count or 30
	for k,v in pairs(el) do  
		local s,e = GetSpotRange(k, EntityStates["idle"], "Autoattach") 
		if (e-s) > filter_count then 
			print(k, e-s)
		end
	end
end

---
--- Lists the autoattach spots for the given entity.
---
--- @param entity string The entity to list the autoattach spots for.
function ListEntityAutoattaches(entity)
	local s,e = GetSpotRange(entity, EntityStates["idle"], "Autoattach") 
	for i=s, e do
		local annotation = GetSpotAnnotation(entity, i)
		print(i, annotation)
	end
end

---------------------- AutoAttach editor ----------------------


local function FindArtSpecById(id)
	local spec = EntitySpecPresets[id]
	if not spec then
		local idx = string.find(id, "_[0-9]+$")
		if idx then
			spec = EntitySpecPresets[string.sub(id, 0, idx - 1)]
		end
	end
	return spec
end

local function GenerateMissingEntities()
	local all_entities = GetAllEntities()
	local to_create = {}
	for entity in pairs(all_entities) do
		local spec = FindArtSpecById(entity)
		if spec and not AutoAttachPresets[entity] and string.find(spec.class_parent, "AutoAttachObject", 1, true) then
			table.insert(to_create, entity)
		end
	end

	if #to_create > 0 then
		for _, entity in ipairs(to_create) do
			local preset = AutoAttachPreset:new({id = entity})
			preset:Register()
			preset:UpdateSpotData()
			Sleep(1)
		end

		AutoAttachPreset:SortPresets()
		ObjModified(Presets.AutoAttachPreset)
	end
end

---
--- Gets a table of all the spots for the given entity.
---
--- @param entity string The name of the entity to get the spots for.
--- @return table A table where the keys are the spot names and the values are tables of spot indices.
---
function GetEntitySpots(entity)
	if not IsValidEntity(entity) then return {} end
	local states = GetStates(entity)
	local idle = table.find(states, "idle")
	if not idle then
		print("WARNING: No idle state for", entity, "cannot fetch spots.")
		return {}
	end
	
	local spots = {}
	local spbeg, spend = GetAllSpots(entity, "idle")
	for spot = spbeg, spend do
		local str = GetSpotName(entity, spot) 
		spots[str] = spots[str] or {}
		table.insert(spots[str], spot)
	end

	return spots
end

local zeropoint = point(0, 0, 0)
---
--- Gets the auto-attach table for the given entity by combining the rules from the entity's auto-attach preset.
---
--- @param entity string The name of the entity to get the auto-attach table for.
--- @param attach_table table The initial auto-attach table to fill.
--- @return table The filled auto-attach table.
---
function GetEntityAutoAttachTableFromPresets(entity, attach_table)
	local preset = AutoAttachPresets[entity]
	if not preset then return attach_table end
	
	local spots
	for _, spot in ipairs(preset) do
		for _, rule in ipairs(spot) do
			attach_table = rule:FillAutoAttachTable(attach_table, entity, preset)
		end
	end

	return attach_table
end

DefineClass.AutoAttachRuleBase = {
	__parents = { "PropertyObject" },
	parent = false,
}

---
--- Fills an auto-attach table with the rules defined by this AutoAttachRuleBase instance.
---
--- @param attach_table table The auto-attach table to fill.
--- @param entity string The name of the entity to attach to.
--- @param preset table The auto-attach preset for the entity.
--- @return table The filled auto-attach table.
---
function AutoAttachRuleBase:FillAutoAttachTable(attach_table, entity, preset)
	return attach_table
end

---
--- Checks if the AutoAttachRuleBase is active.
---
--- @return boolean True if the rule is active, false otherwise.
---
function AutoAttachRuleBase:IsActive()
	return false
end

---
--- Called when a new instance of the AutoAttachRuleBase class is created in the editor.
---
--- @param parent table The parent object of the new instance.
--- @param ged table The editor GUI object.
--- @param is_paste boolean True if the instance was pasted, false otherwise.
---
function AutoAttachRuleBase:OnEditorNew(parent, ged, is_paste)
	self.parent = parent
end

local function GetSpotsCombo(entity_name)
	local t = {}
	local spots = GetEntitySpots(entity_name)
	for spot_name, indices in sorted_pairs(spots) do
		for i = 1, #indices do
			table.insert(t, spot_name .. " " .. i)
		end
	end
	return t
end


DefineClass.AutoAttachRuleInherit = {
	__parents = { "AutoAttachRuleBase" },
	properties = {
		{ id = "parent_entity", category = "Rule", name = "Parent Entity", editor = "combo", items = function() return ClassDescendantsCombo("AutoAttachObject") end, default = "", },
		{ id = "spot", category = "Rule", name = "Spot", editor = "combo", items = function(obj) return GetSpotsCombo(obj:GetParentEntity()) end, default = "", },
	},
}

---
--- Gets the parent entity for the AutoAttachRuleInherit.
---
--- @return string The name of the parent entity.
---
function AutoAttachRuleInherit:GetParentEntity()
	return self.parent_entity
end

---
--- Gets the spot name and index from the spot property.
---
--- @return string|nil The spot name, or nil if the spot property is not in the expected format.
--- @return number|nil The spot index, or nil if the spot property is not in the expected format.
---
function AutoAttachRuleInherit:GetSpotAndIdx()
	local spot = self.spot
	local break_idx = string.find(spot, "%d+$")
	if not break_idx then return end
	local spot_name = string.sub(spot, 1, break_idx - 2)
	local spot_idx = tonumber(string.sub(spot, break_idx))
	if spot_name and spot_idx then
		return spot_name, spot_idx
	end
end

---
--- Gets a string representation of the editor view for the AutoAttachRuleInherit.
---
--- @return string A string representing the editor view for the AutoAttachRuleInherit.
---
function AutoAttachRuleInherit:GetEditorView()
	local str = string.format("Inherit %s from %s", self.spot or "[SPOT]", self:GetParentEntity() or "[ENTITY]")
	if not self:FindInheritedSpot() then
		str = "<color 168 168 168>" .. str .. "</color>"
	end
	return str
end

---
--- Finds the inherited spot for the AutoAttachRuleInherit.
---
--- @return table|nil The AutoAttachPost object for the inherited spot, or nil if the spot could not be found.
--- @return string|nil The name of the parent entity, or nil if the spot could not be found.
--- @return table|nil The parent preset, or nil if the spot could not be found.
---
function AutoAttachRuleInherit:FindInheritedSpot()
	local entity = self:GetParentEntity()
	local parent_preset = AutoAttachPresets[entity]
	if not parent_preset then return end
	local spot_name, spot_idx = self:GetSpotAndIdx()
	if not spot_name or not spot_idx then return end
	local aaspot_idx, aapost_obj = parent_preset:GetSpot(spot_name, spot_idx)
	if not aapost_obj then return end

	return aapost_obj, entity, parent_preset
end

---
--- Fills an auto-attach table with the inherited auto-attach rules.
---
--- @param attach_table table The auto-attach table to fill.
--- @param entity string The name of the parent entity.
--- @param preset table The parent preset.
--- @return table The filled auto-attach table.
---
function AutoAttachRuleInherit:FillAutoAttachTable(attach_table, entity, preset)
	local spot, parent_entity, parent_preset = self:FindInheritedSpot()
	if not spot then return attach_table end

	for _, rule in ipairs(spot) do
		attach_table = rule:FillAutoAttachTable(attach_table, parent_entity, parent_preset, self.parent)
	end
	return attach_table
end

---
--- Checks if the AutoAttachRuleInherit is active.
---
--- @return boolean True if the inherited spot for the AutoAttachRuleInherit was found, false otherwise.
---
function AutoAttachRuleInherit:IsActive()
	local spot, _, _ = self:FindInheritedSpot()
	return not not spot
end

DefineClass.AutoAttachRule = {
	__parents = { "AutoAttachRuleBase" },
	properties = {
		{ id = "attach_class", category = "Rule", name = "Object Class", editor = "combo", items = function() return ClassDescendantsCombo("CObject") end, default = "", },
		{ id = "quick_modes", default = false, no_save = true, editor = "buttons", category = "Rule", buttons = {
			{name = "ParSystem", func = "QuickSetToParSystem"},
		}},
		{ id = "offset", category = "Rule", name = "Offset", editor = "point", default = point(0, 0, 0), },
		{ id = "axis" , category = "Rule", name = "Axis", editor = "point", default = point(0, 0, 0), },
		{ id = "angle", category = "Rule", name = "Angle", editor = "number", default = 0, scale = "deg" },
		{ id = "member", category = "Rule", name = "Member", help = "The name of the property of the parent object that should be pointing to the attach object.", editor = "text", default = "", },
		{ id = "required_state", category = "Rule", name = "Attach State", help = "Conditional attachment", default = "", editor = "combo", items = function(obj)
			return obj and obj.parent and obj.parent.parent and obj.parent.parent:GuessPossibleAutoattachStates() or {}
		end, },
		{ id = "GameStatesFilter", name="Game State", category = "Rule", editor = "set", default = set(), three_state = true, items = function() return GetGameStateFilter() end },
		{ id = "DetailClass", category = "Rule", name = "Detail Class Override", editor = "dropdownlist",
			items = {"Default", "Essential", "Optional", "Eye Candy"}, default = "Default",
		},
		{ id = "inherited_values", no_edit = true, editor = "prop_table", default = false, },
	},
	parent = false,
}

---
--- Checks if the AutoAttachRule is active.
---
--- @return boolean True if the AutoAttachRule has a non-empty attach_class, false otherwise.
---
function AutoAttachRule:IsActive()
	return self.attach_class ~= ""
end


---
--- Quickly sets the `attach_class` property of the `AutoAttachRule` to "ParSystem" and marks the object as modified.
---
--- This is a convenience function to quickly set the `attach_class` property to a common value.
---
--- @function AutoAttachRule:QuickSetToParSystem
--- @return nil
function AutoAttachRule:QuickSetToParSystem()
	self.attach_class = "ParSystem"
	ObjModified(self)
end

---
--- Resolves a condition function for the AutoAttachRule based on the GameStatesFilter property.
---
--- The resolved condition function checks if the current game state matches the GameStatesFilter. If the filter is empty, the condition function returns false. Otherwise, it returns a function that checks each game state in the filter and returns true only if all the required game states are active and all the excluded game states are inactive.
---
--- @return function|false The resolved condition function, or false if the GameStatesFilter is empty.
---
function AutoAttachRule:ResolveConditionFunc()
	local gamestates_filters = self.GameStatesFilter
	if not gamestates_filters or not next(gamestates_filters) then 
		return false
	end

	return function(obj, attach)
		if gamestates_filters then
			for key, value in pairs(gamestates_filters) do
				if value then
					if not GameState[key] then return false end
				else
					if GameState[key] then return false end
				end
			end
		end

		return true
	end
end

---
--- Gets a clean list of inherited property values for the AutoAttachRule.
---
--- The inherited property values are stored in the `inherited_values` table of the AutoAttachRule. This function filters out any inherited property values that do not have a corresponding inherited property defined in the `GetInheritedProps()` function.
---
--- @return table|false A table of clean inherited property values, or `false` if there are no inherited properties or values.
---
function AutoAttachRule:GetCleanInheritedPropertyValues()
	local inherited_values = self.inherited_values
	if not inherited_values then
		return false
	end
	local inherited_props = self:GetInheritedProps()
	if not inherited_props or #inherited_props == 0 then
		return false
	end
	local clean_value_list = {}
	for _, prop in ipairs(inherited_props) do
		local value = inherited_values[prop.id]
		if value ~= nil then
			clean_value_list[prop.id] = value
		end
	end
	return clean_value_list
end

---
--- Fills an auto-attach table with information about attaching entities to a specified spot.
---
--- @param attach_table table The auto-attach table to fill.
--- @param entity table The entity to attach.
--- @param preset table The preset to use for the attachment.
--- @param spot table The spot to attach the entity to.
--- @return table The updated auto-attach table.
---
function AutoAttachRule:FillAutoAttachTable(attach_table, entity, preset, spot)
	if self.attach_class == "" then
		return attach_table
	end
	spot = spot or self.parent
	attach_table = attach_table or {}
	
	local attach_table_idle = attach_table["idle"] or {}
	attach_table["idle"] = attach_table_idle
	
	local istart, iend = GetSpotRange(spot.parent.id, "idle", spot.name)
	if istart < 0 then
		print(string.format("Warning: Could not find '%s' spot range for '%s'", spot.name, entity))
	else
		table.insert(attach_table_idle, {
			spot_idx = istart + spot.idx - 1,
			[2] = self.attach_class,
			offset = self.offset,
			axis = self.axis ~= zeropoint and self.axis,
			angle = self.angle ~= 0 and self.angle,
			member = self.member ~= "" and self.member,
			required_state = self.required_state ~= "" and self.required_state or false,
			condition = self:ResolveConditionFunc() or false, 
			DetailClass = self.DetailClass ~= "Default" and self.DetailClass,
			inherited_properties = self:GetCleanInheritedPropertyValues(),
			inherit_colorization = preset.PropagateColorization and CanInheritColorization(entity, self.attach_class),
		})
	end
	
	return attach_table
end

---
--- Generates a string representation of the AutoAttachRule's editor view.
---
--- @return string The editor view string.
---
function AutoAttachRule:GetEditorView()
	local str
	if self.attach_class == "ParSystem" then
		str = "Particles <color 198 25 198>" .. (self.inherited_values and self.inherited_values["ParticlesName"] or "?") .. "</color>"
	else
		str = "Attach <color 75 105 198>" .. (self.attach_class or "?") .. "</color>"
	end
	str = str .. " (" .. self.DetailClass .. ")"
	if self.required_state ~= "" then
		str = str .. " : <color 20 120 20>" .. self.required_state .. "</color>"
	end
	if self.attach_class == "" then
		str = "<color 168 168 168>" .. str .. "</color>"
	end
	return str
end

---
--- Sets the attach_class property of the AutoAttachRule.
--- If the parent's parent's id matches the provided value, the attach_class is set to an empty string and the function returns false.
--- Otherwise, the attach_class is set to the provided value and the function returns true.
---
--- @param value string The new value for the attach_class property.
--- @return boolean Whether the attach_class was successfully set.
---
function AutoAttachRule:Setattach_class(value)
	if self.parent and self.parent.parent and self.parent.parent.id == value then
		value = ""
		return false
	end
	self.attach_class = value
end

---
--- Gets the inherited properties of the AutoAttachRule.
---
--- @return table The inherited properties of the AutoAttachRule.
---
function AutoAttachRule:GetInheritedProps()
	local properties = {}
	local class_obj = g_Classes[self.attach_class]
	if not class_obj then
		return properties
	end
	
	local orig_properties = PropertyObject.GetProperties(self)
	local properties_of_target_entity = class_obj:GetProperties()
	for _, prop in ipairs(properties_of_target_entity) do
		if prop.autoattach_prop then
			assert(not table.find(orig_properties, "id", prop.id),
				string.format("Property %s conflict between AutoAttachRule and %s", prop.id, self.attach_class))
			prop = table.copy(prop)
			prop.dont_save = true
			table.insert(properties, prop)
		end
	end
	return properties
end

---
--- Gets the properties of the AutoAttachRule, including any inherited properties.
---
--- @return table The properties of the AutoAttachRule.
---
function AutoAttachRule:GetProperties()
	local properties = PropertyObject.GetProperties(self)
	local class_obj = g_Classes[self.attach_class]
	if not class_obj then
		return properties
	end

	properties = table.copy(properties)
	properties = table.iappend(properties, self:GetInheritedProps())
	return properties
end

---
--- Sets a property of the AutoAttachRule, handling inherited properties.
---
--- @param id string The ID of the property to set.
--- @param value any The new value for the property.
---
function AutoAttachRule:SetProperty(id, value)
	if table.find(self:GetInheritedProps(), "id", id) then
		self.inherited_values = self.inherited_values or {}
		self.inherited_values[id] = value
		return
	end
	PropertyObject.SetProperty(self, id, value)
end

---
--- Gets the value of a property, handling inherited properties.
---
--- @param id string The ID of the property to get.
--- @return any The value of the property.
---
function AutoAttachRule:GetProperty(id)
	if self.inherited_values and self.inherited_values[id] ~= nil then
		return self.inherited_values[id]
	end
	
	return PropertyObject.GetProperty(self, id)
end

---
--- Called when a property of the AutoAttachRule is edited in the editor.
---
--- Rebuilds the autoattach, recreates the demo object, and updates the autoattach mode for all objects of the same class.
---
--- @param prop_id string The ID of the property that was edited.
--- @param old_value any The old value of the property.
--- @param ged table The GED (Game Editor) object.
--- @return boolean False if the object is not an AutoAttachObject, otherwise true.
---
function AutoAttachRule:OnEditorSetProperty(prop_id, old_value, ged)
	RebuildAutoattach()
	ged:ResolveObj("SelectedPreset"):RecreateDemoObject(ged)
	local id = self.parent.parent.id
	local class = rawget(_G, id)
	if class and not class:IsKindOf("AutoAttachObject") then
		return false
	end
	MapForEach("map", id, function(obj)
		obj:SetAutoAttachMode(obj:GetAutoAttachMode())
	end)
end

---
--- Gets the maximum number of colorization materials for the attached object.
---
--- If the attached object is a WaterObj, the maximum number of colorization materials is 3.
--- Otherwise, the maximum number of colorization materials is the value returned by ColorizationMaterialsCount for the attached class, if the attached class is a valid entity.
---
--- @return integer The maximum number of colorization materials for the attached object.
---
function AutoAttachRule:GetMaxColorizationMaterials()
	if IsKindOf(_G[self.attach_class], "WaterObj") then return 3 end
	return self.attach_class ~= "" and IsValidEntity(self.attach_class) and ColorizationMaterialsCount(self.attach_class) or 0
end

---
--- Determines whether the colorization properties of the AutoAttachRule should be read-only.
---
--- This function always returns `false`, indicating that the colorization properties are not read-only.
---
--- @return boolean Always returns `false`.
---
function AutoAttachRule:ColorizationReadOnlyReason()
	return false
end

---
--- Determines whether the colorization properties of the AutoAttachRule should be read-only.
---
--- This function checks if the `PropagateColorization` property of the parent AutoAttachRule is true. If so, it returns true, indicating that the colorization properties should be read-only. Otherwise, it checks the maximum number of colorization materials for the attached object and returns true if the current index `i` is greater than the maximum.
---
--- @param i integer The index of the colorization property being checked.
--- @return boolean True if the colorization property should be read-only, false otherwise.
---
function AutoAttachRule:ColorizationPropsNoEdit(i)
	if self.parent.parent.PropagateColorization then
		return true
	end
	return self:GetMaxColorizationMaterials() < i
end

DefineClass.AutoAttachSpot = {
	__parents = { "PropertyObject", "Container" },

	properties = {
		{ id = "name", name = "Spot Name", editor = "text", default = "", read_only = true },
		{ id = "idx", name = "Number", editor = "number", default = -1, read_only = true, },
		{ id = "original_index", name = "Original Index", editor = "number", default = -1, read_only = true, },
	},

	annotated_autoattach = false,
	EditorView = Untranslated("<Color><name> <idx><opt(u(attach_class), ' - <color 32 192 32>')> <AnnotatedAutoattachMsg>"),
	parent = false,
	ContainerClass = "AutoAttachRuleBase",
}

---
--- Returns a color string indicating whether the AutoAttachSpot has something attached.
---
--- If the AutoAttachSpot has no attached rules, this function returns "<color 168 168 168>", otherwise it returns an empty string.
---
--- @return string The color string indicating the attachment state of the AutoAttachSpot.
---
function AutoAttachSpot:Color()
	return not self:HasSomethingAttached() and "<color 168 168 168>" or ""
end

---
--- Determines whether the AutoAttachSpot has any active rules attached.
---
--- If the AutoAttachSpot has no attached rules, this function returns `false`. Otherwise, it iterates through the attached rules and returns `true` if any of them are active.
---
--- @return boolean `true` if the AutoAttachSpot has any active rules attached, `false` otherwise.
---
function AutoAttachSpot:HasSomethingAttached()
	if #self == 0 then return false end
	for _, rule in ipairs(self) do
		if rule:IsActive() then
			return true
		end
	end
	return false
end

---
--- Returns a string indicating whether the AutoAttachSpot has annotated autoattach information.
---
--- If the AutoAttachSpot has annotated autoattach information, this function returns a colored string with the annotated information. Otherwise, it returns an empty string.
---
--- @return string The string indicating the annotated autoattach information of the AutoAttachSpot.
---
function AutoAttachSpot:AnnotatedAutoattachMsg()
	if not self.annotated_autoattach then return "" end
	return "<color 158 22 22>" .. self.annotated_autoattach
end

---
--- Creates a new AutoAttachRule and adds it to the given object.
---
--- @param root table The root object that contains the AutoAttachRule.
--- @param obj table The object to which the new AutoAttachRule will be added.
---
function AutoAttachSpot.CreateRule(root, obj)
	obj[#obj + 1] = AutoAttachRule:new({parent = obj})
	ObjModified(root)
	ObjModified(obj)
end

---
--- Returns a list of commonly used attach classes from all AutoAttachPreset entities.
---
--- This function iterates through all AutoAttachPreset entities, collects the unique attach classes used in their AutoAttachRules, and returns a sorted list of these classes.
--- Classes that are only used once are excluded from the returned list.
---
--- @return table A sorted list of commonly used attach classes.
---
function CommonlyUsedAttachItems()
	local ret = {}
	ForEachPreset("AutoAttachPreset", function(preset)
		for _, rule in ipairs(preset) do
			for _, subrule in ipairs(rule) do
				local class = rawget(subrule, "attach_class")
				if class and class ~= "" then
					ret[class] = (ret[class] or 0) + 1
				end
			end
		end
	end)
	for class, count in pairs(ret) do
		if count == 1 then
			ret[class] = nil
		end
	end
	return table.keys2(ret, "sorted")
end

DefineClass.AutoAttachPresetFilter = {
	__parents = { "GedFilter" },
	properties = {
		{ id = "NonEmpty", name = "Only show non-empty entries", default = false, editor = "bool" },
		{ id = "HasAttach", name = "Has attach of class", default = false, editor = "combo", items = CommonlyUsedAttachItems },
		{ id = "_", editor = "buttons", default = false, buttons = { { name = "Add new AutoAttach entity", func = "AddEntity" } } },
	},
}

---
--- Filters an AutoAttachPreset object based on the specified filter criteria.
---
--- @param obj table The AutoAttachPreset object to filter.
--- @return boolean True if the object passes the filter, false otherwise.
---
function AutoAttachPresetFilter:FilterObject(obj)
	if self.NonEmpty then
		for _, rule in ipairs(obj) do
			for _, subrule in ipairs(rule) do
				if subrule:IsKindOf("AutoAttachRule") and subrule.attach_class ~= "" then
					return true
				end
			end
		end
		return false
	end
	local class = self.HasAttach
	if class then
		for _, rule in ipairs(obj) do
			for _, subrule in ipairs(rule) do
				if subrule:IsKindOf("AutoAttachRule") and subrule.attach_class == class then
					return true
				end
			end
		end
		return false
	end
	return true
end

---
--- Adds a new AutoAttach entity to the AutoAttachPreset.
---
--- @param root table The root object of the GED editor.
--- @param prop_id string The ID of the property being edited.
--- @param ged table The GED editor instance.
---
function AutoAttachPresetFilter:AddEntity(root, prop_id, ged)
	local entities = {}
	ForEachPreset("EntitySpec", function(preset)
		if not string.find(preset.class_parent, "AutoAttachObject", 1, true) and not preset.id:starts_with("#") then
			entities[#entities + 1] = preset.id
		end
	end)

	local entity = ged:WaitListChoice(entities, "Choose entity to add:")
	if not entity then
		return
	end

	local spec = EntitySpecPresets[entity]
	if spec.class_parent == "" then
		spec.class_parent = "AutoAttachObject"
	else
		spec.class_parent = spec.class_parent .. ",AutoAttachObject"
	end

	GedSetUiStatus("add_autoattach_entity", "Saving ArtSpec...")
	EntitySpec:SaveAll()
	self.NonEmpty = false
	self.HasAttach = false
	GenerateMissingEntities()
	ged:SetSelection("root", { 1, table.find(Presets.AutoAttachPreset.Default, "id", entity) })
	GedSetUiStatus("add_autoattach_entity")

	ged:ShowMessage(Untranslated("Attention!"), Untranslated("You need to commit both the assets and the project folder!"))
end

DefineClass.AutoAttachPreset = {
	__parents = { "Preset" },

	properties = {
		{ id = "Id", read_only = true, },
		{ id = "SaveIn", read_only = true, },
		{ id = "help", editor = "buttons", buttons = {{name = "Go to ArtSpec", func = "GotoArtSpec"}}, default = false,},
		{ id = "PropagateColorization", editor = "bool", default = true },
	},

	GlobalMap = "AutoAttachPresets",
	ContainerClass = "AutoAttachSpot",
	GedEditor = "GedAutoAttachEditor",
	EditorMenubar = "Editors.Art",
	EditorMenubarName = "AutoAttach Editor",
	EditorIcon = "CommonAssets/UI/Icons/attach attachment paperclip.png",
	FilterClass = "AutoAttachPresetFilter",

	EnableReloading = false,
}

--- Gets a list of possible auto-attach states for the given AutoAttachPreset.
---
--- @param self AutoAttachPreset The AutoAttachPreset instance.
--- @return table A list of possible auto-attach modes.
function AutoAttachPreset:GuessPossibleAutoattachStates()
	return GetEntityAutoAttachModes(nil, self.id)
end

--- Provides the editor context for the AutoAttachPreset class.
---
--- @return table The editor context for the AutoAttachPreset class.
function AutoAttachPreset:EditorContext()
	local context = Preset.EditorContext(self)
	context.Classes = {}
	context.ContainerTree = true
	return context
end

--- Provides the editor items menu for the AutoAttachPreset class.
---
--- @return table The editor items menu for the AutoAttachPreset class.
function AutoAttachPreset:EditorItemsMenu()
	return {}
end

function AutoAttachPreset:GotoArtSpec(root)
	local editor = OpenPresetEditor("EntitySpec")
	local spec = self:GetEntitySpec()
	local root = editor:ResolveObj("root")
	local group_idx = table.find(root, root[spec.group])
	local idx = table.find(root[spec.group], spec)
	editor:SetSelection("root", {group_idx, idx})
end

--- Performs post-load initialization for an AutoAttachPreset instance.
---
--- This function sets the `parent` field for each item in the AutoAttachPreset, as well as for each sub-item within each item. It then calls the `Preset.PostLoad` function to perform any additional post-load initialization.
---
--- @param self AutoAttachPreset The AutoAttachPreset instance to initialize.
function AutoAttachPreset:PostLoad()
	for idx, item in ipairs(self) do
		item.parent = self
		for _, subitem in ipairs(item) do
			subitem.parent = item
		end
	end
	Preset.PostLoad(self)
end

--- Generates the code for the AutoAttachPreset instance.
---
--- This function first updates the spot data by calling `AutoAttachPreset:UpdateSpotData()`. It then removes any spots that do not have something attached, and removes the `original_index` and `annotated_autoattach` fields from the remaining spots. If there are any spots with something attached, it calls `Preset.GenerateCode(self, code)` to generate the code. Finally, it calls `AutoAttachPreset:UpdateSpotData()` again to write the `original_index` and `annotated_autoattach` fields back to the structure.
---
--- @param self AutoAttachPreset The AutoAttachPreset instance to generate code for.
--- @param code table The code table to generate the code into.
function AutoAttachPreset:GenerateCode(code)
	self:UpdateSpotData() -- to read save_in
	
	-- drop redundant/unneeded data
	local has_something_attached = false
	for i = #self, 1, -1 do
		local spot = self[i]
		if not spot:HasSomethingAttached() then
			table.remove(self, i)
		else
			spot.original_index = nil
			spot.annotated_autoattach = nil
			has_something_attached = true
			if not spot[#spot]:IsActive() then
				table.remove(spot, #spot)
			end
		end
	end
	if has_something_attached then
		Preset.GenerateCode(self, code)
	end

	self:UpdateSpotData() -- to write original_index and annotated_autoattach back to the structure
end

--- Gets the spot with the given name and index from the AutoAttachPreset.
---
--- @param self AutoAttachPreset The AutoAttachPreset instance to search.
--- @param name string The name of the spot to find.
--- @param idx integer The index of the spot to find.
--- @return integer, AutoAttachSpot The index of the spot in the AutoAttachPreset, and the spot itself.
function AutoAttachPreset:GetSpot(name, idx)
	for i, value in ipairs(self) do
		if value.name == name and value.idx == idx then
			return i, value
		end
	end
end

--- Updates the spot data for the AutoAttachPreset.
---
--- This function first gets the entity specification for the AutoAttachPreset. If there is no entity specification, it returns. It then gets the spots for the entity and drops any spots that are beyond the end of the spots list. 
---
--- For each spot in the entity, it checks if the spot already exists in the AutoAttachPreset. If it does, it updates the `original_index` and `annotated_autoattach` fields. If it doesn't, it creates a new `AutoAttachSpot` and adds it to the AutoAttachPreset.
---
--- Finally, it sorts the spots in the AutoAttachPreset by name and index.
---
--- @param self AutoAttachPreset The AutoAttachPreset instance to update the spot data for.
function AutoAttachPreset:UpdateSpotData()
	local spec = self:GetEntitySpec()
	if not spec then
		return
	end
	self.save_in = spec:GetSaveIn()
	local spots = GetEntitySpots(self.id)
	
	-- drop additional spots
	for i = #self, 1, -1 do
		local entry = self[i]
		if entry.idx > (spots[entry.name] and #spots[entry.name] or -1) then
			table.remove(self, i)
		end
	end

	for spot_name, indices in pairs(spots) do
		for idx = 1, #indices do
			local internal_idx, spot = self:GetSpot(spot_name, idx)
			if spot then
				spot.original_index = indices[idx]
				spot.annotated_autoattach = GetSpotAnnotation(self.id, indices[idx])
			else
				spot = AutoAttachSpot:new({
					name = spot_name,
					idx = idx,
					original_index = indices[idx],
					annotated_autoattach = GetSpotAnnotation(self.id, indices[idx]),
				})
				table.insert(self, spot)
			end
			spot.parent = self
		end
	end

	table.sort(self, function(a, b)
		if a.name < b.name then return true end
		if a.name > b.name then return false end
		if a.idx < b.idx then return true end
		return false
	end)
end

if FirstLoad then
	GedAutoAttachEditorLockedObject = {}
	GedAutoAttachDemos = {}
end

DefineClass.AutoAttachPresetDemoObject = {
	__parents = {"Shapeshifter", "AutoAttachObject"}
}

AutoAttachPresetDemoObject.ShouldAttach = return_true

---
--- Changes the entity associated with this AutoAttachPresetDemoObject.
---
--- This function will first destroy any existing auto-attached objects, clear the
--- attach members, then change the entity associated with this object. After the
--- entity is changed, it will re-attach any objects that should be auto-attached
--- to the new entity.
---
--- @param entity string The new entity ID to associate with this object.
---
function AutoAttachPresetDemoObject:ChangeEntity(entity)
	self:DestroyAutoAttaches()
	self:ClearAttachMembers()
	Shapeshifter.ChangeEntity(self, entity)
	self:DestroyAutoAttaches()
	self:ClearAttachMembers()
	AutoAttachShapeshifterObjects(self)
end

---
--- Initializes property helpers for any attached Light objects.
---
--- This function is called to ensure that any Light objects that are
--- auto-attached to the AutoAttachPresetDemoObject have their property
--- helpers initialized. This allows the lights to be properly configured
--- and controlled through the editor.
---
--- @param self AutoAttachPresetDemoObject The AutoAttachPresetDemoObject instance.
---
function AutoAttachPresetDemoObject:CreateLightHelpers()
	self:ForEachAttach(function(attach)
		if IsKindOf(attach, "Light") then
			PropertyHelpers_Init(attach)
		end
	end)
end

---
--- Attaches any objects that should be auto-attached to this AutoAttachPresetDemoObject.
---
--- This function first calls AutoAttachShapeshifterObjects to attach any objects that should be
--- auto-attached to this object. It then calls CreateLightHelpers to initialize property helpers
--- for any Light objects that are auto-attached.
---
function AutoAttachPresetDemoObject:AutoAttachObjects()
	AutoAttachShapeshifterObjects(self)
	self:CreateLightHelpers()
end

---
--- Displays the demo object associated with the given GED.
---
--- @param ged table The GED instance associated with the demo object.
---
function AutoAttachPreset:ViewDemoObject(ged)
	local demo_obj = GedAutoAttachDemos[ged]
	if demo_obj and IsValid(demo_obj) then
		ViewObject(demo_obj)
	end
end

---
--- Recreates the demo object associated with the given GED.
---
--- If the GED has its lock_preset flag set, this function will destroy any existing
--- auto-attached objects and re-attach them. Otherwise, it will create a new
--- AutoAttachPresetDemoObject and associate it with the GED.
---
--- @param ged table The GED instance associated with the demo object.
---
function AutoAttachPreset:RecreateDemoObject(ged)
	if CurrentMap == "" then
		return
	end
	if ged and ged.context.lock_preset then
		local obj = GedAutoAttachEditorLockedObject[ged]
		obj:DestroyAutoAttaches()
		obj:ClearAttachMembers()
		AutoAttachObjects(GedAutoAttachEditorLockedObject[ged], "init")
		return
	end

	local demo_obj = GedAutoAttachDemos[ged]
	if not demo_obj or not IsValid(demo_obj) then
		demo_obj = PlaceObject("AutoAttachPresetDemoObject")
		local look_at = GetTerrainGamepadCursor()
		look_at = look_at:SetZ(terrain.GetSurfaceHeight(look_at))
		demo_obj:SetPos(look_at)
	end
	GedAutoAttachDemos[ged] = demo_obj
	demo_obj:ChangeEntity(self.id)
end

function OnMsg.GedClosing(ged_id)
	local demo_obj = GedAutoAttachDemos[GedConnections[ged_id]]
	DoneObject(demo_obj)
	GedAutoAttachDemos[GedConnections[ged_id]] = nil
end

---
--- Called when the AutoAttachPreset is selected in the editor.
---
--- Updates the spot data and recreates the demo object associated with the given GED.
---
--- @param selected boolean Whether the AutoAttachPreset is selected.
--- @param ged table The GED instance associated with the AutoAttachPreset.
---
function AutoAttachPreset:OnEditorSelect(selected, ged)
	if selected then
		self:UpdateSpotData()
		self:RecreateDemoObject(ged)
	end
end

--- Returns an error message if the ArtSpec for the AutoAttachPreset could not be found.
---
--- @return string|nil The error message, or nil if no error.
function AutoAttachPreset:GetError()
	if not self:GetEntitySpec() then
		return "Could not find the ArtSpec."
	end
end

---
--- Returns the ArtSpec for the AutoAttachPreset.
---
--- @return table|nil The ArtSpec for the AutoAttachPreset, or nil if not found.
function AutoAttachPreset:GetEntitySpec()
	return FindArtSpecById(self.id)
end

function OnMsg.GedOpened(ged_id)
	local ged = GedConnections[ged_id]
	if ged and ged:ResolveObj("root") == Presets.AutoAttachPreset then
		CreateRealTimeThread(GenerateMissingEntities)
	end
end

---
--- Opens the AutoAttach editor and optionally locks the selected entity.
---
--- @param objlist table A list of entities to select in the editor.
--- @param lock_entity boolean Whether to lock the selected entity in the editor.
---
function OpenAutoattachEditor(objlist, lock_entity)
	if not IsRealTimeThread() then
		CreateRealTimeThread(OpenAutoattachEditor, entity)
		return
	end
	lock_entity = not not lock_entity
	local target_entity
	if objlist and objlist[1] and IsValid(objlist[1]) then
		target_entity = objlist[1]
	end

	if not target_entity and lock_entity then
		print("No entity selected.")
		return
	end

	if target_entity then
		GenerateMissingEntities() -- make sure all entities are generated. Otherwise the selection may fail
	end
	
	local context = AutoAttachPreset:EditorContext()
	context.lock_preset = lock_entity
	local ged = OpenPresetEditor("AutoAttachPreset", context)
	if target_entity then
		ged:SetSelection("root", PresetGetPath(AutoAttachPresets[target_entity:GetEntity()]))
		GedAutoAttachEditorLockedObject[ged] = target_entity
	end
end

DefineClass.AutoAttachSIModulator =
{
	__parents = {"CObject", "PropertyObject"},
	properties = {
		{ id = "SIModulation", editor = "number", default = 100, min = 0, max = 255, slider = true, autoattach_prop = true },
	}
}

---
--- Sets the SI modulation value for the parent object.
---
--- If the parent object's `SIModulationManual` property is not set, this function will set the parent's `SIModulation` property to the provided `value`.
---
--- @param value number The new SI modulation value to set.
---
function AutoAttachSIModulator:SetSIModulation(value)
	local parent = self:GetParent()
	if not parent.SIModulationManual then
		parent:SetSIModulation(value)
	end
end