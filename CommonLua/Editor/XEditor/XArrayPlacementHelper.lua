DefineClass.XArrayPlacementHelper = {
	__parents = { "XEditorPlacementHelper" },
	
	-- these properties get appended to the tool that hosts this helper
	properties = {
		persisted_setting = true,
		{ id = "RepeatCount", name = "Repeat Count", editor = "number", default = 2, 
		  min = 1, max = 20, help = "Number of times to clone the selected objects",
		},
	},
	
	HasLocalCSSetting = false,
	HasSnapSetting = true,
	InXSelectObjectsTool = true,
	
	clones = false,
	
	Title = "Array placement (3)",
	Description = false,
	ActionSortKey = "8",
	ActionIcon = "CommonAssets/UI/Editor/Tools/PlaceObjectsInARow.tga",
	ActionShortcut = "3",
	UndoOpName = "Placed array of objects",
}

--- Clones the selected objects a specified number of times and adds them to the `clones` table.
---
--- @param count number The number of times to clone the selected objects.
function XArrayPlacementHelper:Clone(count)
	local objs = {}
	local sel = editor.GetSel()
	for i = 1, count do
		local clones = {}
		for j, obj in ipairs(sel) do
			clones[j] = obj:Clone()
			objs[#objs + 1] = obj
		end
		if XEditorSelectSingleObjects == 0 then
			Collection.Duplicate(clones)
		end
		self.clones[#self.clones + 1] = clones
	end
	Msg("EditorCallback", "EditorCallbackPlace", objs)
end

--- Moves the cloned objects to a new position based on the terrain cursor position.
---
--- This function calculates the interval between the center of the selected objects and the terrain cursor position, and then moves each clone to a new position along that interval. The function also adjusts the height of the clones to match the terrain height at their new position.
---
--- @param self XArrayPlacementHelper The instance of the XArrayPlacementHelper class.
function XArrayPlacementHelper:Move()
	local objs = editor.GetSel()
	local start_point = CenterOfMasses(objs)
	local end_point = GetTerrainCursor()
	local interval = (end_point - start_point) / #self.clones
	
	local clones = {}
	local snapBySlabs = HasAlignedObjs(objs)
	local start_height = terrain.GetHeight(start_point)
	for i, group in ipairs(self.clones) do
		local vMove = interval * i
		vMove = vMove:SetZ(terrain.GetHeight(start_point + vMove) - start_height)
		for j, obj in ipairs(group) do
			XEditorSnapPos(obj, objs[j]:GetPos(), vMove, snapBySlabs)
			clones[#clones + 1] = obj
		end
	end
	Msg("EditorCallback", "EditorCallbackMove", clones)
end

--- Removes the specified number of cloned objects from the `clones` table and deletes them from the editor.
---
--- @param count number The number of cloned objects to remove.
function XArrayPlacementHelper:Remove(count)
	for i = 1, count do
		local objs = self.clones[#self.clones]
		Msg("EditorCallback", "EditorCallbackDelete", objs)
		DoneObjects(objs)
		self.clones[#self.clones] = nil
	end
end

--- Changes the number of cloned objects in the array placement.
---
--- This function is used to adjust the number of cloned objects in the array placement. If the new count is greater than the current number of clones, it will create the additional clones. If the new count is less than the current number of clones, it will remove the extra clones.
---
--- After adjusting the number of clones, the function will call the `Move()` function to update the positions of the cloned objects.
---
--- @param self XArrayPlacementHelper The instance of the XArrayPlacementHelper class.
--- @param count number The new number of cloned objects to have in the array placement.
function XArrayPlacementHelper:ChangeCount(count)
	local newCount = count - #self.clones
	if newCount > 0 then
		self:Clone(newCount)
	elseif newCount < 0 then
		self:Remove(-newCount)
	end
	self:Move()
end

--- Returns a description of the XArrayPlacementHelper functionality.
---
--- The description explains that the helper is used to clone objects in a straight line, and that the number of copies can be changed using the [ and ] keys.
---
--- @return string The description of the XArrayPlacementHelper functionality.
function XArrayPlacementHelper:GetDescription()
	return "(drag to clone objects in a straight line)\n(use [ and ] to change number of copies)"
end

--- Checks if the XArrayPlacementHelper should start a new operation.
---
--- This function is called to determine if a new operation should be started for the XArrayPlacementHelper. It checks if the Shift key is not pressed and if an object is selected at the current cursor position.
---
--- @param pt Vector3 The current cursor position.
--- @return boolean True if a new operation should be started, false otherwise.
function XArrayPlacementHelper:CheckStartOperation(pt)
	return not terminal.IsKeyPressed(const.vkShift) and editor.IsSelected(GetObjectAtCursor())
end

--- Starts a new operation for the XArrayPlacementHelper.
---
--- This function is called to initialize a new operation for the XArrayPlacementHelper. It retrieves the repeat count from the XSelectObjectsTool dialog, creates a new table to store the cloned objects, clones the objects the specified number of times, and sets the operation_started flag to true.
---
--- @param pt Vector3 The current cursor position.
function XArrayPlacementHelper:StartOperation(pt)
	local dlg = GetDialog("XSelectObjectsTool")
	local clones_count = dlg:GetProperty("RepeatCount")
	self.clones = {}
	self:Clone(clones_count)
	self.operation_started = true
end

--- Moves the cloned objects in the array placement.
---
--- This function is called to update the positions of the cloned objects in the array placement. It is typically called after the number of clones has been changed using the `ChangeCount()` function.
function XArrayPlacementHelper:PerformOperation(pt)
	self:Move()
end

--- Ends the operation of the XArrayPlacementHelper.
---
--- This function is called when the operation of the XArrayPlacementHelper is completed. It performs the following tasks:
--- - Calculates the center of mass (CoM) of the selected objects.
--- - Iterates through the cloned objects and adds them to the selection if their CoM is unique, otherwise removes them.
--- - Sets the `clones` table to `false` and the `operation_started` flag to `false`.
--- - If any objects were cloned, it sets the helper class of the `XSelectObjectsTool` dialog to `XSelectObjectsHelper`.
---
--- @param objects table The objects that were cloned during the operation.
function XArrayPlacementHelper:EndOperation(objects)
	local selCoM = CenterOfMasses(editor.GetSel())
	local CoMs = {}
	CoMs[selCoM:x()] = {}
	CoMs[selCoM:x()][selCoM:y()] = true
	local groupCount = #self.clones
	for i = 1, groupCount do
		local group = self.clones[i]
		local CoM = CenterOfMasses(group)
		if not CoMs[CoM:x()] then CoMs[CoM:x()] = {} end
		if not CoMs[CoM:x()][CoM:y()] then
			CoMs[CoM:x()][CoM:y()] = true
			editor.AddToSel(group)
		else
			DoneObjects(group)
			self.clones[i] = nil
		end
	end
	local objectsCloned = self.clones and #self.clones > 0
	self.clones = false
	self.operation_started = false
	if objectsCloned then 
		local dlg = GetDialog("XSelectObjectsTool")
		dlg:SetHelperClass("XSelectObjectsHelper")
	end
end

--- Handles keyboard shortcuts for adjusting the repeat count of the array placement.
---
--- This function is called when a keyboard shortcut is triggered while the XArrayPlacementHelper is active. It checks if the shortcut is "[" or "]", and if so, it adjusts the repeat count of the array placement by -1 or +1 respectively. If the operation has already started, it also calls the `ChangeCount()` function to update the positions of the cloned objects.
---
--- @param shortcut string The keyboard shortcut that was triggered.
--- @param source any The source of the shortcut.
--- @param ... any Additional arguments passed with the shortcut.
--- @return string "break" to indicate that the shortcut has been handled and should not be processed further.
function XArrayPlacementHelper:OnShortcut(shortcut, source, ...)
	if shortcut == "[" or shortcut == "]" then
		local dir = shortcut == "[" and -1 or 1
		self:SetProperty("RepeatCount", self:GetProperty("RepeatCount") + dir)
		if self.operation_started then
			self:ChangeCount(self:GetProperty("RepeatCount"))
		end
		return "break"
	end
end
