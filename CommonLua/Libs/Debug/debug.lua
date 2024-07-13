if FirstLoad then
	s_ShowGossipMatch = false
	dbg_color = false
	dbg_objects = false
end

--- Clears any color modifiers that were set using `DbgSetColor()` on all objects that had their color modified.
--- This function is called when the game is saved to avoid saving temporary color changes.
function DbgClearColors()
	for obj in pairs(dbg_color or empty_table) do
		if IsValid(obj) then
			ClearColorModifierReason(obj, "DbgColor")
		end
	end
	dbg_color = false
end

---
--- Sets the color modifier of the specified object.
---
--- If `color` is `nil`, the color modifier is cleared.
--- Otherwise, the color modifier is set with the specified `color` value.
---
--- @param obj table The object to set the color modifier on.
--- @param color table|nil The color to set, or `nil` to clear the color modifier.
--- @param skip_attaches boolean|nil If `true`, the color modifier will not be applied to any attached objects.
---
function DbgSetColor(obj, color, skip_attaches)
	if not IsValid(obj) then return end
	if not color then
		if dbg_color then dbg_color[obj] = nil end
		ClearColorModifierReason(obj, "DbgColor", nil, skip_attaches)
	else
		dbg_color = table.create_set(dbg_color, obj, true)
		SetColorModifierReason(obj, "DbgColor", color, 1000, nil, skip_attaches)
	end
end

---
--- Clears any objects that were added using `DbgAddObj()`.
---
function DbgClearObjs()
	DoneObjects(dbg_objects)
	dbg_objects = false
end

---
--- Adds the specified object to the list of debug objects.
---
--- The debug objects list is used to keep track of objects that have been added for debugging purposes.
---
--- @param obj table The object to add to the debug objects list.
---
function DbgAddObj(obj)
	dbg_objects = table.create_add_unique(dbg_objects, obj)
end

function OnMsg.SaveGameStart()
	-- avoid saving temp changes
	DbgClearColors()
	DbgClearObjs()
end

if FirstLoad then
	DbgClearLast = false
end

---
--- Clears various debug-related objects and state.
---
--- If `once` is true, this function will only clear the debug state once per frame to avoid excessive clearing.
---
--- This function clears the following:
--- - Debug vectors
--- - Debug texts
--- - Debug colors
--- - Debug objects
---
--- @param once boolean|nil If true, the debug state will only be cleared once per frame.
---
function DbgClear(once)
	if once then
		local time = RealTime()
		if DbgClearLast == time then
			return
		end
		DbgClearLast = time
	end
	DbgClearVectors()
	DbgClearTexts()
	DbgClearColors()
	DbgClearObjs()
	Msg("DbgClear")
end
OnMsg.ChangeMap = DbgClear

---
--- Toggles the display of gossip messages that match the provided pattern.
---
--- When `s_ShowGossipMatch` is set to `false` (the default), all gossip messages will be displayed.
--- When `s_ShowGossipMatch` is set to a string pattern, only gossip messages that match the pattern will be displayed.
---
--- The `NetGossip` function is used to print gossip messages. It will check the `s_ShowGossipMatch` pattern and only print the message if it matches.
---
--- @param gossip_match string|nil The pattern to match gossip messages against. If `nil`, all gossip messages will be displayed.
---
function ShowGossip(gossip_match)
	s_ShowGossipMatch = gossip_match or false
	
	NetGossip = function(...)
		local params = table.pack(...)
		for idx, param in ipairs(params) do
			if type(param) == "string" and not utf8.IsValidString(param) then
				params[idx] = UnicodeEscapeCharactersToUtf8(param)
			end
		end
		if not s_ShowGossipMatch or string.match(s_ShowGossipMatch, params[1]) then
			print(table.unpack(params)) 
		end
	end
	
	netAllowGossip = true
end

---
--- Traces the position of the given object, drawing a history of its position.
---
--- @param o table The object to trace the position of.
--- @param color number|nil The color to use for the position history. If not provided, defaults to white (RGB(255, 255, 255)).
---
function TracePos(o, color)
	local origSetPos = o.SetPos
	g_PosTraced[o] = color or RGB(255, 255, 255)
	o.SetPos = function(self, pos, ...)
		origSetPos(self, pos, ...)
		dbgDrawPosHistory(pos)
	end
end

---
--- Draws visual indicators for the collision radii of objects in the game world.
---
--- This function creates a game time thread that continuously checks for objects within a 50 meter radius of the given object `o`. For each object, it creates a circle mesh to visualize the object's collision radius. The color of the circle is determined by the object's resting state - blue for non-resting objects, green for resting objects.
---
--- The visual indicators are attached to the objects and updated as the objects move. The thread sleeps for 100 milliseconds between each update.
---
--- @param o table The object to draw the collision radii around.
---
function DrawRadiuses(o)
	CreateGameTimeThread(function()
		while IsValid(o) do
			MapForEach( o:GetPos(), 50 * guim, nil, const.efDestlock,
				function(obj)
					if not rawget(obj, "__radius_circle") then
						local circle = CreateCircleMesh(pf.GetDestlockRadius(obj), RGB(0, 255, 255))
						obj:SetEnumFlags(const.efVisible)
						obj:Attach(circle)
						rawset(obj, "__radius_circle", circle)
					end
				end )
			MapForEach(o:GetPos(), 50 * guim, "Unit",
				function(obj)
					if obj:GetEnumFlags(const.efResting) ~= 0 then
						if not rawget(obj, "__radius_circle") then
							local circle = CreateCircleMesh(pf.GetDestlockRadius(obj), RGB(0, 255, 0))
							obj:Attach(circle)
							rawset(obj, "__radius_circle", circle)
						end
					else
						if rawget(obj, "__radius_circle") then
							DoneObject(obj.__radius_circle)
							obj.__radius_circle = nil
						end
					end
				end)
			
			Sleep(100)
		end
	end)
end

g_PosTraced = rawget(_G, "g_PosTraced") or {}
---
--- Traces the collision of an object with other objects in the game world, and sets the object's color modifier to red if it is overlapping with other objects.
---
--- This function is a replacement for the object's `SetPos` method. It first checks for any other objects within a 5 meter radius of the new position. If any of these objects are not dead and are within the combined collision radii of the object and the other object, the function will trace the overlapping objects and set the object's color modifier to red for 1 second.
---
--- @param o table The object to trace the collision for.
--- @param method string (optional) The method to use to get the collision radius of the object. Defaults to "GetCollisionRadius".
---
function TraceCollisionOverstep(o, method)
	method = method or "GetCollisionRadius"
	local origSetPos = o.SetPos
	o.SetPos = function(self, pos, ...)
		local bad = {}
		MapForEach( pos, 5*guim, "Unit", 
				function(o)
					if o ~= self and not o:IsDead() and o:GetVisualDist2D(self) < self[method](self) + o[method](self) - 10 * guic then
						table.insert(bad, o)
					end
				end)
		if #bad > 0 then
			self:Trace("Overlaping", bad, GetStack(1))
			self:SetColorModifier(RGB(255, 0, 0))
			CreateGameTimeThread(function()
				Sleep(1000)
				if IsValid(self) then
					self:SetColorModifier(RGB(128, 128, 128))
				end
			end)
		end
		origSetPos(self, pos, ...)
	end
end

---
--- Draws the position history of objects that have been traced for collision.
---
--- This function clears the debug output and then iterates through the `g_PosTraced` table, which contains objects that have been traced for collision. For each object, it draws a circle at the object's position with a radius equal to the object's collision radius, and an arrow from the object's visual position to its current position. It also outputs the object's class and state text at the object's position.
---
--- @param pos table The position to draw the history for.
---
function dbgDrawPosHistory(pos)
	dbgOutputClear()
	for o, color in pairs(g_PosTraced) do
		local r, g, b = GetRGB(color)
		dbgDrawCircle(o:GetPos(), o:GetCollisionRadius(), RGB(r/2, g/2, b/2))
		dbgDrawArrow(o:GetVisualPos(), o:GetPos(), color)
		dbgInfo(o:GetPos(), RGB(255, 255, 255), false, o.class .. " " .. o:GetStateText())
	end
end

CameraDebugSegments = {}
CameraDebugPoints = {}

---
--- Draws the camera collision debug information.
---
--- This function iterates through the `CameraDebugPoints` and `CameraDebugSegments` tables, and draws vectors representing the camera collision debug information. It draws a green vector from each point in `CameraDebugSegments` to the corresponding point in `CameraDebugPoints`.
---
function dbgDrawCameraCollision()
	for i = 1, #CameraDebugPoints do
		DbgAddVector(CameraDebugSegments[i*2], CameraDebugSegments[i*2+1]-CameraDebugSegments[i*2], RGB(0, 255, 0))
		DbgAddVector(CameraDebugSegments[i*2], CameraDebugPoints[i]-CameraDebugSegments[i*2], RGB(0, 255, 0))
	end
end

---
--- Draws a rectangle with the given bounding box, color, and optional angle.
---
--- This function creates a real-time thread that draws a polyline rectangle with the given bounding box, color, and optional angle. The rectangle is drawn at the center of the bounding box, with a height of 20 * guic. The rectangle is drawn for 1 second and then deleted.
---
--- @param box table The bounding box of the rectangle to draw.
--- @param color table The color of the rectangle, in RGB format.
--- @param angle number (optional) The angle to rotate the rectangle by, in radians.
---
function ShowRect(box, color, angle)
	CreateRealTimeThread(function()
		local rc = Polyline:new()
		local points = pstr("")
		points:AppendVertex(point(box:minx(), box:maxy(), 20 * guic), color)
		points:AppendVertex(point(box:maxx(), box:maxy(), 20 * guic))
		points:AppendVertex(point(box:maxx(), box:miny(), 20 * guic))
		points:AppendVertex(point(box:minx(), box:miny(), 20 * guic))
		points:AppendVertex(point(box:minx(), box:maxy(), 20 * guic))
		rc:SetMeshFlags(const.mfTerrainDistorted)
		rc:SetMesh(points)
		rc:SetPos(box:Center():SetTerrainZ())
		if angle then
			rc:SetAngle(angle)
		end
		
		Sleep(1000)
		rc:delete()
	end)
end


---
--- Temporarily changes the color modifier of the given object to blue for 1 second.
---
--- This function creates a real-time thread that sets the color modifier of the given object to blue, waits for 1 second, and then restores the original color modifier.
---
--- @param obj table The object to temporarily change the color modifier of.
---
function ShowObj(obj)
	CreateRealTimeThread(function()
		local cm = obj:GetColorModifier()
		obj:SetColorModifier(blue)
		Sleep(1000)
		obj:SetColorModifier(cm)
	end)
end

if FirstLoad then
	showme_markers = {}
end

---
--- Displays a visual marker for the given object, point, or vector.
---
--- This function creates a visual marker for the given object, point, or vector. The marker can be a sphere mesh for a point, a vector line for a vector, or a color modifier for an object. The marker is displayed for the specified time (or indefinitely if no time is given). If the input is `nil`, the function clears all previously created markers.
---
--- @param o table|point The object, point, or vector to display a marker for.
--- @param color table The color of the marker, in RGB format.
--- @param time number (optional) The duration in milliseconds to display the marker for.
---
function ShowMe(o, color, time)
	if o == nil then
		return ClearShowMe()
	end
	if type(o) == "table" and #o == 2 then
		if IsPoint(o[1]) and terrain.IsPointInBounds(o[1]) and 
			IsPoint(o[2]) and terrain.IsPointInBounds(o[2]) then
			local m = Vector:new()
			m:Set(o[1], o[2], color)
			showme_markers[m] = "vector"
			o = m
		end
	elseif IsPoint(o) then
		if terrain.IsPointInBounds(o) then
			local m = CreateSphereMesh(50 * guic, color or RGB(0, 255, 0))
			m:SetPos(o)
			showme_markers[m] = "point"
			if not time then
				ViewPos(o)
			end
			o = m
		end
	elseif IsValid(o) then
		showme_markers[o] = showme_markers[o] or o:GetColorModifier()
		o:SetColorModifier(color or RGB(0, 255, 0))
		local pos = o:GetVisualPos()
		if not time and terrain.IsPointInBounds(pos) then
			ViewPos(pos)
		end
	else
		if not showme_markers[o] then
			AddTrackerText(false, o)
		end
	end
	if time then
		CreateGameTimeThread(function(o, time)
			Sleep(time)
			local v = showme_markers[o]
			if IsValid(o) then
				if v == "point" or v == "vector" then
					DoneObject(o)
				else
					o:SetColorModifier(v)
				end
			end
			if ClearTextTrackers then
				ClearTextTrackers(o)
			end
		end, o, time)
	end
end

---
--- Clears all markers and text trackers that were created using the `ShowMe` function.
--- This function is used to clean up any visual debugging elements that were added to the game world.
---
--- @return nil
function ClearShowMe()
	for k, v in pairs(showme_markers) do
		if IsValid(k) then
			if v == "point" then
				DoneObject(k)
			else
				k:SetColorModifier(v)
			end
		end
	end
	if ClearTextTrackers then
		ClearTextTrackers()
	end
	showme_markers = {}
end

---
--- Creates a circle mesh at the specified position and radius, with the given color.
--- The circle will be visible for 7 seconds before being deleted.
---
--- @param pt Vector3 The position of the circle
--- @param r number The radius of the circle
--- @param color? RGB The color of the circle (default is white)
--- @return nil
function ShowCircle(pt, r, color)
	local c = CreateCircleMesh(r, color or RGB(255, 255, 255))
	c:SetPos(pt:SetTerrainZ(10*guic))
	CreateGameTimeThread(function()
		Sleep(7000)
		if IsValid(c) then
			c:delete()
		end
	end)
end

---
--- Generates a class hierarchy visualization for the specified class and its parents.
--- The visualization is generated as an HTML file that opens in the default web browser.
---
--- @param class string The name of the class to visualize
--- @param filter function|string An optional filter function or property name to filter the class hierarchy
--- @param unique_only boolean An optional flag to only show unique parent classes (default is false)
--- @return nil
function DbgShowClassHierarchy(class, filter, unique_only)
	local html = "<!DOCTYPE html><html><head><meta http-equiv='refresh' content = '0; url = %s' /></head></html>"
	local url = "http://magjac.com/graphviz-visual-editor/?dot="
	local dot = {'strict digraph { rankdir=TB'}
	local node_style = '[shape="polygon" style="filled" fillcolor="#1f77b4" fontcolor="#ffffff"]'
	local edge_style = '[fillcolor="#a6cee3" color="#1f78b4"]'
	local ignored_node_style = '[shape="polygon" style="filled" fillcolor="#7d91a0" fontcolor="#ffffff"]'
	if type(filter) == "string" then
		local member = filter
		filter = function(cls) return rawget(cls, member) ~= nil end
	end
	local queue, seen, inherited = {class}, {}, {}
	while next(queue) do
		local curr = table.remove(queue, #queue)
		if not seen[curr] then
			local curr_cls = g_Classes[curr]
			local ignored = filter and not filter(curr_cls)
			local curr_style = ignored and ignored_node_style or node_style
			table.insert(dot, string.format('"%s" %s', curr, curr_style))
			local parents = curr_cls.__parents
			for i, parent in ipairs(parents) do
				if not unique_only or not inherited[parent] then
					inherited[parent] = true
					table.insert(dot, string.format('"%s" -> "%s" %s', curr, parent, edge_style))
					table.insert(queue, parent)
				end
			end
		end
	end
	table.insert(dot, "}")
	url = url .. EncodeURL(table.concat(dot, "\n"))
	html = string.format(html, url)
	local path = ConvertToOSPath("TmpData/ClassGraph.html")
	AsyncStringToFile(path, html)
	OpenUrl(path)
end
