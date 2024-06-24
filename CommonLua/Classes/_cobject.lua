--- Resets the color modifier of the specified property on the given object.
---
--- @param parentEditor table The parent editor object.
--- @param object table The object to reset the color modifier on.
--- @param property string The property to reset the color modifier for.
--- @param ... any Additional arguments (not used).
function ResetColorModifier(parentEditor, object, property, ...)
	object:SetProperty(property, const.clrNoModifier)
end

---
--- Returns a list of all collection names.
---
--- @return table A table of collection names, with an empty string as the first element.
function GetCollectionNames()
	local names = table.keys(CollectionsByName, "sort")
	table.insert(names, 1, "")
	return names
end

---
--- Generates a list of options for handling collisions with camera items.
---
--- The options depend on the class flags of the object, which determine whether the object should repulse the camera or become transparent when colliding with camera items.
---
--- @param obj table The object that is colliding with camera items.
--- @return table A list of options for handling the collision, with the appropriate default options selected based on the object's class flags.
---
function OnCollisionWithCameraItems(obj)
	-- Implementation details
end
local function OnCollisionWithCameraItems(obj)
	local class_become_transparent = GetClassEnumFlags(obj.class, const.efCameraMakeTransparent) ~= 0
	local class_repulse_camera   = GetClassEnumFlags(obj.class, const.efCameraRepulse) ~= 0	
	local items = {
		{ text = "no action", value = "no action"}, 
		{ text = "repulse camera", value = "repulse camera"}, 
		{ text = "become transparent", value = "become transparent"},
		{ text = "repulse camera & become transparent", value = "repulse camera & become transparent"},
	}
	if class_repulse_camera then
		items[2] = { text = "repulse camera (class default)", value = false }
	elseif class_become_transparent then
		items[3] = { text = "become transparent (class default)", value = false }
	else
		items[1] = { text = "no action (class default)", value = false }
	end
	return items
end

---
--- A mapping of collision handling options to the corresponding class flags for an object.
---
--- The `"repulse camera"` option sets the `efCameraRepulse` flag, which causes the object to repulse the camera when colliding with it.
--- The `"become transparent"` option sets the `efCameraMakeTransparent` flag, which causes the object to become transparent when colliding with the camera.
---
--- @field repulse camera table The collision handling option to repulse the camera, and the corresponding class flags.
--- @field become transparent table The collision handling option to become transparent, and the corresponding class flags.
---
OCCtoFlags = {
	["repulse camera"] = { efCameraMakeTransparent = false, efCameraRepulse = true },
	["become transparent"] = { efCameraMakeTransparent = true, efCameraRepulse = false },
}

---
--- Initializes a table of flag names for various engine-defined flags.
---
--- The flags are organized into four categories: Game, Enum, Class, and Component.
--- The flag names are extracted from the `const` table, which contains all the engine-defined constants.
---
--- This initialization is performed only on the first load of the script.
---
--- @return nil
---
if FirstLoad then
	FlagsByBits = {
		Game = {},
		Enum = {},
		Class = {},
		Component = {}
	}
	local const_keys = table.keys(const)
	local const_vars = EnumEngineVars("const.")
	for key in pairs(const_vars) do
		const_keys[#const_keys + 1] = key
	end
	for i = 1, #const_keys do
		local key = const_keys[i]
		local flags
		if string.starts_with(key, "gof") then
			flags = FlagsByBits.Game
		elseif string.starts_with(key, "ef") then
			flags = FlagsByBits.Enum
		elseif string.starts_with(key, "cf") then
			flags = FlagsByBits.Class
		elseif string.starts_with(key, "cof") then
			flags = FlagsByBits.Component
		end
		if flags then
			local value = const[key]
			if value ~= 0 then
				flags[LastSetBit(value) + 1] = key
			end
		end
	end
	FlagsByBits.Enum[1] = { name = "efAlive", read_only = true }
end

---
--- Flags that control the visibility and rendering of an object.
---
--- - `efVisible`: Determines whether the object is visible.
--- - `gofWarped`: Indicates whether the object is warped or distorted.
--- - `efShadow`: Determines whether the object casts a shadow.
--- - `efSunShadow`: Determines whether the object casts a shadow from the sun.
---
local efVisible = const.efVisible
local gofWarped = const.gofWarped
local efShadow = const.efShadow
local efSunShadow = const.efSunShadow

---
--- Returns a table of surface names indexed by their bit flags.
---
--- The returned table maps each surface bit flag to the corresponding surface name.
---
--- @return table<string, string> A table mapping surface bit flags to surface names.
---
local function GetSurfaceByBits()
	local flags = {}
	for name, flag in pairs(EntitySurfaces) do
		if IsPowerOf2(flag) then
			flags[LastSetBit(flag) + 1] = name
		end
	end
	return flags
end

-- MapObject is a base class for all objects that are on the map.
-- Only classes that inherit MapObject can be passed to Map enumeration functions.
---
--- The base class for all objects that are on the map.
---
--- Only classes that inherit `MapObject` can be passed to Map enumeration functions.
---
--- @class MapObject
--- @field GetEntity fun(): Entity The entity associated with this map object.
--- @field persist_baseclass string The base class name for persistence.
--- @field UnpersistMissingClass fun(self: MapObject, id: string, permanents: table): MapObject Called when a missing class is encountered during unpersisting.
---
DefineClass.MapObject = {
	__parents = { "PropertyObject" },
	GetEntity = empty_func,
	persist_baseclass = "class",
	UnpersistMissingClass = function(self, id, permanents) return self end
}

--[[@@@
@class CObject
CObjects are objects, accessible to Lua, which have a counterpart in the C++ side of the engine.
They do not have allocated memory in the Lua side, and therefore cannot store any information.
Reference: [CObject](LuaCObject.md.html)
--]]
---
--- The base class for all objects that are on the map.
---
--- Only classes that inherit `MapObject` can be passed to Map enumeration functions.
---
--- @class MapObject
--- @field GetEntity fun(): Entity The entity associated with this map object.
--- @field persist_baseclass string The base class name for persistence.
--- @field UnpersistMissingClass fun(self: MapObject, id: string, permanents: table): MapObject Called when a missing class is encountered during unpersisting.
DefineClass.CObject =
{
	__parents = { "MapObject", "ColorizableObject", "FXObject" },
	__hierarchy_cache = true,
	entity = false,
	flags = {
		efSelectable = true, efVisible = true, efWalkable = true, efCollision = true, 
		efApplyToGrids = true, efShadow = true, efSunShadow = true,
		cfConstructible = true, gofScaleSurfaces = true,
		cofComponentCollider = const.maxCollidersPerObject > 0,
	},
	radius = 0,
	texture = "",
	material_type = false,
	template_class = "",
	distortion_scale = 0,
	orient_mode = 0,
	orient_mode_bias = 0,
	max_allowed_radius = const.GameObjectMaxRadius,
	variable_entity = false,

	-- Properties, editable in the editor's property window (Ctrl+O)
	properties = {
		{ id = "ClassFlagsProp", name = "ClassFlags", editor = "flags",
			items = FlagsByBits.Class, default = 0, dont_save = true, read_only = true },
		{ id = "ComponentFlagsProp", name = "ComponentFlags", editor = "flags",
			items = FlagsByBits.Component, default = 0, dont_save = true, read_only = true },
		{ id = "EnumFlagsProp", name = "EnumFlags", editor = "flags",
			items = FlagsByBits.Enum, default = 1, dont_save = true },
		{ id = "GameFlagsProp", name = "GameFlags", editor = "flags",
			items = FlagsByBits.Game, default = 0, dont_save = true, size = 64 },
		{ id = "SurfacesProp", name = "Surfaces", editor = "flags",
			items = GetSurfaceByBits, default = 0, dont_save = true, read_only = true },
		{ id = "DetailClass", name = "Detail class", editor = "dropdownlist",
			items = {"Default", "Essential", "Optional", "Eye Candy"}, default = "Default",
			help = "Controls the graphic details level set from the options that can hide the object. Essential objects are never hidden.",
		},
		
		{ id = "Entity", editor = "text", default = "", read_only = true, dont_save = true },
		-- The default values MUST be the values these properties are initialized with at object creation
		{ id = "Pos", name = "Pos", editor = "point", default = InvalidPos(), scale = "m",
			buttons = {{ name = "View", func = "GedViewPosButton" }}, },
		{ id = "Angle", editor = "number", default = 0, min = 0, max = 360*60 - 1, slider = true, scale = "deg", no_validate = true }, -- GetAngle can return -360..+360, skip validation
		{ id = "Scale", editor = "number", default = 100, slider = true,
			min = function(self) return self:GetMinScale() end,
			max = function(self) return self:GetMaxScale() end,
		},
		{ id = "Axis",  editor = "point", default = axis_z, local_space = true,
			buttons = {{ name = "View", func = "GedViewPosButton" }}, },
		{ id = "Opacity", editor = "number", default = 100, min = 0, max = 100, slider = true },
		{ id = "StateCategory", editor = "choice", items = function() return ArtSpecConfig and ArtSpecConfig.ReturnAnimationCategories end, default = "All", dont_save = true },
		{ id = "StateText", name = "State/Animation", editor = "combo", default = "idle", items = function(obj) return obj:GetStatesTextTable(obj.StateCategory) end, show_recent_items = 7,
			help = "Sets the mesh state or animation of the object.",
		},
		{ id = "TestStateButtons", editor = "buttons", default = false, dont_save = true, buttons = {
			{name = "Play once(c)", func = "BtnTestOnce"},
			{name = "Loop(c)", func = "BtnTestLoop"},
			{name = "Test(c)", func = "BtnTestState"}, 
			{name = "Play once", func = "BtnTestOnce", param = "no_compensate"},
			{name = "Loop", func = "BtnTestLoop", param = "no_compensate"},
			{name = "Test", func = "BtnTestState", param = "no_compensate"},
		}},
		{ id = "ForcedLOD", name = "Visualise LOD", editor = "number", default = 0, min = 0, slider = true, dont_save = true, help = "Forces specific lod to show.",
			max = function(obj)
				return obj:IsKindOf("GedMultiSelectAdapter") and 0 or (Max(obj:GetLODsCount(), 1) - 1)
			end,
			no_edit = function(obj) return not IsValid(obj) or not obj:HasEntity() or obj:GetEntity() == "InvisibleObject" end
		},
		{ id = "ForcedLODState", name = "Forced LOD", editor = "dropdownlist",
			items = function(obj) return obj:GetLODsTextTable() end, default = "Automatic",
		},
		{ id = "Groups", editor = "string_list", default = false, items = function() return table.keys2(Groups or empty_table, "sorted") end, arbitrary_value = true,
			help = "Assigns the object under one or more different names, by which it is referenced from the gameplay logic via markers or Lua code.",
		},
		
		{ id = "ColorModifier", editor = "rgbrm", default = RGB(100, 100, 100) },
		{ id = "Saturation", name = "Saturation(Debug)", editor = "number", slider = true, min = 0, max = 255, default = 128 },
		{ id = "Gamma", name = "Gamma(Debug)", editor = "color", default = RGB(128, 128, 128) },
		
		{ id = "SIModulation", editor = "number", default = 100, min = 0, max = 255, slider = true},
		{ id = "SIModulationManual", editor = "bool", default = false, read_only = true},
		
		{ id = "Occludes", editor = "bool", default = false },
		{ id = "Walkable", editor = "bool", default = true },
		{ id = "ApplyToGrids", editor = "bool", default = true },
		{ id = "IgnoreHeightSurfaces", editor = "bool", default = false, },
		{ id = "Collision", editor = "bool", default = true },
		{ id = "Visible",   editor = "bool", default = true, dont_save = true },
		{ id = "SunShadow", name = "Shadow from Sun", editor = "bool", default = function(obj) return GetClassEnumFlags(obj.class, efSunShadow) ~= 0 end },
		{ id = "CastShadow", name = "Shadow from All", editor = "bool", default = function(obj) return GetClassEnumFlags(obj.class, efShadow) ~= 0 end },
		{ id = "Mirrored", name = "Mirrored", editor = "bool", default = false },
		{ id = "OnRoof", name = "On Roof", editor = "bool", default = false },
		{ id = "DontHideWithRoom", name = "Don't hide with room", editor = "bool", default = false,
			no_edit = not const.SlabSizeX, dont_save = not const.SlabSizeX,
		},
		
		{ id = "SkewX",     name = "Skew X",       editor = "number", default = 0 },
		{ id = "SkewY",     name = "Skew Y",       editor = "number", default = 0 },
		{ id = "ClipPlane", name = "Clip Plane",   editor = "number", default = 0, read_only = true, dont_save = true },
		{ id = "Radius",    name = "Radius (m)",   editor = "number", default = 0, scale = guim, read_only = true, dont_save = true },

		{ id = "AnimSpeedModifier", name = "Anim Speed Modifier", editor = "number", default = 1000, min = 0, max = 65535, slider = true },
		
		{ id = "OnCollisionWithCamera", editor = "choice", default = false, items = OnCollisionWithCameraItems, },
		{ id = "Warped", editor = "bool", default = function (obj) return GetClassGameFlags(obj.class, gofWarped) ~= 0 end },
		
		-- Required for map saving purposes only.
		{ id = "CollectionIndex", name = "Collection Index", editor = "number", default = 0, read_only = true },
		{ id = "CollectionName", name = "Collection Name", editor = "choice",
			items = GetCollectionNames, default = "", dont_save = true,
			buttons = {{ name = "Collection Editor", func = function(self)
				if self:GetRootCollection() then
					OpenCollectionEditorAndSelectCollection(self)
				end
			end }},
		},
	},
	
	SelectionPropagate = empty_func,
	GedTreeCollapsedByDefault = true, -- for Ged object editor (selection properties)
	PropertyTabs = {
		{ TabName = "Object", Categories = { Misc = true, ["Random Map"] = true, Child = true, } },
	},
	IsVirtual = empty_func,
	GetDestlock = empty_func,
}

---
--- Returns the minimum and maximum scale limits for the CObject.
---
--- If `mapdata.ArbitraryScale` is true, the limits are 10 and `const.GameObjectMaxScale`.
--- Otherwise, the limits are retrieved from the `ArtSpecConfig.ScaleLimits` table, using the object's `editor_category` and `editor_subcategory` properties.
--- If the limits cannot be found in the config, the default limits of 10 and 250 are returned.
---
--- @return number min_scale
--- @return number max_scale
function CObject:GetScaleLimits()
	if mapdata.ArbitraryScale then
		return 10, const.GameObjectMaxScale
	end
	
	local data = EntityData[self:GetEntity() or false]
	local limits = data and rawget(_G, "ArtSpecConfig") and ArtSpecConfig.ScaleLimits
	if limits then
		local cat, sub = data.editor_category, data.editor_subcategory
		local limits =
			cat and sub and limits[cat][sub] or
			cat and limits[cat]
		if limits then
			return limits[1], limits[2]
		end
	end
	return 10, 250
end

---
--- Returns the minimum and maximum scale limits for the CObject.
---
--- The minimum scale limit is retrieved from the first element of the scale limits returned by `CObject:GetScaleLimits()`.
---
--- The maximum scale limit is retrieved from the second element of the scale limits returned by `CObject:GetScaleLimits()`.
---
--- @return number min_scale The minimum scale limit for the CObject.
--- @return number max_scale The maximum scale limit for the CObject.
function CObject:GetMinScale() return self:GetScaleLimits() end
function CObject:GetMaxScale() return select(2, self:GetScaleLimits()) end
---
--- Sets the scale of the CObject, clamped to the minimum and maximum scale limits.
---
--- @param scale number The desired scale for the CObject.
function CObject:SetScaleClamped(scale)
	self:SetScale(Clamp(scale, self:GetScaleLimits()))
end

---
--- Returns the current value of the CObject's enum flags.
---
--- @return number enum_flags The current value of the CObject's enum flags.
function CObject:GetEnumFlagsProp()
	return self:GetEnumFlags()
end

---
--- Sets the enum flags of the CObject to the specified value.
---
--- This function first sets the enum flags of the CObject to the specified `val` value, and then clears any enum flags that are not set in the `val` value.
---
--- @param val number The new value for the CObject's enum flags.
---
function CObject:SetEnumFlagsProp(val)
	self:SetEnumFlags(val)
	self:ClearEnumFlags(bnot(val))
end

---
--- Returns the current value of the CObject's game flags.
---
--- @return number game_flags The current value of the CObject's game flags.
function CObject:GetGameFlagsProp()
	return self:GetGameFlags()
end

---
--- Defines constants for the detail class of a CObject.
---
--- `gofDetailClass0` and `gofDetailClass1` are bit flags that represent the detail class of a CObject.
--- `gofDetailClassMask` is a mask that can be used to extract the detail class from the CObject's game flags.
---
--- @field gofDetailClass0 number A bit flag representing the "Default" detail class.
--- @field gofDetailClass1 number A bit flag representing the "Essential", "Optional", or "Eye Candy" detail classes.
--- @field gofDetailClassMask number A mask that can be used to extract the detail class from the CObject's game flags.
local gofDetailClass0, gofDetailClass1 = const.gofDetailClass0, const.gofDetailClass1
local gofDetailClassMask = const.gofDetailClassMask
--- Defines a table of detail class names and their corresponding bit flag values.
---
--- The detail class of a CObject is represented by a combination of two bit flags:
--- - `gofDetailClass0`: Represents the "Default" detail class.
--- - `gofDetailClass1`: Represents the "Essential", "Optional", or "Eye Candy" detail classes.
---
--- This table maps the detail class names to their corresponding bit flag values, which are defined in the `const` table.
---
--- @field ["Default"] number The bit flag value for the "Default" detail class.
--- @field ["Essential"] number The bit flag value for the "Essential" detail class.
--- @field ["Optional"] number The bit flag value for the "Optional" detail class.
--- @field ["Eye Candy"] number The bit flag value for the "Eye Candy" detail class.
local s_DetailsValue = {
	["Default"] = const.gofDetailClassDefaultMask,
	["Essential"] = const.gofDetailClassEssential,
	["Optional"] = const.gofDetailClassOptional,
	["Eye Candy"] = const.gofDetailClassEyeCandy,
}
local s_DetailsName = {}
for name, value in pairs(s_DetailsValue) do
	s_DetailsName[value] = name
end

---
--- Returns the name of the detail class corresponding to the given detail class mask.
---
--- @param mask number The detail class mask.
--- @return string The name of the detail class.
function GetDetailClassMaskName(mask)
	return s_DetailsName[mask]
end

---
--- Sets the game flags of the CObject and updates the detail class accordingly.
---
--- @param val number The new value for the game flags.
function CObject:SetGameFlagsProp(val)
	self:SetGameFlags(val)
	self:ClearGameFlags(bnot(val))
	self:SetDetailClass(s_DetailsName[val & gofDetailClassMask])
end

---
--- Returns the class flags of the CObject.
---
--- @return number The class flags of the CObject.
function CObject:GetClassFlagsProp()
	return self:GetClassFlags()
end

---
--- Returns the component flags of the CObject.
---
--- @return number The component flags of the CObject.
function CObject:GetComponentFlagsProp()
	return self:GetComponentFlags()
end

---
--- Returns the enum flags of the CObject.
---
--- @return number The enum flags of the CObject.
function CObject:GetEnumFlagsProp()
	return self:GetEnumFlags()
end

---
--- Returns the surface mask of the CObject.
---
--- @return number The surface mask of the CObject.
function CObject:GetSurfacesProp()
	return GetSurfacesMask(self)
end

---
--- Returns the detail class of the CObject.
---
--- @return string The name of the detail class.
function CObject:GetDetailClass()
	return IsValid(self) and s_DetailsName[self:GetGameFlags(gofDetailClassMask)] or s_DetailsName[0]
end

---
--- Sets the detail class of the CObject by updating the corresponding game flags.
---
--- @param details string The name of the detail class to set.
function CObject:SetDetailClass(details)
	local value = s_DetailsValue[details]
	if band(value, gofDetailClass0) ~= 0 then
		self:SetGameFlags(gofDetailClass0)
	else
		self:ClearGameFlags(gofDetailClass0)
	end
	if band(value, gofDetailClass1) ~= 0 then
		self:SetGameFlags(gofDetailClass1)
	else
		self:ClearGameFlags(gofDetailClass1)
	end
end

---
--- Sets the shadow-only state of the CObject.
---
--- @param bSet boolean Whether to set the CObject as shadow-only.
--- @param time number The time in seconds to transition the opacity change.
function CObject:SetShadowOnly(bSet, time)
	if not time or IsEditorActive() then
		time = 0
	end
	if bSet then
		self:SetHierarchyGameFlags(const.gofSolidShadow)
		self:SetOpacity(0, time)
	else
		self:ClearHierarchyGameFlags(const.gofSolidShadow)
		self:SetOpacity(100, time)
	end
end

---
--- Sets the gamma value of the CObject.
---
--- @param value number The new gamma value to set.
function CObject:SetGamma(value)
	local saturation = GetAlpha(self:GetSatGamma())
	self:SetSatGamma(SetA(value, saturation))
end

---
--- Gets the gamma value of the CObject.
---
--- @return number The gamma value of the CObject.
function CObject:GetGamma()
	return SetA(self:GetSatGamma(), 255)
end

---
--- Sets the saturation value of the CObject.
---
--- @param value number The new saturation value to set.
function CObject:SetSaturation(value)
	local old = self:GetSatGamma()
	self:SetSatGamma(SetA(old, value))
end

---
--- Gets the saturation value of the CObject.
---
--- @return number The saturation value of the CObject.
function CObject:GetSaturation()
	return GetAlpha(self:GetSatGamma())
end

---
--- Handles editor property changes for a CObject.
---
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged table The GED (Graphical Editor) object associated with the property.
--- @param multi boolean Whether the property change was part of a multi-object edit.
---
--- This function is called when a property of the CObject is changed in the editor. It performs the following actions:
---
--- 1. Calls the `OnEditorSetProperty` function of the `ColorizableObject` class.
--- 2. If the changed property is "Saturation" or "Gamma", and the `hr.UseSatGammaModifier` is 0, it sets `hr.UseSatGammaModifier` to 1 and calls `RecreateRenderObjects()`.
--- 3. If the changed property is "ForcedLODState", and the CObject is an `AutoAttachObject`, it calls the `SetAutoAttachMode` function with the current auto attach mode.
--- 4. If the changed property is "SIModulation", it sets the `SIModulationManual` property based on whether the new value is the default value.
---
function CObject:OnEditorSetProperty(prop_id, old_value, ged, multi)
	ColorizableObject.OnEditorSetProperty(self, prop_id, old_value, ged, multi)
	
	if (prop_id == "Saturation" or prop_id == "Gamma") and hr.UseSatGammaModifier == 0 then
		hr.UseSatGammaModifier = 1
		RecreateRenderObjects()
	elseif prop_id == "ForcedLODState" then
		if self:IsKindOf("AutoAttachObject") then
			self:SetAutoAttachMode(self:GetAutoAttachMode())
		end
	elseif prop_id == "SIModulation" then
		local prop_meta = self:GetPropertyMetadata(prop_id)
		self.SIModulationManual = self:GetProperty(prop_id) ~= prop_meta.default
	end
end

---
--- Resets the `ObjectsShownOnPreSave` table to `false` on first load.
---
--- This code is executed when the script is first loaded, and it sets the `ObjectsShownOnPreSave` table to `false`. This table is used to store information about objects that were made visible or had their opacity changed during the pre-save process, so that their state can be restored after the map is saved.
---
--- @param FirstLoad boolean Whether this is the first time the script has been loaded.
if FirstLoad then
	ObjectsShownOnPreSave = false
end

---
--- Handles the pre-save process for the map, ensuring that certain objects are visible and have their opacity set to 100% before the map is saved.
---
--- This function is called when the game receives the `PreSaveMap` message, which occurs before the map is saved. It iterates through all `CObject` instances in the map and performs the following actions:
---
--- 1. If the object has the `gofSolidShadow` game flag set and is not a `Decal`, its current opacity is stored in the `ObjectsShownOnPreSave` table, and its opacity is set to 100%.
--- 2. If the object is not visible (its `efVisible` enum flag is 0), and it is not an `EditorVisibleObject` or a `Slab`, its visibility is set to visible and its state is stored in the `ObjectsShownOnPreSave` table.
---
--- The `ObjectsShownOnPreSave` table is used to store the state of the objects that were modified during the pre-save process, so that their state can be restored after the map is saved.
---
function OnMsg.PreSaveMap()
	ObjectsShownOnPreSave = {}
	MapForEach("map", "CObject", function(o)
		if o:GetGameFlags(const.gofSolidShadow) ~= 0 and not IsKindOf(o, "Decal") then
			ObjectsShownOnPreSave[o] = o:GetOpacity()
			o:SetOpacity(100)
		elseif o:GetEnumFlags(const.efVisible) == 0 then
			local skip = IsKindOf(o, "EditorVisibleObject") or (const.SlabSizeX and IsKindOf(o, "Slab"))
			if not skip then
				ObjectsShownOnPreSave[o] = true
				o:SetEnumFlags(const.efVisible)
			end
		end
	end)
end


---
--- Restores the visibility and opacity of objects that were modified during the pre-save process.
---
--- This function is called when the game receives the `PostSaveMap` message, which occurs after the map has been saved. It iterates through the `ObjectsShownOnPreSave` table, which was populated during the `OnMsg.PreSaveMap` function, and restores the original visibility and opacity of the affected objects.
---
--- For objects that had their opacity set to 100% during the pre-save process, their original opacity is restored. For objects that were made visible during the pre-save process, their visibility is restored to the original state.
---
--- After the objects have been restored, the `ObjectsShownOnPreSave` table is set to `false` to indicate that the post-save process has completed.
---
--- @param ObjectsShownOnPreSave table A table that stores the original visibility and opacity of objects that were modified during the pre-save process.
function OnMsg.PostSaveMap()
	for o, opacity in pairs(ObjectsShownOnPreSave) do
		if IsValid(o) then
			if type(opacity) == "number" then
				o:SetOpacity(opacity)
			else
				o:ClearEnumFlags(const.efVisible)
			end
		end
	end
	ObjectsShownOnPreSave = false
end

---
--- Returns the collision behavior with the camera for this CObject.
---
--- This function checks the default collision behavior for the class of this CObject, as well as the current collision behavior set for this specific CObject instance. It returns a string indicating the current collision behavior, which can be one of the following:
---
--- - "repulse camera"
--- - "become transparent"
--- - "repulse camera & become transparent"
--- - "no action"
---
--- If the current collision behavior matches the default behavior for the class, this function returns `false`.
---
--- @return string|boolean The current collision behavior with the camera, or `false` if it matches the default behavior.
function CObject:GetOnCollisionWithCamera()
	local become_transparent_default = GetClassEnumFlags(self.class, const.efCameraMakeTransparent) ~= 0
	local repulse_camera_default     = GetClassEnumFlags(self.class, const.efCameraRepulse) ~= 0
	local become_transparent         = self:GetEnumFlags(const.efCameraMakeTransparent) ~= 0
	local repulse_camera             = self:GetEnumFlags(const.efCameraRepulse) ~= 0
	if become_transparent_default == become_transparent and repulse_camera_default == repulse_camera then
		return false
	end
	if repulse_camera and not become_transparent then
		return "repulse camera"
	end
	if become_transparent and not repulse_camera then
		return "become transparent"
	end
	if become_transparent and repulse_camera then
		return "repulse camera & become transparent"
	end
	return "no action"
end

---
--- Sets the collision behavior with the camera for this CObject.
---
--- This function allows setting the collision behavior with the camera for this CObject. The behavior can be one of the following:
---
--- - "repulse camera"
--- - "become transparent"
--- - "repulse camera & become transparent"
--- - "no action"
---
--- The function will set the appropriate enum flags on the CObject to reflect the desired behavior.
---
--- @param value string The desired collision behavior with the camera. Can be one of the strings listed above.
---
function CObject:SetOnCollisionWithCamera(value)
	local cmt, cr
	if value then
		local flags = OCCtoFlags[value]
		cmt = flags and flags.efCameraMakeTransparent 
		cr = flags and flags.efCameraRepulse
	end
	if cmt == nil then
		cmt = GetClassEnumFlags(self.class, const.efCameraMakeTransparent) ~= 0 -- class default
	end
	if cmt then
		self:SetEnumFlags(const.efCameraMakeTransparent)
	else
		self:ClearEnumFlags(const.efCameraMakeTransparent)
	end
	if cr == nil then
		cr = GetClassEnumFlags(self.class, const.efCameraRepulse) ~= 0 -- class default
	end
	if cr then
		self:SetEnumFlags(const.efCameraRepulse)
	else
		self:ClearEnumFlags(const.efCameraRepulse)
	end
end

---
--- Gets the name of the collection that this CObject belongs to.
---
--- @return string The name of the collection, or an empty string if the CObject is not in a collection.
---
function CObject:GetCollectionName()
	local col = self:GetCollection()
	return col and col.Name or ""
end

---
--- Sets the name of the collection that this CObject belongs to.
---
--- This function allows setting the collection that this CObject belongs to. If the CObject was previously in a different collection, it will be removed from that collection and added to the new one.
---
--- @param name string The name of the collection to set for this CObject.
---
function CObject:SetCollectionName(name)
	local col = CollectionsByName[name]
	local prev_col = self:GetCollection()
	if prev_col ~= col then
		self:SetCollection(col)
	end
end

---
--- Returns a list of objects that are "connected to", or "a part of" this object.
---
--- These objects "go together" in undo and copy logic; e.g. it is assumed changes to the Room can update/delete/create its child Slabs.
---
--- @return table A list of objects that are related to this object.
---
function CObject:GetEditorRelatedObjects()
	-- return objects that are "connected to", or "a part of" this object
	-- these objects "go together" in undo and copy logic; e.g. is it assumed changes to the Room can update/delete/create its child Slabs
end

---
--- Returns an object that "owns" this object logically, e.g. a Room owns all its Slabs.
---
--- Changes to the "parent" will be tracked by undo when the "child" is updated/deleted/created.
--- It is also assumed that moving the "parent" will auto-move the "children".
---
--- @return CObject The parent object of this CObject, or nil if this CObject has no parent.
---
function CObject:GetEditorParentObject()
	-- return an object that "owns" this object logically, e.g. a Room owns all its Slabs
	-- changes to the "parent" will be tracked by undo when the "child" is updated/deleted/created
	-- it is also assumed that moving the "parent" will auto-move the "childen"
end

-- Used to identify objects on existing maps that don't have a handle, e.g. in map patches.
-- Returns a hash of the basic object properties, but some classes like Container and Slab
-- this is not sufficient, and they have separate implementations.
---
--- Returns a unique identifier for this CObject.
---
--- The identifier is calculated using the object's class, entity, position, axis, angle, and scale.
---
--- @return string A unique identifier for this CObject.
---
function CObject:GetObjIdentifier()
	return xxhash(self.class, self.entity, self:GetPos(), self:GetAxis(), self:GetAngle(), self:GetScale())
end

--- Returns the material type of this CObject.
---
--- @return string The material type of this CObject.
function CObject:GetMaterialType()
	return self.material_type
end

-- copy functions exported from C
for name, value in pairs(g_CObjectFuncs) do
	CObject[name] = value
end

-- table used for keeping references in the C code to Lua objects
---
--- A table that maps C objects to their corresponding Lua objects.
--- This table uses weak keys and values, allowing the Lua objects to be garbage collected when they are no longer referenced.
---
--- @type table<CObject, table>
---
MapVar("__cobjectToCObject", {}, weak_keyvalues_meta)

-- table with destroyed objects
---
--- A table that maps destroyed CObject instances to a boolean value.
--- This table uses weak keys, allowing the CObject instances to be garbage collected when they are no longer referenced.
---
--- @type table<CObject, boolean>
---
MapVar("DeletedCObjects", {}, weak_keyvalues_meta)

--- Creates a new Lua object by calling the `new` method on the metatable of the provided Lua object.
---
--- @param luaobj table The Lua object to create a new instance of.
--- @return table A new instance of the Lua object.
function CreateLuaObject(luaobj)
	return luaobj.new(getmetatable(luaobj), luaobj)
end

---
--- Retrieves a new CObject instance from the C++ implementation.
---
--- @param class table The class of the CObject to create.
--- @param components table The components to initialize the CObject with.
--- @return CObject A new CObject instance.
---
local __PlaceObject = __PlaceObject
--- Creates a new CObject instance.
---
--- @param class table The class of the CObject to create.
--- @param luaobj table The Lua object to create a new instance of.
--- @param components table The components to initialize the CObject with.
--- @return table A new instance of the CObject.
function CObject.new(class, luaobj, components)
	if luaobj and luaobj[true] then -- constructed from C
		return luaobj
	end
	local cobject = __PlaceObject(class.class, components)
	assert(cobject)
	if cobject then
		if luaobj then
			luaobj[true] = cobject
		else
			luaobj = { [true] = cobject }
		end
		__cobjectToCObject[cobject] = luaobj
	end
	setmetatable(luaobj, class)
	return luaobj
end

---
--- Deletes a CObject instance.
---
--- @param fromC boolean If true, the CObject is being deleted from C++ code. If false, the CObject is being deleted from Lua code.
---
function CObject:delete(fromC)
	if not self[true] then return end
	self:RemoveLuaReference()
	self:SetCollectionIndex(0)

	DeletedCObjects[self] = true
	if not fromC then
		__DestroyObject(self)
	end
	__cobjectToCObject[self[true]] = nil
	self[true] = false
end

---
--- Retrieves the collection that the CObject is a part of.
---
--- @return table|boolean The collection that the CObject is a part of, or false if the CObject is not part of a collection.
---
function CObject:GetCollection()
	local idx = self:GetCollectionIndex()
	return idx ~= 0 and Collections[idx] or false
end

---
--- Retrieves the root collection that the CObject is a part of.
---
--- @return table|boolean The root collection that the CObject is a part of, or false if the CObject is not part of a collection.
---
function CObject:GetRootCollection()
	local idx = Collection.GetRoot(self:GetCollectionIndex())
	return idx ~= 0 and Collections[idx] or false
end

---
--- Sets the collection that the CObject is a part of.
---
--- @param collection table|boolean The collection to set the CObject to, or false to remove the CObject from any collection.
--- @return boolean True if the collection was successfully set, false otherwise.
---
function CObject:SetCollection(collection)
	return self:SetCollectionIndex(collection and collection.Index or false)
end

---
--- Returns whether the CObject is visible.
---
--- @return boolean True if the CObject is visible, false otherwise.
---
function CObject:GetVisible()
	return self:GetEnumFlags( efVisible ) ~= 0
end

---
--- Sets the visibility of the CObject.
---
--- @param value boolean Whether the CObject should be visible or not.
---
function CObject:SetVisible(value)
	if value then
		self:SetEnumFlags( efVisible )
	else
		self:ClearEnumFlags( efVisible )
	end
end

---
--- A table that caches the forced LOD state for CObject instances.
---
local cached_forced_lods = {}

---
--- Caches the forced LOD state for the CObject instance.
---
--- This function stores the current forced LOD state of the CObject in the `cached_forced_lods` table, so that it can be restored later using the `RestoreForcedLODState` function.
---
--- @function CObject:CacheForcedLODState
--- @return nil
function CObject:CacheForcedLODState()
	cached_forced_lods[self] = self:GetForcedLOD() or self:GetForcedLODMin()
end

---
--- Restores the forced LOD state of the CObject instance.
---
--- This function retrieves the previously cached forced LOD state of the CObject and sets it back on the object. If the cached state was a number, it sets the forced LOD index to that value. If the cached state was `true`, it sets the forced LOD to the minimum. If the cached state was `false`, it clears the forced LOD.
---
--- After restoring the forced LOD state, the function removes the cached state from the `cached_forced_lods` table.
---
--- @function CObject:RestoreForcedLODState
--- @return nil
function CObject:RestoreForcedLODState()
	if type(cached_forced_lods[self]) == "number" then
		self:SetForcedLOD(cached_forced_lods[self])
	elseif cached_forced_lods[self] then
		self:SetForcedLODMin(true)
	else
		self:SetForcedLOD(const.InvalidLODIndex)
	end

	cached_forced_lods[self] = nil
end

---
--- Returns a table of strings representing the different LOD (Level of Detail) levels for the CObject.
---
--- The table contains the following entries:
---   - "Automatic": Represents automatic LOD selection.
---   - "LOD 0", "LOD 1", ...: Represents the different LOD levels, starting from 0.
---   - "Minimum": Represents the minimum LOD level.
---
--- @return table A table of strings representing the different LOD levels.
function CObject:GetLODsTextTable()
	local lods = {}

	lods[1] = "Automatic"

	for i = 1, Max(self:GetLODsCount(), 1) do
		lods[i + 1] = string.format("LOD %s", i - 1)
	end

	lods[#lods + 1] = "Minimum"

	return lods
end

---
--- Returns the current forced LOD (Level of Detail) state of the CObject instance.
---
--- The function first checks the `cached_forced_lods` table for a previously cached forced LOD state. If a cached state is found, it is returned.
---
--- If no cached state is found, the function retrieves the current forced LOD state of the CObject by calling `self:GetForcedLOD()` or `self:GetForcedLODMin()`. The returned value is then categorized and returned as a string:
---
--- - If the forced LOD state is a number, it is returned as a string in the format "LOD {number}".
--- - If the forced LOD state is `true`, it is returned as the string "Minimum".
--- - If the forced LOD state is `false` or `const.InvalidLODIndex`, it is returned as the string "Automatic".
---
--- @return string The current forced LOD state of the CObject instance.
function CObject:GetForcedLODState()
	local lodState = cached_forced_lods[self]
	
	if lodState == nil then
		lodState = self:GetForcedLOD() or self:GetForcedLODMin()
	end

	if type(lodState) == "number" then
		return string.format("LOD %s", lodState)
	elseif lodState then
		return "Minimum"
	else
		return "Automatic"
	end
end

---
--- Sets the forced LOD (Level of Detail) state of the CObject instance.
---
--- The function first checks the `cached_forced_lods` table for a previously cached forced LOD state. If a cached state is found, it is returned.
---
--- If no cached state is found, the function retrieves the current forced LOD state of the CObject by calling `self:GetForcedLOD()` or `self:GetForcedLODMin()`. The returned value is then categorized and returned as a string:
---
--- - If the forced LOD state is a number, it is returned as a string in the format "LOD {number}".
--- - If the forced LOD state is `true`, it is returned as the string "Minimum".
--- - If the forced LOD state is `false` or `const.InvalidLODIndex`, it is returned as the string "Automatic".
---
--- @param value string The new forced LOD state to set. Can be "Minimum", "Automatic", or a string in the format "LOD {number}".
function CObject:SetForcedLODState(value)
	local cache_forced_lod = nil
	if value == "Minimum" then
		self:SetForcedLODMin(true)
		cache_forced_lod = true
	elseif value == "Automatic" then
		self:SetForcedLOD(const.InvalidLODIndex)
		cache_forced_lod = false
	else
		local lodsTable = self:GetLODsTextTable()
		local targetIndex = nil

		for index, tableValue in ipairs(lodsTable) do
			if value == tableValue then
				targetIndex = index
				break
			end
		end

		if targetIndex then
			local lod = Max(targetIndex - 2, 0)
			cache_forced_lod = lod
			self:SetForcedLOD(lod)
		end
	end
	if cached_forced_lods[self] ~= nil then
		cached_forced_lods[self] = cache_forced_lod
	end
end

---
--- Returns whether the CObject instance is currently warped.
---
--- @return boolean Whether the CObject instance is warped.
function CObject:GetWarped()
	return self:GetGameFlags(gofWarped) ~= 0
end

---
--- Sets the warped state of the CObject instance.
---
--- If `value` is `true`, the CObject instance is set to be warped by setting the `gofWarped` game flag.
--- If `value` is `false`, the `gofWarped` game flag is cleared, setting the CObject instance to be not warped.
---
--- @param value boolean The new warped state to set for the CObject instance.
function CObject:SetWarped(value)
	if value then 
		self:SetGameFlags(gofWarped)
	else
		self:ClearGameFlags(gofWarped)
	end
end

--- Returns whether the object is in the process of being destructed
--@cstyle bool IsBeingDestructed(object obj)
--@param obj object
---
--- Returns whether the given object is in the process of being destructed.
---
--- @param obj object The object to check.
--- @return boolean Whether the object is being destructed.
function IsBeingDestructed(obj)
	return DeletedCObjects[obj] or obj:IsBeingDestructed()
end

---
--- Sets whether the CObject instance should use real-time animation.
---
--- If `bRealtime` is `true`, the `gofRealTimeAnim` game flag is set on the CObject instance, enabling real-time animation.
--- If `bRealtime` is `false`, the `gofRealTimeAnim` game flag is cleared, disabling real-time animation.
---
--- @param bRealtime boolean Whether to enable or disable real-time animation for the CObject instance.
---
function CObject:SetRealtimeAnim(bRealtime)
	if bRealtime then
		self:SetHierarchyGameFlags(const.gofRealTimeAnim)
	else
		self:ClearHierarchyGameFlags(const.gofRealTimeAnim)
	end
end

---
--- Returns whether the CObject instance is currently using real-time animation.
---
--- @return boolean Whether the CObject instance is using real-time animation.
function CObject:GetRealtimeAnim()
	return self:GetGameFlags(const.gofRealTimeAnim) ~= 0
end

-- Support for groups
---
--- Initializes the global `Groups` table to an empty table.
---
--- The `Groups` table is used to store groups of `CObject` instances. This mapping allows `CObject` instances to be associated with one or more groups.
---
--- @field Groups table A table that maps group names to lists of `CObject` instances.
---
MapVar("Groups", {})
---
--- Finds the first occurrence of an element in a table.
---
--- @param t table The table to search.
--- @param value any The value to search for.
--- @return integer|nil The index of the first occurrence of the value, or `nil` if not found.
---
local find = table.find
local remove_entry = table.remove_entry

---
--- Adds the CObject instance to the specified group.
---
--- If the group does not exist, it is created. The CObject instance is then added to the group.
---
--- @param group_name string The name of the group to add the CObject instance to.
---
function CObject:AddToGroup(group_name)
	local group = Groups[group_name]
	if not group then
		group = {}
		Groups[group_name] = group
	end
	if not find(group, self) then
		group[#group + 1] = self
		self.Groups = self.Groups or {}
		self.Groups[#self.Groups + 1] = group_name
	end
end

---
--- Checks if the CObject instance is a member of the specified group.
---
--- @param group_name string The name of the group to check.
--- @return boolean Whether the CObject instance is a member of the specified group.
---
function CObject:IsInGroup(group_name)
	return find(self.Groups, group_name)
end

---
--- Removes the CObject instance from the specified group.
---
--- If the CObject instance is not a member of the specified group, this function does nothing.
---
--- @param group_name string The name of the group to remove the CObject instance from.
---
function CObject:RemoveFromGroup(group_name)
	remove_entry(Groups[group_name], self)
	remove_entry(self.Groups, group_name)
end

---
--- Removes the CObject instance from all groups it is a member of.
---
--- If the CObject instance is not a member of any groups, this function does nothing.
---
function CObject:RemoveFromAllGroups()
	local Groups = Groups
	for i, group_name in ipairs(self.Groups) do
		remove_entry(Groups[group_name], self)
	end
	self.Groups = nil
end

--[[@@@
Called when a cobject having a Lua reference is being destroyed. The method isn't overriden by child classes, but instead all implementations are called starting from the topmost parent.
@function void CObject:RemoveLuaReference()
--]]
---
--- Removes the Lua reference for the CObject instance.
---
--- This method is called when a CObject instance having a Lua reference is being destroyed. The method is not overridden by child classes, but instead all implementations are called starting from the topmost parent.
---
function CObject:RemoveLuaReference()
end
RecursiveCallMethods.RemoveLuaReference = "procall_parents_last"
CObject.RemoveLuaReference = CObject.RemoveFromAllGroups

---
--- Sets the groups that the CObject instance belongs to.
---
--- This function removes the CObject instance from any groups it was previously a member of, and adds it to the specified groups.
---
--- @param groups table A table of group names that the CObject instance should belong to.
---
function CObject:SetGroups(groups)
	for _, group in ipairs(self.Groups or empty_table) do
		if not find(groups or empty_table, group) then
			self:RemoveFromGroup(group)
		end
	end
	for _, group in ipairs(groups or empty_table) do
		if not find(self.Groups or empty_table, group) then
			self:AddToGroup(group)
		end
	end
end

---
--- Gets a random spot position asynchronously.
---
--- @param type string The type of spot to get.
--- @return table The random spot position.
---
function CObject:GetRandomSpotAsync(type)
	return self:GetRandomSpot(type)
end

---
--- Gets a random spot position asynchronously.
---
--- @param type string The type of spot to get.
--- @return table The random spot position.
---
function CObject:GetRandomSpotPosAsync(type)
	return self:GetRandomSpotPos(type)
end

-- returns false, "local" or "remote"
---
--- Returns false, indicating that this CObject instance does not have a network state.
---
function CObject:NetState()
	return false
end

---
--- Gets whether the CObject instance is walkable.
---
--- @return boolean Whether the CObject instance is walkable.
---
function CObject:GetWalkable()
	return self:GetEnumFlags(const.efWalkable) ~= 0
end

---
--- Sets whether the CObject instance is walkable.
---
--- @param walkable boolean Whether the CObject instance should be walkable.
---
function CObject:SetWalkable(walkable)
	if walkable then
		self:SetEnumFlags(const.efWalkable)
	else
		self:ClearEnumFlags(const.efWalkable)
	end
end

---
--- Gets whether the CObject instance has collision enabled.
---
--- @return boolean Whether the CObject instance has collision enabled.
---
function CObject:GetCollision()
	return self:GetEnumFlags(const.efCollision) ~= 0
end

---
--- Sets whether the CObject instance has collision enabled.
---
--- @param value boolean Whether the CObject instance should have collision enabled.
---
function CObject:SetCollision(value)
	if value then
		self:SetEnumFlags(const.efCollision)
	else
		self:ClearEnumFlags(const.efCollision)
	end
end

---
--- Gets whether the CObject instance should be applied to grids.
---
--- @return boolean Whether the CObject instance should be applied to grids.
---
function CObject:GetApplyToGrids()
	return self:GetEnumFlags(const.efApplyToGrids) ~= 0
end

---
--- Sets whether the CObject instance should be applied to grids.
---
--- @param value boolean Whether the CObject instance should be applied to grids.
---
function CObject:SetApplyToGrids(value)
	if not not value == self:GetApplyToGrids() then
		return
	end
	if value then
		self:SetEnumFlags(const.efApplyToGrids)
	else
		self:ClearEnumFlags(const.efApplyToGrids)
	end
	self:InvalidateSurfaces()
end

---
--- Gets whether the CObject instance should ignore height surfaces.
---
--- @return boolean Whether the CObject instance should ignore height surfaces.
---
function CObject:GetIgnoreHeightSurfaces()
	return self:GetGameFlags(const.gofIgnoreHeightSurfaces) ~= 0
end

---
--- Sets whether the CObject instance should ignore height surfaces.
---
--- @param value boolean Whether the CObject instance should ignore height surfaces.
---
function CObject:SetIgnoreHeightSurfaces(value)
	if not not value == self:GetIgnoreHeightSurfaces() then
		return
	end
	if value then
		self:SetGameFlags(const.gofIgnoreHeightSurfaces)
	else
		self:ClearGameFlags(const.gofIgnoreHeightSurfaces)
	end
	self:InvalidateSurfaces()
end

---
--- Checks if the CObject instance has a valid entity.
---
--- @return boolean Whether the CObject instance has a valid entity.
---
function CObject:IsValidEntity()
	return IsValidEntity(self:GetEntity())
end

---
--- Gets whether the CObject instance has sun shadow enabled.
---
--- @return boolean Whether the CObject instance has sun shadow enabled.
---
function CObject:GetSunShadow()
	return self:GetEnumFlags(const.efSunShadow) ~= 0
end

---
--- Sets whether the CObject instance should cast a sun shadow.
---
--- @param sunshadow boolean Whether the CObject instance should cast a sun shadow.
---
function CObject:SetSunShadow(sunshadow)
	if sunshadow then
		self:SetEnumFlags(const.efSunShadow)
	else
		self:ClearEnumFlags(const.efSunShadow)
	end
end

---
--- Gets whether the CObject instance casts a shadow.
---
--- @return boolean Whether the CObject instance casts a shadow.
---
function CObject:GetCastShadow()
	return self:GetEnumFlags(const.efShadow) ~= 0
end

---
--- Sets whether the CObject instance should cast a shadow.
---
--- @param shadow boolean Whether the CObject instance should cast a shadow.
---
function CObject:SetCastShadow(shadow)
	if shadow then
		self:SetEnumFlags(const.efShadow)
	else
		self:ClearEnumFlags(const.efShadow)
	end
end

---
--- Gets whether the CObject instance is on a roof.
---
--- @return boolean Whether the CObject instance is on a roof.
---
function CObject:GetOnRoof()
	return self:GetGameFlags(const.gofOnRoof) ~= 0
end

---
--- Sets whether the CObject instance is on a roof.
---
--- @param on_roof boolean Whether the CObject instance is on a roof.
---
function CObject:SetOnRoof(on_roof)
	if on_roof then
		self:SetGameFlags(const.gofOnRoof)
	else
		self:ClearGameFlags(const.gofOnRoof)
	end
end

---
--- Gets whether the CObject instance should not be hidden with the room.
---
--- @return boolean Whether the CObject instance should not be hidden with the room.
---
function CObject:GetDontHideWithRoom()
	return self:GetGameFlags(const.gofDontHideWithRoom) ~= 0
end

---
--- Sets whether the CObject instance should not be hidden with the room.
---
--- @param val boolean Whether the CObject instance should not be hidden with the room.
---
function CObject:SetDontHideWithRoom(val)
	if val then
		self:SetGameFlags(const.gofDontHideWithRoom)
	else
		self:ClearGameFlags(const.gofDontHideWithRoom)
	end
end
if const.SlabSizeX then
	function CObject:GetDontHideWithRoom()
		return self:GetGameFlags(const.gofDontHideWithRoom) ~= 0
	end

	function CObject:SetDontHideWithRoom(val)
		if val then
			self:SetGameFlags(const.gofDontHideWithRoom)
		else
			self:ClearGameFlags(const.gofDontHideWithRoom)
		end
	end
end

---
--- Gets the number of LODs (Levels of Detail) for the CObject's current state.
---
--- @return number The number of LODs for the CObject's current state.
---
function CObject:GetLODsCount()
	local entity = self:GetEntity()
	return entity ~= "" and GetStateLODCount(entity, self:GetState()) or 1
end

---
--- Gets the default property value for the specified property of the CObject instance.
---
--- @param prop string The name of the property to get the default value for.
--- @param prop_meta table The metadata for the property.
--- @return any The default value for the specified property.
---
---
--- Gets the default property value for the specified property of the CObject instance.
---
--- @param prop string The name of the property to get the default value for.
--- @param prop_meta table The metadata for the property.
--- @return any The default value for the specified property.
---
function CObject:GetDefaultPropertyValue(prop, prop_meta)
	if prop == "ApplyToGrids" then
		return GetClassEnumFlags(self.class, const.efApplyToGrids) ~= 0
	elseif prop == "Collision" then
		return GetClassEnumFlags(self.class, const.efCollision) ~= 0
	elseif prop == "Walkable" then
		return GetClassEnumFlags(self.class, const.efWalkable) ~= 0
	elseif prop == "DetailClass" then
		local details_mask = GetClassGameFlags(self.class, gofDetailClassMask)
		return GetDetailClassMaskName(details_mask)
	end
	return PropertyObject.GetDefaultPropertyValue(self, prop, prop_meta)
end

-- returns the first valid state for the unit or the last one if none is valid
---
--- Chooses a valid state for the CObject instance.
---
--- @param state string The current state of the CObject.
--- @param next_state string The next state to try.
--- @return string The valid state for the CObject.
---
function CObject:ChooseValidState(state, next_state, ...)
	if next_state == nil then return state end
	if state and self:HasState(state) and not self:IsErrorState(state) then
		return state
	end
	return self:ChooseValidState(next_state, ...)
end

-- State property (implemented as text for saving compatibility)
---
--- Gets a table of state names for the CObject instance, optionally filtered by category.
---
--- @param category string (optional) The category to filter the states by.
--- @return table A table of state names for the CObject instance.
---
function CObject:GetStatesTextTable(category)
	local entity = IsValid(self) and self:GetEntity()
	if not IsValidEntity(entity) then return {} end
	local states = category and GetStatesFromCategory(entity, category) or self:GetStates()
	local i = 1
	while i <= #states do
		local state = states[i]
		if string.starts_with(state, "_") then --> ignore states beginning with '_'
			table.remove(states, i)
		else
			if self:IsErrorState(GetStateIdx(state)) then
				states[i] = state.." *"
			end
			i = i + 1
		end
	end
	table.sort(states)
	return states
end

---
--- Sets the state of the CObject instance to the specified value.
---
--- If the value ends with an asterisk (*), the asterisk is removed before setting the state.
--- If the specified state does not exist for the CObject instance, an error is stored.
---
--- @param value string The state to set for the CObject instance.
--- @param ... any Additional arguments to pass to the SetState function.
---
function CObject:SetStateText(value, ...)
	if value:sub(-1, -1) == "*" then
		value = value:sub(1, -3)
	end
	if not self:HasState(value) then
		StoreErrorSource(self, "Missing object state " .. self:GetEntity() .. "." .. value)
	else
		self:SetState(value, ...)
	end
end

---
--- Gets the current state text of the CObject instance.
---
--- @return string The current state text of the CObject instance.
---
function CObject:GetStateText()
	return GetStateName(self)
end

---
--- Called when the property editor for this CObject instance is opened.
--- Sets the realtime animation flag for the CObject instance to true.
---
function CObject:OnPropEditorOpen()
	self:SetRealtimeAnim(true)
end

-- Functions for manipulating text attaches

-- Attaches a text at the given spot
-- @param text string Text to be attached
-- @param spot int Id of the spot
function CObject:AttachText( text, spot )
	local obj = PlaceObject ( "Text" )
	obj:SetText(text)
	if spot == nil then
		spot = self:GetSpotBeginIndex("Origin")
	end
	self:Attach(obj, spot)
	return obj
end

-- Attaches a text at the given spot, which is updated trough a function each 900ms + random ( 200ms )
-- @param f function A function that returns the updated text
-- @param spot int Id of the spot
---
--- Attaches a text object to the CObject instance that is updated through a function at a regular interval.
---
--- @param f function A function that returns the updated text and the sleep duration in milliseconds.
--- @param spot integer (optional) The spot index to attach the text object to. If not provided, the text object will be attached to the "Origin" spot.
--- @return table The attached text object.
---
function CObject:AttachUpdatingText(f, spot)
	-- Implementation details
end
function CObject:AttachUpdatingText( f, spot )
	local obj = PlaceObject ( "Text" )
	CreateRealTimeThread( function ()
		while IsValid(obj) do
			local text, sleep = f(obj)
			obj:SetText(text or "")
			Sleep((sleep or 900) + AsyncRand(200))
		end
	end)
	if spot == nil then
		spot = self:GetSpotBeginIndex("Origin")
	end
	self:Attach(obj, spot)
	return obj
end

-- calls the func or the obj method when the current thread completes (but within the same millisecond);
-- multiple calls with the same arguments result in the function being called only once.
---
--- Notifies the CObject instance of the specified method.
---
--- @param method string The name of the method to notify.
---
function CObject:Notify(method)
	Notify(self, method)
end

if Platform.editor then
	---
 --- Checks if the specified class can be placed in the editor.
 ---
 --- @param class_name string The name of the class to check.
 --- @return boolean True if the class can be placed in the editor, false otherwise.
 ---
 function EditorCanPlace(class_name)
		local class = g_Classes[class_name]
		return class and class:EditorCanPlace()
	end
	function CObject:EditorCanPlace()
		return IsValidEntity(self:GetEntity())
	end
end

CObject.GetObjectBySpot = empty_func

--- Shows the spots of the object using code renderables.
---
--- Shows the spots of the object using code renderables.
---
--- @param spot_type string (optional) The type of spots to show. If not provided, all spots will be shown.
--- @param annotation string (optional) The annotation to filter the spots by. If not provided, all spots will be shown.
--- @param show_spot_idx boolean (optional) If true, the spot index will be shown in the spot name.
---
function CObject:ShowSpots(spot_type, annotation, show_spot_idx)
	if not self:HasEntity() then return end
	local start_id, end_id = self:GetAllSpots(self:GetState())
	local scale = Max(1, DivRound(10000, self:GetScale()))
	for i = start_id, end_id do
		local spot_name = GetSpotNameByType(self:GetSpotsType(i))
		if not spot_type or string.find(spot_name, spot_type) then
			local spot_annotation = self:GetSpotAnnotation(i)
			if not annotation or string.find(spot_annotation, annotation) then
				local text_obj = Text:new{ editor_ignore = true }
				local text_str = self:GetSpotName(i)
				if show_spot_idx then
					text_str = i .. '.' .. text_str
				end
				if spot_annotation then
					text_str = text_str .. ";" .. spot_annotation
				end
				text_obj:SetText(text_str)
				self:Attach(text_obj, i)
				
				local orientation_obj = CreateOrientationMesh()
				orientation_obj.editor_ignore = true
				orientation_obj:SetScale(scale)
				self:Attach(orientation_obj, i)
			end
		end
	end
end

--- Hides the spots of the objects.
--- Hides the spots of the object.
---
--- This function destroys all the text and mesh attachments that were created by the `CObject:ShowSpots()` function.
---
--- If the object does not have an entity, this function will return early without doing anything.
function CObject:HideSpots()
	if not self:HasEntity() then return end
	self:DestroyAttaches("Text")
	self:DestroyAttaches("Mesh")
end


---
--- A table of colors used to represent different types of object surfaces in the game.
---
--- The keys in this table correspond to the different surface types, and the values are the colors to use for each type.
---
--- @field ApplyToGrids red The color to use for grids that can be applied to.
--- @field Build purple The color to use for build surfaces.
--- @field ClearRoad white The color to use for clear road surfaces.
--- @field Collision green The color to use for collision surfaces.
--- @field Flat const.clrGray The color to use for flat surfaces.
--- @field Height cyan The color to use for height surfaces.
--- @field HexShape yellow The color to use for hex-shaped surfaces.
--- @field Road black The color to use for road surfaces.
--- @field Selection blue The color to use for selected surfaces.
--- @field Terrain RGBA(255, 0, 0, 128) The color to use for terrain surfaces.
--- @field TerrainHole magenta The color to use for terrain hole surfaces.
--- @field Walk const.clrPink The color to use for walkable surfaces.
---
ObjectSurfaceColors = {
	ApplyToGrids = red,
	Build = purple,
	ClearRoad = white,
	Collision = green,
	Flat = const.clrGray,
	Height = cyan,
	HexShape = yellow,
	Road = black,
	Selection = blue,
	Terrain = RGBA(255, 0, 0, 128),
	TerrainHole = magenta,
	Walk = const.clrPink,
}

--- A weak-keyed table that maps CObject instances to a set of meshes representing the surfaces of the object.
---
--- This table is used by the `CObject:ShowSurfaces()` and `CObject:HideSurfaces()` functions to track the meshes that are created to visualize the surfaces of each object.
---
--- The keys in this table are the CObject instances, and the values are tables that map surface types to the corresponding mesh objects.
---
--- This table uses a weak-keys metatable, which means that the CObject instances will be automatically removed from the table when they are garbage collected.
MapVar("ObjToShownSurfaces", {}, weak_keys_meta)
---
--- A table that stores the types of object surfaces that have been turned off and should not be displayed.
---
--- This table is used by the `CObject:ShowSurfaces()` function to determine which surface types should be hidden from the visualization.
---
--- The keys in this table are the surface type strings, and the values are boolean flags indicating whether that surface type has been turned off.
---
--- This table is typically populated and modified by other parts of the codebase to control which object surfaces are shown or hidden.
---
MapVar("TurnedOffObjSurfaces", {})

--- Shows the surfaces of the object using code renderables.
--- Shows the surfaces of the object using code renderables.
---
--- This function is responsible for displaying the various surfaces of a CObject instance. It iterates through the different surface types defined in the `EntitySurfaces` table, and creates a mesh object for each surface type that is present on the object and has not been turned off.
---
--- The created mesh objects are stored in the `ObjToShownSurfaces` table, which maps CObject instances to their corresponding surface meshes. This table is used by the `CObject:HideSurfaces()` function to clean up the surface meshes when they are no longer needed.
---
--- If the `ObjToShownSurfaces` table is not empty after this function is called, it also opens the "ObjSurfacesLegend" dialog to display a legend for the surface colors.
---
--- @param self CObject The CObject instance whose surfaces should be displayed.
function CObject:ShowSurfaces()
	local entity = self:GetEntity()
	if not IsValidEntity(entity) then return end
	local entry = ObjToShownSurfaces[self]
	for stype, flag in pairs(EntitySurfaces) do
		if HasAnySurfaces(entity, EntitySurfaces[stype])
			and not (stype == "All" or stype == "AllPass" or stype == "AllPassAndWalk")
			and not TurnedOffObjSurfaces[stype]
			and (not entry or not entry[stype]) then
			local color1 = ObjectSurfaceColors[stype] or RandColor(xxhash(stype))
			local color2 = InterpolateRGB(color1, black, 1, 2)
			local mesh = CreateObjSurfaceMesh(self, flag, color1, color2)
			mesh:SetOpacity(75)
			entry = table.create_set(entry, stype, mesh)
		end
	end
	ObjToShownSurfaces[self] = entry or {}
	OpenDialog("ObjSurfacesLegend")
end

--- Hides the surfaces of the object.
--- Hides the surfaces of the object.
---
--- This function is responsible for cleaning up the surface meshes that were created by the `CObject:ShowSurfaces()` function. It iterates through the `ObjToShownSurfaces` table, which maps CObject instances to their corresponding surface meshes, and destroys each of the mesh objects.
---
--- If the `ObjToShownSurfaces` table becomes empty after this function is called, it also closes the "ObjSurfacesLegend" dialog, as there are no longer any surface meshes to display.
---
--- @param self CObject The CObject instance whose surfaces should be hidden.
function CObject:HideSurfaces()
	for stype, mesh in pairs(ObjToShownSurfaces[self]) do
		DoneObject(mesh)
	end
	ObjToShownSurfaces[self] = nil
	if not next(ObjToShownSurfaces) then
		CloseDialog("ObjSurfacesLegend")
	end
end

--- Handles the loading of the game state.
---
--- When the game is loaded, this function checks if there are any object surfaces that were previously shown. If so, it opens the "ObjSurfacesLegend" dialog to display a legend for the surface colors.
function OnMsg.LoadGame()
	if next(ObjToShownSurfaces) then
		OpenDialog("ObjSurfacesLegend")
	end
end


----- Ged

--- Formats the label for the Ged tree view.
---
--- This function is responsible for generating the label that will be displayed for the current `CObject` instance in the Ged tree view. It first retrieves the `EditorLabel` property of the object, which is used as the base label. If the object has a `Name` or `ParticlesName` property, this is appended to the label separated by a hyphen.
---
--- @param self CObject The `CObject` instance for which the label should be formatted.
--- @return string The formatted label for the Ged tree view.
function CObject:GedTreeViewFormat()
	if IsValid(self) then
		local label = self:GetProperty("EditorLabel") or self.class
		local value = self:GetProperty("Name") or self:GetProperty("ParticlesName")
		local tname = value and (IsT(value) and _InternalTranslate(value) or type(value) == "string" and value) or ""
		if #tname > 0 then
			label = label .. " - " .. tname
		end
		return label
	end
end

--- Returns the list of attached objects for the current CObject instance.
---
--- This function retrieves the list of objects attached to the current CObject instance, and filters out any attached objects that have the "editor_ignore" property set. The filtered list of attached objects is then returned.
---
--- @return table The list of attached objects for the current CObject instance, excluding any objects with the "editor_ignore" property set.
function CObject:GedTreeChildren()
	local ret = IsValid(self) and self:GetAttaches() or empty_table
	return table.ifilter(ret, function(k, v) return not rawget(v, "editor_ignore") end)
end


------------------------------------------------------------
----------------- Animation Moments ------------------------
------------------------------------------------------------

--- Retrieves the animation moments for the specified entity and animation.
---
--- This function retrieves the animation moments for the specified entity and animation. If a moment type is provided, the function will filter the moments to only include those of the specified type.
---
--- @param entity table The entity for which to retrieve the animation moments.
--- @param anim string The animation for which to retrieve the moments.
--- @param moment_type string (optional) The type of moments to retrieve.
--- @return table The list of animation moments, or an empty table if none are found.
function GetEntityAnimMoments(entity, anim, moment_type)
	local anim_entity = GetAnimEntity(entity, anim)
	local preset_group = anim_entity and Presets.AnimMetadata[anim_entity]
	local preset_anim = preset_group and preset_group[anim]
	local moments = preset_anim and preset_anim.Moments
	if moments and moment_type then
		moments = table.ifilter(moments, function(_, m, moment_type)
			return m.Type == moment_type
		end, moment_type)
	end
	return moments or empty_table
end
local GetEntityAnimMoments = GetEntityAnimMoments

--- Retrieves the animation moments for the specified animation of the CObject instance.
---
--- This function retrieves the animation moments for the specified animation of the CObject instance. If a moment type is provided, the function will filter the moments to only include those of the specified type.
---
--- @param anim string (optional) The animation for which to retrieve the moments. If not provided, the current state text of the CObject instance will be used.
--- @param moment_type string (optional) The type of moments to retrieve.
--- @return table The list of animation moments, or an empty table if none are found.
function CObject:GetAnimMoments(anim, moment_type)
	return GetEntityAnimMoments(self:GetEntity(), anim or self:GetStateText(), moment_type)
end

--- The `AnimSpeedScale` constant is used to scale the animation speed of an object. It is multiplied by itself to create the `AnimSpeedScale2` constant, which is likely used for further scaling or calculations related to animation speed.
local AnimSpeedScale = const.AnimSpeedScale
local AnimSpeedScale2 = AnimSpeedScale * AnimSpeedScale

--- Iterates through the animation moments for the specified animation, phase, and moment index.
---
--- This function iterates through the animation moments for the specified animation, phase, and moment index. It returns the type, time, and the moment object for the specified moment index. If the moment index is not found, it returns `false` and `-1`.
---
--- @param anim string The name of the animation.
--- @param phase number The current phase of the animation.
--- @param moment_index number The index of the moment to retrieve.
--- @param moment_type string (optional) The type of moment to retrieve.
--- @param reversed boolean Whether the animation is playing in reverse.
--- @param looping boolean Whether the animation is looping.
--- @param moments table (optional) The list of animation moments to iterate through.
--- @param duration number (optional) The duration of the animation.
--- @return boolean, number, table The type of the moment, the time of the moment, and the moment object, or `false` and `-1` if the moment is not found.
function CObject:IterateMoments(anim, phase, moment_index, moment_type, reversed, looping, moments, duration)	
	moments = moments or self:GetAnimMoments(anim)
	local count = #moments
	if count == 0 or moment_index <= 0 then
		return false, -1
	end
	duration = duration or GetAnimDuration(self:GetEntity(), anim)
	local count_down = moment_index
	local next_loop

	if not reversed then
		local time = -phase		-- current looped beginning time of the animation
		local idx = 1
		while true do
			if idx > count then	-- if we are out of moments for this loop - start over with increased time
				if not looping then
					return false, -1
				end
				idx = 1
				time = time + duration
				if count_down == moment_index and time > duration then
					return false, -1		-- searching for non-existent moment
				end
				next_loop = true
			end
			local moment = moments[idx]
			if (not moment_type or moment_type == moment.Type) and time + moment.Time >= 0 then
				if count_down == 1 then
					return moment.Type, time + Min(duration-1, moment.Time), moment, next_loop
				end
				count_down = count_down - 1
			end
			idx = idx + 1
		end
	else
		local time = phase - duration
		local idx = count
		while true do
			if idx == 0 then
				if not looping then
					return false, -1
				end
				idx = count
				time = time + duration
				if count_down == moment_index and time > duration then
					return false, -1		-- searching for non-existent moment
				end
				next_loop = true
			end
			local moment = moments[idx]
			if (not moment_type or moment_type == moment.Type) and time + duration - moment.Time >= 0 then
				if count_down == 1 then
					return moment.Type, time + duration - moment.Time, moment, next_loop
				end
				count_down = count_down - 1
			end
			idx = idx - 1
		end
	end
end

---
--- Gets the channel data for the specified animation channel.
---
--- @param channel number The animation channel to get data for.
--- @param moment_index number The index of the animation moment to get data for.
--- @return string anim The name of the animation.
--- @return number phase The current phase of the animation.
--- @return number moment_index The index of the animation moment.
--- @return boolean reversed Whether the animation is playing in reverse.
--- @return boolean looping Whether the animation is looping.
---
function CObject:GetChannelData(channel, moment_index)
	local reversed = self:IsAnimReversed(channel)
	if moment_index < 1 then
		reversed = not reversed
		moment_index = -moment_index
	end
	local looping = self:IsAnimLooping(channel)
	local anim = GetStateName(self:GetAnim(channel))
	local phase = self:GetAnimPhase(channel)
	
	return anim, phase, moment_index, reversed, looping
end

---
--- Computes the time required to reach a specific animation time based on the current animation speed.
---
--- @param anim_time number The target animation time.
--- @param combined_speed number The combined animation speed.
--- @param looping boolean Whether the animation is looping.
--- @return number The time required to reach the target animation time.
---
function ComputeTimeTo(anim_time, combined_speed, looping)
	-- Implementation details
end
local function ComputeTimeTo(anim_time, combined_speed, looping)
	if combined_speed == AnimSpeedScale2 then
		return anim_time
	end
	if combined_speed == 0 then
		return max_int
	end
	local time = anim_time * AnimSpeedScale2 / combined_speed
	if time == 0 and anim_time ~= 0 and looping then
		return 1
	end
	return time
end

---
--- Computes the time required to reach a specific animation moment based on the current animation speed.
---
--- @param channel number The animation channel to get data for.
--- @param moment_type string The type of animation moment to find.
--- @param moment_index number The index of the animation moment to get data for.
--- @return number The time required to reach the target animation moment.
---
function CObject:TimeToMoment(channel, moment_type, moment_index)
	if moment_index == nil and type(channel) == "string" then
		channel, moment_type, moment_index = 1, channel, moment_type
	end
	local anim, phase, index, reversed, looping = self:GetChannelData(channel, moment_index or 1)
	local _, anim_time = self:IterateMoments(anim, phase, index, moment_type, reversed, looping)
	if anim_time == -1 then
		return
	end
	local combined_speed = self:GetAnimSpeed(channel) * self:GetAnimSpeedModifier()
	return ComputeTimeTo(anim_time, combined_speed, looping)
end

---
--- Callback function that is called when an animation moment is reached.
---
--- @param moment string The name of the animation moment that was reached.
--- @param anim string The name of the animation that the moment belongs to.
--- @param remaining_duration number The remaining duration of the animation in milliseconds.
--- @param moment_counter number The number of moments that have been reached so far in the animation.
--- @param loop_counter number The number of times the animation has looped.
---
function CObject:OnAnimMoment(moment, anim, remaining_duration, moment_counter, loop_counter)
	PlayFX(FXAnimToAction(anim), moment, self)
end

---
--- Plays an animation with a specified duration and calls a callback function when a specific animation moment is reached.
---
--- @param state string The name of the animation state to play.
--- @param duration number The duration of the animation in milliseconds.
--- @return string The result of the animation playback, either "invalid" if the object is no longer valid, or "msg" if the wait function returned true.
---
function CObject:PlayTimedMomentTrackedAnim(state, duration)
	return self:WaitMomentTrackedAnim(state, nil, nil, nil, nil, nil, duration)
end

---
--- Plays an animation with a specified state and calls a callback function when a specific animation moment is reached.
---
--- @param state string The name of the animation state to play.
--- @param moment string The name of the animation moment to call the callback for.
--- @param callback function The callback function to call when the animation moment is reached.
--- @param ... any Additional arguments to pass to the callback function.
--- @return string The result of the animation playback, either "invalid" if the object is no longer valid, or "msg" if the wait function returned true.
---
function CObject:PlayAnimWithCallback(state, moment, callback, ...)
	return self:WaitMomentTrackedAnim(state, nil, nil, nil, nil, nil, nil, moment, callback, ...)
end

---
--- Plays an animation with a specified state and calls a callback function when a specific animation moment is reached.
---
--- @param state string The name of the animation state to play.
--- @param count number The number of times to play the animation.
--- @param flags number The animation flags to use.
--- @param crossfade number The crossfade duration in milliseconds.
--- @param duration number The duration of the animation in milliseconds.
--- @param moment string The name of the animation moment to call the callback for.
--- @param callback function The callback function to call when the animation moment is reached.
--- @param ... any Additional arguments to pass to the callback function.
--- @return string The result of the animation playback, either "invalid" if the object is no longer valid, or "msg" if the wait function returned true.
---
function CObject:PlayMomentTrackedAnim(state, count, flags, crossfade, duration, moment, callback, ...)
	return self:WaitMomentTrackedAnim(state, nil, nil, count, flags, crossfade, duration, moment, callback, ...)
end

---
--- Plays an animation with a specified state and calls a callback function when a specific animation moment is reached.
---
--- @param state string The name of the animation state to play.
--- @param wait_func function An optional function that is called during the animation to check if the animation should be interrupted.
--- @param wait_param any An optional parameter to pass to the `wait_func` function.
--- @param count number The number of times to play the animation.
--- @param flags number The animation flags to use.
--- @param crossfade number The crossfade duration in milliseconds.
--- @param duration number The duration of the animation in milliseconds.
--- @param moment string The name of the animation moment to call the callback for.
--- @param callback function The callback function to call when the animation moment is reached.
--- @param ... any Additional arguments to pass to the callback function.
--- @return string The result of the animation playback, either "invalid" if the object is no longer valid, or "msg" if the wait function returned true.
---
function CObject:WaitMomentTrackedAnim(state, wait_func, wait_param, count, flags, crossfade, duration, moment, callback, ...)
	if not IsValid(self) then return "invalid" end
	if (state or "") ~= "" then
		if not self:HasState(state) then
			GameTestsError("once", "Missing animation:", self:GetEntity() .. '.' .. state)
			duration = duration or 1000
		else
			self:SetState(state, flags or 0, crossfade or -1)
			assert(self:GetAnimPhase() == 0)
			local anim_duration = self:GetAnimDuration()
			if anim_duration == 0 then
				GameTestsError("once", "Zero length animation:", self:GetEntity() .. '.' .. state)
				duration = duration or 1000
			else
				local channel = 1
				duration = duration or (count or 1) * anim_duration
				local moments = self:GetAnimMoments(state)
				local moment_count = table.count(moments, "Type", moment)
				if moment and callback and moment_count ~= 1 then
					StoreErrorSource(self, "The callback is supposed to be called once for animation", state, "but there are", moment_count, "moments with the name", moment)
				end
				local anim, phase, count_down, reversed, looping = self:GetChannelData(channel, 1)
				local moment_counter, loop_counter = 0, 0
				while duration > 0 do
					if not IsValid(self) then return "invalid" end
					local moment_type, time, moment_descr, next_loop = self:TimeToNextMoment(channel, count_down, anim, phase, reversed, looping, moments, anim_duration)
					local sleep_time
					if not time or time == -1 then
						sleep_time = duration
					else
						sleep_time = Min(duration, time)
					end
					if not wait_func then
						Sleep(sleep_time)
					elseif wait_func(wait_param, sleep_time) then
						return "msg"
					end
					
					if not IsValid(self) then return "invalid" end
					duration = duration - sleep_time
					if sleep_time == time and (duration ~= 0 or not next_loop) then
						moment_counter = moment_counter + 1
						-- moment reached
						if next_loop then
							loop_counter = loop_counter + 1
						end
						if self:OnAnimMoment(moment_type, anim, duration, moment_counter, loop_counter) == "break" then
							assert(not callback)
							return "break"
						end
						if callback then
							if not moment then
								if callback(moment_type, ...) == "break" then
									return "break"
								end
							elseif moment == moment_type then
								if callback(...) == "break" then
									return "break"
								end
								callback = nil
							end
						end
					end
					
					phase = nil
					count_down = 2
				end
			end
		end
	end
	if duration and duration > 0 then
		if not wait_func then
			Sleep(duration)
		elseif wait_func(wait_param, duration) then
			return "msg"
		end
	end
	if callback and moment then
		callback(...)
	end
end

---
--- Plays a transition animation with a callback.
---
--- @param anim string The animation to play.
--- @param moment string The animation moment to trigger the callback at.
--- @param callback function The callback function to call when the specified moment is reached.
--- @param ... any Additional arguments to pass to the callback function.
--- @return string The result of the animation execution.
---
function CObject:PlayTransitionAnim(anim, moment, callback, ...)
	return self:ExecuteWeakUninterruptable(self.PlayAnimWithCallback, anim, moment, callback, ...)
end

---
--- Calculates the time until the next animation moment is reached.
---
--- @param channel number The animation channel to check.
--- @param index number The index of the animation moment to check.
--- @param anim string The name of the animation.
--- @param phase number The current animation phase.
--- @param reversed boolean Whether the animation is playing in reverse.
--- @param looping boolean Whether the animation is looping.
--- @param moments table The table of animation moments.
--- @param duration number The duration of the animation.
--- @return string|nil The type of the next animation moment.
--- @return number|nil The time until the next animation moment is reached.
--- @return table|nil The description of the next animation moment.
--- @return boolean|nil Whether the next animation moment is the start of a new loop.
---
function CObject:TimeToNextMoment(channel, index, anim, phase, reversed, looping, moments, duration)
	anim = anim or GetStateName(self:GetAnim(channel))
	phase = phase or self:GetAnimPhase(channel)
	if reversed == nil then
		reversed = self:IsAnimReversed(channel)
	end
	if looping == nil then
		looping = self:IsAnimLooping(channel)
	end
	if index < 1 then
		reversed = not reversed
		index = -index
	end
	local moment_type, anim_time, moment_descr, next_loop = self:IterateMoments(anim, phase, index, nil, 
		reversed, looping, moments, duration)
	if anim_time == -1 then
		return
	end
	local combined_speed = self:GetAnimSpeed(channel) * self:GetAnimSpeedModifier()
	local time = ComputeTimeTo(anim_time, combined_speed, looping)
	
	return moment_type, time, moment_descr, next_loop
end

--- Returns the type of the specified animation moment.
---
--- @param channel number The animation channel to check.
--- @param moment_index number The index of the animation moment to check.
--- @return string|nil The type of the animation moment.
function CObject:TypeOfMoment(channel, moment_index)
	local anim, phase, index, reversed, looping = self:GetChannelData(channel, moment_index or 1)
	return self:IterateMoments(anim, phase, index, false, reversed, looping)
end

---
--- Returns the time of the specified animation moment.
---
--- @param anim string The name of the animation.
--- @param moment_type string The type of the animation moment to get.
--- @param moment_index number The index of the animation moment to get.
--- @param raise_error boolean Whether to raise an error if the moment is not found.
--- @return number|nil The time of the animation moment, or nil if not found.
---
function CObject:GetAnimMoment(anim, moment_type, moment_index, raise_error)
	local _, anim_time = self:IterateMoments(anim, 0, moment_index or 1, moment_type, false, self:IsAnimLooping())
	if anim_time ~= -1 then
		return anim_time
	end
	if not raise_error then
		return
	end
	assert(false, string.format("No such anim moment: %s.%s.%s", self:GetEntity(), anim, moment_type), 1)
	return self:GetAnimDuration(anim)
end

---
--- Returns the type of the specified animation moment.
---
--- @param anim string The name of the animation.
--- @param moment_index number The index of the animation moment to check.
--- @return string|nil The type of the animation moment, or nil if not found.
---
function CObject:GetAnimMomentType(anim, moment_index)
	local moment_type = self:IterateMoments(anim, 0, moment_index or 1, false, false, self:IsAnimLooping())
	if not moment_type or moment_type == "" then
		return
	end
	return moment_type
end

---
--- Returns the count of the specified animation moments.
---
--- @param anim string The name of the animation.
--- @param moment_type string The type of the animation moment to count.
--- @return number The count of the animation moments.
function CObject:GetAnimMomentsCount(anim, moment_type)
	return #self:GetAnimMoments(anim, moment_type)
end

-- TODO: maybe return directly the (filtered) table from the Presets.AnimMetadata
---
--- Returns a table of animation moments for the specified entity and animation.
---
--- @param entity table The entity to get the animation moments for.
--- @param anim string The name of the animation to get the moments for.
--- @return table A table of animation moments, where each moment is a table with `type` and `time` fields.
---
function GetStateMoments(entity, anim)
	local moments = {}
	for idx, moment in ipairs(GetEntityAnimMoments(entity, anim)) do
		moments[idx] = {type = moment.Type, time = moment.Time}
	end
	return moments
end

---
--- Returns a table of the names of all animation moments for the specified entity and animation.
---
--- @param entity table The entity to get the animation moment names for.
--- @param anim string The name of the animation to get the moment names for.
--- @return table A table of the names of all animation moments.
---
function GetStateMomentsNames(entity, anim)
	if not IsValidEntity(entity) or GetStateIdx(anim) == -1 then return empty_table end
	local moments = {}
	for idx, moment in ipairs(GetEntityAnimMoments(entity, anim)) do
		moments[moment.Type] = true
	end
	return table.keys(moments, true)
end

---
--- Returns a table of the default animation metadata for all entities.
---
--- The returned table is keyed by entity name, and each value is a table containing the default animation metadata for that entity.
--- The default animation metadata is an `AnimMetadata` object with the ID `"__default__"` and the entity name as the group.
--- The `AnimComponents` field of the `AnimMetadata` object is a table of `AnimComponentWeight` objects, one for each animation component defined for the entity.
---
--- @return table The default animation metadata for all entities.
---
function GetEntityDefaultAnimMetadata()
	local entityDefaultAnimMetadata = {}
	for name, entity_data in pairs(EntityData) do
		if entity_data.anim_components then
			local anim_components = table.map( entity_data.anim_components, function(t) return AnimComponentWeight:new(t) end )
			local animMetadata = AnimMetadata:new({id = "__default__", group = name, AnimComponents = anim_components})
			entityDefaultAnimMetadata[name] = { __default__ = animMetadata }
		end
	end
	return entityDefaultAnimMetadata
end

---
--- Reloads the animation data for the game.
---
--- This function performs the following steps:
--- 1. Reloads the animation component definitions from the `AnimComponents` table.
--- 2. Clears the existing animation metadata.
--- 3. Loads the animation metadata from the `Presets.AnimMetadata` table and the `GetEntityDefaultAnimMetadata()` function.
--- 4. Sets the speed modifier for each animation metadata entry based on the `const.AnimSpeedScale` value.
---
--- This function is called when the game data is loaded or reloaded, and when an animation preset is saved.
---
function ReloadAnimData()
end
local function ReloadAnimData()
	ReloadAnimComponentDefs(AnimComponents)
	
	ClearAnimMetaData()
	LoadAnimMetaData(Presets.AnimMetadata)
	LoadAnimMetaData(GetEntityDefaultAnimMetadata())
	
	local speed_scale = const.AnimSpeedScale
	for _, entity_meta in ipairs(Presets.AnimMetadata) do
		for _, anim_meta in ipairs(entity_meta) do
			local speed_modifier = anim_meta.SpeedModifier * speed_scale / 100
			SetStateSpeedModifier(anim_meta.group, GetStateIdx(anim_meta.id), speed_modifier)
		end
	end
end

---
--- Reloads the animation data for the game when the game data is loaded or reloaded, or when an animation preset is saved.
---
--- This function performs the following steps:
--- 1. Reloads the animation component definitions from the `AnimComponents` table.
--- 2. Clears the existing animation metadata.
--- 3. Loads the animation metadata from the `Presets.AnimMetadata` table and the `GetEntityDefaultAnimMetadata()` function.
--- 4. Sets the speed modifier for each animation metadata entry based on the `const.AnimSpeedScale` value.
---
--- @see GetEntityDefaultAnimMetadata
--- @see ReloadAnimComponentDefs
--- @see ClearAnimMetaData
--- @see LoadAnimMetaData
--- @see SetStateSpeedModifier
--- @see GetStateIdx
OnMsg.DataLoaded = ReloadAnimData
OnMsg.DataReloadDone = ReloadAnimData

---
--- Reloads the animation data for the game when an animation preset is saved.
---
--- This function is called when an animation preset is saved, and performs the following steps:
--- 1. Checks if the saved preset is for an `AnimComponent` or `AnimMetadata` class.
--- 2. If so, calls the `ReloadAnimData()` function to reload the animation data.
---
--- @param className string The name of the class for which the preset was saved.
---
function OnMsg.PresetSave(className)
	local class = g_Classes[className]
	if IsKindOf(class, "AnimComponent") or IsKindOf(class, "AnimMetadata") then
		ReloadAnimData()
	end
end

-------------------------------------------------------
---------------------- Testing ------------------------
-------------------------------------------------------

---
--- Initializes the global `g_DevTestState` table with default values when the file is first loaded.
---
--- The `g_DevTestState` table is used to store information related to the development test state of a `CObject` instance. This includes the current test thread, the object being tested, and the starting position, angle, and axis of the object.
---
--- This code is executed only once, when the file is first loaded.
---
if FirstLoad then
	g_DevTestState = {
		thread = false,
		obj = false,
		start_pos = false,
		start_axis = false,
		start_angle = false,
	}
end

---
--- Executes a test state for the CObject instance.
---
--- This function performs the following steps:
--- 1. Checks if the editor is active. If not, prints a message indicating that the test is only available in the editor.
--- 2. If a previous test thread exists, deletes it.
--- 3. If the current CObject instance is different from the previous one, stores the starting position, angle, and axis of the object.
--- 4. Creates a new real-time thread that performs the test state:
---    - Sets the animation to the current state of the object.
---    - Retrieves the duration of the animation.
---    - If the duration is not zero, sets the position and axis-angle of the object to the starting values.
---    - Optionally, applies compensation for the object's step axis and angle.
---    - Loops the animation the specified number of times (or 5 times if no value is provided).
---    - During each loop, checks if the object is still valid, if the editor is still active, and if the object's state has not changed. If any of these conditions are not met, the loop is broken.
---    - Plays the animation for the current state, setting the position and axis-angle back to the starting values.
---    - If compensation is not required, sleeps for the duration of the animation.
---
--- @param main table The main table (not used)
--- @param prop_id number The property ID (not used)
--- @param ged table The GED table (not used)
--- @param no_compensate boolean If true, disables compensation for the object's step axis and angle
---
function CObject:BtnTestState(main, prop_id, ged, no_compensate)
	self:TestState(nil, no_compensate)
end

---
--- Executes a single test state for the CObject instance.
---
--- This function performs the following steps:
--- 1. Checks if the editor is active. If not, prints a message indicating that the test is only available in the editor.
--- 2. If a previous test thread exists, deletes it.
--- 3. If the current CObject instance is different from the previous one, stores the starting position, angle, and axis of the object.
--- 4. Creates a new real-time thread that performs the test state:
---    - Sets the animation to the current state of the object.
---    - Retrieves the duration of the animation.
---    - If the duration is not zero, sets the position and axis-angle of the object to the starting values.
---    - Optionally, applies compensation for the object's step axis and angle.
---    - Plays the animation for the current state, setting the position and axis-angle back to the starting values.
---    - If compensation is not required, sleeps for the duration of the animation.
---
--- @param main table The main table (not used)
--- @param prop_id number The property ID (not used)
--- @param ged table The GED table (not used)
--- @param no_compensate boolean If true, disables compensation for the object's step axis and angle
---
function CObject:BtnTestOnce(main, prop_id, ged, no_compensate)
	self:TestState(1, no_compensate)
end

---
--- Executes a test state for the CObject instance, repeating the test a specified number of times.
---
--- This function calls the `CObject:TestState()` function with the specified number of repetitions, and optionally disables compensation for the object's step axis and angle.
---
--- @param main table The main table (not used)
--- @param prop_id number The property ID (not used)
--- @param ged table The GED table (not used)
--- @param no_compensate boolean If true, disables compensation for the object's step axis and angle
---
function CObject:BtnTestLoop(main, prop_id, ged, no_compensate)
	self:TestState(10000000000, no_compensate)
end

---
--- Executes a test state for the CObject instance, optionally repeating the test a specified number of times.
---
--- This function performs the following steps:
--- 1. Checks if the editor is active. If not, prints a message indicating that the test is only available in the editor.
--- 2. If a previous test thread exists, deletes it.
--- 3. If the current CObject instance is different from the previous one, stores the starting position, angle, and axis of the object.
--- 4. Creates a new real-time thread that performs the test state:
---    - Sets the animation to the current state of the object.
---    - Retrieves the duration of the animation.
---    - If the duration is not zero, sets the position and axis-angle of the object to the starting values.
---    - Optionally, applies compensation for the object's step axis and angle.
---    - Plays the animation for the current state, setting the position and axis-angle back to the starting values.
---    - If compensation is not required, sleeps for the duration of the animation.
---
--- @param self CObject The CObject instance
--- @param rep number The number of times to repeat the test (default is 5)
--- @param ignore_compensation boolean If true, disables compensation for the object's step axis and angle
---
function CObject.TestState(self, rep, ignore_compensation)
	if not IsEditorActive() then
		print("Available in editor only")
	end


	if g_DevTestState.thread then
		DeleteThread(g_DevTestState.thread)
	end
	if g_DevTestState.obj ~= self then
		g_DevTestState.start_pos = self:GetVisualPos()
		g_DevTestState.start_angle = self:GetVisualAngle()
		g_DevTestState.start_axis = self:GetVisualAxis()
		g_DevTestState.obj = self
	end
	g_DevTestState.thread = CreateRealTimeThread(function(self, rep, ignore_compensation)
		local start_pos = g_DevTestState.start_pos
		local start_angle = g_DevTestState.start_angle
		local start_axis = g_DevTestState.start_axis
		self:SetAnim(1, self:GetState(), 0, 0)
		local duration = self:GetAnimDuration()
		if duration == 0 then return end
		local state = self:GetState()
		local step_axis, step_angle
		if not ignore_compensation then
			step_axis, step_angle = self:GetStepAxisAngle()
		end

		local rep = rep or 5
		for i = 1, rep do
			if not IsValid(self) or not IsEditorActive() or self:GetState() ~= state then
				break
			end
			self:SetAnim(1, state, const.eDontLoop, 0)

			self:SetPos(start_pos)
			self:SetAxisAngle(start_axis, start_angle)

			if ignore_compensation then
				Sleep(duration)
			else
				local parts = 2
				for i = 1, parts do
					local start_time = MulDivRound(i - 1, duration, parts)
					local end_time = MulDivRound(i, duration, parts)
					local part_duration = end_time - start_time

					local part_step_vector = self:GetStepVector(state, start_angle, start_time, part_duration)
					self:SetPos(self:GetPos() + part_step_vector, part_duration)

					local part_rot_angle = MulDivRound(i, step_angle, parts) - MulDivRound(i - 1, step_angle, parts) 
					self:Rotate(step_axis, part_rot_angle, part_duration)
					Sleep(part_duration)
					if not IsValid(self) or not IsEditorActive() or self:GetState() ~= state then
						break
					end
				end
			end

			Sleep(400)
			if not IsValid(self) or not IsEditorActive() or self:GetState() ~= state then
				break
			end
			self:SetPos(start_pos)
			self:SetAxisAngle(start_axis, start_angle)
			Sleep(400)
		end

		g_DevTestState.obj = false
	end, self, rep, ignore_compensation)
end

---
--- Sets the color of the object based on the specified text style.
---
--- @param id string The ID of the text style to use.
function CObject:SetColorFromTextStyle(id)
	assert(TextStyles[id])
	self.textstyle_id = id
	local color = TextStyles[id].TextColor
	local _, _, _, opacity = GetRGBA(color)
	self:SetColorModifier(color)
	self:SetOpacity(opacity)
end

---
--- Recursively sets the contour visibility for the object and all its attached objects.
---
--- @param visible boolean Whether the contour should be visible or not.
--- @param id string The ID of the contour to set.
function CObject:SetContourRecursive(visible, id)
	if not IsValid(self) or IsBeingDestructed(self) then
		return
	end
	if visible then
		self:SetContourOuterID(true, id)
		self:ForEachAttach(function(attach)
			attach:SetContourRecursive(true, id)
		end)
	else
		self:SetContourOuterID(false, id)
		self:ForEachAttach(function(attach)
			attach:SetContourRecursive(false, id)
		end)
	end
end

---
--- Recursively calls a function or method on the current object and all its attached objects.
---
--- @param self CObject The object to call the function or method on.
--- @param func function|string The function or method name to call.
--- @param ... any Additional arguments to pass to the function or method.
--- @return string|nil If the `func` parameter is not a function or method name, returns an error message. Otherwise, returns nothing.
function CallRecursive(self, func, ...)
	if not IsValid(self) or IsBeingDestructed(self) then
		return
	end

	if type(func) == "function" then
		func(self, ...)
	elseif type(func) == "string" then
		table.fget(self, func, "(", ...)
	else
		return "Invalid parameter. Expected function or method name"
	end
	
	self:ForEachAttach(CallRecursive, func, ...)
end

---
--- Recursively sets the 'under construction' flag for the object and all its attached objects.
---
--- @param data boolean Whether the object is under construction or not.
function CObject:SetUnderConstructionRecursive(data)
	if not IsValid(self) or IsBeingDestructed(self) then
		return
	end
	self:SetUnderConstruction(data)
	self:ForEachAttach(function(attach, data)
		attach:SetUnderConstructionRecursive(data)
	end, data)
end

---
--- Recursively sets the 'contour outer occlude' flag for the object and all its attached objects.
---
--- @param self CObject The object to set the 'contour outer occlude' flag on.
--- @param set boolean Whether to set the 'contour outer occlude' flag or not.
function CObject:SetContourOuterOccludeRecursive(set)
	if not IsValid(self) or IsBeingDestructed(self) then
		return
	end
	self:SetContourOuterOcclude(set)
	self:ForEachAttach(function(attach, set)
		attach:SetContourOuterOccludeRecursive(set)
	end, set)
end

---
--- Gets the bounding box of the object and all its attached objects, excluding objects of the specified classes.
---
--- @param self CObject The object to get the bounding box for.
--- @param ignore_classes table|nil A table of class names to ignore when calculating the bounding box.
--- @return table The bounding box of the object and all its attached objects, excluding the specified classes.
function CObject:GetObjectAttachesBBox(ignore_classes)
	local bbox = self:GetObjectBBox()
	self:ForEachAttach(function(attach)
		if not ignore_classes or not IsKindOfClasses(attach, ignore_classes) then
			bbox = AddRects(bbox, attach:GetObjectBBox())
		end
	end)
	
	return bbox
end

---
--- Gets the error message for the current object, if any.
---
--- This function checks for several potential errors related to the object's colliders and collection index. If the object has colliders but is not marked as "Essential", it will return an error message. If the object's collection index is invalid, it will also return an error message.
---
--- @return string|nil The error message, or nil if there are no errors.
function CObject:GetError()
	if not IsValid(self) then return end

	local parent = self:GetParent()
	-- CheckCollisionObjectsAreEssentials
	if const.maxCollidersPerObject > 0 then
		if not parent and self:GetEnumFlags(const.efCollision) ~= 0 then
			if collision.GetFirstCollisionMask(self) then
				local detail_class = self:GetDetailClass()
				if detail_class == "Default" then
					local entity = self:GetEntity()
					local entity_data = EntityData[entity]
					detail_class = entity and entity_data and entity_data.entity.DetailClass or "Essential"
				end
				if detail_class ~= "Essential" then
					return "Object with colliders is not declared 'Essential'"
				end
			end
		end
	end

	-- Validate collection index
	if not parent then -- obj is not attached
		local col = self:GetCollectionIndex()
		if col > 0 and not Collections[col] then
			self:SetCollectionIndex(0)
			return string.format("Missing collection object for index %s", col)
		end
	end
end
--- Enables or disables recursive calls to the `OnHoverStart`, `OnHoverUpdate`, and `OnHoverEnd` methods for `CObject` instances.
---
--- When `RecursiveCallMethods.OnHoverStart` is `true`, calling `CObject:OnHoverStart()` will recursively call the `OnHoverStart` method on all attached objects.
--- When `RecursiveCallMethods.OnHoverUpdate` is `true`, calling `CObject:OnHoverUpdate()` will recursively call the `OnHoverUpdate` method on all attached objects.
--- When `RecursiveCallMethods.OnHoverEnd` is `true`, calling `CObject:OnHoverEnd()` will recursively call the `OnHoverEnd` method on all attached objects.
---
--- The `CObject.OnHoverStart`, `CObject.OnHoverUpdate`, and `CObject.OnHoverEnd` properties are set to `empty_func` to provide a default implementation for these methods.

RecursiveCallMethods.OnHoverStart = true
CObject.OnHoverStart = empty_func
RecursiveCallMethods.OnHoverUpdate = true
CObject.OnHoverUpdate = empty_func
RecursiveCallMethods.OnHoverEnd = true
CObject.OnHoverEnd = empty_func

--- Registers a new global variable named "ContourReasons" and sets its initial value to `false`.
---
--- The "ContourReasons" variable is used to store information about contour reasons for objects. It is initialized as a new table with weak keys, allowing the garbage collector to remove entries when the associated objects are no longer referenced.
MapVar("ContourReasons", false)
--- Sets a contour reason for the specified object.
---
--- If the `ContourReasons` table does not exist, it is created with a weak key metatable.
--- The `ContourReasons` table stores contour reasons for each object. For each object, a table of contours is stored, and for each contour, a table of reasons is stored.
---
--- If the contour reasons table for the object does not exist, it is created. If the reasons table for the specified contour does not exist, it is created and the object's contour is set to true recursively.
---
--- If the reason already exists in the reasons table, the function simply returns. Otherwise, the reason is added to the reasons table.
---
--- @param obj CObject The object to set the contour reason for.
--- @param contour string The contour to set the reason for.
--- @param reason string The reason to set.
function SetContourReason(obj, contour, reason)
	if not ContourReasons then
		ContourReasons = setmetatable({}, weak_keys_meta)
	end
	local countours = ContourReasons[obj]
	if not countours then
		countours = {}
		ContourReasons[obj] = countours
	end
	local reasons = countours[contour]
	if reasons then
		reasons[reason] = true
		return
	end
	obj:SetContourRecursive(true, contour)
	countours[contour] = {[reason] = true}
end
--- Removes a contour reason for the specified object.
---
--- If the `ContourReasons` table does not exist or does not have an entry for the specified object, the function simply returns.
---
--- If the reasons table for the specified contour does not exist or does not have the specified reason, the function simply returns.
---
--- If the reasons table for the specified contour becomes empty after removing the reason, the contour is set to false recursively for the object, and the contours table and the `ContourReasons` table are cleaned up as necessary.
---
--- @param obj CObject The object to clear the contour reason for.
--- @param contour string The contour to clear the reason for.
--- @param reason string The reason to clear.
function ClearContourReason(obj, contour, reason)
	local countours = (ContourReasons or empty_table)[obj]
	local reasons = countours and countours[contour]
	if not reasons or not reasons[reason] then
		return
	end
	reasons[reason] = nil
	if not next(reasons) then
		obj:SetContourRecursive(false, contour)
		countours[contour] = nil
		if not next(countours) then
			ContourReasons[obj] = nil
		end
	end
end

-- Additional functions for working with groups

--- Returns a table, containing all objects from the specified group.
-- @param name string - The name of the group to get all objects from.
--- Returns a table containing all objects from the specified group.
---
--- If the specified group does not exist, an empty table is returned.
---
--- @param name string The name of the group to get all objects from.
--- @return table A table containing all objects in the specified group.
function GetGroup(name)
	local list = {}
	local group = Groups[name]
	if not group then
		return list
	end

	for i = 1,#group do
		local obj = group[i]
		if IsValid(obj) then list[#list + 1] = obj end
	end
	return list
end

--- Returns a reference to the specified group.
---
--- If the specified group does not exist, this function will return `nil`.
---
--- @param name string The name of the group to get a reference to.
--- @return table|nil A reference to the specified group, or `nil` if the group does not exist.
function GetGroupRef(name)
	return Groups[name]
end

--- Checks if a group with the given name exists.
---
--- @param name string The name of the group to check.
--- @return boolean true if the group exists, false otherwise.
function GroupExists(name)
	return not not Groups[name]
end

--- Returns a table containing the names of all groups.
---
--- The group names are sorted alphabetically.
---
--- @return table A table containing the names of all groups.
function GetGroupNames()
	local group_names = {}
	for group, _ in pairs(Groups) do
		table.insert(group_names, group)
	end
	table.sort(group_names)
	return group_names
end

--- Returns a table containing the names of all groups, with a leading space added to each name.
---
--- The group names are sorted alphabetically.
---
--- @return table A table containing the names of all groups, with a leading space added to each name.
function GroupNamesWithSpace()
	local group_names = {}
	for group, _ in pairs(Groups) do
		group_names[#group_names + 1] = " " .. group
	end
	table.sort(group_names)
	return group_names
end

--- Spawns the template objects from the specified group, adding the spawned ones to all groups the templates were in.
-- @param name string The name of the group to be spawned.
-- @param pos point Position to center the group on while spawning
-- @param filter is the same function that is passed to MapGet/MapCount queries
-- @return table An object list, containing the spawned units.
function SpawnGroup(name, pos, filter_func)
	local list = {}
	local templates = MapFilter(GetGroup(name, true), "map", "Template", filter_func)
	if #templates > 0 then
		-- Calculate offset to move group (if any)
		local center = AveragePoint(templates)
		if pos then
			center, pos = pos, (pos - center):SetInvalidZ()
		end
		for _, obj in ipairs(templates) do
			local spawned = obj:Spawn()
			if spawned then
				if pos then
					spawned:SetPos(obj:GetPos() + pos)
				end
				list[#list + 1] = spawned
			end
		end
	end
	return list
end


--- Spawns the template objects from the specified group, adding the spawned ones to all groups the templates were in; disperses the times of spawning in the given time interval.
-- @param name string The name of the group to be spawned.
-- @param pos point Position to center the group on while spawning
-- @param filter is the same structure that is passed to MapGet/MapCount queries
-- @param time number The length of the interval in which all units are randomly spawned.
-- @return table An object list, containing the spawned units.
function SpawnGroupOverTime(name, pos, filter, time)
	local list = {}
	local templates = MapFilter(GetGroup(name, true), "map", "Template", filter_func)
	-- Find appropriate times for spawning
	local times, sum = {}, 0
	for i = 1, #templates do
		if templates[i]:ShouldSpawn() then
			local rand = AsyncRand(1000)
			times[i] = rand
			sum = sum + rand
		else
			times[i] = false
		end
	end

	-- Spawn the units using the already known time intervals
	for i,obj in ipairs(templates) do
		if times[i] then
			local spawned_obj = obj:Spawn()
			if spawned_obj then
				list[#list + 1] = spawned_obj:SetPos(pos)
				Sleep(times[i]*time/sum)
			end
		end
	end
	return list
end

--- Clears the global flag tables used for tracking MapObject class information.
-- These tables are used to cache and optimize access to MapObject class flags.
-- They are cleared after the map is loaded, to ensure they are properly reinitialized.
__enumflags = false
__classflags = false
__componentflags = false
__gameflags = false

--- Clears the global flag tables used for tracking MapObject class information.
-- These tables are used to cache and optimize access to MapObject class flags.
-- They are cleared after the map is loaded, to ensure they are properly reinitialized.
function OnMsg.ClassesPostprocess()
	-- Clear surfaces flags for objects without surfaces or valid entities
	local asWalk = EntitySurfaces.Walk
	local efWalkable = const.efWalkable
	-- Collision flag is also used to enable/disable terrain surface application
	local asCollision = EntitySurfaces.Collision
	local efCollision = const.efCollision
	local asApplyToGrids = EntitySurfaces.ApplyToGrids
	local efApplyToGrids = const.efApplyToGrids
	local cmPassability = const.cmPassability
	local cmDefaultObject = const.cmDefaultObject

	__enumflags = FlagValuesTable("MapObject", "ef", function(name, flags)
		local class = g_Classes[name]
		local entity = class:GetEntity()
		if not class.variable_entity and IsValidEntity(entity) then
			if not HasAnySurfaces(entity, asWalk) then
				flags = FlagClear(flags, efWalkable)
			end
			if not HasAnySurfaces(entity, asCollision) and not HasMeshWithCollisionMask(entity, cmDefaultObject) then
				flags = FlagClear(flags, efCollision)
			end
			if not HasAnySurfaces(entity, asApplyToGrids) and not HasMeshWithCollisionMask(entity, cmPassability) then
				flags = FlagClear(flags, efApplyToGrids)
			end
			return flags
		end
	end)
	__gameflags = FlagValuesTable("MapObject", "gof")
	__classflags = FlagValuesTable("MapObject", "cf")
	__componentflags = FlagValuesTable("MapObject", "cof")
end

--- Reloads the MapObject class information in the C++ engine after the classes have been built.
-- This function is called in response to the ClassesBuilt message, and is responsible for:
-- - Clearing the static class information in the C++ engine
-- - Reloading the MapObject class information
-- - Reloading the information for all classes that inherit from MapObject
-- - Clearing the global flag tables used for tracking MapObject class information
-- These flag tables are used to cache and optimize access to MapObject class flags, and are cleared
-- to ensure they are properly reinitialized after the map is loaded.
function OnMsg.ClassesBuilt()
	-- mirror MapObject class info in the C++ engine for faster access
	ClearStaticClasses()
	ReloadStaticClass("MapObject", g_Classes.MapObject)
	ClassDescendants("MapObject", ReloadStaticClass)
	-- clear flag tables
	__enumflags = nil
	__classflags = nil
	__componentflags = nil
	__gameflags = nil
end

--- Clears references to cobjects in all lua objects after the map is done loading.
-- This function is called in response to the PostDoneMap message, and is responsible for:
-- - Iterating through the __cobjectToCObject table, which maps cobjects to lua objects
-- - Setting the true field of each lua object to false, effectively clearing the reference to the cobject
-- This is necessary to ensure that lua objects do not hold onto references to cobjects that have been destroyed or are no longer valid.
function OnMsg.PostDoneMap()
	-- clear references to cobjects in all lua objects
	for cobject, obj in pairs(__cobjectToCObject or empty_table) do
		if obj then
			obj[true] = false
		end
	end
end

DefineClass.StripCObjectProperties = {
	__parents = { "CObject" },
	properties = {
		{ id = "ColorizationPalette" },
		{ id = "ClassFlagsProp" },
		{ id = "ComponentFlagsProp" },
		{ id = "EnumFlagsProp" },
		{ id = "GameFlagsProp" },
		{ id = "SurfacesProp" },
		{ id = "Axis" },
		{ id = "Opacity" },
		{ id = "StateCategory" },
		{ id = "StateText" },
		{ id = "Mirrored" },
		{ id = "ColorModifier" },
		{ id = "Occludes" },
		{ id = "ApplyToGrids" },
		{ id = "IgnoreHeightSurfaces" },
		{ id = "Walkable" },
		{ id = "Collision" },
		{ id = "OnCollisionWithCamera" },
		{ id = "Scale" },
		{ id = "SIModulation" },
		{ id = "SIModulationManual" },
		{ id = "AnimSpeedModifier" },
		{ id = "Visible" },
		{ id = "SunShadow" },
		{ id = "CastShadow" },
		{ id = "Entity" },
		{ id = "Angle" },
		{ id = "ForcedLOD" },
		{ id = "Groups" },
		{ id = "CollectionIndex" },
		{ id = "CollectionName" },
		{ id = "Warped" },
		{ id = "SkewX", },
		{ id = "SkewY", },
		{ id = "ClipPlane", },
		{ id = "Radius", },
		{ id = "Sound", },
		{ id = "OnRoof", },
		{ id = "DontHideWithRoom", },
		{ id = "Saturation" },
		{ id = "Gamma" },
		{ id = "DetailClass", },
		{ id = "ForcedLODState", },
		{ id = "TestStateButtons", },
	},
}

for i = 1, const.MaxColorizationMaterials do
	table.iappend( StripCObjectProperties.properties, { 
		{ id = string.format("EditableColor%d", i) },
		{ id = string.format("EditableRoughness%d", i) },
		{ id = string.format("EditableMetallic%d", i) },
	})
end

---
--- Toggles the visibility of spots associated with the given CObject.
---
--- @param self CObject The CObject instance to toggle spot visibility for.
---
function CObject:AsyncCheatSpots()
	ToggleSpotVisibility{self}
end

---
--- Deletes the CObject instance.
---
--- This function is used to delete the CObject instance from the game world.
---
--- @param self CObject The CObject instance to delete.
---
function CObject:CheatDelete()
	DoneObject(self)
end

---
--- Shows the class hierarchy for the CObject instance.
---
--- This function is used to display the class hierarchy for the CObject instance in the game's debug UI.
---
--- @param self CObject The CObject instance to display the class hierarchy for.
---
function CObject:AsyncCheatClassHierarchy()
	DbgShowClassHierarchy(self.class)
end

---
--- Recursively marks all entities attached to the CObject instance.
---
--- This function is used to mark all entities that are attached to the CObject instance, including any entities that are attached to those attached entities. The marked entities are stored in the provided `entities` table.
---
--- @param self CObject The CObject instance to mark attached entities for.
--- @param entities table A table to store the marked entities in.
--- @return table The `entities` table, containing all marked entities.
---
function CObject:__MarkEntities(entities)
	if not IsValid(self) then return end
	
	entities[self:GetEntity()] = true
	for j = 1, self:GetNumAttaches() do
		local attach = self:GetAttach(j)
		attach:__MarkEntities(entities)
	end
end

---
--- Recursively marks all entities attached to the CObject instance.
---
--- This function is used to mark all entities that are attached to the CObject instance, including any entities that are attached to those attached entities. The marked entities are stored in the provided `entities` table.
---
--- @param self CObject The CObject instance to mark attached entities for.
--- @param entities table A table to store the marked entities in.
--- @return table The `entities` table, containing all marked entities.
---
function CObject:MarkAttachEntities(entities)
	entities = entities or {}
	
	self:__MarkEntities(entities)
	
	return entities
end

---
--- Takes a screenshot of the CObject instance.
---
--- This function is used to take a screenshot of the CObject instance, which can be useful for debugging purposes.
---
--- @param self CObject The CObject instance to take a screenshot of.
---
function CObject:AsyncCheatScreenshot()
	IsolatedObjectScreenshot(self)
end

-- Dev functionality
---
--- A table of allowed members for CObject instances.
---
CObjectAllowedMembers = {}
CObjectAllowedDeleteMethods = {}
