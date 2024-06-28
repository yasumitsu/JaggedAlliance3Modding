MapVar("SelectedObj", false)
MapVar("Selection", {})

local find = table.find
local remove = table.remove
local IsValid = IsValid

local function SelectionChange()
	ObjModified(Selection)
	Msg("SelectionChange")
end

local function __selobj(obj, prev)
	obj = IsValid(obj) and obj or false
	prev = prev or SelectedObj
	if prev ~= obj then
		SelectedObj = obj
		SetDebugObj(obj) -- make it available at the C side for debugging the selected object
		--@@@msg SelectedObjChange,object, previous- fired when the user changes the selected object.
		Msg("SelectedObjChange", obj, prev)
		if SelectedObj == obj then
			if prev then
				PlayFX("SelectObj", "end", prev)
			end
			if obj then
				PlayFX("SelectObj", "start", obj)
			end
		end
	end
end

local function __add(obj)
	if not IsValid(obj) or find(Selection, obj) then
		return
	end
	Selection[#Selection + 1] = obj
	PlayFX("Select", "start", obj)
	Msg("SelectionAdded", obj)
	DelayedCall(0, SelectionChange)
end

local function __remove(obj, idx)
	idx = idx or find(Selection, obj)
	if not idx then
		return
	end
	remove(Selection, idx)
	PlayFX("Select", "end", obj)
	Msg("SelectionRemoved", obj)
	DelayedCall(0, SelectionChange)
end

---
--- Adds the specified object or list of objects to the current selection.
---
--- If `obj` is a single valid object, it is added to the selection.
--- If `obj` is a table, each valid object in the table is added to the selection.
---
--- After adding the object(s), the selection is validated to remove any invalid objects.
---
--- @param obj table|any The object or list of objects to add to the selection.
---
function SelectionAdd(obj)
	if IsValid(obj) then
		__add(obj)
	elseif type(obj) == "table" then
		for i = 1, #obj do
			__add(obj[i])
		end
	end
	SelectionValidate(SelectedObj)
end

---
--- Removes the specified object or list of objects from the current selection.
---
--- If `obj` is a single valid object, it is removed from the selection.
--- If `obj` is a table, each valid object in the table is removed from the selection.
---
--- After removing the object(s), the selection is validated to remove any invalid objects.
---
--- @param obj table|any The object or list of objects to remove from the selection.
---
function SelectionRemove(obj)
	__remove(obj)
	if type(obj) == "table" then
		for i = 1, #obj do
			__remove(obj[i])
		end
	end
	SelectionValidate(SelectedObj)
end

---
--- Checks if the specified object is in the current selection.
---
--- @param obj any The object to check.
--- @return boolean True if the object is in the selection, false otherwise.
---
function IsInSelection(obj)
	return obj == SelectedObj or find(Selection, obj)
end

---
--- Sets the current selection to the specified list of objects.
---
--- If `list` is not provided, the selection is cleared.
--- If `list` is a single object, it is added to the selection.
--- If `list` is a table, the selection is set to the objects in the table.
---
--- After setting the selection, any objects that are no longer valid are removed from the selection.
---
--- @param list table|any The list of objects to set the selection to, or a single object to add to the selection.
--- @param obj any An optional object to validate the selection against.
---
function SelectionSet(list, obj)
	list = list or {}
	assert(not IsValid(list), "SelectionSet requires an array of objects")
	if type(list) ~= "table" then
		return
	end
	for i = 1, #list do
		__add(list[i])
	end
	for i = #Selection, 1, -1 do
		local obj = Selection[i]
		if not find(list, obj) then
			__remove(obj, i)
		end
	end
	SelectionValidate(obj or SelectedObj)
end

---
--- Validates the current selection, removing any objects that are no longer valid.
---
--- If `obj` is provided, it is used to validate the selection. Otherwise, `SelectedObj` is used.
---
--- @param obj any The object to validate the selection against.
---
function SelectionValidate(obj)
	if not Selection then return end
	local Selection = Selection
	for i = #Selection, 1, -1 do
		if not IsValid(Selection[i]) then
			__remove(Selection[i], i)
		end
	end
	SelectionSubSel(obj or SelectedObj)
end

---
--- Sets the current selection to the specified object, or clears the selection if no object is provided.
---
--- If `obj` is provided, it is added to the selection. If `obj` is not valid, the selection is cleared.
--- If `obj` is not provided, the selection is cleared.
---
--- After setting the selection, any objects that are no longer valid are removed from the selection.
---
--- @param obj any The object to set the selection to, or `nil` to clear the selection.
---
function SelectionSubSel(obj)
	obj = IsValid(obj) and find(Selection, obj) and obj or false
	__selobj(obj or #Selection == 1 and Selection[1])
end

--[[@@@
Select object in the game. Clear the current selection if no object is passed.
@function void Selection@SelectObj(object obj)
--]]

---
--- Selects the specified object and removes all other objects from the current selection.
---
--- If the provided `obj` is valid, it is added to the selection. All other objects in the selection are removed.
--- If `obj` is not provided or is not valid, the selection is cleared.
---
--- After setting the selection, the `__selobj` function is called with the new selection.
---
--- @param obj any The object to select, or `nil` to clear the selection.
---
function SelectObj(obj)
	obj = IsValid(obj) and obj or false
	for i = #Selection, 1, -1 do
		local o = Selection[i]
		if o ~= obj then
			__remove(o, i)
		end
	end
	local prev = SelectedObj --__add kills this
	__add(obj)
	__selobj(obj, prev)
end

--[[@@@
Select object in the game and points the camera towards it.
@function void Selection@ViewAndSelectObject(object obj)
--]]

---
--- Selects the specified object and points the camera towards it.
---
--- @param obj any The object to select and view.
---
function ViewAndSelectObject(obj)
	SelectObj(obj)
	ViewObject(obj)
end

--[[@@@
Gets the parent or another associated selectable object or the object itself
@function object Selection@SelectionPropagate(object obj)
@param object obj
--]]

function SelectionPropagate(obj)
	local topmost = GetTopmostSelectionNode(obj)
	local prev = topmost
	while IsValid(topmost) do
		topmost = topmost:SelectionPropagate() or topmost
		if prev == topmost then
			break
		end
		prev = topmost
	end
	return prev
end

AutoResolveMethods.SelectionPropagate = "or"

-- game-specific selection logic (lowest priority)
local sel_tbl = {}
local sel_idx = 0
---
--- Selects an object from the terrain at the specified point.
---
--- @param pt any The terrain point to select an object from.
--- @return object|nil The selected object, or nil if no object is found.
---
function SelectFromTerrainPoint(pt)
	Msg("SelectFromTerrainPoint", pt, sel_tbl)
	if #sel_tbl > 0 then
		sel_idx = (sel_idx + 1) % #sel_tbl
		local obj = sel_tbl[sel_idx + 1]
		sel_tbl = {}
		return obj
	end
end

--[[@@@
Gets the object that would be selected on the current mouse cursor position by default.
Also returns the original selected object without selection propagation.
@function object, object Selection@SelectionMouseObj()
--]]
function SelectionMouseObj()
	local solid, transparent = GetPreciseCursorObj()
	local obj = transparent or solid or SelectFromTerrainPoint(GetTerrainCursor()) or GetTerrainCursorObjSel()
	return SelectionPropagate(obj)
end

--[[@@@
Gets the object that would be selected on the current gamepad position by default.
Also returns the original selected object without selection propagation.
@function object, object Selection@SelectionGamepadObj()
--]]
function SelectionGamepadObj(gamepad_pos)
	local gamepad_pos = gamepad_pos or UIL.GetScreenSize() / 2
	local obj = GetTerrainCursorObjSel(gamepad_pos)
	
	if obj then
		return SelectionPropagate(obj)
	end
	
	if config.GamepadSearchRadius then
		local xpos = GetTerrainCursorXY(gamepad_pos)
		if not xpos or xpos == InvalidPos() or not terrain.IsPointInBounds(xpos) then
			return
		end

		local obj = MapFindNearest(xpos, xpos, config.GamepadSearchRadius, "CObject", const.efSelectable)
		if obj then
			return SelectionPropagate(obj)
		end
	end
end

--Determines the selection class of an object.
---
--- Determines the selection class of an object.
---
--- @param obj object The object to get the selection class for.
--- @return string|nil The selection class of the object, or nil if the object does not have a selection class.
---
function GetSelectionClass(obj)
	if not obj then return end
	
	if IsKindOf(obj, "PropertyObject") and obj:HasMember("SelectionClass") then
		return obj.SelectionClass
	else
		--return obj.class
	end
end

---
--- Gathers all objects on the screen that match the specified selection class.
---
--- @param obj object The object to use as the basis for the selection class. If not provided, the currently selected object will be used.
--- @param selection_class string The selection class to filter the objects by. If not provided, the selection class of the basis object will be used.
--- @return table A table of all objects on the screen that match the specified selection class.
---
function GatherObjectsOnScreen(obj, selection_class)
	obj = obj or SelectedObj
	if not IsValid(obj) then return end
	
	selection_class = selection_class or GetSelectionClass(obj)
	if not selection_class then return end

	local result = GatherObjectsInScreenRect(point20, point(GetResolution()), selection_class)
	if not find(result, obj) then
		table.insert(result, obj)
	end
	
	return result
end

---
--- Converts a screen space rectangle to a terrain space rectangle.
---
--- @param start_pt point The starting point of the screen space rectangle.
--- @param end_pt point The ending point of the screen space rectangle.
--- @return point, point, point, point The top-left, top-right, bottom-left, and bottom-right points of the terrain space rectangle.
---
function ScreenRectToTerrainPoints(start_pt, end_pt)
	local start_x, start_y = start_pt:xy()
	local end_x, end_y = end_pt:xy()
	
	--screen space
	local ss_left =   Min(start_x, end_x)
	local ss_right =  Max(start_x, end_x)
	local ss_top =    Min(start_y, end_y)
	local ss_bottom = Max(start_y, end_y)
	
	--world space
	local top_left =     GetTerrainCursorXY(ss_left,  ss_top)
	local top_right =    GetTerrainCursorXY(ss_right, ss_top)
	local bottom_left =  GetTerrainCursorXY(ss_right, ss_bottom)
	local bottom_right = GetTerrainCursorXY(ss_left,  ss_bottom)
	
	return top_left, top_right, bottom_left, bottom_right
end

---
--- Gathers all objects on the screen that match the specified selection class.
---
--- @param start_pos point The starting point of the screen space rectangle.
--- @param end_pos point The ending point of the screen space rectangle.
--- @param selection_class string The selection class to filter the objects by. If not provided, the selection class of the basis object will be used.
--- @param max_step number The maximum step size to extend the terrain rectangle by.
--- @param enum_flags number The enumeration flags to use when gathering objects.
--- @param filter_func function An optional filter function to apply to the gathered objects.
--- @return table A table of all objects on the screen that match the specified selection class.
---
function GatherObjectsInScreenRect(start_pos, end_pos, selection_class, max_step, enum_flags, filter_func)
	enum_flags = enum_flags or const.efSelectable
	
	local rect = Extend(empty_box, ScreenRectToTerrainPoints(start_pos, end_pos)):grow(max_step or 0)
	local screen_rect = boxdiag(start_pos, end_pos)
	
	local function filter(obj) 
		local _, pos = GameToScreen(obj)
		if not screen_rect:Point2DInside(pos) then return false end
		if not filter_func then return true end
		return filter_func(obj)
	end
	
	return MapGet(rect, selection_class or "Object", enum_flags, filter) or {}
end

---
--- Gathers all objects on the screen that match the specified selection class and are inside the given terrain rectangle.
---
--- @param top_left point The top-left point of the terrain rectangle.
--- @param top_right point The top-right point of the terrain rectangle.
--- @param bottom_left point The bottom-left point of the terrain rectangle.
--- @param bottom_right point The bottom-right point of the terrain rectangle.
--- @param selection_class string The selection class to filter the objects by. If not provided, the selection class of the basis object will be used.
--- @param enum_flags number The enumeration flags to use when gathering objects.
--- @param filter_func function An optional filter function to apply to the gathered objects.
--- @return table A table of all objects on the screen that match the specified selection class and are inside the given terrain rectangle.
---
function GatherObjectsInRect(top_left, top_right, bottom_left, bottom_right, selection_class, enum_flags, filter_func)
	enum_flags = enum_flags or const.efSelectable
	
	local left =   Min(top_left:x(), top_right:x(), bottom_left:x(), bottom_right:x())
	local right =  Max(top_left:x(), top_right:x(), bottom_left:x(), bottom_right:x())
	local top =    Min(top_left:y(), top_right:y(), bottom_left:y(), bottom_right:y())
	local bottom = Max(top_left:y(), top_right:y(), bottom_left:y(), bottom_right:y())
	
	local max_step = 12 * guim --PATH_EXEC_STEP
	top = top - max_step
	left = left - max_step
	bottom = bottom + max_step
	right = right + max_step
	
	local rect = box(left, top, right, bottom)
	local function IsInsideTrapeze(pt)
		return
			IsInsideTriangle(pt, top_left, bottom_right, bottom_left) or
			IsInsideTriangle(pt, top_left, bottom_right, top_right)
	end
	
	local function filter(obj)
		local pos = obj:GetVisualPos()
		if pos:z() ~= terrain.GetHeight(pos:x(), pos:y()) then
			local _, p = GameToScreen(pos)
			pos = GetTerrainCursorXY(p)
		end
		if not IsInsideTrapeze(pos) then return false end
		if filter_func then
			return filter_func(obj)
		end
		return true
	end
	
	return MapGet(rect, selection_class or "Object", enum_flags, filter) or {}
end

function OnMsg.GatherFXActions(list)
	list[#list + 1] = "Select"
	list[#list + 1] = "SelectObj"
end
	
--- Called when a bug report is started. Prints information about the currently selected object.
---
--- @param print_func function The function to use for printing the bug report information.
function OnMsg.BugReportStart(print_func)
	print_func("\nSelected Obj:", SelectedObj and ValueToStr(SelectedObj) or "false")
	local code = GetObjRefCode(SelectedObj)
	if code then
		print_func("Paste in the console: SelectObj(", code, ")\n")
	end
end
