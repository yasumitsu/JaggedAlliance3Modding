bobby_tier_print = CreatePrint{
	-- "BobbyRay Unlock & Tier",         -- comment out to disable these prints;
}
bobby_restock_print = CreatePrint{
	-- "BobbyRay Restock",         -- comment out to disable these prints;
}

bobby_mod_print = CreatePrint{
	-- "BobbyRay Modification",         -- comment out to disable these prints;
}

bobby_cost_print = CreatePrint{
	-- "BobbyRay Cost Mod",         -- comment out to disable these prints;
}

if FirstLoad then
	g_BobbyRayShopOpen = false -- to override g_RolloverShowMoreInfo (RolloverInventoryWeapon) when browsing shop with gamepad
end

---
--- Overrides the behavior of the rollover when browsing the Bobby Ray shop.
---
--- @return boolean
--- @see g_BobbyRayShopOpen
function BobbyRayRolloverOverride()
	return g_BobbyRayShopOpen
end

--------------------------------------------- Tiers

---
--- Returns the current unlocked tier for the Bobby Ray shop.
---
--- @return integer The current unlocked tier for the Bobby Ray shop.
function BobbyRayShopGetUnlockedTier()
	return GetQuestVar("BobbyRayQuest", "UnlockedTier")
end

---
--- Checks if the Bobby Ray shop is currently unlocked.
---
--- @return boolean true if the Bobby Ray shop is unlocked, false otherwise
function BobbyRayShopIsUnlocked()
	if not gv_Quests["BobbyRayQuest"] then return end
	return (GetQuestVar("BobbyRayQuest", "UnlockedTier") or 0) > 0
end

---
--- Checks if the Bobby Ray shop is currently in the process of opening.
---
--- @return boolean true if the Bobby Ray shop is in the process of opening, false otherwise
function BobbyRayShopIsOpening()
	return GetQuestVar("BobbyRayQuest", "TCE_PreparingToOpen") == "done" and not GetQuestVar("BobbyRayQuest", "TCE_StoreNowOpen") == "done"
end

---
--- Returns the time when the Bobby Ray shop will be restocked.
---
--- @return number The time when the Bobby Ray shop will be restocked.
function BobbyRayShopGetRestockTime()
	return GetQuestVar("BobbyRayQuest", "RestockTimer")
end

---
--- Sets the unlocked tier for the Bobby Ray shop.
---
--- @param tier integer The new tier to set for the Bobby Ray shop.
function NetSyncEvents.Cheat_BobbyRaySetTier(tier)
	if not gv_Quests["BobbyRayQuest"] then return end
	SetQuestVar(QuestGetState("BobbyRayQuest"), "UnlockedTier", tier)
	ObjModified("g_BobbyRayShop_UnlockedTier")
end

---
--- Toggles the lock state of the Bobby Ray shop.
---
--- If the Bobby Ray shop is currently unlocked, this function will lock the shop by setting the unlocked tier to 0 and resetting the restock timer.
--- If the Bobby Ray shop is currently locked, this function will unlock the shop by setting the unlocked tier to 1 and setting the restock timer to 1 hour from the current campaign time.
---
--- This function is a cheat function and should only be used for debugging or testing purposes.
---
--- @function NetSyncEvents.Cheat_BobbyRayToggleLock
--- @return nil
function NetSyncEvents.Cheat_BobbyRayToggleLock()
	if not gv_Quests["BobbyRayQuest"] then return end
	if BobbyRayShopGetUnlockedTier() > 0 then
		SetQuestVar(QuestGetState("BobbyRayQuest"), "UnlockedTier", 0)
		SetQuestVar(QuestGetState("BobbyRayQuest"), "RestockTimer", 0)
	else 
		SetQuestVar(QuestGetState("BobbyRayQuest"), "UnlockedTier", 1)
		SetQuestVar(QuestGetState("BobbyRayQuest"), "RestockTimer", Game.CampaignTime + 1 * const.Scale.h)
	end
	
	ObjModified("g_BobbyRayShop_UnlockedTier")
end

---
--- Formats the given time value into a human-readable string.
---
--- @param context table The context table, not used in this function.
--- @param time number The time value to format.
--- @return string A human-readable string representing the given time value.
function TFormat.GetShopTime(context, time)
	local daysLeft = DivCeil(time, const.Scale.day)
	if daysLeft > 2 then return daysLeft .. " " .. T(569233738707, "days") end
	
	local hoursLeft = DivCeil(time, const.Scale.h)
	if hoursLeft > 1 then 
		return T{292118944563, "<hours> hours", hours = hoursLeft}
	else 
		return T(882114309389, "1 hour")
	end
end

---------------------------------------------

-- data structure is store { used = { item_id -> item }, standard = { item_class -> item }, standard_ids = { item_id -> item_class } }
-- 	the item_id -> is to allow saving
-- 	for standard items, we want class index so that we can efficiently check which items are already present during restocking
-- used items could collide, but this reasonably unlikely

GameVar("g_BobbyRayStore", {
	used = {},
	standard = {},
	standard_ids = {},
})

GameVar("g_BobbyRayCart", {
	units = {}
})

-- whenever items are added to the cart, they get assigned an ordinal, such that g_BobbyRayCartOrdinalUnits[item.id] = ordinal
-- the ordinal resets to 0 whenever the units are cleared
-- order form's item list is sorted by ordinal
if FirstLoad then
	lBobbyRayCartNextOrdinal = 1
	lBobbyRayCartOrdinalUnits = {}
end
local function lClearOrdinals()
	lBobbyRayCartNextOrdinal = 1
	lBobbyRayCartOrdinalUnits = lBobbyRayCartOrdinalUnits or {}
	table.clear(lBobbyRayCartOrdinalUnits)
end

local function lGetNextOrdinal()
	lBobbyRayCartNextOrdinal = lBobbyRayCartNextOrdinal + 1
	return lBobbyRayCartNextOrdinal - 1
end

local function lRebuildOrdinals(units)
	lClearOrdinals()
	for item_id, item in sorted_pairs(units) do
		lBobbyRayCartOrdinalUnits[item_id] = lGetNextOrdinal()
	end
end

local function lHasItemOrdinal(item_id)
	return lBobbyRayCartOrdinalUnits[item_id] and true or false
end
local function lGetItemOrdinal(item_id)
	assert(lBobbyRayCartOrdinalUnits[item_id])
	return lBobbyRayCartOrdinalUnits[item_id]
end

local function lCheckShopIdInconsistency()
	for class, item in pairs(g_BobbyRayStore.standard) do
		if g_BobbyRayStore.standard_ids[item.id] ~= item.class then
			return true
		end
	end
	return false
end

local function lFixShopIds()
	table.clear(g_BobbyRayStore.standard_ids)
	for class, item in pairs(g_BobbyRayStore.standard) do
		g_BobbyRayStore.standard_ids[item.id] = item.class
	end
end

function OnMsg.LoadSessionData()
	if lCheckShopIdInconsistency() then
		BobbyRayCartClearEverything()
		lFixShopIds() 
	end
	lRebuildOrdinals(BobbyRayCartGetUnits())
end

---------------------------------------------------------- New logic

GameVar("g_BobbyRayItemsDirty", false) -- so that we don't need to update an item's "New" status on every satellite tick; GameVar to sync in multiplayer
---
--- Marks items in the Bobby Ray store as seen, either for a specific category and subcategory, or for all items.
---
--- @param category string|nil The category of items to mark as seen. If `nil`, all items will be marked as seen.
--- @param subcategory string|nil The subcategory of items to mark as seen. If `nil`, all items in the specified category will be marked as seen.
---
function NetSyncEvents.BobbyRayMarkItemsAsSeen(category, subcategory)
	category = BobbyRayShopGetCategory(category)
	if subcategory then subcategory = BobbyRayShopGetSubCategory(subcategory) end
	
	g_BobbyRayItemsDirty = true
	
	for item_id, item in pairs(g_BobbyRayStore.used) do
		if (subcategory and item:GetSubCategory() == subcategory) or (not subcategory and item:GetCategory() == category) then
			item.Seen = true
		end
	end
	for id, item in pairs(g_BobbyRayStore.standard) do
		if (subcategory and item:GetSubCategory() == subcategory) or (not subcategory and item:GetCategory() == category) then 
			item.Seen = true
		end
	end
end

---
--- Updates the "New" status of items in the Bobby Ray store.
---
--- This function is called when the `g_BobbyRayItemsDirty` flag is set to true, indicating that the "New" status of items needs to be updated.
---
--- It iterates through the `g_BobbyRayStore.used` and `g_BobbyRayStore.standard` tables, and sets the `New` property of each item to `false` if the `Seen` property is `true`.
---
--- This ensures that items are no longer marked as "New" once the player has seen them in the Bobby Ray store.
---
function NetSyncEvents.BobbyRayUpdateNew()
	if not g_BobbyRayItemsDirty then return end
	g_BobbyRayItemsDirty = false
	for item_id, item in pairs(g_BobbyRayStore.used) do
		if item.Seen then item.New = false end
	end
	
	for item_class, item in pairs(g_BobbyRayStore.standard) do
		if item.Seen then item.New = false end
	end
end

---------------------------------------------------------- Shop Contents

---
--- Retrieves a Bobby Ray store item by its ID.
---
--- @param id string The ID of the item to retrieve.
--- @return table|nil The item object, or `nil` if the item is not found.
---
function lGetShopItemFromId(id)
	if g_BobbyRayStore.used[id] then 
		return g_BobbyRayStore.used[id] 
	end
	return g_BobbyRayStore.standard[g_BobbyRayStore.standard_ids[id]]
end

---
--- Retrieves a Bobby Ray store entry based on the given entry.
---
--- If the entry is marked as "used", the used entry is returned. Otherwise, the standard entry is returned.
---
--- @param entry table The entry to retrieve.
--- @return table|nil The retrieved entry, or `nil` if the entry is not found.
---
function BobbyRayStoreGetEntry(entry)
	return entry.Used and entry or g_BobbyRayStore.standard[entry.class] 
end

---
--- Retrieves the cost of a Bobby Ray store entry.
---
--- @param entry table The entry to retrieve the cost for.
--- @return number The cost of the entry.
---
function BobbyRayStoreGetEntryCost(entry)
	local br_entry = BobbyRayStoreGetEntry(entry)
	local cost = br_entry and br_entry.Cost or 0
	if IsGameRuleActive("BobbyPays") then
		local percent = GameRuleDefs.BobbyPays:ResolveValue("PricePercentMultiplier") or 0
		cost = MulDivRound(cost, percent, 100)
	end	
	return cost
end

---
--- Calculates the delivery price for the current Bobby Ray cart.
---
--- If no delivery option is provided, the "Standard" option is used.
--- The delivery price is retrieved from the "BobbyRayShopDeliveryDef" preset, and is adjusted based on the "BobbyPays" game rule.
---
--- @param delivery_option string|nil The delivery option to use. If not provided, "Standard" is used.
--- @return number The calculated delivery price.
---
function BobbyRayStoreDeliveryPrice(delivery_option)
	if not delivery_option then
		g_BobbyRayCart.delivery_option = g_BobbyRayCart.delivery_option or "Standard"
		delivery_option = g_BobbyRayCart.delivery_option
	end
	local price = FindPreset("BobbyRayShopDeliveryDef", delivery_option).Price
	if IsGameRuleActive("BobbyPays") then
		local percent = GameRuleDefs.BobbyPays:ResolveValue("PricePercentMultiplier") or 0
		price = MulDivRound(price,percent, 100)
	end	
	return price
end

---
--- Clears the Bobby Ray store data, including the used and standard entries, and the standard IDs.
--- Also clears the Bobby Ray cart, as any references to the store entries will become invalid.
---
function BobbyRayStoreClear()
	table.clear(g_BobbyRayStore)
	g_BobbyRayStore.used = {}
	g_BobbyRayStore.standard = {}
	g_BobbyRayStore.standard_ids = {}
	
	BobbyRayCartClearEverything() -- clear cart too because any reference will become invalid
end

---
--- Retrieves an array of Bobby Ray store entries based on the specified category and subcategory.
---
--- @param categoryId number The ID of the category to retrieve entries for.
--- @param subcategoryId number|nil The ID of the subcategory to retrieve entries for. If not provided, all entries in the category will be returned.
--- @param context table|nil Additional context information to use when retrieving the entries.
--- @return table An array of Bobby Ray store entries.
---
function BobbyRayStoreToArray(categoryId, subcategoryId, context)
	local category = BobbyRayShopGetCategory(categoryId)
	local subcategory = BobbyRayShopGetSubCategory(subcategoryId)
	local array = {}
	local min_entries = 7
	for item_id, item in pairs(g_BobbyRayStore.used) do
		if (subcategory and subcategory:BelongsInSubCategory(item)) or (not subcategory and category:BelongsInCategory(item)) then
			table.insert(array, item)
		end
	end
	for id, item in pairs(g_BobbyRayStore.standard) do
		if (subcategory and item:GetSubCategory() == subcategory) or (not subcategory and item:GetCategory() == category) then 
			table.insert(array, item)
		end
	end
	
	table.sort(array, function(a,b)
		local aEntry = BobbyRayStoreGetEntry(a)
		local bEntry = BobbyRayStoreGetEntry(b)
		
		-- 0-th first, sort by presence in cart
		local units = g_BobbyRayCart.units
		local aInCart = units[a.id] and units[a.id] ~= 0
		local bInCart = units[b.id] and units[b.id] ~= 0
		if aInCart and not bInCart then return true
		elseif bInCart and not aInCart then return false end
		
		-- first, sort by subcategory
		local aEntrySubCat = aEntry:GetSubCategory()
		local bEntrySubCat = bEntry:GetSubCategory()
		if aEntrySubCat.SortKey < bEntrySubCat.SortKey then return true end
		if aEntrySubCat.SortKey > bEntrySubCat.SortKey then return false end
		
		-- second sort by item class?
		if aEntry.class < bEntry.class then return true end
		if aEntry.class > bEntry.class then return false end
		
		-- third sort by Condition
		if aEntry.Condition < bEntry.Condition then return false end
		if aEntry.Condition > bEntry.Condition then return true end
		
		-- finally sort by id which should be unique
		return aEntry.id < bEntry.id
	end)
	
	for i = table.count(array), min_entries - 1 do
		table.insert(array, empty_table)
	end
	
	NetSyncEvent("BobbyRayMarkItemsAsSeen", category.id, subcategory and subcategory.id)
	
	return array
end

---
--- Converts the units in the Bobby Ray cart to a sorted list of orders.
---
--- @return table Orders - A table of orders, where each order is a table representing a shop item.
---
function BobbyRayCartUnitsToOrders()
	local orders = {}
	local min_entries = 12
	for item_id, count in pairs(BobbyRayCartGetUnits()) do
		local entry = lGetShopItemFromId(item_id)
		table.insert(orders, entry)
	end
	table.sort(orders, function(a,b) return lGetItemOrdinal(a.id) < lGetItemOrdinal(b.id) end)
	for i=table.count(orders), min_entries - 1 do
		table.insert(orders, empty_table)
	end
	return orders
end

---
--- Calculates the total cost and item count in the Bobby Ray cart.
---
--- @return number count - The total number of items in the cart.
--- @return number acc - The total cost of the items in the cart, including the delivery cost.
---
function BobbyRayCartGetAggregate()
	local acc = MulDivRound(BobbyRayStoreDeliveryPrice(), gv_Sectors[BobbyRayCartGetDeliverySector()].BobbyRayDeliveryCostMultiplier, 100)
	local count = 0
	for item_id, number in pairs(BobbyRayCartGetUnits()) do
		local entry = lGetShopItemFromId(item_id)	
		local br_entry_cost = BobbyRayStoreGetEntryCost(entry)
		acc = acc + br_entry_cost * number
		count = count + number
	end
	return count, acc
end

---
--- Checks if the player has enough money to add the given entry to the Bobby Ray cart.
---
--- @param entry table The shop item entry to check.
--- @return boolean True if the player has enough money, false otherwise.
---
function BobbyRayCartHasEnoughMoney(entry)
	local cart_count, cart_cost = BobbyRayCartGetAggregate()
	local entry_cost = BobbyRayStoreGetEntryCost(entry)
	return Game.Money - cart_cost - entry_cost >= 0
end

---
--- Checks if the player has enough stock in the Bobby Ray cart to add the given entry.
---
--- @param entry table The shop item entry to check.
--- @return boolean True if the player has enough stock, false otherwise.
---
function BobbyRayCartHasEnoughStock(entry)
	local max_stock = BobbyRayStoreGetEntry(entry).Stock
	local cur_stock = BobbyRayCartGetUnits()[entry.id] or 0
	return cur_stock < max_stock 
end

---
--- Checks if the given item can be added to the Bobby Ray cart.
---
--- @param item_id number The ID of the item to check.
--- @return boolean True if the item can be added to the cart, false otherwise.
---
function CanAddToCart(item_id)
	local item = lGetShopItemFromId(item_id)
	return BobbyRayCartHasEnoughMoney(item) and BobbyRayCartHasEnoughStock(item)
end

--- Checks if the given item can be removed from the Bobby Ray cart.
---
--- @param item_id number The ID of the item to check.
--- @return boolean True if the item can be removed from the cart, false otherwise.
---
function CanRemoveFromCart(item_id)
	return g_BobbyRayCart.units[item_id] and g_BobbyRayCart.units[item_id] > 0
end

---
--- Clears the Bobby Ray cart, including the delivery option and sector delivery information.
---
function BobbyRayCartClearEverything()
	g_BobbyRayCart.delivery_option = nil
	BobbyRayCartClearSectorDelivery()
	BobbyRayCartClearUnits()
end

---------------------------------------------------------- Cart Operations

local function lForgetBobbyRayOrderTabState()
	if PDABrowserTabState["bobby_ray_shop"] and PDABrowserTabState["bobby_ray_shop"].mode_param == "cart" and table.count(g_BobbyRayCart.units) == 0 then
		PDABrowserTabState["bobby_ray_shop"].mode_param = "front"
	end
end

local function lBobbyRayCartAdd(item_id)
	g_BobbyRayCart.units[item_id] = g_BobbyRayCart.units[item_id] and g_BobbyRayCart.units[item_id] + 1 or 1
	if not lHasItemOrdinal(item_id) then lBobbyRayCartOrdinalUnits[item_id] = lGetNextOrdinal() end
end

local function lBobbyRayCartRemove(item_id)
	g_BobbyRayCart.units[item_id] = g_BobbyRayCart.units[item_id] and Max(0, g_BobbyRayCart.units[item_id] - 1) or 0
end

---
--- Returns the units in the Bobby Ray cart.
---
--- @return table The units in the Bobby Ray cart.
---
function BobbyRayCartGetUnits()
	g_BobbyRayCart.units = g_BobbyRayCart.units or {}
	return g_BobbyRayCart.units
end

---
--- Clears the units in the Bobby Ray cart and the ordinal units.
---
function BobbyRayCartClearUnits()
	table.clear(g_BobbyRayCart.units)
	lClearOrdinals()
end

---
--- Adds an item to the Bobby Ray cart.
---
--- @param item_id string The ID of the item to add to the cart.
---
function NetSyncEvents.BobbyRayCartAdd(item_id)
	if not CanAddToCart(item_id) then return end
	lBobbyRayCartAdd(item_id)
	ObjModified(g_BobbyRayCart)
end

---
--- Removes an item from the Bobby Ray cart.
---
--- @param item_id string The ID of the item to remove from the cart.
---
function NetSyncEvents.BobbyRayCartRemove(item_id)
	lBobbyRayCartRemove(item_id)
	ObjModified(g_BobbyRayCart)
end

--------------------------------------------- Order Form clear empty
-- whenever neither player has the Order page open, the game will clear the cart entries with amount 0
-- if this results in the cart ending up empty, it resets the tab state so that the shop opens at the frontpage instead of the order form (same on satellite ticks, which clear the cart)

if FirstLoad then
	BobbyRayOrderFormOpenedBySelf = false
	BobbyRayOrderFormOpenedByOther = false
end

---
--- Checks and clears any empty entries in the Bobby Ray cart.
---
--- If neither the player nor the other player has the Order page open, the function will
--- remove any cart entries with an amount of 0. If this results in the cart being empty,
--- it will reset the tab state so that the shop opens at the front page instead of the
--- order form (same behavior as on satellite ticks, which also clear the cart).
---
function BobbyRayCheckClearEmptyCartEntries()
	if not g_BobbyRayCart then return end
	if not BobbyRayOrderFormOpenedByOther and not BobbyRayOrderFormOpenedBySelf then
		for item, amount in pairs(g_BobbyRayCart.units) do
			if amount == 0 then
				g_BobbyRayCart.units[item] = nil
				lBobbyRayCartOrdinalUnits[item] = nil
			end
		end
		lForgetBobbyRayOrderTabState()
	end
end

---
--- Gets the ID of the player who has the Bobby Ray order form open.
---
--- @return string The ID of the player who has the order form open, or "self" if no player has it open.
function GetBobbyRayOrderFormOpenId()
	return netInGame and netUniqueId or "self"
end

---
--- Sets whether the Bobby Ray order form is opened by the local player or another player.
---
--- @param player_id string The ID of the player who opened the order form.
--- @param open boolean Whether the order form is opened or closed.
---
function NetSyncEvents.SetBobbyRayOrderFormOpened(player_id, open)
	if player_id == GetBobbyRayOrderFormOpenId() then
		BobbyRayOrderFormOpenedBySelf = open
	else
		BobbyRayOrderFormOpenedByOther = open
	end
	BobbyRayCheckClearEmptyCartEntries()
end

function OnMsg.NetGameLeft()
	BobbyRayOrderFormOpenedByOther = false
	BobbyRayCheckClearEmptyCartEntries()
end

function OnMsg.NetPlayerLeft(player_id)
	BobbyRayOrderFormOpenedByOther = false
	BobbyRayCheckClearEmptyCartEntries()
end

function OnMsg.ChangeMap()
	BobbyRayOrderFormOpenedBySelf = false
	BobbyRayOrderFormOpenedByOther = false
end

---------------------------------------------------------- Delivery Option

---
--- Returns the default delivery option for the Bobby Ray shop.
---
--- @return table The default delivery option preset.
function BobbyRayCartGetDefaultDeliveryOption()
	return Presets.BobbyRayShopDeliveryDef.Default.Standard
end

---
--- Returns the current delivery option for the Bobby Ray shop cart.
---
--- @return table The delivery option preset for the Bobby Ray shop cart.
function BobbyRayCartGetDeliveryOption()
	g_BobbyRayCart.delivery_option = g_BobbyRayCart.delivery_option or "Standard"
	return FindPreset("BobbyRayShopDeliveryDef", g_BobbyRayCart.delivery_option)
end

local function lBobbyRaySetDeliveryOption(option_id)
	g_BobbyRayCart.delivery_option = option_id
end

---
--- Synchronizes the delivery option for the Bobby Ray shop cart across the network.
---
--- @param option_id string The ID of the delivery option to set.
---
function NetSyncEvents.BobbyRaySetDeliveryOption(option_id)
	lBobbyRaySetDeliveryOption(option_id)
	ObjModified(g_BobbyRayCart)
end

---------------------------------------------------------- Sector Delivery

---
--- Returns a list of available delivery sectors for the Bobby Ray shop.
---
--- The list includes the initial sector and all other player-owned sectors that are not port-locked and have been owned for at least one campaign.
---
--- @return table A list of sector IDs that can be used for delivery.
function BobbyRayGetAvailableDeliverySectors()
	local initial_sector = GetCurrentCampaignPreset().InitialSector
	local sectors = { initial_sector }
	for id, sector in pairs(gv_Sectors) do
		if sector.Side == "player1" and sector.CanBeUsedForArrival and not sector.PortLocked and sector.last_own_campaign_time ~= 0 and id ~= initial_sector then
			table.insert(sectors, id)
		end
	end
	if #sectors == 0 then
		table.insert(sectors, initial_sector)
	end
	return sectors
end

---
--- Sets the delivery sector for the Bobby Ray shop cart.
---
--- @param sectorId string The ID of the sector to set as the delivery destination.
---
function BobbyRayCartSetSectorDelivery(sectorId)
	g_BobbyRayCart.delivery_destination = sectorId
end

---
--- Synchronizes the delivery sector for the Bobby Ray shop cart across the network.
---
--- @param sectorId string The ID of the sector to set as the delivery destination.
---
function NetSyncEvents.BobbyRayCartSetSectorDelivery(sectorId)
	BobbyRayCartSetSectorDelivery(sectorId)
	ObjModified(g_BobbyRayCart)
	ObjModified("DeliverySectorChanged")
end

---
--- Returns the default delivery sector for the Bobby Ray shop.
---
--- The default delivery sector is the first sector in the list of available delivery sectors.
---
--- @return string The ID of the default delivery sector.
function BobbyRayGetDefaultDeliverySector()
	return BobbyRayGetAvailableDeliverySectors()[1]
end

---
--- Returns the delivery sector for the Bobby Ray shop cart.
---
--- If a delivery sector has been set for the cart, this function returns that sector.
--- Otherwise, it returns the default delivery sector as determined by `BobbyRayGetDefaultDeliverySector()`.
---
--- @return string The ID of the delivery sector for the Bobby Ray shop cart.
function BobbyRayCartGetDeliverySector()
	return g_BobbyRayCart.delivery_destination or BobbyRayGetDefaultDeliverySector()
end

---
--- Clears the delivery sector for the Bobby Ray shop cart.
---
--- This function sets the `delivery_destination` field of the `g_BobbyRayCart` table to `nil`, effectively clearing the delivery sector for the Bobby Ray shop cart.
---
function BobbyRayCartClearSectorDelivery()
	g_BobbyRayCart.delivery_destination = nil
end

-------------------------------------------------------

---
--- Returns a table of statistics for a firearm item in the Bobby Ray store.
---
--- The returned table contains the following fields:
---   - DMG: The damage value of the firearm.
---   - RANGE: The weapon range of the firearm.
---   - CRIT: The maximum critical chance percentage of the firearm.
---   - PEN: The penetration class of the firearm.
---
--- @param item table The firearm item to get the statistics for.
--- @return table A table of firearm statistics.
function BobbyRayStoreGetStats_Firearm(item)
	return {
		{ T(467324314141, "DMG"), Untranslated(item.Damage) },
		{ T(788999452116, "RANGE"), Untranslated(item.WeaponRange) },
		{ T(921500948697, "CRIT"), T{580888120593, "<percent(number)>", number = Presets.WeaponPropertyDef.Default.MaxCritChance:GetProp(item)} },
		{ T(842354777573, "PEN"), GetPenetrationClassUIText(item.PenetrationClass) },
	}
end

---
--- Returns a table of statistics for a melee weapon item in the Bobby Ray store.
---
--- The returned table contains the following fields:
---   - DMG: The damage value of the melee weapon.
---   - RANGE: The weapon range of the melee weapon.
---   - CRIT: The maximum critical chance percentage of the melee weapon.
---   - PEN: The penetration class of the melee weapon.
---
--- @param item table The melee weapon item to get the statistics for.
--- @return table A table of melee weapon statistics.
function BobbyRayStoreGetStats_MeleeWeapon(item)
	return {
		{ T(467324314141, "DMG"), Untranslated(item.Damage and item.Damage or item.BaseDamage) },
		{ T(788999452116, "RANGE"), Untranslated(item.WeaponRange) },
		{ T(921500948697, "CRIT"), T{580888120593, "<percent(number)>", number = Presets.WeaponPropertyDef.Default.MaxCritChance:GetProp(item)} },
		{ T(842354777573, "PEN"), GetPenetrationClassUIText(item.PenetrationClass) },
	}
end

---
--- Returns a table of statistics for an armor item in the Bobby Ray store.
---
--- The returned table contains the following fields:
---   - DR: The damage reduction percentage of the armor.
---   - SLOT: The body part slot that the armor occupies.
---   - PEN: The penetration class of the armor.
---
--- @param item table The armor item to get the statistics for.
--- @return table A table of armor statistics.
function BobbyRayStoreGetStats_Armor(item)
	return {
		{ T(113963825061, "DR"), T{580888120593, "<percent(number)>", number = item.DamageReduction + item.AdditionalReduction } },
		{ T(260685017729, "SLOT"), Presets.TargetBodyPart.Default[item.Slot].display_name },
		{ T(842354777573, "PEN"), GetPenetrationClassUIText(item.PenetrationClass) },
	}
end

---
--- Returns a table of statistics for an ammo item in the Bobby Ray store.
---
--- The returned table contains the following fields:
---   - Cal: The caliber of the ammo.
---   - Pen: The penetration class of the ammo (if applicable).
---
--- @param item table The ammo item to get the statistics for.
--- @return table A table of ammo statistics.
function BobbyRayStoreGetStats_Ammo(item)
	return {
		{ T(196962828215, "Cal"), FindPreset("Caliber", item.Caliber).Name },
		item.PenetrationClass and { T(314470590373, "Pen"), GetPenetrationClassUIText(item.PenetrationClass) } or nil
	}
end

---
--- Returns a table of statistics for an "other" item in the Bobby Ray store.
---
--- This function is a placeholder and currently returns `nil`.
---
--- @param item table The "other" item to get the statistics for.
--- @return table|nil A table of "other" item statistics, or `nil` if no statistics are available.
function BobbyRayStoreGetStats_Other(item)
	return nil
end

---
--- Randomly selects a number of items from an array of items, with a maximum total weight.
---
--- @param num integer The number of items to select.
--- @param items_array table An array of items to select from.
--- @param max_weight number The maximum total weight of the selected items.
--- @return table A table of the selected item classes.
function PickRandomWeightItems(num, items_array, max_weight)
	local picked_items = {}
	local picked_items_set = {}
	for i=1, num do
		local rand_weight = InteractionRand(max_weight, "BobbyRayShop")
		local cur_weight = 0
		local cur_index = 1
		while true do
			local item = items_array[cur_index]
			while picked_items_set[item] do
				cur_index = cur_index + 1
				item = items_array[cur_index]
			end
			cur_weight = cur_weight + item.RestockWeight
			cur_index = cur_index + 1
			if cur_weight > rand_weight then
				table.insert(picked_items, item.class)
				picked_items_set[item] = true
				max_weight = max_weight - item.RestockWeight
				break
			end
		end
	end
	return picked_items
end

---
--- Prepares the items in the Bobby Ray store for restocking.
---
--- This function aggregates the category weights and counts for items that can appear in the shop, based on whether the items are used or standard, and the player's unlocked tier.
---
--- @param unlocked_tier integer The player's unlocked tier.
--- @param used boolean Whether to consider used items or standard items.
--- @return table, table, table, table The category items, category counts, category weights, and category items set.
function PrepareShopItemsForRestock(unlocked_tier, used)
	local category_weights = {}
	local category_count = {}
	local category_items = {} -- array
	local category_items_set = {}
	NetUpdateHash("PrepareShopItemsForRestock1", unlocked_tier, used)
	-- aggregate category weights and count
	-- !TODO: do we want to skip items that are already at max stock?
	ForEachPreset("InventoryItemCompositeDef", function(preset)
		local item = g_Classes[preset.id]
		local usedOrStandard = false
		if used then 
			usedOrStandard = item.CanAppearUsed
		else 
			usedOrStandard = item.CanAppearStandard
		end
		if item.CanAppearInShop and usedOrStandard and item.Tier <= unlocked_tier and item.RestockWeight > 0 then
			local cat = item:GetCategory().id
			if not category_weights[cat] then
				category_weights[cat] = 0
				category_count[cat] = 0
				category_items[cat] = {}
				category_items_set[cat] = {}
			end
			table.insert(category_items[cat], item)
			category_items_set[cat][item] = true
			category_weights[cat] = category_weights[cat] + item.RestockWeight
			category_count[cat] = category_count[cat] + 1
			NetUpdateHash("PrepareShopItemsForRestock2", cat, item.class, item.RestockWeight, category_count[cat], category_weights[cat])
		end
	end)
	return category_items, category_count, category_weights, category_items_set
end

---
--- Randomly modifies a weapon by applying components to its available slots.
---
--- This function takes a weapon object, shuffles its available component slots, and then randomly applies components to those slots based on a configurable chance. Components that block other slots are also tracked and skipped. The final cost modifier for the weapon is returned.
---
--- @param weapon table The weapon object to modify.
--- @return number The cost modifier for the applied weapon components.
function RandomlyModifyWeapon(weapon)
	local weapon_component_chance = const.BobbyRay.Restock_UsedWeaponComponentPercentage
	local weapon_component_price_modifier = const.BobbyRay.Restock_UsedWeaponComponentPriceMod
	-- we shuffle first because blocked components could get a lower chance of being picked
	local shuffledComponents = {}
	for i, slotDef in ipairs(weapon.ComponentSlots) do
		table.insert(shuffledComponents, slotDef)
	end
	table.shuffle(shuffledComponents, InteractionRand(nil, "BobbyRayShop"))
	
	local blocked_slots = {}
	local applied_mods = {}
	for i, slotDef in ipairs(shuffledComponents) do
		if InteractionRand(100, "BobbyRayShop") <= weapon_component_chance and not blocked_slots[slotDef.SlotType] then
			local comp_num = #slotDef.AvailableComponents
			if slotDef.DefaultComponent and slotDef.DefaultComponent ~= "" then comp_num = comp_num - 1 end -- hack to skip the default component; on clash, we pick the last component, not included in the random gen
			assert(comp_num >= 0)
			if comp_num == 0 then goto continue end
			local index = InteractionRand(comp_num) + 1
			local comp_id = slotDef.AvailableComponents[index]
			local component = WeaponComponents[comp_id]
			if comp_id == slotDef.DefaultComponent then component = slotDef.AvailableComponents[comp_num] end
			applied_mods[slotDef.SlotType] = comp_id
			if component.BlockSlots and next(component.BlockSlots) ~= nil then
				for _, blockSlotType in ipairs(component.BlockSlots) do
					blocked_slots[blockSlotType] = true
				end
			end
			bobby_mod_print("Applied", comp_id,"to", slotDef.SlotType)
		elseif blocked_slots[slotDef.SlotType] then
			bobby_mod_print("Skipped due to blocked slot:", slotDef.SlotType)
		else
			bobby_mod_print("Skipped due to low chance:", slotDef.SlotType)
		end
		::continue::
	end
	
	local cost_modifier = 0
	for slot, component in pairs(applied_mods) do
		cost_modifier = cost_modifier + weapon_component_price_modifier
		weapon:SetWeaponComponent(slot, component)
	end
	
	return cost_modifier
end

--- Restocks a standard item in the Bobby Ray store.
---
--- @param item_class string The class of the item to restock.
function RestockStandardItem(item_class)
	local item = g_BobbyRayStore.standard[item_class]
	if not item then
		item = PlaceInventoryItem(item_class)
		item.Stock = 0
		g_BobbyRayStore.standard[item_class] = item
		g_BobbyRayStore.standard_ids[item.id] = item_class
	end
	
	item.LastRestock = Game.CampaignTime
	local rand_stock = InteractionRand(item.MaxStock + 1, "BobbyRayShop")
	item.Stock = Max(1, item.Stock, rand_stock)
	item.New = true
end

--- Restocks a used armor item in the Bobby Ray store.
---
--- @param armor_id string The ID of the armor item to restock.
function RestockUsedArmor(armor_id)
	local used_price_min = const.BobbyRay.Restock_UsedPriceModMin
	local used_price_max = const.BobbyRay.Restock_UsedPriceModMax
	local used_condition_min = const.BobbyRay.Restock_UsedConditionMin
	local used_condition_max = const.BobbyRay.Restock_UsedConditionMax
	
	local item = PlaceInventoryItem(armor_id)
	item.Used = true
	item.Condition = used_condition_min + InteractionRand(used_condition_max - used_condition_min, "BobbyRayShop")
	local usedCostMod = used_price_min + InteractionRand(used_price_max - used_price_min, "BobbyRayShop")
	item.Stock = 1
	item.LastRestock = Game.CampaignTime
	g_BobbyRayStore.used[item.id] = item
	local baseCost = item.Cost
	item.Cost = MulDivRound(item.Cost, usedCostMod, 100)
	bobby_cost_print(item.class, "\n\tbase price:", baseCost, "$", "\n\tcondition price mod:", usedCostMod, "%", "\n\tfinal price:", item.Cost, "$")
	item.New = true
end

---
--- Restocks a used weapon item in the Bobby Ray store.
---
--- @param weapon_id string The ID of the weapon item to restock.
function RestockUsedWeapon(weapon_id)
	local used_price_min = const.BobbyRay.Restock_UsedPriceModMin
	local used_price_max = const.BobbyRay.Restock_UsedPriceModMax
	local used_condition_min = const.BobbyRay.Restock_UsedConditionMin
	local used_condition_max = const.BobbyRay.Restock_UsedConditionMax
	
	local item = PlaceInventoryItem(weapon_id)
	item.Used = true
	item.Condition = used_condition_min + InteractionRand(used_condition_max - used_condition_min, "BobbyRayShop")
	local usedCostMod = used_price_min + InteractionRand(used_price_max - used_price_min, "BobbyRayShop")
	item.Stock = 1
	item.LastRestock = Game.CampaignTime
	local compCostMod = RandomlyModifyWeapon(item)
	g_BobbyRayStore.used[item.id] = item
	local baseCost = item.Cost
	item.Cost = MulDivRound(item.Cost, usedCostMod + compCostMod, 100)
	bobby_cost_print(item.class, "\n\tbase price:", baseCost, "%", "\n\tcondition price mod:", usedCostMod, "%", "\n\tmodification price mod:", compCostMod, "%", "\n\tfinal price:", item.Cost, "$")
	item.New = true
end

---
--- Restocks the Bobby Ray store with used and standard items.
---
--- @param restock_modifier_standard number The modifier for restocking standard items.
--- @param restock_modifier_used number The modifier for restocking used items.
function BobbyRayStoreRestock(restock_modifier_standard, restock_modifier_used)
	if not BobbyRayShopIsUnlocked() then return end
	
	local restock_min_percent_used = MulDivRound(const.BobbyRay.Restock_UsedPercentageMin, restock_modifier_used or 100, 100)
	local restock_max_percent_used = MulDivRound(const.BobbyRay.Restock_UsedPercentageMax, restock_modifier_used or 100, 100)
	local restock_min_percent_standard = MulDivRound(const.BobbyRay.Restock_StandardPercentageMin, restock_modifier_standard or 100, 100)
	local restock_max_percent_standard = MulDivRound(const.BobbyRay.Restock_StandardPercentageMax, restock_modifier_standard or 100, 100)

	local category_items, category_count, category_weights, category_items_set = PrepareShopItemsForRestock(BobbyRayShopGetUnlockedTier(), "used")
	-- restock random armor
	--[[]]
	local total_items = category_count["Armor"]
	local restock_items = Max(1, MulDivRound(total_items, restock_min_percent_used + InteractionRand(restock_max_percent_used - restock_min_percent_used + 1, "BobbyRayShop"), 100))
	restock_items = Min(restock_items, #category_items["Armor"])
	local picked_items = PickRandomWeightItems(restock_items, category_items["Armor"], category_weights["Armor"])
	if total_items > 0 then  bobby_restock_print("Restocking", restock_items, "out of", total_items, "used", "Armors", "or ", MulDivRound(restock_items, 100, total_items)) end
	for _, item in ipairs(picked_items) do
		RestockUsedArmor(item)
	end
	--]]
	
	--[[]]
	local total_items = category_count["Weapons"]
	local restock_items = Max(1, MulDivRound(total_items, restock_min_percent_used + InteractionRand(restock_max_percent_used - restock_min_percent_used + 1, "BobbyRayShop"), 100))
	restock_items = Min(restock_items, #category_items["Weapons"])
	local picked_items = PickRandomWeightItems(restock_items, category_items["Weapons"], category_weights["Weapons"])
	if total_items > 0 then  bobby_restock_print("Restocking", restock_items, "out of", total_items, "used", "Weapons", "or ", MulDivRound(restock_items, 100, total_items)) end
	for _, item in ipairs(picked_items) do
		RestockUsedWeapon(item)
	end
	--]]
	
	-- restock standard items
	local category_items, category_count, category_weights, category_items_set = PrepareShopItemsForRestock(BobbyRayShopGetUnlockedTier())
	for cat, _ in sorted_pairs(category_weights) do
		local total_items = category_count[cat]
		local restock_items = Max(1, MulDivRound(total_items, restock_min_percent_standard + InteractionRand(restock_max_percent_standard - restock_min_percent_standard + 1, "BobbyRayShop"), 100))
		restock_items = Min(restock_items, #category_items[cat])
		if total_items > 0 then bobby_restock_print("Restocking", restock_items, "out of", total_items, cat, "or ", MulDivRound(restock_items, 100, total_items)) end
		local picked_items = PickRandomWeightItems(restock_items, category_items[cat], category_weights[cat])
		for _, item in ipairs(picked_items) do
			RestockStandardItem(item)
		end
	end
	CombatLog("important", T(938586124784, "Inventory restock at Bobby Ray's Guns 'n Things."))
end

---
--- Consumes a random portion of the stock for standard and used items in the Bobby Ray's store.
---
--- @param pick_probability number The probability (0-100) that an item will be consumed.
--- @param stock_min_percent number The minimum percentage of an item's stock that will be consumed.
--- @param stock_max_percent number The maximum percentage of an item's stock that will be consumed.
function BobbyRayStoreConsumeRandomStock(pick_probability, stock_min_percent, stock_max_percent)
	pick_probability = pick_probability or const.BobbyRay.FakePurchase_PickProbability
	stock_min_percent = stock_min_percent or const.BobbyRay.FakePurchase_StockConsumedMin
	stock_max_percent = stock_max_percent or const.BobbyRay.FakePurchase_StockConsumedMax
	-- standard items
	local consumed_items = 0
	local total_items = 0
	for _, item in sorted_pairs(g_BobbyRayStore.standard) do
		total_items = total_items + 1
		if item.CanBeConsumed and InteractionRand(100, "BobbyRayShop") < pick_probability then
			consumed_items = consumed_items + 1
			local current_stock = item.Stock
			local stock_purchased = Max(1, MulDivRound(current_stock, stock_min_percent, 100) + MulDivRound(current_stock, InteractionRand(stock_max_percent - stock_min_percent + 1, "BobbyRayShop"), 100))
			assert(current_stock >= stock_purchased)
			local new_stock = current_stock - stock_purchased
			item.Stock = new_stock
			bobby_restock_print("Consumed", stock_purchased, "out of", current_stock, "of", item.class, "(Standard)", "or", MulDivRound(stock_purchased, 100, current_stock))
			-- remove if stock is depleted
			if new_stock <= 0 then 
				g_BobbyRayStore.standard[item.class] = nil
				g_BobbyRayStore.standard_ids[item.id] = nil
			end
		end
	end
	if total_items > 0 then bobby_restock_print(" --------------------------- Consumed", consumed_items, "out of", total_items, "standard items", "or", MulDivRound(consumed_items, 100, total_items)) end
	
	-- used items
	consumed_items = 0
	total_items = 0
	for item_id, item in sorted_pairs(g_BobbyRayStore.used) do
		total_items = total_items + 1
		if item.CanBeConsumed and InteractionRand(100, "BobbyRayShop") < pick_probability then
			consumed_items = consumed_items + 1
			bobby_restock_print("Consumed", item.class, "(Used)")
			g_BobbyRayStore.used[item.id] = nil
		end
	end
	if total_items > 0 then bobby_restock_print(" --------------------------- Consumed", consumed_items, "out of", total_items, "used items", "or", MulDivRound(consumed_items, 100, total_items)) end
end

---
--- Sets the current category and subcategory for the Bobby Ray's shop.
---
--- @param category string The category to set, or "Weapons" if nil.
--- @param subcategory string The subcategory to set.
function BobbyRayShopSetCategory(category, subcategory)
	PDABrowserTabState["bobby_ray_shop"].category = category or "Weapons"
	PDABrowserTabState["bobby_ray_shop"].subcategory = subcategory
end

---
--- Gets the active category and subcategory for the Bobby Ray's shop.
---
--- @return string category The active category for the Bobby Ray's shop.
--- @return string subcategory The active subcategory for the Bobby Ray's shop.
function BobbyRayShopGetActiveCategoryPair(category)
	PDABrowserTabState["bobby_ray_shop"].category = PDABrowserTabState["bobby_ray_shop"].category or "Weapons"
	return PDABrowserTabState["bobby_ray_shop"].category, PDABrowserTabState["bobby_ray_shop"].subcategory
end

---
--- Gets the preset for the given Bobby Ray's shop category.
---
--- @param category string The category to get the preset for.
--- @return table The preset for the given Bobby Ray's shop category.
function BobbyRayShopGetCategory(category)
	return FindPreset("BobbyRayShopCategory", category)
end

---
--- Gets the preset for the given Bobby Ray's shop subcategory.
---
--- @param subcategory string The subcategory to get the preset for.
--- @return table The preset for the given Bobby Ray's shop subcategory.
function BobbyRayShopGetSubCategory(subcategory)
	return FindPreset("BobbyRayShopSubCategory", subcategory)
end
---------------------------------------------------------- Weapon Components

---
--- Gets the display name of the weapon modification component at the given index.
---
--- @param ctx table The context containing the weapon and index.
--- @return string The display name of the weapon modification component.
function TFormat.GetWeaponModificationRolloverTitle(ctx)
	local component = WeaponComponents[WeaponGetComponentAt(ctx.weapon, ctx.index)]
	return component.DisplayName
end

---
--- Gets the description of the weapon modification component at the given index.
---
--- @param ctx table The context containing the weapon and index.
--- @return string The description of the weapon modification component.
function TFormat.GetWeaponModificationRolloverText(ctx)
	local component = WeaponComponents[WeaponGetComponentAt(ctx.weapon, ctx.index)]
	return GetWeaponComponentDescription(component)
end

---
--- Gets the number of weapon components attached to the given weapon.
---
--- @param weapon table The weapon to get the component count for.
--- @return integer The number of weapon components attached to the weapon.
function WeaponCountComponents(weapon)
	if not weapon.components then return 0 end
	
	local count = 0
	for slot, component in pairs(weapon.components) do
		local componentSlot = table.find_value(weapon.ComponentSlots, "SlotType", slot)
		-- local defaultComponent = componentSlot and componentSlot.DefaultComponent
		if component and component ~= "" then count = count + 1 end
	end
	return count
end

---
--- Gets the weapon component at the given index.
---
--- @param weapon table The weapon to get the component from.
--- @param index integer The index of the component to get.
--- @return string|nil The weapon component at the given index, or nil if not found.
function WeaponGetComponentAt(weapon, index)
	if not weapon.ComponentSlots or not weapon.ComponentSlots[index] then return nil end
	
	local count = 0
	for _, slot in ipairs(weapon.ComponentSlots) do
		local comp = weapon.components[slot.SlotType]
		
		if comp and comp ~= "" then
			count = count + 1
		end
		if count == index then
			return comp
		end
	end
	return nil
end

---------------------------------------------------------- Finish purchase

GameVar("g_BobbyRay_CurrentShipments", {})

local function lBobbyRayAddShipment(departure_time, due_time, order_id, items, sector_id, total_cost, delivery_option)
	assert(not g_BobbyRay_CurrentShipments[order_id])
	g_BobbyRay_CurrentShipments[order_id] = { order_id = order_id, departure_time = departure_time, due_time = due_time, items = items, sector_id = sector_id, total_cost = total_cost, delivery_option = delivery_option.id }
	return g_BobbyRay_CurrentShipments[order_id]
end

local function lBobbyRayRemoveShipment(order_id)
	assert(g_BobbyRay_CurrentShipments[order_id])
	g_BobbyRay_CurrentShipments[order_id] = nil
end

local function lBobbyRayClearShipments()
	table.clear(g_BobbyRay_CurrentShipments)
end

local function lCheckShipments()
	local due_shipments = {}
	for order_id, shipment in pairs(g_BobbyRay_CurrentShipments) do
		if Game.CampaignTime >= shipment.due_time then
			table.insert(due_shipments, shipment)
		end
	end
	
	table.sort(due_shipments, function(a,b)
		if a.due_time > b.due_time then return false;
		elseif b.due_time > a.due_time then return true;
		end
		
		assert(a == b or a.order_id ~= b.order_id)
		if a.order_id >= b.order_id then return false;
		elseif b.order_id > a.order_id then return true;
		end
	end)
	
	for _, shipment in ipairs(due_shipments) do
		Msg("BobbyRayShopShipmentArrived", shipment)
		lBobbyRayRemoveShipment(shipment.order_id)
	end
end

---
--- Returns the closest shipment from the list of current shipments.
---
--- @return table|nil The closest shipment, or `nil` if there are no current shipments.
function GetClosestShipment()
	if table.count(g_BobbyRay_CurrentShipments) == 0 then return nil end
	
	local closest_shipment = nil
	for id, shipment in pairs(g_BobbyRay_CurrentShipments) do
		if closest_shipment == nil or shipment.due_time < closest_shipment.due_time or shipment.order_id < closest_shipment.order_id then
			closest_shipment = shipment
		end
	end
	return closest_shipment
end

local function lGenerateShipmentId(num_attempts)
	local order_id = InteractionRand(2147483647, "BobbyRayShop")
	local count = 0
	num_attempts = num_attempts or 20
	while g_BobbyRay_CurrentShipments[order_id] do
		order_id = InteractionRand(2147483647, "BobbyRayShop")
		count = count + 1
		if count > num_attempts then return -1 end
	end
	return order_id
end

---
--- Completes the purchase process for the Bobby Ray's shop.
---
--- This function generates a new shipment ID, calculates the delivery time and sector,
--- creates the inventory entries for the purchased items, updates the store inventory,
--- deducts the total cost from the player's money, and adds the shipment to the timeline.
---
--- @param none
--- @return none
---
function BobbyRayShopFinishPurchase()
	-- !TODO: recheck money because of multiplayer lag? a merc could have been hired, etc.
	local order_id = lGenerateShipmentId()
	assert(order_id ~= -1, "Failed to generate shipment id (too many collisions)")
	
	local due_time = Game.CampaignTime + BobbyRayCartGetDeliveryOption().MinTime * const.Scale.day + InteractionRand((BobbyRayCartGetDeliveryOption().MaxTime - BobbyRayCartGetDeliveryOption().MinTime) * const.Scale.day)
	local sector_id = BobbyRayCartGetDeliverySector()
	local delivery_option = BobbyRayCartGetDeliveryOption()
	
	local items_number, total_cost = BobbyRayCartGetAggregate()
	
	-- create inventory entries
	local shipment_items = {}
	local units = BobbyRayCartGetUnits()
	--this generates item ids so it should be in sync order
	for unit, amount in sorted_pairs(units) do
		if amount ~= 0 then
			local actual_unit = lGetShopItemFromId(unit)
			for _, item in sorted_pairs(actual_unit:GenerateInventoryEntries(amount)) do
				table.insert(shipment_items, item)
			end
		end
	end
	
	local gossip_table = {}
	for unit, amount in pairs(units) do
		if amount ~= 0 then
			local actual_unit = lGetShopItemFromId(unit)
			
			table.insert(gossip_table,{
				item = actual_unit.class,
				cost = BobbyRayStoreGetEntryCost(actual_unit),
				used = actual_unit.Used and true or false,
				amount = amount,
				shop_stack = actual_unit.ShopStackSize and actual_unit.ShopStackSize or 1,
			})
		end
	end
	NetGossip("BobbyRayPurchase", order_id, gossip_table, GetCurrentPlaytime(), Game and Game.CampaignTime)
	
	-- add event to satellite timeline
	local shipment_context = { sectorId = sector_id, items = shipment_items, order_id = order_id }
	AddTimelineEvent(
		"bobby_ray_shipment_" .. tostring(order_id), 
		due_time, 
		"store_shipment", 
		shipment_context
	)
	
	-- update store
	for item_id, amount in pairs(units) do
		if amount > 0 then
			local item = lGetShopItemFromId(item_id)
			if item.Used then
				assert(g_BobbyRayStore.used[item.id])
				g_BobbyRayStore.used[item.id] = nil
			else
				assert(g_BobbyRayStore.standard[item.class] and g_BobbyRayStore.standard[item.class].Stock >= amount)
				g_BobbyRayStore.standard[item.class].Stock = g_BobbyRayStore.standard[item.class].Stock - amount
				if g_BobbyRayStore.standard[item.class].Stock == 0 then
					g_BobbyRayStore.standard[item.class] = nil
					g_BobbyRayStore.standard_ids[item.id] = nil
				end
			end
		end
	end
	
	-- clear cart
	BobbyRayCartClearEverything()
	
	-- update player money
	AddMoney(-total_cost, "expense")
	
	local shipment_details = lBobbyRayAddShipment(Game.CampaignTime, due_time, order_id, shipment_items, sector_id, total_cost, delivery_option)
	CombatLog("important",T{624146592949, "<em>Bobby Ray's</em> shipment sent. It will arrive in <em><timeDuration(due_time)></em> in <em><SectorName(sector_id)></em>",order_id = order_id, due_time = due_time - Game.CampaignTime, sector_id = sector_id})
	Msg("BobbyRayShopShipmentSent", shipment_details)
end

function OnMsg.BobbyRayShopShipmentArrived(shipment_details)
	local sectorStash = GetSectorInventory(shipment_details.sector_id)
	local itemsCopy = table.copy(shipment_details.items)
	if sectorStash then 
		AddItemsToInventory(sectorStash, itemsCopy)
	end
end

---------------------------------------------------------- Email

---
--- Formats a list of items for a Bobby Ray email.
---
--- @param context table The context for the email.
--- @param items table A list of items to format.
--- @return string The formatted item list.
---
function TFormat.BobbyRayEmailItemList(context, items)
	return table.concat(table.map(items, function(item) return T{757479034237, "\t<bullet_point> <DisplayName> x <Amount>\n", DisplayName = item.DisplayName, Amount = (item.Amount or 1)} end ))
end

---------------------------------------------------------- Time advancement

function OnMsg.StartSatelliteGameplay()
	lCheckShipments()
	BobbyRayCartClearEverything()
end

function OnMsg.SatelliteTick()
	lCheckShipments()
	BobbyRayCartClearEverything()
	lForgetBobbyRayOrderTabState()
	NetSyncEvents.BobbyRayUpdateNew() --sat tick is sync-ish
end

function OnMsg.MoneyChanged(amount, logReason, previousBalance)
	ObjModified(g_BobbyRayCart)
	ObjModified(g_BobbyRayStore)
end
---------------------------------------------------------- Multiplayer utility

local function lCloseBobbyCountdowns()
	for d, _ in pairs(g_OpenMessageBoxes) do
		if d and d.window_state == "open" and d.context.obj == "bobby-countdown" then
			d:Close()
		end
	end
end

---
--- Handles the completion of various Bobby Ray-related actions in a multiplayer game.
---
--- @param mode string The type of action that has been completed. Can be one of "clear-store", "clear-order", "finish-order", "consume-stock", or "restock".
---
function NetSyncEvents.FinishBBROrder(mode)
	if mode == "clear-store" then
		if IsBobbyRayOpen("cart") then OpenBobbyRayPage() end
		BobbyRayStoreClear()
		ObjModified(g_BobbyRayStore)
	elseif mode == "clear-order" then
		if IsBobbyRayOpen("cart") then OpenBobbyRayPage() end
		BobbyRayCartClearEverything()
		ObjModified(g_BobbyRayCart)
	elseif mode == "finish-order" then
		if IsBobbyRayOpen() then OpenBobbyRayPage() end
		ObjModified("BobbyRayShopFinishPurchaseUI")
		BobbyRayShopFinishPurchase()
	elseif mode == "consume-stock" then
		BobbyRayStoreConsumeRandomStock()
		ObjModified(g_BobbyRayStore)
		ObjModified(g_BobbyRayCart)
	elseif mode == "restock" then
		BobbyRayStoreRestock()
		ObjModified(g_BobbyRayStore)
		ObjModified(g_BobbyRayCart)
	else
		assert("unknown mode:", mode)
	end
end

---
--- Handles the creation of a countdown timer before executing a Bobby Ray-related action in a multiplayer game.
---
--- @param mode string The type of action that will be executed. Can be one of "clear-store", "clear-order", "finish-order", "consume-stock", or "restock".
---
function NetSyncEvents.CreateTimerBeforeAction(mode)
	if not CanYield() then
		CreateGameTimeThread(NetSyncEvents.CreateTimerBeforeAction, mode)
		return
	end
	
	lCloseBobbyCountdowns()
	
	local dialog = CreateMessageBox(terminal.desktop, "", "", T(739643427177, "Cancel"),  "bobby-countdown")
	local reason = "bobby-countdown"
	Pause(reason)
	PauseCampaignTime(reason)
	dialog.OnDelete = function()
		Resume(reason)
		ResumeCampaignTime(reason)
	end
	
	local countdown_seconds = 3
	dialog:CreateThread("bobby-countdown", function()
		if netInGame and table.count(netGamePlayers) > 1 then
			local idText = dialog.idMain.idText
			local currentCountdown = countdown_seconds
			for i = 1, countdown_seconds do
				if idText.window_state == "open" then
					if mode == "clear-order" then
						idText:SetText(T{575279476730, "<center>Clearing order in <u(currentCountdown)>", currentCountdown = currentCountdown})
					elseif mode == "clear-store" then
						idText:SetText(T{332391120755, "<center>(DEV-DEBUG)Clearing store in <u(currentCountdown)>", currentCountdown = currentCountdown})
					elseif mode == "finish-order" then
						idText:SetText(T{533359561728, "<center>Finishing order in <u(currentCountdown)>", currentCountdown = currentCountdown})
					elseif mode == "restock" then
						idText:SetText(T{852189704117, "<center>(DEV-DEBUG)Restocking shop in <u(currentCountdown)>", currentCountdown = currentCountdown})
					elseif mode == "consume-stock" then
						idText:SetText(T{202941315408, "<center>(DEV-DEBUG)Consuming random shop stock in <u(currentCountdown)>", currentCountdown = currentCountdown})
					else
						idText:SetText(T{233587337306, "<center>Unknown action in <u(currentCountdown)>", currentCountdown = currentCountdown})
					end
				else
					break
				end
					
				Sleep(1000)
				currentCountdown = currentCountdown - 1
			end
		end
		dialog:Close()
		
		FireNetSyncEventOnHost("FinishBBROrder", mode)
	end)
	
	WaitMsg(dialog)
	local res = dialog.result
	if res == "ok" then
		NetSyncEvent("CancelBobbyCountdown", mode, netUniqueId)
	end
end

---
--- Cancels any active Bobby Ray countdown timers.
---
--- @param mode string The mode of the countdown being cancelled.
--- @param player_id string The unique identifier of the player who initiated the countdown.
---
function NetSyncEvents.CancelBobbyCountdown(mode, player_id)
	lCloseBobbyCountdowns()
end

---
--- Fixes up the savegame session data for the Bobby Ray tab state.
---
--- If the `bobby_ray_shop` field does not exist in the `PDABrowserTabState` table, it is added with a `locked` field set to `true`.
---
--- @param data table The savegame session data.
--- @param meta table The savegame session metadata.
---
function SavegameSessionDataFixups.BobbyRayTabState(data, meta)
	assert(data.gvars.PDABrowserTabState)
	if not data.gvars.PDABrowserTabState.bobby_ray_shop then
		data.gvars.PDABrowserTabState.bobby_ray_shop = { locked = true }
	end
end

---------------------------------------------------------- Satellite Squad

DefineClass.ShipmentWindowClass = {
	__parents = { "XMapObject", "XContextWindow" },
	ZOrder = 3,
	IdNode = true,
	ContextUpdateOnOpen = true,
	ScaleWithMap = false,
	FXMouseIn = "SatelliteBadgeRollover",
	FXPress = "SatelliteBadgePress",
	FXPressDisabled = "SatelliteBadgeDisabled",
	RolloverOffset = box(30, 24, 0, 0),
	RolloverBackground = RGBA(255, 255, 255, 0),
	PressedBackground = RGBA(255, 255, 255, 0),

	routes_displayed = false,
	
	route_visible = true
}

---
--- Updates the zoom level of the shipment window.
---
--- @param prevZoom number The previous zoom level.
--- @param newZoom number The new zoom level.
--- @param time number The time over which the zoom should be updated.
---
function ShipmentWindowClass:UpdateZoom(prevZoom, newZoom, time)
	local map = self.map
	local maxZoom = map:GetScaledMaxZoom()
	local minZoom = Max(1000 * map.box:sizex() / map.map_size:x(), 1000 * map.box:sizey() / map.map_size:y())
	newZoom = Clamp(newZoom, minZoom + 120, maxZoom)

	XMapWindow.UpdateZoom(self, prevZoom, newZoom, time)
end

---
--- Returns the visual position of the shipment window.
---
--- @return table The visual position of the shipment window.
---
function ShipmentWindowClass:GetTravelPos()
	return self:GetVisualPos()
end

---
--- Sets the visibility of the shipment window and its associated route decorations.
---
--- @param visible boolean Whether the shipment window should be visible or not.
---
function ShipmentWindowClass:SetVisible(visible)
	XMapObject.SetVisible(self, visible)
	XContextWindow.SetVisible(self, visible)
	
	if not self.routes_displayed then return end
	self.routes_displayed["main"][1]:SetVisible(visible)
	for _1, decoration in pairs(self.routes_displayed["main"].decorations) do
		decoration:SetVisible(visible)
	end
end

---
--- Closes the shipment window and any associated route decorations.
---
--- This function is responsible for closing the shipment window and any associated route decorations that were displayed. It first calls the `XMapObject.Close()` function to close the window, and then checks the `window_state` to see if the window was in the "open" or "closing" state, in which case it also calls `XContextWindow.Close()` to fully close the window.
---
--- If the `routes_displayed` table is not empty, it then iterates through the "main" route segment and its decorations, calling the `Close()` function on each one to ensure they are properly closed and removed from the UI.
---
--- @method Close
--- @return nil
function ShipmentWindowClass:Close()
	XMapObject.Close(self)
	if self.window_state == "open" or self.window_state == "closing" then XContextWindow.Close(self) end
	
	if not self.routes_displayed then return end
	self.routes_displayed["main"][1]:Close()
	for _1, decoration in pairs(self.routes_displayed["main"].decorations) do
		decoration:Close()
	end
end

---
--- Creates a new Bobby Ray shipment squad.
---
--- This function creates a new Bobby Ray shipment squad with the provided shipment details. The squad is spawned using the "BobbyRaySquadWindow" template and is assigned various properties such as the side, arrival status, shipment details, and name.
---
--- @param shipment_details table The details of the shipment to be used for the new squad.
--- @return table The newly created Bobby Ray shipment squad.
---
function CreateBobbyRayShipmentSquad(shipment_details)	
	local predef_props = {
		Side = "player1",
		arrival_squad = true, arrival_shipment = true, 
		shipment = shipment_details, 
		Name = "Bobby Ray's shipment " .. tostring(shipment_details.order_id), -- !TODO: this would need to be a translated string, but I'm not showing a rollover, for now.
		CurrentSector = shipment_details.sector_id -- !TODO: should this be something else? Perhaps inferred from the travel time? I believe it may affect its label
	}
	return XTemplateSpawn("BobbyRaySquadWindow", g_SatelliteUI, predef_props)
end

---
--- Updates the movement of a shipment window.
---
--- This function is responsible for updating the movement of a shipment window. It first checks if there is a "late-layout" thread running, and if so, it deletes that thread. It then deletes the "sat-movement" thread and creates a new one, passing the `ArrivingShipmentTravelThread` function and the `shipment_window` as arguments.
---
--- @param shipment_window table The shipment window to update the movement for.
--- @return nil
---
function ShipmentUIUpdateMovement(shipment_window)
	local lateLayoutThread = shipment_window:GetThread("late-layout")
	if lateLayoutThread and CurrentThread() ~= lateLayoutThread then
		shipment_window:DeleteThread(lateLayoutThread)
	end

	shipment_window:DeleteThread("sat-movement")
	shipment_window:CreateThread("sat-movement", ArrivingShipmentTravelThread, shipment_window)
end

---
--- Computes and displays the travel path for an arriving Bobby Ray shipment.
---
--- This function is responsible for computing the travel path for an arriving Bobby Ray shipment and displaying it on the shipment window. It performs the following tasks:
---
--- 1. Retrieves the shipment details and the sector ID of the destination sector.
--- 2. Computes the arriving path from the leftmost sector to the destination sector using the `ComputeArrivingPath` function.
--- 3. If the departure time is not set, it calculates the departure time based on the delivery option preset.
--- 4. Spawns a route end decoration and sets its properties.
--- 5. Stores the computed route segments and decorations in the `routes_displayed` table of the shipment window.
--- 6. Displays the remaining travel time and path on the shipment window using the `DisplayArrivingPathRemainder` function.
---
--- @param shipment_window table The shipment window to update the travel path for.
---
function ArrivingShipmentTravelThread(shipment_window)
	local shipment = shipment_window.context.shipment
	local sectorId = shipment.sector_id
	local sY, sX = sector_unpack(sectorId)
	local sectorPos = gv_Sectors[sectorId].XMapPosition
	local leftMostSectorId = sector_pack(sY, 1)
	
	local positions, routeSegments = ComputeArrivingPath(leftMostSectorId, sectorId)

	if not shipment.departure_time then -- save fixup, essentially
		local preset = FindPreset("BobbyRayShopDeliveryDef", shipment.delivery_option)
		assert(preset)
		shipment.departure_time = shipment.due_time - preset.MaxTime * const.Scale.day
	end
	
	local routeEndDecoration = XTemplateSpawn("SquadRouteDecoration", g_SatelliteUI)
	if g_SatelliteUI.window_state == "open" then
		routeEndDecoration:Open()
	end
	routeEndDecoration:SetRouteEnd(point(0, sY), sectorId)
	routeEndDecoration:SetColor(GameColors.Player)
	
	if not shipment_window.routes_displayed then shipment_window.routes_displayed = {} end
	shipment_window.routes_displayed["main"] = routeSegments
	routeSegments.decorations = { routeEndDecoration }
	
	local totalTime = shipment.due_time - shipment.departure_time
	local timeLeft = shipment.due_time - Game.CampaignTime
	DisplayArrivingPathRemainder(totalTime, timeLeft, routeSegments, positions, shipment_window)
end

---------------------------------------------------------- Rollover Button

DefineClass.PDABobbyRayPopupButtonClass = {
	__parents = { "PDACommonButtonClass" },
	has_lost_rollover = false
}

---
--- This function is called when the layout of the `PDABobbyRayPopupButtonClass` is complete.
--- It checks if the button has lost its rollover state, and if so, sets the `has_lost_rollover` flag.
--- It then calls the `OnLayoutComplete` function of the parent `PDACommonButtonClass`.
---
--- @param self table The `PDABobbyRayPopupButtonClass` instance.
---
function PDABobbyRayPopupButtonClass:OnLayoutComplete()
	if not self.has_lost_rollover then
		if not self:MouseInWindow(terminal.GetMousePos()) then
			self.has_lost_rollover = true
		end
	end
	PDACommonButtonClass.OnLayoutComplete(self)
end

---
--- This function sets up the category button for the Bobby Ray shop.
---
--- It performs the following steps:
--- - Gets the current dialog
--- - Aligns the popup menu to the button
--- - Gets the current category and active category/subcategory
--- - Spawns a new `PDABrowserBobbyRay_Store_SubCategoryMenu` template and sets its properties
--- - Sets the anchor, minimum width, and button reference for the new menu
--- - Opens the new menu
--- - Calls `OnOpenPopupMenu()` on the button
--- - Sets the new menu as the modal window for the desktop
--- - Resets the `has_lost_rollover` flag to `false`
---
--- @param self table The `PDABobbyRayPopupButtonClass` instance.
---
function PDABobbyRayPopupButtonClass:SetupCategoryButton()
	local dlg = GetDialog(self)
	local alignMenuTo = self
	local category = BobbyRayShopGetCategory(self:GetContext())
	local categoryId, subcategoryId = BobbyRayShopGetActiveCategoryPair()
	local active_category = BobbyRayShopGetCategory(categoryId)
	local active_subcategory = BobbyRayShopGetSubCategory(subcategoryId)
	local ctxMenu = XTemplateSpawn("PDABrowserBobbyRay_Store_SubCategoryMenu", dlg, { category = category, active_category = active_category, active_subcategory = active_subcategory })
	ctxMenu:SetAnchor(alignMenuTo.box)
	ctxMenu:SetMinWidth(self.measure_width)
	ctxMenu.button = self
	ctxMenu:Open()
	self:OnOpenPopupMenu()
	self.desktop:SetModalWindow(ctxMenu)
	self.has_lost_rollover = false
end

---
--- This function is called when the mouse cursor enters or leaves the `PDABobbyRayPopupButtonClass` button.
--- If the mouse cursor enters the button and the `has_lost_rollover` flag is true, it creates a new real-time thread that waits 1 millisecond and then calls the `SetupCategoryButton()` function.
---
--- @param self table The `PDABobbyRayPopupButtonClass` instance.
--- @param rollover boolean True if the mouse cursor has entered the button, false if it has left.
---
function PDABobbyRayPopupButtonClass:RolloverCategoryButton(rollover)
	if GetUIStyleGamepad() then return end
	if rollover then
		CreateRealTimeThread(function()
			Sleep(1) -- to avoid recursive update
			self:SetupCategoryButton()
		end)
	end
end

---
--- This function is called when the mouse cursor enters or leaves the `PDABobbyRayPopupButtonClass` button.
--- If the mouse cursor enters the button and the `has_lost_rollover` flag is true, it calls the `RolloverCategoryButton()` function.
--- If the mouse cursor leaves the button, it sets the `has_lost_rollover` flag to true.
--- It also calls the `OnSetRollover()` function from the parent `PDACommonButtonClass`.
---
--- @param self table The `PDABobbyRayPopupButtonClass` instance.
--- @param rollover boolean True if the mouse cursor has entered the button, false if it has left.
---
function PDABobbyRayPopupButtonClass:OnSetRollover(rollover)
	if rollover and self.has_lost_rollover then
		self:RolloverCategoryButton(rollover)
	elseif not rollover then
		self.has_lost_rollover = true
	end
	PDACommonButtonClass.OnSetRollover(self, rollover)
end

---
--- This function is called when the `PDABobbyRayPopupButtonClass` button is pressed.
--- It calls the `SetupCategoryButton()` function to set up the button's category.
---
--- @param self table The `PDABobbyRayPopupButtonClass` instance.
--- @param gamepad boolean Whether the button was pressed using a gamepad.
---
function PDABobbyRayPopupButtonClass:OnPress(gamepad)
	self:SetupCategoryButton()
end

---
--- This function is called when the `PDABobbyRayPopupButtonClass` popup menu is closed.
--- It sets the column usage to "abccd" and checks if the mouse cursor is no longer within the window. If the mouse has left the window, it sets the `has_lost_rollover` flag to true.
---
--- @param self table The `PDABobbyRayPopupButtonClass` instance.
---
function PDABobbyRayPopupButtonClass:OnClosePopupMenu()
	self:SetColumnsUse("abccd")
	if not self:MouseInWindow(terminal.GetMousePos()) then 
		self.has_lost_rollover = true 
	end
end

---
--- This function is called when the `PDABobbyRayPopupButtonClass` popup menu is opened.
--- It sets the column usage to "ccccd" for the popup menu.
---
--- @param self table The `PDABobbyRayPopupButtonClass` instance.
---
function PDABobbyRayPopupButtonClass:OnOpenPopupMenu()
	self:SetColumnsUse("ccccd")
end

---------------------------------------------------------- Resolution change

if FirstLoad then
	g_PrevRes = point(GetResolution())
end
function OnMsg.SystemSize(pt)
	if g_PrevRes ~= pt then
		g_PrevRes = pt
		if IsBobbyRayOpen() then
			OpenBobbyRayPage() -- front page to prevent the grid ui breaking
		end
	end
end
