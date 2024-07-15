local max_o = 100
local function oname(n)
	return string.format("o%d", n)
end

DefineClass.DevDockPinsButton = {
	__parents = { "XTextButton" },
	IdNode = true,
	ChildrenHandleMouse = true,
	BorderWidth = 1,
	BorderColor = const.clrBlack,
	RolloverBorderColor = const.clrBlack,
	RolloverTemplate = "GedToolbarRollover",
	Translate = false,
	AltPress = true,
	
	plugin = false,
	selected = false,
}

---
--- Initializes a DevDockPinsButton instance.
---
--- @param parent table The parent object of the button.
--- @param context table The context object associated with the button.
---
function DevDockPinsButton:Init(parent, context)
	local o_label = XLabel:new({
		Id = "idOLabel",
		HAlign = "right",
		VAlign = "bottom",
		ScaleModifier = point(500, 500),
		Translate = false,
	}, self, self.context)
	function o_label:OnContextUpdate(context, update)
		local main_btn = self.parent
		local idx = main_btn:GetPinIndex(context)
		if idx then
			self:SetVisible(true)
			self:SetText(oname(idx))
		else
			self:SetVisible(false)
		end
	end
	
	local name = self.plugin:GetDisplayName(self.context)
	--find other buttons before me
	local n = 0
	for i,btn in ipairs(self.parent) do
		if btn == self then break end
		if btn.context.class == self.context.class then
			n = n + 1
		end
	end
	if n > 0 then
		name = string.format("%s %d", name, n + 1)
	end
	self:SetText(name)
end

---
--- Selects the object associated with the button when it is pressed.
---
--- @param gamepad boolean Whether the button was pressed on a gamepad.
---
function DevDockPinsButton:OnPress(gamepad)
	SelectObj(self.context)
end

---
--- Handles the double click event on the DevDockPinsButton.
--- When the button is double clicked, the associated object is viewed.
---
--- @param button number The mouse button that was double clicked.
--- @return string "break" to indicate the event has been handled.
---
function DevDockPinsButton:OnMouseButtonDoubleClick(button)
	ViewObject(self.context)
	return "break"
end

---
--- Toggles whether the button is pinned or not.
---
--- @param gamepad boolean Whether the button was pressed on a gamepad.
---
function DevDockPinsButton:OnAltPress(gamepad)
	self.plugin:SetPinned(self.context, not self:IsPinned())
end

---
--- Updates the context of the DevDockPinsButton.
---
--- If the context is no longer valid, or the context update is not "open" and the button is not selected or pinned, the button is closed.
---
--- @param context table The context associated with the button.
--- @param update string The type of update that occurred for the context.
---
function DevDockPinsButton:OnContextUpdate(context, update)
	if not IsValid(context) or (update ~= "open" and not self.selected and not self:IsPinned()) then
		self:Close()
	end
end

---
--- Checks if the OLabel associated with the DevDockPinsButton is visible.
---
--- @return boolean true if the OLabel is visible, false otherwise
---
function DevDockPinsButton:HasOLabel()
	return self:ResolveId("idOLabel"):GetVisible()
end

--- Gets the index of the pin associated with the DevDockPinsButton.
---
--- @return number The index of the pin associated with the DevDockPinsButton, or nil if the button is not pinned.
function DevDockPinsButton:GetPinIndex()
	return self.plugin:GetPinIndex(self.context)
end

---
--- Checks if the DevDockPinsButton is pinned.
---
--- @return boolean true if the button is pinned, false otherwise
---
function DevDockPinsButton:IsPinned()
	return not not self:GetPinIndex()
end

---
--- Sets the selected state of the DevDockPinsButton.
---
--- If the button is not selected and not pinned, the button is closed. Otherwise, the button's highlighted state is set based on the selected parameter.
---
--- @param selected boolean Whether the button is selected or not.
---
function DevDockPinsButton:SetSelected(selected)
	self.selected = selected
	if not selected and not self:IsPinned() then
		self:Close()
	else
		self:SetHighlighted(selected)
	end
end

---
--- Sets the highlighted state of the DevDockPinsButton.
---
--- @param highlighted boolean Whether the button should be highlighted or not.
---
function DevDockPinsButton:SetHighlighted(highlighted)
	local color = highlighted and RGB(120,120,255) or const.clrBlack
	self:SetBorderColor(color)
	self:SetRolloverBorderColor(color)
end

----

DefineClass.DevDockPinsPlugin = {
	__parents = { "DevDockPlugin" },
	LayoutMethod = "HList",
	my_pins = false, --list of indices pinned by the dlg
}

---
--- Checks if the current game interface is valid.
---
--- @return boolean true if the game interface is valid, false otherwise
---
function DevDockPinsPlugin.IsValid()
	return GetInGameInterface()
end

---
--- Initializes the DevDockPinsPlugin.
---
--- This function sets up the `my_pins` table to store the indices of pinned objects, and creates a thread to handle the plugin's logic.
---
function DevDockPinsPlugin:Init()
	self.my_pins = {}
    self:CreateThread("o_thread", self.OThreadProc, self)
end

---
--- Deletes all pinned objects from the global namespace.
---
--- This function is called when the DevDockPinsPlugin is deleted. It iterates over the `self.my_pins` table, which contains the indices of all pinned objects, and removes the corresponding global variables.
---
--- @param result any The result of the deletion operation.
--- @param ... any Additional arguments passed to the deletion operation.
---
function DevDockPinsPlugin:OnDelete(result, ...)
	for idx in pairs(self.my_pins) do
		local varname = oname(idx)
		rawset(_G, varname, nil)
	end
end

---
--- Gets the display name for the given object.
---
--- If the object is a `Human`, the display name is the object's `FirstName` translated using `_InternalTranslate`.
--- Otherwise, the display name is the object's class name.
---
--- @param obj any The object to get the display name for.
--- @return string The display name for the object.
---
function DevDockPinsPlugin:GetDisplayName(obj)
	if IsKindOf(obj, "Human") then
		return _InternalTranslate(obj.FirstName)
	else
		return obj.class
	end
end

---
--- Gets the index of the pinned object.
---
--- @param obj any The object to get the pin index for.
--- @return number The index of the pinned object, or nil if the object is not pinned.
---
function DevDockPinsPlugin:GetPinIndex(obj)
	return OPinsGetIndex(obj)
end

---
--- Gets the next available pin index.
---
--- This function calls `OPinsGetNextIndex()` to retrieve the next available pin index. It is used to assign a unique index to a new pinned object.
---
--- @return number The next available pin index.
---
function DevDockPinsPlugin:GetNextPinIndex()
	return OPinsGetNextIndex()
end

---
--- Sets the pinned state of the given object.
---
--- If the object is pinned, the function adds the object's index to the `self.my_pins` table. If the object is unpinned, the function removes the object's index from the `self.my_pins` table.
---
--- @param obj any The object to set the pinned state for.
--- @param pinned boolean Whether the object should be pinned or unpinned.
--- @return number The index of the pinned object.
---
function DevDockPinsPlugin:SetPinned(obj, pinned)
	local idx = OPinsSet(obj, pinned)
	if pinned then
		self.my_pins[idx] = true
	else
		self.my_pins[idx] = nil
	end
end

--- Toggles the pinned state of the given object.
---
--- If the object is currently pinned, this function will unpin it. If the object is currently unpinned, this function will pin it.
---
--- @param obj any The object to toggle the pinned state for.
function DevDockPinsPlugin:TogglePinned(obj)
	local idx = self:GetPinIndex(obj)
	local is_pinned = not not idx
	self:SetPinned(obj, not is_pinned)
end

---
--- Adds a new button for the given object.
---
--- If a button for the given object does not already exist, this function creates a new `DevDockPinsButton` and adds it to the plugin. If a button already exists, this function returns the existing button.
---
--- @param obj any The object to add a button for.
--- @return DevDockPinsButton The button for the given object.
---
function DevDockPinsPlugin:AddButton(obj)
    local btn = self:FindButton(obj)
    if not btn then
        btn = DevDockPinsButton:new({ plugin = self }, self, obj)
		btn:Open()
    end
    return btn
end

---
--- Removes the button for the given object.
---
--- If a button for the given object exists, this function will close and remove the button from the plugin.
---
--- @param obj any The object to remove the button for.
---
function DevDockPinsPlugin:RemoveButton(obj)
	local btn = self:FindButton(obj)
	if btn then
		btn:Close()
	end
end

---
--- Finds the button associated with the given object.
---
--- @param obj any The object to find the button for.
--- @return DevDockPinsButton|nil The button associated with the given object, or nil if no button exists.
---
function DevDockPinsPlugin:FindButton(obj)
    for i,btn in ipairs(self) do
        if btn.context == obj then
            return btn
        end
    end
end

---
--- Adds the given object to the selection, creating a new button for it if necessary.
---
--- If a button for the given object does not already exist, this function creates a new `DevDockPinsButton` and adds it to the plugin. If a button already exists, this function simply sets the button as selected.
---
--- @param obj any The object to add to the selection.
---
function DevDockPinsPlugin:SelectionAdded(obj)
    local btn = self:FindButton(obj)
    if not btn then
        btn = self:AddButton(obj)
    end
    btn:SetSelected(true)
end

---
--- Removes the selection for the given object.
---
--- If a button for the given object exists, this function will set the button as unselected.
---
--- @param obj any The object to remove the selection for.
---
function DevDockPinsPlugin:SelectionRemoved(obj)
    local btn = self:FindButton(obj)
    if not btn then return end
    btn:SetSelected(false)
end

---
--- Runs a background thread that periodically checks for modified objects and updates the UI accordingly.
---
--- This function is called by the `DevDockPinsPlugin` to manage the lifecycle of the plugin's UI elements. It runs in a separate thread and performs the following tasks:
---
--- 1. Iterates through all the buttons in the plugin and checks if the associated object has been modified. If so, it calls `ObjModified` on the object.
--- 2. Iterates through all the pinned objects and checks if they are still valid. If a valid object is found, it adds a new button for that object and calls `ObjModified` on the object.
--- 3. Sleeps for 1 second before repeating the process.
---
--- The thread continues to run until the `window_state` of the plugin is set to "destroying", at which point the thread will exit.
---
--- @param self DevDockPinsPlugin The plugin instance that owns this thread.
---
function DevDockPinsPlugin:OThreadProc()
	while self.window_state ~= "destroying" do
		for i,btn in ipairs(self) do
			if btn:HasOLabel() then
				ObjModified(btn.context)
			end
		end
		for idx=1,max_o do
			local obj = rawget(_G, oname(idx))
			if IsValid(obj) then
				self:AddButton(obj)
				ObjModified(obj)
			end
		end
		Sleep(1000)
	end
end

---
--- Gets the index of the given object in the pinned object list.
---
--- @param obj any The object to find the index for.
--- @return integer|nil The index of the object in the pinned object list, or nil if the object is not pinned.
---
function OPinsGetIndex(obj)
	for idx=1,max_o do
		local value = rawget(_G, oname(idx))
		if value == obj then return idx end
	end
end

---
--- Gets the next available index in the pinned object list.
---
--- This function iterates through the pinned object list and returns the first available index where a pinned object can be stored. If all indices are currently in use, this function will return `nil`.
---
--- @return integer|nil The next available index in the pinned object list, or `nil` if the list is full.
---
function OPinsGetNextIndex()
	for idx=1,max_o do
		local value = rawget(_G, oname(idx))
		if value == nil then return idx end
	end
end

---
--- Sets the pinned state of the given object.
---
--- If `pinned` is true, the object will be added to the pinned object list at the next available index. If `pinned` is false, the object will be removed from the pinned object list.
---
--- @param obj any The object to set the pinned state for.
--- @param pinned boolean Whether the object should be pinned or unpinned.
--- @return integer|nil The index of the object in the pinned object list, or `nil` if the object was unpinned.
---
function OPinsSet(obj, pinned)
	local idx = OPinsGetIndex(obj)
	if pinned then
		if not idx then
			idx = OPinsGetNextIndex()
			rawset(_G, oname(idx), obj)
			ObjModified(obj)
		end
	else
		if idx then
			rawset(_G, oname(idx), nil)
			ObjModified(obj)
		end
	end
	
	return idx
end

---
--- Clears all pinned objects from the pinned object list.
---
--- This function iterates through the pinned object list and sets all indices to `nil`, effectively removing all pinned objects.
---
function OPinsClear()
	for idx=1,max_o do
		rawset(_G, oname(idx), nil)
	end
end

function OnMsg.LoadGame(metadata, version)
	OPinsClear()
end

function OnMsg.NewGame()
	OPinsClear()
end

function OnMsg.SelectionAdded(obj)
	local plugin = GetDevDockPlugin("DevDockPinsPlugin")
	if not plugin then return end
	plugin:SelectionAdded(obj)
end

function OnMsg.SelectionRemoved(obj)
	local plugin = GetDevDockPlugin("DevDockPinsPlugin")
	if not plugin then return end
	plugin:SelectionRemoved(obj)
end
