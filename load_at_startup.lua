
RealG = _G
--Platform.developer = true



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


if FirstLoad then
    l_editor_boxes = false
end

function PlaceEditorBoxes(obj, new_selection, old_selection, parent)
    if new_selection[obj] or obj.editor_ignore then return end
    local propagate
    local mesh = old_selection[obj]
    if not mesh then
        local ebox = obj:GetEntityBBox()
        if obj:GetGameFlags(const.gofMirrored) ~= 0 then
            local x1, y1, z1, x2, y2, z2 = ebox:xyzxyz()
            ebox = box(x1, -y2, z1, x2, -y1, z2)
        end
        mesh = Mesh:new()
        mesh:SetShader(ProceduralMeshShaders.default_polyline)
        PlaceBox(ebox, parent and 0xcccccc00 or 0xcccccccc, mesh, true)
        mesh.editor_ignore = true
        mesh:ClearMeshFlags(const.mfWorldSpace)
        obj:Attach(mesh)
        propagate = true
    end
    new_selection[obj] = mesh
    if propagate then
        obj:ForEachAttach(PlaceEditorBoxes, new_selection, old_selection, obj)
    end
end

function UpdateEditorBoxes(selection)
    local new_selection = setmetatable({}, weak_keys_meta)
    local old_selection = l_editor_boxes or empty_table
    l_editor_boxes = new_selection
    for i=1,#(selection or "") do
        PlaceEditorBoxes(selection[i], new_selection, old_selection)
    end
    for obj, mesh in pairs(old_selection or empty_table) do
        if not new_selection[obj] then
           DoneObject(mesh)
        end
    end
end

function OnMsg.EditorSelectionChanged(selection)
    UpdateEditorBoxes(selection)
end

function OnMsg.GameEnterEditor()
    UpdateEditorBoxes(editor.GetSel())
end

function OnMsg.GameExitEditor()
    UpdateEditorBoxes()
end

function OnMsg.ChangeMap()
    UpdateEditorBoxes()
end

function OnMsg.SaveGameStart()
    UpdateEditorBoxes()
end

function LuaModEnv(env)
	return
end