-- Supports storing of editor data via :EditorData() and tracking dirty status

---
--- Represents an object that can be edited in the Ged editor.
--- This class provides functionality for tracking the dirty status of the object and storing editor-specific data.
---
--- @class GedEditedObject
--- @field EditorData() table Returns the editor data associated with this object.
--- @field TrackDirty() void Tracks the dirty status of this object when it is bound to the Ged editor.
--- @field UpdateDirtyStatus() void Updates the dirty status of this object when it is modified in the Ged editor.
--- @field IsOpenInGed() boolean Checks if this object is currently open in the Ged editor.
DefineClass("GedEditedObject")

if FirstLoad then
	g_GedEditorData = setmetatable({}, weak_keys_meta)
	g_DirtyObjects = {}
	g_DirtyObjectsById = {}
end

local function notify_dirty_status(obj, dirty)
	g_DirtyObjects[obj] = dirty or nil
	GedUpdateDirtyObjectsById()
	GedNotify(obj, "OnEditorDirty", dirty)
	for id, ged in pairs(GedConnections) do
		GedUpdateObjectValue(ged, nil, "root|dirty_objects")
	end
end

---
--- Returns the editor data associated with this object.
---
--- @return table The editor data for this object.
function GedEditedObject:EditorData()
    local data = g_GedEditorData[self]
    if not data then
        data = {}
        g_GedEditorData[self] = data
    end
    return data
end

-- calculate original hash when the object is displayed in Ged for editing
---
--- Binds a GedEditedObject to the Ged editor and starts tracking its dirty status.
---
--- This function is called when a GedEditedObject is bound to the Ged editor. It recursively traverses the object hierarchy,
--- starting from the bound object, and calls the TrackDirty() method on any GedEditedObject instances encountered.
--- This ensures that the dirty status of all relevant objects is properly tracked and managed by the Ged editor.
---
--- @param obj GedEditedObject The object being bound to the Ged editor.
---
function OnMsg.GedBindObj(obj)
    while obj do
        if IsKindOf(obj, "GedEditedObject") then
            obj:TrackDirty()
        end
        obj = ParentTableCache[obj]
    end
end

-- update current hash when the object is modified in Ged
function OnMsg.ObjModified(obj)
	while obj do
		if IsKindOf(obj, "GedEditedObject") and obj:IsOpenInGed() then
			obj:UpdateDirtyStatus()
		end
		obj = ParentTableCache[obj] and GetParentTableOfKind(obj, "GedEditedObject")
	end
end

---
--- Checks if the GedEditedObject is currently open in the Ged editor.
---
--- @return boolean true if the object is open in Ged, false otherwise
function GedEditedObject:IsOpenInGed()
    assert(false, "Not implemented") -- please implement in the children classes
end

---
--- Binds a GedEditedObject to the Ged editor and starts tracking its dirty status.
---
--- This function is called when a GedEditedObject is bound to the Ged editor. It recursively traverses the object hierarchy,
--- starting from the bound object, and calls the TrackDirty() method on any GedEditedObject instances encountered.
--- This ensures that the dirty status of all relevant objects is properly tracked and managed by the Ged editor.
---
--- @param self GedEditedObject The object being bound to the Ged editor.
---
function GedEditedObject:TrackDirty()
    local data = self:EditorData()
    if not data.old_hash then
        data.old_hash = self:CalculatePersistHash()
        data.current_hash = data.old_hash
    end
end

---
--- Updates the dirty status of the GedEditedObject.
---
--- This function is called when the object has been modified in the Ged editor. It calculates a new hash for the object and
--- compares it to the previous hash stored in the object's editor data. If the hashes differ, the object is marked as dirty
--- and a notification is sent to the Ged editor.
---
--- @param self GedEditedObject The GedEditedObject instance.
---
function GedEditedObject:UpdateDirtyStatus()
    local data = self:EditorData()
    local old_hash = data.old_hash
    if old_hash then
        local new_hash = self:CalculatePersistHash()
        if data.current_hash ~= new_hash then
            data.current_hash = new_hash
            notify_dirty_status(self, old_hash ~= new_hash)
        end
    end
end

---
--- Checks if the GedEditedObject is currently marked as dirty.
---
--- The dirty status of a GedEditedObject is determined by comparing its current hash value to the previous hash value stored in its editor data. If the hashes differ, the object is considered dirty.
---
--- @return boolean true if the object is dirty, false otherwise
function GedEditedObject:IsDirty()
    local data = self:EditorData()
    local old_hash = data.old_hash
    return old_hash and (old_hash == 0 or old_hash ~= data.current_hash)
end

---
--- Marks the GedEditedObject as dirty, optionally notifying the Ged editor.
---
--- This function is called when the object has been modified in the Ged editor. It sets the old hash value to 0, which
--- indicates that the object is dirty. If the `notify` parameter is not set to `false`, it also sends a notification to
--- the Ged editor that the object has been modified.
---
--- @param self GedEditedObject The GedEditedObject instance.
--- @param notify boolean (optional) Whether to notify the Ged editor of the dirty status. Defaults to `true`.
---
function GedEditedObject:MarkDirty(notify)
    if not self:IsDirty() then
        self:EditorData().old_hash = 0
        if notify ~= false then
            notify_dirty_status(self, true)
        end
    end
end

---
--- Marks the GedEditedObject as clean, updating its current hash and notifying the Ged editor if the object was previously dirty.
---
--- This function is called when the object has been saved or otherwise marked as clean. It calculates a new hash for the object
--- and compares it to the previous hash stored in the object's editor data. If the hashes differ, the object is marked as clean
--- and a notification is sent to the Ged editor that the object is no longer dirty.
---
--- @param self GedEditedObject The GedEditedObject instance.
---
function GedEditedObject:MarkClean()
    local data = self:EditorData()
    data.current_hash = self:CalculatePersistHash()
    if self:IsDirty() then
        data.old_hash = data.current_hash
        notify_dirty_status(self, false)
    end
end


----- Send dirty objects to Ged, so * modified marks can be displayed for them

---
--- Updates the g_DirtyObjectsById table with the current dirty objects.
---
--- This function iterates through the g_DirtyObjects table and adds each dirty object to the g_DirtyObjectsById table. It also marks any linked presets as dirty if any of their linked presets are dirty.
---
--- @param none
--- @return none
---
function GedUpdateDirtyObjectsById()
    local dirty = {}
    for obj in pairs(g_DirtyObjects) do
        dirty[tostring(obj)] = true
        -- mark a preset as dirty if any of its linked presets (defined via a linked_presets property) are dirty
        for parent_preset, linked_presets in pairs(LinkedPresetClasses) do
            if table.find(linked_presets, obj.class) then
                local obj = FindLinkedPresetOfClass(obj, parent_preset)
                if obj then
                    dirty[tostring(obj)] = true
                end
            end
        end
    end
    g_DirtyObjectsById = dirty
end

---
--- Returns a table of dirty objects by ID.
---
--- This function returns a table of dirty objects, where the keys are the string representations of the object IDs.
---
--- @param obj GedEditedObject The GedEditedObject instance.
--- @param filter function An optional filter function to apply to the dirty objects.
--- @param preset_class string An optional preset class to filter the dirty objects by.
--- @return table A table of dirty objects by ID.
---
function GedGetDirtyObjects(obj, filter, preset_class)
    return g_DirtyObjectsById
end
