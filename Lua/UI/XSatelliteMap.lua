if FirstLoad then
g_SatelliteUI = false
end

DefineClass.XSatelliteDialog = { -- Parent of map and all UI in PDASatellite
	__parents = { "XDialog" },
}

local function lKeyboardFocusedFuzzy(self)
	if self.desktop.inactive then return false end

	local focus = self.desktop.keyboard_focus
	if not focus then return false end
	return focus == self or self:IsWithin(focus)
end

--- Returns the appropriate icon (sun or moon) based on the current time of day.
---
--- This function is used to determine the appropriate icon to display for the current time of day in the game.
---
--- @return string The appropriate icon string to display.
function TFormat.dayNightIcon()
	local timeOfDay = CalculateTimeOfDay(Game.CampaignTime)
	if timeOfDay == "Night" then
		return "<image UI/PDA/moon 2000>"
	else
		return "<image UI/PDA/sun 2000>"
	end
end

--- Opens the XSatelliteDialog and selects an initial squad.
---
--- This function is called to open the XSatelliteDialog and select an initial squad to display on the satellite map. It first calls the base class's `Open()` function to open the dialog, then selects a squad using the `g_SatelliteUI:SelectSquad()` function and sends a "SatelliteNewSquadSelected" message with the selected squad.
---
--- @function XSatelliteDialog:Open
--- @return nil
function XSatelliteDialog:Open()
	XDialog.Open(self)
	
	-- Initial squad selection. Needs to be ran after everything in PDA has initialized.
	local selSquad = g_SatelliteUI:SelectSquad(false)
	Msg("SatelliteNewSquadSelected", selSquad, false, true)
end

DefineClass.XSatelliteViewMap = {
	__parents = { "XImage", "XMap" },
	HandleMouse = true,
	ChildrenHandleMouse = true,
	ZOrder = 0,
	
	-- satellite settings
	MouseWheelStep = 70,
	max_zoom = 550,
	
	-- read from the current campaign preset
	Image = false,
	map_size = false,
	grid_start = false,
	sector_size = false,
	sector_max_x = 0,
	sector_max_y = 0,
	
	-- sector selection
	last_mouse_down = false,
	click_time = 200,
	
	-- runtime state
	sector_to_wnd = false,
	squad_to_wnd = false,
	shipment_to_wnd = false,
	travel_mode = false,
	selected_squad = false,
	selected_sector = false,
	rollover_sector = false,
	filter_info_mode = false,--toggled from the button on theleft ot the minimap (i), shows all secotrs id
	playable_area = false,
	clamp_box = false,
	translation_change_notWASD = false,
	
	layer_mode = "satellite",
	
	-- UI stuff
	context_menu = false,
	expand_icons_window = false,
	cursor_hint = false,
	mouse_cursor = false,
	
	suppress_visual_updates = false,
	
	-- Effects stuff
	sector_visible_map = false,
	sector_player = false,
	sector_enemy = false,
	sector_neutral = false,
	rollover_sector_fx = false,
	selected_sector_fx = false,
	blinking_sector_fx = false,
	
	-- Caches
	squads_in_shorcuts = false,
	
	-- Layers
	satellite_layer_image = "",
	underground_layer_image = "",
	satellite_image_cached = false,
	underground_image_cached = false,
	
	decorations = false
}

---
--- Initializes the XSatelliteViewMap object, setting up the map size, layer images, and playable area.
---
--- @param self XSatelliteViewMap The XSatelliteViewMap object being initialized.
--- @param campaign table The current campaign preset.
---
function XSatelliteViewMap:Init()
	local campaign = GetCurrentCampaignPreset()
	self:ValidateAndInitSizes(campaign)
	
	self.satellite_layer_image = campaign.map_file
	self.underground_layer_image = campaign.underground_file
	self.satellite_image_cached = self.satellite_layer_image and { ResourceManager.GetResourceID(self.satellite_layer_image) } or empty_table
	self.underground_image_cached = self.underground_layer_image and { ResourceManager.GetResourceID(self.underground_layer_image) } or empty_table
	
	-- Cause caching
	self:SetImage(self.underground_layer_image)
	self:SetImage(self.satellite_layer_image)
	
	self.playable_area = point(campaign.sector_columns * self.sector_size:x(), (campaign.sector_rows - campaign.sector_rowsstart + 1) * self.sector_size:y())
	self.clamp_box = sizebox(self.grid_start, self.playable_area)
end

---
--- Validates and initializes the sizes of the satellite map, including the grid start, sector size, and map size.
---
--- @param self XSatelliteViewMap The XSatelliteViewMap object being initialized.
--- @param campaign table The current campaign preset.
---
function XSatelliteViewMap:ValidateAndInitSizes(campaign)
	local gx, gy = campaign.sectors_offset:xy()
	self.grid_start = point(Max(gx, 0), Max(gy, 0))
	
	local sx, sy = campaign.sector_size:xy()
	self.sector_size = point(Max(sx, 50), Max(sy, 50))
	
	local minx, miny =
		campaign.sector_columns * self.sector_size:x() + self.grid_start:x(),
		(campaign.sector_rows - campaign.sector_rowsstart + 1) * self.sector_size:y() + self.grid_start:y()
	local mx, my = campaign.map_size:xy()
	self.map_size = point(Max(mx, minx), Max(my, miny))
end

SatelliteViewMoveTimeInterval = 25
SatelliteViewMoveTimeAmount = 30

---
--- Opens the satellite view map.
---
--- This function is responsible for initializing and setting up the satellite view map. It performs the following tasks:
--- - Sets the global `g_SatelliteUI` variable to the current `XSatelliteViewMap` object.
--- - Sends a "InitSatelliteView" message.
--- - Sets the global `gv_SatelliteView` flag to `true`.
--- - Asserts that the function is being called from the game time thread or the "PDADialogSatelliteEditor" dialog.
--- - Sets the shortcut mode to "Satellite".
--- - Creates a thread to set the render mode to "ui".
--- - Sets the time factor based on the campaign speed.
--- - Initializes the cache of shortcut squads.
--- - Generates the sector grid, squad windows, and shipment windows.
--- - Updates all sector visuals.
--- - Sends a "OpenSatelliteView" message.
--- - Hides the cursor hint and adds a dynamic position modifier to it.
--- - Creates a thread to restore the camera to the selected squad's current sector or the campaign's initial sector.
--- - Opens the XMap.
--- - Updates the satellite desaturation.
--- - Recalculates the revealed sectors.
--- - Sends a "StartSatelliteGameplay" message.
--- - Modifies various objects in the game.
--- - Plays the "SatelliteOpen" FX if the "Intro" dialog is not present.
--- - Creates a thread to handle WASD-based satellite map movement.
---
function XSatelliteViewMap:Open()
	g_SatelliteUI = self
	Msg("InitSatelliteView")
	gv_SatelliteView = true
	
	assert(IsGameTimeThread() or GetDialog("PDADialogSatelliteEditor")) -- Assure satellite open is sync
	
	XShortcutsSetMode("Satellite")

	-- In a thread so player isnt looking at a black screen while sat view initialized
	self:CreateThread("set-render-mode", function()
		SetRenderMode("ui")
	end)
	
	self:SetTimeFactor(GetCampaignSpeedXMapFactor())
	self:InitCacheOfShortcutSquads()
	self:GenerateSectorGrid()
	self:GenerateSquadWindows()
	self:GenerateShipmentWindows()
	self:UpdateAllSectorVisuals()
	NetUpdateHash("OpenSatelliteView")
	Msg("OpenSatelliteView")
	
	self.cursor_hint = GetDialog(self).idCursorHintText
	self.cursor_hint:SetVisible(false)
	self.cursor_hint:AddDynamicPosModifier({
		id = "cursor_hint",
		target = "mouse",
		interpolate_clip = false
	})

	-- Camera restore needs to wait for the window to layout.
	self:CreateThread("restore-camera", function()
		--TODO: this causes flicker, maybe show black screen until this is done?
		Sleep(1)

		local selectedSquad = self.selected_squad
		local sectorToShow = selectedSquad and selectedSquad.CurrentSector
		sectorToShow = sectorToShow or gv_CurrentSectorId or GetCurrentCampaignPreset().InitialSector
		SatelliteSetCameraDest(sectorToShow, 0)
	end)
	XMap.Open(self)
	UpdateSatelliteDesaturation()
	
	RecalcRevealedSectors()
	Msg("StartSatelliteGameplay")
	ObjModified("gv_SatelliteView")
	ObjModified("satellite-overlay")
	ObjModified(Game)
	if not GetDialog("Intro") then
		PlayFX("SatelliteOpen")
	end
	
	local dlg = GetDialog(self)
	self:CreateThread("WASD-SatelliteMap", function()
		local interval = SatelliteViewMoveTimeInterval
		local moveAmount = SatelliteViewMoveTimeAmount
		while self.window_state == "open" do
			
			-- Prevent the zooming interpolation and the
			-- WASD interpolation from overlapping
			local movingAlready = false
			if self.translation_change_notWASD then
				local transPos = UIL.GetParam(0)
				local transAtEnd = UIL.GetParam(0, "end")
				movingAlready = transPos ~= transAtEnd
			end
			
			local gamepadState = GetUIStyleGamepad() and GetActiveGamepadState()
			
			local upKeyName1, upKeyName2 = table.unpack(GetShortcuts("actionPanUp") or empty_table)
			local leftKeyName1, leftKeyName2 = table.unpack(GetShortcuts("actionPanLeft") or empty_table)
			local downKeyName1, downKeyName2 = table.unpack(GetShortcuts("actionPanDown") or empty_table)
			local rightKeyName1, rightKeyName2 = table.unpack(GetShortcuts("actionPanRight") or empty_table)
			
			local vkUpKey1 = VKStrNamesInverse[upKeyName1] or 0
			local vkUpKey2 = VKStrNamesInverse[upKeyName2] or 0
			
			local vkLeftKey1 = VKStrNamesInverse[leftKeyName1] or 0
			local vkLeftKey2 = VKStrNamesInverse[leftKeyName2] or 0
			
			local vkDownKey1 = VKStrNamesInverse[downKeyName1] or 0
			local vkDownKey2 = VKStrNamesInverse[downKeyName2] or 0
			
			local vkRightKey1 = VKStrNamesInverse[rightKeyName1] or 0
			local vkRightKey2 = VKStrNamesInverse[rightKeyName2] or 0
			
			if lKeyboardFocusedFuzzy(dlg) and not movingAlready then
				if terminal.IsKeyPressed(vkUpKey1) or terminal.IsKeyPressed(vkUpKey2) then
					self:ScrollMap(0, moveAmount, interval)
				elseif terminal.IsKeyPressed(vkLeftKey1) or terminal.IsKeyPressed(vkLeftKey2) then
					self:ScrollMap(moveAmount, 0, interval)
				elseif terminal.IsKeyPressed(vkDownKey1) or terminal.IsKeyPressed(vkDownKey2) then
					self:ScrollMap(0, -moveAmount, interval)
				elseif terminal.IsKeyPressed(vkRightKey1) or terminal.IsKeyPressed(vkRightKey2) then
					self:ScrollMap(-moveAmount, 0, interval)
				end
				self.translation_change_notWASD = false
				
				if gamepadState then
					local stick = GetAccountStorageOptionValue("InvertPDAThumbs") and
									gamepadState.LeftThumb or gamepadState.RightThumb
					if stick ~= point20 and stick:Len2D() > XInput.ThumbsAsButtonsLevel / 2 then
						local moveRts = MulDivRound(stick, moveAmount, XInput.ThumbsAsButtonsLevel * 2)
						self:ScrollMap(-moveRts:x(), moveRts:y(), interval)
					end
				
					local gamepadState, currentGamepadId = GetActiveGamepadState()
					if gamepadState then
						local dPadDown = XInput.IsCtrlButtonPressed(currentGamepadId, "DPadDown")
						local dPadUp = XInput.IsCtrlButtonPressed(currentGamepadId, "DPadUp")
						local ltHeld = XInput.IsCtrlButtonPressed(currentGamepadId, "LeftTrigger")
						if ltHeld and (dPadDown or dPadUp) then
							local center = self.box:Center()
							self:ZoomMap(moveAmount * (dPadDown and -1 or 1), interval, center)
						end
					end
				end
			end
			Sleep(interval)
		end
	end)
end

--- Releases the references to the cached satellite and underground image objects when the XSatelliteViewMap is done.
function XSatelliteViewMap:Done()
	local satImageObj = self.satellite_image_cached[2]
	if satImageObj then
		satImageObj:ReleaseRef()
		satImageObj = false
	end
	
	local undergroundImageObj = self.underground_image_cached[2]
	if undergroundImageObj then
		undergroundImageObj:ReleaseRef()
		undergroundImageObj = false
	end
end

--- Cleans up resources and state related to the XSatelliteViewMap when it is deleted.
---
--- This function is called when the XSatelliteViewMap is being deleted. It performs the following actions:
--- - Removes any context menu associated with the map
--- - Exits travel mode if it was active
--- - Deletes the g_SatelliteThread thread
--- - Sets g_SatelliteUI to false
--- - Fires a "SatelliteViewClosed" net sync event on the host
--- - Sets the shortcut mode back to "Game"
--- - Sets the render mode back to "scene"
--- - Marks the "satellite-overlay" object as modified
--- - Plays the "SatelliteClose" FX
function XSatelliteViewMap:OnDelete()
	self:RemoveContextMenu()
	if self.travel_mode then self:ExitTravelMode() end
	
	DeleteThread(g_SatelliteThread)
	g_SatelliteUI = false
	
	FireNetSyncEventOnHost("SatelliteViewClosed")
	XShortcutsSetMode("Game")
	SetRenderMode("scene")
	ObjModified("satellite-overlay")
	
	PlayFX("SatelliteClose")
end

--- Starts the scroll behavior for the XSatelliteViewMap.
---
--- This function is called when the user starts scrolling the satellite map. It performs the following actions:
--- - Calls the `XMap.ScrollStart()` function to initialize the scroll behavior
--- - Sets the mouse cursor to the "UI/Cursors/Pda_Inspect.tga" cursor
--- - If there is a corner menu associated with the map, it:
---   - Sets the children of the corner menu to not handle mouse events
---   - Deletes any existing "delayed-fade" thread
---   - Creates a new "delayed-fade" thread that fades the corner menu to 150 transparency over 125 milliseconds after a 200 millisecond delay
function XSatelliteViewMap:ScrollStart()
	XMap.ScrollStart(self)
	self:SetMouseCursor("UI/Cursors/Pda_Inspect.tga")
	local cornerMenu = GetDialog(self).idMenu
	if cornerMenu then
		cornerMenu:SetChildrenHandleMouse(false)
		cornerMenu:DeleteThread("delayed-fade")
		cornerMenu:CreateThread("delayed-fade", function()
			Sleep(200)
			cornerMenu:SetTransparency(150, 125)
		end)
	end
end

--- Stops the scroll behavior for the XSatelliteViewMap.
---
--- This function is called when the user stops scrolling the satellite map. It performs the following actions:
--- - Calls the `XMap.ScrollStop()` function to stop the scroll behavior
--- - Resets the mouse cursor to the default
--- - If there is a corner menu associated with the map, it:
---   - Sets the children of the corner menu to handle mouse events
---   - Deletes any existing "delayed-fade" thread
---   - Creates a new "delayed-fade" thread that fades the corner menu to 0 transparency over 125 milliseconds after a 200 millisecond delay
function XSatelliteViewMap:ScrollStop()
	XMap.ScrollStop(self)
	self:SetMouseCursor()
	
	local cornerMenu = GetDialog(self).idMenu
	if cornerMenu then
		cornerMenu:SetChildrenHandleMouse(true)
		cornerMenu:DeleteThread("delayed-fade")
		cornerMenu:CreateThread("delayed-fade", function()
			Sleep(200)
			cornerMenu:SetTransparency(0, 125)
		end)
	end
end

--- Sets the map scroll position with an optional animation.
---
--- @param transX number The horizontal translation value.
--- @param transY number The vertical translation value.
--- @param time? number The duration of the animation in milliseconds. If not provided, the default is 100 milliseconds.
--- @param int? boolean If true, the translation will be interpolated linearly. If false or not provided, the translation will be eased.
function XSatelliteViewMap:SetMapScroll(transX, transY, time, int)
	local win_box = self.box

	local scaleX, scaleY = UIL.GetParam(1, "end")
	local clampMinX, clampMinY = MulDivRound(self.clamp_box:minx(), scaleX, 1000), MulDivRound(self.clamp_box:miny(), scaleY, 1000)
	local clampMaxX, clampMaxY = MulDivRound(self.clamp_box:maxx(), scaleX, 1000), MulDivRound(self.clamp_box:maxy(), scaleY, 1000)
	local winSizeX, winSizeY = win_box:sizex(), win_box:sizey()
	local winMinX, winMinY = win_box:minx(), win_box:miny()

	-- Clamp to map bounds.
	transX = Clamp(transX, winMinX - clampMaxX + winSizeX / 2, (winMinX + winSizeX / 2) - clampMinX)
	transY = Clamp(transY, winMinY - clampMaxY + winSizeY / 2, (winMinY + winSizeY / 2) - clampMinY)
	UIL.SetParam(0, transX, transY, time or 100, int)
	self.translation_change_notWASD = true
end

SatelliteLayers = { "satellite", "underground" }

---
--- Generates a grid of sector windows for the satellite map.
---
--- This function performs the following actions:
--- - Determines the maximum x and y coordinates of the sectors in the game world
--- - Initializes data structures to track the visibility and ownership of each sector
--- - Creates a window object for each sector and positions it on the map
--- - Marks underground sectors as invisible
--- - Adds an underground/overground switch button to each sector window
--- - Spawns decoration objects for the map based on the current campaign preset
---
--- @param self XSatelliteViewMap The instance of the XSatelliteViewMap object
function XSatelliteViewMap:GenerateSectorGrid()
	local size_x, size_y = 0, 0
	for id, s in pairs(gv_Sectors) do
		local y, x = sector_unpack(id)
		size_x = Max(size_x, x)
		size_y = Max(size_y, y)
	end
	self.sector_max_x = size_x
	self.sector_max_y = size_y
	
	-- Fx visibility map
	self.sector_visible_map = {}
	self.sector_player = {}
	self.sector_enemy = {}
	self.sector_neutral = {}
	for i, layerName in ipairs(SatelliteLayers) do
		local visibleMap = {}
		local player = {}
		local enemy = {}
		local neutral = {}
	
		for i = 1, size_x * size_y do
			assert(type(self.sector_visible_map[i]) == "nil")
			visibleMap[i] = false
			player[i] = false
			enemy[i] = false
			neutral[i] = false
		end
		
		self.sector_visible_map[layerName] = visibleMap
		self.sector_player[layerName] = player
		self.sector_enemy[layerName] = enemy
		self.sector_neutral[layerName] = neutral
	end

	-- Sector window objects.
	local sector_to_wnd = {}
	self.sector_to_wnd = sector_to_wnd
	local start_x = self.grid_start:x()
	local start_y = self.grid_start:y()
	local sector_size_x = self.sector_size:x()
	local sector_size_y = self.sector_size:y()
	
	for id, sector in pairs(gv_Sectors) do
		local sectorId = sector.Id
		if not sectorId then
			assert(false, "Sector with no Id property: " .. id)
			goto continue
		end
		
		local y, x = sector_unpack(sectorId)
		x = start_x + (x-1) * sector_size_x
		y = start_y + (y-1) * sector_size_y
		local sectorWin = XTemplateSpawn("SectorWindow", self, gv_Sectors[sectorId])
		sectorWin.PosX, sectorWin.PosY = x, y
		sectorWin:SetWidth(sector_size_x)
		sectorWin:SetHeight(sector_size_y)
		
		sector_to_wnd[sectorId] = sectorWin
		
		-- Update position in global map.
		sector.XMapPosition = point(sectorWin:GetSectorCenter())
		
		-- Put underground sectors behind overground sectors.
		local isUnderground = sector.GroundSector
		if isUnderground then
			sectorWin:SetVisible(false)
		end
		
		-- Add underground/overground switch button.
		if gv_Sectors[sectorId .. "_Underground"] or isUnderground then
			local undergroundIconsList = XTemplateSpawn("XWindow", sectorWin)
			undergroundIconsList:SetLayoutMethod("HList")
			undergroundIconsList:SetUseClipBox(false)
			undergroundIconsList:SetMargins(box(10, 10, 10, 10))
			undergroundIconsList:SetHAlign("right")
			undergroundIconsList:SetVAlign("bottom")
			undergroundIconsList:SetId("idUndergroundIconsList")
		
			local udMarker = XTemplateSpawn("SatelliteSectorUndergroundIcon", undergroundIconsList)
			udMarker:SetId("idUnderground")
		end
		
		::continue::
	end
	
	local decorations = {}
	local campaignDecorations = GetCurrentCampaignPreset()
	campaignDecorations = campaignDecorations and campaignDecorations.decorations
	
	for i, dec in ipairs(campaignDecorations) do
		local sector = gv_Sectors[dec.relativeSector]
		local sectorPos = sector and sector.XMapPosition or point20
		
		local decoPos = sectorPos + dec.offset
		local decoUI = XTemplateSpawn("SatelliteViewDecoration", self)
		decoUI:SetImage(dec.image)
		decoUI.PosX = decoPos:x()
		decoUI.PosY = decoPos:y()
		decoUI.layer = dec.sat_layer
		decoUI:SetVisible(decoUI.layer == self.layer_mode)
		decorations[#decorations + 1] = decoUI
	end
	
	self.decorations = decorations
end

-- slow, to be used from Satellite Sector editor only
---
--- Rebuilds the sector grid for the satellite view map.
---
--- This function is responsible for clearing the existing sector windows,
--- generating a new sector grid, and then opening and updating the visuals
--- for each sector window.
---
--- @function RebuildSectorGrid
--- @return nil
function XSatelliteViewMap:RebuildSectorGrid()
	for _, win in pairs(self.sector_to_wnd) do
		win:delete()
	end
	self:GenerateSectorGrid()
	for id, win in pairs(self.sector_to_wnd) do
		win:Open()
		self:UpdateSectorVisuals(id)
	end	
end

---
--- Sets the layer mode of the satellite view map.
---
--- When the layer mode is set to "underground", the underground layer image is displayed.
--- When the layer mode is set to "satellite", the satellite layer image is displayed.
---
--- This function also updates the visibility of the sector windows and decorations based on the current layer mode.
---
--- @param layerMode string The layer mode to set, either "underground" or "satellite".
--- @return nil
function XSatelliteViewMap:SetLayerMode(layerMode)
	self.layer_mode = layerMode
	if layerMode == "underground" then
		self:SetImage(self.underground_layer_image)
	elseif layerMode == "satellite" then
		self:SetImage(self.satellite_layer_image)
	end
	
	for sectorId, sectorWin in pairs(self.sector_to_wnd) do
		sectorWin:SetVisible(sectorWin.layer == layerMode)
	end
	self:UpdateAllSectorVisuals()
	
	for i, deco in ipairs(self.decorations) do
		deco:SetVisible(deco.layer == layerMode)
	end

	ObjModified("satellite_layer")
end

-- Visualizations
------

---
--- Sets the image of the satellite view map.
---
--- If the image path is not the satellite layer image or the underground layer image, it simply sets the image using `XImage.SetImage()`.
---
--- If the image path is the satellite layer image or the underground layer image, it first checks if the image is cached. If it is, it sets the `image_id` and `image_obj` properties. If the image is not cached, it creates a new thread to load the image asynchronously and updates the cache when the image is loaded.
---
--- @param imagePath string The path of the image to set.
--- @return nil
function XSatelliteViewMap:SetImage(imagePath)
	if not imagePath then return end
	
	if imagePath ~= self.satellite_layer_image and imagePath ~= self.underground_layer_image then
		return XImage.SetImage(self, imagePath)
	end
	
	local cacheTable = imagePath == self.satellite_layer_image and
								self.satellite_image_cached or 
								self.underground_image_cached

	self.image_id = cacheTable[1]
	self.image_obj = cacheTable[2]
	
	if self.image_id and not self.image_obj then
		self:DeleteThread(imagePath)
		self:CreateThread(imagePath, function(imageIdToLoad)
			local obj = AsyncGetResource(imageIdToLoad)
			cacheTable[2] = obj
			
			if self.image_id == imageIdToLoad then
				self.image_obj = obj
				self.src_rect = false
				self:CalcSrcRect()
			end
		end, self.image_id)
	else
		self.src_rect = false
		self:CalcSrcRect()
	end
	self.Image = imagePath
end

---
--- Generates the squad windows for the satellite view map.
---
--- This function iterates through the global `g_SquadsArray` table and creates a new `SquadWindow` template for each squad that has a current sector. The created windows are stored in the `squad_to_wnd` table, which is assigned to the `self.squad_to_wnd` property.
---
--- @param self XSatelliteViewMap The instance of the `XSatelliteViewMap` class.
function XSatelliteViewMap:GenerateSquadWindows()
	local squad_to_wnd = {}
	self.squad_to_wnd = squad_to_wnd

	for _, squad in ipairs(g_SquadsArray) do
		local squad_id = squad.UniqueId
		if squad.CurrentSector then
			local win = XTemplateSpawn("SquadWindow", self, squad)
			squad_to_wnd[squad_id] = win
		end
	end
end

---
--- Generates the shipment windows for the satellite view map.
---
--- This function iterates through the `g_BobbyRay_CurrentShipments` table and creates a new `BobbyRayShipmentSquad` template for each shipment. The created windows are stored in the `shipment_to_wnd` table, which is assigned to the `self.shipment_to_wnd` property.
---
--- @param self XSatelliteViewMap The instance of the `XSatelliteViewMap` class.
function XSatelliteViewMap:GenerateShipmentWindows()
	local shipment_to_wnd = {}
	self.shipment_to_wnd = shipment_to_wnd
	
	for _, shipment_details in pairs(g_BobbyRay_CurrentShipments) do
		shipment_to_wnd[shipment_details] = CreateBobbyRayShipmentSquad(shipment_details)
	end
end

function OnMsg.BobbyRayShopShipmentSent(shipment_details)
	if not (g_SatelliteUI and g_SatelliteUI.shipment_to_wnd) then return end
	g_SatelliteUI.shipment_to_wnd[shipment_details] = CreateBobbyRayShipmentSquad(shipment_details)
	if g_SatelliteUI.window_state == "open" then g_SatelliteUI.shipment_to_wnd[shipment_details]:Open() end
end

function OnMsg.BobbyRayShopShipmentArrived(shipment_details)
	if not (g_SatelliteUI and g_SatelliteUI.shipment_to_wnd) then return end
	
	local shipment_window = g_SatelliteUI.shipment_to_wnd[shipment_details]
	if not shipment_window then return end
	
	g_SatelliteUI.shipment_to_wnd[shipment_details] = nil
	shipment_window:Close()
end

function OnMsg.ActiveQuestChanged()
	if g_SatelliteUI then
		g_SatelliteUI:UpdateAllSectorVisuals()
	end
end

function OnMsg.UnitAssignedToSquad(squad_id)
	if not g_SatelliteUI then return end
	local squad = gv_Squads[squad_id]
	if not squad or not squad.CurrentSector then return end
	g_SatelliteUI:UpdateSectorVisuals(squad.CurrentSector)
end

function OnMsg.ConflictEnd(sector)
	if not g_SatelliteUI then return end
	g_SatelliteUI:UpdateSectorVisuals(sector.Id)
end

function OnMsg.BuildingLockChanged(sector_id)
	if not g_SatelliteUI then return end
	g_SatelliteUI:UpdateSectorVisuals(sector_id)
end

function OnMsg.SquadTravellingTickPassed(squad)
	if not g_SatelliteUI or not squad or not squad.CurrentSector then return end
	g_SatelliteUI:UpdateSectorVisuals(squad.CurrentSector)
end

---
--- Sets whether sector visual updates should be suppressed.
---
--- When visual updates are suppressed, the `UpdateAllSectorVisuals()` function will not be called.
--- This can be used to temporarily disable sector visual updates, for example when the satellite map
--- is not visible.
---
--- @param val boolean Whether to suppress sector visual updates or not.
---
function XSatelliteViewMap:SetSuppressSectorVisualUpdates(val)
	self.suppress_visual_updates = val
	if not val then
		self:UpdateAllSectorVisuals()
	end
end

---
--- Delays the update of all sector visuals on the satellite map.
---
--- This function creates a thread to update all sector visuals on the satellite map.
--- The update is delayed to avoid multiple updates happening at the same time, which
--- could cause performance issues.
---
--- The update is only performed if the window is not in the "destroying" state.
---
function XSatelliteViewMap:DelayedUpdateAllSectorVisuals()
	if self:GetThread("queue-update-all-sectors") then
		return
	end
	self:CreateThread("queue-update-all-sectors", function()
		if self.window_state == "destroying" then return end
		self:UpdateAllSectorVisuals()
	end)
end

---
--- Updates the visuals for all sectors on the satellite map.
---
--- This function iterates through all the sectors on the satellite map and calls `UpdateSectorVisuals()`
--- for each sector. It also updates the visibility of any shipment icons on the map.
---
--- This function is typically called when the satellite map needs to be refreshed, such as when
--- a new building is constructed or a squad moves to a new sector.
---
function XSatelliteViewMap:UpdateAllSectorVisuals()
	for id, _ in pairs(self.sector_to_wnd) do
		self:UpdateSectorVisuals(id)
	end
	self:UpdateShipmentsVisibility()
end

---
--- Returns a localized string representing the current satellite filter mode.
---
--- @return string The localized string for the current satellite filter mode.
---
function TFormat.SatelliteFilterMode()
	if not g_SatelliteUI then return end
	local mode = g_SatelliteUI.filter_info_mode
	if not mode then
		return T(366064427094, "Default")
	end
	if mode == "quests" then
		return T(210514527844, "Tasks")
	elseif mode == "buildings" then
		return T(491601259257, "Buildings")
	end
end

---
--- Updates the visibility of shipment icons on the satellite map.
---
--- This function iterates through all the current shipments and sets the visibility of the corresponding
--- shipment icon on the satellite map. The visibility is determined by the visibility of the sector window
--- and the current satellite filter mode.
---
--- If the filter mode is set to "stash", all shipment icons will be visible. Otherwise, the shipment icon
--- will only be visible if the sector window is also visible.
---
function XSatelliteViewMap:UpdateShipmentsVisibility()
	for _, shipment_details in pairs(g_BobbyRay_CurrentShipments) do
		local window = self.sector_to_wnd[shipment_details.sector_id]
		local shipWin = self.shipment_to_wnd[shipment_details]
		if shipWin then
			local visible = window.visible and (not self.filter_info_mode or self.filter_info_mode == "stash")
			shipWin:SetVisible(visible)
		end
	end
end

---
--- Toggles the filter mode of the satellite map view.
---
--- @param mode string|false The new filter mode. Can be "quests", "squads", or false to reset to the default mode.
---
function XSatelliteViewMap:ToggleFilterMode(mode)
	if	mode == "default" or
		mode and mode == self.filter_info_mode
	then
		mode = false
	end
	self.filter_info_mode = mode

	local questFilter = self.filter_info_mode == "quests"
	local squadFilter = self.filter_info_mode == "squads"
	
	local placeLabelOnSquad = squadFilter or questFilter
	local sectorsPlacedOn = placeLabelOnSquad and {} or false
	for i, squadWnd in pairs(self.squad_to_wnd) do
		local squad = squadWnd.context
		if squad.Side ~= "player1" then goto continue end
		
		local label = squadWnd.idLabel
		local hasLabel = not not label		
		if hasLabel ~= placeLabelOnSquad then
			if hasLabel then
				label:Close()
			elseif not sectorsPlacedOn[squad.CurrentSector] or IsSquadTravelling(squad) then
				local lbl = XTemplateSpawn("SatelliteSquadLabel", squadWnd, squad)
				lbl:SetId("idLabel")
				if squadWnd.window_state == "open" then lbl:Open() end
				
				if sectorsPlacedOn then sectorsPlacedOn[squad.CurrentSector] = true end
			end
		end
		
		::continue::
	end
	XUpdateRolloverWindow(RolloverControl)
	g_SatelliteUI:UpdateAllSectorVisuals()
	ObjModified("satellite_filters")
end

function OnMsg.OperationChanged(ud)
	if not g_SatelliteUI then return end
	local squad = ud.Squad
	ObjModified("SquadLabel" .. squad)
end

---
--- Shows or hides the sector ID UI element for the specified sector.
---
--- @param sector table The sector for which to show or hide the sector ID UI element.
--- @param show boolean Whether to show or hide the sector ID UI element.
---
function XSatelliteViewMap:ShowSectorIdUI(sector, show)
	local window = self.sector_to_wnd[sector.Id]
	if not window then return end
	
	local sectorId = window.context.Id
	if not window.idSectorIcon then
		local sectorIcon = XTemplateSpawn("SectorWindowId", g_SatelliteUI)
		sectorIcon:SetHAlign("left")
		sectorIcon:SetVAlign("top")
		sectorIcon:SetScaleModifier(point(550, 550))
		sectorIcon.ScaleWithMap = false
		sectorIcon.UpdateZoom = function(self, prevZoom, newZoom, time)
			local map = self.map
			local maxZoom = map:GetScaledMaxZoom()
			local minZoom = Max(1000 * map.box:sizex() / map.map_size:x(), 1000 * map.box:sizey() / map.map_size:y())
			local scaleAddition = MulDivRound(100, self.scale:x(), 1000)
			newZoom = Clamp(newZoom, minZoom + scaleAddition, maxZoom)
			XMapWindow.UpdateZoom(self, prevZoom, newZoom, time)
		end
		rawset(window, "idSectorIcon", sectorIcon)
		sectorIcon:SetPos(window.PosX, window.PosY)
		sectorIcon.idSectorId:SetText(T{764093693143, "<SectorIdColored(id)>", id = sectorId})
		if window.window_state == "open" then sectorIcon:Open() end
	end
	
	if show and window.idSectorIcon then
		local sectorIcon = window.idSectorIcon
		local color = GetSectorControlColor(sector.Side)
		sectorIcon.idSectorIdBg:SetBackground(color)
	end
	
	window.idSectorIcon:SetVisible(show)
end

function OnMsg.GamepadUIStyleChanged()
	if g_SatelliteUI then
		g_SatelliteUI:ShowCursorHint(g_SatelliteUI.showCursorHint_CachedShow, g_SatelliteUI.showCursorHint_CachedReason)
	end
end

---
--- Shows or hides the cursor hint UI element on the satellite map, with optional text and styling.
---
--- @param show boolean Whether to show or hide the cursor hint.
--- @param reason string The reason for showing the cursor hint, such as "travel", "travel_mode", or "none".
---
function XSatelliteViewMap:ShowCursorHint(show, reason)
	self.showCursorHint_CachedShow = show
	self.showCursorHint_CachedReason = reason
	if show and not g_ZuluMessagePopup and not RolloverWin then
		local text = false
		local style = false
		local isTravelling = IsSquadTravelling(self.selected_squad, "skip_satellite_tick")
		
		if isTravelling and (reason == "travel" or reason == "none") then -- if travelling click is cancel or nothing
			if CanCancelSatelliteSquadTravel(self.selected_squad) == "enabled" then
				text = GetUIStyleGamepad() and
						T(614351336268, "<ButtonBSmall> Cancel Travel") or
						T(392145576074, "<left_click> Cancel Travel")
			end
		elseif reason == "travel" then -- no mode selected, click is set route
			text = GetUIStyleGamepad() and
					T(109122385021, "<ButtonASmall> Travel<newline><ButtonXSmall> Sector menu") or
					T(828415810044, "<left_click> Travel")
		elseif reason == "travel_mode" then -- plotting travel, get errors to show on cursor
			if self.travel_mode then 
				local travelMode = self.travel_mode
				local invalidRoute, errs = IsRouteForbidden(travelMode.route, travelMode.squad)
				if invalidRoute and #(errs or "") > 0 then
					style = "error"
					text = errs[1]
				end
			end
			
			if not text then
				text = GetUIStyleGamepad() and
						T(938773041595, "<ButtonASmall> Set <newline><ButtonBSmall> Cancel") or
						T(103054576698, "<left_click> Set<newline><right_click> Cancel")
			end
		end
		
		if not text and GetUIStyleGamepad() then
			text = T(427350777180, "<ButtonXSmall> Sector menu")
		end
		
		if style == "error" then
			self.cursor_hint:SetBackground(GetColorWithAlpha(GameColors.B, 220))
			self.cursor_hint:SetBorderWidth(2)
			self.cursor_hint:SetBorderColor(GameColors.I)
			self.cursor_hint:SetMaxWidth(250)
			self.cursor_hint:SetPadding(box(3, 3, 3, 3))
			text = T{772176985382, "<error><txt></error>", txt = text}
		else
			self.cursor_hint:SetBackground(0)
			self.cursor_hint:SetBorderWidth(0)
			self.cursor_hint:SetBorderColor(GameColors.I)
			self.cursor_hint:SetMaxWidth(999)
			self.cursor_hint:SetPadding(empty_box)
		end
		
		self.cursor_hint.idText:SetText(text)	
		self.cursor_hint:SetVisible(not not text)
	else
		self.cursor_hint:SetVisible(false)
	end
end

function OnMsg.ZuluMessagePopup()
	if not g_SatelliteUI then return end
	g_SatelliteUI:RemoveContextMenu()
	g_SatelliteUI:ShowCursorHint(false)
end

function OnMsg.CreateRolloverWindow()
	if not g_SatelliteUI then return end
	g_SatelliteUI:ShowCursorHint(false)
end

function OnMsg.DestroyRolloverWindow()
	if not g_SatelliteUI then return end
	g_SatelliteUI:ShowCursorHint(true, g_SatelliteUI.showCursorHint_CachedReason)
end

---
--- Updates the visual representation of a sector on the satellite map.
---
--- @param sector_id integer The ID of the sector to update.
---
function XSatelliteViewMap:UpdateSectorVisuals(sector_id)
	if self.suppress_visual_updates then return end

	local sector = gv_Sectors[sector_id]
	local sectorVisible = IsSectorRevealed(sector)
	local window = self.sector_to_wnd[sector_id]
	window:SetVisible(window.layer == self.layer_mode)
	
	local windowIsVisible = window.visible
	local inConflict = IsConflictMode(sector_id)
	
	window:SetSectorVisible(sectorVisible)
	
	-- Drawing data
	local windowLayer = window.layer
	local visibleMap = self.sector_visible_map[windowLayer]
	local playerMask = self.sector_player[windowLayer]
	local enemyMask = self.sector_enemy[windowLayer]
	local neutralMask = self.sector_neutral[windowLayer]
	
	local pos_y, pos_x = sector_unpack(sector_id)
	local mapIdx = 1 + pos_x - 1 + (pos_y - 1) * self.sector_max_x
	visibleMap[mapIdx] = not not sectorVisible -- the C++ side needs strictly true/false here
	
	local side = sector.Side
	if (side == "player1" or side == "player2") and not sector.ForceConflict and sector.Passability ~= "Water" then
		playerMask[mapIdx] = true
		enemyMask[mapIdx] = false
		neutralMask[mapIdx] = false
	elseif (side == "enemy1" or side == "enemy2") and sector.Passability ~= "Water" then
		enemyMask[mapIdx] = true
		playerMask[mapIdx] = false
		neutralMask[mapIdx] = false
	elseif side == "neutral" and sector.Passability ~= "Water" and sector.Passability ~= "Blocked" then
		neutralMask[mapIdx] = true
		enemyMask[mapIdx] = false
		playerMask[mapIdx] = false
	else
		neutralMask[mapIdx] = false
		enemyMask[mapIdx] = false
		playerMask[mapIdx] = false
	end
	
	if windowLayer == "underground" then
		local groundSectorId = sector.GroundSector
		local groundSector = gv_Sectors[groundSectorId]
		if groundSector and groundSector.HideUnderground then
			neutralMask[mapIdx] = false
			enemyMask[mapIdx] = false
			playerMask[mapIdx] = false
		end
	end
	
	if not sector.discovered then
		neutralMask[mapIdx] = false
		enemyMask[mapIdx] = false
		playerMask[mapIdx] = false
	end

	local questMode = self.filter_info_mode == "quests"
	local buildingMode = self.filter_info_mode == "buildings"
	local stashMode = self.filter_info_mode == "stash"
	local filterShowSquads = not questMode and not buildingMode and not stashMode

	-- sector indicator
	local sectorIndicatorVisible = self.selected_sector == sector or self.rollover_sector == sector
	self:ShowSectorIdUI(sector, sectorIndicatorVisible)

	-- If the window is toggled to show the underground/overground sector act as if the other one is invisible.
	sectorVisible = sectorVisible and windowIsVisible

	-- Objects on sector visibility
	local playerSquads, enemySquads = GetSquadsInSector(sector.Id, nil, "includeMilitia")
	local enemySquadsInShortcuts = UIGetSquadsInShortcutsHere(window)
	local playerSquadCount, enemySquadCount = #playerSquads, #enemySquads
	local top_priority_shown = false -- set top priority visible and delete all the others
	local sel_id = false
	
	-- Count non travelling squads to display multi-squad image.
	local nonTravellingSquadCount = 0
	for i = 1, playerSquadCount + enemySquadCount do
		local squad = i > playerSquadCount and enemySquads[i - playerSquadCount] or playerSquads[i]
		if not IsSquadTravelling(squad, not IsSquadInSectorVisually(squad)) then
			nonTravellingSquadCount = nonTravellingSquadCount + 1
		end
	end

	-- Sector switch (underground/overground)
	local otherSectorId = GetUnderOrOvergroundId(sector_id)
	if window.idUnderground then
		window.idUnderground:SetImage(GetUndergroundButtonIcon(otherSectorId))
	end
	
	if window.idUndergroundImage then
		local undergroundImage = sector.UndergroundImage or "UI/SatelliteView/sector_underground"
		if inConflict then
			undergroundImage = undergroundImage .. "_conflict"
		end
		window.idUndergroundImage:SetImage(undergroundImage)
		window.idUndergroundImage:SetImageColor(sectorVisible and white or RGB(150, 150, 150))
	end

	-- 1. selected_squad
	if self.selected_squad and table.find(playerSquads, "UniqueId", self.selected_squad.UniqueId) then
		local squadInConflict = IsSquadInConflict(self.selected_squad)
		local travelling = IsSquadTravelling(self.selected_squad, not IsSquadInSectorVisually(self.selected_squad))

		if squadInConflict then
			travelling = false
		end

		top_priority_shown = not travelling and filterShowSquads
		sel_id = self.selected_squad.UniqueId
		
		local squadWin = self.squad_to_wnd[self.selected_squad.UniqueId]			
		if squadWin then
			squadWin:SetVisible(sectorVisible and filterShowSquads)
			local visConflict = sectorVisible and squadInConflict
			squadWin:SetConflictMode(visConflict)
			squadWin:SetAnim(squadWin.rollover)
			squadWin.idMoreSquads:SetVisible(top_priority_shown and nonTravellingSquadCount > 1 and not visConflict)
			squadWin.idSquadSelection.idSquadRollover:SetVisible(false)
			squadWin.idSquadSelection.idSquadSelSmall:SetVisible(true)
			squadWin.idSquadSelection.idSquadSelBig:SetVisible(true)
		end
	end
	
	-- 1.5 Shortcut Travelling Enemy Squads
	for i, s in ipairs(enemySquadsInShortcuts) do
		local squadWin = self.squad_to_wnd[s.UniqueId]
		if squadWin then
			squadWin:SetVisible(windowIsVisible and filterShowSquads)
			squadWin:SetAnim(squadWin.rollover)
			squadWin.idMoreSquads:SetVisible(false)
		end
	end
	
	-- 2. player squad 3. enemy squad
	for i = 1, playerSquadCount + enemySquadCount do
		local squad = i > playerSquadCount and enemySquads[i - playerSquadCount] or playerSquads[i]
		if sel_id == squad.UniqueId then goto continue end
		
		local squadWin = self.squad_to_wnd[squad.UniqueId]
		if not squadWin then goto continue end

		local nonPlayer = squad.Side ~= "player1"
		if nonPlayer and IsTraversingShortcut(squad) then goto continue end
	
		local squadInConflict = IsSquadInConflict(squad)
		local travelling = IsSquadTravelling(squad, not IsSquadInSectorVisually(squad))
		local nonPlayerTravelling = nonPlayer and travelling
		
		-- Dont show the patrol squad for the crocodile guardpost objective.
		-- Dirty hack to test
		if squad.enemy_squad_def == "CampCrocodile_CirclingPatrol" then
			nonPlayerTravelling = false
		end
		
		local vis = (sectorVisible or squad.always_visible or squad.arrival_squad or nonPlayerTravelling) and
						(not top_priority_shown or travelling) and
						filterShowSquads
		vis = vis and windowIsVisible
						
		local showRouteEvenIfInvisible = sectorVisible and not vis and filterShowSquads
		squadWin:SetVisible(vis, showRouteEvenIfInvisible and "iconOnly")
		local visConflict = sectorVisible and not top_priority_shown and squadInConflict
		squadWin:SetConflictMode(visConflict)
		squadWin:SetAnim(squadWin.rollover)
		
		local iAmTop = top_priority_shown
		top_priority_shown = top_priority_shown or (vis and not travelling)
		iAmTop = not iAmTop and top_priority_shown
		squadWin.idMoreSquads:SetVisible(iAmTop and nonTravellingSquadCount > 1 and not visConflict)

		::continue::
	end
	
	-- 4. quests
	local underground = gv_Sectors[sector_id .. "_Underground"]
	local quests = GetQuestsAssociatedWithSector(sector_id)
	local activeQuest = false
	local questSectorId = sector_id
	-- If no quests on this sector, check above/below ground, since they're shown on the same square.
	if #quests == 0 and otherSectorId then
		quests = GetQuestsAssociatedWithSector(otherSectorId)
	end
	local hasQuests = #quests > 0
	local activeQuest = GetQuestsAssociatedWithSector(questSectorId, "active_only")
	local hasActiveQuest = #activeQuest > 0

	local hasMarker = not not window.idQuestMarker	
	local showMarker = (hasActiveQuest or questMode) and hasQuests
	local contextQuest = questMode and quests or activeQuest
	if hasMarker and window.idQuestMarker.context.quest ~= contextQuest then -- Check if displaying the same quest data.
		window.idQuestMarker:Close()
		hasMarker = false
	end
	
	if questMode and showMarker then
		if windowIsVisible then self:ShowSectorIdUI(sector, true) end
		window.quest_shows_sectorId = true
	else
		window.quest_shows_sectorId = false
	end
	if questMode then
		top_priority_shown = true
	end
	
	if hasMarker ~= showMarker then
		if hasMarker and not showMarker then
			window.idQuestMarker:Close()
		elseif not hasMarker and showMarker then
			local questMarker = XTemplateSpawn("SatelliteQuestIcon", window, { sector = gv_Sectors[questSectorId], quest = contextQuest })
			questMarker:SetId("idQuestMarker")
			questMarker:SetHAlign("left")
			questMarker:SetVAlign("bottom")
			questMarker:SetImage("UI/Icons/SateliteView/main_quest")
			if window.window_state == "open" then questMarker:Open() end		
		end
	end
	if window.idIntelMarker then
		window.idIntelMarker:SetVisible(sector.Intel and sector.intel_discovered and questMode)
	end
	
	-- In the quest filter the quest icon looks bigger
	if window.idQuestMarker then
		local marker = window.idQuestMarker
		if rawget(marker, "questMode") ~= questMode then
			if questMode then
				marker:SetHAlign("center")
				marker:SetVAlign("center")
				marker:SetScaleModifier(point(2000, 2000))
				rawset(marker, "questMode", true)
			else
				marker:SetHAlign("left")
				marker:SetVAlign("bottom")
				marker:SetScaleModifier(point(1000, 1000))
				rawset(marker, "questMode", false)
			end
		end
	end
	
	-- 5. POIs (buildings)	
	local sectorSide = sector.Side
	local sectorPOIs = false
	for _, poi in ipairs(POIDescriptions) do
		if sector[poi.id] then
			if not sectorPOIs then sectorPOIs = {} end
			sectorPOIs[#sectorPOIs + 1] = poi.id
		end
	end
	
	local firstPOIId = sectorPOIs and sectorPOIs[1]

	local templateName = "SatelliteSectorIconPOI"
	if firstPOIId == "Guardpost" and not buildingMode then
		templateName = "SatelliteSectorIconGuardpost"
	end

	local shouldHavePOI = not not firstPOIId and sector.reveal_allowed
	local hasPOIIcon = not not window.idPointOfInterest
	
	-- Despawn if changing to a different template
	if hasPOIIcon and shouldHavePOI then
		if window.idPointOfInterest.context.template ~= templateName then
			window.idPointOfInterest:Close()
			hasPOIIcon = false
		end
	end
	
	local canSpawnAsMainIcon = not top_priority_shown and not stashMode
	top_priority_shown = true
	if hasPOIIcon ~= shouldHavePOI then
		if not shouldHavePOI and hasPOIIcon then
			window.idPointOfInterest:Close()
			hasPOIIcon = false
		else
			local poiIcon = XTemplateSpawn(templateName, window, { sector = sector, template = templateName })
			if window.window_state == "open" then poiIcon:Open() end
			hasPOIIcon = true
		end
	end
	
	if hasPOIIcon then
		local wnd = window.idPointOfInterest
		wnd:Update(canSpawnAsMainIcon and "main" or "side", sectorPOIs)
	end
	
	-- Place underground POI
	local undegroundIconList = window.idUndergroundIconsList
	if underground and undegroundIconList then
		local node = undegroundIconList:ResolveId("node")
		for _, poi in ipairs(POIDescriptions) do
			local uPOI = poi.id
			local hasPOI = shouldHavePOI and underground[uPOI]
			local hasPOIUI = node["idUndergroundPOI" .. uPOI]
			
			if (not not hasPOI) ~= (not not hasPOIUI) then
			
				if hasPOI then
					local undergroundPOI = XTemplateSpawn("SatelliteIconPointOfInterest", undegroundIconList, {
						building = uPOI,
						pois = { uPOI },
						sector = underground
					})
					
					undergroundPOI:SetMain(false)
					undergroundPOI:SetScaleModifier(point(800, 800))
					undergroundPOI:SetId("idUndergroundPOI" .. uPOI)
					
					if window.window_state == "open" then undergroundPOI:Open() end		
				else
					hasPOIUI:Close()
				end
			
			end
			
			if hasPOIUI then
				hasPOIUI:UpdateStyle();
			end
		end
	end
	
	-- 6. Stash
	local hasStashIcon = not not window.idStashIcon
	local shouldHaveStashIcon = stashMode
	local stashObject = false
	if stashMode then
		if hasStashIcon then
			stashObject = window.idStashIcon.context
		else
			stashObject = PlaceObject("SectorStash")
			stashObject:SetSectorId(sector_id)
		end

		shouldHaveStashIcon = playerSquadCount > 0 or stashObject:CountItemsInSlot("Inventory") >= 1
	end
	if shouldHaveStashIcon ~= hasStashIcon then
		if hasStashIcon and not shouldHaveStashIcon then
			window.idStashIcon:Close()
			if window.idStashIconMercs then
				window.idStashIconMercs:Close()
			end
		elseif not hasStashIcon and shouldHaveStashIcon then
			local stashIcon = XTemplateSpawn("SatelliteStashIcon", window, stashObject)
			stashIcon:SetId("idStashIcon")
			if window.window_state == "open" then stashIcon:Open() end		
		end
	end
end

function OnMsg.RevealedSectorsUpdate()
	if not g_SatelliteUI then return end
	g_SatelliteUI:UpdateAllSectorVisuals()
end

function OnMsg.ConflictStart(sector_id)
	if not g_SatelliteUI then return end
	g_SatelliteUI:UpdateSectorVisuals(sector_id)
end

function OnMsg.SquadSpawned(squadId)
	assert(squadId)
	if not g_SatelliteUI or not squadId then return end
	local squad = gv_Squads[squadId]
	local window = g_SatelliteUI.squad_to_wnd[squadId]
	assert(not window)
	if not window then
		window = XTemplateSpawn("SquadWindow", g_SatelliteUI, squad)
		if g_SatelliteUI.window_state == "open" then window:Open() end
		g_SatelliteUI.squad_to_wnd[squadId] = window
	end
	RecalcRevealedSectors()
	local playerSquad = squad.Side == "player1"
	if playerSquad then ObjModified("ui_player_squads") end
end

function OnMsg.SquadDespawned(squadId, sector, side)
	assert(squadId)
	if not g_SatelliteUI or not squadId then return end
	local window = g_SatelliteUI.squad_to_wnd[squadId]
	if window then
		window:Close()
		g_SatelliteUI.squad_to_wnd[squadId] = nil
	end
	RecalcRevealedSectors()
	local playerSquad = side == "player1"
	if playerSquad then ObjModified("ui_player_squads") end
end

-- Note: Removed ObjModified(squad) from these msgs and associated logic.
-- These should only matter when the squad is the selected squad.
-- OperationChanged
-- SquadStartedTravelling
-- ReachSectorCenter

function OnMsg.MercReleased(squadId, mercUd)
	ObjModified("ui_player_squads")
end

function OnMsg.SquadStartedTravelling(squad)
	if not g_SatelliteUI or not squad then return end
	local sectorId = squad.CurrentSector
	if sectorId then
		g_SatelliteUI:UpdateSectorVisuals(sectorId)
		local squadWin = g_SatelliteUI.squad_to_wnd[squad.UniqueId]
		squadWin:SetAnim(true)
	end
	
	local travelMode = g_SatelliteUI.travel_mode
	if travelMode and travelMode.squad == squad then
		g_SatelliteUI:ExitTravelMode()
	end
end

function OnMsg.SquadFinishedTraveling(squad)
	local squadWin = g_SatelliteUI.squad_to_wnd[squad.UniqueId]
	squadWin:SetAnim(false)
end

---
--- Returns the campaign speed factor to apply to the satellite map.
---
--- If the campaign is paused, returns 0 to fully desaturate the map.
--- Otherwise, returns 1000 as the default campaign speed factor.
---
--- @return number The campaign speed factor to apply to the satellite map.
function GetCampaignSpeedXMapFactor()
	if IsCampaignPaused() then return 0 end
	return 1000
end

function OnMsg.CampaignSpeedChanged()
	if not g_SatelliteUI then return end
	g_SatelliteUI:SetTimeFactor(GetCampaignSpeedXMapFactor())
	UpdateSatelliteDesaturation()
end

---
--- Updates the satellite map desaturation based on the current campaign speed.
---
--- If the campaign is paused, the map will be fully desaturated (100% desaturation).
--- Otherwise, the map will be fully saturated (0% desaturation).
---
--- The desaturation is interpolated over 500 milliseconds.
---
function UpdateSatelliteDesaturation()
	local factor = GetCampaignSpeedXMapFactor()
	
	local mod = {
		id = "desat",
		type = const.intDesaturation,
		startValue = factor == 0 and 0 or 100,
		endValue = factor == 0 and 100 or 0,
		duration = 500,
		interpolate_clip = false
	}
	g_SatelliteUI:AddInterpolation(mod)
	g_SatelliteUI:SetDesaturation(factor == 0 and 150 or 0)
end

DefineClass.XSatelliteViewMapBaseParams = {
	__parents = { "MeshParamSet", "UIFxModifierPreset" },
	properties = {
		{ uniform = true, id = "OriginalImgAlpha", editor = "number", default = 0, scale = 1000, },
		{ uniform = true, id = "BorderWidth", editor = "number", default = 0, scale = 1000, },
		{ uniform = true, id = "BorderColor", editor = "color", default = RGB(255,255,255) },
		{ uniform = true, id = "BorderOffset", editor = "number", default = 0, min = -500, max = 500, slider = true, scale = 1000, },

		{ uniform = true, id = "InsideColor", editor = "color", default = RGB(255, 255, 255) },
		{ uniform = true, id = "InsideGlowMin", editor = "number", scale = 1000, default = 0, slider = true, min = 0, max = 1500},
		{ uniform = true, id = "InsideGlowMax", editor = "number", scale = 1000, default = 0, slider = true, min = 0, max = 1500},
		{ uniform = true, id = "InsideGlowPow", editor = "number", scale = 1000, default = 1000, slider = true, min = 0, max = 4000},
		{ uniform = true, id = "InsideInterlace", editor = "number", scale = 1000, default = 0, slider = true, min = 0, max = 1000},
		{ uniform = true, id = "InsideGroundLoopColor", editor = "color", default = RGB(255,255,255),  },
		{ uniform = true, id = "InsideGroundLoopGlow", editor = "number", default = 0, min = 0, max = 500, slider = true, scale = 1000, },
		{ uniform = true, id = "InsideGroundLoopSpeed", editor = "number", default = 0, min = 0, max = 1000, scale = 1000, },
		{ uniform = true, id = "InsideGroundLoopLength", editor = "number", default = 0, min = 0, max = 20000, scale = 1000, },
		{ uniform = true, id = "InsideGroundLoopPauseLen", editor = "number", default = 0, min = 0, max = 20000, scale = 1000, },
		{ uniform = true, id = "InsideGroundLoopStrength1", editor = "number", default = 0, min = 0, max = 1000, scale = 1000, },
		{ uniform = true, id = "InsideGroundLoopStrength2", editor = "number", default = 0, min = 0, max = 1000, scale = 1000, },

		{ uniform = true, id = "OutsideColor", editor = "color", default = RGB(255, 255, 255) },
		{ uniform = true, id = "OutsideGlowMin", editor = "number", scale = 1000, default = 0, slider = true, min = 0, max = 1500},
		{ uniform = true, id = "OutsideGlowMax", editor = "number", scale = 1000, default = 0, slider = true, min = 0, max = 1500},
		{ uniform = true, id = "OutsideGlowPow", editor = "number", scale = 1000, default = 1000, slider = true, min = 0, max = 4000},
		{ uniform = true, id = "OutsideInterlace", editor = "number", scale = 1000, default = 0, slider = true, min = 0, max = 1000},
		{ uniform = true, id = "OutsideGroundLoopColor", editor = "color", default = RGB(255,255,255),  },
		{ uniform = true, id = "OutsideGroundLoopGlow", editor = "number", default = 0, min = 0, max = 500, slider = true, scale = 1000, },
		{ uniform = true, id = "OutsideGroundLoopSpeed", editor = "number", default = 1000, min = 0, max = 3000, scale = 1000, },
		{ uniform = true, id = "OutsideGroundLoopLength", editor = "number", default = 6000, min = 0, max = 20000, scale = 1000, },
		{ uniform = true, id = "OutsideGroundLoopPauseLen", editor = "number", default = 0, min = 0, max = 20000, scale = 1000, },
		{ uniform = true, id = "OutsideGroundLoopStrength1", editor = "number", default = 0, min = 0, max = 1000, scale = 1000, },
		{ uniform = true, id = "OutsideGroundLoopStrength2", editor = "number", default = 0, min = 0, max = 1000, scale = 1000, },

		{ uniform = true, id = "LodBias", name = "LodBias (Blur)", editor = "number", default = 0, min = -10000, max = 10000, scale = 1000, slider = true, },
	},
	StoreAsTable = false,
}
DefineClass.XSatelliteViewParams = {
	__parents = { "PersistedRenderVars" },
	group = "XSatelliteViewParams",

	properties = {
		{id = "visible_grid_color", editor = "color", default = RGBA(110, 110, 110, 170)},
		{id = "invisible_grid_color", editor = "color", default =  RGBA(110, 110, 110, 170),},
		{id = "grid_width", editor = "number", min = 1, max = 20, default = 6, },

		{id = "vision_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
		{id = "vision_blur_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
		{id = "neutral_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
		{id = "player_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
		{id = "enemy_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
		{id = "selected_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
		{id = "rollover_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
		{id = "neutral_sector_id", editor = "preset_id", preset_class = "XSatelliteViewMapBaseParams", default = false,},
	},
}

local ModifiersSetTop = UIL.ModifiersSetTop
local ModifiersGetTop = UIL.ModifiersGetTop
local PushModifier = UIL.PushModifier

---
--- Draws the content of the XSatelliteViewMap UI element.
---
--- This function is responsible for rendering the satellite view map, including the background image, grid, and various sector overlays.
---
--- @param self XSatelliteViewMap The instance of the XSatelliteViewMap UI element.
---
function XSatelliteViewMap:DrawContent()
	if not self.Image or self.Image == "" or not self.sector_visible_map then return end

	local image_src = self:CalcSrcRect()
	local satview_image_size = image_src:size()

	local src = box(0, 0, self.map_size:x(), self.map_size:y())
	local width, height = self.map_size:xyz()
	local color = self.ImageColor

	local start_x = self.grid_start:x()
	local start_y = self.grid_start:y()
	local sector_size_x = self.sector_size:x()
	local sector_size_y = self.sector_size:y()

	local satviewSpaceToSrcrc = function(value)
		if IsPoint(value) then
			return MulDivRoundPoint(value, satview_image_size, self.map_size)
		else
			return box(MulDivRoundPoint(value:min(), satview_image_size, self.map_size),
				MulDivRoundPoint(value:max(), satview_image_size, self.map_size))
		end
	end

	local dst_rect = sizebox(start_x, start_y, sector_size_x * self.sector_max_x, sector_size_y * self.sector_max_y)
	local src_rect = satviewSpaceToSrcrc(dst_rect)
	
	local smallImage = dst_rect:size() == src_rect:size()

	local draw_as_paused = IsCampaignPaused()
	--- DrawBackground
	local top = XPushShaderEffectModifier(draw_as_paused and "SatelliteViewFog_Blur" or "SatelliteViewFog")
	UIL.DrawXImage(self.Image,
		box(0, 0, width, height), width, height, satviewSpaceToSrcrc(src),
		color, color, color, color,
		self:CalcDesaturation(), self.Angle, self.FlipX, self.FlipY,
		self.EffectType, self.EffectPixels, self.EffectColor, not smallImage,
		RGBA(255,255,255,0), src_rect:minx(), src_rect:miny(), satview_image_size:x() - src_rect:maxx(), satview_image_size:y() - src_rect:maxy())
	ModifiersSetTop(top)
	--- EndDrawBackground

	local white = RGB(255,255,255)
	
	local shader_params
	if self.layer_mode == "underground" then
		shader_params = XSatelliteViewParams:GetById("NewXSatelliteViewParamsUnderground")
	else
		shader_params = XSatelliteViewParams:GetActiveInstance()
	end
	shader_params = shader_params or XSatelliteViewParams

	local shader_buf = pstr()
	local currentLayer = self.layer_mode
	local visible_sectors = table.copy(self.sector_visible_map[currentLayer])
	local player_sectors = table.copy(self.sector_player[currentLayer])
	local enemy_sectors = table.copy(self.sector_enemy[currentLayer])
	local neutral_sectors = table.copy(self.sector_neutral[currentLayer])
	
	local width, height = 	self.sector_max_x, self.sector_max_y
	local selected_sectors, rollover_sectors = {}, {}
	for i = 1, width * height do
		selected_sectors[i] = false
		rollover_sectors[i] = false
	end
	
	if self.selected_sector_fx then
		local id = self.selected_sector_fx.Id
		local y, x = sector_unpack(id)
		local idx = 1 + (x - 1) + (y - 1) * self.sector_max_x
		selected_sectors[idx] = true
	end
	
	if self.rollover_sector_fx then
		local id = self.rollover_sector_fx.Id
		local y, x = sector_unpack(id)
		local idx = 1 + (x - 1) + (y - 1) * self.sector_max_x
		rollover_sectors[idx] = true
	end
	
	if self.blinking_sector_fx then
		local id = self.blinking_sector_fx.Id
		local y, x = sector_unpack(id)
		local idx = 1 + (x - 1) + (y - 1) * self.sector_max_x
		rollover_sectors[idx] = true
	end
	
	local sectorMax = point(self.sector_max_x, self.sector_max_y)
	local vision_mask_id = draw_as_paused and shader_params.vision_blur_id or shader_params.vision_id
	shader_buf = (UIFxModifierPresets[vision_mask_id] or XSatelliteViewMapBaseParams):ComposeBuffer(shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, sectorMax, visible_sectors, shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, sectorMax, selected_sectors, shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, sectorMax, rollover_sectors, shader_buf)

	UILDrawSatelliteViewLines(dst_rect, sectorMax, visible_sectors, shader_params.visible_grid_color, shader_params.invisible_grid_color, shader_params.grid_width)

	shader_buf = (UIFxModifierPresets[shader_params.neutral_id] or XSatelliteViewMapBaseParams):ComposeBuffer(shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, sectorMax, visible_sectors, shader_buf)
	
	shader_buf = (UIFxModifierPresets[shader_params.neutral_sector_id] or XSatelliteViewMapBaseParams):ComposeBuffer(shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, sectorMax, neutral_sectors, shader_buf)

	shader_buf = (UIFxModifierPresets[shader_params.enemy_id] or XSatelliteViewMapBaseParams):ComposeBuffer(shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, sectorMax, enemy_sectors, shader_buf)

	shader_buf = (UIFxModifierPresets[shader_params.player_id] or XSatelliteViewMapBaseParams):ComposeBuffer(shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, sectorMax, player_sectors, shader_buf)

	shader_buf = (UIFxModifierPresets[shader_params.selected_id] or XSatelliteViewMapBaseParams):ComposeBuffer(shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, sectorMax, selected_sectors, shader_buf)

	shader_buf = (UIFxModifierPresets[shader_params.rollover_id] or XSatelliteViewMapBaseParams):ComposeBuffer(shader_buf)
	UILDrawSatelliteViewMap(self.Image, white, dst_rect, src_rect, sectorMax, rollover_sectors, shader_buf)

	-- Debug visualize satellite shortcut path
--[[	local shortcutPreset = SatelliteShortcuts[1]
	local resolution = 200
	local increment = 1000 / resolution
	for i = 0, 1000 - increment, increment do
		local pt1 = GetShortcutCurvePointAt(shortcutPreset, i)
		local pt2 = GetShortcutCurvePointAt(shortcutPreset, i + increment)
		UIL.DrawLineAntialised(10, pt1, pt2, green)
	end]]
end

--- Returns the current mouse cursor for this XSatelliteViewMap instance.
---
--- @return string The current mouse cursor.
function XSatelliteViewMap:GetMouseCursor()
	return self.mouse_cursor
end

---
--- Retrieves the first UI element of the specified class that the mouse cursor is currently over.
---
--- @param pt table|string The screen position to check, or the string "mouse" to use the current mouse cursor position.
--- @param class string The class of UI element to search for.
--- @return table|nil The first UI element of the specified class that the mouse cursor is over, or nil if none is found.
--- @return string The mouse cursor type that should be used for the UI element.
---
function XSatelliteViewMap:GetMouseTargetOfType(pt, class)
	local target, mouse_cursor
	for i = #self, 1, -1 do
		local win = self[i]
		if (not target or win.DrawOnTop) and win:MouseInWindow(pt) then
			if IsKindOf(win, class) then
				return win, win:GetMouseCursor()
			end
			local newTarget, newMouse_cursor = win:GetMouseTarget(pt)
			if IsKindOf(newTarget, class) then
				return newTarget, newMouse_cursor
			end
		end
	end
end

---
--- Retrieves the sector window under the specified screen position.
---
--- @param pos table|string The screen position to check, or the string "mouse" to use the current mouse cursor position.
--- @param mapSpace boolean If true, the position is assumed to be in map space, otherwise it is assumed to be in screen space.
--- @return table|nil The sector window under the specified position, or nil if none is found.
---
function XSatelliteViewMap:GetSectorOnPos(pos, mapSpace)
	if pos == "mouse" then pos = terminal.GetMousePos() end

	if not mapSpace then pos = self:ScreenToMapPt(pos) end
	return self:GetMouseTargetOfType(pos, "SectorWindow")
end

--- UI Functionality
------

---
--- Sets the camera destination to the specified sector and optionally animates the camera movement.
---
--- @param sector string The ID of the sector to center the camera on.
--- @param time number The duration in seconds of the camera animation, or 0 to instantly center the camera.
---
function SatelliteSetCameraDest(sector, time)
	local sector = gv_Sectors[sector]
	if not sector or not g_SatelliteUI then return end
	local pos = sector.XMapPosition
	g_SatelliteUI:CenterScrollOn(pos:x(), pos:y(), time)
	
	if time and time > 0 then
		SectorWindowBlink(sector)
	end
end

---
--- Selects the specified squad and updates the UI.
---
--- @param squad table The squad to select.
--- @return table The selected squad.
---
function XSatelliteViewMap:SelectSquad(squad)
	local partyCont = self:ResolveId("idPartyContainer")
	partyCont:SelectSquad(squad)
	return partyCont.selected_squad
end

---
--- Selects the specified sector and updates the UI accordingly.
---
--- @param sector table The sector to select, or `false` to deselect the current sector.
---
function XSatelliteViewMap:SelectSector(sector)
	if true then return end

	if sector and sector.Passability == "Water" then
		sector = false
	end
	if sector == self.selected_sector then 
		--sector = false
		return
	end

	if self.selected_sector then self:ShowSectorIdUI(self.selected_sector, false) end
	if sector then self:ShowSectorIdUI(sector, true) end

	self.selected_sector = sector
	self.selected_sector_fx = sector and sector.GroundSector and gv_Sectors[sector.GroundSector] or sector
	ObjModified("sector_selection_changed")
	ObjModified("sector_selection_changed_actions")
	-- If switching underground/overground selection reflect the change on the
	-- in-map sector as well.
	local wnd = sector and self.sector_to_wnd[sector.Id]
	if wnd and not wnd.visible and wnd.idUnderground then
		wnd.idUnderground:SwapSector()
	end
end

---
--- Returns the sector info panel UI element.
---
--- @return table The sector info panel UI element.
---
function GetSectorInfoPanel()
	return g_SatelliteUI and g_SatelliteUI.parent.idSectorInfoPanel
end

---
--- Returns the travel panel UI element.
---
--- @return table The travel panel UI element.
---
function GetTravelPanel()
	return g_SatelliteUI and g_SatelliteUI.parent.idTravelPanel
end

function OnMsg.SatelliteTick()
	if GetSectorInfoPanel() and g_SatelliteUI.selected_sector then		
		ObjModified("sector_selection_changed")
	end
end

-- All squad selection happens here!
function OnMsg.SatelliteNewSquadSelected(selected_squad, old_squad, force)
	if not gv_SatelliteView and not force then return end
	
	local satDiag = g_SatelliteUI	
	satDiag.selected_squad = selected_squad
	ObjModified("PDAButtons")
	UpdatePDAPowerButtonState()
	
	if satDiag.travel_mode then
		--satDiag:SetTravelPreviewSquad(selected_squad)
		satDiag:ExitTravelMode()
	end
	
	if old_squad then
		satDiag:UpdateSectorVisuals(old_squad.CurrentSector)
	end
	
	if selected_squad then
		local sectorId = selected_squad.CurrentSector
		satDiag:UpdateSectorVisuals(sectorId)		
		local squadWin = satDiag.squad_to_wnd[selected_squad.UniqueId]	
		if squadWin then
			squadWin:SelectionAnim()
		end
		
		local sectorUnderground = IsSectorUnderground(sectorId)
		local sectorWin = satDiag.sector_to_wnd[sectorId]
		if sectorWin.layer ~= g_SatelliteUI.layer then
			g_SatelliteUI:SetLayerMode(sectorWin.layer)
		end
	end
			
	local firstUnit = selected_squad and selected_squad.units
	firstUnit = firstUnit and firstUnit[1]
	firstUnit = firstUnit and g_Units[firstUnit]
	if firstUnit and firstUnit:CanBeControlled() then
		SelectObj(firstUnit)
	end

	ObjModified(satDiag)
	ObjModified("gv_SatelliteView")
end

---
--- Opens a context menu for the satellite view map.
---
--- @param ctrl XMapObject The control that triggered the context menu.
--- @param sector_id string The ID of the sector where the context menu is being opened.
--- @param squad_id string The ID of the squad associated with the context menu.
--- @param unit_id string The ID of the unit associated with the context menu.
---
function XSatelliteViewMap:OpenContextMenu(ctrl, sector_id, squad_id, unit_id)
	if self.travel_mode then
		self:ExitTravelMode()
	end

	local actions = {}
	local squad = gv_Squads[squad_id]
	local squadName = squad and Untranslated(squad.Name)
	
	if unit_id then
		table.insert(actions, "idInventory")
		table.insert(actions, "idPerks")
	else
		local squadsOnSector = GetSquadsInSector(sector_id)

		-- If the currently selected squad is on this sector and can enter the map, then we dont need to change
		-- the selected squad for satisfy the context menu.
		local canEnterWithAny = false
		local currentSelectedSquad = self.selected_squad
		if currentSelectedSquad and
			table.find(squadsOnSector, currentSelectedSquad) and
			GetSquadEnterSectorState(currentSelectedSquad.UniqueId) then
			canEnterWithAny = currentSelectedSquad
		end
		
		if not canEnterWithAny then
			for i, s in ipairs(squadsOnSector) do
				if GetSquadEnterSectorState(s.UniqueId) then
					canEnterWithAny = s
					break
				end
			end
		end
		
		local selSquad = canEnterWithAny or squad
		if selSquad and selSquad.Side == "player1" and self.selected_squad ~= selSquad then
			self:SelectSquad(selSquad)
		end
		
		if SatelliteToggleActionState() == "enabled" and canEnterWithAny then
			table.insert(actions, "actionToggleSatellite")
		end
		if #squadsOnSector > 0 then
			table.insert(actions, "idOperations")
		end
		if squad_id and CanCancelSatelliteSquadTravel() == "enabled" then
			table.insert(actions, "idCancelTravel")
		end
		table.insert(actions, "actionContextMenuViewSectorStash")
	end
	if #actions == 0 then return end
	
	if IsKindOf(ctrl, "XMapObject") then
		SetCampaignSpeed(0, GetUICampaignPauseReason("UIContextMenu"))
	end

	local overrideRollover = false
	if RolloverWin and IsKindOf(RolloverWin, "ZuluContextMenu") then
		overrideRollover = RolloverWin
		RolloverWin = false
		RolloverControl = false
		assert(false) -- This is used?
	else
		XDestroyRolloverWindow()
	end
	
	local context = {sector_id = sector_id, squad_id = squad_id, actions = actions, unit_id = unit_id}
	local popupHost = GetParentOfKind(self, "PDAClass")
	popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
	local menu = overrideRollover or XTemplateSpawn("SatelliteViewMapContextMenu", popupHost, context)
	self.context_menu = menu

	menu:SetAnchor(ctrl:ResolveRolloverAnchor())
	if IsKindOf(ctrl, "XMapRolloverable") then
		ctrl:SetupMapSafeArea(menu)
	else
		-- Margins from PDAMercRollover
		menu:SetMargins(box(30, 2, 0, 0))
	end
	if menu.window_state ~= "open" then menu:Open() end
	menu.idContent:SetContext(context, true)
	menu:SetModal(true)
	
	return menu
end		

---
--- Removes the context menu associated with the `XSatelliteViewMap` instance.
---
--- If a context menu is currently open, this function will close it and set the `context_menu` field to `false`.
---
--- @return boolean `true` if a context menu was removed, `false` otherwise.
---
function XSatelliteViewMap:RemoveContextMenu()
	if self.context_menu then
		if self.context_menu.window_state ~= "destroying" then self.context_menu:Close() end
		self.context_menu = false
		return true		
	end
	return false
end

---
--- Returns a list of squads in the given sector, excluding travelling squads and militia.
---
--- @param sectorId number The ID of the sector to get squads for.
--- @return table A table of squad objects.
---
function GetSatelliteSquadsForContextMenu(sectorId)
	if not sectorId then return empty_table end
	local squads = GetSquadsInSector(sectorId, "excludeTravelling", not "includeMilitia", "excludeArriving")
	if #squads <= 1 then return empty_table end
	return squads
end

-- Travel
-----

function OnMsg.TravelModeChanged()
	ObjModified("travel_mode_changed")
end

---
--- Checks if the currently rolled over sector on the satellite map is impassable.
---
--- @return boolean `true` if the rolled over sector is impassable, `false` otherwise.
---
function XSatelliteViewMap:IsRolloverSectorImpassable()
	return self.rollover_sector and (self.rollover_sector.Passability == "Blocked" or self.rollover_sector.Passability == "Water")
end

---
--- Handles the rollover event for a sector on the satellite map.
---
--- This function updates the displayed route and cursor hint based on the current travel mode and the rollovered sector.
--- It also checks if the rollovered sector is impassable and updates the mouse cursor accordingly.
---
--- @param wnd table The window object that triggered the rollover event.
--- @param sector table The sector object that was rolled over.
--- @param rollover boolean Whether the sector was rolled over or not.
---
function XSatelliteViewMap:OnSectorRollover(wnd, sector, rollover)
	-- Update shown route with rollovered sector
	if self.travel_mode then
		if self.travel_mode.destination_choice and rollover then
			self:TravelDestinationSelect(sector.Id)
		end
		self:ShowCursorHint(true, "travel_mode")
	else
		local selSquadSector = self.selected_squad and self.selected_squad.CurrentSector
		selSquadSector = selSquadSector and selSquadSector == sector.Id
		local show_hint = rollover and sector and sector.Passability ~= "Water" and not selSquadSector
		self:ShowCursorHint(show_hint, show_hint and "travel" or "none")
	end
	self.mouse_cursor = self:IsRolloverSectorImpassable() and "UI/Cursors/Pda_Impassable.tga"

	self.rollover_sector = rollover and sector
	self.rollover_sector_fx = rollover and sector
	if self.rollover_sector ~= sector then
		self:Invalidate()
	end
	
	local questFilter = self.filter_info_mode == "quests"
	local window = self.sector_to_wnd[sector.Id]
	local show = rollover or self.selected_sector == sector or (window.visible and window.quest_shows_sectorId)
	self:ShowSectorIdUI(sector, show)
end

---
--- Sets a travel waypoint on the current travel route.
---
--- This function is called when the user sets a travel waypoint on the satellite map. It updates the displayed route to make the current temporary waypoint a permanent one.
---
--- @param self table The XSatelliteViewMap instance.
---
function XSatelliteViewMap:SetTravelWaypoint()
	local travelCtx = self.travel_mode
	assert(travelCtx)
	if not travelCtx then return end
	local route = travelCtx.route
	if not route then return end -- No valid route to that sector (shift-click on impassable adjacent sector)

	local forbidden, _, _, canPlaceWaypoint = IsRouteForbidden(route)
	if forbidden and not canPlaceWaypoint then
		PlayFX("UnreachableSatellite")
		return
	end
	
	-- This will turn the currently temporary waypoint in the display route to a permanent one.	
	route.displayedSectionEnd = false
	ObjModified(travelCtx)
end

---
--- Asks the user if they want to split tired units from the given squad before traveling.
---
--- This function checks if the given squad has any exhausted units. If so, it prompts the user to select which units they want to split from the squad before traveling. If the user chooses to split the exhausted units, the function returns `true` to indicate that the travel should proceed. If the user chooses not to split the exhausted units, or if there are no exhausted units, the function returns `false` to indicate that the travel should be canceled.
---
--- @param squad table The squad to check for exhausted units.
--- @return boolean `true` if the user wants to proceed with travel, `false` if the user wants to cancel the travel.
---
function AskForExhaustedUnits(squad)
	local willTravel = true
	if HasTiredMember(squad, "Exhausted") then
		local exhausted_ids = ShowExhaustedUnitsQuestion(squad)
		if exhausted_ids then
			if #exhausted_ids ~= #squad.units then
				NetSyncEvent("SplitSquad", squad.UniqueId, exhausted_ids)
			else
				willTravel = false
			end
		else
			willTravel = false
		end
	end
	return willTravel
end

---
--- Handles the movement of the travel mode in the satellite view.
---
--- This function is responsible for managing the travel mode movement in the satellite view. It performs various checks and actions, such as:
--- - Checking if the travel mode and route are valid
--- - Checking if the route is forbidden
--- - Asking the user if they want to split tired units from the squad
--- - Trying to assign the squad to the route
--- - Playing voice responses and visual effects
---
--- @param self table The XSatelliteViewMap instance.
---
function XSatelliteViewMap:TravelModeMove()
	-- Sanity checks
	local travelCtx = self.travel_mode
	if not travelCtx then return end
	local route = travelCtx.route
	if not route then return end
	local squad = travelCtx.squad
	if not squad then return end
	
	if IsRouteForbidden(route, squad) then return end

	-- Thread the function so popups can wait
	local existingThread = self:GetThread("TravelModeMove")
	if IsValidThread(existingThread) and existingThread ~= CurrentThread() then
		return
	end

	if not CanYield() then
		self:CreateThread("TravelModeMove", XSatelliteViewMap.TravelModeMove, self)
		return
	end
	
	-- Stop destination choice during popups as it might change the dest.
	self.travel_mode.destination_choice = false
	Msg("TravelModeChanged")
	ObjModified(g_SatelliteUI.travel_mode)
	PlayFX("SatViewMoveCommand", "start")
	
	-- Ask if we want to split tired units
	local willTravel = AskForExhaustedUnits(squad)
	if not willTravel then
		self.travel_mode.destination_choice = true
		return
	end

	-- Ask if we want to split busy mercs etc.
	local res = TryAssignSatelliteSquadRoute(squad.UniqueId, route)
	if res == "cancel" then
		self.travel_mode.destination_choice = true
		return
	end
	
	local vr_type = #squad.units>1 and "GroupOrder" or "Order"
	PlayVoiceResponse(squad.units and squad.units[1], vr_type)
end

---
--- Handles the click event on a sector in the satellite view map.
---
--- @param wnd table The window object that received the click event.
--- @param sector table The sector object that was clicked.
--- @param button string The mouse button that was clicked ("L" for left, "R" for right).
---
--- @return string|nil Returns "break" to stop further processing of the event, or nil to allow other handlers to process it.
---
function XSatelliteViewMap:OnSectorClick(wnd, sector, button)
	if self:RemoveContextMenu() then return "break" end

	self.last_mouse_down = false

	local shiftPressed = terminal.IsKeyPressed(const.vkShift)
	if self.travel_mode and self.travel_mode.destination_choice and button == "L" then
		self.last_mouse_down = { time = RealTime(), sector = sector, map_scroll = point(UIL.GetParam(0)) }
		return
	elseif not self.travel_mode and button == "L" and self.selected_squad then
		if shiftPressed then
			local selSquadSector = self.selected_squad.CurrentSector
			if selSquadSector ~= sector.Id then
				InvokeShortcutAction(self, "idTravel")
				if not self.travel_mode then return end -- It's possible for travel to be disabled
				self:SetTravelWaypoint()
			end
		else
			self.last_mouse_down = { time = RealTime(), sector = sector, map_scroll = point(UIL.GetParam(0)) }
			return
		end
		
		return "break"
	elseif not self.travel_mode and button == "R" then
		--self.last_mouse_down = { time = RealTime(), sector = sector, map_scroll = point(UIL.GetParam(0)) }
		g_SatelliteUI:OpenContextMenu(wnd, sector.Id)
		return "break"
	end
end

---
--- Handles the mouse button up event on the satellite view map.
---
--- @param pt table The point where the mouse button was released.
--- @param button string The mouse button that was released ("L" for left, "R" for right).
--- @param ... Additional arguments passed to the event handler.
---
--- @return string|nil Returns "break" to stop further processing of the event, or nil to allow other handlers to process it.
---
function XSatelliteViewMap:OnMouseButtonUp(pt, button, ...)
	XMap.OnMouseButtonUp(self, pt, button, ...)
	if button ~= "L" or not self.last_mouse_down then return end

	local soon = (RealTime() - self.last_mouse_down.time < self.click_time)
	local didntMove = (self.last_mouse_down.map_scroll:Dist(point(UIL.GetParam(0))) < 20)
	if not soon or not didntMove then return end

	local shiftPressed = terminal.IsKeyPressed(const.vkShift)
	local sector = self.last_mouse_down.sector 
	if self.travel_mode and self.travel_mode.destination_choice and button == "L" then
		local travelCtx = self.travel_mode
		local route = travelCtx.route

		if not route then
			PlayFX("UnreachableSatellite")
			return "break"
		end
	
		if shiftPressed then
			self:SetTravelWaypoint()
			return "break"
		end
		
		if IsRouteForbidden(route) then
			PlayFX("UnreachableSatellite")
			return "break"
		end
		
		if sector.GroundSector then sector = gv_Squads[sector.GroundSector] end -- Prevent waypoints on underground sectors
		self:SetTravelWaypoint(sector)
	
		-- Route wasn't recalculated after placing of waypoint.
		local r = self.travel_mode.route
		if #r > 0 and not r.displayedSectionEnd then 
			local lastWp = r[#r]
			r.displayedSectionEnd = lastWp[#lastWp]
		end
		-- Remove waypoint at end, if any was placed
		if #r > 1 then
			local lastWp = r[#r]
			local penultimate = r[#r - 1]
			if #lastWp == 1 and lastWp[1] == penultimate[#penultimate] then -- Overlapping waypoint
				table.remove(r, #r)
			end
		end
		
		self:TravelModeMove()
		return "break"
	else
		if IsSquadTravelling(self.selected_squad, "skip_satellite_tick") then
			InvokeShortcutAction(self, "idCancelTravel", nil, "check_enabled")
			return
		end
		
		--[[if GetUIStyleGamepad() then
			self:SelectSector(self.last_mouse_down.sector)
			return "break"
		end]]
		
		local selSquadSector = self.selected_squad.CurrentSector
		local sector = self.last_mouse_down.sector
		if selSquadSector ~= sector.Id then
			PlayFX("SectorSelected", "start")
			InvokeShortcutAction(self, "idTravel")
		end
		
		return "break"
	end
end

---
--- Handles mouse button down events on the XSatelliteViewMap UI element.
---
--- If the right mouse button is pressed and the travel mode is active, the travel mode is exited.
--- Otherwise, the default XMap.OnMouseButtonDown handler is called.
---
--- @param pt table The mouse position as a table with `x` and `y` fields.
--- @param button string The mouse button that was pressed, either "L" for left or "R" for right.
--- @param ... any Additional arguments passed to the event handler.
--- @return string "break" if the event was handled, nil otherwise.
function XSatelliteViewMap:OnMouseButtonDown(pt, button, ...)
	if self:RemoveContextMenu() then return "break" end
	if button == "R" and self.travel_mode then
		self:ExitTravelMode()
		return "break"
	end
	
	if GetUIStyleGamepad() then return end -- No dragging with gamepad mouse
	XMap.OnMouseButtonDown(self, pt, button, ...)
end

---
--- Initiates travel mode for the specified squad on the satellite map.
---
--- If travel mode is already active or the specified squad cannot travel, this function does nothing.
---
--- Otherwise, this function:
--- - Removes any existing context menu
--- - Sets the travel mode state with the specified squad and an empty route
--- - Sets the transparency of the speed controls UI element to 125
--- - Sets the campaign speed to 0 and pauses the campaign for "SatelliteTravel"
--- - Sets the mouse cursor to the "UI/Cursors/Pda_Travel.tga" cursor
--- - Deselects the current sector
--- - Selects the current sector of the specified squad as the travel destination
--- - Sends a "TravelModeChanged" message with a true parameter
---
--- @param squadId string The unique ID of the squad to travel with
---
function XSatelliteViewMap:TravelWithSquad(squadId)
	if self.travel_mode or SatelliteCanTravelState(squadId) ~= "enabled" then return end
	self:RemoveContextMenu()
	self.travel_mode = { squad = gv_Squads[squadId], route = false }
	self:ResolveId("node").idSpeedControls:SetTransparency(125)
	SetCampaignSpeed(0, GetUICampaignPauseReason("SatelliteTravel"))
	self.desktop:SetMouseCursor("UI/Cursors/Pda_Travel.tga")

	self:SelectSector(false)

	local squadSector = gv_Squads[squadId].CurrentSector
	self:TravelDestinationSelect(squadSector)
	Msg("TravelModeChanged", true)
end

---
--- Exits the travel mode for the satellite map.
---
--- If travel mode is not active, this function does nothing.
---
--- Otherwise, this function:
--- - Sets the travel mode state to false
--- - If the window is not being destroyed:
---   - Sets the transparency of the speed controls UI element to 0
---   - If there is a travelling squad, displays the squad's route on its UI element
--- - Hides the travel block lines on all sector UI elements
--- - Sets the campaign speed to the normal speed and unpauses the campaign for "SatelliteTravel"
--- - Resets the mouse cursor
--- - Hides the cursor hint for "travel_mode"
--- - Sends a "TravelModeChanged" message with a false parameter
---
function XSatelliteViewMap:ExitTravelMode()
	if not self.travel_mode then return end
	local travellingSquad = self.travel_mode.squad
	self.travel_mode = false
	
	if self.window_state ~= "destroying" then
		self:ResolveId("node").idSpeedControls:SetTransparency(0)
		if travellingSquad then
			local squadWnd = self.squad_to_wnd[travellingSquad.UniqueId]
			if squadWnd then
				squadWnd:DisplayRoute("main", travellingSquad.CurrentSector, travellingSquad.route)
				squadWnd:DisplayRoute("land") -- delete
			end
		end
	end
	
	for i, wnd in pairs(self.sector_to_wnd) do
		wnd:ShowTravelBlockLines(false)
	end

	SetCampaignSpeed(nil, GetUICampaignPauseReason("SatelliteTravel"))
	self.desktop:SetMouseCursor()
	self:ShowCursorHint(false, "travel_mode")
	Msg("TravelModeChanged", false)
end

function OnMsg.TravelModeChanged()
	if not g_SatelliteUI or g_SatelliteUI.window_state == "destroying" then return end
	
	local sectorWndOnMouse = g_SatelliteUI:GetSectorOnPos("mouse")
	if sectorWndOnMouse then
		g_SatelliteUI:OnSectorRollover(sectorWndOnMouse, sectorWndOnMouse.context, true)
	end
end

---
--- Sets the travel preview squad for the satellite map.
---
--- If travel mode is not active, this function does nothing.
---
--- Otherwise, this function:
--- - Checks if the selected squad can travel. If not, exits travel mode.
--- - Displays the route of the old squad on its UI element.
--- - Sets the travel mode squad to the new squad.
--- - If a destination has been set, recalculates the route to that destination.
---
--- @param squad table|nil The squad to set as the travel preview squad. If nil, the selected squad is used.
function XSatelliteViewMap:SetTravelPreviewSquad(squad)
	if not self.travel_mode then return end
	if not squad then squad = self.selected_squad end -- Default to selected

	if SatelliteCanTravelState(squad) ~= "enabled" then
		self:ExitTravelMode()
		return
	end
	
	local oldSquad = self.travel_mode.squad
	local oldSquadWnd = self.squad_to_wnd[oldSquad.UniqueId]
	oldSquadWnd:DisplayRoute("main", oldSquad.CurrentSector, oldSquad.route)
	self.travel_mode.squad = squad
	ObjModified(self.travel_mode)
	
	-- Redraw to current destination
	if self.travel_mode.dest then
		self:TravelDestinationSelect(self.travel_mode.dest)
	end
end

---
--- Sets the travel destination for the satellite map.
---
--- If travel mode is not active, this function does nothing.
---
--- Otherwise, this function:
--- - Checks if the selected squad can travel to the destination sector. If not, exits travel mode.
--- - Generates a new route for the squad to the destination sector.
--- - If no valid route is found, displays a fake route with errors.
--- - Updates the squad's route and displays it on the squad's UI element.
--- - Highlights the sectors along the route on the satellite map.
---
--- @param sectorId string|nil The ID of the destination sector. If nil, the function enters destination selection mode.
---
function XSatelliteViewMap:TravelDestinationSelect(sectorId)
	if not self.travel_mode then return end
	if sectorId then
		local travelCtx = self.travel_mode
		local squad = travelCtx.squad
		if travelCtx.route and travelCtx.route.invalid_shim then
			travelCtx.route = false
		end
	
		local newCalculatedRoute = GenerateSquadRoute(travelCtx.route, false, sectorId, squad)
		
		-- If no valid route then display a fake route with errors
		if not newCalculatedRoute then
			local fakeInvalidRoute = GenerateRouteDijkstra(squad.CurrentSector, sectorId, false, false, "display_invalid")
			newCalculatedRoute = {
				(fakeInvalidRoute or { sectorId }),
				breakdown = {
					total = {
						travelTime = 0,
					},
					errors = {
						sectorId == squad.CurrentSector and T(510578241684, "Already at destination.") or T(895994028402, "No path available.")
					}
				},
				invalid_shim = true
			}
		end
		travelCtx.route = newCalculatedRoute
		
		local squadWin = self.squad_to_wnd[squad.UniqueId]; assert(squadWin)
		local oldRoute = squad.route
		local newRoute = travelCtx.route
		if newRoute then -- When plotting a route from a halfway position the squad needs to recenter as diagonal movements are not allowed.
			local nextStepIsSame = oldRoute and not oldRoute.center_old_movement and newRoute and table.get(oldRoute, 1, 1) == table.get(newRoute, 1, 1)
			local nextStepIsSameDirection = oldRoute and not oldRoute.center_old_movement and newRoute and table.get(oldRoute, 1, 1) == table.get(newRoute, 1, 1)
			local needToRecenter = not nextStepIsSame and not IsSquadInSectorVisually(squad, squad.CurrentSector)
			
			-- Dont recenter if going to move in the same direction we were already moving
			if needToRecenter then
				-- Get direction we're going to move in
				local nextSector = table.get(newRoute, 1, 1)
				local nextSectorY, nextSectorX = sector_unpack(nextSector)
				local currentSector = squad.CurrentSector
				local curSectorY, curSectorX = sector_unpack(currentSector)
				local dX, dY = (nextSectorX - curSectorX), (nextSectorY - curSectorY)
				
				-- Direction squad has moved in
				local squadVisualPos = GetSquadVisualPos(squad)
				local currentSectorVisPos = gv_Sectors[squad.CurrentSector].XMapPosition
				local visualDiff = Normalize(squadVisualPos - currentSectorVisPos)
				local normX = visualDiff:x()
				local normY = visualDiff:y()
				
				-- Convert to [-1,1]
				local visualDiff01X, visualDiff01Y = 0, 0
				if normX > 0 then
					visualDiff01X = 1
				elseif normX < 0 then
					visualDiff01X = -1
				end
				if normY > 0 then
					visualDiff01Y = 1
				elseif normY < 0 then
					visualDiff01Y = -1
				end

				if dX == visualDiff01X and dY == visualDiff01Y then
					needToRecenter = false
				end
			end
			
			newRoute.center_old_movement = needToRecenter
		end
		
		travelCtx.dest = sectorId
		squadWin:DisplayRoute("main", squad.CurrentSector, newRoute)
		
		local routeHashMap = {}
		for i, wp in ipairs(newRoute) do
			for _, sId in ipairs(wp) do
				routeHashMap[sId] = true
			end
		end
		for sId, wnd in pairs(self.sector_to_wnd) do
			wnd:ShowTravelBlockLines(routeHashMap[sId])
		end
	else
		self.travel_mode.destination_choice = true
		Msg("TravelModeChanged")
	end
	ObjModified(self.travel_mode)
end

local function lCloseSatelliteContextMenu()
	if g_SatelliteUI then
		g_SatelliteUI:RemoveContextMenu()
	end
end

OnMsg.SquadStartedTravelling = lCloseSatelliteContextMenu
OnMsg.SquadStoppedTravelling = lCloseSatelliteContextMenu

-- If starting travel from an underground sector the squad will automatically go on the upper sector.
-- In this case we want to switch the ui to the upper sector.
function OnMsg.SquadStartedTravelling(s)
	if g_SatelliteUI and s and s.Side == "player1" then
		local sectorId = s.CurrentSector
		local win = g_SatelliteUI.sector_to_wnd[sectorId]
		if win and not win.visible then
			local undergroundSectorId = sectorId .. "_Underground"
			local undergroundSectorWindow = g_SatelliteUI.sector_to_wnd[undergroundSectorId]
			if undergroundSectorWindow and undergroundSectorWindow.visible then
				local button = undergroundSectorWindow.idUnderground
				if button then
					button:SwapSector()
				end
			end
		end
	end
end

----

DefineClass.GuardpostSpawnTimer = {
	__parents = { "XContextWindow" },
	IdNode = true
}

---
--- Opens the GuardpostSpawnTimer window and starts a thread that updates the timer bar based on the remaining time until the next guardpost spawn.
---
--- The thread runs until the window is being destroyed. It checks if there is a valid guardpost spawn scheduled, and if so, calculates the remaining time and updates the timer bar accordingly.
---
--- @param self GuardpostSpawnTimer The GuardpostSpawnTimer instance.
---
function GuardpostSpawnTimer:Open()
	XContextWindow.Open(self)
	self:CreateThread("guardpost", function()
		while not self.context do
			Sleep(100)
		end
		local sector =  gv_Sectors[self.context.SectorId]
		while self.window_state ~= "destroying" do
			local hasSpawn = self.context.next_spawn_time and self.context.next_spawn_time_duration
			hasSpawn = hasSpawn and sector.Side == "enemy1" or sector.Side == "enemy2"
			hasSpawn = hasSpawn and not not self.context.target_sector_id
			local timeRemaining = hasSpawn and self.context.next_spawn_time - Game.CampaignTime
			hasSpawn = hasSpawn and timeRemaining > 0 and timeRemaining < const.Satellite.GuardPostShowTimer
			self:SetVisible(not not hasSpawn)
			if hasSpawn then
				local percent = 1000 - MulDivRound(timeRemaining, 1000, const.Satellite.GuardPostShowTimer)
				self:SetBar(percent)
			end

			Sleep(1000)
		end
	end)
end

---
--- Updates the timer bar in the GuardpostSpawnTimer window to reflect the remaining time until the next guardpost spawn.
---
--- @param self GuardpostSpawnTimer The GuardpostSpawnTimer instance.
--- @param percent number The percentage of the timer bar to update, from 0 to 1000.
---
function GuardpostSpawnTimer:SetBar(percent)
	local bar = self.idBar
	if not bar then return end
	local totalTicks = #bar
	local currentTick = MulDivRound(percent, totalTicks, 1000)
	bar:Update(currentTick)
end

table.insert(GridMarker.properties,
	{
		id = "EasySetupButtons",
		category = "Enabled Logic",
		editor = "buttons",
		buttons = { { name = "Disable on WorldFlip", func = "SetDefenderMarkerWorldFlipFilter" } },
   }
)

table.insert(GridMarker.properties,
	{
		id = "DespawnEasySetupButtons",
		sort_order = 10,
		category = "Spawn Object",
		editor = "buttons",
		buttons = { { name = "Despawn on WorldFlip", func = "SetMarkerDespawnWorldFlipFilter" } },
   }
)


---
--- Sets a filter on a GridMarker that disables the marker when the world is flipped.
---
--- @param marker GridMarker The GridMarker to set the filter on.
---
function SetDefenderMarkerWorldFlipFilter(_, marker)
	if not marker.EnabledConditions then marker.EnabledConditions = {} end
	table.insert(marker.EnabledConditions,
		QuestIsVariableBool:new({
			QuestId = "04_Betrayal",
			Vars = set({
				TriggerWorldFlip = false
			}),
		})
	)
	ObjModified(marker)
end

---
--- Sets a filter on a GridMarker that despawns the marker when the world is flipped.
---
--- @param marker GridMarker The GridMarker to set the filter on.
---
function SetMarkerDespawnWorldFlipFilter(_, marker)
	if not marker.Despawn_Conditions then marker.Despawn_Conditions = {} end
	table.insert(marker.Despawn_Conditions,
		QuestIsVariableBool:new({
			QuestId = "04_Betrayal",
			Vars = set({
				TriggerWorldFlip = true
			}),
		})
	)
	ObjModified(marker)
end

DefineClass.PostWorldFlipDefenderMarker = {
	__parents = { "GridMarker" },
	Type = "Defender"
}

---
--- Initializes a PostWorldFlipDefenderMarker object.
---
--- Sets the color of the marker to blue (RGBA(0, 105, 205, 255)).
--- Adds the "PostWorldFlip" group to the marker.
--- Sets an enabled condition for the marker based on the "TriggerWorldFlip" variable of the "04_Betrayal" quest.
---
--- @param self PostWorldFlipDefenderMarker The PostWorldFlipDefenderMarker object to initialize.
---
function PostWorldFlipDefenderMarker:Init()
	self:SetColor(RGBA(0, 105, 205, 255))
	self.Groups = { "PostWorldFlip" }
	self.EnabledConditions = {
		QuestIsVariableBool:new({
			QuestId = "04_Betrayal",
			Vars = set( "TriggerWorldFlip" ),
		})
	}
end

---
--- Updates the visuals of the PostWorldFlipDefenderMarker.
---
--- This function updates the text displayed on the marker.
---
function PostWorldFlipDefenderMarker:UpdateVisuals()
	self:UpdateText(false)
end

DefineClass.PostWorldFlipDefenderPriorityMarker = {
	__parents = { "PostWorldFlipDefenderMarker" },
	Type = "DefenderPriority"
}

---
--- Initializes a cache of squads that are currently traversing shortcuts.
---
--- This function iterates through all squads in the `g_SquadsArray` and adds any squads that are traversing shortcuts and have a side other than "player1" to the `squads_in_shorcuts` table.
---
--- @param self XSatelliteViewMap The XSatelliteViewMap object.
---
function XSatelliteViewMap:InitCacheOfShortcutSquads()
	local cache = {}
	for i, s in ipairs(g_SquadsArray) do
		if IsTraversingShortcut(s) and s.Side ~= "player1" then
			cache[#cache + 1] = s
		end
	end
	self.squads_in_shorcuts = cache
end

function OnMsg.SquadStartTraversingShortcut(squad)
	if g_SatelliteUI and g_SatelliteUI.squads_in_shorcuts and squad and squad.Side ~= "player1" then
		table.insert(g_SatelliteUI.squads_in_shorcuts, squad)
	end
end

function OnMsg.SquadSectorChanged(squad)
	if g_SatelliteUI and g_SatelliteUI.squads_in_shorcuts and squad and squad.Side ~= "player1" then
		table.remove_value(g_SatelliteUI.squads_in_shorcuts, squad)
	end
end

---
--- Returns a list of squads that are currently traversing shortcuts and are located within the given sector window.
---
--- @param sectorWin SatelliteSector The sector window to check for squads.
--- @return table|false A table of squads traversing shortcuts within the sector window, or false if no such squads are found.
---
function UIGetSquadsInShortcutsHere(sectorWin)
	local result = false
	if g_SatelliteUI and g_SatelliteUI.squads_in_shorcuts then
		for i, s in ipairs(g_SatelliteUI.squads_in_shorcuts) do
			local win = g_SatelliteUI.squad_to_wnd[s.UniqueId]
			local pos = win and win:GetVisualPos()
			if pos and pos:InBox(sectorWin.box) then
				if not result then result = {} end
				result[#result + 1] = s
			end
		end
	end
	return result
end

---
--- Opens the sector stash UI for the given sector ID.
---
--- If a squad is currently selected, the inventory of the first unit in that squad is opened. If no squad is selected, the inventory of the first unit in any player squad in the sector is opened.
---
--- @param sectorId string The ID of the sector to open the stash UI for.
---
function OpenSectorStashUIForSector(sectorId)
	local selSquad = g_SatelliteUI.selected_squad
	if not selSquad then return end

	local actualInventory = GetSectorInventory(sectorId)
	local _, squadHere = AnyPlayerSquadsInSector(sectorId)
	if not squadHere then
		squadHere = selSquad
	end
	local firstUnit = squadHere.units and squadHere.units[1]
	OpenInventory(gv_UnitData[firstUnit], actualInventory)
end

---
--- Generates an empty satellite sector with the specified ID.
---
--- @param sector_id string The ID of the sector to generate.
--- @return SatelliteSector The generated empty sector.
---
function GenerateEmptySector(sector_id)
	return SatelliteSector:new{
		Id = sector_id,
		Label1 = "Blocked",
		Side = "neutral",
		StickySide = true,
		TerrainType = "Highlands",
		Passability = "Blocked",
		Intel = false,
		MusicCombat = "Battle_Normal",
		MusicConflict = "Cursed_Conflict",
		MusicExploration = "Cursed_Exploration",
		
		name = sector_id,
		generated = true, -- generated sectors won't be saved in the campaign, and are re-generated automatically upon load
	}
end

---
-- WOLF UPDATE
---

DefineClass.SatelliteViewDecoration = {
	__parents = { "XMapWindow", "XImage" },
	HAlign = "left",
	VAlign = "top",
	ZOrder = -2
}

AppendClass.SatelliteSector = {
	properties = {
		{ category = "Satellite Settings", id = "UndergroundImage", name = "Underground image", editor = "ui_image", default = false }
	}
}

DefineClass.SatelliteViewDecorationDef = {
	__parents = { "PropertyObject" },
	
	properties = {
		{ id = "image", name = "Image", editor = "ui_image", default = false },
		{ id = "relativeSector", name = "Relative to sector", editor = "combo", items = function() return GetCampaignSectorsCombo() end, default = false },
		{ id = "offset", name = "Offset", editor = "point", default = point20 },
		{ id = "sat_layer", name = "Satellite layer", editor = "choice", default = "satellite", items = { "satellite", "underground" }},
	}
}

---
--- Returns a string representation of the SatelliteViewDecorationDef object for the editor view.
---
--- @return string The editor view string for the SatelliteViewDecorationDef object.
---
function SatelliteViewDecorationDef:GetEditorView()
	return Untranslated("Decoration: " .. (self.image or ""))
end
