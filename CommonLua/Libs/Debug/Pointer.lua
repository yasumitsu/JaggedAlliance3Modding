if Platform.cmdline then return end

MapVar("g_debug_pointers_list", false)

if FirstLoad then
	g_TrackerTexts = {}
	g_TrackerTextsThread = false
end

function OnMsg.PostDoneMap()
	g_TrackerTextsThread = false
end

---
--- Starts a real-time thread that updates the tracker objects.
---
--- If a tracker text thread is already running, it will be woken up.
--- Otherwise, a new thread is created that will periodically call `UpdateTrackerObjs` and wait for a short sleep duration.
---
--- The thread will continue running until `g_TrackerTextsThread` is set to a different value, indicating that the thread should terminate.
---
--- @function StartUpdateTrackerObjs
--- @return none
function StartUpdateTrackerObjs()
	if IsValidThread(g_TrackerTextsThread) then
		Wakeup(g_TrackerTextsThread)
		return
	end
	g_TrackerTextsThread = CreateMapRealTimeThread(function()
		local clean_up_time = RealTime()
		local thread = CurrentThread()
		while g_TrackerTextsThread == thread do
			PauseInfiniteLoopDetection("UpdateTrackerObjs")
			local sleep = UpdateTrackerObjs(clean_up_time)
			ResumeInfiniteLoopDetection("UpdateTrackerObjs")
			WaitWakeup(sleep)
		end
	end)
end

OnMsg.NewMap = StartUpdateTrackerObjs
OnMsg.PersistPostLoad = StartUpdateTrackerObjs

local function GetDebugPointers()
	local ptrs = g_debug_pointers_list or {}
	g_debug_pointers_list = ptrs
	return ptrs
end

local function AddTrackerDbgText(t)
	table.insert(g_TrackerTexts, t)
	StartUpdateTrackerObjs()
end

DefineClass.PointerWhite = {
	__parents = { "Object" },
	entity = "ArrowUnits",
}

DefineClass.Pointer = {
	__parents = { "Object" },
	entity = "ArrowUnits",
	flags = { gofRealTimeAnim = true },
}

---
--- Initializes a Pointer object, which is a temporary game object that represents a visual pointer.
--- The Pointer object is added to the global list of debug pointers, and a real-time thread is created
--- that will animate the Pointer by moving it up and down along the Z-axis.
---
--- @param self Pointer
--- @return none
function Pointer:Init()
	NetTempObject(self)
	self:SetAxis(axis_y)
	self:SetAngle(180)
	self.thread = CreateMapRealTimeThread(function(self)
		local move, delta, sleep = 2500, 120, 15
		local x, y, z = self:GetVisualPosXYZ()
		while true do
			for i = 0, move, delta do
				self:SetPos(x, y, z + i, sleep)
				Sleep(sleep)
			end
			for i = move, 0, -delta do
				self:SetPos(x, y, z + i, sleep)
				Sleep(sleep)
			end
		end
	end, self)
	local dbg_ptrs = GetDebugPointers()
	dbg_ptrs[#dbg_ptrs + 1] = self
end

---
--- Destroys the Pointer object and removes it from the global list of debug pointers.
---
--- @param self Pointer
--- @return none
function Pointer:Done()
	DeleteThread(self.thread)
	GetDebugPointers():Remove(self)
end

DefineClass.RealTimePoint = {
	__parents = {"Mesh", "InitDone"},
	time_used = -60000,
	depth_test = false,
	vector = false,
}

---
--- Initializes a RealTimePoint object, which is a temporary game object that represents a visual pointer.
--- The RealTimePoint object is added to the global list of debug pointers.
---
--- @param self RealTimePoint
--- @return none
function RealTimePoint:Init()
	NetTempObject(self)
	local dbg_ptrs = GetDebugPointers()
	dbg_ptrs[#dbg_ptrs + 1] = self
	self:SetShader(ProceduralMeshShaders.mesh_linelist)
	self:SetDepthTest(false)
	self:SetMesh(CreateSphereVertices(guim / 2))
end

---
--- Destroys the RealTimePoint object and removes it from the global list of debug pointers.
---
--- @param self RealTimePoint
--- @return none
function RealTimePoint:Done()
	table.remove_value(GetDebugPointers(), self)
	if IsValid(self.vector) then
		self.vector:delete()
	end
end

---
--- Sets up a RealTimePoint object with the given position and color.
---
--- If the given position is not valid (i.e. not on the terrain), the position is set to a default height of 10 and the color is set to green.
--- The RealTimePoint object is set up with a sphere mesh using the given color, and a vector is created between the origin position and the final position.
---
--- @param self RealTimePoint The RealTimePoint object to set up.
--- @param pt Vector The position to set the RealTimePoint to.
--- @param ptOrigin Vector The origin position for the vector.
--- @param color Color The color to use for the RealTimePoint mesh.
--- @return none
function RealTimePoint:SetUp(pt, ptOrigin, color)
	if not pt:IsValidZ() then
		pt = pt:SetTerrainZ(10)
		color = RGB(0, 255, 0)
	end
	self:SetMesh(CreateSphereVertices(guim / 2, RGB(255, 255, 255)))
	Mesh.SetPos(self, pt)
	self.vector = self.vector or Vector:new()
	self.vector:Set(ptOrigin, pt, RGB(0, 255, 0))
end


---
--- Sets the position of the RealTimePoint object and updates its mesh and vector.
---
--- If the given position is not valid (i.e. not on the terrain), the position is set to a default height of 10 and the color is set to green.
--- The RealTimePoint object's mesh is updated with a sphere using the given color, and the vector is updated to connect the origin position and the final position.
---
--- @param self RealTimePoint The RealTimePoint object to set the position for.
--- @param pt Vector The position to set the RealTimePoint to.
--- @param ... any Additional arguments to pass to Mesh.SetPos().
--- @return none
function RealTimePoint:SetPos(pt, ...)
	local color
	if not pt:IsValidZ() then
		pt = pt:SetTerrainZ(10)
		color = RGB(0, 255, 0)
	else
		color = RGB(255, 255, 255) 
	end
	Mesh.SetPos(self, pt, ...)
	self:SetMesh(CreateSphereVertices(guim / 2, color))
	
	if self.vector then
		self.vector:Set(self.vector:GetA(), pt, RGB(0, 255, 0))
	end
end

---
--- Detaches the RealTimePoint object from the map and deletes its associated vector.
---
--- This function is used to clean up the RealTimePoint object when it is no longer needed. It detaches the mesh from the map and deletes the vector object that was created to represent the vector between the origin position and the final position.
---
--- @param self RealTimePoint The RealTimePoint object to detach from the map.
--- @return none
function RealTimePoint:DetachFromMap()
	Mesh.DetachFromMap(self)
	if IsValid(self.vector) then
		self.vector:delete()
		self.vector = false
	end
end


DefineClass.RealTimeText = {
	__parents = {"Text", "InitDone"},
	time_used = -60000,
}

---
--- Initializes a RealTimeText object.
---
--- This function is called when a RealTimeText object is created. It sets the text style to "EditorTextBold", adds the RealTimeText object to the list of debug pointers, and creates a NetTempObject for the RealTimeText.
---
--- @param self RealTimeText The RealTimeText object being initialized.
--- @return none
function RealTimeText:Init()
	NetTempObject(self)
	local dbg_ptrs = GetDebugPointers()
	dbg_ptrs[#dbg_ptrs + 1] = self
	self:SetTextStyle("EditorTextBold")
end

---
--- Removes the RealTimeText object from the list of debug pointers.
---
--- This function is called when a RealTimeText object is no longer needed. It removes the RealTimeText object from the list of debug pointers, effectively detaching it from the map.
---
--- @param self RealTimeText The RealTimeText object being removed from the list of debug pointers.
--- @return none
function RealTimeText:Done()
	table.remove_entry(GetDebugPointers(), self)
end

---
--- Adds a new debug text object to the list of tracked objects.
---
--- This function is used to create a new debug text object that will be displayed on the map. The text object is associated with a root object and an expression that will be evaluated to determine the text to display.
---
--- @param root table|function The root object or a function that returns the root object.
--- @param expression string The expression to evaluate to determine the text to display.
--- @return none
function AddTrackerText(root, expression)
	if not IsValid(root) then
		local arrow = string.find(expression, "->")
		if arrow then
			local f
			root = string.sub(expression, 1, arrow-1)
			local class_name = string.trim_spaces(root)
			if g_Classes[class_name] then
				root = function () return MapGet("map", class_name) or empty_table end
			else
				local r, err = load("return " .. root)
				if err then
					printf("Error while evaluating %s\n%s", string.trim(root, 24, "..."), err)
					return
				end
				root = r
			end
			local e = string.sub(expression, arrow+2)
			if string.find(e, "return") then
				local r, err = load("return function(o) " .. e .. " end" )
				if err then
					printf("Error while evaluating %s\n%s", string.trim(e, 24, "..."), err)
					return
				end
				f = r()
			else
				local r, err = load("return function(o) return " .. e .. " end" )
				if err then
					printf("Error while evaluating %s\n%s", string.trim(e, 24, "..."), err)
					return
				end
				f = r()
			end
			AddTrackerDbgText { id = expression, root = root, to_eval = f }
		else
			local init = 1
			while true do
				local i = string.find(expression, "[:.]", init)
				if i then
					init = i + 1
					root = string.sub(expression, 1, i-1)
				else
					printf("Not a valid expression to track")
					return
				end
				
				local class_name = string.trim_spaces(root)
				if g_Classes[class_name] then
					root = function () return MapGet("map", class_name) or empty_table end
					break
				else
					local r, err = load("return " .. root)
					if not err then
						root = r
						break
					end
				end
			end
			if not root then
				printf("Can't deduce the root object from %s\n", string.trim(expression, 24, "..."))
				return
			end
			local object_expression = string.sub(expression, init-1)
			local r, err = load("return function(o) return o" .. object_expression .. " end")
			if not err then
				AddTrackerDbgText{ id = expression, root = root, to_eval = r() }
				return
			end
		end
	else
		local r, err = load("return function(o) return "     .. expression .. " end")
		if r then
			AddTrackerDbgText{ id = expression, root = root, to_eval = r() }
			return
		else
			printf("Error while evaluating %s\n%s", string.trim(expression, 24, "..."), err)
			return
		end
	end
end

---
--- Adds a debug text overlay to the game world, displaying a point and a label.
---
--- @param o table|userdata The object to associate the debug text with.
--- @param pt Point The point to display.
--- @param label string The label to display.
--- @param time? number The duration in milliseconds to display the debug text. Defaults to 2000 (2 seconds).
---
function ShowPoint(o, pt, label, time)
	AddTrackerDbgText{
		id = pt,
		root = o,
		to_eval = function()
			return pt, label
		end,
		expire_time = GameTime() + (time or 2000),
	}
end

---
--- Updates the debug text trackers in the game world.
---
--- @param clean_up_time number The time in milliseconds since the last cleanup.
---
function UpdateTrackerObjs(clean_up_time)
	local texts = g_TrackerTexts
	local now = RealTime()
	local objs_text = {}

	local live_pts = MapFilter(GetDebugPointers(), "map", "RealTimePoint")
	local pointers_alive = false
	for i = #texts, 1, -1  do
		local t = texts[i]
		if t.expire_time and t.expire_time - GameTime() < 0 then
			table.remove(texts, i)
		end
		
		local ok, root
		if type(t.root) ~= "function" then
			root = t.root
		else
			ok, root = pcall(t.root)
		end
		if IsValid(root) or type(root) == "table" and IsValid(root[1]) then
			if IsValid(root) then
				root = {root}
			end
			for j = 1, #root do
				local r = root[j]
				local labels = {}
				local ok, v, text = pcall(t.to_eval, r) 
				if ok then
					if type(v) == "table" or IsPoint(v) or IsValid(v) then
						local function UnpackExaminedObj(v, resolve_tables)
							if IsPoint(v) then
								return v:IsValid() and {v} or {}
							elseif IsValid(v) then
								if v:IsValidPos() then
									return {v:GetVisualPos()}, RGBA(96, 96, 255, 64)
								else
									return {}
								end
							elseif type(v) == "table" and IsValid(v[1]) then
								local pts = {}
								for _, o in ipairs(v) do
									if o:IsValidPos() then
										pts[#pts+1] = o:GetVisualPos()
									end
								end
								return pts, RGBA(96, 96, 255, 64)
							elseif resolve_tables and type(v) == "table" then
								local pts = {}
								if #v > 0 then
									for i = 1, #v do
										local o = v[i]
										local elements = UnpackExaminedObj(o)
										for j = 1, #elements do
											table.insert(pts, elements[j])
										end
									end
								else
									for o, t in pairs(v) do
										local elements = UnpackExaminedObj(o)
										for j = 1, #elements do
											table.insert(pts, elements[j])
											labels[elements[j]] = tostring(t)
										end
									end
								end
								return pts, RGBA(255, 96, 96, 64)
							end
							return {}
						end
						local pts, color = UnpackExaminedObj(v, true)
						
						pointers_alive = true
						text = text and tostring(text)
						
						for i = 1, #pts do
							local pointer
							if #live_pts > 0 then
								pointer = table.remove(live_pts)
							else
								pointer = RealTimePoint:new()
							end
							pointer:SetUp(pts[i], r:GetVisualPos(), color)
							pointer.time_used = now
							local text = text or labels[pts[i]]
							if text then
								objs_text[pointer] = objs_text[pointer] or {}
								table.insert(objs_text[pointer], string.trim(tostring(text), 30, "..."))
							end
						end
					else
						objs_text[r] = objs_text[r] or {}
						table.insert(objs_text[r], string.trim(tostring(v), 30, "..."))
					end
				end
			end
		end
	end

	local live_texts = MapFilter(GetDebugPointers(), "map", "RealTimeText")
	for o, t in pairs(objs_text) do
		if IsValid(o) and o:IsValidPos() then
			local text
			if #live_texts > 0 then
				text = table.remove(live_texts)
			else
					text = RealTimeText:new()
				end
				text:SetText(table.concat(t, "\n"))
				text:SetPos(o:GetVisualPos())
				text.time_used = now
			end
		end

	if now - clean_up_time > 30000 then
		for i = #live_texts, 1, -1 do
			if now - live_texts[i].time_used > 30000 then
				DoneObject(live_texts[i])
				table.remove(live_texts, i)
			end
		end
		for i = #live_pts, 1, -1 do
			if now - live_pts[i].time_used > 30000 then
				DoneObject(live_pts[i])
				table.remove(live_pts, i)
			end
		end
	end
	if #texts > 0 or pointers_alive then
		for i = 1, #live_texts do
			live_texts[i]:DetachFromMap()
		end
		for i = 1, #live_pts do
			live_pts[i]:DetachFromMap()
		end
		return 50        --  live and positioned texts/pts - fast update
	end
	DoneObjects(live_texts)
	DoneObjects(live_pts)
end

---
--- Clears the list of text trackers.
---
--- If `expression` is provided, it removes the text tracker with the given `expression` from the list.
--- If `expression` is `nil`, it clears the entire list of text trackers.
---
--- @param expression string|nil The expression to remove from the list of text trackers, or `nil` to clear the entire list.
---
function ClearTextTrackers(expression)
	if expression then
		table.remove_value(g_TrackerTexts, "id", expression)
	else
		g_TrackerTexts = {}
	end
end

---
--- Checks if there are any text trackers with the given expression.
---
--- @param expression string The expression to search for in the list of text trackers.
--- @return boolean True if there are any text trackers with the given expression, false otherwise.
---
function HasTextTrackers(expression)
	return table.find(g_TrackerTexts, "id", expression) and true or false
end

---
--- Toggles the visibility of text trackers with the given expression.
---
--- If text trackers with the given expression already exist, this function will clear them.
--- If no text trackers with the given expression exist, this function will add a new text tracker.
---
--- @param expression string The expression to toggle the visibility of text trackers for.
--- @param description string|nil An optional description to print when toggling the visibility of the text trackers.
---
function ToggleTextTrackers(expression, description)
	if HasTextTrackers(expression) then
		ClearTextTrackers(expression)
		if (description or "") ~= "" then
			printf("Show %s: OFF", description)
		end
	else
		AddTrackerText(false, expression)
		if (description or "") ~= "" then
			printf("Show %s: ON", description)
		end
	end
end
