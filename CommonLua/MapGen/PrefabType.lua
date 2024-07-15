local height_tile = const.HeightTileSize
local table_find = table.find

local function CheckProp(name, value)
	value = value or false
	return function(self) return self[name] == value end
end
local OVRLP_DEL_NONE, OVRLP_DEL_ALL, OVRLP_DEL_IGNORE, OVRLP_DEL_PARTIAL, OVRLP_DEL_SINGLE = false, 0, 1, 2, 3
local function OnObjOverlapItems()
	return {
		{ value = OVRLP_DEL_NONE,    text = "Do nothing" },
		{ value = OVRLP_DEL_ALL,     text = "Delete the entire collection" },
		{ value = OVRLP_DEL_IGNORE,  text = "Delete ignoring collections" },
		{ value = OVRLP_DEL_PARTIAL, text = "Delete if the collection is outside" },
		{ value = OVRLP_DEL_SINGLE,  text = "Delete if not in collection" },
	}
end
		
---
--- Provides a set of functions to estimate the radius of a prefab.
---
--- The returned table contains the following functions:
---
--- - `incircle`: Returns the minimum radius of the prefab.
--- - `excircle`: Returns the maximum radius of the prefab.
--- - `amean`: Returns the arithmetic mean of the minimum and maximum radii.
--- - `gmean`: Returns the geometric mean of the minimum and maximum radii.
--- - `bestfit`: Returns the best-fit radius, calculated as the square root of the total area of the prefab divided by a constant.
---
--- @return table The set of radius estimator functions.
---
function PrefabRadiusEstimItems()
	return {
		{ value = "incircle", text = "Incircle (Min)",            color = red },
		{ value = "excircle", text = "Excircle (Max)",            color = green },
		{ value = "amean",    text = "Arithmetic Mean (Average)", color = yellow },
		{ value = "gmean",    text = "Geometric Mean (Ellipse)",  color = blue },
		{ value = "bestfit",  text = "Best Fit (Circle)",         color = cyan },
	}
end
---
--- Provides a set of functions to estimate the radius of a prefab.
---
--- The returned table contains the following functions:
---
--- - `incircle`: Returns the minimum radius of the prefab.
--- - `excircle`: Returns the maximum radius of the prefab.
--- - `amean`: Returns the arithmetic mean of the minimum and maximum radii.
--- - `gmean`: Returns the geometric mean of the minimum and maximum radii.
--- - `bestfit`: Returns the best-fit radius, calculated as the square root of the total area of the prefab divided by a constant.
---
--- @return table The set of radius estimator functions.
---
function PrefabRadiusEstimators()
	return {
		incircle = function(prefab) return prefab.min_radius end,
		excircle = function(prefab) return prefab.max_radius end,
		amean =    function(prefab) return (prefab.min_radius + prefab.max_radius) / 2 end,
		gmean =    function(prefab) return sqrt(prefab.min_radius * prefab.max_radius) end,
		bestfit =  function(prefab) return sqrt(prefab.total_area * 7 / 22) end,
	}
end

DefineClass.PrefabType = {
	__parents = { "Preset", },
	properties = {
		{ category = "General", id = "OnObjOverlap",   name = "On Object Overlap",    editor = "choice",      default = OVRLP_DEL_ALL, items = OnObjOverlapItems },
		{ category = "General", id = "RespectBounds",  name = "Respect Type Bounds",  editor = "bool",        default = true, help = "Disable prefab objects spill beyond the their prefab type boundaries. Doesn't affect POI prefabs as they can share multiple prefab types." },
		{ category = "General", id = "OverlapReduct",  name = "Lim Excircle Overlap", editor = "number",      default = 1, min = 0, max = 4, slider = true, help = "Prioritize prefabs with better incircle to excircle radius ratio (the best being 1, a perfect circle)" },
		{ category = "General", id = "FitEffort",      name = "Prefab Fit Effort",    editor = "number",      default = 1, min = 0, max = 4, slider = true, help = "Prioritize prefabs fitting better the available space (using the radius estimate)" },
		{ category = "General", id = "RadiusEstim",    name = "Radius Estimate",      editor = "choice",      default = "bestfit", items = PrefabRadiusEstimItems, help = "Used to estimate the prefab real form by a circle when fitting prefabs" },
		{ category = "General", id = "PlaceRadius",    name = "Min Prefab Radius",    editor = "number",      default = height_tile, scale = "m", help = "Ignore prefabs with radius estimate below that value" },
		{ category = "General", id = "FitPasses",      name = "Max Fit Passes",       editor = "number",      default = 5, min = 1, max = 5, slider = true, help = "Maximum number of prefab fitting passes" },
		{ category = "General", id = "MinFillRatio",   name = "Min Fill Ratio (%)",   editor = "number",      default = 100, min = 0, max = 100, slider = true, help = "How much of the prefab type surface would be filled at least (actual value can be bigger, but not lesser)" },
		{ category = "General", id = "MaxFillError",   name = "Max Fill Err (%)",     editor = "number",      default = 10, min = 0, max = 1000, scale = 10, slider = true, help = "How much of the prefab type surface specified to be filled could remain unfilled" },
		{ category = "General", id = "Tags",           name = "Tags",                 editor = "set",         default = empty_table, items = PrefabTagsCombo },
		
		{ category = "Terrain", id = "Transition",     name = "Transition",           editor = "number",      default = 0, scale = "m", granularity = height_tile, help = "Transition zone for texture dithering" },
		{ category = "Terrain", id = "TexturingOrder", name = "Texturing Order",      editor = "number",      default = 0, help = "Sort key used when applying prefab type terrain. Types with equal order are compared based on the descending transition dist." },
		{ category = "Terrain", id = "TextureMain",    name = "Main Texture",         editor = "choice",      default = "", items = GetTerrainNamesCombo(), },
		{ category = "Terrain", id = "GrassMain",      name = "Main Grass (%)",       editor = "number",      default = 100, min = 0, max = 200, slider = true, no_edit = CheckProp("TextureMain", "") },
		{ category = "Terrain", id = "PreviewMain",    name = "Main Preview",         editor = "image",       default = false, img_size = 128, img_box = 1, base_color_map = true, dont_save = true, no_edit = CheckProp("TextureMain", "") },
		
		{ category = "Terrain", id = "TextureFlow",    name = "Flow Texture",         editor = "choice",      default = "", items = GetTerrainNamesCombo(), },
		{ category = "Terrain", id = "GrassFlow",      name = "Flow Grass (%)",       editor = "number",      default = 100, min = 0, max = 200, slider = true, no_edit = CheckProp("TextureFlow", "") },
		{ category = "Terrain", id = "FlowStrength",   name = "Flow Strength",        editor = "number",      default = 100, min = 0, max = 200, scale = 100, slider = true },
		{ category = "Terrain", id = "FlowContrast",   name = "Flow Contrast",        editor = "number",      default = 100, min = 0, max = 300, scale = 100, slider = true },
		{ category = "Terrain", id = "PreviewFlow",    name = "Flow Preview",         editor = "image",       default = false, img_size = 128, img_box = 1, base_color_map = true, dont_save = true, no_edit = CheckProp("TextureFlow", "") },
		
		{ category = "Terrain", id = "TextureNoise",   name = "Noise Texture",        editor = "choice",      default = "", items = GetTerrainNamesCombo(), },
		{ category = "Terrain", id = "GrassNoise",     name = "Noise Grass (%)",      editor = "number",      default = 100, min = 0, max = 200, slider = true, no_edit = CheckProp("TextureNoise", "") },
		{ category = "Terrain", id = "PreviewNoise",   name = "Noise Preview",        editor = "image",       default = false, img_size = 128, img_box = 1, base_color_map = true, dont_save = true, no_edit = CheckProp("TextureNoise", "") },
		{ category = "Terrain", id = "HeightModulated",name = "Height Modulated",     editor = "bool",        default = false, },
		{ category = "Terrain", id = "NoiseStrength",  name = "Noise Strength",       editor = "number",      default = 100, min = 0, max = 200, scale = 100, slider = true },
		{ category = "Terrain", id = "NoiseContrast",  name = "Noise Contrast",       editor = "number",      default = 100, min = 0, max = 300, scale = 100, slider = true },
		{ category = "Terrain", id = "NoisePreset",    name = "Noise Pattern",        editor = "preset_id",   default = "", preset_class = "NoisePreset" },
		{ category = "Terrain", id = "NoisePreview",   name = "Noise Preview",        editor = "grid",        default = false, no_edit = function(self) return self.NoisePreset == "" end, frame = 1, min = 64, dont_save = true, read_only = true },
		
		{ category = "Editor",  id = "OverlayColor",   name = "Overlay Color",        editor = "color",       default = false, alpha = false },
		{ category = "Editor",  id = "FillPrefabList", name = "Fill Prefab List",     editor = "string_list", default = false, read_only = true, dont_save = true },
		{ category = "Editor",  id = "POIPrefabList",  name = "POI Prefab List",      editor = "string_list", default = false, read_only = true, dont_save = true },
		{ category = "Editor",  id = "POIList",        name = "POI List",             editor = "string_list", default = false, read_only = true, dont_save = true },
	},
	EditorMenubarName = "Prefab Types",
	EditorMenubar = "Map.Generate",
	EditorIcon = "CommonAssets/UI/Icons/puzzle.png",
	EditorView = Untranslated("<Id> <style GedConsole>[<SortKey>]</style>"),

	StoreAsTable = false,
	GlobalMap = "PrefabTypeToPreset",
	HasSortKey = true,
	
	GetPreviewMain = function(self) return GetTerrainTexturePreview(self.TextureMain) end,
	GetPreviewFlow = function(self) return GetTerrainTexturePreview(self.TextureFlow) end,
	GetPreviewNoise = function(self) return GetTerrainTexturePreview(self.TextureNoise) end,
	GetNoisePreview = function(self) return GetNoisePreview(self.NoisePreset) end,
}

---
--- Compares two `PrefabType` objects and returns a value indicating their relative order.
---
--- The comparison is based on the following criteria, in order of precedence:
--- 1. `SortKey` property: Compares the sort key values of the two `PrefabType` objects.
--- 2. `RespectBounds` property: Compares the `RespectBounds` values, with `true` values having higher precedence.
--- 3. `OnObjOverlap` property: Compares the `OnObjOverlap` values, with higher values having higher precedence.
--- 4. `id` property: If all other criteria are equal, compares the `id` values of the two `PrefabType` objects.
---
--- @param other PrefabType The other `PrefabType` object to compare against.
--- @return number A negative value if `self` is less than `other`, zero if they are equal, and a positive value if `self` is greater than `other`.
function PrefabType:Compare(other)
	local sa, sb = self.SortKey, other.SortKey
	if sa ~= sb then
		return sa < sb
	end
	local ba, bb = self.RespectBounds and 1 or 0, other.RespectBounds and 1 or 0
	if ba ~= bb then
		return ba > bb
	end
	local ooa, oob = (self.OnObjOverlap or -1), (other.OnObjOverlap or -1)
	if ooa ~= oob then
		return ooa > oob
	end
	return self.id < other.id
end

---
--- Returns a list of prefab names that are associated with the current PrefabType instance.
---
--- The list includes all prefabs that have a non-empty `poi_type` field and whose `PrefabTypeGroups` contain the current PrefabType's `id`.
---
--- The list is sorted alphabetically.
---
--- @return table A table of prefab names.
---
function PrefabType:GetPOIPrefabList()
	local names = {}
	local prefabs = PrefabMarkers or empty_table
	local poi_to_preset = PrefabPoiToPreset or empty_table
	local ptype = self.id
	for _, prefab in ipairs(prefabs) do
		local poi_type = prefab and prefab.poi_type or ""
		if poi_type ~= "" then
			local preset = poi_to_preset[poi_type]
			for _, group in pairs(preset and preset.PrefabTypeGroups) do
				if table_find(group.types, ptype) then
					names[#names + 1] = prefabs[prefab]
					break
				end
			end
		end
	end
	if #names == 0 then return end
	table.sort(names)
	return names
end

---
--- Returns a list of POI (Point of Interest) names that are associated with the current PrefabType instance.
---
--- The list includes all POIs that have a non-empty `poi_type` field and whose `PrefabTypeGroups` contain the current PrefabType's `id`.
---
--- The list is sorted alphabetically.
---
--- @return table A table of POI names.
---
function PrefabType:GetPOIList()
	local ptype = self.id
	local list = {}
	for name, preset in pairs(PrefabPoiToPreset) do
		for _, group in pairs(preset.PrefabTypeGroups) do
			if table_find(group.types, ptype) then
				list[#list + 1] = name
				break
			end
		end
	end
	table.sort(list)
	return list
end

---
--- Returns a list of all prefab names that are associated with the current PrefabType instance.
---
--- The list includes all prefabs that have an empty `poi_type` field or whose `type` field matches the current PrefabType's `id`.
---
--- The list is sorted alphabetically.
---
--- @return table A table of prefab names.
---
function PrefabType:GetFullPrefabList()
	local names = {}
	local prefabs = PrefabMarkers or empty_table
	local ptype = self.id
	for _, prefab in ipairs(prefabs) do
		local poi_type = prefab and prefab.poi_type or ""
		if poi_type == "" and (prefab.type == "" or prefab.type == ptype) then
			names[#names + 1] = prefabs[prefab]
		end
	end
	if #names == 0 then return end
	table.sort(names)
	return names
end

---
--- Returns a list of all PrefabType IDs.
---
--- The list is sorted alphabetically.
---
--- @return table A table of PrefabType IDs.
---
function GetPrefabTypeList()
	return table.keys(PrefabTypeToPreset, true)
end

---
--- Returns a list of all unique tags used by PrefabType presets.
---
--- If `add_empty` is true, the returned list will include an empty string as the first element.
---
--- @param add_empty boolean Whether to include an empty string in the returned list.
--- @return table A table of unique tags used by PrefabType presets.
---
function GetPrefabTypeTags(add_empty)
	local tags = {}
	for ptype, preset in pairs(PrefabTypeToPreset) do
		for tag in pairs(preset and preset.Tags or empty_table) do
			if tag ~= "" then
				tags[tag] = true
			end
		end
	end
	tags = table.keys(tags, true)
	if add_empty then
		table.insert(tags, 1, add_empty)
	end
	return tags
end

function OnMsg.GedPropertyEdited(_, obj)
	if IsKindOf(obj, "NoisePreset") then
		ForEachPreset("PrefabType", function(ptype)
			if ptype.NoisePreset == obj.id then
				ObjModified(ptype)
			end
		end)
	end
end