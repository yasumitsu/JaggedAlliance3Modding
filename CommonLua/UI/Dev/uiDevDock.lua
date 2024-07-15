DefineClass.DevDock = {
    __parents = { "XDialog" },
    ZOrder = 100,
    IdNode = true,
    Background = white,
    BorderWidth = 1,
    BorderColor = black,
    MinWidth = 32,
    MinHeight = 32,
    MaxWidth = 32,
    MaxHeight = 32,
    HAlign = "left",
    VAlign = "top",

    dock_side = false,
    popup = false,
}

---
--- Initializes the DevDock UI element, including a movable control, a popup menu, and persistence of dock position and visibility.
---
--- @param self DevDock The DevDock instance.
function DevDock:Init()
    local dock = self
    local mover = XMoveControl:new({
        Id = "idMover",
        last_delta = false,
        any_movement = false,
        popup_visible_before_drag = false,
        OnDragDelta = function(self, delta)
            local dlg = GetDialog(self)
            self.last_delta = delta
            if not self.any_movement and delta ~= point20 then
                self.any_movement = true
                self.popup_visible_before_drag = dlg.popup:GetVisible()
                dlg.popup:SetVisible(false)
            end
            dlg:UpdatePopupAnchor()
        end,
        OnDragStart = function(self)
            local dlg = GetDialog(self)
        end,
        OnDragEnd = function(self)
            local dlg = GetDialog(self)
            if not self.any_movement then
                dlg:OnClick()
            else
                dlg:SnapToEdge()
            end
            self.last_delta = false
            self.any_movement = false
        end,
    }, self)
    local btn = XText:new({
        Id = "idArrow",
    }, mover)
    btn:SetText("?")
    
    self.popup = DevDockPopup:new({
        Id = "idPopup",
        dock = self,
    }, self)
    self.popup:SetVisible(table.get(LocalStorage, "DevDock", "Popup"))
    
    local dock_pos = table.get(LocalStorage, "DevDock", "DockPos")
    local dock_side = table.get(LocalStorage, "DevDock", "DockSide")
    if dock_pos and dock_side then
        mover:ApplyOffsetToTarget(self, dock_pos)
        self:SetDockSide(dock_side)
    end
end

--- Called when the layout of the DevDock UI element is complete.
--- Updates the anchor position of the popup window and marks the OnLayoutComplete function as empty.
function DevDock:OnLayoutComplete()
    self:UpdatePopupAnchor()
    self.OnLayoutComplete = empty_func
end

--- Flashes the arrow icon in the DevDock UI element.
---
--- This function creates a new thread that flashes the arrow icon in the DevDock UI element
--- by alternating between the black and original background colors. The flashing effect
--- occurs 5 times with a 100 millisecond interval between each flash.
---
--- If a "Flash" or "Notify" thread is already running, this function will return without
--- creating a new thread.
---
--- @param self DevDock The DevDock UI element instance.
function DevDock:Flash()
    if self:IsThreadRunning("Flash") then return end
    if self:IsThreadRunning("Notify") then return end
    self:CreateThread("Flash", function(self)
        local win = self:ResolveId("idArrow")
        local original = win:GetBackground()
        local interval = 100
        for i=1,5 do
            win:SetBackground(black)
            Sleep(interval)
            win:SetBackground(original)
            Sleep(interval)
        end
        win:SetBackground(original)
    end, self)
end

--- Flashes the arrow icon in the DevDock UI element.
---
--- This function creates a new thread that flashes the arrow icon in the DevDock UI element
--- by alternating between the yellow and original background colors. The flashing effect
--- occurs indefinitely with a 500 millisecond interval between each flash.
---
--- If a "Notify" thread is already running, this function will return without
--- creating a new thread.
---
--- @param self DevDock The DevDock UI element instance.
function DevDock:Notify()
    if self:IsThreadRunning("Notify") then return end
    if self.popup:GetVisible() then return end
    self:CreateThread("Notify", function(self)
        local win = self:ResolveId("idArrow")
        local original = win:GetBackground()
        local interval = 500
        while win.window_state ~= "destroying" do
            win:SetBackground(yellow)
            Sleep(interval)
            win:SetBackground(original)
            Sleep(interval)
        end
    end, self)
end

--- Toggles the visibility of the DevDock popup window.
---
--- When the popup is visible, this function will hide it. When the popup is hidden, this
--- function will show it. It also updates the anchor position of the popup to match the
--- DevDock UI element.
---
--- If a "Notify" thread is currently running, it will be deleted and the arrow icon will
--- be reset to its original background color.
---
--- @param self DevDock The DevDock UI element instance.
function DevDock:OnClick()
    local popup = self.popup
    local visible = popup:GetVisible()
    popup:SetVisible(not visible)
    self:UpdatePopupAnchor()
    if self.popup:GetVisible() then
        if self:IsThreadRunning("Notify") then
            self:DeleteThread("Notify")
            self:ResolveId("idArrow"):SetBackground(white)
        end
    end
end

---
--- Snaps the DevDock UI element to the nearest edge of its parent window.
---
--- This function calculates the closest point on the edges of the parent window to the
--- current center position of the DevDock. It then moves the DevDock to that position
--- and updates the dock side accordingly.
---
--- If a direction vector is provided, the function will use that to determine the closest
--- edge instead of calculating the projections.
---
--- @param self DevDock The DevDock UI element instance.
--- @param direction? point The direction vector to use for snapping.
function DevDock:SnapToEdge(direction)
    local mover = self:ResolveId("idMover")
    direction = direction or mover.last_delta or point20
    local origin = self.box:Center()
    local sx, sy = self.parent.box:sizexyz()
    local target
    if direction == point20 then
        local projections = {
            ClosestPtPointSegment(point(0, 0),   point(0, sy),  origin),
            ClosestPtPointSegment(point(0, sy),  point(sx, sy), origin),
            ClosestPtPointSegment(point(sx, sy), point(sx, 0),  origin),
            ClosestPtPointSegment(point(sx, 0),  point(0, 0),   origin),
            nil,
        }
        local min_dist = Max(sx, sy)
        for _, p in ipairs(projections) do
            local dist = p:SetInvalidZ():Dist2D(origin)
            if dist < min_dist then
                min_dist = dist
                target = p
            end
        end
    else
        target = 
            IntersectRayWithSegment2D(origin, direction, point(0, 0),   point(0, sy)) or
            IntersectRayWithSegment2D(origin, direction, point(0, sy),  point(sx, sy)) or
            IntersectRayWithSegment2D(origin, direction, point(sx, sy), point(sx, 0)) or
            IntersectRayWithSegment2D(origin, direction, point(sx, 0),  point(0, 0))
    end
    if not target then
        return
    end
    if target:x() == 0 then self:SetDockSide("left") end
    if target:y() == 0 then self:SetDockSide("top") end
    if target:x() == sx then self:SetDockSide("right") end
    if target:y() == sy then self:SetDockSide("bottom") end
    target = target - self.box:size() / 2
    table.set(LocalStorage, "DevDock", "DockPos", target)
    local dist = target:Dist2D(origin)
    local interpolation = {
        id = "SnapToEdge",
		type = const.intRect,
		originalRect = sizebox(target, self.box:size()),
		targetRect = self.box,
		duration = direction ~= point20 and Max(500, dist / direction:Len()) or 500,
        flags = const.intfInverse,
	}
    mover:ApplyOffsetToTarget(self, target)
	self:AddInterpolation(interpolation)
    if not self:IsThreadRunning("UpdatePopupAnchor") then
        self:CreateThread("UpdatePopupAnchor", function(self)
            Sleep(interpolation.duration)
            self:UpdatePopupAnchor()
            self.popup:SetVisible(mover.popup_visible_before_drag)
            mover.popup_visible_before_drag = nil
        end, self)
    end
end

local arrow_props = {
    left = { text = ">", h = "right", v = "center" },
    right = { text = "<", h = "left", v = "center" },
    top = { text = "v", h = "center", v = "bottom" },
    bottom = { text = "^", h = "center", v = "top" },
}
---
--- Sets the dock side of the DevDock UI element.
---
--- @param side string The dock side to set. Can be "left", "right", "top", or "bottom".
---
function DevDock:SetDockSide(side)
    self.dock_side = side
    local arrow = self:ResolveId("idArrow")
    arrow:SetText(arrow_props[side].text)
    arrow:SetTextHAlign(arrow_props[side].h)
    arrow:SetTextVAlign(arrow_props[side].v)
    table.set(LocalStorage, "DevDock", "DockSide", side)
end

local popup_props = {
    left = { anchor = "right" },
    right = { anchor = "left" },
    top = { anchor = "bottom" },
    bottom = { anchor = "top" },
}
---
--- Updates the anchor of the DevDock popup window based on the current dock side.
---
--- @param self DevDock The DevDock instance.
---
function DevDock:UpdatePopupAnchor()
    local side = self.dock_side
    local popup = self.popup
    local anchor = table.get(popup_props, side, "anchor")
    popup:SetAnchorType(anchor or "smart")
    popup:SetAnchor(self.box)
    popup:InvalidateLayout()
end

---
--- Checks if a point is within the bounds of the DevDock window.
---
--- @param self DevDock The DevDock instance.
--- @param pt table A table with `x` and `y` fields representing the point to check.
--- @param for_target boolean If true, the function will return true only if the point is within the window for the purpose of determining a mouse target.
--- @return boolean True if the point is within the bounds of the DevDock window.
---
function DevDock:MouseInWindow(pt, for_target)
    if not for_target then
        return true
    end
    return XDialog.MouseInWindow(self, pt)
end

---
--- Gets the mouse target within the DevDock window.
---
--- @param self DevDock The DevDock instance.
--- @param pt table A table with `x` and `y` fields representing the point to check.
--- @return table|nil The mouse target, or `nil` if no target is found.
--- @return string|nil The cursor type, or `nil` if no target is found.
---
function DevDock:GetMouseTarget(pt)
    local function get_target(win, pt)
        for i,child in ipairs(win) do
            local target, cursor = get_target(child, pt)
            if target then
                return target, cursor
            end
        end
        if win:MouseInWindow(pt, true) then
            if IsKindOf(win, "XPopup") then
                return win:GetMouseTarget(pt)
            elseif IsKindOf(win, "DevDock") then
                return XWindow.GetMouseTarget(win, pt)
            end
        end
    end
    return get_target(self, pt)
end

---
--- Closes the DevDock window.
---
--- @param self DevDock The DevDock instance.
--- @return boolean True if the window was successfully closed, false otherwise.
---
function DevDock:Close()
    return XDialog.Close(self)
end

----

DefineClass.DevDockXTextButton = {
    __parents = { "XTextButton" },
    BorderWidth = 1,
    BorderColor = RGBA(0, 0, 0, 0),
    RolloverTemplate = "GedPropRollover"
}

DefineClass.DevDockXToggleButton = {
    __parents = { "XToggleButton" },
    BorderWidth = 1,
    BorderColor = RGBA(0, 0, 0, 0),
    ToggledBorderColor = RGB(0, 0, 0),
    RolloverTemplate = "GedPropRollover"
}

DefineClass.DevDockPopup = {
    __parents = { "XPopup" },
    IdNode = true,
    HandleMouse = true,
    LayoutMethod = "VList",
    BorderWidth = 1,
    BorderColor = black,

    autohide = true,
    pinned = false,
    dock = false,
    plugins = false,
}

---
--- Initializes the DevDockPopup instance.
---
--- This function sets up the initial state of the DevDockPopup, including:
--- - Restoring the pinned state from local storage
--- - Creating a thread to automatically hide the popup when the mouse is not over it
--- - Creating a toolbar with various actions (preferences, pin/unpin)
--- - Initializing any plugins associated with the DevDockPopup
---
--- @param self DevDockPopup The DevDockPopup instance.
---
function DevDockPopup:Init()
    self.pinned = table.get(LocalStorage, "DevDock", "Pinned")
    self:CreateThread("AutoHideThread", function(self)
        local desktop = self.desktop
        while self.window_state ~= "destroying" do
            Sleep(250)
            if not self.pinned and self.autohide and self:GetVisible() then
                local target = desktop.last_mouse_target or desktop.mouse_capture
                if not GetParentOfKind(target, "DevDock") then
                    self:SetVisible(false)
                end
            end
        end
    end, self)
    local toolbar = XToolBar:new({
        Toolbar = "toolbar",
        Show = "icon",
        ButtonTemplate = "DevDockXTextButton",
        ToggleButtonTemplate = "DevDockXToggleButton",
        FocusOnClick = false,
        AutoHide = false,
        MaxHeight = 16,
        HAlign = "right",
    }, self)
    self:InitControls()
    self:InitPlugins()
end

---
--- Initializes the controls for the DevDockPopup instance.
---
--- This function sets up the initial state of the controls for the DevDockPopup, including:
--- - Creating a "Preferences" action that opens the preferences popup when clicked
--- - Creating a "Pin" action that toggles the pinned state of the DevDockPopup and saves it to local storage
--- - Hiding the "Pin" action if the DevDockPopup is not set to autohide
---
--- @param self DevDockPopup The DevDockPopup instance.
--- @param container table (optional) The container to add the controls to.
---
function DevDockPopup:InitControls(container)
    XAction:new({
        ActionSortKey = "100",
        ActionId = "Preferences",
        ActionIcon = "CommonAssets/UI/Icons/spanner",
        ActionToolbar = "toolbar",
        OnAction = function(self, host, source, ...)
            host.popup:OpenPreferences(source)
        end,
    }, self)
    XAction:new({
        ActionSortKey = "101",
        ActionId = "Pin",
        ActionIcon = "CommonAssets/UI/Icons/pin",
        ActionToolbar = "toolbar",
        ActionToggle = true,
        ActionToggled = function(self, host)
            return host.popup.pinned
        end,
        OnAction = function(self, host, source, ...)
            local new_pinned = not host.popup.pinned
            host.popup.pinned = new_pinned
            table.set(LocalStorage, "DevDock", "Pinned", new_pinned)
        end,
        ActionState = function(self, host)
            if not host.popup.autohide then
                return "hidden"
            end
        end,
    }, self)
end

---
--- Initializes the plugins for the DevDockPopup instance.
---
--- This function sets up the initial state of the plugins for the DevDockPopup, including:
--- - Creating a dictionary to store the plugins
--- - Calling the UpdatePlugins function to load and manage the plugins
---
--- @param self DevDockPopup The DevDockPopup instance.
---
function DevDockPopup:InitPlugins()
    self.plugins = {}
    self:UpdatePlugins()
end

---
--- Updates the plugins for the DevDockPopup instance.
---
--- This function manages the lifecycle of the plugins for the DevDockPopup. It does the following:
--- - Retrieves a list of all available DevDockPlugin classes
--- - Checks if each plugin is enabled in the local storage and valid
--- - Creates new plugin instances for valid and enabled plugins
--- - Closes and removes plugin instances for invalid or disabled plugins
--- - Adds a label if there are no valid plugins
--- - Removes the label if valid plugins are added
---
--- @param self DevDockPopup The DevDockPopup instance.
---
function DevDockPopup:UpdatePlugins()
    local classes = ClassDescendantsList("DevDockPlugin")
    for i, name in ipairs(classes) do
        local plugin_class = g_Classes[name]
        local is_valid = table.get(LocalStorage, "DevDock", "Plugins", name) and plugin_class:IsValid()
        if not self.plugins[name] and is_valid then
            local plugin = plugin_class:new({
                dock = self.dock,
            }, self)
            self.plugins[name] = plugin
            if self.window_state ~= "new" then
                plugin:Open()
            end
        elseif self.plugins[name] and not is_valid then
            self.plugins[name]:Close()
            self.plugins[name] = nil
        end
    end

    if not next(self.plugins) then
        local text = XLabel:new({}, self)
        text:SetText(next(classes) and "Check the wrench icon." or "Nothing to see here...")
        if self.window_state ~= "new" then
            text:Open()
        end
        self.plugins["__empty"] = text
    elseif self.plugins["__empty"] then
        self.plugins["__empty"]:Close()
        self.plugins["__empty"] = nil
    end
end

---
--- Opens a popup list to allow the user to configure the enabled DevDockPlugin instances.
---
--- This function creates a popup list with checkboxes for each available DevDockPlugin class. The checkboxes allow the user to enable or disable each plugin. When a checkbox is checked or unchecked, the function updates the local storage and calls the `UpdatePlugins()` function on the parent DevDockPopup instance to reflect the changes.
---
--- If there are no available DevDockPlugin classes, the function displays a label indicating that there are no plugins available.
---
--- @param self DevDockPopup The DevDockPopup instance.
--- @param anchor table The anchor point for the popup list.
---
function DevDockPopup:OpenPreferences(anchor)
    local list = XPopupList:new({
        Anchor = anchor.box,
        AnchorType = "smart",
        ZOrder = 10,
    }, self)
    local classes = ClassDescendantsList("DevDockPlugin")
    for i, name in ipairs(classes) do
        local plugin_class = g_Classes[name]
        local checkbox = XCheckButton:new({}, list)
        checkbox:SetCheck(table.get(LocalStorage, "DevDock", "Plugins", name))
        local display_name = name
        if display_name:starts_with("DevDock") then
            display_name = display_name:sub(#"DevDock" + 1)
        end
        if display_name:ends_with("Plugin") then
            display_name = display_name:sub(1, -#"Plugin" - 1)
        end
        checkbox:SetText(display_name)
        function checkbox:OnChange(check)
            table.set(LocalStorage, "DevDock", "Plugins", name, check)
            GetParentOfKind(self, "DevDockPopup"):UpdatePlugins()
        end
    end
    if not next(classes) then
        local text = XLabel:new({}, list)
        text:SetText("No plugins available.")
    end
    list:Open()
end

---
--- Sets whether the DevDockPopup should automatically hide when the user interacts outside of it.
---
--- @param self DevDockPopup The DevDockPopup instance.
--- @param autohide boolean Whether the DevDockPopup should automatically hide.
---
function DevDockPopup:SetAutohide(autohide)
    self.autohide = autohide
    GetActionsHost(self, true):UpdateActionViews()
end

---
--- Sets the visibility of the DevDockPopup.
---
--- @param self DevDockPopup The DevDockPopup instance.
--- @param visible boolean Whether the DevDockPopup should be visible.
--- @param instant boolean Whether the visibility change should happen instantly.
--- @param callback function An optional callback function to be called when the visibility change is complete.
--- @return boolean Whether the visibility was successfully set.
---
function DevDockPopup:SetVisible(visible, instant, callback)
    table.set(LocalStorage, "DevDock", "Popup", not not visible)
    return XPopup.SetVisible(self, visible, instant, callback)
end

---
--- Called when the DevDockPopup loses focus.
---
--- @param self DevDockPopup The DevDockPopup instance.
--- @param new_focus table The new focus object.
--- @return boolean Whether the default behavior should be executed.
---
function DevDockPopup:OnKillFocus(new_focus)
    return XWindow.OnKillFocus(self, new_focus)
end

---
--- Handles the mouse button down event for the DevDockPopup.
---
--- @param self DevDockPopup The DevDockPopup instance.
--- @param pt table The mouse position.
--- @param button number The mouse button that was pressed.
--- @return boolean Whether the default behavior should be executed.
---
function DevDockPopup:OnMouseButtonDown(pt, button)
    return XWindow.OnMouseButtonDown(self, pt, button)
end

----

DefineClass.DevDockPlugin = {
    __parents = { "XWindow", "XActionsHost" },
    HostInParent = true,
    dock = false,
}

---
--- Checks if the DevDockPlugin is valid.
---
--- @return boolean true if the DevDockPlugin is valid, false otherwise.
---
function DevDockPlugin.IsValid()
    return true
end

--- Gets a DevDockPlugin instance of the specified class.
---
--- @param class table The class of the DevDockPlugin to get.
--- @return table|nil The DevDockPlugin instance, or nil if not found.
function GetDevDockPlugin(class)
    return table.get(GetDialog("DevDock"), "popup", "plugins", class)
end

----

function OnMsg.DesktopCreated()
    if Platform.ged then return end
    if not config.DevDock then return end
    OpenDialog("DevDock", terminal.desktop, nil, "auto")
end

local function update_plugins()
    local dlg = GetDialog("DevDock")
    if not dlg then return end
    dlg.popup:UpdatePlugins()
end
OnMsg.ChangeMapDone = update_plugins
OnMsg.PostLoadGame = update_plugins
OnMsg.InGameInterfaceCreated = update_plugins

--- Opens the DevDock dialog.
---
--- This function opens the DevDock dialog, which is a UI element that provides
--- development-related functionality. It is typically used in the context of a
--- game or application development environment.
---
--- @function DevDockOpen
--- @return nil
function DevDockOpen()
    OpenDialog("DevDock", terminal.desktop)
end

---
--- Closes the DevDock dialog.
---
--- This function closes the DevDock dialog, which is a UI element that provides
--- development-related functionality. It is typically used in the context of a
--- game or application development environment.
---
--- @function DevDockClose
--- @return nil
function DevDockClose()
    CloseDialog("DevDock")
end

----

--[[
DefineClass.HelloWorldPlugin = {
    __parents = { "DevDockPlugin" },
    Init = function(self)
        local text = XLabel:new({}, self)
        text:SetText("Hello world!")
        XAction:new({
            ActionId = "HelloWorld",
            ActionToolbar = "toolbar",
            ActionIcon = "CommonAssets/UI/Icons/pi",
            OnAction = function(self, host, source, ...)
                host:Flash()
            end,
        }, self)
        XAction:new({
            ActionId = "HelloWorld2",
            ActionToolbar = "toolbar",
            ActionIcon = "CommonAssets/UI/Icons/activity health lifeline medical pulse",
            OnAction = function(self, host, source, ...)
                host.popup:SetVisible(false)
                host:Notify()
            end,
        }, self)
    end,
}
]]
