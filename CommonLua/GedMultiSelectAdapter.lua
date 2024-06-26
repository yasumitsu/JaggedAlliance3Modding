--- Defines a global table `__Undefined` if it does not already exist in the global environment.
--- This is likely a fallback or default value for some undefined or unspecified behavior.
__Undefined = rawget(_G, "__Undefined") or {}
--- Defines a metatable for the `__Undefined` global table, providing custom behavior for converting it to Lua code and to a string representation.
---
--- The `__toluacode` metamethod returns the string `"__Undefined"` when the table is converted to Lua code, either directly or as part of a larger string.
---
--- The `__tostring` metamethod returns the string `"__Undefined__"` when the table is converted to a string.
---
--- This is likely a fallback or default value for some undefined or unspecified behavior in the codebase.
setmetatable(__Undefined, {__toluacode=function(self, indent, pstr)
    local code = "__Undefined"
    if pstr then
        return pstr:append(code)
    else
        return code
    end
end, __tostring=function(self)
    return "__Undefined__"
end})
---
--- Returns the `__Undefined` global table, which is likely a fallback or default value for some undefined or unspecified behavior in the codebase.
---
--- @return table The `__Undefined` global table
function Undefined()
    return __Undefined
end

if FirstLoad then
	GedMultiSelectAdapters = setmetatable({}, weak_keys_meta)
end

--- Defines a class `GedMultiSelectAdapter` that inherits from `PropertyObject` and `InitDone`.
---
--- The class has the following properties:
--- - `__objects`: a table to store nested objects or lists, to prevent name collisions.
--- - `properties`: a boolean value, likely indicating whether the object has properties.
--- - `property_merge_union`: a string value, either "any" or "all", likely controlling how property metadata is merged.
---
--- This class is likely used to manage the state and behavior of a multi-select adapter in a GUI or editor context.
DefineClass.GedMultiSelectAdapter =
    {__parents={"PropertyObject", "InitDone"}, __objects={}, -- try to prevent name collisions; we store nested objs/lists directly in the object
        properties=false, property_merge_union="any" -- or "all"
    }

local dont_evaluate = { default = true, preset_filter = true, class_filter = true, setter = true, getter = true, dont_save = true }
local special_treat = { max = Min, min = Max }
local eval = prop_eval
local function MergePropMeta(prop_accumulator, prop_meta, object)
	if prop_meta.no_edit and eval(prop_meta.no_edit, object, prop_meta) then
		return nil
	end
	
	if not prop_accumulator then
		prop_accumulator = {}
		for meta_name, value in pairs(prop_meta) do
			prop_accumulator[meta_name] = dont_evaluate[meta_name] and value or eval(value, object, prop_meta)
		end
		if prop_accumulator.default == nil then
			prop_accumulator.default = PropertyObject.GetDefaultPropertyValue(object, prop_meta.id, prop_meta)
		end
		prop_accumulator.__count = 1
	else
		for meta_name, value in pairs(prop_meta) do
			value = dont_evaluate[meta_name] and value or eval(value, object, prop_meta)
			local acc_value = prop_accumulator[meta_name]
			local special_treat_fn = special_treat[meta_name]
			if special_treat_fn then
				prop_accumulator[meta_name] = special_treat_fn(acc_value, value)
			elseif not CompareValues(acc_value, value) then
				return nil
			end
		end
		prop_accumulator.__count = prop_accumulator.__count + 1
	end
	return prop_accumulator
end

local function CalculatePropertyMetadata(objects)
	local prop_ids = {} -- keep the order of the properties.
	local properties_accumulator = {}
	local prop_ids_with_mismatches = {}
	
	for _, object in ipairs(objects) do
		local properties = object:GetProperties()
		
		for _, prop_meta in ipairs(properties) do
			if not prop_ids_with_mismatches[prop_meta.id] then
				local acc = properties_accumulator[prop_meta.id]
				if not acc then
					prop_ids[#prop_ids+1] = prop_meta.id
				end
				local resulting_acc = MergePropMeta(acc, prop_meta, object)
				properties_accumulator[prop_meta.id] = resulting_acc
				if resulting_acc == nil then
					prop_ids_with_mismatches[prop_meta.id] = true
				end
			end
		end
	end
	
	-- convert to standard prop table
	return properties_accumulator, prop_ids
end

local function MultiselectAdapterGetProperties(objects, property_merge_union)
	local props = {}
	local metas, order = CalculatePropertyMetadata(objects)

	for _, prop_id in ipairs(order) do
		local meta = metas[prop_id]
		if meta then
			if property_merge_union == "any" or (meta.__count == #objects and property_merge_union == "all") then
				table.insert(props, meta)
				props[prop_id] = meta
			end
		end
	end
	return props
end

--- Initializes the GedMultiSelectAdapter.
-- Removes any invalid objects from the __objects list, binds the remaining objects to the Ged, updates the property metadatas, and adds the adapter to the GedMultiSelectAdapters table.
function GedMultiSelectAdapter:Init()
    local objects = self.__objects
    for i = #objects, 1, -1 do
        if not GedIsValidObject(objects[i]) then
            table.remove(objects, i)
        end
    end
    for _, obj in ipairs(objects) do
        Msg("GedBindObj", obj)
    end

    self:UpdatePropertyMetadatas()
    GedMultiSelectAdapters[self] = true
end

--- Updates the property metadatas for the GedMultiSelectAdapter.
-- This function is responsible for:
-- 1. Calculating the property metadata for the objects in the adapter using `MultiselectAdapterGetProperties`.
-- 2. Creating copies of any nested_obj/nested_list properties in the adapter for the Ged to edit.
-- This function is called during the initialization of the adapter and when the objects in the adapter are modified.
function GedMultiSelectAdapter:UpdatePropertyMetadatas()
    self.properties = MultiselectAdapterGetProperties(self.__objects, self.property_merge_union)

    -- creates copies of any nested_obj/nested_list properties in the object for Ged to edit
    for _, prop in ipairs(self.properties) do
        local editor, id = prop.editor, prop.id
        if editor == "nested_obj" or editor == "nested_list" then
            local value = self:GetProperty(id)
            if value ~= Undefined() and rawget(self, id) == nil then
                rawset(self, id, self:CopyNestedObjOrList(value))
            end
        end
    end
end

--- Copies a nested object or list, creating a deep copy of the nested values.
---
--- If the input `value` is a `PropertyObject`, it will be cloned. If the input `value` is a table, each item in the table will be cloned.
---
--- @param value table|PropertyObject The nested object or list to be copied.
--- @return table|PropertyObject A deep copy of the input `value`.
function GedMultiSelectAdapter:CopyNestedObjOrList(value)
    local ret = false
    if value then
        if IsKindOf(value, "PropertyObject") then
            ret = value:Clone()
        else
            ret = {}
            for i, item in ipairs(value) do
                ret[i] = item:Clone()
            end
        end
    end
    return ret
end

--- Copies the nested property value from the GedMultiSelectAdapter to all the objects in the adapter.
---
--- This function is responsible for:
--- 1. Iterating through all the objects in the adapter.
--- 2. For each object, setting the property with the given ID to a deep copy of the nested property value stored in the adapter.
---
--- This function is called when a nested property is modified in the Ged to ensure that the changes are propagated to all the objects in the adapter.
---
--- @param id string The ID of the nested property to copy.
function GedMultiSelectAdapter:CopyNestedPropValueToObjects(id)
    for _, obj in ipairs(self.__objects) do
        obj:SetProperty(id, self:CopyNestedObjOrList(self[id]))
    end
end

--- When a property with a "nested_obj" or "nested_list" editor is set in the Ged, this function is responsible for copying the nested property value from the GedMultiSelectAdapter to all the objects in the adapter.
---
--- This function is called to ensure that any changes made to the nested property in the Ged are propagated to all the objects in the adapter.
---
--- @param prop_id string The ID of the nested property to copy.
function GedMultiSelectAdapter:OnEditorSetProperty(prop_id, old_value, ged)
    local prop_meta = self:GetPropertyMetadata(prop_id)
    if prop_meta.editor == "nested_obj" or prop_meta.editor == "nested_list" then
        self:CopyNestedPropValueToObjects(prop_id)
    end
end

--- Clears the nested property value stored in the GedMultiSelectAdapter.
---
--- This function is responsible for:
--- 1. Checking if the property metadata indicates that the property has a "nested_obj" or "nested_list" editor.
--- 2. If so, setting the property value to `nil` in the GedMultiSelectAdapter.
---
--- This function is typically called when the nested property needs to be cleared or reset in the Ged.
---
--- @param prop_id string The ID of the nested property to clear.
function GedMultiSelectAdapter:ClearNestedProperty(prop_id)
    local prop_meta = self:GetPropertyMetadata(prop_id)
    if prop_meta.editor == "nested_obj" or prop_meta.editor == "nested_list" then
        self[prop_id] = nil
    end
end

--- Handles object modification events for GedMultiSelectAdapter instances.
---
--- This function is called whenever an object is modified. It checks if the modified object is a GedMultiSelectAdapter instance, and if so, updates its property metadatas. Otherwise, it iterates through all GedMultiSelectAdapter instances and checks if the modified object is referenced by any of them. If so, it calls the `CopyNestedPropValueToObjects` method of the corresponding adapter to propagate any changes to the nested property values.
---
--- @param obj table The modified object.
function GedMultiSelectAdapterObjModified(obj)
    if IsKindOf(obj, "GedMultiSelectAdapter") then
        obj:UpdatePropertyMetadatas()
        return
    end
    for adapter in pairs(GedMultiSelectAdapters) do
        for id, value in pairs(adapter) do
            if (rawequal(obj, value) or type(value) == "table" and table.find(value, obj))
                and table.find(adapter.properties, "id", id) then
                adapter:CopyNestedPropValueToObjects(id)
            end
        end
    end
end

OnMsg.GedObjectModified = GedMultiSelectAdapterObjModified

--- Gets the value of the specified property from the GedMultiSelectAdapter.
---
--- If the property value is set directly on the adapter, it returns that value.
--- Otherwise, it iterates through all the objects in the adapter and gets the property value from each object.
--- If the property values differ across the objects, it returns `Undefined()`.
---
--- @param prop_id string The ID of the property to get.
--- @return any The value of the specified property, or `Undefined()` if the values differ across the objects.
function GedMultiSelectAdapter:GetProperty(prop_id)
    local value = rawget(self, prop_id)
    if value ~= nil then
        return value
    end
    for _, obj in ipairs(self.__objects) do
        if GedIsValidObject(obj) then
            local new_val = GetProperty(obj, prop_id)
            if new_val ~= nil then
                if value ~= nil and not CompareValues(new_val, value) then
                    return Undefined()
                end
                value = new_val
            end
        end
    end
    return value
end

--- Gets the default property value for the specified property.
---
--- If the property metadata contains a "default" field, this function returns that value.
--- Otherwise, it returns the default value specified in the "properties" table of the GedMultiSelectAdapter.
---
--- @param prop_id string The ID of the property.
--- @param prop_meta table The metadata for the property.
--- @return any The default value for the specified property.
function GedMultiSelectAdapter:GetDefaultPropertyValue(prop_id, prop_meta)
    if prop_meta then
        local value = rawget(prop_meta, "default")
        if value ~= nil then
            return value
        end
    end
    return self.properties[prop_id].default
end

---
--- Executes a property button for each object in the GedMultiSelectAdapter.
---
--- This function suspends object modification notifications, executes the specified function or method on each object in the adapter, and collects any errors and undo functions that are returned.
---
--- @param root table The root object for the property button.
--- @param prop_id string The ID of the property.
--- @param ged table The GED object associated with the property.
--- @param func string|function The function or method to execute on each object.
--- @param param any Optional parameter to pass to the function or method.
--- @return string|nil Any error messages concatenated, or nil if no errors.
--- @return function|nil An undo function that can be called to undo the changes made by this function, or nil if no changes were made.
function GedMultiSelectAdapter:ExecPropButton(root, prop_id, ged, func, param)
    SuspendObjModified("GedMultiSelectAdapter:ExecPropButton")
    local errs, undos = {}, {}
    for _, obj in ipairs(self.__objects) do
        if GedIsValidObject(obj) then
            local err, undo
            local prop_capture = GedPropCapture(obj)
            if type(func) == "function" then
                err, undo = func(obj, root, prop_id, ged, param)
            elseif obj:HasMember(func) then
                err, undo = obj[func](obj, root, prop_id, ged, param)
            elseif type(rawget(_G, func)) == "function" then
                err, undo = _G[func](root, obj, prop_id, ged, param)
            end

            local undop = GedCreatePropValuesUndoFn(obj, prop_capture)
            if type(err) == "string" then
                errs[#errs + 1] = err
            end
            if type(undo) == "function" then
                undos[#undos + 1] = undo
            end
            if type(undop) == "function" then
                undos[#undos + 1] = undop
            end
        end
    end
    ResumeObjModified("GedMultiSelectAdapter:ExecPropButton")

    return next(errs) and table.concat(errs, "\n"), #undos > 0 and function()
        for i = 1, #undos do
            undos[i]()
        end
    end or nil
end

---
--- Calls the `OnEditorSelect` method on each valid object in the `GedMultiSelectAdapter`.
---
--- This function iterates through the `__objects` table of the `GedMultiSelectAdapter` and calls the `OnEditorSelect` method on each valid object that has that method defined. This allows each object to handle the editor selection event.
---
--- @param ... any Arguments to pass to the `OnEditorSelect` method of each object.
function GedMultiSelectAdapter:OnEditorSelect(...)
    for _, obj in ipairs(self.__objects) do
        if GedIsValidObject(obj) and PropObjHasMember(obj, "OnEditorSelect") then
            obj:OnEditorSelect(...)
        end
    end
end
