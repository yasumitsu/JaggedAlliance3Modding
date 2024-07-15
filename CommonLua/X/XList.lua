DefineClass.XList = {
	__parents = { "XScrollArea" },
	
	properties = {
		{ category = "General", id = "MultipleSelection", editor = "bool", default = false, },
		{ category = "General", id = "LeftThumbScroll", editor = "bool", default = true, },
		{ category = "General", id = "GamepadInitialSelection", Name = "Gamepad Initial Selection", editor = "bool", default = true, },
		{ category = "General", id = "CycleSelection", Name = "Cycle selection", editor = "bool", default = false, },
		{ category = "General", id = "ForceInitialSelection", editor = "bool", default = false, },
		{ category = "General", id = "SetFocusOnOpen", editor = "bool", default = false, },
		{ category = "General", id = "WorkUnfocused", editor = "bool", default = false, },
		
		{ category = "Actions", id = "ActionContext", editor = "text", default = "", },
		{ category = "Actions", id = "ItemActionContext", editor = "text", default = "", },

		{ category = "Visual", id = "MaxRowsVisible", editor = "number", default = 0, invalidate = "measure" },

		{ category = "Interaction", id = "OnSelection", editor = "func", params = "self, focused_item, selection", },
		{ category = "Interaction", id = "OnDoubleClick", editor = "func", params = "self, item_idx", },
	},
	
	Clip = "parent & self",
	LayoutMethod = "VList",
	Padding = box(2, 2, 2, 2),
	BorderWidth = 1,
	BorderColor = RGB(32, 32, 32),
	Background = RGB(255, 255, 255),
	FocusedBackground = RGB(255, 255, 255),
	
	focused_item = false,
	selection = false, -- table
	item_hashes = false, -- table, used when the LayoutMethod is Grid
	docked_win_count = 0, -- these must be the last children, and are not considered list items (usually scrollbars)
	force_keep_items_spawned = false,
}


----- helpers

local function IsItemSelectable(child)
	return (not child:HasMember("IsSelectable") or child:IsSelectable()) and child:GetVisible()
end

local function SetItemSelected(child, selected)
	if not child or not child:HasMember("SetSelected") then
		return
	end
	child:SetSelected(selected)
end

local function SetItemFocused(child, focused)
	if not child or not child:HasMember("SetFocused") then
		return
	end
	child:SetFocused(focused)
end


----- general methods

--- Initializes the selection table for the XList object.
---
--- @param self XList The XList object being initialized.
--- @param parent any The parent object of the XList.
--- @param context any The context object for the XList.
function XList:Init(parent, context)
	self.selection = {}
end

---
--- Opens the XList and generates the item hash table if the layout method is Grid. Also creates a thread to set the initial selection.
---
--- @param self XList The XList object being opened.
--- @param ... any Additional arguments passed to the XScrollArea.Open function.
---
function XList:Open(...)
	self:GenerateItemHashTable()
	XScrollArea.Open(self, ...)
	self:CreateThread("SetInitialSelection", self.SetInitialSelection, self)
end

---
--- Clears the XList object, removing all non-docked child windows and resetting the focused item and selection.
---
--- @param self XList The XList object being cleared.
function XList:Clear()
	self.focused_item = false
	self.selection = {}
	for i = #self, 1, -1 do
		local win = self[i]
		if not win.Dock or win.Dock == "ignore" then
			win:delete()
		end
	end
	XScrollArea.Clear(self, "keep_children")
end

-- Counts docked child windows (usually scrollbars), and makes sure they are at the end of the children list
---
--- Sorts the child windows of the XList object, ensuring that docked windows are at the end of the list.
---
--- @param self XList The XList object whose children are being sorted.
--- @return boolean True if the sort was successful, false otherwise.
function XList:SortChildren()
	local docked = 0
	for _, win in ipairs(self) do
		if win.Dock and win.Dock ~= "ignore" then
			docked = docked + 1
			win.ZOrder = max_int
		end
	end
	self.docked_win_count = docked
	return XWindow.SortChildren(self)
end

---
--- Returns the number of items in the XList, excluding any docked child windows.
---
--- @return integer The number of items in the XList.
function XList:GetItemCount()
	return #self - self.docked_win_count
end

---
--- Generates a hash table of item indices based on their grid positions.
---
--- This function is used when the XList is using a "Grid" layout. It iterates over all the child windows
--- of the XList, and for each one, it generates a hash table mapping the grid coordinates to the index
--- of the child window in the XList.
---
--- This allows for efficient lookup of items based on their grid position, which is useful for
--- implementing features like scrolling and selection.
---
--- @param self XList The XList object whose items are being hashed.
function XList:GenerateItemHashTable()
	if self.LayoutMethod == "Grid" and self:GetItemCount() > 0 then
		self.item_hashes = {}
		for i, v in ipairs(self) do
			local x, y = v.GridX, v.GridY
			for j = x, x + v.GridWidth - 1 do
				for k = y, y + v.GridHeight - 1 do
					self.item_hashes[j .. k] = i
				end
			end
		end
	end
end

---
--- Creates a new XListItem with the given text and properties.
---
--- @param text string The text to display in the list item.
--- @param props table An optional table of properties to apply to the list item.
--- @param context any An optional context object to pass to the list item.
--- @return XListItem The new list item.
function XList:CreateTextItem(text, props, context)
	props = props or {}
	local item = XListItem:new({ selectable = props.selectable }, self)
	props.selectable = nil
	local text_control = XText:new(props, item, context)
	text_control:SetText(text)
	return item
end

---
--- Returns the index of the XListItem at the given screen point.
---
--- If `allow_outside_items` is true, this function will return the index of the item even if the point is outside the item's bounds.
--- Otherwise, it will only return the index if the point is within the item's bounds.
---
--- @param pt table The screen point to check, in the format `{x = x, y = y}`.
--- @param allow_outside_items boolean If true, the function will return the index even if the point is outside the item's bounds.
--- @return integer|false The index of the XListItem at the given point, or false if no item is found.
function XList:GetItemAt(pt, allow_outside_items)
	local target = false
	local method = allow_outside_items and "PointInWindow" or "MouseInWindow"
	for idx, win in ipairs(self) do
		if (not target or win.DrawOnTop) and win[method](win, pt) then
			target = idx
			if self.LayoutMethod ~= "HOverlappingList" and self.LayoutMethod ~= "VOverlappingList" then
				return target
			end
		end
	end
	return target
end

---
--- Measures the size of the XList control based on the maximum width and height provided.
---
--- If the `MaxRowsVisible` property is set to a positive value, and there are items in the list,
--- the height of the control will be limited to the height of the first item multiplied by the
--- `MaxRowsVisible` value. This is only applicable when the `LayoutMethod` is set to "VList" or "HWrap".
---
--- @param max_width number The maximum width available for the control.
--- @param max_height number The maximum height available for the control.
--- @return number, number The measured width and height of the control.
function XList:Measure(max_width, max_height)
	local width, height = XScrollArea.Measure(self, max_width, max_height)
	local elements = self:GetItemCount()
	if self.MaxRowsVisible > 0 and elements > 0 then
		assert(self.LayoutMethod == "VList" or self.LayoutMethod == "HWrap")
		height = Min(height, self[1].measure_height * self.MaxRowsVisible)
	end
	return width, height
end

----- mouse/keyboard/controller

---
--- Handles the mouse button down event for the XList control.
---
--- This function is responsible for setting the focus, handling item selection, and opening context menus when the user clicks on the list.
---
--- @param pt table The screen point where the mouse button was pressed, in the format `{x = x, y = y}`.
--- @param button string The mouse button that was pressed, either "L" for left or "R" for right.
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
function XList:OnMouseButtonDown(pt, button)
	local target = self:GetItemAt(pt)
	if button == "L" then
		if not self.WorkUnfocused then
			self:SetFocus(true)
		end
		if not target or not IsItemSelectable(self[target]) then
			return "break"
		end
		
		self:OnItemClicked(target, button)
		
		local shift = terminal.IsKeyPressed(const.vkShift)
		local ctrl = terminal.IsKeyPressed(const.vkControl)
		if not self.MultipleSelection or not (shift or ctrl) then
			self:SetSelection(target)
		elseif ctrl then
			self:ToggleSelected(target)
		elseif shift then
			self:SelectRange(self.focused_item or target, target)
		end

		if self.MultipleSelection then
			self.desktop:SetMouseCapture(self)
		end
		return "break"
	elseif button == "R" then 
		if not self.WorkUnfocused then
			self:SetFocus(true)
		end
		local action_context = self.ItemActionContext
		if not target or not IsItemSelectable(self[target]) then
			action_context = self.ActionContext
		end
		local host = GetActionsHost(self, true)
		if host and host:OpenContextMenu(action_context, pt) then
			if target and IsItemSelectable(self[target]) and (not self.MultipleSelection or (not self:HasMember("selected")) or (#self.selected < 2)) then
				self:SetSelection(target)
			end
		end
		self:OnItemClicked(target, button)
		return "break"
	end
end

--- Handles double-click events on the list.
---
--- If the left mouse button is clicked without any modifier keys (Shift or Ctrl) and the list has a focused item, this function calls the `OnDoubleClick` method with the focused item as the argument.
---
--- @param pt table The screen point where the mouse button was double-clicked, in the format `{x = x, y = y}`.
--- @param button string The mouse button that was double-clicked, either "L" for left or "R" for right.
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
function XList:OnMouseButtonDoubleClick(pt, button)
	local shift = terminal.IsKeyPressed(const.vkShift)
	local ctrl = terminal.IsKeyPressed(const.vkControl)
	if button == "L" and not shift and not ctrl and self.focused_item then
		self:OnDoubleClick(self.focused_item)
		return "break"
	end
end

--- Handles mouse position events on the list.
---
--- If the list has the mouse capture and a focused item, this function selects the range of items from the focused item to the item at the given screen point, if the item at the point is selectable.
---
--- @param pt table The screen point where the mouse cursor is located, in the format `{x = x, y = y}`.
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
function XList:OnMousePos(pt)
	if self.desktop:GetMouseCapture() == self and self.focused_item then
		local target = self:GetItemAt(pt)
		if target and IsItemSelectable(self[target]) then
			self:SelectRange(self.focused_item, target)
		end
		return "break"
	end
end

--- Handles the mouse button up event on the list.
---
--- If the left mouse button is released, this function releases the mouse capture of the desktop.
---
--- @param pt table The screen point where the mouse button was released, in the format `{x = x, y = y}`.
--- @param button string The mouse button that was released, either "L" for left or "R" for right.
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
function XList:OnMouseButtonUp(pt, button)
	if button == "L" then
		self.desktop:SetMouseCapture()
		return "break"
	end
end

--- Handles keyboard shortcuts for the list.
---
--- This function is called when a keyboard shortcut is detected for the list. It handles various shortcut actions, such as navigating through the list items, selecting items, and toggling multiple selection.
---
--- @param shortcut string The keyboard shortcut that was detected.
--- @param source string The source of the shortcut, either "keyboard" or "controller".
--- @param ... any Additional arguments passed with the shortcut.
--- @return string "break" to indicate that the event has been handled and should not be propagated further.
function XList:OnShortcut(shortcut, source, ...)
	local target, arrow_key = nil, nil
	shortcut = string.gsub(shortcut, "Shift%-", "") -- ignore shift
	if (self.LayoutMethod == "HList" or self.LayoutMethod == "HOverlappingList" or self.LayoutMethod == "HWrap") and (shortcut == "Left" or shortcut == "Ctrl-Left") or
		(self.LayoutMethod == "VList" or self.LayoutMethod == "VOverlappingList" or self.LayoutMethod == "VWrap") and (shortcut == "Up" or shortcut == "Ctrl-Up")
	then
		target, arrow_key = self:NextSelectableItem(self.focused_item, -1, -1), true
	elseif (self.LayoutMethod == "HList" or self.LayoutMethod == "HOverlappingList" or self.LayoutMethod == "HWrap") and (shortcut == "Right" or shortcut == "Ctrl-Right") or
		(self.LayoutMethod == "VList" or self.LayoutMethod == "VOverlappingList" or self.LayoutMethod == "VWrap") and (shortcut == "Down" or shortcut == "Ctrl-Down")
	then
		target, arrow_key = self:NextSelectableItem(self.focused_item, 1, 1), true
	elseif self.LayoutMethod == "Grid" and (shortcut == "Left" or shortcut == "Right" or shortcut == "Up" or shortcut == "Down" or
							shortcut == "Ctrl-Left" or shortcut == "Ctrl-Right" or shortcut == "Ctrl-Up" or shortcut == "Ctrl-Down") then
		target, arrow_key = self:NextGridItem(self.focused_item, shortcut), true
	elseif shortcut == "Home" or shortcut == "Ctrl-Home" then
		target = self:NextSelectableItem(1, 0, 1)
	elseif shortcut == "End" or shortcut == "Ctrl-End" then
		target = self:NextSelectableItem(self:GetItemCount(), 0, -1)
	elseif shortcut == "Pageup" then
		if self.focused_item then
			local offset = (self.LayoutMethod == "VList" or self.LayoutMethod == "VOverlappingList" or self.LayoutMethod == "VWrap") and point(0, self.content_box:sizey()) or point(self.content_box:sizex(), 0)
			local child = self[self.focused_item]
			target = self:GetItemAt(child.content_box:Center() - offset, "allow_outside_items")
		end
		target = target or self:NextSelectableItem(1, 0, 1)
	elseif shortcut == "Pagedown" then
		if self.focused_item then
			local offset = (self.LayoutMethod == "VList" or self.LayoutMethod == "VOverlappingList" or self.LayoutMethod == "VWrap") and point(0, self.content_box:sizey()) or point(self.content_box:sizex(), 0)
			local child = self[self.focused_item]
			target = self:GetItemAt(child.content_box:Center() + offset, "allow_outside_items")
		end
		target = target or self:NextSelectableItem(self:GetItemCount(), 0, -1)
	elseif self.MultipleSelection and (shortcut == "Space" or shortcut == "Ctrl-Space") then
		if self.focused_item then
			self:ToggleSelected(self.focused_item)
		end
		return "break"
	elseif self.MultipleSelection and shortcut == "Ctrl-A" then
		self:SelectAll()
		return "break"
	end
	
	if target ~= nil then
		if target then
			if arrow_key and terminal.IsKeyPressed(const.vkControl) and self.MultipleSelection then
				self:SetFocusedItem(target)
			elseif terminal.IsKeyPressed(const.vkShift) and self.MultipleSelection then
				self:SelectRange(self.focused_item, target)
			else
				self:SetSelection(target)
			end
		end
		return "break"
	end
	
	if shortcut == "DPadUp" or (shortcut == "LeftThumbUp" and self.LeftThumbScroll) then
		return self:OnShortcut("Up", "keyboard", ...)
	elseif shortcut == "DPadDown" or (shortcut == "LeftThumbDown" and self.LeftThumbScroll) then
		return self:OnShortcut("Down", "keyboard", ...)
	elseif shortcut == "DPadLeft" or ((shortcut == "LeftThumbLeft" or shortcut == "LeftThumbDownLeft" or shortcut == "LeftThumbUpLeft") and self.LeftThumbScroll) then
		return self:OnShortcut("Left", "keyboard", ...)
	elseif shortcut == "DPadRight" or ((shortcut == "LeftThumbRight" or shortcut == "LeftThumbDownRight" or shortcut == "LeftThumbUpRight") and self.LeftThumbScroll) then
		return self:OnShortcut("Right", "keyboard", ...)
	elseif shortcut == "ButtonA" then
		return self:OnShortcut("Space", "keyboard", ...)
	end
end

---
--- Finds the next selectable item in the XList, starting from the given item and moving in the specified direction.
---
--- @param item number|nil The index of the item to start from, or `nil` to start from the first valid item.
--- @param offset number The offset from the starting item to move.
--- @param step number The step size, either 1 or -1, to move in the specified direction.
--- @return number|false The index of the next selectable item, or `false` if no selectable item is found.
function XList:NextSelectableItem(item, offset, step)
	local item_count = self:GetItemCount()
	if not item then
		return item_count > 0 and self:GetFirstValidItemIdx() or false
	end
	
	local i = item + offset
	while i > 0 and i <= item_count and not IsItemSelectable(self[i]) do
		i = i + step
	end
	if self.CycleSelection then
		if i <= 0 then
			i = item_count
		elseif i > item_count then
			i = 1
		end
	end
	while i > 0 and i <= item_count and not IsItemSelectable(self[i]) do
		i = i + step
	end
	return i > 0 and i <= item_count and i or false
end

---
--- Finds the next selectable item in the grid layout of the XList, starting from the given item and moving in the specified direction.
---
--- @param item number|nil The index of the item to start from, or `nil` to start from the first valid item.
--- @param dir string The direction to move, one of "Left", "Right", "Up", or "Down".
--- @return number|false The index of the next selectable item, or `false` if no selectable item is found.
function XList:NextGridItem(item, dir)
	local item_count = self:GetItemCount()
	if not item then
		return item_count > 0 and 1 or false
	end
	
	local current = self[item]
	local x, y = current.GridX, current.GridY
	if dir == "Left" then
		x = x - 1
	elseif dir == "Right" then
		x = x + (current.GridWidth - 1) + 1
	elseif dir == "Up" then
		y = y - 1
	elseif dir == "Down" then
		y = y + (current.GridHeight - 1) + 1
	end
	if x > 0 and y > 0 then
		local i = self.item_hashes[x .. y]
		-- find the first selectable item on the desired row
		while not i and x > 1 do
			x = x - 1
			i = self.item_hashes[x .. y]
		end
		while i and i > 0 and i <= item_count and not IsItemSelectable(self[i]) do
			i = self:NextGridItem(i, dir)
		end
		return i and i > 0 and i <= item_count and i or false
	end
end


----- focus (focused item is also used as single selection)

---
--- Returns the index of the currently focused item in the XList.
---
--- @return number|false The index of the focused item, or `false` if no item is focused.
function XList:GetFocusedItem()
	return self.focused_item
end

---
--- Returns the scroll target for the XList.
---
--- @return table The scroll target for the XList.
function XList:GetScrollTarget()
	return self
end

---
--- Sets the focused item in the XList.
---
--- @param new_focused number|false The index of the new focused item, or `false` to clear the focus.
function XList:SetFocusedItem(new_focused)
	if new_focused ~= self.focused_item then
		local old_focused = self.focused_item
		if old_focused then
			SetItemFocused(self[old_focused], false)
		end
		if new_focused then
			-- For potential virtual items, spawn a "sufficient quantity" of items between the last and the new
			-- focused item, so we can update the layout correctly - this is required for ScrollIntoView below
			if self.window_state == "open" and not self.content_box:IsEmpty() then
				local first, last = old_focused or 1, new_focused
				local step = first > new_focused and -1 or 1
				local from = Clamp(first + step, last - 100*step, last + 100*step) -- assume page size with no more than 100 items
				for idx = from, last, step do
					local item = self[idx]
					if item:HasMember("SetSpawned") then
						item:SetSpawned(true)
					end
				end
				
				local box = self.desktop.box
				self.desktop:UpdateMeasure(box:sizex(), box:sizey())
				self.force_keep_items_spawned = true -- prevent UpdateLayout below from despawning children outside of the list
				self:UpdateLayout()
				self.force_keep_items_spawned = false
			end
			
			local child = self[new_focused]
			self:GetScrollTarget():ScrollIntoView(child)
			local focus = self.desktop:GetKeyboardFocus()
			SetItemFocused(child, self.WorkUnfocused or (focus and focus:IsWithin(self)))
		end
		self.focused_item = new_focused
	end
end

---
--- Called when the XList gains focus. Sets the focused item in the XList to be visually focused.
---
function XList:OnSetFocus()
	if self.focused_item then
		SetItemFocused(self[self.focused_item], true)
	end
end

---
--- Called when the XList loses focus. Sets the focused item in the XList to be visually unfocused.
---
function XList:OnKillFocus()
	if self.focused_item then
		SetItemFocused(self[self.focused_item], false)
	end
end


----- selection

---
--- Deletes all children of the XList and resets the focused item and selection.
---
function XList:DeleteChildren()
	self.focused_item = false
	self.selection = {}
	XWindow.DeleteChildren(self)
end

---
--- Called when a child is leaving the XList. Removes the child from the selection and remaps the selection indexes.
---
--- @param child XWindow The child window that is leaving.
--- @return integer The index of the child that was removed.
---
function XList:ChildLeaving(child)
	-- keep selection valid by removing the entry and remapping the indexes
	local idx = XWindow.ChildLeaving(self, child)
	local selection = self.selection
	if #selection > 0 then
		table.remove_entry(selection, idx)
		for i, sel_idx in ipairs(selection) do
			if sel_idx > idx then
				self.selection[i] = sel_idx - 1
			end
		end
	end
end

---
--- Toggles the selection state of the specified item in the XList.
---
--- If the item is currently selected, it will be deselected. If the item is not selected, it will be selected.
---
--- The focused item in the XList will also be set to the specified item.
---
--- @param item integer The index of the item to toggle the selection state for.
---
function XList:ToggleSelected(item)
	local selection = self.selection
	local idx = table.find(selection, item)
	if idx then
		table.remove(selection, idx)
		SetItemSelected(self[item], false)
	else
		table.insert(selection, item)
		SetItemSelected(self[item], true)
	end
	self:SetFocusedItem(item)
	self:OnSelection(item, selection)
end

---
--- Scrolls the XList to ensure that all selected items are visible.
---
--- This function iterates through the list of selected items and calls `XList:ScrollIntoView()` for each one, ensuring that the selected items are scrolled into view.
---
--- @function XList:ScrollSelectionIntoView
--- @return nil
function XList:ScrollSelectionIntoView()
	for _, item in ipairs(self.selection) do
		if self[item] then
			self:ScrollIntoView(self[item])
		end
	end
end

---
--- Sets the content box of the XList.
---
--- If the content box changes, this function will scroll the selection into view.
---
--- @param ... any Arguments to pass to `XScrollArea.SetBox()`
--- @return nil
function XList:SetBox(...)
	local old_box = self.content_box
	XScrollArea.SetBox(self, ...)
	if old_box ~= self.content_box then
		self:ScrollSelectionIntoView()
	end
end

---
--- Selects a range of items in the XList.
---
--- This function iterates through the range of items specified by `from` and `to`, and adds any selectable items to the selection. The focused item is set to the `to` index.
---
--- @param from integer The starting index of the range to select.
--- @param to integer The ending index of the range to select.
--- @return nil
function XList:SelectRange(from, to)
	local selection = self.selection
	if from < to then
		for i = from, to do
			local child = self[i]
			if IsItemSelectable(child) and not table.find(selection, i) then
				table.insert(selection, i)
				SetItemSelected(child, true)
			end
		end
	else
		for i = to, from do
			local child = self[i]
			if IsItemSelectable(child) and not table.find(selection, i) then
				table.insert(selection, i)
				SetItemSelected(child, true)
			end
		end
	end
	self:SetFocusedItem(to)
	self:OnSelection(to, selection)
end

---
--- Returns the current selection of the XList.
---
--- @return table The current selection of the XList.
function XList:GetSelection()
	return self.selection
end

---
--- Sets the selection of the XList.
---
--- This function clears the current selection, validates the new selection, and updates the focused item and selection state accordingly.
---
--- @param selection number|table The new selection. Can be a single index or a table of indices.
--- @param notify boolean (optional) Whether to notify listeners of the selection change. Defaults to true.
--- @return nil
function XList:SetSelection(selection, notify)
	for _, item in ipairs(self.selection) do
		SetItemSelected(self[item], false)
	end
	
	-- validate selection
	local item_count = self:GetItemCount()
	if type(selection) == "number" then
		if selection < 1 or selection > item_count or not IsItemSelectable(self[selection]) then
			selection = false
		end
	elseif type(selection) == "table" then
		selection = table.ifilter(selection, function(idx, value)
			return value >= 1 and value <= item_count and IsItemSelectable(self[value])
		end)
	end

	if not selection then
		self.selection = {}
		self:SetFocusedItem(false)
	elseif type(selection) == "number" then
		self.selection = { selection }
		self:SetFocusedItem(selection)
		SetItemSelected(self[selection], true)
	else
		assert(type(selection) == "table")
		self.selection = selection
		self:SetFocusedItem(selection[1] or false)
		for _, item in ipairs(selection) do
			SetItemSelected(self[item], true)
		end
	end
	
	if notify ~= false then
		self:OnSelection(self.focused_item, self.selection)
	end
end

---
--- Sets the initial selection of the XList.
---
--- This function checks if the provided selection is valid, and if so, sets it as the current selection.
--- If the selection is not valid, it will attempt to select the first valid item, or set the selection to the first item if all are disabled.
--- If the `ForceInitialSelection` or `GamepadInitialSelection` properties are set, it will always try to select the first valid item.
--- If the `SetFocusOnOpen` property is set, it will set the focus on the XList when opened.
---
--- @param selection number The index of the item to select initially.
--- @param force_ui_style boolean (optional) Whether to force the gamepad UI style.
--- @return nil
function XList:SetInitialSelection(selection, force_ui_style)
	if selection then
		local item = selection and self[selection]
		if item and item:GetEnabled() and IsItemSelectable(item) then
			self:SetSelection(selection)
			return
		end
	end
	if self.ForceInitialSelection or (self.GamepadInitialSelection and (GetUIStyleGamepad() or force_ui_style)) then
		if not self:SelectFirstValidItem() then
			self:SetSelection(1) -- if all are disabled
		end
	elseif self.SetFocusOnOpen then
		self:SetFocus(true)
	end
end

---
--- Gets the index of the first valid item in the XList.
---
--- Iterates through the items in the XList and returns the index of the first item that is enabled and selectable.
---
--- @return number|nil The index of the first valid item, or nil if no valid items are found.
function XList:GetFirstValidItemIdx()
	for idx, item in ipairs(self) do
		if item:GetEnabled() and IsItemSelectable(item) then
			return idx
		end
	end
end

---
--- Selects the first valid item in the XList.
---
--- Iterates through the items in the XList and selects the first item that is enabled and selectable.
---
--- @return boolean true if a valid item was selected, false otherwise
function XList:SelectFirstValidItem()
	local item_idx = self:GetFirstValidItemIdx()
	if item_idx then
		self:SetSelection(item_idx)
		return true
	end
end

---
--- Selects the last valid item in the XList.
---
--- Iterates through the items in the XList in reverse order and selects the first item that is enabled and selectable.
---
--- @return boolean true if a valid item was selected, false otherwise
function XList:SelectLastValidItem()
	for i = #self, 1, -1 do
		local item = self[i]
		if item:GetEnabled() and IsItemSelectable(item) then
			self:SetSelection(i)
			return true
		end
	end
end

---
--- Selects all items in the XList.
---
--- Iterates through all items in the XList and selects them.
---
--- @return nil
function XList:SelectAll()
	local item_count = self:GetItemCount()
	if item_count > 0 then
		self:SelectRange(item_count, 1)
	end
end

---
--- Called when the selection changes in the XList.
---
--- @param focused_item XListItem The item that is now focused.
--- @param selection table A table of selected items.
---
function XList:OnSelection(focused_item, selection)
end

---
--- Called when an item in the XList is double-clicked.
---
--- @param item_idx number The index of the item that was double-clicked.
---
function XList:OnDoubleClick(item_idx)
end

---
--- Called when an item in the XList is clicked.
---
--- @param target XListItem The item that was clicked.
--- @param button number The mouse button that was clicked (1 = left, 2 = right, 3 = middle).
---
function XList:OnItemClicked(target, button)
end

----- XListItem

DefineClass.XListItem = {
	__parents = { "XContextControl" },
	properties = {
		{ category = "Visual", id = "SelectionBackground", editor = "color", default = RGB(204, 232, 255), },
	},
	FocusedBorderColor = RGB(32, 32, 32),
	BorderColor = RGBA(0, 0, 0, 0),
	BorderWidth = 1,
	HandleMouse = false,
	
	selectable = true,
	selected = false,
	focused = false,
}

---
--- Determines if the XListItem is selectable.
---
--- @return boolean True if the XListItem is selectable, false otherwise.
---
function XListItem:IsSelectable()
	return self.selectable and self.Dock ~= "ignore"
end

---
--- Sets the selected state of the XListItem.
---
--- @param selected boolean The new selected state of the XListItem.
---
function XListItem:SetSelected(selected)
	if self.selected ~= selected then
		self.selected = selected
		self:Invalidate()
	end
end

---
--- Sets the focused state of the XListItem.
---
--- @param focused boolean The new focused state of the XListItem.
---
function XListItem:SetFocused(focused)
	if self.focused ~= focused then
		self.focused = focused
		self:Invalidate()
	end
end

---
--- Calculates the background color of the XListItem.
---
--- If the XListItem is selected, the background color is set to the `SelectionBackground` property.
--- Otherwise, the background color is calculated using the `XContextControl.CalcBackground` function.
---
--- @return color The calculated background color of the XListItem.
---
function XListItem:CalcBackground()
	if self.selected then
		return self.SelectionBackground
	end
	return XContextControl.CalcBackground(self)
end

---
--- Calculates the border color of the XListItem.
---
--- If the XListItem is enabled and focused, the border color is set to the `FocusedBorderColor` property.
--- Otherwise, the border color is calculated using the `XContextControl.CalcBorderColor` function.
---
--- @return color The calculated border color of the XListItem.
---
function XListItem:CalcBorderColor()
	if self.enabled and self.focused then
		return self.FocusedBorderColor
	end
	return XContextControl.CalcBorderColor(self)
end
