MapVar("g_CollideLuaObjects", false)
MapVar("s_SelectedWires", false)

DefineClass.CollideLuaObject = {
	__parents = { "Object", "EditorObject", "EditorCallbackObject" },
}

---
--- Removes the current `CollideLuaObject` instance from the `g_CollideLuaObjects` table.
---
--- This function is called when the `CollideLuaObject` is no longer needed, such as when it is deleted from the editor.
---
--- @function CollideLuaObject:Done
--- @return nil
function CollideLuaObject:Done()
	table.remove_entry(g_CollideLuaObjects, self)
end

---
--- Adds the current `CollideLuaObject` instance to the `g_CollideLuaObjects` table.
---
--- This function is called when the `CollideLuaObject` is placed in the editor.
---
--- @function CollideLuaObject:EditorCallbackPlace
--- @return nil
function CollideLuaObject:EditorCallbackPlace()
	g_CollideLuaObjects = g_CollideLuaObjects or {}
	table.insert(g_CollideLuaObjects, self)
end

---
--- Removes the current `CollideLuaObject` instance from the `g_CollideLuaObjects` table.
---
--- This function is called when the `CollideLuaObject` is no longer needed, such as when it is deleted from the editor.
---
--- @function CollideLuaObject:EditorCallbackDelete
--- @return nil
function CollideLuaObject:EditorCallbackDelete()
	table.remove_entry(g_CollideLuaObjects, self)
end

CollideLuaObject.EditorEnter = CollideLuaObject.EditorCallbackPlace
CollideLuaObject.EditorExit = CollideLuaObject.EditorCallbackDelete

---
--- Returns the bounding box of the `CollideLuaObject` instance.
---
--- This function returns a box object representing the axis-aligned bounding box of the `CollideLuaObject`. The bounding box is defined as a box with zero dimensions (0, 0, 0, 0).
---
--- @function CollideLuaObject:GetBBox
--- @return box The bounding box of the `CollideLuaObject` instance.
function CollideLuaObject:GetBBox()
	return box(0, 0, 0, 0)
end

---
--- Tests if a ray intersects the axis-aligned bounding box of the `CollideLuaObject`.
---
--- @param pos vec3 The origin of the ray.
--- @param dir vec3 The direction of the ray.
--- @return boolean True if the ray intersects the bounding box, false otherwise.
function CollideLuaObject:TestRay(pos, dir)
	return RayIntersectsAABB(pos, dir, self:GetBBox())
end

---
--- Sets the highlighted state of the `CollideLuaObject` instance.
---
--- When the `CollideLuaObject` is highlighted, it will have the `const.gofEditorHighlight` game flag set. When it is not highlighted, this flag will be cleared.
---
--- @param highlight boolean Whether the `CollideLuaObject` should be highlighted or not.
--- @return nil
function CollideLuaObject:SetHighlighted(highlight)
	if highlight then
		self:SetHierarchyGameFlags(const.gofEditorHighlight)
	else
		self:ClearHierarchyGameFlags(const.gofEditorHighlight)
	end
end

---
--- Returns the bounding box of the `CollideLuaObject` instance.
---
--- This function returns a box object representing the axis-aligned bounding box of the `CollideLuaObject`. The bounding box is defined as a box with zero dimensions (0, 0, 0, 0).
---
--- @param obj CollideLuaObject The `CollideLuaObject` instance to get the bounding box for.
--- @return box The bounding box of the `CollideLuaObject` instance.
function CollideLuaObjectGetBBox(obj)
	return obj:GetBBox()
end

---
--- Tests if a ray intersects the axis-aligned bounding box of the given `CollideLuaObject`.
---
--- @param obj CollideLuaObject The `CollideLuaObject` instance to test the ray against.
--- @param pos vec3 The origin of the ray.
--- @param dir vec3 The direction of the ray.
--- @return boolean True if the ray intersects the bounding box, false otherwise.
function CollideLuaObjectTestRay(obj, pos, dir)
	return obj:TestRay(pos, dir)
end

DefineClass.Wire = {
	__parents = {"Mesh"},
	
	pos1 = false,
	pos2 = false,
	curve_type = false,
	curve_length_percents = false,
	color = false,
	points_step = false,

	bbox = false,
	samples_bboxes = false,
}

---
--- Creates a new persistent string (pstr) object.
---
--- @return pstr A new persistent string object.
function Wire:CreatePstr()
	return pstr("")
end

DefineClass.SpotHelper = {
	__parents = {"Object", "EditorObject", "EditorCallbackObject"},
	
	obj = false,
	spot_type = false,
	spot_relative_index = false,
}

---
--- Returns the attach position for the SpotHelper object.
---
--- @return vec3 The attach position for the SpotHelper object.
function SpotHelper:GetAttachPos()
	local first = self.obj:GetSpotRange(self.spot_type)
	local index = first + self.spot_relative_index
	
	return self.obj:GetSpotPos(index)
end

---
--- Returns a table of editor-related objects for the SpotHelper.
---
--- @return table The editor-related objects for the SpotHelper.
function SpotHelper:GetEditorRelatedObjects()
	return { self.obj }
end

local s_DefaultHelperSpot = "Wire"

DefineClass.TwoPointsAttachParent = {	-- only these support 2-point attaches
	__parents = {"Object", "EditorCallbackObject"},
}

---
--- Clones the TwoPointsAttachParent object and attaches spot helpers to the new object.
--- Also creates new two-point attaches for any existing attaches that were attached to the source object.
---
--- @param source The source object to clone.
function TwoPointsAttachParent:EditorCallbackClone(source)
	local dlg = GetDialog("XSelectObjectsTool")
	if dlg and IsKindOf(dlg.placement_helper, "XTwoPointAttachHelper") then
		self:AttachSpotHelpers()
	end
	local wires = MapGet(true, "TwoPointsAttach")
	for _, wire in ipairs(wires) do
		if wire.obj1 == source then
			CreateTwoPointsAttach(self, wire.spot_type1, wire.spot_index1, wire.obj2, wire.spot_type2, wire.spot_index2, wire.curve, wire.length_percents)
		elseif wire.obj2 == source then
			CreateTwoPointsAttach(wire.obj1, wire.spot_type1, wire.spot_index1, self, wire.spot_type2, wire.spot_index2, wire.curve, wire.length_percents)
		end	
	end
	EditorCallbackObject.EditorCallbackClone(self, source)
end

---
--- Returns a table of editor-related objects for the TwoPointsAttachParent object.
---
--- @return table The editor-related objects for the TwoPointsAttachParent.
function TwoPointsAttachParent:GetEditorRelatedObjects()
	return MapGet(true, "TwoPointsAttach", function(obj) return obj.obj1 == self or obj.obj2 == self end)
end

---
--- Attaches spot helpers to the TwoPointsAttachParent object.
---
--- This function iterates through the spot range of the default helper spot type and creates a SpotHelper object for each spot. The SpotHelper objects are then attached to the TwoPointsAttachParent object, with the SpotHelper's `obj` field set to the TwoPointsAttachParent, the `spot_type` field set to the default helper spot type, and the `spot_relative_index` field set to the spot index relative to the first spot.
---
--- @param self TwoPointsAttachParent The TwoPointsAttachParent object to attach the spot helpers to.
function TwoPointsAttachParent:AttachSpotHelpers()
	local first, last = self:GetSpotRange(s_DefaultHelperSpot)
	for spot = first, last do
		local helper = PlaceObject("SpotHelper")
		self:Attach(helper, spot)
		helper.obj = self
		helper.spot_type = s_DefaultHelperSpot
		helper.spot_relative_index = spot - first
	end
end

local function CreateOrUpdateWire(pos1, pos2, wire, curve_type, curve_length_percents, color, points_step)
	color = color or const.clrBlack
	points_step = points_step or guim/10

	-- Do not recreate if all input parameteres are the same
	if wire then
		if wire.pos1 == pos1 and wire.pos2 == pos2 and wire.curve_type == curve_type and wire.curve_length_percents == curve_length_percents and wire.color == color and wire.points_step == points_step then
			return wire
		end
	end

	local catenary = curve_type == "Catenary"
	local axis = pos2 - pos1
	local axis_len = axis:Len()
	local wire_length = MulDivTrunc(axis_len, Max(100, curve_length_percents), 100)
	local get_curve_params = catenary and CatenaryToPointArcLength or ParabolaToPointArcLength
	local a, b, c = get_curve_params(axis, wire_length, 10000)
	if not (a and b) then
		return wire
	end
	
	local wire = wire or PlaceObject("Wire")
	wire.pos1 = pos1
	wire.pos2 = pos2
	wire.curve_length_percents = curve_length_percents
	wire.curve_type = curve_type
	wire.color = color
	wire.points_step = points_step

	local points = wire_length / points_step
	local geometry_pstr = wire:CreatePstr()
	local axis_len_2d = axis:Len2D()
	local samples_bboxes = {}
	local wire_pos = (pos1 + pos2) / 2
	local local_pos1 = pos1 - wire_pos
	local local_pos2 = pos2 - wire_pos
	local wire_width = 30 * guim / 100
	local width_vec = SetLen(Rotate(axis:SetInvalidZ(), 90 * 60), wire_width / 2):SetZ(0)
	local curve_value_at = catenary and CatenaryValueAt or ParabolaValueAt
	
	local thickness = MulDivRound(guim, 1, 100)
	local roundness = 10
	local axis2d = axis:SetZ(0)
	
	local last_pt = point()
	local tempPt = point()
	local CreateOrUpdateWire_AppendPt = CreateOrUpdateWire_AppendPt
	if points > 0 then
		for i = 0, points do
			local x = axis_len_2d * i / points
			local y = curve_value_at(x, a, b, c)

			tempPt:InplaceSet(axis)
			InplaceMulDivRound(tempPt, i, points)
			tempPt:InplaceSetZ(y)
			tempPt:InplaceAdd(local_pos1)
			if i > 0 then
				CreateOrUpdateWire_AppendPt(geometry_pstr, samples_bboxes, thickness, roundness, color, width_vec, axis2d, last_pt, tempPt)
			end
			last_pt:InplaceSet(tempPt)
		end
	end
	if last_pt ~= local_pos2 then
		CreateOrUpdateWire_AppendPt(geometry_pstr, samples_bboxes, thickness, roundness, color, width_vec, axis2d, last_pt, local_pos2)
	end
	
	-- calc bounding box - needed by the CollideLuaObject:TestRay()
	local bbox = samples_bboxes[1]
	for i = 2, #samples_bboxes do
		bbox:InplaceExtend(samples_bboxes[i])
	end

	wire:SetMesh(geometry_pstr)
	wire:SetShader(ProceduralMeshShaders.defer_mesh)
	wire:SetDepthTest(true)
	wire:SetPos(wire_pos)
	wire.samples_bboxes = samples_bboxes
	wire.bbox = bbox

	return wire
end

---
--- Creates a wire mesh between two 3D points, with an optional curve type and length.
---
--- @param pos1 table|vec3 The starting position of the wire
--- @param pos2 table|vec3 The ending position of the wire
--- @param curve_type string (optional) The type of curve to use, either "Parabola" or "Catenary"
--- @param curve_length_percents number (optional) The percentage increase in length of the wire compared to the straight line distance between pos1 and pos2
--- @param color table|vec4 (optional) The color of the wire
--- @param points_step number (optional) The number of points to use to render the wire
--- @return table The created wire mesh object
---
function CreateWire(pos1, pos2, curve_type, curve_length_percents, color, points_step)
	return CreateOrUpdateWire(pos1, pos2, nil, curve_type or "Parabola", curve_length_percents or 101, color, points_step)
end

DefineClass.XTwoPointAttachHelper = {
	__parents = { "XEditorPlacementHelper", "XEditorToolSettings" },
	
	-- these properties get appended to the tool that hosts this helper
	properties = {
		persisted_setting = true,
		{ id = "WireLength", name = "Wire Length Increase %", editor = "number", min = 101, max = 1000,
			persisted_setting = true, default = 150, help = "Percents increase of straight line length",
		},
		{ id = "WireCurve", name = "Wire Curve", editor = "dropdownlist", persisted_setting = true, 
		  items = {"Parabola", "Catenary"}, default = "Catenary",
		},
		{ id = "Buttons", name = "Wire Length Increase %", editor = "buttons", default = false,
		  buttons = {{name = "Clear All Wires", func = function(self)
				MapDelete(true, "TwoPointsAttach")
		  end}},
		},
	},
	
	HasLocalCSSetting = false,
	HasSnapSetting = false,
	InXSelectObjectsTool = true,
	UsesCodeRenderables = true,

	Title = "Place wires (2)",
	Description = false,
	ActionSortKey = "32",
	ActionIcon = "CommonAssets/UI/Editor/Tools/PlaceWires.tga",
	ActionShortcut = "2",
	UndoOpName = "Attached wire",
	
	wire = false,
	start_helper = false,
}

---
--- Initializes the XTwoPointAttachHelper by attaching spot helpers to all TwoPointsAttachParent objects in the map.
---
function XTwoPointAttachHelper:Init()
	MapForEach("map", "TwoPointsAttachParent", function(obj)
		obj:AttachSpotHelpers()
	end)
end

---
--- Cleans up the XTwoPointAttachHelper by destroying the wire object and all SpotHelper objects in the map.
---
function XTwoPointAttachHelper:Done()
	if self.wire then
		DoneObject(self.wire)
	end
	MapForEach(true, "SpotHelper", function(spot_helper)
		DoneObject(spot_helper)
	end)
end

---
--- Provides a description for the XTwoPointAttachHelper tool, which is used to place wires between electricity poles in the editor.
---
--- The description indicates that the tool is used to "drag to place wires between electricity poles", and that "Shift-Mousewheel changes wire length".
---
function XTwoPointAttachHelper:GetDescription()
	return "(drag to place wires between electricity poles)\n(Shift-Mousewheel changes wire length)"
end

---
--- Returns the SpotHelper object at the current cursor position.
---
--- @return SpotHelper|nil The SpotHelper object at the cursor position, or nil if none.
---
function XTwoPointAttachHelper:GetSpotHelperCursorObj()
	return GetNextObjectAtScreenPos(function(obj) return IsKindOf(obj, "SpotHelper") end)
end

---
--- Checks if the XTwoPointAttachHelper can start an operation.
---
--- @return boolean true if a SpotHelper object is under the cursor, false otherwise
---
function XTwoPointAttachHelper:CheckStartOperation(pt)
	return not not self:GetSpotHelperCursorObj()
end

---
--- Starts the operation of the XTwoPointAttachHelper tool.
---
--- This function is called when the user starts the operation of the XTwoPointAttachHelper tool. It checks if a SpotHelper object is under the cursor, and if so, it sets the `operation_started` flag and the `start_helper` property to the SpotHelper object. It then calls the `UpdateWire()` function to update the wire being placed.
---
--- @param pt table The current cursor position.
---
function XTwoPointAttachHelper:StartOperation(pt)
	local obj = self:GetSpotHelperCursorObj()
	if not obj then return end
	
	self.operation_started = true
	self.start_helper = obj
	self:UpdateWire()
end

---
--- Ends the operation of the XTwoPointAttachHelper tool.
---
--- This function is called when the user ends the operation of the XTwoPointAttachHelper tool. It performs the following steps:
---
--- 1. Destroys the wire object that was created during the operation.
--- 2. Gets the SpotHelper object at the current cursor position.
--- 3. If a SpotHelper object is found, it retrieves the objects and spot information from the start and end SpotHelper objects.
--- 4. It then checks if the two objects are different and if a TwoPointsAttach object does not already exist between them.
--- 5. If the conditions are met, it creates a new TwoPointsAttach object using the retrieved information and the current wire curve and length settings.
--- 6. Finally, it resets the `start_helper` and `operation_started` properties.
---
--- @return nil
---
function XTwoPointAttachHelper:EndOperation()
	DoneObject(self.wire)
	self.wire = false
	local spot_helper = self:GetSpotHelperCursorObj()
	if spot_helper then
		local obj1, obj2 = self.start_helper.obj, spot_helper.obj
		local spot_type1, spot_type2 = self.start_helper.spot_type, spot_helper.spot_type
		local spot_index1, spot_index2 = self.start_helper.spot_relative_index, spot_helper.spot_relative_index
		local dlg = GetDialog("XSelectObjectsTool")		
		local curve = dlg:GetProperty("WireCurve")
		local length_percents = dlg:GetProperty("WireLength")
		if obj1 ~= obj2 and not GetTwoPointsAttach(obj1, spot_type1, spot_index1, obj2, spot_type2, spot_index2) then
			XEditorUndo:BeginOp{name = "Created wire"}
			XEditorUndo:EndOp({CreateTwoPointsAttach(obj1, spot_type1, spot_index1, obj2, spot_type2, spot_index2, curve, length_percents)})
		end
	end
	self.start_helper = false
	self.operation_started = false
end

---
--- Updates the wire being placed by the XTwoPointAttachHelper tool.
---
--- This function is called during the operation of the XTwoPointAttachHelper tool to update the wire being placed. It retrieves the start and end positions of the wire from the SpotHelper objects, and then creates or updates the wire object using the current wire curve and length settings.
---
--- @param pt table The current cursor position (unused).
---
function XTwoPointAttachHelper:PerformOperation(pt)
	self:UpdateWire()
end

---
--- Updates the wire being placed by the XTwoPointAttachHelper tool.
---
--- This function is called during the operation of the XTwoPointAttachHelper tool to update the wire being placed. It retrieves the start and end positions of the wire from the SpotHelper objects, and then creates or updates the wire object using the current wire curve and length settings.
---
--- @param pt table The current cursor position (unused).
---
function XTwoPointAttachHelper:UpdateWire()
	if not self.start_helper then return end
	
	local pos1 = self.start_helper:GetAttachPos()
	local spot_helper = self:GetSpotHelperCursorObj()
	local pos2 = spot_helper and spot_helper:GetAttachPos() or GetTerrainCursor()
	local dlg = GetDialog("XSelectObjectsTool")
	local curve_type = dlg:GetProperty("WireCurve")
	local curve_length = dlg:GetProperty("WireLength")
	self.wire = CreateOrUpdateWire(pos1, pos2, self.wire, curve_type, curve_length)
end

---
--- Handles keyboard shortcuts for adjusting the wire length in the XTwoPointAttachHelper tool.
---
--- This function is called when a keyboard shortcut is triggered while the XTwoPointAttachHelper tool is active. It checks if the Control key is pressed, and if so, it adjusts the wire length based on the mouse wheel scroll direction. The wire length is clamped to the minimum and maximum values defined in the tool's property metadata.
---
--- @param shortcut string The name of the triggered shortcut.
--- @param source any The source of the shortcut (unused).
--- @param ... any Additional arguments (unused).
---
--- @return string "break" to indicate that the shortcut has been handled and should not be processed further.
---
function XTwoPointAttachHelper:OnShortcut(shortcut, source, ...)
	local delta
	if terminal.IsKeyPressed(const.vkControl) then
		if shortcut:ends_with("MouseWheelFwd") then
			delta = 1
		elseif shortcut:ends_with("MouseWheelBack") then
			delta = -1
		end
	end
	
	if delta then
		local tool = XEditorGetCurrentTool()
		local meta = self:GetPropertyMetadata("WireLength")
		tool:SetProperty("WireLength", Clamp(self:GetProperty("WireLength") + delta, meta.min, meta.max))
		ObjModified(tool)
		self:UpdateWire()
		return "break"
	end
end

DefineClass.TwoPointsAttach = {
	__parents = {"Object", "EditorCallbackObject", "CollideLuaObject"},
	flags = {gofPermanent = true},
	
	properties = {
		{id = "obj1", name = "Object 1", editor = "object", default = false},
		{id = "spot_type1", name = "Spot Type 1", editor = "text", default = s_DefaultHelperSpot},
		{id = "spot_index1", name = "Spot Index 1", editor = "text", default = "invalid"},
		{id = "obj2", name = "Object 2", editor = "object", default = false},
		{id = "spot_type2", name = "Spot Type 2", editor = "text", default = s_DefaultHelperSpot},
		{id = "spot_index2", name = "Spot Index 2", editor = "text", default = "invalid"},
		{id = "curve", name = "Curve", editor = "text", default = "Catenary"},
		{id = "length_percents", name = "Length Percents", editor = "number", default = 150},
		{id = "Pos", dont_save = true},
	},
	
	wire = false,
}

---
--- Marks the TwoPointsAttach object as done, which will destroy the associated wire object.
---
function TwoPointsAttach:Done()
	DoneObject(self.wire)
end

---
--- Sets the positions of the two objects that the TwoPointsAttach object is attached to.
---
--- @param obj1 table The first object to attach to.
--- @param spot_type1 string The type of spot on the first object to attach to.
--- @param spot_index1 number The index of the spot on the first object to attach to.
--- @param obj2 table The second object to attach to.
--- @param spot_type2 string The type of spot on the second object to attach to.
--- @param spot_index2 number The index of the spot on the second object to attach to.
--- @param curve string The type of curve to use for the wire.
--- @param length_percents number The length of the wire as a percentage of the distance between the two objects.
--- @param color table The color of the wire.
--- @param points_step number The number of points to use for the wire.
---
function TwoPointsAttach:SetPositions(obj1, spot_type1, spot_index1, obj2, spot_type2, spot_index2, curve, length_percents, color, points_step)
	self.obj1, self.spot_type1, self.spot_index1 = obj1, spot_type1, spot_index1
	self.obj2, self.spot_type2, self.spot_index2 = obj2, spot_type2, spot_index2
	self.curve, self.length_percents = curve, length_percents
	if IsValid(self.obj1) and IsValid(self.obj2) and type(self.spot_index1) == "number" and type(self.spot_index2) == "number"  then
		local start1 = obj1:GetSpotRange(spot_type1)
		local start2 = obj2:GetSpotRange(spot_type2)
		local pos1 = obj1:GetSpotLocPos(start1 + spot_index1, obj1:TimeToInterpolationEnd())
		local pos2 = obj2:GetSpotLocPos(start2 + spot_index2, obj2:TimeToInterpolationEnd())
		self.wire = CreateOrUpdateWire(pos1, pos2, self.wire, curve, length_percents, color, points_step)
		self:SetPos(self.wire:GetPos())
	end
end

---
--- Updates the positions of the two objects that the TwoPointsAttach object is attached to.
---
--- @param color table The color of the wire.
--- @param points_step number The number of points to use for the wire.
---
function TwoPointsAttach:UpdatePositions(color, points_step)
	self:SetPositions(self.obj1, self.spot_type1, self.spot_index1,
		self.obj2, self.spot_type2, self.spot_index2, self.curve, self.length_percents, color, points_step)
end

---
--- Returns the bounding box of the wire associated with this TwoPointsAttach object.
---
--- @return table The bounding box of the wire.
---
function TwoPointsAttach:GetBBox()
	return self.wire.bbox
end

---
--- Tests if a ray intersects with the bounding boxes of the wire samples.
---
--- @param pos table The starting position of the ray.
--- @param dir table The direction of the ray.
--- @return boolean True if the ray intersects with any of the wire sample bounding boxes, false otherwise.
---
function TwoPointsAttach:TestRay(pos, dir)
	local samples_bboxes = self.wire.samples_bboxes
	local dest = pos + dir
	for _, bbox in ipairs(samples_bboxes) do
		if RayIntersectsAABB(pos, dest, bbox) then
			return true
		end
	end
end

---
--- Sets the highlighted state of the TwoPointsAttach object.
---
--- @param highlighted boolean Whether the TwoPointsAttach object should be highlighted.
---
function TwoPointsAttach:SetHighlighted(highlighted)
	highlighted = highlighted or (s_SelectedWires and s_SelectedWires[self])
	self:UpdatePositions(highlighted and const.clrGray or const.clrBlack)
end

---
--- Sets the visibility of the wire associated with this TwoPointsAttach object.
---
--- @param visible boolean Whether the wire should be visible or not.
---
function TwoPointsAttach:SetVisible(visible)
	if not IsValid(self.wire) then return end
	if visible then
		self.wire:SetEnumFlags(const.efVisible)
	else
		self.wire:ClearEnumFlags(const.efVisible)
	end
end

---
--- Called after the TwoPointsAttach object is loaded.
---
--- If the obj1 or obj2 properties are invalid, the TwoPointsAttach object is destroyed.
--- Otherwise, the positions of the TwoPointsAttach object are updated.
---
--- @param reason string The reason the TwoPointsAttach object was loaded.
---
function TwoPointsAttach:PostLoad(reason)
	if not IsValid(self.obj1) or not IsValid(self.obj2) then
		DoneObject(self)
	else
		self:UpdatePositions()
	end
end

local function CheckValidTwoPointsAttach(obj)
	if not IsValid(obj.obj1) then
		StoreErrorSource(obj, "Wire obj1 is invalid!", obj.handle)
	end
	if not IsValid(obj.obj2) then
		StoreErrorSource(obj, "Wire obj2 is invalid!", obj.handle)
	end
end

function OnMsg.PreSaveMap()
	MapForEach(true, "TwoPointsAttach", CheckValidTwoPointsAttach)
end

function OnMsg.NewMapLoaded()
	MapForEach(true, "TwoPointsAttach", function(obj)
		if obj.spot_index1 == "invalid" then
			obj.spot_index1 = obj.spot1
		end
		if obj.spot_index2 == "invalid" then
			obj.spot_index2 = obj.spot2
		end
		obj:UpdatePositions()
		CheckValidTwoPointsAttach(obj)
		if not obj.wire and IsValid(obj.obj1) and IsValid(obj.obj2) then
			StoreErrorSource(obj, "Wire is invalid!", obj.handle, obj.obj1, obj.obj2)
		end
	end)
end

local function FilterTwoPointsAttachParents(objects)
	local two_points_parents = {}
	for _, obj in ipairs(objects) do
		if IsKindOf(obj, "TwoPointsAttachParent") then
			table.insert(two_points_parents, obj)
		end
	end
	
	return two_points_parents
end

--- Iterates over all TwoPointsAttach objects connected to the given objects and calls the provided function on each connected wire.
---
--- @param objects table A table of objects to check for connected TwoPointsAttach objects.
--- @param func function The function to call on each connected wire.
function ForEachConnectedWire(objects, func)
	local two_points_parents = FilterTwoPointsAttachParents(objects)
	if #two_points_parents == 0 then return end

	local wires = MapGet(true, "TwoPointsAttach")
	for _, obj in ipairs(two_points_parents) do
		for _, wire in ipairs(wires) do
			if wire.obj1 == obj or wire.obj2 == obj then
				func(wire)
			end
		end
	end
end

function OnMsg.EditorCallback(id, objects)
	if id == "EditorCallbackDelete" then
		ForEachConnectedWire(objects, function(wire)
			if IsValid(wire) then
				DoneObject(wire)
			end
		end)
	elseif id == "EditorCallbackMove" or id == "EditorCallbackRotate" or id == "EditorCallbackScale" then
		ForEachConnectedWire(objects, function(wire)
			wire:UpdatePositions()
		end)
	end
end

function OnMsg.WireCurveTypeChanged(new_curve_type)
	s_SelectedWires = s_SelectedWires or {}
	for wire in pairs(s_SelectedWires) do
		if wire.curve ~= new_curve_type then
			wire.curve = new_curve_type
			wire:UpdatePositions()
		end
	end
end

function OnMsg.EditorSelectionChanged(objects)
	s_SelectedWires = s_SelectedWires or {}
	local cur_sel = {}
	for _, obj in ipairs(objects) do
		if IsKindOf(obj, "TwoPointsAttach") then
			cur_sel[obj] = true
			if not s_SelectedWires[obj] then
				s_SelectedWires[obj] = true
				obj:SetHighlighted("highlighted")
			end
		end
	end
	local to_unselect = {}
	for wire in pairs(s_SelectedWires) do
		if not cur_sel[wire] then
			table.insert(to_unselect, wire)
		end
	end
	for _, wire in ipairs(to_unselect) do
		s_SelectedWires[wire] = nil
		if IsValid(wire) then
			wire:SetHighlighted(false)
		end
	end
	local sel_types = {}
	for wire in pairs(s_SelectedWires) do
		if not sel_types[wire.curve] then
			sel_types[wire.curve] = true
			table.insert(sel_types, wire.curve)
		end
	end
	if #sel_types == 1 then
		local dlg = GetDialog("XSelectObjectsTool")
		if dlg then
			dlg:SetProperty("WireCurve", sel_types[1])
		end
	end
end

---
--- Creates a new `TwoPointsAttach` object and sets its positions based on the provided parameters.
---
--- @param obj1 table The first object to attach to.
--- @param spot_type1 string The type of attachment spot on the first object.
--- @param spot_index1 number The index of the attachment spot on the first object.
--- @param obj2 table The second object to attach to.
--- @param spot_type2 string The type of attachment spot on the second object.
--- @param spot_index2 number The index of the attachment spot on the second object.
--- @param curve number The curve type of the attachment.
--- @param length number The length of the attachment.
--- @return table The created `TwoPointsAttach` object.
function CreateTwoPointsAttach(obj1, spot_type1, spot_index1, obj2, spot_type2, spot_index2, curve, length)
	local real_wire = PlaceObject("TwoPointsAttach")
	real_wire:SetPositions(obj1, spot_type1, spot_index1, obj2, spot_type2, spot_index2, curve, length)
	return real_wire
end

---
--- Retrieves a `TwoPointsAttach` object that connects the specified attachment spots on two objects.
---
--- @param obj1 table The first object to attach to.
--- @param spot_type1 string The type of attachment spot on the first object.
--- @param spot_index1 number The index of the attachment spot on the first object.
--- @param obj2 table The second object to attach to.
--- @param spot_type2 string The type of attachment spot on the second object.
--- @param spot_index2 number The index of the attachment spot on the second object.
--- @return table|nil The `TwoPointsAttach` object, or `nil` if not found.
function GetTwoPointsAttach(obj1, spot_type1, spot_index1, obj2, spot_type2, spot_index2)
	local wires = MapGet(true, "TwoPointsAttach")
	for _, wire in ipairs(wires) do
		if	wire.obj1 == obj1 and wire.spot_type1 == spot_type1 and wire.spot_index1 == spot_index1 and 
			wire.obj2 == obj2 and wire.spot_type2 == spot_type2 and wire.spot_index2 == spot_index2 then
			return wire
		end
		if	wire.obj1 == obj2 and wire.spot_type1 == spot_type2 and wire.spot_index1 == spot_index2 and 
			wire.obj2 == obj1 and wire.spot_type2 == spot_type1 and wire.spot_index2 == spot_index1 then
			return wire
		end
	end
end
