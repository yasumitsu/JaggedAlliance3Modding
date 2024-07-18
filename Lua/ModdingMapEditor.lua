if config.ModdingToolsInUserMode then

---
--- Returns the editor view preset prefix.
---
--- This function is used to get the prefix for the editor view preset.
---
--- @return string The editor view preset prefix.
---
function MapDataPreset:GetEditorViewPresetPrefix()
	return ""
end
MapDataPreset.EditorViewPresetPostfix = ""

---
--- Checks if the map data preset is read-only.
---
--- @return boolean True if the map data preset is read-only, false otherwise.
---
function MapDataPreset:IsReadOnly()
	return not self.ModMapPath
end

-- remove unimportant map data properties, make some of them read-only
function OnMsg.ClassesPreprocess()
	local hide = {
		Author = true,
		Status = true,
		ScriptingAuthor = true,
		ScriptingStatus = true,
		SoundsStatus = true,
		
		DisplayName = true,
		Description = true,
		MapType = true,
		GameLogic = true,
		NoTerrain = true,
		DisablePassability = true,
		ModEditor = true,
		
		CameraUseBorderArea = true,
		CameraType = true,
		
		IsPrefabMap = true,
		IsRandomMap = true,
		Terrain = true,
		ZOrder = true,
		OrthoTop = true,
		OrthoBottom = true,
		PassBorder = true,
		PassBorderTiles = true,
		TerrainTreeRows = true,
		
		Playlist = true,
		BlacklistStr = true,
		LockMarkerChanges = true,
		PublishRevision = true,
		CreateRevisionOld = true,
		ForcePackOld = true,
		StartupEnable = true,
		StartupCam = true,
		StartupEditor = true,
		LuaRevision = true,
		OrgLuaRevision = true,
		AssetsRevision = true,
		NetHash = true,
		ObjectsHash = true,
		TerrainHash = true,
		SaveEntityList = true,
		InternalTesting = true,
		
		BiomeGroup = true,
		HeightMin = true, 
		HeightMax = true, 
		WetMin = true,    
		WetMax = true,    
		SeaLevel = true,  
		SeaPreset = true, 
		SeaMinDist = true,
		MapGenSeed = true,
		PersistedPrefabsPreview = true,
	}
	for _, prop in ipairs(MapDataPreset.properties) do
		if hide[prop.id] then
			prop.no_edit = true
		end
	end
end

end