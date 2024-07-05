XEditorPasteFuncs = {}

---
--- Clears the current selection and adds all objects of the specified class(es) to the selection.
---
--- @param ... string|string[] The class name(s) to select.
function editor.SelectByClass(...)
	editor.ClearSel()
	editor.AddToSel(MapGet("map", ...) or empty_table)
end

---
--- Toggles the editor mode on and off.
---
--- If the editor is active, it will be deactivated. If the editor is inactive, it will be activated.
--- This function will wait for any ongoing map changes or saves to complete before toggling the editor mode.
---
--- @return nil
function ToggleEnterExitEditor()
	if Platform.editor then
		CreateRealTimeThread(function()
			while IsChangingMap() or IsEditorSaving() do
				WaitChangeMapDone()
				if IsEditorSaving() then
					WaitMsg("SaveMapDone")
				end
			end
			if GetMap() == "" then
				print("There is no map loaded")
				return
			end
			if IsEditorActive() then
				EditorDeactivate()
			else
				EditorActivate()
			end
		end)
	end		
end

---
--- Moves the camera to view the specified game object.
---
--- @param obj CObject The game object to view.
--- @param dist? number The distance from the object to position the camera, in meters.
--- @param selection? boolean If true, the object will be selected in the editor.
---
--- This function sets the camera position and orientation to view the specified game object. If the object is not valid, the function returns without doing anything.
---
--- If `cameraMax` is not active, it is activated. The camera is positioned a certain distance from the object, looking at the object's position. If the `selection` parameter is true, the object is also selected in the editor.
---
function EditorViewMapObject(obj, dist, selection)
	local la = IsValid(obj) and obj:GetVisualPos() or InvalidPos()
	if la == InvalidPos() then
		return
	end
	if not cameraMax.IsActive() then cameraMax.Activate(1) end
	local cur_pos, cur_la = cameraMax.GetPosLookAt()
	if cur_la == cur_pos then
		-- cam not initialized
		cur_pos = cur_la - point(guim, guim, guim)
	end
	la = la:SetTerrainZ()
	local pos = la - SetLen(cur_la - cur_pos, (dist or 40*guim) + obj:GetRadius())
	cameraMax.SetCamera(pos, la, 200, "Sin in/out")
	
	if selection then
		editor.ClearSel()
		editor.AddToSel{obj}
		OpenGedGameObjectEditor(editor.GetSel())
	end
end

local objs
function OnMsg.DoneMap()
	objs = nil
end
---
--- Opens the GedObjectEditor application and binds the specified game objects to it.
---
--- @param reopen_only boolean If true, the editor will only be reopened if it is already active.
---
--- If the GedObjectEditor is not active, it is opened and the specified game objects are bound to it.
--- If the GedObjectEditor is already active, the objects are rebound to it, unless `reopen_only` is true, in which case the editor is not reopened.
--- The selected objects are then selected in the GedObjectEditor.
---
function _OpenGedGameObjectEditorInGame(reopen_only)
	if not GedObjectEditor then
		GedObjectEditor = OpenGedApp("GedObjectEditor", objs, { WarningsUpdateRoot = "root" }) or false
	else
		GedObjectEditor:UnbindObjs("root")
		if not reopen_only then
			GedObjectEditor:Call("rfnApp", "Activate")
		end
		GedObjectEditor:BindObj("root", objs)
	end
	GedObjectEditor:SelectAll("root")
	objs = nil
end

---
--- Opens the GedObjectEditor application and binds the specified game objects to it.
---
--- @param obj table|nil The game object to bind to the GedObjectEditor. If nil, the editor will only be reopened if it is already active.
--- @param reopen_only boolean If true, the editor will only be reopened if it is already active.
---
--- If the GedObjectEditor is not active, it is opened and the specified game object is bound to it.
--- If the GedObjectEditor is already active, the object is rebound to it, unless `reopen_only` is true, in which case the editor is not reopened.
--- The selected object is then selected in the GedObjectEditor.
---
function OpenGedGameObjectEditorInGame(obj, reopen_only)
	if not obj or not GedObjectEditor and reopen_only then return end
	objs = table.create_add_unique(objs, obj)
	DelayedCall(0, _OpenGedGameObjectEditorInGame, reopen_only)
end
	
---
--- Opens the GedObjectEditor application and binds the specified game object to it.
---
--- @param self table The game object to bind to the GedObjectEditor.
---
--- If the GedObjectEditor is not active, it is opened and the specified game object is bound to it.
--- If the GedObjectEditor is already active, the object is rebound to it.
--- The selected object is then selected in the GedObjectEditor.
---
function CObject:AsyncCheatProperties()
	OpenGedGameObjectEditorInGame(self)
end

function OnMsg.SelectedObjChange(obj)
	OpenGedGameObjectEditorInGame(obj, "reopen_only")
end

---
--- Waits for a map object by its handle, changes the map if necessary, and activates the editor to view the object.
---
--- @param handle number The handle of the map object to wait for.
--- @param map string The name of the map to change to if necessary.
--- @param ged table|nil The GedObjectEditor instance to use for asking the user to change the map.
---
--- If the current map is not the specified map, the function will ask the user to change the map if a GedObjectEditor instance is provided. Once the map is changed, the editor is activated and the specified map object is viewed.
---
--- If the map object cannot be found, an error message is printed.
---
function EditorWaitViewMapObjectByHandle(handle, map, ged)
	if GetMapName() ~= map then
		if ged then
			local answer = ged:WaitQuestion("Change map required!", string.format("Change map to %s?", map))
			if answer ~= "ok" then
				return
			end
		end
		CloseMenuDialogs()
		ChangeMap(map)
		StoreLastLoadedMap()
	end
	EditorActivate()
	WaitNextFrame()
	local obj = HandleToObject[handle]
	if not IsValid(obj) then
		print("ERROR: no such object")
		return
	end
	editor.ChangeSelWithUndoRedo({obj})
	EditorViewMapObject(obj)
end

----

if FirstLoad then
	GedSingleObjectPropEditor = false
end

---
--- Opens the GedSingleObjectPropEditor for the specified object. If the editor is already open, it will be reactivated and bound to the new object.
---
--- @param obj table|nil The object to open the editor for. If nil, the function will return without doing anything.
--- @param reopen_only boolean If true, the function will only reopen the editor if it is already open, and not create a new instance.
---
--- If the editor is not already open and `reopen_only` is false, a new instance of the GedSingleObjectPropEditor will be created and bound to the specified object. If the editor is already open, it will be unbound from the previous object and bound to the new object.
---
function OpenGedSingleObjectPropEditor(obj, reopen_only)
	if not obj then return end
	CreateRealTimeThread(function()
		if not GedSingleObjectPropEditor and reopen_only then
			return
		end
		if not GedSingleObjectPropEditor then
			GedSingleObjectPropEditor = OpenGedApp("GedSingleObjectPropEditor", obj) or false
		else
			GedSingleObjectPropEditor:UnbindObjs("root")
			GedSingleObjectPropEditor:Call("rfnApp", "Activate")
			GedSingleObjectPropEditor:BindObj("root", obj)
		end
	end)
end

function OnMsg.GedClosing(ged_id)
	if GedSingleObjectPropEditor and GedSingleObjectPropEditor.ged_id == ged_id then
		GedSingleObjectPropEditor = false
	end
end

----

-- Grounds all selected objects.
-- If *relative* is true, grounds only the lowest one and then sets the rest of them relative to it
---
--- Resets the Z position of all selected objects to the terrain or walkable object below them.
---
--- If *relative* is true, the lowest object is grounded and the rest are set relative to it.
---
--- @param relative boolean If true, the objects will be grounded relative to the lowest one.
---
function editor.ResetZ(relative)
	local sel = editor:GetSel()
	if #sel < 1 then
		return
	end

	
	local min_z_ground = false
	local min_z_air = false
	local min_idx = false

	if relative then
		-- Get the lowest of all objects and where it will be grounded
		for i = 1, #sel do
			local obj = sel[i]
			
			local _, _, pos_z = obj:GetVisualPosXYZ()
			
			if not min_z_air or min_z_air > pos_z then
				min_z_air = pos_z
				min_idx = i
			end
		end

		if min_idx then
			local obj = sel[min_idx]

			local pos = obj:GetVisualPos2D()
			local o, z = GetWalkableObject( pos )
			if o ~= nil and not IsFlagSet( obj:GetEnumFlags(), const.efWalkable ) then
				min_z_ground = z
			else
				min_z_ground = terrain.GetSurfaceHeight(pos)
			end
		end
	end

	SuspendPassEditsForEditOp()
	XEditorUndo:BeginOp{ objects = sel, name = "Snap to terrain" }
	for i = 1, #sel do	
		local obj = sel[i]
		
		obj:ClearGameFlags(const.gofOnRoof)
		
		local pos = obj:GetVisualPos()
		local pos_z = pos:z()
		pos = pos:SetInvalidZ()
		local o, z = GetWalkableObject( pos )

		if o ~= nil and not IsFlagSet( obj:GetEnumFlags(), const.efWalkable ) then
			if relative and min_z_air and min_z_ground then
				pos = point( pos:x(), pos:y(), pos_z - min_z_air + min_z_ground)
			else
				pos = point( pos:x(), pos:y())
			end
		elseif relative and min_z_air and min_z_ground then
			pos = point( pos:x(), pos:y(), pos_z - min_z_air + min_z_ground)
		end

		obj:SetPos( pos )
	end
	local objects = {}
	local cfEditorCallback = const.cfEditorCallback
	for i = 1, #sel do
		if sel[i]:GetClassFlags(cfEditorCallback) ~= 0 then
			objects[#objects + 1] = sel[i]
		end
	end
	if #objects > 0 then
		Msg("EditorCallback", "EditorCallbackMove", objects)
	end
	Msg("EditorResetZ")
	XEditorUndo:EndOp(sel)
	ResumePassEditsForEditOp()
end

-- this method correctly resets anim back to game time, i.e. it resets the anim timestamps so it doesn't have to wait far in the future to start
---
--- Resets the animation of the given object to game time.
---
--- This function ensures that the object's animation timestamps are reset to the current game time, so that the animation can start playing immediately without having to wait for a long time in the future.
---
--- @param object CObject The object whose animation should be reset to game time.
---
function ObjectAnimToGameTime(object)
	object:SetRealtimeAnim(false)
	local e = object:GetEntity()
	if IsValidEntity(e) then
		object:SetAnimSpeed(1, object:GetAnimSpeed(), 0) -- so the obj can set its anim timestamps correctly in game time
	end
end

---
--- Calculates the center point of a set of objects.
---
--- This function takes a table of objects and calculates the center point of their positions. It also finds the minimum Z coordinate among the objects and sets the Z coordinate of the center point to that value if at least one object has a valid Z coordinate.
---
--- @param objs table A table of CObject instances.
--- @return point The center point of the objects.
---
function editor.GetObjectsCenter(objs)
	local min_z
	local b = box()
	for i = 1, #objs do
		local pos = objs[i]:GetPos()
		b = Extend(b, pos)
		if pos:IsValidZ() then
			min_z = Min(min_z or pos:z(), pos:z())
		end
	end
	local center = b:Center()
	center = min_z and center:SetZ(min_z) or center
	return center
end

---
--- Serializes a set of objects into a Lua script that can be used to recreate the objects.
---
--- This function takes a table of objects and generates a Lua script that can be used to recreate those objects in the game editor. The script includes the position, orientation, and other properties of the objects, as well as any collections they belong to.
---
--- @param objs table A table of CObject instances to serialize.
--- @param collections table (optional) A table of collection indices that should be included in the serialization.
--- @param center point (optional) The center point to use for the serialized objects. If not provided, the center point is calculated from the objects.
--- @param options table (optional) A table of options to control the serialization process.
--- @return string The serialized Lua script.
--- @return string|nil An error message if there was a problem serializing the objects.
---
function editor.Serialize(objs, collections, center, options)
	local objs_orig = objs
	center = center or editor.GetObjectsCenter(objs)
	options = options or empty_table
	
	local GetVisualPosXYZ = CObject.GetVisualPosXYZ
	local GetHeight = terrain.GetHeight
	local GetTerrainNormal = terrain.GetTerrainNormal
	local GetOrientation = CObject.GetOrientation
	local IsValidZ = CObject.IsValidZ
	local GetClassFlags = CObject.GetClassFlags
	local GetGameFlags = CObject.GetGameFlags
	local GetCollectionIndex = CObject.GetCollectionIndex
	local IsValidPos = CObject.IsValidPos
	local cfLuaObject = const.cfLuaObject
	local InvalidPos = InvalidPos
	local IsT = IsT
	
	if not collections then
		collections = {}
		for i = 1, #objs do
			local col_idx = GetCollectionIndex(objs[i])
			if col_idx ~= 0 then
				collections[col_idx] = true
			end
		end
	end
	local cols = {}
	for idx in pairs(collections) do
		cols[#cols + 1] = Collections[idx]
	end
	
	local cobjects
	if options.compact_cobjects then
		if objs == objs_orig then objs = table.icopy(objs) end
		for i = #objs,1,-1 do
			local obj = objs[i]
			if GetClassFlags(obj, cfLuaObject) == 0 then
				cobjects = cobjects or {}
				cobjects[#cobjects + 1] = obj
				table.remove(objs, i)
			end
		end
	end
	
	local get_collection_index_func
	local locked_idx = editor.GetLockedCollectionIdx()
	if locked_idx ~= 0 and not options.ignore_locked_coll then
		get_collection_index_func = function(obj)
			local idx = GetCollectionIndex(obj)
			if idx ~= locked_idx then
				return idx
			end
		end
	end
	
	local no_translation = options.no_translation
	local function get_prop(obj, prop_id)
		if prop_id == "CollectionIndex" and get_collection_index_func then
			return get_collection_index_func(obj)
		elseif prop_id == "Pos" then
			return IsValidPos(obj) and (obj:GetPos() - center) or InvalidPos()
		end
		local value = obj:GetProperty(prop_id)
		if no_translation and value ~= "" and IsT(value) then
			StoreErrorSource(obj, "Translation found for property", prop_id)
			return ""
		end
		return value
	end
	
	local code = pstr("", 1024)
	code:append(options.comment_tag or "--[[HGE place script]]--")
	code:append("\nSetObjectsCenter(")
	code:appendv(center)
	code:append(")\n")

	ObjectsToLuaCode(cols, code, get_prop)
	ObjectsToLuaCode(objs, code, get_prop)
	
	local err
	if cobjects then
		local test_encoding = options.test_encoding
		local collection_remap
		if get_collection_index_func then
			collection_remap = {}
			for _, obj in ipairs(cobjects) do
				collection_remap[obj] = get_collection_index_func(obj)
			end
		end
		code:append("\n--[[COBJECTS]]--\n")
		code:append("PlaceCObjects(\"")
		code, err = __DumpObjPropsForSave(code, cobjects, true, center, nil, nil, collection_remap, test_encoding)
		code:append("\")\n")
	end
	if not options.pstr then
		local str = code:str()
		code:free()
		code = str
	end
	return code, err
end

---
--- Deserializes a script string into a list of game objects.
---
--- @param script string The script string to deserialize.
--- @param no_z boolean If true, the deserialized objects will not have their Z-coordinate set.
--- @param forced_center Vector3 The position to use as the center for the deserialized objects.
--- @return table A list of deserialized game objects.
---
function editor.Unserialize(script, no_z, forced_center)
	return LuaCodeToObjs(script, {
		no_z = no_z,
		pos = forced_center or (terminal.desktop.inactive and GetTerrainGamepadCursor() or GetTerrainCursor())
	})
end

---
--- Copies the currently selected objects in the editor to the clipboard as a serialized script.
---
--- This function is called when the user wants to copy the currently selected objects in the editor to the clipboard.
--- It first checks if the editor is active and if there are any objects selected. If so, it gets the selected objects,
--- serializes them using the `editor.Serialize` function, and then copies the serialized script to the clipboard.
---
--- @return nil
---
function editor.CopyToClipboard()
	if IsEditorActive() and #editor.GetSel() > 0 then
		local objs = editor.GetSel()
		local script = editor.Serialize(objs, empty_table)
		CopyToClipboard(script)
	end
end

---
--- Pastes the objects from the clipboard into the editor.
---
--- This function is called when the user wants to paste the objects from the clipboard into the editor.
--- It first checks if the editor is active. If so, it gets the script from the clipboard, deserializes it using the `editor.Unserialize` function, and then adds the deserialized objects to the editor's selection.
--- If any of the pasted objects have an `EditorCallback` class flag, it suspends pass edits for the edit operation and sends an `EditorCallbackPlace` message to the editor.
---
--- @param no_z boolean If true, the pasted objects will not have their Z-coordinate set.
--- @return table The list of pasted objects.
---
function editor.PasteFromClipboard(no_z)
	if not IsEditorActive() then
		return
	end
	
	local script = GetFromClipboard(-1)
	local objs = editor.Unserialize(script, no_z)
	if not objs then
		return
	end
	
	objs = table.ifilter(objs, function (idx, o) return not o:IsKindOf("Collection") end)
	
	XEditorUndo:BeginOp{name = "Pasted objects"}
	XEditorUndo:EndOp(objs)
	
	editor.ClearSel()
	editor.AddToSel(objs)
	
	local objects = {}
	for i = 1,#objs do
		if IsFlagSet(objs[i]:GetClassFlags(), const.cfEditorCallback) then
			objects[#objects + 1] = objs[i]
		end
	end
	if #objects > 0 then
		SuspendPassEditsForEditOp()
		Msg("EditorCallback", "EditorCallbackPlace", objects)
		ResumePassEditsForEditOp()
	end
	return objs
end

---
--- Selects all duplicate objects in the editor.
---
--- This function first gets all the objects in the map, sorts them by their X-coordinate, and then clears the current selection.
--- It then iterates through the sorted objects and checks if there are any other objects with the same position, axis, angle, and class. If so, it adds those objects to the selection.
--- Any duplicate objects found are removed from the list of objects to avoid checking them again.
---
--- @return nil
---
editor.SelectDuplicates = function()
	local l = MapGet("map") or empty_table
	local num = #l
	
	print( num )

	local function cmp_x(o1,o2) return o1:GetPos():x() < o2:GetPos():x() end
	table.sort( l, cmp_x )

	editor.ClearSel()	

	for i = 1,num do
		local pt = l[i]:GetPos()
		local axis = l[i]:GetAxis()
		local angle = l[i]:GetAngle()
		local class = l[i].class

		local function TestDuplicate(idx)
			local obj = l[idx]
			if pt == obj:GetPos() and axis == obj:GetAxis() and angle == obj:GetAngle() and class == obj.class then
				editor.AddToSel({obj})
				return true
			end
			return false
		end

		local j = i + 1
		local x = pt:x()
		while j <= num and x == l[j]:GetPos():x() do
			if TestDuplicate(j) then
				table.remove( l, j )
				num = num-1
			else
				j = j+1
			end
		end
	end
end

local function SetReplacedObjectDefaultFlags(new_obj)
	new_obj:SetGameFlags(const.gofPermanent)
	new_obj:SetEnumFlags(const.efVisible)
	local entity = new_obj:GetEntity()
	local passability_mesh = HasMeshWithCollisionMask(entity, const.cmPassability)
	local entity_collisions = HasAnySurfaces(entity, EntitySurfaces.Collision) or passability_mesh
	local entity_apply_to_grids = HasAnySurfaces(entity, EntitySurfaces.ApplyToGrids) or passability_mesh
	new_obj:SetCollision(entity_collisions)
	new_obj:SetApplyToGrids(entity_apply_to_grids)
end
---
--- Replaces an object in the editor with a new object of the specified class.
---
--- @param obj table The object to be replaced.
--- @param class string The class of the new object to be placed.
--- @return table The new object that was placed.

function editor.ReplaceObject(obj, class)
	if g_Classes[class] and IsValid(obj) then
		XEditorUndo:BeginOp{ objects = {obj}, name = "Replaced 1 objects" }
		Msg("EditorCallback", "EditorCallbackDelete", {obj}, "replace")
		local new_obj = PlaceObject(class)
		new_obj:CopyProperties(obj)
		DoneObject(obj)
		SetReplacedObjectDefaultFlags(new_obj)
		Msg("EditorCallback", "EditorCallbackPlace", {new_obj}, "replace")
		XEditorUndo:EndOp({new_obj})
		return new_obj
	end
	return obj
end

---
--- Replaces a set of objects in the editor with new objects of the specified class.
---
--- @param objs table The objects to be replaced.
--- @param class string The class of the new objects to be placed.
---
function editor.ReplaceObjects(objs, class)
	if g_Classes[class] and #objs > 0 then
		SuspendPassEditsForEditOp()
		PauseInfiniteLoopDetection("ReplaceObjects")
		XEditorUndo:BeginOp{ objects = objs, name = string.format("Replaced %d objects", #objs) }
		Msg("EditorCallback", "EditorCallbackDelete", objs, "replace")
		local ol = {}
		for i = 1 , #objs do
			local new_obj = PlaceObject(class)
			new_obj:CopyProperties(objs[i])
			DoneObject(objs[i])
			SetReplacedObjectDefaultFlags(new_obj)
			ol[#ol + 1] = new_obj
		end
		if ol then
			editor.ClearSel()
			editor.AddToSel(ol)
		end
		Msg("EditorCallback", "EditorCallbackPlace", ol, "replace")
		XEditorUndo:EndOp(ol)
		ResumeInfiniteLoopDetection("ReplaceObjects")
		ResumePassEditsForEditOp()
	else
		print("No such class: " .. class)
	end
end

function OnMsg.EditorCallback(id, objects, ...)	
	if id == "EditorCallbackClone" then
		local old = ...
		for i = 1, #old do
			local object = objects[i]
			if IsValid(object) and object:IsKindOf("EditorCallbackObject") then
				object:EditorCallbackClone(old[i])
			end
		end
	else
		local place = id == "EditorCallbackPlace"
		local clone = id == "EditorCallbackClone"
		local delete = id == "EditorCallbackDelete"
		for i = 1, #objects do
			local object = objects[i]
			if IsValid(object) then
				if (place or clone) and object:IsKindOf("AutoAttachObject") and object:GetForcedLODMin() then
					object:SetAutoAttachMode(object:GetAutoAttachMode())
				end
				if IsKindOf(object, "EditorCallbackObject") then
					object[id](object, ...)
				end
				if place then
					if IsKindOf(object, "EditorObject") then
						object:EditorEnter()
					end
				elseif delete then
					if IsKindOf(object, "EditorObject") then
						object:EditorExit()
					end
				end
			end
		end
	end
end

---
--- Returns the first selected collection from the given objects.
---
--- @param objs table|nil The objects to extract collections from. If nil, uses the current selection.
--- @return Collection|nil The first selected collection, or nil if no collections are selected.
function editor.GetSingleSelectedCollection(objs)
	local collections, remaining = editor.ExtractCollections(objs or editor.GetSel())
	local first = collections and next(collections)
	return #remaining == 0 and first and not next(collections, first) and Collections[first]
end

---
--- Extracts the collections from the given objects.
---
--- @param objs table|nil The objects to extract collections from. If nil, uses the current selection.
--- @return table|nil The collections extracted from the objects, or nil if no collections were found.
--- @return table The remaining objects that are not part of any collection.
function editor.ExtractCollections(objs)
	local collections
	local remaining = {}
	local locked_idx = editor.GetLockedCollectionIdx()
	for _, obj in ipairs(objs or empty_table) do
		local coll_idx = 0
		if obj:IsKindOf("Collection") then
			coll_idx = obj.Index
		else
			coll_idx = obj:GetCollectionIndex()
			if locked_idx ~= 0 then
				local relation = obj:GetCollectionRelation(locked_idx)
				if relation == "child" then -- add just this object
					coll_idx = 0
				elseif relation == "sub" then -- add the whole collection (use GetCollectionRoot)
					coll_idx = Collection.GetRoot(coll_idx)
				end
			else
				if coll_idx ~= 0 then -- try to find root
					coll_idx = Collection.GetRoot(coll_idx)
				end
			end
		end
		
		if coll_idx == 0 then -- add just this object
			remaining[#remaining + 1] = obj
		else -- add the whole collection
			collections = collections or {}
			collections[coll_idx] = true
		end
	end
	return collections, remaining
end

---
--- Propagates the current selection to include any collections and connected stair slabs.
---
--- @param objs table|nil The objects to propagate the selection from. If nil, uses the current selection.
--- @return table The propagated selection.
function editor.SelectionPropagate(objs)
	local collections, selection = nil, objs or {}
	if XEditorSelectSingleObjects == 0 then
		collections, selection = editor.ExtractCollections(objs)
	end
	for coll_idx, _ in sorted_pairs(collections or empty_table) do
		table.iappend(selection, MapGet("map", "collection", coll_idx, true))
	end
	
	if const.SlabSizeX then
		if terminal.IsKeyPressed(const.vkControl) then
			local visited = {}
			for _, obj in ipairs(objs) do
				if IsKindOf(obj, "StairSlab") and not visited[obj] then
					local gx, gy, gz = obj:GetGridCoords()
					table.iappend(selection, EnumConnectedStairSlabs(gx, gy, gz, 0, visited))
				end
			end
		end
	end
	
	return selection
end

MapVar("EditorCursorObjs", {}, weak_keys_meta)
PersistableGlobals.EditorCursorObjs = nil

---
--- Gets the placement point for an object, taking into account collisions with other objects.
---
--- @param pt Vector3 The initial placement point.
--- @return Vector3 The final placement point, adjusted for collisions.
function editor.GetPlacementPoint(pt)
	local eye = camera.GetEye()
	local target = pt:SetTerrainZ()
	
	local objs = IntersectSegmentWithObjects(eye, target, const.efBuilding | const.efVisible)
	local pos, dist
	if objs then
		for _, obj in ipairs(objs) do
			if not EditorCursorObjs[obj] and obj:GetGameFlags(const.gofSolidShadow) == 0 then
				local hit = obj:IntersectSegment(eye, target)
				if hit then
					local d = eye:Dist(hit)
					if not dist or d < dist then
						pos, dist = hit, d
					end
				end
			end
		end
	end
	return pos or pt:SetInvalidZ()
end

---
--- Cycles the detail class of the selected objects in the editor.
---
--- This function is used to toggle the detail class of the selected objects in the editor between "Eye Candy", "Optional", and "Essential".
---
--- @param sel table The selected objects in the editor.
function editor.CycleDetailClass()
	local sel = editor:GetSel()
	if #sel < 1 then
		return
	end

	XEditorUndo:BeginOp{ objects = sel, name = "Toggle Detail Class" }
	local seldc = {}
	for _, obj in ipairs(sel) do
		local dc = obj:GetDetailClass()
		seldc[dc] = seldc[dc] or 0
		seldc[dc] = seldc[dc] + 1
	end
	
	local next_dc = "Eye Candy"
	if seldc["Eye Candy"] then 
		next_dc = "Optional" 
	elseif seldc["Optional"] then 
		next_dc = "Essential" 
	end
	
	for _, obj in ipairs(sel) do
		obj:SetDetailClass(next_dc)
	end

	XEditorUndo:EndOp(sel)
end

---
--- Forces the detail class of the selected objects in the editor to "Eye Candy".
---
--- This function is used to set the detail class of the selected objects in the editor to "Eye Candy". It suspends pass edits for the edit operation, clears the collision and apply to grids flags, and sets the detail class to "Eye Candy" for each selected object. The edit operation is then ended and the pass edits are resumed.
---
--- @param sel table The selected objects in the editor.
function editor.ForceEyeCandy()
	local sel = editor:GetSel()
	if #sel < 1 then
		return
	end

	XEditorUndo:BeginOp{ objects = sel, name = "Force Eye Candy" }
	SuspendPassEditsForEditOp(sel)
	for _, obj in ipairs(sel) do
		obj:ClearEnumFlags(const.efCollision + const.efApplyToGrids)
		obj:SetDetailClass("Eye Candy")
	end

	ResumePassEditsForEditOp(sel)
	XEditorUndo:EndOp(sel)
end


----- Modding editor
--
-- The Mod Editor starts the map editor in this mode when a user is editing a map.
--
-- The Mod Item that contains the map (or map patch) is stored in editor.ModItem;
-- for ModItemMapPatch Ctrl-S generates a patch via XEditorCreateMapPatch.
-- This mode also disables some shortcuts, e.g. closing the editor.

if FirstLoad then
	editor.ModdingEditor = false
end	

---
--- Checks if the editor is in modding mode.
---
--- @return boolean True if the editor is in modding mode, false otherwise.
function editor.IsModdingEditor()
	return editor.ModdingEditor
end

---
--- Asks the user to save changes to the map if there are any unsaved changes and the editor is in modding mode.
---
--- This function checks if the editor is in modding mode, if there is a mod item, and if the editor map is dirty (has unsaved changes). If all these conditions are met, it displays a dialog asking the user if they want to save the changes before proceeding. If the user chooses to save, the map is saved via the mod item's SaveMap() method. Finally, the EditorMapDirty flag is set to false.
---
--- @return nil
function editor.AskSavingChanges()
	if editor.ModdingEditor and editor.ModItem and EditorMapDirty then
		if GedAskEverywhere("Warning", "There are unsaved changes on the map.\n\nSave before proceeding?", "Yes", "No") == "ok" then
			editor.ModItem:SaveMap()
		end
		SetEditorMapDirty(false)
	end
end

-- When changing the map via F5, ask the user for saving changes;
-- (in case the map is changed via editor.StartModdingEditor, we call editor.AskSavingChanges before updating editor.ModItem)
function OnMsg.ChangingMap(map, mapdata, handler_fns)
	table.insert(handler_fns, editor.AskSavingChanges)
end

---
--- Starts the modding editor for the specified mod item and map.
---
--- This function performs the following steps:
--- 1. Asks the user to save any unsaved changes to the map if the editor is in modding mode.
--- 2. Sets the `editor.ModdingEditor` flag to `true`.
--- 3. Stores the `mod_item` and `map` parameters in the `editor.ModItem` and `editor.ModItemMap` variables, respectively.
--- 4. Reloads the editor shortcuts and updates the mod editor's property panels.
--- 5. If the `editor.PreviousModItem` or the `CurrentMap` is different from the provided `mod_item` and `map`, it changes the map to the specified `map`.
--- 6. If the editor is not active, it activates the editor.
---
--- @param mod_item table The mod item to be edited.
--- @param map string The map to be edited.
--- @return nil
function editor.StartModdingEditor(mod_item, map)
	if ChangingMap then return end
	
	editor.AskSavingChanges()
	
	editor.ModdingEditor = true
	editor.ModItem = mod_item
	editor.ModItemMap = map
	
	ReloadShortcuts()
	UpdateModEditorsPropPanels() -- update buttons in Mod Item properties, e.g. "Edit Map"
	
	if editor.PreviousModItem ~= mod_item or CurrentMap ~= map then
		editor.PreviousModItem = mod_item
		ChangeMap(map)
	end
	
	if not IsEditorActive() then
		EditorActivate()
	end
end

---
--- Stops the modding editor and performs the necessary cleanup.
---
--- This function performs the following steps:
--- 1. If the map is currently being changed, or the modding editor is not active, it returns without doing anything.
--- 2. If the `return_to_mod_map` parameter is true and the current map is not the ModEditorMapName, it changes the map back to the ModEditorMapName.
--- 3. Sets the `editor.ModdingEditor` flag to `false`, and clears the `editor.ModItem` and `editor.ModItemMap` variables.
--- 4. Reloads the editor shortcuts and updates the mod editor's property panels.
--- 5. If the editor is active, it deactivates the editor.
---
--- @param return_to_mod_map boolean If true, the function will change the map back to the ModEditorMapName before stopping the modding editor.
--- @return nil
function editor.StopModdingEditor(return_to_mod_map)
	if ChangingMap or not editor.ModdingEditor then return end
	
	CreateRealTimeThread(function()
		-- change map first, so the OnMsg.ChangingMap asks for saving changes
		if return_to_mod_map and CurrentMap ~= ModEditorMapName then
			editor.PreviousModItem = false
			ChangeMap(ModEditorMapName)
		end
		
		editor.ModdingEditor = false
		editor.ModItem = nil
		editor.ModItemMap = nil
		
		ReloadShortcuts()
		UpdateModEditorsPropPanels() -- update buttons in Mod Item properties, e.g. "Edit Map"
		
		if IsEditorActive() then
			EditorDeactivate()
		end
	end)
end

function OnMsg.GedClosing(ged_id)
	local conn = GedConnections[ged_id]
	if conn and conn.app_template == "ModEditor" then
		if editor.ModdingEditor and editor.ModItem and conn.bound_objects.root[1] == editor.ModItem.mod then
			editor.StopModdingEditor("return to mod map") -- close map editor if the mod editor for its edited map is closed
		end
	end
end

-- the user may change the map to another one; if it is a mod-created map, find its mod item
function OnMsg.ChangeMap(map)
	if editor.ModdingEditor and editor.ModItemMap ~= map then
		editor.ModItemMap = nil
		editor.ModItem = nil
		for _, mod in ipairs(ModsLoaded) do
			mod:ForEachModItem(function(mod_item)
				if mod_item:GetMapName() == map then
					editor.ModItem = mod_item
					return "break"
				end
			end)
		end
		UpdateModEditorsPropPanels() -- update buttons in Mod Item properties, e.g. "Edit Map"
	end
end
