-- ========== THIS IS AN AUTOMATICALLY GENERATED FILE! ==========

---
--- Defines extra definitions for the `InventoryItem` class, including caching and component handling.
---
--- This function is called when the game classes are built, and sets up the following properties on the `InventoryItem` class:
---
--- - `components_cache`: Disables caching of the components for `InventoryItem` objects.
--- - `GetComponents`: Sets the `GetComponents` method to use the `InventoryItemCompositeDef.GetComponents` implementation.
--- - `ComponentClass`: Sets the `ComponentClass` to use the `InventoryItemCompositeDef.ComponentClass`.
--- - `ObjectBaseClass`: Sets the `ObjectBaseClass` to use the `InventoryItemCompositeDef.ObjectBaseClass`.
---
function __InventoryItemExtraDefinitions()
	InventoryItem.components_cache = false
	InventoryItem.GetComponents = InventoryItemCompositeDef.GetComponents
	InventoryItem.ComponentClass = InventoryItemCompositeDef.ComponentClass
	InventoryItem.ObjectBaseClass = InventoryItemCompositeDef.ObjectBaseClass

end

function OnMsg.ClassesBuilt() __InventoryItemExtraDefinitions() end
