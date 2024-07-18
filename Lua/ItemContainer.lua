-- base class handling the syncronization to sector inventory
DefineClass.SectorInventoryObj = {
	__parents = { "Object", "Inventory", "GameDynamicDataObject" },
}

---
--- Initializes the SectorInventoryObj and adds it to the sector inventory.
---
--- This function is called when the SectorInventoryObj is created. It adds the object to the
--- sector inventory, which keeps track of all the objects in the current sector.
---
--- @function SectorInventoryObj:Init
--- @return none
function SectorInventoryObj:Init()
	self:AddInSectorInventory()
end

---
--- Removes the SectorInventoryObj from the sector inventory.
---
--- This function is called when the SectorInventoryObj is no longer needed. It removes the object from the
--- sector inventory, which keeps track of all the objects in the current sector.
---
--- @function SectorInventoryObj:Done
--- @return none
function SectorInventoryObj:Done()
	self:RemoveFromSectorInventory()
end

---
--- Adds the SectorInventoryObj to the sector inventory.
---
--- This function is called when the SectorInventoryObj is created. It adds the object to the
--- sector inventory, which keeps track of all the objects in the current sector.
---
--- @param self SectorInventoryObj
--- @return table|nil cdata The container data for the SectorInventoryObj
function SectorInventoryObj:AddInSectorInventory()
	if not gv_Sectors or not gv_CurrentSectorId then
		return
	end
	local cdata = self:GetSectorContainerData()
	if not cdata then
		-- ?container handle on different maps - can be the same?
		cdata = { self:GetHandle(), self.bOpened }
		local sector = gv_Sectors[gv_CurrentSectorId]
		if not sector then
			sector = {}
			gv_Sectors[gv_CurrentSectorId] = sector
		end
		sector.sector_inventory = sector.sector_inventory or {}
		table.insert(sector.sector_inventory, cdata)
	end
	return cdata
end

---
--- Removes the SectorInventoryObj from the sector inventory.
---
--- This function is called when the SectorInventoryObj is no longer needed. It removes the object from the
--- sector inventory, which keeps track of all the objects in the current sector.
---
--- @param self SectorInventoryObj
--- @return none
function SectorInventoryObj:RemoveFromSectorInventory()
	local cdata, sector_inventory, idx = self:GetSectorContainerData()
	if cdata then
		table.remove(sector_inventory, idx)
	end
end

---
--- Gets the sector container data for the SectorInventoryObj.
---
--- This function retrieves the sector container data for the current SectorInventoryObj. It first
--- gets the current sector from the `gv_Sectors` table using the `gv_CurrentSectorId`. It then
--- searches the `sector_inventory` table in the current sector for the handle of the
--- SectorInventoryObj. If the handle is found, it returns the container data, the sector inventory
--- table, and the index of the container data in the sector inventory table.
---
--- @param self SectorInventoryObj The SectorInventoryObj instance.
--- @return table|nil cdata The container data for the SectorInventoryObj.
--- @return table|nil sector_inventory The sector inventory table.
--- @return integer|nil idx The index of the container data in the sector inventory table.
function SectorInventoryObj:GetSectorContainerData()
	local sector = gv_Sectors and gv_Sectors[gv_CurrentSectorId]
	local sector_inventory = sector and sector.sector_inventory
	local idx = table.find(sector_inventory, 1, self:GetHandle())
	if idx then
		return sector_inventory[idx], sector_inventory, idx
	end
end

---
--- Adds an item to the SectorInventoryObj.
---
--- This function adds an item to the SectorInventoryObj's inventory. It first calls the `Inventory.AddItem` function to add the item to the inventory. If the item is successfully added, it then updates the sector container data to include the new item.
---
--- @param self SectorInventoryObj The SectorInventoryObj instance.
--- @param slot_name string The name of the inventory slot to add the item to.
--- @param item table The item to add to the inventory.
--- @param left number The left position of the item in the inventory.
--- @param top number The top position of the item in the inventory.
--- @param local_execution boolean Whether the operation is being executed locally.
--- @return table|nil pos The position of the added item in the inventory.
--- @return string|nil reason The reason why the item could not be added (if any).
function SectorInventoryObj:AddItem(slot_name, item, left, top, local_execution)
	local pos, reason = Inventory.AddItem(self, slot_name, item, left, top)

	if pos then
		local cdata = self:GetSectorContainerData()
		if cdata then
			local val, idx = table.find_value(cdata[3], item)
			if not val then
				cdata[3] = cdata[3] or {}
				table.insert(cdata[3], item)
			end
		end
	end
	self:ContainerChanged()

	return pos, reason
end

--- Removes an item from the SectorInventoryObj's inventory.
---
--- This function removes an item from the SectorInventoryObj's inventory. It first calls the `Inventory.RemoveItem` function to remove the item from the inventory. If the item is successfully removed, it then updates the sector container data to remove the item.
---
--- @param self SectorInventoryObj The SectorInventoryObj instance.
--- @param slot_name string The name of the inventory slot to remove the item from.
--- @param item table The item to remove from the inventory.
--- @param no_update boolean Whether to skip the `ContainerChanged` call.
--- @return table|nil item The removed item.
--- @return table|nil pos The position of the removed item in the inventory.
function SectorInventoryObj:RemoveItem(slot_name, item, no_update)
	local item, pos = Inventory.RemoveItem(self, slot_name, item, no_update)	

	-- sync with sector data	
	local cdata = self:GetSectorContainerData()
	local items = cdata and cdata[3]
	table.remove_entry(items, item)
	
	self:ContainerChanged()

	return item, pos
end

--- Synchronizes the SectorInventoryObj's inventory with the sector container data.
---
--- This function iterates through the items in the sector container data and ensures that the SectorInventoryObj's inventory matches the data. It first removes any items from the inventory that are not present in the sector data, and then adds any items from the sector data that are not already in the inventory.
---
--- @param self SectorInventoryObj The SectorInventoryObj instance.
function SectorInventoryObj:SyncWithSectorInventory()
	local cdata = self:GetSectorContainerData()
	local items = cdata and cdata[3] or empty_table
	self:ForEachItem(function(item, slot_name, left, top, items) 
		if not table.find(items, item) then
			Inventory.RemoveItem(self, slot_name, item)
		end
	end, items)
	local slot_name = self.inventory_slots[1].slot_name
	for k, item in sorted_pairs(items) do
		if not self:HasItemInSlot(slot_name, item) then
			Inventory.AddItem(self, slot_name, item)
		end
	end
	self:ContainerChanged()
end

--- Notifies the SectorInventoryObj that the container has changed.
---
--- This function is called when the SectorInventoryObj's container has changed, such as when an item is added or removed. It triggers a `DespawnCheck` to ensure the container is properly updated.
---
--- @param self SectorInventoryObj The SectorInventoryObj instance.
function SectorInventoryObj:ContainerChanged()
	self:DespawnCheck()
end

--- Checks if the SectorInventoryObj should be despawned.
---
--- This function is called when the container of the SectorInventoryObj has changed, such as when an item is added or removed. It triggers a check to determine if the SectorInventoryObj should be despawned based on the current state of the container.
---
--- @param self SectorInventoryObj The SectorInventoryObj instance.
function SectorInventoryObj:DespawnCheck()
end

--- Sets the dynamic data of the SectorInventoryObj and synchronizes its inventory with the sector container data.
---
--- This function is called to update the SectorInventoryObj with new dynamic data. It triggers the `SyncWithSectorInventory` function to ensure the SectorInventoryObj's inventory matches the sector container data.
---
--- @param self SectorInventoryObj The SectorInventoryObj instance.
--- @param data table The new dynamic data for the SectorInventoryObj.
function SectorInventoryObj:SetDynamicData(data)
	self:SyncWithSectorInventory()
end

DefineClass.ItemContainer = {
	__parents = { "SectorInventoryObj", "Lockpickable", "BoobyTrappable" },
	flags = { efSelectable = true },
	inventory_slots = {
		{ slot_name = "Inventory", width = 4, height = 2, base_class = "InventoryItem", enabled = true, dont_save = true },
	},
	bOpened = false,
	interacting_unit = false,
}

--- Plays the "Spawn" FX when the ItemContainer is initialized.
---
--- This function is called when the ItemContainer is first created or loaded. It plays the "Spawn" FX to visually indicate the creation of the ItemContainer.
---
--- @param self ItemContainer The ItemContainer instance.
function ItemContainer:GameInit()
	PlayFX("Spawn", "start", self)
end

--- Plays the "Spawn" FX when the ItemContainer is finished.
---
--- This function is called when the ItemContainer is about to be destroyed or removed from the game. It plays the "Spawn" FX in reverse to visually indicate the removal of the ItemContainer.
---
--- @param self ItemContainer The ItemContainer instance.
function ItemContainer:Done()
	PlayFX("Spawn", "end", self)
end

--- Opens the ItemContainer.
---
--- This function is called when the ItemContainer is opened. It performs the following actions:
--- - Checks if the ItemContainer can be opened. If not, it plays the "Cannot Open" FX and returns.
--- - Checks if a trap is triggered. If so, it returns false.
--- - Plays the "Lockpickable" FX to indicate the opening of the ItemContainer.
--- - Resolves the interactable visual objects and updates their state to "open".
--- - Sets the `bOpened` flag to true.
--- - Updates the sector container data with the new opened state and the items in the ItemContainer.
---
--- @param self ItemContainer The ItemContainer instance.
--- @param unit table The unit interacting with the ItemContainer.
--- @return boolean True if the ItemContainer was successfully opened, false otherwise.
function ItemContainer:Open(unit)
	NetUpdateHash("ItemContainer:Open", self, self.lockpickState)
	if self:CannotOpen() then
		NetUpdateHash("ItemContainer:Open:CannotOpen")
		return self:PlayCannotOpenFX(unit)
	end
	
	if self:TriggerTrap(unit) then
		NetUpdateHash("ItemContainer:Open:TriggerTrap")
		return false
	end
	
	self:PlayLockpickableFX("open")
	
	local visuals = ResolveInteractableVisualObjects(self)
	for i,obj in ipairs(visuals) do
		NetUpdateHash("ItemContainer:Open_loop", i, obj, obj:GetStateText(), obj:GetEntity(), IsValidEntity(obj:GetEntity()), obj:HasState("open"))
		if obj:GetStateText() == "idle" and IsValidEntity(obj:GetEntity()) and obj:HasState("open") then
			if obj:HasState("opening") then
				local anim_duration = GetAnimDuration(obj, "opening")
				NetUpdateHash("ItemContainer:Open_Sleep", anim_duration, obj, obj:GetStateText())
				obj:SetState("opening")
				Sleep(anim_duration)
			end
			obj:SetState("open")
			break
		end
	end
	
	self.bOpened = true

	local cdata = self:GetSectorContainerData()
	if cdata then
		cdata[2] = self.bOpened
		-- add items
		local items = {}
		self:ForEachItem(function(item, slot_name, left, top, items)
			items[#items + 1] = item
		end, items)
		cdata[3] = items
	end
	
	return true
end
--- Returns whether the ItemContainer is opened or not.
---
--- @return boolean True if the ItemContainer is opened, false otherwise.

function ItemContainer:IsOpened()
	return self.bOpened
end

--- Returns the title of the item container.
---
--- @return string The title of the item container.
function ItemContainer:GetTitle()
	return T(532393878412, "Item container")
end

--- Returns the appropriate combat action for interacting with this ItemContainer.
---
--- @param unit Unit The unit attempting to interact with the ItemContainer.
--- @return CombatAction, string The combat action and icon to use for the interaction, or nil if no special action is required.
function ItemContainer:GetInteractionCombatAction(unit)
	if self.interacting_unit then return end
	
	local trapAction, icon = BoobyTrappable.GetInteractionCombatAction(self, unit)
	if trapAction then return trapAction, icon end
	
	if self:CannotOpen() then
		local baseAction = Lockpickable.GetInteractionCombatAction(self, unit)
		if baseAction then return baseAction end 
	end
	
	return Presets.CombatAction.Interactions.Interact_LootContainer
end

--- Registers a unit that is interacting with this ItemContainer.
---
--- @param unit Unit The unit that is interacting with the ItemContainer.
function ItemContainer:RegisterInteractingUnit(unit)
	assert(not self.interacting_unit)
	self.interacting_unit = unit
	self:DespawnCheck()
end

--- Registers the given unit as interacting with each of the provided containers, if the container is not already interacting with a unit.
---
--- @param containers table A table of ItemContainer instances.
--- @param unit Unit The unit to register as interacting with the containers.
function MultipleRegisterInteractingUnit(containers, unit)
	for i, container in ipairs(containers) do
		if not container.interacting_unit then
			container:RegisterInteractingUnit(unit)
		end
	end
end

--- Unregisters the unit that is currently interacting with this ItemContainer.
---
--- @param unit Unit The unit that was interacting with the ItemContainer.
function ItemContainer:UnregisterInteractingUnit(unit)
	assert(self.interacting_unit == unit)
	self.interacting_unit = nil
	self:DespawnCheck()
end

--- Unregisters the given unit as interacting with each of the provided containers, if the container is interacting with that unit.
---
--- @param containers table A table of ItemContainer instances.
--- @param unit Unit The unit to unregister as interacting with the containers.
function MultipleUnregisterInteractingUnit(containers, unit)
	for i, container in ipairs(containers) do
		if container.interacting_unit == unit then
			container:UnregisterInteractingUnit(unit)
		end
	end
end

--- Ends the interaction between the given unit and this ItemContainer.
---
--- @param unit Unit The unit that was interacting with the ItemContainer.
function ItemContainer:EndInteraction(unit)
	Interactable.EndInteraction(self, unit)
end

--- Updates the visual state of the ItemContainer based on its lockpick status.
---
--- If the ItemContainer cannot be opened, the visual state is set to "idle".
--- If the ItemContainer is open, the visual state is set to "open".
---
--- @param status string The current lockpick status of the ItemContainer.
function ItemContainer:LockpickStateChanged(status)
	local state = false
	if self:CannotOpen() then
		state = "idle"
	elseif status == "open" then
		state = "open"
	end
	if not state then return end
	
	local visuals = ResolveInteractableVisualObjects(self)
	for i,obj in ipairs(visuals) do
		if obj:HasState(state) then obj:SetState(state) end
	end
end

--- Sets the dynamic data of the ItemContainer.
---
--- If the ItemContainer is opened, the visual state of the interactable objects is set to "open".
---
--- @param data table The dynamic data to set for the ItemContainer.
--- @field data.bOpened boolean Whether the ItemContainer is opened or not.
function ItemContainer:SetDynamicData(data)
	self.bOpened = data.bOpened
	if self.bOpened then
		local visuals = ResolveInteractableVisualObjects(self)
		for i,obj in ipairs(visuals) do
			if obj:HasState("open") then
				obj:SetState("open")
			end
		end
	end
end

--- Gets the dynamic data of the ItemContainer.
---
--- If the ItemContainer is opened, the `bOpened` field is set in the provided `data` table.
---
--- @param data table The table to store the dynamic data of the ItemContainer.
function ItemContainer:GetDynamicData(data)
	if self.bOpened then
		data.bOpened = self.bOpened
	end
end

--- Handles the network event for opening a container.
---
--- @param container ItemContainer The container to open.
--- @param unit_id string The ID of the unit opening the container.
function NetSyncEvents.OpenContainer(container, unit_id)
	if not container then return end

	local unit = g_Units[unit_id]
	if not container:IsOpened() then
		container:Open(unit)
	end
end

function OnMsg.LockpickableBrokeOpen(self)
	-- Breaking an inventory objects incurs a condition penalty
	-- and a chance to destroy non guaranteed drop items.
	local destroyedAny
	if IsKindOf(self, "Inventory") then
		self:ForEachItem(function(item, slot_name, left, top)
			if IsKindOf(item, "ItemWithCondition") then
				local conditionDamage = 20 + InteractionRand(30, "Lockpick")
				self:ItemModifyCondition(item, -conditionDamage)
			end
			if not item.guaranteed_drop or IsKindOf(item, "QuestItem") then
				-- destroy some of the stack items
				if IsKindOf(item, "InventoryStack") then
					local oldAmount = item.Amount
					local percentRemoved = 20 + InteractionRand(30, "Lockpick")
					item.Amount = MulDivRound(item.Amount, percentRemoved, 100)
					item.Amount = Max(item.Amount, 1)
					
					destroyedAny = true
					CombatLog("debug", (oldAmount - item.Amount) .. " " .. item.class .. " were destroyed when opening box")
				end
			end
		end)
		ObjModified(self)
	end
	
	if destroyedAny then
		CombatLog("important", T(146944507889, "Some items were destroyed while attempting to open the box"))
	end
end

-- Handle destroying of item container visual objects dropping the loot on the ground.
function OnMsg.DamageDone(attacker, target, damage, hit_descr)
	if not target:IsDead() then return end -- Check if object died
	if not target:HasMember("spawner") or not IsKindOf(target.spawner, "ItemContainer") then return end -- Object is part of item container
	local spawner = target.spawner
	if not spawner:GetItemInSlot("Inventory") then return end -- Container has items in it
	if not spawner.enabled then return end
	
	-- All of the container's objects are dead (destroyed)
	local spawnerObjs = spawner.objects
	local allDead = true
	for i, o in ipairs(spawnerObjs) do
		if IsKindOf(o, "CombatObject") and not o:IsDead() then
			allDead = false
			break
		end
	end
	
	-- Drop guaranteed drop item, dump everything else.
	if allDead then
		local items = {}
		spawner:ForEachItemInSlot("Inventory", function(item, slot, left, top, items)
			if item.guaranteed_drop or IsKindOf(item, "QuestItem") then
				items[#items + 1] = item
			else
				CombatLog("debug", "Item " .. item.class .. " was destroyed when destroying box")
			end
		end, items)
		spawner:ClearSlot("Inventory")
		
		if #items > 0 then
			local container = GetDropContainer(spawner)
			for i, item in ipairs(items) do
				container:AddItem("Inventory", item)
			end
			local x, y, z = FindFallDownPos(container)
			if not x then return end
			CreateGameTimeThread(GravityFall, container, point(x, y, z))
		end
	end
end

-- ItemDropContainer
DefineClass.ItemDropContainer = {
	DisplayName = T(131517457472, "Dropped Items"),
	__parents = { "ItemContainer", "SyncObject", "GameDynamicSpawnObject" },
	entity = "JungleCamp_Backpack_01",
	flags = { efCollision = false, efApplyToGrids = false },
	despawn_time = 0,
	despawn_thread = false,
	discovered = true,
	bOpened = true,
	__toluacode = empty_func, --fixes assert when trying to generate game record with invalid item drop containers
}

---
--- Destroys the item drop container and cleans up any associated resources.
--- This function is called when the item drop container is no longer needed.
---
--- @param self ItemDropContainer The item drop container instance.
---
function ItemDropContainer:Done()
	DeleteThread(self.despawn_thread)
	self:UpdateInteractableBadge(false)
end

---
--- Returns the interaction position for the item drop container.
---
--- @param self ItemDropContainer The item drop container instance.
--- @param unit Unit The unit interacting with the item drop container.
--- @return table The positions where the unit can interact with the item drop container.
---
function ItemDropContainer:GetInteractionPos(unit)
	local positions = ItemContainer.GetInteractionPos(self, unit)
	if type(positions) == "table" then
		if unit and not table.find(positions, GetPassSlab(self)) then
			positions = ItemContainer.GetInteractionPos(self) -- return occupied positions too (backward compatibility)
		end
	end
	return positions
end

---
--- Determines whether the item drop container can be interacted with by the given unit.
---
--- The function checks if there are any items in the container's inventory. If the inventory is empty, the function returns `false`, disabling interaction.
---
--- If a unit is provided, the function also checks if there is another unit standing on the same tile as the item drop container. If another unit is present, the function returns `false`, disabling interaction.
---
--- This is done to prevent multiple players from interacting with the same item drop container at the same time, which could lead to inconsistencies in the container's state.
---
--- @param self ItemDropContainer The item drop container instance.
--- @param unit Unit The unit attempting to interact with the item drop container.
--- @return boolean Whether the item drop container can be interacted with.
---
function ItemDropContainer:GetInteractionCombatAction(unit)
	-- Disable interaction when there is another unit on the container tile,
	-- because the unit on the tile could drop items without interacting with the container.
	-- Only one player could view/change the container at a time.
	-- We do it for both single and multiplayer for consistency, but it's required only to
	-- disable interaction when the other player controlled unit is on the tile.
	if not next(self.Inventory) then
		return false
	end
	if unit then
		local mypos = point_pack(SnapToVoxel(self:GetPosXYZ()))
		local upos = point_pack(SnapToVoxel(unit:GetPosXYZ()))
		if upos ~= mypos then
			local x, y = point_unpack(mypos)
			local tile_unit = MapGetFirst(x, y, const.SlabSizeX/2, "Unit", function(u, mypos)
				return not u:IsDead() and mypos == point_pack(SnapToVoxel(u:GetPosXYZ()))
			end, mypos)
			if tile_unit then
				return false
			end
		end
	end
	return ItemContainer.GetInteractionCombatAction(self, unit)
end

---
--- Checks if the item drop container should be despawned.
---
--- The container is despawned if there is no unit interacting with it and its inventory is empty.
---
--- When the container is despawned, it is removed from the game after a delay specified by the `despawn_time` property.
---
--- @param self ItemDropContainer The item drop container instance.
---
function ItemDropContainer:DespawnCheck()
	local despawn = not self.interacting_unit and not next(self.Inventory)
	if despawn == IsValidThread(self.despawn_thread) then
		return
	end
	if despawn then
		NetUpdateHash("DespawnCheck", self)
		self.despawn_thread = CreateGameTimeThread(function(self)
			Sleep(self.despawn_time)
			self.despawn_thread = nil
			DoneObject(self)
		end, self)
	else
		DeleteThread(self.despawn_thread)
		self.despawn_thread = false
	end
end

-- walks through all item containers in that sector
DefineClass.SectorStash = {
	__parents = { "Inventory" },
	inventory_slots = {
		{slot_name = "Inventory",  width = 4, height = 1, base_class = "InventoryItem", enabled = true },
	},
	sector_id = false,
	pickup_netsent = false,
	DisplayName = T(660371035462, "Sector stash"),
}

---
--- Resets the binding of the SectorStash container.
---
--- This function is used to clear the container and set a new sector ID. It is necessary because the traditional inventory structure of this container is not sync ordered, which means that enumeration functions will iterate over it in an asynchronous order. However, the "virtual" container data should be the same, so this function rebuilds the async container before performing the sync operation.
---
--- @param self SectorStash The SectorStash instance.
---
function SectorStash:ResetBinding()
	--the traditional inventory structure of this container is not sync ordered, therefore enum funcs with it will iterate in an async order;
	--however the "virtual" container data should be the same
	--so, rebuild async container before sync op
	local id = self.sector_id
	self:Clear()
	self:SetSectorId(id)
end

---
--- Gets the slot data dimensions for the specified slot name.
---
--- @param self SectorStash The SectorStash instance.
--- @param slot_name string The name of the slot.
--- @return number width The width of the slot.
--- @return number height The height of the slot.
--- @return number depth The depth of the slot.
---
function SectorStash:GetSlotDataDim(slot_name)
	local slot_data = self:GetSlotData(slot_name)
	local width = slot_data.width
	local count = #self[slot_name] + 2 --self:CountItemsInSlot(slot_name)*2 -- pretend all are 2 tiles length
	local height = count/width + (count%width==0 and 0 or 1) + 1
	local height = Max(self:GetMaxTopPos(slot_name), height)
	height = Max(4, height)
	return width, height, width
end

---
--- Gets the maximum top position of items in the specified slot.
---
--- This function is used to determine the maximum top position of items in a slot, which is necessary for calculating the slot's height. It iterates through the items in the slot and keeps track of the maximum top position encountered.
---
--- @param self SectorStash The SectorStash instance.
--- @param slot_name string The name of the slot.
--- @return number max The maximum top position of items in the slot.
---
function SectorStash:GetMaxTopPos(slot_name)
	local items = self[slot_name]
	if not next(items) then return 1 end
	local slot_data = self:GetSlotData(slot_name)
	local max = 0
	for i = #items, 1, -2 do
		local item, pos = items[i], items[i-1]
		local l,t = point_unpack(pos)
		max = Max(max, t)
	end
	return max
end

---
--- Clears the SectorStash instance.
---
--- This function is used to reset the SectorStash instance to its initial state. It removes the current inventory slot, resets the sector ID, and creates a new inventory slot.
---
--- @param self SectorStash The SectorStash instance.
---
function SectorStash:Clear()
	local invSlot = self["Inventory"]
	if not IsKindOf(invSlot, "InventorySlot") then return end
	DoneObject(invSlot)
	invSlot = false
	self.sector_id = false
	self["Inventory"] = InventorySlot:new()
end

---
--- Gets the virtual container data for the current sector.
---
--- This function is used to retrieve the data for the virtual container associated with the current sector. It first checks if the `gv_Sectors` table exists and if the current sector ID is valid. If so, it retrieves the `sector_inventory` table from the sector data. It then searches the `sector_inventory` table for an entry with the "virtual" key, and returns the entry, the `sector_inventory` table, and the index of the entry if found.
---
--- @param self SectorStash The SectorStash instance.
--- @return table|nil cdata The virtual container data, or `nil` if not found.
--- @return table|nil sector_inventory The sector inventory table, or `nil` if not found.
--- @return number|nil idx The index of the virtual container data in the sector inventory table, or `nil` if not found.
---
function SectorStash:GetVirtualContainerData()
	local sector = gv_Sectors and gv_Sectors[self.sector_id]
	local sector_inventory = sector and sector.sector_inventory
	local idx = table.find(sector_inventory, 1, "virtual")
	if idx then
		return sector_inventory[idx], sector_inventory, idx
	end
end

---
--- Adds items from the dead units in the current sector to the inventory.
---
--- This function iterates through the list of dead units in the current sector and adds any items in their "InventoryDead" slot to the inventory. The function can optionally filter the items to be added using the provided `filter` function.
---
--- @param self SectorStash The SectorStash instance.
--- @param filter function|nil A function that takes an item as an argument and returns a boolean indicating whether the item should be added to the inventory.
---
function SectorStash:AddDeadUnitsItems(filter)
	if not gv_Sectors or not self.sector_id then
		return
	end
	local units_list = gv_Sectors[self.sector_id].dead_units
	for _, session_id in ipairs(units_list) do
		local ud = gv_UnitData[session_id]
		if ud and ud:IsDead() then
			ud:ForEachItemInSlot("InventoryDead", function(item, slot, left, top, self)
				if not filter or filter(item) then
				Inventory.AddItem(self, "Inventory", item)
				end
			end, self)
		end
	end
end

---
--- Removes an item from the dead units in the current sector.
---
--- This function iterates through the list of dead units in the current sector and removes the specified item from their "InventoryDead" slot. If the item is found, it returns the item and its position in the inventory.
---
--- @param self SectorStash The SectorStash instance.
--- @param item table The item to remove.
--- @return table|nil itm The removed item, or `nil` if not found.
--- @return number|nil pos The position of the removed item in the inventory, or `nil` if not found.
---
function SectorStash:RemoveDeadUnitsItem(item)
	if not gv_Sectors or not self.sector_id then
		return
	end
	local found = false
	local itm, pos
	local units_list = gv_Sectors[self.sector_id].dead_units
	for _, session_id in ipairs(units_list) do
		local ud = gv_UnitData[session_id]
		if ud and ud:IsDead() then
			itm, pos = ud:RemoveItem("InventoryDead", item)	
			if itm then
				found = true
				break
			end
		end
	end
	return itm, pos
end

---
--- Adds a virtual container to the sector inventory.
---
--- This function checks if a virtual container already exists for the current sector. If not, it creates a new virtual container and adds it to the sector inventory. The virtual container is represented as a table with the following structure:
---
--- 
--- { "virtual", true, { item1, item2, ... } }
--- 
---
--- The first element is the string "virtual" to identify it as a virtual container. The second element is a boolean flag indicating that this is a virtual container. The third element is a table containing the items in the virtual container.
---
--- @param self SectorStash The SectorStash instance.
--- @return table cdata The virtual container data.
--- @return number idx The index of the virtual container in the sector inventory.
---
function SectorStash:AddVirtualContainer()
	if not gv_Sectors or not self.sector_id then
		return
	end
	local cdata, sector_inventory, idx = self:GetVirtualContainerData()
	if not cdata then
		cdata = { "virtual", true }
		local sector = gv_Sectors[self.sector_id]
		if not sector then
			sector = {}
			gv_Sectors[self.sector_id] = sector
		end
		sector.sector_inventory = sector.sector_inventory or {}
		sector_inventory = sector.sector_inventory 
		table.insert(sector.sector_inventory, cdata)
	end
	return cdata, #sector_inventory
end

---
--- Sets the sector ID for the SectorStash instance and populates it with items from the sector inventory.
---
--- This function first checks if the current sector ID is the same as the provided sector ID. If they are the same, the function returns without doing anything.
---
--- If the sector ID is different, the function clears the current SectorStash instance, sets the new sector ID, and then adds the dead units' items and the virtual container to the SectorStash. Finally, it iterates through the sector inventory and adds any open containers' items to the SectorStash.
---
--- @param self SectorStash The SectorStash instance.
--- @param sector_id number The new sector ID.
--- @param filter function (optional) A function to filter the items to be added to the SectorStash.
---
function SectorStash:SetSectorId(sector_id, filter)
	local sector_id = sector_id or gv_CurrentSectorId	
	
	if self.sector_id == sector_id then
		return
	end
	
	self:Clear()
	
	self.sector_id = sector_id
	self:AddDeadUnitsItems(filter)
	local containers = gv_Sectors[sector_id].sector_inventory or empty_table
	self:AddVirtualContainer()
	for cidx, container in ipairs(containers) do
		if container[2] then -- opened
			local items = container[3] or empty_table
			for idx, item in sorted_pairs(items) do
				if not filter or filter(item) then
					Inventory.AddItem(self,"Inventory", item)
				end
			end
		end
	end
end

---
--- Adds an item to the SectorStash's virtual container or the sector inventory.
---
--- If the virtual container data does not exist, the item is added to the sector inventory using the `AddToSectorInventory` function.
---
--- If the virtual container data exists, the item is added to the virtual container's item list. If the item already exists in the list, its position is updated.
---
--- The item is then added to the SectorStash's inventory using the `Inventory.AddItem` function, with the specified left and top coordinates if provided.
---
--- @param self SectorStash The SectorStash instance.
--- @param slot_name string The name of the slot to add the item to.
--- @param item table The item to be added.
--- @param left number (optional) The left coordinate of the item in the slot.
--- @param top number (optional) The top coordinate of the item in the slot.
--- @param local_execution boolean (optional) Whether the operation should be executed locally.
--- @param use_pos boolean (optional) Whether to use the specified left and top coordinates.
--- @return number, number The x and y coordinates of the added item.
---
function SectorStash:AddItem(slot_name, item, left, top, local_execution, use_pos)
	-- add to virtual container	
	local cdata = self:GetVirtualContainerData()
	if not cdata then
		AddToSectorInventory(self.sector_id, item)
	end	

	if cdata then
		cdata[3] = cdata[3] or {}
		local val, idx = table.find_value(cdata[3], item)
		if val then
			cdata[3][idx]=item -- if something is changed
		else
			table.insert(cdata[3], item)
		end	
	end
	local x, y
	if left then
		x, y = left, top
	end
	return Inventory.AddItem(self,"Inventory", item, x, y)
end

---
--- Removes an item from the SectorStash's virtual container or the sector inventory.
---
--- If the item is found in the virtual container, it is removed from the container's item list. If the item is not found in the virtual container, it is removed from the sector inventory using the `Inventory.RemoveItem` function.
---
--- If the item is found in the dead units list, it is removed from there and returned.
---
--- @param self SectorStash The SectorStash instance.
--- @param slot_name string The name of the slot to remove the item from.
--- @param item table The item to be removed.
--- @param no_update boolean (optional) Whether to skip updating the inventory after removing the item.
--- @return table, number The removed item and its position.
---
function SectorStash:RemoveItem(slot_name, item, no_update)
	local _, pos = Inventory.RemoveItem(self, slot_name, item, no_update)
	-- remove from dead units
	local itm, pos = self:RemoveDeadUnitsItem(item)
	if itm then 
		return itm , pos
	end	
	--remove from container	

	local containers = gv_Sectors[self.sector_id].sector_inventory or empty_table
	local found = false
	for cidx, container in ipairs(containers) do
		local items = container[3] or empty_table
		for i = #items, 1, -1 do
			if items[i]==item then
				table.remove(items, i)
				if container[1]~= "virtual" then
					local obj = HandleToObject[container[1]]
					if IsKindOf(obj, "SectorInventoryObj") then 
						obj:SyncWithSectorInventory()
--[[				else -- debug
						for i, obj in sorted_pairs(HandleToObject) do
							if IsKindOf(obj, "SectorInventoryObj") then
								if obj:GetItemPos(item) then
									print("change container handle")
									gv_Sectors[self.sector_id].sector_inventory[cidx][1] = obj:GetHandle()
									obj:SyncWithSectorInventory()
								end
							end
						end
--]]						
					end
				end
				found = true
				break
			end
		end
		if found then
			break
		end	
	end
	return item, pos
end

--- Returns the maximum number of tiles that can be stored in the specified slot.
---
--- @param self SectorStash The SectorStash instance.
--- @param slot_name string The name of the slot.
--- @return number The maximum number of tiles that can be stored in the slot.
function SectorStash:GetMaxTilesInSlot(slot_name)
	local width, height = self:GetSlotDataDim(slot_name)
	return width*height
end

------------------------------------------------------------------------------------------------------------
---
--- Adds items to the sector inventory.
---
--- @param sector_id string The ID of the sector to add the items to.
--- @param items table A table of items to add to the sector inventory.
---
function AddToSectorInventory(sector_id, items)
	if not gv_Sectors then
		return		
	end
	local sector = gv_Sectors and gv_Sectors[sector_id]
	local sector_inventory = sector and sector.sector_inventory
	local idx = sector_inventory and table.find(sector_inventory, 1, "virtual")
	local virtual = idx and sector_inventory[idx]
	
	if not virtual then
		virtual = { "virtual", true }
		if not sector then
			sector = {}
			gv_Sectors[sector_id] = sector
		end
		sector.sector_inventory  =  sector.sector_inventory  or {}
		sector_inventory = sector.sector_inventory 
		table.insert(sector.sector_inventory, virtual)
	end
	if virtual then
		virtual[3] = virtual[3] or {}
		for _, item in ipairs(items) do
			local val, idx = table.find_value(virtual[3], item)
			if val then
				virtual[3][idx] = item -- if something is changed
			else
				table.insert(virtual[3], item)
			end	
		end
	end
end


--- Checks if the specified sector or all sectors contain the given item and amount.
---
--- @param sector_id string The ID of the sector to check, or "all_sectors" to check all sectors.
--- @param item_id string The class ID of the item to check for.
--- @param amount number The minimum amount of the item to check for.
--- @return boolean True if the sector(s) contain at least the specified amount of the item, false otherwise.
function SectorContainersHasItem(sector_id, item_id, amount)
	local sector_id = sector_id or gv_CurrentSectorId
	if not sector_id then
		return false
	end
	local cur_amount = 0
	if sector_id=="all_sectors" then
		for sector_id, data in gv_Sectors do
			local containers = data.sector_inventory or empty_table
			for cidx, container in ipairs(containers) do
				if container[2] then
					local items = container[3] or empty_table
					for idx, item in ipairs(items) do
						if item.class == item_id then
							cur_amount = cur_amount + (IsKindOf(item, "InventoryStack") and item.Amount or 1)
							if cur_amount >= amount then
								return true
							end	
						end	
					end	
				end
			end	
		end
		return false	
	else
		local containers = gv_Sectors[sector_id] and gv_Sectors[sector_id].sector_inventory or empty_table
		local cur_amount = 0
		for cidx, container in ipairs(containers) do
			if container[2] then
				local items = container[3] or empty_table
				for idx, item in ipairs(items) do
					if item.class == item_id then
						cur_amount = cur_amount + (IsKindOf(item, "InventoryStack") and item.Amount or 1)
						if cur_amount >= amount then
							return true
						end	
					end	
				end
			end
		end	
		return false
	end
end


---
--- Executes a function for each sector item container in the current sector.
---
--- @param fn function The function to execute for each container. The function should take the container object as the first argument, and any additional arguments passed to ExecSectorItemContainers.
--- @param ... any Additional arguments to pass to the function.
--- @return string "break" if the function returned "break", otherwise nil.
---
function ExecSectorItemContainers(fn, ...)
	local containers = gv_Sectors[gv_CurrentSectorId].sector_inventory or empty_table
	for _,container in ipairs(containers) do
		local handle = container[1]
		local obj = HandleToObject[handle]
		local res
		res = fn(obj, ...)
		if res=="break" then
			return "break"
		end
	end	
end

---
--- Removes the specified item from the inventories of the given mercs up to the specified count.
---
--- @param mercs table An array of merc IDs.
--- @param item_id string The ID of the item to remove.
--- @param count number The maximum number of items to remove.
--- @param callback_on_take function An optional callback function to call after each item is removed. The callback will receive the following arguments: the merc unit, the removed item, the amount removed, and any additional arguments passed to TakeItemFromMercs.
--- @param ... any Additional arguments to pass to the callback function.
--- @return number The remaining count of items that could not be removed.
---
function TakeItemFromMercs(mercs, item_id, count, callback_on_take, ...)
	local args = {...}
	local amount = {count = count}
	for idx, merc in ipairs(mercs) do
		local unit = gv_UnitData[merc]
		local unit_amount = 0
		unit:ForEachItemDef(item_id, function(item, slot, amount)
			local is_stack = IsKindOf(item, "InventoryStack")
			local val = is_stack and item.Amount or 1
			local remove = Min(amount.count, val)
			amount.count = amount.count - remove
			if val == remove then
				unit:RemoveItem(slot, item)
			elseif is_stack then -- item.Amount > remove
				item.Amount = item.Amount - remove
			end
			unit_amount = unit_amount + remove
			ObjModified(unit)
			if callback_on_take then
				callback_on_take(unit, item, unit_amount, table.unpack(args))
			end
			if amount.count <= 0 then
				return "break"
			end	
		end, amount)
		if amount.count <= 0 then
			break
		end
	end
	for idx, merc in ipairs(mercs) do
		local unit = gv_UnitData[mercs[idx]]
		if not unit then return end
		amount.count = TakeItemFromSquadBag(unit.Squad, item_id, amount.count, callback_on_take,...)	
	end	
	return amount.count
end

---
--- Removes the specified item from the sector inventory up to the specified count.
---
--- @param sector table The sector object containing the inventory.
--- @param item_id string The ID of the item to remove.
--- @param count number The maximum number of items to remove.
--- @return number The remaining count of items that could not be removed.
---
function TakeItemFromSectorInventory(sector, item_id, count)
	local containers = sector.sector_inventory or empty_table
	for cidx, container in ipairs(containers) do
		if container[2] then -- is opened
			local items = container[3] or empty_table
			for idx = #items, 1, -1 do
				local item = items[idx]
				if item and item.class == item_id then
					local is_stack = IsKindOf(item, "InventoryStack")
					local val = is_stack and item.Amount or 1
					local remove = Min(count, val)
					count = count - remove
					if val == remove then
						table.remove(items, idx)
						if gv_CurrentSectorId==sector.Id then
							local obj = HandleToObject[container[1]]
							if obj then 
								obj:SyncWithSectorInventory() 
							end
						end
					elseif is_stack then -- item.Amount > remove
						item.Amount = item.Amount - remove
					end
					if count <= 0 then
						return 0
					end
				end
			end
		end
	end
	return count
end

---
--- Checks if the specified item is present in the squad of the given unit, optionally checking all squads on the same side.
---
--- @param unit_id string The ID of the unit to check.
--- @param ItemId string The ID of the item to check for.
--- @param Amount number The minimum amount of the item to check for.
--- @param AnySquad boolean If true, checks all squads on the same side as the given unit.
--- @return boolean, number Whether the item is present in the required amount, and the total amount found.
---
function HasItemInSquad(unit_id, ItemId, Amount, AnySquad)
	if not unit_id then 
		return false 
	end
	local all_mercs = false
	local squad = unit_id and gv_UnitData[unit_id] and gv_UnitData[unit_id].Squad
	local squads = {}
	if squad then
		if AnySquad then
			local side = gv_Squads[squad].Side
			all_mercs = {}
			for _, sqd in pairs(gv_Squads) do
				if sqd.Side == side then
					table.iappend(all_mercs, sqd.units)
					squads[#squads + 1] = sqd.UniqueId
				end
			end	
		else	
			all_mercs = table.copy(gv_Squads[squad].units)
			squads[#squads + 1] = squad
		end
		table.remove_entry(all_mercs, unit_id)
		table.insert(all_mercs, 1, unit_id) -- prioritize unit_id
	else
		all_mercs = GetAllPlayerUnitsOnMapSessionId()
		squads = table.imap(g_PlayerSquads,"UniqueId")
	end
	
	local calc_all = type(Amount)~= "number" 
	local amount = 0
	for idx, merc in ipairs(all_mercs) do
		local unit = gv_UnitData[merc]
		if unit then
			unit:ForEachItemDef(ItemId, function(item, slot, self_Amount)
				amount = amount + (item.Amount or 1)
				if not calc_all and amount >= self_Amount then
					return "break"
				end	
			end, Amount)
		end
		if not calc_all and amount >= Amount then
			return true
		end	
	end
	for _, squad in ipairs(squads) do
		local bag = GetSquadBag(squad) or empty_table
		for _, item in ipairs(bag) do
			if item.class == ItemId then
				amount = amount + (item.Amount or 1)
			end
		end
	end
	if not calc_all then
		return amount >= Amount, amount
	end	
	return true, amount
end

---
--- Synchronizes the item containers on the map with the sector inventory.
--- This function is called when the item containers need to be updated to reflect changes in the sector inventory.
---
--- @function NetSyncEvents.SyncItemContainers
--- @return nil
function NetSyncEvents.SyncItemContainers()
	if not gv_Sectors then return end
	MapForEach("map", "ItemContainer", function(o) 
		o:SyncWithSectorInventory()
	end)
end

---
--- Checks the usage of loot tables in the game, including:
--- - Identifying undefined loot tables
--- - Identifying unused loot tables
--- - Ignoring certain loot table groups
---
--- @function TestLootTablesUsage
--- @return table, table, table
---   - undefinedLootTables: a table of loot table IDs that are not defined
---   - unusedLootTables: a table of loot tables that are not used
---   - lootTableGroupsToIgnore: a table of loot table groups to ignore
function TestLootTablesUsage()
	local lootTablesPreset = {}
	local undefinedLootTables = {}
	local unusedLootTables = {}
	ForEachPreset("LootDef", function(lootTablePreset)
		table.insert(unusedLootTables, lootTablePreset)
		table.insert(lootTablesPreset, lootTablePreset)
	end)
	
	local function DoesLootTableIdExist(id, obj)
		if not table.find(lootTablesPreset, "id", id) then
			table.insert(undefinedLootTables, { id, obj })
		end
	end
	
	local function IsLootTableIdUsed(id)
		unusedLootTables = table.ifilter(unusedLootTables, function(idx, lootTable)
			local foundInSubItems
			for _, subItem in ipairs(lootTable) do
				if IsKindOf(subItem, "LootEntryLootDef") then
					if subItem.loot_def == id then
						foundInSubItems = true
						break
					end
				end
			end
			return id ~= lootTable.id and not foundInSubItems
		end)
	end
	
	--for each marker in markers.debug.lua on every map check used Loot Tables
	for _, markersOnMap in pairs(g_DebugMarkersInfo) do
		for	_, marker in ipairs(markersOnMap) do
			for _, lootTableId in ipairs(marker.LootTableIds) do
				DoesLootTableIdExist(lootTableId, marker)
				IsLootTableIdUsed(lootTableId)
			end
		end
	end
	
	--for each quest preset check used Loot Tables
	ForEachPreset("QuestsDef", function (questPreset)
		questPreset:ForEachSubObject("LootTableFunctionObjectBase", function(lootTable, parents)
			if lootTable.LootTableId then
				DoesLootTableIdExist(lootTable.LootTableId, questPreset)
				IsLootTableIdUsed(lootTable.LootTableId)
			end
		end)
	end)
	
	--for each conv preset check used Loot Tables
	ForEachPreset("Conversation", function (convPreset)
		convPreset:ForEachSubObject("LootTableFunctionObjectBase", function(lootTable, parents)
			if lootTable.LootTableId then
				DoesLootTableIdExist(lootTable.LootTableId, convPreset)
				IsLootTableIdUsed(lootTable.LootTableId)
			end
		end)
	end)
	
	--ignore these loot table groups
	local lootTableGroupsToIgnore = empty_table
	unusedLootTables = table.ifilter(unusedLootTables, function(idx, lootTable) return not table.find(lootTableGroupsToIgnore, lootTable.Group) end)
	
	return undefinedLootTables, unusedLootTables, lootTableGroupsToIgnore
end

-- all loot table id related Conditions & Effects inherit this class
DefineClass.LootTableFunctionObjectBase = { __parents = { "PropertyObject" } }