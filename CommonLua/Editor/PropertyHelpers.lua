-- Property Helpers are ingame objects that visualize and(or) modify an object's property. They are requested per property
-- through the property metatable field "helper". If the main object's property can be changed from Hedge, the helper should implement
-- Update method to receive notification.If modifications of the helper from the ingame editor affect the main object(or the helper) - the helper should
-- implement EditorCallback method and should have cfEditorCallback set in order to receive notification.
-- (see RelativePos helper for reference).

----------------------------------------------------------------------------------
-- Helper classes definition													--
---------------------------------------------------------------------------------- 

DefineClass.PropertyHelper = {
	__parents = { "Object" },
	flags = { cfEditorCallback = true },
	
	parent = false,
}

---
--- Clears the `gofPermanent` game flag for the `PropertyHelper` object.
---
--- This method is called during the initialization of the `PropertyHelper` object to ensure it is not marked as permanent.
---
--- @method Init
--- @return nil
function PropertyHelper:Init()
	self:ClearGameFlags(const.gofPermanent)
end

---
--- Creates a new `PropertyHelper` object.
---
--- This method is called to initialize a new `PropertyHelper` object. It ensures the object is not marked as permanent.
---
--- @method Create
--- @return nil
function PropertyHelper:Create()
end

---
--- Updates the `PropertyHelper` object with the provided `obj`, `value`, and `id`.
---
--- This method is called to notify the `PropertyHelper` object of changes to the associated property. The `PropertyHelper` object can then update its visualization or behavior accordingly.
---
--- @param obj table The object associated with the property.
--- @param value any The new value of the property.
--- @param id string The identifier of the property.
--- @return nil
function PropertyHelper:Update(obj, value, id)
end

---
--- Callback function for the editor to notify the `PropertyHelper` object of changes.
---
--- This function is called when the editor makes changes to the `PropertyHelper` object. The `action` parameter indicates the type of change that occurred.
---
--- @param action string The type of change that occurred in the editor.
--- @return nil
function PropertyHelper:EditorCallback(action)
end

---
--- Returns the parent `PropertyHelper` object.
---
--- @return table The parent `PropertyHelper` object.
function PropertyHelper:GetHelperParent()
	return self.parent
end

---
--- Adds a reference to the provided `helpers` table.
---
--- This method is called to associate the `PropertyHelper` object with a set of helper objects, such as those used for visualization or interaction.
---
--- @param helpers table The table of helper objects to associate with the `PropertyHelper`.
--- @return nil
function PropertyHelper:AddRef(helpers)
end

---------------------------------------------
--helper functions for creating PropHelpers
-------------------------------------------
local function GenericPropHelperCreate(type,info)
	local no_edit = info.property_meta.no_edit or function() end
	if GetMap() ~= "" and info.object and not no_edit(info.object, info.property_id) then
		local marker = _G[type]:new()
		marker:Create(info.object, info.property_id, info.property_meta, info.property_value, false)
		return marker
	end
end
local CreatePropertyHelpers = {
	["sradius"] = function(info,useSecondColor) 	
			local helper = PropertyHelper_SphereRadius:new()
			helper:Create(info.object, info.property_id, info.property_meta, info.property_value, useSecondColor)
			return helper
		end,
	["srange"] = function(info)
			local helper = false
			if info.object:IsKindOf("CObject") then
				helper = PropertyHelper_SphereRange:new()
				helper:Create(info.mainObject, info.object, info.property_id, info.property_meta, info.property_value)
			end
			return helper
		end,
	["relative_pos"] = function(info) return GenericPropHelperCreate("PropertyHelper_RelativePos",info) end,
	["relative_pos_list"] = function(info) return GenericPropHelperCreate("PropertyHelper_RelativePosList",info) end,
	["relative_dist"] = function(info) return GenericPropHelperCreate("PropertyHelper_RelativeDist",info) end,
	["absolute_pos"] = function(info)
		local helper_class = info.property_meta and info.property_meta.helper_class or "PropertyHelper_AbsolutePos"
		return GenericPropHelperCreate(helper_class, info)
	end,
	["terrain_rect"] = function(info) return GenericPropHelperCreate("PropertyHelper_TerrainRect",info) end,
	["volume"] = function(info) return GenericPropHelperCreate("PropertyHelper_VolumePicker", info) end,
	["box3"] = function(info)	
			local helpers = info.helpers
			if helpers then
				local helper = helpers.BoxWidth or helpers.BoxHeight or helpers.BoxDepth
				if helper then
					return helper
				end
			end
			
			local helper = PropertyHelper_Box3:new()
			helper:Create(info.object)
			return helper 
		end,
	["spotlighthelper"] = function(info)
			local helpers = info.helpers
			if helpers then
				local helper = helpers.ConeInnerAngle
				if helper then
					return helper
				end
			end
			
			local helper = PropertyHelper_SpotLight:new()
			helper:Create(info.object)
			return helper
		end,
	["scene_actor_orientation"] = function(info)
			local main_obj = info.mainObject
			local parent_helpers = info.helpers
			if rawget(main_obj, "map") and main_obj.map ~= "All" and ("Maps/" .. main_obj.map .. "/"):lower() ~= GetMap():lower() then
				return false
			end
			
			for _ , helper in pairs(parent_helpers) do
				if helper:IsKindOf("PropertyHelper_SceneActorOrientation") then
					return helper
				end
			end
			local helper = PropertyHelper_SceneActorOrientation:new()
			helper:Create(info.object, info.property_id, info.property_meta)
			return helper
		end,
			
}

-- A helper that shows a marker and measures its relative pos to the main object.
-- Property must be from type point.
DefineClass.PropertyHelper_RelativePos = {
	__parents = { "Shapeshifter", "EditorVisibleObject", "PropertyHelper" },
	entity = "WayPoint",

	use_object = false,
	prop_id = false,
	origin = false,
	outside_object = false,
	angle_prop = false,
	no_z = false,
	line = false,
}
	
---
--- Creates a new `PropertyHelper_RelativePos` object and initializes it with the provided parameters.
---
--- @param obj table The parent object for the helper.
--- @param prop_id string The ID of the property this helper is associated with.
--- @param prop_meta table The metadata for the property this helper is associated with.
--- @param prop_value any The initial value of the property this helper is associated with.
---
function PropertyHelper_RelativePos:Create(obj, prop_id, prop_meta, prop_value)
	self.parent = obj
	self.prop_id = prop_id
	self.use_object = prop_meta.use_object
	self.origin = prop_meta.helper_origin
	self.outside_object = prop_meta.helper_outside_object
	self.angle_prop = prop_meta.angle_prop
	self.no_z = prop_meta.no_z
	if self.use_object then
		self:ChangeEntity( obj:GetEntity() )
		self:SetGameFlags(const.gofWhiteColored)
		self:SetColorModifier( RGB(10, 10, 10))
	else
		local entity = prop_meta.helper_entity
		if type(entity) == "function" then
			entity = entity(obj)
		end
		if entity then
			self:ChangeEntity( entity )
		else
			self:ChangeEntity( "WayPoint" )
			self:SetColorModifier(RGBA(255,255,0,100))
		end
	end
	self:Update(obj, prop_value)

	if prop_meta.helper_scale_with_parent then
		local _, parent_radius = obj:GetBSphere()
		local _, helper_radius = self:GetBSphere()
		self:SetScale(10*parent_radius/Max(helper_radius, 1)) -- 10% of the parent
	end

	self:SetEnumFlags(const.efVisible)
	if prop_meta.color then 
		self:SetColorModifier(prop_meta.color)
	end
end
		
---
--- Updates the position, angle, and scale of the `PropertyHelper_RelativePos` object based on the provided object and value.
---
--- @param obj table The parent object for the helper.
--- @param value any The initial value of the property this helper is associated with.
---
function PropertyHelper_RelativePos:Update(obj, value)
	obj = obj or self.parent
	local center, radius = obj:GetBSphere()
	local rel_pos = point30
	if value then
		if self.outside_object then
			rel_pos = SetLen(value, Max(value:Len(), radius))
		else 
			rel_pos = value
		end
	end
	local origin = self.origin and center or obj:GetVisualPos()
	local pos = origin + rel_pos
	if self.no_z then
		pos = pos:SetInvalidZ()
	end
	self:SetPos(pos)
	if self.angle_prop then
		self:SetAngle(obj:GetProperty(self.angle_prop))
	else
		self:SetAxis(obj:GetVisualAxis())
		self:SetAngle(obj:GetVisualAngle())
	end
	if self.use_object then
		self:SetScale(self.parent:GetScale())
	end
	if IsValid(self.line) then
		DoneObject(self.line)
	end
	self:DrawLine(origin)
end

---
--- Draws a line between the current position of the `PropertyHelper_RelativePos` object and the provided `origin` position.
---
--- If a line already exists, it is first removed by calling `DoneObject()` on it.
--- A new line is then created using `PlaceTerrainLine()` and attached to the `PropertyHelper_RelativePos` object.
---
--- @param origin point3 The origin position to draw the line from.
---
function PropertyHelper_RelativePos:DrawLine(origin)
	if IsValid(self.line) then
		DoneObject(self.line)
	end
	self.line = PlaceTerrainLine(self:GetPos(), origin)
	self:Attach(self.line)
end
	
---
--- Handles the editor callback actions for a `PropertyHelper_RelativePos` object.
---
--- This function is called when the editor performs certain actions on the `PropertyHelper_RelativePos` object, such as moving, rotating, or scaling it.
---
--- @param action_id string The action ID of the editor callback, such as "EditorCallbackMove", "EditorCallbackRotate", or "EditorCallbackScale".
--- @return any The parent object of the `PropertyHelper_RelativePos` object, if the action was handled successfully.
---
function PropertyHelper_RelativePos:EditorCallback(action_id)
	local parent = self.parent
	if not parent then
		return
	end
	if action_id == "EditorCallbackMove" then
		local origin = self.origin and parent:GetBSphere() or parent:GetVisualPos()
		local pos = self:GetVisualPos() - origin
		if self.no_z then
			pos = pos:SetInvalidZ()
		end
		parent:SetProperty(self.prop_id, pos)
		self:DrawLine(origin)
	elseif action_id == "EditorCallbackRotate" then
		if self.angle_prop then
			parent:SetProperty(self.angle_prop, self:GetVisualAngle())
		else
			parent:SetAxis(self:GetVisualAxis()) 
			parent:SetAngle(self:GetVisualAngle())
		end
	elseif action_id == "EditorCallbackScale" then
		parent:SetScale(self:GetScale())
	else
		return false
	end
	return parent
end

-- A helper that shows a marker for each point and measures their relative pos to the main object.
-- Property must be from type point_list.
DefineClass.PropertyHelper_RelativePosList = {
	__parents = { "PropertyHelper" },
	markers = false,

	prop_id = false,
	origin = false,
	no_z = false,
	line = false,
}

DefineClass.PropertyHelper_RelativePosList_Object = {
	__parents = { "Shapeshifter", "EditorVisibleObject", "PropertyHelper" },
	entity = "WayPoint",
	
	obj = false,
	prop_id = false,
	prop_id_idx = false,
	origin = false,
	
	line = false
}

--- Cleans up the line object associated with this PropertyHelper_RelativePosList_Object instance.
---
--- If a line object is valid, it is destroyed using the `DoneObject` function.
--- The `line` field is then set to `false` to indicate there is no longer a line object.
function PropertyHelper_RelativePosList_Object:Done()
	if IsValid(self.line) then
		DoneObject(self.line)
	end
	self.line = false
end

---
--- Updates the line object associated with this PropertyHelper_RelativePosList_Object instance.
---
--- If a line object is already valid, it is first destroyed using the `DoneObject` function.
--- A new line object is then created using `PlaceTerrainLine`, with the start position set to the current
--- visual position of the object, and the end position set to the origin specified in the property metadata.
--- The new line object is then attached to this object using the `Attach` function.
---
--- @function PropertyHelper_RelativePosList_Object:UpdateLine
--- @return nil
function PropertyHelper_RelativePosList_Object:UpdateLine()
	if IsValid(self.line) then
		DoneObject(self.line)
	end
	self.line = PlaceTerrainLine(self:GetPos(), self.origin)
	self:Attach(self.line)
end

---
--- Handles editor callbacks for the `PropertyHelper_RelativePosList_Object` class.
---
--- This function is called when the editor performs certain actions on the object, such as moving it.
---
--- When the "EditorCallbackMove" action is received, the function updates the position of the object in the parent's property list, and then calls the `UpdateLine` function to update the visual line associated with the object.
---
--- @param action_id string The action ID of the editor callback.
--- @return boolean|table The parent object, or `false` if the action is not handled.
function PropertyHelper_RelativePosList_Object:EditorCallback(action_id)
	local parent = self.obj
	if not parent then
		return
	end
	if action_id == "EditorCallbackMove" then
		local origin = self.origin
		if not origin then return end
		local pos = self:GetVisualPos() - origin
		parent[self.prop_id][self.prop_id_idx] = pos
		parent:SetProperty(self.prop_id, parent[self.prop_id])
		self:UpdateLine()
	else
		return false
	end
	return parent
end
	
---
--- Creates a new `PropertyHelper_RelativePosList` instance and initializes it with the provided parameters.
---
--- @param obj table The parent object that owns the property list.
--- @param prop_id string The ID of the property that the list is associated with.
--- @param prop_meta table The metadata for the property, including the `helper_origin` and `no_z` fields.
--- @param prop_value table The initial value of the property list.
--- @return nil
function PropertyHelper_RelativePosList:Create(obj, prop_id, prop_meta, prop_value)
	self.parent = obj
	self.prop_id = prop_id
	self.origin = prop_meta.helper_origin
	self.no_z = prop_meta.no_z

	self:Update(obj, prop_value)
end

---
--- Cleans up the `PropertyHelper_RelativePosList` instance by destroying all the marker objects associated with it.
---
--- This function is called when the `PropertyHelper_RelativePosList` instance is no longer needed, to ensure that all the visual markers are properly removed from the scene.
---
--- @return nil
function PropertyHelper_RelativePosList:Done()
	for i, m in ipairs(self.markers or empty_table) do
		if IsValid(m) then
			DoneObject(m)
		end
	end
	self.markers = false
end
		
---
--- Updates the `PropertyHelper_RelativePosList` instance with the provided object and property value.
---
--- This function is responsible for synchronizing the visual markers associated with the property list. It ensures that the number of markers matches the length of the property value, creating new markers as needed and removing any excess markers.
---
--- The markers are positioned relative to the parent object's bounding sphere center, with the `origin` property of each marker set to this center point. If the `no_z` flag is set in the property metadata, the Z coordinate of the marker positions is set to an invalid value.
---
--- @param obj table The parent object that owns the property list.
--- @param value table The new value of the property list.
--- @return nil
function PropertyHelper_RelativePosList:Update(obj, value)
	obj = obj or self.parent
	local center, radius = obj:GetBSphere()
	
	local markers = self.markers
	if not markers then
		markers = {}
		self.markers = markers
	end
	
	-- Sync count
	local pInList = value and #value or 0
	local pSpawned = #markers
	if pInList ~= pSpawned then
		if pInList < pSpawned then
			for i = pSpawned, pInList + 1, -1 do
				local pToDelete = markers[i]
				markers[i] = nil
				if IsValid(pToDelete) then DoneObject(pToDelete) end
			end
		elseif pInList > 0 then -- less
			for i = pSpawned + 1, pInList do
				local newPoint = PlaceObject("PropertyHelper_RelativePosList_Object")
				newPoint:ChangeEntity("WayPoint")
				newPoint:SetEnumFlags(const.efVisible)
				newPoint:SetColorModifier(RGB(125, 55, 0))
				newPoint.obj = obj
				newPoint.prop_id = self.prop_id
				newPoint.prop_id_idx = i
				newPoint:AttachText("Point Helper " .. tostring(i))
				markers[i] = newPoint
			end
		end
	end
	
	local origin = self.origin and center or obj:GetVisualPos()
	for i, m in ipairs(markers) do
		local pos = origin + value[i]
		if self.no_z then
			pos = pos:SetInvalidZ()
		end
		m.origin = origin
		m:SetPos(pos)
		m:UpdateLine()
	end
end

DefineClass.PropertyHelper_RelativeDist = {
	__parents = { "Shapeshifter", "EditorVisibleObject", "PropertyHelper" },
	entity = "WayPoint",
	
	use_object = false,
	orientation = false,
	prop_id = false,
	pos_update_thread = false,
	rot_update_thread = false,
}
	
---
--- Creates a new `PropertyHelper_RelativeDist` object and initializes it with the provided parameters.
---
--- @param obj table The parent object for the `PropertyHelper_RelativeDist` object.
--- @param prop_id string The property ID associated with the `PropertyHelper_RelativeDist` object.
--- @param prop_meta table The metadata for the property associated with the `PropertyHelper_RelativeDist` object.
--- @param prop_value number The initial value for the property associated with the `PropertyHelper_RelativeDist` object.
---
function PropertyHelper_RelativeDist:Create(obj, prop_id, prop_meta, prop_value)
	self.parent = obj
	self.prop_id = prop_id
	if prop_meta.orientation then
		local x,y,z = unpack_params(prop_meta.orientation)
		self.orientation = Normalize(x,y,z)
	else
		self.orientation = axis_z
	end
	self.use_object = prop_meta.use_object
	if self.use_object then
		self:ChangeEntity( obj:GetEntity() )
		self:SetGameFlags(const.gofWhiteColored)
		self:SetColorModifier(RGB(10, 10, 10))
	else
		local entity = prop_meta.helper_entity
		if type(entity) == "function" then
			entity = entity(obj)
		end
		if entity then
			self:ChangeEntity( entity )
		else
			self:ChangeEntity( "WayPoint" )
			self:SetColorModifier(RGBA(255,255,0,100))
		end
	end
	self:Update(obj, prop_value)

	self:SetEnumFlags(const.efVisible)
	if prop_meta.color then 
		self:SetColorModifier(prop_meta.color)
	end
end
		
---
--- Updates the position and orientation of the `PropertyHelper_RelativeDist` object based on the parent object's position and orientation.
---
--- @param obj table The parent object for the `PropertyHelper_RelativeDist` object.
--- @param value number The new distance value for the `PropertyHelper_RelativeDist` object.
---
function PropertyHelper_RelativeDist:Update(obj, value)
	DeleteThread(self.pos_update_thread)
	DeleteThread(self.rot_update_thread)
	
	local parent = self.parent
	local parent_pos = parent:GetVisualPos()
	local pos = SetLen(parent:GetRelativePoint(self.orientation) - parent_pos, value or 0) -- SetLen to avoid Scale difference
	self:SetPos(parent_pos + pos)
	
	if self.use_object then
		self:SetAxis(parent:GetVisualAxis())
		self:SetAngle(parent:GetVisualAngle())
		self:SetScale(parent:GetScale())
	end
end

---
--- Handles the editor callback actions for the `PropertyHelper_RelativeDist` object.
---
--- @param action_id string The action ID of the editor callback.
--- @return table The parent object of the `PropertyHelper_RelativeDist` object.
---
function PropertyHelper_RelativeDist:EditorCallback(action_id)
	local parent = self.parent
	if action_id == "EditorCallbackMove" then
		-- the target marker is allowed to move, but only its projection on the orientation vector is kept
		local parent_pos = parent:GetVisualPos()
		local orient = SetLen(parent:GetRelativePoint(self.orientation) - parent_pos, 4096) -- SetLen to avoid Scale difference
		local vector = self:GetVisualPos() - parent_pos
		local new_dist = Dot(orient, vector, 4096)
		local target_pos = SetLen(orient, new_dist)
		--[[
		DbgClearVectors()				
		DbgAddVector( parent_pos, orient, RGB(255,0,0))
		DbgAddVector( parent_pos, vector, RGB(0,255,0))
		DbgAddVector( parent_pos, target_pos, RGB(0,255,255))
		--]]
		parent:SetProperty(self.prop_id, new_dist)
		-- don't change the target_pos immediately to avoid flickering:
		DeleteThread(self.pos_update_thread)
		self.pos_update_thread = CreateRealTimeThread( function()
			Sleep(200)
			self:SetPos(parent_pos + target_pos)
		end)
	elseif action_id == "EditorCallbackScale" then
		parent:SetScale(self:GetScale())
	elseif action_id == "EditorCallbackRotate" then
		parent:SetScale(self:GetScale())
		-- don't change the orientation immediately to avoid flickering:
		DeleteThread(self.rot_update_thread)
		self.rot_update_thread = CreateRealTimeThread( function()
			Sleep(200)
			self:SetAxis(parent:GetAxis())
			self:SetAngle(parent:GetAngle())
		end)
	else
		--print(action_id)
		return false
	end
	return parent
end

DefineClass.PropertyHelper_TerrainRect = {
	__parents = { "PropertyHelper", "EditorVisibleObject" },
	entity = "WayPoint",
	lines = false,
	step = guim/2,
	count_x = -1,
	count_y = -1,
	color = RGBA(64, 196, 0, 96),
	z_offset = guim/4,
	depth_test = false,
	parent = false,
	pos = false,
	prop_id = false,
	value = false,
	show_grid = false,
	value_min = false,
	value_max = false,
	value_gran = false,
	is_one_dim = false,
	walkable = false,
}

---
--- Creates a new `PropertyHelper_TerrainRect` object and initializes it with the provided properties.
---
--- @param obj table The parent object that this `PropertyHelper_TerrainRect` is associated with.
--- @param prop_id string The ID of the property this `PropertyHelper_TerrainRect` is associated with.
--- @param prop_meta table The metadata for the property this `PropertyHelper_TerrainRect` is associated with.
--- @param prop_value any The current value of the property this `PropertyHelper_TerrainRect` is associated with.
---
function PropertyHelper_TerrainRect:Create(obj, prop_id, prop_meta, prop_value)
	self.prop_id = prop_id
	self.color = prop_meta.terrain_rect_color
	self.step = prop_meta.terrain_rect_step
	self.walkable = prop_meta.terrain_rect_walkable
	self.show_grid = prop_meta.terrain_rect_grid
	self.z_offset = prop_meta.terrain_rect_zoffset
	self.depth_test = prop_meta.terrain_rect_depth_test
	self.value_min = prop_meta.min
	self.value_max = prop_meta.max
	self.value_gran = prop_meta.granularity
	self.is_one_dim = prop_meta.editor ~= "point"
	self.parent = obj
	self:Update(obj, prop_value)
	self:SetScale(obj:GetScale() * 80 / 100)
	self:SetColorModifier(self.color)
end
	
---
--- Destroys the lines associated with this `PropertyHelper_TerrainRect` object.
---
--- This function clears the `lines` table, which stores the visual lines representing the terrain rectangle, and destroys any valid objects in the table.
---
--- @param self PropertyHelper_TerrainRect The `PropertyHelper_TerrainRect` object whose lines should be destroyed.
---
function PropertyHelper_TerrainRect:DestroyLines()
	self.count_x = -1
	self.count_y = -1
	local lines = self.lines or ""
	for i=1,#lines do
		if IsValid(lines[i]) then
			DoneObject(lines[i])
		end
	end
	self.lines = {}
end

---
--- Calculates the value of a `PropertyHelper_TerrainRect` object based on its position relative to its parent object.
---
--- The calculated value takes into account whether the terrain rectangle is centered on the parent object or not, and applies any minimum, maximum, and granularity constraints specified in the property metadata.
---
--- @param obj table The parent object that this `PropertyHelper_TerrainRect` is associated with.
--- @return any The calculated value of the terrain rectangle.
---
function PropertyHelper_TerrainRect:CalcValue(obj)
	obj = obj or self.parent
	local centered = not obj:HasMember("TerrainRectIsCentered") or obj:TerrainRectIsCentered(self.prop_id)
	local coef = centered and 2 or 1
	local dx, dy = (self:GetVisualPos() - obj:GetVisualPos()):xy()
	if not centered then
		dx = Max(0, dx)
		dy = Max(0, dy)
	end
	local value
	if self.is_one_dim then
		value = Max(1, coef * Max(abs(dx), abs(dy)))
		if self.value_min then
			value = Max(value, self.value_min)
		end
		if self.value_max then
			value = Min(value, self.value_max)
		end
	else
		dx = Max(1, coef*abs(dx))
		dy = Max(1, coef*abs(dy))
		if self.value_min then
			dx = Max(dx, self.value_min)
			dy = Max(dy, self.value_min)
		end
		if self.value_max then
			dx = Min(dx, self.value_max)
			dy = Min(dy, self.value_max)
		end
		if terminal.IsKeyPressed(const.vkAlt) then
			local v = Max(dx, dy)
			value = point(v, v)
		else
			value = point(dx, dy)
		end
	end
	if self.value_gran then
		value = round(value, self.value_gran)
	end
	return value
end

---
--- Updates the visual representation of a `PropertyHelper_TerrainRect` object based on its parent object and the calculated value.
---
--- This function is responsible for creating and updating the lines that represent the terrain rectangle in the editor. It calculates the position and size of the rectangle based on the parent object's properties and the calculated value, and then creates or updates the lines accordingly.
---
--- @param obj table The parent object that this `PropertyHelper_TerrainRect` is associated with.
--- @param value any The calculated value of the terrain rectangle.
---
function PropertyHelper_TerrainRect:Update(obj, value)
	obj = obj or self.parent
	if not IsValid(obj) then
		return
	end
	if obj:HasMember("TerrainRectIsEnabled") and not obj:TerrainRectIsEnabled(self.prop_id) then
		self:ClearEnumFlags(const.efVisible)
		self:DestroyLines()
		self.pos = false
		return
	end
	self:SetEnumFlags(const.efVisible)
	local pos = obj:GetVisualPos()
	local my_pos = self:IsValidPos() and self:GetVisualPos() or pos
	local centered = not obj:HasMember("TerrainRectIsCentered") or obj:TerrainRectIsCentered(self.prop_id)
	local dont_move
	if not value then
		value = self:CalcValue(obj)
		dont_move = true
	end
	if self.pos == pos and self.value == value and self.centered == centered then
		return
	end
	self.centered = centered
	self.pos = pos
	self.value = value
	local count_x, count_y
	if self.step <= 0 then
		count_x = 2
		count_y = 2
	elseif IsPoint(value) then
		count_x = Min(100, Max(2, 1 + MulDivRound(2, value:x(), self.step)))
		count_y = Min(100, Max(2, 1 + MulDivRound(2, value:y(), self.step)))
	else
		local count = Min(100, Max(2, 1 + MulDivRound(2, value, self.step)))
		count_x = count
		count_y = count
	end
	if count_x ~= self.count_x or count_y ~= self.count_y then
		self:DestroyLines()
		self.count_x = count_x
		self.count_y = count_y
	end
	
	local ox, oy, oz = pos:xyz()
	local color = self.color
	local offset = self.z_offset
	local depth_test = self.depth_test
	local lines = self.lines
	local walkable = self.walkable
	local grid = {}
	
	local offset_x, offset_y
	if IsPoint(value) then
		offset_x, offset_y = value:xy()
	else
		offset_x, offset_y = value, value
	end
	local startx, starty = ox, oy
	if centered then
		if not dont_move then
			offset_x = abs(offset_x)
			offset_y = abs(offset_y)
		end
		offset_x = offset_x / 2
		offset_y = offset_y / 2
		startx, starty = ox - offset_x, oy - offset_y
	end
	local endx, endy = ox + offset_x, oy + offset_y
	local mapw, maph = terrain.GetMapSize()
	local height_tile = const.HeightTileSize
	endx = Clamp(endx, 0, mapw - height_tile - 1)
	endy = Clamp(endy, 0, maph - height_tile - 1)
	startx = Clamp(startx, 0, mapw - height_tile - 1)
	starty = Clamp(starty, 0, maph - height_tile - 1)
	if not dont_move then
		self:SetPos(point(endx, endy))
	end
	for yi = 1,count_y do
		local y = starty + MulDivRound(endy - starty, yi - 1, count_y - 1)
		local row = {}
		for xi = 1,count_x do
			local x = startx + MulDivRound(endx - startx, xi - 1, count_x - 1)
			local z = terrain.GetHeight(x, y)
			if walkable then
				z = Max(z, GetWalkableZ(x, y))
			end
			row[xi] = point(x, y, z + offset)
		end
		grid[yi] = row
	end
	
	local li = 1
	local function SetNextLinePoints(points)
		local line = lines[li]
		if not line then
			line = Polyline:new()
			line:SetMeshFlags(const.mfWorldSpace)
			line:SetDepthTest(depth_test)
			lines[li] = line
			obj:Attach(line, obj:GetSpotBeginIndex("Origin"))
		end
		line:SetMesh(points)
		li = li + 1
	end
	for yi = 1,count_y do
		if self.show_grid or yi == 1 or yi == count_y then
			local points = pstr("")
			for xi = 1,count_x do
				points:AppendVertex(grid[yi][xi], color)
			end
			SetNextLinePoints(points)
		end
	end
	for xi = 1,count_x do
		if self.show_grid or xi == 1 or xi == count_x then
			local points = pstr("")
			for yi = 1,count_y do
				points:AppendVertex(grid[yi][xi], color)
			end
			SetNextLinePoints(points)
		end
	end
end
	
---
--- Handles the editor callback for the `PropertyHelper_TerrainRect` class.
---
--- This function is called when an editor action is performed on the `PropertyHelper_TerrainRect` object.
---
--- @param action_id string The ID of the editor action that was performed.
--- @return table|nil The parent object if the action was a move action, otherwise `nil`.
---
function PropertyHelper_TerrainRect:EditorCallback(action_id)
	if not IsValid(self.parent) then
		return
	end
	if action_id == "EditorCallbackMove" then
		self.parent:SetProperty(self.prop_id, self:CalcValue())
		self:Update()
		return self.parent
	end
end

---
--- Destroys the lines associated with the `PropertyHelper_TerrainRect` object.
---
--- This function is called when the `PropertyHelper_TerrainRect` object is no longer needed, and it cleans up the resources used by the object.
---
function PropertyHelper_TerrainRect:Done()
	self:DestroyLines()
end

DefineClass.PropertyHelper_AbsolutePos = {
	__parents = { "Shapeshifter", "EditorVisibleObject", "PropertyHelper" },
	entity = "WayPoint",
	
	use_object = false,
	prop_id = false,
	angle_prop = false,
}
	
---
--- Creates a new `PropertyHelper_AbsolutePos` object and initializes it with the provided properties.
---
--- @param obj table The parent object that owns this `PropertyHelper_AbsolutePos` object.
--- @param prop_id string The ID of the property that this `PropertyHelper_AbsolutePos` object is associated with.
--- @param prop_meta table The metadata for the property that this `PropertyHelper_AbsolutePos` object is associated with.
--- @param prop_value any The initial value of the property that this `PropertyHelper_AbsolutePos` object is associated with.
---
function PropertyHelper_AbsolutePos:Create(obj, prop_id, prop_meta, prop_value)
	self.parent = obj
	self.prop_id = prop_id
	self.use_object = prop_meta.use_object
	if self.use_object then
		self:ChangeEntity( obj:GetEntity() )
		self:SetGameFlags(const.gofWhiteColored)
		self:SetColorModifier( RGB(255, 10, 10))
	else
		local entity = prop_meta.helper_entity
		if type(entity) == "function" then
			entity = entity(obj)
		end
		if entity then
			self:ChangeEntity( entity )
		else
			self:ChangeEntity( "WayPoint" )
			self:SetColorModifier(RGBA(255,255,0,100))
		end
	end
	if obj:HasMember("OnHelperCreated") then
		obj:OnHelperCreated(self)
	end
	local angle = prop_meta.angle_prop and obj:GetProperty(prop_meta.angle_prop)
	if angle then
		self.angle_prop = prop_meta.angle_prop
		self:SetAngle(angle)
	end
	
	self:Update(obj, prop_value)

	self:SetEnumFlags(const.efVisible)
	if prop_meta.color then 
		self:SetColorModifier(prop_meta.color)
	end
end
	
---
--- Adds a reference to the `PropertyHelper_AbsolutePos` object to the provided `helpers` table, using the `angle_prop` field as the key.
---
--- @param helpers table The table to add the reference to.
---
function PropertyHelper_AbsolutePos:AddRef(helpers)
	if self.angle_prop then
		helpers[self.angle_prop] = self
	end
end
		
--- Updates the position or angle of the `PropertyHelper_AbsolutePos` object based on the provided value.
---
--- @param obj table The parent object that this `PropertyHelper_AbsolutePos` object is associated with.
--- @param value any The new value to update the position or angle to.
function PropertyHelper_AbsolutePos:Update(obj, value)
	if type(value) ~= "number" then
		if not value or value == InvalidPos() then
			value = GetVisiblePos()
		end
		self:SetPos(value)
	else
		self:SetAngle(value)
	end
end
	
---
--- Handles the editor callback for the `PropertyHelper_AbsolutePos` object.
---
--- When the editor callback is triggered, this function updates the parent object's properties with the current position and angle of the `PropertyHelper_AbsolutePos` object.
---
--- @param action_id string The action ID of the editor callback.
--- @return table The parent object.
---
function PropertyHelper_AbsolutePos:EditorCallback(action_id)
	local parent = self.parent
	if parent then
		parent:SetProperty(self.prop_id, self:GetVisualPos())
		if self.angle_prop then
			parent:SetProperty(self.angle_prop, self:GetVisualAngle())
		end
	end
	return parent
end

-- A helper that is cut scene editor specific. Only one is created per object and manages 
-- pos, axis and angle per selected actor.
-- Only usable by ActionAnimation class (currently).
DefineClass.PropertyHelper_SceneActorOrientation = { 
	__parents = { "Shapeshifter", "EditorVisibleObject", "PropertyHelper" },
	
	actor_entity = false,
}
	
---
--- Creates a new `PropertyHelper_SceneActorOrientation` object and initializes it with the provided parent object, property ID, and property metadata.
---
--- @param parent table The parent object that this `PropertyHelper_SceneActorOrientation` object is associated with.
--- @param prop_id string The property ID of the parent object that this `PropertyHelper_SceneActorOrientation` object is associated with.
--- @param prop_meta table The property metadata of the parent object that this `PropertyHelper_SceneActorOrientation` object is associated with.
function PropertyHelper_SceneActorOrientation:Create(parent, prop_id, prop_meta)
	self.parent = parent
	self:SetGameFlags(const.gofWhiteColored)
	self:Update()
	EditorActivate()
	self:SetEnumFlags(const.efVisible)
	self:SetRealtimeAnim(true)
end

---
--- Updates the `PropertyHelper_SceneActorOrientation` object with the latest position, axis, and angle information from its parent object.
---
--- If the parent object has an associated actor entity, this function will update the `PropertyHelper_SceneActorOrientation` object to match the actor entity's position, axis, and angle. If the parent object's position is not invalid, the `PropertyHelper_SceneActorOrientation` object will be attached to the map and its state text will be set to the parent object's animation, if it exists.
---
--- If the parent object does not have an associated actor entity, or if its position is invalid, the `PropertyHelper_SceneActorOrientation` object will be detached from the map.
---
--- @param obj table The parent object of the `PropertyHelper_SceneActorOrientation` object.
function PropertyHelper_SceneActorOrientation:Update(obj)
	local parent = self.parent
	local actor_entity = parent:GetActorEntity()
	if actor_entity and actor_entity ~= self.actor_entity then
		self:ChangeEntity(actor_entity)
		self.actor_entity = actor_entity
	end
	if self.actor_entity and parent.pos ~= InvalidPos() then
		self:SetPos(parent.pos) 
		self:SetAxis(parent.axis)
		self:SetAngle(parent.angle)
		if rawget(parent, "animation") and parent.animation ~= "" then
			self:SetStateText(parent.animation)
		end
		if rawget(parent, "animation") then
			self:SetStateText(parent.animation)
		end
	else
		self:DetachFromMap()
	end
end
	
---
--- Handles editor callbacks for the `PropertyHelper_SceneActorOrientation` object.
---
--- If the `PropertyHelper_SceneActorOrientation` object has a valid parent object, this function will update the parent object's position, axis, and angle when the editor callback action is "EditorCallbackMove" or "EditorCallbackRotate" and the `PropertyHelper_SceneActorOrientation` object has a valid actor entity.
---
--- @param action_id string The editor callback action ID.
--- @return table The updated parent object.
function PropertyHelper_SceneActorOrientation:EditorCallback(action_id)
	if not self.parent then
		return
	end	
	if action_id == "EditorCallbackMove" or action_id == "EditorCallbackRotate" and self.actor_entity then
		local parent = self.parent
		parent.pos = self:GetPos()
		parent.axis = self:GetAxis()
		parent.angle = self:GetAngle()
		return parent
	end
end

-- A helper that visualizes a single radius with one code renderable sphere.
-- Property must be from type number.
DefineClass.PropertyHelper_SphereRadius = {
	__parents = { "PropertyHelper", "EditorObject" },
	
	sphere = false,
	color = false,
	square = false,
	square_divider = 1
}

---
--- Creates a `PropertyHelper_SphereRadius` object and attaches a sphere mesh to the specified object.
---
--- @param obj table The object to attach the sphere mesh to.
--- @param prop_id string The property ID.
--- @param prop_meta table The property metadata.
--- @param prop_value number The property value.
--- @param useSecondColor boolean Whether to use the second color from the property metadata.
---
function PropertyHelper_SphereRadius:Create(obj, prop_id, prop_meta, prop_value, useSecondColor)
	if prop_meta.square then
		self.square = true
		if prop_meta.square_divider then
			self.square_divider = prop_meta.square_divider
		end
	end
	local radius 
	if self.square then
		radius = prop_value * prop_value / self.square_divider
	else
		radius = prop_value
	end
	if useSecondColor and prop_meta.color2 then
		self.color = prop_meta.color2
	elseif prop_meta.color then
		self.color = prop_meta.color
	else 
		self.color = RGB(255,255,255)
	end
	local sphere = CreateSphereMesh(radius, self.color)
	sphere:SetDepthTest(true)
	obj:Attach(sphere, obj:GetSpotBeginIndex("Origin"))
	self.parent = obj
	
	self.sphere = sphere
end

---
--- Updates the radius of the sphere mesh attached to the object.
---
--- @param obj table The object the sphere mesh is attached to.
--- @param value number The new value for the property that the sphere radius is visualizing.
---
function PropertyHelper_SphereRadius:Update(obj, value)
	local radius
	if self.square then
		radius = value * value / self.square_divider
	else
		radius = value 
	end
	self.sphere:SetMesh(CreateSphereVertices(radius, self.color))
end
	
--- Called when the editor enters the property helper.
--- Ensures the sphere mesh attached to the object is visible.
---
--- @param self PropertyHelper_SphereRadius The property helper instance.
function PropertyHelper_SphereRadius:EditorEnter()
	if IsValid(self.sphere) then
		self.sphere:SetEnumFlags(const.efVisible)
	end
end
	
---
--- Called when the editor exits the property helper.
--- Ensures the sphere mesh attached to the object is no longer visible.
---
--- @param self PropertyHelper_SphereRadius The property helper instance.
function PropertyHelper_SphereRadius:EditorExit()
	if IsValid(self.sphere) then
		self.sphere:ClearEnumFlags(const.efVisible)
	end
end
	
---
--- Cleans up the sphere mesh attached to the object.
---
--- This function is called when the property helper is done being used.
--- It detaches and deletes the sphere mesh that was created in the `Create` function.
---
--- @param self PropertyHelper_SphereRadius The property helper instance.
function PropertyHelper_SphereRadius:Done()
	if IsValid(self.parent) and IsValid(self.sphere) then
		self.sphere:Detach()
		self.sphere:delete()
	end
end

-- A helper that visualizes numerical range with two spheres' radiuses.
-- Property must be from type table - { from = <number>, to = <number> }
DefineClass.PropertyHelper_SphereRange = {
	__parents = { "PropertyHelper" },
	
	sphere_from = false,
	sphere_to = false,
}

--- Creates two sphere property helpers to visualize a range.
---
--- The `PropertyHelper_SphereRange` class is used to create two sphere property helpers, one for the "from" value and one for the "to" value of a range property.
---
--- @param self PropertyHelper_SphereRange The property helper instance.
--- @param main_obj Object The main object that the property helper is attached to.
--- @param obj Object The object that the property is defined on.
--- @param prop_id string The ID of the property.
--- @param prop_meta table The metadata for the property.
--- @param prop_value table The value of the property, which should be a table with "from" and "to" fields.
function PropertyHelper_SphereRange:Create(main_obj, obj, prop_id, prop_meta, prop_value)
	local fromInfo = { 
		mainObject = main_obj,
		object = obj,
		property_id = prop_id,
		property_meta = prop_meta,
		property_value = prop_value.from,
	}
	local toInfo = table.copy(fromInfo)
	toInfo.property_value = prop_value.to
	
	self.sphere_from = CreatePropertyHelpers["sradius"](fromInfo,false)
	self.sphere_to = CreatePropertyHelpers["sradius"](toInfo,true)
end
	
---
--- Updates the two sphere property helpers to visualize the range.
---
--- This function is called to update the position and size of the two spheres that represent the "from" and "to" values of the range property.
---
--- @param self PropertyHelper_SphereRange The property helper instance.
--- @param obj Object The object that the property is defined on.
--- @param value table The value of the property, which should be a table with "from" and "to" fields.
function PropertyHelper_SphereRange:Update(obj, value)
	if IsValid(self.sphere_from) and IsValid(self.sphere_to) then
		self.sphere_from:Update(obj, value.from)
		self.sphere_to:Update(obj, value.to)
	end
end
	
---
--- Cleans up the two sphere property helpers used to visualize a range.
---
--- This function is called to destroy the two spheres that represent the "from" and "to" values of the range property.
---
--- @param self PropertyHelper_SphereRange The property helper instance.
function PropertyHelper_SphereRange:Done()
	if IsValid(self.sphere_from) and IsValid(self.sphere_to) then
		DoneObject(self.sphere_from)
		DoneObject(self.sphere_to)
	end
end

----------------------------------------- custom helper for box lights
-----------------------------------------

DefineClass.PropertyHelper_Box3 = {
	__parents = { "PropertyHelper" },
	
	box = false,
}

---
--- Creates a new PropertyHelper_Box3 instance and attaches a mesh object to the parent object.
---
--- This function is called to initialize a new PropertyHelper_Box3 instance. It creates a new mesh object and attaches it to the parent object at the "Origin" spot.
---
--- @param self PropertyHelper_Box3 The property helper instance.
--- @param parent_obj Object The parent object that the mesh will be attached to.
function PropertyHelper_Box3:Create(parent_obj)
	self.parent = parent_obj
	self.box = PlaceObject("Mesh")
	self.box:SetDepthTest(true)
	self.box:SetShader(ProceduralMeshShaders.mesh_linelist)
	parent_obj:Attach(self.box, parent_obj:GetSpotBeginIndex("Origin"))
	self:Update()
end

---
--- Updates the mesh of the box property helper to match the current size of the parent object.
---
--- This function is called to update the mesh of the box property helper to match the current size of the parent object. It calculates the width, height, and depth of the box based on the parent object's properties, and then generates the vertex data for the box mesh.
---
--- @param self PropertyHelper_Box3 The property helper instance.
--- @param obj Object The object that the property is defined on.
--- @param value table The value of the property, which is not used in this function.
function PropertyHelper_Box3:Update(obj, value)
	local width = self.parent:GetProperty("BoxWidth") or guim
	local height = self.parent:GetProperty("BoxHeight") or guim
	local depth = self.parent:GetProperty("BoxDepth") or guim

	width = width / 2
	height = height / 2
	depth = -depth
	local p_pstr = pstr("")
	local function AddPoint(x,y,z) p_pstr:AppendVertex(point(x*width, y*height, z*depth)) end

	AddPoint(-1,-1,0) AddPoint(-1,1,0)   AddPoint(1,-1,0) AddPoint(1,1,0)   AddPoint(-1,-1,0) AddPoint(1,-1,0)  AddPoint(-1,1,0) AddPoint(1,1,0)
	AddPoint(-1,-1,1) AddPoint(-1,1,1)   AddPoint(1,-1,1) AddPoint(1,1,1)   AddPoint(-1,-1,1) AddPoint(1,-1,1)  AddPoint(-1,1,1) AddPoint(1,1,1)
	AddPoint(-1,-1,0) AddPoint(-1,-1,1)  AddPoint(-1,1,0) AddPoint(-1,1,1)  AddPoint(1,-1,0) AddPoint(1,-1,1)   AddPoint(1,1,0) AddPoint(1,1,1)
	self.box:SetMesh(p_pstr)
end

---
--- Destroys the mesh object associated with the PropertyHelper_Box3 instance.
---
--- This function is called to clean up the resources associated with the PropertyHelper_Box3 instance. It checks if the mesh object is valid and then destroys it.
---
--- @param self PropertyHelper_Box3 The property helper instance.
function PropertyHelper_Box3:Done()
	if IsValid(self.box) then DoneObject(self.box) end
end

-------------------------------

DefineClass.PropertyHelper_VolumePicker = {
	__parents = { "PropertyHelper" },
	
	box = false,
}

---
--- Creates a new PropertyHelper_VolumePicker instance and attaches it to the parent object.
---
--- This function is called to create a new PropertyHelper_VolumePicker instance and attach it to the parent object. It sets the parent object reference and then calls the Update function to initialize the volume picker box.
---
--- @param self PropertyHelper_VolumePicker The property helper instance.
--- @param parent_obj Object The parent object that the property helper is attached to.
--- @param prop_id string The ID of the property that the helper is associated with.
--- @param prop_meta table The metadata for the property.
--- @param prop_value table The current value of the property.
function PropertyHelper_VolumePicker:Create(parent_obj, prop_id, prop_meta, prop_value)
	self.parent = parent_obj
	self:Update(parent_obj, prop_value)
end

---
--- Updates the volume picker box based on the provided value.
---
--- This function is called to update the volume picker box when the associated property value changes. It creates a new box object using the provided value, or a default box if the value is nil. The new box is then attached to the parent object.
---
--- @param self PropertyHelper_VolumePicker The property helper instance.
--- @param obj Object The parent object that the property helper is attached to.
--- @param value table The current value of the property.
function PropertyHelper_VolumePicker:Update(obj, value)
	local target = value and value.box
	self.box = PlaceBox(target or box(point(0,0,0), point(0,0,0)), RGBA(255, 255, 0, 255), self.box)
end

---
--- Destroys the mesh object associated with the PropertyHelper_VolumePicker instance.
---
--- This function is called to clean up the resources associated with the PropertyHelper_VolumePicker instance. It checks if the mesh object is valid and then destroys it.
---
--- @param self PropertyHelper_VolumePicker The property helper instance.
function PropertyHelper_VolumePicker:Done()
	if IsValid(self.box) then DoneObject(self.box) end
end

----------------------------------------- custom helper for spot lights
-----------------------------------------

DefineClass.PropertyHelper_SpotLight = {
	__parents = { "PropertyHelper" },
	
	box = false,
}

---
--- Creates a new PropertyHelper_SpotLight instance and attaches it to the parent object.
---
--- This function is called to create a new PropertyHelper_SpotLight instance and attach it to the parent object. It sets the parent object reference, creates a new mesh object, sets its depth test and shader, and attaches it to the parent object at the spot begin index "Origin". It then calls the Update function to initialize the spot light mesh.
---
--- @param self PropertyHelper_SpotLight The property helper instance.
--- @param parent_obj Object The parent object that the property helper is attached to.
function PropertyHelper_SpotLight:Create(parent_obj)
	self.parent = parent_obj
	self.box = PlaceObject("Mesh")
	self.box:SetDepthTest(true)
	self.box:SetShader(ProceduralMeshShaders.mesh_linelist)
	parent_obj:Attach(self.box, parent_obj:GetSpotBeginIndex("Origin"))
	self:Update()
end

---
--- Builds a mesh cone with the given radius and angle.
---
--- This function takes in a string of points, a radius, and an angle, and generates a mesh cone with the specified parameters. It does this by calculating various points and adding them to the points string, which can then be used to create a mesh object.
---
--- @param points_pstr string The string of points to append to.
--- @param radius number The radius of the cone.
--- @param angle number The angle of the cone in degrees.
--- @return string The updated points string with the cone mesh added.
function BuildMeshCone(points_pstr, radius, angle)
	local rad2 = radius * radius
	local r = radius * sin(angle*60 / 2) / 4096
	local a = r*866/1000
	local b = r*2/3
	local c = r/2
	local d = r/3
	local e = r*577/1000
	local function addpt(x,y)
		points_pstr:AppendVertex(point(x, y, -sqrt(rad2 - x*x - y*y)))
	end
	local function addcenter()
		points_pstr:AppendVertex( point30)
	end
	local function quadrant(x,y)
		addpt(x*0,y*0) addpt(x*d,y*e)
		addpt(x*d,y*e) addpt(x*b,y*0)
		addpt(x*b,y*0) addpt(x*a,y*c)
		addpt(x*a,y*c) addpt(x*r,y*0)
		addpt(x*d,y*e) addpt(x*a,y*c)
		addpt(x*0,y*r) addpt(x*d,y*e)
		addpt(x*d,y*e) addpt(x*c,y*a)
		addpt(x*c,y*a) addpt(x*a,y*c)
		addpt(x*0,y*r) addpt(x*c,y*a)
		addpt(x*a,y*c) addcenter()
		addpt(x*c,y*a) addcenter()
	end
	local function semicircle(x)
		quadrant(x,1)
		quadrant(x,-1)
		addpt(0,0) addpt(x*b,0)
		addpt(x*b,0) addpt(x*r,0)
		addpt(x*r,0) addcenter()
	end
	semicircle(1)
	semicircle(-1)
	addpt(d,e) addpt(-d,e)
	addpt(d,-e) addpt(-d,-e)
	addpt(0,r) addcenter()
	addpt(0,-r) addcenter()
	return points_pstr
end

---
--- Updates the mesh of the spot light helper object based on the properties of the parent object.
---
--- @param obj table The parent object of the spot light helper.
--- @param value any The value being updated (not used).
---
function PropertyHelper_SpotLight:Update(obj, value)
	local p_pstr = pstr("")
	local radius = self.parent:GetProperty("AttenuationRadius") or 5000
	local spot_inner_angle = self.parent:GetProperty("ConeInnerAngle") or 45
	local spot_outer_angle = self.parent:GetProperty("ConeOuterAngle") or 90
	p_pstr = BuildMeshCone(p_pstr, radius, spot_inner_angle)
	p_pstr = BuildMeshCone(p_pstr, radius, spot_outer_angle)
	self.box:SetMesh(p_pstr)
end

---
--- Destroys the spot light helper object.
---
function PropertyHelper_SpotLight:Done()
	if IsValid(self.box) then DoneObject(self.box) end
end

----------------------------------------------------------------------------------
-- PropertyHelpers Management System											--
----------------------------------------------------------------------------------

MapVar("PropertyHelpers", {})
MapVar("PropertyHelpers_Refs",{})

---
--- Selects the specified helper object in the editor.
---
--- @param helper_object table The helper object to select.
--- @param no_camera_move boolean (optional) If true, the camera will not move to the helper object.
---
function SelectHelperObject(helper_object, no_camera_move)
	if not IsValid(helper_object) then
		return
	end
	
	if helper_object:IsValidPos() then	
		EditorActivate()
		editor:ClearSel()
		editor.AddToSel({helper_object})
		if not no_camera_move then
			ViewObject(helper_object)
		end
	end
end

-- Helper objects destructor function
local function PropertyHelpers_DoneHelpers(object)
	local helpers = PropertyHelpers[object]
		for _ , helper in pairs(helpers) do
			if IsValid(helper) then
				DoneObject(helper)
			end
		end
	PropertyHelpers_Refs[object] = nil
	PropertyHelpers[object] = nil
end

-- Rebuilds helper objects references (usually when window is closed and window ids are changed)
---
--- Rebuilds the references to helper objects for the specified Ged or all Geds.
---
--- @param ignore_ged table (optional) The Ged to ignore when rebuilding the references.
---
function PropertyHelpers_RebuildRefs(ignore_ged)
	if not PropertyHelpers then return end
	PropertyHelpers_Refs = {}
	if IsEditorActive() then return end
	
	for i, ged in pairs(GedConnections) do
		if not ignore_ged or ged == ignore_ged then
			local objects = ged:GetMatchingBoundObjects({ props = GedGetProperties, values = GedGetValues })
			for key, object in ipairs(objects) do
				if object and PropertyHelpers[object] then
					local ref_table = PropertyHelpers_Refs[object] or {}
					table.insert(ref_table, i)
					PropertyHelpers_Refs[object] = ref_table
				end
			end
		end
	end
end

-- Creates helpers for object if not already referenced in other window
---
--- Initializes property helpers for the specified object and Ged.
---
--- This function creates and manages property helpers for a given object. It checks if the object is a valid `PropertyObject`, and if so, it iterates through the object's properties and creates property helpers based on the `helper` property of each property. The created helpers are stored in the `PropertyHelpers` table, and their references are stored in the `PropertyHelpers_Refs` table.
---
--- If the object has an `AdjustHelpers` member function, it is called after the helpers are created.
---
--- @param obj `PropertyObject` The object to create property helpers for.
--- @param ged `table` The Ged associated with the object.
---
function PropertyHelpers_Init(obj, ged)
	if GetMap() == "" or not PropertyHelpers then
		return 
	end
	
	local objects = { obj }
	local helpers_created = false
	for i = 1, #objects do
		local object = objects[i]
		if IsKindOf(object, "AutoAttachRule") and IsKindOf(g_Classes[object.attach_class], "Light") then
			local demo_obj = GedAutoAttachDemos[ged]
			if demo_obj then
				if (object.required_state or "") ~= "" then
					demo_obj:SetAutoAttachMode(object.required_state)
				end
			end
		end
		if PropertyHelpers[object] then
			if not table.find(PropertyHelpers_Refs[object], ged) then
				table.insert(PropertyHelpers_Refs[object], ged)
			end
			local helpers = PropertyHelpers[object]
			local selected = {}
			for _, helper in pairs(helpers) do
				if not selected[helper] and helper:IsKindOf("PropertyHelper_SceneActorOrientation") then
					selected[helper] = true
					SelectHelperObject(helper, not "no_camera_move")
				end
			end
		elseif IsKindOf(object, "PropertyObject") then
			local helpers = false
			
			local properties = object:GetProperties()
			for i=1, #properties do
				local property = properties[i]
				local property_id = property.id
				if not IsKindOf(object, "GedMultiSelectAdapter") and IsValid(object) then
					local no_edit = property.no_edit
					if type(no_edit) == "function" then
						no_edit = no_edit(object, property_id)
					end
					if not no_edit and property.helper then 
						helpers = helpers or {}
						local property_value = object:GetProperty(property_id)
						assert(property_value ~= nil, "Could not get property value for "..tostring(property_id))
						
						local info = {
							object = object,
							property_id = property_id,
							property_meta = property,
							property_value = property_value,
							helpers =  helpers,
						}
						
						local helper_object = false
						if CreatePropertyHelpers[property.helper] then
							helper_object = CreatePropertyHelpers[property.helper](info)
						else
							assert(false, "Unknown property helper requested" .. (property.helper or ""))
						end

						if helper_object then
							if property.helper == "scene_actor_orientation" and obj == object then
								SelectHelperObject(helper_object, not "no_camera_move")
							end
							
							helpers[property_id] = helper_object
							
							helper_object:AddRef(helpers)

							local idx = editor.GetLockedCollectionIdx()
							if idx ~= 0 then
								helper_object:SetCollectionIndex(idx)
							end
						end
					end
				end
			end

			if helpers then
				PropertyHelpers[object] = helpers
				PropertyHelpers_Refs[object] = { ged }
				if object:HasMember("AdjustHelpers") then
					object:AdjustHelpers()
				end
				helpers_created = true
			end
		end
	end
	if helpers_created then
		UpdateCollectionsEditor()
	end
end

-- Destroys helpers for object if this window is its last reference
---
--- Removes the specified window ID from the list of references for the given object's property helpers.
--- If the list of references becomes empty, the property helpers for the object are destroyed.
---
--- @param object table The object whose property helpers should be removed.
--- @param window_id table The window ID to remove from the list of references.
---
function PropertyHelpers_Done(object, window_id)
	local objects = { object }
	for i = 1, #objects do
		local object = objects[i]
		if PropertyHelpers and PropertyHelpers[object] then
			local helpers_refs = PropertyHelpers_Refs[object]
			assert(helpers_refs,"Object property helpers already destroyed")
			
			table.remove_value(helpers_refs, window_id)
			if #helpers_refs == 0 then
				PropertyHelpers_DoneHelpers(object)
			end
		end
	end
end

---
--- Refreshes the property helpers for the specified object.
---
--- This function updates all the property helpers for the given object, rebuilds the references to the
--- GED instances, and ensures that the property helpers are properly initialized and destroyed.
---
--- @param object table The object whose property helpers should be refreshed.
---
function PropertyHelpers_Refresh(object)
	PropertyHelpers_UpdateAllHelpers(object)
	local prop_helpers = {}
	for object, geds in pairs(PropertyHelpers_Refs) do
		prop_helpers[object] = table.copy(geds)
	end
	for object, ged in pairs(prop_helpers) do
		if GedConnections[ged.ged_id] then
			PropertyHelpers_Done(object, ged)
		end
	end
	for object, ged in pairs(prop_helpers) do
		if GedConnections[ged.ged_id] then
			PropertyHelpers_Init(object, ged)
		end
	end
end
---
--- Activates the editor and selects the property helper object for the specified object and property ID.
---
--- If a property helper object exists for the given object and property ID, this function will:
--- - Activate the editor
--- - If the `select` parameter is true, add the helper object to the editor's selection
--- - View the helper object in the editor
---
--- @param object table The object whose property helper should be viewed.
--- @param prop_id string The ID of the property whose helper should be viewed.
--- @param select boolean If true, the helper object will be selected in the editor.
---
function PropertyHelpers_ViewHelper(object, prop_id, select)
	local helper_object = PropertyHelpers and PropertyHelpers[object] and PropertyHelpers[object][prop_id] or false
	if helper_object and GetMap() ~= "" then
		EditorActivate()
		if select and not editor.IsSelected(helper_object) then
			editor.AddToSel({helper_object})
		end
		ViewObject(helper_object)
	end	
end

---
--- Gets the property helper object for the specified object and property ID.
---
--- If a property helper object exists for the given object and property ID, this function will return it.
---
--- @param object table The object whose property helper should be retrieved.
--- @param prop_id string The ID of the property whose helper should be retrieved.
--- @return table|boolean The property helper object, or false if it doesn't exist.
---
function PropertyHelpers_GetHelperObject(object, prop_id)
	local helper_object = PropertyHelpers and PropertyHelpers[object] and PropertyHelpers[object][prop_id] or false
	return helper_object
end

-- Notifies each helper for property changes in the Property Editor
---
--- Handles property changes in the Property Editor.
---
--- This function is called when a property is edited in the Property Editor. It updates the corresponding property helper object with the new property value.
---
--- @param ged_id string The ID of the GED (Graphical Editor Definition) object that was edited.
--- @param object table The object whose property was edited.
--- @param prop_id string The ID of the property that was edited.
--- @param old_value any The previous value of the property.
---
function OnMsg.GedPropertyEdited(ged_id, object, prop_id, old_value)
	local helpers = PropertyHelpers and PropertyHelpers[object]
	if not helpers then
		return
	end
	
	local prop_value = object:GetProperty(prop_id)
	assert(prop_value ~= nil, "Could not get property value for prop: "..tostring(prop_id))
	local prop_metadata = object:GetPropertyMetadata(prop_id)
	local prop_helper = helpers[prop_id]
	if prop_helper then
		prop_helper:Update(object, prop_value, prop_id)
	end
end

---
--- Updates all property helper objects for the specified object.
---
--- This function iterates through all the property helper objects associated with the given object and calls the `Update` method on each one, passing the object, the current property value, and the property ID.
---
--- @param object table The object whose property helpers should be updated.
---
function PropertyHelpers_UpdateAllHelpers(object)
	local helpers = PropertyHelpers[object]
	if not helpers then
		return
	end
	for prop_id, prop_helper in pairs(helpers) do
		if prop_helper then
			prop_helper:Update(object, object:GetProperty(prop_id), prop_id)
		end
	end
end

-- Rebuilds helper refs (windows_ids are changed at window close) and calls destroy function 
-- for unreferenced helper objects 
---
--- Removes any unreferenced property helper objects.
---
--- This function first rebuilds the references to the property helper objects, then iterates through all the known property helper objects and removes any that are no longer referenced.
---
--- @param ignore_ged_instance table (optional) The GED (Graphical Editor Definition) instance to ignore when rebuilding references.
---
function PropertyHelpers_RemoveUnreferenced(ignore_ged_instance)
	PropertyHelpers_RebuildRefs(ignore_ged_instance)
	for object, _ in pairs(PropertyHelpers or empty_table) do
		if not PropertyHelpers_Refs[object] then
			PropertyHelpers_DoneHelpers(object)
		end
	end
end

function OnMsg.GedOnEditorSelect(obj, selected, ged)
	if selected then
		PropertyHelpers_Init(obj, ged)
	else
		PropertyHelpers_RemoveUnreferenced(ged)
	end
end

function OnMsg.GameExitEditor()
	PropertyHelpers_RemoveUnreferenced()
end

local PropertyHelpers_LastAutoUpdate = 0
local PropertyHelpers_UpdateThread = false
local PropertyHelpers_ModifiedObjects = {}

local function HandleAutoUpdate(object, action_id)
	-- if the property helper has been changed from the ingame editor
	if object:IsKindOf("PropertyHelper") then
		local changed_object = object:EditorCallback(action_id)
		if changed_object then 
			ObjModified(changed_object)
		end
	-- if the main object has been changed from the ingame editor - update its helpers
	elseif PropertyHelpers[object] then
		for property_id , helper in pairs(PropertyHelpers[object]) do
			helper:Update(object, object:GetProperty(property_id), property_id)
		end
	end
	--else object not relevant to PropertyHelpers System
end

-- Notifies helpers that implement editor callback function for changes from the ingame editor.
-- Some updates are skipped(Hedge's column update speed is much slower than msg feedback).
-- Thread ensures that a final update is made.
function OnMsg.EditorCallback(action_id, objects, ...)
	local time_now = RealTime()
	if time_now - PropertyHelpers_LastAutoUpdate < 100 then 
		DeleteThread(PropertyHelpers_UpdateThread)
		PropertyHelpers_UpdateThread = CreateRealTimeThread(function() 
			Sleep(100)
			for objs, action_id in pairs(PropertyHelpers_ModifiedObjects) do
				for _, o in ipairs(objs) do
					if IsValid(o) then -- when action_id is EditorCallbackDelete, o can be invalid
						HandleAutoUpdate(o, action_id)
					end
				end
			end
			table.clear(PropertyHelpers_ModifiedObjects)
			PropertyHelpers_LastAutoUpdate = RealTime()
		end)
		PropertyHelpers_ModifiedObjects[objects] = action_id
		return
	end
	
	PropertyHelpers_LastAutoUpdate = time_now
	for _, o in ipairs(objects) do HandleAutoUpdate(o, action_id) end
end
