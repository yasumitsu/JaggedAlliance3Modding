--- Stores a boolean value indicating whether spawned objects in the game are currently hidden or not.
--- This variable is used by the `HideSpawnedObjects` function to track the visibility state of spawned objects.
--- When set to `true`, the `HideSpawnedObjects` function will hide all spawned objects. When set to `false`, it will show all hidden objects.
MapVar("HiddenSpawnedObjects", false)
---
--- Hides or shows all spawned objects in the game.
---
--- When `hide` is `true`, this function will hide all spawned objects by clearing their `efVisible` enum flag.
--- When `hide` is `false`, this function will show all previously hidden spawned objects by setting their `efVisible` enum flag.
---
--- This function uses the `HiddenSpawnedObjects` table to keep track of all objects that have been hidden. When showing objects, it iterates through this table to restore their visibility.
---
--- @param hide boolean Whether to hide or show the spawned objects
---
local function HideSpawnedObjects(hide)
    if not hide == not HiddenSpawnedObjects then
        return
    end

    SuspendPassEdits("HideSpawnedObjects")

    if hide then
        HiddenSpawnedObjects = setmetatable({}, weak_values_meta)
        for template, obj in pairs(TemplateSpawn) do
            if IsValid(obj) and obj:GetEnumFlags(const.efVisible) ~= 0 then
                obj:ClearEnumFlags(const.efVisible)
                HiddenSpawnedObjects[#HiddenSpawnedObjects + 1] = obj
            end
        end
    elseif HiddenSpawnedObjects then
        for i = 1, #HiddenSpawnedObjects do
            local obj = HiddenSpawnedObjects[i]
            if IsValid(obj) then
                obj:SetEnumFlags(const.efVisible)
            end
        end
        HiddenSpawnedObjects = false
    end

    ResumePassEdits("HideSpawnedObjects")
end

---
--- Toggles the visibility of all spawned objects in the game.
---
--- This function calls the `HideSpawnedObjects` function, passing the opposite of the current `HiddenSpawnedObjects` value. This will either hide all spawned objects if they are currently visible, or show all previously hidden objects.
---
--- @function ToggleSpawnedObjects
--- @return nil
function ToggleSpawnedObjects()
    HideSpawnedObjects(not HiddenSpawnedObjects)
end
OnMsg.GameEnterEditor = function()
	HideSpawnedObjects(true)
end
OnMsg.GameExitEditor = function()
	HideSpawnedObjects(false)
end

----

local function SortByItems(self)
	return self:GetSortItems()
end

---
--- Defines a base class for objects that can be sorted.
---
--- The `SortedBy` class provides a set of properties and methods for sorting a collection of objects. It includes a `SortBy` property that allows the user to specify one or more sort keys, and a `Sort()` method that sorts the collection based on those keys.
---
--- The `SortByItems` function is used to provide a list of available sort keys for the `SortBy` property.
---
--- @class SortedBy
--- @field SortBy table|boolean The sort keys to use when sorting the collection. Can be a table of key-value pairs, where the key is the sort key and the value is the sort direction (true for ascending, false for descending). Can also be set to false to disable sorting.
--- @field SortBy.key string The name of the sort key.
--- @field SortBy.dir boolean The sort direction (true for ascending, false for descending).
--- @field SortBy.items function A function that returns a list of available sort keys.
--- @field SortBy.max_items_in_set integer The maximum number of sort keys that can be selected.
--- @field SortBy.border integer The border width of the property editor.
--- @field SortBy.three_state boolean Whether the property editor should have a three-state (true/false/nil) value.
DefineClass.SortedBy = {__parents={"PropertyObject"},
    properties={{id="SortBy", editor="set", default=false, items=SortByItems, max_items_in_set=1, border=2,
        three_state=true}}}

---
--- Returns a list of available sort keys for the `SortBy` property.
---
--- This function is used to provide a list of available sort keys that can be selected for the `SortBy` property of the `SortedBy` class. The implementation of this function is left empty, as the specific sort keys available will depend on the implementation of the `SortedBy` class.
---
--- @function SortedBy:GetSortItems
--- @return table A table of available sort keys.
function SortedBy:GetSortItems()
    return {}
end

---
--- Sets the sort keys for the collection and sorts the collection based on those keys.
---
--- @function SortedBy:SetSortBy
--- @param sort_by table|boolean The new sort keys to use. Can be a table of key-value pairs, where the key is the sort key and the value is the sort direction (true for ascending, false for descending). Can also be set to false to disable sorting.
--- @return nil
function SortedBy:SetSortBy(sort_by)
    self.SortBy = sort_by
    self:Sort()
end

---
--- Resolves the sort key and sort direction from the `SortBy` property.
---
--- This function iterates over the `SortBy` property and returns the first key-value pair, which represents the sort key and sort direction.
---
--- @function SortedBy:ResolveSortKey
--- @return string, boolean The sort key and sort direction.
function SortedBy:ResolveSortKey()
    for key, value in pairs(self.SortBy) do
        return key, value
    end
end

---
--- Compares two objects in the collection based on the specified sort key.
---
--- This function is used to compare two objects in the collection when sorting the collection based on the `SortBy` property. The comparison is performed using the specified sort key.
---
--- @param c1 any The first object to compare.
--- @param c2 any The second object to compare.
--- @param sort_by string The sort key to use for the comparison.
--- @return boolean True if the first object should come before the second object in the sorted collection, false otherwise.
function SortedBy:Cmp(c1, c2, sort_by)
end

---
--- Sorts the collection based on the specified sort keys.
---
--- This function first resolves the sort key and sort direction from the `SortBy` property. It then sorts the collection using the `table.sort()` function, comparing each pair of objects using the `Cmp()` function and the resolved sort key. If the sort direction is descending, the function then reverses the order of the sorted collection.
---
--- @function SortedBy:Sort
--- @return nil
function SortedBy:Sort()
    local key, dir = self:ResolveSortKey()
    table.sort(self, function(c1, c2)
        return self:Cmp(c1, c2, key)
    end)
    if not dir then
        table.reverse(self)
    end
end
