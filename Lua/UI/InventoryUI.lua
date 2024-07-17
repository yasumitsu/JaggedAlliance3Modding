local equip_slot_images = {
	["Head"]  = "UI/Icons/Items/background_helmet",	
	["Legs"]  = "UI/Icons/Items/background_pants", 
	["Torso"]  = "UI/Icons/Items/background_vest", 
	["Handheld A"]  = "UI/Icons/Items/background_weapon",
	["Handheld B"]  = "UI/Icons/Items/background_weapon",
	["Handheld A Big"]  = "UI/Icons/Items/background_weapon_big",
	["Handheld B Big"]  = "UI/Icons/Items/background_weapon_big", 
}

-- context is an inventory object
-- spawns instances of XInventoryTile template
local tile_size = 90
local tile_size_rollover = 110
local function GetTileImage(ctrl, tile)
	local enabled = ctrl:GetEnabled()
	local slot = ctrl.parent:GetInventorySlotCtrl()
	return enabled and (tile and "UI/Inventory/T_Backpack_Slot_Small_Empty.tga" or  "UI/Inventory/T_Backpack_Slot_Small.tga" )or  "UI/Inventory/T_Backpack_Slot_Small_Empty.tga" 
end

DefineClass.XInventoryTile = {
	__parents = { "XHoldButtonControl" },
	
	MinWidth = tile_size_rollover,
	MaxWidth = tile_size_rollover,
	MinHeight = tile_size_rollover,
	MaxHeight = tile_size_rollover,
	ImageFit = "width",	
	slot_image = false,
	MouseCursor = "UI/Cursors/Hand.tga",
	CursorsFolder = "UI/DesktopGamepad/",
}

--- Initializes an XInventoryTile instance.
-- This function sets up the visual elements of the XInventoryTile, including the background image, the equipment slot image, and the rollover image.
-- @param self The XInventoryTile instance being initialized.
function XInventoryTile:Init()

	local image = XImage:new({
		MinWidth = tile_size,
		MaxWidth = tile_size,
		MinHeight = tile_size,
		MaxHeight = tile_size,
		Id = "idBackImage",
		Image = "UI/Inventory/T_Backpack_Slot_Small_Empty.tga",
		ImageColor = 0xFFc3bdac,
	},
	self)

	if self.slot_image then	
		local imgslot = XImage:new({
			MinWidth = tile_size,
			MaxWidth = tile_size,
			MinHeight = tile_size,
			MaxHeight = tile_size,

			Dock = "box",
			Id = "idEqSlotImage",
			ImageFit = "width",
		},
		self)	
		imgslot:SetImage(self.slot_image)
		image:SetImage("UI/Inventory/T_Backpack_Slot_Small.tga")
		image:SetImageColor(RGB(255,255,255))
	end
	local rollover_image = XImage:new({
		MinWidth = tile_size_rollover,
		MaxWidth = tile_size_rollover,
		MinHeight = tile_size_rollover,
		MaxHeight = tile_size_rollover,

		Id = "idRollover",
		Image = "UI/Inventory/T_Backpack_Slot_Small_Hover.tga",
		ImageColor = 0xFFc3bdac,
		Visible = false,		
		},
	self)
	rollover_image:SetVisible(false)
end

--- Returns the XInventorySlot instance that this XInventoryTile is a part of.
-- @return The XInventorySlot instance that this XInventoryTile is a part of, or false if this XInventoryTile is not part of an XInventorySlot.
function XInventoryTile:GetInventorySlotCtrl()
	return IsKindOf(self.parent, "XInventorySlot") and self.parent or false
end

--- Returns the appropriate mouse cursor to use when the XInventoryTile is hovered over.
-- If the game is in compare mode, returns the "UI/Cursors/Inspect.tga" cursor.
-- Otherwise, returns the default mouse cursor.
-- @return The appropriate mouse cursor to use.
function XInventoryTile:GetMouseCursor()
	return InventoryIsCompareMode() and "UI/Cursors/Inspect.tga" or XWindow.GetMouseCursor(self)
end

--- Checks if the current XInventoryTile instance is a valid drop target for the given drag operation.
-- @param drag_win The window being dragged.
-- @param pt The current position of the drag operation.
-- @param source The source of the drag operation.
-- @return True if the current XInventoryTile instance is a valid drop target, false otherwise.
function XInventoryTile:IsDropTarget(drag_win, pt, source)
	local slot = self:GetInventorySlotCtrl()
	return slot:_IsDropTarget(drag_win, pt, source)
end

--- Called when an item is dropped on this XInventoryTile instance.
-- This function is called when an item is dropped on this XInventoryTile instance during a drag and drop operation.
-- @param drag_win The window being dragged.
-- @param pt The current position of the drag operation.
-- @param drag_source_win The source window of the drag operation.
function XInventoryTile:OnDrop(drag_win, pt, drag_source_win)
end

---
--- Called when an item is dragged and enters the current XInventoryTile instance.
--- This function is called when an item is dragged and enters the current XInventoryTile instance during a drag and drop operation.
--- It performs various checks and updates related to the drag and drop operation, such as:
--- - Calling InventoryOnDragEnterStash() to handle stash-related logic
--- - Retrieving the dragged item and the inventory slot controller
--- - Finding the item under the current mouse position
--- - Calculating the AP cost for the potential drop action
--- - Displaying the appropriate mouse text based on the drop action
--- - Highlighting the drop slot and the AP cost
---
--- @param drag_win The window being dragged.
--- @param pt The current position of the drag operation.
--- @param drag_source_win The source window of the drag operation.
---
function XInventoryTile:OnDropEnter(drag_win, pt, drag_source_win)
	InventoryOnDragEnterStash()
	local drag_item = InventoryDragItem	
	local slot = self:GetInventorySlotCtrl()	

	local mouse_text = InventoryGetMoveIsInvalidReason(slot.context, InventoryStartDragContext)
	-- pick + equip 
	--this seems to be drag over empty slot
	local wnd, under_item = slot:FindItemWnd(pt)
	if under_item == drag_item then
		under_item = false
	end
	
	local is_reload = IsReload(drag_item, under_item)
	
	local ap_cost, unit_ap, action_name = InventoryItemsAPCost(slot:GetContext(), slot.slot_name, under_item, is_reload)
	if not mouse_text then
		mouse_text = action_name or ""
		if InventoryIsCombatMode() and ap_cost and ap_cost>0 then
			mouse_text = InventoryFormatAPMouseText(unit_ap, ap_cost, mouse_text)
		end
	end
	InventoryShowMouseText(true,mouse_text)
	HighlightDropSlot(self, true, pt, drag_win)
	HighlightAPCost(InventoryDragItem, true, self)
end

--- Called when an item is dragged and leaves the current XInventoryTile instance.
-- This function is called when an item is dragged and leaves the current XInventoryTile instance during a drag and drop operation.
-- It performs various cleanup actions related to the drag and drop operation, such as:
-- - Hiding the highlight for the drop slot
-- - Hiding the mouse text
-- - Removing the highlight for the AP cost
--
-- @param drag_win The window being dragged.
-- @param pt The current position of the drag operation.
-- @param source The source of the drag operation.
function XInventoryTile:OnDropLeave(drag_win, pt, source)
	if drag_win and drag_win.window_state ~= "destroying" then 
		HighlightDropSlot(self, false, pt, drag_win)
		InventoryShowMouseText(false)
		HighlightAPCost(InventoryDragItem, false,  self)
	end	
end

--- Called when the rollover state of the XInventoryTile changes.
-- This function is called when the rollover state of the XInventoryTile changes. It updates the transparency of the tile's background image based on the rollover state and the slot's rollover_image_transparency and image_transparency properties.
--
-- @param rollover A boolean indicating whether the tile is in a rollover state or not.
function XInventoryTile:OnSetRollover(rollover)
	XDragAndDropControl.OnSetRollover(self,rollover)
	local img = self.idBackImage

	local slot = self:GetInventorySlotCtrl()
	if slot.rollover_image_transparency then
		img:SetTransparency(rollover and slot.rollover_image_transparency or slot.image_transparency)
	end
end

--- Sets the enabled state of the XInventoryTile and updates its appearance accordingly.
--
-- @param enabled A boolean indicating whether the tile should be enabled or not.
function XInventoryTile:SetEnabled(enabled)
	XContextControl.SetEnabled(self, enabled)
	self.idBackImage:SetImage(GetTileImage(self.idBackImage,true))
	--self.idBackImage:SetImageColor(0xFFc3bdac)
	self:SetHandleMouse(enabled)
end

if FirstLoad then
	StartDragSource = false
	InventoryStartDragSlotName = false
	InventoryStartDragContext = false
	InventoryDragItem = false
	InventoryDragItems = false
	InventoryDragItemPos = false
	InventoryDragItemPt = false
	
	SectorStashOpen = false
	WasDraggingLastLMBClick = false
end

--- Clears the global variables related to drag and drop operations in the inventory UI.
--
-- This function resets the values of the following global variables to `false`:
-- - `StartDragSource`
-- - `InventoryStartDragSlotName`
-- - `InventoryStartDragContext`
-- - `InventoryDragItem`
-- - `InventoryDragItems`
-- - `InventoryDragItemPos`
-- - `InventoryDragItemPt`
--
-- This function is likely called when a drag and drop operation is completed or canceled, to ensure that the global state is properly reset.
function ClearDragGlobals()
	StartDragSource = false
	InventoryStartDragSlotName = false
	InventoryStartDragContext = false
	InventoryDragItem = false
	InventoryDragItems = false
	InventoryDragItemPos = false
	InventoryDragItemPt = false
end

--------------------------
DefineClass.XInventoryItem = {
	__parents = { "XHoldButtonControl" },
			
	HandleMouse = true,
	HandleKeyboard = true,
	UseClipBox  = false,
	IdNode = true,
	RolloverTemplate = "RolloverInventory",
	MouseCursor = "UI/Cursors/Hand.tga",
	CursorsFolder = "UI/DesktopGamepad/",
}

--- Returns the appropriate mouse cursor for the inventory item.
--
-- If the game is in compare mode, the cursor will be the "inspect" cursor. Otherwise, the default mouse cursor is returned.
--
-- @return string The mouse cursor image to use for the inventory item.
function XInventoryItem:GetMouseCursor()
	return InventoryIsCompareMode() and "UI/Cursors/Inspect.tga" or XWindow.GetMouseCursor(self)
end

--- Called when the mouse cursor enters the inventory item.
--
-- This function is called when the mouse cursor enters the inventory item. It plays a sound effect to indicate that the item has been hovered over.
--
-- @param pt The current mouse position.
-- @param child The child window under the mouse cursor.
function XInventoryItem:OnMouseEnter(pt, child)
	XWindow.OnMouseEnter(self, pt, child)
--[[	local item = self.context
	if item and item.locked then
		self.idimgLocked:SetImageColor(GameColors.I)		
	end
--]]	
	PlayFX("ItemRollover", "start", self.context.class)
end

--- Called when the mouse is released over the inventory item.
--
-- This function is called when the mouse is released over the inventory item. It plays a sound effect to indicate that the item has been released, and updates the visual state of the locked icon if the item is locked.
--
-- @param pt The current mouse position.
-- @param child The child window under the mouse cursor.
function XInventoryItem:OnMouseLeft(pt, child)
	XWindow.OnMouseLeft(self, pt, child)
	local item = self.context
	if item and item.locked then
		self.idimgLocked:SetImageColor(GameColors.D)		
	end
	
	PlayFX("ItemRollover", "end", self.context.class)
end

--- Called when the inventory item is being destroyed.
--
-- This function is called when the inventory item is being destroyed. It removes the item from the inventory slot's item_windows table.
--
-- @param self The XInventoryItem instance.
function XInventoryItem:Done()
	local slot = self:GetInventorySlotCtrl()
	if slot then
		slot.item_windows[self] = nil
	end
end

--- Initializes an XInventoryItem instance.
--
-- This function is called when an XInventoryItem instance is created. It sets up the various UI elements that make up the inventory item, including the item image, locked icon, and various text elements.
--
-- @param self The XInventoryItem instance.
function XInventoryItem:Init()	
	local dropshadow = XTemplateSpawn("XImage", self)
		dropshadow:SetId("idDropshadow")
		dropshadow:SetMargins(box(0, 20, 20, 0))
		dropshadow:SetUseClipBox(false)
		dropshadow:SetVisible(false)
		dropshadow:SetImageColor(0x80000000)

	local item_pad = XTemplateSpawn("XImage", self)
		local item = self:GetContext()
		local w = item:IsLargeItem() and tile_size_rollover * 2 or tile_size_rollover
		item_pad:SetMinWidth(w)
		item_pad:SetMaxWidth(w)
		item_pad:SetMinHeight(tile_size_rollover)
		item_pad:SetMaxHeight(tile_size_rollover)
		item_pad:SetHAlign("center")
		item_pad:SetVAlign("center")
		
	--	item_pad:SetImageFit("width")
		item_pad:SetId("idItemPad")
		item_pad:SetUseClipBox(false)
		item_pad:SetHandleMouse(true)
		item_pad.SetRollover = function(this,rollover)
			XImage.SetRollover(this,rollover)
			local item = this:GetContext()
			local bShow = rollover
			if not bShow and DragSource then
				bShow = true
			end
			SetInventoryHighlights(item, bShow)
			-- character is busy text
			local slot = self:GetInventorySlotCtrl()
			local owner = slot and slot:GetContext()
			local valid, mouse_text = InventoryIsValidTargetForUnit(owner or gv_UnitData[item.owner])
			if not valid then
				InventoryShowMouseText(rollover,mouse_text)
			end
		end
		item_pad.OnSetRollover = function(this,rollover)
			local dlg = GetMercInventoryDlg()
			local item = this:GetContext()
			rollover = rollover or dlg and dlg.selected_items[item]
			XImage.OnSetRollover(this,rollover)			
			local slot = this.parent:GetInventorySlotCtrl()
			if slot and slot.rollover_image_transparency then
				this:SetTransparency(rollover and slot.rollover_image_transparency or slot.image_transparency)
			end
			if slot and next(GetSlotsToEquipItem(self.context)) then
				if not dlg then return end
				if InventoryIsCompareMode(dlg) then
					dlg:CloseCompare()					
					if rollover then
						dlg:OpenCompare(self, item)	
					end
				end
			end
		end	
		item_pad.OnSetSelected = function(this,selected)				
			this:OnSetRollover(this,selected)
		end	
		
	local slot = self:GetInventorySlotCtrl()
	if slot then
		item_pad:SetTransparency(slot.image_transparency)
	end
	local rollover_image = XImage:new({
		MinWidth = tile_size_rollover,
		MaxWidth = tile_size_rollover,
		MinHeight = tile_size_rollover,
		MaxHeight = tile_size_rollover,

		Id = "idRollover",
		Image = "UI/Inventory/T_Backpack_Slot_Small_Hover.tga",
		Visible = false,	
		UseClipBox = false,
		ImageColor = 0xFFc3bdac,			
		},
	self)

	rollover_image.SetVisible = function(this, visible, ...)
		XImage.SetVisible(this, visible, ...)
		this.parent.idimgLocked:SetVisible(visible and item.locked, ...)
	end
	
	local item_img = XTemplateSpawn("XImage", self)	
		item_img:SetPadding(box(15,15,15,15))
		item_img:SetImageFit("width")
		item_img:SetId("idItemImg")
		item_img:SetUseClipBox(false)
		item_img:SetHandleMouse(false)
		-- sub icon
		if item.SubIcon and item.SubIcon~="" then
			local item_subimg = XTemplateSpawn("XImage", item_img)	
			item_subimg:SetHAlign("left")
			item_subimg:SetVAlign("bottom")
			--item_subimg:SetImageFit("width")
			item_subimg:SetId("idItemSubImg")
			item_subimg:SetUseClipBox(false)	
			item_subimg:SetHandleMouse(false)
		end		
		-- weapon modifications
		if item:IsWeapon() and item.ComponentSlots and #item.ComponentSlots>0 then
			local count, max = CountWeaponUpgrades(item)
			if count>0 then
				local item_modimg = XTemplateSpawn("XImage", item_img)	
				item_modimg:SetHAlign("left")
				item_modimg:SetVAlign("top")
				--item_modimg:SetImageFit("width")
				item_modimg:SetId("idItemModImg")
				item_modimg:SetUseClipBox(false)	
				item_modimg:SetHandleMouse(false)
				item_modimg:SetImage("UI/Inventory/w_mod")
				item_modimg:SetScaleModifier(point(700,700))
				item_modimg:SetMargins(box(-5,-5,0,0))
			end		
		end
		-- amo type icon
		if IsKindOfClasses(item, "Ammo", "Ordnance") and item.ammo_type_icon then
			local item_ammo_type_img = XTemplateSpawn("XImage", item_img)	
			item_ammo_type_img:SetHAlign("left")
			item_ammo_type_img:SetVAlign("top")
			--item_ammo_type_img:SetImageFit("width")
			item_ammo_type_img:SetId("idItemAmmoTypeImg")
			item_ammo_type_img:SetUseClipBox(false)	
			item_ammo_type_img:SetHandleMouse(false)
			item_ammo_type_img:SetImage(item.ammo_type_icon)
			item_ammo_type_img:SetTransparency(45)
			item_ammo_type_img:SetScaleModifier(point(500,500))
			item_ammo_type_img:SetMargins(box(-5,-5,0,0))
		end
	-- texts 	
	local text = XTemplateSpawn("XText", self) -- currently for weapon mag and stack size
		text:SetTranslate(true)
		text:SetTextStyle("InventoryItemsCount")
		text:SetId("idText") --bottom right text
		text:SetUseClipBox(false)
		text:SetClip(false)
		text:SetPadding(box(2,2,10,5))
		text:SetTextHAlign("right")
		text:SetTextVAlign("bottom")
		text:SetHandleMouse(false)

	local center_text = XTemplateSpawn("AutoFitText", self)			
		center_text:SetTranslate(true)
		center_text:SetTextStyle("DescriptionTextAPRed")
		center_text:SetId("idCenterText")		
		center_text:SetUseClipBox(false)
		center_text:SetTextHAlign("center")
		center_text:SetTextVAlign("center")
		center_text:SetHAlign("center")
		center_text:SetVAlign("center")
		center_text:SetHandleMouse(false)
		
	local topRightText = XTemplateSpawn("XText", self) -- currently for armor and weapon condition%
		topRightText:SetTranslate(true)
		topRightText:SetTextStyle("InventoryItemsCount")
		topRightText:SetId("idTopRightText")
		topRightText:SetUseClipBox(false)
		topRightText:SetClip(false)
		topRightText:SetPadding(box(2,6,10,2))
		topRightText:SetTextHAlign("right")
		topRightText:SetTextVAlign("top")
		topRightText:SetHandleMouse(false)
		
	local 	imgLocked = XTemplateSpawn("XImage", self) -- currently for locked items on rollover
		imgLocked:SetId("idimgLocked")
		imgLocked:SetUseClipBox(false)
		imgLocked:SetClip(false)
		imgLocked:SetPadding(box(10,2,2,10))
		imgLocked:SetHAlign("left")
		imgLocked:SetVAlign("bottom")
		imgLocked:SetHandleMouse(false)
		imgLocked:SetVisible(false)
		imgLocked:SetImage("UI/Inventory/padlock")
		imgLocked:SetImageColor(GameColors.D)	
		
	rollover_image:SetVisible(false)	
end

--- Handles the rollover state of an XInventoryItem.
---
--- When the mouse cursor hovers over the inventory item, this function is called to update the rollover state.
--- It checks if the inventory is disabled and displays a mouse text message if so.
---
--- @param rollover boolean Whether the item is in a rollover state or not.
function XInventoryItem:OnSetRollover(rollover)
	if self.HandleMouse then
		local dlg = GetMercInventoryDlg()
		local item = self:GetContext()
		rollover = rollover or dlg and dlg.selected_items and dlg.selected_items[item]
	
		XHoldButtonControl.OnSetRollover(self, rollover)
		local dlgContext = GetDialogContext(self)
		if dlgContext then
			local invDis, reason = InventoryDisabled(dlgContext)
			if invDis then
				InventoryShowMouseText(rollover, reason)
			end
		end
	end
end

--- Sets the selected state of the XInventoryItem.
---
--- This function is called to update the selected state of the inventory item. It checks if the window is not in a destroyed state and then sets the rollover state of the idItemPad control.
---
--- @param selected boolean Whether the item is selected or not.
function XInventoryItem:OnSetSelected(selected)
	if self.window_state~="destroyed" then
		return self.idItemPad:OnSetRollover(selected)
	end	
end

--- Gets the rollover anchor position for the inventory item.
---
--- This function is used to determine the anchor position for the rollover tooltip of the inventory item. It checks if the inventory slot is a BrowseInventorySlot, and if the inventory is in compare mode with an item equipped. In this case, it returns "right" as the anchor position, otherwise it returns "smart".
---
--- @return string The anchor position for the rollover tooltip.
function XInventoryItem:GetRolloverAnchor()
	local slot = self:GetInventorySlotCtrl()
	
	if slot and IsKindOf(slot,"BrowseInventorySlot") then
		local dlg = GetMercInventoryDlg()
		if InventoryIsCompareMode(dlg) and next(dlg.compare_wnd[1]) and next(GetSlotsToEquipItem(self.context)) then
			return "right"
		end
	end
	return "smart"
end

---
--- Updates the context of the XInventoryItem.
---
--- This function is called to update the visual representation of the inventory item based on the provided item context. It sets the size, rollover title and text, image, and text elements of the item based on the properties of the item.
---
--- @param item InventoryItem The inventory item to update the context for.
--- @param ... any Additional arguments passed to the function.
function XInventoryItem:OnContextUpdate(item,...)
	local w, h = item:GetUIWidth(), item:GetUIHeight()
	self:SetMinWidth(tile_size*w)
	self:SetMaxWidth(tile_size*w)
	self:SetMinHeight(tile_size*h)
	self:SetMaxHeight(tile_size*h)
	self:SetGridWidth(w)
	self:SetGridHeight(h)
	self:SetRolloverTitle(item:GetRolloverTitle())		
	self:SetRolloverText(item:GetRollover())		

	self.idDropshadow:SetImage(item:IsLargeItem() and "UI/Inventory/T_Backpack_Slot_Large" or GetTileImage(self.idItemPad))
	self.idItemPad:SetImage(item:IsLargeItem() and "UI/Inventory/T_Backpack_Slot_Large_Empty.tga" or "UI/Inventory/T_Backpack_Slot_Small_Empty.tga")
	local slot = self:GetInventorySlotCtrl()
	if slot and IsEquipSlot(slot.slot_name) then
		self.idItemPad:SetImage(item:IsLargeItem() and "UI/Inventory/T_Backpack_Slot_Large.tga" or GetTileImage(self.idItemPad))
	end
	--self.idItemPad:SetImage(item:IsLargeItem() and "UI/Inventory/T_Backpack_Slot_Large_Empty.tga" or GetTileImage(self.idItemPad))
	--self.idItemPad:SetImageColor(0xffc3bdac)
	self.idRollover:SetImage(item:IsLargeItem() and "UI/Inventory/T_Backpack_Slot_Large_Hover.tga" or "UI/Inventory/T_Backpack_Slot_Small_Hover.tga")
	self.idRollover:SetImageColor(0xffc3bdac)
	self.idText:SetText(item:GetItemSlotUI() or "")
	if IsKindOfClasses(item, "Armor", "Firearm", "HeavyWeapon", "MeleeWeapon", "ToolItem", "Medicine" ) and not IsKindOf(item, "InventoryStack") then
		self.idTopRightText:SetText(item:GetConditionText() or "") -- currently for armor and weapon condition%
	end
	
	local txt = item:GetItemStatusUI()
	self.idCenterText:SetTextStyle("DescriptionTextAPRed")
	self.idCenterText:SetText(txt)			
	self.idItemImg:SetTransparency(txt and txt~="" and 128 or 0)
	if not table.find(InventoryDragItems, item) then
		self.idItemImg:SetImage(item:GetItemUIIcon())
		self.idItemImg:SetImageFit("width")
	end

	if item.SubIcon and item.SubIcon~= "" then
		self.idItemImg.idItemSubImg:SetImage(item.SubIcon or "")
	end
end

---
--- Sets the position of the XInventoryItem.
---
--- @param left number The horizontal grid position of the item.
--- @param top number The vertical grid position of the item.
function XInventoryItem:SetPosition(left, top)
	self:SetGridX(left)
	self:SetGridY(top)
end

---
--- Handles the hold down event for an inventory item.
---
--- If the left mouse button is held down on an inventory item, this function checks if the item can be moved to the player's inventory. If the item is in a valid container or the player is dead, the item is moved to the player's inventory.
---
--- @param pt table The position of the mouse cursor.
--- @param button string The mouse button that was pressed.
---
function XInventoryItem:OnHoldDown(pt, button)
	if button=="ButtonA" then
		local unit = GetInventoryUnit()
		local item = self:GetContext()
		local dlg = GetMercInventoryDlg()
		local container = dlg and dlg:GetContext().container
		if unit and  container and IsKindOf(item, "InventoryItem")then	
			local ctrl = self:GetInventorySlotCtrl() 
			if not ctrl and item==InventoryDragItem then
				ctrl = DragSource
			end	
			local context = ctrl and ctrl:GetContext()
			if IsKindOf(context,"ItemContainer") or IsKindOf(context,"Unit") and context:IsDead()  then
				--print("onhold", context.handle, container.handle)
				ctrl:CancelDragging()
				MoveItem({item = item, src_container = context, src_slot = GetContainerInventorySlotName(context), dest_container = unit, dest_slot = "Inventory"})
			end
		end
	end
end	

---
--- Checks if the current XInventoryItem is a valid drop target for the dragged item.
---
--- @param drag_win table The window object of the dragged item.
--- @param pt table The position of the mouse cursor.
--- @param source table The source of the drag operation.
--- @return boolean True if the current XInventoryItem is a valid drop target, false otherwise.
---
function XInventoryItem:IsDropTarget(drag_win, pt, source)
	local slot = self:GetInventorySlotCtrl()
	return self:GetVisible() and slot and slot:_IsDropTarget(drag_win, pt, source)
end

---
--- Handles the drop event for an inventory item.
---
--- This function is called when an inventory item is dropped onto another inventory item. It performs the necessary actions to handle the drop event, such as moving the item to the player's inventory or performing other actions based on the context of the drop operation.
---
--- @param drag_win table The window object of the dragged item.
--- @param pt table The position of the mouse cursor.
--- @param drag_source_win table The source window of the drag operation.
---
function XInventoryItem:OnDrop(drag_win, pt, drag_source_win)
end

---
--- Handles the drop event when an inventory item is dropped onto another inventory item.
---
--- This function is called when an inventory item is dropped onto another inventory item. It performs the necessary actions to handle the drop event, such as moving the item to the player's inventory or performing other actions based on the context of the drop operation.
---
--- @param drag_win table The window object of the dragged item.
--- @param pt table The position of the mouse cursor.
--- @param drag_source_win table The source window of the drag operation.
---
function XInventoryItem:OnDropEnter(drag_win, pt, drag_source_win)
	InventoryOnDragEnterStash()
	local slot = self:GetInventorySlotCtrl()
	local context = slot:GetContext()
	local mouse_text = InventoryGetMoveIsInvalidReason(context, InventoryStartDragContext)

	local drag_item = InventoryDragItem	
	HighlightDropSlot(self, true, pt, drag_win)


	local cur_item = self:GetContext()
	local slot_name = slot.slot_name
	if IsKindOf(context, "UnitData") and g_Combat then
		context = g_Units[context.session_id]
	end
	
	-- pick + equip or reload + (repair...)]
	local is_reload = IsReload(drag_item, cur_item)
		
	local ap_cost, unit_ap, action_name = InventoryItemsAPCost(context, slot_name, cur_item, is_reload)
	
	if not mouse_text then
		mouse_text = action_name or ""
		local is_combat  = InventoryIsCombatMode()
		if not is_combat then 
			drag_win:OnContextUpdate(drag_win:GetContext())
		end
		if is_combat and ap_cost and ap_cost>0 then
			mouse_text = InventoryFormatAPMouseText(unit_ap, ap_cost, mouse_text)
		end
	end	
	InventoryShowMouseText(true, mouse_text)
	HighlightAPCost(InventoryDragItem, true, self)
end

---
--- Handles the event when an inventory item is dragged out of the drop area.
---
--- This function is called when an inventory item is dragged out of the drop area. It performs the necessary actions to handle the drop leave event, such as removing the highlight from the drop slot and hiding the mouse text.
---
--- @param drag_win table The window object of the dragged item.
--- @param pt table The position of the mouse cursor.
--- @param source table The source of the drag operation.
---
function XInventoryItem:OnDropLeave(drag_win, pt, source)
	if drag_win and drag_win.window_state ~= "destroying" then 
		HighlightDropSlot(self, false, pt, drag_win)
		InventoryShowMouseText(false)
		HighlightAPCost(InventoryDragItem, false,  self)
	end
end

---
--- Returns the XInventorySlot control that the XInventoryItem is a child of.
---
--- @return table|boolean The XInventorySlot control that the XInventoryItem is a child of, or false if the XInventoryItem is not a child of an XInventorySlot.
---
function XInventoryItem:GetInventorySlotCtrl()
	return IsKindOf(self.parent, "XInventorySlot") and self.parent or false
end

----------------------XInventorySlot-----------------------
DefineClass.XInventorySlot = {
	__parents = {"XDragAndDropControl"},

	properties = {
		{ category = "General", id = "image_transparency", name = "Tile Transparency", editor = "number", default = 0, },
		{ category = "General", id = "rollover_image_transparency", name = "Rolllover Tile Transparency", editor = "number", default = false, },
		{ category = "General", id = "slot_name", name = "Slot Name", editor = "text", default = "", },
	},	
	LayoutMethod = "Grid",
	ChildrenHandleMouse = true,
	IdNode = true,
	ClickToDrag = true,
	ClickToDrop = true,
	LayoutHSpacing = 0,
	LayoutVSpacing = 0,
}

---
--- Creates a new XInventoryTile instance as a child of the XInventorySlot.
---
--- @param slot_name string The name of the slot for which the tile is being created.
--- @return table The newly created XInventoryTile instance.
---
function XInventorySlot:SpawnTile(slot_name)
	return XInventoryTile:new({}, self)
end

---
--- Sets the context of the XInventorySlot control.
---
--- @param context table The context to set for the XInventorySlot control.
--- @param update boolean (optional) Whether to update the context.
---
function XInventorySlot:Setslot_name(slot_name) -- This is called by SetProperty
	local context = self:GetContext() 
	if not context then 
		return 
	end 
	
	-- set slot_name should not do other stuff except setting slot name
	-- fill with empty images
	self.tiles = {}
	self.slot_name = slot_name
	local slot_data = context:GetSlotData(slot_name)
	local width, height, last_row_width = context:GetSlotDataDim(slot_name)
	for i=1, width do
		self.tiles[i] = {}
		for j=1, height do	
			if j~=height or i<=last_row_width then -- check for last row that can be not full size
				local tile = self:SpawnTile(slot_name, i, j)
				if tile then
					tile:SetContext(context)
					tile:SetGridX(i)
					tile:SetGridY(j)
					tile.idBackImage:SetTransparency(self.image_transparency)
					if slot_data.enabled==false then
						tile:SetEnabled(false)
					end
					self.tiles[i][j] = tile
				end
			end
		end
	end	
	-- create items 
	self.item_windows = {}
	self.rollover_windows = {}
	--InventoryDragItem = false
	self:InitialSpawnItems()	
end

---
--- Initializes the spawning of item UIs for the inventory slots.
---
--- This function is called to create the initial item UIs for the inventory slots.
--- It iterates through the items in the current slot and spawns a UI element for each item.
---
--- @param self XInventorySlot The inventory slot instance.
---
function XInventorySlot:InitialSpawnItems()
	local context = self:GetContext()
	if not IsKindOf(context, "Inventory") then 
		return 
	end 
	context:ForEachItemInSlot(self.slot_name, function(item, slotname, left, top, self)
		self:SpawnItemUI(item, left, top)
	end, self)
end

---
--- Updates the context of the inventory slot.
---
--- This function is called when the context of the inventory slot is updated.
--- It updates the popup associated with the inventory slot and updates the item UIs
--- for each item in the slot.
---
--- @param self XInventorySlot The inventory slot instance.
--- @param context table The updated context of the inventory slot.
---
function XInventorySlot:OnContextUpdate(context)
	--self:ClosePopup()
	InventoryUpdatePopup(self)
	for item_wnd, item in pairs(self.item_windows or empty_table) do
		if item_wnd.window_state~="destroying" then
			item_wnd:OnContextUpdate(item)
		end
	end
end

---
--- Returns the inventory slot control.
---
--- This function returns the inventory slot control instance.
---
--- @return XInventorySlot The inventory slot control instance.
---
function XInventorySlot:GetInventorySlotCtrl()
	return self
end

---
--- Spawns a drop UI for an inventory slot.
---
--- This function is called to create a UI element for a drop interaction in an inventory slot.
--- It creates a context window with an image and optional text to represent the drop interaction.
---
--- @param width number The width of the drop UI in tiles.
--- @param height number The height of the drop UI in tiles.
--- @param left number The left grid coordinate of the drop UI.
--- @param top number The top grid coordinate of the drop UI.
--- @return XContextWindow The spawned drop UI window.
---
function XInventorySlot:SpawnDropUI(width, height, left, top)
	local item_wnd = XTemplateSpawn("XContextWindow", self)
	item_wnd:SetHandleMouse(false)
	item_wnd:SetMinWidth(tile_size_rollover*width)
	item_wnd:SetMaxWidth(tile_size_rollover*width)
	item_wnd:SetMinHeight(tile_size_rollover*height)
	item_wnd:SetMaxHeight(tile_size_rollover*height)
	item_wnd:SetGridX(left)
	item_wnd:SetGridY(top)
	item_wnd:SetGridWidth(width)
	item_wnd:SetGridHeight(height)
	item_wnd:SetUseClipBox(false)

	item_wnd:SetIdNode(true)
		
	local item_pad = XTemplateSpawn("XImage", item_wnd)
	item_pad:SetImageFit("width")
	item_pad:SetId("idItemPad")
	item_pad:SetUseClipBox(false)
	item_pad:SetHandleMouse(false)

	item_pad:SetImage(width==2 and "UI/Inventory/T_Backpack_Slot_Large.tga" or "UI/Inventory/T_Backpack_Slot_Small.tga")
	local rollover_image = XImage:new({
		MinWidth = tile_size_rollover,
		MaxWidth = tile_size_rollover,
		MinHeight = tile_size_rollover,
		MaxHeight = tile_size_rollover,
		--ImageColor = 0xFFc3bdac,
		},
	item_wnd)
	rollover_image:SetImage(width==2 and "UI/Inventory/T_Backpack_Slot_Large_Hover.tga" or "UI/Inventory/T_Backpack_Slot_Small_Hover.tga")
	--rollover_image:SetDesaturation(255)
	--rollover_image:SetTransparency(120)
	local center_text = XTemplateSpawn("AutoFitText", item_wnd)			
		center_text:SetTranslate(true)
		center_text:SetTextStyle("DescriptionTextAPRed")
		center_text:SetId("idCenterText")		
		center_text:SetUseClipBox(false)
		center_text:SetTextHAlign("center")
		center_text:SetTextVAlign("center")
		center_text:SetHAlign("center")
		center_text:SetVAlign("center")
		center_text:SetHandleMouse(false)

	return item_wnd
end

---
--- Spawns a rollover UI window for an inventory slot.
---
--- @param width number The width of the rollover UI in grid units.
--- @param height number The height of the rollover UI in grid units.
--- @param left number The left grid coordinate of the rollover UI.
--- @param top number The top grid coordinate of the rollover UI.
--- @return XContextWindow The spawned rollover UI window.
---
function XInventorySlot:SpawnRolloverUI(width, height, left, top)
	local image = self.tiles[left][top]
	image:SetVisible(false)
	if width==2 then
		self.tiles[left+1][top]:SetVisible(false)
	end
	local pos = point_pack(left, top, width)
	if not self.rollover_windows[pos] then
		local item_wnd = XTemplateSpawn("XContextWindow", self)
		item_wnd:SetHandleMouse(true)
		item_wnd:SetMinWidth(tile_size_rollover*width)
		item_wnd:SetMaxWidth(tile_size_rollover*width)
		item_wnd:SetMinHeight(tile_size_rollover*height)
		item_wnd:SetMaxHeight(tile_size_rollover*height)
		item_wnd:SetGridX(left)
		item_wnd:SetGridY(top)
		item_wnd:SetGridWidth(width)
		item_wnd:SetGridHeight(height)
		item_wnd:SetUseClipBox(false)

		item_wnd:SetIdNode(true)

	
		local item_pad = XTemplateSpawn("XImage", item_wnd)
		item_pad:SetMinWidth(tile_size*width)
		item_pad:SetMaxWidth(tile_size*width)
		item_pad:SetMinHeight(tile_size*height)
		item_pad:SetMaxHeight(tile_size*height)
		--item_pad:SetImageFit("width")
		item_pad:SetId("idItemPad")
		item_pad:SetUseClipBox(false)
		item_pad:SetHandleMouse(false)
		item_pad:SetImage(width==1 and "UI/Inventory/T_Backpack_Slot_Small_Hover.tga" or "UI/Inventory/T_Backpack_Slot_Large_Hover.tga")
		item_pad:SetImageColor(0xFFc3bdac)
		
		item_pad:SetTransparency(self.image_transparency)
		item_pad.OnSetRollover = function(this,rollover)	
			XImage.OnSetRollover(this,rollover)			
			if self.rollover_image_transparency then
				this:SetTransparency(rollover and self.rollover_image_transparency or self.image_transparency)
			end
		end
		local slot_img = equip_slot_images[self.slot_name] 
		if equip_slot_images[self.slot_name] then
			local image = XImage:new({
				MinWidth = tile_size,
				MaxWidth = tile_size,
				MinHeight = tile_size,
				MaxHeight = tile_size,
				Id = "idBackImage",
				Image = "UI/Inventory/T_Backpack_Slot_Small.tga",				
			},
			item_wnd)
			image:SetImage(width>1 and "UI/Inventory/T_Backpack_Slot_Large.tga" or "UI/Inventory/T_Backpack_Slot_Small.tga")
			local imgslot = XImage:new({
				MinWidth = tile_size,
				MaxWidth = tile_size,
				MinHeight = tile_size,
				MaxHeight = tile_size,

				Dock = "box",
				Id = "idEqSlotImage",
			},
			image)	
			imgslot:SetImageFit(width>1 and "none" or "width")
			imgslot:SetImage(width>1 and equip_slot_images[self.slot_name.." Big"] or slot_img)			
		end
		local rollover_image = XImage:new({
			MinWidth = tile_size_rollover,
			MaxWidth = tile_size_rollover,
			MinHeight = tile_size_rollover,
			MaxHeight = tile_size_rollover,

			Id = "idRollover",
			Image = width==1 and "UI/Inventory/T_Backpack_Slot_Small_Hover.tga" or "UI/Inventory/T_Backpack_Slot_Large_Hover.tga",
			ImageColor = 0xFFc3bdac,
			},
		item_wnd)
		local center_text = XTemplateSpawn("AutoFitText", item_wnd)			
		center_text:SetTranslate(true)
		center_text:SetTextStyle("DescriptionTextAPRed")
		center_text:SetId("idCenterText")		
		center_text:SetText("")
		center_text:SetUseClipBox(false)
		center_text:SetTextHAlign("center")
		center_text:SetTextVAlign("center")
		center_text:SetHandleMouse(false)

		item_wnd.IsDropTarget = function(this, drag_win, pt, source)
			return self:_IsDropTarget(drag_win, pt, source)
		end
			
		item_wnd.OnDropEnter = function(this, drag_win, pt, drag_source_win)
			InventoryOnDragEnterStash()
			local mouse_text = InventoryGetMoveIsInvalidReason(self.context, InventoryStartDragContext)

			--this only happens when over empty slots
			local drag_item = InventoryDragItem	
			HighlightDropSlot(this, true, pt, drag_win)

			-- pick + equip
			local slot = self
			local unit_ap, ap_cost, action_name
			local dest_container = slot:GetContext()
			if dest_container:CheckClass(drag_item, slot.slot_name) then
				local wnd, l, t =  slot:FindTile(pt)
				if l and t then
					ap_cost, unit_ap, action_name = InventoryItemsAPCost( dest_container, slot.slot_name)
				end
			end
			local is_combat = InventoryIsCombatMode()
			if not is_combat then 
				drag_win:OnContextUpdate(drag_win:GetContext())
			end

			if not mouse_text then
				mouse_text = action_name or T(155594239482, "Move item")			
				if is_combat and ap_cost and ap_cost>0 then
					mouse_text = InventoryFormatAPMouseText(unit_ap, ap_cost, mouse_text)
				end	
			end	
			InventoryShowMouseText(true, mouse_text)
			HighlightAPCost(InventoryDragItem, true, this)
		end
		
		item_wnd.OnDropLeave = function(this, drag_win, pt, source)
			if drag_win and drag_win.window_state ~= "destroying" then 
				HighlightDropSlot(this, false, pt, drag_win)
				InventoryShowMouseText(false)
				HighlightAPCost(InventoryDragItem, false, this)
			end
		end
		
		item_wnd.GetInventorySlotCtrl = function(this)
			return this.parent or self
		end	
		
		self.rollover_windows[pos] = item_wnd		
	end
end

---
--- Spawns the UI representation of an inventory item in the specified slot.
---
--- @param item InventoryItem The inventory item to spawn the UI for.
--- @param left number The left coordinate of the slot to spawn the item in.
--- @param top number The top coordinate of the slot to spawn the item in.
---
function XInventorySlot:SpawnItemUI(item, left, top)
	local image = self.tiles[left][top]
	if not image then
		return 
	end	
	image:SetVisible(false)
	if item:IsLargeItem() then
		self.tiles[left+1][top]:SetVisible(false)
	end
	local item_wnd = XTemplateSpawn("XInventoryItem", self, item)
	item_wnd.idItemPad:SetTransparency(self.image_transparency)
	item_wnd:SetPosition(left, top)
	self.item_windows[item_wnd] = item
end

---
--- Shows or hides the tiles representing an inventory item in the specified slot.
---
--- @param show boolean Whether to show or hide the tiles.
--- @param size number The size of the item, either 1 or 2.
--- @param left number The left coordinate of the slot to show/hide the tiles for.
--- @param top number The top coordinate of the slot to show/hide the tiles for.
---
function XInventorySlot:ShowTiles(show,size,left,top)
	if not left then return end
	if type(left)~="number" then -- left is point
		local wnd
		wnd,left,top = self:FindTile(left)
	end
	if left then
		local image = self.tiles[left][top]
		if not image then
			return 
		end	
		image:SetVisible(show)
		if size==2 and self.tiles[left+1] then
			self.tiles[left+1][top]:SetVisible(show)
		end
	end
end	

-- Drag callbacks
---
--- Finds the tile window that contains the specified point.
---
--- @param pt Point The point to check for.
--- @return Window, number, number The tile window, the left coordinate, and the top coordinate of the tile that contains the point.
---
function XInventorySlot:FindTile(pt)
	local context = self:GetContext()
	local width, height, last_row_width = context:GetSlotDataDim(self.slot_name)
	for i=1, width do
		for j=1, height do	
			if j~=height or i<=last_row_width then --
				if #self.tiles[i]>=j then
					local wnd = self.tiles[i][j] 
					if wnd:PointInWindow(pt) then 
						return wnd, i,j
					end
				end
			end
		end	
	end
end

---
--- Finds the item window that contains the specified point.
---
--- @param pt Point The point to check for.
--- @return Window, InventoryItem The item window and the inventory item it contains, or nil if not found.
---
function XInventorySlot:FindItemWnd(pt)
	if IsKindOf(pt, "InventoryItem") then
		for wnd, item in pairs(self.item_windows) do
			if pt==item then
				return wnd, item
			end
		end
	else
		for wnd, item in pairs(self.item_windows) do
			if wnd:MouseInWindow(pt) then 
				return wnd, item
			end
		end
	end
end

function OnMsg.InventoryChange(obj)
	local dlg = GetDialog("FullscreenGameDialogs")
	if dlg then 
		dlg:ActionsUpdated()		
	end
end

---
--- Updates the inventory UI for the specified unit.
---
--- @param unit Unit|UnitData The unit whose inventory should be updated.
---
function InventoryUpdate(unit)
	local dlg = GetMercInventoryDlg()
	if dlg then
		local context = dlg:GetContext() or {}
		local is_unit_data  = IsKindOf(context.unit, "UnitData") 
		if is_unit_data and unit and context.unit.session_id == unit.session_id then
			context.unit = gv_UnitData[unit.session_id]
		else
			assert(IsKindOfClasses(unit, "Unit", "UnitData"))
			context.unit = unit
		end
		dlg:SetContext(context, "update")
		dlg:OnContextUpdate(context)
	end
	InventoryUIRespawn()	
end

function OnMsg.CombatActionEnd(unit)
	if unit:CanBeControlled() then InventoryUpdate(unit) end
	if gv_SatelliteView then
		unit:SyncWithSession("map")
	end	
	ObjModified(unit)
end

function OnMsg.UnitAPChanged(unit)
	if GetMercInventoryDlg() and gv_SatelliteView and g_Combat then
		unit:SyncWithSession("map") -- move info to UnitData , ap is notrovide , so sync the whole data, so it will be synced back when close the satview
	end
end

function OnMsg.InventoryUnload(src, dest)
	InventoryUIRespawn()	
end

function OnMsg.InventoryChangeItemUI(obj)
	local dlg = GetMercInventoryDlg()
	if dlg then
		local context = dlg:GetContext() or {}
		if obj.session_id == context.unit.session_id and obj:CanBeControlled() then 
			InventoryUpdate(obj) 
		else	
			InventoryUIRespawn()
		end
	else	
		InventoryUIRespawn()
	end
end	

--[[
--this can be used very rarely in a system without cursor because major refresh is needed 90% of the time
--it is nice for a system with a cursor though because it can be used to skip major refresh in more cases
function XInventorySlot:SettleDragWindow(drag_win,drag_item, pos)
	local left, top = point_unpack(pos)
	if drag_win then	
		drag_win:SetDock(false)
		drag_win.DrawOnTop = false
		drag_win:SetParent(self)		
		drag_win:SetGridX(left)
		drag_win:SetGridY(top)
		drag_win.idItemPad:SetTransparency(self.image_transparency)
		drag_win.idItemPad:SetVisible(true)
		drag_win.idText:SetVisible(true)
		drag_win.idTopRightText:SetVisible(true)
		drag_win.idDropshadow:SetVisible(false)
		drag_win.idRollover:SetVisible(false)
		self.item_windows[drag_win] = drag_item				
		drag_win:OnContextUpdate(drag_item )
		drag_win:SetHandleMouse(true)
	end	
	self:ShowTiles(false,drag_item:GetUIWidth(), left, top)
end
]]

---
--- Handles the network synchronization event for dropping an item from a unit's inventory to another sector's stash.
---
--- @param unit_id string The session ID of the unit dropping the item.
--- @param sector_id string The ID of the sector where the item is being dropped.
--- @param src_slot string The name of the inventory slot the item is being dropped from.
--- @param item_id string The ID of the item being dropped.
---
function NetSyncEvents.DropToAnotherSectorStash(unit_id,sector_id,src_slot, item_id)
	local item = g_ItemIdToItem[item_id]
	if not item then return end 
	local unit = gv_UnitData[unit_id]
	unit:RemoveItem(src_slot, item)
	AddToSectorInventory(sector_id,{item})
	InventoryUIRespawn()		
end

---
--- Handles dropping an item from the player's inventory to a container or sector stash.
---
--- @param item table The item being dropped.
---
function XInventorySlot:DropItem(item)
	if not item then return end
	local dlg = GetMercInventoryDlg()
	local unit = GetInventoryUnit(dlg)
	local dest = dlg and dlg:GetContext()
	dest = dest and dest.container

	local args = {item = item, src_container = self.context, src_slot = self.slot_name}	
	if not g_GossipItemsMoveFromPlayerToContainer[item.id] then
		g_GossipItemsMoveFromPlayerToContainer[item.id] = true
	end
	
	if dest and IsKindOf(dest, "SectorStash") then
		local unit_sector = unit.Squad 
		unit_sector = unit_sector and gv_Squads[unit_sector].CurrentSector
		if dest.sector_id~=unit_sector then 
			NetSyncEvent("DropToAnotherSectorStash",self.context.session_id, unit_sector, self.slot_name,item.id)
			PlayFX("DropItem", "start", unit, false, item.class)
			return
		else
			args.dest_container = dest
			args.dest_slot = "Inventory"
		end
	else
		args.dest_container = "drop"
	end
			
	MoveItem(args)
	local surface_fx_type =  false
	if IsKindOf(unit, "Unit") then
		local pos = SnapToPassSlab(unit) or unit:GetPos()
		surface_fx_type  = GetObjMaterial(pos)
	end
	PlayFX("DropItem", "start", unit, surface_fx_type, item.class)
end

---
--- Handles dropping multiple items from the player's inventory to a container or sector stash.
---
--- @param items table The items being dropped.
---
function XInventorySlot:DropItems(items)
	local dlg = GetMercInventoryDlg()
	local unit = GetInventoryUnit(dlg)
	--local dest = dlg and dlg:GetContext()
--	dest = dest and dest.container
 
	local tbl = table.keys(items)
	for i,item in ipairs(tbl)do
		local args = {item = item, src_container = self.context, src_slot = self.slot_name,  multi_items = true}	
		
		if not g_GossipItemsMoveFromPlayerToContainer[item.id] then
			g_GossipItemsMoveFromPlayerToContainer[item.id] = true
		end
		
		--[[if dest and IsKindOf(dest, "SectorStash") then
			local unit_sector = unit.Squad 
			unit_sector = unit_sector and gv_Squads[unit_sector].CurrentSector
			if dest.sector_id~=unit_sector then 
				NetSyncEvent("DropToAnotherSectorStash",self.context.session_id, unit_sector, self.slot_name,item.id)
				PlayFX("DropItem", "start", unit, false, item.class)
				return
			else
				args.dest_container = dest
				args.dest_slot = "Inventory"
			end
		else
		--]]
			args.dest_container = "drop"
		--end
		args.no_ui_respawn	= i~=#tbl
		local r1, r2  = MoveItem(args)
	end
	local surface_fx_type =  false
	if IsKindOf(unit, "Unit") then
		local pos = SnapToPassSlab(unit) or unit:GetPos()
		surface_fx_type  = GetObjMaterial(pos)
	end
	--PlayFX("DropItem", "start", unit, surface_fx_type, item.class)
end
---
--- Returns the starting slot control for the current drag and drop operation.
---
--- If the current drag source is not the same as the inventory start drag context, this function
--- will find the slot control for the inventory start drag slot name and context.
---
--- @param self The current inventory slot control.
--- @return The starting slot control for the current drag and drop operation.
---
function InventoryGetStartSlotControl(self)
	local slot_ctrl = StartDragSource or self
	local context = slot_ctrl and slot_ctrl:GetContext()
	if context~=InventoryStartDragContext then
		local dlg = GetMercInventoryDlg()
		slot_ctrl = dlg:GetSlotByName(InventoryStartDragSlotName, InventoryStartDragContext)
	end
	return slot_ctrl
end

---
--- Cancels the current drag and drop operation for the inventory slot.
---
--- This function clears the drag state of the drag window associated with the inventory slot,
--- and triggers a respawn of the inventory UI.
---
--- @param self The current inventory slot control.
--- @return true if the drag operation was successfully canceled, false otherwise.
---
function XInventorySlot:CancelDragging()
	local drag_win = self.drag_win
	if not drag_win then return end
	self:ClearDragState(drag_win)
	InventoryUIRespawn()
	return true
end

---
--- Cancels the current drag and drop operation for the inventory slot.
---
--- This function clears the drag state of the drag window associated with the inventory slot,
--- and triggers a respawn of the inventory UI.
---
--- @param self The current inventory slot control.
--- @return true if the drag operation was successfully canceled, false otherwise.
---
function XInventorySlot:OnCloseDialog()
	self:CancelDragging()
	self:ClosePopup()
end

---
--- Handles the mouse button up event for an inventory slot.
---
--- This function checks if the item in the slot is locked, and if so, sets the image color of the locked indicator.
--- It then calls the parent `XDragAndDropControl.OnMouseButtonUp` function to handle the rest of the mouse button up logic.
---
--- @param self The current inventory slot control.
--- @param pt The mouse position when the button was released.
--- @param button The mouse button that was released.
--- @return The result of the parent `XDragAndDropControl.OnMouseButtonUp` function.
---
function XInventorySlot:OnMouseButtonUp(pt, button)
	local wnd_found, item = self:FindItemWnd(pt)
	
	-- Locked items
	if item and item.locked then
		wnd_found.idimgLocked:SetImageColor(GameColors.D)		
	end

	return XDragAndDropControl.OnMouseButtonUp(self, pt, button)
end


---
--- Toggles the multi-selection state of an inventory item in the Mercenary Inventory dialog.
---
--- If the item is already selected, it will be deselected. If the item is not selected, it will be selected, and any other selected items will be deselected.
---
--- @param dlg The Mercenary Inventory dialog.
--- @param wnd_found The window control for the inventory item.
--- @param item The inventory item.
--- @return true if the item was successfully toggled, false otherwise.
---
function InventoryToggleItemMultiselect(dlg, wnd_found,item)
	local dlg = dlg or GetMercInventoryDlg()
		-- multi select
	InventoryClosePopup(dlg)
	if dlg.selected_items and dlg.selected_items[item] then
		dlg.selected_items[item] = nil			
		wnd_found:OnSetSelected(false)			
	else
		local itm, wnd = next(dlg.selected_items) 
		if wnd and wnd.window_state~="destroying" then	
			local wnd_slot = wnd:GetInventorySlotCtrl()
			local wnd_found_slot = wnd_found and wnd_found:GetInventorySlotCtrl()
			if      wnd_slot and wnd_found_slot
				and (   wnd_slot~=wnd_found_slot
					  or wnd_slot.context~=wnd_found_slot.context) then
				dlg:DeselectMultiItems()						
			end
		end
		if item then
			dlg.selected_items[item] = wnd_found			
			wnd_found:OnSetSelected(true)			
			return true
		end
	end	
	if dlg and (not item or not dlg.selected_items[item]) then
		dlg:DeselectMultiItems()		
	end
end		


---
--- Handles the mouse button down event for an inventory slot.
---
--- This function is responsible for managing the behavior of the inventory slot when the mouse button is pressed. It checks for various conditions, such as whether the slot is disabled, whether the inventory is in compare mode, and whether the item is locked. It also handles multi-selection of items and quick splitting of stacks.
---
--- @param pt The point where the mouse button was pressed.
--- @param button The mouse button that was pressed ("L" for left, "R" for right, "M" for middle).
--- @return "break" if the event should be consumed, otherwise nil.
---
function XInventorySlot:OnMouseButtonDown(pt, button)
	if button == "M" then
		return "break"
	end
	if not self:GetEnabled() then return "break" end
	local dlgContext = GetDialogContext(self)
	if dlgContext then
		if InventoryDisabled(dlgContext) then
			PlayFX("IactDisabled","start", InventoryDragItem)
			return "break"
		end
	end
	
	local wnd_found, item = self:FindItemWnd(pt)
	
	if InventoryIsCompareMode() then
		return "break"
	end
	
	if button == "L" then
		-- Locked items
		if not wnd_found then
			local wnd,l,t = self:FindTile(pt)
			if wnd then
				PlayFX("InventoryEmptyTileClick", "start")
			end
		end
		local unit = GetInventoryUnit()
		if item and item.locked then
			wnd_found.idimgLocked:SetImageColor(GameColors.I)
			PlayVoiceResponse(item.owner or unit, "LockedItemMove")
			PlayFX("IactDisabled", "start", item)
			return "break"
		end	
	
		local dlg = GetMercInventoryDlg()
		if dlg and terminal.IsKeyPressed(const.vkControl) == true and wnd_found and item then
			if InventoryToggleItemMultiselect(dlg, wnd_found, item) then
				return "break"
			end
		end
		if dlg and (not item or not dlg.selected_items[item]) then
			dlg:DeselectMultiItems()		
		end
		
		if terminal.IsKeyPressed(const.vkShift) == true and wnd_found then
			-- Quick split stack
			if not IsKindOf(item, "InventoryStack") or item.Amount < 2 then return "break" end
			local container = self.context
			if IsKindOfClasses(container, "SquadBag","ItemDropContainer") then return "break" end
			local slot = GetContainerInventorySlotName(container)
			local freeSpace = container:FindEmptyPosition(slot, item)
			if not freeSpace then return "break" end
			OpenDialog("SplitStackItem",false, {context = container, item = item, slot_wnd = self})
			return "break"
		end
		
		WasDraggingLastLMBClick = not not InventoryDragItem
	end
	if button == "R" then
		if InventoryDragItem then
			self:CancelDragging()
			return "break"
		else -- open submenu
			local dlg = GetDialog(self)
			if wnd_found then
				if dlg.item_wnd==wnd_found then
					self:ClosePopup()
				else
					local popup
					if dlg.selected_items then 
						if dlg.selected_items[item] then
							popup = self:OpenPopup(wnd_found, item, dlg)
						else
							dlg:DeselectMultiItems()	
							popup = self:OpenPopup(wnd_found, item, dlg)
						end
					else
						popup = self:OpenPopup(wnd_found, item, dlg)
					end
					if not popup and dlg and next(dlg.selected_items) then
						dlg:DeselectMultiItems()	
					end
				end	
				return "break"
			end
		end
	end
	return XDragAndDropControl.OnMouseButtonDown(self, pt, button)
end

---
--- Opens a popup menu for an inventory slot.
---
--- @param wnd_found table The window object that was found.
--- @param item table The item associated with the inventory slot.
--- @param dlg table The dialog object containing the inventory slot.
--- @return table The spawned popup menu.
function XInventorySlot:OpenPopup(wnd_found, item, dlg)
	local context = self:GetContext()	
	
	self:ClosePopup()
	local dlg = dlg or GetDialog(self)
	local unit = (IsKindOfClasses(context, "Unit", "UnitData") and not context:IsDead()) and context or GetInventoryUnit()
	if InventoryIsNotControlled(unit) then
		return 
	end
	if InventoryIsCompareMode(dlg) then
		dlg:CloseCompare()
		dlg.compare_mode = false
		dlg:ActionsUpdated()
	end
	wnd_found.RolloverTemplate = ""
	local popup 
	if next(dlg.selected_items) then
		popup = XTemplateSpawn("InventoryContextMenuMulti", terminal.desktop, {
			item = item,
			items = dlg.selected_items,
			unit = unit,
			container = IsKindOfClasses(context, "ItemContainer", "SectorStash") and context, 
			context = context,
			wnd = wnd_found,
			slot_wnd = self,
			
			wnd_index = table.find(wnd_found.parent, wnd_found)		
		})
	else
		popup = XTemplateSpawn("InventoryContextMenu", terminal.desktop, {
			item = item,
			unit = unit,
			container = IsKindOfClasses(context, "ItemContainer", "SectorStash") and context, 
			context = context,
			wnd = wnd_found,
			slot_wnd = self,
			
			wnd_index = table.find(wnd_found.parent, wnd_found)		
		})
	end	
	dlg.spawned_popup = popup
	dlg.item_wnd = wnd_found
	popup:SetAnchor(wnd_found.box)
	popup.OnDelete = function(this)
		dlg.spawned_popup = false
		dlg.item_wnd.RolloverTemplate = "RolloverInventory"
		dlg.item_wnd = false
	end

	popup:Open()
	return popup
end

--- Closes the inventory popup associated with the current inventory slot.
---
--- This function is responsible for closing the inventory popup that was spawned
--- for the current inventory slot. It retrieves the dialog associated with the
--- slot, and then calls the `InventoryClosePopup` function to close the popup.
---
--- @param self XInventorySlot The inventory slot instance.
function XInventorySlot:ClosePopup()
	local dlg = GetDialog(self)
	InventoryClosePopup(dlg)
end

--- Closes the inventory popup associated with the given dialog.
---
--- This function is responsible for closing the inventory popup that was spawned
--- for the given dialog. It retrieves the popup associated with the dialog, and
--- then calls the `Close()` method to close the popup. It also resets the
--- `RolloverTemplate` of the item window associated with the dialog.
---
--- @param dlg table The dialog associated with the inventory popup.
--- @return boolean True if the popup was successfully closed, false otherwise.
function InventoryClosePopup(dlg)
	local popup = dlg and rawget(dlg, "spawned_popup")
	if popup and popup.window_state ~= "destroying" then	
		popup:Close()
		if dlg.item_wnd then
			dlg.item_wnd.RolloverTemplate = "RolloverInventory"
			dlg.item_wnd = false
		end
		return true
	end
end

--- Updates the inventory popup associated with the given inventory slot.
---
--- This function is responsible for updating the inventory popup that was spawned
--- for the given inventory slot. It retrieves the dialog associated with the
--- slot, and then checks if the popup is still valid. If the popup's context
--- no longer matches the inventory slot's context, the function will close the
--- popup and reopen it.
---
--- @param inventorySlot XInventorySlot The inventory slot instance.
function InventoryUpdatePopup(inventorySlot)
	local dlg = GetDialog(inventorySlot)
	local popup = dlg and rawget(dlg, "spawned_popup")
	if not popup or popup.window_state == "destroying" then return end
	local popupCtx = popup.context
	if popupCtx.context ~= inventorySlot.context then return end
	
	local itemIndex = table.find(inventorySlot, "context", popupCtx.item)
	if itemIndex ~= popupCtx.wnd_index then
		inventorySlot:ClosePopup()
	end
end

--- Deselects any multi-selected items in the given inventory dialog.
---
--- This function is responsible for deselecting any multi-selected items in the
--- given inventory dialog. If no dialog is provided, it will use the current
--- Merc inventory dialog.
---
--- @param dlg table The inventory dialog to deselect multi-selected items from. If not provided, the current Merc inventory dialog will be used.
function InventoryDeselectMultiItems(dlg)
	local dlg = dlg or GetMercInventoryDlg()
	if dlg then 
		dlg:DeselectMultiItems()
	end	
end		

---
--- Clears the drag state of the inventory slot.
---
--- This function is responsible for clearing the drag state of the inventory slot. It stops the drag operation, clears any drag items, and deletes the drag window if it exists.
---
--- @param drag_win table The drag window associated with the inventory slot. If not provided, the function will use the drag_win property of the inventory slot.
function XInventorySlot:ClearDragState(drag_win)
	drag_win = drag_win or self.drag_win
	if drag_win then
		self:StopDrag()
		if next(InventoryDragItems) then
			drag_win.idItemImg:SetImage(drag_win:GetContext():GetItemUIIcon())
			drag_win.idItemImg:SetImageFit("width")
		end
		
		ClearDragGlobals()	
		InventoryDeselectMultiItems()
		self.item_windows[drag_win] = nil
		if drag_win.window_state ~= "destroying" then drag_win:delete() end
		self.drag_win = false
	end
end

---
--- Handles the drop event for an inventory slot.
---
--- This function is called when an item is dropped onto an inventory slot. It checks if the dropped items can be placed in the target slot, and if so, moves the items to the target slot. If the items cannot be placed, it plays a "drop item fail" sound effect and returns an error message.
---
--- @param drag_win table The drag window associated with the dropped items.
--- @param pt table The position where the items were dropped.
--- @param drag_source_win table The window from which the items were dragged.
--- @return string The result of the drop operation, either "not valid target" or the result of the `DragDrop_MoveItem` function.
---
function XInventorySlot:OnDrop(drag_win, pt, drag_source_win)
	if next(InventoryDragItems) then
		local inv = self.context
		if InventoryStartDragContext~=inv and not inv:FindEmptyPositions(self.slot_name,InventoryDragItems) then
			PlayFX("DropItemFail", "start")
			return "not valid target"
		end
	elseif not self:CanDropAt(pt) then
		PlayFX("DropItemFail", "start")
		return "not valid target"
	end

	return self:DragDrop_MoveItem(pt, self, "check_only")
end

---
--- Moves multiple items from one inventory slot to another.
---
--- This function is responsible for moving multiple items from one inventory slot to another. It checks if the destination slot is a valid target, and if so, moves the items to the destination slot. If the move is successful, it plays a sound effect and updates the UI. If the move is not successful, it plays a "drop item fail" sound effect and returns an error message.
---
--- @param pt table The position where the items were dropped.
--- @param target XInventorySlot The target inventory slot.
--- @param check_only boolean If true, the function will only check if the move is valid, and not actually perform the move.
--- @return boolean, string The result of the move operation, and an optional error message.
---
function XInventorySlot:DragDrop_MoveMultiItems(pt, target, check_only)
	local dest_slot = target.slot_name
	local _, pt = self:GetNearestTileInDropSlot(pt)

	--swap items
	local dest_container = target:GetContext()
	local src_container = InventoryStartDragContext


	local src_slot_name = InventoryStartDragSlotName	
	local args = {src_container = src_container, src_slot = src_slot_name, dest_container = dest_container, dest_slot = dest_slot,
						 check_only = check_only, exec_locally = false, multi_items = true}
	local r1, r2, sync_unit
	for i=1, #InventoryDragItems do
		local item = InventoryDragItems[i]
		args.item = item
		args.no_ui_respawn = i~=#InventoryDragItems
		r1, r2, sync_unit = MoveItem(args)
--		print(item.class, r1, r2)
		if r1 or not check_only then
			PlayFXOnMoveItemResult(r1, item, dest_slot, sync_unit)	
		end
		if not r1 and not check_only and (not r2  or r2~="no change") then
			self:Gossip(item, src_container, target)			
		end
	end	
	if not r1 and not check_only then
		local dlg = GetMercInventoryDlg()
	--	dlg:DeselectMultiItems()
	end
	return r1, r2
end

---
--- Moves a single item from one inventory slot to another.
---
--- This function is responsible for moving a single item from one inventory slot to another. It checks if the destination slot is a valid target, and if so, moves the item to the destination slot. If the move is successful, it plays a sound effect and updates the UI. If the move is not successful, it plays a "drop item fail" sound effect and returns an error message.
---
--- @param pt table The position where the item was dropped.
--- @param target XInventorySlot The target inventory slot.
--- @param check_only boolean If true, the function will only check if the move is valid, and not actually perform the move.
--- @return boolean, string The result of the move operation, and an optional error message.
---
function XInventorySlot:DragDrop_MoveItem(pt, target, check_only)
	if not InventoryDragItem then
		return "no item being dragged"
	end
	
	if	not target then 
		return "not valid target"
	end

	local dest_slot = target.slot_name
	local _, pt = self:GetNearestTileInDropSlot(pt)
	local _, dx, dy = target:FindTile(pt)
	if not dx then
		return "no target tile"
	end
	local item = InventoryDragItem
	local items = InventoryDragItems
	local ssx, ssy, sdx = point_unpack(InventoryDragItemPos)
	if item:IsLargeItem() then
		dx = dx - sdx
		if IsEquipSlot(dest_slot) then
			dx = 1
		end
	end
	if ssx==dx and ssy==dy and target == StartDragSource then
		if not check_only then
			PlayFXOnMoveItemResult(false, item, dest_slot)	
			self:CancelDragging()
		end
		return false					
	end

	if not InventoryIsValidTargetForUnit(self.context) or 
		not InventoryIsValidTargetForUnit(InventoryStartDragContext) or
		not InventoryIsValidGiveDistance(self.context, InventoryStartDragContext)
	then	
		return "not valid target"
	end
	
	if next(InventoryDragItems) then
		-- move or give multiple items to slot , not specific destination
		return self:DragDrop_MoveMultiItems(pt, target, check_only)		
	end
	
	--swap items
	local dest_container = target:GetContext()
	local src_container = InventoryStartDragContext

	local under_item = dest_container:GetItemInSlot(dest_slot,nil,dx,dy)

	local src_slot_name = InventoryStartDragSlotName	
	local use_alternative_swap_pos =  not not (IsEquipSlot(dest_slot) and not IsEquipSlot(src_slot_name) and under_item)

	local args = {item = item, src_container = src_container, src_slot = src_slot_name, dest_container = dest_container, dest_slot = dest_slot,
						dest_x = dx, dest_y = dy, check_only = check_only, exec_locally = false, alternative_swap_pos = use_alternative_swap_pos}
	local r1, r2, sync_unit = MoveItem(args)
	if r1 or not check_only then
		PlayFXOnMoveItemResult(r1, item, dest_slot, sync_unit)	
	end
	if not r1 and not check_only and (not r2  or r2~="no change") then
		self:Gossip(item, src_container, target, ssx, ssy, dx, dy)
	end
	return r1, r2
end

---
--- Handles the gossip logic when an item is moved between different inventory containers or units.
---
--- @param item table The item being moved.
--- @param src_container table The source container of the item.
--- @param target table The target container or unit the item is being moved to.
--- @param src_x number The x-coordinate of the item's source position.
--- @param src_y number The y-coordinate of the item's source position.
--- @param dest_x number The x-coordinate of the item's destination position.
--- @param dest_y number The y-coordinate of the item's destination position.
function XInventorySlot:Gossip(item, src_container, target, src_x, src_y, dest_x, dest_y)
	local context = target:GetContext()
	local item_id = item.id	
	if (context=="drop" or IsKindOfClasses(context, "SectorStash",  "ItemDropContainer","ItemContainer", "ContainerMarker")  -- destination
			or IsKindOf(context, "Unit") and context:IsDead() )	
	then		
		if IsKindOfClasses(src_container, "Unit", "UnitData", "SquadBag") -- source
			and not g_GossipItemsMoveFromPlayerToContainer[item_id] 			
		then
			g_GossipItemsMoveFromPlayerToContainer[item_id] = true
		end
	end
		
	-- take from loot	
	if IsKindOfClasses(context, "Unit", "UnitData", "SquadBag") then -- destination
		if (	IsKindOfClasses(src_container, "SectorStash",  "ItemDropContainer","ItemContainer", "ContainerMarker")  -- sorce
			or IsKindOf(src_container, "Unit") and src_container:IsDead() )
			and not g_GossipItemsTakenByPlayer[item_id] 
			and     g_GossipItemsSeenByPlayer[item_id]
			and not g_GossipItemsMoveFromPlayerToContainer[item_id]
		then
			NetGossip("Loot","TakeByPlayer", item.class, rawget(item, "Amount") or 1, GetCurrentPlaytime(), Game and Game.CampaignTime)
			g_GossipItemsTakenByPlayer[item_id] = true
		end
	end
	
	-- equip
	local ammo = IsKindOfClasses(item, "Ammo", "Ordnance")
	if ammo then 
		return 
	end
	
	local src =  IsKindOfClasses(src_container, "Unit", "UnitData") and src_container.session_id or src_container.class
	local dest = IsKindOfClasses(context, "Unit", "UnitData") and context.session_id or context.class

	local src_part  = IsKindOf(self, "EquipInventorySlot") and "Body" or "Items"
	local dest_part = IsKindOf(target, "EquipInventorySlot") and "Body" or "Items"
	
	if not g_GossipItemsEquippedByPlayer[item_id] and dest_part=="Body" and src_part == "Items" then
		NetGossip("EquipItem", item.class, src, src_part, src_x, src_y, dest, dest_part, dest_x, dest_y, GetCurrentPlaytime(), Game and Game.CampaignTime)
		g_GossipItemsEquippedByPlayer[item_id] = true
	end
end

--- Returns the appropriate FX actor for the given inventory item.
---
--- @param item table The inventory item.
--- @return string The FX actor name.
function GetInventoryItemDragDropFXActor(item)
	if IsKindOf(item, "Ammo") then
		return item.Caliber
	end
	if IsKindOf(item, "Armor") then
		if item.Slot=="Head" then
			return "ArmorHelmet"
		elseif item.PenetrationClass<=2 then
			return "ArmorLight"
		else	
			return "ArmorHeavy"
		end		
	end
	if InventoryItemDefs[item.class].group=="Magazines" then
		return "Magazines"
	end
	return item.class
end

---
--- Plays the appropriate FX and logs the appropriate combat log message based on the result of moving an inventory item.
---
--- @param result string The result of the move item operation.
--- @param item table The inventory item being moved.
--- @param dest_slot string The name of the destination inventory slot.
--- @param unit table The unit associated with the inventory.
---
function PlayFXOnMoveItemResult(result, item, dest_slot, unit)
	item = item or InventoryDragItem
	if not result then
		if dest_slot and IsEquipSlot(dest_slot) and IsKindOfClasses(item,"Firearm", "HeavyWeapon")  then
			PlayFX("WeaponEquip", "start", item.class, item.object_class)
		else
			PlayFX("InventoryItemDrop", "start", GetInventoryItemDragDropFXActor(item))
		end
	
		if dest_slot and IsEquipSlot(dest_slot) and item:IsCondition("Poor") then
			local unit = unit or GetInventoryUnit()
			PlayVoiceResponse(unit.session_id, "ItemInPoorConditionEquipped")
		end
	elseif result == "Unit doesn't have ap to execute action" then
		if IsEquipSlot(dest_slot) then
			CombatLog("important", T{536432871775, "<DisplayName> doesn't have enough AP to pick and equip the item", unit or GetInventoryUnit()})
			PlayFX("EquipFail", "start", item)
		else
			CombatLog("important", T{925174211499, "<DisplayName> doesn't have enough AP", unit or GetInventoryUnit()})
		end
	elseif result == "not valid target" or result == "no item being dragged" then
		PlayFX("IactDisabled","start", item)
	elseif result == "item underneath is locked" or result == "item is locked" then
		PlayFX("IactDisabled", "start", item)
	elseif result == "Unit doesn't have ap to execute action" then
		PlayFX("IactDisabled","start", item)
	elseif result == "too many items underneath" or result == "not valid target" then
		PlayFX("IactDisabled","start", item)
	elseif result == "invalid reload target" then
		PlayFX("IactDisabled","start", item)
	elseif result == "Unit doesn't have ap to reload" then
		CombatLog("important", T{984048298727, "<DisplayName> doesn't have enough AP to reload",unit or  GetInventoryUnit()})
		PlayFX("ReloadFail", "start", item)
	elseif result == "Could not swap items, source container does not accept item at dest"
			or result == "Could not swap items, dest container does not accept source item"
			or result == "Could not swap items, item at dest does not fit in source container at the specified position"
			or result == "Could not swap items, item does not fit in dest container at the specified position"
			or result == "Could not swap items, items overlap after swap" then
		PlayFX("IactDisabled","start", item)
	elseif result == "Can't add item to container, wrong class" then
		PlayFX("IactDisabled", "start", item)
	elseif result then --probably this -> string.format("move failed, dest inventory refused item, reason: %s", reason)
		PlayFX("IactDisabled", "start", item)
	end
end

--- Gets the drag target for the inventory slot.
---
--- @param pt table The point where the drag is dropped.
--- @return table|boolean The drag target, or false if no valid target.
--- @return table The point where the drag is dropped.
function XInventorySlot:GetDragTarget(pt)
	local target = self.drag_target
	
	if not target then
		target, pt = self:GetNearestTileInDropSlot(pt)
		if target then
			local is_valid_target = target:IsDropTarget(self.drag_win, pt, self)
			target = is_valid_target and target or false
		end
	end
	
	if target and target:HasMember("GetInventorySlotCtrl") then
		target = target:GetInventorySlotCtrl()
	end
	
	return target, pt
end

---
--- Handles the internal logic when an inventory slot drag operation is stopped.
---
--- @param pt table The point where the drag is dropped.
function XInventorySlot:InternalDragStop(pt)
	local drag_win = self.drag_win
	self:UpdateDrag(drag_win, pt)
	
	local result = "not valid target"
	local target = self:GetDragTarget(pt)
	if target then
		result = target:OnDrop(drag_win, pt, self)
	else
		PlayFX("DropItemFail", "start")
	end
	if not result then
		self:OnDragDrop(target, drag_win, result, pt)
	end
end

---
--- Checks if the current inventory slot can accept a dropped item.
---
--- @param pt table The point where the drag is dropped.
--- @return boolean|string True if the drop is valid, or a string error message if not.
function XInventorySlot:CanDropAt(pt)
	if not pt then return true end

	local unit = self:GetContext()
	if not unit then return end
	
	local stackable = IsKindOf(InventoryDragItem, "InventoryStack")
	local is_multi = next(InventoryDragItems)
	local dest_slot = self.slot_name
	local _, dx, dy = self:FindTile(pt)
	if not dx then return true end
	
	local item_at_dest = dx and unit:GetItemInSlot(dest_slot, nil, dx, dy)
	stackable = stackable and item_at_dest and item_at_dest.class == InventoryDragItem.class
	
	if not is_multi then
		if 	IsReload(InventoryDragItem, item_at_dest) 
			or IsMedicineRefill(InventoryDragItem, item_at_dest) 
			or InventoryIsCombineTarget(InventoryDragItem, item_at_dest) 
		then
			return true
		end
	end
	if not unit:CheckClass(InventoryDragItem, dest_slot) then
		return false, "different class"		
	end
	local is_equip_slot = IsEquipSlot(dest_slot)
	if is_multi and is_equip_slot then 
		return false, "cannot multi equip"
	end	
	if not is_multi then
		if not is_equip_slot and item_at_dest and (item_at_dest ~= InventoryDragItem and not stackable) then
			--swapping is now allowed for items of the same size
			if InventoryDragItem:IsLargeItem() ~= item_at_dest:IsLargeItem() then
				--print("CanDropAt", InventoryDragItem.class, item_at_dest.class, "false")
				return false, "cannot swap"
			end
		end
		if not is_equip_slot and InventoryDragItem:IsLargeItem() then
			local ssx, ssy, sdx = point_unpack(InventoryDragItemPos)
			if sdx>=0 then
				dx = dx - sdx
			end
		
			local otherItem = unit:GetItemInSlot(dest_slot, nil, dx, dy) --item at other slot
			
			if ssx==dx and ssy==dy and self == StartDragSource then
				return true
			end
			if otherItem and (otherItem:IsLargeItem() ~= InventoryDragItem:IsLargeItem() or (item_at_dest and item_at_dest ~= otherItem)) then
				--allow swap when both are large and there is only one underneath
				return false,"cannot swap"
			end
		end
	end	
	return true
end

---
--- Starts the drag operation for an item in the inventory UI.
---
--- @param wnd_found XWindow The window containing the item being dragged.
--- @param item InventoryItem The item being dragged.
---
function XInventorySlot:ItemWndStartDrag(wnd_found, item)
	wnd_found.idItemPad:SetHandleMouse(false)
	wnd_found.idItemPad:SetVisible(false)
	wnd_found.idText:SetVisible(false)
	wnd_found.idTopRightText:SetVisible(false)
	local img_mod = rawget(wnd_found.idItemImg, "idItemModImg")
	if img_mod then img_mod:SetVisible(false) end
	wnd_found.idDropshadow:SetVisible(false)
	wnd_found:SetHandleMouse(false)
	wnd_found.idRollover:SetVisible(false)
	local left, top = self.context:GetItemPosInSlot(self.slot_name, item)
	if left and top then
		self:ShowTiles(true, item:GetUIWidth(), left, top)
	end
end

---
--- Handles the drop event when an item is dropped on this inventory slot.
---
--- @param drag_win XWindow The window of the dragged item.
--- @param pt Point2D The position where the item was dropped.
--- @param drag_source_win XWindow The window of the source of the drag operation.
--- @return string The result of the drop operation, either "not valid target" or the result of `DragDrop_MoveItem`.
---
function XInventorySlot:OnDrop(drag_win, pt, drag_source_win)
	if not self:CanDropAt(pt) then
		PlayFX("DropItemFail", "start")
		return "not valid target"
	end

	return self:DragDrop_MoveItem(pt, self, "check_only")
end

---
--- Handles the drop event when an item is dropped on this inventory slot.
---
--- @param target XInventorySlot The target inventory slot where the item is being dropped.
--- @param drag_win XWindow The window of the dragged item.
--- @param drop_res string The result of the drop operation, either "not valid target" or the result of `DragDrop_MoveItem`.
--- @param pt Point2D The position where the item was dropped.
--- @return boolean, string The result of the drop operation, either "not valid target" or the result of `DragDrop_MoveItem`.
---
function XInventorySlot:OnDragDrop(target, drag_win, drop_res, pt)
	local result, result2 = self:DragDrop_MoveItem(pt, target)
	local sync_err = result=="NetStartCombatAction refused to start"
	assert(not result or sync_err, result, result2)
	self:ClearDragState(drag_win)
	if sync_err or result2 == "no change" then
		InventoryUIRespawn()
	end
end

---
--- Gets the nearest tile in the drop slot for the given point.
---
--- @param pt Point2D The point to find the nearest tile for.
--- @return XInventoryTile|XInventorySlot, Point2D The nearest tile and the adjusted point.
---
function XInventorySlot:GetNearestTileInDropSlot(pt)
	local target = self.desktop.modal_window:GetMouseTarget(pt)
	if IsKindOf(target, "XInventoryTile") then
		return target, pt
	elseif IsKindOf(target, "XInventorySlot") then
		return target:FindNearestTile(pt)
	else
		return false, pt
	end
end

---
--- Gets the nearest tile in the drop slot for the given point.
---
--- @param pt Point2D The point to find the nearest tile for.
--- @return XInventoryTile|XInventorySlot, Point2D The nearest tile and the adjusted point.
---
function XInventorySlot:FindNearestTile(pt)
	if not self.tiles or #self.tiles < 1 then return end
	local closestTile = false
	local newPt = pt
	local minDistance = 9999
	for x, column in ipairs(self.tiles) do
		for y, tile in ipairs(column) do
			local tileCenter = tile.box:Center()
			local dist = pt:Dist2D(tileCenter)
			if dist < minDistance then
				minDistance = dist
				closestTile = tile
				newPt = tileCenter
			end
		end
	end
	return closestTile, newPt
end

---
--- Handles the start of dragging an item from an inventory slot.
---
--- @param pt Point2D The point where the drag started.
--- @param button integer The mouse button that was used to start the drag.
--- @return boolean Whether a valid item was found to start the drag.
---
function XInventorySlot:OnDragStart(pt, button)
	local dlg = GetDialog(self)
	local context = self:GetContext()
	if InventoryUIGrayOut(context) then
		local left = dlg:ResolveId("idPartyContainer")						
		local squad_list = left.idParty and left.idParty.idContainer or empty_table
		for _, button in ipairs(squad_list) do	
			local member = button:GetContext()
			if member.session_id==context.session_id then
				button:SelectUnit()
				return
			end	
		end
	end
	
	local unit = IsKindOf(context, "Unit") and context or not IsKindOf(context, "SquadBag") and g_Units[context.session_id]
	if unit and IsMerc(unit) and (not unit:IsLocalPlayerControlled() and not unit:IsDead() or not InventoryIsValidTargetForUnit(unit)) then
		return
	end
	
	self:ClosePopup()
	local wnd_found, item = self:FindItemWnd(pt)
	if wnd_found and item then
		local left, top = self.context:GetItemPosInSlot(self.slot_name, item)
		if not left then 
			self:StopDrag()
			return
		end
		self:ItemWndStartDrag(wnd_found, item)
		InventoryDragItem = item
		if next(dlg.selected_items) then
			InventoryDragItems = InventoryDragItems or {}
			for item, wnd in pairs(dlg.selected_items) do
				table.insert(InventoryDragItems, item)
				if wnd~=wnd_found and wnd.window_state~="destroying" then
					self:ItemWndStartDrag(wnd, item)
				end
				if wnd~=wnd_found then
					wnd:SetVisible(false)
				else
					wnd.idItemImg:SetImage("UI/Icons/Items/multiple_items")
					wnd.idItemImg:SetImageFit("height")
				end
			end
			table.sort(InventoryDragItems, function(a,b) return a:GetUIWidth()>b:GetUIWidth() end) 
		end
		
		if InventoryDragItem and not InventoryDragItems then
			HighlightEquipSlots(InventoryDragItem, true)
			HighlightWeaponsForAmmo(InventoryDragItem, true)
		end
		
		local  w,lleft, ltop = self:FindTile(pt) -- check where the dragged item's anchor spot is and adjust dest, this is when a large item is clicked in the right part
		InventoryDragItemPos = point_pack(left, top,lleft>left and 1 or 0)
		InventoryDragItemPt = pt
		StartDragSource = self
		InventoryStartDragSlotName = self.slot_name
		InventoryStartDragContext = self:GetContext()
		
	--	HighlightAPCost(InventoryDragItem, true, self)
		
		PlayFX("InventoryItemDrag", "start", GetInventoryItemDragDropFXActor(item))
	end
	return wnd_found
end

---
--- Called when a drag operation has a new target.
---
--- @param target table The new target object.
--- @param drag_win table The drag window object.
--- @param drop_res table The drop resolution object.
--- @param pt table The current mouse position.
---
function XInventorySlot:OnDragNewTarget(target, drag_win, drop_res, pt)
end

---
--- Checks if the inventory is disabled for the given inventory context.
---
--- @param inventoryContext table The inventory context to check.
--- @return boolean, string Whether the inventory is disabled, and an optional error message.
---
function InventoryDisabled(inventoryContext)
	local unit = inventoryContext.unit
	if unit and not inventoryContext.autoResolve then
		if IsKindOf(unit, "UnitData") then
			return unit:InventoryDisabled()
		end
	else
		return false, T("")
	end
end
-------------
--[[
function XInventorySlot:HasItemUnderDragWin(drag_win, pt, drag_size)
	local context = self.context
	local _, left, top = self:FindTile(pt)
	local pt_first = true
	local blong = drag_size>1
	if left and blong and ((drag_win.box:maxx()- InventoryDragItemPt:x())<=drag_win.box:sizex()/2) then
		left = left - 1
		pt_first = false
		if left<=0 then left = false end
	end
	if not left then
		return false
	end
	local  first = context:GetItemInSlot(self.slot_name, false, left, top)
	if first == InventoryDragItem then
		first = false
	end
	if not blong then
		return first, left, top, pt_first
	else
		local second = context:GetItemInSlot(self.slot_name, false, left+1, top)
		if second == InventoryDragItem then
			second = false
		end
		if first and first==second or not second then
			return first, left, top, pt_first
		end	
		if not first and second then
			return second, left, top, pt_first
		end	
			
		return -1, left, top, pt_first
	end
end
--]]
--- Called when a drag operation has ended on this inventory slot.
---
--- @param drag_win table The drag window that was dropped.
--- @param last_target table The last target the drag window was over.
--- @param drag_res boolean The result of the drag operation.
function XInventorySlot:OnDragEnded(drag_win, last_target, drag_res)
end
function XInventorySlot:OnDragEnded(drag_win, last_target, drag_res)	
	local dlg = GetMercInventoryDlg()
	if InventoryIsCompareMode() then
		dlg:CloseCompare()
		dlg.compare_mode = false
		dlg:ActionsUpdated()
		XInventoryItem.RolloverTemplate = "RolloverInventory"
	end

	if drag_win and drag_win.window_state ~= "destroying" then 
		drag_win:OnContextUpdate(drag_win:GetContext()) 
	end
	local context = self:GetContext()
	self:OnContextUpdate(context)
end

---
--- Checks if the current inventory slot is a valid drop target for the dragged item.
---
--- @param drag_win table The drag window that is being dropped.
--- @param pt table The point where the drag window is being dropped.
--- @param drag_source_win table The window that the drag operation originated from.
--- @return boolean True if the current inventory slot is a valid drop target, false otherwise.
---
function XInventorySlot:_IsDropTarget(drag_win, pt, drag_source_win)
	if not self:GetEnabled() then 
		HighlightDropSlot(false, false, false, drag_win)
		return false
	end
	local context = self:GetContext()
	if InventoryIsNotControlled(context) then 
		HighlightDropSlot(false, false, false, drag_win)
		local valid, mouse_text = InventoryIsValidTargetForUnit(context)

		InventoryShowMouseText(true,mouse_text)
		return false
	end	

	local slot_name = self.slot_name
	local drag_item = InventoryDragItem
	local drag_size = drag_item:GetUIWidth()

	--this block makes it so no highlight window appears below dragged item if swap is not possible.
	--comment it out and it will appear, colored when its not possible.
	--0208219
	local res, reason = self:CanDropAt(pt)
	if not res then
		HighlightDropSlot(false, false, false, drag_win)
		return false
	end
	--
	
	HighlightDropSlot(self, true, pt, drag_win)
	local ctrl, itm = self:FindItemWnd(pt) 
	if not ctrl then
		ctrl = self:FindTile(pt)
	end	
	if ctrl and itm~=InventoryDragItem then
		HighlightAPCost(InventoryDragItem, true, ctrl)
	end
	return true
end

---
--- Returns the tile at the given drag window position.
---
--- @param drag_win table The drag window that is being dropped.
--- @param pt table The point where the drag window is being dropped.
--- @return table The tile at the given drag window position.
---
function XInventorySlot:OnTargetDragWnd(drag_win, pt)
	local left, top = point_unpack(InventoryDragItemPos)
	return self.tiles[left][top]
end

---
--- Splits an inventory item into two items, moving the split amount to a new slot.
---
--- @param item table The item to be split.
--- @param splitAmount number The amount of the item to be split off.
--- @param unit table The unit that owns the inventory.
--- @param xInventorySlot table The inventory slot control where the item is located.
--- @return boolean Whether the split operation was successful.
---
function SplitInventoryItem(item, splitAmount, unit, xInventorySlot)
	local container = unit
	local slot = GetContainerInventorySlotName(container)
	local result = MoveItem({item = item, src_container = container, src_slot = xInventorySlot.slot_name, dest_container = container, dest_slot = slot, amount = splitAmount})
	if result then
		PlayFXOnMoveItemResult(result, item)
	else
		PlayFX("SplitItem", "start", item.class,item.object_class)
	end
end

---
--- Sets various highlights on the inventory UI based on the given item.
---
--- @param item table The item to set the highlights for.
--- @param bShow boolean Whether to show or hide the highlights.
---
function SetInventoryHighlights(item, bShow)
	HighlightEquipSlots(item, bShow)
	HighlightWeaponsForAmmo(item, bShow)
	HighlightItemStats(item, bShow)
	HighlightWoundedCharacterPortraits(item, bShow)
	HighlightAmmoForWeapons(item, bShow)
	HighlightMedsForMedicine(item, bShow)
	HighlightMedicinesForMeds(item, bShow)
end

---
--- Highlights the rollover image for an inventory item window.
---
--- @param width number The width of the item window.
--- @param wnd table The inventory item window.
--- @param bShow boolean Whether to show or hide the rollover highlight.
---
function HighlihgtRollover(width, wnd, bShow)
	local rollover_image = wnd.idRollover
	local item = wnd:GetContext()
	local large 
	if item then
		large = item:IsLargeItem() 
	else 
		large = width and width>1
	end
	if bShow then
		rollover_image:SetImage(large and "UI/Inventory/T_Backpack_Slot_Large_Hover_2.tga" or "UI/Inventory/T_Backpack_Slot_Small_Hover_2.tga")
		rollover_image:SetImageColor(RGB(255,255,255))
	else
		rollover_image:SetImage(large and "UI/Inventory/T_Backpack_Slot_Large_Hover.tga" or "UI/Inventory/T_Backpack_Slot_Small_Hover.tga")
		rollover_image:SetImageColor(0xFFc3bdac)
	end
	--rollover_image:SetDesaturation(bShow and 255 or 0)
	--rollover_image:SetTransparency(bShow and 120 or 0)	
end

local dropWnd = false 
function HighlightAPCost(item, bShow, wnd)
--[[
	if not InventoryIsCombatMode() then 
		return 
	end
	local unit = GetInventoryUnit()
	if not unit then
		return 
	end
	if IsKindOf(unit, "UnitData") then
		unit = g_Units[unit.session_id]
	end

	local slot = wnd:GetInventorySlotCtrl()
	local slot_name = slot.slot_name
	local is_eq_slot = IsEquipSlot(slot_name)
	if not is_eq_slot	then
		return 
	end
	-- pick and relaod, pick and equip
	local wnd_item = slot.item_windows[wnd]
	local slot_context = slot:GetContext()
	local cost_ap = 0
	local is_ammo = IsKindOf(item, "Ammo")
	local w, left, top = slot:FindTile(wnd.box:Center())
	local dlg = GetMercInventoryDlg()
	local slot_ctrl = ((InventoryStartDragSlotName == "Inventory") or (InventoryStartDragSlotName == "InventoryDead")) and dlg:GetSlotByName(InventoryStartDragSlotName, InventoryStartDragContext) or dlg:GetSlotByName(InventoryStartDragSlotName)

	
	if is_ammo and wnd_item and wnd.window_state~="destroying" then
		-- reload
		if bShow then
			cost_ap = slot_ctrl:GetCostAP(slot_context, slot_name, point_pack(left, top), is_ammo and IsWeaponReloadTarget(item, wnd_item), item)			
			if cost_ap > 0 then	
				local style = unit:UIHasAP(cost_ap) and "DescriptionTextGlow" or "DescriptionTextAPRed"
				wnd.idCenterText:SetTextStyle(style)
				wnd.idCenterText:SetText(T{463776601477, "<ap(cost_ap)>", cost_ap = cost_ap})
				wnd.idItemImg:SetTransparency(128)
			end
		else	
			wnd:OnContextUpdate(wnd_item)			
		end
	end	
	if wnd_item and wnd_item.locked then
		return
	end	
	local width = item:GetUIWidth() 
	local pos = point_pack(left, top, width)
	local r_wnd = dropWnd --or slot:SpawnRolloverUI(width, 1, left, top)
	--r_wnd = r_wnd or slot.rollover_windows[pos]

	-- equip
	if r_wnd then
		if bShow then	
			cost_ap = slot_ctrl:GetCostAP(slot_context, slot_name, point_pack(left, top), false, item)
			if cost_ap > 0 then	
				local style = unit:UIHasAP(cost_ap) and "DescriptionTextGlow" or "DescriptionTextAPRed"
				r_wnd.idCenterText:SetTextStyle(style)
				r_wnd.idCenterText:SetText(T{463776601477, "<ap(cost_ap)>", cost_ap = cost_ap})
			end				
		else
			r_wnd.idCenterText:SetText("")
		end
	end
--]]	
end

---
--- Highlights the compare slots in the inventory UI when an item is compared.
---
--- @param item table The item being compared.
--- @param other table A list of other items being compared.
--- @param bShow boolean Whether to show or hide the compare slot highlights.
---
function HighlightCompareSlots(item, other, bShow)
	local dlg = GetMercInventoryDlg()
	if not dlg then
		return 
	end
	
	local compare_mode_on = InventoryIsCompareMode(dlg)
	local compare_mode_slot = compare_mode_on and dlg.compare_mode_weaponslot==1 and "Handheld A" or compare_mode_on and "Handheld B" or false
	local context = GetInventoryUnit()
	
	for _, slot_data in ipairs(context.inventory_slots) do
		local slot_name = slot_data.slot_name
		if IsEquipSlot(slot_name) and context:CheckClass(item,slot_name) and (not compare_mode_slot or compare_mode_slot==slot_name) then
			local target = dlg:GetSlotByName(slot_name)
			for wnd, witem in pairs(target.item_windows or empty_table) do
				if witem ~= item and table.find(other, witem) then
					wnd:OnSetRollover(bShow)
				end
			end
		end	
	end			
	
end

---
--- Highlights the equip slots in the inventory UI when an item is equipped or compared.
---
--- @param item table The item being equipped or compared.
--- @param bShow boolean Whether to show or hide the equip slot highlights.
---
function HighlightEquipSlots(item, bShow)
	local dlg = GetMercInventoryDlg()
	if not dlg then
		return 
	end
	
	local compare_mode_on = item:IsWeapon() and InventoryIsCompareMode(dlg)
	local compare_mode_slot = compare_mode_on and dlg.compare_mode_weaponslot==1 and "Handheld A" or compare_mode_on and "Handheld B" or false
	
	local context = GetInventoryUnit()
	local width = item:GetUIWidth() 
	local height = 1
	local p1 = point_pack(point(1, 1))
	local p2 = point_pack(point(2, 1))
	
	for _, slot_data in ipairs(context.inventory_slots) do
		local slot_name = slot_data.slot_name
		if IsEquipSlot(slot_name) and context:CheckClass(item,slot_name) and (not compare_mode_slot or compare_mode_slot==slot_name) then
			local target = dlg:GetSlotByName(slot_name)
			local valid_idx = {target:CanEquip(item, p1) or false, target:CanEquip(item, p2) or false}
			
			local count = context:CountItemsInSlot(slot_name)			
			if width == 1 or count<=1 then 
				if count == 0 then
					if width==1 then
						if bShow then
							target:SpawnRolloverUI(width,height, 1,1)	
							if target.tiles[2] then 
								target:SpawnRolloverUI(width,height, 2,1)
							end
							for pos, wnd in pairs(target.rollover_windows or empty_table) do
								wnd:OnSetRollover(bShow)
								HighlihgtRollover(width, wnd, bShow)
							end
						else
							for pos, wnd in pairs(target.rollover_windows or empty_table) do
								local l,t,w = point_unpack(pos)
								target.tiles[l][t]:SetVisible(true)
								if w>1 then
									target.tiles[l+1][t]:SetVisible(true)
								end
								wnd:delete()
							end
							target.rollover_windows = {}
						end
					elseif width>1 then 
						if bShow then
							target:SpawnRolloverUI(width,height, 1,1)
							for pos, wnd in pairs(target.rollover_windows or empty_table) do
								wnd:OnSetRollover(bShow)
								HighlihgtRollover(width, wnd, bShow)
							end
						else
							for pos, wnd in pairs(target.rollover_windows or empty_table) do
								local l,t,w = point_unpack(pos)
								target.tiles[l][t]:SetVisible(true)
								if w>1 then
									target.tiles[l+1][t]:SetVisible(true)
								end
								wnd:delete()
							end
							target.rollover_windows = {}
						end
					end						
				elseif count==1 and width==1 then
					for wnd, witem in pairs(target.item_windows or empty_table) do
						if witem ~= item then
							wnd:OnSetRollover(bShow)
							HighlihgtRollover(width, wnd, bShow)
						end
					end
					if bShow then
						for i=1,context:GetMaxTilesInSlot(slot_name) do
							if target.tiles[i][1]:GetVisible() then
								if valid_idx[i] then
									target:SpawnRolloverUI(width,height, i,1)	
								else
									local ctrl = target.tiles[i][1]
									local ctrl_eq = ctrl.idEqSlotImage
									ctrl_eq:SetImage("UI/Inventory/cross")
									ctrl_eq:SetImageFit("none")
								end
							end
						end	
						for pos, wnd in pairs(target.rollover_windows or empty_table) do
							wnd:OnSetRollover(bShow)
							HighlihgtRollover(width, wnd, bShow)
						end
					else
						for pos, wnd in pairs(target.rollover_windows or empty_table) do
							local l,t,w = point_unpack(pos)
							target.tiles[l][t]:SetVisible(true)						
							wnd:delete()
						end
						target.rollover_windows = {}
						for i=1,context:GetMaxTilesInSlot(slot_name) do
							if not valid_idx[i] then
								local ctrl = target.tiles[i][1]
								local ctrl_eq = ctrl.idEqSlotImage
								ctrl_eq:SetImage(equip_slot_images[slot_name])								
								ctrl_eq:SetImageFit("width")	
							end
						end	
					end
				else										
					for wnd, witem in pairs(target.item_windows or empty_table) do
						if valid_idx[wnd.GridX] and witem ~= item then
							wnd:OnSetRollover(bShow)
							HighlihgtRollover(width,wnd, bShow)
						end
					end
				end
			end	
		end	
	end			
end

---
--- Highlights ammo items in the inventory UI that are compatible with the given weapon.
---
--- @param weapon Firearm|HeavyWeapon The weapon to find compatible ammo for.
--- @param bShow boolean Whether to show or hide the highlight.
---
function HighlightAmmoForWeapons(weapon, bShow)
	local dlg = GetMercInventoryDlg()
	if not dlg or not weapon then
		return 
	end
	if dlg.compare_mode then
		bShow = false
	end	

	local is_weapon = IsKindOf(weapon, "Firearm")
	local heavy_weapon = IsKindOf(weapon, "HeavyWeapon")
	if not (is_weapon or heavy_weapon) then
		return
	end
	local ammo_class = heavy_weapon and "Ordnance" or "Ammo"
	
	--Highlight ammo
	local all_slots = dlg:GetSlotsArray()
	for slot_wnd in pairs(all_slots) do
		local slot_name = slot_wnd.slot_name
		local target = slot_wnd:GetContext()
		local found =  false
		for wnd, item in pairs(slot_wnd.item_windows or empty_table) do
			if IsKindOf(item,ammo_class) and weapon.Caliber == item.Caliber then
				wnd:OnSetRollover(bShow)
				HighlihgtRollover(item:GetUIWidth(), wnd, bShow)
				found =  true
			end
		end
	end	
end

---
--- Highlights meds in the inventory UI that are compatible with the given medicine.
---
--- @param medicine Medicine The medicine to find compatible meds for.
--- @param bShow boolean Whether to show or hide the highlight.
---
function HighlightMedsForMedicine(medicine, bShow)
	local dlg = GetMercInventoryDlg()
	if not dlg or not medicine then
		return 
	end
	if dlg.compare_mode then
		bShow = false
	end	

	if not IsKindOf(medicine, "Medicine") then return end
	
	--Highlight meds
	local all_slots = dlg:GetSlotsArray()
	for slot_wnd in pairs(all_slots) do
		local slot_name = slot_wnd.slot_name
		local target = slot_wnd:GetContext()
		local found =  false
		for wnd, item in pairs(slot_wnd.item_windows or empty_table) do
			if IsKindOf(item,"Meds")then
				wnd:OnSetRollover(bShow)
				HighlihgtRollover(item:GetUIWidth(), wnd, bShow)
				found =  true
			end
		end
	end	
end

---
--- Highlights the stats or icons for the given item on the party member portraits in the inventory UI.
---
--- @param item Item The item to highlight.
--- @param bShow boolean Whether to show or hide the highlight.
---
function HighlightItemStats(item, bShow)
	local dlg = GetMercInventoryDlg()
	if not dlg or not item then
		return 
	end
	if dlg.compare_mode then
		bShow = false
	end	

	
	local isWeapon = item:IsWeapon() 
	local has_stat = not not item.UnitStat
	
	-- Highlight portraits
	local left = dlg:ResolveId("idPartyContainer")						
	local squad_list = left.idParty and left.idParty.idContainer or empty_table
	for _, button in ipairs(squad_list) do	
		local member = button:GetContext()
		if member then
			if isWeapon then
				button:SetHighlightedStatOrIcon(bShow and item.base_skill)			
			elseif has_stat then
				button:SetHighlightedStatOrIcon(bShow and item.UnitStat)
			end
		end	
	end
end

---
--- Highlights the weapons that can use the given ammo or ordnance item in the inventory UI.
---
--- @param ammo Item The ammo or ordnance item to highlight the compatible weapons for.
--- @param bShow boolean Whether to show or hide the highlight.
---
function HighlightWeaponsForAmmo(ammo, bShow)
	local dlg = GetMercInventoryDlg()
	if not dlg or not ammo then
		return 
	end
	if dlg.compare_mode then
		bShow = false
	end	
	-- squad bag	
	local h_members = {}	
	local is_bag_item = ammo:IsKindOf("SquadBagItem")
	if is_bag_item then
		local bag = gv_SquadBag
		h_members[bag] = true
	end
	local is_ammo = IsKindOf(ammo, "Ammo")
	local is_ordnance = IsKindOf(ammo,"Ordnance")
	if not (is_ammo or is_ordnance) and not is_bag_item then
		return
	end
	
	local weapon_class = is_ammo and "Firearm" or "HeavyWeapon"
	-- Highlight portraits
	local left = dlg:ResolveId("idPartyContainer")						
	local squad_list = left.idParty and left.idParty.idContainer or empty_table
	for _, button in ipairs(squad_list) do	
		local member = button:GetContext()
		if (is_ammo or is_ordnance) and member then
			for _, slot_data in ipairs(member.inventory_slots) do
				local slot_name = slot_data.slot_name
				if IsEquipSlot(slot_name) then
					local result = member:ForEachItemInSlot(slot_name, weapon_class, function(witem, slot, left, top, caliber)
						if witem.Caliber == caliber then
							return "break"
						end
					end, ammo.Caliber)
					if result == "break" then
						-- head
						button:SetHighlightedStatOrIcon(bShow and "UI/Icons/Rollover/ammo")
						-- backpack
						h_members[member] = true
					end
				end
			end
		end

		--Highlight weapons
		local all_slots = dlg:GetSlotsArray()
		for slot_wnd in pairs(all_slots) do
			local slot_name = slot_wnd.slot_name
			local target = slot_wnd:GetContext()
			local found =  false
			for wnd, witem in pairs(slot_wnd.item_windows or empty_table) do
				if (is_ammo or is_ordnance) and IsKindOf(witem,weapon_class) and ammo.Caliber == witem.Caliber then
					wnd:OnSetRollover(bShow)
					HighlihgtRollover(witem:GetUIWidth() ,wnd, bShow)
					found =  true
				end
			end
			if not IsKindOf(target, "SquadBag") and slot_wnd and not IsEquipSlot(slot_name) and (IsKindOf(target, "Unit") and not target:IsDead()) and (found or not bShow or h_members[target]) then
				local name = slot_wnd.parent.idName
				name:SetHightlighted(bShow)
			end
		end	

		if not bShow then
			button:SetHighlighted(bShow)
		end	
	end
end

---
--- Highlights the portraits and inventory slots of wounded characters in the Mercenary Inventory dialog.
---
--- @param meds Meds The meds item to highlight.
--- @param bShow boolean Whether to show or hide the highlighting.
---
function HighlightMedicinesForMeds(meds, bShow)
	local dlg = GetMercInventoryDlg()
	if not dlg or not meds or not IsKindOf(meds, "Meds") then
		return 
	end
	if dlg.compare_mode then
		bShow = false
	end	
	-- squad bag	
	local h_members = {}	
	local bag = gv_SquadBag
	h_members[bag] = true
	-- Highlight portraits
	local left = dlg:ResolveId("idPartyContainer")						
	local squad_list = left.idParty and left.idParty.idContainer or empty_table
	for _, button in ipairs(squad_list) do	
		local member = button:GetContext()
		if member then
			local result = member:ForEachItemInSlot(GetContainerInventorySlotName(member), "Medicine", function(witem)
				if witem.Condition < witem:GetMaxCondition() then
					return "break"
				end	
			end)
			if result == "break" then
				-- head
				button:SetHighlighted(bShow)
				-- backpack
				h_members[member] = true
			end
		end

		--Highlight medicines
		local all_slots = dlg:GetSlotsArray()
		for slot_wnd in pairs(all_slots) do
			local slot_name = slot_wnd.slot_name
			local target = slot_wnd:GetContext()
			local found =  false
			for wnd, witem in pairs(slot_wnd.item_windows or empty_table) do
				if IsKindOf(witem,"Medicine") then
					wnd:OnSetRollover(bShow)
					HighlihgtRollover(witem:GetUIWidth(),wnd, bShow)
					found =  true
				end
			end
			if slot_wnd and (IsKindOf(target, "Unit") and not target:IsDead()) and (found or not bShow or h_members[target]) then
				local name = slot_wnd.parent.idName
				if name then
					name:SetHightlighted(bShow)
				end
			end
		end	

		if not bShow then
			button:SetHighlighted(bShow)
		end	
	end
end

---
--- Highlights the portraits of wounded characters in the party container of the Mercenary Inventory dialog.
---
--- @param item table The item that triggered the highlighting (must be of type "MetaviraShot")
--- @param show boolean Whether to show or hide the highlighting
---
function HighlightWoundedCharacterPortraits(item, show)
	local dlg = GetMercInventoryDlg()
	if not dlg or not item then
		return 
	end
	
	if not item.class or item.class ~= "MetaviraShot" then
		return
	end
	if dlg.compare_mode then
		show = false
	end	

	local left = dlg:ResolveId("idPartyContainer")						
	local squad_list = left.idParty and left.idParty.idContainer or empty_table
	for _, portrait in ipairs(squad_list) do
		local member = portrait:GetContext()
		if member:HasStatusEffect("Wounded") then
			portrait:SetHighlightedStatOrIcon(show)
			portrait.idStatusHighlighter:SetVisible(show)
		end
	end
end

---
--- Returns the width and height of the currently dragged inventory item.
---
--- @return number width The width of the dragged item
--- @return number height The height of the dragged item
---
function InventoryGetDragWidthHeight()
	local width = next(InventoryDragItems) and 1 or InventoryDragItem and InventoryDragItem:GetUIWidth()
	local height = next(InventoryDragItems) and 1 or InventoryDragItem and InventoryDragItem:GetUIHeight()
	return width, height
end

---
--- Highlights the drop slot for the currently dragged inventory item.
---
--- @param wnd table The window that triggered the highlighting
--- @param bShow boolean Whether to show or hide the highlighting
--- @param pt table The mouse position
--- @param drag_win table The window that is being dragged
---
function HighlightDropSlot(wnd, bShow, pt, drag_win)
	local width,height = InventoryGetDragWidthHeight()
	
	local dlg = GetMercInventoryDlg()
	local slot_ctrl = ((InventoryStartDragSlotName == "Inventory") or (InventoryStartDragSlotName == "InventoryDead")) and dlg:GetSlotByName(InventoryStartDragSlotName, InventoryStartDragContext) or dlg:GetSlotByName(InventoryStartDragSlotName)
	local drag_win  = drag_win or (slot_ctrl and slot_ctrl.drag_win)

	if bShow then
		local slot = IsKindOf(wnd, "XInventorySlot") and wnd or wnd:GetInventorySlotCtrl()
		local win, left, top = slot:FindTile(pt)
		local blong = width>1
		local swidth, sheight, last_row_width = slot.context:GetSlotDataDim(slot.slot_name)
		if drag_win then
			if left and blong and swidth==2 and IsKindOf(wnd, "EquipInventorySlot") then
				left=1
			elseif left and blong then
				local l,t, dx = point_unpack(InventoryDragItemPos) 
				left = left - dx
				if left<=0 then left = false end
			end
		end
		if left and ((left+width-1>swidth or top+height-1>sheight) or (top+height-1==sheight and left+width-1>last_row_width)) then
			left = false
		end
		if left then
			if dropWnd and dropWnd.window_state~="destroying" then
				local thesame = 
						 dropWnd:GetParent() == slot
					and dropWnd:GetGridX() == left
					and dropWnd:GetGridY() == top
					and dropWnd:GetGridWidth() == width 
					and dropWnd:GetGridHeight() == height
				if thesame then	
					return
				end
				dropWnd:delete()
				dropWnd  = false
			end	
			dropWnd  = slot:SpawnDropUI(width, height, left, top)
		end
		
		local canDrop = slot and slot:CanDropAt(pt)
		if dropWnd then
			local wnd = dropWnd.idItemPad
			wnd:SetImageColor(canDrop and white or GetColorWithAlpha(GameColors.I, 150))
		end
	else
		if dropWnd and dropWnd.window_state~="destroying" then
			dropWnd:delete()
		end	
		dropWnd  = false
	end
end

---
--- Shows or hides the inventory mouse text and updates its position and content.
---
--- @param bShow boolean Whether to show or hide the mouse text
--- @param text string The text to display in the mouse text
---
function InventoryShowMouseText(bShow, text)
	local dlg = GetDialog("FullscreenGameDialogs")
	local ctrl = dlg.desktop.idInventoryMouseText
	if ctrl then	
		ctrl:SetVisible(bShow)
	end	
	if bShow then
		ctrl:AddDynamicPosModifier{
			id = "DragText",
			target = "mouse",			
		}
		if text then
			ctrl:SetText(text)
		end
	else	
		ctrl:RemoveModifier("DragText")
	end	
end

---
--- Formats the AP mouse text for a given unit and AP cost.
---
--- @param unit_ap Unit The unit whose AP information is being displayed.
--- @param ap_cost number The AP cost of the action being performed.
--- @param mouse_text string The existing mouse text to be formatted.
--- @return string The formatted mouse text.
---
function InventoryFormatAPMouseText(unit_ap, ap_cost, mouse_text)
	mouse_text = mouse_text .."\n".. unit_ap.Nick.." "
	if not unit_ap:UIHasAP(ap_cost) then
		mouse_text = mouse_text .. T{262015822006, "<style InventoryHintTextRed><apn(ap_cost)>/<apn(max_ap)>AP</style>",ap_cost = ap_cost,max_ap = unit_ap:GetUIActionPoints()}				
		mouse_text = mouse_text .. "\n"..T(582323369969, "<style InventoryHintTextRed>Not enough AP</style>")
	else
		mouse_text = mouse_text ..T{939649362145, "<style InventoryMouseText><apn(ap_cost)>/<apn(max_ap)>AP</style>",ap_cost = ap_cost,max_ap = unit_ap:GetUIActionPoints()}				

	end	
	return mouse_text
end	

---
--- Shows or hides the AP text in the inventory UI and sets its text.
---
--- @param bShow boolean Whether to show or hide the AP text
--- @param text string The text to display in the AP text
---
function InventoryEquipAPText(bShow, text)
	local dlg = GetMercInventoryDlg()
	local ctrl = dlg.idUnitInfo.idEquipHint
	ctrl:SetVisible(bShow)
	ctrl:SetText(bShow and text or "")
end

------------------------------Browse/Backpack Inventoryslot-----------
DefineClass.BrowseInventorySlot = {
	__parents = {"XInventorySlot"},
}

---
--- Handles the double click event on a browse inventory slot.
---
--- If the inventory is disabled, the event is ignored.
--- If the container is not on the same sector, the event is ignored.
--- If the left mouse button is clicked and the player is not dragging an item, the function attempts to move the item to the player's bag. If that fails, it attempts to equip the item.
--- If the player is dragging an item, the function cancels the dragging and attempts to move the dragged item to the player's bag.
---
--- @param pt table The position of the mouse click.
--- @param button string The mouse button that was clicked ("L" for left, "R" for right).
--- @param source string The source of the mouse input ("gamepad" if from a gamepad).
--- @return string "break" to indicate the event has been handled.
---
function BrowseInventorySlot:OnMouseButtonDoubleClick(pt, button, source)
	local dlgContext = GetDialogContext(self)
	if dlgContext then
		if InventoryDisabled(dlgContext) then	return "break" end
	end
	
	if not InventoryIsContainerOnSameSector({context = self.context}) then
		return "break"
	end		
	
	if button == "L" then
		if not IsMouseViaGamepadActive() or source == "gamepad" then
			if WasDraggingLastLMBClick then return end
			local wnd_found, item
			local is_dragging = not not InventoryDragItem
			if is_dragging then
				item = InventoryDragItem
				self:CancelDragging()
			else
				wnd_found, item = self:FindItemWnd(pt)
			end
			
			if self:TryMoveToBag(item) then
				return "break"
			elseif item then
				self:EquipItem(item)
			end
		end
	end
	return "break"
end

---
--- Attempts to move the given item to the player's squad bag inventory.
---
--- If the item is not a SquadBagItem, or the context is not an ItemContainer, SectorStash, or a dead Unit, the function returns false.
--- Otherwise, it moves the item from the source container and slot to the player's squad bag inventory.
---
--- @param item SquadBagItem The item to be moved to the player's bag.
--- @return boolean True if the item was successfully moved, false otherwise.
---
function BrowseInventorySlot:TryMoveToBag(item)
	if not IsKindOf(item, "SquadBagItem") --this makes double clicking non ammo from dropped items try to equip them, idk if thats cool
		or not(IsKindOfClasses(self.context, "ItemContainer", "SectorStash") or IsKindOf(self.context, "Unit") and self.context:IsDead()) then --basically for loot containers only
		return false
	end
	local unit = GetInventoryUnit()	
	local src_container = self.context
	local args = {item = item, src_container = src_container, src_slot = GetContainerInventorySlotName(src_container), 
						dest_container = GetSquadBagInventory(unit.Squad), dest_slot = "Inventory"}
	MoveItem(args)
	return true
end

---
--- Attempts to find the previous equipped item for the given item.
---
--- If the given item is a weapon or a quick slot item, this function will try to find a free slot to equip the item.
--- If the given item is a weapon, it will try to find the previous item in the "Handheld A" or "Handheld B" slots.
--- If the given item is a quick slot item, it will try to find the previous item in the "Handheld A" or "Handheld B" slots.
--- If the given item is an armor, it will return the previous item in the item's slot.
---
--- @param item SquadBagItem The item to find the previous equipped item for.
--- @param B_slot_first boolean If true, it will try the "Handheld B" slot first, otherwise it will try the "Handheld A" slot first.
--- @return SquadBagItem, string, point The previous equipped item, the slot name, and the slot position.
---
function BrowseInventorySlot:GetPrevEquipItem(item, B_slot_first)	
	local unit = GetInventoryUnit()
		
	if not unit then return end
	local slot 	
	local slot_pos = point_pack(1,1)
	local prev_item
	
	local slots = B_slot_first and {"Handheld B", "Handheld A"} or {"Handheld A", "Handheld B"}
	local is_weapon = item and item:IsWeapon()
	local is_quick_slot_item = IsKindOf(item, "QuickSlotItem")
	
	if is_quick_slot_item or is_weapon then
		local free =  false
		for _, slot_name in ipairs(slots) do
			slot_pos = unit:CanAddItem(slot_name, item)
			local slot_ctrl = GetInventorySlotCtrl(true, unit, slot_name)
			if slot_pos and slot_ctrl and slot_ctrl:CanEquip(item, slot_pos) then
				slot = slot_name
				free = true
				break
			end	
		end	
		if free then
			return prev_item, slot, slot_pos
		end
	end		
	-- weapon
	if is_weapon then
		local free =  false
		for _, slot_name in ipairs(slots) do
			local aitem = unit:GetItemInSlot(slot_name, false, 1, 1)
			local bitem = unit:GetItemInSlot(slot_name, false, 2, 1)
			local size = item:GetUIWidth()
			local prev,s_name, pos
			if size == 1 then
				return aitem, slot_name, point_pack(1,1)
			else
				if aitem and bitem and aitem~=bitem then
					prev,s_name, pos = aitem, slot_name, point_pack(1, 1)
				else
					if aitem then -- if something breaks because of this additional logic might be needed for swaping items with different UIWidth
						prev,s_name, pos =  aitem, slot_name, point_pack(1, 1)
					else
						prev,s_name, pos =  bitem, slot_name, point_pack(2, 1)
					end
				end		
			end
			local slot_ctrl = GetInventorySlotCtrl(true, unit, slot_name)
			if pos and slot_ctrl and slot_ctrl:CanEquip(item, pos) then
				return prev,s_name, pos
			end
		end	
		--QuickSlotItem
	elseif is_quick_slot_item then
		local free =  false
		for _, slot_name in ipairs(slots) do
			local aitem,l,t = unit:GetItemInSlot(slot_name,"QuickSlotItem")
			if aitem then
				prev_item = aitem
				slot = slot_name
				slot_pos = point_pack(l,t)
				free = true
				break
			end
		end	
		if free then
			return prev_item, slot, slot_pos
		end	
		-- Armor
	elseif IsKindOf(item, "Armor") then
		prev_item = unit:GetItemInSlot(item.Slot)
		slot = item.Slot
	end
	return prev_item, slot, slot_pos
end

---
--- Equips an item in the inventory.
---
--- @param item table The item to be equipped.
---
function BrowseInventorySlot:EquipItem(item)
	if not item then 
		return 
	end
	local context  = self:GetContext()
	local unit = GetInventoryUnit()
	self:ClosePopup()
	
	if not unit then return end
	if not InventoryIsContainerOnSameSector(context) then
		return
	end
	if not gv_SatelliteView and not InventoryIsValidGiveDistance(context, unit)then
		return
	end	
	
	local slot 	
	local slot_pos = point_pack(1,1)
	local prev_item, slot, slot_pos = self:GetPrevEquipItem(item)
	if not slot then return end
	local xpos_big_item = item:GetUIWidth() > 1
	local slot_ctrl = GetInventorySlotCtrl(true, unit, slot)
	if slot_ctrl and slot_ctrl:CanEquip(item, slot_pos) then
		local x, y = point_unpack(slot_pos)
		if xpos_big_item then
			--move item won't allow this move
			--basically we got x 2 because there is an item there and it's trying to swap
			--but move item thinks item should start at x2 and doesn't think it fits there, because there is no x3
			x = 1
		end
		local result = MoveItem({item = item, src_container = context, src_slot = self.slot_name, dest_container = unit, dest_slot = slot, dest_x = x, dest_y = y})
		if result then 
			prev_item, slot, slot_pos = self:GetPrevEquipItem(item,true)	
			local slot_ctrl = GetInventorySlotCtrl(true, unit, slot)
			if slot_ctrl and slot_ctrl:CanEquip(item, slot_pos) then
				local x, y = point_unpack(slot_pos)
				if xpos_big_item then
					--move item won't allow this move
					--basically we got x 2 because there is an item there and it's trying to swap
					--but move item thinks item should start at x2 and doesn't think it fits there, because there is no x3
					x = 1
				end
				result = MoveItem({item = item, src_container = context, src_slot = self.slot_name, dest_container = unit, dest_slot = slot, dest_x = x, dest_y = y})
			end
		end	
		if result then 			
			PlayFXOnMoveItemResult(result, item, slot)
		else
			PlayFX("WeaponEquip", "start", item.class, item.object_class)
		end
		local src_x, src_y = context:GetItemPosInSlot(self.slot_name, item)
		self:Gossip(item, context, slot_ctrl, src_x, src_y, x, y)
	end
end
------------------------------Equip Inventoryslot-----------
DefineClass.EquipInventorySlot = {
	__parents = {"XInventorySlot"},
}

---
--- Creates a new `XInventoryTile` instance with the specified `slot_image` for the given `slot_name`.
---
--- @param slot_name string The name of the inventory slot.
--- @return XInventoryTile A new `XInventoryTile` instance.
---
function EquipInventorySlot:SpawnTile(slot_name)
	return XInventoryTile:new({slot_image = equip_slot_images[slot_name]}, self)
end

--pt is point in screen space, slot_pos is point in tile space, one of the two is required
--pt_or_slot_pos - if point assumes it's pt, else does point_unpack on it
---
--- Checks if the given item can be equipped in the current inventory slot.
---
--- @param item table The item to be equipped.
--- @param pt_or_slot_pos table The position of the slot, either as a point or a slot position.
--- @return boolean True if the item can be equipped, false otherwise.
---
function EquipInventorySlot:CanEquip(item, pt_or_slot_pos)
	--You can have two one-handed ranged weapons on the same row, but you can't mix 'em with melee weapons
	if IsPoint(pt_or_slot_pos) then
		local _, tl, tt = self:FindTile(pt_or_slot_pos)
		pt_or_slot_pos = point_pack(tl,tt)
	end

	return InventoryCanEquip(item, self:GetContext(), self.slot_name, pt_or_slot_pos)
end

---
--- Checks if the given item can be equipped in the specified inventory slot.
---
--- @param item table The item to be equipped.
--- @param context table The inventory context.
--- @param slot_name string The name of the inventory slot.
--- @param slot_pos table The position of the slot.
--- @return boolean True if the item can be equipped, false otherwise.
---
function InventoryCanEquip(item, context, slot_name, slot_pos)
	--You can have two one-handed ranged weapons on the same row, but you can't mix 'em with melee weapons
	local drag_item = item
	local drag_size = drag_item:GetUIWidth()
	if (slot_name=="Handheld A" or slot_name=="Handheld B") and drag_size==1 then
		local weapon1 = context:GetItemInSlot(slot_name, false, 1,1)
		local weapon2 = context:GetItemInSlot(slot_name, false, 2,1)
		local res
		if not weapon1 and not weapon2 then 
			return true
		elseif weapon1==weapon2 and weapon1:GetUIWidth() > 1 then 
			return true
		elseif (not weapon1 or not weapon1:IsWeapon()) and (not weapon2 or not weapon2:IsWeapon()) then
			return true
		elseif weapon1 == drag_item and not weapon2 or
				weapon2 == drag_item and not weapon1 then
			--move 1 tile width item from one to the other slot
			return true
		end
				
		local tl, tt = point_unpack(slot_pos)
		if tl==1 then
			res = not weapon2 or not weapon2:IsWeapon() or not drag_item:IsWeapon() or IsKindOf(weapon2, "Firearm") and IsKindOf(drag_item, "Firearm")
			return res
		end	
		if tl==2 then
			res = not weapon1 or not weapon1:IsWeapon() or not drag_item:IsWeapon() or IsKindOf(weapon1, "Firearm") and IsKindOf(drag_item, "Firearm")
			return res
		end
		
		return true
	end
	
	return true
end

---
--- Unequips the specified item from the inventory slot.
---
--- @param item table The item to be unequipped.
---
function EquipInventorySlot:UnEquipItem(item)
	if not item then return end
	
	local context  = self:GetContext()
	local unit = GetInventoryUnit()
	self:ClosePopup()
	
	if not unit then return end
	local src_x, src_y = context:GetItemPosInSlot(self.slot_name, item)
	local pos, reason =  unit:CanAddItem("Inventory", item)
	if pos then
		local x,y = point_unpack(pos)
		local result = MoveItem({item = item, src_container = context, src_slot = self.slot_name, dest_container = unit, dest_slot = "Inventory", dest_x = x, dest_y = y})
		if result then 
			PlayFXOnMoveItemResult(result, item, "Inventory")
		else
			PlayFX("WeaponUnequip", "start", item.class, item.object_class)
		end
	else
		self:DropItem(item)
	end
end

---
--- Checks if the current inventory slot is a valid drop target for the item being dragged.
---
--- @param drag_win table The window of the item being dragged.
--- @param pt table The position of the drag item.
--- @param drag_source_win table The window of the source of the drag item.
--- @return boolean Whether the current inventory slot is a valid drop target.
---
function EquipInventorySlot:_IsDropTarget(drag_win, pt, drag_source_win)
	local res = XInventorySlot._IsDropTarget(self, drag_win, pt, drag_source_win)
	if not res then
		HighlightDropSlot(false, false, false, drag_win)
		return false
	end	

	res = self:CanEquip(InventoryDragItem, pt)
	HighlightDropSlot(self, res, pt, drag_win)
	local ctrl, itm = self:FindItemWnd(pt) 
	if not ctrl then
		ctrl = self:FindTile(pt)
	end	
	if ctrl and itm~=InventoryDragItem then
		HighlightAPCost(InventoryDragItem, true, ctrl)
	end
	return res
end
--[[
function EquipInventorySlot:HasItemUnderDragWin(drag_win, pt, drag_size)
	local blong = drag_size>1
	local context = self.context
	
	local _, left, top = self:FindTile(pt)
	local pt_first = true
	
	if left and blong then
		local width, height, last_row_width = context:GetSlotDataDim(self.slot_name)
		if width==2 then
			left = 1
		elseif ((drag_win.box:maxx()- InventoryDragItemPt:x())<=drag_win.box:sizex()/2) then
			left = left - 1
			pt_first = false
			if left<=0 then left = false end
		end
	end
	if not left then
		return false
	end
	local  first = context:GetItemInSlot(self.slot_name, false, left, top)
	if not blong then
		return first, left, top, pt_first
	else
		if IsEquipSlot(self.slot_name) then
			return first, left, top, pt_first
		end
		local second = context:GetItemInSlot(self.slot_name, false, left+1, top)
		if first and first==second or not second then
			return first, left, top, pt_first
		end	
		if not first and second then
			return second, left, top, pt_first
		end	
			
		return -1, left, top, pt_first
	end

end
--]]
------------------------------
--[[function XInventorySlot:GetCostAP(dest, dest_slot_name, dest_pos, is_reload, drag_item, src_context)
	if not InventoryIsCombatMode() or (not dest and not dest_pos) then
		return 0
	end
	if dest=="drop" then
		return 0
	end	
	--arg unravel
	local src = src_context or self.context
	local item 
	local l,t 
	dest_pos = dest_pos or InventoryDragItemPos
	if IsKindOf(dest_pos, "InventoryItem") then
		l,t = dest:GetItemPos(dest_pos)		
		item =	 dest_pos
	else
		l,t = point_unpack(dest_pos)
		item = dest:GetItemAtPos(dest_slot_name,l,t)
		if not item then
			item = dest:GetItemAtPos(dest_slot_name, l-1, t)
			if item and item:GetUIWidth()>1 then
				l = l-1
			end
		end		
	end
	if not drag_item and item then
		drag_item = item
		item = false
	end
	return GetAPCostAndUnit(drag_item, src, self.slot_name, dest, dest_slot_name, item, is_reload)
end
--]]
---
--- Performs a network action related to a squad bag.
---
--- @param unit UnitData The unit associated with the inventory. If not provided, the current inventory unit is used.
--- @param srcInventory table The source inventory context.
--- @param src_slot_name string The name of the source slot.
--- @param item InventoryItem|table The item or list of item IDs to be acted upon.
--- @param squadBag table The squad bag associated with the action.
--- @param actionName string The name of the action to perform.
--- @param ap number The action points required for the action.
---
function NetSquadBagAction(unit, srcInventory, src_slot_name, item, squadBag, actionName, ap)
	local unit = unit or GetInventoryUnit()

	local ap = ap or 0
	
	local net_src = GetContainerNetId(srcInventory)
	local squadId = squadBag and squadBag.squad_id or false
	
	local pack = {}	
	
	local ids = {}
	if IsKindOf(item, "InventoryItem") then
		ids[1] = item.id
	else	
		ids = item
	end
	table.insert(pack, pack_params(net_src, src_slot_name, ids, squadId, actionName))

	if IsKindOf(unit, "UnitData") then
		NetSyncEvent("SquadBagAction", unit.session_id, pack)
		return
	end

	NetStartCombatAction("SquadBagAction", unit, ap, pack)
end

---
--- Performs a network action to combine two items.
---
--- @param recipe_id number The ID of the recipe used to combine the items.
--- @param outcome InventoryItem The resulting item from the combination.
--- @param outcome_hp number The hit points of the resulting item.
--- @param skill_type string The type of skill used to combine the items.
--- @param unit_operator_id number The ID of the unit performing the combination.
--- @param item1_context table The context of the first item being combined.
--- @param item1_pos number The position of the first item in its context.
--- @param item2_context table The context of the second item being combined.
--- @param item2_pos number The position of the second item in its context.
--- @param combine_count number The number of times the combination is performed.
---
--- @return nil
function NetCombineItems(recipe_id, outcome, outcome_hp, skill_type, unit_operator_id, item1_context, item1_pos, item2_context, item2_pos, combine_count)
	local container_unit = GetInventoryUnit()
	if not container_unit then
		return -- UnitData from satelitte view
	end
	local net_context1 = GetContainerNetId(item1_context)
	local net_context2 = GetContainerNetId(item2_context)
	
	local params = pack_params(recipe_id, outcome,outcome_hp, skill_type, unit_operator_id, net_context1, item1_pos, net_context2, item2_pos, false, combine_count)
	if IsKindOf(container_unit, "UnitData") then
		NetSyncEvent("CombineItems", params)
		return
	end

	NetStartCombatAction("CombineItems",container_unit, 0, params)
end

GameVar("gv_SectorInventory", false)

OnMsg.OpenSatelliteView = function()
	if gv_CurrentSectorId and gv_SectorInventory then
		gv_SectorInventory:Clear()
		gv_SectorInventory:SetSectorId(gv_CurrentSectorId)
	end
end

OnMsg.LoadSessionData =function()
	if gv_SectorInventory then
		gv_SectorInventory:Clear()
	end	
end

---
--- Opens the sector inventory for the given unit.
---
--- @param unit_id number The ID of the unit to open the sector inventory for.
---
function NetEvents.OpenSectorInventory(unit_id)
	local unit = gv_UnitData[unit_id]
	if not unit then return end
	OpenInventory(unit)
end

---
--- Gets the sector inventory for the given sector ID.
---
--- @param sector_id number The ID of the sector to get the inventory for.
--- @param filter table An optional table of filters to apply to the sector inventory.
--- @return SectorStash The sector inventory object.
---
function GetSectorInventory(sector_id, filter)
	if not gv_SatelliteView or not gv_Sectors[sector_id] then return end

	if not gv_SectorInventory then
		gv_SectorInventory = PlaceObject("SectorStash")
	end
	gv_SectorInventory:SetSectorId(sector_id, filter)
	return gv_SectorInventory
end

---
--- Notifies that the sector stash has been opened by the given player.
---
--- @param player table The player who opened the sector stash.
---
function NetSyncEvents.SectorStashOpenedBy(player)
	SectorStashOpen = player
	ObjModified(GetSatelliteDialog())
end

local function GetLootTableItems(loot_tbl, items)
	for _, entry in ipairs(loot_tbl) do
		local item = rawget(entry,"item")
		if item then
			items[#items +1] = item
		else
			GetLootTableItems(LootDefs[entry.loot_def], items)
		end
	end
end

---
--- Plays a voice response when a valuable item is found in a container.
---
--- @param unit table The unit that found the valuable item.
--- @param container table The container that the valuable item was found in.
---
function PlayResponseOpenContainer(unit,container)
	if container then
		local play_unit = false and GetRandomMapMerc(unit.Squad,AsyncRand()) or unit --stop using random merc for these vr's
		container:ForEachItem(function(item, slot, l,t) 
			if item:IsValuable() then
				PlayVoiceResponse(play_unit,"ValuableItemFound")
				return "break"
			end
		end)	
	end	
end

---
--- Prepares the inventory context for the given object and container.
---
--- @param obj table The object to prepare the inventory context for.
--- @param container table The container to prepare the inventory context for.
--- @return table The prepared inventory context.
---
function PrepareInventoryContext(obj, container)
	local context
	if obj then	
		local coop = IsCoOpGame()
		if coop  then
			local class_tbl = IsKindOf(obj, "Unit") and g_Units or gv_UnitData
			if not obj:IsLocalPlayerControlled() then
				local squad = gv_Squads[obj.Squad]
				local controlled = false
				for _,id in ipairs(squad.units) do
					local u = class_tbl[id]
					if u:IsLocalPlayerControlled() then
						obj = u
						break
					end
				end
			end
		end
		local unit
		if IsKindOfClasses(obj, "Unit", "UnitData") then
			unit = obj
		end		
		if g_Units[unit.session_id] and InventoryIsCombatMode(g_Units[unit.session_id]) then 
			unit = g_Units[unit.session_id]
		end		
		
		context =  context or {}
		context.unit = unit or obj
	end
	if container then
		context = context or {}
		context.container = container
	end
	return context 
end

---
--- Opens the inventory UI for the given object and container.
---
--- @param obj table The object to open the inventory for.
--- @param container table The container to open the inventory for.
--- @param autoResolve boolean If true, the inventory will automatically resolve any conflicts.
--- @return table The opened inventory dialog.
---
function OpenInventory(obj, container, autoResolve)
	local dlg = GetInGameInterfaceModeDlg()
	if IsKindOf(dlg, "IModeCombatAttackBase") then
		SetInGameInterfaceMode(g_Combat and "IModeCombatMovement" or "IModeExploration", {suppress_camera_init = true})
	end

	if gv_SatelliteView and obj then
		local squad = obj.Squad and gv_Squads[obj.Squad]
		if squad and not IsSquadTravelling(squad) then
			container = container or GetSectorInventory(squad.CurrentSector)
		end
		NetSyncEvent("SectorStashOpenedBy", netUniqueId)
	end
	
	local context = PrepareInventoryContext(obj, container)

	if context then
		if autoResolve then
			context.autoResolve = true
		end
		local dlg = GetDialog("FullscreenGameDialogs")
		if dlg and dlg.Mode == "inventory" then
			dlg:SetMode("empty")
			dlg:Close()
		end
		dlg = OpenDialog("FullscreenGameDialogs", GetInGameInterface(), context)
		PlayFX("InventoryPanelOpen")
		NetGossip("InventoryPanel", "Open", GetCurrentPlaytime(), Game and Game.CampaignTime)
		if dlg and dlg.Mode ~= "inventory" then
			dlg:SetMode("inventory")
		end
		return dlg
	end
end

function OnMsg.CloseInventorySubDialog()
	PlayFX("InventoryClose")
	NetSyncEvent("SectorStashOpenedBy", false)
	NetGossip("InventoryPanel", "Close", GetCurrentPlaytime(), Game and Game.CampaignTime)
end

---
--- Checks if the inventory UI is currently opened.
---
--- @return boolean True if the inventory UI is opened, false otherwise.
---
function IsInventoryOpened()
	return not not GetDialog("FullscreenGameDialogs")
end

---
--- Opens the perks dialog for the specified unit.
---
--- @param unit table The unit to display the perks dialog for.
--- @param item_ctrl table The item control that triggered the dialog opening.
---
function OpenPerksDialog(unit, item_ctrl)
	local dlg = GetDialog("FullscreenGameDialogs")
	if dlg  then
		local context = dlg:GetContext()
		context.unit = unit
		if dlg.Mode=="perks"then
			if item_ctrl then
				item_ctrl:SelectUnit()
			end
		else
			dlg:SetContext(context)
			dlg:OnContextUpdate(context)
			dlg:SetMode("perks")
		end
	else
		local context = PrepareInventoryContext(unit)
		dlg = OpenDialog("FullscreenGameDialogs", GetInGameInterface(), context)
		dlg:SetMode("perks")
	end
end		

---
--- Gets the Mercenary Inventory dialog.
---
--- @return table|nil The Mercenary Inventory dialog, or nil if it is not open.
---
function GetMercInventoryDlg()
	local dlg = GetDialog("FullscreenGameDialogs")
	if dlg and dlg.Mode=="inventory" then
		return dlg.idModeDialog[2]
	end
end	

---
--- Gets the unit associated with the current Mercenary Inventory dialog.
---
--- @param dlg table The Mercenary Inventory dialog. If not provided, the current dialog will be used.
--- @return table|nil The unit associated with the dialog, or nil if no dialog is open or the dialog has no associated unit.
---
function GetInventoryUnit(dlg)
	local dlg = dlg or GetMercInventoryDlg()
	local context = dlg and dlg:GetContext()
	return context and context.unit
end

---
--- Checks if the current inventory unit is in combat.
---
--- @param unit table The unit to check. If not provided, the current inventory unit will be used.
--- @return boolean True if the unit is in combat, false otherwise.
---
function InventoryIsCombatMode(unit)
	local unit = unit or GetInventoryUnit()
	local squad_id = unit and unit.Squad
	return squad_id and SquadIsInCombat(squad_id)
end

---
--- Checks if the Mercenary Inventory dialog is in compare mode.
---
--- @param dlg table The Mercenary Inventory dialog. If not provided, the current dialog will be used.
--- @return boolean True if the dialog is in compare mode, false otherwise.
---
function InventoryIsCompareMode(dlg)
	local dlg = dlg or GetMercInventoryDlg()
	return dlg and dlg.compare_mode
end

---
--- Checks if the given control context is a valid target for the unit that is currently in the inventory dialog.
---
--- This function is used to determine if a sector stash can be interacted with when the unit is in transit.
---
--- @param ctrl_context table The control context to check.
--- @return boolean, string True if the target is valid, false and an error message if the target is invalid.
---
function InventoryIsValidTargetForUnitInTransit(ctrl_context)
	if gv_SatelliteView and IsKindOf(ctrl_context, "SectorStash") then	
		local unit = GetInventoryUnit()
		if unit and (unit.Operation == "Arriving" or unit.Squad and IsSquadTravelling(gv_Squads[unit.Squad])) then			
			return false,T(257112039195, "<style InventoryHintTextRed>In transit")
		end
	end
	return true
end	

---
--- Checks if the given control context is a valid target for the unit that is currently in the inventory dialog.
---
--- This function is used to determine if a sector stash can be interacted with when the unit is in transit.
---
--- @param ctrl_context table The control context to check.
--- @return boolean, string True if the target is valid, false and an error message if the target is invalid.
---
function InventoryIsValidTargetForUnit(ctrl_context)
	local unit = GetInventoryUnit()
	if gv_SatelliteView and IsKindOf(ctrl_context, "SectorStash") then	
		if not InventoryIsValidTargetForUnitInTransit(ctrl_context) then			
			return false,T(257112039195, "<style InventoryHintTextRed>In transit")
		end
		if unit and unit.Squad and gv_Squads[unit.Squad] and ctrl_context.sector_id ~= gv_Squads[unit.Squad].CurrentSector then
			return false,T(212348537316, "<style InventoryHintTextRed>Not on sector")
		end	
	end
	if IsKindOfClasses(ctrl_context, "Unit", "UnitData") and not ctrl_context:IsDead() then	
		local ctrl_context_unit = ctrl_context.session_id and g_Units[ctrl_context.session_id]
		if ctrl_context:HasStatusEffect("BandageInCombat") then
			return false, T(107419565286, "Character is busy bandaging")
		elseif ctrl_context:IsDowned() then
			return false, T(360582491602, "Character is Downed")
		elseif ctrl_context:HasStatusEffect("Unconscious") then
			return false, T(894812059755, "Character is Unconscious")
		elseif g_Overwatch[ctrl_context] or g_Pindown[ctrl_context] then
			return false, T(462153644901, "Character is busy")
		elseif ctrl_context_unit and g_Overwatch[ctrl_context_unit] or g_Pindown[ctrl_context_unit] then
			return false, T(462153644901, "Character is busy")
		elseif ctrl_context.retreat_to_sector then	
			return false, T(462153644901, "Character is busy")
		end
	end

	return true
end	

---
--- Checks if the distance between two objects is within the allowed range for inventory give/take actions.
---
--- @param context1 table The first object to check the distance for.
--- @param context2 table The second object to check the distance for.
--- @return boolean, string True if the distance is within the allowed range, false and an error message if the distance is too large.
---
function InventoryIsValidGiveDistance(context1, context2)
	if	context1 == context2 then
		return true
	end	
	local obj1 = (IsKindOf(context1, "UnitData") and InventoryIsCombatMode(context1)) and g_Units[context1.session_id] or context1
	local obj2 = (IsKindOf(context2, "UnitData") and InventoryIsCombatMode(context2)) and g_Units[context2.session_id] or context2
	if	IsKindOf(obj1, "CObject") and IsKindOf(obj2, "CObject") then
		if obj1:GetDist2D(obj2) > const.InventoryGiveDistance then
			return false, T(201109005967, "Character too far")
		end
	end
	return true
end

---
--- Checks if the given contexts are valid targets for inventory give/take actions and if the distance between them is within the allowed range.
---
--- @param context1 table The first object to check the validity and distance for.
--- @param context2 table The second object to check the validity and distance for.
--- @return boolean, string True if both contexts are valid targets and the distance is within the allowed range, false and an error message otherwise.
---
function InventoryGetMoveIsInvalidReason(context1, context2)
	local valid, reason = InventoryIsValidTargetForUnit(context1)	
	if not valid then	
		return reason
	else
		local valid, reason = InventoryIsValidTargetForUnit(context2)
		if not valid then
			return reason
		else
			local valid, reason = InventoryIsValidGiveDistance(context1, context2)
			if not valid then
				return reason
			end
		end
	end
end

---
--- Gets the inventory slot control for the given container and slot name.
---
--- @param bContainer boolean Whether to search for the slot in the container or the unit context.
--- @param container table The container to search for the slot in.
--- @param slot_name string The name of the slot to search for.
--- @return InventorySlotControl The inventory slot control for the given container and slot name.
---
function GetInventorySlotCtrl(bContainer, container, slot_name)
	local dlg = GetMercInventoryDlg()
	if not dlg then return end
	local context = dlg:GetContext()
	local searched_context = bContainer and (container or context.container) or context.unit
	local slots = dlg:GetSlotsArray()
	local container_slot_name = slot_name or GetContainerInventorySlotName(container) --- InventoryDead when loot bodies
	for slot in pairs(slots) do
		if slot.slot_name==container_slot_name and slot:GetContext()==searched_context then
			return slot
		end	
	end
end

---
--- Respawns the content of the Perks UI dialog.
---
--- This function is responsible for respawning the content of the Perks UI dialog when it is in the "perks" mode. It retrieves the Perks UI dialog, gets its context, and then respawns the content of the various child elements of the dialog.
---
--- @return nil
---
function PerksUIRespawn()
	local dlg
	local fdlg = GetDialog("FullscreenGameDialogs")
	if fdlg and fdlg.Mode=="perks" then
		dlg = fdlg.idModeDialog[2]
	end
	if dlg	 then
		local context = dlg:GetContext()
		dlg.idUnitInfo:RespawnContent()
		dlg.idRight:RespawnContent()
		dlg.idRight:OnContextUpdate(context)	
		dlg:OnContextUpdate(context)
	end
end	

---
--- Resets the squad bag by clearing its contents.
---
--- This function is responsible for clearing the contents of the squad bag, which is a container that holds items for the player's squad. It checks if the `gv_SquadBag` variable is not `nil`, and if so, it calls the `Clear()` method on it to remove all items from the bag.
---
--- @return nil
---
function InventoryUIResetSquadBag()
	if gv_SquadBag then
		gv_SquadBag:Clear()
	end	
end

---
--- Resets the sector stash by clearing its contents.
---
--- This function is responsible for clearing the contents of the sector stash, which is a container that holds items for a specific sector. It checks if the `gv_SectorInventory` variable is not `nil`, and if so, it calls the `Clear()` method on it to remove all items from the stash. If an `id` parameter is provided, it also sets the sector ID of the stash using the `SetSectorId()` method.
---
--- @param id number|nil The sector ID to set for the stash, or `nil` to leave the sector ID unchanged.
--- @return nil
---
function InventoryUIResetSectorStash(id)
	if gv_SectorInventory then
		gv_SectorInventory:Clear()
		if id then
			gv_SectorInventory:SetSectorId(id)
		end	
	end	
end

local InventoryUIRespawn_shield
---
--- Respawns the content of the Inventory UI dialog.
---
--- This function is responsible for respawning the content of the Inventory UI dialog. It checks if the `InventoryUIRespawn_shield` flag is set, and if so, it returns without doing anything. Otherwise, it calls the `_InventoryUIRespawn()` function after a short delay using `DelayedCall()`.
---
--- @return nil
---
function InventoryUIRespawn()
	if InventoryUIRespawn_shield then return end
	DelayedCall(0, _InventoryUIRespawn)
end

---
--- Cancels the current drag operation in the Inventory UI dialog.
---
--- This function is responsible for canceling the current drag operation in the Inventory UI dialog. It first retrieves the Inventory UI dialog using the `GetMercInventoryDlg()` function, and then iterates through the slots in the dialog using the `GetSlotsArray()` method. For each slot, it calls the `CancelDragging()` method to cancel any ongoing drag operation. If a slot cancels the drag operation, the function returns that slot.
---
--- @param dlg table|nil The Inventory UI dialog, or `nil` to use the current dialog.
--- @return table|nil The slot that canceled the drag operation, or `nil` if no slot canceled the drag.
---
function CancelDrag(dlg)
	dlg = dlg or GetMercInventoryDlg()
	if not dlg then return end
	local slots = dlg:GetSlotsArray()
	for slot_ctrl in pairs(slots) do
		if slot_ctrl:CancelDragging() then
			return slot_ctrl
		end
	end
end

---
--- Restarts a drag operation in the Inventory UI dialog.
---
--- This function is responsible for restarting a drag operation in the Inventory UI dialog. It first retrieves the slots in the dialog using the `GetSlotsArray()` method, and then iterates through the slots to find the one that contains the specified `item`. Once the slot is found, it calls the `OnMouseButtonDown()` method on the slot to start the drag operation, and then calls the `HighlightDropSlot()` function to highlight the drop slot.
---
--- @param dlg table The Inventory UI dialog.
--- @param item table The item to be dragged.
--- @return nil
---
function RestartDrag(dlg, item)
	--FindItemWnd
	local slots = dlg:GetSlotsArray()
	for slot_ctrl in pairs(slots) do
		local wnd = slot_ctrl:FindItemWnd(item)
		if wnd then
			slot_ctrl:OnMouseButtonDown((wnd.interaction_box or wnd.box):Center(), "L")
			HighlightDropSlot(nil, false)
			--slot_ctrl:InternalDragStart( (wnd.interaction_box or wnd.box):Center() )
			--slot_ctrl:OnDragStart(item)
			return
		end
	end
end

---
--- Respawns the content of the Inventory UI dialog.
---
--- This function is responsible for respawning the content of the Inventory UI dialog. It first checks if there is a concurrent squad bag sort thread running, and if so, it waits for 1 second and then calls itself recursively to run after the squad bag sort is complete.
---
--- The function then sets a shield flag `InventoryUIRespawn_shield` to true, and retrieves the Inventory UI dialog using the `GetMercInventoryDlg()` function. If the dialog is found, the function performs the following steps:
---
--- 1. Cancels any ongoing drag operation using the `CancelDrag()` function.
--- 2. Saves the current scroll positions of the dialog's scrollbars.
--- 3. Respawns the content of various UI elements in the dialog, such as the unit info, party container, right panel, and center panel.
--- 4. Updates the context of the right and center panels.
--- 5. Restores the saved scroll positions of the dialog's scrollbars.
--- 6. Sends a "RespawnedInventory" message.
--- 7. If there was a drag item, it rebuilds the UI and restarts the drag operation using the `RestartDrag()` function.
---
--- Finally, the function sets the `InventoryUIRespawn_shield` flag to `nil`.
---
function _InventoryUIRespawn()
	if IsValidThread(g_squad_bag_sort_thread) then
		Sleep(1)
		InventoryUIRespawn() --run after squad bag sort if concurent
		return
	end
	InventoryUIRespawn_shield = true
	local dlg = GetMercInventoryDlg()
	if dlg then
		local drag_item = InventoryDragItem
		if drag_item then
			CancelDrag(dlg)
		end
		
		local saveScroll = dlg.idScrollbar.Scroll
		local saveScrollCenter = dlg.idScrollbarCenter.Scroll
		local context = dlg:GetContext()
		dlg.idUnitInfo:RespawnContent()
		dlg.idPartyContainer.idParty:RespawnContent()
		dlg.idRight:RespawnContent()
		dlg.idCenter:RespawnContent()
		
		dlg.idRight:OnContextUpdate(context)	
		dlg.idCenter:OnContextUpdate(context)
		
		dlg.idCenter:RespawnContent()
		dlg:OnContextUpdate(context)
		dlg.idScrollbar:ScrollTo(saveScroll)
		dlg.idScrollbarCenter:ScrollTo(saveScrollCenter)
		Msg("RespawnedInventory")
		
		if drag_item then
			Sleep(0) --rebuild ui
			RestartDrag(dlg, drag_item)
		end
	end
	InventoryUIRespawn_shield = nil
end

OnMsg.InventoryRemoveItem = InventoryUIRespawn
OnMsg.InventoryAddItem = InventoryUIRespawn

---
--- Returns a list of valid units that can receive the given item in the given context.
---
--- @param context table The context containing information about the item and the container.
--- @return table A list of valid units that can receive the item.
---
function GetValidMercsToTakeItem(context)
	local remove_self = not context.container and "remove self"
	local unit
 
	if IsKindOf(context.context, "Unit") and not context.context:IsDead() 
		or IsKindOf(context.context, "UnitData") 
		or (IsKindOf(context.context, "SectorStash") and context.unit.Operation=="Arriving")
	then	
		remove_self = "remove self"
		unit = context.context
	else
		remove_self = false
		unit = context.unit
	end	
	
	local item = context.item
	if (not gv_SatelliteView or InventoryIsCombatMode(unit)) and not InventoryIsValidGiveDistance(context.context, unit)then
		return 
	end	
	local units = InventoryGetSquadUnits(unit, remove_self, 
		function(u)
			if type(u)== "string" then
				u = gv_UnitData[u]
			end
			if (not gv_SatelliteView or InventoryIsCombatMode(unit)) and not InventoryIsValidGiveDistance(u, unit) then
				return false
			end
			local pos, reason = u:CanAddItem("Inventory",item)
			return not not pos
		end)	
	return units	
end


---
--- Checks if the container in the given context is on the same sector as the player's current sector.
---
--- @param context table The context containing information about the item and the container.
--- @return boolean True if the container is on the same sector, false otherwise.
---
function InventoryIsContainerOnSameSector(context)
	local unit = GetInventoryUnit()	
	local unit_sector = unit.Squad 
	unit_sector = unit_sector and gv_Squads[unit_sector].CurrentSector
	if IsKindOf(context.context, "SectorStash") and context.context.sector_id~=unit_sector then 
		return false
	end
	return true
end

---
--- Retrieves the valid targets for the "Give To Squad" action in the inventory UI.
---
--- @param context table The context containing information about the item and the container.
--- @return table The list of valid targets for the "Give To Squad" action.
---
function InventoryGetTargetsForGiveAction(context)
	if not InventoryIsContainerOnSameSector(context) then
		return {}
	end	
	local targets = table.copy(GetValidMercsToTakeItem(context))
	if      IsKindOf(context.item, "SquadBagItem") 
		and not IsKindOf(context.context,"SquadBag") 
		and InventoryIsValidTargetForUnitInTransit(context.context) 
	then	
		targets[#targets+1] = context.unit.Squad
	end
	return targets
end

---
--- Retrieves the valid targets for the "Give To Squad" action in the inventory UI, excluding the current unit's squad.
---
--- @param context table The context containing information about the item and the container.
--- @return table The list of valid targets for the "Give To Squad" action, excluding the current unit's squad.
---
function InventoryGetTargetsForGiveToSquadAction(context)
	local ctx = context.context
	local sector_id 
	if IsKindOf(ctx, "SectorStash") then
		sector_id = ctx.sector_id
	else
		local unit_squad = context.unit and context.unit.Squad 
		sector_id = gv_Squads[unit_squad].CurrentSector
	end

	local unit = context.context
	local unit_squad = unit.Squad or unit.squad_id --the second part is a squad bag
	local squads = GetCurrentSectorPlayerSquads(sector_id)

	local unit = context.unit
	table.remove_entry(squads, "UniqueId", unit.Squad or "")
	return squads
end

---
--- Retrieves a list of units in the current squad, optionally excluding the specified unit and filtering the list.
---
--- @param unit string|table The unit to get the squad for. Can be a unit object or a unit session ID.
--- @param remove_self boolean If true, the specified unit will be removed from the list.
--- @param filter function An optional filter function that takes a unit and returns a boolean indicating whether it should be included in the list.
--- @return table The list of units in the current squad, filtered and with the specified unit removed if requested.
---
function InventoryGetSquadUnits(unit, remove_self, filter)
	if gv_SatelliteView then
		local dlg  = GetSatelliteDialog()				
		local squad = dlg and dlg.selected_squad
		if unit then
			if type(unit) ~= "string" then
				squad = unit.Squad and gv_Squads[unit.Squad]
				unit = unit.session_id
			else
				squad = gv_UnitData[unit] and gv_UnitData[unit].Squad 	and gv_Squads[gv_UnitData[unit]]
			end			
		end
		local units = squad and squad.units or empty_table
		unit = unit or units[1]
		return table.ifilter(units, function(i,u) return (not remove_self or u ~= unit) and (not filter or filter(u)) end)
	else
		unit = unit or SelectedObj
		local team = unit.team
		team = GetFilteredCurrentTeam(team)
		return team and table.ifilter(team.units, function(i,u) 
			return not u:IsDead() 
					and (not remove_self or (u.session_id~=unit.session_id)) 
					and (not filter or filter(u))
			end ) 
			or empty_table
	end
end

---
--- Finds an item in the inventories of a list of mercenaries, and returns the first found item and the total number of found items.
---
--- @param all_mercs table A list of mercenary IDs to search through.
--- @param item_id string The ID of the item to search for.
--- @param amount number The minimum amount of the item to find.
--- @param check boolean If true, the function will only check if the item is found, not return the item data.
--- @return table|nil The first found item data, or nil if not found.
--- @return table A list of all found item data.
---
function InventoryFindItemInMercs(all_mercs,item_id, amount, check)
	local result
	local results = {}
	for idx, merc in ipairs(all_mercs) do
		local unit = not gv_SatelliteView and g_Units[merc] or gv_UnitData[merc]
		unit:ForEachItemDef(item_id, function(item, slot)
			local is_stack = IsKindOf(item, "InventoryStack")
			local val = is_stack and item.Amount or 1
			if val >=amount and item:GetConditionPercent()>0 then
				if check then
					return "break"
				end
				local found = {container = unit, slot = slot, item = item}
				result = result or found					
				if not check then
					while val>=amount do
						results[#results + 1] = found
						val = val - amount
					end
				end
			end	
		end)
		if next(result)then
			break
		end
	end
	if not next(result) then		
		local unit = gv_UnitData[all_mercs[1]]
		assert(unit)
		local bag = unit and GetSquadBag(unit.Squad) or empty_table
		local bag_obj = unit and GetSquadBagInventory(unit.Squad)
		
		for i = #bag, 1, -1 do
			local item =  bag[i]
			if item.class == item_id then
				local is_stack = IsKindOf(item, "InventoryStack")
				local val = is_stack and item.Amount or 1
				if val>=amount and item:GetConditionPercent()>0 then					
					if check then
						break
					end	
					local found = {container = bag_obj, slot = "Inventory", item = item}
					result = result or found
					if not check then
						while val>=amount do
							results[#results + 1] = found
							val = val - amount
						end
					end
				end	
			end
		end	
	end	
	return result, results
end

---
--- Finds the ingredients required for a given recipe and the units that have those ingredients.
---
--- @param recipe table The recipe to find the ingredients for.
--- @param unit table The unit to find the ingredients for.
--- @return table The ingredients and the units that have them.
---
function InventoryGetIngredientsForRecipe(recipe, unit)
	local unit_id = unit.session_id
	local squad = gv_UnitData[unit_id] and gv_UnitData[unit_id].Squad
	if not squad then return end 
	local all_mercs = table.copy(gv_Squads[squad].units)
	-- check distance restrictions
	if (not gv_SatelliteView or InventoryIsCombatMode(unit)) then
		for i = #all_mercs, 1, -1 do
			if not InventoryIsValidGiveDistance(g_Units[all_mercs[i]], unit) then
				table.remove(all_mercs, i)
			end
		end
	end

	local ingredients = {}

	for i, ingrd in ipairs(recipe.Ingredients) do
		local result, results = InventoryFindItemInMercs(all_mercs, ingrd.item, ingrd.amount)
		ingredients[#ingredients + 1] = {
			recipe = recipe,
			container_data = result,
			total_data = results
		}
	end
	
	return ingredients
end

---
--- Finds the recipes that can be crafted using the given item, and the units that have the required ingredients.
---
--- @param item InventoryItem The item to find recipes for.
--- @param unit Unit The unit to find the recipes for.
--- @param item2 InventoryItem The second item required for the recipe (optional).
--- @param container2 InventoryContainer The container holding the second item (optional).
--- @return table The recipes that can be crafted and the units that have the required ingredients.
---
function InventoryGetTargetsRecipe(item, unit, item2, container2)
	local is_stack = IsKindOf(item, "InventoryStack")
	if item:GetConditionPercent()<=0 then
		return empty_table
	end	
	local item_id = item.class
	local targets = {}
	
	local unit_id = unit.session_id
	local container2_id = container2 and container2.session_id	
	local squad = gv_UnitData[unit_id] and gv_UnitData[unit_id].Squad
	if not squad then return end 
	local all_mercs = container2 and container2_id and {container2_id} or table.copy(gv_Squads[squad].units)
	-- check distance restrictions
	if (not gv_SatelliteView or InventoryIsCombatMode(unit)) then
		for i = #all_mercs, 1, -1 do
			if not InventoryIsValidGiveDistance(g_Units[all_mercs[i]], unit) then
				table.remove(all_mercs, i)
			end
		end
	end
	for id, recipe in pairs(Recipes) do
		local ingredients = recipe.Ingredients
		for i, ingrd in ipairs(ingredients) do
			--print(item_id,item.Amount)
			if ingrd.item == item_id and (not is_stack or ingrd.amount<=(item.Amount or 1)) then -- first item amount check			
				local second_idx = i==1 and 2 or 1
				local second = ingredients[second_idx]
				-- find the second item and check its condition
				if not item2 or second.item == item2.class then
					local result, results = InventoryFindItemInMercs(all_mercs,second.item,second.amount)
					if next(result) then
						targets[#targets+1] = {
							recipe = recipe,
							second_idx = second_idx,
							second = second.item,
							container_data = result,
							total_data = results
						}
					end
				end
			end
		end
	end
	return targets
end

--- Checks if the given unit can use the specified item.
---
--- @param unit Unit The unit that may use the item.
--- @param item InventoryItem The item to check if the unit can use.
--- @return boolean True if the unit can use the item, false otherwise.
function InventoryUnitCanUseItem(unit, item)
	if InventoryItemDefs[item.class].group=="Magazines" then
		return unit[item.UnitStat] < 100
	end	
	return true
end

---
--- Handles the use of an item by a unit.
---
--- @param unit Unit The unit using the item.
--- @param item InventoryItem The item being used.
--- @param source_context string The context in which the item is being used.
--- @param source_slot_name string The name of the slot from which the item is being used.
---
function InventoryUseItem(unit, item, source_context, source_slot_name) 
 		NetSyncEvent("InvetoryAction_UseItem", unit.session_id, item.id) 
		 
		if InventoryItemDefs[item.class].group=="Magazines" then
			PlayVoiceResponse(unit.session_id, "LevelUp")
		end
		if item.class =="MetaviraShot" then
			PlayVoiceResponse(unit.session_id, "HealReceived")
		end
		CombatLog("short", T{750272913405, "<merc> uses <item>", merc = unit:GetDisplayName(),item = item.DisplayName})
		
		if item.destroy_item then
			DestroyItem(item, unit, source_context, source_slot_name, 1)
		end
end

if FirstLoad then
	ItemClassToRecipes = false
end

function OnMsg.DataLoaded()
	ItemClassToRecipes = {}
	local function push(item_class, recipe)
		local t = ItemClassToRecipes[item_class] or {}
		ItemClassToRecipes[item_class] = t
		table.insert(t, recipe)
	end
	for recipe_id, recipe in pairs(Recipes) do
		local ingredients = recipe.Ingredients
		local ing1 = ingredients[1]
		local ing2 = ingredients[2]
		push(ing1.item, recipe)
		push(ing2.item, recipe)
	end
end

---
--- Checks if the given drag item and target item can be combined using a recipe.
---
--- @param drag_item InventoryItem The item being dragged.
--- @param target_item InventoryItem The item being targeted for combination.
--- @return table|nil The recipe that can be used to combine the items, and a boolean indicating if the drag item is the first ingredient.
---
function InventoryIsCombineTarget(drag_item, target_item) 
	if g_Combat then return false end
	if not target_item then return end
	local drag_id   = drag_item.class
	local target_id = target_item.class 
	local drag_amount = IsKindOf(drag_item,"InventoryStack") and drag_item.Amount or 1
	local target_amount= IsKindOf(target_item,"InventoryStack") and target_item.Amount or 1
	local recipes = ItemClassToRecipes[drag_id]
 	for _, recipe in ipairs(recipes) do
		local ingredients = recipe.Ingredients
		local ing1 = ingredients[1]
		local ing2 = ingredients[2]
		if ing1.item == drag_id and ing2.item == target_id and ing1.amount<=drag_amount and ing2.amount<=target_amount or
			ing2.item == drag_id and ing1.item == target_id and ing2.amount<=drag_amount and ing1.amount<=target_amount
		then 		
			return recipe, ing1.item == drag_id
		end
	end
end

---
--- Finds the unit with the maximum skill level for the given recipe.
---
--- @param unit Unit The unit to search for the highest skill level.
--- @param recipe table The recipe to find the highest skill level for.
--- @return number, string, string The maximum skill level, the session ID of the unit with the maximum skill, and the skill type ("Mechanical" or "Explosives").
---
function InventoryCombineItemMaxSkilled(unit, recipe)
	local maxSkill,mercMaxSkill, skill_type
	local is_unit = IsKindOf(unit, "Unit")
	local sector_id = gv_Squads[unit.Squad].CurrentSector
	local units = GetPlayerMercsInSector(sector_id)
	for i, u_id in ipairs(units) do
		local u = is_unit and g_Units[u_id] or gv_UnitData[u_id]
		skill_type = recipe.MechanicalRoll and "Mechanical" or "Explosives"
		local skill = u[recipe.MechanicalRoll and "Mechanical" or "Explosives"]
		if not maxSkill or skill > maxSkill then
			maxSkill = skill
			mercMaxSkill = u.session_id
		end
	end
	return maxSkill,mercMaxSkill, skill_type
end		

-- maybe split retrieval of containers from ui logic
---
--- Retrieves a list of loot containers around the given container.
---
--- @param container SectorStash|ItemDropContainer|Unit|ContainerMarker The container to search around.
--- @return table The list of loot containers around the given container.
---
function InventoryGetLootContainers(container) -- in area around container
	if IsKindOf(container, "SectorStash") then
		return {container}
	elseif InventoryIsCombatMode() then
		return {container}
	elseif (IsKindOfClasses(container, "ItemDropContainer", "Unit") or IsKindOf(container, "ContainerMarker") and container:IsInGroup("DeadBody")) and IsValid(container) then
		local pos = container:GetPos()
		local unit = container.interacting_unit or false
		local containers = MapGet(pos, const.AreaLootSize * const.SlabSizeX, "ItemDropContainer", "Unit","ItemContainer", 
			function(o, unit) 
				if o == container then
					return false
				end	

				local spawner = o:HasMember("spawner") and o.spawner
				if not IsKindOfClasses(o, "ItemDropContainer", "Unit") and not (IsKindOf(o, "ContainerMarker") and o:IsMarkerEnabled() and o:IsInGroup("DeadBody")) then
					return false
				end					
				
				if spawner and spawner.Type == "IntelInventoryItemSpawn" and not gv_Sectors[gv_CurrentSectorId].intel_discovered then
					return false
				end

				if IsKindOf(o, "Unit") then
					if not o:IsDead() then
						return false
					end
					if o.interacting_unit ~= unit then
						return false
					end
					return  o:GetItemInSlot("InventoryDead")
				end
				
				if IsKindOf(o, "ItemContainer") then
					if not o:IsOpened() and o:CannotOpen() then
						return false
					end
					if o.interacting_unit then
						if not unit then
							return false
						elseif unit and o.interacting_unit ~= unit then
							return false
						end
					end
				end	
								
				return o:GetItem() --or not (spawner and not is_unit and o.spawner.HideIfEmpty)							
			end, unit)
			
		local ret = {container}
		for _,cont in ipairs(containers) do
			ret[#ret+1] = cont
		end
		
		return ret
	else
		return {container}
	end
end
 
---
--- Returns a list of container names to be used in a combo box.
---
--- @return table<string> A table of container name IDs.
function GetContainerNamesCombo()
	local presets = Presets.ContainerNames.Default
	local combo = {}
	for _, preset in ipairs(presets) do
		combo[#combo+1] = preset.id
	end
	return combo
end

---
--- Returns the name of the inventory slot for the given container.
---
--- @param container Unit|UnitData The container object.
--- @return string The name of the inventory slot.
function GetContainerInventorySlotName(container)
	return IsKindOfClasses(container, "Unit", "UnitData") and container:IsDead() and "InventoryDead" or "Inventory"
end

---
--- Spawns a secondary popup for inventory actions.
---
--- @param actionButton UIButton The button that triggered the popup.
--- @param action table The action data.
---
function SpawnInventoryActionsSecondaryPopup(actionButton, action)
	local node =  actionButton:ResolveId("node")
	local context = node.context
	context.action = action
	node = node.parent
	-- open sub menu
	if node.spawned_subpopup then
		node.spawned_subpopup:Close()
	end
	actionButton:SetSelected(true)
	local popup = XTemplateSpawn("InventoryContextSubMenu", terminal.desktop, context)
	popup:SetAnchorType("right")
	popup:SetAnchor(actionButton.box)
	popup.popup_parent = node
	node.spawned_subpopup = popup
	popup:Open()
end

if Platform.developer then

	local function wait_interface_mode(mode, step)
		while GetInGameInterfaceMode() ~= mode do
			Sleep(step or 10)
		end
	end

	local function wait_units_idle()
		local units = table.icopy(g_Units)
		repeat
			for i = #units, 1, -1 do
				if units[i]:IsDead() or units[i]:IsIdleCommand() then
					table.remove(units, i)
				end
			end
			if #units > 0 then
				WaitMsg("Idle", 20)
			end
		until #units == 0
	end

	local function wait_game_time(ms, step)
		local t = GameTime()
		while GameTime() < t + ms do
			Sleep(step or 10)
		end
	end
	
	local function GameTestInventoryDlgAction(dlg, action_id, time)
		local action = dlg:ActionById(action_id)
		if action then action:OnAction(dlg) end
		Sleep(time or 20)
	end	

	local function GameTestInventoryCloseInvDialog()
		local dlg = GetDialog("FullscreenGameDialogs")
		GameTestInventoryDlgAction(dlg, "Close")
		while GetDialog("FullscreenGameDialogs") do
			Sleep(50)
		end
	end	
	
	local function GameTestInventoryOpenPopup(ctrl, posctrl)
		posctrl = posctrl or ctrl
		ctrl:OnMouseButtonDown(posctrl.box:min()+posctrl.box:size()/3, "R")
	end
	
	local function GameTestInventoryStartPopupAction(action_name, inv_dlg, ctrl, posctrl)
		inv_dlg = inv_dlg or GetMercInventoryDlg()
		ctrl:ClosePopup()

		local popup
		while not popup or popup.window_state == "destroying" do
			GameTestInventoryOpenPopup(ctrl, posctrl)
			Sleep(50) -- Layout popup
			popup = inv_dlg.spawned_popup
			if not popup then return end
		end
		
		local btn
		for _, wnd in ipairs(popup.idPopupWindow) do
			btn = wnd
			if not IsKindOf(wnd, "XButton") then
				btn = wnd[1]				
			end
			if btn.Id == action_name then
				btn:Press()
				break
			end
		end
		
		Sleep(50) -- Wait for button press to send event
		WaitAllCombatActionsEnd() -- Wait for event to process
		Sleep(50) -- Wait for event triggers to fire (some respawn the ui)
		return popup
	end
	local function GameTestInventoryGetBrowseCtrl(inv_dlg, n)
		return inv_dlg.idScrollArea[n].idInventorySlot
	end
	
	local function GameTestInventory(bExploration)
		-- Prevent out of space errors in the test 
		g_Units.Buns.Strength = 100
		g_Units.Len.Strength = 100
	
		g_Units.Buns:AddToInventory("Parts", 100)
		g_Units.Len:AddToInventory("AK47")
		g_Units.Len:AddToInventory("AK74")
		AddItemToSquadBag(g_Units.Len.Squad, "762WP_AP", 50)

		SelectObj(g_Units.Buns)
		wait_game_time(50,10)

		-- load inventory
		local dlg = GetInGameInterfaceModeDlg()		
		InvokeShortcutAction(dlg, "idInventory")
		local dlg = GetDialog("FullscreenGameDialogs")
		while not dlg do
			dlg = GetDialog("FullscreenGameDialogs")
			Sleep(20)
		end
		Sleep(200) -- wait for events and layout on open

		-- unload
		local inv_dlg = GetMercInventoryDlg()	
		local ctrl = inv_dlg.idUnitInfo.idWeaponA
		GameTestInventoryStartPopupAction("unload", inv_dlg, ctrl)

		-- reload
		g_Units.Buns:GainAP(100000)
		local ctrl = inv_dlg.idUnitInfo.idWeaponA
		local popup = GameTestInventoryStartPopupAction("reload", inv_dlg, ctrl)
		if popup then
			local subpopup = popup.spawned_subpopup
			subpopup.idPopupWindow[1]:Press()
			Sleep(100) --give it time to execute or it will exec during the rest of the test and close popups and such through UIRespawn
		end
		
		-- inventory 
				
		-- drop item	
		SelectObj(g_Units.Buns)
		local inv_dlg = GetMercInventoryDlg()	
		local ctrl = GameTestInventoryGetBrowseCtrl(inv_dlg, bExploration and 3 or 4)
		for item_ctrl,item in pairs(ctrl.item_windows) do
			if bExploration or not IsKindOf(item, "InventoryStack") then 
				GameTestInventoryStartPopupAction( "drop", inv_dlg, ctrl, item_ctrl)
				Sleep(100)
				break
			end 
		end
		
		-- split and combine items
		local inv_dlg = GetMercInventoryDlg()	
		local ctrl = GameTestInventoryGetBrowseCtrl(inv_dlg, 2)
		for item_ctrl,item in pairs(ctrl.item_windows) do
			local ctrl = GameTestInventoryGetBrowseCtrl(inv_dlg, 2)
			if IsKindOf(item, "InventoryStack") and item.Amount > 3 then 
				GameTestInventoryStartPopupAction("split", inv_dlg, ctrl, item_ctrl)
				local splitdlg = GetDialog("SplitStackItem")
				local slider = splitdlg.idContext.idSlider
				slider:SetScroll(3)
				local actions = splitdlg:GetActions()
				actions[1]:OnAction(splitdlg)
				Sleep(100)
				break
			end 
		end		
		
		-- give item to
		local inv_dlg = GetMercInventoryDlg()	
		local ctrl = GameTestInventoryGetBrowseCtrl(inv_dlg, bExploration and 1 or 4)
		local to_bag =  false
		for item_ctrl,item in pairs(ctrl.item_windows) do
			local ctrl = GameTestInventoryGetBrowseCtrl(inv_dlg, bExploration and 1 or 4)
			local popup = GameTestInventoryStartPopupAction("give", inv_dlg, ctrl, item_ctrl)
			if popup then
				popup = popup.spawned_subpopup
			end
			if not to_bag and IsKindOf(item, "InventoryStack") then -- bag
				popup.idPopupWindow[#popup.idPopupWindow]:Press()
				to_bag =  true
				Sleep(100)
			else -- buns
				popup.idPopupWindow[1]:Press()
				Sleep(100)
				if to_bag then
					break
				end
			end 
		end		
		
		-- modify dlg for equipped weapon
		local inv_dlg = GetMercInventoryDlg()	
		local ctrl = inv_dlg.idUnitInfo.idWeaponA
		GameTestInventoryStartPopupAction("modify", inv_dlg, ctrl)
		local m_dlg = GetDialog("ModifyWeaponDlg")
		while not (m_dlg and rawget(m_dlg,"idModifyDialog")) do
			Sleep(50)
			m_dlg = GetDialog("ModifyWeaponDlg")
		end
		local trigger = m_dlg.idModifyDialog.idWeaponParts[3]
		trigger.idCurrent:OnPress()
		Sleep(50)
		--m_dlg.idModifyDialog.idComponentChoice[1][2][bExploration and 1 or 2]:OnPress()		
		Sleep(50)				
		--local action = m_dlg:ActionById("actionUpgradePanel")
		--m_dlg.idModifyDialog:ApplyChanges("force")		
		GameTestInventoryDlgAction(m_dlg, "actionClosePanel")
		Sleep(30)
		CloseDialog("ModifyWeaponDlg")
		while GetDialog("ModifyWeaponDlg") do
			Sleep(30)
		end
		
		-- equip item
		--nextUnit
		local inv_dlg = GetMercInventoryDlg()
		GameTestInventoryDlgAction(inv_dlg, "NextUnit")
		local ctrl = GameTestInventoryGetBrowseCtrl(inv_dlg, 2)
		for item_ctrl,item in pairs(ctrl.item_windows) do
			if item.class == "AK47" then 
				GameTestInventoryStartPopupAction("equip", inv_dlg, ctrl, item_ctrl)
				break
			end 
		end		
		-- scrap item
		local ctrl = GameTestInventoryGetBrowseCtrl(inv_dlg, 2)
		for item_ctrl,item in pairs(ctrl.item_windows) do
			if item:IsWeapon() then 
				GameTestInventoryStartPopupAction("scrap", inv_dlg, ctrl, item_ctrl)
				Sleep(50)
				for d, _ in pairs(g_OpenMessageBoxes) do
					if d and d[1] then
						d[1].idActionBar.ididOk:Press()
						Sleep(50)
					end
				end
				break
			end 
		end	
	-- join parts to bag
		local inv_dlg = GetMercInventoryDlg()	
		local ctrl = GameTestInventoryGetBrowseCtrl(inv_dlg, 1)
		for item_ctrl,item in pairs(ctrl.item_windows) do
			if item.class == "Parts" then -- bag
				local popup = GameTestInventoryStartPopupAction("give", inv_dlg, ctrl, item_ctrl)
				if popup then
					popup = popup.spawned_subpopup
				end
				if popup and popup.idPopupWindow then
					popup.idPopupWindow[#popup.idPopupWindow]:Press()
				end
				Sleep(30)
				break
			end 
		end		

		-- reload from bag
		local inv_dlg = GetMercInventoryDlg()	
		GameTestInventoryDlgAction(inv_dlg, "NextUnit")
		local inv_dlg = GetMercInventoryDlg()	
		local ctrl = inv_dlg.idUnitInfo.idWeaponA
		GameTestInventoryStartPopupAction("unload", inv_dlg, ctrl)
		
		local ctrl = inv_dlg.idUnitInfo.idWeaponA
		popup = GameTestInventoryStartPopupAction("reload", inv_dlg, ctrl)
		if popup then
			popup = popup.spawned_subpopup
			if popup then
				popup.idPopupWindow[1]:Press()
				Sleep(30)
			end
		end
		GameTestInventoryCloseInvDialog()
		
		--open container	
		SelectObj(g_Units.Buns)
		wait_game_time(50,10)
		wait_game_time(50,10)
		local modedlg = GetInGameInterfaceModeDlg()
		local t = now()
		
		-- The test isn't consistent, the unit is not always in range to interact
		-- Both cases are handled below.
		local interactAction = modedlg:ResolveId("Interact")
		if interactAction then interactAction:Press() end
		local dlg = GetDialog("FullscreenGameDialogs")
		while not dlg and now()-t<500 do
			dlg = GetDialog("FullscreenGameDialogs")
			Sleep(20)
		end
		dlg = GetDialog("FullscreenGameDialogs")
		if dlg then
			GameTestInventoryDlgAction(dlg, "TakeLoot", 50)
			GameTestInventoryCloseInvDialog()
		end
	end

	function GameTests.Inventory()
		--do return end
		assert(CurrentThread() and IsRealTimeThread(CurrentThread()))
		local t = RealTime()
		local test_combat_id = "Default"
		-- reset & seed interaction rand
		GameTestMapLoadRandom = xxhash("GameTestMapLoadRandomSeed")
		MapLoadRandom = InitMapLoadRandom()
		ResetInteractionRand(0) -- same reset at map game time 0 to get control values for interaction rand results
		local expected_sequence = {}
		for i = 1, 10 do
			expected_sequence[i] = InteractionRand(100, "GameTest")
		end
			
		local testPreset = Presets.TestCombat.GameTest[test_combat_id]	
		
		-- reset game session and setup a player squad
		NewGameSession()
		gv_CurrentSectorId = testPreset.sector_id
		CreateNewSatelliteSquad({Side = "player1", CurrentSector = testPreset.sector_id, Name = "GAMETEST"}, {"Buns", "Len", "Ivan", "Tex"}, 14, 1234567)

		-- start a thread to close all popups during the test
		local combat_test_in_progress = true
		CreateRealTimeThread(function()
			while combat_test_in_progress do
				if GetDialog("PopupNotification") then
					Dialogs.PopupNotification:Close()
				end
				Sleep(10)
			end
		end)
		TestCombatEnterSector(testPreset)
		SetTimeFactor(10000)
			
		if true then -- check for InteractionRand inconsistencies
			assert(MapLoadRandom == GameTestMapLoadRandom)
			for i = 1, 10 do
				local value = InteractionRand(100, "GameTest")
				assert(value == expected_sequence[i])
			end
		end
		
		-- wait the ingame interface and navigate it to combat	
		while GetInGameInterfaceMode() ~= "IModeDeployment" and GetInGameInterfaceMode() ~= "IModeExploration" do
			Sleep(20)
		end
		GameTestMapLoadRandom = false
				
		if GetInGameInterfaceMode() == "IModeDeployment" then
			Dialogs.IModeDeployment:StartExploration()
			while GetInGameInterfaceMode() == "IModeDeployment" do
				Sleep(10)
			end
		end		
		
		if GetInGameInterfaceMode() == "IModeExploration" then		
			NetSyncEvent("ExplorationStartCombat")
			wait_interface_mode("IModeCombatMovement")
		end
		
		wait_units_idle()
		
		if true then -- player turn code block
		-- test inventory inside the combat
			GameTestInventory()
		end
		
		-- kill enemies & exit combat
		NetSyncEvent("KillAllEnemies")
		if g_Combat then
		 g_Combat:EndCombatCheck()
		end
		while GetInGameInterfaceMode() ~= "IModeExploration" do
			WaitMsg("ExplorationStart", 50)
		end
		combat_test_in_progress = false
		GameTestInventory("exploration")
		
		print("Inventory test time:", (RealTime()-t)/1000)
	end
end -- platform.developer

---
--- Moves an item from one container to another.
---
--- @param node table The node containing the context information for the item to be moved.
---
function PopupMenuGiveItem(node)
	local context = node and node.context
	if context then
		local ui_slot = context.slot_wnd
		local dest_container = node.unit
		if context.items then			
			local tbl = table.keys(context.items)
			for i, item in ipairs(tbl) do			
				local args = {item = item, src_container = context.context, src_slot = ui_slot.slot_name, dest_container = dest_container,
									dest_slot = GetContainerInventorySlotName(dest_container)}
				args.no_ui_respawn = i~=#tbl
				local r1, r2  = MoveItem(args) --this will merge stacks and move, if you want only move use amount = item.Amount				
			end
		else
			local args = {item = context.item, src_container = context.context, src_slot = ui_slot.slot_name, dest_container = dest_container,
								dest_slot = GetContainerInventorySlotName(dest_container)}
			MoveItem(args) --this will merge stacks and move, if you want only move use amount = item.Amount
		end
		ui_slot:ClosePopup()
		InventoryDeselectMultiItems()
		PlayFX("GiveItem", "start", GetInventoryItemDragDropFXActor(context.item))
	end
end

---
--- Displays a popup menu to give an item to a squad.
---
--- @param node table The node containing the context information for the item to be given.
---
function PopupMenuGiveItemToSquad(node)
	local context = node and node.context
	if not context then return end
	local rez = _PopupMenuGiveItemToSquad(node,context, "check_only")
	if rez then
		CreateRealTimeThread(function(node, context)
			local popupHost = GetInGameInterface()
			local scrapPrompt = CreateQuestionBox(
				popupHost,
				T(333299723785, "GIVE TO SQUAD"),
				T(118439464722, "No space for all items. Are you sure you want to give some of them?"),
				T(689884995409, "Yes"), 
				T(782927325160, "No"))
						
			local resp = scrapPrompt:Wait()
			if resp ~= "ok" then
				return
			else
				_PopupMenuGiveItemToSquad(node, context)					
			end
		end, node, context)
	else	
		_PopupMenuGiveItemToSquad(node,context)
	end
	InventoryDeselectMultiItems()
end


---
--- Displays a popup menu to split and give an item to a squad.
---
--- @param node table The node containing the context information for the item to be given.
---
function PopupMenuSplitGiveToSquad(node)
	local context = node and node.context
	if not context then return end
	if node.squad then
		OpenDialog("SplitStackItem",false, SubContext(context, {squad_id = node.squad and node.squad.UniqueId, fnOK = function(context, splitAmount)
			local ui_slot = context.slot_wnd
			local dest_squad = gv_Squads[context.squad_id]
			local src_container = context.context
			local item = context.item
			local squadBag = context.squad_id
			
			local args = {item = item, src_container = src_container, src_slot = ui_slot.slot_name,
							dest_container = squadBag, dest_slot = "Inventory", amount = splitAmount}
			local rez = MoveItem(args)
			if rez then
				local su = dest_squad.units
				for _, unitName in ipairs(su) do
					local dest_container = gv_SatelliteView and gv_UnitData[unitName] or g_Units[unitName]
					args.dest_container = dest_container
					args.dest_slot = GetContainerInventorySlotName(dest_container)
					rez = MoveItem(args)
					if not rez then
						break
					end
				end
			end

			if rez then
				print("failed to transfer to squad", rez)
			end
		end})
		)
	elseif node.unit then
		OpenDialog("SplitStackItem",false, SubContext(context, {udata = IsKindOf(node.unit, "UnitData"),unit = node.unit.session_id , fnOK = function(context, splitAmount)
			local ui_slot = context.slot_wnd
			local dest_container = context.udata and gv_UnitData[context.unit] or g_Units[context.unit]
			local args = {item = context.item, src_container = context.context, src_slot = ui_slot.slot_name, dest_container = dest_container,
								dest_slot = GetContainerInventorySlotName(dest_container), amount = splitAmount}
			MoveItem(args) --this will merge stacks and move, if you want only move use amount = item.Amount
			ui_slot:ClosePopup()
			PlayFX("GiveItem", "start", GetInventoryItemDragDropFXActor(context.item))
			end})
		)
	end
end

---
--- Moves an item from a source container to a squad's inventory and distributes it among the squad members.
---
--- @param node table The node containing the context information for the item to be given.
--- @param context table The context information for the item to be given.
--- @param check_only boolean If true, only checks if the move is possible, without actually performing the move.
---
function _PopupMenuGiveItemToSquad(node, context,check_only)
	local context = context or (node and node.context)
	local ui_slot = context.slot_wnd
	local dest_squad = node.squad
	local src_container = context.context
	local item = context.item
	local squadBag = dest_squad.UniqueId
	local multi = not not context.items
		
	local tbl = multi and table.keys(context.items) or {item}
	for i, item in ipairs(tbl) do				
		local args = {item = item, src_container = src_container, src_slot = ui_slot.slot_name,
						dest_container = squadBag, dest_slot = "Inventory" , check_only =check_only}
						args.no_ui_respawn = multi and i~=#tbl or nil
		local rez = MoveItem(args)
		if rez then
			local su = dest_squad.units
			for _, unitName in ipairs(su) do
				local dest_container = gv_SatelliteView and gv_UnitData[unitName] or g_Units[unitName]
				args.dest_container = dest_container
				args.dest_slot = GetContainerInventorySlotName(dest_container)
				rez = MoveItem(args)
				if not rez then
					break
				end
			end
		end

		if rez then
			print("failed to transfer to squad", rez)
			if check_only then 
				return rez
			end	
		end
	end	
end

---
--- Moves a set of items from a source container to the sector stash.
---
--- @param node table The node containing the context information for the items to be moved.
---
function PopupMoveItemsToStash(node)
	local context = node and node.context
	if not context then return end
	local ui_slot = context.slot_wnd
	local sector_id = gv_Squads[context.unit.Squad].CurrentSector
	local dest_container = GetSectorInventory(sector_id)
	InventoryOnDragEnterStash(table.keys(context.items))
	NetSyncEvent("MoveItemsToStash",GetItemsNetIds(table.keys(context.items)), sector_id, context.slot_wnd.slot_name, GetContainerNetId(context.context))
	ui_slot:ClosePopup()
	InventoryDeselectMultiItems()	
	PlayFX("GiveItem", "start",  GetInventoryItemDragDropFXActor(context.item))
end

---
--- Synchronizes the movement of items from a container to the sector stash over the network.
---
--- @param ids table A table of item net IDs to be moved.
--- @param sector_id number The ID of the sector where the stash is located.
--- @param slot_name string The name of the slot in the source container where the items are being moved from.
--- @param inv string The net ID of the source container.
---
function NetSyncEvents.MoveItemsToStash(ids, sector_id, slot_name, inv)
	local items = GetItemsFromItemsNetId(ids)
	local stash = GetSectorInventory(sector_id)		
	local container = GetContainerFromContainerNetId(inv)
	if stash then 
		for i=1, #items do
			container:RemoveItem(slot_name,items[i])
		end
		AddItemsToInventory(stash, items, true)
		InventoryUIRespawn()
		InventoryDeselectMultiItems()	
	end
end

---
--- Finds the appropriate inventory tab for a set of items.
---
--- @param items table A table of items to find the appropriate tab for.
--- @return string The ID of the appropriate inventory tab.
---
function InventoryFindTabItems(items)
	local tab = InventoryFindTab(items[1])
	if tab=="all" then return tab end
	
	local preset = InventoryTabs[tab]	
	for i=2,#items do
		if not preset:FilterItem(items[i]) then
			tab = "all"
			break
		end		
	end
	return tab
end

---
--- Finds the appropriate inventory tab for a given item.
---
--- @param item table The item to find the appropriate tab for.
--- @return string The ID of the appropriate inventory tab.
---
function InventoryFindTab(item)
	for i, preset in ipairs(Presets.InventoryTab.Default) do
		if preset.id~="all" then
			if preset:FilterItem(item)then
				return preset.id
			end	
		end
	end
	return "all"
end

---
--- Handles the drag and drop of items into the stash inventory.
---
--- If the player is in the loot mode of the Mercenary Inventory dialog and the dragged items are being dropped into a SectorStash container, this function will ensure the appropriate inventory tab is selected based on the dragged items.
---
--- @param items table A table of items being dragged and dropped, or nil if only a single item is being dragged.
---
function InventoryOnDragEnterStash(items)
	local dlg = GetMercInventoryDlg()
	if gv_SatelliteView and dlg.Mode=="loot" and IsKindOf(dlg.context.container, "SectorStash") then
		if dlg.selected_tab~="all" then
			local tab
			if items or InventoryDragItems then
				tab = InventoryFindTabItems(items or InventoryDragItems)
			else 	
				tab = InventoryFindTab(InventoryDragItem)
			end
			if dlg.selected_tab~=tab then
				local tabs = dlg.idTabs
				tabs[tab]:OnPress()
			end
		end
	end
end
DefineClass.CombineItemPopupClass = {
	__parents = { "ZuluModalDialog" } 
}

---
--- Calculates the action point (AP) cost and unit for dragging and dropping items into an inventory slot.
---
--- @param slotcontext table The context of the inventory slot the items are being dropped into.
--- @param slot_name string The name of the inventory slot the items are being dropped into.
--- @param under_item boolean Whether the items are being dropped under another item.
--- @param is_reload boolean Whether the action is a reload.
--- @return number, number, string The total AP cost, the AP unit, and the action name.
---
function InventoryItemsAPCost(slotcontext, slot_name, under_item, is_reload)
	local ap_cost, unit_ap, action_name
	if InventoryDragItems then
		for _, item in ipairs(InventoryDragItems)do
			local lap_cost, lunit_ap, laction_name = GetAPCostAndUnit(item, InventoryStartDragContext, InventoryStartDragSlotName, slotcontext, slot_name, false, false)
			ap_cost = (ap_cost or 0)+ lap_cost
			unit_ap = unit_ap or lunit_ap
			action_name = action_name or laction_name
		end
	else
		ap_cost, unit_ap, action_name = GetAPCostAndUnit(InventoryDragItem, InventoryStartDragContext, InventoryStartDragSlotName, slotcontext, slot_name, under_item, is_reload)
	end
	return ap_cost, unit_ap, action_name
end	