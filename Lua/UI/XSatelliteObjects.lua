--- Sets the mouse cursor when the object is hovered over.
---
--- @param rollover boolean Whether the object is being hovered over.
function XMapObject:OnSetRollover(rollover)
	self.desktop:SetMouseCursor(rollover and "UI/Cursors/Inspect.tga")
end


-- ZOrder Guide
-- -1: Underground image
-- 0: Route segments
-- 1: Route decorations (corners, end)
-- 2: SectorWindow and children (Buildings etc)
-- 3: Squads
-- 4: Conflict Icon (Squad in disguise)

DefineClass.SectorWindow = {
	__parents = { "XMapWindow", "XContextWindow" },
	HandleMouse = true,
	BorderWidth = 5,
	BorderColor = RGBA(255, 255, 255, 255),
	IdNode = true,
	ZOrder = 2,

	HAlign = "left",
	VAlign = "top",
	
	SectorVisible = true,
	layer = "satellite",
	click_time = false,
	
	--RolloverTemplate = "ZuluContextMenu",
	RolloverAnchor = "right",
	RolloverBackground = RGBA(255, 255, 255, 0),
	PressedBackground = RGBA(255, 255, 255, 0),
	RolloverOffset = box(20, 0, 0, 0),
}

DefineClass.SectorUndergroundImage = {
	__parents = { "XMapWindow", "XImage" },
	
	Clip = false,
	UseClipBox = false,
	HAlign = "left",
	VAlign = "top",
	ZOrder = -1
}

---
--- Formats the city loyalty percentage for display.
---
--- @param ctx table The context table.
--- @param cityId string The ID of the city.
--- @return string The formatted city loyalty percentage, or `false` if the loyalty is 0 or less, or the city is not owned by the player.
---
function TFormat.cityLoyaltyConditional(ctx, cityId)
	local loyalty = GetCityLoyalty(cityId)
	if not loyalty or loyalty <= 0 then
		return false
	end
	if not gv_PlayerCityCounts or not gv_PlayerCityCounts.cities or not gv_PlayerCityCounts.cities[cityId] then
		return false
	end
	return Untranslated(" (" .. tostring(loyalty) .. "%)")
end

---
--- Opens the sector window and sets up its contents.
---
--- @param self SectorWindow The sector window instance.
---
function SectorWindow:Open()
	local text = false
	local city = self.context.City
	if city ~= "none" and self.context.ShowCity then
		local cityPreset = gv_Cities[city]
		text = cityPreset and cityPreset.DisplayName
	end
	
	if text then
		local txt = XTemplateSpawn("XText", self, gv_Cities[city])
		txt:SetTranslate(true)
		txt:SetText(T{547402413356, "<cityName><cityLoyaltyConditional(city)>", {cityName = text, city = city }})
		txt:SetUseClipBox(false)
		txt:SetTextStyle("CityName")
		txt:SetId("idLoyalty")
		txt:SetHAlign("center")
		txt:SetVAlign("top")
		txt:SetMargins(box(0, 5, 0, 0))
		txt:SetClip(false)
		txt:SetHandleMouse(false)
		txt:SetZOrder(2)
	end
	
	if IsSatelliteViewEditorActive() then
		local status = XText:new({
			Id = "idDbgStatus",
			TextStyle = "DbgSectorStatus",
			TextColor = RGB(128, 128, 128),
			HAlign = "center",
			VAlign = "bottom",
			Margins = box(0, 0, 0, 5),
			Clip = false,
			UseClipBox = false,
			HandleMouse = false,
			ZOrder = 2,
		}, self)
		status:SetText(self.context.inherited and "Inherited" or self.context.generated and "Empty" or "")
	end
	
	if self.context.Passability == "Blocked" then
		local img = XTemplateSpawn("XImage", self)
		img:SetImage("UI/SatelliteView/sector_empty")
		img:SetDock("box")
		img:SetClip(false)
		img:SetUseClipBox(false)
		img:SetZOrder(-1)
	end
	
	local icon = XTemplateSpawn("XMapRollerableContextImage", self)
	icon.Clip = false
	icon.UseClipBox = false
	icon:SetId("idIntelMarker")
	icon:SetImage("UI/Icons/SateliteView/icon_neutral")
	icon:SetHAlign("left")
	icon:SetVAlign("bottom")
	icon:SetVisible(false)
	icon:SetMargins(box(10, 10, 10, 10))
	icon:SetRolloverTemplate("RolloverGeneric")
	icon:SetRolloverText(T(230411316470, "Intel acquired."))
	icon:SetRolloverOffset(box(20, 0, 0, 0))
	icon.HandleMouse = true
	
	local iicon = XTemplateSpawn("XImage", icon)
	iicon.Clip = false
	iicon.UseClipBox = false
	iicon.Margins = box(0, 0, 0, 0)
	iicon.VAlign = "center"
	iicon.HAlign = "center"
	iicon.MinHeight = 25
	iicon.MaxHeight = 25
	iicon:SetImage("UI/Icons/SateliteView/intel_missing")
	
	-- Is an underground sector
	if self.context.GroundSector then
		local img = XTemplateSpawn("SectorUndergroundImage", self.parent)
		img.PosX = self.PosX
		img.PosY = self.PosY
		img.MinWidth = self.MinWidth
		img.MaxWidth = self.MaxWidth
		img.MinHeight = self.MinHeight
		img.MaxHeight = self.MaxHeight
		img:SetVisible(self.visible)
		self.idUndergroundImage = img
	elseif self.context.Passability ~= "Blocked" then
		local sectorId = self.context.Id
		local north = GetNeighborSector(sectorId, "North")
		local east = GetNeighborSector(sectorId, "East")
		local south = GetNeighborSector(sectorId, "South")
		local west = GetNeighborSector(sectorId, "West")
	
		local horizontal = "UI/SatelliteView/sector_borders_accessibility_x"
		local vertical = "UI/SatelliteView/sector_borders_accessibility_y"
		
		local container = XTemplateSpawn("XWindow", self)
		container:SetDock("box")
		container:SetClip(false)
		container:SetUseClipBox(false)
		container:SetId("idTravelBlocked")
		container:SetVisible(false)
		container:SetZOrder(-1)
		
		if north and IsTravelBlocked(sectorId, north) then
			local lineImg = XTemplateSpawn("XImage", container)
			lineImg:SetImage(horizontal)
			lineImg:SetClip(false)
			lineImg:SetUseClipBox(false)
			lineImg:SetVAlign("top")
			lineImg:SetMargins(box(0, -6, 0, 0))
		end
		
		if south and IsTravelBlocked(sectorId, south) then
			local lineImg = XTemplateSpawn("XImage", container)
			lineImg:SetImage(horizontal)
			lineImg:SetClip(false)
			lineImg:SetUseClipBox(false)
			lineImg:SetVAlign("bottom")
			lineImg:SetMargins(box(0, 0, 0, -6))
		end
		
		if east and IsTravelBlocked(sectorId, east) then
			local lineImg = XTemplateSpawn("XImage", container)
			lineImg:SetImage(vertical)
			lineImg:SetClip(false)
			lineImg:SetUseClipBox(false)
			lineImg:SetHAlign("right")
			lineImg:SetMargins(box(0, 0, -6, 0))
		end
		
		if west and IsTravelBlocked(sectorId, west) then
			local lineImg = XTemplateSpawn("XImage", container)
			lineImg:SetImage(vertical)
			lineImg:SetClip(false)
			lineImg:SetUseClipBox(false)
			lineImg:SetHAlign("left")
			lineImg:SetMargins(box(-6, 0, 0, 0))
		end
	elseif self.context.Passability ~= "Blocked" then -- Old travel blocked art
		-- Build mask
		local sectorId = self.context.Id
		local north = GetNeighborSector(sectorId, "North")
		local east = GetNeighborSector(sectorId, "East")
		local south = GetNeighborSector(sectorId, "South")
		local west = GetNeighborSector(sectorId, "West")
		
		local mask = ""
		if not north or IsTravelBlocked(sectorId, north) then mask = "X" else mask = "N" end
		if not east or IsTravelBlocked(sectorId, east) then mask = mask .. "X" else mask = mask .. "E" end
		if not south or IsTravelBlocked(sectorId, south) then mask = mask .. "X" else mask = mask .. "S" end
		if not west or IsTravelBlocked(sectorId, west) then mask = mask .. "X" else mask = mask .. "W" end

		local imageData = BlockTravelMasks[mask]
		if imageData then
			local img = XTemplateSpawn("XFrame", self)
			img:SetDock("box")
			img:SetClip(false)
			img:SetUseClipBox(false)
			img:SetId("idTravelBlocked")
			img:SetVisible(false)
			img:SetZOrder(-1)
			
			-- We need to fake the rotation because
			-- rotated windows are not clipped.
			local image = imageData[1]
			local angle = imageData[2]
			if angle == "flip-x" then
				img:SetFlipX(true)
			elseif angle == "flip-y" then
				img:SetFlipY(true)
			end
			
			img:SetImage(image)
			--img:SetAngle(imageData[2])
		end
	end

	XContextWindow.Open(self)
	
	local sector = self.context
	local isUnderground = sector.GroundSector
	self.layer = isUnderground and "underground" or "satellite"
end

BlockTravelMasks = {
	["NESW"] = false,
	
	["NXSW"] = { "UI/SatelliteView/sector_side_1", 0 },
	["XESW"] = { "UI/SatelliteView/sector_side_1_90", "flip-y" }, --270
	["NEXW"] = { "UI/SatelliteView/sector_side_1_90", 0 }, --90
	["NESX"] = { "UI/SatelliteView/sector_side_1", "flip-x" }, --180

	["XESX"] = { "UI/SatelliteView/sector_side_2", 0 },
	["XXSW"] = { "UI/SatelliteView/sector_side_2_90", 0 }, --90
	["NXXW"] = { "UI/SatelliteView/sector_side_2_90", "flip-y" }, --180
	["NEXX"] = { "UI/SatelliteView/sector_side_2", "flip-y" }, --270
	
	["NXSX"] = { "UI/SatelliteView/sector_side_2B", 0 }, 
	["XEXW"] = { "UI/SatelliteView/sector_side_2B_90", 0 }, --90
	
	["XXXW"] = { "UI/SatelliteView/sector_side_3", 0 },
	["NXXX"] = { "UI/SatelliteView/sector_side_3_90", 90 * 60 }, --90
	["XEXX"] = { "UI/SatelliteView/sector_side_3", "flip-x" }, --180
	["XXSX"] = { "UI/SatelliteView/sector_side_3_90", "flip-y" }, --270
}

--- Returns the context of the SectorWindow.
---
--- @return table The context of the SectorWindow.
function SectorWindow:GetRolloverText()
	return self.context
end

---
--- Called when the SectorWindow's rollover state changes.
---
--- @param rollover boolean Whether the rollover state is on or off.
--- @return boolean Whether the rollover event was handled.
function SectorWindow:OnSetRollover(rollover)
	PlayFX("SectorRollover", rollover and "start" or "end")
	SectorRolloverShowGuardpostRoute(rollover and self.context)
	return self.map:OnSectorRollover(self, self.context, rollover)
end

---
--- Handles the mouse button up event for the SectorWindow.
---
--- @param pt table The position of the mouse click.
--- @param button string The mouse button that was clicked ("L" for left, "R" for right).
--- @return string|nil If the event was handled, returns "break" to prevent further processing, otherwise returns nil.
function SectorWindow:OnMouseButtonDown(pt, button)
	-- Gamepad virtual cursor will right click when X is pressed,
	-- but we have a shortcut bound to LeftTrigger+X :(
	if GetUIStyleGamepad() then
		local activeGamepad, gamepadId = GetActiveGamepadState()
		local ltHeld = activeGamepad and XInput.IsCtrlButtonPressed(gamepadId, "LeftTrigger")
		if ltHeld then return end
	end
	
	if button == "L" and IsSatelliteViewEditorActive() then
		self.click_time = GetPreciseTicks()
		if terminal.IsKeyPressed(const.vkShift) then
			return "break"
		end
	end
	
	return self.map:OnSectorClick(self, self.context, button)
end

---
--- Handles the mouse button up event for the SectorWindow.
---
--- @param pt table The position of the mouse click.
--- @param button string The mouse button that was clicked ("L" for left, "R" for right).
--- @return string|nil If the event was handled, returns "break" to prevent further processing, otherwise returns nil.
function SectorWindow:OnMouseButtonUp(pt, button)
	if self.click_time and button == "L" and IsSatelliteViewEditorActive() and GetPreciseTicks() - self.click_time < 150 then
		Msg("OnSectorClick", self.context)
	end
	XMapWindow.OnMouseButtonUp(self, pt, button)
end

---
--- Shows or hides the travel blocked lines for the sector window.
---
--- @param travelMode boolean Whether to show or hide the travel blocked lines.
---
function SectorWindow:ShowTravelBlockLines(travelMode)
	if not self.idTravelBlocked then return end
	self.idTravelBlocked:SetVisible(travelMode)
end

-- Map coordinates
---
--- Returns the center coordinates of the sector window.
---
--- @return number, number The x and y coordinates of the sector window center.
function SectorWindow:GetSectorCenter()
	return self.PosX + self.MaxWidth / 2, self.PosY + self.MaxHeight / 2
end

---
--- Sets the visibility of the sector window.
---
--- @param visible boolean Whether the sector window should be visible or not.
---
function SectorWindow:SetSectorVisible(visible)
	self.SectorVisible = visible
	--self:SetBackground(visible and RGBA(0,0,0,0) or RGBA(0, 0, 0, 0))
	self:SetBorderWidth(0)
end

---
--- Updates the zoom level of the sector window.
---
--- @param prevZoom number The previous zoom level.
--- @param newZoom number The new zoom level.
--- @param time number The time elapsed since the last zoom update.
---
function SectorWindow:UpdateZoom(prevZoom, newZoom, time)
	local map = self.map
	local maxZoom = map:GetScaledMaxZoom()
	if self.idUndergroundIconsList then
		local otherSector = GetUnderOrOvergroundId(self.context.Id)
		otherSector = otherSector and gv_Sectors[otherSector]
		local otherSectorDiscovered = otherSector and otherSector.discovered
		
		self.idUndergroundIconsList:SetVisible(
			not self.context.HideUnderground and otherSectorDiscovered and newZoom > maxZoom / 2)
	end
	if self.idPointOfInterest and IsKindOf(self.idPointOfInterest, "SatelliteSectorIconGuardpostClass") then
		self.idPointOfInterest:SetMiniMode(newZoom <= maxZoom / 2)
	end

	XMapWindow.UpdateZoom(self, prevZoom, newZoom, time)
end

---
--- Sets the visibility of the sector window.
---
--- @param visible boolean Whether the sector window should be visible or not.
--- @param ... any Additional arguments passed to the base class's SetVisible method.
---
function SectorWindow:SetVisible(visible, ...)
	if self.layer == "underground" then
		local groundSector = gv_Sectors[self.context.GroundSector]
		if groundSector and groundSector.HideUnderground then
			visible = false
		end
	end
	
	if not self.context.discovered then
		visible = false
	end

	XMapWindow.SetVisible(self, visible, ...)
	if self.idUndergroundImage then self.idUndergroundImage:SetVisible(visible) end
end

---
--- Updates the sector window's loyalty display based on the current context.
---
--- @param context table The current context for the sector window.
--- @param update table The update to the context.
---
function SectorWindow:OnContextUpdate(context,update)
 --"XMapWindow", "XContextWindow"idLoyalty
 XContextWindow.OnContextUpdate(self, context,update)
 
 	local text = false
	local city = context.City
	if city ~= "none" and context.ShowCity then
		local cityPreset = gv_Cities[city]
		text = cityPreset.DisplayName
	end
	
	if text then
		self.idLoyalty:SetText(T{547402413356, "<cityName><cityLoyaltyConditional(city)>", {cityName = text, city = city }})
	end
end

---
--- Clears all debug text displayed on the sector windows in the satellite UI.
---
--- This function is used to remove any debug text that was previously added to the sector windows using the `DbgAddSectorText` function.
---
--- @function DbgClearSectorTexts
--- @return nil
function DbgClearSectorTexts()
	if not g_SatelliteUI then return end
	for i, sectorWnd in pairs(g_SatelliteUI.sector_to_wnd) do
		if sectorWnd.idDebugText then
			sectorWnd.idDebugText:Close()
		end
	end
end

---
--- Adds a debug text overlay to a sector window in the satellite UI.
---
--- This function is used to display debug text on top of a sector window in the satellite UI. The text is displayed in the center-top of the sector window.
---
--- @param sectorId number The ID of the sector to add the debug text to.
--- @param text string The text to display in the debug overlay.
--- @return nil
function DbgAddSectorText(sectorId, text)
	if not g_SatelliteUI then return end
	local sectorWnd = g_SatelliteUI.sector_to_wnd[sectorId]
	if not sectorWnd.idDebugText then
		local txt = XTemplateSpawn("XText", sectorWnd)
		txt:SetId("idDebugText")
		txt:SetText(text)
		txt:SetUseClipBox(false)
		txt:SetTextStyle("CityName")
		txt:SetHAlign("center")
		txt:SetVAlign("top")
		txt:SetMargins(box(0, 50, 0, 0))
		txt:SetClip(false)
		txt.HandleMouse = false
		txt:Open()
	else
		sectorWnd.idDebugText:SetText(text)
	end
end

DefineClass.SquadWindow = {
	__parents = { "XMapObject", "XContextWindow" },
	ZOrder = 3,
	IdNode = true,
	ContextUpdateOnOpen = true,
	ScaleWithMap = false,
	FXMouseIn = "SatelliteBadgeRollover",
	FXPress = "SatelliteBadgePress",
	FXPressDisabled = "SatelliteBadgeDisabled",
	RolloverTemplate = "SquadRolloverMap",
	RolloverAnchor = "top-right",
	RolloverOffset = box(20, 24, 0, 0),
	RolloverBackground = RGBA(255, 255, 255, 0),
	PressedBackground = RGBA(255, 255, 255, 0),

	is_player = false,
	routes_displayed = false,
	
	route_visible = true
}

---
--- Sets the bounding box of the SquadWindow object.
---
--- This function sets the bounding box of the SquadWindow object, which determines its size and position on the screen. It also calculates the interaction box, which is a smaller box inside the bounding box that is used for mouse interactions.
---
--- @param x number The x-coordinate of the top-left corner of the bounding box.
--- @param y number The y-coordinate of the top-left corner of the bounding box.
--- @param width number The width of the bounding box.
--- @param height number The height of the bounding box.
--- @return nil
function SquadWindow:SetBox(x, y, width, height)
	XMapObject.SetBox(self, x, y, width, height)
	
	local imagePaddingX, imagePaddingY = ScaleXY(self.scale, 20, 10)
	width = width - imagePaddingX
	height = height - imagePaddingY
	self.interaction_box = sizebox(x + imagePaddingX / 2, y + imagePaddingY / 2, width, height)
end

---
--- Returns the visual position of the SquadWindow object.
---
--- This function returns the visual position of the SquadWindow object, which may differ from its actual position on the screen due to scaling or other transformations.
---
--- @return number, number The x and y coordinates of the visual position of the SquadWindow object.
function SquadWindow:GetTravelPos()
	return self:GetVisualPos()
end

---
--- Initializes the SquadWindow object.
---
--- This function sets up the visual elements of the SquadWindow object, including a selection window, a rollover image, and small and large selection indicators. It also creates a container for displaying additional squad icons if there are more squads than can fit in the window.
---
--- @param self SquadWindow The SquadWindow object being initialized.
--- @return nil
function SquadWindow:Init()	
	local sel_window = XTemplateSpawn("XWindow", self)
	sel_window:SetUseClipBox(false)
	sel_window:SetId("idSquadSelection")
	sel_window:SetIdNode(true)
	sel_window:SetVisible(false)
	sel_window:SetHAlign("center")
	sel_window:SetVAlign("center")
	
	local r,g,b = GetRGB(GameColors.L)
	local sel_window_back = XFrame:new({
		Margins    = box(-6,-6,-6,-6),
		Background = RGBA( r,g,b, 60),
		UseClipBox = false,
		}, sel_window)
	
	local sel_window_top = XImage:new({
		Id         = "idSquadRollover",
		Image      = "UI/Inventory/T_Backpack_Slot_Small_Hover",
		UseClipBox = false,
		Visible    = false,
		ScaleModifier = point(800,800),
		},
	sel_window)

	local sel_window_sel_small = XFrame:new({
		Id         = "idSquadSelSmall",
		Image      = "UI/Inventory/perk_selected_2",
		Margins    = box(-6,-6,-6,-6),
		UseClipBox = false,
		Visible    = false,
	}, sel_window)

	local sel_window_sel_big = XFrame:new({
		Id         = "idSquadSelBig",
		Image      = "UI/Inventory/perk_selected",
		Margins    = box(-13,-13,-13,-13),
		UseClipBox = false,
		Visible    = false,
	}, sel_window)

	local topRightIndicator = XTemplateSpawn("XWindow", self)
	topRightIndicator:SetHAlign("right")
	topRightIndicator:SetVAlign("top")
	topRightIndicator:SetMargins(box(0,2,2,0))
	topRightIndicator:SetUseClipBox(false)

	local moreSquadsContainer = XWindow:new({
		Margins     = box(0, -8, -8, 0),
		Id          = "idMoreSquads",
		IdNode      = true,
		UseClipBox  = false,
		HandleMouse = false,
	}, topRightIndicator)
	moreSquadsContainer:SetVisible(false)
	
	local inner, base = GetSatelliteIconImages({ squad = self.context.UniqueId, side = self.context.Side, map = true })
	local squadImage = XImage:new({
		UseClipBox   = false,
		Desaturation = 255,
		ImageColor   = GameColors.F,
		Image        = inner,		
	}, moreSquadsContainer)
	
	local innerIconImage = XImage:new({
		UseClipBox   = false,
		Desaturation = 255,
		ImageColor   = GameColors.F,
		Image        = base,
		Margins     = box(0, 2, 2, 0),
	}, moreSquadsContainer)
	
	local waterTravelIcon = XTemplateSpawn("XImage", self)
	waterTravelIcon:SetImage("UI/Icons/SateliteView/travel_water")
	waterTravelIcon:SetHAlign("center")
	waterTravelIcon:SetVAlign("top")
	waterTravelIcon:SetId("idWaterTravel")
	waterTravelIcon:SetUseClipBox(false)
	waterTravelIcon:SetMargins(box(0, -27, 0, 0))
	waterTravelIcon:SetVisible(self.context.water_route or self.context.traversing_shortcut_water)
end

---
--- Opens the SquadWindow and initializes its state.
---
--- @param self SquadWindow The SquadWindow instance.
---
function SquadWindow:Open()
	assert(self.context and IsKindOf(self.context, "SatelliteSquad"))

	self:SetWidth(72)
	self:SetHeight(72)

	local side = self.context.Side
	local is_militia = self.context.militia
	local is_player = side == "player1" or side == "player2"
	self.is_player = is_player
	self:SpawnSquadIcon()
	
	local map = self.map
	if self.context.XVisualPos then
		self.PosX, self.PosY = self.context.XVisualPos:xy()
	else
		local sectorWnd = map.sector_to_wnd[self.context.CurrentSector]
		if sectorWnd then
			self.PosX, self.PosY = sectorWnd:GetSectorCenter()
		end
	end

	XContextWindow.Open(self)

	-- Initialization wait for layout.
	self:CreateThread("late-update", function()
		SquadUIUpdateMovement(self)
		Sleep(25) -- Needs to be after the layout of the (potential) route in SquadUIUpdateMovement
		self:SetAnim(self.rollover)
	end)
end

---
--- Closes all the route windows and decorations that were displayed for this SquadWindow.
---
--- This function is called when the SquadWindow is deleted to clean up any associated UI elements.
---
function SquadWindow:OnDelete()
	if self.routes_displayed then
		for id, windows in pairs(self.routes_displayed) do
			for i, w in ipairs(windows) do
				w:Close()
			end

			for i, w in ipairs(windows.decorations) do
				w:Close()
			end
			
			for i, w in ipairs(windows.shortcuts) do
				w:Close()
			end
		end
		self.routes_displayed = false
	end
end

---
--- Updates the zoom level of the map in the SquadWindow.
---
--- @param prevZoom number The previous zoom level.
--- @param newZoom number The new zoom level to set.
--- @param time number The duration of the zoom animation in milliseconds.
---
function SquadWindow:UpdateZoom(prevZoom, newZoom, time)
	local map = self.map
	local maxZoom = map:GetScaledMaxZoom()
	local minZoom = Max(1000 * map.box:sizex() / map.map_size:x(), 1000 * map.box:sizey() / map.map_size:y())
	newZoom = Clamp(newZoom, minZoom + 120, maxZoom)

	XMapWindow.UpdateZoom(self, prevZoom, newZoom, time)
end

---
--- Returns the context of the SquadWindow.
---
--- @return table The context of the SquadWindow.
---
function SquadWindow:GetRolloverText()
	return self.context
end

---
--- Plays an animation for the squad selection icon in the SquadWindow.
---
--- This function is called to animate the squad selection icon when it is selected or deselected.
--- The animation involves zooming the selection icon in and out.
---
function SquadWindow:SelectionAnim()
	local sel_ctrl = self.idSquadSelection
	local big = sel_ctrl.idSquadSelBig
	if self:IsThreadRunning("select_icon") then
		return
	end	
	self:CreateThread("select_icon",function(big, self)
		big:RemoveModifier("zoom")
		big:AddInterpolation{
			id = "zoom",
			type = const.intRect,
			duration = 100,
			OnLayoutComplete = IntRectCenterRelative,
			originalRect = sizebox(0, 0, 1400, 1400),
			targetRect = sizebox(0, 0, 1000, 1000),
			flags = const.intfInverse,
			autoremove = true,
			force_in_interpbox = "end",
			exclude_from_interpbox = true,
			interpolate_clip = false,
		}
		Sleep(100)
		big:AddInterpolation{
			id = "zoom",
			type = const.intRect,
			duration = 100,
			OnLayoutComplete = function(modifier, window)				
				modifier.originalRect = sizebox(self.PosX, self.PosY, big.box:sizex(), big.box:sizey())
				modifier.targetRect = sizebox(self.PosX, self.PosY, MulDivRound(big.box:sizex(),800, 1000), MulDivRound(big.box:sizey(),800, 1000))
			end,	
			flags = const.intfInverse,
			autoremove = true,
			force_in_interpbox = "end",
			exclude_from_interpbox = true,
			interpolate_clip = false,
		}
	end, big, self)
end

---
--- Sets the animation for the squad selection icon in the SquadWindow.
---
--- This function is called to set the visibility and animation of the squad selection icon when the window is rolled over or not.
--- The animation involves zooming the selection icon in and out when the squad is selected.
---
--- @param rollover boolean Whether the window is currently rolled over or not.
---
function SquadWindow:SetAnim(rollover)
	local side = self.context.Side
	local is_player = side == "player1" or side == "player2"	
	local sel_ctrl = self.idSquadSelection
	if not is_player then 
		sel_ctrl:SetVisible(rollover)
		sel_ctrl.idSquadRollover:SetVisible(rollover)
		sel_ctrl.idSquadSelSmall:SetVisible(false)
		sel_ctrl.idSquadSelBig:SetVisible(false)
		return 
	end
	
	local selected_squad = g_SatelliteUI.selected_squad
	local is_selected = selected_squad and selected_squad.UniqueId == self.context.UniqueId
	local selectedTravelling = selected_squad and (IsSquadTravelling(selected_squad, true) or selected_squad.arrival_squad)
	local imTravelling = IsSquadTravelling(self.context, true) or self.context.arrival_squad
	if not selectedTravelling and not imTravelling and not is_selected then
		is_selected = selected_squad and selected_squad.CurrentSector == self.context.CurrentSector
	end

	local big = sel_ctrl.idSquadSelBig
	if rollover and not is_selected then
		sel_ctrl:SetVisible(true)
		sel_ctrl.idSquadRollover:SetVisible(true)
		sel_ctrl.idSquadSelSmall:SetVisible(false)
		big:SetVisible(false)
	elseif rollover and is_selected then
		sel_ctrl:SetVisible(true)
		sel_ctrl.idSquadRollover:SetVisible(false)
		sel_ctrl.idSquadSelSmall:SetVisible(true)
		big:SetVisible(true)

		big:AddInterpolation{
			id = "rollover",
			type = const.intRect,
			duration = 200,
			OnLayoutComplete = IntRectCenterRelative,
			targetRect = box(0, 0, 1100, 1100),
			originalRect = box(0, 0, 1000, 1000),
			--flags = const.intfInverse,
			autoremove = true,
			force_in_interpbox = "end",
			exclude_from_interpbox = true,
			interpolate_clip = false,
			--flags = const.intfPingPong + const.intfLooping,
		}
	elseif not rollover and is_selected then
		sel_ctrl:SetVisible(true)
		sel_ctrl.idSquadRollover:SetVisible(false)
		sel_ctrl.idSquadSelSmall:SetVisible(true)
		big:SetVisible(true)
	elseif not rollover and not is_selected then
		sel_ctrl:SetVisible(false)
		sel_ctrl.idSquadRollover:SetVisible(false)
		sel_ctrl.idSquadSelSmall:SetVisible(false)
		big:SetVisible(false)
	end

	if is_selected then
		big:RemoveModifier("rollover")
		
		if not imTravelling then
			local flags = const.intfPingPong + const.intfLooping
			if not rollover then
				flags = const.intfInverse
			end
			
			big:AddInterpolation{
				id = "rollover",
				type = const.intRect,
				duration = 600,
				OnLayoutComplete = IntRectCenterRelative,
				OnWindowMove = IntRectCenterRelative,
				targetRect = box(0, 0, 1100, 1100),
				originalRect = box(0, 0, 1000, 1000),
				flags = flags,
				autoremove = not rollover or nil,
				exclude_from_interpbox = not rollover,
				force_in_interpbox = "end",
				interpolate_clip = false,
				easing = "Sin in"
			}
		end
	end
end

---
--- Handles the rollover state of the SquadWindow.
---
--- When the SquadWindow is in a rollover state, this function updates the appearance of the displayed route, decorations, and shortcuts based on the rollover state.
---
--- @param rollover boolean Whether the SquadWindow is in a rollover state.
function SquadWindow:OnSetRollover(rollover)
	XContextWindow.OnSetRollover(self,rollover)
	self:SetAnim(rollover)
	
	if self.context.Side == "enemy1" then
		local displayedRoute = self.routes_displayed
		displayedRoute = displayedRoute and displayedRoute["main"]
		if not displayedRoute then return end
		
		for i, w in ipairs(displayedRoute) do
			w:SetBackground(rollover and GameColors.C or GameColors.Enemy)
			w:SetDrawOnTop(rollover)
		end

		for i, w in ipairs(displayedRoute.decorations) do
			if w.mode == "port" then
				w:SetColor(rollover and GameColors.C or white)
			else
				w:SetColor(rollover and GameColors.C or GameColors.Enemy)
			end
			w:SetDrawOnTop(rollover)
			self:SetDrawOnTop(rollover)
		end
		
		for i, w in ipairs(displayedRoute.shortcuts) do
			w:SetBackground(rollover and GameColors.C or GameColors.Enemy)
			w:SetDrawOnTop(rollover)
			self:SetDrawOnTop(rollover)
		end
	end
end

---
--- Creates a rollover window for the SquadWindow.
---
--- @param gamepad boolean Whether the rollover is triggered by a gamepad.
--- @param context table The context to use for the rollover window.
--- @param pos table The position of the rollover window.
--- @return boolean|table False if the rollover window could not be created, otherwise the created rollover window.
---
function SquadWindow:CreateRolloverWindow(gamepad, context, pos)
	context = SubContext(self.context,{control = self, anchor = self:ResolveRolloverAnchor(context, pos),gamepad = gamepad})
	local tmpl = self:GetRolloverTemplate()
	if tmpl then
		local win = XTemplateSpawn(tmpl, nil, context)
		if not win then return false end
		win:Open()
		return win
	end
end

---
--- Returns the sector window associated with the current sector of the SquadWindow.
---
--- @return XSectorWindow|nil The sector window, or nil if no sector window is associated.
---
function SquadWindow:GetSectorWindow()
	local map = self.map
	local sectorWnd = map.sector_to_wnd[self.context.CurrentSector]
	return sectorWnd
end

---
--- Draws the children of the SquadWindow, with special handling for when the current sector matches the selected sector.
---
--- @param ... Any additional arguments to pass to the base DrawChildren function.
---
function SquadWindow:DrawChildren(...)
	if self.context.CurrentSector and gv_Sectors[self.context.CurrentSector] == self.map.selected_sector then
		local top = XPushShaderEffectModifier("SquadWindowSelected")
		XMapObject.DrawChildren(self, ...)
		UIL.ModifiersSetTop(top)
	else
		XMapObject.DrawChildren(self, ...)
	end
	XMapObject.DrawChildren(self, ...)
end

DefineClass.XMapRollerableContextImage = {
	__parents = { "XMapRolloverable", "XContextImage" }
}

DefineClass.XMapRollerableContext = {
	__parents = { "XMapRolloverable", "XContextWindow" }
}

--- Spawns a squad icon for the SquadWindow.
---
--- @param parent table The parent window to spawn the icon in. If not provided, the SquadWindow itself is used.
--- @return table The spawned squad icon.
function SquadWindow:SpawnSquadIcon(parent)
	parent =  parent or self
	local side = self.context.Side
	local is_player = side == "player1" or side == "player2"
	self.is_player = is_player
	local img
	if is_player then
		img = XTemplateSpawn("SatelliteIconCombined", parent, SubContext(self.context, {side = side, squad = is_player and self.context.UniqueId, map = true }))
		img:SetUseClipBox(false)
	else	
		img = XTemplateSpawn("XMapRollerableContextImage", parent, self.context)
		local squad_img = GetSatelliteIconImagesSquad(self.context)
		img:SetImage(squad_img or "UI/Icons/SateliteView/enemy_squad")
		img:SetUseClipBox(false)
	end
	if parent == self then
		img:SetId("idSquadIcon")
	end
	return img
end

---
--- Cycles through the squads in the given sector, selecting the next squad.
---
--- @param cur_squad_id string The unique ID of the currently selected squad.
--- @param sectorId string The ID of the sector to cycle the squads in.
---
function CycleSectorSquads(cur_squad_id,sectorId)
	local ally, enemy = GetSquadsInSector(sectorId)
	if not ally or #ally<=1 then
		return
	end
	local squad_idx = table.find(ally,"UniqueId",cur_squad_id)	
	if not squad_idx then
		return 
	end
	squad_idx = squad_idx + 1
	if squad_idx>#ally then
		squad_idx = 1
	end
	g_SatelliteUI:SelectSquad(ally[squad_idx])
end

---
--- Handles mouse button down events for the SquadWindow.
---
--- @param pt table The point where the mouse button was pressed.
--- @param button string The mouse button that was pressed ("L" for left, "R" for right).
--- @return string|nil Returns "break" to stop further processing of the event, or nil to allow other handlers to process it.
---
function SquadWindow:OnMouseButtonDown(pt, button)
	local sectorId = self.context.CurrentSector
	local sector = gv_Sectors[sectorId]
	
	-- In travel mode just propagate to the sector, which will set the route.
	local sectorWin = self:GetSectorWindow()
	if g_SatelliteUI.travel_mode then
		g_SatelliteUI:OnSectorClick(sectorWin, sectorWin.context, button)
		return
	end
	
	if button == "L" and IsSquadInConflict(self.context) then
		if self.is_player then g_SatelliteUI:SelectSquad(self.context) end
		OpenSatelliteConflictDlg(sector)
		return "break"
	end
	
	if button == "R" then
		g_SatelliteUI:OpenContextMenu(self, self.context.CurrentSector, self.context.UniqueId)
		return "break"
	end
	
	if button == "L" and self.is_player then
		g_SatelliteUI:SelectSquad(self.context)
		g_SatelliteUI:SelectSector(false)
		return "break"
	end

	return self.map:OnSectorClick(sectorWin, sectorWin.context, button)
end

local lRouteEffectTable = {
	id = "glow-in-out",
	type = const.intAlpha,
	startValue = 255, -- Multiplied by the 180 alpha of the color
	endValue = 130,
	duration = 2500,
	flags = bor(const.intfRealTime, const.intfPingPong, const.intfLooping),
	modifier_type = const.modInterpolation,

	interpolate_clip = false
}

---
--- Displays the route for a squad on the satellite view.
---
--- @param id string The unique identifier for the route.
--- @param start number The starting sector for the route.
--- @param route table The route data, containing an array of sector IDs.
---
function SquadWindow:DisplayRoute(id, start, route)
	assert(self.window_state ~= "destroying")
	if not self.routes_displayed then
		self.routes_displayed = {}
	end
	local routeShown = self.routes_displayed[id]

	-- no new
	if not route or #route == 0 then
		for i, w in ipairs(routeShown) do
			w:Close()
		end
		
		for i, w in ipairs(routeShown and routeShown.decorations) do
			w:Close()
		end
		
		for i, w in ipairs(routeShown and routeShown.shortcuts) do
			w:Close()
		end
		
		table.clear(routeShown)
		return
	end
	
	if not routeShown then
		routeShown = {}
		self.routes_displayed[id] = routeShown
	end
	
	-- Reset metadata
	routeShown.extra_in_route = false
	routeShown.extra_visual_segment = false
	
	local squad = self.context
	local enemySquad = squad and (squad.Side == "enemy1" or squad.Side == "enemy2")
	local invalidRoute = IsRouteForbidden(route, squad)
	-- Currently plotting route.
	local plotting = self.map.travel_mode and self.map.travel_mode.squad == self.context
	local routeColor = (enemySquad or (plotting and invalidRoute)) and GameColors.Enemy or GameColors.Player
	if plotting and not invalidRoute then routeColor = GameColors.Yellow end
	local routeColorNoAlpha = routeColor
	--routeColor = GetColorWithAlpha(routeColor, 180)
	
	-- Reuse as many spawned segments as possible, cuz respawning is laggy
	local windowsUsed, shortcutsUsed, prevWasShortcut = 0, 0, false
	local uimap = self.map
	local previousSector, prePreviousSector = start, false
	local lastMove, turns, waypoints, ports = false, {}, {}, {}
	
	local function lAddRouteSegment(to)
		prevWasShortcut = false
	
		windowsUsed = windowsUsed + 1
		local routeWnd = routeShown[windowsUsed]
		if not routeWnd then
			routeWnd = XTemplateSpawn("SquadRouteSegment", uimap)
			routeShown[#routeShown + 1] = routeWnd
		end
		if uimap.window_state == "open" and routeWnd.window_state ~= "open" then routeWnd:Open() end
		
		local sectorPreset = gv_Sectors[previousSector]
		local nextSectorPreset = gv_Sectors[to]
		if (sectorPreset.Port and nextSectorPreset.Passability == "Water") or
			(nextSectorPreset.Port and sectorPreset.Passability == "Water") then
			local halfway = (sectorPreset.XMapPosition + nextSectorPreset.XMapPosition) / 2
			ports[#ports + 1] = halfway
			ports[halfway] = {
				port_sector = sectorPreset.Port and sectorPreset.Id or nextSectorPreset.Port and nextSectorPreset.Id,
				sector_one = sectorPreset.Id,
				sector_two = nextSectorPreset.Id
			}
		end
		
		assert(previousSector ~= to)
		routeWnd:SetDisplayedSection(previousSector, to, squad)
		routeWnd:SetBackground(routeColor)
		routeWnd:SetVisible(self.route_visible or plotting)
		if windowsUsed == 1 and shortcutsUsed == 0 then
			routeWnd:FastForwardToSquadPos(self:GetVisualPos())
		end
		
		local moveDir = point(sector_unpack(previousSector)) - point(sector_unpack(to))
		if not lastMove then
			lastMove = moveDir
		elseif lastMove ~= moveDir then
			turns[#turns + 1] = previousSector
			lastMove = moveDir
		end
		
		prePreviousSector = previousSector
		previousSector = to
	end
	
	local function lAddShortcutSegment(to)
		if not routeShown.shortcuts then routeShown.shortcuts = {} end
		local shortcutsArray = routeShown.shortcuts
	
		shortcutsUsed = shortcutsUsed + 1
		local routeWnd = shortcutsArray[shortcutsUsed]
		if not routeWnd then
			routeWnd = XTemplateSpawn("SquadRouteShortcutSegment", uimap)
			shortcutsArray[#shortcutsArray + 1] = routeWnd
		end
		if uimap.window_state == "open" and routeWnd.window_state ~= "open" then routeWnd:Open() end
		
		local shortcut, reverse = GetShortcutByStartEnd(previousSector, to)
		if not shortcut then
			print("once", "didn't find shortcut in route", previousSector, to)
			return
		end

		routeWnd:SetDisplayShortcut(shortcut, self, reverse, shortcutsUsed == 1)
		routeWnd:SetBackground(routeColor)
		routeWnd:SetVisible(self.route_visible or plotting)

		local moveDir
		
		if not prevWasShortcut then
			moveDir = point(sector_unpack(previousSector)) - point(sector_unpack(to))
			if not lastMove then
				lastMove = moveDir
			elseif lastMove ~= moveDir then
				turns[#turns + 1] = previousSector
				lastMove = moveDir
			end
		end
		
		previousSector = reverse and shortcut.shortcut_direction_entrance_sector or shortcut.shortcut_direction_exit_sector;
		moveDir = point(sector_unpack(previousSector)) - point(sector_unpack(to))
		lastMove = moveDir
		
		prePreviousSector = previousSector
		previousSector = to
		prevWasShortcut = true
	end
	
	-- Squad is in sector, but hasn't reached its center yet.
	-- The segment goes from the middle towards us.
	local startSectorPos = gv_Sectors[start].XMapPosition
	local visualPos = self:GetVisualPos()
	assert(visualPos ~= point20)
	local visuallyPreviousSector = GetSquadPrevSector(visualPos, start, startSectorPos)
	local centerOldMovement = route.center_old_movement -- New route was set while squad was in second half of interpolation.
	local nextWp = route[1] and route[1][1]
	local inShortcut = IsTraversingShortcut(squad)
	if startSectorPos ~= visualPos and visuallyPreviousSector ~= start and (nextWp ~= visuallyPreviousSector or centerOldMovement) and not inShortcut then
		previousSector = visuallyPreviousSector
		lAddRouteSegment(start)
		routeShown.extra_visual_segment = true
	end
	-- The route actually contains the visual position. Disregard it.
	local skipFirst = false
	if nextWp == start and not centerOldMovement then
		skipFirst = true
		routeShown.extra_in_route = true
	end

	for i, section in ipairs(route) do -- each waypoint section
		for is, sector in ipairs(section) do -- array of sector ids
			if i == 1 and is == 1 and skipFirst then goto continue end
			
			if section.shortcuts and section.shortcuts[is] then
				lAddShortcutSegment(sector)
			else
				lAddRouteSegment(sector)
			end

			::continue::
		end

		waypoints[#waypoints + 1] = previousSector
		waypoints[previousSector] = i
	end
	
	-- Delete unused route segments
	if windowsUsed < #routeShown then
		for i = windowsUsed + 1, #routeShown do
			routeShown[i]:Close()
			routeShown[i] = nil
		end
	end

	-- Delete unused shortcut segments
	if routeShown.shortcuts and shortcutsUsed < #routeShown.shortcuts then
		for i = shortcutsUsed + 1, #routeShown.shortcuts do
			routeShown.shortcuts[i]:Close()
			routeShown.shortcuts[i] = nil
		end
	end

	local routeDecorations = routeShown.decorations
	if not routeDecorations then
		routeDecorations = {}
		routeShown.decorations = routeDecorations
	end

	local decorationsUsed = 0
	for i, waypointSector in ipairs(waypoints) do
		if waypointSector == previousSector then goto continue end -- Don't place waypoint at end.
	
		decorationsUsed = decorationsUsed + 1
		local decoration = routeDecorations[decorationsUsed]
		if not decoration then
			decoration = XTemplateSpawn("SquadRouteDecoration", uimap)
			routeDecorations[#routeDecorations + 1] = decoration
		end
		if uimap.window_state == "open" and decoration.window_state ~= "open" then decoration:Open() end
		decoration:SetWaypoint(waypointSector, waypoints[waypointSector])
		decoration:SetColor(routeColorNoAlpha)
		decoration:SetVisible(self.route_visible or plotting)
		::continue::
	end
	
	for i, position in ipairs(ports) do
		decorationsUsed = decorationsUsed + 1
		local decoration = routeDecorations[decorationsUsed]
		if not decoration then
			decoration = XTemplateSpawn("SquadRouteDecoration", uimap)
			routeDecorations[#routeDecorations + 1] = decoration
		end
		
		if uimap.window_state == "open" and decoration.window_state ~= "open" then decoration:Open() end
		
		local portData = ports[position]
		decoration:SetPort(position, routeColorNoAlpha, portData)
		decoration:SetVisible(self.route_visible or plotting)
	end
	
	for i, turnSector in ipairs(turns) do
		if waypoints[turnSector] then goto continue end -- Dont put turns on waypoints.

		decorationsUsed = decorationsUsed + 1
		local decoration = routeDecorations[decorationsUsed]
		if not decoration then
			decoration = XTemplateSpawn("SquadRouteDecoration", uimap)
			routeDecorations[#routeDecorations + 1] = decoration
		end
		if uimap.window_state == "open" and decoration.window_state ~= "open" then decoration:Open() end
		decoration:SetCorner(turnSector)
		decoration:SetColor(routeColorNoAlpha)
		decoration:SetVisible(self.route_visible or plotting)
		::continue::
	end
	
	-- End of path
	if prePreviousSector then
		local squadMode = plotting and squad
		if not squadMode or invalidRoute then
			decorationsUsed = decorationsUsed + 1
			local endDecoration = routeDecorations[decorationsUsed]
			if not endDecoration then
				endDecoration = XTemplateSpawn("SquadRouteDecoration", uimap)
				routeDecorations[#routeDecorations + 1] = endDecoration
			end
			if uimap.window_state == "open" and endDecoration.window_state ~= "open" then endDecoration:Open() end
			
			endDecoration:SetRouteEnd(prePreviousSector, previousSector, plotting and invalidRoute)
			endDecoration:SetColor(routeColorNoAlpha)
			endDecoration:SetVisible(self.route_visible or plotting)
		else
			decorationsUsed = decorationsUsed + 1
			local endDecoration = routeDecorations[decorationsUsed]
			if not endDecoration then
				endDecoration = XTemplateSpawn("SquadRouteDecoration", uimap)
				routeDecorations[#routeDecorations + 1] = endDecoration
			end
			if uimap.window_state == "open" and endDecoration.window_state ~= "open" then endDecoration:Open() end
			
			endDecoration:SetRouteEnd(prePreviousSector, previousSector, plotting and invalidRoute, plotting and squad)
			endDecoration:SetColor(routeColorNoAlpha)
			endDecoration:SetVisible(self.route_visible or plotting)
		end
	end

	-- Delete unused decorations
	if decorationsUsed < #routeDecorations then
		for i = decorationsUsed + 1, #routeDecorations do
			routeDecorations[i]:Close()
			routeDecorations[i] = nil
		end
	end
	
	-- Apply effects to decorations that do not have them, or remove effects.
	local shouldHaveEffect = false--plotting
	for i, w in ipairs(routeShown) do
		if not shouldHaveEffect then
			w:RemoveModifier(lRouteEffectTable)
		elseif not w:FindModifier(lRouteEffectTable) then
			w:AddInterpolation(lRouteEffectTable)
		end
	end
	
	for i, w in ipairs(routeShown.shortcuts) do
		if not shouldHaveEffect then
			w:RemoveModifier(lRouteEffectTable)
		elseif not w:FindModifier(lRouteEffectTable) then
			w:AddInterpolation(lRouteEffectTable)
		end
	end
	
	for i, w in ipairs(routeShown and routeShown.decorations) do
		if not shouldHaveEffect then
			w:RemoveModifier(lRouteEffectTable)
		elseif not w:FindModifier(lRouteEffectTable) then
			w:AddInterpolation(lRouteEffectTable)
		end
	end
end

--- Sets the conflict mode for the SquadWindow.
---
--- If `conflictMode` is true, a conflict icon is displayed in the top-right corner of the SquadWindow.
--- If `conflictMode` is false, the conflict icon is hidden and the SquadWindow's z-order is set to 3.
---
--- @param conflictMode boolean Whether to enable conflict mode or not.
function SquadWindow:SetConflictMode(conflictMode)
	local conflictIcon = self.idConflict
	if conflictMode and not conflictIcon then
		local icon = XTemplateSpawn("XImage", self)
		icon:SetImage("UI/Icons/SateliteView/sv_conflict")
		icon:SetMaxWidth(40)
		icon:SetMaxHeight(40)
		icon:SetMinWidth(40)
		icon:SetMinHeight(40)
		icon:SetDrawOnTop(true)
		icon:SetUseClipBox(false)
		icon:SetImageFit("stretch")
		icon:SetId("idConflict")
		self:SetZOrder(4)
		if self.window_state == "open" then icon:Open() end
	elseif not conflictMode and conflictIcon and conflictIcon.window_state == "open" then
		conflictIcon:Close()
		self:SetZOrder(3)
	end
	if self.idSquadIcon then self.idSquadIcon:SetVisible(not conflictMode) end
end

--- Sets the visibility of the SquadWindow and its associated UI elements.
---
--- @param visible boolean Whether to show or hide the SquadWindow.
--- @param iconOnly boolean If true, only the SquadWindow icon will be visible.
function SquadWindow:SetVisible(visible, iconOnly)
	XContextWindow.SetVisible(self, visible)

	if iconOnly then visible = true end
	if visible then CheckAttackSquadCondition(self.context) end --tutorial
	self.route_visible = visible
	for id, route in pairs(self.routes_displayed) do
		for i, wnd in ipairs(route) do
			wnd:SetVisible(visible)
		end
		for i, wnd in ipairs(route.shortcuts) do
			wnd:SetVisible(visible)
		end
		for i, wnd in ipairs(route.decorations) do
			wnd:SetVisible(visible)
		end
	end
end

--- Updates the visual position of the squad in the satellite view when the SquadWindow is closed.
---
--- This function is called when the SquadWindow is closed, to update the visual position of the squad in the satellite view. It retrieves the current travel position of the SquadWindow and assigns it to the `XVisualPos` field of the squad context.
---
--- @param self SquadWindow The SquadWindow instance.
function SquadWindow:Done()
	local squad = self.context
	squad.XVisualPos = self:GetTravelPos()
	--NetUpdateHash("SquadWindow_Done", squad.UniqueId, squad.XVisualPos) --these windows have become unsorted and sometimes close in different orders; cba to fix;
end

if Platform.developer then
	local function TestPositions()
		for id, squad in ipairs(gv_Squads) do
			NetUpdateHash("OpenSatelliteView_SatSquadPositions", id, squad.XVisualPos)
		end
	end

	function OnMsg.StartSatelliteGameplay()
		TestPositions()
	end

	function OnMsg.OpenSatelliteView()
		TestPositions()
	end
end

function OnMsg.GatherSessionData()
	if g_SatelliteUI then
		for i, s in pairs(g_SatelliteUI.squad_to_wnd) do
			local squad = s.context
			squad.XVisualPos = s:GetTravelPos()
		end
	end
end

--- Gets the satellite icon images for a squad.
---
--- This function returns the appropriate satellite icon images for a given squad, based on the squad's properties such as whether it is an enemy, ally, or neutral squad, and whether it has a diamond briefcase or is a militia or villain squad.
---
--- @param squad table The squad object.
--- @param from_ui boolean Whether the images are being requested from the UI.
--- @return string The base image for the satellite icon.
function GetSatelliteIconImagesSquad(squad, from_ui)
	local image = false
	if squad.diamond_briefcase then
		local shipmentPresetId = squad.shipment_preset_id
		local shipmentPreset = shipmentPresetId and ShipmentPresets[shipmentPresetId]
		image = shipmentPreset and shipmentPreset.squad_icon or "UI/Icons/SateliteView/enemy_squad_diamonds"
	end

	if squad.militia then
		image = "UI/Icons/SateliteView/militia"
	end
	if squad.Villain then
		image = "UI/Icons/SateliteView/enemy_boss"
	end
	if squad.Side == "player1" or squad.Side == "player2" then
		image = image or (squad.image and squad.image.."_s")
	end
	image = image or squad.image or ""
	
	-- Append _2 to from map.
	if from_ui then
		return image
	end
	
	return image .. "_2"
end

---
--- Gets the satellite icon images for a context.
---
--- This function returns the appropriate satellite icon images for a given context, based on the context's properties such as whether it is an enemy, ally, or neutral context, and whether it has a diamond briefcase or is a militia or villain context.
---
--- @param context table The context object.
--- @return string The base image for the satellite icon.
--- @return string The upper image for the satellite icon.
function GetSatelliteIconImages(context)
	local base_img, upper_img = "UI/Icons/SateliteView/icon_neutral", "UI/Icons/SateliteView/hospital"
	local side = context.side
	local is_enemy = side=="enemy1" or side=="enemy2"
	local is_player = side=="player1" or side=="player2"
	local is_ally = is_player or side== "ally"
	local is_neutral = side=="neutral"

	if is_enemy then
		base_img = "UI/Icons/SateliteView/icon_enemy"
	elseif is_ally then
		base_img = "UI/Icons/SateliteView/icon_ally"
	end
	local squad_id = context.squad
	local squad = gv_Squads[squad_id]

	if squad then
		if is_ally then
			base_img = "UI/Icons/SateliteView/merc_squad"
			if is_player then
				upper_img = (squad.image and squad.image.."_s") or "UI/Icons/SquadLogo/squad_logo_01_s"
			else
				upper_img = "UI/Icons/SquadLogo/squad_logo_01_s"
			end
		elseif squad.diamond_briefcase then
			local shipmentPresetId = squad.shipment_preset_id
			local shipmentPreset = shipmentPresetId and ShipmentPresets[shipmentPresetId]
			base_img = shipmentPreset and shipmentPreset.squad_icon or "UI/Icons/SateliteView/enemy_squad_diamonds"
			upper_img = false
		elseif squad.image then
			base_img = squad.image
			upper_img = false
		end
	end

	local building = context.building
	if #(building or "") > 0 then
		local image
		local preset = table.find_value(POIDescriptions, "id", building)
		if preset and preset.icon then
			image = preset and preset.icon
			if building == "Mine" and context.sector and context.sector.mine_depleted then
				image = image .. "_depleted"
			elseif is_neutral and image then
				image = image .. "_neutral"
			end
		end
		upper_img = image and ("UI/Icons/SateliteView/" .. image)
	end
	local intel = context.intel
	if intel~= nil then
		local image = intel and "intel_available" or "intel_missing"
		upper_img = "UI/Icons/SateliteView/"..image
	end
	local suf  = context.map and "_2" or ""
	return base_img..suf, upper_img
end

DefineClass.SatelliteQuestIcon = {
	__parents = { "XContextImage", "XMapRolloverable", "XButton" },
	UseClipBox = false,
	Margins = box(10, 10, 10, 10),
	MinWidth = 64,
	MaxWidth = 64,
	MinHeight = 64,
	MaxHeight = 64,
	ImageFit = "stretch",
	HandleMouse = true,
	
	RolloverTemplate = "RolloverQuests",
	RolloverAnchor = "right",
	Background = RGBA(0, 0, 0, 0),
	RolloverBackground = RGBA(255, 255, 255, 0),
	PressedBackground = RGBA(255, 255, 255, 0),
	RolloverOffset = box(20, 0, 0, 0),
	FXMouseIn = "SatelliteBadgeRollover",
	FXPress = "SatelliteBadgePress",
	FXPressDisabled = "SatelliteBadgeDisabled",
}

--- Returns the context associated with the SatelliteQuestIcon.
---
--- @return table The context associated with the SatelliteQuestIcon.
function SatelliteQuestIcon:GetRolloverText()
	return self.context
end

---
--- Handles the press event for the SatelliteQuestIcon.
--- When the icon is pressed, it opens the PDA dialog and navigates to the quest UI, setting the selected quest to the one associated with the SatelliteQuestIcon.
---
--- @param self SatelliteQuestIcon The SatelliteQuestIcon instance.
---
function SatelliteQuestIcon:OnPress()
	InvokeShortcutAction(g_SatelliteUI, "actionOpenNotes")
	CreateRealTimeThread(function()
		local dlg = GetDialog("PDADialog")
		local notesUI = dlg and dlg.idContent
		if not IsKindOf(notesUI, "PDANotesClass") then
			print("Where's the quest UI? :(")
			return
		end
		
		local subTab = notesUI.idSubContent
		local questUI = subTab and subTab.idQuestsContent
		if not IsKindOf(questUI, "PDAQuestsClass") then
			print("Where's the quest UI 2? :(")
			return
		end
		
		local quest = self.context.quest
		quest = quest and quest[1]
		quest = quest and quest.preset
		if not quest then return end
		questUI:SetSelectedQuest(quest.id)
	end)
end

DefineClass.SatelliteSectorUndergroundIcon = {
	__parents = { "XTextButton", "XMapRolloverable" },
	
	UseClipBox = false,
	MinWidth = 64,
	MaxWidth = 64,
	MinHeight = 64,
	MaxHeight = 64,
	ImageFit = "stretch",
	HandleMouse = true,
	
	HAlign = "right",
	VAlign = "bottom",
	
	ColumnsUse = "ababa",
	
	ZOrder = 2,
	RolloverTemplate = "RolloverGeneric",
	RolloverTitle = T(848438434046, "Underground sector"),
	RolloverText = T(859822970788, "This sector has an underground section that can be explored"),
	
	FXPress = "SatViewUndergroundlevel",
}

--- Opens the SatelliteSectorUndergroundIcon.
-- This function is called to open the SatelliteSectorUndergroundIcon UI element.
-- It calls the parent class's Open() function to handle the opening of the UI element.
function SatelliteSectorUndergroundIcon:Open()
	XTextButton.Open(self)
end

---
--- Swaps the current satellite view layer between satellite and underground.
--- If the current layer is "satellite", it sets the layer mode to "underground".
--- If the current layer is "underground", it sets the layer mode to "satellite".
---
--- @function SatelliteSectorUndergroundIcon:SwapSector
--- @return integer, integer # The new visible sector and the previously visible sector
---
function SatelliteSectorUndergroundIcon:SwapSector()
	local layer = g_SatelliteUI.layer_mode
	if layer == "satellite" then
		g_SatelliteUI:SetLayerMode("underground")
	elseif layer == "underground" then
		g_SatelliteUI:SetLayerMode("satellite")
	end
end

---
--- Swaps the current satellite view layer between satellite and underground.
--- If the current layer is "satellite", it sets the layer mode to "underground".
--- If the current layer is "underground", it sets the layer mode to "satellite".
---
--- @function SatelliteSectorUndergroundIcon:OnPress
--- @return integer, integer # The new visible sector and the previously visible sector
---
function SatelliteSectorUndergroundIcon:OnPress()
	local visibleSector, previouslyVisibleSector = self:SwapSector()
	if GetSectorInfoPanel() and g_SatelliteUI.selected_sector == gv_Sectors[previouslyVisibleSector] then
		g_SatelliteUI:SelectSector(gv_Sectors[visibleSector])
	end
end

DefineClass.SatelliteSectorIconGuardpostClass = {
	__parents = { "XContextWindow", "XMapRolloverable", "SatelliteIconClickThrough" },
	UseClipBox = false,

	Id = "idPointOfInterest",
	ContextUpdateOnOpen = true,
	
	HandleMouse = true
}

---
--- Opens the SatelliteSectorUndergroundIcon UI element.
--- This function is called to open the SatelliteSectorUndergroundIcon UI element.
--- It calls the parent class's Open() function to handle the opening of the UI element.
---
--- @function SatelliteSectorIconGuardpostClass:Open
--- @return nil
function SatelliteSectorIconGuardpostClass:Open()
	self.context.side = self.context.sector.Side
	self.context.building = "Guardpost"
	self.context.poi = "Guardpost"
	self.context.poi_preset = table.find_value(POIDescriptions, "id", "Guardpost")
	self.context.map = true
	self.context.is_main = true
	XContextWindow.Open(self)
end

---
--- Updates the SatelliteSectorIconGuardpostClass UI element.
--- This function is called to update the appearance of the SatelliteSectorIconGuardpostClass UI element.
--- It sets the context information, retrieves the appropriate satellite icon images, and updates the UI element's appearance based on the guardpost strength.
---
--- @param mode string The update mode, either "main" or not.
--- @return nil
function SatelliteSectorIconGuardpostClass:Update(mode)
	self.context.is_main = mode == "main"
	self.context.side = self.context.sector.Side
	
	local base, up = GetSatelliteIconImages(self.context)
	self.idIcon:SetImage(base)
	
	local strength = GetGuardpostStrength(self.context.sector.Id)
	local fullStrength = not not strength
	for i, s in ipairs(strength) do
		if s.done then
			fullStrength = false
			break
		end
	end
	if fullStrength then
		up = "UI/Icons/SateliteView/guard_post_2"
	end
	
	self.idInner:SetImage(up)
end

---
--- Gets the rollover text for the SatelliteSectorIconGuardpostClass UI element.
--- This function is called to retrieve the rollover text to be displayed when the user hovers over the SatelliteSectorIconGuardpostClass UI element.
--- It calls the GetGuardpostRollover function to get the rollover text based on the context sector.
---
--- @return string The rollover text to be displayed.
function SatelliteSectorIconGuardpostClass:GetRolloverText()
	local sector = self.context.sector
	return GetGuardpostRollover(sector)
end

---
--- Sets the mini mode for the SatelliteSectorIconGuardpostClass UI element.
---
--- This function is used to set the mini mode for the SatelliteSectorIconGuardpostClass UI element. If the context sector's side is not "enemy1", the mini mode is set to true. Otherwise, the mini mode is set based on the provided `on` parameter.
---
--- When in mini mode, the shield container and timer are hidden, and the icon's scale is reduced.
---
--- @param on boolean Whether to set the mini mode on or off.
--- @return nil
---
function SatelliteSectorIconGuardpostClass:SetMiniMode(on)
	if self.context.sector.Side ~= "enemy1" then
		on = true
	end
	
	self.idShieldContainer:SetVisible(not on)
	self.idTimer:SetVisible(not on)
	self.idIcon:SetScaleModifier(on and point(1000, 1000) or point(1500, 1500))
end

---
--- Blinks the sector window in the satellite UI.
---
--- This function is used to create a blinking effect on a sector window in the satellite UI. It will blink the sector window a maximum of 10 times, with a 250 millisecond interval between each blink. The blinking will stop if the sector window is rolled over or the maximum number of blinks has been reached.
---
--- @param sector table The sector to blink.
--- @return nil
---
function SectorWindowBlink(sector)
	local satMap = g_SatelliteUI
	local sectorWindow = satMap and satMap.sector_to_wnd[sector.Id]
	if not sectorWindow then return end
	
	sector = sector and gv_Sectors[sector.GroundSector] or sector
	sectorWindow:DeleteThread("blink-thread")
	sectorWindow:CreateThread("blink-thread", function()
		local blinkOn = false
		local blinkCount, maxBlinks = 0, 10
		while sectorWindow.window_state ~= "destroying" do
			blinkOn = not blinkOn
			satMap.blinking_sector_fx = blinkOn and sector
			satMap:Invalidate() -- force redraw
			blinkCount = blinkCount + 1
			
			if sectorWindow.rollover or blinkCount > maxBlinks then break end
			Sleep(250) -- blink interval
		end
		satMap.blinking_sector_fx = false
	end)
end

---
--- Displays a route for a guardpost in the satellite UI.
---
--- This function is used to display a route for a guardpost in the satellite UI. It checks if the guardpost has a next spawn time and if the sector is an enemy sector. If the conditions are met, it generates a route from the start sector to the target sector using Dijkstra's algorithm. The route is then displayed on the satellite map using a proxy map object.
---
--- @param sector table The sector containing the guardpost.
--- @return nil
---
function SectorRolloverShowGuardpostRoute(sector)
	local satMap = g_SatelliteUI
	local guardpostObj = sector and sector.guardpost_obj
	local showRoute = guardpostObj and guardpostObj.next_spawn_time and (sector.Side == "enemy1" or sector.Side == "enemy2")
	if showRoute then
		local timeRemaining = showRoute and guardpostObj.next_spawn_time - Game.CampaignTime
		showRoute = timeRemaining > 0 and timeRemaining < const.Satellite.GuardPostShowTimer
	end

	local startSectorId = sector and sector.Id
	local targetSectorId = guardpostObj and guardpostObj.target_sector_id
	if not targetSectorId then
		showRoute = false
	end
	
	local calculateRoute = showRoute and GenerateRouteDijkstra(startSectorId, targetSectorId, false, empty_table, nil, startSectorId, sector.Side)
	calculateRoute = calculateRoute and {calculateRoute} -- Waypointify
	if calculateRoute then
		if not satMap.guardpost_route_proxy then
			-- Init dummy map object and props to use the SquadWindow function. Yes, this is a dirty hack.
			local proxyObj = XTemplateSpawn("XMapObject", g_SatelliteUI);
			proxyObj.ScaleWithMap = false
			proxyObj.context = { Side = sector.Side }
			proxyObj.OnDelete = SquadWindow.OnDelete
			local pos = sector.XMapPosition
			proxyObj:SetPos(pos:xy())
			proxyObj.GetVisualPos = function()
				return pos
			end
			if satMap.window_state == "open" then proxyObj:Open() end
			satMap.guardpost_route_proxy = proxyObj
		end
		SquadWindow.DisplayRoute(satMap.guardpost_route_proxy, "guardpost", startSectorId, calculateRoute)
	else
		if satMap.guardpost_route_proxy then
			satMap.guardpost_route_proxy:Close()
			satMap.guardpost_route_proxy = false
		end
	end
end

DefineClass.SatelliteIconClickThrough = {
	__parents = { "XContextWindow", "XMapRolloverable" }
}

---
--- Handles the mouse button down event for the SatelliteIconClickThrough class.
---
--- When the user clicks on the satellite icon, this function is called to handle the click event.
--- It retrieves the sector associated with the icon, gets the parent XMap, and then calls the OnSectorClick
--- function of the g_SatelliteUI object, passing the sector window and its context.
---
--- @param pt table The position of the mouse click.
--- @param button string The mouse button that was clicked.
--- @return boolean Whether the event was handled.
---
function SatelliteIconClickThrough:OnMouseButtonDown(pt, button)
	local sector = self.context.sector
	local map = GetParentOfKind(self, "XMap")
	local sectorWin = map.sector_to_wnd[sector.Id]
	return g_SatelliteUI:OnSectorClick(sectorWin, sectorWin.context, button)
end

DefineClass.SatelliteSectorIconPOI = {
	__parents = { "XMapRolloverable", "XContextWindow" },
	Id = "idPointOfInterest",
	
	mode = false,
	pois = false,
	
	UseClipBox = false,
	IdNode = true
}

---
--- Updates the SatelliteSectorIconPOI object with the given mode and list of POIs.
---
--- If the mode or list of POIs has changed, the function will respawn the main and sub icons.
--- Otherwise, it will just update the style of the existing icons.
---
--- @param mode string The mode of the POI, either "main" or something else.
--- @param allPOIs table A list of all the POIs to display.
---
function SatelliteSectorIconPOI:Update(mode, allPOIs)
	local oldMode = self.mode
	local oldPOIsHash = self.pois and table.hash(self.pois)
	self.mode = mode
	self.pois = allPOIs
	
	local mainIcon = self.idMainIcon
	local subIcon = self.idSubIcon
	
	local respawnTotally = oldMode ~= mode or oldPOIsHash ~= table.hash(allPOIs)
	if respawnTotally then
		if mainIcon then mainIcon:Close() end
		if subIcon then subIcon:Close() end
	
		local mainIcon = XTemplateSpawn("SatelliteIconPointOfInterest", self, {
			building = allPOIs[1],
			pois = mode == "main" and { allPOIs[1] } or allPOIs,
			sector = self.context.sector
		})
		mainIcon:SetId("idMainIcon")
		mainIcon:SetMain(mode == "main")
		
		local subIcon = false
		if mode == "main" and allPOIs and #allPOIs > 1 then
			table.remove(allPOIs, 1)
			 subIcon = XTemplateSpawn("SatelliteIconPointOfInterest", self, {
				building = allPOIs[1],
				pois = allPOIs,
				sector = self.context.sector
			})
			subIcon:SetId("idSubIcon")
			subIcon:SetMain(false)
		end
		
		if self.window_state == "open" then
			mainIcon:Open()
			if subIcon then subIcon:Open() end
		end
	else
		if mainIcon then
			mainIcon:UpdateStyle()
		end
		if subIcon then
			subIcon:UpdateStyle()
		end
	end
end

--- Handles the mouse button down event for the SatelliteSectorIconPOI class.
---
--- If the left mouse button is clicked and the sector is in conflict, opens the satellite conflict dialog.
--- Otherwise, it calls the OnMouseButtonDown method of the SatelliteIconClickThrough class.
---
--- @param pt table The mouse position.
--- @param button string The mouse button that was pressed.
--- @return string "break" if the conflict dialog was opened, otherwise the return value of the SatelliteIconClickThrough.OnMouseButtonDown method.
function SatelliteSectorIconPOI:OnMouseButtonDown(pt, button)						
	local sector = self.context.sector
	local sectorId = sector.Id
	if button == "L" and sector.conflict then
		OpenSatelliteConflictDlg(sector)
		return "break"
	end
	
	return SatelliteIconClickThrough.OnMouseButtonDown(self, pt, button)
end

DefineClass.PointOfInterestIconClass = {
	__parents = { "XContextWindow", "XMapRolloverable", "SatelliteIconClickThrough" },

	UseClipBox = false,
	Margins = box(10, 10, 10, 10),
	MinWidth = 64,
	MaxWidth = 64,
	MinHeight = 64,
	MaxHeight = 64,
	ImageFit = "stretch",
	HandleMouse = true,
	
	RolloverTemplate = "RolloverGenericPointOfInterest",
	RolloverAnchor = "smart",
	RolloverBackground = RGBA(255, 255, 255, 0),
	PressedBackground = RGBA(255, 255, 255, 0),
	RolloverOffset = box(10, 10, 10, 10),
	FXMouseIn = "SatelliteBadgeRollover",
	FXPress = "SatelliteBadgePress",
	FXPressDisabled = "SatelliteBadgeDisabled",
}

---
--- Sets the main or secondary icon for a point of interest on the satellite map.
---
--- @param main boolean Whether this is the main icon or a secondary icon.
---
function PointOfInterestIconClass:SetMain(main)
	local context = self.context
	local base, up = GetSatelliteIconImages({
		building = context.building,
		side = context.sector.Side,
		map = true,
		sector = context.sector
	})
	self.idBase:SetImage(base)
	self.idUpperIcon:SetImage(up)

	self:SetScaleModifier(main and point(2000, 2000) or point(1000, 1000))
	self:SetHAlign(main and "center" or "right")
	self:SetVAlign(main and "center" or "top")
	self:UpdateStyle()
end

---
--- Updates the style of the point of interest icon on the satellite map.
---
--- This function is responsible for setting the appropriate images and visual
--- state of the point of interest icon based on the context of the icon.
---
--- @param self PointOfInterestIconClass The instance of the PointOfInterestIconClass.
---
function PointOfInterestIconClass:UpdateStyle()
	local context = self.context
	local base, up = GetSatelliteIconImages({
		building = context.building,
		side = context.sector.Side,
		map = true,
		sector = context.sector
	})
	self.idBase:SetImage(base)
	self.idUpperIcon:SetImage(up)

	local sector = context.sector
	local poi = context.building
	local isLocked = sector[poi .. "Locked"]
	local specialLocked = poi == "Mine" and sector.mine_depleted
	isLocked = isLocked or specialLocked

	self.idBase:SetDesaturation(isLocked and 225 or 0)
	self.idLockedIcon:SetVisible(isLocked)
end

---
--- Gets the rollover title for the point of interest icon.
---
--- @return boolean The rollover title.
---
function PointOfInterestIconClass:GetRolloverText()
	return true
end

---
--- Gets the rollover title for the point of interest icon.
---
--- @return boolean The rollover title.
---
function PointOfInterestIconClass:GetRolloverTitle()
	return true
end

DefineClass.PointOfInterestRolloverClass = {
	__parents = { "PDARolloverClass" }
}

---
--- Gets the rollover title for the point of interest icon.
---
--- @param buildingId string The ID of the building.
--- @param sector table The sector object.
--- @return string The rollover title.
---
function PointOfInterestRolloverClass:GetPOITitleForRollover(buildingId, sector)
	if not buildingId or not sector or not g_SatelliteUI then return end
	
	local poiPreset = table.find_value(POIDescriptions, "id", buildingId)
	if not poiPreset then return false end
	
	local rightText = false
	if buildingId == "Port" then
		local selectedSquad = g_SatelliteUI.selected_squad
		local travelCost = sector:GetTravelPrice(selectedSquad)

		if sector.PortLocked then
			rightText = T(319590646964, "Inactive")
		else
			rightText = T{241693398390, "<moneyWithSign(cost)>/sector",
				cost = -travelCost
			}
		end
	elseif buildingId == "Mine" then
		local income  = GetMineIncome(sector.Id, "evenIfUnowned")
		if income then
			rightText = T{374101510295, "<moneyWithSign(income)>/day", income = income}
		elseif sector.mine_depleted then
			rightText = T(670636571444, "Depleted")
		end
	elseif buildingId == "Hospital" then
		if sector.HospitalLocked then
			rightText = T(319590646964, "Inactive")
		end
	end
	
	if rightText then
		rightText = T{985521229804, "<right><style PDASectorInfo_ValueLight><text></style>", text = rightText}
		return poiPreset.display_name .. rightText
	end
	
	return poiPreset.display_name
end

---
--- Gets the rollover text for the point of interest icon.
---
--- @param buildingId string The ID of the building.
--- @param sector table The sector object.
--- @return string The rollover text.
---
function PointOfInterestRolloverClass:GetPOITextForRollover(buildingId, sector)
	if not buildingId or not sector or not g_SatelliteUI then return end

	local poiPreset = table.find_value(POIDescriptions, "id", buildingId)
	if not poiPreset then return end
	
	local extraText = false
	if buildingId == "Port" then
		local selectedSquad = g_SatelliteUI.selected_squad
		local travelCost, discounts = sector:GetTravelPrice(selectedSquad)
		
		if discounts then
			extraText = T(939967219161, "<newline><newline>Discounted By:")
			for i, d in ipairs(discounts) do
				extraText = extraText .. T{487636023428, "<newline><label><right>-<percent(percent)><left>", label = d.label, percent = d.percent}
			end
		end
	elseif buildingId == "Hospital" then	
		local count = #GetOperationProfessionals(sector.Id, "HospitalTreatment", "Patient")
		extraText = T{498858415486, "<newline><newline>Active patients: <number>", number = count}
	elseif buildingId == "Mine" then
		if sector.mine_depleted then
			extraText = T(997788054289, "Deposit: Fully Depleted")
		elseif not sector.Depletion then
			extraText = T(797228414885, "Deposit: Very Rich")
		else
			local daysUntilDepletion = GetDaysLeftUntilDepletionStarts(sector)
			if daysUntilDepletion < 0 then
				extraText = T(825598030543, "Deposit: Depleting")
			elseif daysUntilDepletion < 30 then
				extraText = T(122719825678, "Deposit: Running Low")
			elseif daysUntilDepletion < 90 then
				extraText = T(266694423591, "Deposit: Moderate")
			elseif daysUntilDepletion < 180 then
				extraText = T(864194248788, "Deposit: Rich")
			else
				extraText = T(797228414885, "Deposit: Very Rich")
			end
		end
		extraText = T(866574791377, "<newline><newline>") .. extraText
	end
		
	if extraText then
		return poiPreset.descr .. extraText
	end
	
	return poiPreset.descr
end