DefineClass.DistToTag = {
	__parents = { "PropertyObject", },
	properties = {
		{ category = "General", id = "Tag",  name = "Tag",  editor = "preset_id", default = false, preset_class = "PrefabTag" },
		{ category = "General", id = "Dist", name = "Dist", editor = "number", default = 0, scale = "m" },
		{ category = "General", id = "Op",   name = "Op",   editor = "choice", default = '>', items = {'>', '<'} },
	},
	EditorView = Untranslated("<Tag> <Op> <dist(Dist)>"),
}

DefineClass.PrefabTag = {
	__parents = { "Preset", },
	properties = {
		{ category = "General", id = "Persistable",      name = "Persistable",           editor = "bool",        default = false, help = "POI prefabs with such tag will try to persist their location between map generations." },
		{ category = "General", id = "TagDist",          name = "Dist To Tags",          editor = "nested_list", default = empty_table, base_class = "DistToTag", help = "Defines the distances to the border of other POI with specified tags" },
		{ category = "General", id = "TagDistStats",     name = "All Dist Stats",        editor = "text",        default = "", lines = 1, max_lines = 20, dont_save = true, read_only = true },
		{ category = "General", id = "PrefabPOI",        name = "POI Types",             editor = "text",        default = "", lines = 1, max_lines = 20, dont_save = true, read_only = true },
		{ category = "General", id = "PrefabTypes",      name = "Prefab Types",          editor = "text",        default = "", lines = 1, max_lines = 20, dont_save = true, read_only = true },
		{ category = "General", id = "Prefabs",          name = "Prefabs",               editor = "text",        default = "", lines = 1, max_lines = 30, dont_save = true, read_only = true },
	},
	EditorMenubarName = "Prefab Tags",
	EditorIcon = "CommonAssets/UI/Icons/list.png",
	EditorMenubar = "Map.Generate",
	StoreAsTable = false,
	GlobalMap = "PrefabTags",
}

--- Returns the editor view prefix for the PrefabTag preset.
---
--- If the `Persistable` property is true, the prefix will be "<color 255 255 0>", otherwise it will be an empty string.
---
--- @return string The editor view prefix for the PrefabTag preset.
function PrefabTag:GetEditorViewPresetPrefix()
	return self.Persistable and "<color 255 255 0>" or ""
end

--- Returns the editor view postfix for the PrefabTag preset.
---
--- If the `Persistable` property is true, the postfix will be `</color>`, otherwise it will be an empty string.
---
--- @return string The editor view postfix for the PrefabTag preset.
function PrefabTag:GetEditorViewPresetPostfix()
	return self.Persistable and "</color>" or ""
end

--- Returns a string containing the distance statistics for the tags associated with this PrefabTag.
---
--- The string will contain one line for each tag, in the format:
--- - `<tag> > <min_distance> m`
--- - `<tag> < <max_distance> m`
---
--- The lines are sorted alphabetically by tag name.
---
--- @return string The distance statistics for the tags associated with this PrefabTag.
function PrefabTag:GetTagDistStats()
	local tag_to_tag_limits = GetPrefabTagsLimits(true)
	local stats = {}
	for tag, limits in sorted_pairs(tag_to_tag_limits[self.id]) do
		local min_dist, max_dist = limits[1] or min_int, limits[2] or max_int
		if min_dist and min_dist >= 0 then
			stats[#stats + 1] = string.format("%s > %d m", tag, min_dist / guim)
		end
		if max_dist and max_dist < max_int then
			stats[#stats + 1] = string.format("%s < %d m", tag, max_dist / guim)
		end
	end
	table.sort(stats)
	return table.concat(stats, "\n")
end

--- Returns a list of PrefabPOI preset IDs that are associated with the given PrefabTag.
---
--- The list is sorted alphabetically.
---
--- @return string A newline-separated list of PrefabPOI preset IDs.
function PrefabTag:GetPrefabPOI()
	local tag = self.id
	local presets = {}
	ForEachPreset("PrefabPOI", function(preset, group, tag, presets)
		local tags = preset.Tags or empty_table
		if tags[tag] then
			presets[#presets + 1] = preset.id
		end
	end, tag, presets)
	table.sort(presets)
	return table.concat(presets, "\n")
end

--- Returns a newline-separated list of PrefabType preset IDs that are associated with the given PrefabTag.
---
--- The list is sorted alphabetically.
---
--- @return string A newline-separated list of PrefabType preset IDs.
function PrefabTag:GetPrefabTypes()
	local tag = self.id
	local presets = {}
	ForEachPreset("PrefabType", function(preset, group, tag, presets)
		local tags = preset.Tags or empty_table
		if tags[tag] then
			presets[#presets + 1] = preset.id
		end
	end, tag, presets)
	table.sort(presets)
	return table.concat(presets, "\n")
end

--- Returns a newline-separated list of PrefabMarker preset IDs that are associated with the given PrefabTag.
---
--- The list is sorted alphabetically.
---
--- @return string A newline-separated list of PrefabMarker preset IDs.
function PrefabTag:GetPrefabs()
	local tag = self.id
	local presets = {}
	local markers = PrefabMarkers
	for _, marker in ipairs(markers) do
		local tags = marker.tags or empty_table
		if tags[tag] then
			presets[#presets + 1] = markers[marker]
		end
	end
	table.sort(presets)
	return table.concat(presets, "\n")
end

--- Returns an error message if the PrefabTag has invalid limits.
---
--- The function checks the limits defined for the PrefabTag in the `PrefabTags` table. If any of the limits have a minimum distance greater than or equal to the maximum distance, an "Invalid limits" error message is returned.
---
--- @return string|nil An error message if the limits are invalid, or nil if the limits are valid.
function PrefabTag:GetError()
	local tag_to_tag_limits = GetPrefabTagsLimits()
	for tag, limits in sorted_pairs(tag_to_tag_limits[self.id]) do
		local min_dist, max_dist = limits[1] or min_int, limits[2] or max_int
		if min_dist >= max_dist then
			return "Invalid limitst"
		end
	end
end

----

---
--- Returns a table mapping each PrefabTag to a table of limits for other PrefabTags.
---
--- The returned table has the following structure:
---
--- ```
--- {
---   ["tag1"] = {
---     ["tag2"] = {min_dist, max_dist},
---     ["tag3"] = {min_dist, max_dist},
---     ...
---   },
---   ["tag2"] = {
---     ["tag1"] = {min_dist, max_dist},
---     ["tag4"] = {min_dist, max_dist},
---     ...
---   },
---   ...
--- }
---
--- The min_dist and max_dist values are the minimum and maximum distances allowed between the two PrefabTags, as defined in the `PrefabTags` table.
---
--- @param mirror boolean (optional) If true, the limits will be mirrored in both directions (i.e. the limits for tag1->tag2 will also be set for tag2->tag1).
--- @return table A table mapping PrefabTags to their limits.
---
function GetPrefabTagsLimits(mirror)
	local tag_to_tag_limits = {}
	for tag1, tag_info in pairs(PrefabTags) do
		local tag_limits
		for _, entry in ipairs(tag_info.TagDist) do
			if not tag_limits then
				tag_limits = tag_to_tag_limits[tag1]
				if not tag_limits then
					tag_limits = {}
					tag_to_tag_limits[tag1] = tag_limits
				end
			end
			local tag2 = entry.Tag
			local limits = tag_limits[tag2]
			if not limits then
				limits = {}
				tag_limits[tag2] = limits
				if mirror and tag1 ~= tag2 then
					table.set(tag_to_tag_limits, tag2, tag1, limits)
				end
			end
			local dist = entry.Dist
			local op = entry.Op
			if op == '>' then
				limits[1] = Max(limits[1] or min_int, dist)
			elseif op == '<' then
				limits[2] = Min(limits[2] or max_int, dist)
			end
		end
	end
	return tag_to_tag_limits
end

---
--- Returns a table of PrefabTag names that are marked as Persistable.
---
--- The PrefabTags table defines various tags that can be applied to prefabs in the game world.
--- Some of these tags are marked as Persistable, meaning they should be saved and loaded
--- when the game world is saved and loaded.
---
--- This function iterates through the PrefabTags table and returns a table containing
--- the names of all tags that have the Persistable flag set to true.
---
--- @return table A table of PrefabTag names that are marked as Persistable.
---
function GetPrefabTagsPersistable()
	local tags = {}
	for tag, tag_info in pairs(PrefabTags) do
		if tag_info.Persistable then
			tags[tag] = true
		end
	end
	return tags
end

----

---
--- Returns a table of all PrefabTag names defined in the game.
---
--- This function iterates through all PrefabTag presets and returns a sorted table
--- containing the ID (name) of each preset.
---
--- @return table A table of PrefabTag names.
---
function PrefabTagsCombo()
	local tags = {}
	ForEachPreset("PrefabTag", function(preset, group, tags)
		tags[#tags + 1] = preset.id
	end, tags)
	table.sort(tags)
	return tags
end

----

AppendClass.MapDataPreset = { properties = {
	{ category = "Random Map", id = "PersistedPrefabs", editor = "prop_table", default = empty_table, no_edit = true },
	{ category = "Random Map", id = "PersistedPrefabsPreview", name = "Persisted Prefabs", editor = "text", default = "", read_only = true, lines = 1, max_lines = 10 }
}}

---
--- Returns a preview string of the persisted prefabs for this map data preset.
---
--- The preview string is generated by concatenating the names of all persisted prefabs
--- in the PersistedPrefabs table, separated by commas and newlines.
---
--- @return string The preview string of persisted prefabs.
---
function MapDataPreset:GetPersistedPrefabsPreview()
	local text = {}
	for _, entry in ipairs(self.PersistedPrefabs) do
		text[#text + 1] = table.concat(entry, ", ")
	end
	return table.concat(text, "\n")
end
