-- don't think it's working

if config.ModdingToolsInUserMode then

function MapDataPreset:GetEditorViewPresetPrefix()
	return ""
end
MapDataPreset.EditorViewPresetPostfix = ""

-- Unlocking the Options inside Map Data
function MapDataPreset:IsReadOnly()
	return
end

-- Unlocking the Options inside Presets
function Preset:IsReadOnly()
	return
end

--[[ This will open the Mod Manager inside the Main Menu after Gamestart.
OnMsg.PreGameMenuOpen = ModEditorOpen()
]]

-- remove unimportant map data properties, make some of them read-only
-- true = Hide / false = Show

-- don't really know if all this is unimportant, Anton said that some of this might be mandatory, so I am not running this

function ChangeMapData()
--function OnMsg.ClassesPreprocess()
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