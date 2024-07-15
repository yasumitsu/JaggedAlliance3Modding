local find = table.find
local find_value = table.find_value
local remove = table.remove

if FirstLoad then
	ObjectUIAttachData = {}
	AttachedUIDisplayMode = "Gameplay"
	g_DesktopBox = false
	g_ObjectToAttachedWin = false
	g_ObjectToAttachedData = false
end

local function InitAttachedUITables()
	ObjectUIAttachData = {}
	g_ObjectToAttachedWin = {}
	g_ObjectToAttachedData = {}
end

OnMsg.ChangeMap = InitAttachedUITables
OnMsg.LoadGame = InitAttachedUITables

local function RecalcDesktopBox(pt)
	pt = pt or UIL.GetScreenSize()
	local offset = 200
	g_DesktopBox = sizebox(-offset, -offset, pt:x() + 2 * offset, pt:y() + 2 * offset)
end

function OnMsg.SystemSize(pt)
	RecalcDesktopBox(pt)
end

DefineClass.ObjectsUIAttachDialog = {
	__parents = { "XDrawCacheDialog" },
	FocusOnOpen = "",
	ZOrder = 0,
	UseClipBox = false,
}

--- Initializes a cursor text element for the ObjectsUIAttachDialog.
---
--- The cursor text element is used to display information related to the attached UI.
--- It is positioned in the top-left corner of the dialog with a margin of 30 pixels.
--- The text style used is "UIAttachCursorText" and the element is set to be translatable.
--- The element is initially hidden and will only be shown when it has content.
--- The element is set to not use the clip box, allowing it to potentially extend beyond the dialog's bounds.
function ObjectsUIAttachDialog:Init()
	local cursor_text = XText:new({
		Id = "idCursorText",
		HAlign = "left",
		VAlign = "top",
		ZOrder = 10,
		Margins = box(30,30,0,0),
		Clip = false,
		TextStyle = "UIAttachCursorText",
		Translate = true,
		HideOnEmpty = true,
		UseClipBox = false,
	}, self)
	cursor_text:SetVisible(false)
end

---
--- Opens the ObjectsUIAttachDialog and starts a visibility thread.
---
--- The visibility thread is responsible for updating the visibility of the attached UI elements based on various conditions, such as the current camera position, the object's opacity, and the attached UI display mode.
---
--- @param ... any additional arguments passed to the XDrawCacheDialog:Open() function
function ObjectsUIAttachDialog:Open(...)
	XDrawCacheDialog.Open(self, ...)
	self:StartVisibilityThread()
end

local function IsVisibleInAttachedUIDisplayMode(data)
	-- if there is no data, we can not say whether this should be hidden
	if not data then return true end
	local current_mode = AttachedUIDisplayMode
	local mode = data.attach_ui_mode or "Gameplay"
	if type(mode) == "table" then
		return find(mode, current_mode)
	else
		return mode == current_mode
	end
end

---
--- Starts a visibility thread that updates the visibility of attached UI elements based on various conditions.
---
--- The visibility thread is responsible for the following:
--- - Checking if the current in-game interface mode is the overview mode
--- - Retrieving the current camera position
--- - Iterating through all attached UI elements and their associated objects
--- - Determining the visibility of each attached UI element based on the following conditions:
---   - The `visible` flag in the attached UI data
---   - Whether the overview mode is active
---   - Whether the attached UI is visible in the current display mode
---   - Whether the associated object is valid and has a non-zero opacity
---   - Whether the associated object's UI interaction box is within the camera's view
---   - Whether the camera distance to the associated object is within the maximum allowed distance
--- - Setting the visibility of each attached UI element based on the above conditions
--- - Sorting the children of the `ObjectsUIAttachDialog` to ensure proper z-order
--- - Waiting for the camera transition to end if the overview mode is active
---
--- This function is called when the `ObjectsUIAttachDialog` is opened to start the visibility thread.
---
function ObjectsUIAttachDialog:StartVisibilityThread()
	self:DeleteThread("visibility_thread")
	self:CreateThread("visibility_thread", function()
		while true do
			Sleep(100)
			local overview = GetInGameInterfaceMode() == config.InGameOverviewMode
			local cam_pos = camera.GetPos()
			local object_to_data = g_ObjectToAttachedData
			local presets = Presets.AttachedUIPreset.Default
			for obj, win in pairs(g_ObjectToAttachedWin) do
				local data = object_to_data[obj]
				local visible = data.visible and not overview and IsVisibleInAttachedUIDisplayMode(data)
				local valid = IsValidPos(obj)
				if visible and valid then
					if obj.hide_attached_ui_when_transparent then
						visible = obj:GetOpacity() ~= 0
					end
					if visible then
						local spot = data and data.spot
						spot = spot and obj:HasSpot(spot) and spot or "Origin"
						local x, y, z = obj:GetSpotPosXYZ(obj:GetSpotBeginIndex(spot))
						if z then
							local front, sx, sy = GameToScreenXY(x, y, z)
							visible = front and g_DesktopBox:Point2DInside(sx, sy)
						end
						if visible and cam_pos:IsValid() then
							local modifier = find_value(win.modifiers, "id", "attached_ui")
							local dist = modifier and modifier.max_cam_dist_m
							local cam_dist = cam_pos:Dist(x, y, z)
							visible = not dist or dist*guim >= cam_dist
							win.ZOrder = -cam_dist -- skip window invalidation by setting this directly instead of calling :SetZOrder
						end
					end
				end
				win:SetVisible(visible)
				if visible and valid and PropObjHasMember(obj, "SetInViewUIInteractionBox") then
					local preset = presets[data.template]
					obj:SetInViewUIInteractionBox(win, data.spot, preset and preset.zoom)
				end
			end
			self:SortChildren()
			if overview then
				WaitMsg("CameraTransitionEnd")
			end
		end
	end)
end

---
--- Updates the measure of the `ObjectsUIAttachDialog` and its child windows.
---
--- This function is called when the dialog's maximum width or height changes, and it updates the measure of the dialog and its child windows accordingly.
---
--- @param max_width number The maximum width of the dialog.
--- @param max_height number The maximum height of the dialog.
function ObjectsUIAttachDialog:UpdateMeasure(max_width, max_height)
	-- skip some logic we don't need; the general logic called InvalidateLayout, triggering XTexts:UpdateMeasure which is slow
	self.last_max_width = max_width
	self.last_max_height = max_height
	if not self.measure_update then return end
	
	self.measure_update = false
	for _, win in ipairs(self) do
		win:UpdateMeasure(max_width, max_height)
	end
	self.measure_width = max_width
	self.measure_height = max_height
end

---
--- Sets the display mode for attached UIs.
---
--- @param mode string The new display mode for attached UIs.
---
function SetAttachedUIDisplayMode(mode)
	AttachedUIDisplayMode = mode
end

local box0 = box(0, 0, 0, 0)
local function AttachUIToObject(obj, params)
	if (not IsValid(obj) and obj ~= "mouse" and obj ~= "gamepad") or not params.template then return end
	local win_parent = params.win_parent or GetDialog("ObjectsUIAttachDialog")
	local spot = params.spot
	spot = spot and IsValid(obj) and obj:HasSpot(spot) and spot or "Origin"
	local win = XTemplateSpawn(params.template, win_parent, params.context)
	win:SetVisible(false)
	g_ObjectToAttachedWin[obj] = win
	g_ObjectToAttachedData[obj] = params
	local old_OnLayoutComplete = win.OnLayoutComplete
	win.OnLayoutComplete = function(self)
		old_OnLayoutComplete(self)
		if self.box ~= box0 then
			if (IsValid(obj) or obj == "mouse" or obj == "gamepad") and ObjectUIAttachData[obj] then
				self:SetMargins(box(0, MulDivRound(-self.content_box:sizey(), 1000, self.scale:y()), 0, 0))
			elseif self.window_state ~= "destroying" then
				ObjectUIAttachData[obj] = nil
				g_ObjectToAttachedWin[obj] = nil
				g_ObjectToAttachedData[obj] = nil
				self:delete()
			end
		end
	end
	local preset = Presets.AttachedUIPreset.Default[params.template]
	win:AddDynamicPosModifier({
		id = "attached_ui",
		target = obj,
		spot_type = IsValid(obj) and EntitySpots[spot],
		zoom = preset and preset.zoom,
		max_cam_dist_m = preset and preset.max_cam_dist_m,
		visible = ShouldAttachedUIToObjectBeVisible(obj, params.template),
	})
	win:Open()
	return win
end

local function AttachUIResolvePriority(obj)
	local data = ObjectUIAttachData[obj] or empty_table
	local max_priority
	local params
	for _, row in ipairs(data) do
		if (row.priority or 0) > (max_priority or 0) then
			max_priority = row.priority
			params = row
		end
	end
	if g_ObjectToAttachedData[obj] ~= params then
		local win = g_ObjectToAttachedWin[obj]
		if win then
			if win.window_state ~= "destroying" then
				win:delete()
			end
			g_ObjectToAttachedWin[obj] = nil
			g_ObjectToAttachedData[obj] = nil
		end
		if params then
			AttachUIToObject(obj, params)
		end
	end
end

---
--- Returns the attached UI window for the specified object.
---
--- @param obj table|string The object to get the attached UI window for.
--- @return table|nil The attached UI window, or `nil` if no window is attached.
function GetAttachedUIToObject(obj)
	return g_ObjectToAttachedWin[obj]
end

ShouldAttachedUIToObjectBeVisible = return_true

---
--- Adds an attached UI to the specified object.
---
--- @param obj table|string The object to attach the UI to.
--- @param template string The template to use for the attached UI.
--- @param spot string The spot on the object to attach the UI to.
--- @param context table Any additional context to pass to the attached UI.
--- @param win_parent table The parent window for the attached UI.
--- @return table The attached UI window.
function AddAttachedUIToObject(obj, template, spot, context, win_parent)
	local preset = Presets.AttachedUIPreset.Default[template]
	local priority = preset and preset.SortKey
	assert(priority, string.format("Template %s has no corresponding entry with priority in AttachedUIPreset.Default", template))
	local data = ObjectUIAttachData[obj] or {}
	if find(data, "template", template) then return end -- can't attach same template twice
	data[#data + 1] = {
		template = template,
		spot = spot,
		priority = priority,
		context = context,
		win_parent = win_parent,
		attach_ui_mode = preset and preset.attach_ui_modes,
		visible = ShouldAttachedUIToObjectBeVisible(obj, template),
	}
	ObjectUIAttachData[obj] = data
	AttachUIResolvePriority(obj)
end

---
--- Removes the attached UI for the specified object and template.
---
--- @param obj table|string The object to remove the attached UI from.
--- @param template string The template of the attached UI to remove.
function RemoveAttachedUIToObject(obj, template)
	local data = ObjectUIAttachData[obj]
	if not data then return end
	local idx = find(data, "template", template)
	if idx then
		remove(ObjectUIAttachData[obj], idx)
		if #ObjectUIAttachData[obj] == 0 then
			ObjectUIAttachData[obj] = nil
		end
		AttachUIResolvePriority(obj)
	end
end

---
--- Removes all attached UIs from the specified object.
---
--- @param obj table|string The object to remove all attached UIs from.
function RemoveAllAttachedUIsToObject(obj)
	local win = g_ObjectToAttachedWin[obj]
	if win and win.window_state ~= "destroying" then
		win:delete()
	end
	g_ObjectToAttachedWin[obj] = nil
	g_ObjectToAttachedData[obj] = nil
	ObjectUIAttachData[obj] = nil
end

---
--- Sets the visibility of attached UI templates for the specified objects.
---
--- @param visible boolean Whether the attached UI templates should be visible or not.
--- @param templates_set table A set of template names to apply the visibility change to.
---
function SetAttachedUITemplatesVisible(visible, templates_set)
	for obj, wins in pairs(ObjectUIAttachData) do
		for _, win in ipairs(wins) do
			if templates_set[win.template] then
				win.visible = visible
			end
		end
	end
	for obj, data in pairs(g_ObjectToAttachedData) do
		if templates_set[data.template] then
			data.visible = visible
		end
	end
end

---
--- Initializes the ObjectsUIAttachDialog dialog and attaches UI elements to objects.
---
--- This function is responsible for opening the ObjectsUIAttachDialog dialog and attaching UI elements to objects based on the data stored in the ObjectUIAttachData table.
---
--- @function InitObjectsUIAttachDialog
--- @return nil
function InitObjectsUIAttachDialog()
	if not mapdata.GameLogic then return end
	
	OpenDialog("ObjectsUIAttachDialog", GetInGameInterface())
	for obj, data in pairs(ObjectUIAttachData) do
		AttachUIResolvePriority(obj)
	end
	
	Msg("InitObjectsUIAttach")
end

if Platform.developer then

---
--- Gets the attached UIs for the specified object.
---
--- @param obj table The object to get the attached UIs for.
--- @return table The attached UIs for the specified object.
--- @return integer The number of attached UIs.
function GetAttachedUIsFor(obj)
	local result
	for _, win in ipairs(GetDialog("ObjectsUIAttachDialog")) do
		if ResolvePropObj(win.context) == obj then
			result = table.create_add(result, win)
		end
	end
	return result, #(result or "")
end

end