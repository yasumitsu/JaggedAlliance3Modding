--- Checks if the given ID represents a terrain entity.
---
--- @param id string The ID to check.
--- @return boolean True if the ID represents a terrain entity, false otherwise.
function IsTerrainEntityId(id)
	return id:starts_with("Terrain")
end

function TerrainMaterials()
	---
 --- Retrieves a list of terrain material names from the "svnAssets/Bin/Common/Materials/" directory.
 ---
 --- @return table A table of terrain material names.
 ---
 local path = "svnAssets/Bin/Common/Materials/"
	local files = io.listfiles(path)

	local filtered = {}
	for _, path in ipairs(files) do
		local dir, name, ext = SplitPath(path)
		if string.starts_with(name, "Terrain") then
			table.insert(filtered, name .. ext)
		end
	end

	return filtered
end

---
--- Retrieves the maximum terrain texture index.
---
--- @return integer The maximum terrain texture index.
---
function MaxTerrainTextureIdx()
	local max_idx = -1
	for idx in pairs(TerrainTextures) do
		max_idx = Max(max_idx, idx)
	end
	return max_idx
end

DefineClass.TerrainObj = {
	__parents = { "Preset" },
	properties = {
		{ id = "Group", editor = false },
		
		-- index in the terrain grid, generated per preset and saved (so DLC terrains and deleting terrains won't cause issues)
		{ category = "Terrain", id = "idx", name = "Type index", editor = "number", default = 0, read_only = true, },
		{ category = "Terrain", id = "invalid", name = "Invalid terrain", editor = "bool", default = false, help = "Missing terrains (e.g. disabled in a DLC) will be visualized by the first invalid terrain found", },
		{ category = "Terrain", id = "material_name", name = "Material", editor = "combo", default = "", items = TerrainMaterials, help = "The Alpha of the base color is used as 'height' of the terrain, when blending with others. The height should always reach atleast 128(grey), otherwise there will be problems with the blending."  },
		{ category = "Terrain", id = "size", name = "Size", editor = "number", scale = "m", default = config.DefaultTerrainTileSize },
		{ category = "Terrain", id = "offset_x", name = "Offset X", editor = "number", scale = "m", default = 0, },
		{ category = "Terrain", id = "offset_y", name = "Offset Y", editor = "number", scale = "m", default = 0, },
		{ category = "Terrain", id = "rotation", name = "Rotation", editor = "number", scale = "deg", default = 0 },
		{ category = "Terrain", id = "color_modifier", name = "Color modifier", editor = "rgbrm", default = RGB(100, 100, 100), buttons = {{name = "Reset", func = "ResetColorModifier"}}},
		{ category = "Terrain", id = "vertical", name = "Vertical", editor = "bool", default = false },
		{ category = "Terrain", id = "inside", name = "Inside", editor = "bool", default = false },
		{ category = "Terrain", id = "blur_radius", name = "Blur radius", editor = "number", default = 2*guim, min = 0, max = 15 * guim, slider = true, scale = "m" },
		{ category = "Terrain", id = "z_order", name = "Z Order", editor = "number", default = 0 },
		{ category = "Terrain", id = "type", name = "FX Surface type", editor = "combo", default = "Dirt", items = PresetsPropCombo("TerrainObj", "type") },
		
		{ category = "Textures", id = "basecolor", editor = "text", default = "", read_only = true, dont_save = true, buttons = {{name = "Locate", func = "EV_LocateFile"}} },
		{ category = "Textures", id = "normalmap", editor = "text", default = "", read_only = true, dont_save = true, buttons = {{name = "Locate", func = "EV_LocateFile"}} },
		{ category = "Textures", id = "rmmap",     editor = "text", default = "", read_only = true, dont_save = true, buttons = {{name = "Locate", func = "EV_LocateFile"}} },
		
		{ category = "Grass", name = "Grass Density", id = "grass_density", editor="number", scale = 1000, default = 1000 },
		{ category = "Grass", name = "Grass List", id = "grass_list", editor = "nested_list", base_class = "TerrainGrass", default = false, inclusive = true },			
	},
	
	EditorName = "Terrain Config",
	EditorMenubarName = "Terrain Config",
	EditorIcon = "CommonAssets/UI/Menu/TerrainConfigEditor.tga",
	EditorMenubar = "Editors.Art",
	FilterClass = "TerrainFilter",
	
	StoreAsTable = false,
}

if const.pfTerrainCost then
	function PathfindSurfTypesCombo()
		local items = table.copy(pathfind_pass_types) or {}
		items[1] = "" -- default
		return items
	end
	table.insert(TerrainObj.properties, { category = "Terrain", id = "pass_type", name = "Pass Type", editor = "choice", default = "", items = PathfindSurfTypesCombo })
end

local function RefreshMaterials()
	ForEachPresetExtended(TerrainObj, function(preset) 
		preset:RefreshMaterial()
	end)
	ObjModified(Presets.TerrainObj)
	Msg("TerrainMaterialsLoaded")
end

OnMsg.BinAssetsLoaded = RefreshMaterials

---
--- Reloads the terrain textures and updates the global tables `TerrainTextures` and `TerrainNameToIdx`.
---
--- This function is called when the terrain textures have been loaded or modified. It iterates through all the terrain presets
--- that have a valid material name, and populates the `TerrainTextures` and `TerrainNameToIdx` tables with the terrain data.
---
--- If there are any "holes" in the terrain textures (e.g. terrains that have been moved to a DLC), this function creates
--- new terrain presets with the properties of the first invalid terrain, and adds them to the `TerrainTextures` table to
--- ensure that the C side continues to receive a solid array of terrains.
---
--- @function ReloadTerrains
--- @return nil
function ReloadTerrains()
	local presets = {}
	ForEachPreset("TerrainObj", function(preset)
		if preset.material_name ~= "" then
			presets[#presets + 1] = preset
		end
	end)

	local invalid = presets[1]
	TerrainTextures = {}
	TerrainNameToIdx = {}
	for _, preset in ipairs(presets) do
		TerrainTextures[preset.idx] = preset
		TerrainNameToIdx[preset.id] = preset.idx
		if preset.invalid then
			invalid = preset
		end
	end
	
	-- replace the holes in terrain textures (e.g. terrains moved to a DLC) with an invalid terrain,
	-- so the C side continues to receive a solid array of terrains
	local extended_presets = {}
	for i = 0, MaxTerrainTextureIdx() do
		local preset = TerrainTextures[i]
		if not preset then
			preset = TerrainObj:new()
			preset.SetId = function(self, id) self.id = id end
			preset.SetGroup = function(self, group) self.group = group end
			preset:CopyProperties(invalid)
			preset.idx = i
		end
		extended_presets[i + 1] = preset
	end
	TerrainTexturesLoad(extended_presets)
	Msg("TerrainTexturesLoaded")
end

function OnMsg.DataLoaded()
	ReloadTerrains()
end

--- Refreshes the material properties for the TerrainObj instance.
---
--- This function is called to update the `basecolor`, `normalmap`, and `rmmap` properties of the TerrainObj instance
--- based on the material properties retrieved from the `GetMaterialProperties` function.
---
--- If the `material_name` property is an empty string, this function will return `false` without updating any properties.
---
--- @function TerrainObj:RefreshMaterial
--- @return boolean # Returns `false` if the `material_name` property is an empty string, otherwise `true`
function TerrainObj:RefreshMaterial()
	if self.material_name == "" then return false end
	local mat_props = GetMaterialProperties(self.material_name)
	if mat_props then
		self.basecolor  = mat_props.BaseColorMap or ""
		self.normalmap  = mat_props.NormalMap or ""
		self.rmmap      = mat_props.RMMap or ""
	end
end

---
--- Called when a property of the TerrainObj instance is set in the editor.
---
--- This function is responsible for:
--- - Refreshing the material properties of the TerrainObj instance by calling the `RefreshMaterial()` function.
--- - Reloading the terrain textures by calling the `ReloadTerrains()` function.
--- - Setting the `hr.TR_ForceReloadTextures` flag to `true` to force a reload of the terrain textures.
--- - Calling the `Preset.OnEditorSetProperty()` function to handle any additional property changes.
---
--- @function TerrainObj:OnEditorSetProperty
--- @param ... # Any additional arguments passed to the function
--- @return nil
function TerrainObj:OnEditorSetProperty(...)
	self:RefreshMaterial()
	ReloadTerrains()
	hr.TR_ForceReloadTextures = true
	Preset.OnEditorSetProperty(self, ...)
end

function OnMsg.GedOpened(ged_id)
	local ged = GedConnections[ged_id]
	if ged and ged:ResolveObj("root") == Presets.TerrainObj then
		CreateRealTimeThread(RefreshMaterials)
	end
end

--- Called when a new TerrainObj instance is created in the editor.
---
--- This function is responsible for:
--- - Setting the `idx` property of the TerrainObj instance to the next available terrain texture index.
--- - Calling the `RefreshMaterial()` function to update the material properties of the TerrainObj instance.
---
--- @function TerrainObj:OnEditorNew
--- @return nil
function TerrainObj:OnEditorNew()
	self.idx = MaxTerrainTextureIdx() + 1
	self:RefreshMaterial()
end

--- Called after a TerrainObj instance is loaded.
---
--- This function is responsible for:
--- - Calling the `Preset.PostLoad()` function to handle any additional post-load processing.
--- - Calling the `RefreshMaterial()` function to update the material properties of the TerrainObj instance.
---
--- @function TerrainObj:PostLoad
--- @return nil
function TerrainObj:PostLoad()
	Preset.PostLoad(self)
	self:RefreshMaterial()
end

---
--- Sorts the terrain presets in the Presets table alphabetically by their `id` property, and then by their `save_in` property if the `id` values are the same.
---
--- This function is responsible for:
--- - Retrieving the list of terrain presets from the Presets table, using the `PresetClass` or `class` property of the `TerrainObj` instance.
--- - Sorting the presets in each group (if there are multiple groups) alphabetically by their `id` property, and then by their `save_in` property if the `id` values are the same.
--- - Calling `ObjModified(presets)` to notify the system that the presets have been modified.
---
--- @function TerrainObj:SortPresets
--- @return nil
function TerrainObj:SortPresets()
	-- sort terrain alphabetically by id for convenience; terrain indexes that are stored in the grid are saved in the 'idx' property
	local presets = Presets[self.PresetClass or self.class] or empty_table
	for _, group in ipairs(presets) do
		table.sort(group, function(a, b)
			local aid, bid = a.id:lower(), b.id:lower()
			return aid < bid or aid == bid and a.save_in < b.save_in
		end)
	end
	ObjModified(presets)
end

---
--- Applies a terrain preview to a class definition.
---
--- The function creates a set of preview properties for the class definition, including properties for height, basecolor, normalmap, and RM. The properties are added to the `properties` table of the class definition, and getter functions are defined to retrieve the preview values.
---
--- @param classdef The class definition to apply the terrain preview to.
--- @param objname The name of the object property to use for the preview, if applicable.
---
function ApplyTerrainPreview(classdef, objname)
	local previews = {
		{ id = "Height", tex = "basecolor", img_draw_alpha_only = true },
		{ id = "Basecolor", tex = "basecolor" },
		{ id = "Normalmap", tex = "normalmap" },
		{ id = "RM", tex = "rmmap" },
	}

	for i = 1, #previews do
		local preview = previews[i]
		local id = preview.id .. "Preview"
		local getter = function(self)
			local ext = preview.ext or ""
			local obj = objname and self[objname] or self
			if type(obj) == "function" then
				obj = obj(self)
			end
			local condition = not preview.condition or obj and obj[preview.condition]
			return (obj and obj.id ~= "" and condition) and rawget(obj, preview.tex) and obj[preview.tex] or "" 
		end
		classdef["Get" .. id] = getter
		table.insert(classdef.properties, table.find(classdef.properties, "id", preview.tex) + 1, {
			category = "Textures", 
			id = id,
			name = preview.id,
			editor = "image",
			default = "",
			dont_save = true,
			img_size = 128,
			img_box = 1,
			base_color_map = not preview.img_draw_alpha_only,
			img_draw_alpha_only = preview.img_draw_alpha_only,
			no_edit = function(self) return getter(self) == "" end,
		})
	end
end

ApplyTerrainPreview(TerrainObj)

---
--- Returns a preview string for the terrain object's editor view.
---
--- The preview string includes an image of the terrain object's basecolor texture, and the terrain object's index.
---
--- @return string The preview string for the terrain object's editor view.
---
function TerrainObj:GetEditorViewPresetPrefix()
	local preview = self:GetBasecolorPreview()
	return "<image " .. ConvertToOSPath(preview) .. " 100 rgb> <color 128 128 0>" .. self.idx .. "</color> "
end


----- Filter for the Terrain editor

DefineClass.TerrainFilter = {
	__parents = { "GedFilter" },
	
	properties = {
		{ id = "Material", editor = "choice", default = "", items = TerrainMaterials },
	},
}

---
--- Filters a terrain object based on the specified material.
---
--- @param o table The terrain object to filter.
--- @return boolean True if the terrain object passes the filter, false otherwise.
---
function TerrainFilter:FilterObject(o)
	if self.Material ~= "" and o.material_name ~= self.Material then
		return false
	end
	return true
end

---
--- Attempts to reset the terrain filter.
---
--- This function always returns `false`, indicating that the terrain filter cannot be reset.
---
--- @param ged table The terrain editor object.
--- @param op string The operation being performed.
--- @param to_view boolean Whether the reset is being performed to switch to a different view.
--- @return boolean Always returns `false`.
---
function TerrainFilter:TryReset(ged, op, to_view)
	return false
end
