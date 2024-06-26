SetupVarTable(clutter, "clutter.")

clutter.noisePreset = "ClutterNoise"

IsClutterObj = empty_func

if not clutter.enabled then
	return
end

local cofComponentInstancing = const.cofComponentInstancing
IsClutterObj = function(obj)
	return obj:GetComponentFlags(cofComponentInstancing) ~= 0
end

---
--- Reloads the definitions for clutter objects in the game.
---
--- This function is responsible for updating the clutter system with the latest
--- terrain and grass definitions. It first deactivates the clutter system,
--- then updates the noise preset and adds terrain types and object definitions
--- for each terrain type. Finally, it reactivates the clutter system.
---
--- This function is called in response to various events, such as when terrain
--- textures are loaded, when a property of a terrain object is edited, or when
--- a new map is loaded.
---
--- @function ReloadClutterObjectDefs
--- @return nil
function ReloadClutterObjectDefs()
	local clutterActive = clutter.IsActive()
	clutter.Activate(false)
	local noise = NoisePresets[clutter.noisePreset]
	clutter.SetNoise(noise and noise:GetNoise() or nil)
	ForEachPreset("TerrainObj", function(entry)
		local terrain_idx = GetTerrainTextureIndex(entry.id)
		if not terrain_idx then
			print("once", "Invalid terrain type", entry.id)
		else
			clutter.AddTerrainType(terrain_idx, entry.grass_density)
			for _, grass_def in ipairs(entry.grass_list or empty_table) do
				local classes = grass_def.Classes
				for _, class in ipairs(classes) do
					clutter.AddObjectDef(class, terrain_idx, grass_def.Weight, grass_def.NoiseWeight, grass_def.TiltWithTerrain, grass_def.PlaceOnWater, grass_def.SizeFrom, grass_def.SizeTo, grass_def.ColorVarFrom, grass_def.ColorVarTo)
				end
			end
		end
	end)
	clutter.Activate(clutterActive)
end

---
--- Creates clutter objects in the game.
---
--- This function is responsible for activating the clutter system when the
--- `hr.RenderClutter` flag is true. It is called in response to various events,
--- such as when a new map is loaded or when the game is loaded.
---
--- @function CreateClutterObjects
--- @return nil
function CreateClutterObjects()
    if hr.RenderClutter then
        clutter.Activate(true)
    end
end

---
--- Deactivates the clutter system.
---
--- This function is responsible for deactivating the clutter system, which is
--- used to render clutter objects in the game. It is typically called in
--- response to various events, such as when a new map is loaded or when the
--- game is unloaded.
---
--- @function DestroyClutterObjects
--- @return nil
function DestroyClutterObjects()
    clutter.Activate(false)
end

---
--- Draws debug visualizations for all clutter objects in the current map.
---
--- This function is used for debugging purposes, to visualize the placement and
--- properties of clutter objects in the game world. It iterates through all
--- clutter objects in the current map and draws debug visualizations for each
--- one, using the `clutter.DebugDrawInstances` function.
---
--- @function clutter.DebugDrawObjects
--- @param duration number (optional) The duration in milliseconds for which the debug visualizations should be displayed. Defaults to 2000 (2 seconds).
--- @return nil
function clutter.DebugDrawObjects(duration)
    local clutterObjs = MapGet("map", IsClutterObj) or {}
    for _, obj in ipairs(clutterObjs) do
        clutter.DebugDrawInstances(obj, false, duration or 2000)
    end
end

function OnMsg.PresetSave(class)
	local classdef = g_Classes[class]
	if IsKindOfClasses(classdef, "TerrainObj", "TerrainGrass") then
		ReloadClutterObjectDefs()
	end
end

function OnMsg.GedPropertyEdited(ged_id, object, prop_id, old_value)
	if object.class == "TerrainObj" or object.class == "TerrainGrass" or object.class == "NoisePreset" and object.id == clutter.noisePreset then
		ReloadClutterObjectDefs()
	end
end

OnMsg.TerrainTexturesLoaded = ReloadClutterObjectDefs
OnMsg.LoadGame = CreateClutterObjects
OnMsg.NewMapLoaded = CreateClutterObjects
OnMsg.DoneMap = DestroyClutterObjects
