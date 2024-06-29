--- Defines a class for a terrain water object.
---
--- The `TerrainWaterObject` class represents a water object on the terrain. It has various properties that can be used to configure the water, such as the water type, area, spill tolerance, and more.
---
--- @class TerrainWaterObject
--- @field flags table The flags for the object, including `efMarker` and `cfEditorCallback`.
--- @field properties table The properties of the water object, including water type, area, spill tolerance, and more.
--- @field radius number The radius of the water object.
--- @field invalidation_box boolean The invalidation box for the water object.
--- @field object_list boolean The list of water objects.
DefineClass.TerrainWaterObject = {
	__parents = { "Object", "EditorVisibleObject", "WaterObjProperties" },
	flags = { efMarker = true, cfEditorCallback = true },
	properties = {
		{ category = "Water", id = "wtype",            name = "Water Type",       editor = "number", default = 0 },
		{ category = "Water", id = "area",             name = "Saved Area",       editor = "number", default = -1, read_only = true },
		{ category = "Water", id = "applied_area",     name = "Current Area",     editor = "number", default = -1, read_only = true },
		{ category = "Water", id = "spill_tolerance",  name = "Spill Tolerance",  editor = "number", default = 5, scale = "%", help = "Defines the allowed error in % in the applied water area before adjusting the level." },
		{ category = "Water", id = "spill_avoid_step", name = "Spill Avoid Step", editor = "number", default = guim/2, scale = "m", min = 0, help = "When spilled, try to lower the water level by that much every time before trying to fill again." },
		{ category = "Water", id = "planes",           name = "Planes",           editor = "number", default = 0, read_only = true, dont_save = true },
		{ category = "Water", id = "hborder",          name = "Height Border",    editor = "number", default = guim, scale = "m", help = "Height border to adjusting the water level in the post generation step." },
		{ category = "Water", id = "zoffset",          name = "Level Offset",     editor = "number", default = 0, scale = "m", read_only = true },
	},
	radius = 0,

	invalidation_box = false,
	object_list = false,
}

--- Returns the number of water planes associated with this TerrainWaterObject.
---
--- @return number The number of water planes.
function TerrainWaterObject:GetPlanes()
	return self.object_list and #self.object_list or 0
end
function TerrainWaterObject:Getplanes()
	return self.object_list and #self.object_list or 0
end

--- Returns the maximum number of colorization materials that can be applied to this TerrainWaterObject.
---
--- @return number The maximum number of colorization materials.
function TerrainWaterObject:GetMaxColorizationMaterials()
	return 3
end

--- Returns the plane class and step size for this TerrainWaterObject.
---
--- If the TerrainWaterObject is a WaterFillBig, it returns the WaterPlaneBig class and a step size of 40000. Otherwise, it returns the WaterPlane class and a step size of 10000.
---
--- @return Class, number The plane class and step size.
function TerrainWaterObject:GetPlaneInfo()
	if self:IsKindOf("WaterFillBig") then
		return _G["WaterPlaneBig"], 40000
	end
	return _G["WaterPlane"], 10000
end

--- Cleans up the water objects associated with this TerrainWaterObject.
---
--- This function iterates through the list of water objects associated with this TerrainWaterObject and calls `DoneObject` on each one to properly clean them up and remove them from the game world.
function TerrainWaterObject:Done()
	if self.object_list then
		for _, o in ipairs(self.object_list) do
			DoneObject(o)
		end
	end
end

---
--- Recreates the water objects associated with this TerrainWaterObject.
---
--- This function is responsible for creating and positioning the water objects that represent the water in the game world. It uses the information stored in the TerrainWaterObject, such as the invalidation box and the water plane class, to determine the number and placement of the water objects.
---
--- The function first retrieves the existing list of water objects, and then iterates over the invalidation box to create new water objects as needed. It uses a breadth-first search algorithm to find the positions where water objects should be placed, and then creates or updates the water objects accordingly.
---
--- Finally, the function removes any water objects that are no longer needed, and updates the editor's object list if the game is running in the editor.
---
--- @return boolean False if the number of water objects exceeds the maximum allowed, otherwise true.
function TerrainWaterObject:RecreateWaterObjs()
	local object_list = self.object_list or {}
	local count = 0
	local prev_count = #object_list
	self.object_list = object_list

	local plane_class, step = self:GetPlaneInfo()
	local invalidation_box = self.invalidation_box
	if not invalidation_box then
		return
	end
	invalidation_box = box(invalidation_box:min() - point(step / 2, step / 2), invalidation_box:max() + point(step / 2, step / 2))
	local sizex, sizey = terrain.GetMapSize()
	invalidation_box = IntersectRects(box(0, 0, sizex, sizey), invalidation_box)

	local planes = MulDivTrunc(invalidation_box:sizex(), invalidation_box:sizey(), step * step)
	if planes > 30000 then
		return false
	end
	local x, y, z = self:GetPosXYZ()
	z = (z or terrain.GetHeight(x, y)) + self.zoffset
	local dir_offset = { -step, 0, step, 0, 0, -step, 0, step }
	
	local half_step_sqr = (step / 2) * (step / 2)
	local step_radius = sqrt(half_step_sqr * 2)
	local start = point(x, y)
	local function pt_hash(x, y)
		return (x << 31) + y
	end
	local queue = {start}
	local tested = {[pt_hash(start:xy())] = true,}
	while #queue > 0 do
		local current = queue[1]
		table.remove(queue, 1)

		if invalidation_box:Point2DInside(current) and terrain.IsWaterNearby(current, step_radius) then
			count = count + 1
			local plane = object_list[count]
			if not plane then
				plane = plane_class:new({})
				object_list[count] = plane
			end
			local xi, yi = current:xy()
			plane:SetPos(xi, yi, z)
			for k=1,#dir_offset,2 do
				local dx, dy = dir_offset[k], dir_offset[k + 1]
				local xk, yk = xi + dx, yi + dy
				local hash = pt_hash(xk, yk)
				if not tested[hash] then
					tested[hash] = true
					table.insert(queue, point(xk, yk))
				end
			end
		end
	end
	
	for i=prev_count, count + 1, - 1 do
		DoneObject(object_list[i])
		object_list[i] = nil
	end

	self:WaterPropChanged()
	-- we can't invoke a EditorCallback for placing here, as it triggers a new wate update and causes an infinite loop
	if IsEditorActive() then
		XEditorFilters:UpdateObjectList(object_list)
	end
end

---
--- Updates the water grid and visuals for a TerrainWaterObject.
---
--- @param avoid_spill boolean Whether to avoid water spilling over the object's area.
--- @return table|nil The new invalidation box for the water object, or nil if the object has no water.
--- @return number The area of the water object that was applied.
--- @return boolean Whether water spilled over the object's area.
function TerrainWaterObject:UpdateGridAndVisuals(avoid_spill)
	local zoffset = self.zoffset
	local max_area
	local zstep = 0
	if avoid_spill then
		zstep = self.spill_avoid_step
		max_area = self.area
		if max_area > 0 then
			max_area = MulDivRound(max_area, 100 + self.spill_tolerance, 100)
		end
	end
	local new_inv_box, applied_area, spilled
	local adjusted
	while true do
		new_inv_box, applied_area, spilled = terrain.UpdateWaterGridFromObject(self, self.wtype, zoffset, max_area)
		if not spilled or zstep <= 0 then
			break
		end
		zoffset = zoffset - zstep
		adjusted = true
	end
	if adjusted then
		StoreErrorSource(self, "Water object spill")
		self.zoffset = zoffset
	end
	if not new_inv_box then
		StoreErrorSource(self, "Water object without water")
	end
	local prev_invalid_box = self.invalidation_box
	local invalid_box = false
	if prev_invalid_box and new_inv_box then
		invalid_box = Extend(new_inv_box, prev_invalid_box)
	elseif new_inv_box then
		invalid_box = new_inv_box
	elseif prev_invalid_box then
		invalid_box = prev_invalid_box
	end
	self.invalidation_box = new_inv_box
	self.applied_area = applied_area
	if invalid_box then
		self:RecreateWaterObjs()
	end
end

local WaterPassTypes = {
	{ text = "Impassable" , value = 0 }, -- impassable below certain level from water plane
	{ text = "Passable" , value = 1 },   -- do not affect passability
	{ text = "Water Pass" , value = 2 }, -- special pass type
}

-- A base class for the objects that modify the water grid, and need to be reapplied to it when rebuilding the water grid
-- Also, ApplyAllWaterObjects call RebuildGrids for such objects when a certain hash changes (see below), in order to rebuild passability
--- A base class for the objects that modify the water grid, and need to be reapplied to it when rebuilding the water grid.
---
--- Also, `ApplyAllWaterObjects` call `RebuildGrids` for such objects when a certain hash changes (see below), in order to rebuild passability.
---
--- @class TerrainWaterMod
--- @field Passability number The passability type of the water object. Can be one of the following values:
---   - 0: Impassable (impassable below certain level from water plane)
---   - 1: Passable (do not affect passability)
---   - 2: Water Pass (special pass type)
DefineClass.TerrainWaterMod = {
	__parents = { "Object" },
	flags = { cfEditorCallback = true },
	properties = {
		{ id = "Passability", editor = "dropdownlist", default = 1, items = WaterPassTypes },
	},
}
---
--- Applies all water objects to the water grid, optionally only for a specific height change bounding box.
---
--- If `height_change_bbox` is not provided, the function will clear the entire water grid and rebuild all water objects.
--- If `height_change_bbox` is provided, the function will only clear and rebuild the water objects whose invalidation boxes intersect with the given bounding box.
---
--- The function also updates the passability hash for all `TerrainWaterMod` objects and rebuilds the passability grids for any objects whose hash has changed.
---
--- @param height_change_bbox table|nil The bounding box of the terrain height changes, or `nil` to rebuild the entire water grid.
--- @param avoid_spill boolean|nil If `true`, the function will avoid spilling water objects outside their invalidation boxes.
function ApplyAllWaterObjects(height_change_bbox, avoid_spill)
	SuspendPassEdits("ApplyAllWaterObjects")
	if not height_change_bbox then
		local st = GetPreciseTicks()
		terrain.ClearWater()
		MapForEach("map", "TerrainWaterObject", TerrainWaterObject.UpdateGridAndVisuals, avoid_spill)
	else
		-- Collect all water objects, whose boxes intersect with the changed terrain height box
		-- AND, recursively, water objects whose boxes intersect with those.
		local union_box = height_change_bbox
		local water_objs = MapGet("map", "TerrainWaterObject")
		local added_objs = {}
		local dirty = true
		while dirty do
			dirty = false
			for _, water_obj in ipairs(water_objs) do
				local inv_box = water_obj.invalidation_box
				if inv_box and not added_objs[water_obj] and union_box:Intersect2D(inv_box) ~= const.irOutside then
					union_box = AddRects(inv_box, union_box)
					added_objs[water_obj] = true
					dirty = true
				end
			end
		end
		
		-- Then, clear the water grid in the resulting union box, and rebuild all water object within it.
		terrain.ClearWater(union_box)
		MapForEach(union_box, "TerrainWaterObject", TerrainWaterObject.UpdateGridAndVisuals, avoid_spill)
	end
	
	if const.pfWater then
		-- Remember old TerrainWaterMod hashes and boxes
		local old_hashes = table.copy(TerrainWaterModHashes)
		local old_boxes = table.copy(TerrainWaterModOldBoxes)
		-- Apply all TerrainWaterMod objects to the water grid, calculate new hashes
		MapForEach("map", "TerrainWaterMod", nil, nil, const.gofPermanent, function(water_mod)
			terrain.MarkWaterArea(water_mod, water_mod.Passability)
			water_mod:UpdatePassabilityHash()
		end)
		-- Rebuild passability for all objects for which the PassabilityHash changed (including newly appeared and deleted objects)
		for obj, hash in pairs(TerrainWaterModHashes) do
			local old_hash = old_hashes[obj]
			if old_hash ~= hash then
				RebuildGrids(obj:GetObjectBBox())
				if old_hash then
					RebuildGrids(old_boxes[obj])
				end
			end
			old_hashes[obj] = nil
		end
		for obj, hash in pairs(old_hashes) do
			RebuildGrids(old_boxes[obj])
		end
	end
	
	ResumePassEdits("ApplyAllWaterObjects")
end

function OnMsg.EditorCallback(id, objects, ...)
	if id == "EditorCallbackMove" or id == "EditorCallbackPlace" or id == "EditorCallbackClone" or id == "EditorCallbackDelete" then
		for i, obj in ipairs(objects) do
			if obj:IsKindOfClasses("TerrainWaterObject", "TerrainWaterMod") then
				DelayedCall(0, ApplyAllWaterObjects)
				break
			end
		end
	end
end

---
--- Saves the area covered by all `TerrainWaterObject` objects on the map.
---
--- @param hm table|nil The height map to use for calculating the water area. If not provided, the current height map will be used.
---
function SaveTerrainWaterObjArea(hm)
	local markers = MapGet("map", "TerrainWaterObject")
	if #(markers or "") == 0 then
		return
	end
	hm = hm or terrain.GetHeightGrid()
	local ww, wh = terrain.WaterMapSize()
	local wm = NewComputeGrid(ww, wh, "u", 16)
	for _, m in ipairs(markers) do
		m.area = GridWaterArea(hm, wm, m)
	end
end


function OnMsg.NewMapLoaded()
	ApplyAllWaterObjects()
end

function OnMsg.LoadGameObjectsUnpersisted()
	ApplyAllWaterObjects()
end

---
--- Defines a class for water object properties.
---
--- The `WaterObjProperties` class is used to define the properties of water objects in the game. It inherits from `PropertyObject` and `ColorizableObject`, which provide the basic functionality for managing object properties and colorization.
---
--- The class has a single property, `waterpreset`, which is used to set the water preset for the object. The preset is selected from a list of available presets, which are defined in the `WaterObjPreset` class.
---
--- When the `waterpreset` property is set, the class will automatically update the other properties of the object to match the selected preset. If the preset has modified colors, the class will also update the colorization of the object.
---
--- The class also provides a few utility functions, such as `GetMaxColorizationMaterials()`, which returns the maximum number of colorization materials for the object, and `ColorizationReadOnlyReason()` and `ColorizationPropsDontSave()`, which provide information about the colorization properties of the object.
---
DefineClass.WaterObjProperties = {
	__parents = {"PropertyObject",  "ColorizableObject" },

	properties = {
		{ id = "waterpreset", category = "Water", editor = "preset_id", preset_class = "WaterObjPreset",	autoattach_prop = true, }
	},
	waterpreset = false,
}

---
--- Returns the maximum number of colorization materials for this water object.
---
--- @return integer The maximum number of colorization materials.
---
function WaterObjProperties:GetMaxColorizationMaterials()
	return 3
end

local water_obj_prop_ids
---
--- Sets the water preset for the water object properties.
---
--- When the `waterpreset` property is set, this function will update the other properties of the object to match the selected preset. If the preset has modified colors, the function will also update the colorization of the object.
---
--- @param value string The ID of the water preset to set.
---
function WaterObjProperties:Setwaterpreset(value)
	if self.waterpreset == value then
		return
	end
	self.waterpreset = value
	local props_values = WaterObjPresets[value]
	if not props_values then return end
	for _, id in ipairs(water_obj_prop_ids) do
		self:SetProperty(id, props_values:GetProperty(id))
	end
	if props_values:AreColorsModified() then
		self:SetColorization(props_values)
	end
	self:WaterPropChanged()
end

function WaterObjProperties:WaterPropChanged()
end

---
--- Returns a reason why the colorization properties of this water object are read-only.
---
--- If the `waterpreset` property is set to a valid value, this function will return the string "Object is WaterObj and waterpreset is set to a valid value." Otherwise, it will return `false`.
---
--- @return string|boolean The reason why the colorization properties are read-only, or `false` if they are not read-only.
---
function WaterObjProperties:ColorizationReadOnlyReason()
	return self.waterpreset and self.waterpreset ~= "" and "Object is WaterObj and waterpreset is set to a valid value." or false
end

---
--- Determines whether the colorization properties of this water object should be saved.
---
--- If the `waterpreset` property is set to a valid value, this function will return `true`, indicating that the colorization properties should not be saved.
---
--- @return boolean `true` if the colorization properties should not be saved, `false` otherwise.
---
function WaterObjProperties:ColorizationPropsDontSave(i)
	return self.waterpreset and self.waterpreset ~= ""
end


--------- WaterObj to inherit from for the planes ----------------
---
--- Defines a WaterObj class that inherits from `CObject`, `ComponentCustomData`, `TerrainWaterMod`, and `WaterObjProperties`.
---
--- The WaterObj class has the following properties:
---
--- - `ColorModifier`: An RGB color value that modifies the color of the water object. This property is read-only if the `waterpreset` property is set, and is not saved if the `waterpreset` property is set.
---
--- The WaterObj class also has the following flags:
---
--- - `cfWaterObj`: Indicates that this object is a water object.
--- - `efSelectable`: Indicates that this object is not selectable.
---
DefineClass.WaterObj = {
	__parents = { "CObject", "ComponentCustomData", "TerrainWaterMod", "WaterObjProperties" },

	flags = {
		cfWaterObj = true, efSelectable = false,
	},
	properties = {
		{ id = "ColorModifier", editor = "rgbrm", default = RGB(100, 100, 100),
			read_only = function(obj) return (obj.waterpreset or "") ~= "" end,
			dont_save = function(obj) return (obj.waterpreset or "") ~= "" end,
		},
	},
}


-- Do not reorder; Just rename
local property_names = {
	"Flow Time Speed",
	"Flow Directional Speed",
	"Flow Direction",
	"Flow Magnitude",
	"Wave Texture Scale",
	"Wave Normal Strenght",
	"Specular Contribution",
	"Env Refl Contribution",
	"Color Depth Gradient",
	"Opacity Depth Gradient",
	"Refraction Strength",
	"Edge Noise Scale",
	"HighResolution1",
	"HighResolution2"
}
assert(#property_names == 4 * 3 + 2)
water_obj_prop_ids = {
	"ColorModifier"
}
for i = 1, 14 do
	local int_offset = (i - 1) / 4
	local ccd = 3 + int_offset
	local bit_offset = ((i - 1) % 4) * 8
	local mask = 0xFF
	if i == 13 or i == 14 then
		int_offset = 3
		ccd = 6
		bit_offset = (i - 13) * 16
		mask = 0xFFFF
	end
	local id = "WaterParam" .. i
	table.insert(WaterObjProperties.properties, {
		id = id, editor = "number",
		slider = true, min = 0, max = mask, scale = mask,
		default = 0, name = property_names[i], category = "Water",
		read_only = function(obj) return (obj.waterpreset or "") ~= "" end,
		dont_save = function(obj) return (obj.waterpreset or "") ~= "" end,
	})
	WaterObj["Get" .. id] = function(self)
		return (self:GetCustomData(ccd) >> bit_offset) & mask
	end
	WaterObj["Set" .. id] = function(self, value)
		value = value & mask
		local old = self:GetCustomData(ccd) & ~(mask << bit_offset)
		self:SetGameFlags(const.gofDirtyVisuals)
		local result = self:SetCustomData(ccd, old | (value << bit_offset))
		self:WaterPropChanged()
		return result
	end

	table.insert(water_obj_prop_ids, id)

	if not WaterObjProperties[id] then
		WaterObjProperties[id] = 0
	end
	WaterObjProperties["Get" .. id] = function(self)
		return self[id]
	end
	WaterObjProperties["Set" .. id] = function(self, value)
		self[id] = value
	end
end

function WaterObjProperties:OnEditorSetProperty(prop_id, old_value, ged)
	if table.find(water_obj_prop_ids, prop_id) then
		self:WaterPropChanged()
	end
	if string.starts_with(prop_id, "EditableColor") or string.starts_with(prop_id, "EditableRoughness") or string.starts_with(prop_id, "EditableMetallic") then
		self:WaterPropChanged()
	end
end

function TerrainWaterObject:WaterPropChanged()
	if not self.object_list then return end
	for _, plane in ipairs(self.object_list) do
		for _, id in ipairs(water_obj_prop_ids) do
			plane:SetProperty(id, self:GetProperty(id))
		end
		plane:SetColorization(self)
	end
end

---
--- Defines a preset for water objects in the game.
---
--- The `WaterObjPreset` class inherits from `Preset` and `WaterObjProperties`, and is used to define
--- a preset for water objects in the game. The preset includes properties such as the color modifier
--- and the water preset ID.
---
--- The preset is registered in the global `WaterObjPresets` map, and can be accessed and edited
--- through the game's editor. The preset is also displayed in the "Water presets" menu under the
--- "Editors.Art" category, with the specified icon.
---
DefineClass.WaterObjPreset = {
	__parents = {"Preset", "WaterObjProperties"},
	properties = {
		{id = "ColorModifier", editor = "rgbrm", default = RGB(100, 100, 100) },
		{id = "waterpreset", editor = false,},
	},
	GlobalMap = "WaterObjPresets",
	EditorMenubarName = "Water presets",
	EditorMenubar = "Editors.Art",
	EditorIcon = "CommonAssets/UI/Icons/blood drink drop water.png",
}

---
--- Updates the water properties of all TerrainWaterObject and WaterObj objects that use the current WaterObjPreset.
---
--- This function is called when the properties of the WaterObjPreset are changed. It iterates through all TerrainWaterObject and WaterObj objects in the map, and updates their water properties if they are using the current WaterObjPreset. This ensures that any changes to the preset are reflected in the game world.
---
--- @param self WaterObjPreset The WaterObjPreset instance whose properties have changed.
---
function WaterObjPreset:WaterPropChanged()
	local patchWaterProps = function(obj) 
		if obj:GetGameFlags(const.gofPermanent) ~= 0 and obj.waterpreset == self.id then
			obj:Setwaterpreset(false)
			obj:Setwaterpreset(self.id)
			ObjModified(obj)
		end
	end
	MapForEach("map", "TerrainWaterObject", patchWaterProps)
	MapForEach("map", "WaterObj", patchWaterProps)

	for obj in pairs(GedObjects) do
		if IsKindOf(obj, "GedMultiSelectAdapter") then
			ObjModified(obj)
		end
	end
end

---
--- Adjusts the water levels of all TerrainWaterObject objects in the map based on the provided height map.
---
--- This function iterates through all TerrainWaterObject objects in the map and updates their water levels based on the provided height map. If the water level of an object is different from the calculated level, the function sets the `zoffset` property of the object to the difference. It then updates the water grid for the object and recreates the water objects.
---
--- @param hm ComputeGrid The height map to use for calculating the water levels.
--- @param markers table|nil A table of TerrainWaterObject objects to adjust. If not provided, all TerrainWaterObject objects in the map will be adjusted.
---
function AdjustTerrainWaterObjLevels(hm, markers)
	markers = markers or MapGet("map", "TerrainWaterObject")
	if #(markers or "") == 0 then
		return
	end
	local hscale = const.TerrainHeightScale
	terrain.ClearWater()
	hm = hm or terrain.GetHeightGrid()
	local ww, wh = terrain.WaterMapSize()
	local wm = NewComputeGrid(ww, wh, "u", 16)
	for _, m in ipairs(markers) do
		local x, y, z = m:GetPosXYZ()
		m.zoffset = nil
		if m.area > 0 then
			local z0 = GridWaterLevel(hm, wm, m, m.area, m.hborder)
			if z / hscale ~= z0 / hscale then
				m.zoffset = z0 - z
				z = z0
			end
		end
		if z > 0 then
			local spilled
			m.invalidation_box, m.applied_area, spilled = terrain.UpdateWaterGridFromObject(m, m.wtype, m.zoffset, m.area)
			assert(not spilled)
			m:RecreateWaterObjs()
		end
	end
end

---
--- Places water marker objects on the map based on a provided mask.
---
--- This function takes a mask that represents the areas where water should be placed on the map. It iterates through the zones in the mask, calculates the minimum area for each zone, and creates a water object for each zone that meets the minimum area requirement. The water objects are placed at the maximum distance point within the zone, at the specified sea level.
---
--- @param mask ComputeGrid The mask that represents the areas where water should be placed.
--- @return boolean, string Whether the water markers were successfully placed, and an optional error message.
---
function PlaceWaterMarkers(mask)
	local mw, mh = terrain.GetMapSize()
	local gw, gh = mask:size()
	local tile = mw / gw
	local preset = mapdata.SeaPreset
	local level = mapdata.SeaLevel
	if level == 0 then
		return false, "Map Sea Level should be set"
	end
	local min_dist = mapdata.SeaMinDist
	local min_grid_dist = min_dist / tile
	local min_area = min_grid_dist * min_grid_dist * 22 / 7
	local zone_map = GridRepack(mask, "u", 16, true)
	local zones = GridEnumZones(zone_map, min_area)
	local level_mask = GridDest(zone_map)
	local level_dist = GridRepack(level_mask, "f", 32, true)
	local flags = const.gofGenerated | const.gofPermanent
	local visible = IsEditorActive()
	for i=1,#zones do
		local zone = zones[i]
		assert(zone.size >= min_area)
		GridMask(zone_map, level_mask, zone.level)
		GridFrame(level_mask, 1, 0)
		GridRepack(level_mask, level_dist)
		GridDistance(level_dist, tile)
		local minv, maxv, minp, maxp = GridMinMax(level_dist, true)
		if maxv > min_dist then
			local wobj = WaterFillBig:new()
			wobj:SetGameFlags(flags)
			wobj:SetVisible(visible)
			maxp = maxp * tile
			maxp = maxp:SetZ(level)
			wobj:SetPos(maxp)
			wobj:Setwaterpreset(preset)
			--DbgAddCircle(maxp, maxv) DbgAddVector(maxp, 100*guim)
		end
	end
end

----

if const.pfWater then

if FirstLoad then
	TerrainWaterModHashes = setmetatable({}, weak_keys_meta)
	TerrainWaterModOldBoxes = setmetatable({}, weak_keys_meta)
end

-- ApplyAllWaterObjects call RebuildGrids for such objects when a certain hash changes (see below), in order to rebuild passability

--- Sets the passability of the TerrainWaterMod object.
---
--- If the map is not currently being changed, this will trigger a call to `ApplyAllWaterObjects` to update the passability of all water objects.
---
--- @param value number The new passability value to set.
function TerrainWaterMod:SetPassability(value)
	self.Passability = value
	if not IsChangingMap() then
		DelayedCall(0, ApplyAllWaterObjects)
	end
end

--- Updates the passability hash and old bounding box for the TerrainWaterMod object.
---
--- The passability hash is stored in the `TerrainWaterModHashes` table, keyed by the TerrainWaterMod object. This hash is used to detect when the passability of the object has changed, triggering a call to `ApplyAllWaterObjects` to update the passability of all water objects.
---
--- The old bounding box is stored in the `TerrainWaterModOldBoxes` table, keyed by the TerrainWaterMod object. This is used to determine if the object's position or size has changed, which would also trigger a call to `ApplyAllWaterObjects`.
function TerrainWaterMod:UpdatePassabilityHash()
	TerrainWaterModHashes[self] = xxhash(self:GetPos(), self.Passability)
	TerrainWaterModOldBoxes[self] = self:GetObjectBBox()
end

function TerrainWaterMod:Done()
	TerrainWaterModHashes[self] = nil
end

end -- const.pfWater

---- 