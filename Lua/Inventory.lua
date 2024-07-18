DefineClass.InventoryItem = {
	__parents = {"ZuluModifiable", "InventoryItemProperties", "ScrapableItem", "BobbyRayShopItemProperties"},
	properties = {
		{ id = "id", editor = "number", default = false},
	},
}

if FirstLoad then
	g_ItemIdToItem = setmetatable({}, weak_values_meta)
	nextItemId = 0
	g_UnarmedWeapon = false
end

---
--- Clears the item ID data, including removing all items from the `g_ItemIdToItem` table and resetting the `nextItemId` counter.
--- Also places a new "Unarmed" inventory item in the `g_UnarmedWeapon` global variable.
---
--- @function ClearItemIdData
--- @return nil
function ClearItemIdData()
	for id, item in pairs(g_ItemIdToItem) do
		DoneObject(item)
	end
	g_ItemIdToItem = setmetatable({}, weak_values_meta)
	nextItemId = 0
	g_UnarmedWeapon = PlaceInventoryItem("Unarmed")
end

---
--- Generates a unique item ID by incrementing the `nextItemId` global variable and returning the previous value.
---
--- @return integer The generated item ID.
function GenerateItemId()
	nextItemId = nextItemId + 1
	return nextItemId - 1
end

---
--- Returns whether the InventoryItem has a condition.
---
--- @return boolean True if the InventoryItem has a condition, false otherwise.
function InventoryItem:HasCondition()
	return true
end

---
--- Initializes the item ID for the InventoryItem.
---
--- This function is called when an InventoryItem is created to set its unique ID.
---
--- @function InventoryItem:Init
--- @return nil
function InventoryItem:Init()
	self:InitializeItemId()
end

---
--- Cleans up an InventoryItem when it is no longer needed.
---
--- If the InventoryItem has an owner, the owner is set to `false`. If the InventoryItem has an ID, it is removed from the `g_ItemIdToItem` table and a network update is sent to notify other clients.
---
--- @function InventoryItem:Done
--- @return nil
function InventoryItem:Done()
	if not GameState.sync_loading and self.owner then
		self.owner = false
	end

	if self.id then --only netcheck items with id, otherwise we get false desyncs when weapon mod preview items get nuked;
		g_ItemIdToItem[self.id] = nil
		NetUpdateHash("InventoryItem:Done", self.id, nextItemId, self.class)
	end
end

local function lInventoryItemInitializeItemId(self)
	self:Setid(self.id or GenerateItemId(), true)
end
InventoryItem.InitializeItemId = lInventoryItemInitializeItemId

local function lInventoryItemSetId(self, val, new)
	if self.id == val then return end
	
	local old_item
	if not new and g_ItemIdToItem[val] then
		--not new -> item being loaded from save data (setproplist)
		old_item = g_ItemIdToItem[val]
		old_item:Setid(GenerateItemId(), true) --shift the old item somewhere else, saved ids have precedence
		assert(not g_ItemIdToItem[val])
	end
	
	nextItemId = Max(nextItemId, val + 1)
	if self.id then
		g_ItemIdToItem[self.id] = nil
	end
	self.id = val
	g_ItemIdToItem[val] = self
	NetUpdateHash("InventoryItem:Setid", val, nextItemId, new, self.class, old_item and old_item.class, old_item and old_item.id)
end

InventoryItem.Setid = lInventoryItemSetId

if FirstLoad then
	g_InventoryItemIdInitDetachReasons = {}
end

---
--- Detaches the initialization of the item ID for an InventoryItem.
--- This is used when an InventoryItem is not expected to be part of the inventory system,
--- such as when creating a UI clone of the item.
---
--- @param reason string The reason for detaching the ID initialization.
function InventoryItem.DetachIdInitialization(reason)
	reason = reason or false
	g_InventoryItemIdInitDetachReasons[reason] = true
	InventoryItem.InitializeItemId = empty_func
	InventoryItem.Setid = empty_func
end

---
--- Reattaches the initialization of the item ID for an InventoryItem.
--- This is used to re-enable the ID initialization after it has been detached.
---
--- @param reason string The reason for reattaching the ID initialization.
function InventoryItem.AttachIdInitialization(reason)
	reason = reason or false
	g_InventoryItemIdInitDetachReasons[reason] = nil
	
	if not next(g_InventoryItemIdInitDetachReasons) then
		InventoryItem.InitializeItemId = lInventoryItemInitializeItemId
		InventoryItem.Setid = lInventoryItemSetId
	end
end

---
--- Creates a clone of the InventoryItem.
--- This is used to create a UI representation of the item that is not part of the inventory system.
---
--- @param self InventoryItem The InventoryItem to clone.
--- @return table The cloned InventoryItem.
---
function InventoryItem:UIClone()
	local code = pstr("", 8*1024)
	code:clear()
	code:append("return {")
	self:__toluacode(nil, code)
	code:append("}")
	
	local func, err = load(code:str())
	
	-- Detach item id initialization as this item is not expected to be
	-- part of the inventory system.
	InventoryItem.DetachIdInitialization("UIClone")
	local ok, clonedItem = procall(func)
	InventoryItem.AttachIdInitialization("UIClone")
	
	if not ok or not clonedItem or not clonedItem[1] then return false end
	local clone = clonedItem[1]
	rawset(clone, "is_clone", true)
	clone.RegisterReactions = empty_func -- no reactions for cloned items; handle differently if they prove to be necessary for modify weapon dlg values
	return clone
end

---
--- Dumps the contents of the `g_ItemIdToItem` table to a file named "iddump.txt".
---
--- This function is used for debugging purposes, to save a snapshot of the current
--- item ID to item mapping. The contents of the file can be inspected to
--- understand the state of the item inventory system.
---
--- @return nil
function dumpIds()
	local f = io.open("iddump.txt", "w")
	local str = TableToLuaCode(g_ItemIdToItem)
	f:write(str)
	f:close()
end

DefineClass("ItemUpgrade", "InventoryItem", "ItemUpgradeProperties")
DefineClass.InventoryStack = {
	__parents = {"InventoryItem"},
	properties = {
		{ id = "Amount", editor = "number", default = 1},
		{ id = "MaxStacks", template = true, editor = "number", default = 10},
	}
}

function OnMsg.ClassesPreprocess(classdefs)
	for class, value in pairs(const.BaseDropChance) do
		if classdefs[class] and not classdefs[class].base_drop_chance then
			classdefs[class].base_drop_chance = value
		end
	end
end

DefineClass.SquadBagItem = { __parents = { "InventoryStack"} }
DefineClass.Armor = { __parents = { "InventoryItem", "ArmorProperties", "BobbyRayShopArmorProperties" } ,
	properties = {{ id = "SumDamageReduction", name = "Damage Reduction", editor = "number", default = 0, no_edit = true, read_only = true},},
	GetRolloverType = function() return "Armor" end,
}
DefineClass.Ammo = { __parents = { "SquadBagItem", "AmmoProperties", "BobbyRayShopAmmoProperties" } }
DefineClass.QuickSlotItem = { __parents = { "InventoryItem" } }
DefineClass.Medicine = { __parents = { "InventoryItem", "BobbyRayShopOtherProperties"},
	properties = {
		{ id = "max_meds_parts", name = "Max Meds Parts", template = true, category = "Condition", editor = "number", default = 0},
		{ id = "UsePriority", editor = "number", default = 0, template = true, },
	},
}

DefineClass("GasMaskBase", "Armor")

-- Armor --
---
--- Returns a rollover hint for the armor item, displaying the body parts it protects.
---
--- @return string The rollover hint for the armor item.
function Armor:GetRolloverHint()
	local hint = {} 	
	local parts = {}
	for part,val in sorted_pairs(self.ProtectedBodyParts) do
		local preset= Presets.TargetBodyPart.Default[part]
		parts[#parts+1] = preset.display_name
	end
	hint[#hint+1] = T{378508273050, "<bullet_point> Body parts - <parts>", parts = table.concat(parts, ", ")}
	hint[#hint+1] = self.AdditionalHint or ""
	return table.concat(hint, "\n")
end	

---
--- Returns the sum of the armor's damage reduction and additional reduction.
---
--- @return number The total damage reduction of the armor.
function Armor:GetSumDamageReduction()
	return self.DamageReduction +  self.AdditionalReduction
end

---
--- Returns the status UI text for the armor item.
---
--- If the armor is broken, returns "BROKEN". Otherwise, returns the status UI text from the base InventoryItem class.
---
--- @return string The status UI text for the armor item.
function Armor:GetItemStatusUI()
	if self:IsCondition("Broken") then
		return T(623193685060, "BROKEN")
	end
	return InventoryItem.GetItemStatusUI(self) -- locked item
end
function Armor:GetItemStatusUI()-- centered text
	if self:IsCondition("Broken") then
		return T(623193685060, "BROKEN")
	end
	return InventoryItem.GetItemStatusUI(self) -- locked item
end

---
--- Returns the status UI text for the medicine item.
---
--- If the medicine is depleted (condition is 0), returns "DEPLETED". Otherwise, returns the status UI text from the base InventoryItem class.
---
--- @return string The status UI text for the medicine item.
function Medicine:GetItemStatusUI()-- centered text
	if self.Condition==0 then
		return T(963116994412, "DEPLETED")
	end
	return InventoryItem.GetItemStatusUI(self) -- locked item
end

DefineClass.ConditionAndRepair = { __parents = { "QuickSlotItem", "CapacityItemProperties" } }
DefineClass.Valuables = { __parents = { "InventoryItem" } }
DefineClass.ValuablesStack = { __parents = { "Valuables", "InventoryStack" } }
DefineClass.ValuableItemContainer = { __parents = { "InventoryItem" } }
DefineClass.QuestItem = { __parents = { "InventoryItem", "QuestItemProperties" } }
DefineClass.QuestStackItem = { __parents = { "QuestItem", "InventoryStack" } }
DefineClass.QuestItemValuable = { __parents = { "QuestItem", "Valuables" } }
DefineClass.ResourceItem = { __parents = { "SquadBagItem", "BobbyRayShopOtherProperties" } }

DefineClass.TransmutedArmor   = { __parents = {"Armor","TransmutedItemProperties" }, RevertConditionCounter = const.Weapons.ItemDegradationCounter }
DefineClass.TransmutedMachete = { __parents = {"MacheteWeapon","TransmutedItemProperties" }, RevertConditionCounter = const.Weapons.ItemDegradationCounter }
DefineClass.TransmutedFirearm = { __parents = {"Firearm","TransmutedItemProperties" }, RevertConditionCounter = const.Weapons.ItemDegradationCounter }
DefineClass.TransmutedHeavyWeapon = { __parents = {"HeavyWeapon","TransmutedItemProperties" }, RevertConditionCounter = const.Weapons.ItemDegradationCounter }

-- shield items by initing data when the item is directly added to tjhe inventory from script.
---
--- Initializes the TransmutedItemProperties of an item.
---
--- This function sets the RevertCondition, RevertConditionCounter, and OriginalItemId properties of the item based on the recipe data.
---
--- @param self The TransmutedItemProperties instance to initialize.
---
function TransmutedItemProperties_Init(self)
	local recipe = Recipes[self.class]
	if not recipe then
		for rec, rec_data in pairs(Recipes) do
			if rec_data.ResultItems and rec_data.ResultItems[1].item == self.class then
				recipe = rec_data
				break
			end
		end
	end
	if recipe then
		self.RevertCondition = recipe.RevertCondition
		self.RevertConditionCounter = recipe.RevertConditionValue
		self.OriginalItemId = recipe.Ingredients[1].item
	end
end

---
--- Initializes the TransmutedItemProperties of an item.
---
--- This function sets the RevertCondition, RevertConditionCounter, and OriginalItemId properties of the item based on the recipe data.
---
--- @param self The TransmutedItemProperties instance to initialize.
---
function TransmutedArmor:Init()
    TransmutedItemProperties_Init(self)
end

---
--- Initializes the TransmutedItemProperties of an item.
---
--- This function sets the RevertCondition, RevertConditionCounter, and OriginalItemId properties of the item based on the recipe data.
---
--- @param self The TransmutedItemProperties instance to initialize.
---
function TransmutedMachete:Init()
    TransmutedItemProperties_Init(self)
end

---
--- Initializes the TransmutedItemProperties of an item.
---
--- This function sets the RevertCondition, RevertConditionCounter, and OriginalItemId properties of the item based on the recipe data.
---
--- @param self The TransmutedItemProperties instance to initialize.
---
function TransmutedFirearm:Init()
    TransmutedItemProperties_Init(self)
end

---
--- Initializes the TransmutedItemProperties of an item.
---
--- This function sets the RevertCondition, RevertConditionCounter, and OriginalItemId properties of the item based on the recipe data.
---
--- @param self The TransmutedItemProperties instance to initialize.
---
function TransmutedHeavyWeapon:Init()
    TransmutedItemProperties_Init(self)
end
function TransmutedArmor:Init() TransmutedItemProperties_Init(self) end
function TransmutedMachete:Init() TransmutedItemProperties_Init(self) end
function TransmutedFirearm:Init() TransmutedItemProperties_Init(self) end
function TransmutedHeavyWeapon:Init() TransmutedItemProperties_Init(self) end

---
--- Makes a transmutation of a firearm item.
---
--- This function creates a new transmuted item from the given source item. It copies the ammo, upgrades, and jammed state from the source item to the new transmuted item.
---
--- @param self The TransmutedFirearm instance.
--- @param fromitem The source item to transmute.
--- @return The new transmuted item, and the previous item.
---
function TransmutedFirearm:MakeTransmutation(fromitem)
	local new_item, prev_item = TransmutedItemProperties.MakeTransmutation(self, fromitem)
	-- ammo
	if prev_item.ammo then
		local ammo = prev_item.ammo
		prev_item.ammo =  false
		new_item:Reload(ammo)
	end
	--upgrades
	for slot, component in pairs(prev_item.components) do
		new_item:SetWeaponComponent(slot,component)
	end
	--jammed
	new_item.jammed = prev_item.jammed
	return new_item, prev_item
end

---
--- Makes a transmutation of a heavy weapon item.
---
--- This function creates a new transmuted item from the given source item. It copies the ammo, upgrades, and jammed state from the source item to the new transmuted item.
---
--- @param self The TransmutedHeavyWeapon instance.
--- @param fromitem The source item to transmute.
--- @return The new transmuted item, and the previous item.
---
function TransmutedHeavyWeapon:MakeTransmutation(fromitem)
	return TransmutedFirearm:MakeTransmutation(self, fromitem)
end

---
--- Returns the UI representation of the item stack.
---
--- @param self The InventoryStack instance.
--- @return A table with the UI representation of the item stack.
---
function InventoryStack:GetItemSlotUI()
	return T{709831548750, "<style InventoryItemsCount><cur><valign bottom 0><style InventoryItemsCountMax>/<max></style>", 
				 cur = self.Amount, max = self.MaxStacks}
end

---
--- Returns the rollover title for the inventory stack.
---
--- If the stack contains only one item, the colored name of the item is returned.
--- If the stack contains multiple items, the colored plural name of the item is returned.
---
--- @param self The InventoryStack instance.
--- @return The rollover title for the inventory stack.
---
function InventoryStack:GetRolloverTitle()
	assert(self.DisplayName)
	if self.Amount == 1 then
		return self:GetColoredName()
	else
		return self:GetColoredName("plural")
	end
end	

---
--- Returns whether the inventory stack is at maximum condition.
---
--- @param self The InventoryStack instance.
--- @return True if the inventory stack is at maximum condition, false otherwise.
---
function InventoryStack:IsMaxCondition()
	return true
end

---
--- Returns whether the inventory stack has condition.
---
--- @param self The InventoryStack instance.
--- @return False, as the inventory stack has no condition.
---
function InventoryStack:IsCondition()
	return false
end

---
--- Returns the condition percentage of the inventory stack.
---
--- This function always returns 100, as the inventory stack has no condition.
---
--- @param self The InventoryStack instance.
--- @return The condition percentage of the inventory stack, which is always 100.
---
function InventoryStack:GetConditionPercent()
	return 100
end

---
--- Returns whether the inventory stack has condition.
---
--- This function always returns false, as the inventory stack has no condition.
---
--- @param self The InventoryStack instance.
--- @return False, as the inventory stack has no condition.
---
function InventoryStack:HasCondition()
	return false
end

---
--- Merges the contents of the current InventoryStack with the contents of another InventoryStack.
---
--- @param self The InventoryStack instance.
--- @param otherItem The InventoryStack to merge with.
--- @param amount The amount to merge, or nil to merge the full amount of the other InventoryStack.
--- @return True if the other InventoryStack was fully merged into the current InventoryStack, false otherwise.
---
function InventoryStack:MergeStack(otherItem, amount)
	assert(otherItem.class == self.class)
	amount = amount or otherItem.Amount
	local to_add = Min(amount, otherItem.Amount, self.MaxStacks - self.Amount)
	self.Amount = self.Amount + to_add
	otherItem.Amount = otherItem.Amount - to_add
	return otherItem.Amount <= 0
end

---
--- Splits the contents of the current InventoryStack into two separate stacks.
---
--- @param self The InventoryStack instance.
--- @param newStackAmount The amount of items to move to the new stack.
--- @param splitIfEqual Whether to split the stack even if the new stack amount is equal to the current stack amount.
--- @return The new InventoryStack created from the split, or nil if the split was not possible.
---
function InventoryStack:SplitStack(newStackAmount, splitIfEqual)
	if newStackAmount < 0 then return end
	if not splitIfEqual and newStackAmount >= self.Amount or 
		splitIfEqual and newStackAmount > self.Amount then return end
	
	local newItem = PlaceInventoryItem(self.class)
	if not newItem then return end
	self.Amount = self.Amount - newStackAmount
	newItem.Amount = newStackAmount
	
	return newItem
end

-- CompositeDef code
DefineClass.InventoryItemCompositeDef = {
	__parents = { "CompositeDef", "MsgActorReactionsPreset" },
	
	-- Composite def
	ObjectBaseClass = "InventoryItem",
	ComponentClass = false,
	
	-- Preset
	EditorMenubarName = "Inventory Item Editor",
	EditorIcon = "CommonAssets/UI/Icons/alcohol beverage bottle drink glass wine.png",
	EditorMenubar = "Characters",
	EditorShortcut = "Ctrl-Alt-Y",
	FilterClass = "InventoryFilter",
	GlobalMap = "InventoryItemDefs",
	Documentation = "Creates a new inventory item preset.",
	
	-- 'true' is much faster, but it doesn't call property setters & clears default properties upon saving
	StoreAsTable = false,
	-- Serialize props as an array => {key, value, key value}
	store_as_obj_prop_list = true
}

DefineModItemCompositeObject("InventoryItemCompositeDef", {
	EditorName = "Inventory item",
	EditorSubmenu = "Item",
	TestDescription = "Places the item inside the inventory of the selected merc."
})

if config.Mods then 
	function ModItemInventoryItemCompositeDef:TestModItem(ged)
		ModItemCompositeObject.TestModItem(self, ged)
		if IsKindOf(SelectedObj, "UnitInventory") then
			UIPlaceInInventory(nil, self)
		else
			ModLog(T(770217791797, "Cannot add the item as no merc is selected."))
		end
	end
end

--- Returns the DPS (damage per second) of the inventory item.
---
--- This method is only applicable for inventory items of the "Firearm" group. For other item groups, this method will return `nil`.
---
--- @return number|nil The DPS of the inventory item, or `nil` if the item is not a firearm.
InventoryItemCompositeDef.GetDPS = function(self) 
	if self.group == "Firearm" then
		return FirearmProperties.GetDPS(self)
	end
end

local TransformedItemIds = {
	CrocodileJawsInventoryItem = "CrocodileJaws",
}

--- Transforms an item ID to handle class name collisions and IDs starting with numbers.
---
--- This function is used to transform item IDs before creating new inventory items.
---
--- @param item_id string The original item ID.
--- @return string The transformed item ID.
function TransformItemId(item_id) 
	if not item_id then return item_id end

	-- Handle ids starting with numbers (ex. "9mm_Basic" => "_9mm_Basic")
	local id = item_id
	if string.match(id , "^%d") then
		id = "_" .. id 
	end
	
	-- Handle class name collisions
	if TransformedItemIds[id] then
		id = TransformedItemIds[id]
		print("Class name Collision resolved (PlaceItem):", id)
	elseif g_Classes[id .. "InventoryItem"] then -- ..InventoryItem
		id = id .. "InventoryItem"
		print("Class name Collision resolved (PlaceItem):", id)
	end
	
	return id
end

---
--- Verifies if the given actor is compatible with the inventory item composite definition.
---
--- @param event string The event that triggered the reaction.
--- @param reaction string The reaction to be verified.
--- @param actor any The actor to be verified.
--- @return boolean True if the actor is compatible with the inventory item composite definition, false otherwise.
---
function InventoryItemCompositeDef:VerifyReaction(event, reaction, actor, ...)
	if IsKindOf(actor, self.class) then
		return true
	end
	if IsKindOfClasses(actor, "Unit", "UnitData") then
		local equipped
		actor:ForEachItemInSlot(self.Slot, actor.class, function()
			equipped = true
		end)
		return equipped
	end
end

---
--- Retrieves the reaction actors for the given event and reaction.
---
--- @param event string The event that triggered the reaction.
--- @param reaction string The reaction to be verified.
--- @param ... any Additional arguments passed to the reaction.
--- @return table The list of reaction actors.
---
function InventoryItemCompositeDef:GetReactionActors(event, reaction, ...)
	return ZuluReactionGetReactionActors_Light(event, reaction, ...)
end


-- Overwrite of the old PlaceInventoryItem
---
--- Places an inventory item in the game world.
---
--- @param item_id string The ID of the inventory item to be placed.
--- @param instance table The instance data of the inventory item.
--- @param ... any Additional arguments to be passed to the inventory item's constructor.
--- @return InventoryItem The placed inventory item object.
---
function PlaceInventoryItem(item_id, instance, ...)
	local id = TransformItemId(item_id)
	
	local class = g_Classes[id]
	
	-- Fallback
	if not class then 
		printf("once", "InventoryItem class %s not found, replacing with MissingItem", id)
		return PlaceInventoryItem("MissingItem", instance, ...) 
	end
	
	local obj
	if InventoryItemCompositeDef.store_as_obj_prop_list then
		InventoryItem.DetachIdInitialization("PlaceInventoryItem")
		obj = class:new({}, ...)
		InventoryItem.AttachIdInitialization("PlaceInventoryItem")
		SetObjPropertyList(obj, instance)
		if not obj.id then -- Shouldn't happen (outside of Unarmed weapon creation on clear) but better than having items with no ids
			obj:InitializeItemId()
		end
		
		if next(obj.applied_modifiers) then
			obj:ApplyModifiersList(obj.applied_modifiers)
		end
		
		-- old save compat
		if IsKindOf(obj, "BaseWeapon") and obj.subweapons then
			for i, w in pairs(obj.subweapons) do
				if not w.parent_weapon then
					w.parent_weapon = obj
				end
			end
		end
	else
		obj = class:new(instance, ...)
	end
	
	return obj
end
-- end of CompositeDef code

---
--- Converts the current InventoryItem object to a Lua code string that can be used to place the item in the game world.
---
--- @param indent string The indentation to use for the generated Lua code.
--- @param pstr table An optional table to append the generated Lua code to.
--- @param GetPropFunc function An optional function to use for getting the properties of the InventoryItem object.
--- @return string The generated Lua code to place the InventoryItem object.
---
function InventoryItem:__toluacode(indent, pstr, GetPropFunc)
	if not pstr then
		local props = self:SavePropsToLuaCode(indent, GetPropFunc)
		props = props or "nil"
		return string.format("PlaceInventoryItem('%s', %s)", self.class, props)
	end
	pstr:appendf("PlaceInventoryItem('%s', ", self.class)
	if not self:SavePropsToLuaCode(indent, GetPropFunc, pstr) then
		pstr:append("nil")
	end
	return pstr:append(")")	
end

---
--- Displays the UI for the item's slot, typically shown in the bottom right of the item's icon.
---
function InventoryItem:GetItemSlotUI()-- bottom right text

end

---
--- Returns the condition text for the InventoryItem.
---
--- @return string The condition text for the InventoryItem.
---
function InventoryItem:GetConditionText()
	return T{686202559556, "<percent(condPercent)>", condPercent = self.Condition}
end

---
--- Displays the UI for the item's status, typically shown in the center of the item's icon.
---
function InventoryItem:GetItemStatusUI()-- centered text

end

---
--- Returns the appropriate icon for the InventoryItem based on its type.
---
--- @return string The icon path for the InventoryItem.
---
function InventoryItem:GetItemUIIcon()--
	local icon
	if self.Icon~="" then
		icon = self.Icon 
	else--placeholders
		if self:IsKindOfClasses("Firearm","MeleeWeapon") then
			icon = (self:IsLargeItem() and "UI/Icons/Weapons/weapon_placeholder.tga" or "UI/Icons/Weapons/pistol_placeholder.tga")
		elseif self:IsKindOfClasses("Armor") then	
			icon = "UI/Icons/Items/vest_placeholder.tga"
		else
			icon = "UI/Icons/Items/medkit_placeholder.tga"
		end				
	end
	return icon
end

---
--- Checks if the InventoryItem is a weapon.
---
--- @return boolean True if the InventoryItem is a weapon, false otherwise.
---
function InventoryItem:IsWeapon() 
  return IsKindOfClasses(self, "Firearm","MeleeWeapon","HeavyWeapon")
end	

---
--- Returns the rollover title for the InventoryItem.
---
--- @return string The rollover title for the InventoryItem.
---
function InventoryItem:GetRolloverTitle()
	assert(self.DisplayName)
	return self:GetColoredName()
end	

---
--- Returns the rollover text for the InventoryItem.
---
--- If the InventoryItem has a non-empty Description, it is returned.
--- Otherwise, if the InventoryItem has a non-empty DisplayName, it is returned.
--- If both Description and DisplayName are empty, an empty string is returned.
---
--- @return string The rollover text for the InventoryItem.
---
function InventoryItem:GetRollover()
	if (self.Description or "") ~= "" then
		return self.Description
	end
	if (self.DisplayName or "") ~= "" then
		return self.DisplayName
	end

	return ""
end	

---
--- Returns the rollover hint for the InventoryItem.
---
--- The rollover hint is constructed by concatenating the AdditionalHint property of the InventoryItem, if it exists, into a single string.
---
--- @return string The rollover hint for the InventoryItem.
---
function InventoryItem:GetRolloverHint()
	local hint = {} 
	hint[#hint+1] = self.AdditionalHint or ""
	return table.concat(hint, "\n")
end	

---
--- Returns the rollover hint for the InventoryItem, including the condition keyword.
---
--- The rollover hint is constructed by concatenating the AdditionalHint property of the InventoryItem, if it exists, and the condition keyword, separated by a newline.
---
--- @return string The rollover hint for the InventoryItem, including the condition keyword.
---
function InventoryItem:GetRolloverHintWithCondition()
	local condition = self:GetConditionKeyword()
	if self.AdditionalHint and condition~="" then
		return self.AdditionalHint.."\n"..condition
	end
	return (self.AdditionalHint or "")..condition
end	

---
--- Returns the condition keyword for the InventoryItem, including the condition percentage.
---
--- The condition keyword is constructed by calling `GetConditionKeywordNoPrefix()` and then formatting the result with the condition percentage.
---
--- @return string The condition keyword for the InventoryItem, including the condition percentage.
---
function InventoryItem:GetConditionKeyword()
	local text = self:GetConditionKeywordNoPrefix()
	return T{186484098339, "Condition: <keyword> (<percent(condPercent)>)",  keyword = text, condPercent = self.Condition}
end

---
--- Returns the condition keyword for the InventoryItem, without the "Condition: " prefix.
---
--- The condition keyword is constructed based on the condition percentage of the InventoryItem. The keyword and color are determined by the condition percentage ranges defined in the Presets.ConstDef.Weapons table.
---
--- @return string The condition keyword for the InventoryItem, without the "Condition: " prefix.
---
function InventoryItem:GetConditionKeywordNoPrefix()
	if not self.Condition then 
		return "" 
	end
	
	local presets = Presets.ConstDef.Weapons
	local color --AP_Main_SmallRed
	local keyword = ""
	local conditionPercent = self:GetConditionPercent()
	
	if conditionPercent>=const.Weapons.ItemConditionExcellent then
		color = "item_green"
		keyword =  T(486989771291, "Excellent")
	elseif conditionPercent>=const.Weapons.ItemConditionUsed then
		color = "item_green"
		keyword =  T(299810656374, "Used")
	elseif conditionPercent>=const.Weapons.ItemConditionNeedsRepair then
		color = "red"
		keyword = T(567857971439, "Needs Repair")
	elseif conditionPercent>=const.Weapons.ItemConditionPoor then
		color = "red"
		keyword = T(939310080350, "Poor")
	else--if conditionPercent>=presets.ItemConditionBroken.name then
		color = "red"
		keyword =  T(968409848233, "Broken")
	end
	return T{997078176629, "<clr><keyword><closeclr>",clr = const.TagLookupTable[color],closeclr  = const.TagLookupTable["/"..color],  keyword = keyword}
end

---
--- Checks if the condition of an inventory item matches the specified condition type.
---
--- @param condition number The current condition of the inventory item.
--- @param maxCondition number The maximum condition of the inventory item.
--- @param condition_type string The condition type to check for.
--- @return boolean True if the condition matches the specified condition type, false otherwise.
---
function IsConditionType(condition, maxCondition, condition_type)
	local conditionPercent = MulDivRound(condition, 100, maxCondition)

	if conditionPercent>=const.Weapons.ItemConditionExcellent then
		return condition_type=="Excellent"
	elseif conditionPercent>=const.Weapons.ItemConditionUsed then
		return condition_type=="Used"
	elseif conditionPercent>=const.Weapons.ItemConditionNeedsRepair then
		return condition_type=="NeedRepair"
	elseif conditionPercent>=const.Weapons.ItemConditionPoor then
		return condition_type=="Poor"
	else--if conditionPercent>=const.Weapons.ItemConditionBroken then
		return condition_type=="Broken"
	end
end

---
--- Checks if the condition of an inventory item matches the specified condition type.
---
--- @param condition_type string The condition type to check for.
--- @return boolean True if the condition matches the specified condition type, false otherwise.
---
function InventoryItem:IsCondition(condition_type)
	local condition = self.Condition
	local maxCondition = self:GetMaxCondition()
	
	return IsConditionType(condition, maxCondition, condition_type)
end

---
--- Checks if the condition of the inventory item is at its maximum.
---
--- @param self InventoryItem The inventory item to check.
--- @return boolean True if the condition is at the maximum, false otherwise.
---
function InventoryItem:IsMaxCondition()
	return self.Condition >= self:GetMaxCondition()
end	

---
--- Returns the maximum condition of the inventory item.
---
--- @param self InventoryItem The inventory item to get the maximum condition for.
--- @return number The maximum condition of the inventory item.
---
function InventoryItem:GetMaxCondition()
	return InventoryItemDefs[self.class]:GetProperty("Condition")
end

---
--- Returns the condition of the inventory item as a percentage of its maximum condition.
---
--- @param self InventoryItem The inventory item to get the condition percentage for.
--- @return number The condition of the inventory item as a percentage of its maximum condition.
---
function InventoryItem:GetConditionPercent()
	return MulDivRound(self.Condition, 100, self:GetMaxCondition())
end

---
--- Saves the inventory item to Lua code.
---
--- @param self InventoryItem The inventory item to save.
--- @param indent string The indentation to use for the Lua code.
--- @param pstr string (optional) A string buffer to append the Lua code to.
--- @param GetPropFunc function (optional) A function to get the property value for the inventory item.
--- @param pos number The position of the inventory item.
--- @return string The Lua code for the inventory item.
---
function InventoryItem:SaveToLuaCode(indent, pstr, GetPropFunc, pos)
	if not pstr then
		local props = self:SavePropsToLuaCode(indent, GetPropFunc)
		props = props or "nil"
		return string.format("%d, PlaceInventoryItem('%s', %s)", pos, self.class, props)
	else
		pstr:append(tostring(pos)..", " )
		pstr:appendf("PlaceInventoryItem('%s', ", self.class)
		if not self:SavePropsToLuaCode(indent, GetPropFunc, pstr) then
			pstr:append("nil")
		end
		pstr:append(")")
	end
end

---
--- Registers the reactions associated with the inventory item to the given owner.
---
--- @param self InventoryItem The inventory item to register the reactions for.
--- @param owner UnitBase The owner to register the reactions with. If not provided, the owner will be resolved from the inventory item's owner.
---
function InventoryItem:RegisterReactions(owner)
	owner = owner or self.owner and ZuluReactionResolveUnitActorObj(self.owner)
	if owner then
		owner:AddReactions(self, self.unit_reactions)
	end
end

---
--- Unregisters the reactions associated with the inventory item from the given owner.
---
--- @param self InventoryItem The inventory item to unregister the reactions for.
--- @param owner UnitBase The owner to unregister the reactions from. If not provided, the owner will be resolved from the inventory item's owner.
---
function InventoryItem:UnregisterReactions(owner)
	owner = owner or self.owner and ZuluReactionResolveUnitActorObj(self.owner)
	if owner then
		owner:RemoveReactions(self)
	end
end

---
--- Registers the reactions associated with the inventory item when it is added to the unit's inventory.
---
--- @param self InventoryItem The inventory item being added.
--- @param u UnitBase The unit the inventory item is being added to.
--- @param slot string The inventory slot the item is being added to.
--- @param pos number The position of the inventory item.
--- @param item InventoryItem The inventory item being added.
---
function InventoryItem:OnAdd(u, slot, pos, item)
	if IsKindOf(u, "UnitBase") and slot ~= "SetpieceWeapon" then
		self:RegisterReactions(u)
		self:OnItemGained(u, slot)
	end
end

---
--- Unregisters the reactions associated with the inventory item when it is removed from the unit's inventory.
---
--- @param self InventoryItem The inventory item being removed.
--- @param u UnitBase The unit the inventory item is being removed from.
--- @param slot string The inventory slot the item is being removed from.
---
function InventoryItem:OnRemove(u, slot) 
	if IsKindOf(u, "UnitBase") and slot ~= "SetpieceWeapon" then
		self:UnregisterReactions(u)
		self:OnItemLost(u, slot)
	end
end

DefineClass.InventoryFilter = {
	__parents = {"GedFilter"},
	properties = {
		{ id = "CanAppearInShop", editor = "choice", default = "don't care", items = { true, false, "don't care" }, },
		{ id = "Caliber", editor = "choice", default = "", items = PresetGroupCombo("Caliber", "Default"), },
		{ id = "ItemClass", editor = "choice", default = "", items = ClassDescendantsCombo("InventoryItem"), },
	}
}

---
--- Filters an inventory item based on the specified criteria.
---
--- @param self InventoryFilter The inventory filter object.
--- @param preset InventoryItem The inventory item to be filtered.
--- @return boolean True if the inventory item passes the filter, false otherwise.
---
function InventoryFilter:FilterObject(preset)
	if self.CanAppearInShop ~= "don't care" and preset:GetProperty("CanAppearInShop") ~= self.CanAppearInShop then
		return false
	end
	if self.Caliber ~= "" then
		if not (preset:HasMember("Caliber") and string.find(preset.Caliber or "", self.Caliber)) then
			return false
		end
	end
	if self.ItemClass ~= "" then
		local class = preset:HasMember("object_class") and g_Classes[preset.object_class]
		if not IsKindOf(class, self.ItemClass) then
			return false
		end
	end
	return true
end

DefineClass.InventorySlot ={
	__parents = { "PropertyObject"},	
}

---
--- Converts a table of inventory slot items to the new format for savegame compatibility.
---
--- This function is used to convert the old format of inventory slots, where the keys were the items and the values were the positions, to the new format where the slots are stored as a list of alternating positions and items.
---
--- @param self InventorySlot The inventory slot object.
--- @param props table The properties of the inventory slot.
--- @return table The inventory slot in the new format.
---
function InventorySlot:__fromluacode(props)	
	local slot = self:new(props)
	if not next(slot) then return slot end		
	-- convert to new format for savegame compatibility after inventory structure is changed and remove when no need of ald savegames in bugreports(22.1.2021)    
	for item, pos in pairs(slot) do	
		if type(item)~="number" then
			local idx = #slot + 1
			for i=1, #slot, 2 do
				local cpos = slot[i]
				if pos<=cpos then 
					idx = i
					break
				end
			end
			table.insert(slot,idx,   pos)
			table.insert(slot,idx+1, item)
		end
	end		
	return slot
end

---
--- Converts an InventorySlot object to Lua code.
---
--- This function is used to generate Lua code that can be used to recreate an InventorySlot object.
---
--- @param self InventorySlot The InventorySlot object to convert to Lua code.
--- @param indent string The indentation to use for the generated Lua code.
--- @param pstr string (optional) A string to append the generated Lua code to.
--- @param GetPropFunc function (optional) A function to get the property value of an object.
--- @return string|table The generated Lua code or the modified pstr table.
---
function InventorySlot:__toluacode(indent, pstr, GetPropFunc)
	self:GenerateLocalizationContext(self)
	if not pstr then
		local items = { }
		for i=1,#self, 2 do
			local pos, item = self[i], self[i+1]
			local item_code = item:SaveToLuaCode(indent, false, GetPropFunc, pos)
			table.insert(items, item_code)
		end
		
		return string.format("PlaceObj('InventorySlot', {%s})", table.concat(items, ", "))
	else
		pstr:append("PlaceObj('InventorySlot', {")
		for i=1,#self, 2 do
			local pos, item = self[i], self[i+1]
			item:SaveToLuaCode(indent, pstr, GetPropFunc, pos)
			if i ~= #self then
				pstr:append(", ")
			end
		end
		pstr:append("})")
		return pstr
	end
end

--[[ 
	inventory_slots = {
       -- { slot_name = "<slot_name>", width = 2, height = 1, base_class = "Weapon", enabled = false },
    }, -- static class data
	
	["<slot_name>"] = {
        [<item instance>] = point_pack(left, top), -- see point_pack/unpack functions
        ...
    } -- instance data created on Init from inventory_slots
--]]
DefineClass.Inventory = {
	__parents = { "PropertyObject", "InitDone" },	

	inventory_slots = {
       -- { slot_name = "<slot_name>", width = 2, height = 1, base_class = "Weapon", enabled = false },
    }, -- static class data	
}	

function OnMsg.ClassesGenerate(classdefs)
	for classname, classdef in pairs(classdefs) do
		if classdef.inventory_slots then
			classdef.properties = classdef.properties or {}
			for _,slot_data in ipairs( classdef.inventory_slots ) do
				table.insert(classdef.properties, 
				 { id = slot_data.slot_name, editor = "nested_obj", default = false, base_class = "InventorySlot", read_only = slot_data.read_only,
					dont_save = slot_data.dont_save })
				 classdef.inventory_slots[slot_data.slot_name] = slot_data
			end	 
		end
	end
end

--- Initializes the inventory slots for the Inventory object.
-- This function is called during the initialization of the Inventory object.
-- It creates a new InventorySlot object for each slot defined in the `inventory_slots` table,
-- and assigns it to the corresponding slot name property of the Inventory object.
-- @function Inventory:Init
-- @return nil
function Inventory:Init()
	for _, slot_data in ipairs(self.inventory_slots) do
		local slot_name = slot_data.slot_name
		self[slot_name] = rawget(self, slot_name) or InventorySlot:new()
	end	
end

--- Returns the maximum number of tiles that can fit in the specified inventory slot.
-- @param slot_name (string) The name of the inventory slot.
-- @return (number) The maximum number of tiles that can fit in the specified inventory slot.
function Inventory:GetMaxTilesInSlot(slot_name)
	local slot_data = self:GetSlotData(slot_name)	
	return slot_data.width*slot_data.height
end

---
--- Iterates over all items in the inventory and calls the provided function for each item that matches the specified base class.
--- @param base_class string|nil The base class to filter the items by. If nil, the function will be called for all items.
--- @param fn function The function to call for each matching item. The function will be called with the following arguments:
---   - item: the item object
---   - slot_name: the name of the slot the item is in
---   - ... any additional arguments passed to ForEachItem
--- @param ... any additional arguments to pass to the provided function
--- @return string "break" if the provided function returned "break", nil otherwise
---
function Inventory:ForEachItem(base_class, fn, ...)
	for _, slot_data in ipairs(self.inventory_slots) do
		if self:ForEachItemInSlot(slot_data.slot_name, base_class, fn, ...) == "break" then
			return "break"
		end
	end
end

-- Does NOT override its inlined in ForEachItem... and GetItemInSlot functions 
--- Checks if the given item is valid for the specified inventory slot.
-- @param item table The item to check.
-- @param slot_name string The name of the inventory slot.
-- @param base_class string|nil The base class to check the item against. If nil, the slot's base class is used.
-- @return boolean True if the item is valid for the slot, false otherwise.
function Inventory:CheckClass(item, slot_name, base_class)
	local slot_data = self:GetSlotData(slot_name)
	if slot_data.check_slot_name and item.Slot ~= slot_name then
		return false
	end
	local base_class = base_class or slot_data.base_class
	if base_class and not item:IsKindOfClasses(base_class) then
		return false
	end
	return true 
end

---
--- Checks if the inventory contains an item of the specified class.
--- @param class string|nil The class of the item to search for. If nil, the function will return true if the inventory is not empty.
--- @return boolean True if the inventory contains an item of the specified class, false otherwise.
---
function Inventory:HasItem(class)
	if class then
		for _, slot_data in ipairs(self.inventory_slots) do
			local items = self[slot_data.slot_name]
			for i = 2, items and #items or 0, 2 do
				if items[i].class == class then
					return true
				end
			end
		end
	else
		for _, slot_data in ipairs(self.inventory_slots) do
			local items = self[slot_data.slot_name]
			if items and #items > 0 then
				return true
			end
		end
	end
end

---
--- Checks if the inventory contains the specified item in the given slot.
--- @param slot_name string The name of the inventory slot to search.
--- @param search_item table The item to search for.
--- @return boolean True if the item is found in the slot, false otherwise.
---
function Inventory:HasItemInSlot(slot_name, search_item)
	local items = self[slot_name]
	if items and search_item then
		for i = 2, #items, 2 do
			if items[i] == search_item then
				return true
			end	
		end
	end
	return false
end

---
--- Iterates over all items in the inventory and calls the provided function for each item that matches the specified class.
--- @param item_class string The class of the items to iterate over.
--- @param fn function The function to call for each matching item. The function should have the following signature: `function(item, slot_name, ...)`
--- @param ... any Additional arguments to pass to the provided function.
--- @return string "break" if the provided function returns "break", otherwise nil.
---
function Inventory:ForEachItemDef(item_class, fn, ...)
	for _, slot_data in ipairs(self.inventory_slots) do
		local slot_name = slot_data.slot_name
		local items = self[slot_data.slot_name]
		for i = (items and #items or 0), 1, -2 do
			if items[i].class == item_class then
				if fn(items[i], slot_name, ...) == "break" then
					return "break"
				end	
			end
		end
	end
end

---
--- Checks if the specified inventory slot is empty.
--- @param slot_name string The name of the inventory slot to check.
--- @return boolean True if the slot is empty, false otherwise.
---
function Inventory:IsEmpty(slot_name)
	local items = self[slot_name]
	return not items or #items == 0
end

--  ForEachItemInSlot(slot_name, [base_class], function(item, slot_name, left, top, ...) end, ...)
---
--- Iterates over all items in the specified inventory slot and calls the provided function for each item that matches the specified base class.
--- @param slot_name string The name of the inventory slot to iterate over.
--- @param base_class string|function The base class of the items to iterate over. If a function is provided, it will be used to filter the items instead.
--- @param fn function The function to call for each matching item. The function should have the following signature: `function(item, slot_name, left, top, ...)`
--- @param ... any Additional arguments to pass to the provided function.
--- @return string "break" if the provided function returns "break", otherwise nil.
---
function Inventory:ForEachItemInSlot(slot_name, base_class, fn, ...)
	local items = self[slot_name]
	if not items or #items == 0 then
		return
	end
	if not base_class then
		for i = #items, 1, -2 do
			local left, top = point_unpack(items[i-1])
			if fn(items[i], slot_name, left, top, ...) == "break" then
				return "break"
			end
		end
	elseif type(base_class) == "function" then
		local arg1 = fn
		fn = base_class
		for i = #items, 1, -2 do
			local left, top = point_unpack(items[i-1])
			if fn(items[i], slot_name, left, top, arg1, ...) == "break" then
				return "break"
			end
		end
	else
		for i = #items, 1, -2 do
			if IsKindOfClasses(items[i], base_class) then
				local left, top = point_unpack(items[i-1])
				if fn(items[i], slot_name, left, top, ...) == "break" then
					return "break"
				end
			end
		end
	end
end

--- Finds an item in the specified inventory slot that matches the provided function.
---
--- @param slot_name string The name of the inventory slot to search.
--- @param func function The function to call for each item in the slot. The function should return a truthy value if the item matches the search criteria.
--- @param ... any Additional arguments to pass to the provided function.
--- @return any The first item that matches the provided function, or nil if no match is found.
function Inventory:FindItemInSlot(slot_name, func, ...)
	local items = self[slot_name]
	for i = 2, items and #items or 0, 2 do
		local value = func(items[i], ...)
		if value then
			return value
		end
	end
end

--GetItem(base_class, [left, [top]])
--- Finds an item in the inventory that matches the provided base class and position.
---
--- @param base_class any The base class to match the item against.
--- @param left number The left position of the item.
--- @param top number The top position of the item.
--- @return any The first item that matches the provided base class and position, or false if no match is found.
--- @return number The left position of the matched item.
--- @return number The top position of the matched item.
function Inventory:GetItem(base_class, left, top)
	for _, slot_data in ipairs(self.inventory_slots) do
		local slot_name = slot_data.slot_name
		local item, ileft, itop = self:GetItemInSlot(slot_name, base_class, left, top)
		if item then 
			return item, ileft, itop
		end
	end
	return false
end

--- Gets all items in the inventory.
---
--- @return table An array of all items in the inventory.
function Inventory:GetItems()
	local items = {}
	self:ForEachItem(function(item, slot_name, left, top, items)
		items[#items+1] = item
	end, items)
	return items
end

--GetItemInSlot(slot_name, base_class, [left, [top]])
--- Gets an item in the specified inventory slot that matches the provided base class and position.
---
--- @param slot_name string The name of the inventory slot to search.
--- @param base_class any The base class to match the item against.
--- @param left number The left position of the item.
--- @param top number The top position of the item.
--- @return any The first item that matches the provided base class and position, or false if no match is found.
--- @return number The left position of the matched item.
--- @return number The top position of the matched item.
function Inventory:GetItemInSlot(slot_name, base_class, left, top)
	local items = self[slot_name]
	if not items or #items == 0 then
		return
	end
	local slot_data = self:GetSlotData(slot_name)
	local lbase_class = base_class or slot_data.base_class
	local lcheck_slot_name = slot_data.check_slot_name
	for i = 2, #items, 2 do
		local item = items[i]
		if (not lcheck_slot_name or item.Slot == slot_name) and item:IsKindOfClasses(lbase_class) then
			local ileft, itop = point_unpack(items[i-1])
			if left then
				if ileft <= left and (not top or itop <= top) and ileft + item:GetUIWidth() > left and (not top or itop + item:GetUIHeight() > top) then
					return item, ileft, itop
				end
			elseif top then
				if itop <= top and itop + item:GetUIHeight() > top then
					return item, ileft, itop
				end	
			else 
				return item, ileft, itop
			end
		end
	end
	return false
end

--- Gets the inventory slot that contains the specified item.
---
--- @param item any The item to search for.
--- @return string The name of the inventory slot that contains the item, or nil if the item is not found.
function Inventory:GetItemSlot(item)
	for _, slot_data in ipairs(self.inventory_slots) do
		if self:HasItemInSlot(slot_data.slot_name, item) then
			return slot_data.slot_name
		end
	end
end

--- Gets the position of the specified item in the inventory.
---
--- @param item any The item to search for.
--- @return number The left position of the item.
--- @return number The top position of the item.
function Inventory:GetItemPos(item)
	for _, slot_data in ipairs(self.inventory_slots) do
		local ileft, itop = self:GetItemPosInSlot(slot_data.slot_name, item)
		if ileft and itop then 
			return ileft, itop
		end
	end
end

--- Gets the position of the specified item in the specified inventory slot.
---
--- @param slot_name string The name of the inventory slot to search.
--- @param item any The item to search for.
--- @return number The left position of the item.
--- @return number The top position of the item.
function Inventory:GetItemPosInSlot(slot_name,item)
	local slot_items = self[slot_name]
	for i = 2, #slot_items, 2 do
		if slot_items[i] == item then
			return point_unpack(slot_items[i-1])
		end	
	end	
end

--- Gets the packed position of the specified item in the inventory.
---
--- @param item any The item to search for.
--- @return number The packed position of the item, or nil if the item is not found.
function Inventory:GetItemPackedPos(item)
	for i, slot_data in ipairs(self.inventory_slots) do
		local ileft, itop = self:GetItemPosInSlot(slot_data.slot_name, item)
		if ileft and itop then 
			return point_pack(ileft, itop, i)
		end
	end
end

--- Gets the item with the specified ID in the given inventory slot.
---
--- @param slot_name string The name of the inventory slot to search.
--- @param id any The ID of the item to search for.
--- @return any The item with the specified ID, or nil if not found.
--- @return number The packed position of the item, or nil if not found.
function Inventory:GetItemWithId(slot_name, id)
	local items = self[slot_name]
	for i = 2, #items, 2 do
		if items[i].id == id then
			return items[i], items[i-1] -- item, packed pos
		end
	end
end

--- Gets the item at the specified position in the given inventory slot.
---
--- This method is different from `GetItemInSlot` in that it will not return large items whose second part is in the slot.
---
--- @param slot_name string The name of the inventory slot to search.
--- @param left number The left position of the item.
--- @param top number The top position of the item.
--- @return any The item at the specified position, or `nil` if not found.
function Inventory:GetItemAtPos(slot_name, left, top)
	--ATTN: this is not equivalent to GetItemInSlot(nil, left, top)
	--the difference is that GetItemInSlot will return large items whos second part is in the slot
	--and this method wont
	local pos = point_pack(left, top)
	local items = self[slot_name]
	for i = 1, #items, 2 do
		if items[i] == pos then
			return items[i+1]
		end
	end
end

--- Gets the item at the specified packed position in the inventory.
---
--- @param value number The packed position of the item to retrieve.
--- @return any The item at the specified packed position, or `nil` if not found.
function Inventory:GetItemAtPackedPos(value)
	local x,y,z = point_unpack(value)
	local slot = z and self.inventory_slots[z]
	local item = slot and self:GetItemAtPos(slot.slot_name, x, y)
	return item
end

--- Counts the number of items in the specified inventory slot.
---
--- @param slot_name string The name of the inventory slot to count items in.
--- @return number The number of items in the specified inventory slot.
function Inventory:CountItemsInSlot(slot_name)
	local items = self[slot_name]
	return items and #items / 2 or 0
end

-- point_pack, reason = CanAddItem(slot_name, item, [left, top])
--- Checks if an item can be added to the specified inventory slot.
---
--- @param slot_name string The name of the inventory slot to check.
--- @param item table The item to add to the inventory.
--- @param left number The left position of the item.
--- @param top number The top position of the item.
--- @param local_changes boolean Whether the changes are being made locally.
--- @return number|boolean The packed position of the item if it can be added, or false if it cannot.
--- @return string The reason why the item cannot be added, or the string "current" if the item is already in the slot.
function Inventory:CanAddItem(slot_name, item, left, top, local_changes)
	local pos,reason

	if not self:CheckClass(item, slot_name) then
		return false, "different class"		
	end	
	-- if not given left and top find empty space
	reason = ""
	local stack = false
	if left and top then 
		-- check stack items
		local currentitem = self:GetItemInSlot(slot_name,false, left, top)
		if currentitem == item then
			if item:IsLargeItem() then
				--could be the other slot and it could be out of bounds
				if not self:IsEmptyPosition(slot_name, item, left, top, nil, local_changes) then
					return false, "full or smaller position"
				end
			end
			return point_pack(left, top), "current"
		end
		local is_current_stack = IsKindOf(currentitem, "InventoryStack")
		if is_current_stack and item.class == currentitem.class then 
			if (currentitem.Amount + item.Amount)>currentitem.MaxStacks then
				return false, "full stack"
			else
				reason = "stack items"
				stack = true
			end
		end
		-- chek if this pos in space is empty and big enough for the item
		if not stack and not self:IsEmptyPosition(slot_name, item, left, top, nil, local_changes) then
			return false, "full or smaller position"
		end
	else 
		left, top = self:FindEmptyPosition(slot_name, item, local_changes)
		if not left or not top then 
			return false, "inventory full"
		end
	end
	pos = point_pack(left, top)
	return pos, reason
end

--  point_pack, reason = AddItem(slot_name, item, [left, top])
---
--- Adds an item to the specified inventory slot.
---
--- @param slot_name string The name of the inventory slot to add the item to.
--- @param item table The item to be added.
--- @param left number The left position of the item.
--- @param top number The top position of the item.
--- @param local_execution boolean Whether the changes are being made locally.
--- @return number|boolean The packed position of the item if it can be added, or false if it cannot.
--- @return string The reason why the item cannot be added, or the string "current" if the item is already in the slot.
function Inventory:AddItem(slot_name, item, left, top, local_execution)	
	local pos, reason = self:CanAddItem(slot_name, item, left, top)
	if not pos then
		return false, reason
	end
	
	if reason == "current" then
		return pos, reason
	end	

	item.owner = false

	-- add in slot
	if reason == "stack items" then
		local currentitem = self:GetItemInSlot(slot_name, false, left, top)
		currentitem.Amount = currentitem.Amount + item.Amount
		self:RemoveItem(slot_name, item)
		DoneObject(item)
	else
		local slot_items = self[slot_name]
		local idx = #slot_items + 1
		for i=1, #slot_items, 2 do
			if pos <= slot_items[i] then
				idx = i
				break
			end
		end
		table.insert(slot_items,idx,   pos)
		table.insert(slot_items,idx+1, item)
		self[slot_name] = slot_items
	end

	if item.class == "Parts" then
		UpdateWeaponModificationPartsCounter()
	end
	--ObjModified(self)
	return pos, reason
end

---
--- Checks if the specified item can be removed from the inventory.
---
--- @param slot_name string The name of the inventory slot.
--- @param item table The item to be removed.
--- @return boolean True if the item can be removed, false otherwise.
function Inventory:CanRemoveItem(slot_name, item)
	return true
end

---
--- Removes an item from the specified inventory slot.
---
--- @param slot_name string The name of the inventory slot.
--- @param item table The item to be removed.
--- @param no_update boolean (optional) If true, the inventory object will not be marked as modified.
--- @return table,number The removed item and its position in the slot.
---
function Inventory:RemoveItem(slot_name, item, no_update)
	if not self:CanRemoveItem(slot_name, item) then
		return
	end
	local slot_items = self[slot_name]
	for i = (slot_items and #slot_items or 0), 2, -2 do
		if item == slot_items[i] then
			local pos = slot_items[i-1]
			table.remove(slot_items, i)
			table.remove(slot_items, i-1)
			if not no_update then
				ObjModified(self)
			end
			return item, pos
		end
	end
end

---
--- Clears the specified inventory slot.
---
--- @param slot_name string The name of the inventory slot to clear.
---
function Inventory:ClearSlot(slot_name)
	self[slot_name] = {}
	ObjModified(self)
end

---
--- Returns the index of the specified inventory slot.
---
--- @param slot_name string The name of the inventory slot.
--- @return number The index of the specified inventory slot.
function Inventory:GetSlotIdx(slot_name)
	return table.find(self.inventory_slots, "slot_name", slot_name)
end

---
--- Returns the slot data for the specified inventory slot.
---
--- @param slot_name string The name of the inventory slot.
--- @return table The slot data for the specified inventory slot.
---
function Inventory:GetSlotData(slot_name)
	return self.inventory_slots[slot_name]
end

---
--- Returns the dimensions of the specified inventory slot.
---
--- @param slot_name string The name of the inventory slot.
--- @return number width The width of the inventory slot.
--- @return number height The height of the inventory slot.
--- @return number last_row_width The width of the last row in the inventory slot.
---
function Inventory:GetSlotDataDim(slot_name)
	local slot_data = self:GetSlotData(slot_name)	
	local width = slot_data.width
	local height = slot_data.height
	local max_tiles = self:GetMaxTilesInSlot(slot_name)
	local last_row_width = width
	if width*height > max_tiles then
		local rem = max_tiles%width
		height = max_tiles/width + (rem==0 and 0 or 1)
		last_row_width = rem==0 and width or rem
	end
	return width, height, last_row_width
end

---
--- Checks if the specified position in the inventory slot is empty and available for placing an item.
---
--- @param slot_name string The name of the inventory slot.
--- @param item table The item to be placed.
--- @param left number The left coordinate of the position to check.
--- @param top number The top coordinate of the position to check.
--- @param ignore_item table An item to ignore when checking for intersections.
--- @param local_changes table Any local changes that should be considered when checking the position.
--- @return boolean true if the position is empty and available, false otherwise.
---
function Inventory:IsEmptyPosition(slot_name, item, left, top, ignore_item, local_changes)
	if left < 1 or top < 1 then
		return false
	end
	local width, height, last_row_width = self:GetSlotDataDim(slot_name)
	local iwidth = item:GetUIWidth()
	local iheight = item:GetUIHeight()
	if left+iwidth-1>width or top+iheight-1>height then
		return false
	end
	-- last row check
	if top+iheight-1==height and left+iwidth-1>last_row_width then
		return false
	end
	
	if local_changes and local_changes[xxhash(left, top)] then
		--presumably, a local change is blocking
		return false
	end
	
	--check for intersection with any item
	local ibox = box(left, top, left+iwidth-1, top+iheight-1)
	local res = self:ForEachItemInSlot(slot_name, function(slot_item, slot_name, item_left, item_top, ibox, item, ignore_item)
		if item ~= slot_item and slot_item ~= ignore_item then
			local intersection = IntersectRects(ibox, box(item_left, item_top,item_left+slot_item:GetUIWidth()-1,item_top+slot_item:GetUIHeight()-1))
			if intersection:IsValid() then
				return "break"
			end	
		end
	end, ibox, item, ignore_item)
	if res=="break" then
		return false
	end
	return true
end

---
--- Finds an empty position in the specified inventory slot to place an item.
---
--- @param slot_name string The name of the inventory slot.
--- @param item table The item to be placed.
--- @param local_changes table Any local changes that should be considered when checking the position.
--- @return number, number The left and top coordinates of the empty position, or nil if no empty position is found.
---
function Inventory:FindEmptyPosition(slot_name, item, local_changes)
	local slot_data = self:GetSlotData(slot_name)
	local space = {}
	--local rects = {}
	local width, height, last_row_width = self:GetSlotDataDim(slot_name)
	for i=1, width do
		space[i] = {}
	end
	local free_space = self:GetMaxTilesInSlot(slot_name)
	local fe = local_changes and local_changes.force_empty
	
	self:ForEachItemInSlot(slot_name, function(slot_item, slot_name, left, top, space) 
		local item_width = slot_item:GetUIWidth()
		local item_height = slot_item:GetUIHeight()
		for i=left, left+item_width-1 do
			for j=top, top+item_height-1 do
				if not fe or not fe[xxhash(i, j)] then
					space[i][j] = true
				else
					free_space = free_space + 1
				end
			end
		end	
		free_space = free_space - item_width * item_height
		--rects[#rects+1] = sizebox(left, top, item_width, item_height)
	end, space)
	
	-- mark space to rect size with full
	if last_row_width~=width then
		for i = last_row_width+1, width do
			space[i][height] =  true
		end
	end
	
	local iwidth = item:GetUIWidth()
	local iheight = item:GetUIHeight()
	
	if free_space < iwidth*iheight then
		return 
	end
	
--[[-- sort rects
	table.sort(rects, function(r1,r2)
		local y1,y2 = r1:miny(),r2.miny()
		if y1<y2 then return true end
		if y1==y2 then	
			local x1,x2 = r1:minx(),r2.minx()
			if x1<x2 then return true end
		end
	end)
--]]
	local x,y = 1,1
	local raw_width = width
	while x<=raw_width and y<=height and (x+iwidth-1)<=raw_width and (y+iheight-1)<=height do
		local full =  false
		for i=x, x+iwidth-1 do
			for j=y, y+iheight-1 do
				if not space[i] or space[i][j] or (local_changes and local_changes[xxhash(i, j)]) then
					full = true
					break
				end	
			end
			if full then
				break
			end	
		end
		if not full then
			return x,y
		end	
		x = x+1
		if x>raw_width or (x+iwidth-1)>raw_width then
			x = 1
			y = y+1
			if y == height then
				raw_width = last_row_width
			end
		end
	end
end
-- find empty position for more items at the same time
---
--- Fills empty positions in a slot of the inventory.
---
--- @param slot_name string The name of the slot to fill.
--- @return table, table, number The updated space table, the free amounts table, and the remaining free space.
function Inventory:FillEmptyPositions(slot_name)
	local slot_data = self:GetSlotData(slot_name)
	local width, height, last_row_width = self:GetSlotDataDim(slot_name)
	
	local 	space, free_amounts = {}, {}
	for i=1, width do
		space[i] = {}
	end
	local free_space = self:GetMaxTilesInSlot(slot_name)
	
	self:ForEachItemInSlot(slot_name, function(slot_item, slot_name, left, top, space) 
		local item_width = slot_item:GetUIWidth()
		local item_height = slot_item:GetUIHeight()
		local is_stack = IsKindOf(slot_item,"InventoryStack") 
		if is_stack and slot_item.MaxStacks - slot_item.Amount>0 then
			local tbl = free_amounts[slot_item.class] or {}
			tbl[#tbl+1] = {left = left, top = top, free_amount = slot_item.MaxStacks - slot_item.Amount }
			free_amounts[slot_item.class] = tbl
		end
		for i=left, left+item_width-1 do
			for j=top, top+item_height-1 do
				space[i][j] = true
			end
		end	
		free_space = free_space - item_width * item_height
	end, space)
		
	-- mark space to rect size with full
	if last_row_width~=width then
		for i = last_row_width+1, width do
			space[i][height] =  true
		end
	end
	return space, free_amounts, free_space
end

---
--- Finds empty positions in a slot of the inventory to place items.
---
--- @param slot_name string The name of the slot to find empty positions in.
--- @param items table A table of items to be placed in the slot.
--- @param space table The current space table for the slot.
--- @param free_amounts table The current free amounts table for the slot.
--- @return boolean, table, table Whether the items were successfully placed, the updated space table, and the updated free amounts table.
function Inventory:FindEmptyPositions(slot_name, items, space, free_amounts)
	local slot_data = self:GetSlotData(slot_name)
	local space = space
	local free_amounts = free_amounts
	local width, height, last_row_width = self:GetSlotDataDim(slot_name)
	
	if not next(space) then
		local free_space
		space, free_amounts, free_space  = self:FillEmptyPositions(slot_name)
		-- check for stacking
		--if free_space<=0 then
		--	return false,space
		--end
		local total_space = 0
		for i=1 , #items do
			local item =  items[i]
			local iwidth = item:GetUIWidth()
			local iheight = item:GetUIHeight()					
			total_space = total_space + iwidth*iheight
		end
--		if free_space < total_space then
--			return false,space
--		end
	end
	
	for i=1, #items do
		local item =  items[i]
		local iwidth = item:GetUIWidth()
		local iheight = item:GetUIHeight()
		local is_stack = IsKindOf(item,"InventoryStack") 
		local item_amount = is_stack and item.Amount or 1
		-- serach to stack
		if is_stack and free_amounts and free_amounts[item.class] then
			local tbl = free_amounts[item.class]
			for  j = #tbl, 1, -1 do
				local t = tbl[j]
				local to_add =   Min(t.free_amount,item_amount)
				item_amount = item_amount - to_add
				t.free_amount = t.free_amount - to_add
				if t.free_amount==0 then
					table.remove(tbl,j)
				end
			end	
			if item_amount==0 then	
				return true, space, free_amounts
			end
		end
		
		
		local x,y = 1,1
		local raw_width = width
		local placed = false
		while x<=raw_width and y<=height and (x+iwidth-1)<=raw_width and (y+iheight-1)<=height do
			local full =  false
			for i=x, x+iwidth-1 do
				for j=y, y+iheight-1 do
					if not space[i] or space[i][j] then
						full = true
						break
					end	
				end
				if full then
					break
				end	
			end
			if not full then				
				for i=x, x+iwidth-1 do
					for j=y, y+iheight-1 do
						space[x][y] = true
						placed = true
					end
				end
				break
			end	
			x = x+1
			if x>raw_width or (x+iwidth-1)>raw_width then
				x = 1
				y = y+1
				if y == height then
					raw_width = last_row_width
				end
			end
		end
		if not placed then 
			return false, space, free_amounts
		end
	end
	return true, space, free_amounts
end

---
--- Sorts an array of items, stacking items of the same class, removing empty stacks, and sorting the array by item class.
---
--- @param items table An array of items to sort.
--- @return table The sorted array of items.
function SortItemsArray(items)
	-- stack items
	for i = 1, #items do
		if IsKindOf(items[i], "InventoryStack") then
			for j = i+1, #items do
				if items[i].class == items[j].class then
					local transferAmount = Min(items[i].MaxStacks - items[i].Amount, items[j].Amount)
					items[i].Amount = items[i].Amount + transferAmount
					items[j].Amount = items[j].Amount - transferAmount
				end
			end
		end
	end
	
	-- remove empty stacks
	for i = #items, 1, -1 do
		if items[i].Amount and items[i].Amount <= 0 then
			local item = table.remove(items, i)
			DoneObject(item)
		end
	end
	
	-- sort
	table.sortby_field(items, "class")
	
	return items
end

-- repairing items

---
--- Gets the queue of items for a given sector operation.
---
--- @param sector_id string The ID of the sector.
--- @param operation_id string The ID of the operation.
--- @return table The queue of items for the specified operation.
function SectorOperationItems_GetItemsQueue(sector_id, operation_id)
	local queue = {}
	if IsCraftOperation(operation_id) then
		queue = GetCraftOperationQueueTable(gv_Sectors[sector_id], operation_id) or {}
	end
	return queue
end

-- backward compatibility
---
--- Gets the item from the given data.
---
--- @param data table The data containing the item information.
--- @return table|nil The item, or nil if the data is invalid.
function SectorOperationRepairItems_GetItemFromData(data)
	return data and (data.id and g_ItemIdToItem[data.id] or data[1])
end

---
--- Processes the next item in the repair queue for the given sector.
---
--- @param sector string The ID of the sector.
--- @param dont_progress boolean If true, the function will not progress the repair queue.
--- @return table|nil The next item in the repair queue, or nil if the queue is empty.
--- @return table|nil The data for the next item in the repair queue, or nil if the queue is empty.
function SectorOperationItemToRepair(sector, dont_progress)
	local queue = SectorOperationItems_GetItemsQueue(sector, "RepairItems") 
	if not next(queue) then		
		return 
	end	
	local data = queue[1]
	local item = SectorOperationRepairItems_GetItemFromData(data)
	local once = false
	if not dont_progress then
		NetUpdateHash("SectorOperationItemToRepair", Game and Game.CampaignTime, item and item.class, not not next(queue), item and item:IsMaxCondition(), item and item.id, item and item.Condition)
	end
	while not dont_progress and next(queue) and (not item or item:IsMaxCondition()) do
		--this func gets called by ui, but this part here changes the op state
		--use dont_progress to determine when we are in a sync context and it is ok to modify the state
		table.remove(queue,1)
		data = queue[1]
		item = SectorOperationRepairItems_GetItemFromData(data)
		if not once then
			RecalcOperationETAs(sector,"RepairItems")
			once = true
		end	
	end
	if once then
		InventoryUIRespawn()
	end
	gv_Sectors[sector].sector_repair_items_queued = queue
	return item, data
end

---
--- Gets all the items for the given sector and operation.
---
--- @param sector_id string The ID of the sector.
--- @param operation_id string The ID of the operation.
--- @return table The list of items for the given sector and operation.
function SectorOperationItems_GetAllItems(sector_id, operation_id)
	local sector = gv_Sectors[sector_id]
	local mercs = GetOperationProfessionals(sector_id, operation_id)
			
	if operation_id=="RepairItems" then
		if next(sector.sector_repair_items) then return sector.sector_repair_items end
		return SectorOperationFillItemsToRepair(sector_id, mercs)
	end
	if IsCraftOperationId(operation_id) then
		return SectorOperationFillItemsToCraft(sector_id, operation_id, mercs[1])
	end
end

---
--- Fills the most damaged items in the repair queue for the given sector.
---
--- @param sector_id string The ID of the sector.
--- @return table The list of items that are not in the repair queue.
--- @return table The list of items that are in the repair queue.
--- @return number The index of the last item in the repair queue.
function SectorOperationRepairItems_FillMostDamagedItems(sector_id)
	local all = table.icopy(gv_Sectors[sector_id].sector_repair_items)
	table.iappend(all, table.icopy(gv_Sectors[sector_id].sector_repair_items_queued))
	table.sortby(all,function(item) 
		local itm = SectorOperationRepairItems_GetItemFromData(item)
		return itm and itm.Condition or -1 
	end )	
	
	local width, idx = 0, 0
	local queued = {}
	local rem
	while width<9  and idx<#all do
		idx = idx+1
		local item = all[idx]
		local itm = SectorOperationRepairItems_GetItemFromData(item)
		local item_width = itm and itm:IsLargeItem() and 2 or 1
		width = width + item_width
		if width>9 then
			idx = idx-1			
			rem = 9-(width - item_width)
			break
		end
		queued[#queued+1] = item
	end	
		
	local tbl_all= {}	
	for i = idx+1, #all do
		local added = false
		if rem and rem>0 then
			local item = all[i]
			local itm = SectorOperationRepairItems_GetItemFromData(item)
			local item_width = itm and itm:IsLargeItem() and 2 or 1
			if item_width<=rem then
				queued[#queued+1] = item
				rem = rem - item_width
				added = true
			end
		end
		if not added then
			tbl_all[#tbl_all+1] = all[i]
		end
	end
	
	NetSyncEvent("ChangeSectorOperationItemsOrder",sector_id,"RepairItems", TableWithItemsToNet(tbl_all), TableWithItemsToNet(queued))
	return tbl_all, queued, idx
end

---
--- Updates the item lists in the Sector Operations UI dialog.
---
--- @param dlg table The Sector Operations UI dialog, or nil to use the default dialog.
---
function SectorOperation_ItemsUpdateItemLists(dlg)
	dlg = dlg or table.get(GetDialog("SectorOperationsUI"), "idBase", "idMain") --GetDialog("SectorOperationsUI").idBase.idMain
	if not dlg then return end
	local items_ctrl = dlg.idQueueList
	if not items_ctrl then return end
	items_ctrl:RespawnContent()
	items_ctrl:OnContextUpdate(items_ctrl:GetContext())
	local allitems_ctrl = dlg.idAllList
	allitems_ctrl:RespawnContent()
	allitems_ctrl:OnContextUpdate(allitems_ctrl:GetContext())
	local node = items_ctrl:ResolveId("node")
	node:OnContextUpdate(node:GetContext())
	local node = allitems_ctrl:ResolveId("node")
	node:OnContextUpdate(node:GetContext())
	ObjModified(items_ctrl)
	ObjModified(allitems_ctrl)
end

local priority_slots = {"Handheld A", "Handheld B", "Head", "Torso", "Legs"}
---
--- Finds and returns a list of items that need to be repaired in the given sector, prioritizing the player's equipped items, squad members' equipped items, and other items in the sector.
---
--- @param sector_id number The ID of the sector to find repair items for.
--- @param mercs table A table of mercenary units in the sector.
--- @param check_only boolean If true, the function will only check if there are any items that need repair, and not actually add them to the repair list.
--- @return boolean|table If check_only is true, returns true if there are items that need repair, false otherwise. If check_only is false, returns a table of items that need repair.
---
function SectorOperationFillItemsToRepair(sector_id, mercs, check_only)
	-- priority of mercs whose item will be repaired:
	--[[
		1. My personal equipped Weapons
		2. My personal Armor items
		3. My squadmates equipped Weapons
		4. My squadmates equipped Armor items
		5. Weapons in the bag of any merc (starting form first bag on down)
		6. Armor items in merc bags
		7. Other squad on sector - weapons
		8. Other squad on sector - armor
		9. Sector stash - weapons
		10. Sector stash - armor
	--]]
	-- remove queued items
	local queue = gv_Sectors[sector_id].sector_repair_items_queued
	if not check_only  then
		gv_Sectors[sector_id].sector_repair_items  = {}
	end 
	local all_to_repair = gv_Sectors[sector_id].sector_repair_items or {}
	local chek_only_var = {var_bool=false}
	--equipped weapons and armors 
	local act_mercs ={}
	for _, slot in ipairs(priority_slots) do
		for _,merc in ipairs(mercs) do
			act_mercs[merc.session_id] = true
			merc:ForEachItemInSlot(slot, "ItemWithCondition", function(item, slot_name, left, top, all_to_repair, chek_only_var)
				if item and not item:IsMaxCondition() and item.Repairable then
				   if check_only then
						chek_only_var.var_bool =  true
						return "break"
					end
					if not table.find(all_to_repair, "id", item.id) and not table.find(queue, "id", item.id) then
						table.insert(all_to_repair,{ unit = merc.session_id, id = item.id, slot = slot, pos_left = left, pos_top = top})
					end
				end
			end,all_to_repair,chek_only_var)	
		end
	end
	
	if chek_only_var.var_bool then
		return true
	end	

	local all_sector_mercs = GetPlayerSectorUnits(sector_id)	
	all_sector_mercs = table.ifilter(all_sector_mercs, function(idx,m) return m.Operation~="Traveling" and m.Operation~= "Arriving" end)
	--squadmates equipped weapons and armors 
	for _, slot in ipairs(priority_slots) do
		for _,merc in ipairs(mercs) do
			table.remove_value(all_sector_mercs, "session_id", merc.session_id)
			local squad = merc.Squad
			local units = gv_Squads[squad].units
			for _, unit_id in ipairs(units) do
				if not act_mercs[unit_id] then
					table.remove_value(all_sector_mercs, "session_id", unit_id)
					local unit = gv_UnitData[unit_id]
					unit:ForEachItemInSlot(slot, "ItemWithCondition", function(item, slot_name, left, top, all_to_repair, chek_only_var)
						if item and not item:IsMaxCondition() and item.Repairable then
							if check_only then
								chek_only_var.var_bool =  true
								return "break"
							end
							if not table.find(all_to_repair, "id", item.id) and not table.find(queue, "id", item.id) then
								table.insert(all_to_repair,{ unit = unit_id,  id = item.id, slot = slot, pos_left = left, pos_top = top})
							end
						end
					end,all_to_repair,chek_only_var)
				end
			end
		end
	end
	
	if chek_only_var.var_bool then
		return true
	end	

	-- in inventory weapons than armors
	for _,merc in ipairs(mercs) do
		local squad = merc.Squad
		local units = gv_Squads[squad].units
		for _, unit_id in ipairs(units) do
			local unit = gv_UnitData[unit_id]
			local slot = GetContainerInventorySlotName(unit)
			unit:ForEachItemInSlot(slot, "ItemWithCondition", function(item, slot_name, left, top, all_to_repair, chek_only_var)
				if not item:IsMaxCondition() and item.Repairable and item:IsWeapon() then
					if check_only then 
						chek_only_var.var_bool =  true
						return "break" 
					end
					if not table.find(all_to_repair, "id", item.id) and not table.find(queue, "id", item.id) then
						table.insert(all_to_repair,{ unit = unit_id, id = item.id, slot = slot, pos_left = left, pos_top = top})
					end	
				end
			end, all_to_repair,chek_only_var)
		end
	end
	
	if chek_only_var.var_bool then
		return true
	end	
	
	for _,merc in ipairs(mercs) do
		local squad = merc.Squad
		local units = gv_Squads[squad].units
		for _, unit_id in ipairs(units) do
			local unit = gv_UnitData[unit_id]
			local slot = GetContainerInventorySlotName(unit)
			unit:ForEachItemInSlot(slot, "ItemWithCondition", function(item, slot_name, left, top,all_to_repair,chek_only_var)
				if not item:IsMaxCondition() and item.Repairable and not item:IsWeapon() then
					if check_only then 
						chek_only_var.var_bool =  true
						return "break" 
					end
					if not table.find(all_to_repair, "id", item.id) and not table.find(queue, "id", item.id)  then
						table.insert(all_to_repair,{ unit = unit_id, id = item.id, slot = slot, pos_left = left, pos_top = top})
					end
				end
			end,all_to_repair,chek_only_var)
		end
	end
	
	if chek_only_var.var_bool then
		return true
	end	
	
	-- mercs from other squads on sector equipped
	-- equipped
	for _, slot in ipairs(priority_slots) do
		for _,merc in ipairs(all_sector_mercs) do
			merc:ForEachItemInSlot(slot, "ItemWithCondition", function(item, slot_name, left, top, all_to_repair, chek_only_var)
				if item and not item:IsMaxCondition() and item.Repairable then
				   if check_only then
						chek_only_var.var_bool =  true
						return "break"
					end
					if not table.find(all_to_repair, "id", item.id) and not table.find(queue, "id", item.id) then
						table.insert(all_to_repair,{ unit = merc.session_id, id = item.id, slot = slot, pos_left = left, pos_top = top})
					end
				end
			end,all_to_repair,chek_only_var)	
		end
	end
	
	if chek_only_var.var_bool then
		return true
	end	
	
	-- other squads bags -  weapons
	for _,unit in ipairs(all_sector_mercs) do
		local slot = GetContainerInventorySlotName(unit)
		unit:ForEachItemInSlot(slot, "ItemWithCondition", function(item, slot_name, left, top,all_to_repair,chek_only_var)
			if not item:IsMaxCondition() and item.Repairable and item:IsWeapon() then
				if check_only then 
					chek_only_var.var_bool =  true
					return "break" 
				end
				if not table.find(all_to_repair, "id", item.id) and not table.find(queue, "id", item.id)  then
					table.insert(all_to_repair,{ unit = unit.session_id, id = item.id, slot = slot, pos_left = left, pos_top = top})
				end
			end
		end,all_to_repair,chek_only_var)
	end

	if chek_only_var.var_bool then
		return true
	end	
-- other squads bags -  armors
	for _,unit in ipairs(all_sector_mercs) do
		local slot = GetContainerInventorySlotName(unit)
		unit:ForEachItemInSlot(slot, "ItemWithCondition", function(item, slot_name, left, top,all_to_repair,chek_only_var)
			if not item:IsMaxCondition() and item.Repairable and not item:IsWeapon() then
				if check_only then 
					chek_only_var.var_bool =  true
					return "break" 
				end
				if not table.find(all_to_repair, "id", item.id) and not table.find(queue, "id", item.id)  then
					table.insert(all_to_repair,{ unit = unit.session_id, id = item.id, slot = slot, pos_left = left, pos_top = top})
				end
			end
		end,all_to_repair,chek_only_var)
	end

	if chek_only_var.var_bool then
		return true
	end	

	-- sector stash
	local stash = gv_Sectors[sector_id].sector_inventory or empty_table
	for cidx, container in ipairs(stash) do
		if container[2] then -- is opened
			local items = container[3] or empty_table
			for idx, item in ipairs(items) do			
				if not item:IsMaxCondition() and item.Repairable then
					if check_only then 
						chek_only_var.var_bool =  true
						break 
					end
					if not table.find(all_to_repair, "id", item.id) and not table.find(queue, "id", item.id)  then
						table.insert(all_to_repair,{ unit = "stash", id = item.id})
					end
				end	
			end
		end
	end

	if chek_only_var.var_bool then
		return true
	end
	
	if check_only then 
		return false
	end
	
	gv_Sectors[sector_id].sector_repair_items = all_to_repair
	return all_to_repair
end

---
--- Finds the item definition for the given item.
---
--- If the item has an `id` field, it returns the item definition from `SectorOperationRepairItems_GetItemFromData`.
--- Otherwise, it looks up the item definition in the `g_Classes` table using the `item_id` field.
---
--- @param item table The item to find the definition for.
--- @return table|nil The item definition, or `nil` if not found.
---
function SectorOperation_FindItemDef(item)
	-- repair item
	if item.id then
		return SectorOperationRepairItems_GetItemFromData(item)
	end	
	-- craft recipe item
	local item_id = item.item_id
	--for _,group in ipairs( Presets.InventoryItemCompositeDef) do
	--	for id, item_def in pairs( group) do
		--	if type(id)~="number" then
			--	if id==item_id then
					return type(item_id)=="string" and g_Classes[item_id]
			--	end	
			--end
		--end
	--end
end

if FirstLoad then
	g_RecipesCraftAmmo = false
	g_RecipesCraftExplosives =  false
end

---
--- Fills the list of items to craft for the given sector and operation.
---
--- This function calculates the required resources for the given craft operation and
--- populates the `g_Recipes<operation_id>` table with the list of items that can be crafted.
--- The list includes information about the recipe, the item to be crafted, the amount,
--- whether the recipe is enabled (based on available resources), and whether the recipe
--- is hidden (based on quest conditions and required crafter).
---
--- @param sector_id string The ID of the sector
--- @param operation_id string The ID of the craft operation
--- @param merc table The merc performing the craft operation
--- @return table The list of items that can be crafted
---
function SectorOperationFillItemsToCraft(sector_id, operation_id, merc)
	if not IsCraftOperationId(operation_id) then
		return
	end	
	local id = "g_Recipes"..operation_id

	if rawget(_G,id) then
		SectorOperationValidateItemsToCraft(sector_id, operation_id, merc )	
		return _G[id]
	end
	
	rawset(_G, id, {})	
	local res_items = SectorOperation_CalcCraftResources(sector_id, operation_id)
	local all_to_craft = _G[id] or {}
	local mercs = merc and gv_Squads[merc.Squad].units
	local checked_amount_cach = {}
	for recipe_id, recipe in pairs(CraftOperationsRecipes) do
		local is_ammocraft = recipe.group=="Ammo" and operation_id=="CraftAmmo" 
		local is_explosivescraft =  recipe.group=="Explosives" and operation_id=="CraftExplosives"
		
		if recipe.CraftOperationId==operation_id  or is_ammocraft or is_explosivescraft then
			local hidden = false
			if recipe.RequiredCrafter and merc and merc.session_id~=recipe.RequiredCrafter then
				hidden = true
			end
			local condition = not recipe.QuestConditions or EvalConditionList(recipe.QuestConditions)
			hidden = hidden or not condition


			local res = merc and SectorOperation_ValidateRecipeIngredientsAmount(mercs, recipe, res_items, checked_amount_cach)			local item = recipe.ResultItem.item
			local find_idx = table.find(all_to_craft, "recipe", recipe_id)
			if not find_idx then
				table.insert(all_to_craft,{ recipe = recipe_id, item_id = item, amount = recipe.ResultItem.amount, enabled = not not res,  hidden = hidden})
			else
				all_to_craft[find_idx].enabled = not not res
				all_to_craft[find_idx].hidden = hidden
			end
		end
	end
	
	table.sort(all_to_craft, function(a,b) 
		if not a or not b then return true end
		return a.enabled and not b.enabled 
	end)
	
	_G[id] = all_to_craft
	return all_to_craft
end

function OnMsg.InventoryChange(obj)
	return RepairItems_InventoryChange(obj)
end

function OnMsg.ItemAdded(obj)
	return RepairItems_InventoryChange(obj)
end

function OnMsg.ItemRemoved(obj,item, slot_name, pos)
	return RepairItems_InventoryChange(obj, "removed", item.id)
end

--[[function OnMsg.ItemDeleted(obj, item)
	DelayedCall(0,RepairItems_InventoryChange(obj, item))
end
--]]

-- remove items from queue when the units mvoe out fromthe sector
---
--- Removes repaired items from the repair queue for the given units.
---
--- @param units table An array of units or unit IDs.
--- @param synced boolean (optional) Whether the operation should be synchronized with other clients.
---
function RepairItems_RemoveRepairedItems(units, synced)
	local mercs = {}
	for j = #units, 1, -1 do
		local unit_id = units[j]
		local unit_data = type(unit_id)== "string" and gv_UnitData[unit_id] or unit_id
		table.insert(mercs, unit_data)
		local sector_id = unit_data:GetSector().Id
		local repair_all = gv_Sectors[sector_id].sector_repair_items
		local repair_queue = gv_Sectors[sector_id].sector_repair_items_queued	
		if not next(repair_all) and not next(repair_queue) then
			return
		end	
		for i = #repair_queue, 1, -1 do
			local items_data = repair_queue[i]
			local itm = SectorOperationRepairItems_GetItemFromData(items_data)
			if itm and unit_data.session_id==itm.owner then
				table.remove_value(repair_queue,"id", itm.id)
			end
		end		
		gv_Sectors[sector_id].sector_repair_items_queued = repair_queue
		gv_Sectors[sector_id].sector_repair_items = {}
		SectorOperationFillItemsToRepair(sector_id, mercs)
		if not synced then
			NetSyncEvent("ChangeSectorOperationItemsOrder",sector_id, "RepairItems", TableWithItemsToNet(gv_Sectors[sector_id].sector_repair_items), TableWithItemsToNet(repair_queue))
		end
	end	
end

---
--- Handles changes to the inventory of a unit, updating the repair queue accordingly.
---
--- @param obj table The unit whose inventory has changed.
--- @param removed boolean (optional) Whether an item was removed from the inventory.
--- @param item_id string (optional) The ID of the item that was removed.
---
function RepairItems_InventoryChange(obj, removed, item_id)
	if not (IsMerc(obj) and not obj:IsDead() and obj.Squad) then
		return 
	end
	local sector_id = gv_Squads[obj.Squad].CurrentSector 
	local repair_all = gv_Sectors[sector_id].sector_repair_items
	local repair_queue = gv_Sectors[sector_id].sector_repair_items_queued	
	
	if not next(repair_all) and not next(repair_queue) then
		return
	end	
	
	local mercs = GetPlayerSectorUnits(sector_id) --GetOperationProfessionals(sector_id, "RepairItems")
	if not next(mercs) then
		return
	end	
		
	for i = #repair_queue, 1, -1 do
		local items_data = repair_queue[i]
		local itm = SectorOperationRepairItems_GetItemFromData(items_data)
		if not itm then -- remove destroyed
			table.remove_value(repair_queue,"id", items_data.id)
		else
			local unit_session_id = items_data.unit
			if unit_session_id == "stash" or unit_session_id==obj.session_id then -- item from changed unit inventory
				local new_unit_session_id = (not removed or item_id~=itm.id) and itm.owner or false -- new item owner
				if not new_unit_session_id then
					if unit_session_id ~= "stash" then --moved to container
						items_data.unit = "stash"
						items_data.pos_left = false
						items_data.pos_top  = false
						items_data.slot     = false
					end
					--table.remove_value(repair_queue,"id", itm.id)					
				else
					local found = table.find(mercs, "session_id", new_unit_session_id) 
					local new_unit = gv_UnitData[new_unit_session_id]
					if not found then
						local sq = new_unit and new_unit.Squad
						local squads = table.map(mercs, "Squad")
						found = table.find(squads, sq)
					end
					if not found then
						table.remove_value(repair_queue,"id", itm.id)
					else
						local ps = new_unit:GetItemPackedPos(itm)
						if ps then
							local left, top, slot_idx = point_unpack(ps)
							items_data.pos_left = left
							items_data.pos_top  = top
							items_data.slot     = new_unit.inventory_slots[slot_idx].slot_name
						end
					end
				end	
			end	
		end	
	end	
	
	gv_Sectors[sector_id].sector_repair_items_queued = repair_queue
	gv_Sectors[sector_id].sector_repair_items = {}
	SectorOperationFillItemsToRepair(sector_id, mercs)	
	NetSyncEvent("ChangeSectorOperationItemsOrder",sector_id, "RepairItems", TableWithItemsToNet(gv_Sectors[sector_id].sector_repair_items), TableWithItemsToNet(repair_queue))
end

-- fill item _id after load
function OnMsg.PreLoadSessionData()
	for sector_id,sector in pairs(gv_Sectors) do
		for i = #(sector.sector_repair_items or empty_table),1,-1 do
			local items_data = sector.sector_repair_items[i]
			local unit   = items_data.unit
			local slot   = items_data.slot
			local pos_left = items_data.pos_left 
			local pos_top = items_data.pos_top
			local itm
			if unit=="stash" then
				for  _, container in ipairs(sector.sector_inventory) do
					if container[2] then
						itm = table.find_value(container[3],"id",items_data.id)
						if itm then 
							break
						end	
					end
				end
			else
				itm = gv_UnitData[unit]:GetItemAtPos(slot,pos_left, pos_top)			
			end
			if items_data.id and items_data[1] then
				items_data[1] = nil
			elseif not items_data.id and not itm then
				table.remove(sector.sector_repair_items, i)
			elseif not items_data.id and itm and items_data[1] then
				items_data.id = itm.id
				items_data[1] = nil
			elseif itm and items_data.id~=itm.id then 
				items_data.id = itm.id
				items_data[1] = nil
			end
		end
		for i = #(sector.sector_repair_items_queued or empty_table),1,-1 do
			local items_data = sector.sector_repair_items_queued[i]
			local unit   = items_data.unit
			local slot    = items_data.slot
			local pos_left = items_data.pos_left 
			local pos_top = items_data.pos_top		
			local itm
			if unit=="stash" then
				for  _, container in ipairs(sector.sector_inventory) do
					if container[2] then
						itm = table.find_value(container[3],"id",items_data.id)
						if itm then 
							break
						end	
					end
				end
			else
				itm = gv_UnitData[unit]:GetItemAtPos(slot,pos_left, pos_top)			
			end
		
			if items_data.id and items_data[1] then
				items_data[1] = nil
			elseif not items_data.id and not itm then
				table.remove(sector.sector_repair_items_queued, i)
			elseif not items_data.id and itm and items_data[1] then
				items_data.id = itm.id
				items_data[1] = nil
			elseif itm and items_data.id~=itm.id then 
				items_data.id = itm.id
				items_data[1] = nil
			end
		end	 
	end	
end

---
--- Checks if all equipped items on the given mercenary are fully repaired.
---
--- @param merc Merc The mercenary to check.
--- @return boolean True if all equipped items are fully repaired, false otherwise.
---
function AreAllEquippedItemsRepaired(merc)
	for i = 1, #priority_slots do
		local item, left, top = merc:GetItemInSlot(priority_slots[i])
		if item and not item:IsMaxCondition() then
			return false
		end
	end
	
	return true
end

---
--- Removes any inventory items of unknown type (i.e. not of class "InventoryItem") from the game's unit inventories, sector containers, and squad bags.
---
--- This function is part of the SavegameSessionDataFixups module, which handles various data fixups when loading a saved game.
---
--- @param data table The saved game data.
---
function SavegameSessionDataFixups.InventoryRemoveObsoleteItems(data)
	local l_gv_unit_data = GetGameVarFromSession(data, "gv_UnitData")
	local l_gv_sectors = GetGameVarFromSession(data, "gv_Sectors")
	local l_gv_squads = GetGameVarFromSession(data, "gv_Squads")
	-- units
	for k, merc in pairs(l_gv_unit_data) do
		-- all inventory slots 
		local deleted =  false
		merc:ForEachItem(function(item, slot_name,left, top )
			if item.class=="InventoryItem" then
				merc:RemoveItem(slot_name, item)
				deleted =  true
			end
		end)
		if deleted then
			print("Inventory items of unknown type were found in the inventory "..merc.session_id.." - deleting them.") 
		end	
	end
	-- containers
	for sector, sector_data in pairs(l_gv_sectors) do
		local deleted =  false
		local sector_inventory = sector_data.sector_inventory
		if sector_inventory then
			for _, inv_data in ipairs(sector_inventory) do
				local items = inv_data[3] or {}
				for i = #items,1, -1  do
					local item = items[i]
					if item and item.class=="InventoryItem" then
						table.remove(items,i)
						deleted = true
					end
				end
			end
		end		
		if deleted then
			print("Inventory items of unknown type were found in some containers in sector "..sector.." - deleting them.") 
		end
	end
	-- squad bags
	for squad_id, squad_data in pairs(l_gv_squads) do
		local deleted =  false
		local bag = squad_data.squad_bag
		if bag then
			for i = #bag, 1, -1  do
				local item = bag[i]
				if item and item.class=="InventoryItem" then
					table.remove(bag,i)
					deleted = true
				end
			end
		end		
		if deleted then
			print("Inventory items of unknown type were found in the squad bags of squad "..squad_id.." - deleting them.") 
		end
	end
end

---
--- Fixes inventory slot changes in a savegame session.
---
--- This function is responsible for migrating inventory data from old slot names
--- to new slot names when loading a savegame. It iterates through all units in
--- the savegame data and moves items from the old "Weapon A", "Weapon B",
--- "Quick Slot A", and "Quick Slot B" slots to the new "Handheld A" and
--- "Handheld B" slots.
---
--- @param data table The savegame session data.
function SavegameSessionDataFixups.InventoryFixChangedSlots(data)
	local l_gv_unit_data = GetGameVarFromSession(data, "gv_UnitData")
	-- units	
	for k, merc in pairs(l_gv_unit_data) do
		-- all inventory slots 
		local items = rawget(merc,"Weapon A")
		if items then
			for item, pos in pairs(items) do
				merc:AddItem("Handheld A",item,point_unpack(pos))			
			end		
			rawset(merc,"Weapon A", nil)
		end
		
		items = rawget(merc,"Weapon B")
		if items then
			for item, pos in pairs(items) do
				merc:AddItem("Handheld B",item,point_unpack(pos))		
			end		
			rawset(merc,"Weapon B", nil)
		end	
		
		items = rawget(merc,"Quick Slot A")
		if items then
			local quicka = merc["Quick Slot A"]
			for item, pos in pairs(items) do
				merc:AddItem("Handheld B",item,point_unpack(pos))			
			end
			rawset(merc,"Quick Slot A", nil)
		end
		
		items = rawget(merc,"Quick Slot B")
		if items then
			local quickb = merc["Quick Slot B"]
			for item, pos in pairs(items) do
				merc:AddItem("Handheld B",item,point_unpack(pos))			
			end
			rawset(merc,"Quick Slot B", nil)
		end
	end
end

--- Returns a list of all inventory item IDs.
---
--- This function iterates through all InventoryItemCompositeDef presets and
--- collects their IDs into a table. The first element of the table is an empty
--- string, which is used as a placeholder for the "None" option in UI
--- dropdowns.
---
--- @return table A table containing all inventory item IDs.
function InventoryItemCombo()
	local items = { "" }
	ForEachPreset("InventoryItemCompositeDef", function(o)
		table.insert(items, o.id)
	end)
	return items
end

--- Returns a list of all inventory item IDs that have a WeaponType defined.
---
--- This function iterates through all InventoryItemCompositeDef presets and
--- collects the IDs of items that have a non-empty WeaponType property. The
--- first element of the table is an empty string, which is used as a
--- placeholder for the "None" option in UI dropdowns.
---
--- @return table A table containing all inventory item IDs with a WeaponType.
function InventoryItemWeaponsCombo()
	local items = { "" }
	ForEachPreset("InventoryItemCompositeDef", function(o)
		if o.WeaponType and o.WeaponType ~= "" then
			table.insert(items, o.id)
		end
	end)
	return items
end

--- Returns a table of all available weapon types, excluding certain groups.
---
--- This function iterates through all WeaponType presets and collects them into a
--- table, excluding certain weapon groups such as GrenadeLauncher, MissileLauncher,
--- Mortar, and Throwables. The table is then sorted by the SortKey property of
--- each WeaponType.
---
--- @return table A table containing all available weapon types, excluding certain groups.
function GetWeaponTypes()
	local weaponTypes = { }
	local excludeWeaponGroups = {
		GrenadeLauncher = true, 
		MissileLauncher = true,
		Mortar = true,
		Throwables = true,
	}
	
	ForEachPreset("WeaponType", function(o)
		if not excludeWeaponGroups[o.id] then
			table.insert(weaponTypes, o)
		end
	end)
	
	table.sort(weaponTypes, function (a,b) 
		return tostring(a.SortKey) < tostring(b.SortKey)
	end)
	
	return weaponTypes
end

---
--- Returns a list of inventory items that match the specified weapon type.
---
--- This function iterates through all InventoryItemCompositeDef presets and
--- collects the items that match the specified weapon type. It excludes certain
--- weapon types such as BrowningM2HMG, UnderslungGrenadeLauncher, and
--- SteroidPunchGrenade. The returned list is sorted by the DisplayName property
--- of each item.
---
--- @param weaponType string The weapon type to filter by. Can be "Grenade",
---                         "GrenadeGas", "GrenadeFire", "HeavyWeapon", or "Armor".
--- @return table A table containing the matching InventoryItemCompositeDef objects.
function GetWeaponsByType(weaponType)
	local weapons = {}
	local excludeWeapons = {
		BrowningM2HMG = true, 
		UnderslungGrenadeLauncher = true,
		SteroidPunchGrenade = true,
	}
	ForEachPreset("InventoryItemCompositeDef", function(o)
		if not excludeWeapons[o.id] then
			local classdef = g_Classes[o.object_class]
			if weaponType == "Grenade" and IsKindOfClasses(classdef, "Grenade", "ThrowableTrapItem") then
				table.insert(weapons, o)
			elseif weaponType == "GrenadeGas" and IsKindOf(classdef, "Grenade") and classdef:IsGasGrenade(o.aoeType) then
				table.insert(weapons, o)
			elseif weaponType == "GrenadeFire" and IsKindOf(classdef, "Grenade") and classdef:IsFireGrenade(o.aoeType) then
				table.insert(weapons, o)
			elseif classdef.WeaponType == weaponType or (weaponType == "HeavyWeapon" and (o.group == weaponType or IsKindOf(classdef, "HeavyWeapon"))) then
				table.insert(weapons, o) 
			elseif weaponType == "Armor" and IsKindOf(classdef, "Armor") then
				table.insert(weapons, o)
			end
		end
	end)
	
	TSort(weapons, function(x) return x:GetProperty("DisplayName") or Untranslated(x.id) end) 
	
	return weapons
end

local AmmoRarity = {
	AmmoBasicColor = 0,
	AmmoAPColor = 1,
	AmmoHPColor = 2,
	AmmoMatchColor = 3,
	AmmoTracerColor = 4,
}

---
--- Returns a list of ammunition items that match the specified caliber.
---
--- This function iterates through all InventoryItemCompositeDef presets and
--- collects the items that match the specified caliber. It returns a sorted list
--- of the matching items, with the rarest items (based on the colorStyle
--- property) appearing first.
---
--- @param caliber string The caliber to filter by.
--- @param sort boolean Whether to sort the returned list by rarity.
--- @return table A table containing the matching InventoryItemCompositeDef objects.
---
function GetAmmosWithCaliber(caliber, sort)
	local items = {  }
	ForEachPreset("InventoryItemCompositeDef", function(o)
		local tclass = g_Classes[o.object_class]
		if IsKindOfClasses(tclass, "Ammo", "Ordnance") and o.Caliber == caliber then
			table.insert(items, o)
		end
	end)
	if sort then
		-- sort by "rarity"
		table.sort(items, function(a, b)
			return (AmmoRarity[a.colorStyle] or 100) < (AmmoRarity[b.colorStyle] or 100)
		end)
	end
	return items
end

---
--- Returns the display name of the specified item.
---
--- @param context table The current context.
--- @param item string The name of the item.
--- @return string The display name of the item, or an empty string if the item is not found.
---
function TFormat.ItemName(context, item)
	return g_Classes[item] and g_Classes[item].DisplayName or Untranslated("")
end

function OnMsg.CombatActionCanceled(action_id, unit)
	if g_ItemNetEvents[action_id] and unit then
		local dlg = GetMercInventoryDlg()
		local context = dlg and dlg:GetContext()
		if context then
			dlg:SetContext(context, "update")
			dlg:OnContextUpdate(context)
			InventoryUIRespawn()
		end
	end
end

---
--- Determines whether an inventory object should be grayed out in the UI.
---
--- @param obj table The inventory object to check.
--- @return boolean True if the object should be grayed out, false otherwise.
---
function InventoryUIGrayOut(obj)
	if (not gv_SatelliteView or InventoryIsCombatMode()) and not InventoryIsValidGiveDistance(obj, GetInventoryUnit()) then
		return true
	end
	if InventoryIsNotControlled(obj) then 
		return true
	end	
end

---
--- Determines whether an inventory object is not controlled by the player.
---
--- @param obj table The inventory object to check.
--- @return boolean True if the object is not controlled, false otherwise.
---
function InventoryIsNotControlled(obj)
	if IsKindOf(obj, "Unit") and obj:IsDead() then return false end
	if IsKindOfClasses(obj, "Unit", "UnitData") 
		and (obj:HasStatusEffect("BandageInCombat") or obj:IsDowned() 
				or obj:HasStatusEffect("Unconscious") or g_Overwatch[obj] 
				or g_Pindown[obj]) 
	then
		return true
	end	
		
	return 
		(IsKindOf(obj, "Unit")     and obj:IsPlayerAlly() and not obj:CanBeControlled())
	or (IsKindOf(obj, "UnitData") and gv_Squads[obj.Squad] and gv_Squads[obj.Squad].Side == "player1" and not obj:CanBeControlled())
end

---
--- Gets the drop container for an item at the specified position.
---
--- @param unit table The unit that is dropping the item.
--- @param pos table The position to place the drop container, or nil to use the unit's position.
--- @param item_to_add table The item to be added to the container, or nil to not check for compatibility.
--- @return table The drop container object.
---
function GetDropContainer(unit, pos, item_to_add)
	pos = pos or SnapToPassSlab(unit) or unit:GetPos()
	
	local container = MapGetFirst(pos, const.SlabSizeX/2, "ItemDropContainer", function(o) 
		if not item_to_add then 
			return true 
		end 
		local pos, reason = o:CanAddItem("Inventory",item_to_add)
		return not not pos
	end)
	if not container then
		container = PlaceObject("ItemDropContainer")
		container:SetAngle(container:Random(360*60))
		container:SetPos(pos)
	end
	return container
end

---
--- Performs a squad bag action, such as unloading, scrapping, or cashing in items.
---
--- @param srcInventory table|number|string The source inventory, which can be a table, a squad ID, or a unit name.
--- @param srcSlotName string The name of the source slot.
--- @param itemIds table A table of item IDs to perform the action on.
--- @param squadId number The ID of the squad.
--- @param actionName string The name of the action to perform, such as "unload", "scrap", "salvage", "refill", "cashin", or "unpack".
---
function SquadBagAction(srcInventory, srcSlotName, itemIds, squadId, actionName)
	NetUpdateHash("SquadBagAction", srcSlotName, itemIds, squadId, actionName)
	local squadBag =squadId and GetSquadBagInventory(squadId)
	
	local srcType = type(srcInventory)
	if srcType == "number" then
		srcInventory = GetSquadBagInventory(srcInventory)
	elseif srcType == 'string' then
		local val = (gv_SatelliteView and gv_UnitData[srcInventory] or g_Units[srcInventory]) 
		if not val then
			if gv_Sectors[srcInventory] then
				InventoryUIResetSectorStash()
				val = GetSectorInventory(srcInventory) 
			else
			  val = gv_UnitData[srcInventory]
			 end 
		end
		srcInventory  = val
	end
	for _, itemId in ipairs(itemIds) do
		local item = g_ItemIdToItem[itemId]
		if item then
			local is_stack = IsKindOf(item, "InventoryStack")
			if is_stack then
				actionName = actionName=="scrap" and "scrapall" or actionName
				actionName = actionName=="cashin" and "cashstack" or actionName
			end
			if actionName == "unload" then
				UnloadWeapon(item, squadBag)
			elseif actionName == "unload underslung" then
				if IsKindOf(item, "FirearmBase") then
					item = item:GetSubweapon("Firearm")
					if item then
						UnloadWeapon(item, squadBag)
					end
				end
			elseif actionName == "scrap" then
				ScrapItem(srcInventory, srcSlotName, item, 1, squadBag, squadId)
			elseif actionName == "scrapall" then
				ScrapItem(srcInventory, srcSlotName, item, false, squadBag, squadId)
			elseif actionName == "salvage" then	
				SalvageItem(srcInventory, srcSlotName, item, squadBag)
			elseif actionName == "refill" then	
				RefillMedsItem(srcInventory, srcSlotName, item, squadBag)	
			elseif actionName == "cashin" then
				CashInItem(srcInventory, srcSlotName, item, 1)
			elseif actionName == "cashstack" or actionName == "cashstack-nolog" then
				CashInItem(srcInventory, srcSlotName, item, false, actionName == "cashstack-nolog")
			elseif actionName == "unpack" then
				UnpackItem(srcInventory, srcSlotName, item, 1)
			end
		end
	end
	Msg("InventoryChange", srcInventory)
	Msg("InventoryChange", squadBag)
	Msg("InventoryAddItem", squadBag)
	Msg("InventoryRemoveItem", srcInventory)
	ObjModified(srcInventory)
	ObjModified(squadBag)
	ObjModified("SquadBagAction")
	if srcInventory:HasMember("CanBeControlled") and srcInventory:CanBeControlled() and not srcInventory:IsDead() then InventoryUpdate(srcInventory) end
end

---
--- Handles the execution of a squad bag action for a given session.
---
--- @param session_id string The ID of the session.
--- @param pack table A table of action data to be executed.
---
function NetSyncEvents.SquadBagAction(session_id, pack)
	for i, data in ipairs(pack or empty_table) do
		SquadBagAction(unpack_params(data))
	end
end

---
--- Handles the execution of a squad bag action for a given session.
---
--- @param unit table The unit performing the action.
--- @param ap number The action points used for the action.
--- @param pack table A table of action data to be executed.
---
function CustomCombatActions.SquadBagAction(unit, ap, pack)
	for i, data in ipairs(pack) do
		SquadBagAction(unpack_params(data))
	end
end

---
--- Combines two items using the specified recipe, handling the case where the combination needs to be performed multiple times.
---
--- @param recipe_id string The ID of the recipe to use for the combination.
--- @param outcome string The outcome of the combination (e.g. "crit-fail").
--- @param outcome_hp number The amount of health points lost in case of a critical failure.
--- @param skill_type string The type of skill used for the combination (e.g. "Explosives").
--- @param unit_operator table The unit performing the combination.
--- @param item1_context string|number The context of the first item to be combined.
--- @param item1_pos table The position of the first item to be combined.
--- @param item2_context string|number The context of the second item to be combined.
--- @param item2_pos table The position of the second item to be combined.
--- @param item2 table The second item to be combined (optional).
--- @param combine_count number The number of times the combination should be performed (optional).
---
function Combine2Items(recipe_id, outcome, outcome_hp, skill_type, unit_operator, item1_context, item1_pos, item2_context, item2_pos, item2, combine_count)
	Combine2ItemsInternal(recipe_id, outcome, outcome_hp, skill_type, unit_operator, item1_context, item1_pos, item2_context, item2_pos, item2)
	
	local combineCount = combine_count
	if combineCount and combineCount > 1 then
		combineCount = combineCount - 1
		
		local unit = gv_UnitData[unit_operator]
		local recipe = Recipes[recipe_id]
		local ingredients = InventoryGetIngredientsForRecipe(recipe, unit)
		
		for i = 1, combineCount do
			local ingredientOne = ingredients[1].total_data[i]
			local ingredientTwo = ingredients[2].total_data[i]

			local item1Ctx = GetContainerNetId(ingredientOne.container)
			local item1Pos = ingredientOne.container:GetItemPackedPos(ingredientOne.item)
			local item2Ctx = GetContainerNetId(ingredientTwo.container)
			local item2Pos = ingredientTwo.container:GetItemPackedPos(ingredientTwo.item)
			Combine2ItemsInternal(recipe_id, outcome, outcome_hp, skill_type, unit_operator, item1Ctx, item1Pos, item2Ctx, item2Pos)
		end
	end
end

---
--- Combines two items using the specified recipe, handling the case where the combination needs to be performed multiple times.
---
--- @param recipe_id string The ID of the recipe to use for the combination.
--- @param outcome string The outcome of the combination (e.g. "crit-fail").
--- @param outcome_hp number The amount of health points lost in case of a critical failure.
--- @param skill_type string The type of skill used for the combination (e.g. "Explosives").
--- @param unit_operator table The unit performing the combination.
--- @param item1_context string|number The context of the first item to be combined.
--- @param item1_pos table The position of the first item to be combined.
--- @param item2_context string|number The context of the second item to be combined.
--- @param item2_pos table The position of the second item to be combined.
--- @param item2 table The second item to be combined (optional).
--- @param combine_count number The number of times the combination should be performed (optional).
---
function Combine2ItemsInternal(recipe_id, outcome, outcome_hp, skill_type, unit_operator, item1_context, item1_pos, item2_context, item2_pos, item2)
	local recipe = Recipes[recipe_id]
	local is_string = type(unit_operator) == 'string'
	local combat_mode
	if is_string then
		combat_mode = g_Units[unit_operator] and InventoryIsCombatMode(g_Units[unit_operator] )
		unit_operator = (not gv_SatelliteView  or combat_mode) and g_Units[unit_operator] or gv_UnitData[unit_operator]
		if combat_mode and gv_SatelliteView then 
			unit_operator:SyncWithSession("session")
		end	
	end	
	
	local context1 = GetContainerFromContainerNetId(item1_context)
	local is_bag1 = type(item1_context) == "number"
	local context2 = GetContainerFromContainerNetId(item2_context)
	local is_bag2 = type(item2_context) == "number"

	local pos1x, pos1y, slot1_idx = point_unpack(item1_pos)
	local pos2x, pos2y, slot2_idx = point_unpack(item2_pos)
	local slot1 = context1.inventory_slots[slot1_idx].slot_name
	local item1 = context1:GetItemAtPos(slot1, pos1x, pos1y)

	local slot2 = context2.inventory_slots[slot2_idx].slot_name
	local item2 = item2 or context2:GetItemAtPos(slot2, pos2x, pos2y)	
	
	local is_stack1 = IsKindOf(item1,"InventoryStack")
	local is_stack2 = IsKindOf(item2,"InventoryStack")
	if outcome == "crit-fail" then
		if skill_type=="Explosives" then
			local _, src_pos1 = context1:RemoveItem(slot1,item1)	
			local _, src_pos2 = context2:RemoveItem(slot2,item2)	
			-- take damage
			local hp = outcome_hp
			local diff = MulDivRound(unit_operator.HitPoints, hp,100)
			unit_operator.HitPoints = unit_operator.HitPoints - diff
			unit_operator:AccumulateDamageTaken(diff)
			if is_stack1 then
				item1.Amount = item1.Amount - recipe.Ingredients[first_idx].amount 
				if item1.Amount<=0 then
					DoneObject(item1)
				end	
			else
				DoneObject(item1)
			end
			if is_stack2 then
				item2.Amount = item2.Amount - recipe.Ingredients[second_index].amount 
				if item2.Amount<=0 then
					DoneObject(item2)
				end	
			else
				DoneObject(item2)
			end
			if is_string then
				Msg("InventoryRemoveItem",context1)
				Msg("InventoryRemoveItem",context2)	
				if combat_mode and gv_SatelliteView then 
					unit_operator:SyncWithSession("map")
				end	
			end
			return 
		end
		outcome = "fail"	
	end	
	local first_idx, sec_idx = 1,2 
	local first_ing_item, second_ing_item = item1, item2
	if recipe.Ingredients[1].item == item2.class then
		first_idx, sec_idx = 2, 1 
		first_ing_item, second_ing_item = item2, item1
	end
	
	
	if outcome == "fail" then
		local is_ammo1 = IsKindOf(item1,"Ammo")
		local is_ammo2 = IsKindOf(item2,"Ammo")
		
		if is_ammo1 then
			local change_amount = -MulDivRound(recipe.Ingredients[first_idx].amount,const.CombineFailAmmoLose,100) or 0
			item1.Amount = item1.Amount + change_amount
		elseif item1:HasCondition() then
			local change_condition = -MulDivRound(item1.Condition, const.CombineFailConditionLose,100)
			context1:ItemModifyCondition(item1, change_condition)
		end
		if is_string then
			Msg("InventoryChange", context1) 
			Msg("InventoryChangeItemUI", context1) 
		end
		
		if is_ammo2 then
			local change_amount = -MulDivRound(recipe.Ingredients[sec_idx].amount,const.CombineFailAmmoLose,100) or 0
			item2.Amount = item2.Amount + change_amount
		elseif item2:HasCondition() then
			local change_condition = -MulDivRound(item2.Condition, const.CombineFailConditionLose,100)
			context2:ItemModifyCondition(item2, change_condition)
		end	
		if is_string then
			Msg("InventoryChange", context2) 
			Msg("InventoryChangeItemUI", context2) 
			if combat_mode and gv_SatelliteView then 
				unit_operator:SyncWithSession("map")
			end	
		end
		return
	end

	--	 crit success and success - normal result									--		
	if is_stack1 then
		item1.Amount = item1.Amount - recipe.Ingredients[first_idx].amount
	end
	if is_stack2 then
		item2.Amount = item2.Amount - recipe.Ingredients[sec_idx].amount
	end
	local delete_item1, delete_item2, src_pos1, src_pos2
	if not is_stack1 or item1.Amount==0 then
		delete_item1, src_pos1 = context1:RemoveItem(slot1,item1)	
	end
	if not is_stack2 or item2.Amount==0 then
		delete_item2, src_pos2 = context2:RemoveItem(slot2,item2)	
	end	
	
	-- result items
	for i=1, #recipe.ResultItems do							
		local new_item_id = recipe.ResultItems[i].item
		local new_item_amount = recipe.ResultItems[i].amount
		local new_item = PlaceInventoryItem(new_item_id)
		local item = i==1 and first_ing_item or second_ing_item
		new_item.Condition = item.Condition
		if IsKindOf(new_item, "ToolItem") then
			local change_condition = -MulDivRound(new_item.Condition, const.CombineToolConditionLose,100)
			unit_operator:ItemModifyCondition(new_item, change_condition)
		end
		local is_transmuted = IsKindOf(new_item, "TransmutedItemProperties")											
		local is_stack = IsKindOf(new_item, "InventoryStack")
		if is_transmuted then
			new_item:MakeTransmutation(item)
			new_item.RevertCondition = recipe.RevertCondition
			new_item.RevertConditionCounter = recipe.RevertConditionValue
			new_item.OriginalItemId = recipe.Ingredients[1].item
		end
		if is_stack  then
			new_item.Amount = new_item_amount
		end	
		
		local skip = i==1  and not IsEquipSlot(slot1) and IsEquipSlot(slot2)
		local context,new_slot,pos, reason
		
		if not skip then
			context = i==1 and context1 or context2
			new_slot = i==1 and slot1 or slot2
			local equip_to_inventory = false
			if IsWeaponSlot(new_slot) then
				equip_to_inventory = (i==1 and is_stack1 or is_stack2) and (i==1 and (is_stack1 and item1.Amount>0) or (is_stack2 and item2.Amount>0))
			end	
			if new_slot=="Inventory" or equip_to_inventory then
				pos, reason = AddItemsToInventory(context, {new_item}, IsKindOf("UnitProperties", context)) 
			else 
				pos, reason = context:AddItem(new_slot, new_item)
			end
			if not pos then
				pos, reason = AddItemsToInventory(context, {new_item}, IsKindOf("UnitProperties", context)) 
			end	
		end
		if not pos then -- try the other context for free space
			context = i==1 and context2 or context1
			new_slot = i==1 and slot2 or slot1
			local equip_to_inventory = false
			if IsWeaponSlot(new_slot) then
				equip_to_inventory = (i==1 and is_stack1 or is_stack2) and (i==1 and (is_stack1 and item1.Amount>0) or (is_stack2 and item2.Amount>0))
			end	
			if new_slot=="Inventory" or equip_to_inventory then
				pos, reason = AddItemsToInventory(context, {new_item}, IsKindOf("UnitProperties", context)) 
			else 
				pos, reason = context:AddItem(new_slot, new_item)
			end
			if not pos then
				pos, reason = AddItemsToInventory(context, {new_item}, IsKindOf("UnitProperties", context)) 
			end	

		end
		local target
		if not pos then	-- drop to ground or sector stash	
			--try to drop from first unit/first item/then second unit second items/ then mechanic
			local units = {context1, context2,unit_operator}
			for i=1, #units do
				local unit = units[i]
				target = IsKindOf(unit, "Unit") and GetDropContainer(unit, false, new_item) or (unit.Squad and GetSectorInventory(gv_Squads[unit.Squad].CurrentSector))
				if target then 
					pos, reason = target:AddItem("Inventory", new_item)
					if pos then
						local amount = is_stack and new_item.Amount or 1
						CombatLog("important", T{740183432105, "  Inventory full. <amount><em><item></em> dropped by <name>", amount = amount>1 and Untranslated(amount.." x ") or "", item = amount>1 and item.DisplayNamePlural or item.DisplayName,  name = unit:GetDisplayName()})
						break	
					end
				end	
			end
		end
		if is_string then
			Msg("InventoryChange", context) 
			if pos then Msg("InventoryAddItem", target or context) end
		end
	end
	
	Msg("CombineItemsSuccess", unit_operator, skill_type)

	DoneObject(delete_item1)
	DoneObject(delete_item2)												
	if is_string then
		if delete_item1 then Msg("InventoryRemoveItem",context1) end
		if delete_item2 then Msg("InventoryRemoveItem",context2) end		
		Msg("InventoryChangeItemUI", context1)
		Msg("InventoryChangeItemUI", context2)
		if combat_mode and gv_SatelliteView then 
			unit_operator:SyncWithSession("map")
		end	
	end
end

---
--- Modifies the condition of an item in the inventory.
---
--- @param item InventoryStack The item to modify the condition of.
--- @param amount number The amount to modify the condition by.
--- @return number The new condition value of the item.
---
function Inventory:ItemModifyCondition(item, amount)
	if not item:HasCondition() then
		return
	end
	local prev = item.Condition
	local newValue = Max(0, item.Condition + amount)
	item.Condition = newValue
	Msg("InventoryChange", self)
	if prev~=newValue then
		Msg("ItemChangeCondition", item, prev, newValue, self)
	end	
	ObjModified(item)
	ObjModified(self)
	
	return newValue
end

---
--- Combines two items in the inventory.
---
--- @param pack table A table containing the parameters for the item combination.
---
function NetSyncEvents.CombineItems(pack)
	Combine2Items(unpack_params(pack))
end

---
--- Synchronizes the modification of a weapon's condition.
---
--- @param ownerId number The ID of the unit that owns the weapon.
--- @param weaponSlot number The slot index of the weapon.
--- @param amount number The amount to modify the weapon's condition by.
---
function NetSyncEvents.WeaponModifyCondition(ownerId, weaponSlot, amount)
	local owner = gv_SatelliteView and gv_UnitData[ownerId] or g_Units[ownerId]
	assert(owner)
	if not owner then return end
	local weaponItem = owner:GetItemAtPackedPos(weaponSlot)
	owner:ItemModifyCondition(weaponItem, amount)
end

---
--- Synchronizes the modification of a weapon's components, color, and other properties.
---
--- @param ownerId number The ID of the unit that owns the weapon.
--- @param weaponSlot number The slot index of the weapon.
--- @param components table A table of weapon components to set on the weapon.
--- @param color table The new color to set on the weapon.
--- @param success boolean Whether the weapon modification was successful.
--- @param modAdded boolean Whether a new weapon modification was added.
--- @param mechanicId number The ID of the unit that performed the weapon modification.
--- @param modSlot number The slot index of the weapon modification.
--- @param oldComponent table The old weapon component that was replaced.
---
function NetSyncEvents.WeaponModified(ownerId, weaponSlot, components, color, success, modAdded, mechanicId, modSlot, oldComponent)
	local owner = gv_SatelliteView and gv_UnitData[ownerId] or g_Units[ownerId]
	assert(owner)
	if not owner then return end
	local weaponItem = owner:GetItemAtPackedPos(weaponSlot)
	if weaponItem then
		for s, c in sorted_pairs(components) do
			weaponItem:SetWeaponComponent(s, c)
		end
		if color then weaponItem.Color = color end
		weaponItem:UpdateVisualObj()
		ObjModified(weaponItem)
	end

	if not gv_SatelliteView then
		owner:FlushCombatCache()
		owner:RecalcUIActions(true) 
	end
	
	local mechanic = gv_SatelliteView and gv_UnitData[mechanicId] or g_Units[mechanicId]
	if success then
		Msg("WeaponModifiedSuccessSync", weaponItem, owner, modAdded, mechanic, modSlot, oldComponent)
	end
end

---
--- Combines two items in the player's inventory.
---
--- @param unit Unit The unit that is combining the items.
--- @param ap number The action points used to combine the items.
--- @param pack table A table containing the parameters to unpack and pass to the Combine2Items function.
---
function CustomCombatActions.CombineItems(unit,ap,pack)
	Combine2Items(unpack_params(pack))
end

DefineClass.MiscItem = {
	__parents = {"InventoryStack", "MiscItemProperties", "BobbyRayShopOtherProperties" }
}

DefineClass.StatBoostItem = { 
	__parents = { "QuickSlotItem", "StatBoostItemProperties"},
	modifiers_added = {},
	modifier_id = false,
}

---
--- Generates a unique identifier for a modifier associated with a StatBoostItem.
---
--- @param u Unit The unit that the StatBoostItem is being added to.
--- @param slot number The slot index of the item.
--- @param pos number The position index of the item.
---
function StatBoostItem:GenerateModifierId(u, slot, pos)
	self.modifier_id = string.format("StatBoostItem-%s-%s-%s-%d", self.class, u.session_id, slot, pos)
end

---
--- Adds a StatBoostItem to a unit's inventory and applies the associated modifier.
---
--- @param u Unit The unit that the StatBoostItem is being added to.
--- @param slot number The slot index of the item.
--- @param pos number The position index of the item.
--- @param item StatBoostItem The StatBoostItem being added.
---
function StatBoostItem:OnAdd(u, slot, pos, item)
	InventoryItem.OnAdd(self, u, slot, item)
	if not IsKindOf(u, "Modifiable") or not IsEquipSlot(slot) then
		return
	end
	if not self.stat or not self.boost then
		return
	end
	self:GenerateModifierId(u, slot, pos)
	local mod = u:AddModifier(self.modifier_id, self.stat, false, self.boost, self.DisplayName, nil, self.boost)
	ObjModified(u)
	Msg("ModifierAdded", u, self.stat, mod)
end

---
--- Removes a StatBoostItem from a unit's inventory and removes the associated modifier.
---
--- @param u Unit The unit that the StatBoostItem is being removed from.
--- @param slot number The slot index of the item.
--- @param pos number The position index of the item.
--- @param item StatBoostItem The StatBoostItem being removed.
---
function StatBoostItem:OnRemove(u, slot, pos, item)
	if not IsKindOf(u, "Modifiable") or not IsEquipSlot(slot) then
		return
	end
	if not self.stat or not self.boost  then
		return
	end
	if not self.modifier_id then
		self:GenerateModifierId(u, slot, pos)
	end
	u:RemoveModifier(self.modifier_id, self.stat)
	ObjModified(u)
end

function OnMsg.InventoryChange(obj)
	if IsKindOf(obj, "Unit") then
		obj:ApplyModifiersList(obj.applied_modifiers)
	end
end

g_InventoryItemEffectMoments = {"on_pickup", "on_use"}
---
--- Returns the list of inventory item effect moments.
---
--- @return table The list of inventory item effect moments.
---
function InventoryItemEffectMoments()
	return g_InventoryItemEffectMoments
end

---
--- Scraps an item from the inventory, potentially generating additional scrap items.
---
--- @param inventory Inventory The inventory that the item is being scrapped from.
--- @param slot_name string The name of the inventory slot that the item is in.
--- @param item InventoryItem The item being scrapped.
--- @param amount number The amount of the item to scrap (for stacks).
--- @param squadBag SquadBag The squad bag that the scrapped parts will be added to.
--- @param squadId number The ID of the squad that the item is being scrapped from.
---
function ScrapItem(inventory, slot_name, item, amount, squadBag, squadId)
	local is_stack = IsKindOf(item, "InventoryStack")
	if is_stack then
		amount = amount and Min(amount, item.Amount) or item.Amount
	end	
	amount = amount or 1
	local partsAmount = item:AmountOfScrapPartsFromItem() * amount
	local additional 
	if IsKindOf(item, "Firearm") then
		additional = item:GetSpecialScrapItems()
	end	
	
	if next(additional) then
		local units    = gv_Squads[squadId].units 
		local unit_id  = table.max(units,function(unit_id) return gv_UnitData[unit_id].Mechanical end)
		local max_mech   = gv_UnitData[unit_id].Mechanical/2
		local rnd_unit = gv_UnitData[units[1]]
		local rand = rnd_unit:Random(100)
		if rand<max_mech then
			local res_idx = 1 + rnd_unit:Random(#additional)
			local res = additional[res_idx]
			local res_item = PlaceInventoryItem(res.restype)
			if IsKindOf(res_item, "InventoryStack") then
				res_item.Amount = res.amount
			end
			local add_slot_name = GetContainerInventorySlotName(inventory)
			if add_slot_name=="Inventory" then
				AddItemsToInventory(inventory, {res_item})
			else
				inventory:AddItem(add_slot_name, res_item)
			end
		end
	end
	
	if item.ammo then
		UnloadWeapon(item, squadBag)
	end
	if partsAmount > 0 then
		local parts = PlaceInventoryItem("Parts")
		parts.Amount = partsAmount	
		squadBag:AddAndStackItem(parts)
	end
		
	if is_stack then
		item.Amount = Max(0, item.Amount - amount)
	end
	
	if not is_stack or item.Amount==0 then
		local removedItem, pos = inventory:RemoveItem(slot_name, item)
		DoneObject(removedItem)
	end
	
	if IsKindOf(inventory, "Unit") and slot_name == inventory.current_weapon and inventory:IsIdleCommand() then
		inventory:SetCommand("Idle")
	end
	
	ObjModified("inventory tabs")
	UpdateWeaponModificationPartsCounter()
end

---
--- Scales and performs a division operation on the provided values.
---
--- @param a number The first value to multiply.
--- @param b number The second value to multiply.
--- @param c number The value to divide the product by.
--- @param scale number (optional) The scaling factor to apply to the product before division.
--- @return number The result of the scaled division operation.
function MulDivScaled(a,b,c,scale)
	scale = scale or 1
	local rem = a*b*scale%c
	local add = rem>0 and 1 or 0
	return MulDivTrunc(a,b,c) + add
end

-- refill and salvage
local med_calc_scale = 100
---
--- Calculates the amount of meds needed to fill an item's condition.
---
--- @param item InventoryItem The item to calculate the meds needed for.
--- @return number The amount of meds needed to fill the item's condition.
function AmountOfMedsToFill(item)
	local meds = AmountOfSalvagedMeds(item, item.Condition, const.MedicineRefillToSalvageFactor)
	return MulDivScaled(item.max_meds_parts, const.MedicineRefillToSalvageFactor, 100, med_calc_scale) - meds
end

---
--- Refills the meds of the specified item from the squad bag or the unit's inventory.
---
--- @param inventory UnitData|Unit The inventory to refill the item from.
--- @param slot_name string The name of the slot the item is in.
--- @param item InventoryItem The item to refill.
--- @param squadBag SquadBag The squad bag to take meds from.
---
function RefillMedsItem(inventory, slot_name, item, squadBag)
	local medsNeeded = AmountOfMedsToFill(item)
	if medsNeeded <=0 then return end
	
	--get meds from squad bag untill fill the condition or all meds ends
	local allmedsNeeded = medsNeeded
	local rem
	if IsKindOfClasses(inventory, "UnitData", "Unit") and not inventory:IsDead() then
		rem = TakeItemFromMercs({inventory.session_id}, "Meds", medsNeeded)
	else
		rem = TakeItemFromSquadBag(squadBag.squad_id, "Meds", medsNeeded)
	end
	local usedmeds = allmedsNeeded - rem
	local max_condition = item:GetMaxCondition()
	if rem==0 then
		-- full condition
		item.Condition = max_condition
	else
		item.Condition = Clamp(item.Condition + MulDivScaled(usedmeds, max_condition-item.Condition, allmedsNeeded, med_calc_scale),0, max_condition)
	end
end

---
--- Calculates the amount of meds that can be salvaged from an inventory item.
---
--- @param item InventoryItem The item to calculate the salvaged meds for.
--- @param condition number The condition of the item. If not provided, the item's current condition is used.
--- @param factor number An optional factor to apply to the calculation.
--- @return number The amount of meds that can be salvaged from the item.
function AmountOfSalvagedMeds(item, condition, factor)
	local condition = condition or item.Condition
	if condition and condition >= 1  then
		local max_meds = factor and MulDivScaled(item.max_meds_parts, const.MedicineRefillToSalvageFactor, 100,med_calc_scale) or item.max_meds_parts
		return Clamp(MulDivScaled(condition, max_meds, item:GetMaxCondition(),med_calc_scale), 1,max_meds)
	end	
	return 0
end

---
--- Salvages the meds from the specified inventory item and adds them to the squad bag.
---
--- @param inventory UnitData|Unit The inventory to remove the item from.
--- @param slot_name string The name of the slot the item is in.
--- @param item InventoryItem The item to salvage meds from.
--- @param squadBag SquadBag The squad bag to add the salvaged meds to.
---
function SalvageItem(inventory, slot_name, item, squadBag)
	local medsAmount = AmountOfSalvagedMeds(item)
	if medsAmount <=0 then return end
	local meds = PlaceInventoryItem("Meds")
	meds.Amount = medsAmount	
	squadBag:AddAndStackItem(meds)
	
	--item.Condition = 0
	local removedItem, pos = inventory:RemoveItem(slot_name, item)
	DoneObject(removedItem)
end

---
--- Cashes in an inventory item for money.
---
--- @param inventory UnitData|Unit|SectorStash The inventory to remove the item from.
--- @param slot_name string The name of the slot the item is in.
--- @param item InventoryItem|InventoryStack The item to cash in.
--- @param amount number The amount of the item to cash in.
--- @param dontLog boolean If true, don't log the cash-in event.
---
--- @return nil
function CashInItem(inventory, slot_name, item, amount, dontLog)
	local money = item.Cost
	local to_remove
	if IsKindOf(item, "InventoryStack") then
		amount = amount and Min(amount, item.Amount) or item.Amount
		money = money * amount
		item.Amount = item.Amount - amount
		to_remove = item.Amount==0
	else
		to_remove =  true
	end
	if not dontLog then
		if amount == 1 then
			CombatLog("important",T{279086132540, "Cashed in <em><item></em> for <em><money(money_gained)></em>",item = item.DisplayName, money_gained = money})
		else
			CombatLog("important",T{879321398432, "Cashed in <em><amount> x <items></em> for <em><money(money_gained)></em>",amount = amount, items = item.DisplayNamePlural, money_gained = money})
		end
	end
	AddMoney(money, "deposit",true)
	Msg("CashInItem", item, amount, money)
	if to_remove then
		local removedItem, pos = inventory:RemoveItem(slot_name, item)
		DoneObject(removedItem)
	end
end

---
--- Unpacks an inventory item, generating new items from its loot definition.
---
--- @param inventory UnitData|Unit|SectorStash The inventory to unpack the item from.
--- @param slot_name string The name of the slot the item is in.
--- @param item InventoryItem The item to unpack.
--- @param amount number The amount of the item to unpack.
---
--- @return nil
function UnpackItem(inventory, slot_name, item, amount)
	local lootDef = item.loot_def
	lootDef = LootDefs[lootDef]
	if not lootDef then
		CombatLog("debug", Untranslated("Unpack item: no loot set"))
		return
	end
	if not IsKindOfClasses(inventory, "Unit", "UnitData", "SectorStash") then
		CombatLog("debug", Untranslated("Unpack item: unpacking from weird container"))
		return
	end

	local items = {}
	lootDef:GenerateLoot(inventory, {}, InteractionRand(nil, "UnpackItem"), items)
	
	local putItemsHere = false
	if gv_SatelliteView then
		if IsKindOf(inventory, "SectorStash") then
			putItemsHere = inventory
		else -- UnitData (hopefully)
			local squad = inventory.Squad
			squad = squad and gv_Squads[squad]
			local sectorId = squad.CurrentSector
			putItemsHere = GetSectorInventory(sectorId)
		end
	else
		putItemsHere = inventory
	end
	if not putItemsHere then
		CombatLog("debug", Untranslated("Unpack item: Nowhere to put?"))
		return
	end
	
	for i, item in ipairs(items) do
		local added = putItemsHere:AddItem("Inventory", item)
		if item.Amount and item.Amount > 1 then
			CombatLog("important", T{478224212958, "Unpacked <itemAmount> <itemDisplayName>",
				itemAmount = item.Amount,
				itemDisplayName = item.DisplayNamePlural
			})
		else
			CombatLog("important", T{455452587774, "Unpacked <itemDisplayName>", itemDisplayName = item.DisplayName})
		end

		-- Item dropped on the ground because no space in tactical view
		if not added and not gv_SatelliteView then
			local unit = inventory
			local amount = item.Amount or 1
			CombatLog("important", T{740183432105, "  Inventory full. <amount><em><item></em> dropped by <name>",
				amount = amount>1 and Untranslated(amount.." x ") or "", item = amount>1 and item.DisplayNamePlural or item.DisplayName, 
				name = unit:GetDisplayName()
			})
		end
	end
	
	local removedItem, pos = inventory:RemoveItem(slot_name, item)
	DoneObject(removedItem)
end

---
--- Gets the total value of all Valuables items in the inventory of the specified mercenary.
---
--- @param mercId number The ID of the mercenary to check.
--- @return number The total value of all Valuables items in the mercenary's inventory.
function GetValuablesWorthInMerc(mercId)
	local ud = gv_UnitData[mercId]
	if not ud then return end
	
	local moneyAmount = 0
	ud:ForEachItem(false, function(item, slot)
		if not IsKindOf(item, "Valuables") then return end
		
		local amount = 1
		if IsKindOf(item, "InventoryStack") then
			amount = item.Amount
		end
		
		moneyAmount = moneyAmount + item.Cost * amount
	end)
	return moneyAmount
end

---
--- Cashes in all Valuables items in the inventory of the specified mercenary.
---
--- @param mercId number The ID of the mercenary whose Valuables items should be cashed in.
function CashInMercValuables(mercId)
	local ud = gv_UnitData[mercId]
	if not ud then return end

	local params = {}
	ud:ForEachItem(false, function(item, slot_name)
		if not IsKindOf(item, "Valuables") then return end
		NetSquadBagAction(ud, ud, slot_name, item, false, "cashstack-nolog", 0)
	end)
end

---
--- Unloads a weapon, returning any remaining ammunition to the squad bag.
---
--- @param item Firearm The weapon to unload.
--- @param squadBag InventoryContainer The squad bag to return the ammunition to.
---
function UnloadWeapon(item, squadBag)
	local ammo = item.ammo
	item.ammo = false
	if ammo and ammo.Amount > 0 then
		squadBag:AddAndStackItem(ammo)
	end
	if IsKindOf(item, "Firearm") then
		item:OnUnloadWeapon()
	end
end

local o1, o2
---
--- Suppresses and restores inventory UI updates.
---
--- When called, this function will suppress inventory UI updates by replacing the `InventoryUIRespawn` and `ObjModified` functions with empty functions. Calling it again will restore the original functions.
---
--- This can be used to temporarily disable inventory UI updates, for example during a batch operation that would otherwise trigger many unnecessary UI updates.
---
--- @function SuppressInvUpdates
--- @return nil
function SuppressInvUpdates()
	if not o1 then
		o1, o2 = InventoryUIRespawn, ObjModified
		InventoryUIRespawn = empty_func
		ObjModified = empty_func
		print("suppressed")
	else
		InventoryUIRespawn, ObjModified = o1, o2
		o1 = false
		o2 = false
		print("restored")
	end
end

-- Tries to move all items from "containers" to "units" (and their squad bag)
---
--- Takes all items from the specified units and containers and moves them to the first unit's squad bag.
---
--- @param units table A table of units to take items from.
--- @param containers table A table of containers to take items from.
---
function InventoryTakeAll(units, containers)
	-- Cancel the dragging first if any
	if InventoryDragItem and StartDragSource then
		StartDragSource:CancelDragging()
	end
	local net_units, net_containers = {}, {}
	for i, unit in ipairs(units) do
		net_units[i] = GetContainerNetId(unit)
	end
	for i, container in ipairs(containers) do
		net_containers[i] = GetContainerNetId(container)
	end
	NetSyncEvent("InventoryTakeAllNet", netUniqueId, net_units, net_containers)
end

---
--- Handles the logic for taking all items from the specified units and containers and moving them to the first unit's squad bag.
---
--- This function is called when the "Take All" action is triggered. It first cancels any ongoing dragging, then retrieves the container net IDs for the specified units and containers. It then calls the `NetSyncEvent` function to synchronize the item transfer across the network.
---
--- The actual item transfer logic is implemented in the `NetSyncEvents.InventoryTakeAllNet` function, which is called on the server-side to perform the item transfer.
---
--- @param units table A table of units to take items from.
--- @param containers table A table of containers to take items from.
---
function NetSyncEvents.InventoryTakeAllNet(playerId, net_units, net_containers)
	local units, containers = {}, {}
	for i, unit in ipairs(net_units) do
		units[i] = GetContainerFromContainerNetId  (unit)
	end
	for i, container in ipairs(net_containers) do
		containers[i] = GetContainerFromContainerNetId  (container)
	end

	local is_local_player = playerId == netUniqueId
	local pick_cost = g_Combat and const["Action Point Costs"].PickItem or 0
	local squad_bag = GetSquadBagInventory(units[1] and units[1].Squad) or gv_SquadBag
	
	-- Looting itself; from all containers, starting from top one to first unit
	local unit_done = {}
	local sector_stash = false
	local itemsTakenCount, itemsNonTakenCount = 0, 0
	for _, container in ipairs(containers or empty_table) do
		if IsKindOf(container, "SectorStash") then
			sector_stash = true
			container:ResetBinding() --make ForEachItemInSlot iterate in the same order for this container
		end
		local container_slot_name = GetContainerInventorySlotName(container)
		local result = container:ForEachItemInSlot(container_slot_name, false, function(item, slot_name, src_left, src_top)
			local overwriteApCost = itemsTakenCount > 0 and 0
			local item_placeholder = {id = item.id, DisplayName = item.DisplayName, DisplayNamePlural = item.DisplayNamePlural, class = item.class}
			local is_stack = IsKindOf(item,"InventoryStack")	
			local amount = is_stack and item.Amount or 1
			-- try to move to equiped stack
			local new_amount
			if is_stack then
				for _, unit in ipairs(units) do
					if not unit_done[unit] and InventoryIsValidGiveDistance(container, unit) then
						local eq_slot = "Handheld A"
						local itm, il, it = unit:GetItemInSlot(eq_slot, item.class)
						if not il then
							eq_slot = "Handheld B"
							itm, il, it = unit:GetItemInSlot(eq_slot, item.class)
						end					
						if il and it then
							local amnt = Min(item.Amount,itm.MaxStacks-itm.Amount)
							local result
							if amnt>0 then
								local args = {item = item, s_item_at_dest = itm, src_container = container, src_slot = container_slot_name, dest_container = unit,
													dest_slot = eq_slot, ap_cost = overwriteApCost, sync_call  = true, dest_x = il, dest_y = it, amount = amnt}							
								result, new_amount = MoveItem(args)
							else
								result = "no space"
							end
							if result == "Unit doesn't have ap to execute action" then
								unit_done[unit] = true
								if is_local_player then
									CombatLog("important", T{308028682851, "<DisplayName> doesn't have enough AP to pick all items",unit})
									PlayFX("TakeAllFail", "start", unit)
								end
							end
							if not result then
								local transfered = not new_amount and amount or amount - new_amount
								amount = amount - transfered
								if is_local_player then
									Msg("InventoryTakeAllAddItem", unit, item_placeholder, transfered)
								end
								if amount <= 0 then
									itemsTakenCount = itemsTakenCount + 1
									return
								end
							end
						end
					end
				end
			end
			--try to move to squad bag first
			--partial merge not possible for squad bag because its infinite
			local args = {item = item, src_container = container, src_slot = container_slot_name, dest_container = squad_bag,
								dest_slot = "Inventory", ap_cost = overwriteApCost, sync_call  = true }
			local result, new_amount = MoveItem(args)
			if result then
				--could not move to squad bag, try to move to units
				for _, unit in ipairs(units) do
					if not unit_done[unit] and InventoryIsValidGiveDistance(container, unit) then
						local args = {item = item, src_container = container, src_slot = container_slot_name, dest_container = unit,
											dest_slot = "Inventory", ap_cost = overwriteApCost, sync_call  = true}
						result, new_amount = MoveItem(args)
						if result then
							if result == "Unit doesn't have ap to execute action" then
								unit_done[unit] = true
								if is_local_player then
									CombatLog("important", T{308028682851, "<DisplayName> doesn't have enough AP to pick all items",unit})
									PlayFX("TakeAllFail", "start", unit)
								end
							end
							if new_amount == "inventory full" and not item:IsLargeItem() then
								unit_done[unit] = true
							end
						else
							local transfered = not new_amount and amount or amount - new_amount
							amount = amount - transfered
							if is_local_player then
								Msg("InventoryTakeAllAddItem", unit, item_placeholder, transfered)
							end
							if amount <= 0 then
								itemsTakenCount = itemsTakenCount + 1
								return
							end
						end
					end
				end
			else
				itemsTakenCount = itemsTakenCount + 1
				if is_local_player then
					Msg("SquadBagTakeAllAddItem", item_placeholder, amount)
				end
				return
			end
			
			itemsNonTakenCount = itemsNonTakenCount + 1
		end, units)
	end
	if is_local_player then
		if itemsNonTakenCount <= 0 then
			if not sector_stash then
				local dlg = GetDialog("FullscreenGameDialogs")
				if dlg then
					dlg:SetMode("empty")
					dlg:Close()
				end
			end	
		else
			CombatLog("important", T(928914188428, "The inventory of the nearby mercs is full"))
		end
	end
	return itemsTakenCount, itemsNonTakenCount
end

---
--- Synchronizes the process of taking loot from an auto-resolve encounter across the network.
---
--- @param units table<Unit> The units that will be taking the loot.
--- @param items table<Item> The items that will be taken as loot.
--- @param sectorId number The ID of the sector where the loot is located.
---
function TakeLootFromAutoResolve(units, items, sectorId)
	local netUnits = {}
	local netItems = {}
	for i, unit in ipairs(units) do
		netUnits[i] = GetContainerNetId(unit)
	end
	for i, item in ipairs(items) do
		netItems[i] = item.id
	end
	
	NetSyncEvent("TakeLootFromAutoResolveNet", netUniqueId, netUnits, netItems, sectorId)
end

---
--- Synchronizes the process of taking loot from an auto-resolve encounter across the network.
---
--- @param executingNetId number The net ID of the player executing the event.
--- @param netUnits table<number> The net IDs of the units taking the loot.
--- @param netItems table<number> The IDs of the items being taken as loot.
--- @param sectorId number The ID of the sector where the loot is located.
---
function NetSyncEvents.TakeLootFromAutoResolveNet(executingNetId, netUnits, netItems, sectorId)
	local isLocalPlayer = netUniqueId == executingNetId
	-- Deserialization
	local units, items = {}, {}
	for i, unitId in ipairs(netUnits) do
		units[i] = GetContainerFromContainerNetId(unitId)
	end
	for i, itemId in ipairs(netItems) do
		if g_ItemIdToItem[itemId] then
			items[#items+1] = g_ItemIdToItem[itemId]
		end
	end
	local src_container = GetSectorInventory(sectorId)
	local src_container_slot_name = "Inventory"
	
	-- Actual Work	
	local squad_bag = GetSquadBagInventory(units[1] and units[1].Squad) or gv_SquadBag
	local unit_done = {}
	local itemsTakenCount = 0
	local itemsNonTaken = {}
	
	for _, item in ipairs(items) do
		local item_placeholder = {id = item.id, DisplayName = item.DisplayName, DisplayNamePlural = item.DisplayNamePlural, class = item.class}
		local is_stack = IsKindOf(item,"InventoryStack")	
		local amount = is_stack and item.Amount or 1
		local args = {item = item, dest_container = squad_bag,	dest_slot = "Inventory", src_container = src_container, src_container_slot_name = src_container_slot_name, sync_call = true}
		local result, new_amount = MoveItem(args)
		if result then
			--could not move to squad bag, try to move to units
			for _, unit in ipairs(units) do
				if not unit_done[unit] then
					local args = {item = item, dest_container = unit, dest_slot = "Inventory", src_container = src_container, src_container_slot_name = src_container_slot_name, sync_call = true}
					result, new_amount = MoveItem(args)
					if result then
						if new_amount == "inventory full" and not item:IsLargeItem() then
							unit_done[unit] = true
						end
					else
						local transfered = not new_amount and amount or amount - new_amount
						amount = amount - transfered
						Msg("InventoryTakeAllAddItem", unit, item_placeholder, transfered, "auto_resolve")
						if amount <= 0 then
							itemsTakenCount = itemsTakenCount + 1
							goto continue
						end
					end
				end
			end
		else
			itemsTakenCount = itemsTakenCount + 1
			Msg("SquadBagTakeAllAddItem", item_placeholder, amount, "auto_resolve")
			goto continue
		end
		
		itemsNonTaken[#itemsNonTaken+1] = item
		::continue::
	end
	
	-- Check for left out items and close the conflict screen
	local conflictDlg = GetDialog("SatelliteConflict")
	if isLocalPlayer then
		if #itemsNonTaken > 0 then
			CreateRealTimeThread(function()
				local popupHost = GetDialog("PDADialog")
				popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
				local popup = CreateMessageBox(nil,
					T(719913116871, "Not enough space"),
					T(585970067597, "Some of the items were placed in the sector stash"),
					T(6877, "OK"), popupHost)
				
				popup:Wait()
				conflictDlg:Close()
			end)
		else
			conflictDlg:Close()
		end
	else
		if conflictDlg then	conflictDlg:Close()	end
	end
end

---
--- Generates a comma-separated string of item names and amounts from a list of items.
---
--- @param items table A table of items to generate the text for.
--- @return string A comma-separated string of item names and amounts.
---
function GetItemsNamesText(items)
	local texts = {}
	for _, item in ipairs(items) do
			local item_id =  item.class
			local item_name = item.DisplayName
			local item_name_pl = item.DisplayNamePlural
			if item_id == "Money" then
				texts[#texts+1] =  T{975705544014, "<em><money(Amount)></em>", Amount = item.Amount}
			else
				if item.Amount then
					texts[#texts+1] =  T{322035442910, "<Amount> x <em><item></em>", Amount = item.Amount, item =  item.Amount<=1 and item_name or item_name_pl}
				else
					texts[#texts+1] =  T{817405706345, "<em><item></em>",item =  item_name}
				end
			end
	end
	return table.concat(texts, ", ")
end

---
--- Generates a hash value for an inventory object.
---
--- @param obj table A table of inventory items and their positions.
--- @return number The hash value for the inventory object.
---
function GetInventoryHash(obj)
	local hash = 0
	for i = 1, #obj, 2 do
		local pos = obj[i]
		local item = obj[i + 1]
		
		local itemId = item.id
		hash = xxhash(hash, pos, itemId)
	end
	return hash
end

---
--- Determines if an inventory item can be used in the new inventory rollover UI.
---
--- @param item table The inventory item to check.
--- @return boolean True if the item can be used in the new inventory rollover UI, false otherwise.
---
function UseNewInventoryRollover(item)
	return item and (item:IsWeapon() or IsKindOfClasses(item, "Grenade", "Ordnance") or IsKindOf(item, "Armor"))
end

-- Remove locked items on death
function OnMsg.UnitDieStart(unit)
	if not IsMerc(unit) then return end
	unit:ForEachItem(function(item, slot)
		if item.locked then
			unit:RemoveItem(slot, item)
		end
	end)
end

---
--- Determines if an inventory item should be included in the context menu.
---
--- @param context table The context information for the inventory item.
--- @param className string (optional) The class name to check the item against.
--- @return boolean True if the item should be included in the context menu, false otherwise.
---
function InvContextMenuFilter(context, className)
	if not context or not context.item then return false end
	if className and not IsKindOf(context.item, className) then return false end
	
	local slot_name = context.slot_wnd.slot_name
	if slot_name == "Inventory" or slot_name == "InventoryDead" then
		return true
	end
	
	return false
end

---
--- Determines if an inventory item can be equipped in the context menu.
---
--- @param context table The context information for the inventory item.
--- @return boolean True if the item can be equipped, false otherwise.
---
function InvContextMenuEquippable(context)
	if not InventoryIsContainerOnSameSector(context) then
		return false
	end

	if not context or not context.item then return false end
	if context.item.locked then return false end
	if not InvContextMenuFilter(context) then return false end
	if not gv_SatelliteView and not InventoryIsValidGiveDistance(context.context, context.unit)then
		return false
	end	
	
	return context.item:IsKindOfClasses("Grenade", "QuickSlotItem", "Armor", "Firearm","MeleeWeapon","HeavyWeapon") or -- Equippable
		not context.item:IsKindOfClasses("InventoryStack", "ToolItem", "Medicine", -- Equippable by omission lol
												 "Valuables", "ValuableItemContainer", "QuestItem", "ConditionAndRepair",
												 "MiscItem", "TrapDetonator", "ValuablesStack")
end