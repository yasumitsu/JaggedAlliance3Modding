-- Sample transitional terrains declaration. Note that the transitional has greater id than the 2 that use it.
--- Returns the index of the terrain giving its name as input.
-- @cstyle int GetTerrainTextureIndex(string nameTerrain).
-- @param nameTerrain string. the name of the terrain.
-- @return int. index of the terrain (nil if invalid terrain name is given).

if FirstLoad then
	TerrainTextures = {}
	TerrainNameToIdx = {}
end

--- Returns the index of the terrain giving its name as input.
-- @param nameTerrain string. the name of the terrain.
-- @return int. index of the terrain (nil if invalid terrain name is given).
function GetTerrainTextureIndex(nameTerrain)
    return TerrainNameToIdx[nameTerrain]
end

---
--- Returns the terrain texture preview image for the given terrain name.
---
--- @param nameTerrain string The name of the terrain.
--- @return boolean|userdata The terrain texture preview image, or false if the terrain name is invalid.
function GetTerrainTexturePreview(nameTerrain)
    local idx = GetTerrainTextureIndex(nameTerrain)
    return idx and TerrainTextures[idx] and GetTerrainImage(TerrainTextures[idx].basecolor) or false
end

---
--- Returns a combo box containing all the terrain names.
---
--- @return table A table containing the terrain names.
function GetTerrainNamesCombo()
    return PresetsCombo("TerrainObj", false, "")
end

----

if FirstLoad then
	suspendReasons = {}
end

---
--- Suspends terrain invalidations for the given reason.
---
--- If there are no other reasons to suspend terrain invalidations and the map is not empty, this function will suspend terrain invalidation.
--- The given reason is stored in the `suspendReasons` table, and terrain invalidation will remain suspended until `ResumeTerrainInvalidations` is called with the same reason.
---
--- @param reason string|boolean The reason for suspending terrain invalidations, or `false` if no specific reason is given.
function SuspendTerrainInvalidations(reason)
    reason = reason or false
    if next(suspendReasons) == nil and GetMap() ~= "" then
        terrain.SuspendInvalidation()
    end
    suspendReasons[reason] = true
end

---
--- Resumes terrain invalidations that were previously suspended.
---
--- If there are no other reasons to suspend terrain invalidations and the map is not empty, this function will resume terrain invalidation.
--- The given reason is removed from the `suspendReasons` table, and terrain invalidation will resume if there are no other reasons to suspend it.
---
--- @param reason string|boolean The reason for suspending terrain invalidations, or `false` if no specific reason was given.
--- @param reload boolean If true, forces a reload of the terrain textures.
function ResumeTerrainInvalidations(reason, reload)
    reason = reason or false
    suspendReasons[reason] = nil
    if next(suspendReasons) == nil and GetMap() ~= "" then
        if reload then
            hr.TR_ForceReloadNoTextures = 1
        end
        terrain.ResumeInvalidation()
    end
end

----

if FirstLoad then
	activeThread = false
end
---
--- Schedules a terrain reload to occur in 3 seconds.
---
--- If there is no active thread for reloading the terrain, this function will create a new real-time thread that will sleep for 2.8 seconds and then force a reload of the terrain textures.
---
--- @function ScheduleReloadTerrain
--- @return nil
function ScheduleReloadTerrain()
    if not IsValidThread(activeThread) then
        print("The terrain will be reloaded in 3 sec.")
        activeThread = CreateRealTimeThread(function()
            Sleep(2800)
            hr.TR_ForceReloadTextures = true
            activeThread = false
        end)
    end
end

--[==[
local step = const.TypeTileSize 
local map = box(0, 0, terrain.GetMapWidth() - 1, terrain.GetMapHeight() - 1)
local typestats = {}

for j = map:miny(), map:maxy(), step do
	for i = map:minx(), map:maxx(), step do
		local type = terrain.GetTerrainType(point(i,j))
		if type then
			typestats[type] = typestats[type] and typestats[type] + 1 or 1
		end
	end
end


print("------------------------------------------------------------")
print("Terrain test:")
for type, texture in sorted_pairs(TerrainTextures) do
	local count = typestats[type] or 0

	print("Texture " .. texture.id .. " used " .. count .. " times.")

end

]==]