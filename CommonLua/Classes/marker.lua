DefineClass.Marker = {
	__parents = { "InitDone" },

	properties = {
		{ id = "name", name = "Name", editor = "text", read_only = true, default = false, },
		{ id = "type", editor = "text", default = "", read_only = true },
		{ id = "map", editor = "text", default = "", read_only = true },
		{ id = "handle", editor = "number", default = 0, read_only = true, buttons = {{name = "Teleport", func = "ViewMarker"}}},
		{ id = "pos", editor = "point", default = point(-1,-1)},
		{ id = "display_name", editor = "text", default = "", translate = true },
		{ id = "data", editor = "text", default = "", read_only = true },
		{ id = "data_version", editor = "text", default = "", read_only = true },
	},
	StoreAsTable = false,
}

if FirstLoad or ReloadForDlc then
	Markers = {}
end

---
--- Registers a marker object with the global `Markers` table.
---
--- If a marker with the same name already exists, it will be overwritten and a warning will be printed.
---
--- @param self Marker The marker object to register.
---
function Marker:Register()
	local name = self.name
	if not name then 
		return
	end
	local old = Markers[name]
	if old then
		if old == self then
			return
		end
		print("Duplicated marker:", name, "\n\t1.", self.map, "at", self.pos, "\n\t2.", old.map, "at", old.pos)
		old:delete()
	end

	table.insert(Markers, self)
	Markers[name] = self
end

---
--- Constructs a new `Marker` object from a Lua table.
---
--- This function is used to deserialize a `Marker` object from a Lua table, typically when loading data from a file or database.
---
--- @param self The `Marker` class or object.
--- @param table A Lua table containing the properties to initialize the `Marker` object with.
--- @return The newly constructed `Marker` object.
---
function Marker:__fromluacode(table)
	local obj = Container.__fromluacode(self, table)
	obj:Register()
	return obj
end

function OnMsg.PostLoad()
	table.sort(Markers, function(m1,m2) return CmpLower(m1.name, m2.name) end)
end

---
--- Gets the editor view of the marker.
---
--- @return string The name of the marker.
---
function Marker:GetEditorView()
	return self.name
end

---
--- Initializes a new `Marker` object and registers it with the `Markers` table.
---
--- This function is called when a new `Marker` object is created. It registers the marker with the global `Markers` table, ensuring that it can be accessed and managed by other parts of the application.
---
--- @param self Marker The `Marker` object being initialized.
---
function Marker:Init()
	self:Register()
end

---
--- Removes the `Marker` object from the global `Markers` table and removes its reference by name.
---
--- This function is called when a `Marker` object is no longer needed and should be removed from the application's state.
---
--- @param self Marker The `Marker` object being removed.
---
function Marker:Done()
	table.remove_value(Markers, self)
	Markers[self.name] = nil
end

---
--- Opens the GedMarkerViewer application with the current list of Markers.
---
--- This function is used to display the GedMarkerViewer UI, which allows the user to view and interact with the current set of map markers.
---
--- @function OpenMarkerViewer
--- @return nil
function OpenMarkerViewer()
	OpenGedApp("GedMarkerViewer", Markers)
end

---
--- Deletes all map markers from the current map and any other maps that are no longer loaded.
---
--- This function is used to remove all map markers from the game world. It first checks if marker changes are locked, and if so, it prints a message and returns. Otherwise, it iterates through the list of all loaded maps and the list of all markers, and deletes any markers that are associated with the current map or a map that is no longer loaded.
---
--- After deleting the markers, it calls `ObjModified(Markers)` to notify the game that the list of markers has been modified.
---
--- @function DeleteMapMarkers
--- @return nil
function DeleteMapMarkers()
	if mapdata.LockMarkerChanges then
		print("Marker changes locked!")
		return
	end
	local maps = {}
	local maps_list = ListMaps()
	for i=1,#maps_list do
		maps[maps_list[i]] = true
	end
	local map = GetMapName()

	for i = #Markers, 1, -1 do
		local marker = Markers[i]
		if marker.map == map or not maps[marker.map] then
			marker:delete()
		end
	end
	ObjModified(Markers)
end

---
--- Rebuilds the map markers for the current map.
---
--- This function is called when the map data is saved, and it is responsible for rebuilding the list of map markers for the current map. It first deletes all existing map markers, then iterates through all `MapMarkerObj` objects in the current map and creates a new `Marker` object for each one. The new `Marker` objects are then sorted by name and stored in the `Markers` table. Finally, the function updates the `mapdata.markers` table with the new list of markers for the current map, and sends a `MarkersChanged` message to notify other parts of the application that the markers have been updated.
---
--- @function RebuildMapMarkers
--- @return nil
function RebuildMapMarkers()
	local t = GetPreciseTicks()
	Msg("MarkersRebuildStart")
	DeleteMapMarkers()
	local count = MapForEach("map", "MapMarkerObj", nil, nil, const.gofPermanent, function(obj)
		obj:CreateMarker()
	end)
	Msg("MarkersRebuildEnd")
	table.sort(Markers, function(m1,m2) return CmpLower(m1.name, m2.name) end)
	ObjModified(Markers)
	if mapdata.LockMarkerChanges then
		print("Marker changes locked!")
		return
	end

	local map_name = GetMapName()
	local markers = {}
	for _, marker in ipairs(Markers) do
		if marker.map == map_name then
			table.insert(markers, marker)
		end
	end
	mapdata.markers = markers
	Msg("MarkersChanged")
	DebugPrint(string.format("%d map markers rebuilt in %d ms\n", count, GetPreciseTicks() - t))
end

OnMsg.SaveMap = RebuildMapMarkers

DefineClass.MarkerBase = {
	__parents = { "Object", "EditorObject", "EditorCallbackObject" },
	flags = { efMarker = true },
}

DefineClass.MapMarkerObj = {
	__parents = { "MarkerBase", "MinimapObject", "EditorTextObject" },
	properties = {
		{ id = "MarkerName", category = "Gameplay", editor = "text", default = "", important = true, },
		{ id = "MarkerDisplayName", category = "Gameplay", editor = "text", default = "", translate = true, important = true },
	},
	marker_type = "",
	marker_name = false,
	editor_text_member = "MarkerName",
}

---
--- Sets the marker name and updates the marker_name property based on the map name and marker name.
---
--- @param value string The new marker name to set.
---
function MapMarkerObj:SetMarkerName(value)
	self.MarkerName = value
	self.marker_name = value ~= "" and GetMapName() .. " - " .. value or value
end

---
--- Determines whether the marker should be visible on the minimap.
---
--- @return boolean true if the marker name is not empty, false otherwise
---
function MapMarkerObj:VisibleOnMinimap()
	return self.MarkerName ~= ""
end

---
--- Resets the minimap_rollover property to the default value.
---
function MapMarkerObj:SetMinimapRollover()
	self.minimap_rollover = nil -- resetting to the default value
end

if Platform.developer then

---
--- Creates a new map marker object.
---
--- @param self MapMarkerObj The MapMarkerObj instance.
--- @return Marker|nil The created marker object, or nil if marker changes are locked.
---
function MapMarkerObj:CreateMarker()
	if mapdata.LockMarkerChanges then
		print("Marker changes locked!")
		return
	end
	local marker_name = self.marker_name
	if (marker_name or "") == "" then return end
	return Marker:new{
		name = marker_name,
		type = self.marker_type,
		map = GetMapName(),
		handle = self.handle,
		pos = self:GetVisualPos(),
		display_name = self.MarkerDisplayName,
	}
end

end -- Platform.developer

---
--- Displays the specified map marker in the editor view.
---
--- @param root EditorObject The root editor object.
--- @param marker Marker The map marker to display.
--- @param prop_id string The property ID of the marker.
--- @param ged EditorObject The GED (Game Editor) object.
---
function ViewMarker(root, marker, prop_id, ged)
	local map = marker.map
	local handle = marker.handle
	EditorWaitViewMapObjectByHandle(marker.handle, marker.map, ged)
end

---
--- Displays the specified map marker in the editor view.
---
--- @param editor_obj EditorObject The root editor object.
--- @param obj Marker The map marker to display.
--- @param prop_id string The property ID of the marker.
---
function ViewMarkerProp(editor_obj, obj, prop_id)
	local name = obj[prop_id]
	local marker = Markers[name]
	if marker then
		ViewMarker(editor_obj, marker)
	end
end

DefineClass.PosMarkerObj = { 
	__parents = { "MapMarkerObj", "EditorVisibleObject", "StripCObjectProperties" },
	entity = "WayPoint",
	marker_type = "pos",
	flags = { efCollision = false, efApplyToGrids = false, },
}

----

DefineClass.EditorMarker = {
	__parents = { "MarkerBase", "EditorVisibleObject", "EditorTextObject", "EditorColorObject", },
	
	properties = {
		{ id = "DetailClass", name = "Detail Class", editor = "dropdownlist", default = "Default",
			items = {{text = "Default", value = 0}}, no_edit = true
		},
	},
	
	flags = { efWalkable = false, efCollision = false, efApplyToGrids = false },
	entity = "WayPoint",
	editor_text_offset = point(0, 0, 13*guim),
}

----

DefineClass.RadiusMarker = {
	__parents = { "EditorMarker", "EditorSelectedObject" },
	editor_text_color = RGB(50, 50, 100),
	editor_color = RGB(150, 150, 0),
	radius_mesh = false,
	radius_prop = false,
	show_radius_on_select = false,
}

---
--- Handles the editor selection state for a RadiusMarker object.
---
--- When the RadiusMarker is selected in the editor, this function will show the radius mesh if the `show_radius_on_select` flag is set. When the RadiusMarker is deselected, this function will hide the radius mesh.
---
--- @param selected boolean Whether the RadiusMarker is currently selected in the editor.
---
function RadiusMarker:EditorSelect(selected)
	if self.show_radius_on_select then
		self:ShowRadius(selected)
	end
end

---
--- Returns the mesh radius for the RadiusMarker object.
---
--- The mesh radius is determined by the value of the `radius_prop` property. If `radius_prop` is set, the value of the corresponding property on the RadiusMarker object is returned. Otherwise, this function returns `nil`.
---
--- @return number|nil The mesh radius for the RadiusMarker object, or `nil` if the `radius_prop` property is not set.
---
function RadiusMarker:GetMeshRadius()
	return self.radius_prop and self[self.radius_prop]
end

---
--- Returns the editor color for the RadiusMarker object.
---
--- @return table The editor color for the RadiusMarker object.
---
function RadiusMarker:GetMeshColor()
	return self.editor_color
end

---
--- Updates the mesh radius for the RadiusMarker object.
---
--- If the `radius_mesh` property is valid, this function will update the scale of the mesh based on the provided `radius` value. If `radius` is not provided, it will use the value returned by the `GetMeshRadius()` function, or a default value of `guim` if that is also `nil`.
---
--- The scale of the mesh is calculated by first scaling the `radius` value by the object's scale, and then dividing by 10 * `guim` to get the appropriate mesh size.
---
--- @param radius number|nil The new radius value for the mesh. If `nil`, the value from `GetMeshRadius()` will be used.
---
function RadiusMarker:UpdateMeshRadius(radius)
	if IsValid(self.radius_mesh) then
		local scale = self:GetScale()
		radius = radius or self:GetMeshRadius() or guim
		radius = MulDivRound(radius, 100, scale)
		self.radius_mesh:SetScale(MulDivRound(radius, 100, 10*guim))
	end
end

---
--- Shows or hides the radius mesh for the RadiusMarker object.
---
--- If the `show_radius_on_select` flag is set, this function will show the radius mesh when the RadiusMarker is selected in the editor, and hide it when the RadiusMarker is deselected.
---
--- @param show boolean Whether to show or hide the radius mesh.
---
function RadiusMarker:ShowRadius(show)
	local radius = show and self:GetMeshRadius()
	if not radius then
		DoneObject(self.radius_mesh)
		self.radius_mesh = nil
		return
	end
	if not IsValid(self.radius_mesh) then
		local radius_mesh = CreateCircleMesh(10*guim, self:GetMeshColor(), point30)
		self.radius_mesh = radius_mesh
		self:Attach(radius_mesh)
	end
	self:UpdateMeshRadius(radius)
end

---
--- Called when the RadiusMarker is entered in the editor.
---
--- If the `show_radius_on_select` flag is set, this function will show the radius mesh when the RadiusMarker is selected in the editor. If the RadiusMarker is not selected, the radius mesh will be hidden.
---
--- @param ... any Additional arguments passed to the function.
---
function RadiusMarker:EditorEnter(...)
	if not self.show_radius_on_select or editor.IsSelected(self)  then
		self:ShowRadius(true)
	end
end

---
--- Called when the RadiusMarker is exited in the editor.
---
--- If the `show_radius_on_select` flag is set, this function will hide the radius mesh when the RadiusMarker is deselected in the editor.
---
--- @param ... any Additional arguments passed to the function.
---
function RadiusMarker:EditorExit(...)
	self:ShowRadius(false)
end

---
--- Called when a property of the RadiusMarker is set in the editor.
---
--- If the property being set is the radius property, this function will update the mesh radius of the RadiusMarker.
---
--- @param prop_id string The ID of the property being set.
--- @param old_value any The previous value of the property.
--- @param ged any Additional arguments passed to the function.
---
function RadiusMarker:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == self.radius_prop then
		self:UpdateMeshRadius()
	end
	EditorMarker.OnEditorSetProperty(self, prop_id, old_value, ged)
end

----

DefineClass.EnumMarker = {
	__parents = { "RadiusMarker", "EditorTextObject" },
	properties = {
		{ category = "Enum", id = "EnumClass",      name = "Class",      editor = "text",       default = false, help = "Accept children from the given class only" },
		{ category = "Enum", id = "EnumCollection", name = "Collection", editor = "bool",       default = false, help = "Use the marker's collection to filter children" },
		{ category = "Enum", id = "EnumRadius",     name = "Radius",     editor = "number",     default = 64*guim, scale = "m", min = 0, max = function(self) return self.EnumRadiusMax end, slider = true, help = "Max children distance" },
		{ category = "Enum", id = "EnumInfo",       name = "Objects",    editor = "prop_table", default = false, read_only = true, dont_save = true, lines = 3, indent = "" },
	},
	editor_text_color = white,
	editor_color = white,
	radius_prop = "EnumRadius",
	children_highlight = false,
	EnumRadiusMax = 64*guim,
}

---
--- Returns a table that maps the class names of the objects within the enum radius to the count of each class.
---
--- @return table A table that maps class names to the count of each class.
---
function EnumMarker:GetEnumInfo()
	local class_to_count = {}
	for _, obj in ipairs(self:GatherObjects()) do
		if IsValid(obj) then
			class_to_count[obj.class] = (class_to_count[obj.class]or 0) + 1
		end
	end
	return class_to_count
end

---
--- Highlights the objects within the enum radius of the EnumMarker.
---
--- If `enable` is `true`, the function will highlight the objects within the enum radius by setting a color modifier on them.
--- If `enable` is `false`, the function will remove the color modifier from the previously highlighted objects.
---
--- @param enable boolean Whether to enable or disable the highlighting of the objects.
--- @return table The previously highlighted objects.
---
function EnumMarker:HightlightObjects(enable)
	local prev_highlight = self.children_highlight
	if not enable and not prev_highlight then
		return
	end
	for _, obj in ipairs(prev_highlight) do
		if IsValid(obj) then
			ClearColorModifierReason(obj, "EnumMarker")
		end
	end
	self.children_highlight = enable and self:GatherObjects() or nil
	for _, obj in ipairs(self.children_highlight) do
		SetColorModifierReason(obj, "EnumMarker", white)
	end
	return prev_highlight
end

---
--- Selects the EnumMarker and highlights the objects within its enum radius.
---
--- If `selected` is `true`, the function will highlight the objects within the enum radius by setting a color modifier on them.
--- If `selected` is `false`, the function will remove the color modifier from the previously highlighted objects.
---
--- @param selected boolean Whether to enable or disable the highlighting of the objects.
--- @return boolean The result of calling the `RadiusMarker.EditorSelect` function.
---
function EnumMarker:EditorSelect(selected)
	if IsValid(self) then
		self:HightlightObjects(selected)
	end
	return RadiusMarker.EditorSelect(self, selected)
end

---
--- Gathers the objects within the specified radius of the EnumMarker.
---
--- If `radius` is not provided, the function will use the `EnumRadius` property of the EnumMarker.
--- If `self.EnumCollection` is falsy, the function will return the objects attached to the EnumMarker within the specified radius.
--- If `self.EnumCollection` is truthy and `collection` is 0, the function will return the objects attached to the EnumMarker and marked as "collected" within the specified radius.
--- If `self.EnumCollection` is truthy and `collection` is not 0, the function will return the objects attached to the EnumMarker and belonging to the specified collection within the specified radius.
---
--- @param radius number The radius to gather objects within.
--- @return table The objects gathered within the specified radius.
---
function EnumMarker:GatherObjects(radius)
	radius = radius or self.EnumRadius
	local collection = self:GetCollectionIndex()
	if not self.EnumCollection then
		return MapGet(self, radius, "attached", false, self.EnumClass or nil)
	elseif collection == 0 then
		return MapGet(self, radius, "attached", false, "collected", false, self.EnumClass or nil)
	else
		return MapGet(self, radius, "attached", false, "collection", collection, self.EnumClass or nil)
	end
end

---
--- Checks if the collection objects are all inside the enum radius.
---
--- If the `EnumRadius` property is not equal to the `EnumRadiusMax` property, this function will gather the objects within the `EnumRadius` and the `EnumRadiusMax`, and check if the number of objects is the same. If the number of objects is different, it will return an error message.
---
--- @return string|nil An error message if the collection objects are not all inside the enum radius, or `nil` if they are.
---
function EnumMarker:GetError()
	if self.EnumRadius ~= self.EnumRadiusMax then
		local t1 = self:GatherObjects() or ""
		local t2 = self:GatherObjects(self.EnumRadiusMax) or ""
		if #t1 ~= #t2 then
			return "Not all collection objects are inside the enum radius!"
		end
	end
end

---
--- Updates all EnumMarker objects in the map.
---
--- This function iterates through all EnumMarker objects in the map and calls their `GatherObjects()` method.
--- The time taken to update all the markers is printed to the debug log.
---
--- @return nil
---
function EnumMarker.UpdateAll()
	local st = GetPreciseTicks()
	MapForEach("map", "EnumMarker", function(obj) obj:GatherObjects() end)
	DebugPrint("Container markers updated in", GetPreciseTicks() - st, "ms")
end
OnMsg.PreSaveMap = EnumMarker.UpdateAll

----

MapVar("ForcedImpassableMarkers", false)

DefineClass.ForcedImpassableMarker = {
	__parents = { "EditorMarker", "EditorSelectedObject", "EditorCallbackObject" },
	properties = {
		{ category = "Area", id = "SizeX", editor = "number", default = 0, scale = "m", min = 0 },
		{ category = "Area", id = "SizeY", editor = "number", default = 0, scale = "m", min = 0 },
		{ category = "Area", id = "SizeZ", editor = "number", default = 0, scale = "m", min = 0 },
	},
	editor_color = RGB(255, 0, 0),
	editor_text_color = white,
	mesh_obj = false,
	area = false,
}

---
--- Initializes a ForcedImpassableMarker object.
---
--- This function is called when a ForcedImpassableMarker object is created. It sets the color modifier of the object and adds it to the global ForcedImpassableMarkers table.
---
--- @param self ForcedImpassableMarker The ForcedImpassableMarker object being initialized.
--- @return nil
---
function ForcedImpassableMarker:Init()
	if not ForcedImpassableMarkers then
		ForcedImpassableMarkers = {}
	end
	self:SetColorModifier(self.editor_color)
	table.insert(ForcedImpassableMarkers, self)
end

---
--- Returns the class name of the ForcedImpassableMarker object.
---
--- @param self ForcedImpassableMarker The ForcedImpassableMarker object.
--- @return string The class name of the ForcedImpassableMarker object.
---
function ForcedImpassableMarker:EditorGetText()
	return self.class
end

---
--- Removes the ForcedImpassableMarker object from the global ForcedImpassableMarkers table and rebuilds the grid in the area covered by the marker.
---
--- @param self ForcedImpassableMarker The ForcedImpassableMarker object being removed.
--- @return nil
---
function ForcedImpassableMarker:Done()
	table.remove_value(ForcedImpassableMarkers, self)
	if self.area then
		RebuildGrids(self.area)
	end
end

---
--- Returns the area covered by the ForcedImpassableMarker object.
---
--- If the area has not been calculated yet, this function calculates the area based on the position and size properties of the marker. The area is stored in the `area` field of the marker object.
---
--- @param self ForcedImpassableMarker The ForcedImpassableMarker object.
--- @return box The area covered by the ForcedImpassableMarker object.
---
function ForcedImpassableMarker:GetArea()
	if not self.area then
		if self:IsValidPos() then
			local posx, posy, posz = self:GetVisualPosXYZ()
			local sizex, sizey, sizez = self.SizeX, self.SizeY, self.SizeZ
			if sizez > 0 then
				-- clear terrain and slab passability inside the box
				self.area = box(
					posx - sizex/2,
					posy - sizey/2,
					posz - sizez/2,
					posx + sizex/2 + 1,
					posy + sizey/2 + 1,
					posz + sizez/2 + 1)
			else
				-- clear terrain only passability inside the 2D box
				self.area = box(
					posx - sizex/2,
					posy - sizey/2,
					posx + sizex/2 + 1,
					posy + sizey/2 + 1)
			end
		else
			self.area = box()
		end
	end
	return self.area
end

function OnMsg.OnPassabilityRebuilding(clip)
	for i, marker in ipairs(ForcedImpassableMarkers) do
		local bx = marker:GetArea()
		if clip:Intersect2D(bx) ~= const.irOutside then
			terrain.ClearPassabilityBox(bx)
		end
	end
end

---
--- Shows or hides a visual representation of the area covered by the ForcedImpassableMarker object.
---
--- If `show` is true, a box mesh is created and attached to the marker object, representing the area covered by the marker. If `show` is false, the box mesh is removed.
---
--- @param self ForcedImpassableMarker The ForcedImpassableMarker object.
--- @param show boolean Whether to show or hide the visual representation of the marker's area.
---
function ForcedImpassableMarker:ShowArea(show)
	DoneObject(self.mesh_obj)
	self.mesh_obj = nil
	if show then
		self.mesh_obj = PlaceBox(self:GetArea(), self.editor_color, false, "depth test")
		self:Attach(self.mesh_obj)
	end
end

---
--- Shows or hides a visual representation of the area covered by the ForcedImpassableMarker object.
---
--- This function is called when the ForcedImpassableMarker is selected or deselected in the editor.
---
--- @param self ForcedImpassableMarker The ForcedImpassableMarker object.
--- @param selected boolean Whether the marker is selected or not.
---
function ForcedImpassableMarker:EditorSelect(selected)
	self:ShowArea(selected)
end

---
--- Rebuilds the area covered by the ForcedImpassableMarker object.
---
--- This function is called when the marker is placed, moved, or a property is changed in the editor.
---
--- It suspends passability edits, rebuilds the grid for the marker's area, and resumes passability edits. If the marker has a visual representation (mesh_obj), it is shown.
---
--- @param self ForcedImpassableMarker The ForcedImpassableMarker object.
---
function ForcedImpassableMarker:RebuildArea()
	SuspendPassEdits("ForcedImpassableMarker")
	if self.area then
		RebuildGrids(self.area)
		self.area = false
	end
	RebuildGrids(self:GetArea())
	ResumePassEdits("ForcedImpassableMarker")
	if self.mesh_obj then
		self:ShowArea(true)
	end
end

---
--- Called when the ForcedImpassableMarker is placed in the editor.
---
--- This function rebuilds the area covered by the marker, suspending and resuming passability edits as needed. If the marker has a visual representation (mesh_obj), it is shown.
---
--- @param self ForcedImpassableMarker The ForcedImpassableMarker object.
---
function ForcedImpassableMarker:EditorCallbackPlace()
	self:RebuildArea()
end

---
--- Called when the ForcedImpassableMarker is moved in the editor.
---
--- This function rebuilds the area covered by the marker, suspending and resuming passability edits as needed. If the marker has a visual representation (mesh_obj), it is shown.
---
--- @param self ForcedImpassableMarker The ForcedImpassableMarker object.
---
function ForcedImpassableMarker:EditorCallbackMove()
	self:RebuildArea()
end

---
--- Called when a property of the ForcedImpassableMarker is changed in the editor.
---
--- This function rebuilds the area covered by the marker, suspending and resuming passability edits as needed. If the marker has a visual representation (mesh_obj), it is shown.
---
--- @param self ForcedImpassableMarker The ForcedImpassableMarker object.
--- @param prop_id string The ID of the property that was changed.
--- @param old_value any The previous value of the property.
--- @param ged any The editor object that triggered the property change.
---
function ForcedImpassableMarker:OnEditorSetProperty(prop_id, old_value, ged)
	self:RebuildArea()
end
