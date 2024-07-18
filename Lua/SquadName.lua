DefineClass.SquadName = {
	__parents = { "Preset" },
	properties = {
		{ id = "Name", name = "Name", editor = "text", default = "", translate = true, },
		{ id = "ShortName", name = "Short Name", editor = "text", default = false, translate = true, },
		{ id = "Context", name = "Context", editor = "text", default = "", },
	},
	PropertyTranslation = true,
	HasSortKey = true,
	
	EditorName = "Squad name",
	EditorMenubarName = "Squad Names",
	EditorMenubar = "Editors.Other",
	EditorViewPresetPostfix = Untranslated(" <color 75 105 198><Name>"),
	Documentation = "Defines a new squad name.",
}

DefineModItemPreset("SquadName", { EditorName = "Squad name", EditorSubmenu = "Unit" })

Affiliations = {
	"AIM",
	"Legion",
	"Army",
	"Beast",
	"Adonis",
	"Rebel",
	"Civilian",
	"Secret",
	"Thugs",
	"SuperSoldiers",
	"Other"
}
GameVar("gv_UsedSquadNameIndexes", {})

-- input is the Name T for the squad name
-- output is the corresponding ShortName T, or the input if it doesn't exist
---
--- Gets the short name for a given squad name.
---
--- @param Name string The full name of the squad.
--- @return string The short name of the squad, or the original name if no short name is found.
function SquadName:GetShortNameFromName(Name)
	local shortName = nil
	local name_id = TGetID(Name)
	ForEachPreset("SquadName", function(preset)
		if TGetID(preset.Name) == name_id then
			shortName = preset.ShortName
			return "break"
		end
	end)
	return shortName or Name
end

---
--- Gets a new unique squad name for the given side and units.
---
--- @param side string The side of the squad, either "player1", "player2", or "enemy1".
--- @param units table A table of unit IDs that the squad is composed of.
--- @return string The new unique squad name.
function SquadName:GetNewSquadName(side, units)
	local nameType = false
	if side == "player1" or side == "player2" then
		nameType = "Player"
	else
		-- if no units are passed we cannot determine affiliation
		if not units or not next(units) then
			return Presets.SquadName.Default.Enemy.Name
		end
		
		local firstUnit = units[1]
		firstUnit = firstUnit and gv_UnitData[firstUnit]
		if firstUnit then
			nameType = firstUnit.Affiliation
			assert(Presets.SquadName[nameType])
		end
	end
	
	local names = Presets.SquadName[nameType]
	if not names then
		if side ~= "enemy1" then
			return Presets.SquadName.Default.Squad.Name
		end
		return Presets.SquadName.Default.Enemy.Name
	end
	
	-- pick next unused name from the group
	local used = gv_UsedSquadNameIndexes[nameType] or {} -- this used to store indexes, but now it keeps a table with a <preset id => true> mapping
	for _, preset in ipairs(names) do
		if not used[preset.id] then
			used[preset.id] = true
			gv_UsedSquadNameIndexes[nameType] = used
			return preset.Name
		end
	end
	
	-- if not, pick a name currently not in use
	for _, preset in ipairs(names) do
		local nameUsed = false
		for _, squad in ipairs(g_SquadsArray) do
			if TGetID(squad.Name) == TGetID(preset.Name) then
				nameUsed = true
				break
			end
		end
		
		if not nameUsed then
			return preset.Name
		end
	end
	
	gv_UsedSquadNameIndexes[nameType] = { [names[1].id] = true }
	return names[1].Name
end

---
--- Converts the format of the `gv_UsedSquadNameIndexes` global variable from a numeric index to a table with preset IDs as keys.
---
--- This function is part of the `SavegameSessionDataFixups` module, which is responsible for fixing up data in saved games when the game is updated.
---
--- @param data table The saved game data to be fixed up.
--- @param metadata table Metadata about the saved game.
--- @param lua_ver number The version of Lua used in the saved game.
---
function SavegameSessionDataFixups.ConvertUsedSquadNamesToPresetIds(data, metadata, lua_ver)
	local to_fixup = data.gvars.gv_UsedSquadNameIndexes
	for group, idx in pairs(to_fixup) do
		local used_ids = {}
		for i = 1, idx do
			used_ids[string.format("Name%02d", i)] = true
		end
		to_fixup[group] = used_ids
	end
end
