local equip_slots = {
	["Handheld A"] = true,	
	["Handheld B"] = true,
	["Head"] = true,
	["Torso"] = true,
	["Legs"] = true,
}

--- Checks if the given slot name is an equipment slot.
---
--- @param slot_name string The name of the slot to check.
--- @return boolean True if the slot is an equipment slot, false otherwise.
function IsEquipSlot(slot_name)
	return equip_slots[slot_name]
end

--- Checks if the given slot name is a weapon slot.
---
--- @param slot_name string The name of the slot to check.
--- @return boolean True if the slot is a weapon slot, false otherwise.
function IsWeaponSlot(slot_name)
	return slot_name=="Handheld A" or slot_name=="Handheld B"
end

--- Gets the list of equipment slots that the given item can be equipped in.
---
--- @param item table The item to check for equippable slots.
--- @return table A table of slot names that the item can be equipped in.
function GetSlotsToEquipItem(item)
	if not item then return end
	local canequipslots = {}
	local slots = UnitInventory.inventory_slots
	for _, slot_data in ipairs(slots) do
		local slot_name = slot_data.slot_name
		if IsEquipSlot(slot_name) then
			local base_class = slot_data.base_class
			if item:IsKindOfClasses(base_class) and (not slot_data.check_slot_name or item.Slot==slot_name) then
				canequipslots[#canequipslots +1] = slot_name
			end	
		end
	end
	return canequipslots
end

DefineClass.UnitInventory = {
	__parents = { "Inventory" },
	inventory_slots = {
		{ slot_name = "Inventory",     width = 6, height = 4, base_class = "InventoryItem", enabled = true },
		{ slot_name = "InventoryDead", width = 4, height = 6, base_class = "InventoryItem", enabled = true },
		{ slot_name = "Pick",          width = 2, height = 1, base_class = "InventoryItem", enabled = true },
		{ slot_name = "Handheld A",    width = 2, height = 1, base_class = {"Firearm","MeleeWeapon","HeavyWeapon","QuickSlotItem"}, enabled = true },
		{ slot_name = "Handheld B",    width = 2, height = 1, base_class = {"Firearm","MeleeWeapon","HeavyWeapon","QuickSlotItem"}, enabled = true },
		{ slot_name = "Head",          width = 1, height = 1, base_class = "Armor", check_slot_name = true, enabled = true },
		{ slot_name = "Torso",         width = 1, height = 1, base_class = "Armor", check_slot_name = true, enabled = true },
		{ slot_name = "Legs",          width = 1, height = 1, base_class = "Armor", check_slot_name = true, enabled = true },
		{ slot_name = "SetpieceWeapon",width = 2, height = 1, base_class = {"Firearm","MeleeWeapon","HeavyWeapon"}, enabled = true },
	},
	properties = {
		{ id = "current_weapon", editor = "text", default =  "Handheld A"},
	},
	pick_slot_item_src = false,
}

---
--- Gets the maximum number of tiles in the specified inventory slot.
---
--- @param slot_name string The name of the inventory slot.
--- @return integer The maximum number of tiles in the specified slot.
function UnitInventory:GetMaxTilesInSlot(slot_name)
	if slot_name=="Inventory" then
		return self:GetInventoryMaxSlots()
	elseif slot_name=="InventoryDead" then
		local max_slots = self.max_dead_slot_tiles or 24
		local rem = max_slots % 4
		if rem > 0 then
			max_slots = max_slots + 4 - rem
		end
		
		return max_slots
	else
		return Inventory.GetMaxTilesInSlot(self,slot_name)
	end
end

---
--- Adds an item to the specified inventory slot.
---
--- @param slot_name string The name of the inventory slot to add the item to.
--- @param item InventoryItem The item to add to the inventory.
--- @param left number The horizontal position of the item in the slot.
--- @param top number The vertical position of the item in the slot.
--- @param local_execution boolean Whether the item addition is being executed locally.
--- @return boolean, string Whether the item was successfully added, and the reason if not.
---
function UnitInventory:AddItem(slot_name, item, left, top, local_execution)
	local pos, reason = Inventory.AddItem(self, slot_name, item, left, top)
	if not pos then return pos, reason end
	
	item.owner = IsMerc(self) and self.session_id or false -- Dont bloat save with non-merc owners.
	if not local_execution then
		Msg("ItemAdded", self, item, slot_name, pos)
	end
	item:OnAdd(self, slot_name, pos, item)

	return pos, reason
end

-- add already generated items (from loot table) into inventory, stack them if can
---
--- Adds a list of items to an inventory object.
---
--- @param inventoryObj UnitInventory The inventory object to add the items to.
--- @param items table A table of InventoryItem objects to add to the inventory.
--- @param bLog boolean Whether to log the addition of the items to the inventory.
--- @return boolean, string Whether the items were successfully added, and the reason if not.
---
function AddItemsToInventory(inventoryObj, items, bLog)
	local pos, reason
	for i = #items, 1, -1 do
		local item =  items[i]
		if IsKindOf(item, "InventoryStack") then
			inventoryObj:ForEachItemDef(item.class, 
				function(curitm, slot_name, item_left, item_top)
					if slot_name~="Inventory" then return end
					
				   if curitm.Amount < curitm.MaxStacks then
						local to_add = Min(curitm.MaxStacks - curitm.Amount, item.Amount)
						curitm.Amount =curitm.Amount + to_add
						curitm.drop_chance = Max(curitm.drop_chance, item.drop_chance)
						if bLog then
							Msg("InventoryAddItem", inventoryObj, curitm, to_add)
						end
						item.Amount =  item.Amount - to_add			
						if item.Amount <= 0 then
							DoneObject(item)
							item = false
							table.remove(items, i)
							return "break"
						end
					end
				end)
		end
		if item then 
			pos, reason = inventoryObj:AddItem("Inventory", item)
			if pos then
				if bLog then
					Msg("InventoryAddItem", inventoryObj, item, IsKindOf(item, "InventoryStack") and item.Amount or 1)
				end
				table.remove(items, i)
			end
		else
			pos = true
		end				
	end
	ObjModified(inventoryObj)
	return pos, reason
end

---
--- Adds a list of items to the unit's inventory.
---
--- @param items table A table of InventoryItem objects to add to the inventory.
--- @return boolean, string Whether the items were successfully added, and the reason if not.
---
function UnitInventory:AddItemsToInventory(items)
	return AddItemsToInventory(self, items, true)
end


function OnMsg.InventoryAddItem(unit, item, amount)
	LogGotItem(unit, item, amount)
end

GameVar("g_GossipItemsTakenByPlayer",{})
GameVar("g_GossipItemsSeenByPlayer",{})
GameVar("g_GossipItemsEquippedByPlayer",{})
GameVar("g_GossipItemsMoveFromPlayerToContainer",{})

function OnMsg.InventoryTakeAllAddItem(unit, item, amount, bAutoResolve)
	local item_id = item.id
	if not g_GossipItemsTakenByPlayer[item_id] and (bAutoResolve or g_GossipItemsSeenByPlayer[item_id]) then
		NetGossip("Loot","TakeByPlayer", item.class, amount, GetCurrentPlaytime(), Game and Game.CampaignTime)
		g_GossipItemsTakenByPlayer[item_id] = true
	end
	LogGotItem(unit, item, amount)
end

function OnMsg.SquadBagAddItem(item, amount)
	LogGotItem(false, item, amount)
end

function OnMsg.SquadBagTakeAllAddItem(item, amount, bAutoResolve)
	local item_id = item.id
	if not g_GossipItemsTakenByPlayer[item_id] and (bAutoResolve or g_GossipItemsSeenByPlayer[item_id])then
		NetGossip("Loot","TakeByPlayer", item.class, amount, GetCurrentPlaytime(), Game and Game.CampaignTime)
		g_GossipItemsTakenByPlayer[item_id] = true
	end	
	LogGotItem(false, item, amount)
end

if FirstLoad then
	DeferredItemLog = false
	CombatLogActorOverride = false
end

function OnMsg.NewGame()
	DeferredItemLog = false
	CombatLogActorOverride = false
end

---
--- Formats an item log entry for display, with different formatting depending on whether the item was taken by a unit or added to the squad bag.
---
--- @param itemLog table The item log entry to format.
--- @param unit Unit|nil The unit that took the item, or nil if the item was added to the squad bag.
--- @param isSingleEntry boolean Whether this is a single entry or part of a list of entries.
--- @return string The formatted item log entry.
---
TFormat.ItemLog = function(itemLog, unit, isSingleEntry)
	local amount = itemLog.amount or 1
	local itemNameT
	if amount > 1 then
		itemNameT = itemLog.item.DisplayNamePlural
	else
		itemNameT = itemLog.item.DisplayName
	end
	
	local res 
	if isSingleEntry then
		if unit then
			if IsKindOf(unit, "SectorStash") then
				res = T(585970067597, "Some of the items were placed in the sector stash")
			else	
				res = T{849649099073, " <amount> x <em><itemNameT></em> taken by <mercName>", amount = amount, itemNameT = itemNameT, mercName = unit:GetDisplayName()}
			end
		else
			res = T{359344947585, " <amount> x <em><itemNameT></em> added in the squad bag", amount = amount, itemNameT = itemNameT}
		end
	else
		if unit then
			if IsKindOf(unit, "SectorStash") then
				res = T(585970067597, "Some of the items were placed in the sector stash")
			else	
				res = T{581384045758, " <amount> x <em><itemNameT></em> (<mercName>)", amount = amount, itemNameT = itemNameT, mercName = unit:GetDisplayName()}
			end
		else
			res = T{437609056132, " <amount> x <em><itemNameT></em> (squad bag)", amount = amount, itemNameT = itemNameT}
		end
	end
	return res
end

---
--- Logs the acquisition of an item by a unit.
---
--- @param unit Unit|nil The unit that acquired the item, or nil if the item was added to the squad bag.
--- @param item BaseItem The item that was acquired.
--- @param amount number The amount of the item that was acquired.
---
function LogGotItem(unit, item, amount)
	if not item then return end
	--allow logs of ammo, parts and meds
	--if not IsKindOf(unit, "Unit") then return false end
	
	amount = amount or 1
	local actor = CombatLogActorOverride or "short"
	local logItem = { 
		unit = unit,
		item = item,
		amount = amount,
		actor = actor,
	}
	
	if DeferredItemLog then
		DeferredItemLog[#DeferredItemLog + 1] = logItem
		return
	end
	
	DeferredItemLog = { logItem }
	CreateRealTimeThread(function()
		Sleep(1)
		local text = false
		if #DeferredItemLog > 1 then
			local mercPickedUpItems = {}
			for i, log in ipairs(DeferredItemLog) do
				local amount = log.amount
				if amount == 0 then goto continue end

				if not mercPickedUpItems[log.unit] then
					mercPickedUpItems[log.unit] = {log}
				else
					for j, logItem in ipairs(mercPickedUpItems[log.unit]) do
						if log.item.class == logItem.item.class then
							logItem.amount = logItem.amount + log.amount
							goto continue
						end
					end
					table.insert(mercPickedUpItems[log.unit], log)
				end
				::continue::
			end
			
			local lineActor = DeferredItemLog[1].actor == "short" and "helper" or "importanthelper"
			
			CombatLog(DeferredItemLog[1].actor, T(435437836774, "Items acquired:"))
			local lines = {}
			
			for unit, itemsLog in pairs(mercPickedUpItems) do
				
				for _, itemLog in ipairs(itemsLog) do
					CombatLog(lineActor, TFormat.ItemLog(itemLog, unit))
				end
			end
			
			
			
			
		else
			text = TFormat.ItemLog({amount = amount, item = item}, unit, "singleEntry")
			CombatLog(DeferredItemLog[1].actor, text)
		end
		DeferredItemLog = false
	end)
end

---
--- Removes an item from the unit's inventory.
---
--- @param slot_name string The name of the inventory slot to remove the item from.
--- @param item table The item to remove.
--- @return table, number The removed item and its position in the inventory.
---
function UnitInventory:RemoveItem(slot_name, item,...)
	local item, pos = Inventory.RemoveItem(self, slot_name, item,...)
	if not item then return end
	item:OnRemove(self, slot_name, pos, item)
	if IsKindOf(item, "BaseWeapon") and IsKindOf(self, "Unit") then
		-- Remove perk modifiers associated with this item.
		for _, id in ipairs(self.StatusEffects) do
			item:RemoveModifiers(id)
		end
	end	
	Msg("ItemRemoved", self, item, slot_name, pos)
	
	return item, pos
end

---
--- Gets the available ammo for a given weapon.
---
--- @param weapon Firearm|HeavyWeapon The weapon to get the available ammo for.
--- @param ammo_type string|nil The type of ammo to filter for.
--- @param unique boolean|nil If true, only return unique ammo types.
--- @return table, table, table The available ammo, the containers they are in, and the slots they are in.
---
function UnitInventory:GetAvailableAmmos(weapon, ammo_type, unique)
	if not IsKindOfClasses(weapon, "Firearm", "HeavyWeapon") then
		return empty_table
	end
	local ammo_class = IsKindOfClasses(weapon, "HeavyWeapon", "FlareGun") and "Ordnance" or "Ammo"
	local types = {}
	local containers = {}
	local slots = {}

	local slot_name = GetContainerInventorySlotName(self)
	local caliber = weapon.Caliber
	self:ForEachItemInSlot(slot_name, ammo_class, function(ammo, slot_name, left, top, types, ammo_type, caliber, unique)
		if (not ammo_type or ammo.class == ammo_type) and ammo.Caliber == caliber then
			if not unique or not table.find(types, "class", ammo.class) then
				table.insert(types, ammo)
			end
		end
	end, types, ammo_type, caliber, unique)
	for i = 1, #types do
		containers[i] = self
		slots[i] = slot_name
	end

	local bag = GetSquadBag(self.Squad)	
	for _, ammo in ipairs(bag) do
		if IsKindOf(ammo, ammo_class)and (not ammo_type or ammo.class == ammo_type) and ammo.Caliber == caliber then
			if not unique or not table.find(types, "class", ammo.class) then
				table.insert(types, ammo)
				table.insert(containers, bag)
			end
		end
	end
	return types, containers, slots
end

local l_count_available_ammo

-- count available ammo im mercs backpack and squads backpack
---
--- Counts the available ammo of the specified type in the unit's inventory and squad bag.
---
--- @param ammo_type string|nil The type of ammo to count. If nil, counts all ammo types.
--- @return number The total amount of available ammo.
---
function UnitInventory:CountAvailableAmmo(ammo_type)
	l_count_available_ammo = 0
	local slot_name = GetContainerInventorySlotName(self)
	self:ForEachItemInSlot(slot_name, ammo_type, function(ammo, slot, left, top, ammo_type)
		if (not ammo_type or ammo.class == ammo_type) then
			l_count_available_ammo = l_count_available_ammo + ammo.Amount
		end
	end, ammo_type)
	local bag = GetSquadBag(self.Squad)
	for _, ammo in ipairs(bag) do
		if (not ammo_type or ammo.class == ammo_type) then
			l_count_available_ammo = l_count_available_ammo + ammo.Amount
		end
	end
	return l_count_available_ammo
end

---
--- Reloads the specified weapon with the available ammo.
---
--- @param gun Firearm The weapon to reload.
--- @param ammo_type string|Ammo The type of ammo to use for reloading, or the ammo item itself.
--- @param delayed_fx boolean Whether to add a delay before playing the reload animation.
--- @param ai boolean Whether this is an AI-controlled reload.
--- @return boolean Whether the weapon was successfully reloaded.
---
function UnitInventory:ReloadWeapon(gun, ammo_type, delayed_fx, ai)
	local reloaded
	local ammo
	local ammo_items = {}
	local bag = self.Squad and GetSquadBagInventory(self.Squad)
	if not ammo_type or type(ammo_type) == "string" then
		if not ammo_type and gun.ammo then 
			ammo_type = gun.ammo.class
			ammo = self:GetAvailableAmmos(gun, ammo_type)
			if not ammo then 
				ammo = self:GetAvailableAmmos(gun)
			end
		else
			ammo = self:GetAvailableAmmos(gun, ammo_type)
		end
		ammo_items = ammo and table.ifilter(ammo, function(idx, stack) return stack.class == ammo[1].class and stack.Amount > 0 end)
		ammo = table.remove(ammo_items, 1)
	else
		ammo = ammo_type
		ammo_items = self:GetAvailableAmmos(gun, ammo_type.class)
		table.remove_value(ammo_items, ammo)
	end
	
	local prev, playedFX, change
	while ammo and (ai or ((gun.ammo and gun.ammo.Amount or 0) < gun.MagazineSize) or not gun.ammo or gun.ammo.class ~= ammo.class) do
		prev, playedFX, change = gun:Reload(ammo, nil, delayed_fx)
		local vo = gun:GetVisualObj()
		if (change or ai) and vo and not playedFX then
			CreateGameTimeThread(function(weapon, obj, delayed_fx)
				--Added randomness for weapon reload to cover the case with all mercs reloading on combat end or ReloadMultiSelection shortcut(both are during unpaused game)
				if delayed_fx then
					Sleep(InteractionRand(500, "ReloadDelay"))
				end
				if GetMercInventoryDlg() then
					PlayFX("WeaponLoad", "start", obj.object_class or (obj.weapon and obj.weapon.object_class), obj)
				else
					local actor_class = obj.fx_actor_class
					obj.fx_actor_class = weapon.class
					PlayFX("WeaponReload", "start", obj)
					obj.fx_actor_class = actor_class
				end
			end, gun, vo, delayed_fx)
			playedFX = true
		end
		ai = false	
		reloaded = true	
		local slot_name = GetContainerInventorySlotName(self)
		if ammo.Amount <= 0 then
			self:RemoveItem(slot_name, ammo)	
			if bag then
				bag:RemoveItem("Inventory", ammo)
			end
			ammo = table.remove(ammo_items, 1) -- keep loading from the next item stack if there's one and still not fully loaded
		else
			ObjModified(ammo)
		end
		if prev then
			if prev.Amount == 0 then
				DoneObject(prev)
			else
				bag:AddAndStackItem(prev)
			end
		end
	end
	
	if reloaded then
		local reloadOptions = GetReloadOptionsForWeapon(gun, self)
		if gun.ammo and gun.ammo.Amount and gun.ammo.Amount < gun.MagazineSize and not next(reloadOptions) then
			PlayVoiceResponse(self, "AmmoLow")
		end
	end
	
	Msg("WeaponReloaded", self)
	ObjModified("WeaponReloaded")
	return reloaded
end

---
--- Returns the name of the equipped weapon slot for the given weapon.
---
--- @param weapon Weapon The weapon to find the equipped slot for.
--- @return string The name of the equipped weapon slot, or nil if the weapon is not equipped.
---
function UnitInventory:GetEquippedWeaponSlot(weapon)
	if self:FindItemInSlot("Handheld A", function(item, weapon) return item == weapon end, weapon) then
		return "Handheld A"
	elseif self:FindItemInSlot("Handheld B", function(item, weapon) return item == weapon end, weapon) then
		return "Handheld B"
	end
end

-- check for equipped weapons in specified Handheld slot
---
--- Returns a list of all weapons equipped in the specified inventory slot.
---
--- @param slot_name string The name of the inventory slot to search.
--- @param class table (optional) The class of weapon to filter for.
--- @return table A list of weapons equipped in the specified slot.
---
function UnitInventory:GetEquippedWeapons(slot_name, class)
	local weapons = {}
	self:ForEachItemInSlot(slot_name,function(item, s, l,t, weapons, class)
		if item:IsWeapon() and (not class or IsKindOf(item, class)) then
			weapons[#weapons + 1] = item
		end	
	end, weapons, class)
	return weapons
end

---
--- Returns a list of all items in the specified inventory slot.
---
--- @param slot_name string The name of the inventory slot to search.
--- @return table A list of items in the specified slot.
---
function UnitInventory:GetItemsInWeaponSlot(slot_name) 
	local items = {}
	self:ForEachItemInSlot(slot_name, function(item, slot, x, y, items)
		items[x] = item
	end, items)
	table.compact(items) -- Items will be sorted by x
	return items
end

---
--- Finds a weapon in the specified inventory slot by its ID.
---
--- @param slot string The name of the inventory slot to search.
--- @param id number The ID of the weapon to find.
--- @return Weapon|nil The weapon found in the slot, or nil if not found.
---
function UnitInventory:FindWeaponInSlotById(slot, id)
	return self:FindItemInSlot(slot, function(item, id)
		if item.id == id then
			return item
		end
		if IsKindOf(item, "Firearm") then
			local min
			for slot, sub in pairs(item.subweapons) do
				if sub.id == id and (not min or lessthan(sub, min)) then
					min = sub
				end
			end
			if min then
				return min
			end
		end
	end, id)
end

---
--- Bandages the unit's wounds using the equipped medicine.
---
--- @param self UnitInventory The unit's inventory.
---
function UnitInventory:InventoryBandage()
	local target = self
	local medicine = GetUnitEquippedMedicine(self)

	target:GetBandaged(medicine, self)
	Msg("InventoryChange", self)
end

---
--- Bandages the unit's wounds using the equipped medicine.
---
--- @param self UnitInventory The unit's inventory.
--- @param medkit Medkit The medkit used to bandage the unit.
--- @param healer UnitInventory The unit performing the bandaging.
---
function UnitInventory:GetBandaged(medkit, healer)
	if not self:HasStatusEffect("Bleeding") and self.HitPoints >= self.MaxHitPoints then
		return
	end
	
	-- Hemophobic quirk
	local chance = CharacterEffectDefs.Hemophobic:ResolveValue("procChance")
	if HasPerk(self, "Hemophobic") then
		local roll = InteractionRand(100, "Hemophobic")
		if roll < chance then
			PlayVoiceResponse(self, "Hemophobic")
			CombatLog("debug", T{Untranslated("<em>Hemophobic</em> proc on <unit>"), unit = self.Name})
			if g_Combat and IsValid(healer) and healer:GetBandageTarget() == self then
				healer:SetCommand("EndCombatBandage")
			end
			PanicOutOfSequence({self})
			return
		end
	end
	
	local heal_amount, condition_rate = healer:CalcHealAmount(medkit, self)	
	if (heal_amount or 0) <= 0 then
		return
	end
		
	-- restore hp up to (current) max hp
	local old_hp = self.HitPoints
	self.HitPoints = Min(self.MaxHitPoints, self.HitPoints + heal_amount)
	local restored = self.HitPoints - old_hp
	self:OnHeal(restored, medkit, healer)
	
	if healer == self then
		CombatLog("short", T{934288978076, "<target> <em>bandaged</em> their wounds (<em><amount> HP</em> restored)",
			target = self.Nick or self.Name,
			amount = restored,
		})
	else
		CombatLog("short", T{559041931277, "<target> was <em>bandaged</em> by <healer> (<em><amount> HP</em> restored)",
			healer = healer.Nick or healer.Name,
			target = self.Nick or self.Name,
			amount = restored,
		})
		PlayVoiceResponse(self, "HealReceived")
	end
	
	local condition_loss = Max(1, MulDivRound(restored, 100, CombatActions.Bandage:ResolveValue("MaxConditionHPRestore")))
	condition_loss = Max(1, MulDivRound(condition_loss, condition_rate, 100))
	medkit.Condition = Clamp(medkit.Condition - condition_loss, 0, 100)
	local slot = healer:GetItemSlot(medkit)
	if slot and medkit.Condition <= 0 then
		CombatLog("short", T{831717454393, "<merc>'s <item> has been depleted", merc = healer.Nick, item = medkit.DisplayName})
		--healer:RemoveItem(slot, medkit)
		--DoneObject(medkit)
	end
		
	ObjModified(self)
	Msg("OnBandage", healer, self, restored)
	Msg("OnBandaged", healer, self, restored)
	healer:CallReactions("OnUnitBandaged", healer, self, restored)
	if healer ~= self then
		self:CallReactions("OnUnitBandaged", healer, self, restored)
	end
	if IsValid(healer) then
		Msg("InventoryChange", healer)
	end
end

--- Handles the healing of a unit.
---
--- @param hp number The amount of HP restored.
--- @param medkit table The medkit used for healing.
--- @param healer table The unit that performed the healing.
function UnitInventory:OnHeal(hp, medkit, healer)
	Msg("OnHeal", self, hp, medkit, healer)
end

--- Returns a list of handheld items and their corresponding slots.
---
--- @return table items A list of handheld items.
--- @return table slots A list of the corresponding slots for the handheld items.
function UnitInventory:GetHandheldItems()
	local items = {}
	local slots = {}
	local item = false
	
	local y = 1
	for i = 1, 2 do
		local slot = (i == 1) and "Handheld A" or "Handheld B"
		for x = 1, 2 do
			item = self:GetItemAtPos(slot, x, y)
			if item then
				items[#items+1] = item
				slots[#slots+1] = slot
			end
		end
	end
	
	return items, slots
end

--- Returns a list of equipped armor items.
---
--- @return table items A list of equipped armor items.
function UnitInventory:GetEquipedArmour()
	local slots = {"Head", "Torso", "Legs"}
	local items = {}
	
	for _, slot in ipairs(slots) do
		local item = self:GetItemAtPos(slot, 1, 1)
		if item then
			items[#items+1] = item
		end
	end
	
	return items
end

DefineClass.UnitData = {
	__parents = { "UnitBase" },
	properties = {
		{ category = "", id = "MessengerOnline", editor = "bool", default = true },
		{ id = "status_effect_exp", editor = "nested_list", default = false, no_edit = true },
	},
}

--- Calculates the base damage of a weapon for the unit.
---
--- @param weapon table The weapon to calculate the base damage for.
--- @return number The calculated base damage.
function UnitData:GetBaseDamage(weapon)
	local base_damage = 0
	if IsKindOf(weapon, "Firearm") then
		base_damage = weapon.Damage
	elseif IsKindOfClasses(weapon, "Grenade", "MeleeWeapon", "Ordnance") then
		base_damage = weapon.BaseDamage
	elseif IsKindOf(weapon, "HeavyWeapon") then
		base_damage = weapon:GetBaseDamage()
	end

	local data = { base_damage = base_damage, modifier = 100, breakdown = {} }
	self:CallReactions("OnCalcBaseDamage", weapon, nil, data)	
	return MulDivRound(data.base_damage, data.modifier, 100)
end

--- Calculates the critical hit chance for the given weapon.
---
--- @param weapon table The weapon to calculate the critical hit chance for.
--- @return number The calculated critical hit chance.
function UnitData:CalcCritChance(weapon)
	return self:GetBaseCrit(weapon)
end

--- Sets the MessengerOnline property of the UnitData object.
---
--- @param val boolean The new value for the MessengerOnline property.
function UnitData:SetMessengerOnline(val)
	if IsGameRuleActive("AlwaysOnline") and not val then 
		return
	end
	self.MessengerOnline = val
	if GetMercStateFlag(self.session_id, "OnlineNotificationSubscribe") then
		CombatLog("important", T{910877762088, "<Name> is now online.", self})
		SetMercStateFlag(self.session_id, "OnlineNotificationSubscribe", false)
	end
end

--- Adds a status effect with the given perk ID to the specified mercenary.
---
--- @param merc table The mercenary to add the status effect to.
--- @param perk_id string The ID of the perk to add as a status effect.
function CheatAddPerk(merc, perk_id)
	merc:AddStatusEffect(perk_id)
end

--- Initializes the derived properties of the UnitData object.
---
--- This function sets the initial maximum hit points, current hit points, maximum action points, and experience of the UnitData object. It also creates copies of the Likes and Dislikes tables.
---
--- @param self UnitData The UnitData object to initialize.
function UnitData:InitDerivedProperties()
	self.MaxHitPoints = self:GetInitialMaxHitPoints()
	self.HitPoints = self.MaxHitPoints
	self.GetMaxActionPoints = UnitProperties.GetMaxActionPoints
	self.ActionPoints = self:GetMaxActionPoints()
	
	self.Likes = table.copy(self.Likes)
	self.Dislikes = table.copy(self.Dislikes)
	
	if not self.Experience then
		local minXP = GetXPTable(self.StartingLevel)
		self.Experience = minXP
	end
end

--- Initializes the starting perks for the UnitData object.
---
--- This function retrieves the list of starting perks for the UnitData object and adds them as status effects.
function UnitData:CreateStartingPerks()
	local startingPerks = self:GetStartingPerks()
	for i, p in ipairs(startingPerks) do
		if CharacterEffectDefs[p] then
			self:AddStatusEffect(p)
		end
	end
end

--- Checks if the given unit has the specified perk.
---
--- @param unit StatusEffectObject The unit to check for the perk.
--- @param id string The ID of the perk to check for.
--- @return boolean True if the unit has the specified perk, false otherwise.
function HasPerk(unit, id)
	if not IsKindOf(unit, "StatusEffectObject") or not unit.StatusEffects then return false end
	return unit.StatusEffects[id]
end

--- Initializes the starting equipment for the UnitData object.
---
--- This function generates the starting equipment for the UnitData object based on the defined equipment in the UnitData object. It creates a list of items and looted items, and then equips the starting gear on the UnitData object.
---
--- @param seed number The seed value to use for generating the starting equipment.
--- @param add_inventory boolean Whether to add the generated items to the UnitData object's inventory.
function UnitData:CreateStartingEquipment(seed, add_inventory)
	local items, looted = {}, {}
	for _, loot in ipairs(self.Equipment or empty_table) do
		local loot_tbl = LootDefs[loot]
		if loot_tbl then
			loot_tbl:GenerateLoot(self, looted, seed, items)
		end
	end
		
	self:EquipStartingGear(items)
	
end

--- Checks if the UnitData object represents an NPC (non-player character).
---
--- @return boolean True if the UnitData object represents an NPC, false otherwise.
function UnitData:IsNPC()
	local unit_data = UnitDataDefs[self.class]
	return not unit_data or not IsMerc(unit_data)
end

-- add unitdata function for checks in invenitry ui in satellite view
--- Checks if the UnitData object is in a downed state.
---
--- This function checks if the UnitData object is in a downed state, which is valid only when the game is in combat mode. It retrieves the corresponding Unit object from the global g_Units table and checks if it is downed.
---
--- @return boolean True if the UnitData object is in a downed state, false otherwise.
function UnitData:IsDowned()
	if not g_Combat then return false end
	-- valid for unit in combat mode only
	local unit = g_Units[self.session_id]
	return unit and unit:IsDowned()	
end

--- Generates a random number between 1 and the specified maximum value.
---
--- This function uses the `InteractionRand` function to generate a random number between 1 and the specified `max` value. The "Loot" string is used as the seed for the random number generation.
---
--- @param max number The maximum value for the random number.
--- @return number A random number between 1 and `max`.
function UnitData:Random(max)
	return InteractionRand(max, "Loot")
end

--- Checks if the UnitData object is controlled by the local player.
---
--- This function checks if the UnitData object is controlled by the local player. It retrieves the Squad object associated with the UnitData object and checks if the side of the squad matches the local player's side, and if the UnitData object's ControlledBy field matches the local player's control.
---
--- @return boolean True if the UnitData object is controlled by the local player, false otherwise.
function UnitData:IsLocalPlayerControlled()
	local squad = gv_Squads and gv_Squads[self.Squad]
	if not squad then return true end
	return IsControlledByLocalPlayer(squad and squad.Side, self.ControlledBy)
end

UnitData.CanBeControlled = UnitData.IsLocalPlayerControlled

--- Returns a list of available intel sectors within a specified radius of a given sector.
---
--- @param sector_id number The ID of the sector to search around.
--- @return table, table The list of available intel sectors, and the list of all sectors within the search radius.
function GetAvailableIntelSectors(sector_id)
	local available = {}
	local allSectors = {}
	local campaign = GetCurrentCampaignPreset()
	-- Check within radius of current sector
	local row, col = sector_unpack(sector_id)
	local radius = 2
	for r = row - 2, row + 2 do
		for c = col - 2, col + 2 do
			if r >= campaign.sector_rowsstart and r <= campaign.sector_rows and c >= 1 and c <= campaign.sector_columns then
				local sector_id = sector_pack(r, c)
				if gv_Sectors[sector_id].Intel and not gv_Sectors[sector_id].intel_discovered then
					table.insert(available, sector_id)
				end
				table.insert(allSectors, sector_id)
			end
		end
	end
	
	return available, allSectors
end

--- Handles the completion of a gather intel operation.
---
--- This function is called when a gather intel operation is completed. It discovers new intel sectors within a radius of the completed sector, and updates the revealed sectors around the completed sector. It also generates a text message to display the results of the operation.
---
--- @param sector_id number The ID of the sector where the gather intel operation was completed.
--- @param mercs table A list of mercenaries that participated in the gather intel operation.
--- @return string The text message to display the results of the gather intel operation.
function HandleGatherIntelCompleted(sector_id, mercs)
	local discovered_in = {}
	local intel_sectors = GetAvailableIntelSectors(sector_id)
	
	local s_id, idx 
	for i=1,2 do -- revil 2 intel sectors
		s_id, idx = table.interaction_rand(intel_sectors, "Satellite")
		if s_id then
			discovered_in[#discovered_in + 1] = s_id
			DiscoverIntelForSector(s_id, true)
			table.remove(intel_sectors, idx)
		end
	end
	
	s_id, idx = table.interaction_rand(intel_sectors, "Satellite")
	if s_id then
		local avg_wisdom = 0
		for _, m in ipairs(mercs) do
			avg_wisdom = avg_wisdom + m.Wisdom
		end
		avg_wisdom = avg_wisdom / #mercs
		local r = InteractionRand(100, "Satellite") + 1
		if r < (avg_wisdom - 25) then
			discovered_in[#discovered_in + 1] = s_id
			DiscoverIntelForSector(s_id, true)
			table.remove(intel_sectors, idx)
			s_id, idx = table.interaction_rand(intel_sectors, "Satellite")
		end
		r = InteractionRand(100, "Satellite") + 1
		if s_id and r < avg_wisdom - 55 then
			discovered_in[#discovered_in + 1] = s_id
			DiscoverIntelForSector(s_id, true)
		end
	end

	ForEachSectorAround(sector_id, 2, function(s) 
		gv_RevealedSectorsTemporarily[s] = Game.CampaignTime + 48*const.Scale.h
	end)
	RecalcRevealedSectors()
	
	local mercText = ConcatListWithAnd(table.map(mercs, function(o) return o.Nick; end))
	local sectorList = ConcatListWithAnd(table.map(discovered_in, function(o) return GetSectorName(gv_Sectors[o]); end))
	local text = false
	if #discovered_in == 0 then
		if #mercs == 1 then
			text = mercText .. T(814036636117, " has finished scouting the area and has found no <em>new intel</em>")
		else
			text = mercText .. T(266040497025, " have finished scouting the area and have found no <em>new intel</em>")
		end
	else
		if #discovered_in == 1 then
			if #mercs == 1 then
				text = mercText .. T(449289464268, " has finished scouting the area and has found intel for sector ")
			else
				text = mercText .. T(209577403591, " have finished scouting the area and have found intel for sector ")
			end
		else
			if #mercs == 1 then
				text = mercText .. T(215246075897, " has finished scouting the area and has found intel for sectors ")
			else
				text = mercText .. T(997308088801, " have finished scouting the area and have found intel for sectors ")
			end
		end
		text = text .. sectorList
	end
	
	-- text for not visited sector with property "interesting"
	local interesting_sectors = {}	
	ForEachSectorAround(sector_id, 2,
		function(s_id, interesting_sectors)
			local sector = gv_Sectors[s_id]
			if sector and sector.InterestingSector and not sector.last_enter_campaign_time then
				interesting_sectors[#interesting_sectors + 1] = GetSectorName(sector)
			end
		end, interesting_sectors)
	if next(interesting_sectors) then
		local interesting_sectors_text = T{769686665237, "There may be something of interest in sectors - <sectors>", sectors = table.concat(interesting_sectors, ", ")}
		text = text.."\n"..interesting_sectors_text
	end
	
	local questHints = GetQuestsThatCanProvideHints(sector_id)
	if #questHints > 0 then
		local roll = InteractionRand(100, "Satellite")
		if roll > 50 then
			local idx = InteractionRand(#questHints, "Satellite") + 1
			local note = ShowQuestScoutingNote(questHints[idx])
			if note then
				text = text .. "\n\n".. T{717080721103, "Discovered info about nearby events:\n<note>", note = note.Text}.."\n\n"			
			end
		end
	end
	
	if DynamicSquadSpawnChanceOnScout > InteractionRand(100, "Satellite") then
		SpawnDynamicDBSquad(false, s_id)
	end
	
	return text 
end

---
--- Recalculates the operation ETA (Estimated Time of Arrival) for all units in the same squad as the current unit.
---
--- @param operation string The operation ID to recalculate the ETA for.
--- @param exclude_self boolean If true, excludes the current unit from the ETA recalculation.
---
function UnitData:RecalcOperationETA(operation, exclude_self) 
	local squad = self.Squad and gv_Squads[self.Squad]
	if not squad then return end
	local units = GetPlayerMercsInSector(squad.CurrentSector)
	for _,unit in ipairs(units) do
		local unit_data = gv_UnitData[unit]
		if unit_data.Operation==operation and (not exclude_self or unit~=self.session_id) then
			local new_eta = GetOperationTimerInitialETA(unit_data)
			if new_eta and new_eta>0 and new_eta~=unit_data.OperationInitialETA then
				unit_data.OperationInitialETA = new_eta
				Msg("OperationTimeUpdated", unit_data, operation)
			end
		end	
	end
end

---
--- Resorts the operation slots for a given profession in a sector operation.
---
--- @param sector_id string The ID of the sector.
--- @param operation_id string The ID of the operation.
--- @param profession string The profession to resort the slots for.
--- @param slot integer The slot to start resorting from.
---
function ReSortOperationSlots(sector_id,operation_id, profession, slot)
	local mercs = GetOperationProfessionals(sector_id,operation_id, profession)
	for _, merc in ipairs(mercs) do
		local mslot = merc.OperationProfessions[profession]
		if mslot then
			merc.OperationProfessions[profession] = mslot>slot and mslot-1 or mslot
		end
	end
end

---
--- Removes a profession from the unit's current operation.
---
--- If no profession is provided, the unit's current operation is set to "Idle".
--- If the unit has no professions for the current operation, the operation is set to "Idle".
--- Otherwise, the profession is removed from the unit's professions for the current operation, and the operation slots are re-sorted.
--- The operation's initial ETA is recalculated, and a "OperationTimeUpdated" message is sent.
---
--- @param profession string The profession to remove from the unit's current operation, or nil to set the operation to "Idle".
---
function UnitData:RemoveOperationProfession(profession)
	if not profession then
		self:SetCurrentOperation("Idle")
		return
	end	
	if not self.OperationProfessions or not self.OperationProfessions[profession] then
		return
	end	
	
	local operation_id = self.Operation
	local operation = SectorOperations[operation_id]
	local prev_slot = self.OperationProfessions[profession]
	self.OperationProfessions[profession] = nil
	if not next(self.OperationProfessions) then
		self:SetCurrentOperation("Idle")
		return
	end
	ReSortOperationSlots(self:GetSector().Id,operation_id, profession, prev_slot)
	self.OperationInitialETA = GetOperationTimerInitialETA(self)
	self:RecalcOperationETA(operation_id, "exclude_self")
	Msg("OperationTimeUpdated", self, operation_id)
end

---
--- Sets the current operation for the unit.
---
--- @param operation_id string The ID of the operation to set.
--- @param slot integer The slot to assign the unit's profession to.
--- @param profession string The profession to assign to the operation.
--- @param partial_wounds boolean Whether the operation has partial wounds.
--- @param interrupted boolean Whether the operation was interrupted.
---
function UnitData:SetCurrentOperation(operation_id, slot, profession, partial_wounds, interrupted)
	--print("set operation: ", self.session_id, operation_id)
	local sector = self:GetSector()
	local is_operation_started = operation_id == "Idle" or operation_id == "Traveling" or operation_id == "Arriving" or
			sector and sector.started_operations and sector.started_operations[operation_id]

	if self.Operation == operation_id then
		local operation = SectorOperations[operation_id]
		if profession then
			self.OperationProfessions = self.OperationProfessions or {}
			self.OperationProfessions[profession] = self.Operation ~= "Idle" and slot or nil
		end
		operation:OnSetOperation(self, partial_wounds)
		self.OperationInitialETA = GetOperationTimerInitialETA(self)
		self:RecalcOperationETA(operation_id, "exclude_self")
		if is_operation_started then
			Msg("OperationTimeUpdated", self, operation_id)
		else	
			Msg("OperationChanged", self, operation, operation, self.OperationProfession, interrupted)
		end	
		return
	end
	local prev_operation = SectorOperations[self.Operation]
	local prev_profession = self.OperationProfession

	local prev_started = sector and sector.started_operations and sector.started_operations[self.Operation]
	local current = prev_started and prev_operation:ProgressCurrent(self, sector, self.OperationProfession or "prediction") or 0
	local target = prev_started and prev_operation:ProgressCompleteThreshold(self, sector, self.OperationProfession or "prediction") or 0
	
	prev_operation:OnRemoveOperation(self)
	local prev_professions = self.OperationProfessions
	local operation = SectorOperations[operation_id]
	self.Operation = operation_id
	self.OperationProfession = profession or operation.Professions and operation.Professions[1].id or "Idle"
	if profession or self.Operation ~= prev_operation.id then
		self.OperationProfessions = {}
		if profession then
			self.OperationProfessions[profession] = self.Operation ~= "Idle" and slot or nil
		end
	end
	
	for prof, slot in pairs(prev_professions) do
		ReSortOperationSlots(sector.Id,prev_operation.id,prof,slot)
	end

	operation:OnSetOperation(self, partial_wounds)
	self.OperationInitialETA = GetOperationTimerInitialETA(self)
	self:RecalcOperationETA(operation_id, "exclude_self") 
	if prev_operation.id ~= "Traveling" and prev_operation.id ~= "Idle" and prev_operation.id~= "Arriving" then
		self:RecalcOperationETA(prev_operation.id, "exclude_self") 	
	end
	
	local interrupted = interrupted
	local reason = interrupted
	if self.Operation == operation_id then -- we can cancel the operation in OnSetOperation
		CombatLog("debug", T{Untranslated("<em><activity></em> assigned to <DisplayName>"), self, activity = operation.display_name})
		if not sector then return end
		if operation_id == "Idle" and current < target and prev_operation.id ~= "Traveling" then
			interrupted = true
			local last_mercs =  #GetOperationProfessionals(sector.Id, prev_operation.id)
			if last_mercs == 0 and reason~="no log" then
				local perc = target==0 and 0 or MulDivRound(100, current, target)
				if perc > 0 then
					CombatLog("important", T{711857921546, "<em><display_name></em> was interrupted at <percent(percent)> in sector <SectorName(sector)>",
						prev_operation, sector = sector, percent = perc})
				end
			end
		end
	end
	ObjModified(self)
	Msg("OperationChanged", self, prev_operation, operation, prev_profession, interrupted)
end

---
--- Swaps the active weapon of the unit between "Handheld A" and "Handheld B".
---
--- @param action_id string The action ID associated with the weapon swap.
--- @param cost_ap number The action point cost for the weapon swap.
---
function UnitData:SwapActiveWeapon(action_id, cost_ap)
	self.current_weapon = self.current_weapon == "Handheld A" and "Handheld B" or "Handheld A"
	ObjModified(self)
end

---
--- Checks if the unit is currently travelling.
---
--- @param self UnitData The unit data object.
--- @return boolean True if the unit is travelling, false otherwise.
---
function UnitData:IsTravelling()
	return IsSquadTravelling(gv_Squads[self.Squad])
end

---
--- Gets the sector that the unit is currently in.
---
--- @param self UnitData The unit data object.
--- @return Sector The sector that the unit is currently in.
---
function UnitData:GetSector()
	local squad = gv_Squads[self.Squad]
	local sector_id = squad and squad.CurrentSector
	return gv_Sectors[sector_id]
end

---
--- Removes an item from the unit's inventory.
---
--- @param self UnitData The unit data object.
--- @param ... any The arguments to pass to `UnitInventory.RemoveItem`.
--- @return boolean, number The result of the item removal and the position of the removed item.
---
function UnitData:RemoveItem(...)
	local res, pos = UnitInventory.RemoveItem(self, ...)
	self:CheckValidOperation()
	return res, pos
end

---
--- Checks if the unit's current operation is valid.
---
--- If the unit has a required item or the operation is "RepairItems", this function checks if the operation can be performed. If the operation cannot be performed, it cancels the operation.
---
--- @param self UnitData The unit data object.
---
function UnitData:CheckValidOperation()
	if self.RequiredItem or self.Operation=="RepairItems" then
		local operation_descr = SectorOperations[self.Operation]
		local err, context = operation_descr:CanPerformOperation(self) 
		if err then
			SectorOperation_CancelByGame({self}, self.Operation, true)
		end
	end
end

-- Check for any expired mercs
function OnMsg.StartSatelliteGameplay()
	for i, ud in pairs(gv_UnitData) do
		if ud.HireStatus == "Hired" and ud.HiredUntil and Game.CampaignTime >= ud.HiredUntil then
			MercContractExpired(ud)
			return
		end
	end
end

---
--- Handles the periodic tick for a unit data object.
---
--- This function performs the following actions:
--- - If the unit's contract is about to expire, sets a tutorial hint flag.
--- - If the unit's contract has expired, calls the `MercContractExpired` function.
--- - Heals the unit based on its current operation and status:
---   - Player mercs are healed at a constant rate.
---   - Militia and enemy units are healed at a constant rate when not traveling.
---   - Units in the "R&R" operation receive an additional healing multiplier.
---   - The unit's `OnHeal` event is triggered when the unit is healed.
---
--- @param self UnitData The unit data object.
---
function UnitData:Tick()
	if self.HiredUntil and Game.CampaignTime + const.Scale.h * 60 > self.HiredUntil then
		TutorialHintsState.ContractExpireHint = true
	end

	if self.HiredUntil and Game.CampaignTime >= self.HiredUntil then
		MercContractExpired(self)
	end
	
	-- heal player mercs 
	---heal militia and enemy units when no travel
	if IsMerc(self) or self.Operation~="Traveling" then
		local add = IsPatient(self) and const.Satellite.PatientHealPerTick or const.Satellite.NaturalHealPerTick
		if self.Operation=="RAndR" then
			add = const.Satellite.RandRActivityHealingMultiplier * add
		end	
		local old_hp = self.HitPoints
		self.HitPoints = Min(self.HitPoints + add, self.MaxHitPoints)
		local healed = self.HitPoints - old_hp
		if healed > 0 then
			self:OnHeal(healed)
		end
	end
	Msg("UnitDataTick", self)
end

function OnMsg.UnitDataTick(self)
	-- wound heal for enemy and militia when no travel
	if not IsMerc(self) and self.Operation~="Traveling" then
		UnitHealPerTick(self, const.Satellite.HealWoundsPerTick, const.Satellite.HealWoundThreshold, "dont log")
	end
end

local constRandomizationStats = 10
---
--- Randomizes the stats of a unit data object.
---
--- This function performs the following actions:
--- - Retrieves the list of unit stats to randomize.
--- - Iterates through each stat and applies a random modification to the stat value.
--- - If the modified stat value would be 0 or below, the modification is clamped to 0 or -1 respectively.
--- - Adds a "randstat" modifier to the unit data object for each randomized stat.
---
--- @param self UnitData The unit data object.
--- @param seed number The random seed to use for the randomization.
---
function UnitData:RandomizeStats(seed)
	local stats = GetUnitStatsCombo()
	local unit_def = UnitDataDefs[self.class]

	local rand
	for _, stat in ipairs(stats) do
		rand, seed = BraidRandom(seed, 2 * constRandomizationStats + 1)
		
		-- If the stat will be brought to or below 0 then
		-- clamp it to 0 if it was already 0 or 1 if it wasn't.
		local unitStat = self[stat]
		local modValue = rand - constRandomizationStats
		if unitStat - modValue <= 0 then
			modValue = unitStat == 0 and 0 or -(self[stat] - 1)
		end
		
		self:AddModifier("randstat", stat, false, modValue)
	end
end

---
--- Converts the UnitData object to Lua code that can be used to place a unit on the map.
---
--- This function generates a Lua code string that can be used to place a unit on the map. It takes the current state of the UnitData object and generates a call to the `PlaceUnitData` function, passing the unit's class and its property values.
---
--- @param indent string The indentation to use for the generated Lua code.
--- @param pstr string (optional) A string buffer to append the generated Lua code to.
--- @param GetPropFunc function (optional) A function to get the value of a property on the UnitData object.
--- @return string The generated Lua code.
function UnitData:__toluacode(indent, pstr, GetPropFunc)
	if not pstr then
		return string.format("PlaceUnitData('%s', %s)", self.class, self:SavePropsToLuaCode(indent, GetPropFunc, pstr) or "nil")
	end
	pstr:appendf("PlaceUnitData('%s', ", self.class)
	if not self:SavePropsToLuaCode(indent, GetPropFunc, pstr) then
		pstr:append("nil")
	end
	return pstr:append(")")
end

---
--- Handles the death of a unit, including removing it from its squad, rewarding team experience, and updating its hire status.
---
--- When a unit dies, this function performs the following actions:
--- - If the unit is part of a squad, it retrieves the current sector of the squad and the player mercs in that sector, and rewards team experience.
--- - It sends a "UnitDiedOnSector" message with the unit and the sector ID.
--- - It removes the unit from its squad.
--- - It sends a "MercHireStatusChanged" message with the unit, its previous hire status, and the new "Dead" status.
--- - It updates the unit's hire status to "Dead" and sets its hired until time to the current campaign time.
---
--- @param self UnitData The unit data object.
---
function UnitData:Die()
	if self.Squad then
		local sectorId = gv_Squads[self.Squad].CurrentSector
		local playerMercs = GetPlayerMercsInSector(sectorId)
		RewardTeamExperience(self, { units = playerMercs, sector = sectorId })
		Msg("UnitDiedOnSector", self, sectorId)
	end

	RemoveUnitFromSquad(self)
	Msg("MercHireStatusChanged", self, self.HireStatus, "Dead")
	self.HireStatus = "Dead"
	self.HiredUntil = Game.CampaignTime
end

---
--- Adds a status effect to the unit with a specified duration.
---
--- This function adds a status effect to the unit's status effect table, and sets the expiration time for the effect based on the provided duration. If the effect already exists in the table, the function will update the expiration time if the new duration is longer than the current expiration time.
---
--- @param self UnitData The unit data object.
--- @param id string The ID of the status effect to add.
--- @param duration number The duration of the status effect in campaign time.
---
function UnitData:AddStatusEffectWithDuration(id, duration)
	self.status_effect_exp = self.status_effect_exp or {}
	local exp_time = Game.CampaignTime + duration
	if not self.status_effect_exp[id] or self.status_effect_exp[id] < exp_time then
		self.status_effect_exp[id] = exp_time
	end
	self:AddStatusEffect(id)
end

---
--- Returns the squad that the unit is currently a member of.
---
--- @param self UnitData The unit data object.
--- @return Squad|nil The squad that the unit is currently a member of, or `nil` if the unit is not in a squad.
---
function UnitData:GetSatelliteSquad()
	return self.Squad and gv_Squads[self.Squad]
end

---
--- Checks if the unit has the specified action points (AP) available for the given action.
---
--- This function checks if the unit has the specified action points (AP) available for the given action. It first checks if the combat system and the unit are valid, and if so, it delegates the check to the unit's `UIHasAP` method.
---
--- @param self UnitData The unit data object.
--- @param ap number The amount of action points required for the action.
--- @param action_id string The ID of the action.
--- @param args table Optional arguments for the action.
--- @return boolean True if the unit has the required AP, false otherwise.
---
function UnitData:UIHasAP(ap, action_id, args)
	if not g_Combat or not g_Units[self.session_id] then
		return true
	end
	return g_Units[self.session_id]:UIHasAP(ap, action_id, args)
end

---
--- Returns the unit's UI-scaled action points (AP).
---
--- This function returns the unit's UI-scaled action points (AP). It first checks if the combat system and the unit are valid, and if so, it delegates the retrieval to the unit's `GetUIScaledAP` method.
---
--- @param self UnitData The unit data object.
--- @return number The unit's UI-scaled action points.
---
function UnitData:GetUIScaledAP() 
	if not g_Combat or not g_Units[self.session_id] then
		return 0
	end
	return g_Units[self.session_id]:GetUIScaledAP() 
end

---
--- Returns the unit's maximum UI-scaled action points (AP).
---
--- This function returns the unit's maximum UI-scaled action points (AP). It first checks if the combat system and the unit are valid, and if so, it delegates the retrieval to the unit's `GetUIScaledAPMax` method.
---
--- @param self UnitData The unit data object.
--- @return number The unit's maximum UI-scaled action points.
---
function UnitData:GetUIScaledAPMax() 
	if not g_Combat or not g_Units[self.session_id] then
		return 0
	end
	return g_Units[self.session_id]:GetUIScaledAPMax() 
end

---
--- Returns the unit's UI-scaled action points (AP).
---
--- This function returns the unit's UI-scaled action points (AP). It first checks if the combat system and the unit are valid, and if so, it delegates the retrieval to the unit's `GetUIActionPoints` method.
---
--- @param self UnitData The unit data object.
--- @return number The unit's UI-scaled action points.
---
function UnitData:GetUIActionPoints() 
	if not g_Combat or not g_Units[self.session_id] then
		return 0
	end
	return g_Units[self.session_id]:GetUIActionPoints() 
end

---
--- Checks if the unit's inventory is disabled.
---
--- This function returns a boolean indicating whether the unit's inventory is disabled.
---
--- @param self UnitData The unit data object.
--- @return boolean True if the unit's inventory is disabled, false otherwise.
---
function UnitData:InventoryDisabled()

end

function OnMsg.SatelliteTick()
	for _, u in sorted_pairs(gv_UnitData or emtpy_table) do
		for effect_id, time in sorted_pairs(u.status_effect_exp or empty_table) do
			if Game.CampaignTime > time then
				u:RemoveStatusEffect(effect_id)
			end
		end
	end
end

---
--- Creates a new UnitData object with the specified ID and randomization seed.
---
--- This function creates a new UnitData object with the specified ID and randomization seed. It first checks if a UnitData object with the given ID already exists in the `gv_UnitData` table. If not, it retrieves the UnitDataCompositeDef for the specified `unitdata_id`, and creates a new UnitData object using the `PlaceUnitData` function. The new UnitData object is then initialized with the specified randomization seed, and its derived properties, starting perks, and starting equipment are set. Finally, the new UnitData object is added to the `gv_UnitData` table and a "UnitDataCreated" message is sent.
---
--- @param unitdata_id string The ID of the UnitDataCompositeDef to use for the new UnitData object.
--- @param id string The ID of the new UnitData object.
--- @param seed number The randomization seed to use for the new UnitData object.
--- @return UnitData The new UnitData object.
---
function CreateUnitData(unitdata_id, id, seed)
	id = id or unitdata_id
	if gv_UnitData and gv_UnitData[id] then
		return gv_UnitData[id]
	end
	local unitdata_def = UnitDataDefs[unitdata_id]
	if not unitdata_def then
		local fallback = next(UnitDataDefs)
		StoreErrorSource(id, string.format("Invalid UnitDataCompositeDef '%s', falling back to '%s'!", unitdata_id, fallback))
		unitdata_def = UnitDataDefs[fallback]
		unitdata_id = fallback
	end
	local man = PlaceUnitData(unitdata_id)
	man.session_id = id
	if man then
		man.randomization_seed = seed
		if unitdata_def.Randomization then
			man:RandomizeStats(seed)
		end
		man:InitDerivedProperties()
		man:CreateStartingPerks()
		man:CreateStartingEquipment(seed, "add_inventory")
		GenerateEliteUnitName(man)
		if gv_UnitData then
			gv_UnitData[id] = man
		end
		Msg("UnitDataCreated", man)
		return man
	end
end

---
--- Returns a list of all UnitData objects in the `gv_UnitData` table, sorted by their `session_id`.
---
--- This function iterates over the `gv_UnitData` table, collects all the UnitData objects into a new table, and then sorts that table by the `session_id` field of each UnitData object.
---
--- @return table A table containing all the UnitData objects, sorted by their `session_id`.
---
function GetUnitDataList()
	local list = {}
	for _, ud in pairs(gv_UnitData) do
		list[#list + 1] = ud
	end
	table.sortby_field(list, "session_id")
	return list
end

---
--- Adds a scaled progress value to an object's property.
---
--- This function takes an object, a progress ID, a property ID, an amount to add, a maximum value, and an optional scale factor. It updates the progress ID by adding the absolute value of the amount, and if the progress exceeds the scale factor, it updates the property ID by the appropriate amount, clamped between 0 and the maximum value. The remaining progress is stored back in the progress ID.
---
--- @param obj table The object to update.
--- @param progress_id string The ID of the progress property to update.
--- @param prop_id string The ID of the property to update based on the progress.
--- @param add number The amount to add to the progress.
--- @param max number The maximum value for the property.
--- @param scale number (optional) The scale factor for the progress. Defaults to 1000.
---
function AddScaledProgress(obj, progress_id, prop_id, add, max, scale)
	local scale = scale or 1000 -- one prop_id point is equal to <scale> progress_id points
	local abs_add = abs(add)
	local progress = obj[progress_id] + abs_add
	if progress >= scale then
		local sign = add ~= 0 and (add/abs_add) or 1
		obj[prop_id] = Clamp(obj[prop_id] + sign * (progress / scale), 0, max)
		progress = progress % scale
	end
	obj[progress_id] = progress
end

-- CompositeDef code
DefineClass.UnitDataCompositeDef = {
	__parents = { "CompositeDef" },
	
	-- Composite def
	ObjectBaseClass = "UnitData",
	ComponentClass = false,
	
	-- Preset
	EditorMenubarName = "Unit Editor",
	EditorMenubar = "Characters",
	EditorShortcut = "Ctrl-Alt-M",
	EditorIcon = "CommonAssets/UI/Icons/group outline.png",
	EditorCustomActions = {
		{
			Name = "Test",
		},
		{
			FuncName = "UIAddMercToSquad",
			Icon = "CommonAssets/UI/Ged/plus-one.tga",
			Menubar = "Test",
			Name = "Add Unit To Squad",
			Toolbar = "main",
		},
		{
			FuncName = "UIQuickTestUnit",
			Icon = "CommonAssets/UI/Ged/preview.tga",
			Menubar = "Test",
			Name = "Quick Test Unit in Combat of One",
			Toolbar = "main",
		},
	},
	GlobalMap = "UnitDataDefs",
	Documentation = CompositeDef.Documentation .. "\n\nCreates a new unit preset.",
	
	-- 'true' is much faster, but it doesn't call property setters & clears default properties upon saving
	StoreAsTable = false,
	-- Serialize props as an array => {key, value, key value}
	store_as_obj_prop_list = true
}

DefineModItemCompositeObject("UnitDataCompositeDef", {
	EditorName = "Unit",
	EditorSubmenu = "Unit",
	TestDescription = "Places the unit on the map."
})

if config.Mods then
	function ModItemUnitDataCompositeDef:TestModItem(ged)
		ModItemCompositeObject.TestModItem(self, ged)
		
		--despawn merc if on map
		local id = self.id
		if g_Units and g_Units[id] then
			LocalRemoveMercFromSquad(id)
			local mercs = GetPlayerMercsInSector()
			if mercs and #mercs == 1 and not g_Units[id] then
				local squads = GetPlayerMercSquads()
				if squads and squads[1] then
					RemoveSquadsFromLists(squads[1])
				end
			end
			gv_UnitData[id] = nil
		end
		
		if IsMerc(self) then
			CheatAddMerc(id)
		else
			CheatSpawnEnemy(id)
		end
	end
end

---
--- Checks if the unit has enough starting perks based on its starting level.
--- If the unit is a mercenary and the number of non-bronze/silver/gold starting perks is less than the starting level minus 1, returns a warning message.
--- If the unit doesn't have a name, returns a warning message.
---
--- @param self UnitDataCompositeDef
--- @return string|nil Warning message if the unit has issues, nil otherwise
---
function UnitDataCompositeDef:GetWarning()
	local id = self.id
	if id and IsMerc(self) then
		local startingPerks = self:GetProperty("StartingPerks")
		local startingPerksCount = #startingPerks
		for indx, perk in ipairs(startingPerks) do
			local perkProps = CharacterEffectDefs[perk]
			if perkProps and not (perkProps.Tier == "Bronze" or perkProps.Tier == "Silver" or perkProps.Tier == "Gold") then
				startingPerksCount = startingPerksCount - 1
			end
		end
		local rspc = self:GetProperty("StartingLevel")
		if startingPerksCount + 1 < rspc  then
			return "Not enough starting perks! Should be " .. rspc - 1 .. ", has " .. startingPerksCount .. "."
		end
	end

	if not self.Name then
		return "Unit doesn't have name"
	end
end


---
--- Returns the maximum action points for the unit.
---
--- @param self UnitDataCompositeDef
--- @return number Maximum action points
---
UnitDataCompositeDef.GetMaxActionPoints = function(self) return UnitProperties.GetMaxActionPoints(self) end
---
--- Returns the unit's level.
---
--- @param self UnitDataCompositeDef
--- @param baseLevel number The base level of the unit
--- @return number The unit's level
---
UnitDataCompositeDef.GetLevel = function(self, baseLevel) return UnitProperties.GetLevel(self, baseLevel) end
---
--- Returns the initial maximum hit points for the unit.
---
--- @param self UnitDataCompositeDef
--- @return number The initial maximum hit points
---
UnitDataCompositeDef.GetInitialMaxHitPoints = function(self) return UnitProperties.GetInitialMaxHitPoints(self) end
---
--- Returns the units that like the given unit.
---
--- @param self UnitDataCompositeDef
--- @return table<string, boolean> A table of unit IDs that like the given unit, with the value being true.
---
UnitDataCompositeDef.GetLikedBy = function(self) return UnitProperties.GetLikedBy(self) end
---
--- Returns the units that dislike the given unit.
---
--- @param self UnitDataCompositeDef
--- @return table<string, boolean> A table of unit IDs that dislike the given unit, with the value being true.
---
UnitDataCompositeDef.GetDislikedBy = function(self) return UnitProperties.GetDislikedBy(self) end
---
--- Returns the unit's power.
---
--- @param self UnitDataCompositeDef
--- @return number The unit's power
---
UnitDataCompositeDef.GetUnitPower = function(self) end

---
--- Returns the unit's starting perks.
---
--- @param self UnitDataCompositeDef
--- @return table The unit's starting perks
---
UnitDataCompositeDef.GetStartingPerks = function(self) end

---
--- Returns the daily salary preview for the mercenary.
---
--- @param self UnitDataCompositeDef The mercenary unit.
--- @return number The daily salary preview for the mercenary.
---
UnitDataCompositeDef.GetSalaryPreview = function(self)
	return GetDailyMercSalary(self, 10)
end

---
--- Returns the mercenary's starting salary.
---
--- @param self UnitDataCompositeDef The mercenary unit.
--- @return number The mercenary's starting salary.
---
UnitDataCompositeDef.GetMercStartingSalary = function(self)
	 return UnitProperties.GetMercStartingSalary(self)
end

---
--- Returns the unit's salary increase property.
---
--- @param self UnitDataCompositeDef
--- @return number The unit's salary increase property
---
UnitDataCompositeDef.GetSalaryIncreaseProp = function(self)
	 return UnitProperties.GetSalaryIncreaseProp(self)
end

UnitDataCompositeDef.PropertyTabs = {
	{ TabName = "General", Categories = {
		Preset = true,
		Stats = true,
		General = true,
		XP = true,
		AI = true,
		["Derived Stats"] = true,
		Misc = true,
		Perks = true,		
		Equipment = true,		
	} },
	{ TabName = "Leveling", Categories = {
		XP = true,
		Stats = true,
		Perks = true,		
	} },	
	{ TabName = "Hiring", Categories = {
		Hiring = true,
		["Hiring - Parameters"] = true,
		["Hiring - Lines"] = true,
		["Hiring - Conditions"] = true,
	} },	
	{ TabName = "Appearance", Categories = {
		Appearance = true,		
	} },	
	{ TabName = "Likes&Dislikes", Categories = {
		["Likes And Dislikes"] = true,
	} },
	{ TabName = "Voices", Categories = {
		["Voice"] = true,
	} },
}

---
--- Iterates over all mercenary presets and calls the provided function for each one.
---
--- @param fn function The function to call for each mercenary preset. The function will be passed the ID of the mercenary preset.
---
function ForEachMerc(fn)
	ForEachPreset("UnitDataCompositeDef", function(preset)
		if preset.IsMercenary then fn(preset.id) end
	end)
end

---
--- Iterates over all mercenary presets and returns a sorted list of their IDs.
---
--- @return table A sorted table of mercenary preset IDs.
---
function MercPresetCombo()
	local ret = {}
	ForEachMerc(function(preset) table.insert(ret, preset) end)
	table.sort(ret)
	return ret
end

function OnMsg.CombatEnd(combat, any_enemies)
	if IsCageFighting() then return end --special map and scenario - skip vr's for end combat
	local merc = GetRandomMapMerc(nil, AsyncRand()) -- no need for sync random for VR purposes
	if merc and combat.current_turn>1 then
		if combat.retreat_enemies then
			CreateMapRealTimeThread(function() 
				Sleep(2740)
				PlayVoiceResponse(merc, "CombatEndEnemiesRetreated")
			end)
			combat.retreat_enemies = false
		elseif any_enemies then
			CreateMapRealTimeThread(function() 
				Sleep(2740)
				PlayVoiceResponse(merc, "CombatEndEnemiesRemain")
			end)
		else
			CreateMapRealTimeThread(function() 
				Sleep(2740)
				PlayVoiceResponse(merc, "CombatEndNoEnemies")
			end)	
		end
	end	
	-- reset voiceresponses for combat end
	CreateMapRealTimeThread(function()
		--add delay to the reset by design: 0185549
		Sleep(2000)
		ResetVoiceResponses("OncePerCombat")
	end)
end

---
--- Saves all UnitDataCompositeDef presets, and also saves a file containing a mapping of preset IDs to their associated Polly voice names.
---
--- This function is called when saving all presets, and is used to ensure that the Polly voice mapping is up-to-date.
---
--- @param force_save_all boolean If true, forces a full save of all presets, even if they haven't changed.
--- @param by_user_request boolean If true, the save was initiated by a user request.
--- @param ... any Additional arguments passed to the base SaveAll function.
---
function UnitDataCompositeDef:SaveAll(force_save_all, by_user_request, ...)
	if Platform.developer and config.VoicesTTS then
		g_LocPollyActorsMatchTable = {}
		local updatePollyActors = function (obj)
			if IsKindOf(obj, "PropertyObject") and obj:GetProperty("pollysim") ~= "none" then
				local voice_name = obj:GetProperty("pollyvoice") or ""
				local name = obj:GetProperty("id")
				g_LocPollyActorsMatchTable[name] = voice_name
			end
		end
		ForEachPreset("UnitDataCompositeDef", updatePollyActors)
		local file_path = "svnProject/Lua/Dev/VoiceLines/__voiceActorPollyMatch.lua"
		SaveSVNFile(file_path, "return "..TableToLuaCode(g_LocPollyActorsMatchTable))
	end
	
	Preset.SaveAll(self, force_save_all, by_user_request, ...)
end

-- UnitDataCompositDefs reference LootDef presets, and their GetError needs the parent table cache populated
-- make sure it is loaded by hooking something that happens to be called at the right moment
---
--- Populates the parent table cache for LootDef presets, then calls the base EditorContext function.
---
--- This function is called when the UnitDataCompositeDef editor context is accessed. It ensures that the LootDef parent table cache is populated, which is required for the GetError function to work correctly.
---
--- @param ... any Additional arguments passed to the base EditorContext function.
---
function UnitDataCompositeDef:EditorContext(...)
	PopulateParentTableCache(Presets.LootDef)
	return CompositeDef.EditorContext(self, ...)
end

-- Overwrite of the old PlaceUnitData 
---
--- Creates a new instance of a unit data class.
---
--- This function is used to create a new instance of a unit data class, such as a UnitDataCompositeDef. It handles the creation of the object based on the class definition and the provided instance data.
---
--- @param item_id string The ID of the unit data class to create.
--- @param instance table The instance data to use for the new object.
--- @param ... any Additional arguments to pass to the class constructor.
--- @return table The new instance of the unit data class.
---
function PlaceUnitData(item_id, instance, ...)
	local id = item_id

	local class = g_Classes[id]
	if not class then 
		printf("PlaceUnitData for invalid class %s", id)
		return PlaceUnitData("Dummy", instance, ...) 
	end

	local obj
	if UnitDataCompositeDef.store_as_obj_prop_list then
		obj = class:new({}, ...)
		SetObjPropertyList(obj, instance)
	else
		obj = class:new(instance, ...)
	end

	return obj
end
-- end of CompositeDef code

---
--- Synchronizes the placement of an item in a unit's inventory.
---
--- This function is called when a "PlaceItemInInventoryCheat" network event is received. It calls the `PlaceItemInInventoryCheat` function with the provided parameters, passing `true` for the `sync_call` argument to indicate that this is a synchronization call.
---
--- @param item_name string The name of the item to place in the inventory.
--- @param amount number The amount of the item to place.
--- @param container_id string The network ID of the container (unit) to place the item in.
--- @param drop_chance number The chance of the item dropping when placed in the inventory.
---
function NetSyncEvents.PlaceItemInInventoryCheat(item_name, amount, container_id, drop_chance)
	PlaceItemInInventoryCheat(item_name, amount, GetContainerFromContainerNetId(container_id), drop_chance, true)
end

---
--- Places an item in a unit's inventory.
---
--- This function is used to place an item in a unit's inventory. It handles the creation of the inventory item, setting its properties, and moving it to the unit's inventory. If this is a synchronization call, it skips the network event and directly places the item in the inventory.
---
--- @param item_name string The name of the item to place in the inventory.
--- @param amount number The amount of the item to place.
--- @param unit table The unit to place the item in.
--- @param drop_chance number The chance of the item dropping when placed in the inventory.
--- @param sync_call boolean Whether this is a synchronization call.
--- @return boolean, boolean The results of the `MoveItem` function call.
---
function PlaceItemInInventoryCheat(item_name, amount, unit, drop_chance, sync_call)
	assert(amount ~= 0)
	if not sync_call then
		unit = unit or GetMercInventoryDlg() and GetInventoryUnit() or SelectedObj
		NetSyncEvent("PlaceItemInInventoryCheat", item_name, amount, GetContainerNetId(unit), drop_chance)
		return
	end
	local item = PlaceInventoryItem(item_name)
	item.drop_chance = drop_chance or nil
	if IsKindOf(item, "InventoryStack") then
		item.Amount = amount or item.MaxStacks
	end
	-- for debug add data as is it is a result of combining items
	if IsKindOf(item,"TransmutedItemProperties") then
		local recipe = Recipes[item.class]
		if not recipe then
			for rec, rec_data in pairs(Recipes) do
				if rec_data.ResultItems and rec_data.ResultItems[1].item == item.class then
					recipe = rec_data
					break
				end
			end
		end
		if recipe then
			item.RevertCondition = recipe.RevertCondition
			item.RevertConditionCounter = recipe.RevertConditionValue
			item.OriginalItemId = recipe.Ingredients[1].item
		end
	end
	local args = {item = item, dest_container = unit, dest_slot = "Inventory", sync_call = true}
	local r, r2 = MoveItem(args)
	return r, r2
end

---
--- Places an item in the inventory of the currently selected unit.
---
--- This function is used to place an item in the inventory of the currently selected unit. It handles the creation of the inventory item, setting its properties, and moving it to the unit's inventory. If the selected object is not a unit inventory, the function will return without doing anything.
---
--- @param root table The root table of the UI element that triggered this function.
--- @param obj table The object that contains the item information to be placed in the inventory.
--- @param prop_id string The ID of the property that triggered this function.
--- @param self table The UI element that triggered this function.
---
function UIPlaceInInventory(root, obj, prop_id, self)
	if not IsKindOf(SelectedObj, "UnitInventory") or not obj then
		return
	end
	local r1, r2 = PlaceItemInInventoryCheat(obj.id)
	local unit = GetMercInventoryDlg() and GetInventoryUnit() or SelectedObj
	print("Trying to place item", obj.id, "in inventory of", unit.session_id)
end


---
--- Places all ingredients of the specified object in the inventory of the currently selected unit.
---
--- This function is used to place all ingredients of the specified object in the inventory of the currently selected unit. It iterates through the Ingredients table of the object and calls PlaceItemInInventory for each ingredient.
---
--- @param root table The root table of the UI element that triggered this function.
--- @param obj table The object that contains the ingredient information to be placed in the inventory.
--- @param prop_id string The ID of the property that triggered this function.
--- @param self table The UI element that triggered this function.
---
function UIPlaceIngredientsInInventory(root, obj, prop_id, self)
	if not IsKindOf(SelectedObj, "UnitInventory") or not obj then
		return
	end
	local ingredients  = obj.Ingredients
	for _, ing in ipairs(ingredients) do
		PlaceItemInInventory(ing.item)
	end
end

---
--- Places the appropriate ammo item in the inventory of the currently selected unit.
---
--- This function is used to place the appropriate ammo item in the inventory of the currently selected unit. It first retrieves a list of ammo items with the same caliber as the specified object, then finds the ammo item with the "AmmoBasicColor" color style and places it in the unit's inventory.
---
--- @param root table The root table of the UI element that triggered this function.
--- @param obj table The object that contains the ammo information to be placed in the inventory.
--- @param prop_id string The ID of the property that triggered this function.
--- @param self table The UI element that triggered this function.
---
function UIPlaceInInventoryAmmo(root, obj, prop_id, self)
	if not IsKindOf(SelectedObj, "UnitInventory") or not obj then
		return
	end
	local ammos = GetAmmosWithCaliber(obj.Caliber)
	local ammoKey = table.find(ammos, "colorStyle" , "AmmoBasicColor")
	if not ammoKey then
		ammoKey = 1
	end
	assert(ammos[ammoKey].id)
	PlaceItemInInventory(ammos[ammoKey].id)
end

function OnMsg.ClassesGenerate(classdefs)
	local props = classdefs.LootDef.properties
	local idx = table.find(props, "id", "TestFile")
	table.insert(props, idx and idx + 1 or -1, 
		{ category = "Test", id = "btnGenerateItems", 
			editor = "buttons", default = false, buttons = { {name = "Generate test loot", func = "GedUIGenerateAndDropLoot", is_hidden = function(self) return AreModdingToolsActive() end}, }, template = true, }
	)
	if config.Mods then
		local props = classdefs.ModItemLootDefEdit.properties
		table.insert(props, 
			{ category = "Test", id = "btnGenerateItems", 
				editor = "buttons", default = false, buttons = { {name = "Generate test loot", func = "GedUIGenerateAndDropLoot", is_hidden = function(self) return AreModdingToolsActive() end }, }, template = true, }
		)
	end
end

---
--- Generates and drops loot from a specified loot table.
---
--- This function is used to generate and drop loot from a specified loot table. It first retrieves the loot table by its ID, then generates the loot items and adds them to a container. The container is either placed at the currently selected unit's inventory, or on the ground if no unit is selected.
---
--- @param root table The root table of the UI element that triggered this function.
--- @param obj table The object that contains the loot table information.
--- @param prop_id string The ID of the property that triggered this function.
--- @param ged table The UI element that triggered this function.
---
function GedUIGenerateAndDropLoot(root, obj, prop_id, ged)
	local table_id = obj.id or obj.TargetId
	local name = obj.TargetId and obj.name or false
	if not table_id then return end
	UIGenerateAndDropLoot(table_id, name, ged)
end

---
--- Generates and drops loot from a specified loot table.
---
--- This function is used to generate and drop loot from a specified loot table. It first retrieves the loot table by its ID, then generates the loot items and adds them to a container. The container is either placed at the currently selected unit's inventory, or on the ground if no unit is selected.
---
--- @param table_id string The ID of the loot table to generate loot from.
--- @param name string The name of the loot table (optional).
--- @param ged table The UI element that triggered this function.
---
function UIGenerateAndDropLoot(table_id, name, ged)
	if not table_id then return end
	local loot_tbl = LootDefs[table_id]
	if not loot_tbl then return end
	
	local unit = GetMercInventoryDlg() and GetInventoryUnit() or SelectedObj
	local pos 
	if not unit then
		pos = terrain.FindPassable(GetCursorPos())
		pos = pos and SnapToPassSlab(pos)
	end	
	local bag = GetDropContainer(unit, pos)
	local items, texts = {}, {}
	loot_tbl:GenerateLoot(bag, {}, InteractionRand(nil, "LootTest"), items)
	for _,item in ipairs(items) do
		local amount = IsKindOf(item, "InventoryStack") and item.Amount or 1
		table.insert(texts, string.format("\t%3d x %s", amount, item.DisplayName and _InternalTranslate(item.DisplayName) or item.class))
	end
	AddItemsToInventory(bag, items)
	
	if config.ModdingToolsInUserMode then
		ged:ShowMessage("Loot Generated", table.concat(texts, "\n"))
	else
		print("Test item generation from loot table: ", name or table_id)
		print(table.concat(texts, "\n"))
	end
end

if config.Mods then  
	ModItemLootDef.TestDescription = "Places a loot container on the ground with the defined loot inside."
	ModItemLootDefEdit.TestDescription = "Places a loot container on the ground with the defined loot inside."
	
	function ModItemLootDef:TestModItem(ged)
		UIGenerateAndDropLoot(self.id, ged)	
	end

	function ModItemLootDefEdit:TestModItem(ged)
		UIGenerateAndDropLoot(self.TargetId, self.name, ged)	
	end
end

local all_caps_stats = {
	Health = T(939485407221, "HEALTH"),
	Agility = T(896381935221, "AGILITY"),
	Dexterity = T(326250337641, "DEXTERITY"),
	Strength = T(250860654401, "STRENGTH"),
	Leadership = T(209792662352, "LEADERSHIP"),
	Wisdom = T(497213135536, "WISDOM"),
	Marksmanship = T(173881749528, "MARKSMANSHIP"),
	Mechanical = T(635077702917, "MECHANICAL"),
	Explosives = T(587803252973, "EXPLOSIVES"),
	Medical = T(295164282418, "MEDICAL"),
}

---
--- Returns the all-caps name for a given stat property ID.
---
--- If the property ID is found in the `all_caps_stats` table, the corresponding
--- all-caps name is returned. Otherwise, if the platform is not in developer
--- mode, the property ID is converted to all-caps and returned.
---
--- @param prop_id string The property ID to get the all-caps name for.
--- @return string The all-caps name for the given property ID.
---
function GetStatAllCapsName(prop_id)
	return all_caps_stats[prop_id] or not Platform.developer and prop_id:upper() -- for props added my modders, all caps it assuming English language
end

-- Only for Elite Units
GameVar("gv_UsedEliteNames", {})
---
--- Generates a unique elite unit name for the given unit.
---
--- If the unit is an elite unit, this function will select a random name from the
--- "EliteEnemyName" preset group that matches the unit's `eliteCategory` property.
--- If no `eliteCategory` is set, it will select from the full "EliteEnemyName"
--- preset group. The selected name is assigned to the unit's `Name` property.
--- 
--- To avoid reusing the same name, this function keeps track of the used names
--- in the `gv_UsedEliteNames` global variable.
---
--- @param unit table The unit to generate a name for.
---
function GenerateEliteUnitName(unit)
	if unit and unit.elite then
		local namePool = {}
		if unit.eliteCategory then
			ForEachPresetInGroup("EliteEnemyName", unit.eliteCategory, function(preset)
				namePool[#namePool+1] = preset
			end)
		else
			namePool = PresetArray("EliteEnemyName")
		end
		
		while #namePool > 0 do
			local rand = InteractionRand(#namePool, "EliteName") + 1
			if not table.find(gv_UsedEliteNames, namePool[rand].id) then
				unit.Name = namePool[rand].name
				gv_UsedEliteNames[#gv_UsedEliteNames+1] = namePool[rand].id
				return
			else
				table.remove(namePool, rand)
			end
		end
	end
end

-- XP
---
--- Calculates the reward experience for a unit based on the given per-unit experience.
---
--- The function takes into account the unit's Wisdom stat and applies a bonus to the
--- per-unit experience based on the difference between the unit's Wisdom and 60.
---
--- @param unit table The unit to calculate the reward experience for.
--- @param perUnitExp number The base per-unit experience to apply.
--- @return number The calculated reward experience for the unit.
---
function CalcRewardExperienceToUnit(unit, perUnitExp)
	return perUnitExp + MulDivRound(perUnitExp,(unit.Wisdom - 60),200)
end

---
--- Accumulates the experience gained by a team member.
---
--- This function keeps track of the total experience gained by each team member in the
--- `g_AccumulatedTeamXP` global table. If the team member's log name already exists in
--- the table, the function adds the new experience gained to the existing value. Otherwise,
--- it creates a new entry in the table with the team member's log name as the key and the
--- new experience gained as the value.
---
--- @param unitLogName string The log name of the team member.
--- @param xpGained number The amount of experience gained by the team member.
---
function AccumulateTeamMemberXp(unitLogName, xpGained)
	if g_AccumulatedTeamXP[unitLogName] then
		g_AccumulatedTeamXP[unitLogName] = g_AccumulatedTeamXP[unitLogName] + xpGained
	else
		g_AccumulatedTeamXP[unitLogName] = xpGained
	end
end

---
--- Handles the experience gained by a unit.
---
--- This function updates the unit's experience and checks if the unit has leveled up.
--- If the unit has leveled up, it increases the unit's perk points, sets the
--- `TutorialHintsState.GainLevel` flag, logs an important combat log message, and
--- triggers the `UnitLeveledUp` message.
---
--- @param unit table The unit that gained experience.
--- @param xp number The amount of experience gained by the unit.
---
function UnitGainXP(unit, xp)
	local previousLvl = unit:GetLevel()
	unit.Experience = (unit.Experience or 0) + xp
	local newLvl = unit:GetLevel()
	
	if xp > 0 then
		CombatLog("short", T{564767483783, "Gained XP: <unit> (<em><gain></em>)", unit = unit:GetLogName(), gain = xp})
	end
	
	local levelsGained = newLvl - previousLvl
	if levelsGained > 0 then
		unit.perkPoints = unit.perkPoints + 1
		TutorialHintsState.GainLevel = true
		CombatLog("important", T{134899495484, "<DisplayName> has reached <em>level <level></em>", SubContext(unit, { level = newLvl})})
		ObjModified(unit)
		Msg("UnitLeveledUp", unit)
	end
end

---
--- Rewards the team with experience gained from defeating a unit.
---
--- This function calculates the amount of experience to be rewarded to the team based on the defeated unit's level and any applicable experience bonuses. It then distributes the experience evenly among the living members of the team, updating their experience and checking if any team members have leveled up as a result. If any team members have leveled up, their perk points are increased, the `TutorialHintsState.GainLevel` flag is set, and a combat log message is generated.
---
--- @param defeatedUnit table The unit that was defeated and is providing the experience reward.
--- @param team table The team that will receive the experience reward.
--- @param logImportant boolean If true, the combat log message will be marked as important.
---
function RewardTeamExperience(defeatedUnit, team, logImportant)
	if not team or not team.units or #team.units == 0 then return end

	local xpToReward = defeatedUnit.RewardExperience
	if not xpToReward then
		local level = defeatedUnit:GetLevel()
		xpToReward = XPRewardTable[level] or XPRewardTable[#XPRewardTable] or 0
	end
	
	local array = team.units
	if type(array[1]) == "string" then
		array = GetMercArrayUnitData(team.units)
	end
	
	local livingUnits = {} -- Unit data should all be alive, but units might not be, check just in case.
	for i, u in ipairs(array) do
		if not u:IsDead() then
			livingUnits[#livingUnits + 1] = u
		end
	end
	array = livingUnits;
	
	local xpBonusPercent = 0
	for i, u in ipairs(array) do -- add one time bonus xp from Teacher
		if HasPerk(u, "Teacher") then
			xpBonusPercent = xpBonusPercent + CharacterEffectDefs.Teacher:ResolveValue("squad_exp_bonus")
			break
		end
	end
	for i, u in ipairs(array) do -- add one time bonus xp from OldDog
		if HasPerk(u, "OldDog") then
			xpBonusPercent = xpBonusPercent + CharacterEffectDefs.OldDog:ResolveValue("old_dog_XP_bonus")
			break
		end
	end
	xpToReward = xpToReward + MulDivRound(xpToReward, xpBonusPercent, 100)
	
	local leveled_up = {}
	local log_msg
	local perUnit = MulDivRound(xpToReward, 1000, #team.units * 1000)

	for i, u in ipairs(array) do
		local previousLvl = u:GetLevel()
		local gain = CalcRewardExperienceToUnit(u, perUnit)
		local unitLogName = u:GetLogName()
		
		ReceiveStatGainingPoints(u, gain)
		u.Experience = (u.Experience or 0) + gain
		local newLvl = u:GetLevel()
		
		if g_AccumulatedTeamXP then
			AccumulateTeamMemberXp(unitLogName, gain)
		elseif gain > 0 then
			if i == 1 then
				log_msg = T{564767483783, "Gained XP: <unit> (<em><gain></em>)", unit = unitLogName, gain = gain}
			else
				log_msg = log_msg .. T{978587146153, ", <unit> (<em><gain></em>)", unit = unitLogName, gain = gain}
			end
		end
		
		local levelsGained = newLvl - previousLvl
		if levelsGained > 0 then
			leveled_up[#leveled_up + 1] = u
			u.perkPoints = u.perkPoints + 1
			TutorialHintsState.GainLevel = true
		end
	end
	
	if log_msg and not g_AccumulatedTeamXP then
		CombatLog(logImportant and "important" or "short", log_msg)
	end
		
	for _, u in ipairs(leveled_up) do
		CombatLog("important", T{134899495484, "<DisplayName> has reached <em>level <level></em>", SubContext(u, { level = u:GetLevel() })})
		ObjModified(u)
		Msg("UnitLeveledUp", u)
	end
end

-- Experience point thresholds per level.
XPTable =
{
	0, -- Level 1
	1000,
	2500,
	4500,
	7000, -- Level 5
	10000,
	13500,
	17500,
	22000,
	27000 -- Level 10
}

---
--- Gets the experience point (XP) table value for the given level.
---
--- If the "HardLessons" game rule is active, the XP table values are modified by the
--- "XPTableModifier" value defined in the game rule.
---
--- @param level number|nil The level to get the XP table value for. If nil, the entire XP table is returned.
--- @return number|table The XP table value for the given level, or the entire XP table if level is nil.
---
function GetXPTable(level)
	if IsGameRuleActive("HardLessons") then 
		local percent = 100 + (GameRuleDefs.HardLessons:ResolveValue("XPTableModifier") or 0)
		if level then
			return MulDivRound(XPTable[level], percent, 100)
		else
			return table.imap(XPTable,function(xp) return MulDivRound(xp, percent, 100) end)
		end
	end
	return level and XPTable[level] or XPTable
end

---
--- Calculates the level for the given experience points (XP).
---
--- If the XP is less than the XP required for the next level, the current level is returned.
--- If the XP is greater than or equal to the XP required for the highest level, the highest level is returned.
---
--- @param xp number The experience points to calculate the level for.
--- @return number The level corresponding to the given experience points.
---
function CalcLevel(xp)
	local nXPTable = #XPTable
	for i = 1, nXPTable do
		if xp < GetXPTable(i) then
			return i - 1
		end
	end
	return nXPTable	
end

---
--- Calculates the experience point (XP) percentage and level for the given XP.
---
--- If the XP is greater than or equal to the XP required for the highest level, the percentage is 100% and the highest level is returned.
--- Otherwise, the percentage of the XP towards the next level is calculated and the current level is returned.
---
--- @param xp number The experience points to calculate the percentage and level for.
--- @return number, number The XP percentage (multiplied by 10 for precision to tenths) and the level corresponding to the given XP.
---
function CalcXpPercentAndLevel(xp)
	local level = CalcLevel(xp)
	local nXPTable = #XPTable
	if level == nXPTable then
		return 100 * 10, nXPTable
	else
		local levelxp = GetXPTable(level)
		return MulDivRound(xp - levelxp, 100 * 10, GetXPTable(level + 1) - levelxp), level
	end
end
function CalcXpPercentAndLevel(xp) -- multiplied by 10 for precision to tenths
	local level = CalcLevel(xp)
	local nXPTable = #XPTable
	if level == nXPTable then
		return 100 * 10, nXPTable
	else
		local levelxp = GetXPTable(level)
		return MulDivRound(xp - levelxp, 100 * 10, GetXPTable(level + 1) - levelxp), level
	end
end

-- XP rewards for defeating an enemy, based on the enemy level
XPRewardTable =
{
	40, -- Level 1
	45,
	50,
	60,
	70, -- Level 5
	80,
	95,
	110,
	125,
	150 -- Level 10
}

-- Get the generic hire amount merc price.
---
--- Calculates the price and medical deposit for hiring a mercenary for the specified number of days.
---
--- @param unit_data UnitProperties The mercenary unit data.
--- @param days number The number of days to hire the mercenary for. Defaults to 7 days.
--- @param include_medical boolean Whether to include the medical deposit in the price. Defaults to true.
--- @param level number The mercenary's level. Defaults to the level from the unit_data.
--- @return number, number The total price to hire the mercenary, and the medical deposit amount.
---
function GetMercPrice(unit_data, days, include_medical, level)
	days = days or 7
	level = level or unit_data:GetLevel()

	local daily = GetDailyMercSalary(unit_data, level)
	local percentDiscount = 100 - GetMercDurationDiscountPercent(unit_data, days)
	local price = MulDivRound(daily * days, percentDiscount, 100 * 10) * 10 -- Round to tens
	
	local oneLessDay = (days - 1)
	local oneDayLessDiscount = 100 - GetMercDurationDiscountPercent(unit_data, oneLessDay)
	local oneDayLessPrice = MulDivRound(daily * oneLessDay, oneDayLessDiscount, 100 * 10) * 10
	local minRaise = oneDayLessPrice + 100
	if price < minRaise then -- Ensure that adding days is always at least $100 more expensive.
		price = minRaise
	end

	local medical = include_medical and CalculateMedical(unit_data) or 0
	price = price + medical
	
	return price, medical
end

---
--- Formats the price for hiring a mercenary.
---
--- @param ctx UnitProperties The mercenary unit data.
--- @param days number The number of days to hire the mercenary for.
--- @param include_medical boolean Whether to include the medical deposit in the price.
--- @return string The formatted price for hiring the mercenary.
---
TFormat.MercPrice = function(ctx, days, include_medical)
	return TFormat.money(ctx, GetMercPrice(ctx, days, include_medical))
end

---
--- Formats the price for hiring a mercenary.
---
--- @param ctx UnitProperties The mercenary unit data.
--- @param days number The number of days to hire the mercenary for.
--- @param include_medical boolean Whether to include the medical deposit in the price.
--- @return string The formatted price for hiring the mercenary.
---
TFormat.MercPriceBioPage = function(ctx, days, include_medical)
	local money = Game.Money
	local price, medical = GetMercPrice(ctx, days, include_medical)
	
	local medicalTextAdd = ""
	if medical > 0 then
		medicalTextAdd = T{203193755258, " (incl. <money(medicalAmount)> medical)", medicalAmount = medical}
	end
	
	if price > money then
		return T{733522960694, "<color MercStatValue_TooExpensive><money(price)></color>", price = price} .. medicalTextAdd
	end
	return T{409566110387, "<money(price)>", price = price} .. medicalTextAdd
end

---
--- Formats the price for hiring a mercenary on the bio page rollover.
---
--- @param ctx UnitProperties The mercenary unit data.
--- @return string The formatted price for hiring the mercenary, including the medical deposit information.
---
TFormat.MercPriceBioPageRollover = function(ctx)
	if not IsKindOf(ctx, "UnitProperties") then
		ctx = ctx:ResolveValue()
		if not IsKindOf(ctx, "UnitProperties") then
			return false
		end
	end

	local defaultContractRollover = T(180617047212, "The contract cost of this merc for a week.")
	local medicalRollover = T(624700359694, "The Medical deposit will be refunded if the merc is healthy at the end of their contract. It will be partially refunded if the merc is wounded at the end of the contract and lost if the merc is heavily wounded or killed in action.")

	local rolloverText = defaultContractRollover
	local price, medical = GetMercPrice(ctx, 7, true)	
	local medicalTextAdd = ""
	if medical > 0 then
		rolloverText = rolloverText .. "<newline><newline>" .. medicalRollover
	end

	return rolloverText
end

---
--- Calculates the minimum number of days the player can afford to hire a mercenary.
---
--- @param mercUd UnitProperties The mercenary unit data.
--- @param min number The minimum number of days to hire the mercenary for.
--- @param def number The default number of days to hire the mercenary for.
--- @return number The minimum number of days the player can afford to hire the mercenary for.
---
function GetMercMinDaysCanAfford(mercUd, min, def)
	local level = mercUd:GetLevel()
	local daily = GetDailyMercSalary(mercUd, level)
	
	local medical = CalculateMedical(mercUd)
	local moneyAvail = Game.Money - medical
	moneyAvail = moneyAvail
	
	if mercUd.HireStatus == "Hired" then
		moneyAvail = moneyAvail + const.Satellite.PlayerMaxDebt
	end
	
	local daysCanAfford = moneyAvail / daily
	
	if daysCanAfford > def then return def end
	if daysCanAfford < min then return min end
	
	return daysCanAfford
end

---
--- Calculates the daily salary for a mercenary based on their starting level and current level.
---
--- @param merc UnitProperties The mercenary unit data.
--- @param level number The current level of the mercenary. If not provided, the mercenary's current level will be used.
--- @return number The daily salary for the mercenary.
---
function GetDailyMercSalary(merc, level)
	local startingLevel = merc:GetProperty("StartingLevel")
	local currentLevel = level or merc:GetLevel()
	
	local levelsOver = currentLevel - startingLevel

	local salaryAtStartingLevel = merc:GetMercStartingSalary()
	
	local salaryIncrease = merc:GetSalaryIncreaseProp()
	local currentSalary = salaryAtStartingLevel
	for level = startingLevel, currentLevel - 1 do
		local increaseAmount = MulDivRound(currentSalary, salaryIncrease, 1000)
		currentSalary = currentSalary + increaseAmount 
	end

	return currentSalary
end

---
--- Calculates the duration discount percentage for a mercenary based on the duration of hire.
---
--- @param merc UnitProperties The mercenary unit data.
--- @param duration number The duration of hire for the mercenary.
--- @return number The duration discount percentage.
---
function GetMercDurationDiscountPercent(merc, duration)
	local discount = merc:GetProperty("DurationDiscount")
	if discount == "none" then return 0 end
	
	local minDay, minDiscount, maxDay, maxDiscount = 0,0,0,0
	if discount == "normal" then
		minDay = 3
		minDiscount = 0
		maxDay = 14
		maxDiscount = 25
	elseif discount == "long only" then
		minDay = 7
		minDiscount = 0
		maxDay = 14
		maxDiscount = 35
	end
	
	if duration >= minDay and duration <= maxDay then
		return minDiscount + MulDivRound(duration - minDay, (maxDiscount - minDiscount), maxDay - minDay)
	end
	return 0
end

---
--- Calculates the medical deposit amount for a mercenary based on their starting salary and the medical deposit type.
---
--- @param merc UnitProperties The mercenary unit data.
--- @return number The medical deposit amount.
---
function CalculateMedical(merc)
	local deposit = merc:GetProperty("MedicalDeposit")
	if deposit == "none" then return 0 end

	local level = merc:GetLevel()
	local salary = merc:GetMercStartingSalary()
	
	if deposit == "small" then
		-- 1 daily salary
		return salary
	elseif deposit == "large" then
		-- 2 daily salaries
		return MulDivRound(salary, 200, 100 * 10) * 10
	elseif deposit == "extreme" then
		-- 3 daily salaries
		return MulDivRound(salary, 300, 100 * 10) * 10
	end
end

--- Calculates the haggle amount for a mercenary based on their haggling skill.
---
--- @param merc UnitProperties The mercenary unit data.
--- @param offeredAmount number The offered amount to haggle.
--- @return number The haggled amount.
function CalculateHaggleAmount(merc, offeredAmount)
	local haggle = merc:GetProperty("Haggling")
	local percent, min = 0, 0
	if haggle == "low" then
		percent = 10
		min = 100
	elseif haggle == "normal" then
		percent = 25
		min = 200
	elseif haggle == "high" then
		percent = 50
		min = 500
	end
	local haggleAmount = MulDivRound(offeredAmount, percent * 10, 1000)
	return Max(haggleAmount, min)
end

---
--- Formats the medical deposit amount for a mercenary as a money string.
---
--- @param context UnitProperties The mercenary unit data.
--- @return string The formatted medical deposit amount.
---
function TFormat.MedicalMoney(context, val)
	return TFormat.money(context, CalculateMedical(context) or 0)
end

---
--- Sets a flag in the mercenary state tracker for the specified mercenary.
---
--- @param mercId string The ID of the mercenary.
--- @param flag string The name of the flag to set.
--- @param value any The value to set the flag to.
---
function SetMercStateFlag(mercId, flag, value)
	local trackerQuest = QuestGetState("MercStateTracker")
	assert(trackerQuest)
	local mercTable = trackerQuest[mercId]
	if not mercTable then
		trackerQuest[mercId] = {}
		mercTable = trackerQuest[mercId]
	end
	mercTable[flag] = value
end

---
--- Gets the value of a flag in the mercenary state tracker for the specified mercenary.
---
--- @param mercId string The ID of the mercenary.
--- @param flag string The name of the flag to get.
--- @return any The value of the specified flag.
---
function GetMercStateFlag(mercId, flag)
	local trackerQuest = QuestGetState("MercStateTracker")
	assert(trackerQuest)
	local mercTable = trackerQuest[mercId]
	if not mercTable then
		trackerQuest[mercId] = {}
		mercTable = trackerQuest[mercId]
	end
	return mercTable[flag]
end

-- Medical deposit logic 165599 ad. 184562
function OnMsg.MercHireStatusChanged(unit_data, previousState, newState)
	local merc_id = unit_data.session_id
	if previousState == "Available" and newState == "Hired" then
		SetMercStateFlag(merc_id, "DownedDuringContract", false)
		SetMercStateFlag(merc_id, "MedicalPaidWhenHired", CalculateMedical(unit_data))
		SetMercStateFlag(merc_id, "RejectedRehire", false)
		SetMercStateFlag(merc_id, "HiredAt", Game.CampaignTime)
		SetMercStateFlag(merc_id, "HireCount", 1) -- How many times the contract has been extended
		MercHealOnHire(merc_id)
	elseif previousState == "Hired" and newState == "Available" then
		SetMercStateFlag(merc_id, "LastHiredAt", Game.CampaignTime)
	
		local medical = GetMercStateFlag(merc_id, "MedicalPaidWhenHired")
		if medical and medical > 0 then
			local mercHp = unit_data.HitPoints
			local mercMaxHp = unit_data:GetInitialMaxHitPoints() -- without wounds
			local percentHp = MulDivRound(mercHp, 100, mercMaxHp)
			
			local dontPayBelowPercent = 20
			percentHp = Max(0, percentHp - dontPayBelowPercent)
			if percentHp < dontPayBelowPercent then percentHp = 0 end
			
			medical = MulDivRound(medical, percentHp, 100 - dontPayBelowPercent)
			if medical > 0 then
				CombatLog("important", T{619266158254, "<Nick> has returned their medical deposit", unit_data})
				AddMoney(medical, "deposit")
			end
		end
	end
	
	-- Add random amount of xp on first hire 204339
	local isImp = not not string.find(merc_id, "IMP")
	if newState == "Hired" and not GetMercStateFlag(merc_id, "RandomEXPGiven") then -- and not isImp then
		local randomXpRangeMin = GetXPTable(1)
		local randomXpRangeMax = GetXPTable(2)
		local range = randomXpRangeMax - randomXpRangeMin
		range = MulDivRound(range, 600, 1000)
		range = randomXpRangeMin + InteractionRand(range, "RandomXPOnHire")
		unit_data.Experience = (unit_data.Experience or 0) + range
		local unit = g_Units[merc_id]
		if unit then
			unit.Experience = (unit.Experience or 0) + range
		end
		SetMercStateFlag(merc_id, "RandomEXPGiven", true)
	end
end

-- Mercs are healed when hired (but not contract extended) based on how
-- much time elapsed since they were last hired. This is an approximation of the RnR operation
---
--- Heals the mercenary when they are hired, based on the time elapsed since their last hire.
--- This is an approximation of the R&R (Rest and Recuperation) operation.
---
--- @param merc_id string The session ID of the mercenary.
---
function MercHealOnHire(merc_id)
	local ud = gv_UnitData[merc_id]
	local lastHireExpire = GetMercStateFlag(merc_id, "LastHiredAt")
	if not lastHireExpire then return end -- Wasn't hired before
	
	local timeElapsed = Game.CampaignTime - lastHireExpire
	local ticksPassed = timeElapsed / const.Satellite.Tick
	
	if ticksPassed > 0 then
		local woundStacks = PatientGetWoundedStacks(ud)
		ud.wounds_being_treated = PatientGetWoundedStacks(ud)
		
		local perTick = SectorOperations.RAndR:ResolveValue("HealPerTickBase")
		local threshold = SectorOperations.RAndR:ResolveValue("HealWoundThreshold") -- progress to heal one wound
		
		PatientAddHealWoundProgress(ud, perTick * ticksPassed, threshold, "no_log")
	end 
	
	-- Always heal to full and restore tiredness
	ud.HitPoints = ud.MaxHitPoints
	ud:SetTired(const.utNormal)
	
	ud.randr_activity_progress = 0
	ud.wounds_being_treated = 0
end

function OnMsg.MercContractExtended(merc)
	local merc_id = merc.session_id
	SetMercStateFlag(merc_id, "HiredAt", Game.CampaignTime)
	SetMercStateFlag(merc_id, "HireCount", (GetMercStateFlag(merc_id, "HireCount") or 1) + 1)
end

function OnMsg.UnitDowned(unit)
	local sessionId = IsMerc(unit) and unit.session_id
	if not sessionId then return end
	SetMercStateFlag(sessionId, "DownedDuringContract", true)
end

-- used by Combat participation condition
function OnMsg.ConflictStart(sector_id)
	if not next(gv_Quests) then return end -- Quick Start starts a conflict before quests are initialized.

	local squads = GetSquadsInSector(sector_id)
	for i, squad in ipairs(squads) do
		if squad.Side == "player1" then
			for i, uid in ipairs(squad.units) do
				local ud = gv_UnitData[uid]
				if IsMerc(ud) then
					local conflictList = GetMercStateFlag(uid, "ConflictsParticipated") or {}
					conflictList[#conflictList + 1] = { sector_id, Game.CampaignTime }
					SetMercStateFlag(uid, "ConflictsParticipated", conflictList)
				end
			end
		end
	end
end

---
--- Returns the number of conflicts a mercenary has participated in within the last specified number of days.
---
--- @param merc_id string The session ID of the mercenary.
--- @param days number The number of days to check for conflict participation.
--- @param unique_sectors boolean If true, only count each sector once, even if the mercenary participated in multiple conflicts in that sector.
--- @return number The number of conflicts the mercenary has participated in within the last specified number of days.
function GetMercConflictsParticipatedWithinLastDays(merc_id, days, unique_sectors)
	local list = GetMercStateFlag(merc_id, "ConflictsParticipated")
	if not list then return 0 end
	local day = Game.CampaignTime / const.Scale.day

	local count = 0
	local sectorsDedupe = {}
	for i, conflict in ipairs(list) do
		local where = conflict[1]
		local when = conflict[2] / const.Scale.day
		if day - when > days then goto continue end
		if unique_sectors and sectorsDedupe[where] then goto continue end
		sectorsDedupe[where] = true;
		count = count + 1
		
		::continue::
	end
	return count
end

-- Stat Gaining

---
--- Receives stat gaining points for a unit based on their experience gain.
---
--- @param unit table The unit to receive the stat gaining points.
--- @param xpGain number The amount of experience gained by the unit.
---
function ReceiveStatGainingPoints(unit, xpGain)
	if HasPerk(unit, "OldDog") then return end
	
	local xp = unit.Experience
	local xpPercent, level = CalcXpPercentAndLevel(xp)
	local pointsToGain = 0
	
	local xpTresholds = {}
	local interval = 1000 / const.StatGaining.PointsPerLevel
	for i=1, const.StatGaining.PointsPerLevel-1 do
		xpTresholds[#xpTresholds+1] = (xpTresholds[#xpTresholds] or 0) + interval
	end
	xpTresholds[#xpTresholds+1] = 1000
	local nXPTable = #XPTable
	while level < nXPTable and xpGain > 0 do -- loop per levelup, check all milestones
		local tempXp = Min(xpGain, GetXPTable(level + 1) - GetXPTable(level))
		xp = xp + tempXp
		xpGain = xpGain - tempXp
		
		local newXpPercent, newLevel = CalcXpPercentAndLevel(xp)
		if newLevel > level then newXpPercent = 100 * 10 end
		
		for i = 1, #xpTresholds do
			if xpPercent < xpTresholds[i] and newXpPercent >= xpTresholds[i] then
				pointsToGain = pointsToGain + 1
			end
		end
		
		level = newLevel
		xpPercent = 0
	end
	
	if level == nXPTable and xpGain > 0 then -- after max level
		local xpSinceLastMilestone = (xp - GetXPTable(nXPTable))
		-- Currently after lvl 10 you get a point every <MilestoneAfterMax> xp increasing by <MilestoneAfterMaxIncrement> xp every time
		local milestone = const.StatGaining.MilestoneAfterMax
		local increment = const.StatGaining.MilestoneAfterMaxIncrement
		while xpSinceLastMilestone >= milestone do
			xpSinceLastMilestone = xpSinceLastMilestone - milestone
			milestone = milestone + increment
		end
		
		while xpGain > 0 do -- loop per after max level milestone
			local xpToMilestone = milestone - xpSinceLastMilestone
			local tempXp = Min(xpGain, xpToMilestone)
			xp = xp + tempXp
			xpGain = xpGain - tempXp
			
			if tempXp >= xpToMilestone then
				pointsToGain = pointsToGain + 1
				xpSinceLastMilestone = 0
				milestone = milestone + increment
			end
		end
	end
	unit.statGainingPoints = unit.statGainingPoints + pointsToGain
end

StatGainReason = {
	FieldExperience = T(417395547281, "Field Experience"),
	Studying = T(713701397094, "Studying"),
	Training = T(168227169104, "Training"),
}

---
--- Increases a unit's stat by the specified amount.
---
--- @param unit table The unit to gain the stat.
--- @param stat string The stat to increase.
--- @param [gainAmount] number The amount to increase the stat by. Defaults to 1.
--- @param [modId] string The unique identifier for the modifier. Defaults to a generated string.
--- @param [reason] string The reason for the stat gain. Defaults to "FieldExperience".
---
--- @return string The stat that was increased.
function GainStat(unit, stat, gainAmount, modId, reason)
	assert(stat)
	if unit:IsDead() then return end
	local unitData = gv_UnitData[unit.session_id]
	local unit = g_Units[unit.session_id]
	gainAmount = gainAmount or 1
	reason = reason or "FieldExperience"
	
	modId = modId or string.format("StatGain-%s-%s-%d", stat, unitData.session_id, GetPreciseTicks())
	local mod = unitData:AddModifier(modId, stat, false, gainAmount)
	if unit then
		unit:AddModifier(modId, stat, false, gainAmount)
	end
	Msg("ModifierAdded", unitData, stat, mod)
	
	local unitName = unitData:GetLogName()
	local statName = table.find_value(UnitPropertiesStats:GetProperties(), "id", stat).name
	if reason ~= "Training" then
		CombatLog("important", T{124938068325, "<em><unit></em> gained +<amount> <em><stat></em>",
			unit = unitName,
			stat = statName,
			amount = gainAmount
		})
	end
	if stat == "Health" then
		if unit then
			RecalcMaxHitPoints(unit)
		end
		RecalcMaxHitPoints(unitData)
	end

	ObjModified(unit)
	ObjModified(unitData)
	
	Msg("StatIncreased", unitData, stat, gainAmount, reason)
	PlayFX("StatIncreased", "start", stat)
	return stat
end

---
--- Gets the current state of a prerequisite for a unit.
---
--- @param unit table The unit to get the prerequisite state for.
--- @param id string The unique identifier of the prerequisite.
---
--- @return boolean The current state of the prerequisite.
---
function GetPrerequisiteState(unit, id)
	local statGaining = GetMercStateFlag(unit.session_id, "StatGaining") or {}
	if statGaining[id] then
		return statGaining[id].state
	else
		return false
	end
end

MapVar("g_StatGainingMapCDs", {}) 
--	state: Custom information that needs to be saved and tracked
--	gain: 	If the unit achieved the prerequisite
---
--- Sets the state of a prerequisite for a unit's stat gaining.
---
--- @param unit table The unit to set the prerequisite state for.
--- @param id string The unique identifier of the prerequisite.
--- @param state boolean The new state of the prerequisite.
--- @param gain boolean Whether the prerequisite was just gained.
---
--- If the prerequisite was just gained, this function will reset the state and roll for a stat gain.
--- If the prerequisite state is being updated, this function will simply update the state.
---
--- The state and gain information is stored in the "StatGaining" table for the unit's session.
---
--- If the prerequisite has the "oncePerMapVisit" flag set, this function will also check and set a global cooldown to prevent multiple gains per map visit.
---
function SetPrerequisiteState(unit, id, state, gain)
	NetUpdateHash("SetPrerequisiteState", unit, id, state, gain)
	local statGaining = GetMercStateFlag(unit.session_id, "StatGaining") or {}
	if not statGaining[id] then statGaining[id] = {} end
	
	if gain then -- reset the state
		statGaining[id].state = false
	else -- update the state
		statGaining[id].state = state 
	end
	SetMercStateFlag(unit.session_id, "StatGaining", statGaining)
	
	if gain then -- roll for statgain
		local prerequisite = StatGainingPrerequisites[id]
		local stat = prerequisite.relatedStat
		local failChance =  prerequisite.failChance
		
		if not prerequisite.oncePerMapVisit or not g_StatGainingMapCDs[id] then
			RollForStatGaining(unit, stat, failChance)
		end
		g_StatGainingMapCDs[id] = true
	end	
end

---
--- Rolls for a stat gain for the given unit.
---
--- @param unit table The unit to roll for a stat gain.
--- @param stat string The stat to roll for.
--- @param failChance number The chance of the roll failing.
---
--- This function checks if the unit has any stat gaining points left, if the stat is within the valid range, and if the stat is not on cooldown. If all conditions are met, it rolls for a stat gain. If the roll is successful, the stat is increased and the cooldown for that stat is set. The function also logs the result of the roll.
---
function RollForStatGaining(unit, stat, failChance)
	local statGaining = GetMercStateFlag(unit.session_id, "StatGaining") or {}
	local cooldowns = statGaining.Cooldowns or {}
	local success_text = "(fail) "
	local reason_text = ""
	
	local roll = InteractionRand(100, "StatGaining")
	if not failChance or roll >= failChance then
		if unit.statGainingPoints > 0 then 
			if(not cooldowns[stat] or cooldowns[stat] <= Game.CampaignTime) then
				if unit[stat] > 0 and unit[stat] < 100 then
					local threshold = unit[stat] - const.StatGaining.BonusToRoll
					local roll = InteractionRand(100, "StatGaining") + 1
					if roll >= threshold then
						GainStat(unit, stat)
						unit.statGainingPoints = unit.statGainingPoints - 1
						
						-- set when the cooldown expires
						local cd = InteractionRandRange(const.StatGaining.PerStatCDMin, const.StatGaining.PerStatCDMax, "StatCooldown")
						cooldowns[stat] = Game.CampaignTime + cd
						statGaining.Cooldowns = cooldowns
						
						success_text = "(success) "
					else
						reason_text = "Need: " .. threshold .. ", Rolled: " .. roll .. "/100"
					end
				else
					reason_text = stat .. " is " .. unit[stat]
				end
			else
				reason_text = stat .. " is in cooldown"
			end
		else
			reason_text = "Not enough milestone points"
		end
	else
		reason_text = "Fail chance proced"
	end
	CombatLog("debug", success_text .. _InternalTranslate(unit.Nick) .. " stat gain " .. stat .. ". " .. reason_text)
	
	SetMercStateFlag(unit.session_id, "StatGaining", statGaining)
end

g_MercStatGainVisualize = false

---
--- Updates the visualization for a mercenary's stat gain.
---
--- @param window table The window object that displays the stat gain visualization.
---
--- This function is responsible for updating the visual display of a mercenary's stat gain. It checks if there is a valid stat gain visualization for the mercenary, and if so, updates the display with the relevant information (stat name, amount gained, and duration of the visualization). If the visualization has expired, it hides the display. The function also creates a thread to handle the hiding of the visualization after the duration has elapsed.
---
function UpdateStatGainVisualization(window)
	local merc = window and window.context
	local visualizationForMerc = merc and g_MercStatGainVisualize and g_MercStatGainVisualize[merc]
	local timeStarted = visualizationForMerc and visualizationForMerc.timeStart
	
	local duration = 1000
	local timeLeft = 0
	if timeStarted then
		timeLeft = duration - (RealTime() - timeStarted)
	end
	
	if not visualizationForMerc or timeLeft <= 0 then
		if visualizationForMerc then g_MercStatGainVisualize[merc] = false end
		visualizationForMerc = false
		window:SetVisible(false)
		return
	end
	
	local stat = visualizationForMerc and visualizationForMerc.stat
	local amount = visualizationForMerc and visualizationForMerc.amount
	
	local meta = Presets.MercStat.Default
	local metaEntry = meta and meta[stat]
	if metaEntry then
		window.idStatIcon:SetImage(metaEntry.Icon)
	end
	window.idStatCount:SetText("+" .. amount)

	if timeLeft > 0 then
		window:DeleteThread("hide-stat-gain")
		window:CreateThread("hide-stat-gain", function()
			window:SetVisible(true)
			Sleep(timeLeft + 1)
			UpdateStatGainVisualization(window)
		end)
	end
end

function OnMsg.StatIncreased(unit, stat, amount)
	if not g_MercStatGainVisualize then g_MercStatGainVisualize = {} end
	local unitName = unit.session_id
	g_MercStatGainVisualize[unitName] = {
		timeStart = RealTime(),
		stat = stat,
		amount = amount,
	}
	ObjModified(unitName)
end

---
--- Formats the stat gaining information for a given unit.
---
--- @param unit Unit The unit to format the stat gaining information for.
--- @return table A table of strings representing the formatted stat gaining information.
function StatGainingInspectorFormat(unit)
	local statGaining = GetMercStateFlag(unit.session_id, "StatGaining") or {}
	local res = {}
	res[#res+1] = unit.Name
	
	ForEachPreset("StatGainingPrerequisite", function(preset)
		local presetDetails = "<color 20 122 122>" .. preset.id .. "</color>" .. " (" .. preset.relatedStat .. ")" .. ": " .. preset.Comment
		res[#res+1] = presetDetails
		if statGaining[preset.id] and statGaining[preset.id].state then
			local presetState = preset.id .. " - "
			
			local state = statGaining[preset.id].state
			if state and type(state) == "table" then
				for k, v in pairs(state) do
					presetState = presetState .. k .. ": " .. v .. ". "
				end
			end
			res[#res+1] = presetState
		end
	end)
	
	local percent, level = CalcXpPercentAndLevel(unit.Experience)
	res[#res+1] = "<color 8 86 86>Current Xp</color>: " .. unit.Experience .. "xp, " .. percent/10 .. "," .. percent%10 .. "% of Level " .. level .. ". "
	res[#res+1] = "<color 8 86 86>Stat Gaining points</color>: " .. unit.statGainingPoints
	
	if statGaining.Cooldowns then
		for k, v in pairs(statGaining.Cooldowns) do
			res[#res+1] = "<color 8 86 86>" .. k .. " CD</color>: " .. _InternalTranslate(TFormat.time({}, v)) .. " " .. _InternalTranslate(TFormat.date({}, v))
		end
	end

	return res
end

-- Tracked Stats
---
--- Gets the value of a tracked stat for the given unit.
---
--- @param unit Unit The unit to get the tracked stat for.
--- @param id string The ID of the tracked stat to get.
--- @return any The value of the tracked stat, or nil if it is not set.
function GetTrackedStat(unit, id)
	local statTracking = GetMercStateFlag(unit.session_id, "StatTracking") or {}
	return statTracking[id]
end

---
--- Sets the value of a tracked stat for the given unit.
---
--- @param unit Unit The unit to set the tracked stat for.
--- @param id string The ID of the tracked stat to set.
--- @param value any The value to set the tracked stat to.
function SetTrackedStat(unit, id, value)
	local statTracking = GetMercStateFlag(unit.session_id, "StatTracking") or {}
	statTracking[id] = value
	SetMercStateFlag(unit.session_id, "StatTracking", statTracking)
end

-- Employment History
---
--- Adds a new entry to the employment history log for the given unit.
---
--- @param unit Unit The unit to add the employment history log for.
--- @param presetId string The ID of the preset associated with the employment.
--- @param context string The context of the employment, such as the job or mission.
function AddEmploymentHistoryLog(unit, presetId, context)
	local employmentHistory = GetMercStateFlag(unit.session_id, "EmploymentHistory") or {}
	local log = { id = presetId, level = unit:GetLevel(), time = Game.CampaignTime, context = context }
	employmentHistory[#employmentHistory+1] = log
	SetMercStateFlag(unit.session_id, "EmploymentHistory", employmentHistory)
end

---
--- Gets the employment history log for the given unit.
---
--- @param unit Unit The unit to get the employment history log for.
--- @return table The employment history log for the unit, or an empty table if none exists.
function GetEmploymentHistory(unit)
	return GetMercStateFlag(unit.session_id, "EmploymentHistory") or {}
end

-- Modifications
GameVar("NewModifications", {})
function OnMsg.ModifierAdded(unit, prop, mod)
	if not IsMerc(unit) then return end
	local modedProps = NewModifications[unit.session_id] or {}
	local mods = modedProps[prop] or {}
	
	mods[#mods+1] = mod
	modedProps[prop] = mods
	
	NewModifications[unit.session_id] = modedProps
end

-- from, to: session_id
---
--- Replaces one mercenary unit with another, optionally keeping the original unit's inventory.
---
--- @param from string The session ID of the mercenary unit to be replaced.
--- @param to string The session ID of the mercenary unit to replace the original with.
--- @param keepInventory boolean If true, the original unit's inventory will be transferred to the new unit.
---
--- This function handles the full process of replacing one mercenary unit with another, including:
--- - Transferring the hire status, hired until date, and squad assignment from the original unit to the new unit.
--- - Transferring the original unit's experience, arrival direction, retreat sector, perk points, stat gaining points, and tiredness to the new unit.
--- - Optionally transferring the original unit's inventory to the new unit.
--- - Transferring any active status effects from the original unit to the new unit.
--- - Transferring any active modifications from the original unit to the new unit.
--- - Creating a new unit object for the new unit and replacing the original unit object.
--- - Updating the squad, original unit data, and new unit data objects.
---
function ReplaceMerc(from, to, keepInventory)
	local fromUnitData = gv_UnitData[from]
	local toUnitData = gv_UnitData[to]

	local hireStatus = fromUnitData.HireStatus
	if hireStatus ~= "Hired" then return end
	
	local hiredUntil = fromUnitData.HiredUntil
	local squad = gv_Squads[fromUnitData.Squad]
	
	fromUnitData.HireStatus = toUnitData.HireStatus
	fromUnitData.HiredUntil = false
	fromUnitData.Squad = false
	local squadIdx = table.remove_entry(squad.units, from)

	
	toUnitData.HireStatus = hireStatus
	toUnitData.HiredUntil = hiredUntil
	toUnitData.Squad = squad.UniqueId
	table.insert(squad.units, squadIdx, to)
	
	toUnitData.Experience = fromUnitData.Experience
	toUnitData.arrival_dir = fromUnitData.arrival_dir
	toUnitData.retreat_to_sector = fromUnitData.retreat_to_sector
	toUnitData.perkPoints = fromUnitData.perkPoints
	toUnitData.statGainingPoints = fromUnitData.statGainingPoints
	toUnitData.Tiredness = fromUnitData.Tiredness
	
	local trackerQuest = QuestGetState("MercStateTracker")
	trackerQuest[to] = trackerQuest[from]
	
	Msg("MercHireStatusChanged", fromUnitData, "Hired", false)
	Msg("MercHireStatusChanged", toUnitData, false, "Hired")
	
	if keepInventory then -- just swap their inventory slots
		for _, slotData in ipairs(fromUnitData.inventory_slots) do
			local slotName = slotData.slot_name
			local slot = fromUnitData[slotName]
			fromUnitData[slotName] = toUnitData[slotName]
			toUnitData[slotName] = slot
		end
	end
	
	-- status effects
	for _, effect in ipairs(fromUnitData.StatusEffects) do
		if not IsKindOf(effect, "Perk") or IsKindOf(effect, "Perk") and effect:IsLevelUp() then
			toUnitData:AddStatusEffect(effect.class)
		end
	end
	
	-- modifications
	if fromUnitData.modifications then
		local modList = fromUnitData.applied_modifiers
		fromUnitData:ApplyModifiersList(toUnitData.applied_modifiers)
		toUnitData:ApplyModifiersList(modList)
	end
	
	local unit = g_Units[from]
	if unit then
		local pos = unit:GetPos()
		local angle = unit:GetAngle()
		local side = unit.team and unit.team.side
		
		local newUnit = Unit:new{ 
			unitdatadef_id = to,
			session_id = to,
		}
		
		if SelectedObj == unit then
			SelectObj(newUnit)
		end
		
		DoneObject(unit)

		AddToGlobalUnits(newUnit)

		if angle then
			newUnit:SetAngle(angle)
		end
		if pos then
			newUnit:SetPos(pos)
		end
		if side then
			newUnit:SetSide(side)
		end
	end
	
	ObjModified(squad)
	ObjModified(fromUnitData)
	ObjModified(toUnitData)
end