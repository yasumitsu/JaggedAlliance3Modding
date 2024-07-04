if FirstLoad then
	EditorMeasureLines = false
end

---
--- Adds a new editor measure line to the `EditorMeasureLines` table.
---
--- @param line table The line to add to the `EditorMeasureLines` table.
function AddEditorMeasureLine(line)
	EditorMeasureLines = EditorMeasureLines or {}
	EditorMeasureLines[#EditorMeasureLines + 1] = line
end

---
--- Destroys all editor measure lines in the `EditorMeasureLines` table.
---
function DestroyEditorMeasureLines()
	for _, line in ipairs(EditorMeasureLines or empty_table) do
		line:Done()
	end
	EditorMeasureLines = false
end

---
--- Updates the position of all editor measure lines in the `EditorMeasureLines` table.
---
function UpdateEditorMeasureLines()
	for _, line in ipairs(EditorMeasureLines or empty_table) do
		line:Move(line.point0, line.point1)
	end
end

OnMsg.EditorHeightChanged = UpdateEditorMeasureLines
OnMsg.EditorPassabilityChanged = UpdateEditorMeasureLines
OnMsg.ChangeMap = DestroyEditorMeasureLines


----- XMeasureTool

DefineClass.XMeasureTool = {
	__parents = { "XEditorTool" },
	properties = {
		persisted_setting = true,
		{ id = "CamDist", editor = "help", default = false, persisted_setting = false,
			help = function(self)
				local frac = self.cam_dist % guim
				return string.format("Distance to screen: %d.%0".. (#tostring(guim) - 1) .."dm", self.cam_dist / guim, frac)
			end
		},
		{ id = "Slope", editor = "help", default = false, persisted_setting = false,
			help = function(self)
				return string.format("Terrain slope: %.1f°", self.slope / 60.0)
			end
		},
		{ id = "MeasureInSlabs", name = "Measure in slabs", editor = "bool", default = false, no_edit = not const.SlabSizeZ },
		{ id = "FollowTerrain", name = "Follow terrain", editor = "bool", default = false, },
		{ id = "IgnoreWalkables", name = "Ignore walkables", editor = "bool", default = false, },
		{ id = "MeasurePath", name = "Measure path", editor = "bool", default = false, },
		{ id = "StayOnScreen", name = "Stay on screen", editor = "bool", default = false, },
	},
	ToolTitle = "Measure",
	Description = {
		"Measures distance between two points.",
		"The path found using the pathfinder and slope in degrees are also displayed.",
	},
	ActionSortKey = "1",
	ActionIcon = "CommonAssets/UI/Editor/Tools/MeasureTool.tga", 
	ActionShortcut = "Alt-M",
	ToolSection = "Misc",
	UsesCodeRenderables = true,
	
	measure_line = false,
	measure_cam_dist_thread = false,
	cam_dist = 0,
	slope = 0,
}
--- Initializes the XMeasureTool class.
-- This function creates a real-time thread that continuously updates the camera distance and terrain slope properties of the XMeasureTool instance.
-- The thread checks the mouse position and requests the pixel world position. It then calculates the distance between the camera eye and the returned pixel world position, as well as the terrain slope at the current terrain cursor position.
-- The `ObjModified` function is called to notify the engine that the XMeasureTool instance has been modified.
-- The thread sleeps for 50 milliseconds between each iteration to avoid excessive CPU usage.
function XMeasureTool:Init()
	-- ...
end

function XMeasureTool:Init()
	self.measure_cam_dist_thread = CreateRealTimeThread(function()
		while true do
			local mouse_pos = terminal.GetMousePos()
			if mouse_pos:InBox2D(terminal.desktop.box) then
				RequestPixelWorldPos(mouse_pos)
				WaitNextFrame(6)
				self.cam_dist = camera.GetEye():Dist2D(ReturnPixelWorldPos())
				self.slope = terrain.GetTerrainSlope(GetTerrainCursor())
				ObjModified(self)
			end
			Sleep(50)
		end
	end)
end

--- Finalizes the XMeasureTool instance.
-- This function is called when the XMeasureTool is done being used. It destroys any editor measure lines that were created, and deletes the real-time thread that was updating the camera distance and terrain slope properties.
function XMeasureTool:Done()
	if not self:GetStayOnScreen() then
		DestroyEditorMeasureLines()
	end
	DeleteThread(self.measure_cam_dist_thread)
end

--- Handles the mouse button down event for the XMeasureTool.
-- If the left mouse button is pressed, this function will either create a new MeasureLine object or destroy the existing one, depending on the current state of the tool.
-- If a MeasureLine object already exists, it will be destroyed. Otherwise, a new MeasureLine object will be created and added to the editor's measure lines.
-- The MeasureLine object's properties are set based on the current settings of the XMeasureTool, such as whether to measure in slabs, follow the terrain, ignore walkables, and show the path.
-- The MeasureLine object is then moved to the current terrain cursor position.
-- If the tool is not set to stay on screen, any existing editor measure lines will be destroyed before creating the new one.
-- This function returns "break" to indicate that the event has been handled and should not be propagated further.
function XMeasureTool:OnMouseButtonDown(pt, button)
	if button == "L" then
		local terrain_cursor = GetTerrainCursor()
		if self.measure_line then
			self.measure_line = false
		else
			if not self:GetStayOnScreen() then
				DestroyEditorMeasureLines()
			end
			self.measure_line = PlaceObject("MeasureLine", {
				measure_in_slabs = self:GetMeasureInSlabs(),
				follow_terrain = self:GetFollowTerrain(),
				ignore_walkables = self:GetIgnoreWalkables(),
				show_path = self:GetMeasurePath()
			})
			self.measure_line:Move(terrain_cursor, terrain_cursor)
			AddEditorMeasureLine(self.measure_line)
		end
		return "break"
	end
	return XEditorTool.OnMouseButtonDown(self, pt, button)
end

--- Updates the position and path of the MeasureLine object associated with the XMeasureTool.
-- This function is called when the mouse position changes while the XMeasureTool is active.
-- It moves the MeasureLine object to the current terrain cursor position and updates the path of the line.
-- If the MeasureLine object is not valid, this function does nothing.
function XMeasureTool:UpdatePoints()
	local obj = self.measure_line
	if obj and IsValid(obj) then
		local pt = GetTerrainCursor()
		obj:Move(obj.point0, pt)
		obj:UpdatePath()
	end
end

--- Updates the position and path of the MeasureLine object associated with the XMeasureTool.
-- This function is called when the mouse position changes while the XMeasureTool is active.
-- It moves the MeasureLine object to the current terrain cursor position and updates the path of the line.
-- If the MeasureLine object is not valid, this function does nothing.
function XMeasureTool:OnMousePos(pt, button)
	self:UpdatePoints()
end

--- Updates the properties of all editor measure lines when certain XMeasureTool properties change.
-- This function is called when the "MeasureInSlabs", "FollowTerrain", "IgnoreWalkables", or "MeasurePath" properties of the XMeasureTool are changed.
-- It iterates through all the editor measure lines and updates their corresponding properties to match the new XMeasureTool settings.
-- If the "StayOnScreen" property is set to false, it destroys all existing editor measure lines and resets the measure_line property of the XMeasureTool.
function XMeasureTool:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "MeasureInSlabs" then
		for _, line in ipairs(EditorMeasureLines or empty_table) do
			line.measure_in_slabs = self:GetMeasureInSlabs()
			line:UpdateText()
		end
	elseif prop_id == "FollowTerrain" then
		for _, line in ipairs(EditorMeasureLines or empty_table) do
			line.follow_terrain = self:GetFollowTerrain()
			line:Move(line.point0, line.point1)
		end
	elseif prop_id == "IgnoreWalkables" then
		for _, line in ipairs(EditorMeasureLines or empty_table) do
			line.ignore_walkables = self:GetIgnoreWalkables()
			line:Move(line.point0, line.point1)
		end
	elseif prop_id == "MeasurePath" then
		for _, line in ipairs(EditorMeasureLines or empty_table) do
			line.show_path = self:GetMeasurePath()
			line:UpdatePath()
		end
	end
	if prop_id == "StayOnScreen" and not self:GetStayOnScreen() then
		DestroyEditorMeasureLines()
		self.measure_line = false
	end
end


----- MeasureLine

DefineClass.MeasureLine = {
	__parents = { "Object" },

	point0 = point30,
	point1 = point30,
	path_distance = -1,
	line_distance = -1,
	horizontal_distance = -1,
	vertical_distance = -1,
	measure_in_slabs = false,
	show_path = false,
	follow_terrain = true,
}

--- Initializes a new MeasureLine object.
-- This function is called when a new MeasureLine object is created.
-- It creates the necessary visual components for the measure line, including a polyline for the line itself, a polyline for the path, and a text label.
function MeasureLine:Init()
	self.line = PlaceObject("Polyline")
	self.path = PlaceObject("Polyline")
	self.label = PlaceObject("Text")
end

--- Finalizes and destroys the visual components of a MeasureLine object.
-- This function is called when a MeasureLine object is no longer needed.
-- It destroys the polyline, path, and text label objects that were created in the Init() function.
function MeasureLine:Done()
	DoneObject(self.line)
	DoneObject(self.path)
	DoneObject(self.label)
end

---
--- Converts a distance value to a string representation.
---
--- If `measure_in_slabs` is true, the distance is formatted as a number of slabs, with the integer part representing the whole number of slabs and the decimal part representing the fractional part of a slab.
---
--- If `measure_in_slabs` is false, the distance is formatted as a number of decimeters, with the integer part representing the whole number of decimeters and the decimal part representing the fractional part of a decimeter.
---
--- @param dist number The distance value to be converted.
--- @param slab_size number The size of a slab, used when `measure_in_slabs` is true.
--- @param skip_slabs boolean If true, the "slabs" unit is omitted from the output.
--- @return string The string representation of the distance.
function MeasureLine:DistanceToString(dist, slab_size, skip_slabs)
	dist = Max(0, dist)
	if self.measure_in_slabs then
		local whole = dist / slab_size
		return string.format(skip_slabs and "%d.%d" or "%d.%d slabs", whole, dist * 10 / slab_size - whole * 10)
	else
		local frac = dist % guim
		return string.format("%d.%0".. (#tostring(guim) - 1) .."dm", dist / guim, frac)
	end
end

---
--- Updates the text label for the measure line.
--- The text label displays the distance measurements and angle of the line.
--- If `measure_in_slabs` is true, the distances are displayed in terms of slabs.
--- If `measure_in_slabs` is false, the distances are displayed in decimeters.
--- If `show_path` is true, the path distance is also displayed.
---
--- @param self MeasureLine The MeasureLine object to update the text for.
function MeasureLine:UpdateText()
	local dist_string
	if self.measure_in_slabs then
		local x = self:DistanceToString(abs(self.point0:x() - self.point1:x()), const.SlabSizeX, true)
		local y = self:DistanceToString(abs(self.point0:y() - self.point1:y()), const.SlabSizeY, true)
		local z = self:DistanceToString(self.vertical_distance, const.SlabSizeZ, true)
		dist_string = string.format("x%s, y%s, z%s", x, y, z)
	else
		local h = self:DistanceToString(self.horizontal_distance)
		local v = self:DistanceToString(self.vertical_distance)
		dist_string = string.format("h%s, v%s", h, v)
	end
	local angle = atan(self.vertical_distance, self.horizontal_distance) / 60.0
	local l = self:DistanceToString(self.line_distance, const.SlabSizeX)
	if self.show_path then
		local p = "No path"
		if self.show_path and self.path_distance ~= -1 then
			p = self:DistanceToString(self.path_distance, const.SlabSizeX)
		end
		self.label:SetText(string.format("%s (%s, %.1f°) : %s", l, dist_string, angle, p))
	else
		self.label:SetText(string.format("%s (%s, %.1f°)", l, dist_string, angle))
	end
end

local function _GetZ(pt, ignore_walkables)
	if ignore_walkables then
		return terrain.GetHeight(pt)
	else
		return Max(GetWalkableZ(pt), terrain.GetSurfaceHeight(pt))
	end
end

local function SetLineMesh(line, p_pstr)
	line:SetMesh(p_pstr)
	return line
end

---
--- Moves the measure line to the specified points.
---
--- @param point0 point The starting point of the measure line.
--- @param point1 point The ending point of the measure line.
function MeasureLine:Move(point0, point1)
	self.point0 = point0:SetInvalidZ()
	self.point1 = point1:SetInvalidZ()
	
	local point0t = point(point0:x(), point0:y(), _GetZ(point0))
	local point1t = point(point1:x(), point1:y(), _GetZ(point1))
	local len = (point0t - point1t):Len()

	local points_pstr = pstr("")
	points_pstr:AppendVertex(point0t)
	points_pstr:AppendVertex(point0t + point(0, 0, 5 * guim))
	points_pstr:AppendVertex(point0t + point(0, 0, guim))
	
	local steps = len / (guim / 2)
	steps = steps > 0 and steps or 1
	local distance = 0
	local prev_point = point0t + point(0, 0, guim)
	for i = 0, steps do
		local pt = point0t + (point1t - point0t) * i / steps
		if self.follow_terrain then
			pt = point(pt:x(), pt:y(), _GetZ(pt, self.ignore_walkables))
			distance = distance + (prev_point - point(0, 0, guim)):Dist(pt)
		end
		prev_point = pt + point(0, 0, guim)
		points_pstr:AppendVertex(prev_point)
	end
	
	points_pstr:AppendVertex(point1t + point(0, 0, guim))
	points_pstr:AppendVertex(point1t + point(0, 0, 5 * guim))
	points_pstr:AppendVertex(point1t)
	
	self.line = SetLineMesh(self.line, points_pstr)
	
	-- update text label
	local middlePoint = (point0 + point1) / 2
	self.line:SetPos(middlePoint)
	self.path:SetPos(middlePoint)
	self.label:SetPos(middlePoint + point(0, 0, 4 * guim))
	self.label:SetTextStyle("EditorTextBold")

	self.line_distance = self.follow_terrain and distance or len
	self.horizontal_distance = (point0t - point1t):Len2D()
	self.vertical_distance = abs(point0t:z() - point1t:z())
	self:UpdateText()
end

local function SetWalkableHeight(pt)
	return pt:SetZ(_GetZ(pt))
end

-- will create a red line if *delayed* == true and a green line if *delayed* == false
---
--- Sets the path for the measure line.
---
--- @param path table|nil The path points, or nil if no path.
--- @param delayed boolean Whether the path should be drawn in red (delayed) or green (not delayed).
---
function MeasureLine:SetPath(path, delayed)
	local v_points_pstr = pstr("")
	if path and #path > 0 then
		local v_prev = {}
		v_points_pstr:AppendVertex(SetWalkableHeight(self.point0), delayed and const.clrRed or const.clrGreen)
		v_points_pstr:AppendVertex(SetWalkableHeight(self.point0))
		local dist = 0
		for i = 1, #path do
			v_points_pstr:AppendVertex(SetWalkableHeight(path[i]))
			if i > 1 then
				dist = dist + path[i]:Dist(path[i - 1])
			end
		end
		self.path_distance = dist
	else
		v_points_pstr:AppendVertex(self.point0, delayed and const.clrRed or const.clrGreen)
		v_points_pstr:AppendVertex(self.point0)
		self.path_distance = -1
	end
	
	self.path = SetLineMesh(self.path, v_points_pstr)
	self:UpdateText()
end

---
--- Updates the path visualization for the measure line.
---
--- If `show_path` is true, the function will get the path between the two points and set it as the path visualization. If `show_path` is false, it will update the text label and hide the path visualization.
---
--- @param self MeasureLine The MeasureLine instance.
---
function MeasureLine:UpdatePath()
	if self.show_path then
		local pts, delayed = pf.GetPosPath(self.point0, self.point1)
		self:SetPath(pts, delayed)
		self.path:SetEnumFlags(const.efVisible)
	else
		self:UpdateText()
		self.path:ClearEnumFlags(const.efVisible)
	end
end
