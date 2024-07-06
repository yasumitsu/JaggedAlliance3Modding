listener.Debug = 0

local FlushLogFile = FlushLogFile
local OnMsg = OnMsg

local options
local Log
local FlushLog

local function ModOptions(id)

	if id and id ~= CurrentModId then
		return
	end
	
	options = CurrentModOptions
	Log = CurrentModOptions:GetProperty("Log")
	FlushLog = options:GetProperty("FlushLog")

	ShowConsoleLog(Log)
	
	
	if CurrentModOptions["Cheats"] then
		Platform.cheats = true
	end 
	if not CurrentModOptions["Cheats"] then
		Platform.cheats = false
	end
	if CurrentModOptions["Developer"] then
		Platform.developer = true
	end 
	if not CurrentModOptions["Developer"] then
		Platform.developer = false
	end
	if CurrentModOptions["ModdingMode"] then
		config.ModdingToolsInUserMode = false
	end 
	if not CurrentModOptions["ModdingMode"] then
		config.ModdingToolsInUserMode = true
	end
	if CurrentModOptions["Editor"] then
		Platform.editor = true
	end 
	if not CurrentModOptions["Editor"] then
		Platform.editor = false
	end
end

FlushLogFile()
OnMsg.ModsReloaded = FlushLogFile
OnMsg.LoadGame = FlushLogFile
OnMsg.NewGame = FlushLogFile
OnMsg.ReloadLua = FlushLogFile
OnMsg.ClassesGenerate = FlushLogFile
OnMsg.ClassesPreprocess = FlushLogFile
OnMsg.ClassesPostprocess = FlushLogFile
OnMsg.ClassesBuilt = FlushLogFile

OnMsg.ApplyModOptions = ModOptions
OnMsg.ModsReloaded = ModOptions
OnMsg.DataLoaded = ModOptions

function OnMsg.OnRender()
	if FlushLog then
		FlushLogFile()
	end
end


function OnMsg.DataLoaded()
	ApplyModOptions()
end

-- CHapi's box

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
