if FirstLoad then
	ParentTableCache = setmetatable({}, weak_keyvalues_meta)
end

local function no_loops(t)
	local processed = {}
	while t and not processed[t] do
		processed[t] = true
		t = ParentTableCache[t]
	end
	return not processed[t]
end

local function __PopulateParentTableCache(t, processed, ignore_keys)
	for key, value in pairs(t) do
		if not ignore_keys[key] and type(value) == "table" and not IsT(value) and not processed[value] then
			if not ParentTableCache[value] then
				ParentTableCache[value] = t
				processed[value] = true
				if no_loops(value) then
					__PopulateParentTableCache(value, processed, ignore_keys)
				else
					assert(false, "A loop in ParentTableCache was just introduced.")
					ParentTableCache[value] = nil
				end
			elseif ParentTableCache[value] ~= t then
				-- only ModItem objects and their subitems are expected to have two conflicting parent tables, e.g. ModItemPreset
				-- if this asserts for something else, please add calls to UpdateParentTable or ParentTableModified when its parent changes
				assert(IsKindOf(value, "ModElement") or GetParentTableOfKind(value, "ModElement"))
			end
		end
	end
end

---
--- Populates the ParentTableCache by recursively traversing the given table `t` and its child tables.
--- The cache maps each table to its parent table, if any.
--- This function is used to build the cache for tables that are part of the mod system.
---
--- @param t table The table to start populating the cache from.
---
function PopulateParentTableCache(t)
	PauseInfiniteLoopDetection("PopulateParentTableCache")
	__PopulateParentTableCache(t, {}, MembersReferencingParents)
	ResumeInfiniteLoopDetection("PopulateParentTableCache")
end

---
--- Updates the parent table cache for the given table `t` with the new parent `parent`.
--- Asserts that this update does not introduce a loop in the parent table cache.
---
--- @param t table The table whose parent table should be updated.
--- @param parent table The new parent table for `t`.
---
function UpdateParentTable(t, parent)
	ParentTableCache[t] = parent
	assert(no_loops(t), "A loop in ParentTableCache was just introduced.")
end

---
--- Updates the parent table of 'value' if 'parent' itself has its parent table cached (and 'value' is a table).
--- If 'recursive' is true, also populates the ParentTableCache for 'value'.
---
--- @param value table The table whose parent table should be updated.
--- @param parent table The new parent table for 'value'.
--- @param recursive boolean If true, also populates the ParentTableCache for 'value'.
---
-- updates the parent table of 'value' if 'parent' itself has its parent table cached (and 'value' is a table)
function ParentTableModified(value, parent, recursive)
	if ParentTableCache[parent] and type(value) == "table" and not IsT(value) then
		ParentTableCache[value] = parent
		if recursive then
			PopulateParentTableCache(value)
		end
	end
	assert(no_loops(value), "A loop in ParentTableCache was just introduced.")
end


------ Reading functions

---
--- Returns the parent table of the given table `t` from the ParentTableCache.
---
--- @param t table The table whose parent table should be returned.
--- @return table The parent table of `t`, if it exists in the ParentTableCache.
---
function GetParentTable(t)
	assert(ParentTableCache[t]) -- table parent cache not built (for Presets it is only available after a Ged editor is started, please call PopulateParentTableCache)
	return ParentTableCache[t]
end

---
--- Returns the first parent table of `t` that is an instance of any of the given classes.
---
--- @param t table The table whose parent table should be returned.
--- @param ... string The names of the classes to check for.
--- @return table|nil The first parent table of `t` that is an instance of any of the given classes, or `nil` if no such parent exists.
---
function GetParentTableOfKindNoCheck(t, ...)
	local parent = ParentTableCache[t]
	while parent and not IsKindOfClasses(parent, ...) do
		parent = ParentTableCache[parent]
	end
	return parent
end

---
--- Returns the first parent table of `t` that is an instance of any of the given classes.
---
--- @param t table The table whose parent table should be returned.
--- @param ... string The names of the classes to check for.
--- @return table|nil The first parent table of `t` that is an instance of any of the given classes, or `nil` if no such parent exists.
---
function GetParentTableOfKind(t, ...)
	assert(ParentTableCache[t]) -- table parent cache not built (for Presets it is only available after a Ged editor is started, please call PopulateParentTableCache)
	return GetParentTableOfKindNoCheck(t, ...)
end

---
--- Checks if the given table `t` is a parent table of the given `child` table.
---
--- @param t table The table to check if it is a parent of `child`.
--- @param child table The table to check if it has `t` as a parent.
--- @return boolean `true` if `t` is a parent table of `child`, `false` otherwise.
---
function IsParentTableOf(t, child)
	local parent = ParentTableCache[child]
	while parent do
		if parent == t then return true end
		parent = ParentTableCache[parent]
	end
end